/// Main (and only) screen of the app: create, call and serve tickets.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/turno.dart';
import '../providers/turnos_provider.dart';

/// Color palette of the interface (warm tones).
///
/// Each column has a strong color for icons and a light variant for
/// backgrounds: peach for pending, sage for called, terracotta for served.
class Paleta {
  static const fondo = Color(0xFFFAF6F1);
  static const tarjeta = Color(0xFFFFFCF8);
  static const borde = Color(0xFFEDE4DA);
  static const texto = Color(0xFF4A4039);
  static const textoSuave = Color(0xFF9A8F86);
  static const terracota = Color(0xFFE07A5F);
  static const terracotaClaro = Color(0xFFF9E4DC);
  static const durazno = Color(0xFFD98B5F);
  static const duraznoClaro = Color(0xFFFBEADF);
  static const salvia = Color(0xFF6B8F71);
  static const salviaClaro = Color(0xFFE6ECE3);
  static const enLinea = Color(0xFF6BAA75);
}

/// Ticket management screen.
///
/// Shows a header with the connection status, the controls to enter the
/// clerk and customer names, and three columns: pending, called and served
/// tickets. Reads and updates the [TurnosProvider] above it in the tree.
class TurnosScreen extends StatefulWidget {
  /// Creates the ticket management screen.
  const TurnosScreen({super.key});

  @override
  State<TurnosScreen> createState() => _TurnosScreenState();
}

