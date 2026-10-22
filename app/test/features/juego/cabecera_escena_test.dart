import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/features/juego/juego_providers.dart';
import 'package:tuturno/features/juego/modelos.dart';
import 'package:tuturno/features/juego/textos.dart';
import 'package:tuturno/features/juego/widgets/cabecera_escena.dart';
import 'package:tuturno/tema.dart';

import 'fakes.dart';

// El hueco de la ilustración de cada escena: un solo widget (CabeceraEscena) con el lugar y los personajes, que el
// equipo de pixel art sustituirá.

final _caso = Caso.fromJson(jsonDecode(casoPrueba) as Map<String, dynamic>);

Future<void> _pintar(WidgetTester tester, Widget hijo, {bool oscuro = false, double escala = 1}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: temaTuTurno(oscuro ? Brightness.dark : Brightness.light),
      home: MediaQuery(
        data: MediaQueryData(size: const Size(360, 740), textScaler: TextScaler.linear(escala)),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [hijo]),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('enseña el lugar y a los personajes como fichas, y lo dice al lector de pantalla', (tester) async {
    final semantica = tester.ensureSemantics();
    await _pintar(tester, CabeceraEscena(escena: _caso.escena('E1')!, protagonista: 'Nora'));

    expect(find.text('En el colegio'), findsOneWidget);
    expect(find.text('Nora'), findsOneWidget);
    expect(find.text('Su tutor'), findsOneWidget);
    expect(find.bySemanticsLabel('En el colegio. En esta escena: Nora y Su tutor'), findsOneWidget);
    expect(tester.getSize(find.byType(CabeceraEscena)).height, greaterThanOrEqualTo(CabeceraEscena.altoMinimo));
    semantica.dispose();
  });

  testWidgets('la versión compacta (portada del caso) no tiene fichas ni semántica propia', (tester) async {
    await _pintar(tester, CabeceraEscena(escena: _caso.primera, protagonista: 'Nora', compacta: true));

    expect(find.text('Nora'), findsNothing);
    expect(find.text('En el colegio'), findsNothing);
    expect(tester.getSize(find.byType(CabeceraEscena)).height, CabeceraEscena.altoCompacta);
  });

  testWidgets('con letra grande y muchos personajes crece en vez de desbordarse', (tester) async {
    const escena = Escena(
      id: 'X',
      lugar: 'sala_espera',
      narracion: '',
      personajes: ['Lucía', 'Su tía Elena', 'Ana, la psicóloga', 'La jueza', 'El abogado'],
    );
    await _pintar(tester, const CabeceraEscena(escena: escena, protagonista: 'Lucía'), oscuro: true, escala: 1.3);

    expect(tester.takeException(), isNull);
    expect(find.text('En la sala de espera'), findsOneWidget);
    expect(find.text('El abogado'), findsOneWidget);
    expect(tester.getSize(find.byType(CabeceraEscena)).height, greaterThan(CabeceraEscena.altoMinimo));
  });

  testWidgets('el reproductor usa una sola cabecera por escena, y la lista una por caso', (tester) async {
    final router = await abrirJuego(tester, overrides: await overridesJuego());
    expect(find.byType(CabeceraEscena), findsOneWidget, reason: 'la portada del caso');

    router.push('/juego/caso-prueba');
    await tester.pumpAndSettle();
    expect(find.text(tituloCaso('Nora')), findsOneWidget);
    final cabeceras = find.byWidgetPredicate((w) => w is CabeceraEscena && !w.compacta);
    expect(cabeceras, findsOneWidget);
    expect(tester.widget<CabeceraEscena>(cabeceras).escena.id, 'E1');

    await contenedor(tester).read(partidaProvider('caso-prueba').notifier).elegir(1);
    await contenedor(tester).read(partidaProvider('caso-prueba').notifier).avanzar();
    await tester.pumpAndSettle();
    expect(tester.widget<CabeceraEscena>(cabeceras).escena.id, 'E2');
    expect(find.text('En el juzgado'), findsOneWidget);
  });
}
