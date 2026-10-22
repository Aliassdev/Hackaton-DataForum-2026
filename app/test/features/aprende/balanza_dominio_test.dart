import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/justicia/balanza_dominio.dart';

// La balanza del dominio (BKT): 14° × (1 − avance), muelle de ~900 ms y, con «reducir animaciones», el ángulo final.

Future<void> _montar(WidgetTester tester, Widget balanza) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: temaTuTurno(Brightness.light),
      home: Center(child: balanza),
    ),
  );
}

double _inclinacion(WidgetTester tester) =>
    tester.state<EstadoBalanzaDominio>(find.byType(BalanzaDominio)).inclinacionActual;

void main() {
  test('inclinación: 14° sin practicar, recta al dominarlo, y nunca fuera de rango', () {
    expect(BalanzaDominio.inclinacion(0), 14);
    expect(BalanzaDominio.inclinacion(0.5), 7);
    expect(BalanzaDominio.inclinacion(1), 0);
    expect(BalanzaDominio.inclinacion(-1), 14);
    expect(BalanzaDominio.inclinacion(2), 0);
  });

  test('estados: se inclina un poco, casi en equilibrio y en equilibrio', () {
    expect(BalanzaDominio.estado(0), 'Se inclina un poco');
    expect(BalanzaDominio.estado(0.5), 'Se inclina un poco');
    expect(BalanzaDominio.estado(0.7), 'Casi en equilibrio');
    expect(BalanzaDominio.estado(1), 'En equilibrio: lo dominas');
  });

  testWidgets('sin «desde», aparece ya en su sitio', (tester) async {
    await _montar(tester, const BalanzaDominio(avance: 0.25));
    expect(_inclinacion(tester), 10.5);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_inclinacion(tester), 10.5, reason: 'no se mueve');
  });

  testWidgets('al mejorar, el brazo oscila con un muelle y se queda recto; avisa una vez al equilibrarse', (
    tester,
  ) async {
    var avisos = 0;
    await _montar(tester, BalanzaDominio(avance: 1, desde: 0, alEquilibrar: () => avisos++));
    expect(_inclinacion(tester), 14);
    var minimo = 14.0;
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      minimo = _inclinacion(tester) < minimo ? _inclinacion(tester) : minimo;
    }
    expect(minimo, lessThan(0), reason: 'se pasa un poco y vuelve: oscila');
    expect(minimo, greaterThan(-5), reason: 'oscilaciones pequeñas');
    await tester.pumpAndSettle();
    expect(_inclinacion(tester), closeTo(0, 0.05));
    expect(avisos, 1);
    // Tarda lo que el muelle: alrededor de 900 ms.
    expect(BalanzaDominio.duracionMuelle, const Duration(milliseconds: 900));
  });

  testWidgets('el muelle se para en torno a los 900 ms', (tester) async {
    await _montar(tester, const BalanzaDominio(avance: 1, desde: 0));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(_inclinacion(tester).abs(), lessThan(0.3));
  });

  testWidgets('con «reducir animaciones», el ángulo final directo, sin oscilar, y avisa igual', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    var avisos = 0;
    await _montar(tester, BalanzaDominio(avance: 1, desde: 0, alEquilibrar: () => avisos++));
    expect(_inclinacion(tester), 0);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(avisos, 1);
  });

  testWidgets('al cambiar el avance, va al nuevo ángulo; si ya estaba recta, no vuelve a avisar', (tester) async {
    var avisos = 0;
    await _montar(tester, BalanzaDominio(avance: 0.5, alEquilibrar: () => avisos++));
    expect(_inclinacion(tester), 7);
    await _montar(tester, BalanzaDominio(avance: 1, alEquilibrar: () => avisos++));
    await tester.pumpAndSettle();
    expect(_inclinacion(tester), closeTo(0, 0.05));
    expect(avisos, 1);
    await _montar(tester, BalanzaDominio(avance: 1, alEquilibrar: () => avisos++));
    await tester.pumpAndSettle();
    expect(avisos, 1);
  });

  testWidgets('es decorativa por defecto; si no, dice cómo está', (tester) async {
    final semantica = tester.ensureSemantics();
    await _montar(tester, const BalanzaDominio(avance: 0.2));
    expect(find.bySemanticsLabel(RegExp('Balanza')), findsNothing);
    await _montar(tester, const BalanzaDominio(avance: 1, decorativo: false));
    expect(find.bySemanticsLabel('Balanza: En equilibrio: lo dominas'), findsOneWidget);
    semantica.dispose();
  });
}
