import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/motor/motor.dart';

import 'ayudantes.dart';

void main() {
  setUp(() => RelojPixel.debugEnMarcha = 0);

  const tableroFilas = ['NYNY', 'YNYN', 'NYNY', 'AAAA'];
  final tablero = Sprite('tablero', tableroFilas);
  final semaforo = Sprite.animado('semáforo', [
    ['A'],
    ['Y'],
  ], animacion: const AnimacionPixel([PasoPixel(0, ms: 1000), PasoPixel(1, ms: 200)]));

  /// Comprueba píxel a píxel que [lamina] es el dibujo [filas] a [k] píxeles físicos por píxel, con la esquina en
  /// ([x0], [y0]), y papel alrededor: si hubiera suavizado, saldrían colores mezclados en los bordes.
  void esNitido(Lamina lamina, List<String> filas, {required int k, required int x0, required int y0}) {
    final papel = PaletaPixel.papel.color;
    for (var y = 0; y < lamina.alto; y++) {
      for (var x = 0; x < lamina.ancho; x++) {
        final i = (x - x0) ~/ k;
        final j = (y - y0) ~/ k;
        final dentro = x >= x0 && y >= y0 && j < filas.length && i < filas[j].length;
        final esperado = dentro ? colorDe(filas[j][i]) : papel;
        if (lamina.en(x, y) != esperado) fail('El píxel ($x, $y) es ${lamina.en(x, y)}, no $esperado.');
      }
    }
  }

  group('tamaño y escala', () {
    testWidgets('con ancho y alto: escala entera de píxeles físicos, centrado y nítido', (tester) async {
      await montar(tester, SpritePixel(sprite: tablero, ancho: 104, alto: 104), dpr: 2.75);
      expect(tester.getSize(find.byType(SpritePixel)), const Size(104, 104));
      final lamina = await leerPixeles(tester);
      expect((lamina.ancho, lamina.alto), (286, 286));
      // 286 píxeles físicos: caben 71 por cada uno de los 4 del dibujo (284) y sobra 1 a cada lado.
      esNitido(lamina, tableroFilas, k: 71, x0: 1, y0: 1);
    });

    testWidgets('a otra densidad, otra escala entera', (tester) async {
      await montar(tester, SpritePixel(sprite: tablero, ancho: 48, alto: 48), dpr: 2.625);
      final lamina = await leerPixeles(tester);
      // 48 puntos son 126 píxeles: caben 31 por píxel (124) y sobra 1 a cada lado.
      expect(lamina.ancho, 126);
      esNitido(lamina, tableroFilas, k: 31, x0: 1, y0: 1);
    });

    testWidgets('con solo el alto, el ancho sale de la proporción', (tester) async {
      await montar(tester, SpritePixel(sprite: Sprite('alto', List.filled(4, 'NN')), alto: 64));
      expect(tester.getSize(find.byType(SpritePixel)), const Size(32, 64));
      await montar(tester, SpritePixel(sprite: Sprite('alto', List.filled(4, 'NN')), ancho: 64));
      expect(tester.getSize(find.byType(SpritePixel)), const Size(64, 128));
    });

    testWidgets('si el padre le obliga, ocupa ese sitio', (tester) async {
      await montar(tester, SizedBox(width: 200, height: 50, child: SpritePixel(sprite: tablero)), dpr: 2);
      expect(tester.getSize(find.byType(SpritePixel)), const Size(200, 50));
      final lamina = await leerPixeles(tester);
      // 100 píxeles físicos de alto: 25 por píxel; a lo ancho sobran 300 (150 a cada lado).
      esNitido(lamina, tableroFilas, k: 25, x0: 150, y0: 0);
    });

    testWidgets('si el padre le deja elegir, 4 puntos por píxel', (tester) async {
      await montar(tester, SpritePixel(sprite: tablero));
      expect(tester.getSize(find.byType(SpritePixel)), const Size(16, 16));
    });

    testWidgets('en espejo, dado la vuelta', (tester) async {
      await montar(tester, SpritePixel(sprite: Sprite('flecha', ['NY']), ancho: 20, alto: 10, espejo: true), dpr: 1);
      esNitido(await leerPixeles(tester), ['YN'], k: 10, x0: 0, y0: 0);
    });

    testWidgets('la alineación lo coloca dentro de su sitio', (tester) async {
      await montar(
        tester,
        SpritePixel(sprite: Sprite('punto', ['N']), ancho: 10, alto: 30, alineacion: Alignment.bottomCenter),
        dpr: 1,
      );
      esNitido(await leerPixeles(tester), ['N'], k: 10, x0: 0, y0: 20);
    });
  });

  group('animación en reposo', () {
    testWidgets('cambia de fotograma a su tiempo', (tester) async {
      await montar(tester, SpritePixel(sprite: semaforo, ancho: 10, alto: 10), dpr: 1);
      expect(RelojPixel.debugEnMarcha, 1);
      expect((await leerPixeles(tester)).en(5, 5), colorDe('A'));
      await tester.pump(const Duration(milliseconds: 1000));
      expect((await leerPixeles(tester)).en(5, 5), colorDe('Y'));
      await tester.pump(const Duration(milliseconds: 200));
      expect((await leerPixeles(tester)).en(5, 5), colorDe('A'));
    });

    testWidgets('no pide fotogramas sin parar: pumpAndSettle termina', (tester) async {
      await montar(tester, SpritePixel(sprite: semaforo, ancho: 10, alto: 10));
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpAndSettle();
      expect(RelojPixel.debugEnMarcha, 1);
    });

    testWidgets('el balanceo sube el dibujo un píxel sin salirse de su sitio', (tester) async {
      final globo = Sprite.animado('globo', [
        ['A'],
      ], animacion: AnimacionPixel.balanceo(ms: 500));
      await montar(tester, SpritePixel(sprite: globo, ancho: 10, alto: 20), dpr: 1);
      // Se encaja con una fila de más arriba para el balanceo: 10 píxeles por píxel, el globo abajo.
      esNitido(await leerPixeles(tester), ['P', 'A'], k: 10, x0: 0, y0: 0);
      await tester.pump(const Duration(milliseconds: 500));
      esNitido(await leerPixeles(tester), ['A', 'P'], k: 10, x0: 0, y0: 0);
    });

    testWidgets('con «reducir animaciones» se queda quieto en la pose de descanso', (tester) async {
      await montar(tester, SpritePixel(sprite: semaforo, ancho: 10, alto: 10), dpr: 1, reducir: true);
      expect(RelojPixel.debugEnMarcha, 0);
      await tester.pump(const Duration(seconds: 3));
      expect((await leerPixeles(tester)).en(5, 5), colorDe('A'));
      expect(tester.binding.hasScheduledFrame, isFalse);

      // Si se vuelve a permitir, se pone en marcha.
      await montar(tester, SpritePixel(sprite: semaforo, ancho: 10, alto: 10), dpr: 1);
      expect(RelojPixel.debugEnMarcha, 1);
      await tester.pump(const Duration(milliseconds: 1000));
      expect((await leerPixeles(tester)).en(5, 5), colorDe('Y'));

      // Y al pedir reducirlas a mitad de un paso, vuelve al descanso.
      await montar(tester, SpritePixel(sprite: semaforo, ancho: 10, alto: 10), dpr: 1, reducir: true);
      expect(RelojPixel.debugEnMarcha, 0);
      expect((await leerPixeles(tester)).en(5, 5), colorDe('A'));
    });

    testWidgets('con animar: false, tampoco se mueve', (tester) async {
      await montar(tester, SpritePixel(sprite: semaforo, ancho: 10, alto: 10, animar: false), dpr: 1);
      expect(RelojPixel.debugEnMarcha, 0);
      await tester.pump(const Duration(seconds: 3));
      expect((await leerPixeles(tester)).en(5, 5), colorDe('A'));
    });

    testWidgets('fuera de la vista (TickerMode apagado) se para', (tester) async {
      Widget conModo(bool activo) => TickerMode(
        enabled: activo,
        child: SpritePixel(sprite: semaforo, ancho: 10, alto: 10),
      );
      await montar(tester, conModo(false));
      expect(RelojPixel.debugEnMarcha, 0);
      await montar(tester, conModo(true));
      expect(RelojPixel.debugEnMarcha, 1);
      await montar(tester, conModo(false));
      expect(RelojPixel.debugEnMarcha, 0);
    });

    testWidgets('un sprite sin animación no crea reloj', (tester) async {
      await montar(tester, SpritePixel(sprite: tablero, ancho: 10, alto: 10));
      expect(RelojPixel.debugEnMarcha, 0);
    });

    testWidgets('al cambiar de sprite cambia de reloj y deja el viejo parado', (tester) async {
      await montar(tester, SpritePixel(sprite: semaforo, ancho: 10, alto: 10));
      expect(RelojPixel.debugEnMarcha, 1);
      await montar(tester, SpritePixel(sprite: tablero, ancho: 10, alto: 10));
      expect(RelojPixel.debugEnMarcha, 0);
      await montar(tester, SpritePixel(sprite: semaforo, ancho: 10, alto: 10, desfaseMs: 500));
      expect(RelojPixel.debugEnMarcha, 1);
    });

    testWidgets('al quitarlo, el reloj se para y no queda nada pendiente', (tester) async {
      await montar(tester, SpritePixel(sprite: semaforo, ancho: 10, alto: 10));
      expect(RelojPixel.debugEnMarcha, 1);
      await tester.pumpWidget(const SizedBox());
      expect(RelojPixel.debugEnMarcha, 0);
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('accesibilidad', () {
    testWidgets('con etiqueta es una imagen con nombre', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, SpritePixel(sprite: tablero, etiqueta: 'La jueza'));
      expect(tester.getSemantics(find.bySemanticsLabel('La jueza')), isSemantics(label: 'La jueza', isImage: true));
      semantica.dispose();
    });

    testWidgets('sin etiqueta es decorativo', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, SpritePixel(sprite: tablero));
      expect(find.bySemanticsLabel(RegExp('.')), findsNothing);
      semantica.dispose();
    });
  });
}
