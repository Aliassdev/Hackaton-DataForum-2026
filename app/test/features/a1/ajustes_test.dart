import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/voz/tts.dart';
import 'package:tuturno/features/ajustes/ajustes_screen.dart';
import 'package:tuturno/widgets/iconos/iconos.dart';
import 'package:tuturno/widgets/marca/marca.dart';

import '../ajustes/ayudas_ajustes.dart' show revelarEquipo;
import '../pregunta/fakes.dart' show FakeTts;
import 'helpers.dart';

/// El servidor está en «Para el equipo (demo)», que solo sale tras la pulsación larga en el pie (auditoría P1-6).
const _servidor = 'Servidor (API_URL)';

void main() {
  group('Ajustes', () {
    testWidgets('el tamaño de letra se guarda y se aplica al momento', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/ajustes');

      final antes = MediaQuery.textScalerOf(tester.element(find.text('Así se verá'))).scale(1);
      await tester.tap(find.text('Grande'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('ajustes.tamano_texto'), 1.15);
      final despues = MediaQuery.textScalerOf(tester.element(find.text('Así se verá'))).scale(1);
      expect(despues, closeTo(antes * 1.15, 0.001));

      await tester.tap(find.text('Enorme'));
      await tester.pumpAndSettle();
      expect(prefs.getDouble('ajustes.tamano_texto'), 1.3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la voz se puede apagar y cambiar de velocidad', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/ajustes');

      await pulsar(tester, find.text('Leer las respuestas en voz alta'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('ajustes.voz_activada'), isFalse);

      await tester.ensureVisible(find.byType(Slider));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Slider), const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(prefs.getDouble('ajustes.velocidad_voz'), closeTo(0.7, 0.0001));

      await tester.drag(find.byType(Slider), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(prefs.getDouble('ajustes.velocidad_voz'), closeTo(0.3, 0.0001));
      expect(find.text('Más lenta'), findsOneWidget);
      expect(find.text('Más rápida'), findsOneWidget);
    });

    testWidgets('el servidor solo acepta http(s), se guarda y se puede volver al de serie', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/ajustes');
      final prefs = await SharedPreferences.getInstance();

      expect(find.text(_servidor), findsNothing);
      await revelarEquipo(tester);
      expect(find.text('sin configurar'), findsOneWidget);
      await pulsar(tester, find.text(_servidor));
      // Con USE_MOCK se explica que las respuestas son simuladas.
      expect(find.textContaining('las respuestas son simuladas'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ftp://servidor.es');
      await pulsar(tester, find.text('Usar este servidor'));
      expect(find.text('Escribe una dirección que empiece por http:// o https://'), findsOneWidget);
      expect(prefs.getString('ajustes.api_url'), isNull);

      await tester.enterText(find.byType(TextField), '  https://demo.tuturno.dev  ');
      await pulsar(tester, find.text('Usar este servidor'));
      expect(prefs.getString('ajustes.api_url'), 'https://demo.tuturno.dev');
      expect(find.text('Escribe una dirección que empiece por http:// o https://'), findsNothing);
      // El valor actual se ve en el título de la sección.
      expect(
        find.descendant(of: find.byType(ListTile), matching: find.text('https://demo.tuturno.dev')),
        findsOneWidget,
      );

      await pulsar(tester, find.text('Volver al de serie'));
      expect(prefs.getString('ajustes.api_url'), isNull);
      expect(find.text('sin configurar'), findsOneWidget);
    });

    testWidgets('«Probar la voz» lee una frase con la velocidad elegida', (tester) async {
      final tts = FakeTts();
      final router = await arrancarApp(
        tester,
        preferencias: {'ajustes.velocidad_voz': 0.6},
        overrides: [ttsProvider.overrideWithValue(tts)],
      );
      await irA(tester, router, '/ajustes');

      await pulsar(tester, find.text('Probar la voz'));
      expect(tts.leidos, [fraseProbarVoz]);
      expect(tts.velocidades, [0.6]);
    });

    testWidgets('el deslizador de velocidad dice qué controla (TalkBack)', (tester) async {
      final semantica = tester.ensureSemantics();
      final router = await arrancarApp(tester);
      await irA(tester, router, '/ajustes');
      expect(find.bySemanticsLabel(RegExp('Velocidad de la voz')), findsWidgets);
      semantica.dispose();
    });

    testWidgets('«Probar la conexión» dice si el servidor responde', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/ajustes');
      await revelarEquipo(tester);
      await pulsar(tester, find.text(_servidor));

      await pulsar(tester, find.text('Probar la conexión'));
      expect(find.text('Conectado: el servidor responde (respuestas simuladas).'), findsOneWidget);
    });

    testWidgets('sin mock y sin dirección, «Probar la conexión» explica qué falta', (tester) async {
      final router = await arrancarApp(tester, useMock: false);
      await irA(tester, router, '/ajustes');
      await revelarEquipo(tester);
      await pulsar(tester, find.text(_servidor));

      await pulsar(tester, find.text('Probar la conexión'));
      expect(find.text(pistaConexion('SIN_API_URL')), findsOneWidget);
    });

    testWidgets('sin mock no sale el aviso de respuestas simuladas', (tester) async {
      final router = await arrancarApp(tester, useMock: false);
      await irA(tester, router, '/ajustes');
      await revelarEquipo(tester);
      await pulsar(tester, find.text(_servidor));
      expect(find.textContaining('las respuestas son simuladas'), findsNothing);
    });

    testWidgets('lo guardado se recupera al volver a abrir', (tester) async {
      final router = await arrancarApp(
        tester,
        preferencias: {
          'ajustes.tamano_texto': 1.3,
          'ajustes.voz_activada': false,
          'ajustes.velocidad_voz': 0.6,
          'ajustes.api_url': 'https://otra.dev',
        },
      );
      await irA(tester, router, '/ajustes');

      final segmentos = tester.widget<SegmentedButton<double>>(find.byType(SegmentedButton<double>));
      expect(segmentos.selected, {1.3});
      final voz = find.widgetWithText(SwitchListTile, 'Leer las respuestas en voz alta');
      expect(tester.widget<SwitchListTile>(voz).value, isFalse);
      expect(tester.widget<Slider>(find.byType(Slider)).value, closeTo(0.6, 0.0001));
      expect(find.text(textoPieAjustes, skipOffstage: false), findsOneWidget);
      // La dirección puesta a mano se ve en «Para el equipo (demo)».
      await revelarEquipo(tester);
      expect(find.text('https://otra.dev'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Validación y nombres', () {
    test('esUrlServidorValida', () {
      expect(esUrlServidorValida('https://a.b'), isTrue);
      expect(esUrlServidorValida('http://192.168.1.10:8000'), isTrue);
      expect(esUrlServidorValida(' https://x.trycloudflare.com '), isTrue);
      expect(esUrlServidorValida('ftp://a.b'), isFalse);
      expect(esUrlServidorValida('a.b'), isFalse);
      expect(esUrlServidorValida('https://'), isFalse);
      expect(esUrlServidorValida(''), isFalse);
    });

    test('soloHttps: la APK release y la web por https no pueden usar http://', () {
      expect(soloHttps(release: true, web: false), isTrue);
      expect(soloHttps(release: true, web: true, esquemaPagina: 'https'), isTrue);
      expect(soloHttps(release: true, web: true, esquemaPagina: 'http'), isFalse);
      expect(soloHttps(release: false, web: false), isFalse);
    });

    test('pistaConexion explica cada código con palabras claras', () {
      expect(pistaConexion('URL_INVALIDA'), contains('https://'));
      expect(pistaConexion('SIN_CONEXION'), contains('túnel'));
      expect(pistaConexion('HTTP_502'), contains('HTTP_502'));
    });

    test('nombreVelocidad', () {
      expect(nombreVelocidad(0.3), 'Más lenta');
      expect(nombreVelocidad(0.5), 'Normal');
      expect(nombreVelocidad(0.7), 'Más rápida');
    });
  });

  group('Identidad de TuTurno en Ajustes', () {
    testWidgets('«Acerca de» enseña el icono de la app, el logotipo y qué se queda en el móvil', (tester) async {
      final semantica = tester.ensureSemantics();
      final router = await arrancarApp(tester);
      await irA(tester, router, '/ajustes');
      await tester.scrollUntilVisible(find.byType(PlacaTut), 300, scrollable: find.byType(Scrollable).first);

      expect(find.byType(PlacaTut), findsOneWidget);
      expect(find.byType(LogoTuTurno), findsOneWidget);
      // El logotipo se lee una sola vez («TuTurno»): el icono de al lado es decorativo.
      expect(find.bySemanticsLabel('TuTurno'), findsOneWidget);
      expect(find.textContaining('Sin cuentas ni datos personales'), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('tras la pulsación larga en el pie, la galería de iconos y de Tut se abre desde Ajustes', (
      tester,
    ) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/ajustes');
      expect(find.text('Ver los iconos y a Tut', skipOffstage: false), findsNothing);
      await revelarEquipo(tester);
      await pulsar(tester, find.text('Ver los iconos y a Tut'));
      expect(find.byType(GaleriaIconos), findsOneWidget);
      expect(find.text('Iconos de TuTurno'), findsOneWidget);
    });

    testWidgets('el resultado de «Probar la conexión» lleva el icono de acierto o de error', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/ajustes');
      await revelarEquipo(tester);
      await pulsar(tester, find.text(_servidor));
      await pulsar(tester, find.text('Probar la conexión'));
      // El del botón «Usar este servidor» es de un color; el del resultado, a dos tintas.
      expect(
        find.byWidgetPredicate((w) => w is IconoTuTurno && w.icono == TuIcono.check && w.estilo == EstiloIcono.color),
        findsOneWidget,
      );
    });

    for (final brillo in Brightness.values) {
      testWidgets('cumple las pautas de accesibilidad en tema ${brillo.name}', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brillo;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final semantica = tester.ensureSemantics();
        final router = await arrancarApp(tester);
        await irA(tester, router, '/ajustes');
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantica.dispose();
      });
    }
  });
}
