/**
 * @file HTTP and WebSocket server for the ticket (turnos) system.
 *
 * Exposes a REST API under `/api/turnos` to create tickets and move them
 * through their lifecycle, and broadcasts every change to all connected
 * clients through Socket.IO so every screen stays in sync.
 *
 * Ticket lifecycle (only forward transitions are allowed):
 *
 *     pendiente --(call)--> llamado --(serve)--> atendido
 *
 * Socket.IO events emitted to all clients:
 * - `turno_creado`      - payload: {@link Turno}, after a ticket is created.
 * - `turno_actualizado` - payload: {@link Turno}, after a ticket changes state.
 *
 * Error responses always have the shape `{ "error": string }`.
 */

const express = require('express');
const cors = require('cors');
const http = require('http');
const path = require('path');
const db = require('./db');
const { Server } = require('socket.io');

/**
 * A ticket row as stored in the database and returned by the API.
 *
 * @typedef {Object} Turno
 * @property {number} id                  Internal identifier.
 * @property {number} numero              Sequential ticket number shown to the customer.
 * @property {string} cliente             Customer name (2-60 characters).
 * @property {'pendiente'|'llamado'|'atendido'} estado  Current lifecycle state.
 * @property {?string} funcionario        Clerk who called the ticket, or `null` while pending.
 * @property {string} creado_en           Creation time, local `YYYY-MM-DD HH:MM:SS`.
 * @property {?string} llamado_en         Time the ticket was called, or `null`.
 * @property {?string} atendido_en        Time the ticket was served, or `null`.
 */

const app = express();
app.use(cors());
app.use(express.json());

// Serves static files from `public/` (e.g. the Socket.IO test page).
app.use(express.static(path.join(__dirname, 'public')));

// Socket.IO needs to attach to a plain HTTP server, so we wrap the Express app.
const server = http.createServer(app);
const io = new Server(server, {
    // Allow any origin so Flutter Web (served from another port) can connect.
    cors: { origin: '*' },
});

io.on('connection', (socket) => {
    console.log(`Cliente conectado: ${socket.id} (total: ${io.engine.clientsCount})`);

    socket.on('disconnect', (motivo) => {
        console.log(`Cliente desconectado: ${socket.id} (${motivo})`);
    });
});

/**
 * Valid ticket states. Must match the `CHECK` constraint in `db.js`.
 * @type {ReadonlyArray<string>}
 */
const ESTADOS = ['pendiente', 'llamado', 'atendido'];

/**
 * Finds a ticket by its id.
 *
 * @param {number|bigint} id - Ticket id.
 * @returns {Turno|undefined} The ticket, or `undefined` if it does not exist.
 */
function buscarTurno(id) {
    return db.prepare('SELECT * FROM turnos WHERE id = ?').get(id);
}

/**
 * GET /api/turnos
 *
 * Lists tickets ordered by number.
 *
 * Query parameters:
 * - `estado` (optional): only return tickets in this state.
 *
 * Responses:
 * - 200 `Turno[]`
 * - 400 if `estado` is not a valid state.
 */
app.get('/api/turnos', (req, res) => {
    const { estado } = req.query;

    if (estado) {
        if (!ESTADOS.includes(estado)) {
            return res.status(400).json({ error: 'Estado inválido' });
        }
        const turnos = db
            .prepare('SELECT * FROM turnos WHERE estado = ? ORDER BY numero')
            .all(estado);
        return res.json(turnos);
    }

    const turnos = db.prepare('SELECT * FROM turnos ORDER BY numero').all();
    res.json(turnos);
});

/**
 * Creates a ticket with the next sequential number.
 *
 * Reading `MAX(numero)` and inserting run inside a single transaction, so two
 * clerks creating tickets at the same time can never get the same number.
 * The `UNIQUE` constraint on `numero` is a second line of defense.
 *
 * @function
 * @param {string} cliente - Customer name, already validated.
 * @returns {Turno} The newly created ticket.
 */
const crearTurno = db.transaction((cliente) => {
    const { siguiente } = db
        .prepare('SELECT COALESCE(MAX(numero), 0) + 1 AS siguiente FROM turnos')
        .get();

    const info = db
        .prepare('INSERT INTO turnos (numero, cliente) VALUES (?, ?)')
        .run(siguiente, cliente);

    return buscarTurno(info.lastInsertRowid);
});

/**
 * POST /api/turnos
 *
 * Creates a new ticket in the `pendiente` state.
 *
 * Body: `{ "cliente": string }` (2-60 characters after trimming).
 *
 * Responses:
 * - 201 `Turno`
 * - 400 if the name length is invalid.
 *
 * Emits: `turno_creado`.
 */
