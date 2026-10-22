import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/ui/ui.dart';

import 'ayudantes.dart';

Finder _glifo(GlifoPixel glifo) => find.byWidgetPredicate((widget) => widget is IconoPixel && widget.glifo == glifo);

Finder _rotulo(String texto) => find.byWidgetPredicate((widget) => widget is RotuloPixel && widget.texto == texto);

/// El CustomPaint del marco de la carta.
CustomPaint _marcoCarta(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.descendant(of: find.byType(CartaPixel), matching: find.byType(CustomPaint)))
    .firstWhere((pintura) => pintura.painter is PintorCajaPixel);

/// Si la carta tiene brillo (va delante de su dibujo).
bool _conBrillo(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.descendant(of: find.byType(CartaPixel), matching: find.byType(CustomPaint)))
    .any((pintura) => pintura.foregroundPainter != null);

/// Un dibujo que cuenta cuántas veces se monta.
class _Arte extends StatefulWidget {
  const _Arte(this.montajes);

  final List<int> montajes;

  @override
  State<_Arte> createState() => _ArteState();
}

class _ArteState extends State<_Arte> {
  @override
  void initState() {
    super.initState();
    widget.montajes.add(1);
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 30, height: 30);
}

void main() {
  group('TicketPixel', () {
    testWidgets('se ve con su cuerpo y su talón; al tocarlo, baja, vibra y llama a onPressed', (tester) async {
      final vibraciones = registrarVibraciones(tester);
      var pulsaciones = 0;
      await montar(
        tester,
        TicketPixel(
          talon: const Text('A-07'),
          semantica: 'Tu turno: A 07',
          onPressed: () => pulsaciones++,
          child: const Text('Vive el caso'),
        ),
      );
      expect(find.text('Vive el caso'), findsOneWidget);
      expect(find.text('A-07'), findsOneWidget);
      final reposo = tester.getTopLeft(find.text('Vive el caso'));
      final dedo = await tester.startGesture(tester.getCenter(find.byType(TicketPixel)));
      await tester.pump();
      expect(tester.getTopLeft(find.text('Vive el caso')) - reposo, const Offset(0, 3));
      await dedo.up();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.getTopLeft(find.text('Vive el caso')), reposo);
      expect(pulsaciones, 1);
      expect(vibraciones, ['HapticFeedbackType.lightImpact']);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Tu turno: A 07')),
        isSemantics(label: 'Tu turno: A 07', isButton: true, hasTapAction: true),
      );
    });

    testWidgets('sin onPressed no es un botón y el lector lee lo que lleva escrito', (tester) async {
      await montar(tester, const TicketPixel(talon: RotuloPixel('N.º 1'), child: Text('Caso 1')));
      final nodo = tester.getSemantics(find.bySemanticsLabel(RegExp('Caso 1')));
      expect(nodo, isSemantics(isButton: false, hasTapAction: false));
      expect(nodo.label, allOf(contains('Caso 1'), contains('N.º 1')));
    });

    testWidgets('pulsable y sin semantica, el lector lo lee en un solo nodo: un botón con todo su texto', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await montar(
        tester,
        TicketPixel(talon: const RotuloPixel('A-07'), onPressed: () {}, child: const Text('Caso 1')),
      );
      final nodo = tester.getSemantics(find.bySemanticsLabel(RegExp('Caso 1')));
      expect(nodo, isSemantics(isButton: true, hasTapAction: true, isFocusable: true));
      expect(nodo.label, allOf(contains('Caso 1'), contains('A-07')));
      // No hay otro nodo con el mismo texto, ni un botón sin nombre.
      expect(find.bySemanticsLabel(RegExp('Caso 1')), findsOneWidget);
      expect(
        find.semantics.byPredicate((nodo) => nodo.getSemanticsData().flagsCollection.isButton && nodo.label.isEmpty),
        findsNothing,
      );
      semantica.dispose();
    });

    testWidgets('en un Center (o una celda) no se estira: el alto sale del contenido', (tester) async {
      for (final escala in [1.0, 1.3, 2.0]) {
        await montar(
          tester,
          const TicketPixel(talon: Text('A-07'), child: Text('Caso 1 · Lucía')),
          tamano: const Size(360, 780),
          escalaTexto: escala,
        );
        expect(tester.getSize(find.byType(TicketPixel)).height, lessThan(260), reason: 'letra $escala');
      }
    });

    testWidgets('el talón crece con la letra del sistema (no la encoge) y, si no cabe al lado, va debajo', (
      tester,
    ) async {
      await cargarFuentesPixel();
      Future<(double, Rect, Rect)> medir(double ancho, double escala, String talon) async {
        await montar(
          tester,
          TicketPixel(
            talon: Column(mainAxisSize: MainAxisSize.min, children: [Text(talon), const RotuloPixel('A-07')]),
            child: const Text('Vive el caso'),
          ),
          tamano: Size(ancho, 900),
          escalaTexto: escala,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(FittedBox), findsNothing);
        final parrafo = tester.renderObject<RenderParagraph>(find.text(talon));
        final tamano = parrafo.textScaler.scale(parrafo.text.style!.fontSize!);
        return (tamano, tester.getRect(find.text('Vive el caso')), tester.getRect(find.text(talon)));
      }

      for (final (ancho, escala) in [(390.0, 1.0), (320.0, 1.3), (390.0, 2.0)]) {
        final (tamano, cuerpo, talon) = await medir(ancho, escala, 'TURNO');
        expect(tamano, closeTo(18 * escala, 0.01), reason: 'TURNO con $ancho de ancho y letra $escala');
        expect(talon.right, lessThan(ancho), reason: 'cabe');
      }
      // Un talón largo con letra muy grande no cabe al lado del cuerpo: va debajo, a todo el ancho.
      final (_, cuerpo, talon) = await medir(320, 2, 'TURNO DE HOY');
      expect(talon.top, greaterThan(cuerpo.bottom));
    });

    testWidgets('con teclado: Intro lo pulsa', (tester) async {
      var pulsaciones = 0;
      await montar(tester, TicketPixel(onPressed: () => pulsaciones++, child: const Text('Caso 1')));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(pulsaciones, 1);
      await desmontar(tester);
    });

    testWidgets('las muescas dejan ver el fondo y todo se pinta sin suavizado', (tester) async {
      await montar(
        tester,
        ColoredBox(
          color: ColoresUiPixel.cielo,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: RepaintBoundary(
              child: SizedBox(
                width: 300,
                child: TicketPixel(
                  talon: const SizedBox(height: 40),
                  onPressed: () {},
                  child: const SizedBox(height: 40),
                ),
              ),
            ),
          ),
        ),
      );
      final colores = await coloresPintados(tester, find.byType(TicketPixel));
      expect(
        colores.difference({
          for (final c in [ColoresUiPixel.cielo, ColoresUiPixel.noche, ColoresUiPixel.papel, ColoresUiPixel.amarillo])
            rgba(c),
        }),
        isEmpty,
      );
      // Arriba, en la columna de la perforación (a 28 unidades del borde derecho), la muesca deja ver el fondo.
      final pixeles = await leerPixeles(tester, find.byType(TicketPixel));
      final corte = pixeles.ancho - 28 * 9;
      expect(pixeles.pixel(corte + 4, 2), rgba(ColoresUiPixel.cielo), reason: 'la muesca de arriba');
      expect(pixeles.pixel(corte - 40, 2), rgba(ColoresUiPixel.noche), reason: 'el contorno, fuera de la muesca');
    });

    testWidgets('sobre el azul noche del juego lleva filo, que se abre en las muescas', (tester) async {
      await montar(
        tester,
        FondoPixel(
          color: ColoresUiPixel.noche,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: RepaintBoundary(
              child: SizedBox(
                width: 300,
                child: TicketPixel(talon: const SizedBox(height: 40), child: const SizedBox(height: 40)),
              ),
            ),
          ),
        ),
      );
      final pixeles = await leerPixeles(tester, find.byType(TicketPixel));
      final corte = pixeles.ancho - (28 + 1) * 9;
      expect(pixeles.pixel(corte - 40, 2), rgba(ColoresUiPixel.azul), reason: 'el filo, arriba');
      expect(pixeles.pixel(corte + 4, 2), rgba(ColoresUiPixel.noche), reason: 'la muesca, abierta');
    });

    testWidgets('con letra grande no se desborda', (tester) async {
      await montar(
        tester,
        TicketPixel(
          talon: const Text('A-07'),
          onPressed: () {},
          child: const Text('Caso 1 · Lucía, 11 años: la sala con el espejo grande'),
        ),
        escalaTexto: 1.3,
        tamano: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('CartaPixel', () {
    testWidgets('desbloqueada: título, texto, dibujo y número; el lector la lee entera', (tester) async {
      await montar(
        tester,
        const SizedBox(
          width: 180,
          child: CartaPixel(numero: 1, titulo: 'Derecho a entender', texto: 'Pide que te lo expliquen.'),
        ),
      );
      expect(find.text('Derecho a entender'), findsOneWidget);
      expect(find.text('Pide que te lo expliquen.'), findsOneWidget);
      // El número, con la letra de rótulo (en Pixelify, algunas cifras se confunden con letras).
      expect(_rotulo('N.º 1'), findsOneWidget);
      expect(_glifo(GlifoPixel.balanza), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('Derecho a entender'))),
        isSemantics(label: 'Carta número 1: Derecho a entender. Pide que te lo expliquen.'),
      );
      await desmontar(tester);
    });

    testWidgets('bloqueada: candado, «???» y la pista; sin brillo; el lector dice su número', (tester) async {
      await montar(
        tester,
        const SizedBox(
          width: 180,
          child: CartaPixel(numero: 2, titulo: 'Secreto', texto: 'No se ve', bloqueada: true, pista: 'Juega el caso.'),
        ),
      );
      expect(find.text('???'), findsOneWidget);
      expect(find.text('Secreto'), findsNothing);
      expect(find.text('No se ve'), findsNothing);
      expect(find.text('Juega el caso.'), findsOneWidget);
      expect(_glifo(GlifoPixel.candado), findsOneWidget);
      expect(_conBrillo(tester), isFalse);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('Carta número 2'))),
        isSemantics(label: 'Carta número 2, bloqueada. Juega el caso.'),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('el dibujo brilla una vez al aparecer (nunca en bucle) y otra al desbloquearse', (tester) async {
      final bloqueada = ValueNotifier(false);
      addTearDown(bloqueada.dispose);
      await montar(
        tester,
        SizedBox(
          width: 180,
          child: ValueListenableBuilder<bool>(
            valueListenable: bloqueada,
            builder: (context, valor, _) => CartaPixel(titulo: 'A', texto: 'B', bloqueada: valor),
          ),
        ),
      );
      expect(_conBrillo(tester), isTrue);
      // Espera (de 0,4 a 1 s, según su sitio) y cruza en 0,9 s.
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'esperando, no pinta nada');
      var cruzando = false;
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (tester.binding.hasScheduledFrame) cruzando = true;
      }
      expect(cruzando, isTrue, reason: 'ha cruzado');
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      // Ya no vuelve solo.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(seconds: 1));
        expect(tester.binding.hasScheduledFrame, isFalse, reason: 'sin brillo en bucle');
      }
      // Bloqueada y desbloqueada de nuevo: un barrido más.
      bloqueada.value = true;
      await tester.pump();
      bloqueada.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.hasScheduledFrame, isTrue, reason: 'brilla al desbloquearse');
      await desmontar(tester);
    });

    testWidgets('con el ratón encima (si se puede tocar), el dibujo vuelve a brillar', (tester) async {
      final raton = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await raton.addPointer(location: Offset.zero);
      addTearDown(raton.removePointer);
      await montar(
        tester,
        SizedBox(
          width: 180,
          child: CartaPixel(titulo: 'A', texto: 'B', onPressed: () {}),
        ),
      );
      // El barrido de aparecer, entero (a pasos: el brillo se mueve fotograma a fotograma).
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.binding.hasScheduledFrame, isFalse);
      await raton.moveTo(tester.getCenter(find.byType(CartaPixel)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await desmontar(tester);
    });

    testWidgets('con «reducir animaciones» no hay brillo', (tester) async {
      await montar(
        tester,
        const SizedBox(
          width: 180,
          child: CartaPixel(titulo: 'A', texto: 'B'),
        ),
        reducir: true,
      );
      expect(_conBrillo(tester), isFalse);
      await tester.pump(const Duration(seconds: 5));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('el hueco del dibujo acepta un sprite (o cualquier widget)', (tester) async {
      await montar(
        tester,
        const SizedBox(
          width: 180,
          child: CartaPixel(
            titulo: 'A',
            texto: 'B',
            arte: SizedBox(key: ValueKey('arte'), width: 30, height: 30),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('arte')), findsOneWidget);
      expect(_glifo(GlifoPixel.balanza), findsNothing);
      await desmontar(tester);
    });

    testWidgets('con onPressed es un botón: baja al pulsarla y vibra', (tester) async {
      final vibraciones = registrarVibraciones(tester);
      var pulsaciones = 0;
      await montar(
        tester,
        SizedBox(
          width: 180,
          child: CartaPixel(titulo: 'A', texto: 'B', onPressed: () => pulsaciones++),
        ),
      );
      final reposo = tester.getTopLeft(find.text('A'));
      final dedo = await tester.startGesture(tester.getCenter(find.byType(CartaPixel)));
      await tester.pump();
      expect(tester.getTopLeft(find.text('A')) - reposo, const Offset(0, 3));
      await dedo.up();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.getTopLeft(find.text('A')), reposo);
      expect(pulsaciones, 1);
      expect(vibraciones, ['HapticFeedbackType.lightImpact']);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('Carta: A'))),
        isSemantics(isButton: true, hasTapAction: true),
      );
      await desmontar(tester);
    });

    testWidgets('el dibujo crece a escala entera según el sitio (nunca a medias)', (tester) async {
      Future<int> escala(double ancho) async {
        await montar(
          tester,
          SizedBox(
            width: ancho,
            child: const CartaPixel(titulo: 'A', texto: 'B', brillo: false),
          ),
        );
        return tester.widget<IconoPixel>(_glifo(GlifoPixel.balanza)).escala;
      }

      final pequena = await escala(150);
      final grande = await escala(320);
      expect(pequena, greaterThanOrEqualTo(1));
      expect(grande, greaterThan(pequena));
    });

    testWidgets('con letra muy grande (2) en una carta estrecha, la ventana del dibujo crece', (tester) async {
      await montar(
        tester,
        const SizedBox(
          width: 140,
          child: CartaPixel(numero: 7, titulo: 'Ir acompañada', texto: 'Con un adulto de confianza.', brillo: false),
        ),
        escalaTexto: 2,
        tamano: const Size(320, 1200),
      );
      expect(tester.takeException(), isNull);
      expect(_rotulo('N.º 7'), findsOneWidget);
      expect(_glifo(GlifoPixel.balanza), findsOneWidget);
    });

    testWidgets('al quitarle onPressed no se queda con el foco ni pulsada, y su dibujo no se vuelve a montar', (
      tester,
    ) async {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      final montajes = <int>[];
      final activa = ValueNotifier(true);
      addTearDown(activa.dispose);
      await montar(
        tester,
        SizedBox(
          width: 180,
          child: ValueListenableBuilder<bool>(
            valueListenable: activa,
            builder: (context, valor, _) => CartaPixel(
              titulo: 'A',
              texto: 'B',
              brillo: false,
              arte: _Arte(montajes),
              onPressed: valor ? () {} : null,
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect((_marcoCarta(tester).painter! as PintorCajaPixel).foco, isTrue);
      activa.value = false;
      await tester.pump();
      expect((_marcoCarta(tester).painter! as PintorCajaPixel).foco, isFalse);
      activa.value = true;
      await tester.pump();
      expect((_marcoCarta(tester).painter! as PintorCajaPixel).foco, isFalse, reason: 'el foco ya no está en ella');
      expect(montajes, [1], reason: 'el dibujo (un sprite animado) sigue montado');
    });

    testWidgets('tumbada: el dibujo a la izquierda y el texto a la derecha, con aire alrededor', (tester) async {
      await montar(
        tester,
        const SizedBox(
          width: 358,
          child: CartaPixel(
            numero: 1,
            titulo: 'Derecho a entender',
            texto: 'Si no entiendes algo, pide que te lo expliquen.',
            formato: FormatoCartaPixel.horizontal,
            brillo: false,
          ),
        ),
      );
      final dibujo = tester.getRect(_glifo(GlifoPixel.balanza));
      final texto = tester.getRect(find.text('Si no entiendes algo, pide que te lo expliquen.'));
      expect(dibujo.right, lessThan(texto.left));
      // El texto tiene sitio para leerse: más de la mitad de la carta.
      expect(texto.width, greaterThan(358 * 0.5 - 40));
      // Y queda a tres unidades del borde de su panel (una es el contorno).
      final panel = tester.getRect(
        find.ancestor(
          of: find.text('Si no entiendes algo, pide que te lo expliquen.'),
          matching: find.byType(CajaPixel),
        ),
      );
      expect(texto.left - panel.left, closeTo(9, 0.2));
    });

    testWidgets('tumbada, si al texto no le caben unas catorce letras por línea (letra grande), se pone de pie', (
      tester,
    ) async {
      await montar(
        tester,
        const SizedBox(
          width: 328,
          child: CartaPixel(
            titulo: 'Derecho a entender',
            texto: 'Si no entiendes algo, pide que te lo expliquen.',
            formato: FormatoCartaPixel.horizontal,
            brillo: false,
          ),
        ),
        escalaTexto: 1.3,
        tamano: const Size(360, 1200),
      );
      expect(tester.takeException(), isNull);
      final dibujo = tester.getRect(_glifo(GlifoPixel.balanza));
      final texto = tester.getRect(find.text('Si no entiendes algo, pide que te lo expliquen.'));
      expect(dibujo.bottom, lessThan(texto.top), reason: 'el dibujo arriba y el texto debajo, a todo el ancho');
    });

    testWidgets('con letra grande el texto crece y no se desborda', (tester) async {
      await montar(
        tester,
        const SizedBox(
          width: 200,
          child: CartaPixel(
            numero: 12,
            titulo: 'Derecho a entender',
            texto: 'Si no entiendes algo, pide que te lo expliquen.',
          ),
        ),
        escalaTexto: 1.3,
        tamano: const Size(320, 900),
      );
      expect(tester.takeException(), isNull);
      await desmontar(tester);
    });
  });
}
