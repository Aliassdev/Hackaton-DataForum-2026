// Mi situación con la identidad de TuTurno: la cabecera de ticket con tu papel, «Qué significa» con su nota de
// tranquilidad, la línea de pasos real (features/pasos) y el selector de papel como tickets. Sigue siendo parte de
// Pregunta: tranquila, sin celebraciones, y nunca pregunta qué pasó.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/app.dart';
import 'package:tuturno/core/api/models.dart';
import 'package:tuturno/core/config.dart';
import 'package:tuturno/core/content_repo.dart';
import 'package:tuturno/core/providers.dart';
import 'package:tuturno/features/pasos/pasos.dart';
import 'package:tuturno/features/situacion/roles.dart';
import 'package:tuturno/features/situacion/situacion_screen.dart';
import 'package:tuturno/widgets/iconos/iconos.dart';
import 'package:tuturno/widgets/movimiento/ticket.dart';

import 'helpers.dart';

/// Un itinerario de testigo validado y con fuente, como los de content/itinerarios.
const _itinerarioTestigo = '''
{
  "rol": "testigo",
  "pasos": [
    {"id": "P1", "fase": "antes", "nombre": "Te llega una citación",
     "que_pasa": "Un aviso oficial dice qué día, a qué hora y dónde tienes que ir.",
     "quien_esta": ["Tu familia o quien te represente"],
     "que_puedes_pedir": ["Que te lo expliquen con palabras claras"],
     "fuentes": ["LECrim, art. 433"]},
    {"id": "P2", "fase": "durante", "nombre": "Cuentas lo que sabes",
     "que_pasa": "Te escuchan con calma y puedes pedir un descanso.",
     "quien_esta": ["El juez o la jueza"],
     "que_puedes_pedir": ["Un descanso"],
     "fuentes": ["LECrim, art. 433"]}
  ],
  "validado": true
}
''';

/// Como `arrancarApp`, pero con el itinerario de testigo en el contenido.
Future<GoRouter> _arrancarConPasos(WidgetTester tester) async {
  tester.view.physicalSize = movil * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({'bienvenida_vista': true});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        configProvider.overrideWithValue(const AppConfig(apiUrl: '', useMock: true, demo: false)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        contentProvider.overrideWithValue(
          ContentRepo(
            bundle: BundleEnMemoria({
              '${ContentRepo.raiz}/glosario.json': glosarioDePrueba,
              '${ContentRepo.raiz}/itinerarios/testigo.json': _itinerarioTestigo,
            }),
          ),
        ),
      ],
      child: const TuTurnoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(TuTurnoApp))).read(routerProvider);
}

void main() {
  group('Mi situación', () {
    testWidgets('la cabecera es un ticket con tu papel y su pegatina', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/situacion/victima');

      final cabecera = find.byType(CabeceraRol);
      expect(cabecera, findsOneWidget);
      expect(find.descendant(of: cabecera, matching: find.text('Víctima')), findsOneWidget);
      expect(find.descendant(of: cabecera, matching: find.text(RolProceso.victima.resumen)), findsOneWidget);
      final pegatina = tester.widget<IconoTuTurno>(find.descendant(of: cabecera, matching: find.byType(IconoTuTurno)));
      expect(pegatina.icono, TuIcono.escudo);
      expect(pegatina.pegatina, isTrue);
    });

    testWidgets('con itinerario, enseña la línea de pasos en lugar del aviso «Muy pronto»', (tester) async {
      final router = await _arrancarConPasos(tester);
      await irA(tester, router, '/situacion/testigo');

      expect(find.byType(LineaPasos), findsOneWidget);
      expect(find.text('Muy pronto'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Cuentas lo que sabes'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Te llega una citación'), findsOneWidget);
      expect(find.text('Cuentas lo que sabes'), findsOneWidget);
      // Debajo de los pasos sigue la pregunta con ese papel.
      await pulsar(tester, find.text('Pregunta como testigo'));
      await esperarTransicion(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin itinerario para ese papel lo dice con calma y el resto de la pantalla sigue', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/situacion/investigado');

      expect(find.text(textoSinPasos), findsOneWidget);
      expect(find.text(RolProceso.investigado.explicacion), findsOneWidget);
      expect(find.text(RolProceso.investigado.tranquilidad), findsOneWidget);
      expect(find.text('Pregunta como investigado o investigada'), findsOneWidget);
    });

    testWidgets('el selector de papel son tickets con el icono de cada papel y Tut tranquilo', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/situacion/otra-cosa');

      for (final rol in RolProceso.values) {
        final ticket = find.ancestor(of: find.text(rol.nombre), matching: find.byType(TicketTuTurno));
        expect(ticket, findsOneWidget, reason: rol.name);
        final iconos = tester.widgetList<IconoTuTurno>(
          find.descendant(of: ticket, matching: find.byType(IconoTuTurno)),
        );
        expect(iconos.map((i) => i.icono), contains(rol.tuIcono), reason: rol.name);
      }
      final tut = tester.widget<MascotaTut>(find.byType(MascotaTut));
      expect(tut.expresion, ExpresionTut.neutral);
      expect(tut.animada, isFalse);
    });

    testWidgets('con «reducir animaciones», nada se mueve (ni el papel de la cabecera)', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final router = await _arrancarConPasos(tester);
      router.push('/situacion/testigo');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.byType(CabeceraRol), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    for (final brillo in Brightness.values) {
      testWidgets('cumple las pautas de accesibilidad en tema ${brillo.name} (pantalla y selector)', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brillo;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final semantica = tester.ensureSemantics();
        final router = await _arrancarConPasos(tester);
        await irA(tester, router, '/situacion/testigo');
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        await pulsar(tester, find.text('Cambiar de papel'));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantica.dispose();
      });
    }

    testWidgets('cabe con letra grande en un móvil pequeño, con los pasos', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final router = await _arrancarConPasos(tester);
      tester.view.physicalSize = const Size(360, 640) * tester.view.devicePixelRatio;
      await tester.pumpAndSettle();
      await irA(tester, router, '/situacion/testigo');
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -6000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await pulsar(tester, find.text('Cambiar de papel'));
      expect(tester.takeException(), isNull);
    });
  });
}
