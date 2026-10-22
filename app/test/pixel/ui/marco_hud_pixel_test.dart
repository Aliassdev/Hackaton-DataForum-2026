import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/ui/ui.dart';
import 'package:tuturno/widgets/ayuda_button.dart';

import 'ayudantes.dart';

Finder _rotulo(String texto) => find.byWidgetPredicate((widget) => widget is RotuloPixel && widget.texto == texto);

void main() {
  group('MarcoPixel', () {
    testWidgets('enmarca la escena: la recorta con esquinas de pixel dentro de un bisel de 5 unidades', (tester) async {
      await montar(
        tester,
        const SizedBox(
          width: 300,
          child: MarcoPixel(child: SizedBox(key: ValueKey('escena'), height: 150)),
        ),
      );
      final marco = tester.getRect(find.byType(MarcoPixel));
      final escena = tester.getRect(find.byKey(const ValueKey('escena')));
      // La unidad pixel es 3: bisel de 15 puntos (y una unidad más abajo, la sombra). Al pintarse, todo se mueve
      // menos de medio píxel físico para caer en la rejilla de la pantalla (AjustePixel).
      const medioPixel = 0.5 / 3 + 1e-9;
      expect(escena.left - marco.left, closeTo(15, medioPixel));
      expect(marco.right - escena.right, closeTo(15, medioPixel));
      expect(escena.top - marco.top, closeTo(15, medioPixel));
      expect(marco.bottom - escena.bottom, closeTo(18, medioPixel));
      final recorte = tester.widget<ClipPath>(
        find.ancestor(of: find.byKey(const ValueKey('escena')), matching: find.byType(ClipPath)),
      );
      expect(recorte.clipper, isA<RecortePixel>());
      expect(recorte.clipBehavior, Clip.hardEdge, reason: 'sin suavizado');
    });

    testWidgets('con título, una placa encima del borde que el lector anuncia como encabezado', (tester) async {
      await montar(
        tester,
        const SizedBox(
          width: 300,
          child: MarcoPixel(titulo: 'Vive el caso', child: SizedBox(height: 150)),
        ),
      );
      expect(find.text('Vive el caso'), findsOneWidget);
      expect(tester.getSemantics(find.text('Vive el caso')), isSemantics(isHeader: true));
      // La placa queda centrada sobre el marco.
      expect(
        tester.getCenter(find.text('Vive el caso')).dx,
        moreOrLessEquals(tester.getCenter(find.byType(MarcoPixel)).dx, epsilon: 1),
      );
    });

    testWidgets('el recorte escalonado deja fuera las esquinas', (tester) async {
      const recorte = RecortePixel(u: 3, esquina: 2);
      final camino = recorte.getClip(const Size(60, 30));
      expect(camino.contains(const Offset(1, 1)), isFalse, reason: 'la esquina');
      expect(camino.contains(const Offset(7, 1)), isTrue);
      expect(camino.contains(const Offset(1, 7)), isTrue);
      expect(camino.contains(const Offset(30, 15)), isTrue);
      expect(camino.contains(const Offset(59, 29)), isFalse, reason: 'la esquina de abajo');
    });
  });

  group('HudPixel', () {
    Widget hud({VoidCallback? onVolver, List<Widget> acciones = const []}) => HudPixel(
      titulo: 'El caso de Lucía',
      progreso: 0.4,
      textoProgreso: '4 de 10 escenas',
      cartas: 2,
      totalCartas: 5,
      onVolver: onVolver,
      acciones: acciones,
    );

    testWidgets('título, volver, progreso y cartas, cada uno con su semántica', (tester) async {
      var volver = 0;
      await montar(tester, hud(onVolver: () => volver++), centrar: false);
      expect(find.text('El caso de Lucía'), findsOneWidget);
      expect(tester.getSemantics(find.text('El caso de Lucía')), isSemantics(isHeader: true));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Volver')),
        isSemantics(label: 'Volver', isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Progreso del caso')),
        isSemantics(label: 'Progreso del caso', value: '4 de 10 escenas'),
      );
      expect(find.bySemanticsLabel('Cartas conseguidas: 2 de 5'), findsOneWidget);
      // Las cifras van con la letra de rótulo: en Pixelify, «2/5» se leería «2/S».
      expect(_rotulo('2/5'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Volver'));
      await tester.pump();
      expect(volver, 1);
      // El botón de volver mide al menos 48 × 48.
      final boton = tester.getSize(find.byType(BotonPixel));
      expect(boton.width, greaterThanOrEqualTo(48));
      expect(boton.height, greaterThanOrEqualTo(48));
    });

    testWidgets('sin onVolver ni cartas, solo el título y el progreso', (tester) async {
      await montar(tester, const HudPixel(titulo: 'Caso', progreso: 0.5), centrar: false);
      expect(find.byType(BotonPixel), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Cartas')), findsNothing);
      expect(find.byType(BarraPixel), findsOneWidget);
    });

    testWidgets('lleva las acciones de la app arriba a la derecha', (tester) async {
      await montar(
        tester,
        hud(
          onVolver: () {},
          acciones: [IconButton(onPressed: () {}, tooltip: 'Ayuda', icon: const Icon(Icons.support_rounded))],
        ),
        centrar: false,
      );
      final ayuda = tester.getRect(find.byType(IconButton));
      final titulo = tester.getRect(find.text('El caso de Lucía'));
      expect(ayuda.left, greaterThan(titulo.right));
      expect(ayuda.top, lessThan(tester.getRect(find.byType(BarraPixel)).top), reason: 'en la fila de arriba');
    });

    for (final (tamano, escala) in [(const Size(390, 844), 1.0), (const Size(360, 780), 1.3)]) {
      testWidgets('con los botones de verdad (Glosario y Ayuda) caben el título y la barra '
          '(${tamano.width.round()} de ancho, letra $escala)', (tester) async {
        await montar(
          tester,
          hud(onVolver: () {}, acciones: const [GlosarioButton(), AyudaButton()]),
          centrar: false,
          tamano: tamano,
          escalaTexto: escala,
        );
        expect(tester.takeException(), isNull);
        final ancho = tester.getSize(find.byType(HudPixel)).width;
        final titulo = tester.getRect(find.text('El caso de Lucía'));
        final barra = tester.getRect(find.byType(BarraPixel));
        // El título tiene su sitio (si no cabe al lado de los botones, va en su propia fila) y se lee entero.
        final parrafo = tester.renderObject<RenderParagraph>(find.text('El caso de Lucía'));
        expect(parrafo.constraints.maxWidth, greaterThanOrEqualTo(HudPixel.anchoMinimoTitulo));
        expect(parrafo.didExceedMaxLines, isFalse);
        expect(titulo.width, greaterThan(0));
        // La barra, a todo el ancho salvo el contador.
        expect(barra.width, greaterThanOrEqualTo(ancho * 0.5));
        final ayuda = tester.getRect(find.byType(AyudaButton));
        expect(ayuda.right, lessThanOrEqualTo(ancho), reason: 'Ayuda, entera y a la derecha');
        expect(tester.getRect(find.byType(GlosarioButton)).right, lessThanOrEqualTo(ayuda.left));
      });
    }

    testWidgets('con letra grande en un móvil estrecho, el título baja de línea y nada se desborda', (tester) async {
      await montar(tester, hud(onVolver: () {}), centrar: false, escalaTexto: 1.3, tamano: const Size(320, 640));
      expect(tester.takeException(), isNull);
      final titulo = tester.widget<Text>(find.text('El caso de Lucía'));
      expect(titulo.maxLines, 2);
      expect(titulo.overflow, TextOverflow.ellipsis);
    });
  });
}
