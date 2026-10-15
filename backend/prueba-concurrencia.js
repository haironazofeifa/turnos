/**
 * @file Concurrency test: simulates two clerks acting at the same time.
 *
 * Runs two scenarios against the live API and prints `CORRECTO` or `ERROR`:
 * 1. Two clerks call the SAME ticket at once -> exactly one must succeed.
 * 2. Two clerks press "call next" at once -> each must get a different ticket.
 *
 * Prerequisite: the server must be running (`npm start` in another terminal).
 * Note: this script creates real tickets in the database.
 *
 * Usage: `node prueba-concurrencia.js`
 */

/** Base URL of the tickets API. */
const URL = 'http://localhost:3000/api/turnos';

/** Headers for JSON request bodies. */
const JSON_HEADERS = { 'Content-Type': 'application/json' };

/**
 * Creates a ticket.
 *
 * @param {string} cliente - Customer name.
 * @returns {Promise<Object>} The created ticket as returned by the API.
 */
async function crearTurno(cliente) {
  const res = await fetch(URL, {
    method: 'POST',
    headers: JSON_HEADERS,
    body: JSON.stringify({ cliente }),
  });
  return res.json();
}

/**
 * Tries to call a specific ticket (`pendiente -> llamado`).
 *
 * @param {number} id - Ticket id.
 * @param {string} funcionario - Name of the clerk making the call.
 * @returns {Promise<{funcionario: string, status: number, body: Object}>}
 *   The clerk name, the HTTP status and the parsed response body.
 */
async function llamarTurno(id, funcionario) {
  const res = await fetch(`${URL}/${id}`, {
    method: 'PATCH',
    headers: JSON_HEADERS,
    body: JSON.stringify({ estado: 'llamado', funcionario }),
  });
  return { funcionario, status: res.status, body: await res.json() };
}

/**
 * Calls the next pending ticket.
 *
 * @param {string} funcionario - Name of the clerk making the call.
 * @returns {Promise<{funcionario: string, status: number, body: Object}>}
 *   The clerk name, the HTTP status and the parsed response body.
 */
async function llamarSiguiente(funcionario) {
  const res = await fetch(`${URL}/siguiente`, {
    method: 'POST',
    headers: JSON_HEADERS,
    body: JSON.stringify({ funcionario }),
  });
  return { funcionario, status: res.status, body: await res.json() };
}

/**
 * Runs both scenarios and prints the results.
 *
 * `Promise.all` fires both requests without waiting for the first one to
 * finish, which is what makes them race against each other on the server.
 *
 * @returns {Promise<void>}
 */
async function main() {
  console.log('=== Prueba 1: dos funcionarios llaman EL MISMO turno a la vez ===');
  const turno = await crearTurno('Prueba concurrencia');
  console.log(`Turno creado: número ${turno.numero} (id ${turno.id})`);

  const resultados = await Promise.all([
    llamarTurno(turno.id, 'Funcionario A'),
    llamarTurno(turno.id, 'Funcionario B'),
  ]);

  for (const r of resultados) {
    const detalle = r.status === 200 ? 'lo llamó' : r.body.error;
    console.log(`  ${r.funcionario}: ${r.status} -> ${detalle}`);
  }

  const exitos = resultados.filter((r) => r.status === 200).length;
  console.log(exitos === 1
    ? 'CORRECTO: solo un funcionario tuvo éxito\n'
    : `ERROR: ${exitos} funcionarios tuvieron éxito\n`);

  console.log('=== Prueba 2: dos funcionarios presionan "Llamar siguiente" a la vez ===');
  await crearTurno('Cliente X');
  await crearTurno('Cliente Y');

  const [a, b] = await Promise.all([
    llamarSiguiente('Funcionario A'),
    llamarSiguiente('Funcionario B'),
  ]);

  console.log(`  Funcionario A: ${a.status} -> turno ${a.body.numero ?? a.body.error}`);
  console.log(`  Funcionario B: ${b.status} -> turno ${b.body.numero ?? b.body.error}`);

  if (a.status === 200 && b.status === 200) {
    console.log(a.body.numero !== b.body.numero
      ? 'CORRECTO: cada funcionario recibió un turno distinto'
      : 'ERROR: ambos recibieron el mismo turno');
  }
}

main().catch((e) => console.error('Error. ¿Está encendido el servidor?', e.message));
