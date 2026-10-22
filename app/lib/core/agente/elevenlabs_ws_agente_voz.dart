import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'agente_voz.dart';
import 'conexion_ws.dart';
import 'reproductor_pcm.dart';
import 'respuesta_agente.dart' show esSaludoAgente;
import 'url_firmada.dart';

// Pregunta, fase 1 (docs/ARQUITECTURA.md, secciones 5.0 y 8.5 a 8.7) sin SDK: la API WebSocket de ElevenLabs Agents
// (wss://api.elevenlabs.io/v1/convai/conversation), comprobada en su documentación (esquema AsyncAPI y «client
// events») y en el SDK oficial de JavaScript (@elevenlabs/client). Sin LiveKit ni WebRTC: no hay modo llamada, ni
// pista de micrófono que volver a publicar, ni nada que pida el micrófono. La voz del menor se transcribe en el móvil
// (speech_to_text) y llega como texto; nunca se manda audio. ElevenLabs solo pone la voz del agente.
//
// - La app manda conversation_initiation_client_data (dynamic_variables), user_message, user_activity y pong. Si el
//   agente llamara a una client tool (fase 2, sección 8.8, aún sin hacer), contesta con un error para que no espere.
// - Llega conversation_initiation_metadata (el formato del audio: pcm_16000 si no se ha cambiado), agent_response
//   (el texto completo del turno, antes que casi todo su audio), agent_response_correction (lo que llegó a decir si se
//   le interrumpe), interruption, audio (PCM en base64 con su event_id) y ping. agent_chat_response_part (el texto
//   en streaming) solo llega si se activa en los client_events del agente; aquí solo sirve para medir.
// - ping: pong enseguida con el mismo event_id, como hace el SDK. ping_ms (opcional) es la latencia que estima
//   ElevenLabs: solo se registra.
// - El audio suena en streaming según llega (reproductor_pcm.dart), como multimedia. Al empezar se junta un colchón
//   pequeño si el primer trozo es muy corto. Al llegar interruption, al enviar otra pregunta y al cerrar, se para en
//   el acto y se descarta lo que llegue tarde de la respuesta cortada (event_id ya sonado o anterior al de la
//   interrupción, como en el SDK). hablando es true mientras suena.
// - Si la conexión se cae sin querer (red, error del servidor), se reconecta sola con espera creciente. Si se corta
//   con una pregunta sin responder, el estado pasa a desconectado enseguida para que Pregunta enseñe el error. Una
//   sesión que se abre sola no saluda (sería raro oír «Hola» de repente): el saludo se guarda y se da como texto si
//   Pregunta pide la sesión. Si ElevenLabs cierra la conversación de forma normal (fin de la llamada o duración
//   máxima), no se reconecta sola: se abre otra al preguntar, y así una sesión olvidada no gasta minutos.
// - Si el Custom LLM (el backend de B) no responde, ElevenLabs no avisa: el tiempo de espera lo pone Pregunta
//   (features/pregunta/agente/chat_agente.dart).
// - Medidas: líneas «TUTURNO_LAT …» con debugPrint (adb logcat), sin nada de lo que escribe el usuario ni la URL.

/// [AgenteVoz] con ElevenLabs Agents por WebSocket.
///
/// - [urlFirmada]: si hay API_URL, la URL firmada del backend (`GET /api/session/signed-url`). Manda ella; si no se
///   consigue y hay [agentId], se conecta con el agent_id.
/// - [agentId]: agente público (lo que hay ahora, sección 8.5).
/// - [enviarVariablesAlLlm]: manda también las variables en `custom_llm_extra_body` (llegan al Custom LLM como
///   `elevenlabs_extra_body`). Por defecto no: el backend saca el perfil del prompt y no lo usa.
///
/// Por [mensajes] solo llega lo que dice el agente (`deAgente: true`), también las correcciones. Lo que se envía con
/// [enviarTexto] no vuelve como eco: lo pinta quien lo envía. Si se llama a [terminar] o a [dispose] mientras
/// [iniciar] está conectando, [iniciar] acaba sin error y el estado queda en [EstadoAgente.desconectado].
class ElevenLabsWsAgenteVoz implements AgenteVoz {
  ElevenLabsWsAgenteVoz({
    String? agentId,
    this.urlFirmada,
    ReproductorPcm? reproductor,
    this.enviarVariablesAlLlm = false,
    @visibleForTesting AbrirConexionWs? abrirConexion,
    @visibleForTesting Duration Function()? reloj,
    @visibleForTesting void Function(String linea)? registrar,
  }) : _agentId = agentId?.trim() ?? '',
       _reproductor = reproductor ?? ReproductorAudioStream(),
       _abrirConexion = abrirConexion ?? ((uri) => abrirConexionWs(uri, limite: limiteConexion)),
       _reloj = reloj ?? _relojMonotono(),
       _registrar = registrar ?? ((linea) => debugPrint(linea));

