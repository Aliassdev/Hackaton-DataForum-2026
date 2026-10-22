// Textos de «¿Quién es quién en el juzgado?»: quién es y qué hace cada persona de la sala, para chicos y chicas desde
// los 11 años.
//
// Regla (CLAUDE.md): toda afirmación jurídica sale de docs/MARCO_LEGAL.md, con su artículo y la cita literal de allí
// (una prueba lo comprueba). Lo demás solo presenta a cada persona y dice qué hace en la sala, sin afirmar derechos,
// deberes, plazos ni excepciones. Si algo no está en MARCO_LEGAL, no está aquí: las citas del BOE que había antes
// (LOPJ, Estatuto del Ministerio Fiscal, más artículos de la LECrim y de la LO 5/2000…) están en el historial de git
// para cuando se añadan a MARCO_LEGAL.
//
// Los textos están pendientes de que los revise alguien con formación jurídica ([DatosJuzgado.validado] es false):
// hasta entonces, la actividad lleva la franja «Borrador» y el juego solo la abre con el interruptor de borradores del
// modo DEMO (la regla del contenido con «validado»).
import 'package:flutter/foundation.dart';

import '../../widgets/iconos/tu_icono.dart';
import 'sala_juzgado.dart' show ModoJuzgado;

/// Un artículo de una ley en el BOE, con la [cita] literal (la de docs/MARCO_LEGAL.md) en la que se apoya un texto.
@immutable
class FuenteJuzgado {
  const FuenteJuzgado({required this.norma, required this.articulo, required this.cita, required this.boe});

  /// Nombre corto de la norma: «LECrim», «LO 5/2000», «Ley 4/2015»…
  final String norma;

  /// El artículo (y el apartado o los párrafos, si los hay): «22», «19.2 y 19.6», «4, párrs. 4 y 5».
  final String articulo;

  /// El texto literal. «(...)» marca lo que se omite.
  final String cita;

  /// Identificador de la norma en el BOE: «BOE-A-1882-6036».
  final String boe;

  /// «art. 22», «arts. 656 y 708» (con varios artículos) o, si es una disposición, «disposición adicional primera».
  /// Varios apartados del mismo artículo («118.2 y 118.4», «22.1 a), b) y d)») siguen siendo un solo artículo, y los
  /// párrafos («, párrs. 4 y 5») no cuentan como artículos.
  String get referencia {
    if (articulo.startsWith('disposición')) return articulo;
    final soloArticulos = articulo.split(RegExp(r',\s*párrs?\.')).first;
    final numeros = {
      for (final m in RegExp(r'(?:^|,\s*|\sy\s)(\d+(?:\s(?:bis|ter))?)').allMatches(soloArticulos)) m.group(1),
    };
    return '${numeros.length > 1 ? 'arts.' : 'art.'} $articulo';
  }

  /// «Ley 4/2015, art. 22».
  String get etiqueta => '$norma, $referencia';

  /// El nombre largo de la norma, para quien no sabe qué es «LECrim».
  String get nombreNorma => nombresNormas[norma] ?? norma;

  /// El texto consolidado en el BOE.
  String get url => 'https://www.boe.es/buscar/act.php?id=$boe';
}

/// Nombres largos de las normas que se citan.
const nombresNormas = {
  'Constitución': 'Constitución Española',
  'LECrim': 'Ley de Enjuiciamiento Criminal',
  'Ley 4/2015': 'Ley 4/2015, del Estatuto de la víctima del delito',
  'LO 1/1996': 'Ley Orgánica 1/1996, de Protección Jurídica del Menor',
  'LO 5/2000': 'Ley Orgánica 5/2000, reguladora de la responsabilidad penal de los menores',
  'LOPIVI': 'Ley Orgánica 8/2021, de protección de la infancia y la adolescencia frente a la violencia',
  'LOPJ': 'Ley Orgánica 6/1985, del Poder Judicial',
};

/// Una persona de la sala: quién es, qué hace y de dónde sale.
@immutable
class RolJuzgado {
  const RolJuzgado({
    required this.id,
    required this.titulo,
    required this.corto,
    this.subtitulo,
    required this.quienEs,
    required this.queHace,
    this.sabiasQue,
    required this.icono,
    this.fuentes = const [],
    this.sitio,
  });

  /// El id de su puesto en la sala («jueza»).
  final String id;

  /// «La jueza».
  final String titulo;

  /// Nombre corto, para las fichas de la sala: «Jueza», «Policía».
  final String corto;

  /// Otro nombre con el que se le conoce («Letrada del menor»), si lo tiene.
  final String? subtitulo;

