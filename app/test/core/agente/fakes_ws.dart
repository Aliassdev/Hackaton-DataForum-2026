import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:tuturno/core/agente/conexion_ws.dart';
import 'package:tuturno/core/agente/reproductor_pcm.dart';

// Un WebSocket y un reproductor falsos para los tests del agente de voz: sin red y sin audio.

/// Conexión falsa: el test decide lo que llega del servidor y cómo se cierra.
class ConexionFalsa implements ConexionWs {
  ConexionFalsa({this.formato = 'pcm_16000', this.responderInicio = true});

  /// agent_output_audio_format de los metadatos.
  final String formato;

  /// Contesta a conversation_initiation_client_data con conversation_initiation_metadata, como ElevenLabs.
  final bool responderInicio;

  final _textos = StreamController<String>();

  /// Lo que ha mandado la app, ya decodificado.
  final enviados = <Map<String, dynamic>>[];
  int? _codigo;
  var cerrada = false;
  var cerradaPorLaApp = false;
  var fallarAlEnviar = false;

  @override
  Stream<String> get textos => _textos.stream;

  @override
  int? get codigoCierre => _codigo;

  @override
  void enviar(String texto) {
    if (cerrada || fallarAlEnviar) throw StateError('La conexión está cerrada');
    final json = jsonDecode(texto) as Map<String, dynamic>;
    enviados.add(json);
    if (responderInicio && json['type'] == 'conversation_initiation_client_data') {
      scheduleMicrotask(llegaMetadatos);
    }
  }

  @override
  Future<void> cerrar() async {
    cerrada = true;
    cerradaPorLaApp = true;
  }

  /// Los tipos de lo que ha mandado la app, en orden.
  List<String> get tipos => [for (final m in enviados) m['type'] as String? ?? '(sin tipo)'];

  List<Map<String, dynamic>> deTipo(String tipo) => [
    for (final m in enviados)
      if (m['type'] == tipo) m,
  ];

  void llega(Map<String, Object?> json) => _textos.add(jsonEncode(json));

  void llegaTextoCrudo(String texto) => _textos.add(texto);

  void llegaMetadatos() => llega({
    'type': 'conversation_initiation_metadata',
    'conversation_initiation_metadata_event': {
      'conversation_id': 'conv_prueba',
      'agent_output_audio_format': formato,
      'user_input_audio_format': 'pcm_16000',
    },
  });

  void llegaRespuesta(String texto, {int id = 1}) => llega({
    'type': 'agent_response',
    'agent_response_event': {'agent_response': texto, 'event_id': id},
  });

  void llegaTrozoDeTexto(String texto, {String tipo = 'delta'}) => llega({
    'type': 'agent_chat_response_part',
    'text_response_part': {'text': texto, 'type': tipo, 'event_id': 1},
  });

  void llegaAudio(Uint8List datos, {required int id, bool? esFinal}) => llega({
    'type': 'audio',
    'audio_event': {'audio_base_64': base64Encode(datos), 'event_id': id, 'is_final': ?esFinal},
  });

  void llegaPing(int id, {int? ms}) => llega({
    'type': 'ping',
    'ping_event': {'event_id': id, 'ping_ms': ms},
  });

  void llegaInterrupcion(int id) => llega({
    'type': 'interruption',
    'interruption_event': {'event_id': id},
  });

  void llegaCorreccion(String original, String corregido) => llega({
    'type': 'agent_response_correction',
    'agent_response_correction_event': {
      'original_agent_response': original,
      'corrected_agent_response': corregido,
      'event_id': 1,
    },
  });

  /// El servidor cierra la conexión con [codigo] (null: sin código, como un corte).
  void cierraServidor(int? codigo) {
    _codigo = codigo;
    cerrada = true;
    unawaited(_textos.close());
  }

  /// Se cae la red: error y cierre, como hace dart:io.
  void seCae() {
    cerrada = true;
    _textos.addError(const ErrorConexionWs());
    unawaited(_textos.close());
  }
}

/// Abre conexiones falsas y apunta a qué URL.
class ServidorFalso {
  final conexiones = <ConexionFalsa>[];
  final uris = <Uri>[];

  /// Lo que lanzan las próximas aperturas, en orden (una cada vez).
  final fallos = <Object>[];

  /// Si no es null, abrir espera a que se complete.
  Completer<void>? bloquear;
  String formato = 'pcm_16000';
  var responderInicio = true;

  ConexionFalsa get ultima => conexiones.last;

  Future<ConexionWs> abrir(Uri uri) async {
    uris.add(uri);
    await bloquear?.future;
    if (fallos.isNotEmpty) throw fallos.removeAt(0);
    final conexion = ConexionFalsa(formato: formato, responderInicio: responderInicio);
    conexiones.add(conexion);
    return conexion;
  }
}

/// Reproductor falso: apunta lo que se le pide.
class ReproductorFalso implements ReproductorPcm {
  final llamadas = <String>[];
  final trozos = <Uint8List>[];
  int? frecuencia;

  /// Lo que contesta pendiente().
  var queda = Duration.zero;
  Object? fallarAlPreparar;

  @override
  Future<void> preparar(int frecuencia) async {
    llamadas.add('preparar($frecuencia)');
    final fallo = fallarAlPreparar;
    if (fallo != null) throw fallo;
    this.frecuencia = frecuencia;
  }

  @override
  Future<void> anadir(Uint8List pcm) async {
    llamadas.add('anadir(${pcm.length})');
    trozos.add(pcm);
  }

  @override
  Future<void> parar() async => llamadas.add('parar');

  @override
  Future<Duration> pendiente() async {
    llamadas.add('pendiente');
    return queda;
  }

  @override
  Future<void> liberar() async => llamadas.add('liberar');

  /// Las llamadas sin las consultas de pendiente().
  List<String> get acciones => [
    for (final l in llamadas)
      if (l != 'pendiente') l,
  ];

  int get bytes => trozos.fold(0, (total, t) => total + t.length);
}

/// [milisegundos] de PCM de 16 bits mono a [frecuencia] Hz.
Uint8List pcm(int milisegundos, {int frecuencia = 16000, int valor = 1}) {
  final muestras = frecuencia * milisegundos ~/ 1000;
  return Uint8List(muestras * 2)..fillRange(0, muestras * 2, valor);
}
