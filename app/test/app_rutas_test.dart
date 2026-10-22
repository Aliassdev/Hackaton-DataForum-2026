import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/app.dart';
import 'package:tuturno/core/ajustes.dart';
import 'package:tuturno/core/api/models.dart';
import 'package:tuturno/core/config.dart';
import 'package:tuturno/core/providers.dart';
import 'package:tuturno/features/aprende/aprende_screen.dart';
import 'package:tuturno/features/ayuda/ayuda_screen.dart';
import 'package:tuturno/features/ayuda/pantalla_neutra.dart';
import 'package:tuturno/features/inicio/inicio_screen.dart';
import 'package:tuturno/features/juego/juego_screen.dart' show CasoScreen, JuzgadoScreen, rutaJuzgado;
import 'package:tuturno/features/mis_preguntas/ensenar_screen.dart';
import 'package:tuturno/features/mis_preguntas/mis_preguntas_screen.dart';
import 'package:tuturno/features/situacion/situacion_screen.dart';
import 'package:tuturno/pixel/juzgado/juzgado.dart' show ModoJuzgado;
import 'package:tuturno/pixel/ui/estilo_pixel.dart';
import 'package:tuturno/pixel/ui/transicion_pixel.dart' show DuracionTransicionPixel;
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/ayuda_button.dart';
import 'package:tuturno/widgets/marca/marca.dart';

/// Arranca TuTurnoApp como en main(), con la API de prueba y [preferencias] guardadas, y devuelve su router.
Future<GoRouter> _arrancar(WidgetTester tester, {Map<String, Object> preferencias = const {}}) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({'bienvenida_vista': true, ...preferencias});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        configProvider.overrideWithValue(const AppConfig(apiUrl: '', useMock: true, demo: false)),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const TuTurnoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return _contenedor(tester).read(routerProvider);
}

ProviderContainer _contenedor(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(TuTurnoApp)));

Future<void> _ajustar(WidgetTester tester, Ajustes Function(Ajustes) cambio) async {
  await _contenedor(tester).read(ajustesProvider.notifier).actualizar(cambio);
  await tester.pumpAndSettle();
}

Future<void> _ir(WidgetTester tester, GoRouter router, String ruta) async {
  router.go(ruta);
  await tester.pumpAndSettle();
}

/// La sonda: lo que lee de MediaQuery cualquier widget de la pantalla [pantalla].
bool _sinAnimaciones(WidgetTester tester, Type pantalla) =>
    MediaQuery.disableAnimationsOf(tester.element(find.byType(pantalla)));

/// Lo que dura la transición de la ruta en la que está [pantalla].
Duration _transicion(WidgetTester tester, Type pantalla) =>
    ModalRoute.of(tester.element(find.byType(pantalla)))!.transitionDuration;

