import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/features/juego/juego_providers.dart';
import 'package:tuturno/features/juego/modelos.dart';
import 'package:tuturno/features/juego/widgets/cabecera_escena.dart';
import 'package:tuturno/pixel/escenarios/escenarios.dart';
import 'package:tuturno/pixel/escenas/escenas.dart';
import 'package:tuturno/pixel/motor/motor.dart';
import 'package:tuturno/pixel/personajes/personajes.dart';
import 'package:tuturno/tema.dart';

import 'fakes.dart';

// La ilustración de cada escena en pixel art (CabeceraEscena): el lugar y quién sale, enmarcado como la pantalla de un
// juego, con las fichas de quién sale debajo.

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
  testWidgets('pinta el lugar en pixel con quién sale, y las fichas debajo para el lector de pantalla', (tester) async {
    final semantica = tester.ensureSemantics();
    await _pintar(tester, CabeceraEscena(escena: _caso.escena('E1')!, protagonista: 'Nora'));

    expect(find.byType(EscenaCasoPixel), findsOneWidget);
    expect(tester.widget<EscenaPixel>(find.byType(EscenaPixel)).fondo, same(EscenariosPixel.colegio.fondo));
    expect(find.text('Nora'), findsOneWidget);
    expect(find.text('Su tutor'), findsOneWidget);
    expect(find.bySemanticsLabel('En el colegio. ${EscenariosPixel.colegio.descripcion}'), findsOneWidget);
    expect(find.bySemanticsLabel('En esta escena: Nora y Su tutor'), findsOneWidget);
    expect(tester.getSize(find.byType(EscenaCasoPixel)).height, greaterThanOrEqualTo(CabeceraEscena.altoMinimo));
    semantica.dispose();
  });

  testWidgets('sin fichas, la escena sola (el reproductor la deja fija arriba)', (tester) async {
    await _pintar(tester, CabeceraEscena(escena: _caso.escena('E1')!, protagonista: 'Nora', conFichas: false));
    expect(find.byType(EscenaCasoPixel), findsOneWidget);
    expect(find.byType(FichasPersonajes), findsNothing);
  });

  testWidgets('la versión compacta (portada del caso) no tiene fichas ni semántica propia', (tester) async {
    final semantica = tester.ensureSemantics();
    await _pintar(tester, CabeceraEscena(escena: _caso.primera, protagonista: 'Nora', compacta: true));

    expect(find.text('Nora'), findsNothing);
    expect(find.byType(FichasPersonajes), findsNothing);
    expect(tester.getSize(find.byType(CabeceraEscena)).height, CabeceraEscena.altoCompacta);
    expect(find.bySemanticsLabel(RegExp('colegio')), findsNothing);
    semantica.dispose();
  });

  testWidgets('con letra grande y muchos personajes no se desborda', (tester) async {
    const escena = Escena(
      id: 'X',
      lugar: 'sala_espera',
      narracion: '',
      personajes: ['Lucía', 'Su tía Elena', 'Ana, la psicóloga', 'La jueza', 'El abogado', 'Su perro'],
    );
    await _pintar(tester, const CabeceraEscena(escena: escena, protagonista: 'Lucía'), oscuro: true, escala: 1.3);

    expect(tester.takeException(), isNull);
    expect(find.text('El abogado'), findsOneWidget);
    expect(find.text('Su perro'), findsOneWidget, reason: 'sin dibujo no sale en la escena, pero sí en su ficha');
  });

  group('de los nombres del contenido a los personajes pixel', () {
    test('el posesivo lo aclara el caso: cada caso tiene su familia', () {
      expect(idsPersonaje('Su madre', lugar: 'habitacion', protagonista: 'Sara'), ['madre-sara']);
      expect(idsPersonaje('Su madre', lugar: 'fiscalia', protagonista: 'Sergio'), ['madre-sergio']);
      expect(idsPersonaje('Sus padres', lugar: 'casa', protagonista: 'Sergio'), ['padre-sergio', 'madre-sergio']);
      expect(idsPersonaje('Su tía Elena', lugar: 'juzgado', protagonista: 'Lucía'), ['elena']);
      expect(idsPersonaje('Su amiga Nadia', lugar: 'instituto', protagonista: 'Sara'), ['amiga-sara']);
      expect(nombreParaPixel('Su madre', 'Sara'), 'Su madre de Sara');
      expect(nombreParaPixel('El fiscal', 'Sara'), 'El fiscal');
    });

    test('fuera de la sala nadie lleva toga (Reglamento 2/2005 del CGPJ, art. 33)', () {
      expect(idsPersonaje('El fiscal', lugar: 'fiscalia'), ['fiscal-despacho']);
      expect(idsPersonaje('El fiscal de menores', lugar: 'fiscalia', protagonista: 'Sara'), ['fiscal-despacho']);
      expect(idsPersonaje('Su abogada', lugar: 'fiscalia', protagonista: 'Sara'), ['abogada-despacho']);
    });

    test('todas las personas de los tres casos oficiales tienen dibujo', () {
      for (final json in casosOficiales().values) {
        final caso = Caso.fromJson(jsonDecode(json) as Map<String, dynamic>);
        for (final escena in caso.escenas) {
          for (final nombre in escena.personajes) {
            final ids = idsPersonaje(nombre, lugar: escena.lugar, protagonista: caso.protagonista);
            expect(ids, isNotEmpty, reason: '${caso.id}, ${escena.id}: «$nombre»');
            for (final id in ids) {
              expect(PersonajesPixel.porId(id), isNotNull, reason: id);
            }
          }
        }
      }
    });

    test('nada de togas en la Sala Gesell, la Fiscalía ni los pasillos de los casos', () {
      const conToga = {'jueza', 'fiscal', 'abogada-victima', 'abogado-defensa', 'letrada'};
      for (final json in casosOficiales().values) {
        final caso = Caso.fromJson(jsonDecode(json) as Map<String, dynamic>);
        for (final escena in caso.escenas) {
          final ids = {
            for (final nombre in escena.personajes)
              ...idsPersonaje(nombre, lugar: escena.lugar, protagonista: caso.protagonista),
          };
          expect(ids.intersection(conToga), isEmpty, reason: '${caso.id}, ${escena.id} (${escena.lugar})');
        }
      }
    });
  });

  testWidgets('el reproductor pinta una escena pixel por escena, y cambia con ella', (tester) async {
    await abrirJuego(tester, ruta: '/juego/caso-prueba', overrides: await overridesJuego());
    final cabeceras = find.byWidgetPredicate((w) => w is CabeceraEscena && !w.compacta);
    expect(cabeceras, findsOneWidget);
    expect(tester.widget<CabeceraEscena>(cabeceras).escena.id, 'E1');

    await contenedor(tester).read(partidaProvider('caso-prueba').notifier).elegir(1);
    await contenedor(tester).read(partidaProvider('caso-prueba').notifier).avanzar();
    await tester.pumpAndSettle();
    expect(tester.widget<CabeceraEscena>(cabeceras).escena.id, 'E2');
    expect(
      tester.widget<EscenaPixel>(find.descendant(of: cabeceras, matching: find.byType(EscenaPixel))).fondo,
      same(EscenariosPixel.juzgado.fondo),
    );
  });
}
