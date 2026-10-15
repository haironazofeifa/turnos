/**
 * @file SQLite connection and schema setup.
 *
 * Opens (or creates) `turnos.db` next to this file, enables WAL mode and makes
 * sure the `turnos` table exists. The module exports a single shared
 * connection that the rest of the backend reuses.
 *
 * @module db
 */

const Database = require('better-sqlite3');
const path = require('path');

/**
 * Absolute path to the database file.
 *
 * Built from `__dirname` so the file always lives in `backend/`, no matter
 * which directory the server is started from.
 * @type {string}
 */
const rutaDb = path.join(__dirname, 'turnos.db');

/**
 * Shared database connection. The file is created if it does not exist.
 * @type {import('better-sqlite3').Database}
 */
const db = new Database(rutaDb);

// Write-Ahead Logging lets reads and writes happen at the same time without
// blocking each other, which improves performance with several clients.
db.pragma('journal_mode = WAL');

// `IF NOT EXISTS` makes this idempotent: restarting the server keeps the data.
//
// Columns:
//   id          Internal identifier.
//   numero      Sequential ticket number shown to the customer (assigned by the server).
//   cliente     Customer name.
//   estado      Lifecycle state: 'pendiente' -> 'llamado' -> 'atendido'.
//   funcionario Name of the clerk who called the ticket (NULL while pending).
//   creado_en   Local timestamp when the ticket was created.
//   llamado_en  Local timestamp when the ticket was called.
//   atendido_en Local timestamp when the ticket was served.
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

module.exports = db;
