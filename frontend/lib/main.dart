import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/turnos_provider.dart';
import 'screens/turnos_screen.dart';

void main() {
  runApp(
    // El provider envuelve toda la app: cualquier pantalla puede leer los turnos.
    // "..cargarTurnos()" pide los turnos al backend apenas arranca.
    ChangeNotifierProvider(
      create: (_) => TurnosProvider()..cargarTurnos(),
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
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const TurnosScreen(),
    );
  }
}