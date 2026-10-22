import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/api/models.dart';
import 'package:tuturno/features/aprende/correccion_local.dart';
import 'package:tuturno/features/aprende/modelos.dart';

import 'ayudantes.dart';

// «Dilo con tus palabras» corregido en el móvil (sin servidor). La nota depende siempre de lo escrito: nunca es una
// respuesta enlatada. Se prueba con los ejercicios de verdad del contenido de ejemplo.

final _ejercicios = ejerciciosDeEjemplo();

EjercicioDilo _dilo(String id) => _ejercicios[id]! as EjercicioDilo;

/// Qué ideas de [id] da por dichas [texto], como «110» (la 1 y la 2 sí, la 3 no).
String _dichas(String id, String texto) {
  final e = _dilo(id);
  return [
    for (final d in ideasDichas(proposiciones: e.proposiciones, texto: texto, pregunta: e.pregunta)) d ? '1' : '0',
  ].join();
}

GradeResponse _corregir(String id, String texto) {
  final e = _dilo(id);
  return corregirEnElMovil(proposiciones: e.proposiciones, texto: texto, pregunta: e.pregunta);
}

void main() {
  group('E-212, la prueba preconstituida (la de la demo)', () {
    test('«Que te graban la entrevista y ese vídeo sirve para el juicio»: 2 de 3, falta no ir al juicio', () {
      final nota = _corregir('E-212', 'Que te graban la entrevista y ese vídeo sirve para el juicio');
      expect(nota.cubiertas, ['Tu entrevista se graba en vídeo', 'La grabación vale para el juicio']);
      expect(nota.faltan, ['Normalmente no tienes que ir al juicio']);
      expect(nota.puntuacion, closeTo(2 / 3, 1e-9));
      expect(nota.feedback, 'Te falta una idea: normalmente no tienes que ir al juicio.');
    });

    test('bien: las tres ideas, con palabras propias', () {
      expect(
        _dichas(
          'E-212',
          'Te graban en vídeo, la grabación vale para el juicio y normalmente no tienes que ir al juicio',
        ),
        '111',
      );
      expect(_dichas('E-212', 'Te entrevistan y lo graban para que no tengas que ir al juicio'), '101');
      expect(_corregir('E-212', 'Te graban en vídeo, vale para el juicio y no hace falta que vayas').puntuacion, 1);
    });

    test('regular: una idea', () {
      expect(_dichas('E-212', 'Que no hace falta que vayas al juicio'), '001');
    });

    test('lo contrario no vale: «sí tienes que ir al juicio»', () {
      expect(_dichas('E-212', 'Que sí tienes que ir al juicio'), '000');
    });

    test('negar una idea que afirma no la explica: «la grabación no vale para el juicio»', () {
      expect(_dichas('E-212', 'La grabación no vale para el juicio'), '000');
      final nota = _corregir('E-212', 'No te graban la entrevista y el vídeo no sirve para el juicio');
      expect(nota.cubiertas, isEmpty);
      expect(nota.puntuacion, 0);
      // Lo que sí está bien sigue contando.
      expect(
        _corregir('E-212', 'Que te graban la entrevista y ese vídeo sirve para el juicio').puntuacion,
        closeTo(2 / 3, 1e-9),
      );
      expect(_corregir('E-212', 'Te graban para que no tengas que ir al juicio').puntuacion, closeTo(2 / 3, 1e-9));
      // «No solo…» no niega: «no solo te graban: la grabación vale para el juicio».
      expect(_dichas('E-212', 'No solo te graban la entrevista, la grabación vale para el juicio'), '110');
    });

    test('vacío, sin sentido o repitiendo la pregunta: ninguna idea', () {
      for (final texto in ['', '   ', 'asdf qwer zxcv', 'bla bla bla bla', 'La prueba preconstituida es una prueba']) {
        final nota = _corregir('E-212', texto);
        expect(nota.cubiertas, isEmpty, reason: '«$texto»');
        expect(nota.faltan, _dilo('E-212').proposiciones, reason: '«$texto»');
        expect(nota.puntuacion, 0, reason: '«$texto»');
      }
    });

    test('repetir una palabra no cuenta como explicar', () {
      expect(_dichas('E-212', 'juicio juicio juicio juicio'), '000');
    });
  });

  group('otros ejercicios: bien, regular, vacío y sin sentido', () {
    // Para cada ejercicio: una respuesta buena (todas), dos regulares (alguna) y una que solo repite la pregunta.
    const casos = <String, List<(String, String)>>{
      'E-106': [
        (
          'Tienes derecho a que te escuchen en lo que te afecta, tu opinión cuenta según tu edad y madurez, y a partir '
              'de los 12 años se da por hecho que tienes madurez',
          '111',
        ),
        ('Que tengo derecho a que me escuchen y que desde los doce años ya se considera que soy maduro', '101'),
        ('Lo que piensas importa según tu edad', '010'),
        ('El derecho a ser oído', '000'),
      ],
      'E-118': [
        ('Puede contarlo él mismo a la policía o a la fiscalía por canales seguros y confidenciales', '111'),
        ('Lo puede decir ella sola', '100'),
        ('Tiene que ser un sitio seguro y secreto', '001'),
        ('Puede contar que sufre violencia', '000'),
      ],
      'E-506': [
        (
          'Reenviarlas hace daño a la persona que sale, pasar fotos sexuales de un menor es un delito muy serio y la '
              'culpa es de quien las difunde, no de quien sale',
          '111',
        ),
        ('No hay que reenviarlas porque le hace mucho daño', '100'),
        ('La culpa es del que las comparte', '001'),
        ('La culpa es de quien sale en ellas', '000'),
        ('No hay que reenviar imágenes íntimas de otra persona', '000'),
      ],
      'E-606': [
        (
          'Se aplica la ley penal de menores, la fiscalía de menores dirige la investigación y el juez de menores pone '
              'medidas, no penas como a los adultos',
          '111',
        ),
        ('El juez le pone medidas y no va a la cárcel', '001'),
        ('El juez le pone penas como a los adultos', '000'),
        ('Si un chico de 14 años comete un delito', '000'),
      ],
      'E-706': [
        (
          'Desde los 12 años el juez tiene que escucharte, con menos de 12 puede escucharte si lo ve necesario, y tu '
              'opinión cuenta pero decide el juez',
          '111',
        ),
        ('Desde los 12 el juez tiene que escucharte', '100'),
        ('Si tienes menos de 12 te puede escuchar si hace falta', '010'),
        ('El juez te escucha si tus padres se separan', '000'),
      ],
      'E-218': [
        (
          'Los juzgados se organizan para que no se crucen, en la entrevista no la ve cara a cara y le pueden prohibir '
              'acercarse',
          '111',
        ),
        ('No tiene que ver a la persona en la entrevista', '010'),
        ('Hay una orden de alejamiento', '001'),
        ('En la entrevista la ve cara a cara', '000'),
      ],
    };
    for (final MapEntry(key: id, value: respuestas) in casos.entries) {
      test(id, () {
        for (final (texto, esperado) in respuestas) {
          expect(_dichas(id, texto), esperado, reason: '«$texto»');
        }
      });
    }
  });

  test('todos los «Dilo» del contenido: una respuesta con sus propias ideas las cubre todas', () {
    final dilos = _ejercicios.values.whereType<EjercicioDilo>().toList();
    expect(dilos, isNotEmpty);
    for (final e in dilos) {
      final nota = corregirEnElMovil(
        proposiciones: e.proposiciones,
        texto: e.proposiciones.join('. '),
        pregunta: e.pregunta,
      );
      expect(nota.faltan, isEmpty, reason: e.id);
      expect(nota.puntuacion, 1, reason: e.id);
      // Y sin escribir nada, ninguna.
      expect(corregirEnElMovil(proposiciones: e.proposiciones, texto: '', pregunta: e.pregunta).puntuacion, 0);
    }
  });

  test('la nota depende de lo escrito: dos textos distintos, dos notas distintas', () {
    final buena = _corregir('E-106', 'Tienes derecho a que te escuchen en lo que te afecta');
    final otra = _corregir('E-106', 'Desde los 12 años se da por hecho que tienes madurez');
    expect(buena.cubiertas, ['Tienes derecho a que te escuchen en lo que te afecta']);
    expect(otra.cubiertas, ['A partir de los 12 años se da por hecho que tienes madurez']);
  });

  group('raíces y sinónimos', () {
    test('quita tildes y plurales y recorta a 5 letras', () {
      expect(raizDilo('grabacion'), 'graba');
      expect(raizDilo('graban'), 'graba');
      expect(raizDilo('jueces'), 'juez');
      expect(raizDilo('leyes'), 'ley');
      expect(raizDilo('fotos'), 'foto');
      expect(raizDilo('doce'), '12');
      expect(raizDilo('14'), '14');
      // «confidencial» no es «confianza».
      expect(raizDilo('confidenciales'), isNot(raizDilo('confianza')));
    });

    test('ninguna raíz está en dos grupos de sinónimos distintos', () {
      final grupoDe = <String, String>{};
      for (final grupo in gruposSinonimosDilo) {
        final canonica = raizDilo(grupo.first);
        for (final palabra in grupo) {
          final raiz = raizDilo(palabra);
          expect(grupoDe[raiz] ?? canonica, canonica, reason: '«$palabra» está en dos grupos');
          grupoDe[raiz] = canonica;
        }
      }
    });

    test('mayúsculas, tildes y signos no cambian nada', () {
      expect(
        _dichas('E-212', '¡QUE TE GRABAN LA ENTREVISTA, Y ESE VÍDEO SIRVE PARA EL JUICIO!'),
        _dichas('E-212', 'que te graban la entrevista y ese video sirve para el juicio'),
      );
    });
  });

  group('mensaje', () {
    test('una idea que falta, varias o ninguna', () {
      expect(
        mensajeIdeas(['Normalmente no tienes que ir al juicio']),
        'Te falta una idea: normalmente no tienes que ir al juicio.',
      );
      expect(mensajeIdeas(['Idea uno.', 'Idea dos']), 'Te faltan 2 ideas: idea uno; idea dos.');
      expect(mensajeIdeas(const []), '¡Has dicho todas las ideas clave!');
    });
  });

  group('respuesta del servidor', () {
    test('sin ideas es la de crisis (sección 8.2, «tipo»: «crisis»)', () {
      const crisis = GradeResponse(
        puntuacion: 0,
        cubiertas: [],
        faltan: [],
        feedback: 'Siento que estés pasando por esto.',
      );
      const normal = GradeResponse(puntuacion: 0, cubiertas: [], faltan: ['Una idea'], feedback: 'Te falta una idea.');
      expect(esCorreccionDeCrisis(crisis), isTrue);
      expect(esCorreccionDeCrisis(normal), isFalse);
    });

    test('con «tipo», manda el tipo: una crisis con ideas es crisis y una normal sin ideas no', () {
      const crisisConIdeas = GradeResponse(
        puntuacion: 0,
        cubiertas: [],
        faltan: ['Una idea'],
        feedback: 'Siento que estés pasando por esto.',
        tipo: 'crisis',
      );
      const normalSinIdeas = GradeResponse(puntuacion: 0, cubiertas: [], faltan: [], feedback: '', tipo: 'normal');
      expect(esCorreccionDeCrisis(crisisConIdeas), isTrue);
      expect(esCorreccionDeCrisis(normalSinIdeas), isFalse);
    });
  });
}
