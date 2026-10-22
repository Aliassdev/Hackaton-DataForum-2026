import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/voz/tts.dart';
import 'package:tuturno/features/glosario/detalle_termino.dart';
import 'package:tuturno/widgets/iconos/iconos.dart';

import '../a1/helpers.dart';
import 'ayudantes.dart';

// «Escuchar» en el detalle del glosario (plan v2, producto §5.7), con una voz falsa.

/// Abre el glosario de prueba y el detalle de [termino], con la voz [tts].
Future<void> _abrirDetalle(
  WidgetTester tester,
  TtsFalso tts, {
  String termino = 'Citación',
  Map<String, Object> preferencias = const {},
}) async {
  final router = await arrancarApp(tester, preferencias: preferencias, overrides: [ttsProvider.overrideWithValue(tts)]);
  await irA(tester, router, '/glosario');
  await tester.tap(find.text(termino));
  await tester.pumpAndSettle();
  expect(find.byType(DetalleTermino), findsOneWidget);
}

Future<void> _cerrarDetalle(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(DetalleTermino))).pop();
  await tester.pumpAndSettle();
  expect(find.byType(DetalleTermino), findsNothing);
}

/// El icono del botón de la voz.
TuIcono _iconoVoz(WidgetTester tester) => tester
    .widget<IconoTuTurno>(
      find.descendant(of: find.byKey(const Key('glosario-escuchar')), matching: find.byType(IconoTuTurno)),
    )
    .icono;

void main() {
  test('el texto: el término, la definición y el ejemplo; sin ejemplo, sin «Ejemplo»', () {
    final con = palabra(
      'G-citacion',
      'Citación',
      definicion: 'Documento del juzgado que te dice cuándo y dónde tienes que ir',
      ejemplo: 'A Lucía le llegó una citación.',
    );
    expect(
      textoParaEscuchar(con),
      'Citación. Documento del juzgado que te dice cuándo y dónde tienes que ir. Ejemplo: A Lucía le llegó una citación.',
    );
    final sin = palabra('G-testigo', 'Testigo', definicion: 'Persona que cuenta lo que sabe. [A-010]');
    expect(textoParaEscuchar(sin), 'Testigo. Persona que cuenta lo que sabe.');
  });

  testWidgets('«Escuchar» lee el término, la definición y el ejemplo, y pasa a «Parar»', (tester) async {
    final tts = TtsFalso();
    await _abrirDetalle(tester, tts);
    expect(find.text('Escuchar'), findsOneWidget);
    expect(_iconoVoz(tester), TuIcono.altavoz);

    await pulsar(tester, find.text('Escuchar'));
    expect(tts.leidos, hasLength(1));
    final leido = tts.leidos.single;
    expect(leido, startsWith('Citación.'));
    expect(leido, contains('Documento del juzgado que te dice cuándo y dónde tienes que ir.'));
    expect(leido, endsWith('Ejemplo: A Lucía le llegó una citación para declarar como testigo.'));
    // Con la velocidad de Ajustes (0,5 por defecto).
    expect(tts.velocidades.single, 0.5);
    expect(find.text('Parar'), findsOneWidget);
    expect(_iconoVoz(tester), TuIcono.silencio);

    await pulsar(tester, find.text('Parar'));
    expect(tts.paradas, 1);
    expect(find.text('Escuchar'), findsOneWidget);
  });

  testWidgets('al cerrar el detalle mientras lee, se para la voz', (tester) async {
    final tts = TtsFalso();
    await _abrirDetalle(tester, tts);
    await pulsar(tester, find.text('Escuchar'));
    expect(tts.paradas, 0);

    await _cerrarDetalle(tester);
    expect(tts.paradas, 1);
  });

  testWidgets('si la lectura ya ha terminado, vuelve a «Escuchar» y al cerrar no corta nada', (tester) async {
    final tts = TtsFalso(terminarAlInstante: true);
    await _abrirDetalle(tester, tts);
    await pulsar(tester, find.text('Escuchar'));
    expect(tts.leidos, hasLength(1));
    expect(find.text('Escuchar'), findsOneWidget);

    await _cerrarDetalle(tester);
    expect(tts.paradas, 0, reason: 'la voz es de toda la app: solo se para la lectura del glosario');
  });

  testWidgets('funciona aunque «Leer las respuestas en voz alta» esté desactivado', (tester) async {
    final tts = TtsFalso();
    await _abrirDetalle(tester, tts, preferencias: {'ajustes.voz_activada': false, 'ajustes.velocidad_voz': 0.3});
    await pulsar(tester, find.text('Escuchar'));
    expect(tts.leidos.single, startsWith('Citación.'));
    expect(tts.velocidades.single, 0.3);
  });

  testWidgets('una palabra sin ejemplo se lee sin «Ejemplo»', (tester) async {
    final tts = TtsFalso();
    await _abrirDetalle(tester, tts, termino: 'Abogado o abogada');
    await pulsar(tester, find.text('Escuchar'));
    expect(tts.leidos.single, 'Abogado o abogada. Persona que conoce las leyes y te defiende.');
  });

  testWidgets('si la app pasa a segundo plano, se calla', (tester) async {
    final tts = TtsFalso();
    await _abrirDetalle(tester, tts);
    await pulsar(tester, find.text('Escuchar'));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(tts.paradas, 1);
    // Al volver, el botón ya dice «Escuchar».
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Escuchar'), findsOneWidget);
  });

  testWidgets('abrir una palabra no lee nada solo', (tester) async {
    final tts = TtsFalso();
    await _abrirDetalle(tester, tts);
    expect(tts.leidos, isEmpty);
    await _cerrarDetalle(tester);
    expect(tts.paradas, 0);
  });
}
