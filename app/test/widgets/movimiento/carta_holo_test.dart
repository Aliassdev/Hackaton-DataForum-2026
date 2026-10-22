import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/widgets/movimiento/movimiento.dart';

import 'entorno.dart';

final _carta = find.byType(CartaHolo);

/// En reposo solo queda la perspectiva.
final _reposo = Matrix4.identity()..setEntry(3, 2, 0.0012);

const _contenido = SizedBox(width: 200, height: 280, child: ColoredBox(color: Colors.blue));

Future<void> _arrastrar(WidgetTester tester, Offset desplazamiento) async {
  final gesto = await tester.startGesture(tester.getCenter(_carta));
  await gesto.moveBy(desplazamiento / 2);
  await gesto.moveBy(desplazamiento / 2);
  await tester.pump();
  await gesto.up();
}

void main() {
  testWidgets('se inclina al arrastrar y vuelve a su sitio con un rebote al soltar', (tester) async {
    await montar(tester, const CartaHolo(child: _contenido));
    expect(transformacionDe(tester, _carta), matrixMoreOrLessEquals(_reposo));

    final gesto = await tester.startGesture(tester.getCenter(_carta));
    await gesto.moveBy(const Offset(40, 0));
    await gesto.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(transformacionDe(tester, _carta), isNot(matrixMoreOrLessEquals(_reposo)));

    await gesto.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(transformacionDe(tester, _carta), matrixMoreOrLessEquals(_reposo));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('aunque el dedo salga de la carta, la inclinación tiene un límite', (tester) async {
    await montar(tester, const CartaHolo(child: _contenido));
    final gesto = await tester.startGesture(tester.getCenter(_carta));
    await gesto.moveBy(const Offset(400, 0));
    await gesto.moveBy(const Offset(400, 300));
    await tester.pump();
    final maxima = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateX(-0.35)
      ..rotateY(0.35);
    expect(transformacionDe(tester, _carta), matrixMoreOrLessEquals(maxima));
    await gesto.up();
    await tester.pumpAndSettle();
  });

  testWidgets('al tocarla avisa y se balancea un momento', (tester) async {
    var toques = 0;
    await montar(tester, CartaHolo(onTap: () => toques++, child: _contenido));
    await tester.tap(_carta);
    await tester.pump(const Duration(milliseconds: 60));
    expect(toques, 1);
    expect(transformacionDe(tester, _carta), isNot(matrixMoreOrLessEquals(_reposo)));
    await tester.pumpAndSettle();
    expect(transformacionDe(tester, _carta), matrixMoreOrLessEquals(_reposo));
  });

  testWidgets('con «reducir animaciones» no se mueve, pero el toque funciona', (tester) async {
    var toques = 0;
    await montar(tester, reducir: true, CartaHolo(onTap: () => toques++, child: _contenido));
    await _arrastrar(tester, const Offset(80, 40));
    expect(transformacionDe(tester, _carta), matrixMoreOrLessEquals(_reposo));
    await tester.tap(_carta);
    await tester.pump();
    expect(toques, 1);
    expect(transformacionDe(tester, _carta), matrixMoreOrLessEquals(_reposo));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('el reflejo se pinta en los dos temas y sin brillo también', (tester) async {
    for (final brillo in Brightness.values) {
      await montar(tester, brillo: brillo, const CartaHolo(child: _contenido));
      expect(tester.takeException(), isNull);
    }
    await montar(tester, const CartaHolo(brillo: false, child: _contenido));
    expect(tester.takeException(), isNull);
  });

  testWidgets('se puede quitar mientras vuelve a su sitio', (tester) async {
    await montar(tester, const CartaHolo(child: _contenido));
    await _arrastrar(tester, const Offset(80, 0));
    await tester.pump(const Duration(milliseconds: 50));
    await desmontar(tester);
  });
}
