import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/api/models.dart';
import 'package:tuturno/features/aprende/aprende_screen.dart';
import 'package:tuturno/features/juego/juego_screen.dart';
import 'package:tuturno/features/juego/textos.dart' show casoNoEncontradoTitulo, sinCasosTitulo;
import 'package:tuturno/features/pregunta/pregunta_screen.dart';
import 'package:tuturno/features/situacion/roles.dart';
import 'package:tuturno/features/situacion/situacion_screen.dart';
import 'package:tuturno/widgets/justicia/cartel_sala.dart';
import 'package:tuturno/widgets/modulos.dart';

import 'helpers.dart';

void main() {
  // Los tickets de los módulos del inicio son las puertas del palacio de justicia de papel: cada uno con el cartel de
  // su sala (tema-justicia.md, §7.9). Se tienen que ver bien en claro, en oscuro y con la letra grande.
  group('Tickets de módulo en el inicio', () {
    Future<void> comprobarCarteles(WidgetTester tester, String caso) async {
      for (final modulo in Modulo.values) {
        final tarjeta = find.widgetWithText(TarjetaModulo, modulo.titulo);
        await tester.ensureVisible(tarjeta);
        await tester.pumpAndSettle();
        final cartel = find.descendant(of: tarjeta, matching: find.byType(CartelSala));
        expect(cartel, findsOneWidget, reason: '$caso ${modulo.titulo}');
        expect(tester.widget<CartelSala>(cartel).texto, modulo.sala, reason: caso);
        expect(
          find.descendant(of: cartel, matching: find.text(modulo.sala!)),
          findsOneWidget,
          reason: caso,
        );
        // El cartel va arriba, encima del título, y dentro de la tarjeta.
        expect(tester.getBottomLeft(cartel).dy, lessThan(tester.getTopLeft(find.text(modulo.titulo)).dy));
        final caja = tester.getRect(tarjeta);
        expect(caja.inflate(1).contains(tester.getRect(cartel).topLeft), isTrue, reason: caso);
        expect(caja.inflate(1).contains(tester.getRect(cartel).bottomRight), isTrue, reason: caso);
      }
      expect(tester.takeException(), isNull, reason: caso);
    }

    testWidgets('«SALA 1», «SALA 2» e «INFORMACIÓN», en claro y en oscuro', (tester) async {
      expect([for (final modulo in Modulo.values) modulo.sala], ['SALA 1', 'SALA 2', 'INFORMACIÓN']);
      for (final brillo in Brightness.values) {
        tester.platformDispatcher.platformBrightnessTestValue = brillo;
        await arrancarApp(tester);
        await comprobarCarteles(tester, '$brillo');
      }
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });

    testWidgets('con la letra a 1,3 en un móvil pequeño, sin desbordarse', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final brillo in Brightness.values) {
        tester.platformDispatcher.platformBrightnessTestValue = brillo;
        await arrancarApp(tester, tamano: const Size(360, 640));
        await comprobarCarteles(tester, '1,3 $brillo');
      }
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });

    testWidgets('el cartel se lee junto al módulo, y Ayuda (fuera de la metáfora) no lleva cartel', (tester) async {
      final semantica = tester.ensureSemantics();
      await arrancarApp(tester);
      for (final modulo in Modulo.values) {
        final datos = tester.getSemantics(find.widgetWithText(TarjetaModulo, modulo.titulo)).getSemanticsData();
        expect(datos.label, contains(modulo.sala!));
        expect(datos.label, contains(modulo.titulo));
      }
      expect(find.byType(CartelSala), findsNWidgets(Modulo.values.length));
      semantica.dispose();
    });
  });

  // En este arnés no hay contenido (ni AssetManifest): Vive el caso y Aprende enseñan sus estados vacíos, que tienen
  // que explicarlo con calma y dejar seguir.
  group('Vive el caso y Aprende sin contenido', () {
    testWidgets('Vive el caso dice que aún no hay casos y lleva a Pregunta', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/juego');

      expect(find.byType(JuegoScreen), findsOneWidget);
      expect(find.text(sinCasosTitulo), findsOneWidget);

      await pulsar(tester, find.text('Ir a Pregunta'));
      await esperarTransicion(tester);
      expect(find.byType(PreguntaScreen), findsOneWidget);
    });

    testWidgets('Aprende dice que las lecciones están en camino y lleva a Pregunta', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/aprende');

      expect(find.byType(AprendeScreen), findsOneWidget);
      expect(find.text('Las lecciones están en camino'), findsOneWidget);

      await pulsar(tester, find.text('Ir a Pregunta'));
      await esperarTransicion(tester);
      expect(find.byType(PreguntaScreen), findsOneWidget);
    });

    testWidgets('un caso o una lección que no existen lo dicen sin romper nada', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/juego/caso-testigo');
      expect(find.byType(CasoScreen), findsOneWidget);
      expect(find.text(casoNoEncontradoTitulo), findsOneWidget);

      await irA(tester, router, '/aprende/leccion/U1-L1');
      expect(find.byType(LeccionScreen), findsOneWidget);
      expect(find.text('No encuentro esta lección'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Mi situación', () {
    for (final rol in RolProceso.values) {
      testWidgets('explica el papel ${rol.name} y pregunta con ese papel', (tester) async {
        final router = await arrancarApp(tester);
        await irA(tester, router, '/situacion/${rol.name}');

        expect(find.text(rol.nombre), findsOneWidget);
        expect(find.text(rol.explicacion), findsOneWidget);
        expect(find.text(rol.tranquilidad), findsOneWidget);
        expect(find.text(notaNoPreguntamos), findsOneWidget);

        await pulsar(tester, find.text('Pregunta como ${rol.enFrase}'));
        await esperarTransicion(tester);
        expect(tester.widget<PreguntaScreen>(find.byType(PreguntaScreen)).situacion, rol);
      });
    }

    testWidgets('con un papel que no existe, deja elegirlo', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/situacion/otra-cosa');

      expect(find.text('¿Qué papel tienes en el caso?'), findsOneWidget);
      await tester.tap(find.text('Testigo'));
      await tester.pumpAndSettle();
      expect(tester.widget<SituacionScreen>(find.byType(SituacionScreen)).rol, RolProceso.testigo);
      expect(find.text('Pregunta como testigo'), findsOneWidget);
    });

    testWidgets('se puede cambiar de papel', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/situacion/testigo');

      await pulsar(tester, find.text('Cambiar de papel'));
      await tester.tap(find.text('Investigado o investigada').last);
      await tester.pumpAndSettle();
      expect(tester.widget<SituacionScreen>(find.byType(SituacionScreen)).rol, RolProceso.investigado);
    });

    testWidgets('cabe con letra grande en un móvil pequeño', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final router = await arrancarApp(
        tester,
        preferencias: {'ajustes.tamano_texto': 1.3},
        tamano: const Size(360, 640),
      );
      for (final ruta in ['/situacion/investigado', '/juego', '/aprende', '/glosario', '/ajustes']) {
        await irA(tester, router, ruta);
        expect(tester.takeException(), isNull, reason: ruta);
        final desplazable = find.byType(Scrollable);
        if (desplazable.evaluate().isNotEmpty) {
          await tester.drag(desplazable.first, const Offset(0, -6000));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: ruta);
        router.pop();
        await tester.pumpAndSettle();
      }
    });
  });

  test('ningún texto de los papeles habla de los hechos ni dice «12 a 18»', () {
    for (final rol in RolProceso.values) {
      for (final texto in [rol.nombre, rol.resumen, rol.explicacion, rol.tranquilidad]) {
        expect(texto.contains('¿Qué pasó'), isFalse);
        expect(texto.contains('12 a 18'), isFalse);
      }
    }
  });
}
