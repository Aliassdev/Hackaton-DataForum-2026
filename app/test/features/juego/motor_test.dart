import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/features/juego/modelos.dart';
import 'package:tuturno/features/juego/motor.dart';

import 'fakes.dart';

Caso _caso(String json) => Caso.fromJson(jsonDecode(json) as Map<String, dynamic>);

/// Caso con ramas: la respuesta incorrecta lleva a una escena de repaso antes de seguir.
final _ramas = Caso.fromJson({
  'id': 'ramas',
  'titulo': 'Ramas',
  'escenas': [
    {
      'id': 'A',
      'narracion': 'Empieza.',
      'decision': {
        'pregunta': '¿Por dónde?',
        'opciones': [
          {'texto': 'Bien', 'correcta': true, 'siguiente': 'C', 'feedback': 'Sí.', 'fuente': 'X, art. 1'},
          {'texto': 'Mal', 'correcta': false, 'siguiente': 'B', 'feedback': 'No.', 'fuente': 'X, art. 1'},
        ],
      },
    },
    {'id': 'B', 'narracion': 'Repaso.', 'siguiente': 'C'},
    {'id': 'C', 'narracion': 'Final.'},
  ],
});

void main() {
  final caso = _caso(casoPrueba);

  test('empieza en la primera escena y no deja avanzar sin decidir', () {
    final p = Partida.nueva(caso);
    expect(p.escena.id, 'E1');
    expect(p.numeroEscena, 1);
    expect(p.totalEscenas, 4);
    expect(p.empezada, isFalse);
    expect(p.terminada, isFalse);
    expect(p.puedeAvanzar, isFalse);
    expect(identical(p.avanzar(), p), isTrue, reason: 'sin elegir no se pasa de escena');
  });

  test('decisión: la opción elegida lleva a su siguiente', () {
    final p = Partida.nueva(caso).elegir(0);
    expect(p.eleccion, 0);
    expect(p.acierto, isTrue);
    expect(p.puedeAvanzar, isTrue);
    expect(p.empezada, isTrue);
    final siguiente = p.avanzar();
    expect(siguiente.escena.id, 'E2');
    expect(siguiente.eleccion, isNull);
    expect(siguiente.recorrido, ['E1', 'E2']);
  });

  test('con ramas, cada opción lleva a su escena', () {
    final mal = Partida.nueva(_ramas).elegir(1).avanzar();
    expect(mal.escena.id, 'B');
    expect(mal.totalEscenas, 3);
    final bien = Partida.nueva(_ramas).elegir(0).avanzar();
    expect(bien.escena.id, 'C');
    expect(bien.totalEscenas, 2);
  });

  test('escena lineal: avanzar va a su siguiente', () {
    final p = Partida.nueva(caso).elegir(0).avanzar();
    expect(p.decision, isNull);
    expect(p.puedeAvanzar, isTrue);
    expect(p.alAvanzarTermina, isFalse);
    expect(p.avanzar().escena.id, 'E3');
  });

  test('final del caso: en la última escena, avanzar termina', () {
    var p = Partida.nueva(caso).elegir(0).avanzar().avanzar().elegir(2).avanzar();
    expect(p.escena.id, 'E4');
    expect(p.numeroEscena, 4);
    expect(p.totalEscenas, 4);
    expect(p.alAvanzarTermina, isTrue);
    p = p.avanzar();
    expect(p.terminada, isTrue);
    expect(p.puedeAvanzar, isFalse);
    expect(identical(p.avanzar(), p), isTrue);
    expect(identical(p.elegir(0), p), isTrue);
  });

  test('una salida a una escena que no existe termina el caso', () {
    final doc = _caso(ejemploDoc);
    final p = Partida.nueva(doc).elegir(0).avanzar();
    expect(p.escena.id, 'S2');
    expect(p.alAvanzarTermina, isTrue, reason: 'S2 apunta a S3, que no está');
    expect(p.avanzar().terminada, isTrue);
  });

  group('cartas', () {
    test('una respuesta correcta con carta la gana y, si no se tenía, es nueva', () {
      final p = Partida.nueva(caso).elegir(0);
      expect(p.cartaDeLaEleccion?.id, 'R-entender');
      expect(p.cartaNueva?.id, 'R-entender');
      expect(p.cartasGanadas, ['R-entender']);
    });

    test('si ya estaba en la colección, se gana pero no es nueva', () {
      final p = Partida.nueva(caso).elegir(0, coleccion: {'R-entender'});
      expect(p.cartasGanadas, ['R-entender']);
      expect(p.cartaNueva, isNull);
    });

    test('una respuesta incorrecta no da carta', () {
      final p = Partida.nueva(caso).elegir(1);
      expect(p.acierto, isFalse);
      expect(p.cartaDeLaEleccion, isNull);
      expect(p.cartaNueva, isNull);
      expect(p.cartasGanadas, isEmpty);
    });

    test('la carta nueva se olvida al avanzar, pero sigue en las ganadas', () {
      final p = Partida.nueva(caso).elegir(0).avanzar();
      expect(p.cartaNueva, isNull);
      expect(p.cartasGanadas, ['R-entender']);
    });

    test('con dos respuestas correctas, cada una da su carta', () {
      final base = Partida.nueva(caso).elegir(0).avanzar().avanzar();
      expect(base.elegir(0).cartaNueva?.id, 'R-acompanada');
      expect(base.elegir(1).cartaNueva?.id, 'R-explicar');
    });
  });

  group('reintentar', () {
    test('tras una incorrecta, deja volver a elegir', () {
      final fallo = Partida.nueva(caso).elegir(1);
      final otraVez = fallo.reintentar();
      expect(otraVez.eleccion, isNull);
      expect(otraVez.escena.id, 'E1');
      expect(otraVez.elegir(0).cartaNueva?.id, 'R-entender');
    });

    test('tras una correcta no hace nada', () {
      final acierto = Partida.nueva(caso).elegir(0);
      expect(identical(acierto.reintentar(), acierto), isTrue);
    });
  });

  test('no se puede elegir dos veces ni una opción que no existe', () {
    final p = Partida.nueva(caso);
    expect(identical(p.elegir(-1), p), isTrue);
    expect(identical(p.elegir(9), p), isTrue);
    final elegida = p.elegir(1);
    expect(identical(elegida.elegir(0), elegida), isTrue);
    final lineal = p.elegir(0).avanzar();
    expect(identical(lineal.elegir(0), lineal), isTrue, reason: 'en una escena sin decisión no se elige');
  });
}
