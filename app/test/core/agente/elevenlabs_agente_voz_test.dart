import 'dart:async';

import 'package:elevenlabs_agents/elevenlabs_agents.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/agente/agente_voz.dart';
import 'package:tuturno/core/agente/elevenlabs_agente_voz.dart';

// ElevenLabsAgenteVoz con un ConversationClient falso: sin red, sin LiveKit y sin micrófono. Basado en el de la
// ronda de diseño (plan-v2/sdk), con lo que cambia aquí: sin eco, con correcciones y con variables vacías.

const _variables = {'edad': '11', 'procedimiento': 'penal', 'rol': 'victima', 'fase': 'antes'};

/// Deja correr los microtasks y timers pendientes (avisos de los streams y liberación del cliente).
Future<void> _esperar() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late List<_ClienteFalso> clientes;
  late DateTime ahora;

  setUp(() {
    clientes = [];
    ahora = DateTime(2026, 10, 22, 9, 30);
  });

  ElevenLabsAgenteVoz crear({
    String? agentId = 'agente-de-prueba',
    Future<String> Function()? pedirToken,
    bool enviarVariablesAlLlm = false,
    void Function(_ClienteFalso cliente)? preparar,
  }) {
    final agente = ElevenLabsAgenteVoz(
      agentId: agentId,
      pedirToken: pedirToken,
      enviarVariablesAlLlm: enviarVariablesAlLlm,
      crearCliente: (callbacks) {
        final cliente = _ClienteFalso(callbacks);
        preparar?.call(cliente);
        clientes.add(cliente);
        return cliente;
      },
      reloj: () => ahora,
    );
    addTearDown(agente.dispose);
    return agente;
  }

  group('iniciar', () {
    test('abre la sesión con las variables y silencia el micrófono antes de darla por conectada', () async {
      final agente = crear();
      final estados = <EstadoAgente>[];
      agente.estado.addListener(() => estados.add(agente.estado.value));

      await agente.iniciar(variables: _variables);

      final cliente = clientes.single;
      expect(cliente.agentIdUsado, 'agente-de-prueba');
      expect(cliente.tokenUsado, isNull);
      expect(cliente.variables, _variables);
      expect(cliente.extraBody, isNull, reason: 'el backend no usa elevenlabs_extra_body: no se manda');
      expect(cliente.llamadas, ['startSession', 'setMicMuted(true)']);
      expect(cliente.isMuted, isTrue);
      expect(estados, [EstadoAgente.conectando, EstadoAgente.conectado]);
    });

    test('van siempre las cuatro variables; la que no se sabe, vacía (ElevenLabs lo acepta)', () async {
      final agente = crear();

      await agente.iniciar(variables: {'edad': ' 13 ', 'rol': ''});

      expect(clientes.single.variables, {'edad': '13', 'procedimiento': '', 'rol': '', 'fase': ''});
    });

    test('con enviarVariablesAlLlm también van en customLlmExtraBody', () async {
      final agente = crear(enviarVariablesAlLlm: true);

      await agente.iniciar(variables: _variables);

      expect(clientes.single.extraBody, _variables);
    });

    test('con pedirToken usa el token del backend y no el agentId', () async {
      final agente = crear(pedirToken: () async => ' token-de-prueba ');

      await agente.iniciar(variables: _variables);

      expect(clientes.single.tokenUsado, 'token-de-prueba');
      expect(clientes.single.agentIdUsado, isNull);
    });

    test('sin agentId ni token lanza ErrorAgente y no crea ningún cliente', () async {
      final agente = crear(agentId: '  ');

      await expectLater(
        agente.iniciar(variables: _variables),
        throwsA(isA<ErrorAgente>().having((e) => e.mensaje, 'mensaje', TextosAgente.sinConfigurar)),
      );
      expect(clientes, isEmpty);
      expect(agente.estado.value, EstadoAgente.desconectado);
    });

    test('si se deniega el micrófono, el error lo dice y el cliente se libera', () async {
      final agente = crear(preparar: (c) => c.fallarAlIniciar = Exception('DOMException, NotAllowedError'));

      await expectLater(
        agente.iniciar(variables: _variables),
        throwsA(isA<ErrorAgente>().having((e) => e.mensaje, 'mensaje', TextosAgente.sinPermiso)),
      );
      await _esperar();
      expect(agente.estado.value, EstadoAgente.desconectado);
      expect(clientes.single.liberado, isTrue);
    });

    test('si no se puede silenciar el micrófono, cierra la sesión y lanza ErrorAgente', () async {
      final agente = crear(preparar: (c) => c.silenciable = false);

      await expectLater(
        agente.iniciar(variables: _variables),
        throwsA(isA<ErrorAgente>().having((e) => e.mensaje, 'mensaje', TextosAgente.microAbierto)),
      );
      await _esperar();
      final cliente = clientes.single;
      expect(cliente.llamadas.where((l) => l == 'setMicMuted(true)'), hasLength(3));
      expect(cliente.terminado, greaterThanOrEqualTo(1));
      expect(cliente.liberado, isTrue);
      expect(agente.estado.value, EstadoAgente.desconectado);
    });

    test('dos llamadas seguidas abren una sola sesión', () async {
      final agente = crear();

      await Future.wait([agente.iniciar(variables: _variables), agente.iniciar(variables: _variables)]);

      expect(clientes, hasLength(1));
    });

    test('terminar mientras conecta: iniciar acaba sin error y no queda nada abierto', () async {
      final bloqueo = Completer<void>();
      final agente = crear(preparar: (c) => c.bloquearInicio = bloqueo);

      final iniciando = agente.iniciar(variables: _variables);
      await _esperar();
      final terminando = agente.terminar();
      bloqueo.complete();
      await iniciando;
      await terminando;

      final cliente = clientes.single;
      expect(agente.estado.value, EstadoAgente.desconectado);
      expect(cliente.status, ConversationStatus.disconnected);
      expect(cliente.liberado, isTrue);
    });

    test('después de terminar mientras conectaba, iniciar abre otra sesión (no devuelve la anterior)', () async {
      final bloqueo = Completer<void>();
      var primero = true;
      final agente = crear(
        preparar: (c) {
          if (primero) c.bloquearInicio = bloqueo;
          primero = false;
        },
      );

      final viejo = agente.iniciar(variables: _variables);
      await _esperar();
      unawaited(agente.terminar());
      await agente.iniciar(variables: _variables);

      expect(clientes, hasLength(2));
      expect(agente.estado.value, EstadoAgente.conectado);
      bloqueo.complete();
      await viejo;
      await _esperar();
      expect(agente.estado.value, EstadoAgente.conectado, reason: 'la sesión vieja no toca la nueva');
    });

    test('después de una desconexión, la sesión nueva usa un cliente nuevo', () async {
      final agente = crear();
      await agente.iniciar(variables: _variables);
      clientes.first.callbacks.onDisconnect!(DisconnectionDetails(reason: 'agent'));
      await _esperar();

      await agente.iniciar(variables: _variables);

      expect(clientes, hasLength(2));
      expect(clientes.first.liberado, isTrue);
      expect(agente.estado.value, EstadoAgente.conectado);
    });
  });

  group('durante la sesión', () {
    late ElevenLabsAgenteVoz agente;
    late _ClienteFalso cliente;
    late List<MensajeAgente> mensajes;
    late List<String> errores;

    setUp(() async {
      agente = crear();
      mensajes = [];
      errores = [];
      final subMensajes = agente.mensajes.listen(mensajes.add);
      final subErrores = agente.errores.listen(errores.add);
      addTearDown(subMensajes.cancel);
      addTearDown(subErrores.cancel);
      await agente.iniciar(variables: _variables);
      cliente = clientes.single;
    });

    test('las respuestas del agente llegan como mensajes; lo que ElevenLabs atribuya al usuario, no', () async {
      cliente.callbacks.onMessage!(message: ' Hola, soy TuTurno. ', source: Role.ai);
      cliente.callbacks.onMessage!(message: 'transcripción que no debería existir', source: Role.user);
      await _esperar();

      expect(mensajes.map((m) => (m.texto, m.deAgente, m.esCorreccion)), [('Hola, soy TuTurno.', true, false)]);
    });

    test('si se interrumpe al agente, llega la corrección con el texto original', () async {
      cliente.callbacks.onAgentResponseCorrection!({
        'type': 'agent_response_correction',
        'agent_response_correction_event': {
          'original_agent_response': 'Hola, soy TuTurno. ¿En qué te puedo ayudar?',
          'corrected_agent_response': '...',
          'event_id': 1,
        },
      });
      cliente.callbacks.onAgentResponseCorrection!({'type': 'agent_response_correction'});
      await _esperar();

      final correccion = mensajes.single;
      expect(correccion.esCorreccion, isTrue);
      expect(correccion.corrigeA, 'Hola, soy TuTurno. ¿En qué te puedo ayudar?');
      expect(correccion.texto, '...');
    });

    test('si llega una transcripción del usuario con el micrófono abierto, lo vuelve a silenciar', () async {
      cliente.silenciado = false;

      cliente.callbacks.onUserTranscript!(transcript: 'x', eventId: 1);
      await _esperar();

      expect(cliente.isMuted, isTrue);
      expect(cliente.llamadas.where((l) => l == 'setMicMuted(true)'), hasLength(2));
    });

    test('enviarTexto manda el texto limpio y no lo devuelve como eco', () async {
      agente.enviarTexto('  ¿Qué es la Sala Gesell?  ');
      agente.enviarTexto('   ');
      await _esperar();

      expect(cliente.enviados, ['¿Qué es la Sala Gesell?']);
      expect(mensajes, isEmpty);
    });

    test('hablando sigue el modo del agente', () {
      cliente.callbacks.onModeChange!(mode: ConversationMode.speaking);
      expect(agente.hablando.value, isTrue);

      cliente.callbacks.onModeChange!(mode: ConversationMode.listening);
      expect(agente.hablando.value, isFalse);
    });

    test('avisarQueEscribe manda user_activity como mucho una vez por segundo', () {
      agente.avisarQueEscribe();
      agente.avisarQueEscribe();
      expect(cliente.actividades, 1);

      ahora = ahora.add(const Duration(milliseconds: 1100));
      agente.avisarQueEscribe();
      expect(cliente.actividades, 2);
    });

    test('si falla el envío, avisa con un texto propio', () async {
      cliente.callbacks.onError!('Failed to send message', StateError('x'));
      cliente.callbacks.onError!('Data stream error', Exception('Could not enable speakerphone'));
      await _esperar();

      expect(errores, [TextosAgente.noEnviado]);
    });

    test('si se corta la conexión, avisa, pasa a desconectado y libera el cliente', () async {
      cliente.callbacks.onModeChange!(mode: ConversationMode.speaking);

      cliente.callbacks.onDisconnect!(DisconnectionDetails(reason: 'error'));

      expect(agente.estado.value, EstadoAgente.desconectado);
      expect(agente.hablando.value, isFalse);
      await _esperar();
      expect(errores, [TextosAgente.cortado]);
      expect(cliente.liberado, isTrue);
    });

    test('si el agente termina la conversación, no es un error', () async {
      cliente.callbacks.onDisconnect!(DisconnectionDetails(reason: 'agent'));
      await _esperar();

      expect(agente.estado.value, EstadoAgente.desconectado);
      expect(errores, isEmpty);
      expect(cliente.liberado, isTrue);
    });

    test('terminar cierra la sesión y lo que llegue tarde se ignora', () async {
      await agente.terminar();

      expect(cliente.terminado, greaterThanOrEqualTo(1));
      expect(cliente.liberado, isTrue);
      expect(agente.estado.value, EstadoAgente.desconectado);

      cliente.callbacks.onMessage!(message: 'tarde', source: Role.ai);
      cliente.callbacks.onModeChange!(mode: ConversationMode.speaking);
      await _esperar();
      expect(mensajes, isEmpty);
      expect(agente.hablando.value, isFalse);
    });

    test('sin sesión, enviarTexto avisa y no manda nada', () async {
      await agente.terminar();

      agente.enviarTexto('hola');
      await _esperar();

      expect(cliente.enviados, isEmpty);
      expect(errores, [TextosAgente.sinSesion]);
    });
  });

  test('dispose cierra los streams y después todo es seguro', () async {
    final agente = crear();
    await agente.iniciar(variables: _variables);
    final cerrado = Completer<void>();
    agente.mensajes.listen(null, onDone: cerrado.complete);

    agente.dispose();
    await cerrado.future;
    await _esperar();

    expect(clientes.single.liberado, isTrue);
    agente.enviarTexto('hola');
    agente.avisarQueEscribe();
    await agente.terminar();
    await expectLater(agente.iniciar(variables: _variables), throwsStateError);
  });

  test('mensajeDeConexion: agent_id rechazado, sin red y sin permiso', () {
    expect(
      ElevenLabsAgenteVoz.mensajeDeConexion(Exception('Failed to fetch token (403): {"detail": "missing permission"}')),
      TextosAgente.sinConfigurar,
    );
    expect(ElevenLabsAgenteVoz.mensajeDeConexion(Exception('Failed to fetch token (500)')), TextosAgente.sinConexion);
    expect(
      ElevenLabsAgenteVoz.mensajeDeConexion(Exception('SocketException: Failed host lookup')),
      TextosAgente.sinConexion,
    );
    expect(ElevenLabsAgenteVoz.mensajeDeConexion(Exception('DOMException, NotAllowedError')), TextosAgente.sinPermiso);
  });
}

