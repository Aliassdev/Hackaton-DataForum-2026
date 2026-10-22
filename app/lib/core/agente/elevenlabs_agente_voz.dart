import 'dart:async';

import 'package:elevenlabs_agents/elevenlabs_agents.dart';
import 'package:flutter/foundation.dart';

import 'agente_voz.dart';

// Pregunta, fase 1 (docs/ARQUITECTURA.md, secciones 5.0 y 8.5 a 8.7): una sesión de ElevenLabs Agents con el SDK
// oficial elevenlabs_agents 0.6.1. La voz del menor nunca entra en la sesión: se transcribe en el móvil
// (speech_to_text) y llega como texto con sendUserMessage. ElevenLabs solo pone la voz del agente.
//
// Lo que hace el SDK por dentro y explica este archivo (comprobado en su código, ~/.pub-cache):
// - startSession() publica siempre el micrófono al conectar (LiveKitManager.connect llama a
//   setMicrophoneEnabled(true)) y no tiene ninguna opción para empezar en silencio. Por eso se silencia justo
//   después, se comprueba con isMuted y, si no se puede, se cierra la sesión. Queda un hueco de una fracción de
//   segundo (lo que tarda en enviarse el mensaje de inicio) con el micrófono abierto.
// - Al silenciar, LiveKit para la captura (stopAudioCaptureOnMute vale true por defecto en Android).
// - Si el agente cuelga o se corta la red, el SDK pasa a «disconnected», pero no suelta la sala de LiveKit ni sus
//   suscripciones, y endSession() ya no hace nada. Un startSession() posterior duplicaría los callbacks. Por eso
//   cada sesión usa un ConversationClient nuevo y se libera con dispose().
// - onMessage(Role.ai) trae el texto completo de cada turno del agente (agent_response), antes que el audio. Un
//   Role.user solo llegaría si ElevenLabs transcribiera el micrófono: no se enseña y se vuelve a silenciar.
// - Si se interrumpe al agente (por ejemplo, se manda una pregunta mientras saluda), llegan «interruption» y
//   «agent_response_correction» con lo que llegó a decir: se emite como corrección del mensaje original.
// - Los errores del SDK llegan por onError con frases fijas en inglés: aquí solo se enseñan textos propios.
// - Si el Custom LLM (el backend de B) no responde, ElevenLabs no avisa: ni error ni cierre. El tiempo de espera lo
//   pone quien usa esta clase (features/pregunta/agente/chat_agente.dart).

/// Crea el cliente del SDK con los callbacks de una sesión. En los tests se sustituye por uno falso.
typedef CrearClienteAgente = ConversationClient Function(ConversationCallbacks callbacks);

/// No se ha podido abrir la sesión. [mensaje] se puede enseñar tal cual.
class ErrorAgente implements Exception {
  const ErrorAgente(this.mensaje, {this.causa});

  final String mensaje;

  /// Lo que lanzó el SDK, solo para depurar. No se enseña.
  final Object? causa;

  @override
  String toString() => 'ErrorAgente: $mensaje';
}

/// Textos para el usuario: frases cortas y claras para 11 a 17 años. Sin promesas.
abstract final class TextosAgente {
  static const sinConfigurar =
      'TuTurno no está preparado en este móvil. Puedes usar las respuestas de ejemplo o pulsar Ayuda.';
  static const sinConexion = 'No se puede conectar con TuTurno ahora mismo. Mira si tienes internet y prueba otra vez.';
  static const sinPermiso =
      'Para conectar con TuTurno, el móvil pide permiso para usar el micrófono. '
      'Puedes darlo en los ajustes del móvil y probar otra vez.';
  static const microAbierto =
      'Se ha cerrado la conversación porque no se podía apagar el micrófono de la llamada. Prueba otra vez.';
  static const cortado = 'Se ha cortado la conexión con TuTurno.';
  static const noEnviado = 'Tu mensaje no ha llegado a TuTurno. Prueba a enviarlo otra vez.';
  static const sinSesion = 'Ahora no hay conexión con TuTurno.';
}

