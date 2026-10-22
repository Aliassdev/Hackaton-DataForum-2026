import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/ui/ui.dart';

import 'ayudantes.dart';

const _opciones = ['Una citación', 'Una multa', 'Una nota del instituto'];

/// La fila de la opción [i] (su detector de foco).
Finder _fila(int i) => find.ancestor(of: find.text(_opciones[i]), matching: find.byType(FocusableActionDetector)).first;

Finder _glifo(GlifoPixel glifo) => find.byWidgetPredicate((widget) => widget is IconoPixel && widget.glifo == glifo);

/// En qué opción está el cursor ►, o null si no está en ninguna.
int? _cursor(WidgetTester tester) {
  for (var i = 0; i < _opciones.length; i++) {
    if (find.descendant(of: _fila(i), matching: _glifo(GlifoPixel.flecha)).evaluate().isNotEmpty) return i;
  }
  return null;
}

CajaPixel _caja(WidgetTester tester, int i) =>
    tester.widget<CajaPixel>(find.descendant(of: _fila(i), matching: find.byType(CajaPixel)));

/// El nodo de la opción [i] (al decidir, su etiqueta dice además el resultado).
SemanticsNode _semantica(WidgetTester tester, int i) =>
    tester.getSemantics(find.bySemanticsLabel(RegExp('^${RegExp.escape(_opciones[i])}')));

/// Un menú que guarda la elección (como lo usaría el juego).
class _Menu extends StatefulWidget {
  const _Menu({this.correctas = const {0}, this.cursorInicial, this.alElegir});

  final Set<int>? correctas;
  final int? cursorInicial;
  final ValueChanged<int>? alElegir;

  @override
  State<_Menu> createState() => _MenuState();
}

class _MenuState extends State<_Menu> {
  int? elegida;

  @override
  Widget build(BuildContext context) => MenuOpcionesPixel(
    etiqueta: '¿Qué es este papel?',
    opciones: _opciones,
    correctas: widget.correctas,
    cursorInicial: widget.cursorInicial,
    elegida: elegida,
    onElegir: (indice) {
      widget.alElegir?.call(indice);
      setState(() => elegida = indice);
    },
  );
}

