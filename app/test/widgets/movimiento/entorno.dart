import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/tema.dart';

/// Un tema por brillo, siempre el mismo objeto: si cambiara, MaterialApp animaría el cambio de tema.
final _temas = {for (final brillo in Brightness.values) brillo: temaTuTurno(brillo)};

/// Monta [child] con el tema de TuTurno, centrado en una pantalla. Con [reducir], como si el sistema pidiera reducir
/// animaciones; [escalaTexto] simula el tamaño de letra del sistema y de Ajustes.
Future<void> montar(
  WidgetTester tester,
  Widget child, {
  bool reducir = false,
  Brightness brillo = Brightness.light,
  double escalaTexto = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: _temas[brillo],
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducir, textScaler: TextScaler.linear(escalaTexto)),
        child: app!,
      ),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  // MaterialApp pide un fotograma más al arrancar; con este, lo único que puede quedar pendiente es nuestro.
  await tester.pump();
}

/// Apunta las vibraciones que se piden a la plataforma («HapticFeedbackType.heavyImpact»…).
List<String> registrarVibraciones(WidgetTester tester) {
  final vibraciones = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (llamada) async {
    if (llamada.method == 'HapticFeedback.vibrate') vibraciones.add(llamada.arguments as String);
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return vibraciones;
}

/// Quita el widget a mitad de lo que esté haciendo: no debe quedar nada vivo (controladores, temporizadores).
Future<void> desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  expect(tester.takeException(), isNull);
  expect(tester.binding.hasScheduledFrame, isFalse);
}

/// La primera transformación dentro de [de] (la del propio widget de movimiento).
Matrix4 transformacionDe(WidgetTester tester, Finder de) =>
    tester.widget<Transform>(find.descendant(of: de, matching: find.byType(Transform)).first).transform;

/// La primera opacidad dentro de [de].
double opacidadDe(WidgetTester tester, Finder de) =>
    tester.widget<Opacity>(find.descendant(of: de, matching: find.byType(Opacity)).first).opacity;
