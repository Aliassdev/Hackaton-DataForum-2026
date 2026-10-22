import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/ui/ui.dart';

import 'ayudantes.dart';

CajaPixel _caja(WidgetTester tester) => tester.widget<CajaPixel>(find.byType(CajaPixel));

/// Dónde está el texto del ticket y de la carta sin pulsar.
final _reposo = <String, double>{};

/// El nodo de Semantics propio del botón (está por debajo del detector de foco).
Finder _nodo() => find.descendant(of: find.byType(BotonPixel), matching: find.byType(Semantics)).first;

Color? _colorTexto(WidgetTester tester, String texto) =>
    tester.renderObject<RenderParagraph>(find.text(texto)).text.style?.color;

void main() {
  testWidgets('se ve, mide al menos 48 × 48 y al tocarlo llama a onPressed y vibra un poco', (tester) async {
    final vibraciones = registrarVibraciones(tester);
    var pulsaciones = 0;
    await montar(tester, BotonPixel(etiqueta: 'Empezar', onPressed: () => pulsaciones++));
    expect(find.text('Empezar'), findsOneWidget);
    final tamano = tester.getSize(find.byType(BotonPixel));
    expect(tamano.width, greaterThanOrEqualTo(48));
    expect(tamano.height, greaterThanOrEqualTo(48));
    await tester.tap(find.byType(BotonPixel));
    await tester.pump();
    expect(pulsaciones, 1);
    expect(vibraciones, ['HapticFeedbackType.lightImpact']);
  });

  testWidgets('pulsado, baja una unidad pixel (hasta su sombra) y al soltar vuelve', (tester) async {
    await montar(tester, BotonPixel(etiqueta: 'Empezar', icono: const IconoPixel(GlifoPixel.flecha), onPressed: () {}));
    final reposo = tester.getTopLeft(find.text('Empezar'));
    final icono = tester.getTopLeft(find.byType(IconoPixel));
    final gesto = await tester.startGesture(tester.getCenter(find.byType(BotonPixel)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_caja(tester).pulsada, isTrue);
    // La unidad pixel de un móvil de densidad 3 son 3 puntos.
    expect(tester.getTopLeft(find.text('Empezar')) - reposo, const Offset(0, 3));
    expect(tester.getTopLeft(find.byType(IconoPixel)) - icono, const Offset(0, 3));
    // Con el dedo abajo más del mínimo, sube en cuanto se suelta.
    await gesto.up();
    await tester.pump();
    expect(_caja(tester).pulsada, isFalse);
    expect(tester.getTopLeft(find.text('Empezar')), reposo);
  });

  testWidgets('un toque rapidísimo también se ve: abajo al menos 120 ms', (tester) async {
    var pulsaciones = 0;
    await montar(tester, BotonPixel(etiqueta: 'Empezar', onPressed: () => pulsaciones++));
    final gesto = await tester.startGesture(tester.getCenter(find.byType(BotonPixel)));
    await tester.pump(const Duration(milliseconds: 10));
    await gesto.up();
    await tester.pump();
    expect(pulsaciones, 1);
    expect(_caja(tester).pulsada, isTrue, reason: 'sigue abajo hasta cumplir el mínimo');
    await tester.pump(const Duration(milliseconds: 60));
    expect(_caja(tester).pulsada, isTrue);
    await tester.pump(const Duration(milliseconds: 60));
    expect(_caja(tester).pulsada, isFalse);
  });

  testWidgets('dentro de una lista con scroll, un toque de 60 ms se ve pulsado (botón, opción, ticket y carta)', (
    tester,
  ) async {
    // Dentro de un scroll, el «abajo» del dedo espera a saber si es un arrastre (100 ms): en un toque rápido llega a
    // la vez que el «arriba». Aun así, la pieza tiene que verse bajar.
    final piezas = <String, bool Function()>{
      'botón': () => tester
          .widget<CajaPixel>(find.descendant(of: find.byType(BotonPixel), matching: find.byType(CajaPixel)))
          .pulsada,
      'opción': () => tester
          .widget<CajaPixel>(
            find.descendant(of: find.byType(MenuOpcionesPixel), matching: find.byType(CajaPixel)).first,
          )
          .pulsada,
      'ticket': () => tester.getTopLeft(find.text('Ticket')).dy > _reposo['ticket']!,
      'carta': () => tester.getTopLeft(find.text('Carta')).dy > _reposo['carta']!,
    };
    final dianas = {
      'botón': find.byType(BotonPixel),
      'opción': find.text('Opción'),
      'ticket': find.byType(TicketPixel),
      'carta': find.byType(CartaPixel),
    };
    for (final MapEntry(key: nombre, value: pulsada) in piezas.entries) {
      var tocada = 0;
      await montar(
        tester,
        ListView(
          children: [
            BotonPixel(etiqueta: 'Botón', onPressed: () => tocada++),
            MenuOpcionesPixel(opciones: const ['Opción', 'Otra'], onElegir: (_) => tocada++),
            TicketPixel(onPressed: () => tocada++, child: const Text('Ticket')),
            SizedBox(
              width: 200,
              child: CartaPixel(titulo: 'Carta', texto: 'Texto', brillo: false, onPressed: () => tocada++),
            ),
          ],
        ),
        centrar: false,
      );
      _reposo['ticket'] = tester.getTopLeft(find.text('Ticket')).dy;
      _reposo['carta'] = tester.getTopLeft(find.text('Carta')).dy;
      final gesto = await tester.startGesture(tester.getCenter(dianas[nombre]!.first));
      await tester.pump(const Duration(milliseconds: 60));
      expect(pulsada(), isFalse, reason: '$nombre: el scroll aún no ha dejado pasar el toque');
      await gesto.up();
      await tester.pump();
      expect(tocada, 1, reason: nombre);
      expect(pulsada(), isTrue, reason: '$nombre: se ve abajo después del toque rápido');
      await tester.pump(const Duration(milliseconds: 150));
      expect(pulsada(), isFalse, reason: '$nombre: y vuelve a subir');
    }
  });

  testWidgets('cada variante con sus colores y su tinta legible', (tester) async {
    for (final (variante, relleno, tinta) in [
      (VarianteBotonPixel.primario, ColoresUiPixel.amarillo, ColoresUiPixel.noche),
      (VarianteBotonPixel.secundario, ColoresUiPixel.papel, ColoresUiPixel.noche),
      (VarianteBotonPixel.peligro, ColoresUiPixel.teja, ColoresUiPixel.blanco),
    ]) {
      await montar(tester, BotonPixel(etiqueta: variante.name, variante: variante, onPressed: () {}));
      expect(_caja(tester).estilo.relleno, relleno, reason: variante.name);
      expect(_caja(tester).estilo.sombra, ColoresUiPixel.noche, reason: 'sombra dura');
      expect(_colorTexto(tester, variante.name), tinta, reason: variante.name);
    }
  });

  testWidgets('desactivado: gris, sin sombra, no responde y el lector lo dice', (tester) async {
    final vibraciones = registrarVibraciones(tester);
    await montar(tester, const BotonPixel(etiqueta: 'Bloqueado', onPressed: null));
    await tester.tap(find.byType(BotonPixel), warnIfMissed: false);
    await tester.pump();
    expect(vibraciones, isEmpty);
    expect(_caja(tester).estilo.relleno, ColoresUiPixel.grisClaro);
    expect(_caja(tester).estilo.sombra, isNull);
    expect(_caja(tester).pulsada, isFalse);
    expect(
      tester.getSemantics(_nodo()),
      isSemantics(label: 'Bloqueado', isButton: true, hasEnabledState: true, isEnabled: false, hasTapAction: false),
    );
  });

  testWidgets('el lector de pantalla lo anuncia como botón que se puede tocar', (tester) async {
    await montar(tester, BotonPixel(etiqueta: 'Empezar', onPressed: () {}));
    expect(
      tester.getSemantics(_nodo()),
      isSemantics(
        label: 'Empezar',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
      ),
    );
  });

  testWidgets('solo con icono: 48 × 48 como mínimo y el lector lee lo que hace', (tester) async {
    var pulsaciones = 0;
    await montar(
      tester,
      BotonPixel(
        icono: const IconoPixel(GlifoPixel.altavoz),
        semantica: 'Escuchar otra vez',
        variante: VarianteBotonPixel.secundario,
        onPressed: () => pulsaciones++,
      ),
    );
    final tamano = tester.getSize(find.byType(BotonPixel));
    expect(tamano.width, greaterThanOrEqualTo(48));
    expect(tamano.height, greaterThanOrEqualTo(48));
    expect(tester.getSemantics(_nodo()), isSemantics(label: 'Escuchar otra vez', isButton: true, hasTapAction: true));
    // El icono toma la tinta del botón.
    final icono = tester.widget<CustomPaint>(
      find.descendant(of: find.byType(IconoPixel), matching: find.byType(CustomPaint)),
    );
    expect(icono.size.width, greaterThan(0));
    await tester.tap(find.byType(BotonPixel));
    expect(pulsaciones, 1);
  });

  testWidgets('con el ratón encima se enciende un filo por dentro, en las tres variantes', (tester) async {
    // Con un ratón conectado desde el principio (como en la web o en un ordenador).
    final raton = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await raton.addPointer(location: Offset.zero);
    addTearDown(raton.removePointer);
    for (final variante in VarianteBotonPixel.values) {
      final colores = ColoresBotonPixel.de(variante);
      await montar(tester, BotonPixel(etiqueta: 'Empezar', variante: variante, onPressed: () {}));
      expect(_caja(tester).estilo.anillo, isNull, reason: variante.name);
      await raton.moveTo(tester.getCenter(find.byType(BotonPixel)));
      await tester.pump();
      expect(_caja(tester).estilo.anillo, colores.brillo, reason: variante.name);
      expect(colores.brillo, isNot(colores.relleno), reason: '${variante.name}: el filo se distingue del relleno');
      await raton.moveTo(Offset.zero);
      await tester.pump();
      expect(_caja(tester).estilo.anillo, isNull, reason: variante.name);
    }
  });

  testWidgets('sobre el azul noche del juego lleva filo, y al pulsarlo baja dentro de él', (tester) async {
    await montar(
      tester,
      FondoPixel(
        color: ColoresUiPixel.noche,
        child: BotonPixel(etiqueta: 'Empezar', onPressed: () {}),
      ),
    );
    final pintor = tester
        .widgetList<CustomPaint>(find.descendant(of: find.byType(BotonPixel), matching: find.byType(CustomPaint)))
        .map((pintura) => pintura.painter)
        .whereType<PintorCajaPixel>()
        .single;
    expect(pintor.filo, ColoresUiPixel.azul);
    final reposo = tester.getTopLeft(find.text('Empezar'));
    final gesto = await tester.startGesture(tester.getCenter(find.byType(BotonPixel)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getTopLeft(find.text('Empezar')) - reposo, const Offset(0, 3));
    await gesto.up();
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('con teclado: anillo de foco, e Intro o Espacio lo pulsan (baja un momento)', (tester) async {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    final foco = FocusNode();
    addTearDown(foco.dispose);
    var pulsaciones = 0;
    await montar(tester, BotonPixel(etiqueta: 'Empezar', focusNode: foco, onPressed: () => pulsaciones++));
    expect(_caja(tester).foco, isFalse);
    foco.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(_caja(tester).foco, isTrue);
    expect(tester.getSemantics(_nodo()), isSemantics(isFocused: true));

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(pulsaciones, 1);
    expect(_caja(tester).pulsada, isTrue);
    await tester.pump(const Duration(milliseconds: 150));
    expect(_caja(tester).pulsada, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(pulsaciones, 2);
    // Se quita con el botón aún bajado: el temporizador se cancela.
    await desmontar(tester);
  });

  testWidgets('con texto, el icono va centrado en la línea y uno alto no hace el botón más alto', (tester) async {
    for (final escala in [1.0, 1.3]) {
      await montar(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BotonPixel(
              key: const ValueKey('flecha'),
              etiqueta: 'Uno',
              icono: const IconoPixel(GlifoPixel.flecha),
              onPressed: () {},
            ),
            BotonPixel(
              key: const ValueKey('carta'),
              etiqueta: 'Dos',
              icono: const IconoPixel(GlifoPixel.carta),
              onPressed: () {},
            ),
            BotonPixel(key: const ValueKey('nada'), etiqueta: 'Tres', onPressed: () {}),
          ],
        ),
        escalaTexto: escala,
      );
      final alto = tester.getSize(find.byKey(const ValueKey('nada'))).height;
      for (final (clave, texto) in [('flecha', 'Uno'), ('carta', 'Dos')]) {
        expect(tester.getSize(find.byKey(ValueKey(clave))).height, alto, reason: '$clave con letra $escala');
        final icono = tester.getCenter(
          find.descendant(of: find.byKey(ValueKey(clave)), matching: find.byType(CustomPaint)).last,
        );
        expect(icono.dy, closeTo(tester.getCenter(find.text(texto)).dy, 0.5), reason: '$clave con letra $escala');
      }
    }
  });

  testWidgets('con letra grande y poco sitio, la etiqueta baja de línea sin desbordarse', (tester) async {
    await montar(
      tester,
      SizedBox(
        width: 200,
        child: BotonPixel(
          etiqueta: 'Pedir que me lo expliquen otra vez',
          icono: const IconoPixel(GlifoPixel.pregunta),
          expandido: true,
          onPressed: () {},
        ),
      ),
      escalaTexto: 1.3,
      tamano: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(BotonPixel)).width, 200);
    expect(tester.getSize(find.byType(BotonPixel)).height, greaterThan(70));
  });
}
