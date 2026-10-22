import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/widgets/movimiento/movimiento.dart';

import 'entorno.dart';

void main() {
  group('TicketBorder', () {
    const rect = Rect.fromLTWH(0, 0, 300, 100);

    test('apaisado: las muescas van arriba y abajo, en la línea de corte del talón', () {
      const forma = TicketBorder(talon: 80);
      final path = forma.getOuterPath(rect);
      expect(forma.corte(rect), 220);
      expect(path.contains(const Offset(220, 3)), isFalse, reason: 'muesca de arriba');
      expect(path.contains(const Offset(220, 97)), isFalse, reason: 'muesca de abajo');
      expect(path.contains(const Offset(220, 50)), isTrue, reason: 'papel entre las muescas');
      expect(path.contains(const Offset(150, 2)), isTrue, reason: 'borde de arriba, lejos de la muesca');
      expect(path.contains(const Offset(1, 1)), isFalse, reason: 'esquina redondeada');
      expect(forma.rectTalon(rect), const Rect.fromLTRB(220, 0, 300, 100));
    });

    test('vertical: las muescas van a los lados', () {
      const forma = TicketBorder(ladoTalon: LadoTalon.abajo, talon: 30);
      final path = forma.getOuterPath(rect);
      expect(forma.corte(rect), 70);
      expect(path.contains(const Offset(3, 70)), isFalse);
      expect(path.contains(const Offset(297, 70)), isFalse);
      expect(path.contains(const Offset(150, 70)), isTrue);
    });

    test('sin talón, las muescas van en el centro; un talón que no cabe se ajusta', () {
      expect(const TicketBorder().corte(rect), 150);
      // Como mucho hasta donde empiezan la esquina y la muesca (18 + 10).
      expect(const TicketBorder(talon: 1000).corte(rect), 28);
      expect(const TicketBorder(talon: 0).corte(rect), 272);
    });

    test('escala, mezcla, copia e igualdad', () {
      const a = TicketBorder(talon: 80);
      expect(a.scale(0.5), const TicketBorder(radio: 9, radioMuesca: 5, talon: 40));
      expect(a.copyWith(talon: 60).talon, 60);
      expect(TicketBorder.lerp(a, const TicketBorder(talon: 40), 0.5).talon, 60);
      expect(a.lerpTo(const TicketBorder(talon: 40), 0.5), const TicketBorder(talon: 60));
      expect(a.lerpFrom(const TicketBorder(talon: 40), 0.5), const TicketBorder(talon: 60));
      expect(a, const TicketBorder(talon: 80));
      expect(a.hashCode, const TicketBorder(talon: 80).hashCode);
      expect(a == const TicketBorder(talon: 81), isFalse);
      expect(a.dimensions, EdgeInsets.zero);
    });

    testWidgets('se pinta con talón de color, perforado y contorno, en las dos orientaciones', (tester) async {
      for (final lado in LadoTalon.values) {
        await montar(
          tester,
          SizedBox(
            width: 300,
            height: 100,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: TicketBorder(
                  talon: 40,
                  ladoTalon: lado,
                  colorTalon: Colors.yellow,
                  side: const BorderSide(width: 3, strokeAlign: BorderSide.strokeAlignOutside),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$lado');
      }
    });
  });

  group('TicketTuTurno', () {
    testWidgets('muestra etiqueta, título, descripción y número; se lee y se pulsa como un botón', (tester) async {
      final semantica = tester.ensureSemantics();
      final vibraciones = registrarVibraciones(tester);
      var pulsado = 0;
      await montar(
        tester,
        SizedBox(
          width: 360,
          child: TicketTuTurno(
            etiqueta: 'Tu turno',
            titulo: 'Vive el caso',
            descripcion: 'Juega un caso.',
            numero: '07',
            onTap: () => pulsado++,
          ),
        ),
      );
      expect(find.text('TU TURNO'), findsOneWidget);
      expect(find.text('Vive el caso'), findsOneWidget);
      expect(find.text('07'), findsOneWidget);
      // Mide lo que su contenido, no toda la pantalla.
      expect(tester.getSize(find.byType(TicketTuTurno)).height, lessThan(300));

      // Todo el ticket es un solo botón que se lee entero.
      final nodo = tester.getSemantics(find.text('Vive el caso'));
      expect(nodo, isSemantics(isButton: true, hasTapAction: true));
      final etiqueta = nodo.getSemanticsData().label;
      expect(etiqueta, allOf(contains('TU TURNO'), contains('Vive el caso'), contains('Juega un caso.')));
      expect(etiqueta, contains('Nº 07'));

      await tester.tap(find.text('Vive el caso'));
      await tester.pumpAndSettle();
      expect(pulsado, 1);
      expect(vibraciones, ['HapticFeedbackType.lightImpact']);
      semantica.dispose();
    });

    testWidgets('se hunde al mantenerlo pulsado y deja de estarlo si el dedo acaba desplazando la lista', (
      tester,
    ) async {
      var pulsado = 0;
      await montar(
        tester,
        SizedBox(
          height: 400,
          child: ListView(
            children: [
              TicketTuTurno(titulo: 'Vive el caso', numero: '01', onTap: () => pulsado++),
              const SizedBox(height: 1200),
            ],
          ),
        ),
      );
      double escala() => tester
          .widget<AnimatedScale>(find.descendant(of: find.byType(TicketTuTurno), matching: find.byType(AnimatedScale)))
          .scale;
      expect(escala(), 1);

      final gesto = await tester.startGesture(tester.getCenter(find.text('Vive el caso')));
      await tester.pump(const Duration(milliseconds: 150));
      expect(escala(), lessThan(1), reason: 'mantenido pulsado');

      await gesto.moveBy(const Offset(0, -80));
      await tester.pump();
      expect(escala(), 1, reason: 'el toque se ha convertido en un desplazamiento');
      await gesto.up();
      await tester.pumpAndSettle();
      expect(pulsado, 0);
    });

    testWidgets('sin onTap no es un botón; semanticLabel sustituye a todo', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(
        tester,
        const SizedBox(
          width: 360,
          child: TicketTuTurno(titulo: 'Misión del día', numero: '3', semanticLabel: 'Misión del día, turno 3'),
        ),
      );
      expect(find.bySemanticsLabel('Misión del día, turno 3'), findsOneWidget);
      expect(tester.getSemantics(find.byType(TicketTuTurno)), isSemantics(isButton: false));
      semantica.dispose();
    });

    testWidgets('el texto tiene contraste AA en claro y en oscuro', (tester) async {
      final semantica = tester.ensureSemantics();
      for (final brillo in Brightness.values) {
        await montar(
          tester,
          brillo: brillo,
          const SizedBox(
            width: 360,
            child: TicketTuTurno(
              etiqueta: 'Tu turno',
              titulo: 'Aprende',
              descripcion: 'Lecciones cortas.',
              numero: '12',
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline), reason: '$brillo');
      }
      semantica.dispose();
    });

    testWidgets('cabe con la letra a 1,3 × 1,3 en un móvil pequeño, con el talón a la derecha y abajo', (tester) async {
      for (final lado in LadoTalon.values) {
        // En una lista, como en las pantallas (con letra tan grande, el ticket crece hacia abajo).
        await montar(
          tester,
          escalaTexto: 1.69,
          SingleChildScrollView(
            child: SizedBox(
              width: 320,
              child: TicketTuTurno(
                etiqueta: 'Misión del día',
                titulo: 'Descubre tus derechos',
                descripcion: 'Tres preguntas rápidas.',
                numero: '128',
                ladoTalon: lado,
                onTap: () {},
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$lado');
      }
    });

    testWidgets('acepta un talón propio, icono, inclinación y contorno, con zona táctil grande', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(
        tester,
        SizedBox(
          width: 360,
          child: TicketTuTurno(
            titulo: 'Pasaporte',
            icono: const Icon(Icons.badge_rounded),
            talon: const ContadorFlip(valor: 3, digitos: 2),
            inclinacion: -0.02,
            contorno: Colors.white,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ContadorFlip), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      semantica.dispose();
    });
  });
}
