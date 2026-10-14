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

// TODO: ruta GET "/" que responda un texto
app.get('/', (req, res) => {
  res.send('¡Hola, mundo!');
});

// TODO: escuchar en el puerto 3000 e imprimir "Servidor en puerto 3000"
app.listen(3000, () => {
  console.log('Servidor en puerto 3000');
});