// Frontend tests. They do not need the backend running: the provider is used
// without calling cargarTurnos() or iniciarTiempoReal(), so no network
// requests are made.
//
// Run with:  flutter test

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:frontend/models/turno.dart';
import 'package:frontend/providers/turnos_provider.dart';
import 'package:frontend/screens/turnos_screen.dart';

/// Builds a test ticket with sensible defaults for the given [estado].
Turno turno({
  required int id,
  String estado = 'pendiente',
  String? atendidoEn,
}) {
  return Turno(
    id: id,
    numero: id,
    cliente: 'Cliente $id',
    estado: estado,
    funcionario: estado == 'pendiente' ? null : 'Ana',
    creadoEn: '2026-10-14 08:00:00',
    llamadoEn: estado == 'pendiente' ? null : '2026-10-14 08:05:00',
    atendidoEn: atendidoEn,
  );
}

void main() {
  group('Turno.fromJson', () {
    test('reads the backend column names', () {
      final t = Turno.fromJson({
        'id': 7,
        'numero': 3,
        'cliente': 'Ana Mora',
        'estado': 'llamado',
        'funcionario': 'Carlos',
        'creado_en': '2026-10-14 13:50:19',
        'llamado_en': '2026-10-14 13:52:03',
        'atendido_en': null,
      });

      expect(t.id, 7);
      expect(t.numero, 3);
      expect(t.funcionario, 'Carlos');
      expect(t.llamadoEn, '2026-10-14 13:52:03');
      expect(t.atendidoEn, isNull);
    });
  });

  group('TurnosProvider', () {
    test('splits tickets by state', () {
      final p = TurnosProvider();
      p.aplicarTurno(turno(id: 1));
      p.aplicarTurno(turno(id: 2, estado: 'llamado'));
      p.aplicarTurno(turno(id: 3, estado: 'atendido', atendidoEn: '2026-10-14 09:00:00'));

      expect(p.pendientes.map((t) => t.id), [1]);
      expect(p.llamados.map((t) => t.id), [2]);
      expect(p.atendidos.map((t) => t.id), [3]);
    });

    test('the same ticket is never duplicated', () {
      final p = TurnosProvider();
      p.aplicarTurno(turno(id: 1));
      p.aplicarTurno(turno(id: 1, estado: 'llamado'));

      expect(p.pendientes, isEmpty);
      expect(p.llamados.length, 1);
    });

    test('ignores a stale event that would move a ticket backwards', () {
      final p = TurnosProvider();
      p.aplicarTurno(turno(id: 1, estado: 'atendido', atendidoEn: '2026-10-14 09:00:00'));
      p.aplicarTurno(turno(id: 1, estado: 'llamado')); // arrives late

      expect(p.atendidos.length, 1);
      expect(p.llamados, isEmpty);
    });

    test('atendidos: most recently served first, even with a lower number', () {
      final p = TurnosProvider();
      p.aplicarTurno(turno(id: 5, estado: 'atendido', atendidoEn: '2026-10-14 09:00:00'));
      p.aplicarTurno(turno(id: 2, estado: 'atendido', atendidoEn: '2026-10-14 09:30:00'));
      p.aplicarTurno(turno(id: 8, estado: 'atendido', atendidoEn: '2026-10-14 08:45:00'));

      expect(p.atendidos.map((t) => t.numero), [2, 5, 8]);
    });
  });

  testWidgets('the screen shows the three columns with their tickets',
      (WidgetTester tester) async {
    // Desktop-sized window: the UI shows three columns side by side.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = TurnosProvider()
      ..aplicarTurno(turno(id: 1))
      ..aplicarTurno(turno(id: 2, estado: 'llamado'));

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => provider,
        child: const MaterialApp(home: TurnosScreen()),
      ),
    );

    expect(find.text('Gestión de turnos'), findsOneWidget);
    expect(find.text('Pendientes (1)'), findsOneWidget);
    expect(find.text('Llamados (1)'), findsOneWidget);
    expect(find.text('Atendidos (0)'), findsOneWidget);
    expect(find.text('Cliente 1'), findsOneWidget);
    expect(find.text('Sin turnos atendidos'), findsOneWidget);
  });
}
