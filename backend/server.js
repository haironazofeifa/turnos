const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// TODO: ruta GET "/" que responda un texto

// TODO: escuchar en el puerto 3000 e imprimir "Servidor en puerto 3000"