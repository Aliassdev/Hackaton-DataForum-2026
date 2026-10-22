import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/agente/agente_voz.dart';
import 'package:tuturno/core/agente/conexion_ws.dart';
import 'package:tuturno/core/agente/elevenlabs_ws_agente_voz.dart';
import 'package:tuturno/core/agente/url_firmada.dart';

import 'fakes_ws.dart';

// ElevenLabsWsAgenteVoz con un WebSocket falso, un reproductor falso y un reloj falso: sin red y sin audio. Inicio con
// las variables, saludo, pregunta y respuesta, ping y pong, corrección, audio en streaming, interrupción, cortes,
// reconexión, segundo plano, URL firmada frente a agent_id y las líneas TUTURNO_LAT.

const _variables = {'edad': '11', 'procedimiento': 'penal', 'rol': 'victima', 'fase': 'antes'};
const _saludo = 'Hola, soy TuTurno. ¿En qué te puedo ayudar?';
const _agentId = 'agente-de-prueba';
const _apiUrl = 'https://backend.example';

final _firmada = Uri.parse(
  'wss://api.elevenlabs.io/v1/convai/conversation?agent_id=agente-privado&conversation_signature=firma-de-prueba',
);

/// El resultado de una llamada a iniciar(), para mirarlo después de mover el reloj.
class _Llamada {
  var acabada = false;
  Object? error;
}

class _Banco {
  _Banco(this.async, {String? agentId = _agentId, this.urlFirmada, bool enviarVariablesAlLlm = false}) {
    agente = ElevenLabsWsAgenteVoz(
      agentId: agentId,
      urlFirmada: urlFirmada,
      reproductor: reproductor,
      enviarVariablesAlLlm: enviarVariablesAlLlm,
      abrirConexion: servidor.abrir,
      reloj: () => async.elapsed,
      registrar: lineas.add,
    );
    agente.mensajes.listen(mensajes.add);
    agente.errores.listen(errores.add);
    agente.estado.addListener(() => estados.add(agente.estado.value));
    agente.hablando.addListener(() => hablando.add(agente.hablando.value));
  }

  final FakeAsync async;
  final FuenteUrlFirmada? urlFirmada;
  final servidor = ServidorFalso();
  final reproductor = ReproductorFalso();
  final lineas = <String>[];
  final mensajes = <MensajeAgente>[];
  final errores = <String>[];
  final estados = <EstadoAgente>[];
  final hablando = <bool>[];
  late final ElevenLabsWsAgenteVoz agente;

  ConexionFalsa get conexion => servidor.ultima;

  List<String> get medidas => [
    for (final l in lineas)
      if (l.startsWith('TUTURNO_LAT')) l,
  ];

  _Llamada iniciar([Map<String, String> variables = _variables]) {
    final llamada = _Llamada();
    agente
        .iniciar(variables: variables)
        .then(
          (_) {
            llamada.acabada = true;
          },
          onError: (Object e) {
            llamada.error = e;
            llamada.acabada = true;
          },
        );
    async.flushMicrotasks();
    return llamada;
  }

  void flush() => async.flushMicrotasks();

  void cerrar() {
    agente.dispose();
    async.flushMicrotasks();
  }
}

/// Un banco con la sesión ya abierta.
_Banco _conectado(FakeAsync async, {String formato = 'pcm_16000'}) {
  final banco = _Banco(async)..servidor.formato = formato;
  final llamada = banco.iniciar();
  expect(llamada.error, isNull);
  expect(banco.agente.estado.value, EstadoAgente.conectado);
  return banco;
}

FuenteUrlFirmada _fuente(FakeAsync async, Future<Uri> Function(Duration limite) pedir, {CacheUrlFirmada? cache}) =>
    FuenteUrlFirmada(
      apiUrl: _apiUrl,
      cache: cache ?? CacheUrlFirmada(reloj: () => DateTime(2026, 10, 22, 9).add(async.elapsed)),
      pedir: pedir,
    );

Matcher _errorAgente(String mensaje) => isA<ErrorAgente>().having((e) => e.mensaje, 'mensaje', mensaje);

