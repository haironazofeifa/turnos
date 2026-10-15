/// HTTP client for the backend's REST API.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/turno.dart';

/// Thrown when the backend answers with a non-2xx status code.
///
/// [mensaje] holds the `error` text sent by the backend (for example, the
/// message of a 409 Conflict), so it can be shown directly to the user.
class ApiException implements Exception {
  /// HTTP status code of the failed response.
  final int statusCode;

  /// Human-readable error message from the backend.
  final String mensaje;

  /// Creates an exception with the given [statusCode] and [mensaje].
  ApiException(this.statusCode, this.mensaje);

  @override
  String toString() => mensaje;
}

/// Wraps every endpoint of `/api/turnos`, one method per operation.
///
/// Each method returns the ticket(s) parsed into [Turno] objects and throws an
/// [ApiException] if the backend rejects the request. Network failures are
/// thrown as the underlying `http` exception.
class ApiService {
  /// Base URL of the tickets API.
  static const String baseUrl = 'http://localhost:3000/api/turnos';

  /// Headers for requests that send a JSON body.
  static const Map<String, String> _headers = {'Content-Type': 'application/json'};

  /// Fetches every ticket, ordered by number.
  ///
  /// Calls `GET /api/turnos`.
  Future<List<Turno>> obtenerTurnos() async {
    final res = await http.get(Uri.parse(baseUrl));
    _verificar(res);
    final List<dynamic> datos = jsonDecode(res.body);
    return datos.map((j) => Turno.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Creates a new pending ticket for [cliente] and returns it.
  ///
  /// Calls `POST /api/turnos`. Throws an [ApiException] (400) if the name is
  /// not between 2 and 60 characters.
  Future<Turno> crearTurno(String cliente) async {
    final res = await http.post(
      Uri.parse(baseUrl),
      headers: _headers,
      body: jsonEncode({'cliente': cliente}),
    );
    _verificar(res);
    return Turno.fromJson(jsonDecode(res.body));
  }

  /// Calls the pending ticket with the lowest number on behalf of
  /// [funcionario] and returns it.
  ///
  /// Calls `POST /api/turnos/siguiente`. Throws an [ApiException] (404) if
  /// there are no pending tickets.
  Future<Turno> llamarSiguiente(String funcionario) async {
    final res = await http.post(
      Uri.parse('$baseUrl/siguiente'),
      headers: _headers,
      body: jsonEncode({'funcionario': funcionario}),
    );
    _verificar(res);
    return Turno.fromJson(jsonDecode(res.body));
  }

  /// Calls a specific ticket (`pendiente` -> `llamado`) on behalf of
  /// [funcionario].
  ///
  /// Calls `PATCH /api/turnos/:id`. Throws an [ApiException] (409) if the
  /// ticket is no longer pending, for example because another clerk called
  /// it first.
  Future<Turno> llamarTurno(int id, String funcionario) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/$id'),
      headers: _headers,
      body: jsonEncode({'estado': 'llamado', 'funcionario': funcionario}),
    );
    _verificar(res);
    return Turno.fromJson(jsonDecode(res.body));
  }

  /// Marks a called ticket as served (`llamado` -> `atendido`).
  ///
  /// Calls `PATCH /api/turnos/:id`. Throws an [ApiException] (409) if the
  /// ticket is not in the `llamado` state.
  Future<Turno> marcarAtendido(int id) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/$id'),
      headers: _headers,
      body: jsonEncode({'estado': 'atendido'}),
    );
    _verificar(res);
    return Turno.fromJson(jsonDecode(res.body));
  }

  /// Throws an [ApiException] unless [res] has a 2xx status code.
  ///
  /// Uses the backend's `error` message when the body is JSON; otherwise
  /// falls back to a generic `Error <status>` message.
  void _verificar(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    String mensaje = 'Error ${res.statusCode}';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] != null) {
        mensaje = body['error'];
      }
    } catch (_) {
      // The body was not JSON; keep the generic message.
    }
    throw ApiException(res.statusCode, mensaje);
  }
}
