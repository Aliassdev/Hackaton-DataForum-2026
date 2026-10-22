import 'package:flutter/foundation.dart';

import '../texto.dart';

// Lo que llega del agente de voz (Pregunta, fase 1) y cómo se enseña en pantalla. Funciones puras.
//
// El backend de B escribe para la voz: quita listas, pasa los números a letras («novecientos, veinte, veinte, diez»)
// y, en las plantillas fijas, añade etiquetas de tono como [slow], que ElevenLabs no pronuncia. Aquí se deshace lo
// necesario para leerlo: sin etiquetas y con los teléfonos en cifras, que se pueden pulsar. Además se reconoce qué
// plantilla fija ha mandado el backend (crisis, hechos, fuera de ámbito o la respuesta segura del orquestador) para
// enseñar la tarjeta de ayuda, el aviso de derivación, sugerencias o «Reintentar».
//
// Plantillas copiadas de la rama de B (origin/feat/api-base, d3009c9): content/seguridad.json y
// backend/app/agent/orquestador.py (RESPUESTA_SEGURA). Si cambian allí, hay que cambiarlas aquí.

/// Qué tipo de texto ha mandado el agente.
enum TipoTextoAgente { normal, crisis, hechos, fueraDeAmbito, respuestaSegura }

/// Un texto del agente listo para enseñar.
@immutable
class RespuestaAgente {
  const RespuestaAgente({required this.texto, required this.telefonos, required this.tipo});

  /// Sin etiquetas de voz ni referencias de fuente, y con los teléfonos en cifras («900 20 20 10»).
  final String texto;

  /// Los teléfonos que aparecen en [texto], en orden y sin repetir, tal como se enseñan.
  final List<String> telefonos;
  final TipoTextoAgente tipo;
}

/// Plantillas fijas del backend de B (content/seguridad.json, d3009c9), palabra por palabra.
const plantillasSeguridad = <TipoTextoAgente, List<String>>{
  TipoTextoAgente.crisis: [
    'Gracias por contármelo. Lo que me cuentas es importante y mereces ayuda ahora mismo. [slow] Llama a la '
        'Fundación ANAR: novecientos, veinte, veinte, diez. También puedes llamar al ciento dieciséis, ciento once. '
        'Es gratis y te atienden personas a cualquier hora. Si estás en peligro ahora mismo, llama al uno, uno, dos.',
  ],
  TipoTextoAgente.hechos: [
    'Gracias por confiar en mí. Lo que pasó es importante, pero es mejor que se lo cuentes a las personas que llevan '
        'tu caso, como tu abogado o el equipo del juzgado, para que tu recuerdo no se mezcle con lo que hablemos aquí. '
        'Yo sí puedo explicarte cómo funciona el proceso y qué derechos tienes. ¿Qué te gustaría saber?',
    'Te agradezco que me lo cuentes. De lo que pasó es mejor que hables con los profesionales de tu caso; yo no te '
        'voy a preguntar por ello. Lo que sí puedo hacer es explicarte qué va a pasar en el proceso. Y si te sientes '
        'mal, en ANAR te escuchan: novecientos, veinte, veinte, diez. ¿Qué quieres saber del proceso?',
  ],
  TipoTextoAgente.fueraDeAmbito: [
    'Eso no te lo puedo responder. Yo solo sé de cómo funciona la justicia y de tus derechos en el proceso. ¿Hay algo '
        'del juicio o del juzgado que quieras saber?',
    'Con eso no te puedo ayudar. Estoy aquí para explicarte el proceso judicial y tus derechos. ¿Tienes alguna duda '
        'sobre eso?',
  ],
};

/// Lo que dice el orquestador de B si falla el modelo de lenguaje (backend/app/agent/orquestador.py, d3009c9).
const respuestaSeguraBackend =
    'Ahora mismo no he podido responderte. Prueba otra vez en un momento, o pulsa el botón de Ayuda si lo necesitas.';

