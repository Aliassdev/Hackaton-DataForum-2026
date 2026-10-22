// Modelos de la API (docs/ARQUITECTURA.md, sección 8).

/// `modo` de una pregunta.
enum ModoPregunta { libre, situacion }

/// Papel de quien está en un proceso («Mi situación»). Coincide con `situacion` en la API
/// y con `rol` en las rutas y en el contenido.
enum RolProceso { testigo, victima, investigado }

/// Quién escribió un mensaje del historial. Se envía como `rol`.
enum Autor { usuario, asistente }

/// `tipo` de la respuesta del agente.
enum TipoRespuesta {
  normal('normal'),
  crisis('crisis'),
  hechos('hechos'),
  fueraDeAmbito('fuera_de_ambito');

  const TipoRespuesta(this.json);

  final String json;

  /// Un tipo desconocido se trata como `normal`: la respuesta sigue siendo texto válido.
  /// No importan las mayúsculas ni los espacios, para no perder nunca un `crisis` (sección 10.2).
  static TipoRespuesta fromJson(Object? value) {
    final texto = value?.toString().trim().toLowerCase();
    return values.firstWhere((t) => t.json == texto, orElse: () => normal);
  }
}

class Mensaje {
  const Mensaje({required this.autor, required this.texto});

  final Autor autor;
  final String texto;

  Map<String, dynamic> toJson() => {'rol': autor.name, 'texto': texto};
}

/// Petición de `POST /api/agent/ask`.
class AskRequest {
  const AskRequest({
    required this.pregunta,
    this.modo = ModoPregunta.libre,
    this.situacion,
    this.historial = const [],
    this.perfil,
  });

  /// La API solo admite los 4 últimos mensajes.
  static const maxHistorial = 4;

  final String pregunta;
  final ModoPregunta modo;
  final RolProceso? situacion;
  final List<Mensaje> historial;

  /// Las cuatro variables del perfil (edad, procedimiento, rol y fase), las mismas que van a la sesión de voz
  /// (`Entrada.variablesAgente`, sección 8.6). Opcional: si es null, la petición es la de la sección 8.1 tal cual. Lo
  /// que no se ha respondido va vacío, y el backend lo trata como «sin dato» (backend/API.md).
  final Map<String, String>? perfil;

  Map<String, dynamic> toJson() {
    final desde = historial.length > maxHistorial ? historial.length - maxHistorial : 0;
    final perfil = this.perfil;
    return {
      'pregunta': pregunta,
      'modo': modo.name,
      'situacion': situacion?.name,
      'historial': [for (final m in historial.skip(desde)) m.toJson()],
      if (perfil != null) 'perfil': Map<String, String>.of(perfil),
    };
  }
}

class Fuente {
  const Fuente({required this.id, required this.titulo, required this.norma, required this.articulo, this.url = ''});

  factory Fuente.fromJson(Map<String, dynamic> json) => Fuente(
    id: json['id'] as String,
    titulo: _texto(json['titulo']),
    norma: _texto(json['norma']),
    articulo: _texto(json['articulo']),
    url: _url(json['url']),
  );

  final String id;
  final String titulo;
  final String norma;
  final String articulo;

  /// Enlace al texto oficial (el artículo en el BOE, o la web del organismo). Vacío si no hay o si no es https.
  final String url;
}

/// Respuesta de `POST /api/agent/ask`.
class AskResponse {
  const AskResponse({
    required this.tipo,
    required this.respuesta,
    this.fuentes = const [],
    this.sugerencias = const [],
    this.terminos = const [],
    this.latenciaMs = 0,
  });

  factory AskResponse.fromJson(Map<String, dynamic> json) => AskResponse(
    tipo: TipoRespuesta.fromJson(json['tipo']),
    respuesta: json['respuesta'] as String,
    fuentes: [for (final f in json['fuentes'] as List? ?? const []) Fuente.fromJson(f as Map<String, dynamic>)],
    sugerencias: _textos(json['sugerencias']),
    terminos: _textos(json['terminos']),
    latenciaMs: (json['latencia_ms'] as num?)?.toInt() ?? 0,
  );

  final TipoRespuesta tipo;
  final String respuesta;
  final List<Fuente> fuentes;
  final List<String> sugerencias;
  final List<String> terminos;
  final int latenciaMs;

