import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
