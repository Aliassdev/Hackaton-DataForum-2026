import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/tema.dart';

/// Monta [hijo] con el tema de TuTurno. Con [sinAnimaciones], como un móvil con «reducir animaciones».
Future<void> montar(
  WidgetTester tester,
  Widget hijo, {
  Brightness brillo = Brightness.light,
  bool sinAnimaciones = false,
  double letra = 1,
  bool desplazable = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: temaTuTurno(brillo),
      // Sin transición entre temas: cada montaje se ve ya con su brillo.
      themeAnimationDuration: Duration.zero,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: sinAnimaciones, textScaler: TextScaler.linear(letra)),
        child: child!,
      ),
      home: Scaffold(body: desplazable ? hijo : Center(child: hijo)),
    ),
  );
}

/// Contraste WCAG entre dos colores opacos.
double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (claro, oscuro) = la > lb ? (la, lb) : (lb, la);
  return (claro + 0.05) / (oscuro + 0.05);
}
