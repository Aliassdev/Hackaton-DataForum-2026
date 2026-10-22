import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/motor/motor.dart';

import 'ayudantes.dart';

void main() {
  setUp(() => RelojPixel.debugEnMarcha = 0);

  // Un fondo de 40 × 20 en una caja de 400 × 300 a densidad 2: 20 píxeles físicos (10 puntos) por píxel, así que la
  // escena mide 400 × 200 puntos y queda centrada, con 50 puntos de papel arriba y abajo.
  final fondo = Sprite('fondo', List.filled(20, 'h' * 40));
  final persona = Sprite('persona', List.filled(6, 'AAAA'));
  final otra = Sprite('otra', List.filled(6, 'YYYY'));
  final punto = Sprite('punto', ['N']);
  final ojos = Sprite.animado('ojos', [
    List.filled(6, 'AAAA'),
    List.filled(6, 'RRRR'),
  ], animacion: const AnimacionPixel([PasoPixel(0, ms: 1000), PasoPixel(1, ms: 1000)]));

  Widget escena({
    List<ElementoEscena>? elementos,
    ValueChanged<String>? alPulsar,
    String? descripcion,
    Color? colorMarco,
    bool? contorno = false,
    bool animar = true,
  }) => SizedBox(
    width: 400,
    height: 300,
    child: EscenaPixel(
      fondo: fondo,
      elementos:
          elementos ??
          [
            ElementoEscena(sprite: persona, x: 10, y: 15, id: 'persona', etiqueta: 'Persona'),
            ElementoEscena(sprite: otra, x: 30, y: 15),
          ],
      alPulsar: alPulsar,
      descripcion: descripcion,
      colorMarco: colorMarco,
      contorno: contorno,
      animar: animar,
    ),
  );

  /// Dónde está en la pantalla el punto ([x], [y]) de la caja de la escena.
  Offset en(WidgetTester tester, double x, double y) => tester.getTopLeft(find.byType(EscenaPixel)) + Offset(x, y);

  group('dibujo', () {
    testWidgets('la escena se escala entera, centrada, con márgenes de papel', (tester) async {
      await montar(tester, escena(), dpr: 2);
      final lamina = await leerPixeles(tester);
      expect((lamina.ancho, lamina.alto), (800, 600));
      final papel = PaletaPixel.papel.color.toARGB32();
      expect(lamina.colores(0, 0, 800, 100), {papel});
      expect(lamina.colores(0, 500, 800, 600), {papel});
      // El fondo y, encima, la persona: su sprite de 4 × 6 con los pies en (10, 15) va de (8, 9) a (12, 15).
      expect(lamina.en(5, 105), colorDe('h'));
      expect(lamina.colores(160, 100 + 180, 240, 100 + 300), {colorDe('A').toARGB32()});
      expect(lamina.en(159, 290), colorDe('h'));
      expect(lamina.en(240, 290), colorDe('h'));
      // Cada píxel del dibujo es un bloque de 20 × 20 de un solo color.
      for (var j = 0; j < 20; j++) {
        for (var i = 0; i < 40; i++) {
          final x = i * 20;
          final y = 100 + j * 20;
          expect(lamina.colores(x, y, x + 20, y + 20), hasLength(1), reason: 'píxel ($i, $j)');
        }
      }
    });

    testWidgets('el color de los márgenes se puede cambiar', (tester) async {
      await montar(tester, escena(colorMarco: PaletaPixel.noche.color), dpr: 2);
      final lamina = await leerPixeles(tester);
      expect(lamina.en(400, 20), PaletaPixel.noche.color);
      expect(lamina.en(400, 120), colorDe('h'));
    });

    testWidgets('sobre el papel lleva un contorno azul noche de un píxel; con otro color de margen, no', (
      tester,
    ) async {
      await montar(tester, escena(contorno: null), dpr: 2);
      var lamina = await leerPixeles(tester);
      final noche = PaletaPixel.noche.color;
      // Por dentro de los cuatro bordes del dibujo (de (0, 100) a (800, 500)), un píxel del dibujo: 20 físicos.
      expect(lamina.colores(0, 100, 800, 120), {noche.toARGB32()});
      expect(lamina.colores(0, 480, 800, 500), {noche.toARGB32()});
      expect(lamina.colores(0, 120, 20, 480), {noche.toARGB32()});
      expect(lamina.colores(780, 120, 800, 480), {noche.toARGB32()});
      expect(lamina.en(30, 130), colorDe('h'));
      expect(lamina.en(400, 20), PaletaPixel.papel.color);
      // Con el margen azul noche de un marco, sobra.
      await montar(tester, escena(contorno: null, colorMarco: noche), dpr: 2);
      lamina = await leerPixeles(tester);
      expect(lamina.en(10, 110), colorDe('h'));
      // Y se puede pedir a mano.
      await montar(tester, escena(contorno: true, colorMarco: PaletaPixel.blanco.color), dpr: 2);
      expect((await leerPixeles(tester)).en(10, 110), noche);
    });

    testWidgets('aunque la caja empiece a medio píxel de la pantalla, el dibujo cae en su rejilla', (tester) async {
      // Un tablero en el que cada píxel es distinto de sus vecinos: un píxel de 5 o de 7 se notaría enseguida.
      final tablero = Sprite('tablero', [
        for (var y = 0; y < 20; y++) [for (var x = 0; x < 40; x++) 'NYAr'[(x + 2 * y) % 4]].join(),
      ]);
      for (final (dpr, izquierda, arriba) in [(2.75, 18.0, 7.3), (2.625, 16.4, 9.1), (2.75, 16 + 0.5 / 2.75, 3.0)]) {
        await montar(
          tester,
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.only(left: izquierda, top: arriba),
              child: SizedBox(width: 352, height: 212, child: EscenaPixel(fondo: tablero, contorno: false)),
            ),
          ),
          dpr: dpr,
          centrar: false,
        );
        final lamina = await leerPixeles(tester);
        final papel = PaletaPixel.papel.color;
        final k = EncajePixel(caja: const Size(352, 212), arte: const Size(40, 20), dpr: dpr).fisicos.toInt();
        // Dónde empieza el dibujo: el primer píxel que no es papel, por el medio de la caja.
        final medioX = ((izquierda + 176) * dpr).round(), medioY = ((arriba + 106) * dpr).round();
        var x0 = 0, y0 = 0;
        while (lamina.en(x0, medioY) == papel) {
          x0++;
        }
        while (lamina.en(medioX, y0) == papel) {
          y0++;
        }
        for (var j = 0; j < 20; j++) {
          for (var i = 0; i < 40; i++) {
            final x = x0 + i * k, y = y0 + j * k;
            expect(lamina.colores(x, y, x + k, y + k), {
              colorDe(tablero.fotogramas.first[j][i]).toARGB32(),
            }, reason: 'a densidad $dpr, el píxel ($i, $j) no es un bloque de $k × $k de un solo color');
          }
        }
      }
    });

    testWidgets('en espejo, el sprite se da la vuelta alrededor de su ancla', (tester) async {
      final flecha = Sprite('flecha', List.filled(2, 'NYYY'), ancla: (x: 1, y: 2));
      await montar(tester, escena(elementos: [ElementoEscena(sprite: flecha, x: 10, y: 10, espejo: true)]), dpr: 2);
      final lamina = await leerPixeles(tester);
      // Sin espejo iría de x = 9 a 13; en espejo, de 10 - 3 = 7 a 11, con la N a la derecha.
      expect(lamina.en(7 * 20 + 10, 100 + 9 * 20), colorDe('Y'));
      expect(lamina.en(10 * 20 + 10, 100 + 9 * 20), colorDe('N'));
      expect(lamina.en(11 * 20 + 10, 100 + 9 * 20), colorDe('h'));
    });

    testWidgets('el elemento resaltado lleva el halo amarillo alrededor', (tester) async {
      await montar(tester, escena(elementos: [ElementoEscena(sprite: persona, x: 10, y: 15, resaltado: true)]), dpr: 2);
      final lamina = await leerPixeles(tester);
      // El sprite va de x = 8 a 11; el halo amarillo está en x = 7 y x = 12.
      expect(lamina.en(7 * 20 + 10, 100 + 12 * 20), colorDe('Y'));
      expect(lamina.en(12 * 20 + 10, 100 + 12 * 20), colorDe('Y'));
      expect(lamina.en(8 * 20 + 10, 100 + 12 * 20), colorDe('A'));
    });

    testWidgets('en una columna ocupa todo el ancho y el alto justo', (tester) async {
      await montar(
        tester,
        SizedBox(
          width: 400,
          child: ListView(shrinkWrap: true, children: [EscenaPixel(fondo: fondo)]),
        ),
        dpr: 2,
      );
      expect(tester.getSize(find.byType(EscenaPixel)), const Size(400, 200));
    });

    testWidgets('sin ningún límite, 4 puntos por píxel', (tester) async {
      await montar(tester, UnconstrainedBox(child: EscenaPixel(fondo: fondo)));
      expect(tester.getSize(find.byType(EscenaPixel)), const Size(160, 80));
    });

    testWidgets('sabe su tamaño intrínseco: cabe en un AlertDialog y en un IntrinsicWidth', (tester) async {
      await montar(
        tester,
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AlertDialog(
                title: const Text('Carta nueva'),
                content: EscenaPixel(fondo: fondo),
              ),
            ),
          ),
        ),
        dpr: 2,
      );
      expect(tester.takeException(), isNull);
      final tamano = tester.getSize(find.byType(EscenaPixel));
      // El ancho que deja el diálogo y el alto justo para su escala entera: 20 píxeles del dibujo por cada 40 de ancho.
      expect(tamano.width, greaterThan(100));
      final fisicos = (tamano.width * 2 / 40 + 1e-6).floorToDouble();
      expect(tamano.height, 20 * fisicos / 2);

      // A lo alto de la pantalla (800) cabría a 80 físicos por píxel: más ancha que la pantalla, así que la llena.
      await montar(tester, IntrinsicWidth(child: EscenaPixel(fondo: fondo)), dpr: 2);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(EscenaPixel)), const Size(400, 200));
      await montar(
        tester,
        SizedBox(
          height: 50,
          child: IntrinsicWidth(child: EscenaPixel(fondo: fondo)),
        ),
        dpr: 2,
      );
      expect(tester.getSize(find.byType(EscenaPixel)), const Size(100, 50));
      await montar(
        tester,
        SizedBox(
          width: 400,
          child: IntrinsicHeight(child: EscenaPixel(fondo: fondo)),
        ),
        dpr: 2,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(EscenaPixel)), const Size(400, 200));
    });
  });

  group('toques', () {
    testWidgets('al tocar a alguien llega su id; al tocar el fondo, nada', (tester) async {
      final tocados = <String>[];
      await montar(tester, escena(alPulsar: tocados.add), dpr: 2);
      // La persona ocupa de (80, 140) a (120, 200) en la caja.
      await tester.tapAt(en(tester, 100, 170));
      expect(tocados, ['persona']);
      await tester.tapAt(en(tester, 200, 100));
      // La otra no tiene id: no se puede tocar.
      await tester.tapAt(en(tester, 300, 170));
      expect(tocados, ['persona']);
    });

    testWidgets('si se tapan, gana el que está delante (el último)', (tester) async {
      final tocados = <String>[];
      await montar(
        tester,
        escena(
          alPulsar: tocados.add,
          elementos: [
            ElementoEscena(sprite: persona, x: 10, y: 15, id: 'detras'),
            ElementoEscena(sprite: otra, x: 12, y: 15, id: 'delante'),
          ],
        ),
        dpr: 2,
      );
      await tester.tapAt(en(tester, 110, 170));
      await tester.tapAt(en(tester, 78, 170));
      expect(tocados, ['delante', 'detras']);
    });

    testWidgets('un sprite pequeño tiene una zona de toque de 48 × 48 como mínimo', (tester) async {
      final tocados = <String>[];
      await montar(
        tester,
        escena(
          alPulsar: tocados.add,
          elementos: [ElementoEscena(sprite: punto, x: 30, y: 5, id: 'punto')],
        ),
        dpr: 2,
      );
      // El punto ocupa de (300, 90) a (310, 100): 10 × 10 puntos. Su zona, 48 × 48 alrededor del centro.
      expect(
        tester.getRect(find.descendant(of: find.byType(EscenaPixel), matching: find.byType(GestureDetector))),
        Rect.fromCenter(
          center: tester.getTopLeft(find.byType(EscenaPixel)) + const Offset(305, 95),
          width: 48,
          height: 48,
        ),
      );
      await tester.tapAt(en(tester, 305 + 22, 95 - 22));
      expect(tocados, ['punto']);
      await tester.tapAt(en(tester, 305 + 26, 95));
      expect(tocados, ['punto']);
    });

    testWidgets('sin alPulsar no hay nada que tocar', (tester) async {
      await montar(tester, escena(), dpr: 2);
      expect(find.descendant(of: find.byType(EscenaPixel), matching: find.byType(GestureDetector)), findsNothing);
    });
  });

  group('accesibilidad', () {
    testWidgets('cada personaje que se puede tocar es un botón con su etiqueta', (tester) async {
      final semantica = tester.ensureSemantics();
      final tocados = <String>[];
      await montar(
        tester,
        escena(
          alPulsar: tocados.add,
          descripcion: 'La sala',
          elementos: [
            ElementoEscena(sprite: persona, x: 10, y: 15, id: 'jueza', etiqueta: 'La jueza'),
            ElementoEscena(sprite: otra, x: 30, y: 15, id: 'fiscal'),
            ElementoEscena(sprite: punto, x: 20, y: 5),
          ],
        ),
        dpr: 2,
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('La jueza')),
        isSemantics(label: 'La jueza', isButton: true, hasTapAction: true),
      );
      // Sin etiqueta, se lee el id.
      expect(
        tester.getSemantics(find.bySemanticsLabel('fiscal')),
        isSemantics(label: 'fiscal', isButton: true, hasTapAction: true),
      );
      expect(tester.getSemantics(find.bySemanticsLabel('La sala')), isSemantics(label: 'La sala', isImage: true));
      // El lector de pantalla también puede tocarlo.
      tester.semantics.tap(find.semantics.byLabel('La jueza'));
      expect(tocados, ['jueza']);
      semantica.dispose();
    });

    testWidgets('quien lleva el halo se anuncia como seleccionado', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(
        tester,
        escena(
          alPulsar: (_) {},
          elementos: [
            ElementoEscena(sprite: persona, x: 10, y: 15, id: 'jueza', etiqueta: 'La jueza', resaltado: true),
            ElementoEscena(sprite: otra, x: 30, y: 15, id: 'fiscal', etiqueta: 'El fiscal'),
          ],
        ),
        dpr: 2,
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('La jueza')),
        isSemantics(label: 'La jueza', isButton: true, isSelected: true, hasSelectedState: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('El fiscal')),
        isSemantics(label: 'El fiscal', isButton: true, hasSelectedState: false),
      );
      semantica.dispose();
    });
  });

  group('animación', () {
    testWidgets('los personajes se animan desfasados y se paran al quitar la escena', (tester) async {
      await montar(
        tester,
        escena(
          elementos: [
            ElementoEscena(sprite: ojos, x: 10, y: 15),
            ElementoEscena(sprite: ojos, x: 30, y: 15),
          ],
        ),
        dpr: 2,
      );
      expect(RelojPixel.debugEnMarcha, 1);
      Color color(Lamina lamina, int x) => lamina.en(x * 20 + 10, 100 + 12 * 20);
      // Desfases: 1370 ms el primero (en el fotograma 1, le quedan 630) y 2740 % 2000 = 740 el segundo.
      var lamina = await leerPixeles(tester);
      expect((color(lamina, 9), color(lamina, 29)), (colorDe('R'), colorDe('A')));
      await tester.pump(const Duration(milliseconds: 260));
      lamina = await leerPixeles(tester);
      expect((color(lamina, 9), color(lamina, 29)), (colorDe('R'), colorDe('R')));
      await tester.pump(const Duration(milliseconds: 370));
      lamina = await leerPixeles(tester);
      expect((color(lamina, 9), color(lamina, 29)), (colorDe('A'), colorDe('R')));

      await tester.pumpWidget(const SizedBox());
      expect(RelojPixel.debugEnMarcha, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('cambiar quién está resaltado no reinicia las animaciones', (tester) async {
      Widget conResaltado(bool resaltado) => escena(
        elementos: [ElementoEscena(sprite: ojos, x: 10, y: 15, resaltado: resaltado)],
      );
      await montar(tester, conResaltado(false), dpr: 2);
      await tester.pump(const Duration(milliseconds: 400));
      await montar(tester, conResaltado(true), dpr: 2);
      // Le quedaban 630 ms de fotograma 1: si se hubiera reiniciado, seguiría en él 630 ms más.
      await tester.pump(const Duration(milliseconds: 230));
      expect((await leerPixeles(tester)).en(9 * 20 + 10, 100 + 12 * 20), colorDe('A'));
      expect(RelojPixel.debugEnMarcha, 1);
    });

    testWidgets('con «reducir animaciones», todos quietos en la pose de descanso', (tester) async {
      await montar(
        tester,
        escena(
          elementos: [
            ElementoEscena(sprite: ojos, x: 10, y: 15),
            ElementoEscena(sprite: ojos, x: 30, y: 15),
          ],
        ),
        dpr: 2,
        reducir: true,
      );
      expect(RelojPixel.debugEnMarcha, 0);
      await tester.pump(const Duration(seconds: 5));
      final lamina = await leerPixeles(tester);
      expect(lamina.en(9 * 20 + 10, 100 + 12 * 20), colorDe('A'));
      expect(lamina.en(29 * 20 + 10, 100 + 12 * 20), colorDe('A'));
    });

    testWidgets('con animar: false tampoco se mueve nada', (tester) async {
      await montar(tester, escena(elementos: [ElementoEscena(sprite: ojos, x: 10, y: 15)], animar: false));
      expect(RelojPixel.debugEnMarcha, 0);
    });

    testWidgets('con la app en segundo plano el reloj se para, y vuelve al volver', (tester) async {
      await montar(tester, escena(elementos: [ElementoEscena(sprite: ojos, x: 10, y: 15)]), dpr: 2);
      expect(RelojPixel.debugEnMarcha, 1);
      for (final estado in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(estado);
      }
      await tester.pump();
      expect(RelojPixel.debugEnMarcha, 0);
      await tester.pump(const Duration(seconds: 5));
      expect(tester.binding.hasScheduledFrame, isFalse);
      for (final estado in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(estado);
      }
      await tester.pump();
      expect(RelojPixel.debugEnMarcha, 1);
      await tester.pumpWidget(const SizedBox());
      expect(RelojPixel.debugEnMarcha, 0);
    });

    testWidgets('sin nada animado no hay reloj', (tester) async {
      await montar(tester, escena());
      expect(RelojPixel.debugEnMarcha, 0);
    });
  });
}
