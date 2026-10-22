import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/ui/ui.dart';

import 'ayudantes.dart';

const _secciones = [
  'Botones',
  'Barras',
  'Diálogo',
  'Opciones',
  'Ticket',
  'Cartas',
  'Sobre el fondo del juego',
  'Marco y HUD',
  'Transición',
];

/// Recorre la galería de arriba abajo: cada apartado se ve y nada se desborda.
Future<void> _recorrer(WidgetTester tester) async {
  for (final seccion in _secciones) {
    await tester.scrollUntilVisible(find.text(seccion), 300);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(seccion), findsOneWidget);
    expect(tester.takeException(), isNull, reason: seccion);
  }
}

void main() {
  for (final brillo in Brightness.values) {
    testWidgets('se ve entera en tema ${brillo.name}', (tester) async {
      await montar(tester, const GaleriaPixelUi(), brillo: brillo, centrar: false);
      expect(find.text('Kit pixel'), findsOneWidget);
      await _recorrer(tester);
      await desmontar(tester);
    });
  }

  testWidgets('con letra grande (1,3) en un móvil pequeño tampoco se desborda nada', (tester) async {
    await montar(tester, const GaleriaPixelUi(), centrar: false, escalaTexto: 1.3, tamano: const Size(320, 640));
    await _recorrer(tester);
    await desmontar(tester);
  });

  testWidgets('cada apartado es un encabezado para el lector de pantalla', (tester) async {
    await montar(tester, const GaleriaPixelUi(), centrar: false);
    expect(tester.getSemantics(find.text('Botones')), isSemantics(isHeader: true));
  });

  testWidgets('se puede jugar: barra, diálogo y opciones responden', (tester) async {
    await montar(tester, const GaleriaPixelUi(), centrar: false);
    await tester.tap(find.text('Más'));
    await tester.pump();
    expect(tester.getSemantics(find.bySemanticsLabel('Progreso del caso')), isSemantics(value: '5 de 10 escenas'));

    await tester.scrollUntilVisible(find.byType(DialogoPixel).first, 300);
    await tester.pump(const Duration(seconds: 5));
    await tester.tap(find.byType(DialogoPixel).first);
    await tester.pump();
    expect(find.text('Ana'), findsOneWidget, reason: 'la siguiente frase');

    await tester.scrollUntilVisible(find.text('Una multa'), 300);
    await tester.tap(find.text('Una multa'));
    await tester.pump();
    expect(find.text('Otra vez'), findsOneWidget);
    await tester.tap(find.text('Otra vez'));
    await tester.pump();
    expect(find.text('Otra vez'), findsNothing);
  });

  testWidgets('el HUD con los botones de la app deja sitio al título y a la barra', (tester) async {
    await montar(tester, const GaleriaPixelUi(), centrar: false);
    final hud = find.byKey(const ValueKey('hud con acciones'));
    await tester.scrollUntilVisible(hud, 400);
    await tester.ensureVisible(hud);
    await tester.pumpAndSettle();
    final titulo = find.descendant(of: hud, matching: find.text('El caso de Lucía'));
    final parrafo = tester.renderObject<RenderParagraph>(titulo);
    expect(parrafo.constraints.maxWidth, greaterThanOrEqualTo(HudPixel.anchoMinimoTitulo));
    final barra = tester.getSize(find.descendant(of: hud, matching: find.byType(BarraPixel)));
    expect(barra.width, greaterThanOrEqualTo(tester.getSize(hud).width * 0.5));
  });

  testWidgets('el botón de la transición abre la pantalla de juego y se vuelve con el HUD', (tester) async {
    await montar(tester, const GaleriaPixelUi(), centrar: false);
    await tester.scrollUntilVisible(find.text('Entrar en el juego'), 400);
    await tester.ensureVisible(find.text('Entrar en el juego'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entrar en el juego'));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(DuracionTransicionPixel.entrada ~/ 6);
      expect(tester.takeException(), isNull);
    }
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Que me acompañe mi tía'), findsOneWidget);
    await tester.tap(find.text('Que me acompañe mi tía'));
    await tester.pump();
    expect(find.bySemanticsLabel('Cartas conseguidas: 1 de 5'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Volver').last);
    await tester.pump();
    await tester.pump(DuracionTransicionPixel.salida);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Que me acompañe mi tía'), findsNothing);
    expect(find.text('Entrar en el juego'), findsOneWidget);
    await desmontar(tester);
  });
}
