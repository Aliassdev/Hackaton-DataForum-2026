import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/mis_preguntas.dart';
import 'package:tuturno/features/mis_preguntas/ensenar_screen.dart';
import 'package:tuturno/features/mis_preguntas/mis_preguntas_screen.dart';
import 'package:tuturno/features/mis_preguntas/textos.dart';
import 'package:tuturno/tema.dart';

import '../situacion/ayudantes.dart';

// «Enseñar en grande» (plan v2, producto §5.2): un apunte por página, en letra muy grande y con mucho contraste, con
// «Anterior», «Ya lo he preguntado», «Siguiente» y «Cerrar». Con «reducir animaciones», sin moverse.

Map<String, Object> _tres() => {
  MisPreguntasNotifier.clave: jsonEncode([
    {'id': 'a', 'texto': '¿Puedo hacer un descanso?', 'tipo': 'preguntar'},
    {'id': 'b', 'texto': 'Un descanso si lo necesitas', 'tipo': 'pedir', 'origen': 'Tu declaración'},
    {'id': 'c', 'texto': '¿Quién estará en la sala?', 'tipo': 'preguntar'},
  ]),
};

Future<void> _abrirEnsenar(WidgetTester tester, {Map<String, Object>? preferencias, Brightness? brillo}) async {
  if (brillo != null) {
    tester.platformDispatcher.platformBrightnessTestValue = brillo;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  }
  final router = await arrancarSituacion(tester, preferencias: preferencias ?? _tres());
  await abrir(tester, router, '/mis-preguntas');
  await abrir(tester, router, '/mis-preguntas/ensenar');
}

void main() {
  testWidgets('un apunte por página: primero lo que quieres pedir, con su etiqueta; pasa de página', (tester) async {
    await _abrirEnsenar(tester);

    expect(find.text('1 de 3'), findsOneWidget);
    expect(find.text(etiquetaPedir), findsOneWidget);
    expect(find.text('Un descanso si lo necesitas'), findsOneWidget);
    final anterior = find.widgetWithText(OutlinedButton, botonAnterior);
    expect(tester.widget<OutlinedButton>(anterior).onPressed, isNull);

    await tester.tap(find.text(botonSiguiente));
    await tester.pumpAndSettle();
    expect(find.text('2 de 3'), findsOneWidget);
    expect(find.text(etiquetaPreguntar), findsOneWidget);
    expect(find.text('¿Puedo hacer un descanso?'), findsOneWidget);

    await tester.tap(find.text(botonSiguiente));
    await tester.pumpAndSettle();
    expect(find.text('3 de 3'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, botonSiguiente)).onPressed, isNull);

    await tester.tap(anterior);
    await tester.pumpAndSettle();
    expect(find.text('2 de 3'), findsOneWidget);
  });

  testWidgets('la letra es muy grande y con mucho contraste (azul noche sobre papel; al revés en oscuro)', (
    tester,
  ) async {
    await _abrirEnsenar(tester);
    final texto = tester.widget<Text>(find.text('Un descanso si lo necesitas'));
    expect(texto.style!.fontSize, greaterThanOrEqualTo(34));
    expect(texto.style!.color, ColoresMarca.azulNoche);
    expect(tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor, ColoresMarca.papel);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('en oscuro, papel sobre azul noche', (tester) async {
    await _abrirEnsenar(tester, brillo: Brightness.dark);
    final texto = tester.widget<Text>(find.text('Un descanso si lo necesitas'));
    expect(texto.style!.color, ColoresMarca.papel);
    expect(tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor, ColoresMarca.azulNoche);
  });

  testWidgets('«Ya lo he preguntado» se marca en el apunte que se enseña (y se desmarca)', (tester) async {
    await _abrirEnsenar(tester);
    await tester.tap(find.text(textoYaPreguntado));
    await tester.pumpAndSettle();
    final apuntes = contenedor(tester).read(misPreguntasProvider);
    expect(apuntes.firstWhere((a) => a.id == 'b').hecho, isTrue);
    expect(find.text('✓ $textoYaPreguntado'), findsOneWidget);
    // El orden no cambia al marcar.
    expect(find.text('1 de 3'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, textoYaPreguntado));
    await tester.pumpAndSettle();
    expect(contenedor(tester).read(misPreguntasProvider).firstWhere((a) => a.id == 'b').hecho, isFalse);
  });

  testWidgets('«Cerrar» vuelve a Mis preguntas', (tester) async {
    await _abrirEnsenar(tester);
    await tester.tap(find.text(botonCerrar));
    await tester.pumpAndSettle();
    expect(find.byType(EnsenarScreen), findsNothing);
    expect(find.byType(MisPreguntasScreen), findsOneWidget);
  });

  testWidgets('con «reducir animaciones», la página cambia sin moverse', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _abrirEnsenar(tester);
    await tester.tap(find.text(botonSiguiente));
    await tester.pump();
    expect(find.text('2 de 3'), findsOneWidget);
    // Ya está en la página 2 en el primer fotograma (solo se anima la onda del toque).
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1.0);
  });

  testWidgets('sin nada apuntado lo dice y deja cerrar', (tester) async {
    await _abrirEnsenar(tester, preferencias: const {});
    expect(find.text(vacioEnsenar), findsOneWidget);
    expect(find.text(botonCerrar), findsOneWidget);
    expect(find.text(botonSiguiente), findsNothing);
  });

  testWidgets('el lector de pantalla lee cada página como una frase y cumple las pautas', (tester) async {
    final semantica = tester.ensureSemantics();
    await _abrirEnsenar(tester);
    expect(find.bySemanticsLabel('$etiquetaPedir. Un descanso si lo necesitas'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantica.dispose();
  });

  testWidgets('con letra a 1,3 en un móvil pequeño, un apunte largo se desplaza y nada se desborda', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final router = await arrancarSituacion(
      tester,
      tamano: const Size(360, 640),
      preferencias: {
        MisPreguntasNotifier.clave: jsonEncode([
          {'id': 'x', 'texto': 'Una pregunta muy larga ' * 8, 'tipo': 'preguntar'},
        ]),
      },
    );
    await abrir(tester, router, '/mis-preguntas/ensenar');
    expect(tester.takeException(), isNull);
  });
}