  final String quienEs;
  final String queHace;

  /// Un dato más, para quien quiera saber más.
  final String? sabiasQue;

  /// El icono de su carta y de su ficha, de la iconografía de TuTurno (nunca un mazo, una balanza de juicio ni una
  /// placa de policía).
  final TuIcono icono;

  /// Los artículos de MARCO_LEGAL de los que salen las afirmaciones jurídicas de [quienEs], [queHace] y [sabiasQue].
  /// Vacía si la carta solo presenta a la persona.
  final List<FuenteJuzgado> fuentes;

  /// Dónde está en la sala, para decírselo a quien usa un lector de pantalla («en el estrado, arriba en el centro»).
  final String? sitio;
}

/// Un aviso sobre la sala (que hoy no hay público, dónde está Sergio…), con sus fuentes.
@immutable
class NotaJuzgado {
  const NotaJuzgado({required this.titulo, required this.texto, required this.icono, required this.fuentes});

  final String titulo;
  final String texto;
  final TuIcono icono;
  final List<FuenteJuzgado> fuentes;
}

/// Lo que cambia de un montaje a otro: los títulos, quién está y los avisos.
@immutable
class DatosJuzgado {
  const DatosJuzgado({
    required this.titulo,
    required this.subtitulo,
    required this.descripcion,
    required this.roles,
    this.notas = const [],
    this.validado = false,
  });

  /// Los datos de [modo].
  factory DatosJuzgado.de(ModoJuzgado modo) => switch (modo) {
    ModoJuzgado.salaVistas => datosSalaVistas,
    ModoJuzgado.menores => datosMenores,
  };

  /// «¿Quién es quién en el juzgado?».
  final String titulo;

  /// La frase de debajo del título.
  final String subtitulo;

  /// Lo que dicen los lectores de pantalla de la sala.
  final String descripcion;

  /// Quién está en la sala, en el orden de las fichas.
  final List<RolJuzgado> roles;

  final List<NotaJuzgado> notas;

  /// Si alguien con formación jurídica ha revisado los textos (como el «validado» del contenido, CLAUDE.md). Mientras
  /// sea false, [JuzgadoExplorable] enseña la franja «Borrador: textos pendientes de revisión jurídica» y el juego solo
  /// abre la actividad en modo DEMO, con el interruptor de borradores.
  final bool validado;

  /// El rol [id], o null si no está.
  RolJuzgado? rol(String id) => roles.where((rol) => rol.id == id).firstOrNull;
}

// ----------------------------------------------------------------------------------------------------------- fuentes
// Las citas son las de docs/MARCO_LEGAL.md, tal cual («[...]» allí es «(...)» aquí).

const _ce = 'BOE-A-1978-31229';
const _lecrim = 'BOE-A-1882-6036';
const _estatuto = 'BOE-A-2015-4606';
const _lopjm = 'BOE-A-1996-1069';
const _lorpm = 'BOE-A-2000-641';
const _lopivi = 'BOE-A-2021-9347';
const _lopj = 'BOE-A-1985-12666';

const _lopj453 = FuenteJuzgado(
  norma: 'LOPJ',
  articulo: '453.1',
  boe: _lopj,
  cita:
      '1. Corresponde a los Letrados de la Administración de Justicia, con exclusividad y plenitud, el ejercicio de la fe '
      'pública judicial. En el ejercicio de esta función, dejarán constancia fehaciente de la realización de actos '
      'procesales en el Tribunal o ante éste (...) mediante las oportunas actas y diligencias. (...) En todo caso, el '
      'Letrado de la Administración de Justicia garantizará la autenticidad e integridad de lo grabado o reproducido.',
);

const _ce24 = FuenteJuzgado(
  norma: 'Constitución',
  articulo: '24.2',
  boe: _ce,
  cita:
      '2. Asimismo, todos tienen derecho al Juez ordinario predeterminado por la ley, a la defensa y a la asistencia de '
      'letrado, a ser informados de la acusación formulada contra ellos, a un proceso público sin dilaciones indebidas y '
      'con todas las garantías, a utilizar los medios de prueba pertinentes para su defensa, a no declarar contra sí '
      'mismos, a no confesarse culpables y a la presunción de inocencia.',
);

const _lecrim449bis = FuenteJuzgado(
  norma: 'LECrim',
  articulo: '449 bis, párrs. 2 y 3',
  boe: _lecrim,
  cita:
      'La autoridad judicial garantizará el principio de contradicción en la práctica de la declaración. (...) su '
      'defensa letrada, en todo caso, deberá estar presente. (...) La autoridad judicial asegurará la documentación de '
      'la declaración en soporte apto para la grabación del sonido y la imagen (...)',
);