  static const endpoint = 'wss://api.elevenlabs.io/v1/convai/conversation';

  /// Las variables del prompt del agente (sección 8.6). Van siempre las cuatro; la que no se sabe va vacía, y el
  /// backend la trata como «sin dato» (backend/app/agent/perfil.py). ElevenLabs acepta los valores vacíos.
  static const variablesDelPrompt = ['edad', 'procedimiento', 'rol', 'fase'];

  /// Lo que se espera a la URL firmada si hay agent_id de reserva, y si no lo hay.
  static const limiteUrlFirmada = Duration(seconds: 4);
  static const limiteUrlFirmadaSinReserva = Duration(seconds: 8);

  /// Lo que se espera a que se abra el WebSocket y, después, a conversation_initiation_metadata.
  static const limiteConexion = Duration(seconds: 6);
  static const limiteInicio = Duration(seconds: 6);

  /// Esperas entre reconexiones automáticas. Después de la última, se deja desconectado.
  static const esperasReconexion = [
    Duration(milliseconds: 300),
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
  ];

  /// Sesiones abiertas solas seguidas sin que el usuario pregunte nada: después ya no se reconecta sola.
  static const maxReconexionesSinActividad = 3;

  /// Colchón al empezar a sonar: si el primer trozo dura menos, se espera un poco a que llegue más.
  static const colchon = Duration(milliseconds: 100);
  static const esperaColchon = Duration(milliseconds: 60);

  /// Lo que se espera después del final previsto antes de dar el audio por terminado (por si llega otro trozo). Si el
  /// último trozo viene marcado como final (is_final), menos.
  static const margenFin = Duration(milliseconds: 400);
  static const margenFinFinal = Duration(milliseconds: 120);

  /// Lo que puede quedar en el reproductor y darse ya por terminado.
  static const _restoInaudible = Duration(milliseconds: 40);

  /// Cada cuánto, como mucho, se manda user_activity mientras el usuario escribe o dicta.
  static const _intervaloActividad = Duration(seconds: 1);

  final String _agentId;
  final FuenteUrlFirmada? urlFirmada;
  final bool enviarVariablesAlLlm;
  final ReproductorPcm _reproductor;
  final AbrirConexionWs _abrirConexion;
  final Duration Function() _reloj;
  final void Function(String linea) _registrar;

  final _estado = ValueNotifier(EstadoAgente.desconectado);
  final _hablando = ValueNotifier(false);
  final _mensajes = StreamController<MensajeAgente>.broadcast();
  final _errores = StreamController<String>.broadcast();

  /// La sesión abierta o la que se está abriendo. Lo que llegue de otra se ignora.
  _Sesion? _sesion;
  Future<void>? _abriendo;
  Map<String, String> _variables = completarVariables(const {});
  Timer? _temporizadorReconexion;
  var _intentosReconexion = 0;
  var _reconexionesSinActividad = 0;
  Duration? _ultimaActividad;
  var _cerrado = false;

  /// Se ha enviado una pregunta y aún no ha llegado su respuesta.
  var _preguntaPendiente = false;
  _Medida? _medida;

  // Audio.
  var _formato = FormatoAudio.porDefecto;
  int? _frecuenciaPreparada;
  var _audioDisponible = true;
  final _colchon = <Uint8List>[];
  var _bytesColchon = 0;
  Timer? _temporizadorColchon;
  Timer? _temporizadorFin;

  /// Suena (o va a sonar) audio entregado al reproductor.
  var _sonando = false;

  /// Hay audio en el reproductor que habría que parar.
  var _audioEnReproductor = false;
  var _ultimoTrozoFinal = false;

