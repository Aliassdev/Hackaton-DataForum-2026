import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/agente/respuesta_agente.dart';

// Lo que llega del agente de voz: las plantillas exactas del backend de B (content/seguridad.json y RESPUESTA_SEGURA
// del orquestador, rama origin/feat/api-base, d3009c9) y los textos para voz de su capa 4.

// Plantillas tal como las manda el backend (palabra a palabra, con un espacio al final).
const _crisis =
    'Gracias por contármelo. Lo que me cuentas es importante y mereces ayuda ahora mismo. [slow] Llama a la Fundación '
    'ANAR: novecientos, veinte, veinte, diez. También puedes llamar al ciento dieciséis, ciento once. Es gratis y te '
    'atienden personas a cualquier hora. Si estás en peligro ahora mismo, llama al uno, uno, dos. ';
const _hechos1 =
    'Gracias por confiar en mí. Lo que pasó es importante, pero es mejor que se lo cuentes a las personas que llevan tu '
    'caso, como tu abogado o el equipo del juzgado, para que tu recuerdo no se mezcle con lo que hablemos aquí. Yo sí '
    'puedo explicarte cómo funciona el proceso y qué derechos tienes. ¿Qué te gustaría saber? ';
const _hechos2 =
    'Te agradezco que me lo cuentes. De lo que pasó es mejor que hables con los profesionales de tu caso; yo no te voy '
    'a preguntar por ello. Lo que sí puedo hacer es explicarte qué va a pasar en el proceso. Y si te sientes mal, en '
    'ANAR te escuchan: novecientos, veinte, veinte, diez. ¿Qué quieres saber del proceso? ';
const _fuera1 =
    'Eso no te lo puedo responder. Yo solo sé de cómo funciona la justicia y de tus derechos en el proceso. ¿Hay algo '
    'del juicio o del juzgado que quieras saber? ';
const _fuera2 =
    'Con eso no te puedo ayudar. Estoy aquí para explicarte el proceso judicial y tus derechos. ¿Tienes alguna duda '
    'sobre eso? ';
const _segura =
    'Ahora mismo no he podido responderte. Prueba otra vez en un momento, o pulsa el botón de Ayuda si lo necesitas.';

