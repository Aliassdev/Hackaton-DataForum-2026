import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/features/ajustes/ajustes_screen.dart';
import 'package:tuturno/tema.dart';

import 'ayudas_ajustes.dart';

// Ajustes → «Leer mejor» (plan v2, producto §5.8): el tamaño de la letra, «Lectura fácil» con «Así se verá»,
// «Reducir animaciones» y la voz, juntos. Lo que se cambia se guarda y se nota en la app al momento.

Finder _interruptor(String titulo) => find.widgetWithText(SwitchListTile, titulo);

SwitchListTile _estado(WidgetTester tester, String titulo) => tester.widget<SwitchListTile>(_interruptor(titulo));

void main() {
  testWidgets('«Leer mejor» junta la letra, la lectura fácil, las animaciones y la voz', (tester) async {
    final router = await arrancarAjustes(tester);
    await abrir(tester, router, '/ajustes');

    expect(find.text('Leer mejor'), findsOneWidget);
    expect(find.text('Tamaño de la letra'), findsOneWidget);
    expect(_interruptor('Lectura fácil'), findsOneWidget);
    expect(find.text(textoLecturaFacil), findsOneWidget);
    expect(find.text('Así se verá'), findsOneWidget);
    expect(_interruptor('Reducir animaciones'), findsOneWidget);
    expect(find.text(textoReducirAnimaciones), findsOneWidget);
    expect(find.text('Voz'), findsOneWidget);
    expect(_interruptor('Leer las respuestas en voz alta'), findsOneWidget);
    // Por defecto, apagados y sin la nota del sistema.
    expect(_estado(tester, 'Lectura fácil').value, isFalse);
    expect(_estado(tester, 'Reducir animaciones').value, isFalse);
    expect(find.text(notaAnimacionesDelSistema), findsNothing);
  });

  testWidgets('«Lectura fácil» se guarda y toda la app pasa a Atkinson al momento', (tester) async {
    final router = await arrancarAjustes(tester);
    await abrir(tester, router, '/ajustes');
    final prefs = await SharedPreferences.getInstance();
    String? familia() => Theme.of(tester.element(find.text('Así se verá'))).textTheme.bodyLarge?.fontFamily;

    expect(familia(), Fuentes.texto);
    await tocar(tester, _interruptor('Lectura fácil'));
    expect(prefs.getBool('ajustes.lectura_facil'), isTrue);
    expect(_estado(tester, 'Lectura fácil').value, isTrue);
    expect(familia(), Fuentes.lecturaFacil);
    // También los títulos (sin MaryKate).
    final titulo = Theme.of(tester.element(find.text('Leer mejor'))).textTheme.headlineSmall;
    expect(titulo?.fontFamily, Fuentes.lecturaFacil);

    await tocar(tester, _interruptor('Lectura fácil'));
    expect(prefs.getBool('ajustes.lectura_facil'), isFalse);
    expect(familia(), Fuentes.texto);
    expect(tester.takeException(), isNull);
  });

  testWidgets('«Reducir animaciones» se guarda y deja quieta toda la app al momento', (tester) async {
    final router = await arrancarAjustes(tester);
    await abrir(tester, router, '/ajustes');
    final prefs = await SharedPreferences.getInstance();
    bool quieta() => MediaQuery.disableAnimationsOf(tester.element(find.text('Así se verá')));

    expect(quieta(), isFalse);
    await tocar(tester, _interruptor('Reducir animaciones'));
    expect(prefs.getBool('ajustes.reducir_movimiento'), isTrue);
    expect(_estado(tester, 'Reducir animaciones').value, isTrue);
    expect(quieta(), isTrue);
    expect(duracion(tester.element(find.text('Así se verá')), Duracion.larga), Duration.zero);

    // En otra pantalla también.
    await abrir(tester, router, '/glosario');
    expect(MediaQuery.disableAnimationsOf(tester.element(find.text('Glosario').first)), isTrue);
    router.pop();
    await tester.pumpAndSettle();

    await tocar(tester, _interruptor('Reducir animaciones'));
    expect(prefs.getBool('ajustes.reducir_movimiento'), isFalse);
    expect(quieta(), isFalse);
  });

  testWidgets('lo guardado se recupera al volver a abrir la app', (tester) async {
    final router = await arrancarAjustes(
      tester,
      preferencias: {'ajustes.lectura_facil': true, 'ajustes.reducir_movimiento': true, 'ajustes.tamano_texto': 1.15},
    );
    await abrir(tester, router, '/ajustes');

    expect(_estado(tester, 'Lectura fácil').value, isTrue);
    expect(_estado(tester, 'Reducir animaciones').value, isTrue);
    expect(_estado(tester, 'Reducir animaciones').onChanged, isNotNull);
    expect(tester.widget<SegmentedButton<double>>(find.byType(SegmentedButton<double>)).selected, {1.15});
    expect(Theme.of(tester.element(find.text('Así se verá'))).textTheme.bodyLarge?.fontFamily, Fuentes.lecturaFacil);
  });

  testWidgets('si el móvil ya reduce las animaciones, el interruptor sale encendido, desactivado y con la nota', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final router = await arrancarAjustes(tester);
    await abrir(tester, router, '/ajustes');

    final interruptor = _estado(tester, 'Reducir animaciones');
    expect(interruptor.value, isTrue);
    expect(interruptor.onChanged, isNull);
    expect(find.text(notaAnimacionesDelSistema), findsOneWidget);
    // No se guarda nada: es del sistema.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('ajustes.reducir_movimiento'), isNot(isTrue));
  });

  testWidgets('con el del móvil y el de la app encendidos, se puede apagar el de la app', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final router = await arrancarAjustes(tester, preferencias: {'ajustes.reducir_movimiento': true});
    await abrir(tester, router, '/ajustes');

    expect(_estado(tester, 'Reducir animaciones').onChanged, isNotNull);
    await tocar(tester, _interruptor('Reducir animaciones'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('ajustes.reducir_movimiento'), isFalse);
    // Queda el del sistema: encendido, desactivado y con la nota.
    expect(_estado(tester, 'Reducir animaciones').value, isTrue);
    expect(_estado(tester, 'Reducir animaciones').onChanged, isNull);
    expect(find.text(notaAnimacionesDelSistema), findsOneWidget);
  });

  testWidgets('con letra grande en un móvil pequeño, «Leer mejor» cabe', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final router = await arrancarAjustes(
      tester,
      preferencias: {'ajustes.tamano_texto': 1.3, 'ajustes.lectura_facil': true},
      tamano: const Size(360, 640),
    );
    await abrir(tester, router, '/ajustes');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