app.post('/api/turnos', (req, res) => {
    const cliente = (req.body?.cliente ?? '').toString().trim();

    // Always validate on the server; never rely only on the client form.
    if (cliente.length < 2 || cliente.length > 60) {
        return res
            .status(400)
            .json({ error: 'El nombre del cliente debe tener entre 2 y 60 caracteres' });
    }

    const turno = crearTurno(cliente);
    io.emit('turno_creado', turno);
    res.status(201).json(turno);
});

/**
 * PATCH /api/turnos/:id
 *
 * Moves a ticket to the next state. Only two transitions are allowed:
 * - `pendiente -> llamado`: body `{ "estado": "llamado", "funcionario": string }`
 * - `llamado -> atendido`:  body `{ "estado": "atendido" }`
 *
 * The current state is part of the `UPDATE`'s `WHERE` clause, so checking and
 * updating happen in one atomic statement. If two clerks call the same ticket
 * at once, only one succeeds and the other gets a 409.
 *
 * Responses:
 * - 200 `Turno` with the updated ticket.
 * - 400 if the id, the state or the clerk name is invalid.
 * - 404 if the ticket does not exist.
 * - 409 `{ error, turno }` if the transition is not allowed from the
 *   ticket's current state (`turno` holds its current data).
 *
 * Emits: `turno_actualizado`.
 */
app.patch('/api/turnos/:id', (req, res) => {
    const id = Number(req.params.id);
    const estado = req.body?.estado;
    const funcionario = (req.body?.funcionario ?? '').toString().trim();

    if (!Number.isInteger(id) || id <= 0) {
        return res.status(400).json({ error: 'Id inválido' });
    }
    if (estado !== 'llamado' && estado !== 'atendido') {
        return res.status(400).json({ error: 'El estado debe ser "llamado" o "atendido"' });
    }
    if (estado === 'llamado' && funcionario.length === 0) {
        return res.status(400).json({ error: 'Debe indicar el funcionario que llama' });
    }

    let info;
    if (estado === 'llamado') {
        info = db.prepare(`
      UPDATE turnos
      SET estado = 'llamado', funcionario = ?, llamado_en = datetime('now', 'localtime')
      WHERE id = ? AND estado = 'pendiente'
    `).run(funcionario, id);
    } else {
        info = db.prepare(`
      UPDATE turnos
      SET estado = 'atendido', atendido_en = datetime('now', 'localtime')
      WHERE id = ? AND estado = 'llamado'
    `).run(id);
    }

    // No rows changed: either the ticket does not exist or it was not in the
    // expected state. Look it up to tell those two cases apart.
    if (info.changes === 0) {
        const actual = buscarTurno(id);
        if (!actual) {
            return res.status(404).json({ error: 'El turno no existe' });
        }
        return res.status(409).json({
            error: `No se puede cambiar: el turno ${actual.numero} está "${actual.estado}"`,
            turno: actual,
        });
    }

    const actualizado = buscarTurno(id);
    io.emit('turno_actualizado', actualizado);
    res.json(actualizado);
});

/**
 * Prepared statement that calls the pending ticket with the lowest number.
 *
 * Finding the ticket and updating it is a single atomic SQL statement, so two
 * clerks pressing "call next" at the same time always get different tickets.
 * `RETURNING *` yields the updated row, or nothing if no ticket was pending.
 *
 * Parameters: `funcionario` (string).
 * @type {import('better-sqlite3').Statement}
 */
const llamarSiguiente = db.prepare(`
  UPDATE turnos
  SET estado = 'llamado', funcionario = ?, llamado_en = datetime('now', 'localtime')
  WHERE id = (
    SELECT id FROM turnos
    WHERE estado = 'pendiente'
    ORDER BY numero
    LIMIT 1
  )
  RETURNING *
`);

/**
 * POST /api/turnos/siguiente
 *
 * Calls the next pending ticket (lowest number).
 *
 * Body: `{ "funcionario": string }`.
 *
 * Responses:
 * - 200 `Turno` with the ticket that was called.
 * - 400 if `funcionario` is missing.
 * - 404 if there are no pending tickets.
 *
 * Emits: `turno_actualizado`.
 */
app.post('/api/turnos/siguiente', (req, res) => {
    const funcionario = (req.body?.funcionario ?? '').toString().trim();

    if (funcionario.length === 0) {
        return res.status(400).json({ error: 'Debe indicar el funcionario que llama' });
    }

    const turno = llamarSiguiente.get(funcionario);

    if (!turno) {
        return res.status(404).json({ error: 'No hay turnos pendientes' });
    }

    io.emit('turno_actualizado', turno);
    res.json(turno);
});

/**
 * GET /
 *
 * Simple health check to confirm the server is running.
 */
app.get('/', (req, res) => {
    res.send('¡Hola, mundo!');
});

server.listen(3000, () => {
  console.log('Servidor en puerto 3000');
});