/// Frases de cada plantilla que el modelo de lenguaje no suele decir, ya en forma [comparable]. Sirven si la
/// plantilla llega con algún cambio pequeño. No se usan frases cortas como «eso no te lo puedo responder», que también
/// podría decir el modelo cuando no sabe algo.
const _huellas = <TipoTextoAgente, List<String>>{
  TipoTextoAgente.crisis: ['mereces ayuda ahora mismo'],
  TipoTextoAgente.respuestaSegura: ['ahora mismo no he podido responderte'],
  TipoTextoAgente.hechos: ['para que tu recuerdo no se mezcle', 'yo no te voy a preguntar por ello'],
  TipoTextoAgente.fueraDeAmbito: [
    'yo solo se de como funciona la justicia',
    'estoy aqui para explicarte el proceso judicial y tus derechos',
  ],
};

/// Orden de comprobación: ante la duda, gana la crisis.
const _ordenTipos = [
  TipoTextoAgente.crisis,
  TipoTextoAgente.respuestaSegura,
  TipoTextoAgente.hechos,
  TipoTextoAgente.fueraDeAmbito,
];

/// Etiquetas de tono de ElevenLabs ([slow], [whispers], [sighs]…), en minúsculas. [DATO] se queda.
final _etiqueta = RegExp(r'\[[a-z]+(?:[ _-][a-z]+){0,3}\]');

/// Referencias de fuente del modo texto ([A-017]). Por el agente no llegan fuentes.
final _referencia = RegExp(r'\[[A-Z]-\d{2,4}\]');
final _variosEspacios = RegExp('[ \t ]{2,}');
final _espacioAntesDeSigno = RegExp('[ \t ]+([,.;:!?…])');

/// Quita las etiquetas de voz y las referencias de fuente, y arregla los espacios que dejan.
String quitarEtiquetas(String texto) => texto
    .replaceAll(_etiqueta, '')
    .replaceAll(_referencia, '')
    .replaceAll(_variosEspacios, ' ')
    .replaceAllMapped(_espacioAntesDeSigno, (m) => m[1]!)
    .trim();

/// Separador entre las palabras o cifras de un teléfono dicho en voz alta: espacios, comas o guiones.
const _sep = '(?:[ \t ]*[,\\-][ \t ]*|[ \t ]+)';

String _palabras(List<String> palabras) => '\\b${palabras.join(_sep)}\\b';

String _cifras(List<String> grupos) => '\\b${grupos.join('$_sep?')}\\b';

/// Reglas de teléfonos, de más larga a más corta: (expresión, cómo se enseña). Son los teléfonos de Ayuda
/// (lib/core/recursos_ayuda.dart). «diecisiete» o «dieciséis» sin «cero» delante no se tocan: pueden ser una edad.
final _reglasTelefono = <(RegExp, String Function(Match))>[
  for (final (expresion, numero) in [
    (_palabras(['novecientos', 'doscientos', 'noventa', 'y', 'tres', 'ciento', 'ochenta', 'y', 'tres']), '900 293 183'),
    (_cifras(['900', '293', '183']), '900 293 183'),
    (_palabras(['novecientos', 'ciento', 'diecis[eé]is', 'ciento', 'diecisiete']), '900 116 117'),
    (_cifras(['900', '116', '117']), '900 116 117'),
    (_palabras(['novecientos', 'veinte', 'veinte', 'diez']), '900 20 20 10'),
    (_cifras(['900', '20', '20', '10']), '900 20 20 10'),
    (_palabras(['ciento', 'diecis[eé]is', '(?:mil$_sep)?ciento', 'once']), '116 111'),
    (_palabras(['uno', 'uno', 'seis', 'uno', 'uno', 'uno']), '116 111'),
    (_cifras(['116', '111']), '116 111'),
    (_palabras(['uno', 'uno', 'dos']), '112'),
  ])
    (RegExp(expresion, caseSensitive: false), (_) => numero),
  // «ciento doce» solo detrás de «al» o «el» («llama al…», «marca el…»): así «el artículo ciento doce» no cambia.
  (RegExp('\\b(al|el)${_sep}ciento${_sep}doce\\b', caseSensitive: false), (m) => '${m[1]} 112'),
  for (final (expresion, numero) in [
    (r'\b112\b', '112'),
    (_palabras(['cero', 'diecisiete']), '017'),
    (_palabras(['cero', 'uno', 'siete']), '017'),
    (r'\b017\b', '017'),
    (_palabras(['cero', 'diecis[eé]is']), '016'),
    (_palabras(['cero', 'uno', 'seis']), '016'),
    (r'\b016\b', '016'),
  ])
    (RegExp(expresion, caseSensitive: false), (_) => numero),
];