class _TurnosScreenState extends State<TurnosScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clienteCtrl = TextEditingController();
  /// Whether a "create ticket" request is in progress.
  /// Disables the create button to avoid duplicate tickets.
  bool _enviando = false;

  /// Whether a call or serve request is in progress.
  /// Disables those buttons so a double click cannot send two requests.
  bool _procesando = false;

  @override
  void dispose() {
    _clienteCtrl.dispose();
    super.dispose();
  }

  /// Extracts the `HH:MM` part of a backend timestamp.
  ///
  /// `"2026-10-14 13:50:19"` -> `"13:50"`. Returns an empty string for
  /// `null` or malformed values.
  String _hora(String? fecha) =>
      (fecha == null || fecha.length < 16) ? '' : fecha.substring(11, 16);

  /// Shows a floating message: [error] in red if it is not `null`,
  /// otherwise [exito] in green.
  void _avisar(String? error, String exito) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? exito),
        backgroundColor: error == null ? Paleta.salvia : Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Validates the customer name and creates a ticket.
  ///
  /// Clears the field on success and shows the result either way.
  Future<void> _crearTurno() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);
    final error =
        await context.read<TurnosProvider>().crearTurno(_clienteCtrl.text.trim());
    if (!mounted) return;
    setState(() => _enviando = false);

    if (error == null) _clienteCtrl.clear();
    _avisar(error, 'Turno creado');
  }

  /// Runs a call/serve [accion] and shows its result, using [exito] as the
  /// success message.
  ///
  /// Does nothing while another action is in progress, and asks for the
  /// clerk name first if it is empty.
  Future<void> _accion(Future<String?> Function() accion, String exito) async {
    if (_procesando) return;
    if (context.read<TurnosProvider>().funcionario.isEmpty) {
      _avisar('Escribí tu nombre de funcionario primero', '');
      return;
    }
    setState(() => _procesando = true);
    try {
      final error = await accion();
      _avisar(error, exito);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TurnosProvider>();
    final sinDatos =
        p.pendientes.isEmpty && p.llamados.isEmpty && p.atendidos.isEmpty;

    return Scaffold(
      backgroundColor: Paleta.fondo,
      body: Stack(
        children: [
          // Decorative blob in the top-right corner.
          Positioned(
            top: -90,
            right: -70,
            child: Container(
              width: 320,
              height: 220,
              decoration: BoxDecoration(
                color: Paleta.terracotaClaro,
                borderRadius: BorderRadius.circular(160),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _encabezado(p),
                  const SizedBox(height: 16),
                  const Divider(color: Paleta.borde, height: 1),
                  const SizedBox(height: 20),
                  _controles(p),
                  const SizedBox(height: 20),
                  if (p.error != null) ...[
                    Text(
                      p.error!,
                      style: TextStyle(
                          color: Colors.red.shade400, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: p.cargando && sinDatos
                        ? const Center(
                            child: CircularProgressIndicator(color: Paleta.terracota))
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: _columnaPendientes(p)),
                              const SizedBox(width: 16),
                              Expanded(child: _columnaLlamados(p)),
                              const SizedBox(width: 16),
                              Expanded(child: _columnaAtendidos(p)),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Header: title, connection status and reload button.
  Widget _encabezado(TurnosProvider p) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gestión de turnos',
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w600, color: Paleta.texto),
              ),
              SizedBox(height: 4),
              Text(
                'Organiza y da seguimiento a tus turnos de manera fácil y rápida.',
                style: TextStyle(color: Paleta.textoSuave),
              ),
            ],
          ),
        ),
        _estadoConexion(p.conectado),
        const SizedBox(width: 12),
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 2,
          shadowColor: Colors.black12,
          child: IconButton(
            icon: const Icon(Icons.refresh, color: Paleta.texto),
            tooltip: 'Recargar',
            onPressed: p.cargarTurnos,
          ),
        ),
      ],
    );
  }

  /// Pill showing "En línea" (online) or "Reconectando..." (reconnecting).
  Widget _estadoConexion(bool conectado) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle,
              size: 10, color: conectado ? Paleta.enLinea : Paleta.terracota),
          const SizedBox(width: 8),
          Text(
            conectado ? 'En línea' : 'Reconectando...',
            style: const TextStyle(color: Paleta.texto, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// Controls: clerk name, customer name, "create" and "call next" buttons.
  ///
  /// The customer field is validated on the client with the same rules as
  /// the backend (2-60 characters).
  Widget _controles(TurnosProvider p) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 240,
          child: TextField(
            decoration: _decoracion('Funcionario', Icons.badge_outlined),
            onChanged: p.setFuncionario,
          ),
        ),
        SizedBox(
          width: 260,
          child: Form(
            key: _formKey,
            child: TextFormField(
              controller: _clienteCtrl,
              decoration: _decoracion('Nombre del cliente', Icons.person_outline),
              validator: (valor) {
                final texto = valor?.trim() ?? '';
                if (texto.isEmpty) return 'Campo obligatorio';
                if (texto.length < 2) return 'Mínimo 2 caracteres';
                if (texto.length > 60) return 'Máximo 60 caracteres';
                return null;
              },
              onFieldSubmitted: (_) => _crearTurno(),
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: _enviando ? null : _crearTurno,
          icon: const Icon(Icons.add),
          label: const Text('Crear turno'),
          style: _estiloBoton(Paleta.terracota, Colors.white),
        ),
        FilledButton.icon(
          onPressed:
              _procesando ? null : () => _accion(p.llamarSiguiente, 'Turno llamado'),
          icon: const Icon(Icons.campaign_outlined),
          label: const Text('Llamar siguiente'),
          style: _estiloBoton(Paleta.salviaClaro, Paleta.salvia),
        ),
      ],
    );
  }

  /// Rounded, filled input style with a [texto] hint and an [icono] prefix.
  InputDecoration _decoracion(String texto, IconData icono) {
    OutlineInputBorder borde(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: color),
        );

    return InputDecoration(
      hintText: texto,
      hintStyle: const TextStyle(color: Paleta.textoSuave),
      prefixIcon: Icon(icono, color: Paleta.textoSuave),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
      enabledBorder: borde(Paleta.borde),
      focusedBorder: borde(Paleta.terracota),
      errorBorder: borde(Colors.red.shade300),
      focusedErrorBorder: borde(Colors.red.shade300),
    );
  }

  /// Pill-shaped button style with the given [fondo] and [texto] colors.
  ButtonStyle _estiloBoton(Color fondo, Color texto) => FilledButton.styleFrom(
        backgroundColor: fondo,
        foregroundColor: texto,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      );

  /// Pending column: each ticket has a button to call it.
  Widget _columnaPendientes(TurnosProvider p) => _columna(
        titulo: 'Pendientes',
        icono: Icons.hourglass_bottom,
        color: Paleta.durazno,
        colorClaro: Paleta.duraznoClaro,
        turnos: p.pendientes,
        vacioIcono: Icons.assignment_outlined,
        vacioTitulo: 'Sin turnos pendientes',
        vacioTexto: 'Los turnos que lleguen aparecerán aquí.',
        item: (t) => _itemTurno(
          t,
          detalle: 'Creado ${_hora(t.creadoEn)}',
          colorNumero: Paleta.duraznoClaro,
          accion: _botonRedondo(
            Icons.campaign_outlined,
            'Llamar',
            Paleta.terracota,
            () => _accion(() => p.llamarTurno(t.id), 'Turno ${t.numero} llamado'),
          ),
        ),
      );

  /// Called column: shows who called each ticket and a button to mark it
  /// as served.
  Widget _columnaLlamados(TurnosProvider p) => _columna(
        titulo: 'Llamados',
        icono: Icons.call,
        color: Paleta.salvia,
        colorClaro: Paleta.salviaClaro,
        turnos: p.llamados,
        vacioIcono: Icons.campaign_outlined,
        vacioTitulo: 'Sin turnos llamados',
        vacioTexto: 'Aquí aparecerán los turnos que ya fueron llamados.',
        item: (t) => _itemTurno(
          t,
          detalle: 'Llamado ${_hora(t.llamadoEn)} · por ${t.funcionario ?? '-'}',
          colorNumero: Paleta.salviaClaro,
          accion: _botonRedondo(
            Icons.check,
            'Marcar atendido',
            Paleta.salvia,
            () => _accion(() => p.marcarAtendido(t.id), 'Turno ${t.numero} atendido'),
          ),
        ),
      );

  /// Served column: read-only history with created, called and served
  /// times.
  Widget _columnaAtendidos(TurnosProvider p) => _columna(
        titulo: 'Atendidos',
        icono: Icons.check,
        color: Paleta.terracota,
        colorClaro: Paleta.terracotaClaro,
        turnos: p.atendidos,
        vacioIcono: Icons.task_alt,
        vacioTitulo: 'Sin turnos atendidos',
        vacioTexto: 'El historial de atención aparecerá aquí.',
        item: (t) => _itemTurno(
          t,
          detalle: 'Creado ${_hora(t.creadoEn)} · Llamado ${_hora(t.llamadoEn)} · '
              'Atendido ${_hora(t.atendidoEn)} (${t.funcionario ?? '-'})',
          colorNumero: Paleta.terracotaClaro,
          accion: Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
                color: Paleta.fondo, shape: BoxShape.circle),
            child: const Icon(Icons.check, size: 18, color: Paleta.textoSuave),
          ),
        ),
      );

  /// Shared layout for the three columns.
  ///
  /// Renders a colored header with [titulo], [icono] and the ticket count,
  /// then either the list of [turnos] (each built with [item]) or an empty
  /// state with [vacioIcono], [vacioTitulo] and [vacioTexto].
  Widget _columna({
    required String titulo,
    required IconData icono,
    required Color color,
    required Color colorClaro,
    required List<Turno> turnos,
    required IconData vacioIcono,
    required String vacioTitulo,
    required String vacioTexto,
    required Widget Function(Turno) item,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Paleta.tarjeta,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Paleta.borde),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Column header
          Container(
            color: colorClaro,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color,
                  child: Icon(icono, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$titulo (${turnos.length})',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600, color: Paleta.texto),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${turnos.length}',
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Paleta.textoSuave),
              ],
            ),
          ),
          // Body: ticket list or empty state
          Expanded(
            child: turnos.isEmpty
                ? _estadoVacio(vacioIcono, vacioTitulo, vacioTexto, color, colorClaro)
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: turnos.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) => item(turnos[index]),
                  ),
          ),
        ],
      ),
    );
  }

  /// Placeholder shown when a column has no tickets.
  Widget _estadoVacio(
      IconData icono, String titulo, String texto, Color color, Color colorClaro) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(color: colorClaro, shape: BoxShape.circle),
              child: Icon(icono, size: 56, color: color),
            ),
            const SizedBox(height: 20),
            Text(
              titulo,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: Paleta.texto),
            ),
            const SizedBox(height: 6),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Paleta.textoSuave),
            ),
          ],
        ),
      ),
    );
  }

  /// Card for a single ticket: number badge, customer name, a [detalle]
  /// line and an [accion] widget on the right.
  Widget _itemTurno(
    Turno t, {
    required String detalle,
    required Color colorNumero,
    required Widget accion,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Paleta.borde.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colorNumero, shape: BoxShape.circle),
            child: Text(
              '${t.numero}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Paleta.texto),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.cliente,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15, color: Paleta.texto),
                ),
                const SizedBox(height: 2),
                Text(detalle,
                    style: const TextStyle(fontSize: 12, color: Paleta.textoSuave)),
              ],
            ),
          ),
          accion,
        ],
      ),
    );
  }

  /// Round icon button used for ticket actions.
  ///
  /// Disabled while another action is in progress (see [_procesando]).
  Widget _botonRedondo(
      IconData icono, String tooltip, Color color, VoidCallback onPressed) {
    return IconButton(
      onPressed: _procesando ? null : onPressed,
      tooltip: tooltip,
      icon: Icon(icono, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
      ),
    );
  }
}