/// [AgenteVoz] con ElevenLabs Agents.
///
/// - [agentId]: agente público; el SDK pide el token a ElevenLabs (lo que hay ahora, sección 8.5).
/// - [pedirToken]: agente privado; devuelve el token de `GET /api/session/token` del backend. Si se da, manda él.
/// - [herramientas]: client tools de la fase 2 (sección 8.8), con el nombre exacto que tienen en el agente.
/// - [enviarVariablesAlLlm]: manda también las variables en `customLlmExtraBody` (llegan al Custom LLM como
///   `elevenlabs_extra_body`). Por defecto no: el backend saca el perfil del prompt y no lo usa.
///
/// Por [mensajes] solo llega lo que dice el agente (`deAgente: true`), también las correcciones. Lo que se envía con
/// [enviarTexto] no vuelve como eco: lo pinta quien lo envía.
///
/// Si se llama a [terminar] o a [dispose] mientras [iniciar] está conectando, [iniciar] acaba sin error y el estado
/// queda en [EstadoAgente.desconectado].
class ElevenLabsAgenteVoz implements AgenteVoz {
  ElevenLabsAgenteVoz({
    String? agentId,
    this.pedirToken,
    Map<String, ClientTool>? herramientas,
    this.enviarVariablesAlLlm = false,
    @visibleForTesting CrearClienteAgente? crearCliente,
    @visibleForTesting DateTime Function()? reloj,
  }) : _agentId = agentId?.trim() ?? '',
       _crearCliente =
           crearCliente ?? ((callbacks) => ConversationClient(callbacks: callbacks, clientTools: herramientas)),
       _reloj = reloj ?? DateTime.now;

  /// Las variables del prompt del agente (sección 8.6). Van siempre las cuatro; la que no se sabe va vacía, y el
  /// backend la trata como «sin dato» (backend/app/agent/perfil.py). ElevenLabs acepta los valores vacíos
  /// (comprobado el 22-10 con una sesión real).
  static const variablesDelPrompt = ['edad', 'procedimiento', 'rol', 'fase'];

  /// Cada cuánto, como mucho, se manda user_activity mientras el usuario escribe o dicta.
  static const _intervaloActividad = Duration(seconds: 1);

  final String _agentId;

  /// Agente privado: el token de la sesión (`GET /api/session/token`). Si no es null, se usa en vez del agentId.
  final Future<String> Function()? pedirToken;

  /// Si las variables van también en `customLlmExtraBody`.
  final bool enviarVariablesAlLlm;
  final CrearClienteAgente _crearCliente;
  final DateTime Function() _reloj;

  final _estado = ValueNotifier(EstadoAgente.desconectado);
  final _hablando = ValueNotifier(false);
  final _mensajes = StreamController<MensajeAgente>.broadcast();
  final _errores = StreamController<String>.broadcast();

  /// La sesión viva o la que está conectando. Lo que llegue de otra se ignora.
  _Sesion? _sesion;
  Future<void>? _iniciando;
  DateTime? _ultimaActividad;
  var _cerrado = false;

  @override
  ValueListenable<EstadoAgente> get estado => _estado;

  @override
  ValueListenable<bool> get hablando => _hablando;

  @override
  Stream<MensajeAgente> get mensajes => _mensajes.stream;

  @override
  Stream<String> get errores => _errores.stream;

  /// Las cuatro variables, sin espacios de más. La que falte va vacía.
  static Map<String, String> completarVariables(Map<String, String> variables) => {
    for (final clave in variablesDelPrompt) clave: '',
    for (final MapEntry(:key, :value) in variables.entries) key: value.trim(),
  };

  @override
  Future<void> iniciar({required Map<String, String> variables}) {
    if (_cerrado) return Future.error(StateError('ElevenLabsAgenteVoz ya está cerrado'));
    final enCurso = _iniciando;
    if (enCurso != null) return enCurso;
    if (_estado.value == EstadoAgente.conectado) return Future.value();
    final futuro = _conectar(completarVariables(variables));
    _iniciando = futuro;
    return futuro.whenComplete(() {
      if (identical(_iniciando, futuro)) _iniciando = null;
    });
  }

  Future<void> _conectar(Map<String, String> variables) async {
    final sesion = _Sesion();
    _sesion = sesion;
    _ponerEstado(EstadoAgente.conectando);
    _ponerHablando(false);
    try {
      String? token;
      final pedirToken = this.pedirToken;
      if (pedirToken != null) {
        token = (await pedirToken()).trim();
        if (token.isEmpty) throw const ErrorAgente(TextosAgente.sinConexion);
      } else if (_agentId.isEmpty) {
        throw const ErrorAgente(TextosAgente.sinConfigurar);
      }
      // Se comprueba antes de crear el cliente: si se terminó mientras llegaba el token, no se abre nada.
      if (!_esLaActual(sesion)) return;

      final cliente = sesion.cliente = _crearCliente(_callbacks(sesion));
      final arranque = sesion.arranque = cliente.startSession(
        agentId: token == null ? _agentId : null,
        conversationToken: token,
        dynamicVariables: variables,
        customLlmExtraBody: enviarVariablesAlLlm ? variables : null,
      );
      await arranque;
      if (!_esLaActual(sesion)) return;
      // El SDK acaba de publicar el micrófono: se silencia antes de dar la sesión por abierta.
      await _silenciar(cliente);
      if (!_esLaActual(sesion)) return;
      if (sesion.cortada) throw const ErrorAgente(TextosAgente.sinConexion);
      _ponerEstado(EstadoAgente.conectado);
    } catch (error) {
      final eraLaActual = _esLaActual(sesion);
      _soltar(sesion);
      if (!eraLaActual) return;
      if (error is ErrorAgente) rethrow;
      throw ErrorAgente(mensajeDeConexion(error), causa: error);
    }
  }