/// ConversationClient sin red. Imita lo que importa del SDK 0.6.1: al conectar deja el micrófono abierto.
class _ClienteFalso extends ChangeNotifier implements ConversationClient {
  _ClienteFalso(this.callbacks);

  final ConversationCallbacks callbacks;

  // Lo que prepara cada test.
  Object? fallarAlIniciar;
  Completer<void>? bloquearInicio;
  var silenciable = true;

  // Lo que se comprueba.
  final llamadas = <String>[];
  final enviados = <String>[];
  String? agentIdUsado;
  String? tokenUsado;
  Map<String, dynamic>? variables;
  Map<String, dynamic>? extraBody;
  var actividades = 0;
  var terminado = 0;
  var liberado = false;
  var silenciado = true;
  var _status = ConversationStatus.disconnected;

  @override
  ConversationStatus get status => _status;

  @override
  bool get isMuted => silenciado;

  @override
  Future<void> startSession({
    String? agentId,
    String? conversationToken,
    String? userId,
    String? environment,
    ConversationOverrides? overrides,
    Map<String, dynamic>? customLlmExtraBody,
    Map<String, dynamic>? dynamicVariables,
  }) async {
    llamadas.add('startSession');
    agentIdUsado = agentId;
    tokenUsado = conversationToken;
    variables = dynamicVariables;
    extraBody = customLlmExtraBody;
    _status = ConversationStatus.connecting;
    await bloquearInicio?.future;
    final fallo = fallarAlIniciar;
    if (fallo != null) {
      _status = ConversationStatus.disconnected;
      throw fallo;
    }
    silenciado = false;
    _status = ConversationStatus.connected;
  }

  @override
  Future<void> setMicMuted(bool muted) async {
    llamadas.add('setMicMuted($muted)');
    if (silenciable) silenciado = muted;
  }

  @override
  void sendUserMessage(String text) {
    if (_status != ConversationStatus.connected) throw StateError('Not connected to agent');
    enviados.add(text);
  }

  @override
  void sendUserActivity() => actividades++;

  @override
  Future<void> endSession() async {
    terminado++;
    _status = ConversationStatus.disconnected;
  }

  @override
  void dispose() {
    liberado = true;
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