const _lecrim449ter = FuenteJuzgado(
  norma: 'LECrim',
  articulo: '449 ter, párr. 1',
  boe: _lecrim,
  cita:
      'Cuando una persona menor de catorce años (...) deba intervenir en condición de testigo en un procedimiento '
      'judicial que tenga por objeto la instrucción de un delito de homicidio, lesiones, contra la libertad, contra la '
      'integridad moral (...), la autoridad judicial acordará, en todo caso, practicar la audiencia del menor como prueba '
      'preconstituida',
);

const _lecrim520 = FuenteJuzgado(
  norma: 'LECrim',
  articulo: '520.2 bis',
  boe: _lecrim,
  cita:
      '2 bis. La información a que se refiere el apartado anterior se facilitará en un lenguaje comprensible y que '
      'resulte accesible al destinatario. A estos efectos se adaptará la información a su edad, grado de madurez, '
      'discapacidad y cualquier otra circunstancia personal (...)',
);

const _lecrim681 = FuenteJuzgado(
  norma: 'LECrim',
  articulo: '681.3',
  boe: _lecrim,
  cita:
      '3. Queda prohibida, en todo caso, la divulgación o publicación de información relativa a la identidad de víctimas '
      'menores de edad, (...) así como de datos que puedan facilitar su identificación de forma directa o indirecta, '
      '(...) así como la obtención, divulgación o publicación de imágenes suyas o de sus familiares.',
);

const _lecrim703bis = FuenteJuzgado(
  norma: 'LECrim',
  articulo: '703 bis, párrs. 1 y 2',
  boe: _lecrim,
  cita:
      'se procederá, a instancia de la parte interesada, a la reproducción en la vista de la grabación audiovisual (...) '
      'sin que sea necesaria la presencia del testigo en la vista. En los supuestos previstos en el artículo 449 ter, la '
      'autoridad judicial solo podrá acordar la intervención del testigo en el acto del juicio, con carácter '
      'excepcional (...)',
);

const _estatuto7 = FuenteJuzgado(
  norma: 'Ley 4/2015',
  articulo: '7.1 a) y b)',
  boe: _estatuto,
  cita:
      '1. Toda víctima será informada de manera inmediata de la fecha, hora y lugar del juicio, así como del contenido '
      'de la acusación dirigida contra el infractor, y se le notificarán las siguientes resoluciones: a) La resolución '
      'por la que se acuerde no iniciar el procedimiento penal. b) La sentencia que ponga fin al procedimiento.',
);

const _estatuto19 = FuenteJuzgado(
  norma: 'Ley 4/2015',
  articulo: '19, párrs. 1 y 2',
  boe: _estatuto,
  cita:
      'Las autoridades y funcionarios encargados de la investigación, persecución y enjuiciamiento de los delitos '
      'adoptarán las medidas necesarias (...) para evitar el riesgo de su victimización secundaria o reiterada. En el '
      'caso de las víctimas menores de edad, la Fiscalía velará especialmente por el cumplimiento de este derecho de '
      'protección (...)',
);

const _estatuto20 = FuenteJuzgado(
  norma: 'Ley 4/2015',
  articulo: '20',
  boe: _estatuto,
  cita:
      'Las dependencias en las que se desarrollen los actos del procedimiento penal, incluida la fase de investigación, '
      'estarán dispuestas de modo que se evite el contacto directo entre las víctimas y sus familiares, de una parte, y '
      'el sospechoso de la infracción o acusado, de otra (...)',
);

const _estatuto22 = FuenteJuzgado(
  norma: 'Ley 4/2015',
  articulo: '22',
  boe: _estatuto,
  cita:
      'Los Jueces, Tribunales, Fiscales (...) adoptarán, de acuerdo con lo dispuesto en la Ley, las medidas necesarias '
      'para proteger la intimidad de todas las víctimas y de sus familiares y, en particular, para impedir la difusión '
      'de cualquier información que pueda facilitar la identificación de las víctimas menores de edad (...)',
);

const _lopjm4 = FuenteJuzgado(
  norma: 'LO 1/1996',
  articulo: '4.1 y 4.5',
  boe: _lopjm,
  cita:
      '1. Los menores tienen derecho al honor, a la intimidad personal y familiar y a la propia imagen. (...) 5. Los '
      'padres o tutores y los poderes públicos respetarán estos derechos y los protegerán frente a posibles ataques de '
      'terceros.',
);

