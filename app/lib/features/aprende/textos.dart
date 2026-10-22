import 'package:flutter/material.dart';

import 'modelos.dart';

// Textos de Aprende. Frases cortas, de tú, con palabras que entiende alguien de 11 años.
// Nunca culpan: fallar es parte de aprender.

/// Nombre corto de cada concepto, para las barras de dominio. Si el contenido trae uno nuevo, se deduce del id.
const _nombresConceptos = {
  'C-ser-oido': 'Ser oído y escuchado',
  'C-fiscalia': 'Avisar a la Fiscalía',
  'C-defensor': 'Quejarte al Defensor del Pueblo',
  'C-abogado-gratis': 'Abogado de oficio',
  'C-comunicar-violencia': 'Contar la violencia',
  'C-citacion': 'La citación y los avisos',
  'C-que-pedir': 'Qué puedes pedir',
  'C-sala-gesell': 'Sala Gesell y prueba preconstituida',
  'C-sin-contacto': 'No cruzarte con la persona investigada',
  'C-despues': 'Qué pasa después',
  'C-proceso': 'Los pasos del proceso',
  'C-personas': 'Quién es quién',
  'C-abogados': 'Los abogados',
  'C-entender': 'Derecho a entender',
  'C-informacion': 'Información sobre tu caso',
  'C-proteccion': 'Protección durante el proceso',
  'C-intimidad-victima': 'Tu intimidad como víctima',
  'C-testigo': 'Declarar con garantías',
  'C-propia-imagen': 'Tu imagen es tuya',
  'C-no-reenviar': 'No reenviar',
  'C-retirar-contenido': 'Pedir que lo quiten',
  'C-denunciar': 'Denunciar y pedir ayuda',
  'C-ayuda-internet': 'Ayuda en internet',
  'C-edad-penal': 'La edad y la ley de menores',
  'C-medidas': 'Medidas, no penas',
  'C-derechos-detenido': 'Si te detienen',
  'C-conciliacion': 'Conciliación y mediación',
  'C-escuchado-familia': 'Que te escuchen en familia',
  'C-tu-opinion': 'Tu opinión cuenta',
  'C-seguir-familia': 'Seguir con tu familia',
  'C-defender-derechos': 'Defender tus derechos',
};

String nombreConcepto(String id) {
  final conocido = _nombresConceptos[id];
  if (conocido != null) return conocido;
  final palabras = id.replaceFirst(RegExp(r'^C-'), '').replaceAll('-', ' ').trim();
  if (palabras.isEmpty) return id;
  return palabras[0].toUpperCase() + palabras.substring(1);
}

/// Cómo va un concepto, según su probabilidad de dominio.
String nivelDominio(double p) => p >= 0.95
    ? '¡Dominado!'
    : p >= 0.7
    ? 'Casi lo tienes'
    : p >= 0.4
    ? 'Aprendiendo'
    : 'Por aprender';

/// Instrucción corta de cada tipo de ejercicio.
String etiquetaTipo(TipoEjercicio tipo) => switch (tipo) {
  TipoEjercicio.eleccion => 'Elige la respuesta',
  TipoEjercicio.vf => '¿Verdadero o falso?',
  TipoEjercicio.ordenar => 'Ordena los pasos',
  TipoEjercicio.emparejar => 'Une las parejas',
  TipoEjercicio.dilo => 'Dilo con tus palabras',
};

IconData iconoTipo(TipoEjercicio tipo) => switch (tipo) {
  TipoEjercicio.eleccion => Icons.checklist_rounded,
  TipoEjercicio.vf => Icons.rule_rounded,
  TipoEjercicio.ordenar => Icons.format_list_numbered_rounded,
  TipoEjercicio.emparejar => Icons.join_inner_rounded,
  TipoEjercicio.dilo => Icons.record_voice_over_rounded,
};

const _titulosAcierto = ['¡Correcto!', '¡Muy bien!', '¡Eso es!', '¡Genial!', '¡Lo has clavado!'];
const _titulosFallo = ['¡Casi!', 'Esta vez no', 'No pasa nada', '¡Casi lo tienes!'];

/// Título del panel de corrección. [vez] hace que no salga siempre el mismo.
String tituloCorreccion({required bool acierto, required int vez}) =>
    acierto ? _titulosAcierto[vez % _titulosAcierto.length] : _titulosFallo[vez % _titulosFallo.length];

/// Ánimo cuando se encadenan aciertos.
String? textoRachaAciertos(int seguidos) => switch (seguidos) {
  3 => '¡3 seguidas!',
  5 => '¡5 seguidas! Imparable',
  >= 6 => '¡$seguidos seguidas!',
  _ => null,
};

