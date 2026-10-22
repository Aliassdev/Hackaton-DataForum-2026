import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/ui/ui.dart';

import 'ayudantes.dart';

const _largo = 'Hoy vengo al juzgado con mi tía Elena. Me han dicho que solo tendré que contarlo una vez.';

/// El texto que se ve del diálogo: el primero de los dos trozos (el segundo, lo que falta, ocupa su sitio
/// transparente).
String _visible(WidgetTester tester) {
  TextSpan? buscar(InlineSpan span) {
    if (span is! TextSpan) return null;
    final hijos = span.children;
    if (hijos == null) return null;
    if (hijos.length == 2 && hijos.every((hijo) => hijo is TextSpan && hijo.children == null)) return span;
    for (final hijo in hijos) {
      final encontrado = buscar(hijo);
      if (encontrado != null) return encontrado;
    }
    return null;
  }

  for (final rico in tester.widgetList<RichText>(
    find.descendant(of: find.byType(DialogoPixel), matching: find.byType(RichText)),
  )) {
    final partes = buscar(rico.text);
    if (partes != null) return (partes.children!.first as TextSpan).text ?? '';
  }
  fail('no se encuentra el texto del diálogo');
}

/// La opacidad del ▼ de la placa «Continuar» (la de dentro, la que parpadea) y la de la placa entera.
(double, double) _indicador(WidgetTester tester) {
  final opacidades = find.ancestor(
    of: find.byWidgetPredicate((widget) => widget is IconoPixel && widget.glifo == GlifoPixel.abajo),
    matching: find.byType(Opacity),
  );
  return (tester.widget<Opacity>(opacidades.first).opacity, tester.widget<Opacity>(opacidades.last).opacity);
}