const _lopjm9 = FuenteJuzgado(
  norma: 'LO 1/1996',
  articulo: '9.1 y 9.2',
  boe: _lopjm,
  cita:
      'El menor tiene derecho a ser oído y escuchado sin discriminación alguna por edad (...) el menor deberá recibir '
      'la información que le permita el ejercicio de este derecho en un lenguaje comprensible, en formatos accesibles y '
      'adaptados a sus circunstancias. (...) Se considera, en todo caso, que tiene suficiente madurez cuando tenga doce '
      'años cumplidos.',
);

const _lopjm10 = FuenteJuzgado(
  norma: 'LO 1/1996',
  articulo: '10.2.b) y 10.2.c)',
  boe: _lopjm,
  cita:
      'Para la defensa y garantía de sus derechos el menor puede: (...) b) Poner en conocimiento del Ministerio Fiscal '
      'las situaciones que considere que atentan contra sus derechos con el fin de que éste promueva las acciones '
      'oportunas. c) Plantear sus quejas ante el Defensor del Pueblo o ante las instituciones autonómicas homólogas.',
);

const _lopivi14 = FuenteJuzgado(
  norma: 'LOPIVI',
  articulo: '14.1 y 14.3',
  boe: _lopivi,
  cita:
      'Las personas menores de edad víctimas de violencia tienen derecho a la defensa y representación gratuitas por '
      'abogado y procurador de conformidad con lo dispuesto en la Ley 1/1996, de 10 de enero, de asistencia jurídica '
      'gratuita. (...) los Colegios de Abogados adoptarán las medidas necesarias para la designación urgente de letrado '
      'o letrada de oficio',
);

const _lopivi50d = FuenteJuzgado(
  norma: 'LOPIVI',
  articulo: '50.2.d)',
  boe: _lopivi,
  cita:
      'd) Se impedirá cualquier tipo de contacto directo o indirecto en dependencias policiales entre la persona '
      'investigada y el niño, niña o adolescente.',
);

const _lopivi50eh = FuenteJuzgado(
  norma: 'LOPIVI',
  articulo: '50.2.e) y 50.2.h)',
  boe: _lopivi,
  cita:
      'e) Se permitirá a las personas menores de edad, que así lo soliciten, formular denuncia por sí mismas y sin '
      'necesidad de estar acompañadas de una persona adulta. (...) h) Se procurará que el niño, niña o adolescente se '
      'encuentre en todo momento en compañía de una persona de su confianza designada libremente por él o ella misma en '
      'un entorno seguro',
);

const _lorpm1 = FuenteJuzgado(
  norma: 'LO 5/2000',
  articulo: '1.1',
  boe: _lorpm,
  cita:
      '1. Esta Ley se aplicará para exigir la responsabilidad de las personas mayores de catorce años y menores de '
      'dieciocho por la comisión de hechos tipificados como delitos o faltas en el Código Penal o las leyes penales '
      'especiales.',
);

const _lorpm4Victimas = FuenteJuzgado(
  norma: 'LO 5/2000',
  articulo: '4, párrs. 1 y 3',
  boe: _lorpm,
  cita:
      'El Ministerio Fiscal y el Juez de Menores velarán en todo momento por la protección de los derechos de las '
      'víctimas y de las personas perjudicadas por las infracciones cometidas por las personas menores de edad. (...) '
      'Las víctimas y las personas perjudicadas tendrán derecho a personarse y ser parte en el expediente que se incoe al '
      'efecto (...)',
);

const _lorpm4Distancia = FuenteJuzgado(
  norma: 'LO 5/2000',
  articulo: '4, párrs. 4 y 5',
  boe: _lorpm,
  cita:
      'Se garantizará especialmente que las declaraciones o interrogatorios (...) se realicen de forma telemática en los '
      'siguientes supuestos, salvo que el Juez, Tribunal o Ministerio Fiscal, mediante resolución motivada, (...) estime '
      'necesaria su presencia física: (...) cuando sean víctimas menores de edad o con discapacidad.',
);

const _lorpm6 = FuenteJuzgado(
  norma: 'LO 5/2000',
  articulo: '6',
  boe: _lorpm,
  cita:
      'Corresponde al Ministerio Fiscal la defensa de los derechos que a los menores reconocen las leyes, así como la '
      'vigilancia de las actuaciones que deban efectuarse en su interés y la observancia de las garantías del '
      'procedimiento, para lo cual dirigirá personalmente la investigación de los hechos (...)',
);

