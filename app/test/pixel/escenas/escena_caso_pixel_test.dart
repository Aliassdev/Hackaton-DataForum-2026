import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/escenarios/escenarios.dart';
import 'package:tuturno/pixel/escenas/escenas.dart';
import 'package:tuturno/pixel/motor/motor.dart';
import 'package:tuturno/pixel/personajes/personajes.dart';
import 'package:tuturno/pixel/ui/ui.dart' show MarcoPixel;

/// Las escenas de los casos del contenido: (caso, id, lugar, personajes).
List<(String, String, String, List<String>)> _escenas() => [
  for (final archivo in Directory('assets/mock/content/juego').listSync().whereType<File>())
    if (archivo.path.endsWith('.json'))
      for (final escena in ((jsonDecode(archivo.readAsStringSync()) as Map)['escenas'] as List).cast<Map>())
        (
          archivo.uri.pathSegments.last,
          escena['id'] as String,
          escena['lugar'] as String,
          (escena['personajes'] as List).cast<String>(),
        ),
];

/// Las personas de un montaje (los elementos con sprite de personaje), por su id de [PersonajesPixel].
Map<String, ElementoEscena> _personas(MontajeEscenaCaso montaje) => {
  for (final elemento in montaje.elementos)
    for (final id in montaje.ids)
      if (identical(elemento.sprite, PersonajesPixel.porId(id))) id: elemento,
};

