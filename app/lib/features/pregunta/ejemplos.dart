import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/mock_api.dart';
import '../../core/api/tuturno_api.dart';
import '../../core/seguridad.dart';
import '../../core/texto.dart';

// Respuestas de ejemplo de Pregunta (plan v2, demo §3.2). Salen solo si no responde nadie: ni el agente de voz ni el
// modo texto (POST /api/agent/ask), o si se fuerza desde el modo demo. En la pantalla siempre van marcadas como
// ejemplo («Ejemplo», «TuTurno · ejemplo» y la banda «Sin conexión con el asistente»). Nunca parecen en directo.
//
// Primero, las tres conversaciones del guion de la demo (assets/mock/content/pregunta_ejemplos.json: Sergio con una
// pregunta del proceso, Sergio en el momento «hechos» y Sara con las fotos); si la pregunta no es una de ellas, las
// respuestas por palabras clave de MockTuTurnoApi, también sacadas de docs/MARCO_LEGAL.md. Antes que nada va la red de
// seguridad: lo que suena a peligro o a que le hacen daño se contesta con la plantilla de ayuda. Todo es local: la
// pregunta no sale del móvil.

/// El JSON con las conversaciones de ejemplo (es contenido de la app, no de content/).
const rutaEjemplosPregunta = 'assets/mock/content/pregunta_ejemplos.json';

/// Las respuestas de ejemplo de Pregunta.
final respuestasEjemploProvider = Provider<TuTurnoApi>((ref) => RespuestasDeEjemplo());

/// Una conversación de ejemplo: la pregunta del guion, cómo se reconoce y la respuesta.
class ConversacionEjemplo {
  const ConversacionEjemplo({
    required this.id,
    required this.caso,
    required this.origen,
    required this.pregunta,
    required this.claves,
    required this.respuesta,
  });

  /// Lanza si al JSON le falta algo: mejor saberlo en los tests que en la demo.
  factory ConversacionEjemplo.fromJson(Map<String, dynamic> json) {
    final claves = [
      for (final grupo in json['claves'] as List) [for (final clave in grupo as List) clave as String],
    ];
    if (claves.isEmpty || claves.any((g) => g.isEmpty)) {
      throw FormatException('La conversación de ejemplo ${json['id']} no tiene claves');
    }
    return ConversacionEjemplo(
      id: json['id'] as String,
      caso: json['caso'] as String,
      origen: json['origen'] as String,
      pregunta: json['pregunta'] as String,
      claves: claves,
      respuesta: AskResponse.fromJson(json['respuesta'] as Map<String, dynamic>),
    );
  }

  final String id;

  /// Lucía, Sergio o Sara.
  final String caso;

  /// De dónde salen el texto y las fuentes: `marco_legal` (docs/MARCO_LEGAL.md) o, tras el ensayo, `agente`.
  final String origen;

  /// La frase del guion.
  final String pregunta;

  /// Grupos de trozos (minúsculas, sin tildes): se reconoce si la pregunta tiene todos los de algún grupo.
  final List<List<String>> claves;
  final AskResponse respuesta;

  /// [texto] ya en la forma de [comparableEjemplo].
  bool reconoce(String texto) => claves.any((grupo) => grupo.every(texto.contains));
}

/// Lee el JSON de las conversaciones de ejemplo. Lanza [FormatException] (o un error de tipos) si no tiene la forma
/// esperada.
List<ConversacionEjemplo> leerEjemplosPregunta(String json) {
  final datos = jsonDecode(json);
  if (datos is! Map<String, dynamic> || datos['conversaciones'] is! List) {
    throw const FormatException('pregunta_ejemplos.json: falta «conversaciones»');
  }
  return [for (final c in datos['conversaciones'] as List) ConversacionEjemplo.fromJson(c as Map<String, dynamic>)];
}

/// Minúsculas, sin tildes ni signos, con un espacio entre palabras y otro al principio y al final (así « foto» es una
/// palabra que empieza por «foto»).
String comparableEjemplo(String texto) => ' ${normalizar(texto).replaceAll(RegExp('[^a-z0-9]+'), ' ').trim()} ';

/// [TuTurnoApi] de ejemplo: las conversaciones del JSON y, si no es ninguna, [MockTuTurnoApi].
class RespuestasDeEjemplo implements TuTurnoApi {
  /// Lee el JSON del bundle la primera vez que hace falta.
  RespuestasDeEjemplo({AssetBundle? bundle, TuTurnoApi? reserva, this.latencia = const Duration(milliseconds: 300)})
    : _bundle = bundle ?? rootBundle,
      _reserva = reserva ?? MockTuTurnoApi(latencia: latencia);

  /// Con el JSON ya leído (para los tests: así no hace falta esperar al bundle).
  RespuestasDeEjemplo.desdeJson(String json, {TuTurnoApi? reserva, this.latencia = Duration.zero})
    : _bundle = null,
      _reserva = reserva ?? MockTuTurnoApi(latencia: latencia),
      _leidas = leerEjemplosPregunta(json);

  final AssetBundle? _bundle;
  final TuTurnoApi _reserva;

  /// Lo que tarda en contestar un ejemplo del JSON (que no parezca que no ha pensado nada).
  final Duration latencia;
  List<ConversacionEjemplo>? _leidas;
  Future<List<ConversacionEjemplo>>? _cargando;

  Future<List<ConversacionEjemplo>> _conversaciones() async {
    final leidas = _leidas;
    if (leidas != null) return leidas;
    final bundle = _bundle;
    if (bundle == null) return const [];
    return _cargando ??= () async {
      try {
        return _leidas = leerEjemplosPregunta(await bundle.loadString(rutaEjemplosPregunta));
      } catch (_) {
        // Sin el JSON quedan las respuestas por palabras clave, que también son de docs/MARCO_LEGAL.md.
        return _leidas = const <ConversacionEjemplo>[];
      }
    }();
  }

  /// La conversación del JSON que reconoce [pregunta], o null. Con [investigado], solo la de «hechos»: las demás
  /// contestan como a una víctima (Sergio y Sara).
  Future<ConversacionEjemplo?> buscar(String pregunta, {bool investigado = false}) async {
    final texto = comparableEjemplo(pregunta);
    for (final conversacion in await _conversaciones()) {
      if (investigado && conversacion.respuesta.tipo == TipoRespuesta.normal) continue;
      if (conversacion.reconoce(texto)) return conversacion;
    }
    return null;
  }

  /// La pregunta llega como investigado: desde «Pregunta como investigado» o con ese papel en el ticket.
  static bool _deInvestigado(AskRequest request) =>
      request.situacion == RolProceso.investigado || request.perfil?['rol'] == 'investigado';

  @override
  Future<AskResponse> ask(AskRequest request) async {
    final pregunta = request.pregunta;
    // La red de seguridad, antes que el guion: el peligro y quien cuenta que le hacen daño, con la plantilla de ayuda.
    final peligro = pareceCrisis(pregunta) || MockTuTurnoApi.cuentaQueLeHacenDano(comparableEjemplo(pregunta));
    if (!peligro) {
      final conversacion = await buscar(pregunta, investigado: _deInvestigado(request));
      if (conversacion != null) {
        if (latencia > Duration.zero) await Future<void>.delayed(latencia);
        return conversacion.respuesta;
      }
    }
    return _reserva.ask(request);
  }

  @override
  Future<GradeResponse> grade(GradeRequest request) => _reserva.grade(request);

  @override
  Future<HealthResponse> health() => _reserva.health();
}
