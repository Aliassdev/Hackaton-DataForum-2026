import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/widgets/iconos/iconos.dart';

import 'ayudantes.dart';

void main() {
  group('MascotaTut', () {
    for (final brillo in Brightness.values) {
      testWidgets('todas las expresiones se pintan en ${brillo.name}, de 32 a 200 px, con y sin pegatina', (
        tester,
      ) async {
        await montar(
          tester,
          SingleChildScrollView(
            child: Wrap(
              children: [
                for (final lado in const [32.0, 40.0, 72.0, 200.0])
                  for (final expresion in ExpresionTut.values) ...[
                    MascotaTut(expresion: expresion, size: lado, animada: false),
                    MascotaTut(expresion: expresion, size: lado, animada: false, pegatina: true),
                  ],
              ],
            ),
          ),
          brillo: brillo,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(MascotaTut), findsNWidgets(ExpresionTut.values.length * 8));
      });
    }

    testWidgets('se lee lo que expresa; con semanticLabel, eso; decorativa, nada', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(
        tester,
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MascotaTut(expresion: ExpresionTut.celebrando, size: 60, animada: false),
            MascotaTut(size: 60, animada: false, semanticLabel: 'Tut te saluda'),
            MascotaTut(expresion: ExpresionTut.triste, size: 60, animada: false, decorativo: true),
          ],
        ),
      );
      expect(find.bySemanticsLabel(ExpresionTut.celebrando.descripcion), findsOneWidget);
      expect(find.bySemanticsLabel('Tut te saluda'), findsOneWidget);
      expect(find.bySemanticsLabel(ExpresionTut.triste.descripcion), findsNothing);
      for (final expresion in ExpresionTut.values) {
        expect(expresion.descripcion, contains('Tut'));
      }
      semantica.dispose();
    });

    testWidgets('al cambiar de expresión, la cara se transforma y se para', (tester) async {
      Widget tut(ExpresionTut expresion) => MascotaTut(expresion: expresion, size: 120, animada: false);
      await montar(tester, tut(ExpresionTut.neutral));
      expect(tester.binding.transientCallbackCount, 0);
      for (final expresion in ExpresionTut.values.reversed) {
        await montar(tester, tut(expresion));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('animada: entra con un salto y hace gestos de vez en cuando, sin bucles', (tester) async {
      await montar(tester, const MascotaTut(size: 120));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpAndSettle();
      // Quieta entre gesto y gesto: no pide fotogramas.
      expect(tester.binding.transientCallbackCount, 0);
      var gestos = 0;
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 1));
        if (tester.binding.transientCallbackCount > 0) gestos++;
        await tester.pumpAndSettle();
      }
      expect(gestos, greaterThanOrEqualTo(2));
      // Al quitarla de la pantalla no queda ningún reloj pendiente (flutter_test lo comprueba al acabar).
      await montar(tester, const SizedBox());
    });

    testWidgets('al celebrar, salta', (tester) async {
      await montar(tester, const MascotaTut(size: 120, animada: true));
      await tester.pumpAndSettle();
      await montar(tester, const MascotaTut(expresion: ExpresionTut.celebrando, size: 120, animada: true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpAndSettle();
      await montar(tester, const SizedBox());
    });

    testWidgets('con «reducir animaciones» o animada: false, ni gestos ni relojes', (tester) async {
      for (final (sinAnimaciones, animada) in [(true, true), (false, false)]) {
        await montar(
          tester,
          MascotaTut(expresion: ExpresionTut.feliz, size: 120, animada: animada),
          sinAnimaciones: sinAnimaciones,
        );
        expect(tester.binding.transientCallbackCount, 0);
        await tester.pump(const Duration(seconds: 20));
        expect(tester.binding.transientCallbackCount, 0);
        // El cambio de expresión es instantáneo si no hay movimiento.
        await montar(
          tester,
          MascotaTut(expresion: ExpresionTut.celebrando, size: 120, animada: animada),
          sinAnimaciones: sinAnimaciones,
        );
        if (sinAnimaciones) expect(tester.binding.transientCallbackCount, 0);
        await tester.pumpAndSettle();
      }
    });
  });

  group('GaleriaIconos', () {
    testWidgets('enseña todos los iconos y todas las expresiones', (tester) async {
      tester.view.physicalSize = const Size(1000, 6000) * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
      await montar(tester, const GaleriaIconos(), desplazable: true);
      expect(tester.takeException(), isNull);
      // Cuadrícula, pegatinas, una tinta (2 tamaños) y la fila de tamaños.
      expect(find.byType(IconoTuTurno), findsAtLeastNWidgets(TuIcono.values.length * 4));
      expect(find.byType(MascotaTut), findsNWidgets(ExpresionTut.values.length * 3));
      for (final icono in TuIcono.values) {
        expect(find.text(icono.etiqueta), findsOneWidget);
      }
    });

    for (final brillo in Brightness.values) {
      testWidgets('cabe en un móvil con letra grande (${brillo.name})', (tester) async {
        tester.view.physicalSize = const Size(360, 740) * tester.view.devicePixelRatio;
        addTearDown(tester.view.resetPhysicalSize);
        await montar(tester, const GaleriaIconos(), brillo: brillo, letra: 1.3, desplazable: true);
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -20000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
