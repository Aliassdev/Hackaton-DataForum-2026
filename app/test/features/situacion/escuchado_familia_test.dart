import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/features/pregunta/pregunta_screen.dart';
import 'package:tuturno/features/situacion/situacion_screen.dart';
import 'package:tuturno/widgets/movimiento/ticket.dart';

import 'ayudantes.dart';

// «Escuchado en familia» (cuarto papel de Mi situación): su itinerario propio, su sitio en el selector («Me van a
// escuchar»: «En un proceso de familia, por ejemplo una separación») y Pregunta sin situación, porque no es uno de los
// tres papeles del contrato de la API (sección 8).

void main() {
  testWidgets('/situacion/escuchado_familia enseña su itinerario, con su carátula y su icono', (tester) async {
    final router = await arrancarSituacion(tester);
    await abrir(tester, router, '/situacion/escuchado_familia');

    final pantalla = tester.widget<SituacionScreen>(find.byType(SituacionScreen));
    expect(pantalla.rol, isNull);
    expect(pantalla.rolId, 'escuchado_familia');
    expect(find.text('Tu camino cuando te escuchan'), findsOneWidget);
    expect(find.text('Te van a escuchar en un proceso de familia'), findsOneWidget);
    expect(find.text('Te avisan de que te quieren escuchar'), findsOneWidget);
    expect(find.text('Hablas con el juez o la jueza'), findsOneWidget);
    expect(find.textContaining('No es un examen'), findsOneWidget);
  });

  testWidgets('«Pregúntale a TuTurno» abre Pregunta sin situación', (tester) async {
    final router = await arrancarSituacion(tester);
    await abrir(tester, router, '/situacion/escuchado_familia');
    await tocar(tester, find.text('Pregúntale a TuTurno'));
    await tester.pump(const Duration(milliseconds: 600));

    final pregunta = tester.widget<PreguntaScreen>(find.byType(PreguntaScreen));
    expect(pregunta.situacion, isNull);
    expect(router.state.uri.queryParameters.containsKey('situacion'), isFalse);
  });

  testWidgets('«Pregúntaselo a TuTurno» desde un paso también va sin situación, con la duda escrita', (tester) async {
    final router = await arrancarSituacion(tester);
    await abrir(tester, router, '/situacion/escuchado_familia');
    await tocar(tester, find.text('Te avisan de que te quieren escuchar'));
    await tocar(tester, find.text('Pregúntaselo a TuTurno').first);
    await tester.pump(const Duration(milliseconds: 600));

    final pregunta = tester.widget<PreguntaScreen>(find.byType(PreguntaScreen));
    expect(pregunta.situacion, isNull);
    expect(pregunta.preguntaInicial, '¿Por qué me quiere escuchar el juez?');
  });

  testWidgets('sale en el selector como «Me van a escuchar», con su explicación, y lleva a su camino', (tester) async {
    final router = await arrancarSituacion(tester);
    await abrir(tester, router, '/situacion/elegir');

    final ticket = find.ancestor(of: find.text('Me van a escuchar'), matching: find.byType(TicketTuTurno));
    expect(ticket, findsOneWidget);
    expect(
      find.descendant(of: ticket, matching: find.text('En un proceso de familia, por ejemplo una separación.')),
      findsOneWidget,
    );
    await tocar(tester, ticket);
    expect(router.state.uri.path, '/situacion/escuchado_familia');
  });

  testWidgets('con 12 años en el ticket: el juez tiene que escucharle (LEC, art. 770) y su momento se marca', (
    tester,
  ) async {
    final router = await arrancarSituacion(
      tester,
      preferencias: {
        'entrada': jsonEncode({'edad': 12, 'procedimiento': 'familia', 'rol': 'escuchado_familia', 'fase': 'durante'}),
      },
    );
    await abrir(tester, router, '/situacion/escuchado_familia');

    expect(find.textContaining('Con 12 años, si tus padres no se ponen de acuerdo'), findsWidgets);
    expect(find.text('LEC · art. 770'), findsWidgets);
    expect(find.bySemanticsLabel('Durante. Estás aquí'), findsOneWidget);
    // Desde su propio camino no se le ofrece ir al de familia.
    expect(find.text('Ver ese camino'), findsNothing);
  });

  testWidgets('desde otro papel con un proceso de familia, una nota lleva al camino «Me van a escuchar»', (
    tester,
  ) async {
    final router = await arrancarSituacion(
      tester,
      preferencias: {
        'entrada': jsonEncode({'edad': 12, 'procedimiento': 'familia', 'rol': 'testigo'}),
      },
    );
    await abrir(tester, router, '/situacion/testigo');
    await tocar(tester, find.text('Ver ese camino'));
    expect(router.state.uri.path, '/situacion/escuchado_familia');
    expect(tester.takeException(), isNull);
  });

  testWidgets('cabe con letra grande en un móvil pequeño', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final router = await arrancarSituacion(tester, tamano: const Size(360, 640));
    await abrir(tester, router, '/situacion/escuchado_familia');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
