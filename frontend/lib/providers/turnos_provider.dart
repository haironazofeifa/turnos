import 'package:flutter/foundation.dart';

import '../models/turno.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class TurnosProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  // Los turnos se guardan por id: así un mismo turno nunca aparece dos veces.
  final Map<int, Turno> _turnos = {};

  bool cargando = false;
  String? error;
  String funcionario = '';

  final SocketService _socket = SocketService();
  bool conectado = false;

  // Conecta el WebSocket.
  // Cada vez que se conecta o RECONECTA, recarga todo desde el backend.
  // Así recupera los cambios que se perdió mientras estuvo desconectado.
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
      alRecibirTurno:
          aplicarTurno, // agrega o reemplaza por id (sin duplicados)
    );
  }

  @override
  void dispose() {
    _socket.desconectar();
    super.dispose();
  }

  // Orden de los estados: sirve para no "retroceder" un turno (ver aplicarTurno).
  static const Map<String, int> _orden = {
    'pendiente': 0,
    'llamado': 1,
    'atendido': 2,
  };

  // ---------- Listas para la interfaz ----------
  List<Turno> _porEstado(String estado) {
    final lista = _turnos.values.where((t) => t.estado == estado).toList();
    lista.sort((a, b) => a.numero.compareTo(b.numero));
    return lista;
  }

  List<Turno> get pendientes => _porEstado('pendiente');
  List<Turno> get llamados => _porEstado('llamado');
  List<Turno> get atendidos =>
      _porEstado('atendido').reversed.toList(); // recientes primero

  void setFuncionario(String nombre) {
    funcionario = nombre.trim();
    notifyListeners();
  }

  // ---------- Cargar todo desde el backend ----------
  // También se usará al reconectar el WebSocket (Fase 7) para recuperar el estado real.
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

  // ---------- Agregar o reemplazar un turno ----------
  // Se usa con la respuesta REST y, en la Fase 7, con los eventos del WebSocket.
  void aplicarTurno(Turno nuevo) {
    final actual = _turnos[nuevo.id];

    // Si llega información más vieja que la que ya tenemos, se ignora.
    // Ejemplo: ya sabemos que está "atendido" y llega tarde un "llamado".
    if (actual != null && _orden[nuevo.estado]! < _orden[actual.estado]!) {
      return;
    }

    _turnos[nuevo.id] = nuevo;
    notifyListeners();
  }

  // ---------- Acciones del usuario ----------
  // Cada una devuelve null si salió bien, o el mensaje de error para mostrarlo en pantalla.
  Future<String?> _ejecutar(Future<Turno> Function() accion) async {
    try {
      final turno = await accion();
      aplicarTurno(turno);
      return null;
    } on ApiException catch (e) {
      return e.mensaje; // por ejemplo, el mensaje del 409
    } catch (e) {
      return 'Error de conexión con el servidor';
    }
  }

  Future<String?> crearTurno(String cliente) =>
      _ejecutar(() => _api.crearTurno(cliente));

  Future<String?> llamarSiguiente() =>
      _ejecutar(() => _api.llamarSiguiente(funcionario));

  Future<String?> llamarTurno(int id) =>
      _ejecutar(() => _api.llamarTurno(id, funcionario));

  Future<String?> marcarAtendido(int id) =>
      _ejecutar(() => _api.marcarAtendido(id));
}
