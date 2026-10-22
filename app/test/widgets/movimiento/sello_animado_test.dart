import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/widgets/iconos/iconos.dart';
import 'package:tuturno/widgets/movimiento/movimiento.dart';

import 'entorno.dart';

final _sello = find.byType(SelloAnimado);

/// Pose final: torcido [inclinacion] y a tamaño normal.
Matrix4 _puesto(double inclinacion) => Matrix4.identity()..rotateZ(inclinacion);

void main() {
  testWidgets('cae, golpea a su tiempo (vibración fuerte y aviso) y se queda torcido', (tester) async {
    final vibraciones = registrarVibraciones(tester);
    var golpes = 0;
    await montar(
      tester,
      SelloAnimado(
        alEstampar: () => golpes++,
        child: const Sello(texto: 'Oído', icono: Icons.hearing_rounded),
      ),
    );
    expect(opacidadDe(tester, _sello), 0, reason: 'aún no ha empezado a caer');
    await tester.pump(const Duration(milliseconds: 200));
    expect(golpes, 0);
    expect(vibraciones, isEmpty);
    expect(transformacionDe(tester, _sello).getMaxScaleOnAxis(), greaterThan(1.2), reason: 'aún está en el aire');

    await tester.pump(const Duration(milliseconds: 160));
    expect(golpes, 1);
    expect(vibraciones, ['HapticFeedbackType.heavyImpact']);

    await tester.pumpAndSettle();
    expect(golpes, 1);
    expect(transformacionDe(tester, _sello), matrixMoreOrLessEquals(_puesto(-0.16)));
    expect(opacidadDe(tester, _sello), 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('sin animar aparece ya puesto y sin vibrar (los sellos que ya tenías)', (tester) async {
    final vibraciones = registrarVibraciones(tester);
    var golpes = 0;
    await montar(
      tester,
      SelloAnimado(
        animar: false,
        alEstampar: () => golpes++,
        child: const Sello(texto: 'Hecho'),
      ),
    );
    expect(transformacionDe(tester, _sello), matrixMoreOrLessEquals(_puesto(-0.16)));
    expect(opacidadDe(tester, _sello), 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(golpes, 0);
    expect(vibraciones, isEmpty);
  });

  testWidgets('con «reducir animaciones» aparece puesto, pero sí avisa y vibra', (tester) async {
    final vibraciones = registrarVibraciones(tester);
    var golpes = 0;
    await montar(
      tester,
      reducir: true,
      SelloAnimado(
        alEstampar: () => golpes++,
        child: const Sello(texto: 'Oído'),
      ),
    );
    await tester.pump();
    expect(transformacionDe(tester, _sello), matrixMoreOrLessEquals(_puesto(-0.16)));
    expect(opacidadDe(tester, _sello), 1);
    expect(golpes, 1);
    expect(vibraciones, ['HapticFeedbackType.heavyImpact']);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('sin estampar deja su hueco; al estamparse, cae (con retraso)', (tester) async {
    var golpes = 0;
    Widget sello(bool estampado) => SelloAnimado(
      estampado: estampado,
      retraso: const Duration(milliseconds: 300),
      vibrar: false,
      alEstampar: () => golpes++,
      child: const SizedBox.square(dimension: 80, child: ColoredBox(color: Colors.blue)),
    );
    await montar(tester, sello(false));
    expect(opacidadDe(tester, _sello), 0);
    expect(tester.getSize(_sello), const Size.square(80));
    expect(tester.binding.hasScheduledFrame, isFalse);

    await montar(tester, sello(true));
    await tester.pump(const Duration(milliseconds: 280));
    expect(opacidadDe(tester, _sello), 0, reason: 'esperando el retraso');
    await tester.pump(const Duration(milliseconds: 400));
    expect(golpes, 1);
    await tester.pumpAndSettle();
    expect(opacidadDe(tester, _sello), 1);
  });

  testWidgets('se puede quitar a mitad de la caída sin que vibre después', (tester) async {
    final vibraciones = registrarVibraciones(tester);
    await montar(tester, const SelloAnimado(child: Sello(texto: 'Oído')));
    await tester.pump(const Duration(milliseconds: 100));
    await desmontar(tester);
    expect(vibraciones, isEmpty);
  });

  testWidgets('el sello se pinta en claro, en oscuro y con letra grande, y se lee', (tester) async {
    final semantica = tester.ensureSemantics();
    for (final brillo in Brightness.values) {
      await montar(
        tester,
        brillo: brillo,
        escalaTexto: 1.69,
        const Sello(texto: 'Abogado gratis', icono: Icons.gavel_rounded, tamano: 140),
      );
      expect(tester.takeException(), isNull, reason: '$brillo');
    }
    expect(find.bySemanticsLabel('Sello: Abogado gratis'), findsOneWidget);
    semantica.dispose();
  });

  group('con tuIcono', () {
    const lado = 200.0;
    const tinta = Color(0xFFD50000);
    final marco = GlobalKey();

    /// Píxeles del sello (tamaño lógico, fondo transparente) en una franja de alturas relativas al centro, en radios.
    Future<List<Color>> franja(WidgetTester tester, Widget sello, double desde, double hasta) async {
      await montar(tester, RepaintBoundary(key: marco, child: sello));
      final limite = marco.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final datos = (await tester.runAsync(() async {
        final imagen = await limite.toImage();
        return imagen.toByteData();
      }))!;
      const r = lado / 2;
      return [
        for (var y = (r + desde * r).round(); y < (r + hasta * r).round(); y++)
          for (var x = (r - 0.18 * r).round(); x < (r + 0.18 * r).round(); x++)
            Color.fromARGB(
              datos.getUint8((y * lado.toInt() + x) * 4 + 3),
              datos.getUint8((y * lado.toInt() + x) * 4),
              datos.getUint8((y * lado.toInt() + x) * 4 + 1),
              datos.getUint8((y * lado.toInt() + x) * 4 + 2),
            ),
      ];
    }

    bool esTinta(Color c) => c.a > 0.5 && c.r > 0.6 && c.g < 0.35 && c.b < 0.35;

    testWidgets('lleva el icono grabado encima de la palabra, a una tinta del color del sello', (tester) async {
      // Con una palabra corta, el icono ocupa en el centro la franja de −0,40 a +0,10 radios (y la palabra, debajo).
      final conIcono = await franja(
        tester,
        const Sello(texto: 'OK', tuIcono: TuIcono.balanza, color: tinta, tamano: lado),
        -0.25,
        -0.15,
      );
      expect(conIcono.where(esTinta).length, greaterThan(60), reason: 'el brazo y los platos de la balanza');
      // Una sola tinta: ni el azul ni el amarillo del icono a dos tintas.
      expect(conIcono.where((c) => c.a > 0.5 && (c.b > c.r || c.g > 0.6)), isEmpty);

      final palabra = await franja(
        tester,
        const Sello(texto: 'OK', tuIcono: TuIcono.balanza, color: tinta, tamano: lado),
        0.15,
        0.35,
      );
      expect(palabra.where(esTinta), isNotEmpty, reason: 'la palabra sigue debajo');

      final sinIcono = await franja(tester, const Sello(texto: 'OK', color: tinta, tamano: lado), -0.25, -0.15);
      expect(sinIcono.where((c) => c.a > 0), isEmpty, reason: 'sin icono, encima de la palabra no hay nada');
    });

    testWidgets('se pinta en claro, en oscuro y con letra grande, y se lee igual', (tester) async {
      final semantica = tester.ensureSemantics();
      for (final brillo in Brightness.values) {
        await montar(
          tester,
          brillo: brillo,
          escalaTexto: 1.69,
          const Sello(texto: 'Completado', tuIcono: TuIcono.puertaSala, icono: Icons.check_rounded),
        );
        expect(tester.takeException(), isNull, reason: '$brillo');
      }
      expect(find.bySemanticsLabel('Sello: Completado'), findsOneWidget);
      semantica.dispose();
    });
  });
}