void main() {
  group('plantillas del backend', () {
    test('las constantes de la app son las del backend, palabra por palabra', () {
      expect(plantillasSeguridad[TipoTextoAgente.crisis], [_crisis.trim()]);
      expect(plantillasSeguridad[TipoTextoAgente.hechos], [_hechos1.trim(), _hechos2.trim()]);
      expect(plantillasSeguridad[TipoTextoAgente.fueraDeAmbito], [_fuera1.trim(), _fuera2.trim()]);
      expect(respuestaSeguraBackend, _segura);
    });

    test('crisis: sin [slow], con los tres teléfonos en cifras y reconocida', () {
      final r = prepararRespuestaAgente(_crisis);

      expect(
        r.texto,
        'Gracias por contármelo. Lo que me cuentas es importante y mereces ayuda ahora mismo. Llama a la Fundación '
        'ANAR: 900 20 20 10. También puedes llamar al 116 111. Es gratis y te atienden personas a cualquier hora. '
        'Si estás en peligro ahora mismo, llama al 112.',
      );
      expect(r.telefonos, ['900 20 20 10', '116 111', '112']);
      expect(r.tipo, TipoTextoAgente.crisis);
    });

    test('hechos: las dos plantillas', () {
      final primera = prepararRespuestaAgente(_hechos1);
      expect(primera.tipo, TipoTextoAgente.hechos);
      expect(primera.telefonos, isEmpty);

      final segunda = prepararRespuestaAgente(_hechos2);
      expect(segunda.tipo, TipoTextoAgente.hechos);
      expect(segunda.texto, contains('en ANAR te escuchan: 900 20 20 10.'));
      expect(segunda.telefonos, ['900 20 20 10']);
    });

    test('fuera de ámbito: las dos plantillas', () {
      expect(prepararRespuestaAgente(_fuera1).tipo, TipoTextoAgente.fueraDeAmbito);
      expect(prepararRespuestaAgente(_fuera2).tipo, TipoTextoAgente.fueraDeAmbito);
    });

    test('la respuesta segura del orquestador', () {
      final r = prepararRespuestaAgente(_segura);
      expect(r.tipo, TipoTextoAgente.respuestaSegura);
      expect(r.texto, _segura);
    });

    test('no dependen de tildes, mayúsculas, signos ni de cómo vengan los teléfonos', () {
      expect(
        clasificarTextoAgente(
          'GRACIAS POR CONTARMELO lo que me cuentas es importante y mereces ayuda ahora mismo llama a la fundacion anar '
          '900 20 20 10 tambien puedes llamar al 116 111 es gratis y te atienden personas a cualquier hora si estas en '
          'peligro ahora mismo llama al 112',
        ),
        TipoTextoAgente.crisis,
      );
      expect(
        clasificarTextoAgente('eso no te lo puedo responder... yo solo se de como funciona la justicia!'),
        TipoTextoAgente.fueraDeAmbito,
      );
      expect(clasificarTextoAgente('¡Ahora mismo no he podido responderte!'), TipoTextoAgente.respuestaSegura);
    });

    test('con algo más delante o detrás, también se reconocen', () {
      expect(clasificarTextoAgente('Vale. $_hechos2 Hasta luego.'), TipoTextoAgente.hechos);
    });

    test('una plantilla de crisis cambiada: [slow] y ANAR bastan', () {
      expect(clasificarTextoAgente('Lo siento mucho. [slow] Llama a ANAR cuando quieras.'), TipoTextoAgente.crisis);
    });

    test('lo que no es una plantilla es normal, aunque hable de peligro o de no saber algo', () {
      expect(clasificarTextoAgente('Si estás en peligro ahora mismo, llama al uno, uno, dos.'), TipoTextoAgente.normal);
      expect(clasificarTextoAgente('Eso no te lo puedo responder, pregunta a tu abogado.'), TipoTextoAgente.normal);
      expect(clasificarTextoAgente('Hola, soy TuTurno. ¿En qué te puedo ayudar?'), TipoTextoAgente.normal);
      expect(clasificarTextoAgente(''), TipoTextoAgente.normal);
      expect(clasificarTextoAgente('...'), TipoTextoAgente.normal);
    });
  });

  group('casos del contrato (plan-v2/contrato/casos-posproceso.json)', () {
    // (entrada, texto, teléfonos, tipo)
    const casos = <(String, String, List<String>, TipoTextoAgente)>[
      (
        'La Sala Gesell es una sala preparada para que puedas hablar con calma. Si tienes dudas, puedes llamar a la '
            'Fundación ANAR, en el novecientos, veinte, veinte, diez.',
        'La Sala Gesell es una sala preparada para que puedas hablar con calma. Si tienes dudas, puedes llamar a la '
            'Fundación ANAR, en el 900 20 20 10.',
        ['900 20 20 10'],
        TipoTextoAgente.normal,
      ),
      ('Llama al novecientos veinte veinte diez.', 'Llama al 900 20 20 10.', ['900 20 20 10'], TipoTextoAgente.normal),
      ('Llama al 900202010.', 'Llama al 900 20 20 10.', ['900 20 20 10'], TipoTextoAgente.normal),
      ('Llama al novecientos-veinte-veinte-diez.', 'Llama al 900 20 20 10.', ['900 20 20 10'], TipoTextoAgente.normal),
      (
        'También puedes llamar al ciento dieciséis mil ciento once.',
        'También puedes llamar al 116 111.',
        ['116 111'],
        TipoTextoAgente.normal,
      ),
      ('Marca el uno, uno, seis, uno, uno, uno.', 'Marca el 116 111.', ['116 111'], TipoTextoAgente.normal),
      ('Si es urgente, llama al uno, uno, dos.', 'Si es urgente, llama al 112.', ['112'], TipoTextoAgente.normal),
      ('Si es urgente, llama al ciento doce.', 'Si es urgente, llama al 112.', ['112'], TipoTextoAgente.normal),
      (
        'Lo dice el artículo ciento doce de la ley.',
        'Lo dice el artículo ciento doce de la ley.',
        [],
        TipoTextoAgente.normal,
      ),
      (
        'Marca el ciento doce si estás en peligro.',
        'Marca el 112 si estás en peligro.',
        ['112'],
        TipoTextoAgente.normal,
      ),
      ('Llama al Uno, Uno, Dos.', 'Llama al 112.', ['112'], TipoTextoAgente.normal),
      ('Puedes llamar al cero, diecisiete.', 'Puedes llamar al 017.', ['017'], TipoTextoAgente.normal),
      ('Puedes llamar al 017.', 'Puedes llamar al 017.', ['017'], TipoTextoAgente.normal),
      ('Puedes llamar al cero dieciséis.', 'Puedes llamar al 016.', ['016'], TipoTextoAgente.normal),
      ('Con diecisiete años ya puedes pedirlo.', 'Con diecisiete años ya puedes pedirlo.', [], TipoTextoAgente.normal),
      (
        'Llama al novecientos, doscientos noventa y tres, ciento ochenta y tres.',
        'Llama al 900 293 183.',
        ['900 293 183'],
        TipoTextoAgente.normal,
      ),
      (
        'Escribe por WhatsApp al novecientos ciento dieciséis ciento diecisiete.',
        'Escribe por WhatsApp al 900 116 117.',
        ['900 116 117'],
        TipoTextoAgente.normal,
      ),
      (
        'Llama al uno, uno, dos o al novecientos, veinte, veinte, diez.',
        'Llama al 112 o al 900 20 20 10.',
        ['112', '900 20 20 10'],
        TipoTextoAgente.normal,
      ),
      ('[whispers] Vale, te lo explico.', 'Vale, te lo explico.', [], TipoTextoAgente.normal),
      ('Tranquilo. [slow] [sighs] Te lo cuento.', 'Tranquilo. Te lo cuento.', [], TipoTextoAgente.normal),
      ('Has escrito un [DATO] personal.', 'Has escrito un [DATO] personal.', [], TipoTextoAgente.normal),
      (
        'Antes de los 14 años no hay responsabilidad penal [A-017].',
        'Antes de los 14 años no hay responsabilidad penal.',
        [],
        TipoTextoAgente.normal,
      ),
      (
        'Si estás en peligro ahora mismo, llama al uno, uno, dos.',
        'Si estás en peligro ahora mismo, llama al 112.',
        ['112'],
        TipoTextoAgente.normal,
      ),
      (
        'Lo que hablamos es privado, pero si hay un peligro, los adultos que te protegen tienen que actuar.',
        'Lo que hablamos es privado, pero si hay un peligro, los adultos que te protegen tienen que actuar.',
        [],
        TipoTextoAgente.normal,
      ),
      ('Hola ,  ¿qué tal ?', 'Hola, ¿qué tal?', [], TipoTextoAgente.normal),
      (
        'Hola, soy TuTurno. ¿En qué te puedo ayudar?',
        'Hola, soy TuTurno. ¿En qué te puedo ayudar?',
        [],
        TipoTextoAgente.normal,
      ),
    ];

    for (final (entrada, texto, telefonos, tipo) in casos) {
      test(entrada, () {
        final r = prepararRespuestaAgente(entrada);
        expect(r.texto, texto);
        expect(r.telefonos, telefonos);
        expect(r.tipo, tipo);
      });
    }
  });

  group('piezas sueltas', () {
    test('quitarEtiquetas deja [DATO] y arregla los espacios', () {
      expect(quitarEtiquetas('  Hola [slow] , ¿qué tal ?  [laughs softly]'), 'Hola, ¿qué tal?');
      expect(quitarEtiquetas('Un [DATO] y [A-017].'), 'Un [DATO] y.');
    });

    test('telefonosEnCifras no toca otros números', () {
      expect(telefonosEnCifras('Desde los catorce años, en el 2017.'), 'Desde los catorce años, en el 2017.');
      expect(telefonosEnCifras('Llama al 1900 20 20 10.'), 'Llama al 1900 20 20 10.');
    });

    test('telefonosEn da cada teléfono una vez, en orden', () {
      expect(telefonosEn('El 112, el 900 20 20 10 y otra vez el 112.'), ['112', '900 20 20 10']);
    });

    test('esSaludoAgente reconoce el primer mensaje fijo y no una respuesta sobre quién es', () {
      expect(esSaludoAgente('Hola, soy TuTurno. ¿En qué te puedo ayudar?'), isTrue);
      expect(esSaludoAgente('hola soy tuturno en que te puedo ayudar'), isTrue);
      expect(esSaludoAgente('Soy TuTurno, una inteligencia artificial que explica la justicia.'), isFalse);
    });

    test('tieneContenido: «...» no cuenta', () {
      expect(tieneContenido('...'), isFalse);
      expect(tieneContenido('  '), isFalse);
      expect(tieneContenido('La Sala'), isTrue);
    });
  });
}