void main() {
  testWidgets('se ven todas las opciones y, sin tocar nada, no hay cursor', (tester) async {
    await montar(tester, const _Menu());
    for (final opcion in _opciones) {
      expect(find.text(opcion), findsOneWidget);
    }
    expect(_cursor(tester), isNull);
    // Cada opción es un botón de 48 de alto como mínimo.
    for (var i = 0; i < _opciones.length; i++) {
      expect(tester.getSize(_fila(i)).height, greaterThanOrEqualTo(48));
      expect(_semantica(tester, i), isSemantics(isButton: true, isEnabled: true, hasTapAction: true));
    }
  });

  testWidgets('el cursor va a la opción con el ratón encima', (tester) async {
    final raton = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await raton.addPointer(location: Offset.zero);
    addTearDown(raton.removePointer);
    await montar(tester, const _Menu());
    await raton.moveTo(tester.getCenter(find.text(_opciones[1])));
    await tester.pump();
    expect(_cursor(tester), 1);
    expect(_caja(tester, 1).estilo.relleno, ColoresUiPixel.amarillo, reason: 'la opción con el cursor se ilumina');
    await raton.moveTo(tester.getCenter(find.text(_opciones[2])));
    await tester.pump();
    expect(_cursor(tester), 2);
  });

  testWidgets('el cursor va a la opción con el foco del teclado', (tester) async {
    await montar(tester, const _Menu());
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump();
    expect(_cursor(tester), 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump();
    expect(_cursor(tester), 1);
    expect(_semantica(tester, 1), isSemantics(isFocused: true));
  });

  testWidgets('el cursor va a la opción que se pulsa, que baja, y al soltar se elige', (tester) async {
    final elegidas = <int>[];
    await montar(tester, _Menu(alElegir: elegidas.add));
    final dedo = await tester.startGesture(tester.getCenter(find.text(_opciones[2])));
    await tester.pump();
    expect(_cursor(tester), 2);
    expect(_caja(tester, 2).pulsada, isTrue);
    expect(elegidas, isEmpty);
    await dedo.up();
    await tester.pump();
    expect(elegidas, [2]);
    // Termina de bajar ya con su resultado y vuelve a subir.
    await tester.pump(const Duration(milliseconds: 150));
    expect(_caja(tester, 2).pulsada, isFalse);
  });

  testWidgets('con cursorInicial, el ► está pero la opción no se resalta hasta que se toca algo', (tester) async {
    final raton = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await raton.addPointer(location: Offset.zero);
    addTearDown(raton.removePointer);
    await montar(tester, const _Menu(cursorInicial: 1));
    expect(_cursor(tester), 1);
    for (var i = 0; i < _opciones.length; i++) {
      expect(_caja(tester, i).estilo.relleno, ColoresUiPixel.papel, reason: 'ninguna parece la buena');
    }
    await raton.moveTo(tester.getCenter(find.text(_opciones[1])));
    await tester.pump();
    expect(_caja(tester, 1).estilo.relleno, ColoresUiPixel.amarillo);
    await desmontar(tester);
  });

  testWidgets('al acertar: verde con ✓, el lector lo dice y vibra', (tester) async {
    final vibraciones = registrarVibraciones(tester);
    await montar(tester, const _Menu());
    await tester.tap(find.text(_opciones[0]));
    await tester.pump();
    expect(_caja(tester, 0).estilo.relleno, ColoresUiPixel.verdeOscuro);
    expect(find.descendant(of: _fila(0), matching: _glifo(GlifoPixel.check)), findsOneWidget);
    expect(find.descendant(of: _fila(1), matching: _glifo(GlifoPixel.check)), findsNothing);
    // El resultado va en la etiqueta de la elegida, que es una región en vivo: el lector lo dice al momento. Ya no es
    // un botón (ni «desactivado»): es texto con su resultado.
    expect(
      _semantica(tester, 0),
      isSemantics(
        label: 'Una citación. Tu respuesta: correcta.',
        isLiveRegion: true,
        isSelected: true,
        isButton: false,
        hasEnabledState: false,
        hasTapAction: false,
      ),
    );
    expect(_semantica(tester, 1), isSemantics(label: 'Una multa', isLiveRegion: false, hasEnabledState: false));
    expect(_cursor(tester), 0);
    expect(vibraciones, ['HapticFeedbackType.selectionClick', 'HapticFeedbackType.mediumImpact']);
  });

  testWidgets('al fallar: la elegida en teja con ✗ y se enseña la correcta con su ✓', (tester) async {
    final vibraciones = registrarVibraciones(tester);
    await montar(tester, const _Menu());
    await tester.tap(find.text(_opciones[1]));
    await tester.pump();
    expect(_caja(tester, 1).estilo.relleno, ColoresUiPixel.teja);
    expect(find.descendant(of: _fila(1), matching: _glifo(GlifoPixel.cruz)), findsOneWidget);
    expect(find.descendant(of: _fila(0), matching: _glifo(GlifoPixel.check)), findsOneWidget);
    expect(_caja(tester, 0).estilo.anillo, ColoresUiPixel.verdeOscuro);
    expect(_caja(tester, 2).estilo.sombra, isNull, reason: 'las demás se apagan');
    expect(
      _semantica(tester, 1),
      isSemantics(
        label: 'Una multa. Tu respuesta: no es correcta. La correcta era: Una citación.',
        isLiveRegion: true,
        isSelected: true,
      ),
    );
    expect(
      _semantica(tester, 0),
      isSemantics(label: 'Una citación', value: 'Esta era la respuesta correcta', isSelected: false),
    );
    expect(vibraciones, ['HapticFeedbackType.selectionClick']);
  });

  testWidgets('decidido, ya no se puede elegir otra', (tester) async {
    final elegidas = <int>[];
    await montar(tester, _Menu(alElegir: elegidas.add));
    await tester.tap(find.text(_opciones[1]));
    await tester.pump();
    await tester.tap(find.text(_opciones[2]));
    await tester.pump();
    await tester.tap(find.text(_opciones[0]));
    await tester.pump();
    expect(elegidas, [1]);
    expect(_cursor(tester), 1);
  });

  testWidgets('con teclado: Intro elige la opción con el foco, que lo conserva al decidir', (tester) async {
    final elegidas = <int>[];
    await montar(tester, _Menu(alElegir: elegidas.add));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(elegidas, [1]);
    await tester.pump();
    // El foco no se va al principio de la pantalla justo cuando sale la corrección.
    expect(_semantica(tester, 1), isSemantics(isFocused: true));
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Opción 2');
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('el cursor se balancea una unidad, salvo con «reducir animaciones»', (tester) async {
    double desplazamiento() => tester
        .widget<Padding>(find.ancestor(of: _glifo(GlifoPixel.flecha), matching: find.byType(Padding)).first)
        .padding
        .resolve(TextDirection.ltr)
        .left;

    await montar(tester, const _Menu(cursorInicial: 0));
    expect(_cursor(tester), 0);
    final antes = desplazamiento();
    await tester.pump(const Duration(milliseconds: 420));
    expect(desplazamiento(), isNot(antes));
    expect((desplazamiento() - antes).abs(), 3, reason: 'una unidad pixel');
    await desmontar(tester);

    await montar(tester, const _Menu(cursorInicial: 0), reducir: true);
    final quieto = desplazamiento();
    await tester.pump(const Duration(seconds: 2));
    expect(desplazamiento(), quieto);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('el cursor deja de balancearse a los 8 segundos (y vuelve si cambia de opción)', (tester) async {
    double desplazamiento() => tester
        .widget<Padding>(find.ancestor(of: _glifo(GlifoPixel.flecha), matching: find.byType(Padding)).first)
        .padding
        .resolve(TextDirection.ltr)
        .left;

    await montar(tester, const _Menu(cursorInicial: 0));
    await tester.pump(const Duration(seconds: 9));
    final quieto = desplazamiento();
    expect(quieto, 0);
    await tester.pump(const Duration(seconds: 2));
    expect(desplazamiento(), quieto);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));
    expect(desplazamiento(), 3, reason: 'en la opción nueva vuelve a moverse');
    await desmontar(tester);
  });

  testWidgets('sin respuestas correctas, la elegida solo queda marcada', (tester) async {
    await montar(tester, const _Menu(correctas: null));
    await tester.tap(find.text(_opciones[2]));
    await tester.pump();
    expect(_caja(tester, 2).estilo.relleno, ColoresUiPixel.amarillo);
    expect(find.descendant(of: _fila(2), matching: _glifo(GlifoPixel.check)), findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget is IconoPixel && widget.glifo == GlifoPixel.cruz), findsNothing);
    expect(_semantica(tester, 2), isSemantics(label: 'Una nota del instituto. Tu respuesta.', isSelected: true));
  });

  testWidgets('el menú lleva la pregunta para el lector de pantalla', (tester) async {
    await montar(tester, const _Menu());
    expect(find.bySemanticsLabel('¿Qué es este papel?'), findsOneWidget);
  });

  testWidgets('con letra grande y opciones largas no se desborda', (tester) async {
    await montar(
      tester,
      MenuOpcionesPixel(
        opciones: const ['Una citación: dice cuándo y dónde tiene que ir a declarar', 'Una multa'],
        onElegir: (_) {},
        cursorInicial: 0,
      ),
      escalaTexto: 1.3,
      tamano: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('se quita con el cursor balanceándose sin dejar temporizadores', (tester) async {
    await montar(tester, const _Menu(cursorInicial: 1));
    await tester.pump(const Duration(milliseconds: 500));
    await desmontar(tester);
  });
}