  /// Cuándo acabará de sonar lo entregado, según el reloj de [_reloj].
  var _finPrevisto = Duration.zero;

  /// Sube con cada entrega y cada parada: una comprobación del final que llegue tarde se ignora.
  var _entregas = 0;

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

  static Duration Function() _relojMonotono() {
    final cronometro = Stopwatch()..start();
    return () => cronometro.elapsed;
  }

  // ---------------------------------------------------------------------------------------------------------------
  // Sesión.

  @override
  Future<void> iniciar({required Map<String, String> variables}) {
    if (_cerrado) return Future.error(StateError('ElevenLabsWsAgenteVoz ya está cerrado'));
    final sesion = _sesion;
    final enCurso = _abriendo;
    if (sesion != null && sesion.abierta) {
      _pedir(sesion);
      return Future.value();
    }
    if (sesion != null && enCurso != null) {
      // Se está abriendo (quizá sola, tras un corte): Pregunta la pide y espera a la misma.
      _pedir(sesion);
      return enCurso;
    }
    _variables = completarVariables(variables);
    _cancelarReconexion();
    _intentosReconexion = 0;
    return _abrir(_nuevaSesion(silenciada: false));
  }

  _Sesion _nuevaSesion({required bool silenciada}) => _Sesion(silenciada: silenciada, inicio: _reloj());

  Future<void> _abrir(_Sesion sesion) {
    _sesion = sesion;
    final futuro = _conectar(sesion);
    _abriendo = futuro;
    return futuro.whenComplete(() {
      if (identical(_abriendo, futuro)) _abriendo = null;
    });
  }

  Future<void> _conectar(_Sesion sesion) async {
    _ponerEstado(EstadoAgente.conectando);
    // El reproductor se prepara mientras conecta: así no retrasa el primer audio.
    _prepararReproductor(_formato.frecuencia);
    try {
      final uri = await _resolverUrl(sesion);
      if (!_esLaActual(sesion)) return;
      final conexion = await _abrirConexion(uri);
      if (!_esLaActual(sesion)) {
        unawaited(conexion.cerrar());
        return;
      }
      sesion.conexion = conexion;
      _registrarLatencia('ws_abierto', _reloj() - sesion.inicio);
      sesion.suscripcion = conexion.textos.listen(
        (texto) => _alTexto(sesion, texto),
        onError: (Object error) => _alCerrarse(sesion, error: error),
        onDone: () => _alCerrarse(sesion),
      );
      final inicio = {
        'type': 'conversation_initiation_client_data',
        'dynamic_variables': _variables,
        if (enviarVariablesAlLlm) 'custom_llm_extra_body': _variables,
      };
      if (!_enviar(sesion, inicio)) throw const ErrorConexionWs();
      await sesion.metadatos.future.timeout(
        limiteInicio,
        onTimeout: () => throw const ErrorConexionWs(tiempoAgotado: true),
      );
      if (!_esLaActual(sesion)) return;
      sesion.abierta = true;
      if (sesion.silenciada) _reconexionesSinActividad++;
      _ponerEstado(EstadoAgente.conectado);
      _registrarLatencia('conectado', _reloj() - sesion.inicio);
    } catch (error) {
      final eraLaActual = _esLaActual(sesion);
      // Una URL firmada con la que no se ha podido conectar no se reutiliza (puede haber caducado).
      if (sesion.firmada) urlFirmada?.olvidar();
      _soltar(sesion);
      if (!eraLaActual) return;
      _registrarFallo('conectar', error);
      if (!sesion.silenciada) _ponerEstado(EstadoAgente.desconectado);
      if (error is ErrorAgente) rethrow;
      // Con URL firmada, un rechazo suele ser la firma: al reintentar se pide otra.
      throw ErrorAgente(sesion.firmada ? TextosAgente.sinConexion : mensajeDeConexion(error), causa: error);
    }
  }

