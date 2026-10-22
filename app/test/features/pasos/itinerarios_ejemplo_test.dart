import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/entrada.dart';
import 'package:tuturno/features/pasos/fuentes_paso.dart';
import 'package:tuturno/features/pasos/pasos.dart';

import 'datos.dart';

// Los itinerarios que lleva la app de verdad (assets/content/itinerarios, o assets/mock/content/itinerarios mientras
// content/ esté vacío), como los verá quien use la app: sin borradores. Cada papel tiene que tener su fichero, con
// todos los pasos validados y con fuente, y la línea de pasos los tiene que pintar bien en las condiciones difíciles.
// Si falla, la demo enseñaría «Todavía no tengo los pasos para este papel» o se comería pasos.

void main() {
  final roles = [
    for (final rol in RolEntrada.values)
      if (rol != RolEntrada.noLoSe) rol.valor,
  ];

  for (final rol in roles) {
    testWidgets(
      'el itinerario de «$rol» de la app se enseña entero y se pinta bien con letra a 1,3, en oscuro y a 320 px',
      (tester) async {
        final repo = repoDeLaApp();
        final crudo = await repo.json('$carpetaItinerarios/$rol.json');
        expect(
          crudo,
          isA<Map<String, dynamic>>(),
          reason: 'falta $carpetaItinerarios/$rol.json en el contenido de la app',
        );
        final pasosJson = (crudo! as Map<String, dynamic>)['pasos'];
        expect(pasosJson, isA<List<Object?>>(), reason: '$carpetaItinerarios/$rol.json no tiene una lista de pasos');
        final esperados = (pasosJson! as List<Object?>).length;

        // Cada cita de una ley o de un organismo dice el artículo o el apartado, y la app conoce su nombre fácil.
        for (final paso in Itinerario.tryParse(crudo, rol: rol)!.pasos) {
          for (final cita in CitaPaso.de(paso.fuentes)) {
            if (cita.esTarjeta) continue;
            expect(cita.detalle, isNotEmpty, reason: '$rol ${paso.id}: «${cita.original}» no dice el artículo');
            expect(nombreFacilDeNorma(cita.norma), isNotNull, reason: '$rol ${paso.id}: no se conoce «${cita.norma}»');
          }
        }

        await montarLinea(
          tester,
          repo: repo,
          rol: rol,
          faseActual: Fase.durante,
          escalaTexto: 1.3,
          brillo: Brightness.dark,
          tamano: const Size(320, 640),
        );

        final total = find.bySemanticsLabel(RegExp(r'^Paso \d+ de \d+: ')).evaluate().length;
        expect(
          total,
          esperados,
          reason: 'la app no enseña todos los pasos de $carpetaItinerarios/$rol.json: sin validar o sin fuente',
        );
        for (var numero = 1; numero <= total; numero++) {
          final paso = find.bySemanticsLabel(RegExp('^Paso $numero de $total: '));
          await tester.ensureVisible(paso);
          await tester.pumpAndSettle();
          await tester.tap(paso);
          await tester.pumpAndSettle();
          expect(tester.getSemantics(paso), isSemantics(isExpanded: true), reason: 'paso $numero de $rol');
        }

        expect(find.byType(ChipFuentePaso), findsWidgets);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      },
    );
  }
}