const _lorpm7i = FuenteJuzgado(
  norma: 'LO 5/2000',
  articulo: '7.1 i)',
  boe: _lorpm,
  cita:
      'i) La prohibición de aproximarse o comunicarse con la víctima (...). Esta medida impedirá al menor acercarse a '
      'ellos, en cualquier lugar donde se encuentren, así como a su domicilio, a su centro docente (...) impedirá al '
      'menor establecer con ellas, por cualquier medio de comunicación o medio informático o telemático, contacto '
      'escrito, verbal o visual.',
);

const _lorpm73 = FuenteJuzgado(
  norma: 'LO 5/2000',
  articulo: '7.3',
  boe: _lorpm,
  cita:
      '3. Para la elección de la medida o medidas adecuadas se deberá atender de modo flexible, no sólo a la prueba y '
      'valoración jurídica de los hechos, sino especialmente a la edad, las circunstancias familiares y sociales, la '
      'personalidad y el interés del menor, puestos de manifiesto los dos últimos en los informes de los equipos '
      'técnicos (...). El Juez deberá motivar en la sentencia las razones por las que aplica una determinada medida, así '
      'como el plazo de duración de la misma (...)',
);

const _lorpm17 = FuenteJuzgado(
  norma: 'LO 5/2000',
  articulo: '17.1 (segundo inciso) y 17.2',
  boe: _lorpm,
  cita:
      '1. (...) También deberán notificar inmediatamente el hecho de la detención y el lugar de la custodia a los '
      'representantes legales del menor y al Ministerio Fiscal. (...) 2. Toda declaración del detenido, se llevará a '
      'cabo en presencia de su letrado y de aquéllos que ejerzan la patria potestad, tutela o guarda del menor (...), '
      'salvo que, en este último caso, las circunstancias aconsejen lo contrario. (...) El menor detenido tendrá derecho '
      'a la entrevista reservada con su abogado con anterioridad y al término de la práctica de la diligencia de toma de '
      'declaración.',
);

const _lorpm19 = FuenteJuzgado(
  norma: 'LO 5/2000',
  articulo: '19.2 y 19.6',
  boe: _lorpm,
  cita:
      'se entenderá producida la conciliación cuando el menor reconozca el daño causado y se disculpe ante la víctima, y '
      'ésta acepte sus disculpas (...) 6. En los casos en los que la víctima del delito o falta fuere menor de edad '
      '(...), el compromiso (...) habrá de ser asumido por el representante legal de la misma, con la aprobación del '
      'Juez de Menores.',
);

const _lorpm22 = FuenteJuzgado(
  norma: 'LO 5/2000',
  articulo: '22.1 a), b), d) y e)',
  boe: _lorpm,
  cita:
      '1. Desde el mismo momento de la incoación del expediente, el menor tendrá derecho a: a) Ser informado por el '
      'Juez, el Ministerio Fiscal, o agente de policía de los derechos que le asisten. b) Designar abogado que le '
      'defienda, o a que le sea designado de oficio y a entrevistarse reservadamente con él, incluso antes de prestar '
      'declaración. (...) d) Ser oído por el Juez o Tribunal antes de adoptar cualquier resolución que le concierna '
      'personalmente. e) La asistencia afectiva y psicológica en cualquier estado y grado del procedimiento, con la '
      'presencia de los padres o de otra persona que indique el menor, si el Juez de Menores autoriza su presencia.',
);

const _lorpm23 = FuenteJuzgado(
  norma: 'LO 5/2000',
  articulo: '23.4 b)',
  boe: _lorpm,
  cita:
      '4. El Ministerio Fiscal (...) instará al Juzgado de menores, la práctica de la declaración de la víctima o de un '
      'cualquier otro testigo, con las garantías de la prueba preconstituida (...) b) Cuando se trate de una persona '
      'especialmente vulnerable. En todo caso, tendrá esa consideración toda persona menor de catorce años (...)',
);

const _lorpm28 = FuenteJuzgado(
  norma: 'LO 5/2000',
  articulo: '28.1',
  boe: _lorpm,
  cita:
      '1. El Ministerio Fiscal (...) podrá solicitar del Juez de Menores, en cualquier momento, la adopción de medidas '
      'cautelares (...) para la debida protección de la víctima. Dichas medidas podrán consistir en (...) prohibición de '
      'aproximarse o comunicarse con la víctima (...)',
);

// ------------------------------------------------------------------------------------------------- la sala de vistas

