import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/voz/tts.dart';
import 'package:tuturno/features/pasos/linea_pasos.dart' show tooltipEscuchar, tooltipParar;
import 'package:tuturno/features/pasos/pasos.dart';

import 'datos.dart';

// «Escuchar este paso» (plan v2, producto §5.2): cada tarjeta se puede escuchar con la voz de la app (ttsProvider, con
// la velocidad de Ajustes). Un paso a la vez; se para al tocarlo otra vez, al salir, al tocar otro y si la app pasa a
// segundo plano.

class _TtsFalso implements Tts {
  final leidos = <String>[];
  int paradas = 0;
  final _hablando = ValueNotifier(false);

  @override
  ValueListenable<bool> get hablando => _hablando;

  /// No termina sola: así se ve el estado «leyendo».
  @override
  Future<void> hablar(String texto, {double? velocidad}) async {
    leidos.add(texto);
    _hablando.value = true;
  }

  @override
  Future<void> parar() async {
    paradas++;
    _hablando.value = false;
  }

  void terminar() => _hablando.value = false;
}

/// El botón «Escuchar» (o «Parar») de la tarjeta del paso [nombre].
Finder _escucharDe(String nombre, {String tooltip = tooltipEscuchar}) => find.descendant(
  of: find.ancestor(of: find.text(nombre), matching: find.byType(AnimatedContainer)).first,
  matching: find.byTooltip(tooltip),
);

Future<_TtsFalso> _montar(WidgetTester tester) async {
  final tts = _TtsFalso();
  await montarLinea(
    tester,
    repo: repoCon({real('victima'): itinerarioConFases}).$1,
    overrides: [ttsProvider.overrideWithValue(tts)],
  );
  return tts;
}

void main() {
  testWidgets('lee el paso empezando por su nombre: qué pasa, quién estará y qué puedes pedir', (tester) async {
    final tts = await _montar(tester);
    const nombre = 'La entrevista en la Sala Gesell';
    final boton = _escucharDe(nombre);
    expect(boton, findsOneWidget);
    expect(tester.getSize(boton).width, greaterThanOrEqualTo(48));

    await tester.ensureVisible(boton);
    await tester.pumpAndSettle();
    await tester.tap(boton);
    await tester.pump();

    expect(tts.leidos, hasLength(1));
    final texto = tts.leidos.single;
    expect(texto, startsWith('$nombre.'));
    expect(texto, contains('Te hace las preguntas una persona preparada'));
    expect(texto, contains('Quién estará: Una psicóloga o un psicólogo del juzgado'));
    expect(texto, contains('Qué puedes pedir: Un descanso; Que te repitan una pregunta.'));
    // Mientras lee, el botón dice «Parar».
    expect(_escucharDe(nombre, tooltip: tooltipParar), findsOneWidget);
  });

  testWidgets('tocarlo otra vez para la voz', (tester) async {
    final tts = await _montar(tester);
    const nombre = 'Te llega una citación';
    await tester.tap(_escucharDe(nombre));
    await tester.pump();
    await tester.tap(_escucharDe(nombre, tooltip: tooltipParar));
    await tester.pump();

    expect(tts.paradas, 1);
    expect(_escucharDe(nombre), findsOneWidget);
  });

  testWidgets('uno a la vez: al tocar otro paso, se lee ese y el primero vuelve a «Escuchar»', (tester) async {
    final tts = await _montar(tester);
    await tester.tap(_escucharDe('Te llega una citación'));
    await tester.pump();
    await tester.tap(_escucharDe('Te explican tus derechos'));
    await tester.pump();

    expect(tts.leidos, hasLength(2));
    expect(tts.leidos.last, startsWith('Te explican tus derechos.'));
    expect(_escucharDe('Te llega una citación'), findsOneWidget);
    expect(_escucharDe('Te explican tus derechos', tooltip: tooltipParar), findsOneWidget);
  });

  testWidgets('cuando la lectura termina sola, el botón vuelve a «Escuchar»', (tester) async {
    final tts = await _montar(tester);
    await tester.tap(_escucharDe('Te llega una citación'));
    await tester.pump();
    tts.terminar();
    await tester.pump();
    expect(_escucharDe('Te llega una citación'), findsOneWidget);
    expect(tts.paradas, 0);
  });

  testWidgets('al salir de la pantalla, la voz se para', (tester) async {
    final tts = await _montar(tester);
    await tester.tap(_escucharDe('Te llega una citación'));
    await tester.pump();

    // Se va la pantalla (como al volver atrás).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tts.paradas, 1);
  });

  testWidgets('si la app pasa a segundo plano, la voz se para', (tester) async {
    final tts = await _montar(tester);
    await tester.tap(_escucharDe('Te llega una citación'));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(tts.paradas, greaterThanOrEqualTo(1));
    // De vuelta, por los estados de siempre.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('sin leer nada, salir no llama a parar (no corta la voz de otra pantalla)', (tester) async {
    final tts = await _montar(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tts.paradas, 0);
  });

  test('el texto que se escucha añade lo que cambia para ti y quita las referencias [A-017]', () {
    final paso = itinerarioDe(itinerarioConFases).pasos.first;
    final texto = textoParaEscuchar(
      paso,
      extras: const ExtrasPaso(paraTi: [NotaParaTi(texto: 'Como tienes 11 años, se graba [A-050]')]),
    );
    expect(texto, startsWith('Te llega una citación.'));
    expect(texto, contains('Para ti: Como tienes 11 años, se graba.'));
    expect(texto, isNot(contains('[A-050]')));
  });
}