  ConversationCallbacks _callbacks(_Sesion sesion) => ConversationCallbacks(
    onModeChange: ({required mode}) {
      if (_esLaActual(sesion)) _ponerHablando(mode == ConversationMode.speaking);
    },
    onMessage: ({required message, required source}) {
      if (!_esLaActual(sesion)) return;
      if (source == Role.ai) {
        final texto = message.trim();
        if (texto.isNotEmpty) _emitir(MensajeAgente(texto: texto, deAgente: true));
      } else {
        _vigilarMicro(sesion);
      }
    },
    onAgentResponseCorrection: (json) {
      if (!_esLaActual(sesion)) return;
      final evento = json['agent_response_correction_event'];
      if (evento is! Map) return;
      final original = evento['original_agent_response'];
      final corregido = evento['corrected_agent_response'];
      if (original is! String || original.trim().isEmpty) return;
      _emitir(
        MensajeAgente(texto: corregido is String ? corregido.trim() : '', deAgente: true, corrigeA: original.trim()),
      );
    },
    // Con el micrófono silenciado no debería llegar ninguna transcripción del usuario.
    onTentativeUserTranscript: ({required transcript, required eventId}) => _vigilarMicro(sesion),
    onUserTranscript: ({required transcript, required eventId}) => _vigilarMicro(sesion),
    onDisconnect: (detalles) {
      if (!_esLaActual(sesion)) return;
      if (_estado.value != EstadoAgente.conectado) {
        // Aún conectando: el fallo lo cuenta iniciar() con su excepción.
        sesion.cortada = true;
        return;
      }
      // 'agent': el agente ha terminado (end_call o duración máxima). 'error': se ha cortado.
      if (detalles.reason == 'error') _avisar(TextosAgente.cortado);
      _soltar(sesion);
    },
    onError: (mensaje, [contexto]) {
      if (!_esLaActual(sesion)) return;
      _registrar(mensaje, contexto);
      if (mensaje == 'Failed to send message') _avisar(TextosAgente.noEnviado);
    },
    onUnhandledClientToolCall: (llamada) => _registrar('Client tool sin implementar: ${llamada.toolName}', null),
  );

  @override
  void enviarTexto(String texto) {
    final limpio = texto.trim();
    if (limpio.isEmpty || _cerrado) return;
    final sesion = _sesion;
    final cliente = sesion?.cliente;
    if (sesion == null || cliente == null || _estado.value != EstadoAgente.conectado) {
      _avisar(TextosAgente.sinSesion);
      return;
    }
    try {
      cliente.sendUserMessage(limpio);
    } catch (_) {
      _avisar(TextosAgente.noEnviado);
      return;
    }
    _vigilarMicro(sesion);
  }

  @override
  void avisarQueEscribe() {
    final sesion = _sesion;
    final cliente = sesion?.cliente;
    if (sesion == null || cliente == null || _estado.value != EstadoAgente.conectado) return;
    final ahora = _reloj();
    final ultima = _ultimaActividad;
    if (ultima != null && ahora.difference(ultima) < _intervaloActividad) return;
    _ultimaActividad = ahora;
    try {
      cliente.sendUserActivity();
    } catch (_) {
      // Solo es un aviso: si no llega, no pasa nada.
    }
  }

  @override
  Future<void> terminar() async {
    // Un iniciar() posterior abre otra sesión aunque el startSession() anterior aún no haya vuelto.
    _iniciando = null;
    final sesion = _sesion;
    if (sesion == null) return;
    _soltar(sesion);
    await sesion.liberar();
  }

  @override
  void dispose() {
    if (_cerrado) return;
    final sesion = _sesion;
    _sesion = null;
    _cerrado = true;
    if (sesion != null) unawaited(sesion.liberar());
    _estado.dispose();
    _hablando.dispose();
    unawaited(_mensajes.close());
    unawaited(_errores.close());
  }

