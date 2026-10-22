import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/texto.dart';
import 'package:tuturno/features/juego/modelos.dart';
import 'package:tuturno/features/juego/motor.dart';
import 'package:tuturno/features/juego/widgets/estilo.dart';
import 'package:tuturno/pixel/escenarios/escenarios.dart';

// Comprueba los casos de ejemplo que se ven en la demo (assets/mock/content/juego): que siguen el esquema 9.4 al
// pie de la letra, que se pueden jugar de principio a fin y que respetan las reglas del contenido.

const _camposCaso = {'id', 'titulo', 'rol', 'basado_en', 'escenas', 'cartas', 'validado'};
const _camposEscena = {'id', 'lugar', 'personajes', 'narracion', 'decision', 'siguiente'};
const _camposDecision = {'pregunta', 'opciones'};
const _camposOpcion = {'texto', 'correcta', 'siguiente', 'feedback', 'fuente', 'carta'};
const _camposCarta = {'id', 'titulo', 'texto', 'fuente'};

final _ficheros =
    Directory('assets/mock/content/juego').listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));

Map<String, dynamic> _leer(File f) => jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('están los tres casos oficiales: Lucía, Sergio y Sara', () {
    final ids = [for (final f in _ficheros) _leer(f)['id']];
    expect(ids, containsAll(['caso-sala-gesell', 'caso-acoso-escolar', 'caso-difusion-imagenes']));
  });

  for (final fichero in _ficheros) {
    final nombre = fichero.uri.pathSegments.last;
    group(nombre, () {
      final json = _leer(fichero);
      final caso = Caso.fromJson(json);

      test('sigue el esquema 9.4: mismos campos y mismos tipos', () {
        expect(_camposCaso.containsAll(json.keys), isTrue, reason: 'campos de más: ${json.keys}');
        expect(json['id'], isA<String>());
        expect(json['titulo'], isA<String>());
        expect(json['rol'], isIn(['testigo', 'victima', 'investigado']));
        expect(json['basado_en'], isA<List<dynamic>>());
        expect(json['validado'], isTrue, reason: 'la app solo enseña lo validado');
        for (final e in json['escenas'] as List) {
          final escena = e as Map<String, dynamic>;
          expect(_camposEscena.containsAll(escena.keys), isTrue, reason: '${escena['id']}: ${escena.keys}');
          expect(escena['personajes'], isA<List<dynamic>>());
          expect(escena['narracion'], isA<String>());
          expect(
            escena.containsKey('decision') && escena.containsKey('siguiente'),
            isFalse,
            reason: '${escena['id']}: o decisión o siguiente, no las dos',
          );
          final decision = escena['decision'] as Map<String, dynamic>?;
          if (decision == null) continue;
          expect(_camposDecision.containsAll(decision.keys), isTrue);
          for (final o in decision['opciones'] as List) {
            final opcion = o as Map<String, dynamic>;
            expect(_camposOpcion.containsAll(opcion.keys), isTrue, reason: '${escena['id']}: ${opcion.keys}');
            expect(opcion['correcta'], isA<bool>());
          }
        }
        for (final c in json['cartas'] as List) {
          expect((c as Map<String, dynamic>).keys.toSet(), _camposCarta);
        }
      });

      test('todas las escenas tienen un lugar conocido, personajes y narración', () {
        final ids = <String>{};
        for (final e in caso.escenas) {
          expect(ids.add(e.id), isTrue, reason: 'id repetido: ${e.id}');
          expect(Lugar.desde(e.lugar), isNot(Lugar.otro), reason: '${e.id}: lugar «${e.lugar}»');
          expect(e.personajes, isNotEmpty, reason: e.id);
          expect(e.narracion, isNotEmpty, reason: e.id);
        }
      });

      test('cada opción tiene explicación y fuente, y lleva a una escena que existe', () {
        for (final e in caso.escenas) {
          for (final o in e.decision?.opciones ?? const <Opcion>[]) {
            expect(o.feedback, isNotEmpty, reason: '${e.id}: ${o.texto}');
            expect(o.fuente, isNotEmpty, reason: '${e.id}: ${o.texto}');
            expect(caso.escena(o.siguiente ?? ''), isNotNull, reason: '${e.id}: ${o.texto} → ${o.siguiente}');
          }
          if (e.siguiente != null) expect(caso.escena(e.siguiente!), isNotNull, reason: '${e.id} → ${e.siguiente}');
          final d = e.decision;
          if (d != null) {
            expect(d.opciones.length, inInclusiveRange(2, 4), reason: e.id);
            expect(d.opciones.any((o) => o.correcta), isTrue, reason: '${e.id}: sin respuesta correcta');
          }
        }
      });

      test('las fuentes citan normas que la app sabe explicar', () {
        final fuentes = [
          for (final e in caso.escenas)
            for (final o in e.decision?.opciones ?? const <Opcion>[]) o.fuente,
          for (final c in caso.cartas) c.fuente,
        ];
        for (final fuente in fuentes) {
          final citas = citasDe(fuente);
          expect(citas, isNotEmpty, reason: fuente);
          for (final cita in citas) {
            expect(nombreNormaJuego(cita.norma), isNotNull, reason: 'norma desconocida en «$fuente»');
            expect(cita.articulo, isNotEmpty, reason: 'falta el artículo en «$fuente»');
          }
        }
      });

      test('las cartas solo salen de respuestas correctas y todas se pueden ganar', () {
        final ganables = <String>{};
        for (final e in caso.escenas) {
          for (final o in e.decision?.opciones ?? const <Opcion>[]) {
            if (o.carta == null) continue;
            expect(o.correcta, isTrue, reason: '${e.id}: «${o.texto}» da carta sin ser correcta');
            expect(caso.carta(o.carta!), isNotNull, reason: '${e.id}: la carta ${o.carta} no existe');
            ganables.add(o.carta!);
          }
        }
        expect(ganables, {for (final c in caso.cartas) c.id});
      });

      test('se puede jugar de principio a fin, pasando por todas las escenas', () {
        // Con la primera respuesta correcta de cada decisión.
        var partida = Partida.nueva(caso);
        var pasos = 0;
        while (!partida.terminada && pasos++ < 100) {
          final d = partida.decision;
          if (d != null) partida = partida.elegir(d.opciones.indexWhere((o) => o.correcta));
          partida = partida.avanzar();
        }
        expect(partida.terminada, isTrue);
        expect(partida.recorrido.toSet(), {for (final e in caso.escenas) e.id});
        expect(partida.recorrido.length, caso.escenas.length, reason: 'sin vueltas atrás');
      });

      test('respeta las reglas del contenido (sección 2.3)', () {
        final textos = normalizar(fichero.readAsStringSync());
        expect(textos, isNot(contains('carcel')), reason: 'la ley de menores pone medidas, no penas');
        expect(textos, isNot(contains('siempre gratis')));
        expect(textos, isNot(contains('que paso')), reason: 'nunca se pregunta qué pasó');
        expect(textos, isNot(contains('te lo prometo')));
      });
    });
  }

  group('caso oficial: Lucía en la Sala Gesell', () {
    final caso = Caso.fromJson(_leer(File('assets/mock/content/juego/caso-sala-gesell.json')));

    test('Lucía, 11 años, víctima; de 10 a 12 escenas y 5 decisiones', () {
      expect(caso.protagonista, 'Lucía');
      expect(caso.edad, 11);
      expect(caso.rol, 'victima');
      expect(caso.escenas.length, inInclusiveRange(10, 12));
      expect(caso.decisiones, 5);
      expect(caso.cartas.length, greaterThanOrEqualTo(5));
      expect(Lugar.desde(caso.escenas.first.lugar), Lugar.colegio);
      expect(caso.escenas.any((e) => Lugar.desde(e.lugar) == Lugar.salaGesell), isTrue);
    });

    test('responde a «¿tendré que dejar de vivir con mi madre?» sin prometer nada', () {
      final escena = caso.escenas.firstWhere(
        (e) => e.decision != null && e.narracion.contains('dejar de vivir con mi madre'),
      );
      final correcta = escena.decision!.opciones.singleWhere((o) => o.correcta);
      expect(normalizar(correcta.texto), contains('nadie puede prometer'));
      expect(correcta.fuente, contains('LO 1/1996'));
      final promesa = escena.decision!.opciones.firstWhere((o) => normalizar(o.texto).contains('se lo promete'));
      expect(promesa.correcta, isFalse);
    });
  });

  test('caso de Sara: en su habitación (S1, S2, S3 y S8), con su fondo pixel', () {
    final caso = Caso.fromJson(_leer(File('assets/mock/content/juego/caso-difusion-imagenes.json')));
    final enLaHabitacion = [
      for (final e in caso.escenas)
        if (Lugar.desde(e.lugar) == Lugar.habitacion) e.id,
    ];
    expect(enLaHabitacion, ['S1', 'S2', 'S3', 'S8']);
    expect(EscenariosPixel.tiene('habitacion'), isTrue);
    for (final e in caso.escenas) {
      expect(EscenariosPixel.tiene(e.lugar), isTrue, reason: '${e.id}: «${e.lugar}» tiene fondo pixel');
    }
  });

  test('caso de Sergio: 13 años, Fiscalía de Menores y protección', () {
    final caso = Caso.fromJson(_leer(File('assets/mock/content/juego/caso-acoso-escolar.json')));
    expect(caso.protagonista, 'Sergio');
    expect(caso.edad, 13);
    expect(caso.escenas.any((e) => Lugar.desde(e.lugar) == Lugar.fiscalia), isTrue);
    expect(caso.escenas.length, lessThan(11), reason: 'es el caso corto');
  });
}
