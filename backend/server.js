const express = require('express');
const cors = require('cors');
const db = require('./db');

const app = express();
app.use(cors());
app.use(express.json());

// TODO: ruta GET "/" que responda un texto
app.get('/', (req, res) => {
  res.send('¡Hola, mundo!');
});

// TODO: escuchar en el puerto 3000 e imprimir "Servidor en puerto 3000"
app.listen(3000, () => {
  console.log('Servidor en puerto 3000');
});