void main() {
  group('montarEscenaCaso', () {
    test('cada escena de los casos sale con todas sus personas, dentro del fondo y sin pisarse', () {
      final escenas = _escenas();
      expect(escenas.length, greaterThanOrEqualTo(19), reason: 'las 11 escenas de Lucía y las 8 de Sergio');
      for (final (caso, id, lugar, personajes) in escenas) {
        final montaje = montarEscenaCaso(lugar, personajes);
        final donde = '$caso, $id ($lugar)';
        expect(montaje.escenario.lugar, EscenariosPixel.clave(lugar), reason: donde);
        final personas = _personas(montaje);
        expect(personas.keys.toSet(), montaje.ids.toSet(), reason: donde);
        expect(montaje.ids, isNotEmpty, reason: donde);
        for (final elemento in personas.values) {
          final rect = elemento.rectPixel;
          expect(rect.left, greaterThanOrEqualTo(0), reason: '$donde: ${elemento.sprite.nombre}');
          expect(rect.right, lessThanOrEqualTo(160), reason: '$donde: ${elemento.sprite.nombre}');
          expect(rect.bottom, lessThanOrEqualTo(96), reason: '$donde: ${elemento.sprite.nombre}');
        }
        // Nadie encima de nadie: los pies de cada persona, a 20 píxeles como mínimo de los de las demás.
        final xs = [for (final elemento in personas.values) elemento.x]..sort();
        for (var i = 1; i < xs.length; i++) {
          expect(xs[i] - xs[i - 1], greaterThanOrEqualTo(20), reason: donde);
        }
        for (final nombre in personajes) {
          expect(montaje.descripcion, contains(nombre), reason: donde);
        }
      }
    });

    test('la tutora, la madre y los dos padres de Sergio salen donde los nombra el contenido', () {
      expect(montarEscenaCaso('colegio', ['Lucía', 'Su tutora']).ids, ['lucia', 'tutora']);
      expect(montarEscenaCaso('fiscalia', ['Sergio', 'Su madre', 'El fiscal']).ids, [
        'sergio',
        'madre-sergio',
        'fiscal-despacho',
      ]);
      expect(montarEscenaCaso('casa', ['Sergio', 'Sus padres']).ids, ['sergio', 'padre-sergio', 'madre-sergio']);
    });

    test('en la Fiscalía, el fiscal va sin toga, tras su mesa, y el resto delante, lejos de él', () {
      final montaje = montarEscenaCaso('fiscalia', ['Sergio', 'Su madre', 'El fiscal']);
      final personas = _personas(montaje);
      final fiscal = personas['fiscal-despacho']!;
      expect((x: fiscal.x, y: fiscal.y), EscenariosPixel.fiscalia.puesto('fiscal'));
      final mesa = EscenariosPixel.fiscalia.delante.single;
      expect(montaje.elementos.indexOf(fiscal), lessThan(montaje.elementos.indexOf(mesa)), reason: 'la mesa le tapa');
      for (final id in ['sergio', 'madre-sergio']) {
        expect((personas[id]!.x - fiscal.x).abs(), greaterThanOrEqualTo(30), reason: id);
      }
      // Solo, Sergio se pone delante de la mesa.
      final solo = _personas(montarEscenaCaso('fiscalia', ['Sergio', 'El fiscal']))['sergio']!;
      expect((x: solo.x, y: solo.y), EscenariosPixel.fiscalia.puesto('centro'));
    });

    test('en la Sala Gesell, Lucía en el sofá y Ana en el sillón; dos personas, juntas a los lados del centro', () {
      final gesell = _personas(montarEscenaCaso('sala_gesell', ['Lucía', 'Ana, la psicóloga']));
      expect((x: gesell['lucia']!.x, y: gesell['lucia']!.y), EscenariosPixel.salaGesell.puesto('sofa'));
      expect((x: gesell['ana']!.x, y: gesell['ana']!.y), EscenariosPixel.salaGesell.puesto('sillon'));
      final colegio = _personas(montarEscenaCaso('colegio', ['Lucía', 'Su tutora']));
      final centro = EscenariosPixel.colegio.puesto('centro')!;
      expect(colegio['lucia']!.x, lessThan(centro.x));
      expect(colegio['tutora']!.x, greaterThan(centro.x));
      expect(colegio['tutora']!.x - colegio['lucia']!.x, lessThanOrEqualTo(48));
    });

    test('un nombre sin dibujo no sale, pero la escena se monta; un lugar sin fondo usa el de reserva', () {
      final montaje = montarEscenaCaso('hospital', ['Lucía', 'Su perro']);
      expect(montaje.escenario.lugar, EscenariosPixel.reserva);
      expect(montaje.ids, ['lucia']);
      expect(montaje.descripcion, contains('Lucía y Su perro'));
    });

    test('con tocables, cada persona tiene su id y su descripción; resaltado lleva el halo', () {
      final montaje = montarEscenaCaso('casa', ['Lucía'], tocables: true, resaltado: 'lucia');
      final lucia = _personas(montaje)['lucia']!;
      expect(lucia.id, 'lucia');
      expect(lucia.etiqueta, PersonajesPixel.ficha('lucia')!.descripcion);
      expect(lucia.resaltado, isTrue);
      expect(_personas(montarEscenaCaso('casa', ['Lucía']))['lucia']!.id, isNull);
    });
  });

  group('EscenaCasoPixel', () {
    Future<void> montar(WidgetTester tester, Widget hijo, {double dpr = 2.75, double ancho = 1080}) async {
      tester.view
        ..physicalSize = Size(ancho, 2400)
        ..devicePixelRatio = dpr;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [hijo]),
            ),
          ),
        ),
      );
    }

    testWidgets('el marco abraza la escena: escala entera, sin bandas a los lados, centrado', (tester) async {
      for (final (dpr, ancho) in [(2.75, 1080.0), (2.625, 1080.0), (3.0, 1080.0), (2.0, 720.0)]) {
        await montar(
          tester,
          const EscenaCasoPixel(lugar: 'colegio', personajes: ['Lucía', 'Su tutora']),
          dpr: dpr,
          ancho: ancho,
        );
        expect(tester.takeException(), isNull);
        final escena = tester.getRect(find.byType(EscenaPixel));
        final fisicos = escena.width * dpr / 160;
        expect(fisicos, closeTo(fisicos.roundToDouble(), 1e-6), reason: 'a $dpr: ${escena.width}');
        expect(escena.height * dpr, closeTo(96 * fisicos, 1e-6));
        final marco = tester.getRect(find.byType(MarcoPixel));
        expect(marco.center.dx, closeTo(ancho / dpr / 2, 1));
      }
    });

    testWidgets('los lectores de pantalla oyen el lugar y quién sale; con alPulsar, cada persona es un botón', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      final tocados = <String>[];
      await montar(
        tester,
        EscenaCasoPixel(lugar: 'sala_espera', personajes: const ['Lucía', 'Su tía Elena'], alPulsar: tocados.add),
      );
      expect(find.bySemanticsLabel(RegExp('La sala de espera.*En esta escena: Lucía y Su tía Elena')), findsOneWidget);
      final elena = PersonajesPixel.ficha('elena')!.descripcion;
      expect(tester.getSemantics(find.bySemanticsLabel(elena)), isSemantics(isButton: true, hasTapAction: true));
      await tester.tap(find.bySemanticsLabel(elena));
      expect(tocados, ['elena']);
      semantica.dispose();
    });

    testWidgets('compacta, para la portada: sin marco, quieta y sin semántica propia', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(
        tester,
        const SizedBox(
          height: 148,
          child: EscenaCasoPixel(lugar: 'colegio', personajes: ['Lucía', 'Su tutora'], compacta: true),
        ),
      );
      expect(find.byType(MarcoPixel), findsNothing);
      expect(tester.takeException(), isNull);
      // Llena toda la portada (sin bandas a los lados), a escala entera, y lo que sobra se recorta.
      final escena = tester.getRect(find.byType(EscenaPixel));
      final columna = tester.getRect(find.byType(Column).first);
      final fisicos = escena.width * 2.75 / 160;
      expect(fisicos, closeTo(fisicos.roundToDouble(), 1e-6));
      expect(escena.width, greaterThanOrEqualTo(columna.width));
      expect(escena.width - columna.width, lessThan(160 / 2.75), reason: 'una escala de más, como mucho');
      expect(escena.height, greaterThan(148));
      expect(RelojPixel.debugEnMarcha, 0);
      expect(find.bySemanticsLabel(RegExp('colegio|aula', caseSensitive: false)), findsNothing);
      semantica.dispose();
    });

    testWidgets('se anima y para su reloj al salir; con «reducir animaciones», quieta', (tester) async {
      final antes = RelojPixel.debugEnMarcha;
      await montar(tester, const EscenaCasoPixel(lugar: 'casa', personajes: ['Lucía']));
      expect(RelojPixel.debugEnMarcha, antes + 1);
      await tester.pumpWidget(const SizedBox());
      expect(RelojPixel.debugEnMarcha, antes);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Column(
              children: [
                EscenaCasoPixel(lugar: 'casa', personajes: const ['Lucía']),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(RelojPixel.debugEnMarcha, antes);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