void main() {
  group('iniciar', () {
    test('conecta con el agent_id, manda las cuatro variables y queda conectado al llegar los metadatos', () {
      fakeAsync((async) {
        final b = _Banco(async);

        final llamada = b.iniciar();

        expect(llamada.acabada, isTrue);
        expect(llamada.error, isNull);
        final uri = b.servidor.uris.single;
        expect(uri.scheme, 'wss');
        expect(uri.host, 'api.elevenlabs.io');
        expect(uri.path, '/v1/convai/conversation');
        expect(uri.queryParameters, {'agent_id': _agentId});
        final inicio = b.conexion.enviados.single;
        expect(inicio['type'], 'conversation_initiation_client_data');
        expect(inicio['dynamic_variables'], _variables);
        expect(inicio.containsKey('custom_llm_extra_body'), isFalse, reason: 'el backend no lo usa: no se manda');
        expect(b.estados, [EstadoAgente.conectando, EstadoAgente.conectado]);
        expect(b.reproductor.llamadas, ['preparar(16000)'], reason: 'el reproductor se prepara mientras conecta');
        b.cerrar();
      });
    });

    test('van siempre las cuatro variables; la que falta, vacía', () {
      fakeAsync((async) {
        final b = _Banco(async);

        b.iniciar({'edad': ' 13 ', 'rol': ''});

        expect(b.conexion.enviados.single['dynamic_variables'], {
          'edad': '13',
          'procedimiento': '',
          'rol': '',
          'fase': '',
        });
        b.cerrar();
      });
    });

    test('con enviarVariablesAlLlm también van en custom_llm_extra_body', () {
      fakeAsync((async) {
        final b = _Banco(async, enviarVariablesAlLlm: true);

        b.iniciar();

        expect(b.conexion.enviados.single['custom_llm_extra_body'], _variables);
        b.cerrar();
      });
    });

    test('el formato de los metadatos elige la frecuencia del reproductor', () {
      fakeAsync((async) {
        final b = _conectado(async, formato: 'pcm_22050');

        expect(b.reproductor.llamadas, ['preparar(16000)', 'preparar(22050)']);
        expect(b.lineas, contains('TUTURNO_LAT audio pcm_22050'));
        b.cerrar();
      });
    });

    test('con API_URL usa la URL firmada (sin agent_id) y la reutiliza unos minutos', () {
      fakeAsync((async) {
        final limites = <Duration>[];
        final b = _Banco(
          async,
          agentId: null,
          urlFirmada: _fuente(async, (limite) async {
            limites.add(limite);
            return _firmada;
          }),
        );

        b.iniciar();
        expect(b.servidor.uris.single, _firmada);
        expect(limites, [ElevenLabsWsAgenteVoz.limiteUrlFirmadaSinReserva]);
        expect(b.medidas, contains(startsWith('TUTURNO_LAT url_firmada +')));

        // Otra sesión (por ejemplo, al volver de segundo plano): la misma URL, sin pasar por el backend.
        unawaited(b.agente.terminar());
        b.flush();
        b.iniciar();
        expect(b.servidor.uris, [_firmada, _firmada]);
        expect(limites, hasLength(1));
        expect(b.lineas, contains('TUTURNO_LAT url_firmada guardada'));

        // A los 10 minutos se pide otra.
        unawaited(b.agente.terminar());
        async.elapse(const Duration(minutes: 10));
        b.iniciar();
        expect(limites, hasLength(2));
        b.cerrar();
      });
    });

    test('si la URL firmada falla y hay agent_id, conecta con el agent_id', () {
      fakeAsync((async) {
        final limites = <Duration>[];
        final b = _Banco(
          async,
          urlFirmada: _fuente(async, (limite) async {
            limites.add(limite);
            throw const ErrorUrlFirmada('respuesta', codigoHttp: 503);
          }),
        );

        final llamada = b.iniciar();

        expect(llamada.error, isNull);
        expect(limites, [ElevenLabsWsAgenteVoz.limiteUrlFirmada], reason: 'con agent_id de reserva se espera menos');
        expect(b.servidor.uris.single.queryParameters, {'agent_id': _agentId});
        expect(b.agente.estado.value, EstadoAgente.conectado);
        b.cerrar();
      });
    });

    test('sin URL firmada ni agent_id no se puede conectar; sin nada configurado, tampoco', () {
      fakeAsync((async) {
        final conBackend = _Banco(
          async,
          agentId: null,
          urlFirmada: _fuente(async, (_) async => throw const ErrorUrlFirmada('sin conexión')),
        );
        expect(conBackend.iniciar().error, _errorAgente(TextosAgente.sinConexion));
        expect(conBackend.servidor.uris, isEmpty);
        expect(conBackend.agente.estado.value, EstadoAgente.desconectado);
        conBackend.cerrar();

        final sinNada = _Banco(async, agentId: '  ');
        expect(sinNada.iniciar().error, _errorAgente(TextosAgente.sinConfigurar));
        expect(sinNada.servidor.uris, isEmpty);
        sinNada.cerrar();
      });
    });

    test('si no se puede conectar con la URL firmada, se olvida y al reintentar se pide otra', () {
      fakeAsync((async) {
        var pedidas = 0;
        final b = _Banco(
          async,
          agentId: null,
          urlFirmada: _fuente(async, (_) async {
            pedidas++;
            return _firmada;
          }),
        );
        b.servidor.fallos.add(const ErrorConexionWs(codigoHttp: 403));

        expect(b.iniciar().error, _errorAgente(TextosAgente.sinConexion), reason: 'reintentable: la firma caduca');
        expect(b.iniciar().error, isNull);
        expect(pedidas, 2);
        b.cerrar();
      });
    });

    test('si el WebSocket no abre: sin conexión; si rechaza el agent_id (403 o 1008): no está preparado', () {
      fakeAsync((async) {
        final b = _Banco(async);
        b.servidor.fallos.add(const ErrorConexionWs(tiempoAgotado: true));
        expect(b.iniciar().error, _errorAgente(TextosAgente.sinConexion));
        expect(b.agente.estado.value, EstadoAgente.desconectado);

        b.servidor.fallos.add(const ErrorConexionWs(codigoHttp: 403));
        expect(b.iniciar().error, _errorAgente(TextosAgente.sinConfigurar));

        b.servidor.responderInicio = false;
        final llamada = b.iniciar();
        b.conexion.cierraServidor(1008);
        b.flush();
        expect(llamada.error, _errorAgente(TextosAgente.sinConfigurar));
        expect(b.agente.estado.value, EstadoAgente.desconectado);
        b.cerrar();
      });
    });

    test('si no llegan los metadatos a tiempo, falla y cierra la conexión', () {
      fakeAsync((async) {
        final b = _Banco(async)..servidor.responderInicio = false;

        final llamada = b.iniciar();
        async.elapse(ElevenLabsWsAgenteVoz.limiteInicio - const Duration(milliseconds: 1));
        expect(llamada.acabada, isFalse);
        async.elapse(const Duration(milliseconds: 1));

        expect(llamada.error, _errorAgente(TextosAgente.sinConexion));
        expect(b.conexion.cerradaPorLaApp, isTrue);
        expect(b.agente.estado.value, EstadoAgente.desconectado);
        b.cerrar();
      });
    });

    test('dos llamadas seguidas abren una sola sesión', () {
      fakeAsync((async) {
        final b = _Banco(async)..servidor.bloquear = Completer<void>();

        final primera = b.iniciar();
        final segunda = b.iniciar();
        b.servidor.bloquear!.complete();
        b.flush();

        expect(primera.acabada && segunda.acabada, isTrue);
        expect(b.servidor.conexiones, hasLength(1));
        b.cerrar();
      });
    });

    test('terminar mientras conecta: iniciar acaba sin error y no queda nada abierto', () {
      fakeAsync((async) {
        final b = _Banco(async)..servidor.bloquear = Completer<void>();

        final llamada = b.iniciar();
        unawaited(b.agente.terminar());
        b.servidor.bloquear!.complete();
        b.flush();

        expect(llamada.acabada, isTrue);
        expect(llamada.error, isNull);
        expect(b.conexion.cerradaPorLaApp, isTrue);
        expect(b.agente.estado.value, EstadoAgente.desconectado);
        b.cerrar();
      });
    });
  });

  group('durante la sesión', () {
    test('saludo, pregunta y respuesta: lo del agente llega como mensajes; lo enviado no vuelve como eco', () {
      fakeAsync((async) {
        final b = _conectado(async);

        b.conexion.llegaRespuesta(' $_saludo ', id: 0);
        b.flush();
        b.agente.enviarTexto('  ¿Qué es la Sala Gesell?  ');
        b.agente.enviarTexto('   ');
        b.conexion.llegaRespuesta('Es una sala con un espejo especial.', id: 2);
        b.flush();

        expect(b.conexion.deTipo('user_message').map((m) => m['text']), ['¿Qué es la Sala Gesell?']);
        expect(b.mensajes.map((m) => (m.texto, m.deAgente, m.esCorreccion)), [
          (_saludo, true, false),
          ('Es una sala con un espejo especial.', true, false),
        ]);
        b.cerrar();
      });
    });

    test('ping: pong enseguida con el mismo event_id; ping_ms solo se registra una vez', () {
      fakeAsync((async) {
        final b = _conectado(async);

        b.conexion.llegaPing(7, ms: 85);
        b.conexion.llegaPing(8);
        b.conexion.llegaPing(9, ms: 40);
        b.flush();

        expect(b.conexion.deTipo('pong').map((m) => m['event_id']), [7, 8, 9]);
        expect(b.medidas.where((l) => l.startsWith('TUTURNO_LAT ping')), ['TUTURNO_LAT ping +85 ms']);
        b.cerrar();
      });
    });

    test('corrección: llega como corrección del mensaje original', () {
      fakeAsync((async) {
        final b = _conectado(async);

        b.conexion.llegaCorreccion(_saludo, '...');
        b.conexion.llega({'type': 'agent_response_correction'});
        b.flush();

        final correccion = b.mensajes.single;
        expect(correccion.esCorreccion, isTrue);
        expect(correccion.corrigeA, _saludo);
        expect(correccion.texto, '...');
        b.cerrar();
      });
    });

    test('el audio suena según llega, sin cortes entre trozos, y hablando dura lo que suena', () {
      fakeAsync((async) {
        final b = _conectado(async);

        b.conexion.llegaAudio(pcm(200), id: 1);
        b.flush();
        expect(b.reproductor.acciones, ['preparar(16000)', 'anadir(${pcm(200).length})']);
        expect(b.agente.hablando.value, isTrue);

        async.elapse(const Duration(milliseconds: 200));
        expect(b.agente.hablando.value, isTrue, reason: 'un margen por si llega otro trozo');
        b.conexion.llegaAudio(pcm(100), id: 1);
        b.flush();
        expect(b.reproductor.acciones.last, 'anadir(${pcm(100).length})', reason: 'va directo: ya sonaba');

        async.elapse(const Duration(milliseconds: 100) + ElevenLabsWsAgenteVoz.margenFin);
        expect(b.agente.hablando.value, isFalse);
        expect(b.hablando, [true, false]);
        expect(b.reproductor.acciones, isNot(contains('parar')), reason: 'acabado, no hay nada que parar');
        b.cerrar();
      });
    });

    test('si el último trozo viene marcado como final, hablando acaba antes', () {
      fakeAsync((async) {
        final b = _conectado(async);

        b.conexion.llegaAudio(pcm(200), id: 1, esFinal: true);
        b.flush();
        async.elapse(const Duration(milliseconds: 200) + ElevenLabsWsAgenteVoz.margenFinFinal);

        expect(b.agente.hablando.value, isFalse);
        b.cerrar();
      });
    });

    test('colchón: un primer trozo muy corto espera un poco a juntarse con el siguiente', () {
      fakeAsync((async) {
        final b = _conectado(async);

        b.conexion.llegaAudio(pcm(40), id: 1);
        b.flush();
        expect(b.reproductor.trozos, isEmpty);
        expect(b.agente.hablando.value, isFalse);
        async.elapse(const Duration(milliseconds: 20));
        b.conexion.llegaAudio(pcm(80), id: 1);
        b.flush();
        expect(b.reproductor.trozos.single, hasLength(pcm(120).length), reason: 'los dos juntos');
        expect(b.agente.hablando.value, isTrue);

        // Después de acabar, un trozo corto solo suena igual al poco.
        async.elapse(const Duration(seconds: 2));
        b.conexion.llegaAudio(pcm(30), id: 3);
        b.flush();
        expect(b.reproductor.trozos, hasLength(1));
        async.elapse(ElevenLabsWsAgenteVoz.esperaColchon);
        expect(b.reproductor.trozos, hasLength(2));
        b.cerrar();
      });
    });

    test('si el reproductor va por detrás del reloj, hablando sigue hasta que acaba de verdad', () {
      fakeAsync((async) {
        final b = _conectado(async);
        b.reproductor.queda = const Duration(milliseconds: 300);

        b.conexion.llegaAudio(pcm(200), id: 1);
        b.flush();
        async.elapse(const Duration(milliseconds: 200) + ElevenLabsWsAgenteVoz.margenFin);
        expect(b.agente.hablando.value, isTrue);

        b.reproductor.queda = Duration.zero;
        async.elapse(const Duration(milliseconds: 300) + ElevenLabsWsAgenteVoz.margenFin);
        expect(b.agente.hablando.value, isFalse);
        b.cerrar();
      });
    });

    test('interrupción: para el audio en el acto, vacía el colchón y descarta lo que llega tarde', () {
      fakeAsync((async) {
        final b = _conectado(async);
        b.conexion.llegaAudio(pcm(500), id: 3);
        b.flush();
        expect(b.agente.hablando.value, isTrue);

        b.conexion.llegaInterrupcion(4);
        b.flush();
        expect(b.agente.hablando.value, isFalse);
        expect(b.reproductor.acciones.last, 'parar');

        b.conexion.llegaAudio(pcm(300), id: 3);
        b.flush();
        expect(b.reproductor.trozos, hasLength(1), reason: 'era de la respuesta interrumpida');

        b.conexion.llegaAudio(pcm(40), id: 5);
        b.flush();
        b.conexion.llegaInterrupcion(6);
        b.flush();
        async.elapse(const Duration(milliseconds: 200));
        expect(b.reproductor.trozos, hasLength(1), reason: 'el colchón se vacía sin sonar');

        b.conexion.llegaAudio(pcm(200), id: 7);
        b.flush();
        expect(b.reproductor.trozos, hasLength(2));
        expect(b.agente.hablando.value, isTrue);
        b.cerrar();
      });
    });

    test('una pregunta nueva calla el audio y descarta lo que llegue tarde de la respuesta anterior', () {
      fakeAsync((async) {
        final b = _conectado(async);
        b.conexion.llegaRespuesta('Una respuesta larga.', id: 1);
        b.conexion.llegaAudio(pcm(800), id: 1);
        b.flush();

        b.agente.enviarTexto('Otra pregunta');
        expect(b.agente.hablando.value, isFalse);
        expect(b.reproductor.acciones.last, 'parar');

        b.conexion.llegaAudio(pcm(200), id: 1);
        b.flush();
        expect(b.reproductor.trozos, hasLength(1));
        b.conexion.llegaAudio(pcm(200), id: 3);
        b.flush();
        expect(b.reproductor.trozos, hasLength(2));
        b.cerrar();
      });
    });

    test('ulaw_8000 se pasa a PCM de 16 bits a 8000 Hz', () {
      fakeAsync((async) {
        final b = _conectado(async, formato: 'ulaw_8000');
        expect(b.reproductor.llamadas, contains('preparar(8000)'));

        final ulaw = Uint8List(800)..setAll(0, [0xFF, 0x00, 0x80]);
        b.conexion.llegaAudio(ulaw, id: 1);
        b.flush();

        final trozo = b.reproductor.trozos.single;
        expect(trozo, hasLength(1600));
        final muestras = ByteData.sublistView(trozo);
        expect([for (var i = 0; i < 3; i++) muestras.getInt16(i * 2, Endian.little)], [0, -32124, 32124]);
        b.cerrar();
      });
    });

    test('user_activity, como mucho una vez por segundo', () {
      fakeAsync((async) {
        final b = _conectado(async);

        b.agente.avisarQueEscribe();
        b.agente.avisarQueEscribe();
        expect(b.conexion.deTipo('user_activity'), hasLength(1));
        async.elapse(const Duration(milliseconds: 1100));
        b.agente.avisarQueEscribe();

        expect(b.conexion.deTipo('user_activity'), hasLength(2));
        b.cerrar();
      });
    });

    test('una client tool (fase 2, sin hacer) se contesta con error para que el agente no espere', () {
      fakeAsync((async) {
        final b = _conectado(async);

        b.conexion.llega({
          'type': 'client_tool_call',
          'client_tool_call': {
            'tool_name': 'mostrar_fuentes',
            'tool_call_id': 'llamada_1',
            'parameters': <String, Object?>{},
            'expects_response': true,
          },
        });
        b.flush();

        final resultado = b.conexion.deTipo('client_tool_result').single;
        expect(resultado['tool_call_id'], 'llamada_1');
        expect(resultado['is_error'], isTrue);
        b.cerrar();
      });
    });

    test('lo que no se entiende o no hace falta se ignora; nunca se manda audio', () {
      fakeAsync((async) {
        final b = _conectado(async);

        b.conexion.llegaTextoCrudo('esto no es JSON');
        b.conexion.llega({
          'type': 'vad_score',
          'vad_score_event': {'vad_score': 0.9},
        });
        b.conexion.llega({
          'type': 'user_transcript',
          'user_transcription_event': {'user_transcript': 'x'},
        });
        b.conexion.llega({
          'type': 'audio',
          'audio_event': {'audio_base_64': '%%%', 'event_id': 1},
        });
        b.conexion.llegaPing(1);
        b.agente.enviarTexto('Hola');
        b.agente.avisarQueEscribe();
        b.flush();

        expect(b.mensajes, isEmpty);
        expect(b.reproductor.trozos, isEmpty);
        expect(b.conexion.tipos.toSet(), {
          'conversation_initiation_client_data',
          'pong',
          'user_message',
          'user_activity',
        });
        expect(b.conexion.enviados.where((m) => m.containsKey('user_audio_chunk')), isEmpty);
        b.cerrar();
      });
    });

    test('sin sesión, enviarTexto avisa y no manda nada; si falla el envío, también avisa', () {
      fakeAsync((async) {
        final b = _Banco(async);
        b.agente.enviarTexto('hola');
        b.flush();
        expect(b.errores, [TextosAgente.sinSesion]);
        expect(b.servidor.conexiones, isEmpty);

        b.iniciar();
        b.conexion.fallarAlEnviar = true;
        b.agente.enviarTexto('hola');
        b.flush();
        expect(b.errores, [TextosAgente.sinSesion, TextosAgente.noEnviado]);
        b.cerrar();
      });
    });

    test('si el reproductor no se puede preparar, la sesión sigue (solo texto) y no hay hablando', () {
      fakeAsync((async) {
        final b = _Banco(async)..reproductor.fallarAlPreparar = StateError('sin AudioTrack');
        b.iniciar();

        b.conexion.llegaRespuesta('Te lo explico.', id: 1);
        b.conexion.llegaAudio(pcm(200), id: 1);
        b.flush();

        expect(b.agente.estado.value, EstadoAgente.conectado);
        expect(b.mensajes.single.texto, 'Te lo explico.');
        expect(b.reproductor.trozos, isEmpty);
        expect(b.agente.hablando.value, isFalse);
        b.cerrar();
      });
    });
  });

  group('cortes y reconexión', () {
    test('si se corta a mitad de una pregunta: desconectado enseguida y reconecta sola en segundo plano', () {
      fakeAsync((async) {
        final b = _conectado(async);
        b.agente.enviarTexto('¿Qué es la Sala Gesell?');
        b.estados.clear();

        b.conexion.seCae();
        b.flush();

        expect(b.agente.estado.value, EstadoAgente.desconectado, reason: 'Pregunta enseña el error ya');
        expect(b.estados, [EstadoAgente.desconectado]);
        expect(b.lineas, contains('TUTURNO_LAT corte motivo=red'));

        async.elapse(ElevenLabsWsAgenteVoz.esperasReconexion.first);
        expect(b.servidor.conexiones, hasLength(2));
        expect(b.agente.estado.value, EstadoAgente.conectado);
        expect(b.lineas, contains('TUTURNO_LAT reconexion intento=1'));
        b.cerrar();
      });
    });

    test(
      'si se cae sin pregunta pendiente, reconecta sola sin saludar; si Pregunta la pide, el saludo va en texto',
      () {
        fakeAsync((async) {
          final b = _conectado(async);
          b.conexion.llegaRespuesta(_saludo, id: 0);
          b.flush();
          b.mensajes.clear();

          b.conexion.cierraServidor(1006);
          b.flush();
          expect(b.agente.estado.value, EstadoAgente.conectando, reason: 'para Pregunta sigue habiendo conversación');
          expect(b.lineas, contains('TUTURNO_LAT corte motivo=red codigo=1006'));

          async.elapse(ElevenLabsWsAgenteVoz.esperasReconexion.first);
          expect(b.agente.estado.value, EstadoAgente.conectado);
          final nueva = b.conexion;
          expect(nueva.enviados.first['dynamic_variables'], _variables, reason: 'las mismas variables');
          nueva.llegaRespuesta(_saludo, id: 0);
          nueva.llegaAudio(pcm(300), id: 0);
          b.flush();
          expect(b.mensajes, isEmpty);
          expect(b.reproductor.trozos, isEmpty, reason: 'nadie ha pedido oír el saludo otra vez');
          expect(b.agente.hablando.value, isFalse);

          // Pregunta pide la sesión (por ejemplo, con «Conectar»): no abre otra y recibe el saludo como texto.
          final llamada = b.iniciar();
          expect(llamada.acabada, isTrue);
          expect(b.servidor.conexiones, hasLength(2));
          expect(b.mensajes.single.texto, _saludo);
          nueva.llegaAudio(pcm(300), id: 0);
          b.flush();
          expect(b.reproductor.trozos, isEmpty, reason: 'el resto del saludo empezaría a medias');

          b.agente.enviarTexto('¿Qué es la Sala Gesell?');
          nueva.llegaRespuesta('Es una sala especial.', id: 2);
          nueva.llegaAudio(pcm(200), id: 2);
          b.flush();
          expect(b.mensajes.last.texto, 'Es una sala especial.');
          expect(b.reproductor.trozos, hasLength(1));
          b.cerrar();
        });
      },
    );

    test('reintenta con esperas crecientes y, tras el último intento, queda desconectado', () {
      fakeAsync((async) {
        final b = _conectado(async);
        b.servidor.fallos.addAll(List.filled(5, const ErrorConexionWs()));

        b.conexion.seCae();
        b.flush();
        final intentos = <int>[];
        for (final espera in ElevenLabsWsAgenteVoz.esperasReconexion) {
          async.elapse(espera - const Duration(milliseconds: 1));
          intentos.add(b.servidor.uris.length);
          async.elapse(const Duration(milliseconds: 1));
          intentos.add(b.servidor.uris.length);
          if (b.servidor.uris.length < 6) expect(b.agente.estado.value, EstadoAgente.conectando);
        }

        expect(intentos, [1, 2, 2, 3, 3, 4, 4, 5, 5, 6]);
        expect(b.agente.estado.value, EstadoAgente.desconectado);
        async.elapse(const Duration(minutes: 1));
        expect(b.servidor.uris, hasLength(6));
        b.cerrar();
      });
    });

    test('un cierre normal del servidor (fin de la llamada o duración máxima) no reconecta solo', () {
      fakeAsync((async) {
        final b = _conectado(async);

        b.conexion.cierraServidor(1000);
        b.flush();
        async.elapse(const Duration(minutes: 1));

        expect(b.agente.estado.value, EstadoAgente.desconectado);
        expect(b.servidor.conexiones, hasLength(1));
        expect(b.lineas, contains('TUTURNO_LAT corte motivo=fin_servidor codigo=1000'));
        b.cerrar();
      });
    });

    test('no reconecta sola más de tres veces seguidas si el usuario no pregunta nada', () {
      fakeAsync((async) {
        final b = _conectado(async);

        for (var i = 0; i < ElevenLabsWsAgenteVoz.maxReconexionesSinActividad; i++) {
          b.conexion.seCae();
          b.flush();
          async.elapse(ElevenLabsWsAgenteVoz.esperasReconexion.first);
          expect(b.agente.estado.value, EstadoAgente.conectado);
        }
        b.conexion.seCae();
        b.flush();
        async.elapse(const Duration(minutes: 1));

        expect(b.servidor.conexiones, hasLength(1 + ElevenLabsWsAgenteVoz.maxReconexionesSinActividad));
        expect(b.agente.estado.value, EstadoAgente.desconectado);
        b.cerrar();
      });
    });

    test('si Pregunta pide la sesión mientras se reconecta, espera a esa misma y el saludo suena', () {
      fakeAsync((async) {
        final b = _conectado(async);
        b.servidor.bloquear = Completer<void>();
        b.conexion.seCae();
        b.flush();
        async.elapse(ElevenLabsWsAgenteVoz.esperasReconexion.first);

        final llamada = b.iniciar();
        expect(b.servidor.uris, hasLength(2));
        expect(llamada.acabada, isFalse);
        b.servidor.bloquear!.complete();
        b.flush();

        expect(llamada.acabada, isTrue);
        expect(llamada.error, isNull);
        expect(b.servidor.uris, hasLength(2), reason: 'no abre otra');
        b.conexion.llegaRespuesta(_saludo, id: 0);
        b.conexion.llegaAudio(pcm(200), id: 0);
        b.flush();
        expect(b.mensajes.single.texto, _saludo);
        expect(b.reproductor.trozos, hasLength(1));
        b.cerrar();
      });
    });

    test('al pasar a segundo plano (terminar) se calla en el acto, cierra y no reconecta', () {
      fakeAsync((async) {
        final b = _conectado(async);
        b.conexion.llegaAudio(pcm(500), id: 1);
        b.flush();
        expect(b.agente.hablando.value, isTrue);

        unawaited(b.agente.terminar());
        b.flush();

        expect(b.agente.hablando.value, isFalse);
        expect(b.reproductor.acciones.last, 'parar');
        expect(b.conexion.cerradaPorLaApp, isTrue);
        expect(b.agente.estado.value, EstadoAgente.desconectado);
        b.conexion.llegaRespuesta('tarde', id: 2);
        b.flush();
        async.elapse(const Duration(minutes: 1));
        expect(b.mensajes, isEmpty);
        expect(b.servidor.conexiones, hasLength(1));
        expect(b.medidas.where((l) => l.contains('corte')), isEmpty, reason: 'no es un corte');
        b.cerrar();
      });
    });

    test('dispose cierra todo y después es seguro', () {
      fakeAsync((async) {
        final b = _conectado(async);
        var cerrado = false;
        b.agente.mensajes.listen(null, onDone: () => cerrado = true);

        b.agente.dispose();
        b.flush();

        expect(cerrado, isTrue);
        expect(b.conexion.cerradaPorLaApp, isTrue);
        expect(b.reproductor.llamadas.last, 'liberar');
        b.agente.enviarTexto('hola');
        b.agente.avisarQueEscribe();
        unawaited(b.agente.terminar());
        expect(b.iniciar().error, isStateError);
        b.agente.dispose();
      });
    });
  });

  test('TUTURNO_LAT: conectado, envío, primer texto, primer audio, suena y corte, sin datos del usuario', () {
    fakeAsync((async) {
      final b = _Banco(async)..servidor.responderInicio = false;

      b.iniciar();
      async.elapse(const Duration(milliseconds: 250));
      b.conexion.llegaMetadatos();
      b.flush();
      expect(b.medidas, [
        'TUTURNO_LAT ws_abierto +0 ms',
        'TUTURNO_LAT audio pcm_16000',
        'TUTURNO_LAT conectado +250 ms',
      ]);

      b.lineas.clear();
      async.elapse(const Duration(seconds: 1));
      b.agente.enviarTexto('Tengo 13 años y me llamo Ana');
      async.elapse(const Duration(milliseconds: 600));
      b.conexion.llegaTrozoDeTexto('Vale');
      b.flush();
      async.elapse(const Duration(milliseconds: 300));
      b.conexion.llegaRespuesta('Vale, te lo explico.', id: 2);
      b.flush();
      async.elapse(const Duration(milliseconds: 100));
      b.conexion.llegaAudio(pcm(200), id: 2);
      b.conexion.llegaAudio(pcm(200), id: 2);
      b.flush();
      expect(b.medidas, [
        'TUTURNO_LAT envio',
        'TUTURNO_LAT primer_texto +600 ms',
        'TUTURNO_LAT primer_audio +1000 ms',
        'TUTURNO_LAT suena +1000 ms',
      ]);

      b.conexion.cierraServidor(1011);
      b.flush();
      expect(b.medidas.last, 'TUTURNO_LAT corte motivo=error_servidor codigo=1011');
      for (final linea in b.lineas) {
        expect(linea, isNot(contains('Ana')));
        expect(linea, isNot(contains('13 años')));
        expect(linea, isNot(contains(_agentId)));
        expect(linea, isNot(contains('Vale')));
      }
      b.cerrar();
    });
  });

  test('mensajeDeConexion: agent_id rechazado frente a sin red', () {
    expect(ElevenLabsWsAgenteVoz.mensajeDeConexion(const ErrorConexionWs(codigoHttp: 403)), TextosAgente.sinConfigurar);
    expect(ElevenLabsWsAgenteVoz.mensajeDeConexion(const ErrorConexionWs(codigoHttp: 404)), TextosAgente.sinConfigurar);
    expect(
      ElevenLabsWsAgenteVoz.mensajeDeConexion(const ErrorConexionWs(codigoCierre: 1008)),
      TextosAgente.sinConfigurar,
    );
    expect(ElevenLabsWsAgenteVoz.mensajeDeConexion(const ErrorConexionWs(codigoHttp: 500)), TextosAgente.sinConexion);
    expect(
      ElevenLabsWsAgenteVoz.mensajeDeConexion(const ErrorConexionWs(tiempoAgotado: true)),
      TextosAgente.sinConexion,
    );
    expect(ElevenLabsWsAgenteVoz.mensajeDeConexion(TimeoutException('x')), TextosAgente.sinConexion);
  });
}
