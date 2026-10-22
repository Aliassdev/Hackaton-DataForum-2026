// JSON de docs/ARQUITECTURA.md copiados tal cual (secciones 8 y 9.7).
//
// contrato_doc_test.dart comprueba que siguen siendo iguales a los del documento: si alguien cambia
// el contrato allí, los tests avisan.

import 'dart:convert';

/// 8.1, petición de `POST /api/agent/ask`.
const askPeticionDoc = r'''
{
  "pregunta": "Si tengo 13 años y hago algo malo, ¿me pueden juzgar?",
  "modo": "libre",
  "situacion": null,
  "historial": [
    {"rol": "usuario", "texto": "..."},
    {"rol": "asistente", "texto": "..."}
  ]
}
''';

/// 8.1, respuesta de `POST /api/agent/ask`.
const askRespuestaDoc = r'''
{
  "tipo": "normal",
  "respuesta": "Antes de los 14 años no se puede exigir responsabilidad penal en España [A-017]...",
  "fuentes": [
    {"id": "A-017", "titulo": "Antes de los 14 años no hay responsabilidad penal", "norma": "LO 5/2000", "articulo": "3"}
  ],
  "sugerencias": ["¿Qué pasa a partir de los 14?", "¿Qué hace la Fiscalía de Menores?"],
  "terminos": ["responsabilidad penal", "Fiscalía de Menores"],
  "latencia_ms": 2140
}
''';

/// 8.2, petición de `POST /api/learn/grade`.
const gradePeticionDoc = r'''
{"concepto_id": "C-ser-oido", "texto": "Que el juez tiene que escucharte si tienes 12 años"}
''';

/// 8.2, respuesta de `POST /api/learn/grade`.
const gradeRespuestaDoc = r'''
{
  "puntuacion": 0.67,
  "cubiertas": [
    "Tienes derecho a que te escuchen en lo que te afecta",
    "A partir de los 12 años se da por hecho que tienes madurez"
  ],
  "faltan": ["Tu opinión se tiene en cuenta según tu edad y madurez"],
  "feedback": "¡Muy bien! Te falta una idea: tu opinión se tiene en cuenta según tu edad y madurez."
}
''';

/// 8.3, respuesta de `GET /api/health`.
const healthDoc = r'''
{"estado": "ok", "indice_a": 182, "indice_b": 940, "modelo_llm": "claude-haiku-5-5", "demo": false}
''';

/// 8.4, cuerpo de un error.
const errorDoc = r'''
{"error": {"codigo": "LLM_NO_DISPONIBLE", "mensaje": "No he podido responder ahora. Prueba otra vez o pulsa Ayuda."}}
''';

/// 9.7, plantillas de seguridad.
const seguridadDoc = r'''
{
  "crisis": "Siento que estés pasando por esto. No estás solo ni sola. Llama ahora al 900 20 20 10 (ANAR, gratis y a cualquier hora) o al 112 si estás en peligro. También puedes hablar con un adulto de confianza.",
  "hechos": "Gracias por contármelo. Yo no soy la persona adecuada para escuchar lo que ha pasado, pero hay personas que sí: un adulto de confianza, el coordinador de bienestar de tu centro o ANAR (900 20 20 10). Si quieres, te explico qué pasa cuando se cuenta algo así.",
  "fuera_de_ambito": "Eso se sale de lo que sé. Puedo ayudarte con tus derechos y con cómo funciona la justicia."
}
''';

/// Decodifica uno de los JSON anteriores como mapa.
Map<String, dynamic> mapa(String json) => jsonDecode(json) as Map<String, dynamic>;
