/// Data model for a ticket.
library;

/// A ticket (turno) exactly as the backend returns it.
///
/// A ticket moves forward through three states:
/// `'pendiente'` (waiting) -> `'llamado'` (called) -> `'atendido'` (served).
///
/// Timestamps are kept as the strings the backend sends, in local time with
/// the format `YYYY-MM-DD HH:MM:SS`. Because of that format they sort
/// correctly when compared as plain text.
class Turno {
  /// Internal database identifier. Unique per ticket.
  final int id;

  /// Sequential number shown to the customer.
  final int numero;

  /// Customer name.
  final String cliente;

  /// Current state: `'pendiente'`, `'llamado'` or `'atendido'`.
  final String estado;

  /// Name of the clerk who called the ticket, or `null` while it is pending.
  final String? funcionario;

  /// When the ticket was created.
  final String creadoEn;

  /// When the ticket was called, or `null` if it has not been called yet.
  final String? llamadoEn;

  /// When the ticket was served, or `null` if it has not been served yet.
  final String? atendidoEn;

  /// Creates a ticket. Usually built with [Turno.fromJson] instead.
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

  /// Builds a [Turno] from the backend's JSON.
  ///
  /// The JSON keys use the database column names (snake_case), for example
  /// `creado_en` maps to [creadoEn].
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