/// Un juicio penal de personas adultas.
const datosSalaVistas = DatosJuzgado(
  titulo: '¿Quién es quién en el juzgado?',
  subtitulo: 'La sala de vistas, durante un juicio. Toca a cada persona para saber quién es y qué hace.',
  descripcion:
      'La sala de vistas de un juzgado durante un juicio. Al fondo, en su mesa, la jueza y la Letrada de la '
      'Administración de Justicia. A la izquierda, el fiscal y la abogada de la víctima; a la derecha, la persona '
      'investigada y su abogado. Todas las mesas están a la misma altura. En el centro, el testigo, en el sitio de quien '
      'declara. De pie, a la derecha, un agente de policía, y delante, el público.',
  roles: [
    RolJuzgado(
      id: 'jueza',
      sitio: 'al fondo, en el centro, en su mesa',
      titulo: 'La jueza',
      corto: 'Jueza',
      quienEs:
          'Es quien dirige el juicio y, al final, decide. Su decisión se llama sentencia, y a la víctima o a su familia '
          'se la tienen que comunicar.',
      queHace:
          'Escucha a todas las partes y mira las pruebas. También tiene que proteger la intimidad de las víctimas. Si '
          'son menores, debe impedir que se difunda cualquier dato que permita saber quiénes son.',
      sabiasQue: 'Si un juicio afecta a la vida de un chico o de una chica, tiene derecho a que le escuchen. Da igual su edad.',
      icono: TuIcono.toga,
      fuentes: [_estatuto7, _estatuto22, _lopjm9],
    ),
    RolJuzgado(
      id: 'fiscal',
      sitio: 'a la izquierda, en la primera silla de la mesa',
      titulo: 'El fiscal',
      corto: 'Fiscal',
      quienEs:
          'Trabaja en la Fiscalía. En un juicio penal, es quien acusa a la persona que cree que ha cometido un delito.',
      queHace:
          'Tiene que procurar que el proceso no haga más daño a las víctimas. Si la víctima es menor de edad, la '
          'Fiscalía lo vigila de forma especial.',
      sabiasQue: 'Cualquier chico o chica puede contar a la Fiscalía que no se respetan sus derechos, para que actúe.',
      icono: TuIcono.ley,
      fuentes: [_estatuto19, _lopjm10],
    ),
    RolJuzgado(
      id: 'abogadaVictima',
      sitio: 'a la izquierda, en la mesa, junto al fiscal',
      titulo: 'La abogada de la víctima',
      corto: 'Abogada de la víctima',
      quienEs: 'Es la abogada que defiende a la víctima. Conoce bien las leyes y la acompaña durante el proceso.',
      queHace:
          'En el juicio habla en nombre de la víctima: hace preguntas y explica a la jueza lo que la víctima pide.',
      sabiasQue:
          'Si la víctima es menor y ha sufrido violencia, puede tener abogado gratis en los casos que marca la ley. Y se '
          'le asigna con urgencia.',
      icono: TuIcono.manoAlzada,
      fuentes: [_lopivi14],
    ),
    RolJuzgado(
      id: 'abogadoDefensa',
      sitio: 'a la derecha, en la silla del extremo de la mesa',
      titulo: 'El abogado de la defensa',
      corto: 'Abogado de la defensa',
      quienEs:
          'Es el abogado de la persona investigada. Todo el mundo tiene derecho a defenderse con la ayuda de un abogado '
          'o de una abogada.',
      queHace: 'Habla con ella y la defiende en el juicio: hace preguntas y da sus razones a la jueza.',
      sabiasQue:
          'Si la declaración de un testigo se graba antes del juicio, el abogado de la defensa tiene que estar presente. '
          'Así es justa para todos.',
      icono: TuIcono.manoAlzada,
      fuentes: [_ce24, _lecrim449bis],
    ),
    RolJuzgado(
      id: 'letrada',
      sitio: 'al fondo, a la derecha de la jueza',
      titulo: 'Letrado o Letrada de la Administración de Justicia',
      corto: 'Letrada de la Administración de Justicia',
      quienEs: 'Es una persona experta en derecho que trabaja en el juzgado. Se sienta junto a la jueza.',
      queHace:
          'Da fe de lo que pasa en el juicio: deja constancia oficial de lo que se hace, por escrito o en una grabación. '
          'Y garantiza que lo grabado no se cambia.',
      icono: TuIcono.expediente,
      fuentes: [_lopj453],
    ),
    RolJuzgado(
      id: 'testigo',
      sitio: 'en el centro, en el sitio de quien declara',
      titulo: 'El testigo',
      corto: 'Testigo',
      quienEs:
          'Es una persona que vio u oyó algo relacionado con el caso. No está acusado de nada: viene a contar lo que '
          'sabe.',
      queHace:
          'Responde a las preguntas que le hacen en el juicio. Si es la víctima, el juzgado se organiza para que no se '
          'cruce con la persona acusada.',
      sabiasQue:
          'Si un testigo tiene menos de 14 años y es un caso de violencia, su entrevista se graba antes. En el juicio se '
          'pone la grabación, y normalmente no tiene que venir.',
      icono: TuIcono.turnoPalabra,
      fuentes: [_estatuto20, _lecrim449ter, _lecrim703bis],
    ),
    RolJuzgado(
      id: 'investigada',
      sitio: 'a la derecha, en la mesa, junto a su abogado',
      titulo: 'La persona investigada',
      corto: 'Persona investigada',
      quienEs:
          'Es la persona a la que se investiga por un delito. En el juicio se la llama «acusada». Para la ley es '
          'inocente mientras no se demuestre lo contrario.',
      queHace:
          'Escucha el juicio junto a su abogado. Tiene derecho a defenderse y a saber de qué se la acusa. No está '
          'obligada a declarar contra sí misma ni a confesarse culpable.',
      sabiasQue: 'Si la detienen, la policía tiene que explicarle sus derechos con palabras que pueda entender.',
      icono: TuIcono.info,
      fuentes: [_ce24, _lecrim520],
    ),
    RolJuzgado(
      id: 'policia',
      sitio: 'de pie, abajo a la derecha',
      titulo: 'El agente de policía',
      corto: 'Policía',
      quienEs: 'Es un agente de policía. Ayuda a investigar los delitos.',
      queHace:
          'Escucha a quien va a contar algo. Cualquier chico o chica puede denunciar sin ir con una persona adulta, y '
          'tener a su lado a alguien de su confianza.',
      sabiasQue:
          'En la comisaría, la policía tiene que evitar que un chico o una chica víctima se encuentre con la persona '
          'investigada.',
      icono: TuIcono.escudo,
      fuentes: [_lopivi50eh, _lopivi50d],
    ),
    RolJuzgado(
      id: 'publico',
      sitio: 'abajo a la izquierda, en el primer banco',
      titulo: 'El público',
      corto: 'Público',
      subtitulo: 'Familias y otras personas',
      quienEs:
          'Son personas que vienen a ver el juicio: familiares, amistades, estudiantes, periodistas… Por regla general, '
          'los juicios son públicos.',
      queHace: 'Miran y escuchan en silencio, sin intervenir en el juicio.',
      sabiasQue: 'Está prohibido publicar el nombre, los datos o las fotos de una víctima menor de edad.',
      icono: TuIcono.personaConfianza,
      fuentes: [_ce24, _lecrim681],
    ),
  ],
);

