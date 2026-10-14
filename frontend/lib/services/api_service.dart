import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/turno.dart';

// Error con el mensaje que envía el backend (por ejemplo, el del 409).
class ApiException implements Exception {
  final int statusCode;
  final String mensaje;

  ApiException(this.statusCode, this.mensaje);

  @override
  String toString() => mensaje;
}

class ApiService {
  static const String baseUrl = 'http://localhost:3000/api/turnos';
  static const Map<String, String> _headers = {'Content-Type': 'application/json'};

  // GET /api/turnos
  Future<List<Turno>> obtenerTurnos() async {
    final res = await http.get(Uri.parse(baseUrl));
    _verificar(res);
    final List<dynamic> datos = jsonDecode(res.body);
    return datos.map((j) => Turno.fromJson(j as Map<String, dynamic>)).toList();
  }

  // POST /api/turnos
  Future<Turno> crearTurno(String cliente) async {
    final res = await http.post(
      Uri.parse(baseUrl),
      headers: _headers,
      body: jsonEncode({'cliente': cliente}),
    );
    _verificar(res);
    return Turno.fromJson(jsonDecode(res.body));
  }

  // POST /api/turnos/siguiente
  Future<Turno> llamarSiguiente(String funcionario) async {
    final res = await http.post(
      Uri.parse('$baseUrl/siguiente'),
      headers: _headers,
      body: jsonEncode({'funcionario': funcionario}),
    );
    _verificar(res);
    return Turno.fromJson(jsonDecode(res.body));
  }

  // PATCH /api/turnos/:id  (pendiente -> llamado)
  Future<Turno> llamarTurno(int id, String funcionario) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/$id'),
      headers: _headers,
      body: jsonEncode({'estado': 'llamado', 'funcionario': funcionario}),
    );
    _verificar(res);
    return Turno.fromJson(jsonDecode(res.body));
  }

  // PATCH /api/turnos/:id  (llamado -> atendido)
  Future<Turno> marcarAtendido(int id) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/$id'),
      headers: _headers,
      body: jsonEncode({'estado': 'atendido'}),
    );
    _verificar(res);
    return Turno.fromJson(jsonDecode(res.body));
  }

  // Si el código no es 2xx, lanza un ApiException con el mensaje del backend.
  void _verificar(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    String mensaje = 'Error ${res.statusCode}';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] != null) {
        mensaje = body['error'];
      }
    } catch (_) {
      // La respuesta no era JSON; nos quedamos con el mensaje genérico
    }
    throw ApiException(res.statusCode, mensaje);
  }
}