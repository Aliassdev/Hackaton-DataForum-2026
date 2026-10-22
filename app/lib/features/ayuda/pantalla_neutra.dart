import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../tema.dart';

/// La pantalla neutra de la salida rápida (/salida): solo el color del papel y, abajo, un botón discreto para volver.
///
/// Sin barra, sin botón de Ayuda, sin logotipo y sin transición (lib/app.dart la abre sin animar): si alguien se
/// acerca, no ve nada de TuTurno. Es la pantalla en la que se queda la app al salir rápido, y la que se ve si se
/// vuelve a abrir. Es siempre del color del papel, también en el tema oscuro.
class PantallaNeutra extends StatelessWidget {
  const PantallaNeutra({super.key});

  /// Iconos oscuros en las barras del sistema, que se funden con el papel.
  static const _barrasSistema = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: ColoresMarca.papel,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  @override
  Widget build(BuildContext context) {
    // La tinta secundaria del tema claro: discreta, pero legible sobre el papel (7,7:1) en los dos temas.
    final tinta = esquemaTuTurno(Brightness.light).onSurfaceVariant;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _barrasSistema,
      child: Scaffold(
        backgroundColor: ColoresMarca.papel,
        body: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(Espacio.m),
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: tinta),
                onPressed: () => context.go('/'),
                child: const Text('Volver a TuTurno'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