// ------------------------------------------------------------------------------------------- el Juzgado de Menores

/// La audiencia del caso de Sergio en el Juzgado de Menores.
const datosMenores = DatosJuzgado(
  titulo: '¿Quién es quién en el Juzgado de Menores?',
  subtitulo: 'La audiencia del caso de Sergio. Toca a cada persona para saber quién es y qué hace.',
  descripcion:
      'La sala del Juzgado de Menores durante la audiencia del caso de Sergio. En el estrado, el juez de menores. A la '
      'izquierda, el fiscal y la psicóloga del equipo técnico; a la derecha, la abogada del chico; en el centro, el '
      'chico investigado y su madre. Los bancos del público están vacíos y un cordón cierra el paso.',
  roles: [
    RolJuzgado(
      id: 'juezMenores',
      sitio: 'en el estrado, arriba en el centro',
      titulo: 'El juez de menores',
      corto: 'Juez de menores',
      quienEs:
          'Es el juez que se encarga de los casos de chicos y chicas de 14 a 17 años acusados de un delito. Junto al '
          'fiscal, protege los derechos de las víctimas.',
      queHace:
          'Dirige la audiencia, que es el juicio de menores. Si se demuestra que el chico lo hizo, puede ponerle una '
          'medida: por ejemplo, prohibirle acercarse a la víctima.',
      sabiasQue:
          'Para elegir la medida, piensa sobre todo en la edad del chico, su familia y lo que es mejor para él. Y en la '
          'sentencia tiene que explicar por qué la elige.',
      icono: TuIcono.toga,
      fuentes: [_lorpm1, _lorpm4Victimas, _lorpm7i, _lorpm73],
    ),
    RolJuzgado(
      id: 'fiscalMenores',
      sitio: 'a la izquierda, en la primera silla de la mesa',
      titulo: 'El fiscal de menores',
      corto: 'Fiscal de menores',
      quienEs:
          'Trabaja en la Fiscalía de Menores. Defiende los derechos de los chicos y chicas y vigila que el proceso sea '
          'justo.',
      queHace:
          'Dirige la investigación de lo que pasó. En cualquier momento puede pedir al juez medidas para proteger a '
          'Sergio, como que el chico no se le acerque.',
      sabiasQue:
          'Si el chico reconoce el daño y pide perdón, Sergio decide si acepta sus disculpas: nadie le puede obligar. Si '
          'las acepta, hay conciliación. Como Sergio es menor, el acuerdo lo asumen sus padres y lo aprueba el juez.',
      icono: TuIcono.ley,
      fuentes: [_lorpm6, _lorpm28, _lorpm19],
    ),
    RolJuzgado(
      id: 'letradaMenor',
      sitio: 'a la derecha, en la mesa',
      titulo: 'La abogada del chico',
      corto: 'Abogada del chico',
      subtitulo: 'Letrada del menor',
      quienEs: 'Es la abogada que defiende al chico investigado. Aquí, «letrada» quiere decir abogada.',
      queHace:
          'Le defiende en la audiencia y da sus razones al juez. El chico puede elegirla o le asignan una «de oficio», y '
          'puede hablar con ella a solas.',
      sabiasQue: 'Si detienen a alguien de 14 a 17 años, su abogado o abogada tiene que estar presente cuando declare.',
      icono: TuIcono.manoAlzada,
      fuentes: [_lorpm22, _lorpm17],
    ),
    RolJuzgado(
      id: 'equipoTecnico',
      sitio: 'a la izquierda, en la mesa, junto al fiscal',
      titulo: 'El equipo técnico',
      corto: 'Equipo técnico',
      quienEs:
          'Es una psicóloga del equipo técnico: un grupo de profesionales que ayudan al juez y al fiscal de menores.',
      queHace:
          'En sus informes cuentan cómo es el chico investigado y qué es lo mejor para él. El juez los tiene en cuenta '
          'para elegir la medida.',
      icono: TuIcono.buscar,
      fuentes: [_lorpm73],
    ),
    RolJuzgado(
      id: 'menor',
      sitio: 'en el centro, en el banco, a la izquierda',
      titulo: 'El chico investigado',
      corto: 'Chico investigado',
      quienEs:
          'Es uno de los chicos denunciados en el caso de Sergio. La ley de menores se aplica a chicos y chicas de 14 a '
          '17 años. Para la ley es inocente mientras no se demuestre lo contrario.',
      queHace:
          'Está en la audiencia con su abogada. Tiene derecho a que le expliquen sus derechos y a defenderse. Y el juez '
          'tiene que escucharle antes de decidir algo sobre él.',
      sabiasQue: 'Como todos los menores, tiene derecho a su intimidad y a su propia imagen.',
      icono: TuIcono.info,
      fuentes: [_lorpm1, _ce24, _lorpm22, _lopjm4],
    ),
    RolJuzgado(
      id: 'familia',
      sitio: 'en el centro, en el banco, junto al chico',
      titulo: 'La madre del chico',
      corto: 'Madre del chico',
      subtitulo: 'Su familia',
      quienEs: 'Es la madre del chico investigado. Ha venido a la audiencia para estar con su hijo.',
      queHace:
          'Le acompaña y le apoya. El chico tiene derecho a que estén con él sus padres u otra persona que elija, si el '
          'juez lo autoriza.',
      sabiasQue: 'Los padres tienen que respetar y proteger la intimidad y la imagen de sus hijos.',
      icono: TuIcono.personaConfianza,
      fuentes: [_lorpm22, _lopjm4],
    ),
  ],
  notas: [
    NotaJuzgado(
      titulo: 'Hoy no hay público',
      texto:
          'En esta audiencia no hay público. Jueces y fiscales tienen que proteger la intimidad de las víctimas. Y está '
          'prohibido publicar datos o fotos que permitan saber quién es una víctima menor de edad.',
      icono: TuIcono.candado,
      fuentes: [_estatuto22, _lecrim681],
    ),
    NotaJuzgado(
      titulo: '¿Y Sergio?',
      texto:
          'Lo normal es que no esté en la sala. Como tiene menos de 14 años, la Fiscalía tiene que pedir que su '
          'declaración se grabe antes, con garantías. Y si tuviera que declarar, lo normal es hacerlo a distancia, por '
          'videoconferencia.',
      icono: TuIcono.grabacion,
      fuentes: [_lorpm23, _lorpm4Distancia],
    ),
  ],
);
