/// Entry point of the ticket management (turnos) web app.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/turnos_provider.dart';
import 'screens/turnos_screen.dart';

/// Starts the app.
///
/// [TurnosProvider] wraps the whole widget tree so any screen can read the
/// tickets. As soon as it is created it loads the tickets from the backend
/// and opens the real-time WebSocket connection.
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => TurnosProvider()
        ..cargarTurnos()
        ..iniciarTiempoReal(),
      child: const MyApp(),
    ),
  );
}

/// Root widget: configures the Material theme and shows [TurnosScreen].
///
/// Expects a [TurnosProvider] above it in the widget tree.
class MyApp extends StatelessWidget {
  /// Creates the root widget.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestión de turnos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFE07A5F),
        scaffoldBackgroundColor: const Color(0xFFFAF6F1),
      ),
      home: const TurnosScreen(),
    );
  }
}