  AskResponse copyWith({
    TipoRespuesta? tipo,
    String? respuesta,
    List<Fuente>? fuentes,
    List<String>? sugerencias,
    List<String>? terminos,
  }) => AskResponse(
    tipo: tipo ?? this.tipo,
    respuesta: respuesta ?? this.respuesta,
    fuentes: fuentes ?? this.fuentes,
    sugerencias: sugerencias ?? this.sugerencias,
    terminos: terminos ?? this.terminos,
    latenciaMs: latenciaMs,
  );
}

/// Petición de `POST /api/learn/grade` («Dilo con tus palabras»).
class GradeRequest {
  const GradeRequest({required this.conceptoId, required this.texto});

  final String conceptoId;
  final String texto;

  Map<String, dynamic> toJson() => {'concepto_id': conceptoId, 'texto': texto};
}

/// Respuesta de `POST /api/learn/grade`.
class GradeResponse {
  const GradeResponse({
    required this.puntuacion,
    required this.cubiertas,
    required this.faltan,
    required this.feedback,
    this.tipo,
  });

  factory GradeResponse.fromJson(Map<String, dynamic> json) => GradeResponse(
    puntuacion: (json['puntuacion'] as num).toDouble(),
    cubiertas: _textos(json['cubiertas']),
    faltan: _textos(json['faltan']),
    feedback: json['feedback'] as String,
    tipo: _tipoGrade(json['tipo']),
  );

  final double puntuacion;
  final List<String> cubiertas;
  final List<String> faltan;
  final String feedback;

  /// `"normal"` o `"crisis"` (campo nuevo y opcional de backend/API.md; null si el backend no lo manda). Con `crisis`,
  /// lo escrito sonaba a peligro: no se ha corregido, [feedback] es la plantilla de ayuda con ANAR y la app enseña la
  /// tarjeta de Ayuda sin tocar el dominio ni los puntos.
  final String? tipo;

  bool get esCrisis => tipo == 'crisis';
}

/// Respuesta de `GET /api/health`.
class HealthResponse {
  const HealthResponse({
    required this.estado,
    required this.indiceA,
    required this.indiceB,
    required this.modeloLlm,
    required this.demo,
  });

  factory HealthResponse.fromJson(Map<String, dynamic> json) => HealthResponse(
    estado: json['estado'] as String,
    indiceA: (json['indice_a'] as num?)?.toInt() ?? 0,
    indiceB: (json['indice_b'] as num?)?.toInt() ?? 0,
    modeloLlm: _texto(json['modelo_llm']),
    demo: json['demo'] == true,
  );

  final String estado;
  final int indiceA;
  final int indiceB;
  final String modeloLlm;
  final bool demo;
}

/// Error de la API (sección 8.4). [mensaje] siempre se puede enseñar al usuario.
class ApiException implements Exception {
  const ApiException(this.codigo, this.mensaje);

  /// Lee `{"error": {"codigo", "mensaje"}}`. Si el cuerpo no tiene ese formato, usa el mensaje seguro.
  factory ApiException.desdeRespuesta(Object? json, {required int statusCode}) {
    final error = json is Map<String, dynamic> ? json['error'] : null;
    if (error is Map<String, dynamic>) {
      final codigo = _texto(error['codigo']).trim();
      final mensaje = _texto(error['mensaje']).trim();
      return ApiException(codigo.isEmpty ? 'HTTP_$statusCode' : codigo, mensaje.isEmpty ? mensajeSeguro : mensaje);
    }
    return ApiException('HTTP_$statusCode', mensajeSeguro);
  }

  static const mensajeSeguro = 'No he podido responder ahora. Prueba otra vez o pulsa Ayuda.';

  final String codigo;
  final String mensaje;

  @override
  String toString() => 'ApiException($codigo): $mensaje';
}

String _texto(Object? value) => value?.toString() ?? '';

/// Solo enlaces https (o http) con dominio: los escribe el backend y se abren fuera de la app.
String _url(Object? value) {
  final texto = value?.toString().trim() ?? '';
  final uri = Uri.tryParse(texto);
  if (uri == null || !(uri.isScheme('https') || uri.isScheme('http')) || uri.host.isEmpty) return '';
  return texto;
}

/// `tipo` de `grade`, en minúsculas y sin espacios (como [TipoRespuesta.fromJson], para no perder nunca un `crisis`).
String? _tipoGrade(Object? value) {
  final texto = value?.toString().trim().toLowerCase();
  return texto == null || texto.isEmpty ? null : texto;
}

List<String> _textos(Object? value) => value is List ? [for (final v in value) v.toString()] : const [];
