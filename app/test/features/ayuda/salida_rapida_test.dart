import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tuturno/core/progreso.dart';
import 'package:tuturno/core/salida_rapida.dart';
import 'package:tuturno/core/voz/tts.dart';
import 'package:tuturno/features/ayuda/ayuda_screen.dart';
import 'package:tuturno/features/ayuda/pantalla_neutra.dart';
import 'package:tuturno/features/inicio/inicio_screen.dart';
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/ayuda_button.dart';
import 'package:tuturno/widgets/marca/marca.dart';
import 'package:tuturno/widgets/salida_rapida_button.dart';

import '../a1/helpers.dart';

// «Salir rápido» en Ayuda (plan v2, producto §5.3), con la plataforma y la voz falsas.

class _SalidaFalsa implements SalidaPlataforma {
  int salidas = 0;

  @override
  Future<void> salir() async => salidas++;
}

class _TtsFalso implements Tts {
  int paradas = 0;

  @override
  ValueListenable<bool> get hablando => ValueNotifier(false);

  @override
  Future<void> hablar(String texto, {double? velocidad}) async {}

  @override
  Future<void> parar() async => paradas++;
}

/// Mediodía en la península: el 017 abierto (así la pantalla no depende de la hora de los tests).
final _mediodia = DateTime.utc(2026, 10, 21, 10);

Future<GoRouter> _abrirAyuda(WidgetTester tester, {_SalidaFalsa? salida, _TtsFalso? tts}) async {
  final router = await arrancarApp(
    tester,
    overrides: [
      relojProvider.overrideWithValue(() => _mediodia),
      salidaPlataformaProvider.overrideWithValue(salida ?? _SalidaFalsa()),
      ttsProvider.overrideWithValue(tts ?? _TtsFalso()),
    ],
  );
  await irA(tester, router, '/ayuda');
  return router;
}

void main() {
  testWidgets('«Salir rápido» está en Ayuda justo debajo del 112, con su explicación, y se ve sin desplazar', (
    tester,
  ) async {
    await _abrirAyuda(tester);

    final boton = find.byType(SalidaRapidaButton);
    expect(boton, findsOneWidget);
    expect(find.text(explicacionSalidaRapida), findsOneWidget);
    expect(
      explicacionSalidaRapida,
      '¿Alguien se acerca y prefieres que no vea la pantalla? Pulsa «Salir rápido». TuTurno se cierra al momento y la '
      'conversación de Pregunta desaparece de la pantalla.',
    );
    // Sin prometer un borrado que no depende del móvil (auditoría P1-4).
    expect(explicacionSalidaRapida, isNot(contains('se borra')));
    // Debajo del 112 y antes de todos los demás recursos.
    final y112 = tester.getTopLeft(find.text('Llamar al 112')).dy;
    final ySalir = tester.getTopLeft(boton).dy;
    expect(ySalir, greaterThan(y112));
    expect(ySalir, lessThan(tester.getTopLeft(find.text('Teléfonos y webs que te ayudan')).dy));
    // En la primera pantalla de un móvil normal, sin buscarlo.
    expect(tester.getBottomLeft(boton).dy, lessThan(movil.height));
    // A todo el ancho del panel: imposible no verlo.
    expect(tester.getSize(boton).width, greaterThan(movil.width * 0.8));
  });

  for (final brillo in Brightness.values) {
    testWidgets('no es rojo y se lee «Salir rápido. Cierra TuTurno al momento.» (${brillo.name})', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brillo;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final semantica = tester.ensureSemantics();
      await _abrirAyuda(tester);

      final contexto = tester.element(find.byType(SalidaRapidaButton));
      final boton = tester.widget<FilledButton>(
        find.descendant(
          of: find.byType(SalidaRapidaButton),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      final fondo = boton.style!.backgroundColor!.resolve({})!;
      for (final rojo in [contexto.colores.ayuda, Theme.of(contexto).colorScheme.error, ColoresMarca.rojoAyuda]) {
        expect(fondo, isNot(rojo));
      }
      expect(
        tester.getSemantics(find.byType(SalidaRapidaButton)),
        isSemantics(label: etiquetaSalidaRapida, isButton: true, hasTapAction: true),
      );
      expect(tester.getSize(find.byType(SalidaRapidaButton)).height, greaterThanOrEqualTo(48));
      semantica.dispose();
    });
  }

  testWidgets('el consejo de la ventana de incógnito solo sale en la web', (tester) async {
    await _abrirAyuda(tester);
    // Los tests no son la web.
    expect(find.text(avisoIncognitoWeb), findsNothing);
    expect(avisoIncognitoWeb, 'Si usas un móvil o un ordenador compartido, abre TuTurno en una ventana de incógnito.');

    await tester.pumpWidget(
      MaterialApp(
        theme: temaTuTurno(Brightness.light),
        home: const Scaffold(body: SingleChildScrollView(child: PanelSalidaRapida(web: true))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(avisoIncognitoWeb), findsOneWidget);
    expect(find.text(explicacionSalidaRapida), findsOneWidget);
    // Debajo de la explicación.
    expect(
      tester.getTopLeft(find.text(avisoIncognitoWeb)).dy,
      greaterThan(tester.getTopLeft(find.text(explicacionSalidaRapida)).dy),
    );
  });

  testWidgets('al pulsarlo: para la voz, pasa a la pantalla neutra y sale; «Volver a TuTurno» lleva al inicio', (
    tester,
  ) async {
    final salida = _SalidaFalsa();
    final tts = _TtsFalso();
    final router = await _abrirAyuda(tester, salida: salida, tts: tts);

    await tester.tap(find.byType(SalidaRapidaButton));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, rutaSalida);
    expect(tts.paradas, 1);
    expect(salida.salidas, 1);

    // La pantalla neutra: sin barra, sin Ayuda, sin Glosario y sin logotipo; solo el papel y el botón para volver.
    expect(find.byType(PantallaNeutra), findsOneWidget);
    expect(find.byType(AyudaScreen), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(AyudaButton), findsNothing);
    expect(find.byType(GlosarioButton), findsNothing);
    expect(find.byType(LogoTuTurno), findsNothing);
    expect(find.byType(MonogramaTut), findsNothing);
    expect(find.byType(Text), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Volver a TuTurno'));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/');
    expect(find.byType(InicioScreen), findsOneWidget);
    // «atrás» no vuelve a Ayuda: la pila de pantallas se ha cerrado.
    expect(router.canPop(), isFalse);
  });
}
