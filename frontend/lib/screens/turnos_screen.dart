import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/turno.dart';
import '../providers/turnos_provider.dart';

class TurnosScreen extends StatefulWidget {
  const TurnosScreen({super.key});

  @override
  State<TurnosScreen> createState() => _TurnosScreenState();
}

class _TurnosScreenState extends State<TurnosScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clienteCtrl = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _clienteCtrl.dispose();
    super.dispose();
  }

  // "2026-10-14 13:50:19" -> "13:50"
  String _hora(String? fecha) =>
      (fecha == null || fecha.length < 16) ? '' : fecha.substring(11, 16);

  // Muestra un mensaje verde (éxito) o rojo (error)
  void _avisar(String? error, String exito) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? exito),
        backgroundColor: error == null ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _crearTurno() async {
    // Validación en el frontend (el backend valida otra vez)
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);
    final error =
        await context.read<TurnosProvider>().crearTurno(_clienteCtrl.text.trim());
    if (!mounted) return;
    setState(() => _enviando = false);

    if (error == null) _clienteCtrl.clear();
    _avisar(error, 'Turno creado');
  }

  // Para llamar o atender hace falta saber quién es el funcionario
  Future<void> _accion(Future<String?> Function() accion, String exito) async {
    if (context.read<TurnosProvider>().funcionario.isEmpty) {
      _avisar('Escribí tu nombre de funcionario primero', '');
      return;
    }
    final error = await accion();
    _avisar(error, exito);
  }

  @override
  Widget build(BuildContext context) {
    // watch: esta pantalla se redibuja cada vez que el provider llama notifyListeners()
    final p = context.watch<TurnosProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de turnos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: p.cargarTurnos,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _panelSuperior(p),
            const SizedBox(height: 12),
            if (p.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(p.error!, style: const TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: p.cargando
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _columnaPendientes(p)),
                        const SizedBox(width: 12),
                        Expanded(child: _columnaLlamados(p)),
                        const SizedBox(width: 12),
                        Expanded(child: _columnaAtendidos(p)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Parte de arriba: funcionario, formulario y "Llamar siguiente" ----------
  Widget _panelSuperior(TurnosProvider p) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 220,
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Funcionario',
              prefixIcon: Icon(Icons.badge),
              border: OutlineInputBorder(),
            ),
            onChanged: p.setFuncionario,
          ),
        ),
        Form(
          key: _formKey,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 260,
                child: TextFormField(
                  controller: _clienteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del cliente',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (valor) {
                    final texto = valor?.trim() ?? '';
                    if (texto.isEmpty) return 'Campo obligatorio';
                    if (texto.length < 2) return 'Mínimo 2 caracteres';
                    if (texto.length > 60) return 'Máximo 60 caracteres';
                    return null; // null = válido
                  },
                  onFieldSubmitted: (_) => _crearTurno(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _enviando ? null : _crearTurno,
                icon: const Icon(Icons.add),
                label: const Text('Crear turno'),
              ),
            ],
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: () => _accion(p.llamarSiguiente, 'Turno llamado'),
          icon: const Icon(Icons.campaign),
          label: const Text('Llamar siguiente'),
        ),
      ],
    );
  }

  // ---------- Columnas ----------
  Widget _columnaPendientes(TurnosProvider p) {
    return _columna(
      titulo: 'Pendientes',
      color: Colors.orange,
      turnos: p.pendientes,
      item: (t) => ListTile(
        leading: CircleAvatar(child: Text('${t.numero}')),
        title: Text(t.cliente),
        subtitle: Text('Creado: ${_hora(t.creadoEn)}'),
        trailing: TextButton(
          onPressed: () => _accion(() => p.llamarTurno(t.id), 'Turno ${t.numero} llamado'),
          child: const Text('Llamar'),
        ),
      ),
    );
  }

  Widget _columnaLlamados(TurnosProvider p) {
    return _columna(
      titulo: 'Llamados',
      color: Colors.blue,
      turnos: p.llamados,
      item: (t) => ListTile(
        leading: CircleAvatar(child: Text('${t.numero}')),
        title: Text(t.cliente),
        subtitle: Text('Por ${t.funcionario ?? '-'} a las ${_hora(t.llamadoEn)}'),
        trailing: TextButton(
          onPressed: () => _accion(() => p.marcarAtendido(t.id), 'Turno ${t.numero} atendido'),
          child: const Text('Atendido'),
        ),
      ),
    );
  }

  Widget _columnaAtendidos(TurnosProvider p) {
    return _columna(
      titulo: 'Atendidos',
      color: Colors.green,
      turnos: p.atendidos,
      item: (t) => ListTile(
        leading: CircleAvatar(child: Text('${t.numero}')),
        title: Text(t.cliente),
        subtitle: Text(
          'Creado ${_hora(t.creadoEn)} · Llamado ${_hora(t.llamadoEn)} · '
          'Atendido ${_hora(t.atendidoEn)} (${t.funcionario ?? '-'})',
        ),
      ),
    );
  }

  // Molde común para las tres columnas
  Widget _columna({
    required String titulo,
    required Color color,
    required List<Turno> turnos,
    required Widget Function(Turno) item,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: color.withValues(alpha: 0.15),
            padding: const EdgeInsets.all(12),
            child: Text(
              '$titulo (${turnos.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Expanded(
            child: turnos.isEmpty
                ? const Center(child: Text('Sin turnos'))
                : ListView.separated(
                    itemCount: turnos.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) => item(turnos[index]),
                  ),
          ),
        ],
      ),
    );
  }
}