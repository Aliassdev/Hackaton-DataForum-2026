import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/features/pasos/pasos.dart';

import 'datos.dart';

void main() {
  silenciarAvisos();

  group('Itinerario (sección 9.5)', () {
    test('lee el ejemplo de la sección 9.5 tal cual', () {
      final itinerario = itinerarioDe(itinerarioSeccion95);

      expect(itinerario.rol, 'testigo');
      expect(itinerario.validado, isFalse);
      expect(itinerario.tieneFases, isFalse);
      final paso = itinerario.pasos.single;
      expect(paso.id, 'P1');
      expect(paso.nombre, 'Te llega una citación');
      expect(paso.quePasa, 'El juzgado te dice cuándo y dónde tienes que ir.');
      expect(paso.quienEsta, ['Tu familia o un adulto de confianza']);
      expect(paso.quePuedesPedir, ['Que te expliquen lo que no entiendas']);
      expect(paso.fuentes, ['A-050']);
      expect(paso.fase, isNull);
    });

    test('lee un itinerario con fase en cada paso (también «Después», con tilde y mayúscula)', () {
      final itinerario = itinerarioDe(itinerarioConFases);

      expect(itinerario.rol, 'victima');
      expect(itinerario.validado, isTrue);
      expect(itinerario.tieneFases, isTrue);
      expect([for (final p in itinerario.pasos) p.nombre], nombresConFases);
      expect(
        [for (final p in itinerario.pasos) p.fase],
        [Fase.antes, Fase.antes, Fase.durante, Fase.durante, Fase.despues, Fase.despues],
      );
      final entrevista = itinerario.pasos[3];
      expect(entrevista.quienEsta, hasLength(2));
      expect(entrevista.quePuedesPedir, ['Un descanso', 'Que te repitan una pregunta']);
      expect(entrevista.fuentes, ['LECrim, art. 449 ter', 'LECrim, art. 449 bis']);
      expect(itinerario.pasos[4].quePuedesPedir, isEmpty);
    });

    test('se salta los pasos sin nombre o que no son objetos; sin id, usa su posición', () {
      final itinerario = itinerarioDe('''
        {"rol": "testigo", "validado": true, "pasos": [
          {"id": "P1", "nombre": "Bien", "fuentes": ["A-1"]},
          {"id": "P2", "que_pasa": "Sin nombre: no se puede enseñar"},
          "no soy un paso",
          {"id": "P4", "nombre": "   "},
          {"nombre": "Sin id", "fuentes": ["A-2"]}
        ]}
      ''');

      expect([for (final p in itinerario.pasos) p.id], ['P1', 'P5']);
      expect(itinerario.pasos.last.nombre, 'Sin id');
    });

    test('acepta un texto suelto donde va una lista, quita espacios y vacíos, e ignora fases que no existen', () {
      final paso = itinerarioDe('''
        {"rol": "testigo", "pasos": [
          {"id": " P1 ", "nombre": "  Te llega una citación ", "que_pasa": 3,
           "quien_esta": "Tu familia", "que_puedes_pedir": ["", "  Que te lo expliquen  ", 7, null],
           "fuentes": "A-050", "fase": "mañana"}
        ]}
      ''').pasos.single;

      expect(paso.id, 'P1');
      expect(paso.nombre, 'Te llega una citación');
      expect(paso.quePasa, '');
      expect(paso.quienEsta, ['Tu familia']);
      expect(paso.quePuedesPedir, ['Que te lo expliquen']);
      expect(paso.fuentes, ['A-050']);
      expect(paso.fase, isNull);
    });

    test('"validado" tiene que ser true de verdad (no "true" ni 1)', () {
      for (final valor in ['"true"', '1', 'null']) {
        expect(itinerarioDe('{"rol": "testigo", "pasos": [], "validado": $valor}').validado, isFalse, reason: valor);
      }
    });

    test('sin "rol" usa el que se pide; sin "pasos" no tiene pasos', () {
      final itinerario = Itinerario.tryParse(jsonDecode('{"validado": true}'), rol: 'victima')!;

      expect(itinerario.rol, 'victima');
      expect(itinerario.pasos, isEmpty);
    });

    test('tryParse devuelve null si no es un objeto (y no lanza)', () {
      expect(Itinerario.tryParse(null), isNull);
      expect(Itinerario.tryParse([1, 2]), isNull);
      expect(Itinerario.tryParse('testigo'), isNull);
    });
  });

  test('faseDe acepta mayúsculas, tildes y espacios', () {
    expect(faseDe('antes'), Fase.antes);
    expect(faseDe(' DURANTE '), Fase.durante);
    expect(faseDe('Después'), Fase.despues);
    expect(faseDe('despues'), Fase.despues);
    expect(faseDe('luego'), isNull);
    expect(faseDe(2), isNull);
    expect(faseDe(null), isNull);
  });
}
