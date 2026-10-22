import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/voz/tts.dart';
import 'package:tuturno/features/glosario/glosario_screen.dart';
import 'package:tuturno/features/glosario/terminos_por_caso.dart';
import 'package:tuturno/features/juego/juego_providers.dart';
import 'package:tuturno/widgets/movimiento/contador_flip.dart';

import '../a1/helpers.dart';
import 'ayudantes.dart';

// Chips de caso del glosario (plan v2, producto §5.7), con el glosario de ejemplo (42 palabras) y los tres casos
// oficiales de assets/mock/content.

Finder _chip(String texto) => find.widgetWithText(ChoiceChip, texto);

bool _elegido(WidgetTester tester, String texto) => tester.widget<ChoiceChip>(_chip(texto)).selected;

int _recuento(WidgetTester tester) => tester.widget<ContadorFlip>(find.byType(ContadorFlip)).valor;

/// Desplaza la lista de palabras hasta que se ve [texto].
Future<void> _verEnLaLista(WidgetTester tester, String texto) => tester.scrollUntilVisible(
  find.text(texto),
  200,
  scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)),
);

void main() {
  final casos = casosDeEjemplo();
  final glosario = glosarioDeEjemploJson();
  final deSara = filtrosDeCaso(glosarioDeEjemplo(), casos).singleWhere((f) => f.protagonista == 'Sara').terminos;

  Future<void> abrir(WidgetTester tester, {TtsFalso? tts, Size tamano = movil}) async {
    final router = await arrancarApp(
      tester,
      glosario: glosario,
      tamano: tamano,
      overrides: [
        casosProvider.overrideWith((ref) async => casos),
        if (tts != null) ttsProvider.overrideWithValue(tts),
      ],
    );
    await irA(tester, router, '/glosario');
  }

  testWidgets('hay un chip por caso: Lucía, Sergio y Sara, después de «Todas» y «Mis palabras»', (tester) async {
    final semantica = tester.ensureSemantics();
    await abrir(tester);

    expect(_recuento(tester), 42);
    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
    expect([for (final c in chips) (c.label as Text).data], ['Todas', 'Mis palabras (0)', 'Lucía', 'Sergio', 'Sara']);
    expect(_elegido(tester, 'Todas'), isTrue);
    for (final nombre in ['Lucía', 'Sergio', 'Sara']) {
      expect(find.bySemanticsLabel('Palabras del caso de $nombre'), findsOneWidget, reason: nombre);
    }
    semantica.dispose();
  });

  testWidgets('el chip de Sara deja sus palabras, se combina con la búsqueda y lleva a todas si no está', (
    tester,
  ) async {
    await abrir(tester);

    await tester.tap(_chip('Sara'));
    await tester.pumpAndSettle();
    expect(_elegido(tester, 'Sara'), isTrue);
    expect(_elegido(tester, 'Todas'), isFalse);
    expect(_recuento(tester), deSara.length);
    await _verEnLaLista(tester, 'Canal prioritario');
    expect(find.text('Canal prioritario'), findsOneWidget);

    // Fiscalía, Fiscalía de Menores y Denuncia (que habla de la Fiscalía) salen en el caso de Sara.
    await tester.enterText(find.byType(TextField), 'fiscalia');
    await tester.pumpAndSettle();
    final palabrasDeSara = glosarioDeEjemplo().where((e) => deSara.contains(e.id)).toList();
    expect(_recuento(tester), filtrarGlosario(palabrasDeSara, 'fiscalia').length);
    expect(_recuento(tester), 3);

    // La Sala Gesell es del caso de Lucía: no sale con Sara, pero sí está en el glosario.
    await tester.enterText(find.byType(TextField), 'gesell');
    await tester.pumpAndSettle();
    expect(find.text('No sale en el caso de Sara'), findsOneWidget);
    expect(find.text('Pero en el glosario sí hay palabras con «gesell».'), findsOneWidget);
    await tester.tap(find.text('Buscar en todas'));
    await tester.pumpAndSettle();
    expect(_elegido(tester, 'Todas'), isTrue);
    expect(find.text('Sala Gesell'), findsOneWidget);

    // Lo que no está en ningún sitio: el aviso de siempre, con «Pregúntalo».
    await tester.tap(_chip('Sara'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pumpAndSettle();
    expect(find.text('Aún no tengo «xyz» en el glosario'), findsOneWidget);
    expect(find.text('Pregúntalo'), findsOneWidget);
  });

  testWidgets('el momento de la demo: «Sara» → «Canal prioritario» → «Escuchar»', (tester) async {
    final tts = TtsFalso();
    await abrir(tester, tts: tts);

    await tester.tap(_chip('Sara'));
    await tester.pumpAndSettle();
    await _verEnLaLista(tester, 'Canal prioritario');
    await tester.tap(find.text('Canal prioritario'));
    await tester.pumpAndSettle();
    await pulsar(tester, find.text('Escuchar'));
    expect(tts.leidos.single, startsWith('Canal prioritario.'));
    expect(tts.leidos.single, contains('no para WhatsApp'));
  });

  testWidgets('si los casos no cargan, el glosario funciona sin chips de caso', (tester) async {
    final router = await arrancarApp(
      tester,
      glosario: glosario,
      overrides: [casosProvider.overrideWith((ref) async => throw Exception('sin casos'))],
    );
    await irA(tester, router, '/glosario');
    expect(tester.takeException(), isNull);
    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
    expect([for (final c in chips) (c.label as Text).data], ['Todas', 'Mis palabras (0)']);
    expect(_recuento(tester), 42);
  });

  for (final brillo in Brightness.values) {
    testWidgets('chips con contraste y zonas táctiles de 48 en tema ${brillo.name}, con uno elegido', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brillo;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final semantica = tester.ensureSemantics();
      await abrir(tester);
      await tester.tap(_chip('Sergio'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantica.dispose();
    });
  }

  testWidgets('con letra grande en un móvil pequeño, los chips pasan a otra línea y se ven todos', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await abrir(tester, tamano: const Size(360, 640));
    expect(tester.takeException(), isNull);
    for (final texto in ['Todas', 'Mis palabras (0)', 'Lucía', 'Sergio', 'Sara']) {
      final caja = tester.getRect(_chip(texto));
      expect(caja.left, greaterThanOrEqualTo(0), reason: texto);
      expect(caja.right, lessThanOrEqualTo(360), reason: texto);
    }
    await tester.tap(_chip('Sara'));
    await tester.pumpAndSettle();
    expect(_elegido(tester, 'Sara'), isTrue);
    expect(tester.takeException(), isNull);
  });
}