  /// La URL firmada (guardada o nueva) si hay backend; si no se consigue, o no hay backend, la del agent_id.
  Future<Uri> _resolverUrl(_Sesion sesion) async {
    final fuente = urlFirmada;
    if (fuente != null) {
      final guardada = fuente.guardada();
      if (guardada != null) {
        sesion.firmada = true;
        _registrar('TUTURNO_LAT url_firmada guardada');
        return guardada;
      }
      try {
        final nueva = await fuente.nueva(_agentId.isEmpty ? limiteUrlFirmadaSinReserva : limiteUrlFirmada);
        sesion.firmada = true;
        _registrarLatencia('url_firmada', _reloj() - sesion.inicio);
        return nueva;
      } catch (error) {
        _registrarFallo('url firmada', error);
        if (_agentId.isEmpty) throw ErrorAgente(TextosAgente.sinConexion, causa: error);
        // El backend está dormido o caído: se usa el agente público, con su agent_id.
      }
    } else if (_agentId.isEmpty) {
      throw const ErrorAgente(TextosAgente.sinConfigurar);
    }
    return Uri.parse(endpoint).replace(queryParameters: {'agent_id': _agentId});
  }

  /// Pregunta pide una sesión que se ha abierto sola: desde ahora habla, y el saludo que se guardó se da como texto.
  void _pedir(_Sesion sesion) {
    if (!sesion.silenciada) return;
    sesion.silenciada = false;
    // Lo que quede del saludo no suena: empezaría a medias.
    sesion.descartarHasta = math.max(sesion.descartarHasta, sesion.ultimoAudio);
    final saludo = sesion.saludoGuardado;
    sesion.saludoGuardado = null;
    if (saludo != null && !sesion.enviado) _emitir(MensajeAgente(texto: saludo, deAgente: true));
  }

  void _alCerrarse(_Sesion sesion, {Object? error}) {
    if (!_esLaActual(sesion)) return;
    final codigo = sesion.conexion?.codigoCierre;
    if (!sesion.abierta) {
      // Aún conectando: el fallo lo cuenta iniciar() con su excepción.
      sesion.fallarInicio(ErrorConexionWs(codigoCierre: codigo));
      return;
    }
    _registrar('TUTURNO_LAT corte motivo=${_motivoCorte(codigo, error)}${codigo == null ? '' : ' codigo=$codigo'}');
    final aMitad = _preguntaPendiente;
    _preguntaPendiente = false;
    _medida = null;
    _soltar(sesion);
    final reconectar = _seCayoSinQuerer(codigo, error) && _reconexionesSinActividad < maxReconexionesSinActividad;
    // Con una pregunta sin responder, Pregunta tiene que enseñar el error ya, aunque se vaya a reconectar.
    _ponerEstado(aMitad || !reconectar ? EstadoAgente.desconectado : EstadoAgente.conectando);
    if (reconectar) {
      _intentosReconexion = 0;
      _programarReconexion();
    }
  }

  /// Red caída, conexión muerta (sin pong: 1001) o error del servidor. Un cierre normal (1000: fin de la llamada o
  /// duración máxima) o un rechazo (1008) no se reintenta solo.
  static bool _seCayoSinQuerer(int? codigo, Object? error) =>
      error != null || codigo == null || const {1001, 1005, 1006, 1011, 1012, 1013, 1014}.contains(codigo);

  static String _motivoCorte(int? codigo, Object? error) {
    if (error != null || codigo == null || codigo == 1005 || codigo == 1006) return 'red';
    return switch (codigo) {
      1000 => 'fin_servidor',
      1001 => 'sin_respuesta',
      1008 => 'rechazo',
      1011 || 1012 || 1013 || 1014 => 'error_servidor',
      _ => 'otro',
    };
  }

  void _programarReconexion() {
    _temporizadorReconexion?.cancel();
    _temporizadorReconexion = null;
    if (_cerrado) return;
    if (_intentosReconexion >= esperasReconexion.length) {
      _ponerEstado(EstadoAgente.desconectado);
      return;
    }
    final espera = esperasReconexion[_intentosReconexion++];
    _temporizadorReconexion = Timer(espera, () {
      _temporizadorReconexion = null;
      if (_cerrado || _sesion != null || _abriendo != null) return;
      _registrar('TUTURNO_LAT reconexion intento=$_intentosReconexion');
      final sesion = _nuevaSesion(silenciada: true);
      _abrir(sesion).then(
        (_) {
          if (_esLaActual(sesion) && sesion.abierta) _intentosReconexion = 0;
        },
        onError: (Object _) {
          // Si Pregunta pidió esta sesión mientras se abría, el error ya le ha llegado con iniciar() y decide ella.
          if (!sesion.silenciada || _cerrado || _sesion != null || _abriendo != null) return;
          _programarReconexion();
        },
      );
    });
  }

