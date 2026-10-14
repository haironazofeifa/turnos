const express = require('express');
const cors = require('cors');
const db = require('./db');

const app = express();
app.use(cors());
app.use(express.json());

// Valores permitidos para el estado (los mismos del CHECK de la base)
const ESTADOS = ['pendiente', 'llamado', 'atendido'];

// Devuelve un turno por su id (lo usamos en varias rutas)
function buscarTurno(id) {
  return db.prepare('SELECT * FROM turnos WHERE id = ?').get(id);
}

// ---------- 3a. GET /api/turnos : listar turnos ----------
// Opcional: /api/turnos?estado=pendiente filtra por estado
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

// ---------- 3b. POST /api/turnos : crear turno ----------
// La transacción hace que "calcular el número" e "insertar" sean una sola operación.
// Así dos funcionarios creando turnos a la vez nunca reciben el mismo número.
const crearTurno = db.transaction((cliente) => {
  const { siguiente } = db
    .prepare('SELECT COALESCE(MAX(numero), 0) + 1 AS siguiente FROM turnos')
    .get();

  const info = db
    .prepare('INSERT INTO turnos (numero, cliente) VALUES (?, ?)')
    .run(siguiente, cliente);

  return buscarTurno(info.lastInsertRowid);
});

app.post('/api/turnos', (req, res) => {
  const cliente = (req.body?.cliente ?? '').toString().trim();

  // Validación en el servidor: nunca confiamos solo en la del formulario
  if (cliente.length < 2 || cliente.length > 60) {
    return res
      .status(400)
      .json({ error: 'El nombre del cliente debe tener entre 2 y 60 caracteres' });
  }

  const turno = crearTurno(cliente);
  res.status(201).json(turno);
});

// ---------- 3c. PATCH /api/turnos/:id : cambiar estado ----------
// Solo se permiten dos transiciones: pendiente -> llamado, llamado -> atendido
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
    // El WHERE incluye "estado = 'pendiente'": verificar y actualizar en UNA sola operación
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

  // info.changes = cuántas filas se modificaron
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

  res.json(buscarTurno(id));
});

// TODO: ruta GET "/" que responda un texto
app.get('/', (req, res) => {
  res.send('¡Hola, mundo!');
});

// TODO: escuchar en el puerto 3000 e imprimir "Servidor en puerto 3000"
app.listen(3000, () => {
  console.log('Servidor en puerto 3000');
});