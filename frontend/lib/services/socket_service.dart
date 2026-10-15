/// Real-time connection to the backend through Socket.IO.
library;

import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/turno.dart';

/// Owns the WebSocket connection to the backend and nothing else.
///
/// It turns the backend's `turno_creado` and `turno_actualizado` events into
/// [Turno] objects and reports them through callbacks, so it does not need to
/// know how the app stores its state.
class SocketService {
  io.Socket? _socket;

  /// Opens the connection and registers the callbacks.
  ///
  /// - [alConectar] runs on the first connection **and on every
  ///   reconnection**, which makes it the right place to reload data that
  ///   may have been missed while offline.
  /// - [alDesconectar] runs whenever the connection drops.
  /// - [alRecibirTurno] runs with the ticket from every `turno_creado` or
  ///   `turno_actualizado` event.
  ///
  /// The connection uses WebSocket directly (no HTTP long-polling) and
  /// reconnects automatically.
  void conectar({
    required void Function() alConectar,
    required void Function() alDesconectar,
    required void Function(Turno turno) alRecibirTurno,
  }) {
    _socket = io.io(
      'http://localhost:3000',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .build(),
    );

    _socket!.onConnect((_) => alConectar());
    _socket!.onDisconnect((_) => alDesconectar());

    _socket!.on('turno_creado', (data) {
      alRecibirTurno(Turno.fromJson(Map<String, dynamic>.from(data as Map)));
    });
    _socket!.on('turno_actualizado', (data) {
      alRecibirTurno(Turno.fromJson(Map<String, dynamic>.from(data as Map)));
    });
  }

  /// Closes the connection and releases its resources.
  ///
  /// Safe to call even if [conectar] was never called.
  void desconectar() {
    _socket?.dispose();
  }
}
