// Representa un turno tal como lo devuelve el backend.
class Turno {
  final int id;
  final int numero;
  final String cliente;
  final String estado; // 'pendiente', 'llamado' o 'atendido'
  final String? funcionario; // null mientras nadie lo llame
  final String creadoEn;
  final String? llamadoEn;
  final String? atendidoEn;

  Turno({
    required this.id,
    required this.numero,
    required this.cliente,
    required this.estado,
    this.funcionario,
    required this.creadoEn,
    this.llamadoEn,
    this.atendidoEn,
  });

  // Convierte el JSON del backend en un objeto Turno.
  // Los nombres entre comillas son los de la base de datos (con guion bajo).
  factory Turno.fromJson(Map<String, dynamic> json) {
    return Turno(
      id: json['id'] as int,
      numero: json['numero'] as int,
      cliente: json['cliente'] as String,
      estado: json['estado'] as String,
      funcionario: json['funcionario'] as String?,
      creadoEn: json['creado_en'] as String,
      llamadoEn: json['llamado_en'] as String?,
      atendidoEn: json['atendido_en'] as String?,
    );
  }
}