void main() {
  testWidgets('escribe letra a letra y avisa una vez, al acabar', (tester) async {
    final controlador = ControladorDialogoPixel();
    addTearDown(controlador.dispose);
    var avisos = 0;
    controlador.addListener(() => avisos++);
    var completado = 0;
    await montar(
      tester,
      DialogoPixel(
        hablante: 'Lucía',
        texto: 'Hola, soy Lucía.',
        controlador: controlador,
        onCompletado: () => completado++,
        onContinuar: () {},
      ),
    );
    expect(_visible(tester).length, lessThan(3));
    expect(controlador.completo, isFalse);
    expect(controlador.total, 'Hola, soy Lucía.'.length);
    await tester.pump(const Duration(milliseconds: 200));
    final aMedias = _visible(tester);
    expect(aMedias.length, inExclusiveRange(1, 16));
    expect('Hola, soy Lucía.'.startsWith(aMedias), isTrue);
    expect(controlador.visibles, aMedias.length);
    await tester.pump(const Duration(seconds: 2));
    expect(_visible(tester), 'Hola, soy Lucía.');
    expect(completado, 1);
    expect(controlador.completo, isTrue);
    expect(avisos, 1);
  });

  testWidgets('hace una pausa en las comas y los puntos', (tester) async {
    await montar(tester, const DialogoPixel(texto: 'Ah, sí.', caracteresPorSegundo: 10));
    // A 10 por segundo, la «h» sale a los 0,1 s y la coma a los 0,2 s; la coma pesa como cuatro letras, así que el
    // espacio no sale hasta los 0,6 s.
    await tester.pump(const Duration(milliseconds: 250));
    expect(_visible(tester), 'Ah,');
    await tester.pump(const Duration(milliseconds: 300));
    expect(_visible(tester), 'Ah,', reason: 'la pausa de la coma');
    await tester.pump(const Duration(milliseconds: 100));
    expect(_visible(tester), 'Ah, ');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('un toque mientras escribe lo enseña todo; otro, continúa', (tester) async {
    final vibraciones = registrarVibraciones(tester);
    var completado = 0;
    var continuar = 0;
    await montar(tester, DialogoPixel(texto: _largo, onCompletado: () => completado++, onContinuar: () => continuar++));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_visible(tester), isNot(_largo));
    await tester.tap(find.byType(DialogoPixel));
    await tester.pump();
    expect(_visible(tester), _largo);
    expect(completado, 1);
    expect(continuar, 0);
    expect(vibraciones, ['HapticFeedbackType.selectionClick']);

    await tester.tap(find.byType(DialogoPixel));
    await tester.pump();
    expect(continuar, 1);
    expect(completado, 1);
    expect(vibraciones.last, 'HapticFeedbackType.lightImpact');
  });

  testWidgets('con «reducir animaciones», el texto sale entero y el ▼ no parpadea', (tester) async {
    var completado = 0;
    await montar(
      tester,
      DialogoPixel(texto: _largo, onCompletado: () => completado++, onContinuar: () {}),
      reducir: true,
    );
    expect(_visible(tester), _largo);
    expect(completado, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(_indicador(tester), (1.0, 1.0));
  });

  testWidgets('la placa «Continuar» sale al acabar y su ▼ parpadea', (tester) async {
    await montar(tester, DialogoPixel(texto: 'Hola.', onContinuar: () {}));
    expect(_indicador(tester).$2, 0, reason: 'mientras escribe, la placa no se ve (pero guarda su sitio)');
    await tester.pump(const Duration(seconds: 1));
    expect(_indicador(tester).$2, 1);
    expect(_indicador(tester).$1, 1, reason: 'empieza a la vista');
    // Se ve 650 ms y se esconde 350.
    await tester.pump(const Duration(milliseconds: 660));
    expect(_indicador(tester).$1, 0);
    await tester.pump(const Duration(milliseconds: 360));
    expect(_indicador(tester).$1, 1);
  });

  testWidgets('el ▼ deja de parpadear a los 8 segundos y se queda a la vista', (tester) async {
    await montar(tester, DialogoPixel(texto: 'Hola.', onContinuar: () {}));
    await tester.pump(const Duration(seconds: 1));
    expect(_indicador(tester), (1.0, 1.0));
    var escondido = false;
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (_indicador(tester).$1 == 0) escondido = true;
    }
    expect(escondido, isTrue, reason: 'ha parpadeado');
    // Ya quieto: a la vista y sin nada pendiente.
    await tester.pump(const Duration(seconds: 1));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(_indicador(tester).$1, 1);
    }
    await desmontar(tester);
  });

  testWidgets('reiniciar() con el ▼ escondido: deja de parpadear mientras escribe y vuelve a empezar a la vista', (
    tester,
  ) async {
    final controlador = ControladorDialogoPixel();
    addTearDown(controlador.dispose);
    await montar(tester, DialogoPixel(texto: 'Hola.', controlador: controlador, onContinuar: () {}));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 660));
    expect(_indicador(tester).$1, 0, reason: 'escondido');
    controlador.reiniciar();
    await tester.pump();
    expect(controlador.completo, isFalse);
    expect(_indicador(tester), (1.0, 0.0), reason: 'mientras escribe, la placa no se ve; el ▼, preparado');
    // Escribiendo, el ▼ no cambia (no quedó ningún temporizador del parpadeo vivo).
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(_indicador(tester).$1, 1);
    }
    await tester.pump(const Duration(seconds: 1));
    expect(controlador.completo, isTrue);
    expect(_indicador(tester), (1.0, 1.0), reason: 'al acabar, empieza a la vista');
    await desmontar(tester);
  });

  testWidgets('es una región en vivo: el lector dice cada frase nueva (salvo con anunciar: false, si ya hay voz)', (
    tester,
  ) async {
    await montar(tester, DialogoPixel(texto: _largo, onContinuar: () {}));
    expect(tester.getSemantics(find.bySemanticsLabel(_largo)), isSemantics(isLiveRegion: true));
    await montar(tester, DialogoPixel(texto: _largo, anunciar: false, onContinuar: () {}));
    expect(tester.getSemantics(find.bySemanticsLabel(_largo)), isSemantics(isLiveRegion: false));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('sin onContinuar, si tenía el foco lo conserva al acabar de escribir', (tester) async {
    final foco = FocusNode();
    addTearDown(foco.dispose);
    await montar(tester, DialogoPixel(texto: 'Hola, soy Lucía.', focusNode: foco));
    foco.requestFocus();
    await tester.pump();
    expect(foco.hasPrimaryFocus, isTrue);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(foco.hasPrimaryFocus, isTrue, reason: 'el teclado no vuelve al principio de la pantalla');
    // Intro ya no hace nada (no hay nada después).
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin onContinuar no hay placa ni nada que tocar al acabar', (tester) async {
    await montar(tester, const DialogoPixel(texto: 'Hola.'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Continuar'), findsNothing);
    expect(tester.getSemantics(find.bySemanticsLabel('Hola.')), isSemantics(label: 'Hola.', hasTapAction: false));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('el lector de pantalla lee todo el texto (con quién habla) desde el principio', (tester) async {
    await montar(tester, DialogoPixel(hablante: 'Lucía', texto: _largo, onContinuar: () {}));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Lucía: $_largo')),
      isSemantics(label: 'Lucía: $_largo', hasTapAction: true, onTapHint: 'ver todo el texto'),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Lucía: $_largo')),
      isSemantics(hasTapAction: true, onTapHint: 'continuar'),
    );
  });

  testWidgets('no cambia de tamaño mientras escribe', (tester) async {
    await montar(tester, DialogoPixel(hablante: 'Lucía', texto: _largo, onContinuar: () {}));
    final antes = tester.getSize(find.byType(DialogoPixel));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.getSize(find.byType(DialogoPixel)), antes);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.getSize(find.byType(DialogoPixel)), antes);
  });

  testWidgets('un texto nuevo vuelve a escribirse; el controlador lo enseña todo o lo reinicia', (tester) async {
    final controlador = ControladorDialogoPixel();
    addTearDown(controlador.dispose);
    final texto = ValueNotifier('Primera frase.');
    addTearDown(texto.dispose);
    await montar(
      tester,
      ValueListenableBuilder<String>(
        valueListenable: texto,
        builder: (context, valor, _) => DialogoPixel(texto: valor, controlador: controlador),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(controlador.completo, isTrue);

    texto.value = 'Segunda frase, algo más larga.';
    await tester.pump();
    expect(controlador.completo, isFalse);
    expect(_visible(tester).length, lessThan(3));

    controlador.mostrarTodo();
    await tester.pump();
    expect(_visible(tester), 'Segunda frase, algo más larga.');
    expect(controlador.completo, isTrue);

    controlador.reiniciar();
    await tester.pump();
    expect(controlador.completo, isFalse);
    expect(_visible(tester).length, lessThan(3));
    await tester.pump(const Duration(seconds: 3));
    expect(controlador.completo, isTrue);
  });

  testWidgets('con teclado: Intro lo enseña todo y luego continúa', (tester) async {
    final foco = FocusNode();
    addTearDown(foco.dispose);
    var continuar = 0;
    await montar(tester, DialogoPixel(texto: _largo, focusNode: foco, onContinuar: () => continuar++));
    foco.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_visible(tester), _largo);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(continuar, 1);
  });

  testWidgets('se quita a medias (escribiendo o parpadeando) sin dejar nada vivo', (tester) async {
    await montar(tester, DialogoPixel(hablante: 'Lucía', texto: _largo, onContinuar: () {}));
    await tester.pump(const Duration(milliseconds: 100));
    await desmontar(tester);

    await montar(tester, DialogoPixel(texto: 'Hola.', onContinuar: () {}));
    await tester.pump(const Duration(seconds: 1));
    await desmontar(tester);
  });

  testWidgets('con letra grande no se desborda', (tester) async {
    await montar(
      tester,
      DialogoPixel(hablante: 'Ana, la psicóloga del juzgado', texto: _largo, onContinuar: () {}),
      escalaTexto: 1.3,
      tamano: const Size(320, 640),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });
}