void main() {
  group('rutas nuevas', () {
    testWidgets('/mis-preguntas y /mis-preguntas/ensenar abren, y «atrás» vuelve de Enseñar a Mis preguntas', (
      tester,
    ) async {
      final router = await _arrancar(tester);

      await _ir(tester, router, '/mis-preguntas');
      expect(find.byType(MisPreguntasScreen), findsOneWidget);
      expect(_transicion(tester, MisPreguntasScreen), greaterThan(Duration.zero));

      await _ir(tester, router, '/mis-preguntas/ensenar');
      expect(find.byType(EnsenarScreen), findsOneWidget);
      expect(router.canPop(), isTrue);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(MisPreguntasScreen), findsOneWidget);
      expect(find.byType(EnsenarScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final brillo in Brightness.values) {
      testWidgets('/salida (${brillo.name}): solo el papel y «Volver a TuTurno», sin barra, Ayuda, logotipo ni '
          'transición', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brillo;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final router = await _arrancar(tester);

        router.go('/salida');
        // Un solo fotograma: la pantalla de antes ya no se ve.
        await tester.pump();
        expect(find.byType(PantallaNeutra), findsOneWidget);
        expect(find.byType(InicioScreen), findsNothing);
        expect(_transicion(tester, PantallaNeutra), Duration.zero);

        expect(find.byType(AppBar), findsNothing);
        expect(find.byType(AyudaButton), findsNothing);
        expect(find.byType(GlosarioButton), findsNothing);
        expect(find.byType(LogoTuTurno), findsNothing);
        expect(find.byType(MonogramaTut), findsNothing);
        expect(find.byType(PlacaTut), findsNothing);
        final fondo = tester.widget<Scaffold>(
          find.descendant(of: find.byType(PantallaNeutra), matching: find.byType(Scaffold)),
        );
        expect(fondo.backgroundColor, ColoresMarca.papel, reason: 'el papel también en el tema oscuro');
        expect(find.byType(Text), findsOneWidget, reason: 'nada más que el botón para volver');

        final volver = find.widgetWithText(TextButton, 'Volver a TuTurno');
        expect(volver, findsOneWidget);
        expect(tester.getSize(volver).height, greaterThanOrEqualTo(48));
        expect(tester.getCenter(volver).dy, greaterThan(844 / 2), reason: 'abajo');
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        await tester.tap(volver);
        await tester.pumpAndSettle();
        expect(find.byType(InicioScreen), findsOneWidget);
        expect(find.byType(PantallaNeutra), findsNothing);
      });
    }

    testWidgets('/juego/juzgado abre «El juzgado por dentro» (no un caso que se llame «juzgado»)', (tester) async {
      final router = await _arrancar(tester);

      await _ir(tester, router, '/juego/juzgado');
      expect(find.byType(JuzgadoScreen), findsOneWidget);
      expect(find.byType(CasoScreen), findsNothing);
      expect(tester.widget<JuzgadoScreen>(find.byType(JuzgadoScreen)).modo, ModoJuzgado.salaVistas);
      expect(_transicion(tester, JuzgadoScreen), DuracionTransicionPixel.entrada, reason: 'a bloques, como el juego');
      expect(tester.takeException(), isNull);
    });

    testWidgets('/juzgado?modo=menores (final de Sergio) lleva al juzgado de menores', (tester) async {
      final router = await _arrancar(tester);

      await _ir(tester, router, '/juzgado?modo=menores');
      expect(find.byType(JuzgadoScreen), findsOneWidget);
      expect(tester.widget<JuzgadoScreen>(find.byType(JuzgadoScreen)).modo, ModoJuzgado.menores);
      expect(router.routeInformationProvider.value.uri.toString(), '$rutaJuzgado?modo=menores');
    });

    testWidgets('/juego/:casoId abre el caso con la transición a bloques del kit pixel', (tester) async {
      final router = await _arrancar(tester);

      await _ir(tester, router, '/juego/caso-sala-gesell');
      expect(find.byType(CasoScreen), findsOneWidget);
      expect(_transicion(tester, CasoScreen), DuracionTransicionPixel.entrada);
    });

    testWidgets('entrar directo en una lección (con go o un enlace) no rompe el mapa de Aprende de debajo', (
      tester,
    ) async {
      // La siguiente lección es U2-L2, la quinta: el mapa querría bajar hasta ella, pero está tapado por la lección.
      final router = await _arrancar(
        tester,
        preferencias: {
          'progreso': jsonEncode({
            'lecciones': ['U1-L1', 'U1-L2', 'U1-L3', 'U2-L1'],
          }),
        },
      );
      router.go('/aprende/leccion/U2-L2');
      // El contenido se lee de verdad (fuera del reloj falso de la prueba): se espera a que llegue.
      for (var i = 0; i < 60 && find.byType(LeccionScreen).evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pumpAndSettle();
      }
      expect(find.byType(LeccionScreen), findsOneWidget);
      expect(find.byType(AprendeScreen, skipOffstage: false), findsOneWidget, reason: 'Aprende, debajo');
      expect(tester.takeException(), isNull);
    });

    testWidgets('/situacion/escuchado_familia no rompe y pasa el papel tal cual (rolId)', (tester) async {
      final router = await _arrancar(tester);

      await _ir(tester, router, '/situacion/escuchado_familia');
      final familia = tester.widget<SituacionScreen>(find.byType(SituacionScreen));
      expect(familia.rol, isNull, reason: 'no es uno de los tres papeles del contrato (RolProceso)');
      expect(familia.rolId, 'escuchado_familia');
      expect(tester.takeException(), isNull);

      await _ir(tester, router, '/situacion/victima');
      final victima = tester.widget<SituacionScreen>(find.byType(SituacionScreen));
      expect(victima.rol, RolProceso.victima);
      expect(victima.rolId, 'victima');
    });
  });

  group('«reducir animaciones» de Ajustes', () {
    testWidgets(
      'con el ajuste guardado, la sonda lee disableAnimations en todas las rutas y las páginas no se mueven',
      (tester) async {
        final router = await _arrancar(tester, preferencias: {'ajustes.reducir_movimiento': true});
        expect(_sinAnimaciones(tester, InicioScreen), isTrue);

        for (final (ruta, pantalla) in [
          ('/mis-preguntas', MisPreguntasScreen),
          ('/mis-preguntas/ensenar', EnsenarScreen),
          ('/ayuda', AyudaScreen),
          ('/salida', PantallaNeutra),
        ]) {
          await _ir(tester, router, ruta);
          expect(_sinAnimaciones(tester, pantalla), isTrue, reason: ruta);
          expect(_transicion(tester, pantalla), Duration.zero, reason: ruta);
        }
      },
    );

    testWidgets('al encenderlo, la app deja de moverse al momento; al apagarlo, vuelve a moverse', (tester) async {
      final router = await _arrancar(tester);
      await _ir(tester, router, '/mis-preguntas');
      expect(_sinAnimaciones(tester, MisPreguntasScreen), isFalse);

      await _ajustar(tester, (a) => a.copyWith(reducirMovimiento: true));
      expect(_sinAnimaciones(tester, MisPreguntasScreen), isTrue);
      expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeAnimationDuration, Duration.zero);
      await _ir(tester, router, '/ayuda');
      expect(_transicion(tester, AyudaScreen), Duration.zero);

      await _ajustar(tester, (a) => a.copyWith(reducirMovimiento: false));
      expect(_sinAnimaciones(tester, AyudaScreen), isFalse);
      expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeAnimationDuration, kThemeAnimationDuration);
      await _ir(tester, router, '/mis-preguntas');
      expect(_transicion(tester, MisPreguntasScreen), greaterThan(Duration.zero));
    });

    testWidgets('sin el ajuste, la opción del sistema sigue valiendo', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final router = await _arrancar(tester);

      expect(_sinAnimaciones(tester, InicioScreen), isTrue);
      expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeAnimationDuration, Duration.zero);
      await _ir(tester, router, '/mis-preguntas');
      expect(_transicion(tester, MisPreguntasScreen), Duration.zero);
    });
  });

  group('«lectura fácil»', () {
    testWidgets('el tema pasa a Atkinson Hyperlegible al momento, en claro y en oscuro, y Vive el caso también', (
      tester,
    ) async {
      await _arrancar(tester);
      BuildContext contexto() => tester.element(find.byType(InicioScreen));
      expect(Theme.of(contexto()).textTheme.bodyLarge!.fontFamily, Fuentes.texto);
      expect(Theme.of(contexto()).textTheme.headlineSmall!.fontFamily, Fuentes.titulos);
      expect(TemaPixel.maybeOf(contexto())!.lecturaFacil, isFalse);
      final cuerpo = Theme.of(contexto()).textTheme.bodyLarge!;

      await _ajustar(tester, (a) => a.copyWith(lecturaFacil: true));
      final facil = Theme.of(contexto()).textTheme.bodyLarge!;
      expect(facil.fontFamily, Fuentes.lecturaFacil);
      expect(facil.fontSize, cuerpo.fontSize);
      expect(facil.height, greaterThan(cuerpo.height!), reason: 'algo más de interlineado');
      expect(Theme.of(contexto()).textTheme.headlineSmall!.fontFamily, Fuentes.lecturaFacil);
      expect(TemaPixel.maybeOf(contexto())!.lecturaFacil, isTrue, reason: 'el kit pixel cambia de letra');

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpAndSettle();
      expect(Theme.of(contexto()).brightness, Brightness.dark);
      expect(Theme.of(contexto()).textTheme.bodyLarge!.fontFamily, Fuentes.lecturaFacil);
    });

    testWidgets('se guarda: con el ajuste guardado, la app arranca ya en lectura fácil', (tester) async {
      await _arrancar(tester, preferencias: {'ajustes.lectura_facil': true});

      final contexto = tester.element(find.byType(InicioScreen));
      expect(Theme.of(contexto).textTheme.titleLarge!.fontFamily, Fuentes.lecturaFacil);
      expect(TemaPixel.maybeOf(contexto)!.lecturaFacil, isTrue);
    });

    testWidgets('con «reducir animaciones», el cambio de letra no se anima', (tester) async {
      await _arrancar(tester, preferencias: {'ajustes.reducir_movimiento': true});

      await _contenedor(tester).read(ajustesProvider.notifier).actualizar((a) => a.copyWith(lecturaFacil: true));
      await tester.pump();

      expect(Theme.of(tester.element(find.byType(InicioScreen))).textTheme.bodyLarge!.fontFamily, Fuentes.lecturaFacil);
    });

    testWidgets('TemaPixel solo cambia la letra: el resto de la app conserva su scroll', (tester) async {
      await _arrancar(tester);

      expect(ScrollConfiguration.of(tester.element(find.byType(InicioScreen))), isA<MaterialScrollBehavior>());
    });
  });
}
