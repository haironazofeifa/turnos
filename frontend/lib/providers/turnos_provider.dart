/// Application state for the tickets screen.
library;

import 'package:flutter/foundation.dart';

import '../models/turno.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

/// Holds the tickets, the current clerk and the connection status, and
/// exposes the actions the UI can perform.
///
/// Tickets arrive from two sources: REST responses (after the user's own
/// actions or a full reload) and WebSocket events (after anyone's actions).
/// Both go through [aplicarTurno], which keeps a single copy of each ticket
/// and never lets it move back to an earlier state.
///
/// Typical setup:
///
/// ```dart
/// TurnosProvider()
///   ..cargarTurnos()
///   ..iniciarTiempoReal();
/// ```
class TurnosProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  /// Tickets keyed by id, so the same ticket can never appear twice.
  final Map<int, Turno> _turnos = {};

  /// Whether a full reload ([cargarTurnos]) is in progress.
  bool cargando = false;

  /// Message from the last failed reload, or `null` if it succeeded.
  String? error;

  /// Name of the clerk using this screen. Sent with every call action.
  String funcionario = '';

  final SocketService _socket = SocketService();

  /// Whether the WebSocket is currently connected.
  bool conectado = false;

  /// Opens the WebSocket connection.
  ///
  /// Every time the socket connects **or reconnects**, all tickets are
  /// reloaded from the backend to recover any change missed while offline.
  /// Incoming ticket events are passed to [aplicarTurno].
  void iniciarTiempoReal() {
    _socket.conectar(
      alConectar: () {
        conectado = true;
        notifyListeners();
        cargarTurnos();
      },
      alDesconectar: () {
        conectado = false;
        notifyListeners();
      },
      alRecibirTurno: aplicarTurno,
    );
  }

  @override
  void dispose() {
    _socket.desconectar();
    super.dispose();
  }

  /// Position of each state in the lifecycle. Used by [aplicarTurno] to
  /// detect stale data that would move a ticket backwards.
  static const Map<String, int> _orden = {
    'pendiente': 0,
    'llamado': 1,
    'atendido': 2,
  };

  /// Returns the tickets in [estado], sorted by number (ascending).
  List<Turno> _porEstado(String estado) {
    final lista = _turnos.values.where((t) => t.estado == estado).toList();
    lista.sort((a, b) => a.numero.compareTo(b.numero));
    return lista;
  }

  /// Pending tickets, lowest number first.
  List<Turno> get pendientes => _porEstado('pendiente');

  /// Called tickets, lowest number first.
  List<Turno> get llamados => _porEstado('llamado');

  /// Served tickets, most recently served first.
  ///
  /// Sorted by [Turno.atendidoEn]; its `YYYY-MM-DD HH:MM:SS` format sorts
  /// correctly as text. Tickets served in the same second are ordered by
  /// number, highest first.
  List<Turno> get atendidos {
    final lista = _porEstado('atendido');
    lista.sort((a, b) {
      final porHora = (b.atendidoEn ?? '').compareTo(a.atendidoEn ?? '');
      return porHora != 0 ? porHora : b.numero.compareTo(a.numero);
    });
    return lista;
  }

  /// Sets the clerk name (trimmed) used for call actions.
  void setFuncionario(String nombre) {
    funcionario = nombre.trim();
    notifyListeners();
  }

  /// Replaces all local tickets with the backend's current list.
  ///
  /// Called at startup and on every WebSocket (re)connection. On failure the
  /// existing tickets are kept and [error] is set.
  Future<void> cargarTurnos() async {
    cargando = true;
    error = null;
    notifyListeners();

    try {
      final lista = await _api.obtenerTurnos();
      _turnos
        ..clear()
        ..addAll({for (final t in lista) t.id: t});
    } catch (e) {
      error = 'No se pudo conectar con el servidor';
    } finally {
      cargando = false;
      notifyListeners();
    }
  }

  /// Adds [nuevo] or replaces the stored ticket with the same id.
  ///
  /// Ignores [nuevo] if it is in an earlier state than the stored copy. For
  /// example, if the ticket is already `atendido` and a late `llamado` event
  /// arrives, the event is dropped.
  void aplicarTurno(Turno nuevo) {
    final actual = _turnos[nuevo.id];

    if (actual != null && _orden[nuevo.estado]! < _orden[actual.estado]!) {
      return;
    }

    _turnos[nuevo.id] = nuevo;
    notifyListeners();
  }

  /// Runs an API [accion] and applies the returned ticket.
  ///
  /// Returns `null` on success, or an error message ready to show the user:
  /// the backend's message for an [ApiException] (such as a 409), or a
  /// generic connection error otherwise.
  Future<String?> _ejecutar(Future<Turno> Function() accion) async {
    try {
      final turno = await accion();
      aplicarTurno(turno);
      return null;
    } on ApiException catch (e) {
      return e.mensaje;
    } catch (e) {
      return 'Error de conexión con el servidor';
    }
  }

  /// Creates a ticket for [cliente].
  ///
  /// Returns `null` on success or an error message.
  Future<String?> crearTurno(String cliente) =>
      _ejecutar(() => _api.crearTurno(cliente));

  /// Calls the next pending ticket on behalf of [funcionario].
  ///
  /// Returns `null` on success or an error message.
  Future<String?> llamarSiguiente() =>
      _ejecutar(() => _api.llamarSiguiente(funcionario));

  /// Calls the ticket with [id] on behalf of [funcionario].
  ///
  /// Returns `null` on success or an error message.
  Future<String?> llamarTurno(int id) =>
      _ejecutar(() => _api.llamarTurno(id, funcionario));

  /// Marks the ticket with [id] as served.
  ///
  /// Returns `null` on success or an error message.
  Future<String?> marcarAtendido(int id) =>
      _ejecutar(() => _api.marcarAtendido(id));
}