  /// Silencia el micrófono de la sesión y comprueba que lo está. setMicMuted() no lanza: sus fallos van a onError.
  Future<void> _silenciar(ConversationClient cliente) async {
    for (var intento = 0; intento < 3; intento++) {
      await cliente.setMicMuted(true);
      if (cliente.isMuted) return;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    throw const ErrorAgente(TextosAgente.microAbierto);
  }

  /// Si el micrófono de la sesión no está silenciado, lo silencia; si no puede, cierra la sesión.
  void _vigilarMicro(_Sesion sesion) {
    final cliente = sesion.cliente;
    if (cliente == null || cliente.isMuted || sesion.silenciando) return;
    sesion.silenciando = true;
    _silenciar(cliente)
        .then(
          (_) {},
          onError: (Object _) {
            if (!_esLaActual(sesion)) return;
            _avisar(TextosAgente.microAbierto);
            _soltar(sesion);
          },
        )
        .whenComplete(() => sesion.silenciando = false);
  }

  /// Deja una sesión. Si es la actual, el estado pasa a desconectado. El cliente se libera después, fuera del
  /// callback del SDK desde el que se haya llamado.
  void _soltar(_Sesion sesion) {
    if (identical(_sesion, sesion)) {
      _sesion = null;
      _ponerEstado(EstadoAgente.desconectado);
      _ponerHablando(false);
    }
    unawaited(Future<void>(sesion.liberar));
  }

  bool _esLaActual(_Sesion sesion) => !_cerrado && identical(_sesion, sesion);

  void _ponerEstado(EstadoAgente valor) {
    if (!_cerrado) _estado.value = valor;
  }

  void _ponerHablando(bool valor) {
    if (!_cerrado) _hablando.value = valor;
  }

  void _emitir(MensajeAgente mensaje) {
    if (!_cerrado) _mensajes.add(mensaje);
  }

  void _avisar(String texto) {
    if (!_cerrado) _errores.add(texto);
  }

  /// Solo en depuración y sin texto de la conversación: el SDK manda aquí frases fijas y excepciones.
  static void _registrar(String mensaje, Object? contexto) {
    if (kDebugMode) debugPrint('ElevenLabsAgenteVoz: $mensaje (${contexto?.runtimeType})');
  }

  /// El texto que se enseña cuando no se puede abrir la sesión.
  @visibleForTesting
  static String mensajeDeConexion(Object error) {
    final texto = error.toString().toLowerCase();
    // TokenService del SDK: «Failed to fetch token (404): …». Un 4xx suele ser un agent_id mal puesto o un agente
    // privado (que necesita el token del backend). Va antes que el permiso: el cuerpo puede decir «permission».
    if (texto.contains('failed to fetch token (4')) return TextosAgente.sinConfigurar;
    if (texto.contains('failed to fetch token')) return TextosAgente.sinConexion;
    // En Android (flutter_webrtc) y en web, el permiso de micrófono denegado llega como NotAllowedError.
    if (texto.contains('notallowed') || texto.contains('permission')) return TextosAgente.sinPermiso;
    return TextosAgente.sinConexion;
  }
}

/// Una sesión: su cliente del SDK y lo necesario para liberarlo una sola vez.
class _Sesion {
  ConversationClient? cliente;

  /// El startSession() en curso o terminado.
  Future<void>? arranque;

  /// El SDK avisó de una desconexión mientras se conectaba.
  var cortada = false;
  var silenciando = false;
  Future<void>? _liberando;

  Future<void> liberar() => _liberando ??= _liberar();

  Future<void> _liberar() async {
    final cliente = this.cliente;
    if (cliente == null) return;
    // endSession() corta la sala si ya existe. Si startSession() sigue en marcha, se espera a que acabe y se repite,
    // por si llegó a conectar después: dispose() sin esperar podría dejar una sala abierta o avisar a un cliente ya
    // liberado.
    await _sinErrores(cliente.endSession(), const Duration(seconds: 5));
    await _sinErrores(arranque, const Duration(seconds: 20));
    await _sinErrores(cliente.endSession(), const Duration(seconds: 5));
    try {
      cliente.dispose();
    } catch (_) {
      // Ya liberado.
    }
  }

  static Future<void> _sinErrores(Future<void>? futuro, Duration limite) async {
    if (futuro == null) return;
    try {
      await futuro.timeout(limite);
    } catch (_) {
      // Lo que falle al cerrar no le importa al usuario.
    }
  }
}
