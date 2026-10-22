import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/ui/ui.dart';

import 'ayudantes.dart';

/// Una barra que se puede cambiar desde la prueba, con su RepaintBoundary para contar píxeles.
Widget _barra(ValueNotifier<double> valor, {int segmentos = 10}) => ValueListenableBuilder<double>(
  valueListenable: valor,
  builder: (context, v, _) => RepaintBoundary(
    child: SizedBox(
      width: 300,
      child: BarraPixel(valor: v, segmentos: segmentos),
    ),
  ),
);

Future<int> _amarillos(WidgetTester tester) => contarPixeles(tester, find.byType(BarraPixel), ColoresUiPixel.amarillo);

void main() {
  testWidgets('el lector la lee con su porcentaje, o con el texto que se le dé', (tester) async {
    await montar(tester, const BarraPixel(valor: 0.4));
    expect(tester.getSemantics(find.bySemanticsLabel('Progreso')), isSemantics(label: 'Progreso', value: '40 %'));
    await montar(tester, const BarraPixel(valor: 0.3, etiqueta: 'Progreso del caso', textoValor: '3 de 10 escenas'));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Progreso del caso')),
      isSemantics(label: 'Progreso del caso', value: '3 de 10 escenas'),
    );
  });

  testWidgets('los valores fuera de rango se quedan entre 0 y 100 %', (tester) async {
    for (final (valor, texto) in [(1.5, '100 %'), (-1.0, '0 %'), (double.nan, '0 %')]) {
      await montar(tester, BarraPixel(valor: valor));
      expect(tester.getSemantics(find.bySemanticsLabel('Progreso')), isSemantics(value: texto), reason: '$valor');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('cuanto más valor, más relleno; vacía no pinta amarillo', (tester) async {
    final valor = ValueNotifier(0.0);
    addTearDown(valor.dispose);
    await montar(tester, _barra(valor), reducir: true);
    expect(await _amarillos(tester), 0);
    valor.value = 0.5;
    await tester.pump();
    final mitad = await _amarillos(tester);
    valor.value = 1;
    await tester.pump();
    final llena = await _amarillos(tester);
    expect(mitad, greaterThan(0));
    expect(llena / mitad, closeTo(2, 0.15));
  });

  testWidgets('al cambiar el valor, el relleno avanza poco a poco, con la punta encendida', (tester) async {
    final valor = ValueNotifier(0.2);
    addTearDown(valor.dispose);
    await montar(tester, _barra(valor));
    final antes = await _amarillos(tester);
    valor.value = 0.8;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.binding.hasScheduledFrame, isTrue);
    final medio = await _amarillos(tester);
    // Mientras sube, la punta del relleno brilla en blanco.
    expect(await contarPixeles(tester, find.byType(BarraPixel), ColoresUiPixel.blanco), greaterThan(0));
    await tester.pumpAndSettle();
    final despues = await _amarillos(tester);
    expect(medio, greaterThan(antes));
    expect(despues, greaterThan(medio));
    expect(despues / antes, closeTo(4, 0.4));
    expect(await contarPixeles(tester, find.byType(BarraPixel), ColoresUiPixel.blanco), 0);
    // El lector de pantalla tiene el valor nuevo desde el principio.
    expect(tester.getSemantics(find.bySemanticsLabel('Progreso')), isSemantics(value: '80 %'));
  });

  testWidgets('con «reducir animaciones», salta al valor nuevo sin animar', (tester) async {
    final valor = ValueNotifier(0.2);
    addTearDown(valor.dispose);
    await montar(tester, _barra(valor), reducir: true);
    final antes = await _amarillos(tester);
    valor.value = 0.8;
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(await _amarillos(tester) / antes, closeTo(4, 0.4));
  });

  testWidgets('también baja (sin la punta encendida)', (tester) async {
    final valor = ValueNotifier(1.0);
    addTearDown(valor.dispose);
    await montar(tester, _barra(valor));
    final llena = await _amarillos(tester);
    valor.value = 0.5;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(await contarPixeles(tester, find.byType(BarraPixel), ColoresUiPixel.blanco), 0);
    await tester.pumpAndSettle();
    expect(await _amarillos(tester) / llena, closeTo(0.5, 0.05));
  });

  testWidgets('los segmentos van separados por huecos de una unidad', (tester) async {
    final valor = ValueNotifier(1.0);
    addTearDown(valor.dispose);
    await montar(tester, _barra(valor, segmentos: 5), reducir: true);
    final cinco = await _amarillos(tester);
    await montar(tester, _barra(valor, segmentos: 10), reducir: true);
    final diez = await _amarillos(tester);
    // Con más segmentos hay más huecos, así que algo menos de amarillo.
    expect(diez, lessThan(cinco));
  });

  testWidgets('se quita a mitad de la animación sin dejar nada vivo', (tester) async {
    final valor = ValueNotifier(0.0);
    addTearDown(valor.dispose);
    await montar(tester, _barra(valor));
    valor.value = 1;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await desmontar(tester);
  });

  testWidgets('los segmentos que faltan son huecos con borde azul claro: se ve cuántos faltan y cuántos hay', (
    tester,
  ) async {
    final valor = ValueNotifier(0.0);
    addTearDown(valor.dispose);
    await montar(tester, _barra(valor, segmentos: 5), reducir: true);
    final vacia = await contarPixeles(tester, find.byType(BarraPixel), ColoresUiPixel.azulClaro);
    expect(vacia, greaterThan(0));
    valor.value = 0.6;
    await tester.pump();
    final aMedias = await contarPixeles(tester, find.byType(BarraPixel), ColoresUiPixel.azulClaro);
    // Quedan dos huecos de cinco.
    expect(aMedias / vacia, closeTo(0.4, 0.05));
    valor.value = 1;
    await tester.pump();
    expect(await contarPixeles(tester, find.byType(BarraPixel), ColoresUiPixel.azulClaro), 0);
  });

  testWidgets('sobre el azul noche del juego lleva filo (y ocupa una unidad más por cada lado)', (tester) async {
    await montar(tester, const SizedBox(width: 300, child: BarraPixel(valor: 0.5)));
    final sinFilo = tester.getSize(find.byType(BarraPixel));
    await montar(
      tester,
      const FondoPixel(
        color: ColoresUiPixel.noche,
        child: SizedBox(width: 300, child: RepaintBoundary(child: BarraPixel(valor: 0.5))),
      ),
    );
    expect(tester.getSize(find.byType(BarraPixel)).height, sinFilo.height + 6);
    expect(await contarPixeles(tester, find.byType(BarraPixel), ColoresUiPixel.azul), greaterThan(0));
  });

  testWidgets('sin ancho fijo (en una fila sin límite) no rompe nada', (tester) async {
    await montar(tester, const SingleChildScrollView(scrollDirection: Axis.horizontal, child: BarraPixel(valor: 0.5)));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(BarraPixel)).width, greaterThan(0));
  });
}
