import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/turnos_provider.dart';
import 'screens/turnos_screen.dart';

void main() {
  runApp(
    // El provider envuelve toda la app: cualquier pantalla puede leer los turnos.
    // "..cargarTurnos()" pide los turnos al backend apenas arranca.
    ChangeNotifierProvider(
      create: (_) => TurnosProvider()
        ..cargarTurnos()
        ..iniciarTiempoReal(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
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
