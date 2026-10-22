import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/features/juego/modelos.dart';

import 'fakes.dart';

void main() {
  group('ejemplo de la sección 9.4', () {
    final caso = Caso.fromJson(jsonDecode(ejemploDoc) as Map<String, dynamic>);

    test('lee los datos del caso', () {
      expect(caso.id, 'caso-sala-gesell');
      expect(caso.titulo, 'Lucía y la sala de la entrevista');
      expect(caso.rol, 'victima');
      expect(caso.basadoEn, ['ids de sentencias del corpus usadas como estructura']);
      expect(caso.validado, isFalse);
      expect(caso.escenas.map((e) => e.id), ['S1', 'S2']);
      expect(caso.decisiones, 1);
    });

    test('lee una escena con decisión', () {
      final s1 = caso.escena('S1')!;
      expect(s1.lugar, 'colegio');
      expect(s1.personajes, ['Lucía', 'Su tutora']);
      expect(s1.narracion, startsWith('Lucía tiene 11 años.'));
      expect(s1.siguiente, isNull);
      final decision = s1.decision!;
      expect(decision.pregunta, '¿Por qué quieren hablar con Lucía?');
      expect(decision.opciones, hasLength(2));

      final buena = decision.opciones[0];
      expect(buena.texto, 'Para escucharla y poder protegerla');
      expect(buena.correcta, isTrue);
      expect(buena.siguiente, 'S2');
      expect(buena.feedback, startsWith('Correcto.'));
      expect(buena.fuente, 'A-003');
      expect(buena.carta, 'R-ser-oida');

      final mala = decision.opciones[1];
      expect(mala.correcta, isFalse);
      expect(mala.carta, isNull, reason: 'carta es opcional');
      expect(s1.salidas, ['S2', 'S2']);
    });

    test('lee una escena lineal (con siguiente y sin decisión)', () {
      final s2 = caso.escena('S2')!;
      expect(s2.lugar, 'sala_gesell');
      expect(s2.decision, isNull);
      expect(s2.siguiente, 'S3');
      expect(s2.salidas, ['S3']);
    });

    test('lee las cartas', () {
      final carta = caso.carta('R-ser-oida')!;
      expect(carta.titulo, 'Tienes derecho a que te escuchen');
      expect(carta.texto, 'En lo que te afecta, tu opinión cuenta.');
      expect(carta.fuente, 'A-003');
      expect(caso.carta('no-existe'), isNull);
    });

    test('deduce la protagonista, su edad y el planteamiento de la primera escena', () {
      expect(caso.protagonista, 'Lucía');
      expect(caso.edad, 11);
      // La frase de presentación ya sale como «Lucía, 11 años».
      expect(caso.resumen, startsWith('Su tutora le cuenta'));
    });

    test('distancia al final: una salida a una escena que no existe cuenta como final', () {
      expect(caso.distanciaAlFinal('S1'), 1);
      expect(caso.distanciaAlFinal('S2'), 0);
    });
  });

  group('datos incompletos', () {
    test('tryParse devuelve null en vez de lanzar', () {
      silenciarAvisos();
      expect(Caso.tryParse(null), isNull);
      expect(Caso.tryParse('no es un caso'), isNull);
      expect(Caso.tryParse({'id': 'x', 'titulo': 'Sin escenas'}), isNull);
      expect(Caso.tryParse({'id': 'x', 'titulo': 'Escenas vacías', 'escenas': []}), isNull);
      expect(
        Caso.tryParse({
          'id': 'x',
          'titulo': 'Escena rota',
          'escenas': [
            {'lugar': 'casa'},
          ],
        }),
        isNull,
      );
    });

    test('lo opcional tiene valores por defecto', () {
      final caso = Caso.tryParse({
        'id': 'minimo',
        'titulo': 'Mínimo',
        'escenas': [
          {
            'id': 'S1',
            'narracion': 'Sin más.',
            'decision': {'pregunta': '¿Y?', 'opciones': []},
          },
        ],
      })!;
      expect(caso.validado, isFalse, reason: 'sin "validado": true no se publica');
      expect(caso.cartas, isEmpty);
      expect(caso.basadoEn, isEmpty);
      expect(caso.rol, '');
      expect(caso.protagonista, '');
      expect(caso.edad, isNull);
      expect(caso.primera.personajes, isEmpty);
      expect(caso.primera.decision, isNull, reason: 'una decisión sin opciones no se puede jugar');
    });

    test('si algún día llegan protagonista, edad y resumen, mandan sobre lo deducido', () {
      final caso = Caso.fromJson({
        'id': 'x',
        'titulo': 'X',
        'protagonista': 'Sara',
        'edad': 15,
        'resumen': 'Un resumen escrito a mano.',
        'escenas': [
          {
            'id': 'S1',
            'personajes': ['Otra persona'],
            'narracion': 'Tiene 10 años.',
          },
        ],
      });
      expect(caso.protagonista, 'Sara');
      expect(caso.edad, 15);
      expect(caso.resumen, 'Un resumen escrito a mano.');
    });
  });

  test('Lugar acepta tildes, espacios, guiones y alias', () {
    expect(Lugar.desde('sala_gesell'), Lugar.salaGesell);
    expect(Lugar.desde('Sala Gesell'), Lugar.salaGesell);
    expect(Lugar.desde('sala de espera'), Lugar.salaEspera);
    expect(Lugar.desde('sala-espera'), Lugar.salaEspera);
    expect(Lugar.desde('Instituto'), Lugar.instituto);
    expect(Lugar.desde('escuela'), Lugar.colegio);
    expect(Lugar.desde('Comisaría'), Lugar.comisaria);
    expect(Lugar.desde('Fiscalía'), Lugar.fiscalia);
    expect(Lugar.desde('después'), Lugar.despues);
    expect(Lugar.desde('la luna'), Lugar.otro);
    expect(Lugar.desde(''), Lugar.otro);
  });
}
