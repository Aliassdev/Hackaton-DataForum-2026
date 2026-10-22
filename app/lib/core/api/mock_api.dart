import '../texto.dart';
import 'tuturno_api.dart';

/// Respuestas simuladas para trabajar sin backend (`--dart-define=USE_MOCK=true`).
///
/// Devuelve exactamente los JSON de la sección 8. Para poder probar en la interfaz los tipos
/// `crisis`, `hechos` y `fuera_de_ambito`, los simula con unas pocas expresiones y con las
/// plantillas de content/seguridad.json (sección 9.7). La detección real está en el backend.
class MockTuTurnoApi implements TuTurnoApi {
  MockTuTurnoApi({this.latencia = const Duration(milliseconds: 600)});

  final Duration latencia;

  /// Sección 8.1.
  static const ejemploAsk = <String, Object?>{
    'tipo': 'normal',
    'respuesta': 'Antes de los 14 años no se puede exigir responsabilidad penal en España [A-017]...',
    'fuentes': [
      {
        'id': 'A-017',
        'titulo': 'Antes de los 14 años no hay responsabilidad penal',
        'norma': 'LO 5/2000',
        'articulo': '3',
      },
    ],
    'sugerencias': ['¿Qué pasa a partir de los 14?', '¿Qué hace la Fiscalía de Menores?'],
    'terminos': ['responsabilidad penal', 'Fiscalía de Menores'],
    'latencia_ms': 2140,
  };

  /// Sección 8.2.
  static const ejemploGrade = <String, Object?>{
    'puntuacion': 0.67,
    'cubiertas': [
      'Tienes derecho a que te escuchen en lo que te afecta',
      'A partir de los 12 años se da por hecho que tienes madurez',
    ],
    'faltan': ['Tu opinión se tiene en cuenta según tu edad y madurez'],
    'feedback': '¡Muy bien! Te falta una idea: tu opinión se tiene en cuenta según tu edad y madurez.',
  };

  /// Las ideas de los otros «Dilo con tus palabras» del contenido de ejemplo (assets/mock/content/ejercicios), una lista
  /// por concepto. Así, sin backend, cada «Dilo» enseña sus propias ideas y no las de C-ser-oido.
  static const _ideasPorConcepto = <String, List<String>>{
    'C-fiscalia': [
      'Defiende los derechos de los menores',
      'Vigila que el proceso sea justo',
      'Dirige la investigación',
    ],
    'C-comunicar-violencia': [
      'Puede contarlo él mismo o ella misma',
      'Puede contárselo a la policía, a la Fiscalía, a un juzgado o a servicios sociales',
      'Los canales para contarlo tienen que ser seguros y confidenciales',
    ],
    'C-que-pedir': [
      'Que se lo expliquen todo con palabras claras',
      'Ir acompañada de una persona de confianza',
      'Pedir medidas para que la protejan',
    ],
    'C-sala-gesell': [
      'Tu entrevista se graba en vídeo',
      'La grabación vale para el juicio',
      'Normalmente no tienes que ir al juicio',
    ],
    'C-sin-contacto': [
      'Los juzgados se organizan para evitar que se crucen',
      'En la entrevista no tiene que verla cara a cara',
      'Se puede prohibir que se acerque o que se comunique con ella',
    ],
  };

  /// La respuesta de `grade` para [conceptoId]: la de la sección 8.2 para C-ser-oido (y para un concepto que no conoce)
  /// y, para los demás, la misma forma con sus ideas: las primeras explicadas y la última, la que falta.
  static Map<String, Object?> ejemploGradePara(String conceptoId) {
    final ideas = _ideasPorConcepto[conceptoId];
    if (ideas == null) return ejemploGrade;
    final falta = ideas.last;
    return {
      'puntuacion': 0.67,
      'cubiertas': ideas.sublist(0, ideas.length - 1),
      'faltan': [falta],
      'feedback': '¡Muy bien! Te falta una idea: ${falta[0].toLowerCase()}${falta.substring(1)}.',
    };
  }

  /// Sección 8.3.
  static const ejemploHealth = <String, Object?>{
    'estado': 'ok',
    'indice_a': 182,
    'indice_b': 940,
    'modelo_llm': 'claude-haiku-5-5',
    'demo': false,
  };

  /// Sección 9.7.
  static const plantillas = <TipoRespuesta, String>{
    TipoRespuesta.crisis: 'Siento que estés pasando por esto. No estás solo ni sola. Llama ahora al 900 20 20 10 (ANAR, gratis y a cualquier hora) o al 112 si estás en peligro. También puedes hablar con un adulto de confianza.',
    TipoRespuesta.hechos: 'Gracias por contármelo. Yo no soy la persona adecuada para escuchar lo que ha pasado, pero hay personas que sí: un adulto de confianza, el coordinador de bienestar de tu centro o ANAR (900 20 20 10). Si quieres, te explico qué pasa cuando se cuenta algo así.',
    TipoRespuesta.fueraDeAmbito:
        'Eso se sale de lo que sé. Puedo ayudarte con tus derechos y con cómo funciona la justicia.',
  };

  /// Sección 10.1, paso 6: después de la plantilla de `hechos` se propone seguir hablando del proceso.
  static const sugerenciasHechos = ['¿Qué pasa si se denuncia?', '¿A quién puedo pedir ayuda?'];

  static const _crisis = ['quiero morir', 'hacerme dano', 'no quiero vivir', 'tengo miedo de volver a casa'];
  static const _hechos = ['me pegaron', 'me han pegado', 'me paso', 'me ha pasado'];
  static const _fueraDeAmbito = ['futbol', 'videojuego', 'receta'];

  @override
  Future<AskResponse> ask(AskRequest request) async {
    await Future<void>.delayed(latencia);
    final texto = normalizar(request.pregunta);
    bool contiene(List<String> expresiones) => expresiones.any(texto.contains);

    final tipo = contiene(_crisis)
        ? TipoRespuesta.crisis
        : contiene(_hechos)
        ? TipoRespuesta.hechos
        : contiene(_fueraDeAmbito)
        ? TipoRespuesta.fueraDeAmbito
        : TipoRespuesta.normal;
    if (tipo == TipoRespuesta.normal) return AskResponse.fromJson(ejemploAsk);
    return AskResponse(
      tipo: tipo,
      respuesta: plantillas[tipo]!,
      sugerencias: tipo == TipoRespuesta.hechos ? sugerenciasHechos : const [],
      latenciaMs: 5,
    );
  }

  @override
  Future<GradeResponse> grade(GradeRequest request) async {
    await Future<void>.delayed(latencia);
    return GradeResponse.fromJson(ejemploGradePara(request.conceptoId));
  }

  @override
  Future<HealthResponse> health() async => HealthResponse.fromJson(ejemploHealth);
}
