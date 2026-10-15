import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/turno.dart';

// Se encarga solo de la conexión WebSocket con el backend.
class SocketService {
  io.Socket? _socket;

  void conectar({
    required void Function() alConectar,
    required void Function() alDesconectar,
    required void Function(Turno turno) alRecibirTurno,
  }) {
    _socket = io.io(
      'http://localhost:3000',
      io.OptionBuilder()
          .setTransports(['websocket']) // usar WebSocket directo (no polling)
          .enableReconnection() // si se cae, reintenta solo
          .build(),
    );

    // Se ejecuta en la primera conexión y en CADA reconexión
    _socket!.onConnect((_) => alConectar());
    _socket!.onDisconnect((_) => alDesconectar());

    // Eventos que emite el backend
    _socket!.on('turno_creado', (data) {
      alRecibirTurno(Turno.fromJson(Map<String, dynamic>.from(data as Map)));
    });
    _socket!.on('turno_actualizado', (data) {
      alRecibirTurno(Turno.fromJson(Map<String, dynamic>.from(data as Map)));
    });
  }

  void desconectar() {
    _socket?.dispose();
  }
}