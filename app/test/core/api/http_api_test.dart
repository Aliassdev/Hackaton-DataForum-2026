import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tuturno/core/api/http_api.dart';
import 'package:tuturno/core/api/tuturno_api.dart';

import 'fixtures.dart';

const _base = 'https://tuturno.example.com';

/// Respuesta con el cuerpo en UTF-8 y SIN charset en la cabecera, como la manda el backend.
/// (Con http.Response(String) el cuerpo se codificaría en latin1.)
http.Response _json(String cuerpo, [int estado = 200, Map<String, String> cabeceras = const {}]) =>
    http.Response.bytes(utf8.encode(cuerpo), estado, headers: cabeceras);

Matcher _apiException(String codigo, [String mensaje = ApiException.mensajeSeguro]) =>
    isA<ApiException>().having((e) => e.codigo, 'codigo', codigo).having((e) => e.mensaje, 'mensaje', mensaje);

void main() {
  late List<http.Request> peticiones;

  /// Cliente que guarda cada petición y responde con [responder].
  HttpTuTurnoApi api(
    FutureOr<http.Response> Function(http.Request request) responder, {
    String baseUrl = _base,
    Duration timeout = const Duration(seconds: 5),
  }) => HttpTuTurnoApi(
    baseUrl: baseUrl,
    timeout: timeout,
    client: MockClient((request) async {
      peticiones.add(request);
      return responder(request);
    }),
  );

  setUp(() => peticiones = []);

  group('peticiones', () {
    test('ask: POST a /api/agent/ask con cabeceras JSON y el cuerpo del contrato en UTF-8', () async {
      const request = AskRequest(
        pregunta: '¿Qué pasa después de declarar en la Sala Gesell?',
        modo: ModoPregunta.situacion,
        situacion: RolProceso.victima,
        historial: [Mensaje(autor: Autor.usuario, texto: 'Tengo 11 años')],
      );

      await api((_) => _json(askRespuestaDoc)).ask(request);

      final p = peticiones.single;
      expect(p.method, 'POST');
      expect(p.url.toString(), '$_base/api/agent/ask');
      expect(p.headers['content-type'], startsWith('application/json'));
      expect(p.headers['content-type']!.toLowerCase(), contains('utf-8'));
      expect(p.headers['accept'], 'application/json');
      expect(jsonDecode(utf8.decode(p.bodyBytes)), request.toJson());
      expect(utf8.decode(p.bodyBytes), contains('¿Qué pasa después'));
    });

    test('ask: solo envía los 4 últimos mensajes del historial', () async {
      final historial = [for (var i = 1; i <= 6; i++) Mensaje(autor: Autor.usuario, texto: 'm$i')];

      await api((_) => _json(askRespuestaDoc)).ask(AskRequest(pregunta: 'p', historial: historial));

      final cuerpo = jsonDecode(peticiones.single.body) as Map<String, dynamic>;
      expect((cuerpo['historial'] as List).map((m) => (m as Map)['texto']), ['m3', 'm4', 'm5', 'm6']);
    });

    test('grade: POST a /api/learn/grade con concepto_id y texto', () async {
      const request = GradeRequest(
        conceptoId: 'C-ser-oido',
        texto: 'Que el juez tiene que escucharte si tienes 12 años',
      );

      final r = await api((_) => _json(gradeRespuestaDoc)).grade(request);

      final p = peticiones.single;
      expect(p.method, 'POST');
      expect(p.url.toString(), '$_base/api/learn/grade');
      expect(jsonDecode(p.body), mapa(gradePeticionDoc));
      expect(r.puntuacion, 0.67);
      expect(r.faltan, ['Tu opinión se tiene en cuenta según tu edad y madurez']);
    });

    test('health: GET a /api/health sin cuerpo', () async {
      final r = await api((_) => _json(healthDoc)).health();

      final p = peticiones.single;
      expect(p.method, 'GET');
      expect(p.url.toString(), '$_base/api/health');
      expect(p.bodyBytes, isEmpty);
      expect([r.estado, r.indiceA, r.indiceB, r.modeloLlm, r.demo], ['ok', 182, 940, 'claude-haiku-5-5', false]);
    });

    test('la URL base se une bien aunque tenga barras al final o espacios', () async {
      const casos = {
        'https://tuturno.example.com/': 'https://tuturno.example.com/api/health',
        'https://tuturno.example.com///': 'https://tuturno.example.com/api/health',
        '  https://tuturno.example.com/  ': 'https://tuturno.example.com/api/health',
        'https://abc.trycloudflare.com/backend/': 'https://abc.trycloudflare.com/backend/api/health',
        'http://localhost:8000': 'http://localhost:8000/api/health',
        'HTTPS://TUTURNO.EXAMPLE.COM/': 'https://tuturno.example.com/api/health',
      };
      for (final MapEntry(key: base, value: esperada) in casos.entries) {
        await api((_) => _json(healthDoc), baseUrl: base).health();
        expect(peticiones.last.url.toString(), esperada, reason: base);
      }
    });
  });

  group('respuestas correctas', () {
    test('tildes en UTF-8 sin charset en la cabecera (el backend no lo indica)', () async {
      final r = await api((_) => _json(askRespuestaDoc)).ask(const AskRequest(pregunta: '¿Me pueden juzgar?'));

      expect(r.tipo, TipoRespuesta.normal);
      expect(r.respuesta, 'Antes de los 14 años no se puede exigir responsabilidad penal en España [A-017]...');
      expect(r.sugerencias, ['¿Qué pasa a partir de los 14?', '¿Qué hace la Fiscalía de Menores?']);
      expect(r.terminos, ['responsabilidad penal', 'Fiscalía de Menores']);
      expect(r.fuentes.single.norma, 'LO 5/2000');
      expect(r.latenciaMs, 2140);
    });

    test('tildes en UTF-8 con «application/json» sin charset (http usaría latin1)', () async {
      final r = await api((_) => _json(askRespuestaDoc, 200, {'content-type': 'application/json'}))
          .ask(const AskRequest(pregunta: 'p'));

      expect(r.sugerencias.first, '¿Qué pasa a partir de los 14?');
    });

    test('tipo crisis llega tal cual a la app', () async {
      final cuerpo = jsonEncode({
        'tipo': 'crisis',
        'respuesta': mapa(seguridadDoc)['crisis'],
        'fuentes': <Object>[],
        'sugerencias': <Object>[],
        'terminos': <Object>[],
        'latencia_ms': 40,
      });

      final r = await api((_) => _json(cuerpo)).ask(const AskRequest(pregunta: 'p'));

      expect(r.tipo, TipoRespuesta.crisis);
      expect(r.respuesta, startsWith('Siento que estés pasando por esto.'));
    });
  });

  group('errores (siempre ApiException con un mensaje que se puede enseñar)', () {
    test('error JSON 503 → ApiException con el código y el mensaje del backend', () async {
      final llamada = api((_) => _json(errorDoc, 503)).ask(const AskRequest(pregunta: 'p'));

      await expectLater(
        llamada,
        throwsA(_apiException('LLM_NO_DISPONIBLE', 'No he podido responder ahora. Prueba otra vez o pulsa Ayuda.')),
      );
    });

    test('mensaje de error con tildes en UTF-8 se lee bien', () async {
      const cuerpo = '{"error": {"codigo": "DEMASIADAS_PETICIONES", "mensaje": "Espera un momento, ¿vale? Ahora sí."}}';

      await expectLater(
        api((_) => _json(cuerpo, 429)).grade(const GradeRequest(conceptoId: 'C-ser-oido', texto: 't')),
        throwsA(_apiException('DEMASIADAS_PETICIONES', 'Espera un momento, ¿vale? Ahora sí.')),
      );
    });

    test('502 que no es JSON (p. ej. la página del túnel) → HTTP_502 con el mensaje seguro', () async {
      final llamada = api(
        (_) => http.Response('<html><body>Bad gateway</body></html>', 502, headers: {'content-type': 'text/html'}),
      ).ask(const AskRequest(pregunta: 'p'));

      await expectLater(llamada, throwsA(_apiException('HTTP_502')));
    });

    test('404 con el error por defecto de FastAPI → HTTP_404 con el mensaje seguro', () async {
      await expectLater(api((_) => _json('{"detail": "Not Found"}', 404)).health(), throwsA(_apiException('HTTP_404')));
    });

    test('fallo de red (ClientException) → SIN_CONEXION', () async {
      final llamada = api((request) => throw http.ClientException('Connection refused', request.url))
          .ask(const AskRequest(pregunta: 'p'));

      await expectLater(llamada, throwsA(_apiException('SIN_CONEXION')));
    });

    test('cualquier otro fallo del cliente, aunque no sea Exception → SIN_CONEXION', () async {
      await expectLater(
        api((_) => throw StateError('cliente cerrado')).health(),
        throwsA(_apiException('SIN_CONEXION')),
      );
      await expectLater(
        api((_) => throw ArgumentError('No host specified in URI')).health(),
        throwsA(_apiException('SIN_CONEXION')),
      );
    });

    test('el servidor no contesta a tiempo → TIEMPO_AGOTADO', () async {
      final nunca = Completer<http.Response>();
      final llamada = api(
        (_) => nunca.future,
        timeout: const Duration(milliseconds: 20),
      ).ask(const AskRequest(pregunta: 'p'));

      await expectLater(llamada, throwsA(_apiException('TIEMPO_AGOTADO')));
    });

    test('JSON válido con otra forma → RESPUESTA_INVALIDA', () async {
      const casos = <String>[
        '{"hola": "mundo"}',
        '{"tipo": "normal", "respuesta": 42}',
        '{"tipo": "normal", "respuesta": "x", "fuentes": ["A-017"]}',
        '[]',
        '"ok"',
        'null',
      ];
      for (final cuerpo in casos) {
        await expectLater(
          api((_) => _json(cuerpo)).ask(const AskRequest(pregunta: 'p')),
          throwsA(_apiException('RESPUESTA_INVALIDA')),
          reason: cuerpo,
        );
      }
      await expectLater(
        api((_) => _json('{"puntuacion": "mucho"}')).grade(const GradeRequest(conceptoId: 'c', texto: 't')),
        throwsA(_apiException('RESPUESTA_INVALIDA')),
      );
      await expectLater(api((_) => _json('{"estado": 1}')).health(), throwsA(_apiException('RESPUESTA_INVALIDA')));
    });

    test('200 que no es JSON (p. ej. un portal cautivo) → RESPUESTA_INVALIDA', () async {
      await expectLater(
        api((_) => http.Response('<html>Inicia sesión en la wifi</html>', 200)).ask(const AskRequest(pregunta: 'p')),
        throwsA(_apiException('RESPUESTA_INVALIDA')),
      );
    });

    test('sin URL del backend → SIN_API_URL, sin hacer ninguna petición', () async {
      for (final base in ['', '   ', '/']) {
        await expectLater(
          api((_) => _json(healthDoc), baseUrl: base).ask(const AskRequest(pregunta: 'p')),
          throwsA(_apiException('SIN_API_URL')),
          reason: '"$base"',
        );
      }
      expect(peticiones, isEmpty);
    });

    test('URL escrita sin http(s):// o mal formada → URL_INVALIDA, sin hacer ninguna petición', () async {
      const bases = [
        'localhost:8000',
        '192.168.1.20:8000',
        'abc.trycloudflare.com',
        'ftp://tuturno.example.com',
        'https://',
        'http:/tuturno.example.com',
        'http://[::1',
      ];
      for (final base in bases) {
        await expectLater(
          api((_) => _json(healthDoc), baseUrl: base).health(),
          throwsA(_apiException('URL_INVALIDA')),
          reason: base,
        );
      }
      expect(peticiones, isEmpty);
    });

    test('URL sin http(s):// con el cliente real tampoco se escapa como otro tipo de error', () async {
      // Antes, «192.168.1.20:8000» lanzaba FormatException y «localhost:8000», ArgumentError.
      for (final base in ['192.168.1.20:8000', 'localhost:8000']) {
        final real = HttpTuTurnoApi(baseUrl: base);
        await expectLater(real.health(), throwsA(_apiException('URL_INVALIDA')), reason: base);
        real.close();
      }
    });
  });

  test('HttpTuTurnoApi cumple la interfaz y el timeout por defecto deja margen a la segunda pasada', () {
    final real = HttpTuTurnoApi(baseUrl: _base);
    addTearDown(real.close);

    expect(real, isA<TuTurnoApi>());
    expect(real.timeout, greaterThanOrEqualTo(const Duration(seconds: 15)));
  });
}
