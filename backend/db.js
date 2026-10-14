// Importamos la librería de SQLite y "path" (viene con Node, sirve para armar rutas de archivos)
const Database = require('better-sqlite3');
const path = require('path');

// __dirname es la carpeta donde está este archivo (backend).
// Así turnos.db siempre se crea en backend, sin importar desde dónde se ejecute el servidor.
const rutaDb = path.join(__dirname, 'turnos.db');

// Abre la base de datos. Si el archivo no existe, lo crea.
const db = new Database(rutaDb);

// WAL mejora el rendimiento cuando hay lecturas y escrituras al mismo tiempo.
db.pragma('journal_mode = WAL');

// Crea la tabla solo si no existe. Por eso no da error al reiniciar el servidor.
db.exec(`
  CREATE TABLE IF NOT EXISTS turnos (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    numero      INTEGER NOT NULL UNIQUE,
    cliente     TEXT    NOT NULL,
    estado      TEXT    NOT NULL DEFAULT 'pendiente'
                CHECK (estado IN ('pendiente', 'llamado', 'atendido')),
    funcionario TEXT,
    creado_en   TEXT    NOT NULL DEFAULT (datetime('now', 'localtime')),
    llamado_en  TEXT,
    atendido_en TEXT
  )
`);

console.log('Base de datos lista en', rutaDb);

// Exportamos la conexión para usarla en server.js
module.exports = db;
