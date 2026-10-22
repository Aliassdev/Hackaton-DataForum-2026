import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/ui/ui.dart';

import 'ayudantes.dart';

// El sello «COMPLETADO» del final de un caso: cae una vez, golpea (vibración fuerte) y se queda. Con «reducir
// animaciones», aparece ya puesto.

void main() {
  testWidgets('mide lo que pide su dibujo y cabe en una pantalla estrecha (con la celda más pequeña)', (tester) async {
    await montar(tester, const SelloPixel(), reducir: true);
    final columnas = SelloPixel.columnas('COMPLETADO');
    expect(columnas, greaterThan(60));
    final tamano = tester.getSize(find.byType(SelloPixel));
    expect(tamano.width / columnas, closeTo(tamano.height / SelloPixel.filas, 0.001), reason: 'celdas cuadradas');
    expect(tamano.width / columnas, 3, reason: 'en un móvil, una celda es una unidad pixel (3)');

    await montar(tester, const SizedBox(width: 150, child: SelloPixel()), reducir: true);
    expect(tester.getSize(find.byType(SelloPixel)).width, lessThanOrEqualTo(150));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cae, golpea una sola vez (vibra fuerte) y se queda puesto', (tester) async {
    final vibraciones = registrarVibraciones(tester);
    var golpes = 0;
    await montar(tester, SelloPixel(alEstampar: () => golpes++));

    // Antes del retraso, el papel está limpio.
    expect(await contarPixeles(tester, find.byType(SelloPixel), ColoresUiPixel.azul), 0);
    expect(golpes, 0);

    await tester.pump(DuracionSelloPixel.retraso);
    await tester.pump(const Duration(milliseconds: 100));
    expect(golpes, 0, reason: 'aún está cayendo');

    await tester.pumpAndSettle();
    expect(golpes, 1);
    expect(vibraciones, ['HapticFeedbackType.heavyImpact']);
    expect(await contarPixeles(tester, find.byType(SelloPixel), ColoresUiPixel.azul), greaterThan(100));

    await tester.pump(const Duration(seconds: 3));
    expect(golpes, 1, reason: 'nunca en bucle');
    await desmontar(tester);
  });

  testWidgets('con «reducir animaciones» aparece ya puesto y vibra una vez', (tester) async {
    final vibraciones = registrarVibraciones(tester);
    var golpes = 0;
    await montar(tester, SelloPixel(alEstampar: () => golpes++), reducir: true);
    await tester.pump();

    expect(await contarPixeles(tester, find.byType(SelloPixel), ColoresUiPixel.azul), greaterThan(100));
    expect(golpes, 1);
    expect(vibraciones, ['HapticFeedbackType.heavyImpact']);
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'nada se mueve');
    await desmontar(tester);
  });

  testWidgets('el lector de pantalla lo lee como una imagen con su texto', (tester) async {
    final semantica = tester.ensureSemantics();
    await montar(tester, const SelloPixel(), reducir: true);
    expect(find.bySemanticsLabel('Sello: caso completado'), findsOneWidget);
    semantica.dispose();
  });

  testWidgets('quitarlo a mitad de la caída no deja nada vivo', (tester) async {
    await montar(tester, const SelloPixel());
    await tester.pump(DuracionSelloPixel.retraso);
    await tester.pump(const Duration(milliseconds: 80));
    await desmontar(tester);
  });

  test('los dibujos del kit están bien hechos: filas iguales y solo «#» y «.»', () {
    for (final glifo in GlifoPixel.values) {
      expect(glifo.filas, isNotEmpty, reason: glifo.nombre);
      for (final fila in glifo.filas) {
        expect(fila.length, glifo.ancho, reason: '${glifo.nombre}: «$fila»');
        expect(fila, matches(RegExp(r'^[#.]+$')), reason: glifo.nombre);
      }
    }
    expect({for (final glifo in GlifoPixel.values) glifo.nombre}, hasLength(GlifoPixel.values.length));
  });
}
