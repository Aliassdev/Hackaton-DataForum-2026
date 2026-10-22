import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/widgets/movimiento/movimiento.dart';

import 'entorno.dart';

final _pegatina = find.byType(PopPegatina);

Matrix4 _pegada(double inclinacion) => Matrix4.identity()..rotateZ(inclinacion);

void main() {
  testWidgets('crece de más, gira y se asienta ligeramente torcida', (tester) async {
    await montar(tester, const PopPegatina(child: Text('+10 XP')));
    expect(opacidadDe(tester, _pegatina), 0);
    await tester.pump(const Duration(milliseconds: 290));
    expect(transformacionDe(tester, _pegatina).getMaxScaleOnAxis(), greaterThan(1.05), reason: 'se pasa un poco');
    await tester.pumpAndSettle();
    expect(transformacionDe(tester, _pegatina), matrixMoreOrLessEquals(_pegada(-0.05)));
    expect(opacidadDe(tester, _pegatina), 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('orden escalona: la tercera espera a las anteriores', (tester) async {
    await montar(tester, const PopPegatina(orden: 3, child: Text('C')));
    await tester.pump(const Duration(milliseconds: 180));
    expect(opacidadDe(tester, _pegatina), 0);
    await tester.pumpAndSettle();
    expect(opacidadDe(tester, _pegatina), 1);
  });

  testWidgets('al cambiar la clave vuelve a hacer pop (y vibra si se pide)', (tester) async {
    final vibraciones = registrarVibraciones(tester);
    await montar(tester, const PopPegatina(clave: 10, vibrar: true, child: Text('10 XP')));
    await tester.pumpAndSettle();
    expect(vibraciones, ['HapticFeedbackType.lightImpact']);
    await montar(tester, const PopPegatina(clave: 20, vibrar: true, child: Text('20 XP')));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(const Duration(milliseconds: 280));
    expect(transformacionDe(tester, _pegatina).getMaxScaleOnAxis(), greaterThan(1.05));
    await tester.pumpAndSettle();
    expect(vibraciones, hasLength(2));
  });

  testWidgets('con «reducir animaciones» o sin animar, aparece ya pegada', (tester) async {
    await montar(tester, reducir: true, const PopPegatina(child: Text('A')));
    expect(transformacionDe(tester, _pegatina), matrixMoreOrLessEquals(_pegada(-0.05)));
    expect(opacidadDe(tester, _pegatina), 1);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await montar(tester, const PopPegatina(animar: false, inclinacion: 0.1, child: Text('B')));
    expect(transformacionDe(tester, _pegatina), matrixMoreOrLessEquals(_pegada(0.1)));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('se puede quitar a mitad del pop', (tester) async {
    await montar(tester, const PopPegatina(child: Text('A')));
    await tester.pump(const Duration(milliseconds: 100));
    await desmontar(tester);
  });
}