/// Los teléfonos que se reconocen, tal como se enseñan.
const telefonosConocidos = ['900 293 183', '900 116 117', '900 20 20 10', '116 111', '112', '017', '016'];

/// Pasa a cifras los teléfonos dichos con letras: «novecientos, veinte, veinte, diez» → «900 20 20 10»,
/// «ciento dieciséis, ciento once» → «116 111», «uno, uno, dos» → «112», «cero, diecisiete» → «017».
String telefonosEnCifras(String texto) {
  var resultado = texto;
  for (final (expresion, reemplazo) in _reglasTelefono) {
    resultado = resultado.replaceAllMapped(expresion, reemplazo);
  }
  return resultado;
}

/// Los teléfonos de [texto] (ya en cifras), en orden de aparición y sin repetir.
List<String> telefonosEn(String texto) {
  final encontrados = <(int, String)>[];
  for (final numero in telefonosConocidos) {
    for (final m in RegExp('\\b${RegExp.escape(numero)}\\b').allMatches(texto)) {
      encontrados.add((m.start, numero));
    }
  }
  encontrados.sort((a, b) => a.$1.compareTo(b.$1));
  return [
    ...{for (final (_, numero) in encontrados) numero},
  ];
}

/// Minúsculas, sin tildes ni signos y con un solo espacio entre palabras: para comparar textos sin que importe cómo
/// se han escrito.
String comparable(String texto) =>
    normalizar(texto).replaceAll(RegExp('[^a-z0-9 ]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

/// La forma con la que se comparan los textos con las plantillas: sin etiquetas, teléfonos en cifras y [comparable].
String _paraComparar(String texto) => comparable(telefonosEnCifras(quitarEtiquetas(texto)));

final _plantillasComparables = {
  for (final MapEntry(:key, :value) in plantillasSeguridad.entries) key: [for (final p in value) _paraComparar(p)],
  TipoTextoAgente.respuestaSegura: [_paraComparar(respuestaSeguraBackend)],
};

/// Reconoce las plantillas fijas del backend, sin que importen las tildes, los signos, las etiquetas ni cómo vengan
/// escritos los teléfonos. Lo demás es [TipoTextoAgente.normal].
TipoTextoAgente clasificarTextoAgente(String texto) {
  final c = _paraComparar(texto);
  if (c.isEmpty) return TipoTextoAgente.normal;
  for (final tipo in _ordenTipos) {
    if (_plantillasComparables[tipo]!.any((p) => c == p || c.contains(p))) return tipo;
    if (_huellas[tipo]!.any(c.contains)) return tipo;
  }
  // Una plantilla de crisis cambiada: la etiqueta [slow] solo está en la de crisis, y nombra a ANAR.
  if (texto.contains('[slow]') && RegExp(r'\banar\b').hasMatch(c)) return TipoTextoAgente.crisis;
  return TipoTextoAgente.normal;
}

/// Todo junto: el texto para enseñar, sus teléfonos y su tipo.
RespuestaAgente prepararRespuestaAgente(String bruto) {
  final texto = telefonosEnCifras(quitarEtiquetas(bruto));
  return RespuestaAgente(texto: texto, telefonos: telefonosEn(texto), tipo: clasificarTextoAgente(bruto));
}

/// El primer mensaje fijo del agente («Hola, soy TuTurno. ¿En qué te puedo ayudar?»). No pasa por el backend.
bool esSaludoAgente(String texto) {
  final c = comparable(texto);
  return c.contains('soy tuturno') && c.contains('en que te puedo ayudar');
}

/// true si [texto] tiene alguna letra o cifra: «...» no cuenta.
bool tieneContenido(String texto) => comparable(texto).isNotEmpty;