  void _cancelarReconexion() {
    _temporizadorReconexion?.cancel();
    _temporizadorReconexion = null;
  }

  @override
  Future<void> terminar() async {
    _cancelarReconexion();
    _intentosReconexion = 0;
    _preguntaPendiente = false;
    _medida = null;
    // Un iniciar() posterior abre otra sesión aunque la anterior aún no haya terminado de conectar.
    _abriendo = null;
    // Al pasar a segundo plano o salir de Pregunta, el reproductor se para del todo, sonara algo o no.
    _pararAudio(forzar: true);
    final sesion = _sesion;
    if (sesion != null) _soltar(sesion);
    _ponerEstado(EstadoAgente.desconectado);
  }

  @override
  void dispose() {
    if (_cerrado) return;
    _cancelarReconexion();
    _temporizadorColchon?.cancel();
    _temporizadorFin?.cancel();
    _colchon.clear();
    final sesion = _sesion;
    _sesion = null;
    _abriendo = null;
    _cerrado = true;
    if (sesion != null) {
      sesion.cerrada = true;
      sesion.fallarInicio(const _Cancelada());
      unawaited(sesion.liberar());
    }
    unawaited(_reproductor.liberar().catchError((Object error) => _registrarFallo('liberar audio', error)));
    _estado.dispose();
    _hablando.dispose();
    unawaited(_mensajes.close());
    unawaited(_errores.close());
  }

  /// Deja una sesión: lo que llegue de ella se ignora y su conexión se cierra. Si es la actual, para el audio.
  void _soltar(_Sesion sesion) {
    if (identical(_sesion, sesion)) {
      _sesion = null;
      _pararAudio();
    }
    if (sesion.cerrada) return;
    sesion.cerrada = true;
    // Por si _conectar sigue esperando conversation_initiation_metadata.
    sesion.fallarInicio(const _Cancelada());
    unawaited(sesion.liberar());
  }

  bool _esLaActual(_Sesion sesion) => !_cerrado && !sesion.cerrada && identical(_sesion, sesion);

  // ---------------------------------------------------------------------------------------------------------------
  // Lo que manda la app.

  @override
  void enviarTexto(String texto) {
    final limpio = texto.trim();
    if (limpio.isEmpty || _cerrado) return;
    final sesion = _sesion;
    if (sesion == null || !sesion.abierta || _estado.value != EstadoAgente.conectado) {
      _avisar(TextosAgente.sinSesion);
      return;
    }
    // Lo que sonaba se calla ya, y lo que llegue tarde de esa respuesta se descarta.
    sesion.descartarHasta = math.max(sesion.descartarHasta, sesion.ultimoAudio);
    _pararAudio();
    sesion.silenciada = false;
    sesion.saludoGuardado = null;
    if (!_enviar(sesion, {'type': 'user_message', 'text': limpio})) {
      _avisar(TextosAgente.noEnviado);
      return;
    }
    sesion.enviado = true;
    _reconexionesSinActividad = 0;
    _preguntaPendiente = true;
    _medida = _Medida(_reloj());
    _registrar('TUTURNO_LAT envio');
  }

  @override
  void avisarQueEscribe() {
    final sesion = _sesion;
    if (_cerrado || sesion == null || !sesion.abierta) return;
    final ahora = _reloj();
    final ultima = _ultimaActividad;
    if (ultima != null && ahora - ultima < _intervaloActividad) return;
    _ultimaActividad = ahora;
    // Solo es un aviso: si no llega, no pasa nada.
    _enviar(sesion, const {'type': 'user_activity'});
  }