/// Lo que dice la celebración según cómo haya ido.
String animoFinal({required int aciertos, required int total}) {
  if (total == 0) return 'Cada intento cuenta.';
  final proporcion = aciertos / total;
  if (proporcion == 1) return 'Todo perfecto. ¡Sabes un montón!';
  if (proporcion >= 0.66) return 'Lo estás entendiendo muy bien.';
  if (proporcion >= 0.33) return 'Vas por buen camino. Repasar ayuda mucho.';
  return 'Cada intento cuenta. La próxima vez te saldrá mejor.';
}

const textoSalirTitulo = '¿Salir de la lección?';
const textoSalirMensaje = 'Si sales ahora, no se guardan los puntos de esta lección. Lo que has aprendido sí se queda.';
const textoDiloAyuda = 'Escribe o usa el micrófono. Puedes corregir el texto antes de comprobarlo.';
const textoDiloSinRevisar = 'No he podido revisarlo ahora';

/// Si no se ha podido corregir «Dilo» (sin conexión o con el servidor caído). No manda a Ayuda: es un fallo técnico.
const textoDiloSinConexion =
    'Puede que no haya conexión. Vuelve a intentarlo o compara lo que has escrito con las ideas clave.';
const textoVolverAIntentar = 'Volver a intentarlo';
const textoDiloIdeasClave = 'Las ideas clave son:';
const textoDiloTeFalta = 'Te falta';
const palabrasMinimasDilo = 3;

/// Título del panel de «Dilo» según la parte de las ideas que ha explicado ([puntuacion], de 0 a 1). Con la mitad o
/// más, suma puntos.
String tituloDilo(double puntuacion) => puntuacion >= 1
    ? '¡Perfecto!'
    : puntuacion >= 0.5
    ? '¡Ya casi!'
    : 'Vas por buen camino';

/// Si en «Dilo» se escribe algo que suena a peligro, no se corrige: se ofrece ayuda (sección 10.2, «ante la duda,
/// ofrecer ayuda»). Es la plantilla de crisis de la sección 9.7, partida en el título y lo que sigue a la tarjeta roja
/// de Ayuda (que ya dice que no estás solo ni sola y tiene los botones de ANAR y del 112).
const textoAyudaDiloTitulo = 'Siento que estés pasando por esto';
const textoAyudaDiloResto =
    'También puedes hablar con un adulto de confianza. Cuando quieras, puedes seguir con la lección.';

/// La plantilla de crisis entera (sección 9.7), para leerla en voz alta.
const textoAyudaDiloVoz =
    'Siento que estés pasando por esto. No estás solo ni sola. Llama ahora al 900 20 20 10 (ANAR, gratis y a cualquier '
    'hora) o al 112 si estás en peligro. También puedes hablar con un adulto de confianza.';

/// Nombre fácil de las normas que se citan en las fuentes, para quien no sabe qué es «LECrim». Son los mismos nombres
/// que usan Vive el caso, Pregunta y Mi situación.
const nombresNormas = {
  'LO 1/1996': 'Ley de protección jurídica del menor',
  'Ley 1/1996': 'Ley de asistencia jurídica gratuita',
  'LO 5/2000': 'Ley de responsabilidad penal de los menores',
  'LO 8/2021': 'Ley de protección de la infancia y la adolescencia frente a la violencia (LOPIVI)',
  'LOPIVI': 'Ley de protección de la infancia y la adolescencia frente a la violencia',
  'Ley 4/2015': 'Estatuto de la víctima del delito',
  'LECrim': 'Ley de Enjuiciamiento Criminal',
  'LEC': 'Ley de Enjuiciamiento Civil',
  'LO 3/1981': 'Ley del Defensor del Pueblo',
  'LO 1/1982': 'Ley del derecho al honor, a la intimidad y a la propia imagen',
  'CDN': 'Convención sobre los Derechos del Niño',
  'CE': 'Constitución Española',
  'Código Penal': 'Código Penal',
  'LOPDGDD': 'Ley de protección de datos personales',
  'RGPD': 'Reglamento General de Protección de Datos',
  'AEPD': 'Agencia Española de Protección de Datos',
  'INCIBE': 'Instituto Nacional de Ciberseguridad',
};

/// Las normas de [nombresNormas] que aparecen en [fuente], en orden y sin repetir.
List<(String, String)> normasEn(String fuente) {
  final encontradas = <(int, String, String)>[];
  for (final MapEntry(key: sigla, value: nombre) in nombresNormas.entries) {
    final i = RegExp('(^|[^\\w/])${RegExp.escape(sigla)}(?![\\w/])').firstMatch(fuente)?.start;
    if (i != null) encontradas.add((i, sigla, nombre));
  }
  encontradas.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (_, sigla, nombre) in encontradas) (sigla, nombre)];
}
