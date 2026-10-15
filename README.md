# Gestión de turnos

Sistema para administrar la fila de atención de clientes. Los funcionarios crean turnos, llaman al siguiente cliente y marcan los turnos como atendidos. Todos los funcionarios conectados ven los cambios **en tiempo real**, sin recargar la página.

- **Backend:** Node.js + Express 5 + SQLite (`better-sqlite3`) + Socket.IO
- **Frontend:** Flutter Web + Provider + `http` + `socket_io_client`

---

## Tabla de contenido

1. [Arquitectura](#arquitectura)
2. [Estructura del proyecto](#estructura-del-proyecto)
3. [Requisitos](#requisitos)
4. [Instalación y ejecución](#instalación-y-ejecución)
5. [Ciclo de vida de un turno](#ciclo-de-vida-de-un-turno)
6. [Base de datos](#base-de-datos)
7. [API REST](#api-rest)
8. [Eventos en tiempo real (Socket.IO)](#eventos-en-tiempo-real-socketio)
9. [Manejo de concurrencia](#manejo-de-concurrencia)
10. [Frontend](#frontend)
11. [Pruebas](#pruebas)
12. [Limitaciones conocidas](#limitaciones-conocidas)

---

## Arquitectura

```
┌──────────────────────┐   HTTP (REST)     ┌──────────────────────┐
│   Flutter Web        │ ────────────────▶ │   Express (puerto    │
│   (uno por           │                   │   3000)              │
│   funcionario)       │ ◀──────────────── │                      │
│                      │   WebSocket       │   Socket.IO          │
│   Provider (estado)  │   turno_creado    │         │            │
│                      │   turno_actualizado         ▼            │
└──────────────────────┘                   │   SQLite (turnos.db) │
                                           └──────────────────────┘
```

1. El cliente Flutter hace **acciones** por REST (crear, llamar, atender).
2. El servidor valida, guarda en SQLite y responde.
3. Después de cada cambio, el servidor **emite un evento** por Socket.IO a todos los clientes conectados.
4. Cada cliente aplica el evento a su lista local, así todas las pantallas quedan sincronizadas.

---

## Estructura del proyecto

```
turnos/
├── backend/
│   ├── server.js               # API REST + Socket.IO
│   ├── db.js                   # Conexión SQLite y creación de la tabla
│   ├── prueba-concurrencia.js  # Script que simula dos funcionarios a la vez
│   ├── public/
│   │   └── prueba-socket.html  # Página para ver los eventos del WebSocket
│   └── package.json
└── frontend/
    ├── lib/
    │   ├── main.dart                     # Punto de entrada, registra el Provider
    │   ├── models/turno.dart             # Modelo Turno (fromJson)
    │   ├── services/api_service.dart     # Llamadas REST
    │   ├── services/socket_service.dart  # Conexión WebSocket
    │   ├── providers/turnos_provider.dart# Estado de la app
    │   └── screens/turnos_screen.dart    # Interfaz (tres columnas)
    └── pubspec.yaml
```

---

## Requisitos

| Herramienta | Versión |
|---|---|
| Node.js | 20 o superior (el script de prueba usa `fetch` nativo y `npm start` usa `--watch`) |
| Flutter | Con Dart SDK 3.13 o superior |
| Navegador | Chrome (para Flutter Web) |

---

## Instalación y ejecución

### 1. Backend

```bash
cd backend
npm install
npm start
```

El servidor queda en `http://localhost:3000`. La primera vez crea el archivo `backend/turnos.db` con la tabla `turnos`.

> `npm start` usa `node --watch`, por lo que el servidor se reinicia solo al guardar cambios.

### 2. Frontend

En otra terminal:

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

La URL del backend está fija en el código:

- `frontend/lib/services/api_service.dart` → `http://localhost:3000/api/turnos`
- `frontend/lib/services/socket_service.dart` → `http://localhost:3000`

Si el backend corre en otra máquina o puerto, hay que cambiar ambas.

### 3. Probar varios funcionarios

Abrí la app en dos pestañas o ventanas, escribí un nombre de funcionario distinto en cada una y realizá acciones: los cambios aparecen en ambas al instante.

---

## Ciclo de vida de un turno

```
 ┌───────────┐  llamar (funcionario)  ┌─────────┐  marcar atendido  ┌──────────┐
 │ pendiente │ ─────────────────────▶ │ llamado │ ────────────────▶ │ atendido │
 └───────────┘                        └─────────┘                   └──────────┘
```

- Solo se permiten esas dos transiciones, siempre hacia adelante.
- Al **llamar** se guarda el nombre del funcionario y la hora (`llamado_en`).
- Al **atender** se guarda la hora (`atendido_en`).
- Cualquier otro cambio responde `409 Conflict`.

---

## Base de datos

Archivo: `backend/turnos.db` (SQLite en modo WAL).

### Tabla `turnos`

| Columna | Tipo | Descripción |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | Identificador interno |
| `numero` | INTEGER NOT NULL UNIQUE | Número consecutivo que ve el cliente; lo asigna el servidor |
| `cliente` | TEXT NOT NULL | Nombre del cliente (2 a 60 caracteres) |
| `estado` | TEXT NOT NULL | `pendiente` (por defecto), `llamado` o `atendido` (restricción `CHECK`) |
| `funcionario` | TEXT | Quién llamó el turno; `NULL` mientras esté pendiente |
| `creado_en` | TEXT NOT NULL | Fecha y hora local de creación (`YYYY-MM-DD HH:MM:SS`) |
| `llamado_en` | TEXT | Fecha y hora en que se llamó |
| `atendido_en` | TEXT | Fecha y hora en que se atendió |

Para empezar con la base vacía: detené el servidor y borrá `turnos.db`, `turnos.db-wal` y `turnos.db-shm`.

---

## API REST

Base: `http://localhost:3000/api/turnos`
Todas las respuestas son JSON. Los errores tienen la forma `{ "error": "mensaje" }`.

### Objeto `Turno`

```json
{
  "id": 1,
  "numero": 1,
  "cliente": "Ana Mora",
  "estado": "llamado",
  "funcionario": "Carlos",
  "creado_en": "2026-10-14 13:50:19",
  "llamado_en": "2026-10-14 13:52:03",
  "atendido_en": null
}
```

### `GET /api/turnos`

Lista todos los turnos ordenados por número.

| Query | Descripción |
|---|---|
| `estado` (opcional) | Filtra por `pendiente`, `llamado` o `atendido` |

| Código | Cuándo |
|---|---|
| 200 | Lista de turnos |
| 400 | `estado` no válido |

```bash
curl "http://localhost:3000/api/turnos?estado=pendiente"
```

### `POST /api/turnos`

Crea un turno nuevo en estado `pendiente`. El número lo calcula el servidor.

```json
{ "cliente": "Ana Mora" }
```

| Código | Cuándo |
|---|---|
| 201 | Turno creado (devuelve el turno) |
| 400 | El nombre no tiene entre 2 y 60 caracteres |

Emite: `turno_creado`.

### `PATCH /api/turnos/:id`

Cambia el estado de un turno.

Llamar un turno específico (`pendiente → llamado`):

```json
{ "estado": "llamado", "funcionario": "Carlos" }
```

Marcarlo como atendido (`llamado → atendido`):

```json
{ "estado": "atendido" }
```

| Código | Cuándo |
|---|---|
| 200 | Turno actualizado |
| 400 | Id inválido, estado distinto de `llamado`/`atendido`, o falta `funcionario` al llamar |
| 404 | El turno no existe |
| 409 | La transición no es válida (por ejemplo, otro funcionario ya lo llamó). Incluye el turno actual en `turno` |

Emite: `turno_actualizado`.

### `POST /api/turnos/siguiente`

Llama al turno pendiente con el número más bajo.

```json
{ "funcionario": "Carlos" }
```

| Código | Cuándo |
|---|---|
| 200 | Devuelve el turno llamado |
| 400 | Falta `funcionario` |
| 404 | No hay turnos pendientes |

Emite: `turno_actualizado`.

---

## Eventos en tiempo real (Socket.IO)

Servidor: `http://localhost:3000` (CORS abierto).

| Evento | Cuándo se emite | Datos |
|---|---|---|
| `turno_creado` | Después de `POST /api/turnos` | Objeto `Turno` |
| `turno_actualizado` | Después de `PATCH /api/turnos/:id` o `POST /api/turnos/siguiente` | Objeto `Turno` |

Los eventos se envían a **todos** los clientes, incluido el que hizo la acción.

**Página de prueba:** con el servidor encendido, abrí `http://localhost:3000/prueba-socket.html` para ver los eventos a medida que llegan.

---

## Manejo de concurrencia

Varios funcionarios pueden actuar al mismo tiempo. El backend evita conflictos así:

| Situación | Solución |
|---|---|
| Dos turnos creados a la vez | Calcular `MAX(numero) + 1` e insertar ocurre dentro de una **transacción**; además `numero` es `UNIQUE` |
| Dos funcionarios llaman el mismo turno | El `UPDATE` incluye `WHERE estado = 'pendiente'`: verificar y actualizar es una sola operación. El segundo recibe `409` |
| Dos funcionarios presionan "Llamar siguiente" | Un solo `UPDATE ... WHERE id = (SELECT ... LIMIT 1) RETURNING *` atómico: cada uno recibe un turno distinto |

En el frontend:

- Los turnos se guardan en un `Map` por `id`, así un turno nunca aparece repetido aunque llegue por REST y por WebSocket.
- `aplicarTurno` ignora información vieja: si un turno ya está `atendido` y llega tarde un evento `llamado`, no retrocede.
- Al conectarse o **reconectarse** el WebSocket, se recarga la lista completa para recuperar lo que pasó mientras estuvo desconectado.

---

## Frontend

### Capas

| Archivo | Responsabilidad |
|---|---|
| `models/turno.dart` | Convierte el JSON del backend (`creado_en`, etc.) en un objeto `Turno` |
| `services/api_service.dart` | Una función por endpoint. Si la respuesta no es 2xx lanza `ApiException` con el mensaje del backend |
| `services/socket_service.dart` | Conecta por WebSocket con reconexión automática y avisa al recibir eventos |
| `providers/turnos_provider.dart` | `ChangeNotifier` con la lista de turnos, el funcionario actual, el estado de conexión y las acciones |
| `screens/turnos_screen.dart` | Interfaz |

### Interfaz

- **Encabezado:** título, indicador *En línea / Reconectando…* y botón para recargar.
- **Controles:** nombre del funcionario, nombre del cliente (validado de 2 a 60 caracteres), botones *Crear turno* y *Llamar siguiente*.
- **Tres columnas:**
  - *Pendientes*: botón para llamar un turno específico.
  - *Llamados*: hora, funcionario y botón *Marcar atendido*.
  - *Atendidos*: historial con horas de creación, llamado y atención.
- Las acciones muestran un aviso verde si salen bien o rojo con el mensaje del servidor (por ejemplo, el del `409`).
- Para llamar o atender hay que escribir primero el nombre del funcionario.

---

## Pruebas

### Prueba de concurrencia (backend)

Con el servidor encendido:

```bash
cd backend
node prueba-concurrencia.js
```

Hace dos pruebas y muestra `CORRECTO` o `ERROR`:

1. Dos funcionarios llaman **el mismo** turno a la vez → solo uno debe tener éxito.
2. Dos funcionarios presionan **"Llamar siguiente"** a la vez → cada uno debe recibir un turno distinto.

> El script crea turnos reales en la base (`Prueba concurrencia`, `Cliente X`, `Cliente Y`).

### Pruebas del frontend

No necesitan el backend encendido:

```bash
cd frontend
flutter test
```

Revisan la lectura del JSON en `Turno.fromJson`, que el provider separe los turnos por estado sin duplicarlos, que un evento viejo no haga retroceder un turno, que *Atendidos* muestre primero el atendido más reciente y que la pantalla muestre las tres columnas.

### Prueba de WebSocket

Abrí `http://localhost:3000/prueba-socket.html` y creá o llamá turnos desde la app o con `curl`.

---

## Limitaciones conocidas

- No hay autenticación: cualquiera que llegue al servidor puede crear o cambiar turnos, y el "funcionario" es solo un texto.
- La numeración nunca se reinicia (no hay cierre diario) y `GET /api/turnos` devuelve todo el historial.
- La URL del backend y el puerto `3000` están fijos en el código.
- La interfaz está pensada para pantalla de escritorio (tres columnas lado a lado).