  bool _enviar(_Sesion sesion, Map<String, Object?> mensaje) {
    final conexion = sesion.conexion;
    if (conexion == null || sesion.cerrada) return false;
    try {
      conexion.enviar(jsonEncode(mensaje));
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------------------------------------------
  // Lo que llega.

  void _alTexto(_Sesion sesion, String texto) {
    if (!_esLaActual(sesion)) return;
    final Object? json;
    try {
      json = jsonDecode(texto);
    } on FormatException {
      return;
    }
    if (json is! Map) return;
    switch (json['type']) {
      case 'conversation_initiation_metadata':
        _alIniciarConversacion(sesion, json['conversation_initiation_metadata_event']);
      case 'ping':
        _alPing(sesion, json['ping_event']);
      case 'audio':
        _alAudio(sesion, json['audio_event']);
      case 'agent_response':
        _alRespuesta(sesion, json['agent_response_event']);
      case 'agent_chat_response_part':
        _alTrozoDeTexto(sesion, json['text_response_part']);
      case 'agent_response_correction':
        _alCorreccion(sesion, json['agent_response_correction_event']);
      case 'interruption':
        _alInterrumpir(sesion, json['interruption_event']);
      case 'client_tool_call':
        _alHerramienta(sesion, json['client_tool_call']);
      default:
        // user_transcript (no se manda audio), vad_score, agent_response_metadata…: no hacen falta.
        break;
    }
  }

  void _alIniciarConversacion(_Sesion sesion, Object? evento) {
    final formato = evento is Map ? evento['agent_output_audio_format'] : null;
    _formato = FormatoAudio.desde(formato is String ? formato : null);
    _registrar('TUTURNO_LAT audio $_formato');
    _prepararReproductor(_formato.frecuencia);
    if (!sesion.metadatos.isCompleted) sesion.metadatos.complete();
  }

  void _alPing(_Sesion sesion, Object? evento) {
    if (evento is! Map) return;
    _enviar(sesion, {'type': 'pong', 'event_id': evento['event_id']});
    final ms = evento['ping_ms'];
    if (ms is num && !sesion.pingRegistrado) {
      sesion.pingRegistrado = true;
      _registrar('TUTURNO_LAT ping +${ms.round()} ms');
    }
  }

  void _alRespuesta(_Sesion sesion, Object? evento) {
    final texto = evento is Map ? evento['agent_response'] : null;
    if (texto is! String) return;
    final limpio = texto.trim();
    if (sesion.silenciada && !sesion.enviado) {
      // Sesión abierta sola: el saludo se guarda por si Pregunta la pide; lo demás se descarta.
      if (limpio.isNotEmpty) sesion.saludoGuardado ??= limpio;
      return;
    }
    _marcarTexto();
    if (!esSaludoAgente(limpio)) _preguntaPendiente = false;
    if (limpio.isNotEmpty) _emitir(MensajeAgente(texto: limpio, deAgente: true));
  }

  void _alTrozoDeTexto(_Sesion sesion, Object? parte) {
    if (parte is! Map || (sesion.silenciada && !sesion.enviado)) return;
    final texto = parte['text'];
    if (texto is String && texto.trim().isNotEmpty) _marcarTexto();
  }

  void _alCorreccion(_Sesion sesion, Object? evento) {
    if (evento is! Map || (sesion.silenciada && !sesion.enviado)) return;
    final original = evento['original_agent_response'];
    final corregido = evento['corrected_agent_response'];
    if (original is! String || original.trim().isEmpty) return;
    _emitir(
      MensajeAgente(texto: corregido is String ? corregido.trim() : '', deAgente: true, corrigeA: original.trim()),
    );
  }

  void _alInterrumpir(_Sesion sesion, Object? evento) {
    final id = evento is Map ? evento['event_id'] : null;
    if (id is num) sesion.interrupcion = math.max(sesion.interrupcion, id.toInt());
    sesion.descartarHasta = math.max(sesion.descartarHasta, sesion.ultimoAudio);
    _pararAudio();
  }

  void _alHerramienta(_Sesion sesion, Object? llamada) {
    if (llamada is! Map) return;
    final nombre = llamada['tool_name'];
    if (kDebugMode) _registrar('ElevenLabsWsAgenteVoz: client tool sin implementar: $nombre');
    final id = llamada['tool_call_id'];
    if (id is! String || llamada['expects_response'] == false) return;
    _enviar(sesion, {
      'type': 'client_tool_result',
      'tool_call_id': id,
      'result': 'Esta herramienta no está en la app.',
      'is_error': true,
    });
  }

  void _alAudio(_Sesion sesion, Object? evento) {
    if (evento is! Map) return;
    final base64 = evento['audio_base_64'];
    if (base64 is! String || base64.isEmpty) return;
    // Sesión abierta sola y sin preguntas: no suena nada.
    if (sesion.silenciada && !sesion.enviado) {
      final id = evento['event_id'];
      if (id is num) sesion.ultimoAudio = math.max(sesion.ultimoAudio, id.toInt());
      return;
    }
    final id = evento['event_id'];
    if (id is num) {
      final n = id.toInt();
      if (n <= sesion.descartarHasta || n < sesion.interrupcion) return;
      sesion.ultimoAudio = math.max(sesion.ultimoAudio, n);
    }
    Uint8List pcm;
    try {
      pcm = base64Decode(base64);
    } on FormatException {
      return;
    }
    if (_formato.ulaw) pcm = ulawAPcm16(pcm);
    _marcarAudio();
    _ultimoTrozoFinal = evento['is_final'] == true;
    _encolarAudio(pcm);
  }

  // ---------------------------------------------------------------------------------------------------------------
  // Audio.

  void _prepararReproductor(int frecuencia) {
    if (_cerrado || _frecuenciaPreparada == frecuencia) return;
    _frecuenciaPreparada = frecuencia;
    _audioDisponible = true;
    _reproductor
        .preparar(frecuencia)
        .then(
          (_) {},
          onError: (Object error) {
            // Sin voz, la respuesta se sigue leyendo en pantalla. Se vuelve a probar en la próxima sesión.
            if (_frecuenciaPreparada == frecuencia) {
              _audioDisponible = false;
              _frecuenciaPreparada = null;
            }
            _registrarFallo('preparar audio', error);
          },
        );
  }

  void _encolarAudio(Uint8List pcm) {
    if (!_audioDisponible || pcm.isEmpty) return;
    if (_sonando) {
      _entregar(pcm);
      return;
    }
    // Empieza a sonar con el primer trozo; si es muy corto, se junta un colchón pequeño para que no se corte.
    _colchon.add(pcm);
    _bytesColchon += pcm.length;
    if (_formato.duracion(_bytesColchon) >= colchon) {
      _vaciarColchon();
    } else {
      _temporizadorColchon ??= Timer(esperaColchon, _vaciarColchon);
    }
  }

  void _vaciarColchon() {
    _temporizadorColchon?.cancel();
    _temporizadorColchon = null;
    if (_colchon.isEmpty) return;
    final juntos = BytesBuilder(copy: false);
    _colchon.forEach(juntos.add);
    _colchon.clear();
    _bytesColchon = 0;
    _entregar(juntos.takeBytes());
  }

  void _entregar(Uint8List pcm) {
    final ahora = _reloj();
    _finPrevisto = (_finPrevisto > ahora ? _finPrevisto : ahora) + _formato.duracion(pcm.length);
    _entregas++;
    _audioEnReproductor = true;
    final empieza = !_sonando;
    _sonando = true;
    _ponerHablando(true);
    final medida = empieza ? _medida : null;
    _reproductor.anadir(pcm).then((_) {
      if (medida == null || medida.suena || !identical(_medida, medida)) return;
      medida.suena = true;
      _registrarLatencia('suena', _reloj() - medida.inicio);
    }, onError: (Object error) => _registrarFallo('reproducir', error));
    _programarFin();
  }

  void _programarFin() {
    _temporizadorFin?.cancel();
    final espera = _finPrevisto - _reloj() + (_ultimoTrozoFinal ? margenFinFinal : margenFin);
    _temporizadorFin = Timer(espera.isNegative ? Duration.zero : espera, () => unawaited(_comprobarFin()));
  }

  /// Al final previsto se pregunta al reproductor lo que queda (puede ir algo por detrás del reloj).
  Future<void> _comprobarFin() async {
    _temporizadorFin = null;
    final entregas = _entregas;
    var queda = Duration.zero;
    try {
      queda = await _reproductor.pendiente();
    } catch (_) {
      // Sin dato, vale el reloj.
    }
    if (_cerrado || !_sonando || entregas != _entregas) return;
    if (queda > _restoInaudible) {
      _finPrevisto = _reloj() + queda;
      _programarFin();
      return;
    }
    _sonando = false;
    // Ya no suena nada: no hace falta parar el reproductor.
    _audioEnReproductor = false;
    _ponerHablando(false);
  }

  /// Para en el acto lo que suena y vacía el colchón. Con [forzar], para el reproductor aunque ya no sonara nada.
  void _pararAudio({bool forzar = false}) {
    _temporizadorColchon?.cancel();
    _temporizadorColchon = null;
    _colchon.clear();
    _bytesColchon = 0;
    _temporizadorFin?.cancel();
    _temporizadorFin = null;
    _sonando = false;
    _ultimoTrozoFinal = false;
    _finPrevisto = Duration.zero;
    _entregas++;
    _ponerHablando(false);
    if (!_audioEnReproductor && !forzar) return;
    _audioEnReproductor = false;
    unawaited(_reproductor.parar().catchError((Object error) => _registrarFallo('parar audio', error)));
  }

  // ---------------------------------------------------------------------------------------------------------------
  // Medidas y avisos.

  void _marcarTexto() {
    final medida = _medida;
    if (medida == null || medida.texto) return;
    medida.texto = true;
    _registrarLatencia('primer_texto', _reloj() - medida.inicio);
  }

  void _marcarAudio() {
    final medida = _medida;
    if (medida == null || medida.audio) return;
    medida.audio = true;
    _registrarLatencia('primer_audio', _reloj() - medida.inicio);
  }

  void _registrarLatencia(String paso, Duration tiempo) => _registrar('TUTURNO_LAT $paso +${tiempo.inMilliseconds} ms');

  /// Solo en depuración y sin la URL ni texto de la conversación: el tipo del error y, si son nuestros, sus códigos.
  void _registrarFallo(String paso, Object error) {
    if (!kDebugMode) return;
    final detalle = error is ErrorConexionWs || error is ErrorUrlFirmada || error is ErrorAgente
        ? '$error'
        : '${error.runtimeType}';
    _registrar('ElevenLabsWsAgenteVoz: $paso: $detalle');
  }

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

  /// El texto que se enseña cuando no se puede abrir la sesión con el agent_id.
  @visibleForTesting
  static String mensajeDeConexion(Object error) {
    if (error is ErrorAgente) return error.mensaje;
    if (error is ErrorConexionWs) {
      // El agent_id no existe o el agente es privado (necesita la URL firmada del backend).
      if (const {401, 403, 404}.contains(error.codigoHttp) || error.codigoCierre == 1008) {
        return TextosAgente.sinConfigurar;
      }
    }
    return TextosAgente.sinConexion;
  }
}

/// Una sesión: su conexión y lo que se sabe de ella.
class _Sesion {
  _Sesion({required this.silenciada, required this.inicio}) {
    // Si nadie la espera ya, que su error no salga como no capturado.
    metadatos.future.ignore();
  }

  /// Cuándo se pidió, para medir.
  final Duration inicio;

  /// Se ha abierto sola (reconexión) y Pregunta aún no la ha pedido: no suena ni se emite nada.
  bool silenciada;
  ConexionWs? conexion;
  StreamSubscription<String>? suscripcion;
  final metadatos = Completer<void>();
  var abierta = false;
  var cerrada = false;
  var firmada = false;
  var enviado = false;
  String? saludoGuardado;
  var pingRegistrado = false;

  /// Trozos de audio con event_id hasta este, o menor que [interrupcion], ya no suenan.
  var descartarHasta = -1;
  var interrupcion = -1;
  var ultimoAudio = -1;
  var _liberada = false;

  void fallarInicio(Object error) {
    if (!metadatos.isCompleted) metadatos.completeError(error);
  }

  Future<void> liberar() async {
    if (_liberada) return;
    _liberada = true;
    try {
      await suscripcion?.cancel().timeout(const Duration(seconds: 2));
    } catch (_) {
      // Lo que falle al cerrar no le importa al usuario.
    }
    try {
      await conexion?.cerrar();
    } catch (_) {
      // Ya cerrada.
    }
  }
}

/// La sesión se ha dejado mientras se abría.
class _Cancelada implements Exception {
  const _Cancelada();
}

/// Tiempos de una pregunta, desde que se envía.
class _Medida {
  _Medida(this.inicio);

  final Duration inicio;
  var texto = false;
  var audio = false;
  var suena = false;
}
