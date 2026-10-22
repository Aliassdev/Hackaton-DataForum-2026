import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/api/models.dart';

import 'fixtures.dart';

void main() {
  group('8.1 POST /api/agent/ask · petición', () {
    test('AskRequest.toJson reproduce la petición del documento', () {
      const request = AskRequest(
        pregunta: 'Si tengo 13 años y hago algo malo, ¿me pueden juzgar?',
        historial: [
          Mensaje(autor: Autor.usuario, texto: '...'),
          Mensaje(autor: Autor.asistente, texto: '...'),
        ],
      );

      expect(request.toJson(), mapa(askPeticionDoc));
      // Y se puede codificar tal cual para enviarla.
      expect(jsonDecode(jsonEncode(request.toJson())), mapa(askPeticionDoc));
    });

    test('por defecto: modo libre, sin situación y sin historial', () {
      final json = const AskRequest(pregunta: '¿Qué es un juicio?').toJson();

      expect(json, {'pregunta': '¿Qué es un juicio?', 'modo': 'libre', 'situacion': null, 'historial': <Object>[]});
    });

    test('situacion nula se envía como null (la clave existe)', () {
      final json = const AskRequest(pregunta: 'Hola').toJson();

      expect(json.containsKey('situacion'), isTrue);
      expect(json['situacion'], isNull);
    });

    test('los enums se envían por su nombre, como en el contrato', () {
      for (final rol in RolProceso.values) {
        final json = AskRequest(pregunta: '¿Qué puedo pedir?', modo: ModoPregunta.situacion, situacion: rol).toJson();
        expect(json['modo'], 'situacion');
        expect(json['situacion'], rol.name);
      }
      expect(RolProceso.values.map((r) => r.name), ['testigo', 'victima', 'investigado']);
      expect(ModoPregunta.values.map((m) => m.name), ['libre', 'situacion']);
      expect(const Mensaje(autor: Autor.usuario, texto: 'a').toJson(), {'rol': 'usuario', 'texto': 'a'});
      expect(const Mensaje(autor: Autor.asistente, texto: 'b').toJson(), {'rol': 'asistente', 'texto': 'b'});
    });

    test('historial: solo van los 4 últimos mensajes, en orden', () {
      final historial = [
        for (var i = 1; i <= 7; i++) Mensaje(autor: i.isOdd ? Autor.usuario : Autor.asistente, texto: 'm$i'),
      ];
      final request = AskRequest(pregunta: '¿Y después?', historial: historial);

      final enviado = request.toJson()['historial'] as List;

      expect(AskRequest.maxHistorial, 4);
      expect(enviado, [
        {'rol': 'asistente', 'texto': 'm4'},
        {'rol': 'usuario', 'texto': 'm5'},
        {'rol': 'asistente', 'texto': 'm6'},
        {'rol': 'usuario', 'texto': 'm7'},
      ]);
      // La lista original no se toca: el chat sigue entero en memoria.
      expect(request.historial, hasLength(7));
    });

    test('historial con 4 mensajes o menos se envía entero', () {
      for (final n in [0, 1, 4]) {
        final historial = [for (var i = 0; i < n; i++) Mensaje(autor: Autor.usuario, texto: 'm$i')];
        final enviado = AskRequest(pregunta: 'p', historial: historial).toJson()['historial'] as List;
        expect(enviado.map((m) => (m as Map)['texto']), [for (var i = 0; i < n; i++) 'm$i']);
      }
    });
  });

  group('8.1 POST /api/agent/ask · respuesta', () {
    test('AskResponse.fromJson lee la respuesta del documento', () {
      final r = AskResponse.fromJson(mapa(askRespuestaDoc));

      expect(r.tipo, TipoRespuesta.normal);
      expect(r.respuesta, 'Antes de los 14 años no se puede exigir responsabilidad penal en España [A-017]...');
      expect(r.fuentes, hasLength(1));
      expect(r.fuentes.single.id, 'A-017');
      expect(r.fuentes.single.titulo, 'Antes de los 14 años no hay responsabilidad penal');
      expect(r.fuentes.single.norma, 'LO 5/2000');
      expect(r.fuentes.single.articulo, '3');
      expect(r.sugerencias, ['¿Qué pasa a partir de los 14?', '¿Qué hace la Fiscalía de Menores?']);
      expect(r.terminos, ['responsabilidad penal', 'Fiscalía de Menores']);
      expect(r.latenciaMs, 2140);
    });

    test('tipo: los cuatro valores del contrato', () {
      const esperados = {
        'normal': TipoRespuesta.normal,
        'crisis': TipoRespuesta.crisis,
        'hechos': TipoRespuesta.hechos,
        'fuera_de_ambito': TipoRespuesta.fueraDeAmbito,
      };
      esperados.forEach((json, tipo) {
        expect(TipoRespuesta.fromJson(json), tipo, reason: json);
        expect(tipo.json, json);
        expect(AskResponse.fromJson({'tipo': json, 'respuesta': 'x'}).tipo, tipo);
      });
    });

    test('tipo desconocido o ausente → normal', () {
      for (final valor in ['urgente', 'fuera de ambito', '', null, 3, true]) {
        expect(TipoRespuesta.fromJson(valor), TipoRespuesta.normal, reason: '$valor');
      }
      expect(AskResponse.fromJson({'respuesta': 'x'}).tipo, TipoRespuesta.normal);
    });

    test('tipo con mayúsculas o espacios no pierde una crisis', () {
      expect(TipoRespuesta.fromJson('CRISIS'), TipoRespuesta.crisis);
      expect(TipoRespuesta.fromJson(' crisis\n'), TipoRespuesta.crisis);
      expect(TipoRespuesta.fromJson('Fuera_De_Ambito'), TipoRespuesta.fueraDeAmbito);
    });

    test('campos opcionales ausentes o nulos → valores por defecto', () {
      final r = AskResponse.fromJson({
        'tipo': 'crisis',
        'respuesta': 'Llama al 900 20 20 10.',
        'fuentes': null,
        'sugerencias': null,
      });

      expect(r.tipo, TipoRespuesta.crisis);
      expect(r.fuentes, isEmpty);
      expect(r.sugerencias, isEmpty);
      expect(r.terminos, isEmpty);
      expect(r.latenciaMs, 0);
    });

    test('números donde se espera texto y latencia con decimales', () {
      final r = AskResponse.fromJson({
        'tipo': 'normal',
        'respuesta': 'x',
        'fuentes': [
          {'id': 'A-003', 'titulo': 'Derecho a ser oído', 'norma': 'LO 1/1996', 'articulo': 9},
        ],
        'latencia_ms': 812.6,
      });

      expect(r.fuentes.single.articulo, '9');
      expect(r.latenciaMs, 812);
    });

    test('Fuente sin título, norma o artículo → textos vacíos', () {
      final f = Fuente.fromJson({'id': 'A-001'});

      expect([f.id, f.titulo, f.norma, f.articulo], ['A-001', '', '', '']);
    });

    test('sin «respuesta» o con otra forma → lanza (el cliente lo convierte en RESPUESTA_INVALIDA)', () {
      expect(() => AskResponse.fromJson({'tipo': 'normal'}), throwsA(anything));
      expect(() => AskResponse.fromJson({'respuesta': 42}), throwsA(anything));
      expect(
        () => AskResponse.fromJson({
          'respuesta': 'x',
          'fuentes': ['A-017'],
        }),
        throwsA(anything),
      );
    });
  });

  group('8.2 POST /api/learn/grade', () {
    test('GradeRequest.toJson reproduce la petición del documento', () {
      const request = GradeRequest(
        conceptoId: 'C-ser-oido',
        texto: 'Que el juez tiene que escucharte si tienes 12 años',
      );

      expect(request.toJson(), mapa(gradePeticionDoc));
    });

    test('GradeResponse.fromJson lee la respuesta del documento', () {
      final r = GradeResponse.fromJson(mapa(gradeRespuestaDoc));

      expect(r.puntuacion, 0.67);
      expect(r.cubiertas, [
        'Tienes derecho a que te escuchen en lo que te afecta',
        'A partir de los 12 años se da por hecho que tienes madurez',
      ]);
      expect(r.faltan, ['Tu opinión se tiene en cuenta según tu edad y madurez']);
      expect(r.feedback, '¡Muy bien! Te falta una idea: tu opinión se tiene en cuenta según tu edad y madurez.');
    });

    test('puntuación entera (0 o 1) se lee como double', () {
      final r = GradeResponse.fromJson({'puntuacion': 1, 'cubiertas': null, 'faltan': [], 'feedback': '¡Genial!'});

      expect(r.puntuacion, 1.0);
      expect(r.puntuacion, isA<double>());
      expect(r.cubiertas, isEmpty);
    });

    test('sin puntuación o sin feedback → lanza', () {
      expect(() => GradeResponse.fromJson({'feedback': 'x'}), throwsA(anything));
      expect(() => GradeResponse.fromJson({'puntuacion': 0.5}), throwsA(anything));
    });
  });

  group('8.3 GET /api/health', () {
    test('HealthResponse.fromJson lee la respuesta del documento', () {
      final r = HealthResponse.fromJson(mapa(healthDoc));

      expect(r.estado, 'ok');
      expect(r.indiceA, 182);
      expect(r.indiceB, 940);
      expect(r.modeloLlm, 'claude-haiku-5-5');
      expect(r.demo, isFalse);
    });

    test('solo «estado» es obligatorio; demo solo es true si viene true', () {
      final r = HealthResponse.fromJson({'estado': 'degradado', 'demo': 'true'});

      expect([r.indiceA, r.indiceB], [0, 0]);
      expect(r.modeloLlm, '');
      expect(r.demo, isFalse);
      expect(HealthResponse.fromJson({'estado': 'ok', 'demo': true}).demo, isTrue);
      expect(() => HealthResponse.fromJson({'indice_a': 1}), throwsA(anything));
    });
  });

  group('8.4 errores', () {
    test('lee el error del documento', () {
      final e = ApiException.desdeRespuesta(mapa(errorDoc), statusCode: 503);

      expect(e.codigo, 'LLM_NO_DISPONIBLE');
      expect(e.mensaje, 'No he podido responder ahora. Prueba otra vez o pulsa Ayuda.');
    });

    test('el mensaje seguro es el del documento', () {
      expect(ApiException.mensajeSeguro, mapa(errorDoc)['error']['mensaje']);
    });

    test('sin mensaje (o vacío) → mensaje seguro; sin código (o vacío) → HTTP_estado', () {
      final sinMensaje = ApiException.desdeRespuesta({
        'error': {'codigo': 'LIMITE', 'mensaje': '  '},
      }, statusCode: 429);
      final sinCodigo = ApiException.desdeRespuesta({
        'error': {'codigo': '', 'mensaje': 'Espera un momento.'},
      }, statusCode: 429);

      expect([sinMensaje.codigo, sinMensaje.mensaje], ['LIMITE', ApiException.mensajeSeguro]);
      expect([sinCodigo.codigo, sinCodigo.mensaje], ['HTTP_429', 'Espera un momento.']);
    });

    test('cuerpo sin el formato de la sección 8.4 → HTTP_estado y mensaje seguro', () {
      final cuerpos = <Object?>[
        null,
        'Bad gateway',
        [1, 2],
        {'detail': 'Not Found'}, // Error por defecto de FastAPI.
        {'error': 'algo falló'},
      ];
      for (final cuerpo in cuerpos) {
        final e = ApiException.desdeRespuesta(cuerpo, statusCode: 502);
        expect(e.codigo, 'HTTP_502', reason: '$cuerpo');
        expect(e.mensaje, ApiException.mensajeSeguro, reason: '$cuerpo');
      }
    });

    test('toString incluye el código (para depurar) y es una Exception', () {
      const e = ApiException('SIN_CONEXION', ApiException.mensajeSeguro);

      expect(e.toString(), contains('SIN_CONEXION'));
      expect(e, isA<Exception>());
    });
  });
}
