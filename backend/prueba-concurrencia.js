// Prueba de concurrencia: simula dos funcionarios actuando al mismo tiempo.
// Requisito: el servidor debe estar encendido (npm start en otra terminal).
const URL = 'http://localhost:3000/api/turnos';
const JSON_HEADERS = { 'Content-Type': 'application/json' };

async function crearTurno(cliente) {
  const res = await fetch(URL, {
    method: 'POST',
    headers: JSON_HEADERS,
    body: JSON.stringify({ cliente }),
  });
  return res.json();
}

async function llamarTurno(id, funcionario) {
  const res = await fetch(`${URL}/${id}`, {
    method: 'PATCH',
    headers: JSON_HEADERS,
    body: JSON.stringify({ estado: 'llamado', funcionario }),
  });
  return { funcionario, status: res.status, body: await res.json() };
}

async function llamarSiguiente(funcionario) {
  const res = await fetch(`${URL}/siguiente`, {
    method: 'POST',
    headers: JSON_HEADERS,
    body: JSON.stringify({ funcionario }),
  });
  return { funcionario, status: res.status, body: await res.json() };
}

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