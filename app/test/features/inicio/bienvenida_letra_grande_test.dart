// La bienvenida con la letra muy grande y las fuentes de verdad (Nunito y MaryKate): con la letra de las pruebas, cada
// letra es un cuadrado mucho más ancho que la real, y no se puede ver si un texto de una línea cabe de verdad.
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/features/inicio/bienvenida.dart';
import 'package:tuturno/widgets/fuente_chip.dart';
import 'package:tuturno/widgets/justicia/fondo_justicia.dart';

import '../../fuentes_reales.dart';
import '../a1/helpers.dart';

void main() {
  setUpAll(cargarFuentesReales);

  for (final escala in [1.3, 1.6]) {
    testWidgets('con la letra a $escala en un móvil pequeño, la fuente del derecho a que te escuchen se lee entera', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = escala;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await arrancarApp(tester, bienvenidaVista: false, tamano: const Size(360, 640));
      expect(find.byType(FondoJusticia), findsOneWidget);
      await tester.ensureVisible(find.byType(FuenteChip));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(textoDerechoASerOido), findsOneWidget);
      final etiqueta = tester.renderObject<RenderParagraph>(find.text('LO 1/1996 · art. 9.1'));
      expect(etiqueta.didExceedMaxLines, isFalse, reason: 'sin «…»');
      // El chip no se sale de la página.
      expect(tester.getRect(find.byType(FuenteChip)).right, lessThanOrEqualTo(360));
    });
  }
}
