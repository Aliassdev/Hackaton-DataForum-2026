import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/widgets/movimiento/movimiento.dart';

import 'entorno.dart';

void main() {
  testWidgets('gira cifra a cifra como un panel de aeropuerto y acaba en el número nuevo', (tester) async {
    await montar(tester, const ContadorFlip(valor: 7, digitos: 2));
    expect(find.text('0'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await montar(tester, const ContadorFlip(valor: 9, digitos: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    // A mitad de la primera vuelta se ven la cifra de antes y la siguiente (7 → 8 → 9).
    expect(find.text('7'), findsWidgets);
    expect(find.text('8'), findsWidgets);
    expect(find.text('9'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('9'), findsOneWidget);
    expect(find.text('7'), findsNothing);
    expect(find.text('8'), findsNothing);
    expect(find.text('0'), findsOneWidget, reason: 'las decenas no cambian');
  });

  testWidgets('con desde, gira al aparecer; se lee el número, no las paletas', (tester) async {
    final semantica = tester.ensureSemantics();
    await montar(tester, const ContadorFlip(valor: 3, desde: 0, semanticsLabel: '3 XP'));
    expect(find.text('0'), findsWidgets);
    expect(find.bySemanticsLabel('3 XP'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    semantica.dispose();
  });

  testWidgets('de 99 a 100 y con letras (PanelFlip) no se rompe', (tester) async {
    await montar(tester, const ContadorFlip(valor: 99));
    await montar(tester, const ContadorFlip(valor: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));

    await montar(tester, const PanelFlip(texto: 'A-12'));
    await montar(tester, const PanelFlip(texto: 'B-13'));
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('un cambio a mitad de giro sigue hasta el último número', (tester) async {
    await montar(tester, const ContadorFlip(valor: 1));
    await montar(tester, const ContadorFlip(valor: 5));
    await tester.pump(const Duration(milliseconds: 150));
    await montar(tester, const ContadorFlip(valor: 2));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    expect(find.text('5'), findsNothing);
  });

  testWidgets('con «reducir animaciones» cambia sin girar', (tester) async {
    await montar(tester, reducir: true, const ContadorFlip(valor: 5, desde: 0));
    expect(find.text('5'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await montar(tester, reducir: true, const ContadorFlip(valor: 8));
    expect(find.text('8'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('cabe con letra grande y en el tema oscuro', (tester) async {
    await montar(tester, escalaTexto: 1.69, brillo: Brightness.dark, const ContadorFlip(valor: 1234, desde: 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('se puede quitar a mitad de giro', (tester) async {
    await montar(tester, const ContadorFlip(valor: 0));
    await montar(tester, const ContadorFlip(valor: 9));
    await tester.pump(const Duration(milliseconds: 50));
    await desmontar(tester);
  });
}
