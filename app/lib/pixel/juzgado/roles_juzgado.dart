// Textos de «¿Quién es quién en el juzgado?»: quién es y qué hace cada persona de la sala, para chicos y chicas desde
// los 11 años, con la norma y el artículo de donde sale cada frase.
//
// Las citas son literales («(...)» marca lo que se omite) y se comprobaron el 22/10/2026 contra los textos
// consolidados del BOE (boe.es). Las de LOPIVI, art. 14, LECrim, art. 520.2 bis y LO 5/2000, art. 4, son también las de
// docs/MARCO_LEGAL.md. Si un detalle no se podía comprobar, no está.
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter/foundation.dart';

import 'sala_juzgado.dart' show ModoJuzgado;

/// Un artículo de una ley en el BOE, con la [cita] literal en la que se apoya un texto.
@immutable
class FuenteJuzgado {
  const FuenteJuzgado({required this.norma, required this.articulo, required this.cita, required this.boe});

  /// Nombre corto de la norma: «Constitución», «LECrim», «LO 5/2000»…
  final String norma;

  /// El artículo (y el apartado, si lo hay): «117.1», «22.1 b)».
  final String articulo;

  /// El texto literal del BOE. «(...)» marca lo que se omite.
  final String cita;

  /// Identificador de la norma en el BOE: «BOE-A-1978-31229».
  final String boe;

  /// «art. 117.1» o, si es una disposición, «disposición adicional primera».
  String get referencia => articulo.startsWith('disposición') ? articulo : 'art. $articulo';

  /// «Constitución, art. 117.1».
  String get etiqueta => '$norma, $referencia';

  /// El nombre largo de la norma, para quien no sabe qué es «LECrim».
  String get nombreNorma => nombresNormas[norma] ?? norma;

  /// El texto consolidado en el BOE.
  String get url => 'https://www.boe.es/buscar/act.php?id=$boe';
}

/// Nombres largos de las normas que se citan.
const nombresNormas = {
  'Constitución': 'Constitución Española',
  'LOPJ': 'Ley Orgánica 6/1985, del Poder Judicial',
  'LECrim': 'Ley de Enjuiciamiento Criminal',
  'EOMF': 'Ley 50/1981, del Estatuto Orgánico del Ministerio Fiscal',
  'Código Penal': 'Ley Orgánica 10/1995, del Código Penal',
  'LOPIVI': 'Ley Orgánica 8/2021, de protección de la infancia y la adolescencia frente a la violencia',
  'LO 5/2000': 'Ley Orgánica 5/2000, reguladora de la responsabilidad penal de los menores',
  'RD 1774/2004': 'Real Decreto 1774/2004, Reglamento de la Ley Orgánica 5/2000',
  'LO 7/2015': 'Ley Orgánica 7/2015, que modifica la Ley Orgánica del Poder Judicial',
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
    required this.fuentes,
  });

  /// El id de su puesto en la sala («jueza»).
  final String id;

  /// «La jueza».
  final String titulo;

  /// Nombre corto, para las fichas de la sala: «Jueza», «Letrada».
  final String corto;

  /// Otro nombre que le da la ley («Acusación particular»), si lo tiene.
  final String? subtitulo;

  final String quienEs;
  final String queHace;

  /// Un dato más, para quien quiera saber más.
  final String? sabiasQue;

  final IconData icono;

  /// Las normas de las que salen [quienEs], [queHace] y [sabiasQue].
  final List<FuenteJuzgado> fuentes;
}

/// Un aviso sobre la sala (que hoy no hay público, dónde está Sergio…), con su fuente.
@immutable
class NotaJuzgado {
  const NotaJuzgado({required this.titulo, required this.texto, required this.icono, required this.fuente});

  final String titulo;
  final String texto;
  final IconData icono;
  final FuenteJuzgado fuente;
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

  /// El rol [id], o null si no está.
  RolJuzgado? rol(String id) => roles.where((rol) => rol.id == id).firstOrNull;
}

// ----------------------------------------------------------------------------------------------------------- fuentes

const _ce = 'BOE-A-1978-31229';
const _lopj = 'BOE-A-1985-12666';
const _lecrim = 'BOE-A-1882-6036';
const _eomf = 'BOE-A-1982-837';
const _cp = 'BOE-A-1995-25444';
const _lopivi = 'BOE-A-2021-9347';
const _lorpm = 'BOE-A-2000-641';
const _rlorpm = 'BOE-A-2004-15601';
const _lo72015 = 'BOE-A-2015-8167';

const _ce24 = FuenteJuzgado(
  norma: 'Constitución',
  articulo: '24.2',
  boe: _ce,
  cita:
      'Asimismo, todos tienen derecho al Juez ordinario predeterminado por la ley, a la defensa y a la asistencia de '
      'letrado, a ser informados de la acusación formulada contra ellos, a un proceso público sin dilaciones indebidas '
      'y con todas las garantías, a utilizar los medios de prueba pertinentes para su defensa, a no declarar contra sí '
      'mismos, a no confesarse culpables y a la presunción de inocencia.',
);

// ------------------------------------------------------------------------------------------------- la sala de vistas

/// Un juicio penal de personas adultas.
const datosSalaVistas = DatosJuzgado(
  titulo: '¿Quién es quién en el juzgado?',
  subtitulo: 'La sala de vistas, durante un juicio. Toca a cada persona para saber quién es y qué hace.',
  descripcion:
      'La sala de vistas de un juzgado durante un juicio. Al fondo, en el estrado, la jueza y la letrada. A la '
      'izquierda, el fiscal y la abogada de la víctima; a la derecha, la persona investigada y su abogado. En el centro, '
      'el testigo, en el sitio de quien declara. De pie, a la derecha, un agente de policía, y delante, el público.',
  roles: [
    RolJuzgado(
      id: 'jueza',
      titulo: 'La jueza',
      corto: 'Jueza',
      quienEs:
          'Es quien dirige el juicio y, al final, decide. Es independiente: nadie puede darle instrucciones sobre cómo '
          'decidir, y solo obedece a la Constitución y a las leyes.',
      queHace:
          'Mantiene el orden en la sala, escucha a todas las partes y mira las pruebas. Después dicta la sentencia, en '
          'la que tiene que explicar sus razones.',
      sabiasQue: 'Los juicios penales son sobre todo orales: casi todo se dice en voz alta, en la sala.',
      icono: Icons.balance_rounded,
      fuentes: [
        FuenteJuzgado(
          norma: 'LOPJ',
          articulo: '1, 12.3 y 13',
          boe: _lopj,
          cita:
              'La justicia emana del pueblo y se administra en nombre del Rey por Jueces y Magistrados integrantes del '
              'Poder Judicial, independientes, inamovibles, responsables y sometidos únicamente a la Constitución y al '
              'imperio de la ley. / Tampoco podrán los Jueces y Tribunales, órganos de gobierno de los mismos o el '
              'Consejo General del Poder Judicial dictar instrucciones (...) sobre la aplicación o interpretación del '
              'ordenamiento jurídico que lleven a cabo en el ejercicio de su función jurisdiccional. / Todos están '
              'obligados a respetar la independencia de los Jueces y Magistrados.',
        ),
        FuenteJuzgado(
          norma: 'LOPJ',
          articulo: '190.1',
          boe: _lopj,
          cita:
              'Corresponde al Presidente del Tribunal o al juez mantener el orden en la Sala, a cuyo efecto acordará lo '
              'que proceda.',
        ),
        FuenteJuzgado(
          norma: 'LECrim',
          articulo: '741',
          boe: _lecrim,
          cita:
              'El Tribunal, apreciando según su conciencia las pruebas practicadas en el juicio, las razones expuestas '
              'por la acusación y la defensa y lo manifestado por los mismos procesados, dictará sentencia (...)',
        ),
        FuenteJuzgado(
          norma: 'Constitución',
          articulo: '120.2 y 120.3',
          boe: _ce,
          cita:
              '2. El procedimiento será predominantemente oral, sobre todo en materia criminal. 3. Las sentencias serán '
              'siempre motivadas y se pronunciarán en audiencia pública.',
        ),
      ],
    ),
    RolJuzgado(
      id: 'fiscal',
      titulo: 'El fiscal',
      corto: 'Fiscal',
      quienEs:
          'Trabaja en el Ministerio Fiscal (la Fiscalía). Su misión es defender la ley, los derechos de las personas y '
          'el interés de toda la sociedad.',
      queHace:
          'En un juicio penal, acusa a quien cree que ha cometido un delito. Tiene que actuar con objetividad y velar '
          'por que las víctimas y los testigos estén protegidos.',
      sabiasQue:
          'Además de acusar, el fiscal pide que se repare el daño a la víctima, salvo que ella renuncie a eso de forma '
          'expresa.',
      icono: Icons.policy_rounded,
      fuentes: [
        FuenteJuzgado(
          norma: 'Constitución',
          articulo: '124.1',
          boe: _ce,
          cita:
              'El Ministerio Fiscal, sin perjuicio de las funciones encomendadas a otros órganos, tiene por misión '
              'promover la acción de la justicia en defensa de la legalidad, de los derechos de los ciudadanos y del '
              'interés público tutelado por la ley (...)',
        ),
        FuenteJuzgado(
          norma: 'EOMF',
          articulo: '3.4 y 3.10',
          boe: _eomf,
          cita:
              '4. Ejercitar las acciones penales y civiles dimanantes de delitos (...) 10. Velar por la protección '
              'procesal de las víctimas y por la protección de testigos y peritos (...)',
        ),
        FuenteJuzgado(
          norma: 'EOMF',
          articulo: '7',
          boe: _eomf,
          cita:
              'Por el principio de imparcialidad el Ministerio Fiscal actuará con plena objetividad e independencia en '
              'defensa de los intereses que le estén encomendados.',
        ),
        FuenteJuzgado(
          norma: 'LECrim',
          articulo: '108',
          boe: _lecrim,
          cita:
              'La acción civil ha de entablarse juntamente con la penal por el Ministerio Fiscal, haya o no en el '
              'proceso acusador particular; pero si el ofendido renunciare expresamente su derecho de restitución, '
              'reparación o indemnización, el Ministerio Fiscal se limitará a pedir el castigo de los culpables.',
        ),
      ],
    ),
    RolJuzgado(
      id: 'abogadaVictima',
      titulo: 'La abogada de la víctima',
      corto: 'Abogada de la víctima',
      subtitulo: 'Acusación particular',
      quienEs:
          'Es la abogada que defiende a la víctima. Cuando la víctima decide participar en el juicio para acusar, se '
          'dice que es la «acusación particular».',
      queHace:
          'Habla en nombre de la víctima: acusa, propone pruebas, hace preguntas a los testigos y pide que se repare '
          'el daño causado.',
      sabiasQue:
          'Si la víctima es menor y ha sufrido violencia, puede tener abogado gratis en los casos que marca la ley, y '
          'se le asigna con urgencia.',
      icono: Icons.volunteer_activism_rounded,
      fuentes: [
        FuenteJuzgado(
          norma: 'LECrim',
          articulo: '109 bis.1',
          boe: _lecrim,
          cita:
              'Las víctimas del delito que no hubieran renunciado a su derecho podrán ejercer la acción penal en '
              'cualquier momento antes del trámite de calificación del delito (...)',
        ),
        FuenteJuzgado(
          norma: 'LECrim',
          articulo: '110',
          boe: _lecrim,
          cita:
              'Las personas perjudicadas por un delito que no hubieren renunciado a su derecho podrán mostrarse parte '
              'en la causa (...) y ejercitar las acciones civiles que procedan (...)',
        ),
        FuenteJuzgado(
          norma: 'LECrim',
          articulo: '656 y 708',
          boe: _lecrim,
          cita:
              'El Ministerio Fiscal y las partes manifestarán en sus respectivos escritos de calificación las pruebas '
              'de que intenten valerse (...) / (...) la parte que le haya presentado podrá hacerle las preguntas que '
              'tenga por conveniente. Las demás partes podrán dirigirle también las preguntas que consideren oportunas '
              '(...)',
        ),
        FuenteJuzgado(
          norma: 'LOPIVI',
          articulo: '14.1 y 14.3',
          boe: _lopivi,
          cita:
              'Las personas menores de edad víctimas de violencia tienen derecho a la defensa y representación '
              'gratuitas por abogado y procurador de conformidad con lo dispuesto en la Ley 1/1996, de 10 de enero, de '
              'asistencia jurídica gratuita. (...) los Colegios de Abogados adoptarán las medidas necesarias para la '
              'designación urgente de letrado o letrada de oficio (...)',
        ),
      ],
    ),
    RolJuzgado(
      id: 'abogadoDefensa',
      titulo: 'El abogado de la defensa',
      corto: 'Abogado de la defensa',
      quienEs:
          'Es el abogado de la persona investigada. Todo el mundo tiene derecho a defenderse con un abogado: si no elige '
          'uno, se le asigna uno de oficio.',
      queHace:
          'Habla con ella en privado y la defiende en el juicio: propone pruebas, hace preguntas a los testigos y da '
          'sus razones a la jueza.',
      sabiasQue: 'Lo que la persona investigada habla con su abogado es confidencial.',
      icono: Icons.shield_rounded,
      fuentes: [
        _ce24,
        FuenteJuzgado(
          norma: 'LECrim',
          articulo: '118.2 y 118.4',
          boe: _lecrim,
          cita:
              'El derecho de defensa comprende la asistencia letrada de un abogado de libre designación o, en su '
              'defecto, de un abogado de oficio, con el que podrá comunicarse y entrevistarse reservadamente (...) / '
              'Todas las comunicaciones entre el investigado o encausado y su abogado tendrán carácter confidencial.',
        ),
        FuenteJuzgado(
          norma: 'LECrim',
          articulo: '741',
          boe: _lecrim,
          cita:
              'El Tribunal, apreciando según su conciencia las pruebas practicadas en el juicio, las razones expuestas '
              'por la acusación y la defensa (...) dictará sentencia (...)',
        ),
      ],
    ),
    RolJuzgado(
      id: 'letrada',
      titulo: 'La letrada de la Administración de Justicia',
      corto: 'Letrada',
      quienEs:
          'Es una funcionaria experta en derecho que dirige la oficina del juzgado. Antes, este puesto se llamaba '
          '«secretario judicial».',
      queHace:
          'Da fe pública: garantiza que lo que pasa en el juicio queda registrado, en una grabación o en un acta, y que '
          'la grabación es auténtica y está completa.',
      sabiasQue:
          'Si el juicio se graba, no siempre tiene que estar en la sala: con su firma electrónica garantiza que la '
          'grabación es la de verdad.',
      icono: Icons.verified_rounded,
      fuentes: [
        FuenteJuzgado(
          norma: 'LOPJ',
          articulo: '440',
          boe: _lopj,
          cita:
              'Los Letrados de la Administración de Justicia son funcionarios públicos que constituyen un Cuerpo '
              'Superior Jurídico (...) ostentando la dirección de la Oficina judicial.',
        ),
        FuenteJuzgado(
          norma: 'LOPJ',
          articulo: '453.1',
          boe: _lopj,
          cita:
              'Corresponde a los Letrados de la Administración de Justicia, con exclusividad y plenitud, el ejercicio de '
              'la fe pública judicial. En el ejercicio de esta función, dejarán constancia fehaciente de la realización '
              'de actos procesales (...) mediante las oportunas actas y diligencias. (...) En todo caso, el Letrado de '
              'la Administración de Justicia garantizará la autenticidad e integridad de lo grabado o reproducido.',
        ),
        FuenteJuzgado(
          norma: 'LECrim',
          articulo: '743.2',
          boe: _lecrim,
          cita:
              'Siempre que se cuente con los medios tecnológicos necesarios, estos garantizarán la autenticidad e '
              'integridad de lo grabado o reproducido. A tal efecto, el letrado o letrada de la Administración de '
              'Justicia hará uso de la firma electrónica (...). En este caso, la celebración del acto no requerirá la '
              'presencia en la sala del letrado o letrada de la Administración de Justicia salvo que lo hubieran '
              'solicitado las partes (...)',
        ),
        FuenteJuzgado(
          norma: 'LO 7/2015',
          articulo: 'disposición adicional primera',
          boe: _lo72015,
          cita:
              '(...) todas las referencias que se contengan en la Ley Orgánica 6/1985, de 1 de julio, del Poder '
              'Judicial, así como en otras normas jurídicas, a Secretarios judiciales (...) deberán entenderse hechas '
              '(...) a Letrados de la Administración de Justicia (...)',
        ),
      ],
    ),
    RolJuzgado(
      id: 'testigo',
      titulo: 'El testigo',
      corto: 'Testigo',
      quienEs:
          'Es una persona que vio u oyó algo relacionado con el caso. No está acusado de nada: viene a contar lo que '
          'sabe.',
      queHace:
          'Responde a las preguntas de las partes y de la jueza. Tiene que decir la verdad: mentir como testigo en un '
          'juicio es un delito, el falso testimonio.',
      sabiasQue:
          'Si un testigo es menor de 18 años, se puede evitar que vea a la persona acusada; por ejemplo, declarando '
          'desde otra sala por videoconferencia.',
      icono: Icons.record_voice_over_rounded,
      fuentes: [
        FuenteJuzgado(
          norma: 'LECrim',
          articulo: '410',
          boe: _lecrim,
          cita:
              'Todos los que residan en territorio español, nacionales o extranjeros, que no estén impedidos, tendrán '
              'obligación de concurrir al llamamiento judicial para declarar cuanto supieren sobre lo que les fuere '
              'preguntado (...)',
        ),
        FuenteJuzgado(
          norma: 'LECrim',
          articulo: '708',
          boe: _lecrim,
          cita:
              '(...) la parte que le haya presentado podrá hacerle las preguntas que tenga por conveniente. Las demás '
              'partes podrán dirigirle también las preguntas que consideren oportunas (...) El Presidente (...) podrá '
              'dirigir a los testigos las preguntas que estime conducentes (...)',
        ),
        FuenteJuzgado(
          norma: 'Código Penal',
          articulo: '458.1',
          boe: _cp,
          cita:
              'El testigo que faltare a la verdad en su testimonio en causa judicial, será castigado con las penas de '
              'prisión de seis meses a dos años y multa de tres a seis meses.',
        ),
        FuenteJuzgado(
          norma: 'LECrim',
          articulo: '707',
          boe: _lecrim,
          cita:
              '(...) cuando una persona menor de dieciocho años (...) deba intervenir en el acto del juicio, su '
              'declaración se llevará a cabo, cuando resulte necesario para impedir o reducir los perjuicios que para '
              'ella puedan derivar del desarrollo del proceso (...), evitando la confrontación visual con la persona '
              'inculpada. (...) incluyéndose la posibilidad de que los testigos puedan ser oídos sin estar presentes en '
              'la sala mediante la utilización de tecnologías de la comunicación accesible.',
        ),
      ],
    ),
    RolJuzgado(
      id: 'investigada',
      titulo: 'La persona investigada',
      corto: 'Persona investigada',
      quienEs:
          'Es la persona a la que se acusa del delito (en el juicio se la llama «acusada»). Para la ley es inocente '
          'mientras no se demuestre lo contrario.',
      queHace:
          'Escucha el juicio junto a su abogado. Tiene derechos: puede declarar o quedarse en silencio, y no está '
          'obligada a declarar contra sí misma ni a confesarse culpable.',
      sabiasQue:
          'Al final del juicio, la jueza le pregunta si quiere decir algo más: es su derecho a la «última palabra».',
      icono: Icons.person_rounded,
      fuentes: [
        _ce24,
        FuenteJuzgado(
          norma: 'LECrim',
          articulo: '118.1 g) y h)',
          boe: _lecrim,
          cita:
              'g) Derecho a guardar silencio y a no prestar declaración si no desea hacerlo, y a no contestar a alguna o '
              'algunas de las preguntas que se le formulen. h) Derecho a no declarar contra sí mismo y a no confesarse '
              'culpable.',
        ),
        FuenteJuzgado(
          norma: 'LECrim',
          articulo: '701 y 739',
          boe: _lecrim,
          cita:
              '(...) si a propuesta de su defensa el acusado solicitara declarar en último lugar, el Presidente así lo '
              'acordará expresamente. (...) / Terminadas la acusación y la defensa, el Presidente preguntará a los '
              'procesados si tienen algo que manifestar al Tribunal. Al que contestare afirmativamente le será concedida '
              'la palabra. (...)',
        ),
      ],
    ),
    RolJuzgado(
      id: 'policia',
      titulo: 'El agente de policía',
      corto: 'Policía',
      quienEs:
          'Es un agente de policía. Cuando ayuda a jueces y fiscales a investigar un delito, hace de Policía Judicial.',
      queHace:
          'Busca pruebas y lo apunta todo en un informe que se llama atestado. En el juicio puede declarar para contar '
          'lo que averiguó.',
      sabiasQue:
          'Si la policía detiene a alguien, tiene que explicarle sus derechos con palabras que pueda entender según su '
          'edad.',
      icono: Icons.local_police_rounded,
      fuentes: [
        FuenteJuzgado(
          norma: 'LOPJ',
          articulo: '547',
          boe: _lopj,
          cita:
              'La función de la Policía Judicial comprende el auxilio a los juzgados y tribunales y al Ministerio '
              'Fiscal en la averiguación de los delitos y en el descubrimiento y aseguramiento de los delincuentes. '
              '(...)',
        ),
        FuenteJuzgado(
          norma: 'LECrim',
          articulo: '292',
          boe: _lecrim,
          cita:
              'Los funcionarios de Policía judicial extenderán (...) un atestado de las diligencias que practiquen, en '
              'el cual especificarán con la mayor exactitud los hechos por ellos averiguados, insertando las '
              'declaraciones e informes recibidos y anotando todas las circunstancias que hubiesen observado y pudiesen '
              'ser prueba o indicio del delito. (...)',
        ),
        FuenteJuzgado(
          norma: 'LECrim',
          articulo: '717',
          boe: _lecrim,
          cita:
              'Las declaraciones de las Autoridades y funcionarios de Policía judicial tendrán el valor de '
              'declaraciones testificales, apreciables como éstas según las reglas del criterio racional.',
        ),
        FuenteJuzgado(
          norma: 'LECrim',
          articulo: '520.2 bis',
          boe: _lecrim,
          cita:
              'La información a que se refiere el apartado anterior se facilitará en un lenguaje comprensible y que '
              'resulte accesible al destinatario. A estos efectos se adaptará la información a su edad, grado de '
              'madurez, discapacidad y cualquier otra circunstancia personal (...)',
        ),
      ],
    ),
    RolJuzgado(
      id: 'publico',
      titulo: 'El público',
      corto: 'Público',
      subtitulo: 'Familias y otras personas',
      quienEs:
          'Son personas que vienen a ver el juicio: familiares, amistades, estudiantes, periodistas… Por regla general, '
          'los juicios son públicos.',
      queHace:
          'Mira y escucha sin intervenir. La jueza puede hacer salir a quien altere el orden, y también celebrar el '
          'juicio a puerta cerrada para proteger, por ejemplo, la intimidad de la víctima.',
      sabiasQue: 'Está prohibido publicar el nombre, los datos o las fotos de una víctima menor de edad.',
      icono: Icons.groups_rounded,
      fuentes: [
        FuenteJuzgado(
          norma: 'Constitución',
          articulo: '120.1',
          boe: _ce,
          cita:
              'Las actuaciones judiciales serán públicas, con las excepciones que prevean las leyes de procedimiento.',
        ),
        FuenteJuzgado(
          norma: 'LECrim',
          articulo: '680 y 681.1',
          boe: _lecrim,
          cita:
              'Los debates del juicio oral serán públicos, bajo pena de nulidad, sin perjuicio de lo dispuesto en el '
              'artículo siguiente. / El Juez o Tribunal podrá acordar (...) que todos o alguno de los actos o las '
              'sesiones del juicio se celebren a puerta cerrada, cuando así lo exijan (...) la adecuada protección de '
              'los derechos fundamentales de los intervinientes, en particular, el derecho a la intimidad de la víctima '
              '(...)',
        ),
        FuenteJuzgado(
          norma: 'LECrim',
          articulo: '684',
          boe: _lecrim,
          cita:
              'El Presidente llamará al orden a todas las personas que lo alteren, y podrá hacerlas salir del local si '
              'lo considerare oportuno (...)',
        ),
        FuenteJuzgado(
          norma: 'LECrim',
          articulo: '681.3',
          boe: _lecrim,
          cita:
              'Queda prohibida, en todo caso, la divulgación o publicación de información relativa a la identidad de '
              'víctimas menores de edad (...) así como de datos que puedan facilitar su identificación de forma directa '
              'o indirecta (...) así como la obtención, divulgación o publicación de imágenes suyas o de sus familiares.',
        ),
      ],
    ),
  ],
);

// ------------------------------------------------------------------------------------------- el Juzgado de Menores

const _lorpm1 = FuenteJuzgado(
  norma: 'LO 5/2000',
  articulo: '1.1',
  boe: _lorpm,
  cita:
      'Esta Ley se aplicará para exigir la responsabilidad de las personas mayores de catorce años y menores de '
      'dieciocho por la comisión de hechos tipificados como delitos o faltas en el Código Penal o las leyes penales '
      'especiales.',
);

const _lorpm372 = FuenteJuzgado(
  norma: 'LO 5/2000',
  articulo: '37.2',
  boe: _lorpm,
  cita:
      '(...) oyéndose, asimismo, al equipo técnico sobre las circunstancias del menor. A continuación, el Juez oirá al '
      'Ministerio Fiscal, a quien haya ejercitado en su caso la acción penal, al letrado del menor (...) sobre la '
      'valoración de la prueba, su calificación jurídica y la procedencia de las medidas propuestas (...). Por último, '
      'el Juez oirá al menor, dejando el expediente visto para sentencia.',
);

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
      titulo: 'El juez de menores',
      corto: 'Juez de menores',
      quienEs:
          'Es el juez que se encarga de los casos en los que un chico o una chica de 14 a 17 años está acusado de '
          'cometer un delito.',
      queHace:
          'Dirige la audiencia (así se llama aquí el juicio) y escucha a todos; al chico, el último. Si se demuestra que '
          'lo hizo, le pone una medida, como hacer tareas educativas, pensando en su edad, su familia, su forma de ser '
          'y lo que más le conviene.',
      sabiasQue:
          'Una de las medidas son las prestaciones en beneficio de la comunidad: actividades sin cobrar que ayudan a '
          'otras personas. Solo se pueden poner si el chico está de acuerdo.',
      icono: Icons.balance_rounded,
      fuentes: [
        _lorpm1,
        FuenteJuzgado(
          norma: 'LO 5/2000',
          articulo: '2.1',
          boe: _lorpm,
          cita:
              'Los Jueces de Menores serán competentes para conocer de los hechos cometidos por las personas mencionadas '
              'en el artículo 1 de esta Ley, así como para hacer ejecutar las sentencias (...)',
        ),
        FuenteJuzgado(
          norma: 'LO 5/2000',
          articulo: '7.1 k) y l) y 7.3',
          boe: _lorpm,
          cita:
              'k) Prestaciones en beneficio de la comunidad. La persona sometida a esta medida, que no podrá imponerse '
              'sin su consentimiento, ha de realizar las actividades no retribuidas que se le indiquen, de interés '
              'social o en beneficio de personas en situación de precariedad. l) Realización de tareas socio-educativas. '
              '(...) 3. Para la elección de la medida o medidas adecuadas se deberá atender de modo flexible, no sólo a '
              'la prueba y valoración jurídica de los hechos, sino especialmente a la edad, las circunstancias '
              'familiares y sociales, la personalidad y el interés del menor (...)',
        ),
        _lorpm372,
      ],
    ),
    RolJuzgado(
      id: 'fiscalMenores',
      titulo: 'El fiscal de menores',
      corto: 'Fiscal de menores',
      quienEs:
          'Es un fiscal especialista en menores. Defiende los derechos de los chicos y chicas y, junto al juez, vela por '
          'los derechos de las víctimas, como Sergio.',
      queHace:
          'Dirige la investigación y, si hay pruebas, acusa y propone una medida. En todo lo que hace tiene que buscar '
          'el interés superior del menor.',
      sabiasQue:
          'Si el chico reconoce el daño, pide perdón y Sergio acepta sus disculpas, hay conciliación. En los casos '
          'menos graves, la Fiscalía puede entonces no seguir con el expediente.',
      icono: Icons.policy_rounded,
      fuentes: [
        FuenteJuzgado(
          norma: 'LO 5/2000',
          articulo: 'disposición final cuarta, apartado 2',
          boe: _lorpm,
          cita:
              'En todas las Fiscalías existirá una Sección de Menores compuesta por miembros de la Carrera Fiscal, '
              'especialistas (...)',
        ),
        FuenteJuzgado(
          norma: 'LO 5/2000',
          articulo: '4 y 6',
          boe: _lorpm,
          cita:
              'El Ministerio Fiscal y el Juez de Menores velarán en todo momento por la protección de los derechos de '
              'las víctimas (...) / Corresponde al Ministerio Fiscal la defensa de los derechos que a los menores '
              'reconocen las leyes (...) para lo cual dirigirá personalmente la investigación de los hechos (...)',
        ),
        FuenteJuzgado(
          norma: 'LO 5/2000',
          articulo: '30.1',
          boe: _lorpm,
          cita:
              'Acabada la instrucción, el Ministerio Fiscal (...) remitirá al Juzgado de Menores el expediente (...) con '
              'un escrito de alegaciones en el que constará la descripción de los hechos, la valoración jurídica de los '
              'mismos (...) la proposición de alguna medida de las previstas en esta Ley (...)',
        ),
        FuenteJuzgado(
          norma: 'EOMF',
          articulo: '3.13',
          boe: _eomf,
          cita:
              'Ejercer en materia de responsabilidad penal de menores las funciones que le encomiende la legislación '
              'específica, debiendo orientar su actuación a la satisfacción del interés superior del menor.',
        ),
        FuenteJuzgado(
          norma: 'LO 5/2000',
          articulo: '19.1 y 19.2',
          boe: _lorpm,
          cita:
              'También podrá el Ministerio Fiscal desistir de la continuación del expediente (...) a la circunstancia de '
              'que además el menor se haya conciliado con la víctima (...) El desistimiento en la continuación del '
              'expediente sólo será posible cuando el hecho imputado al menor constituya delito menos grave o falta. '
              '2. (...) se entenderá producida la conciliación cuando el menor reconozca el daño causado y se disculpe '
              'ante la víctima, y ésta acepte sus disculpas (...)',
        ),
      ],
    ),
    RolJuzgado(
      id: 'letradaMenor',
      titulo: 'La abogada del chico',
      corto: 'Abogada del chico',
      subtitulo: 'Letrada del menor',
      quienEs:
          'Es la abogada que defiende al chico investigado. Él tiene derecho a tener abogado desde el principio y a '
          'hablar con su abogada en privado.',
      queHace: 'Le defiende en la audiencia: propone pruebas, opina sobre las medidas que se piden y da sus razones al juez.',
      sabiasQue: 'Si el chico y su familia no eligen abogado, se le nombra uno de oficio, especialista en menores.',
      icono: Icons.shield_rounded,
      fuentes: [
        FuenteJuzgado(
          norma: 'LO 5/2000',
          articulo: '22.1 b) y 22.2',
          boe: _lorpm,
          cita:
              'Desde el mismo momento de la incoación del expediente, el menor tendrá derecho a: (...) b) Designar '
              'abogado que le defienda, o a que le sea designado de oficio y a entrevistarse reservadamente con él, '
              'incluso antes de prestar declaración. (...) 2. (...) de no hacerlo, se le nombrará de oficio de entre los '
              'integrantes del turno de especialistas del correspondiente Colegio de Abogados.',
        ),
        FuenteJuzgado(
          norma: 'LO 5/2000',
          articulo: '31',
          boe: _lorpm,
          cita:
              '(...) el secretario judicial dará traslado de todo lo actuado al letrado del menor (...) para que en un '
              'plazo de cinco días hábiles formule a su vez escrito de alegaciones y proponga la prueba que considere '
              'pertinente.',
        ),
        _lorpm372,
      ],
    ),
    RolJuzgado(
      id: 'equipoTecnico',
      titulo: 'El equipo técnico',
      corto: 'Equipo técnico',
      quienEs:
          'Son profesionales de la psicología, la educación y el trabajo social que ayudan al juez y al fiscal de '
          'menores.',
      queHace:
          'Estudian cómo está el chico: su situación psicológica, sus estudios, su familia y su entorno. Lo explican en '
          'un informe y en la audiencia, para ayudar a elegir la medida que más le conviene.',
      sabiasQue:
          'Si lo ven bueno para el chico, pueden proponer que repare el daño o que se concilie con la víctima. Cuando '
          'hay mediación, son quienes la llevan.',
      icono: Icons.psychology_rounded,
      fuentes: [
        FuenteJuzgado(
          norma: 'RD 1774/2004',
          articulo: '4.1',
          boe: _rlorpm,
          cita:
              'Los equipos técnicos estarán formados por psicólogos, educadores y trabajadores sociales cuya función es '
              'asistir técnicamente en las materias propias de sus disciplinas profesionales a los jueces de menores y '
              'al Ministerio Fiscal, elaborando los informes, efectuando las propuestas (...)',
        ),
        FuenteJuzgado(
          norma: 'LO 5/2000',
          articulo: '27.1 y 27.3',
          boe: _lorpm,
          cita:
              '(...) la elaboración de un informe (...) sobre la situación psicológica, educativa y familiar del menor, '
              'así como sobre su entorno social (...) 3. De igual modo, el equipo técnico informará, si lo considera '
              'conveniente y en interés del menor, sobre la posibilidad de que éste efectúe una actividad reparadora o '
              'de conciliación con la víctima (...)',
        ),
        FuenteJuzgado(
          norma: 'LO 5/2000',
          articulo: '19.3',
          boe: _lorpm,
          cita:
              'El correspondiente equipo técnico realizará las funciones de mediación entre el menor y la víctima o '
              'perjudicado (...)',
        ),
        _lorpm372,
      ],
    ),
    RolJuzgado(
      id: 'menor',
      titulo: 'El chico investigado',
      corto: 'Chico investigado',
      quienEs:
          'Es uno de los chicos denunciados en el caso de Sergio. La ley de menores se aplica a chicos y chicas de 14 a '
          '17 años. Para la ley es inocente mientras no se demuestre lo contrario.',
      queHace:
          'Está en la audiencia con su abogada y puede estar acompañado de su familia. Tiene derecho a que le expliquen '
          'sus derechos y de qué se le acusa, a defenderse y a ser oído: el juez le escucha el último.',
      sabiasQue: 'Los medios de comunicación nunca pueden sacar imágenes suyas ni datos que permitan saber quién es.',
      icono: Icons.person_rounded,
      fuentes: [
        _lorpm1,
        _ce24,
        FuenteJuzgado(
          norma: 'LO 5/2000',
          articulo: '22.1 a), b) y d)',
          boe: _lorpm,
          cita:
              'Desde el mismo momento de la incoación del expediente, el menor tendrá derecho a: a) Ser informado por el '
              'Juez, el Ministerio Fiscal, o agente de policía de los derechos que le asisten. b) Designar abogado que '
              'le defienda (...) d) Ser oído por el Juez o Tribunal antes de adoptar cualquier resolución que le '
              'concierna personalmente.',
        ),
        FuenteJuzgado(
          norma: 'LO 5/2000',
          articulo: '35 y 36.1',
          boe: _lorpm,
          cita:
              '1. La audiencia se celebrará con asistencia (...) del propio menor, el cual podrá estar acompañado de sus '
              'representantes legales, salvo que el Juez (...) acuerde lo contrario. (...) 2. (...) en ningún caso se '
              'permitirá que los medios de comunicación social obtengan o difundan imágenes del menor ni datos que '
              'permitan su identificación. / El secretario judicial informará al menor expedientado, en un lenguaje '
              'comprensible y adaptado a su edad, de las medidas (...) solicitadas (...) así como de los hechos y de la '
              'causa en que se funden.',
        ),
        _lorpm372,
      ],
    ),
    RolJuzgado(
      id: 'familia',
      titulo: 'Su familia',
      corto: 'Su familia',
      subtitulo: 'Su madre',
      quienEs:
          'Es su madre. El chico tiene derecho a que sus padres, u otra persona que él elija, le den apoyo durante el '
          'proceso, si el juez lo autoriza.',
      queHace:
          'Puede acompañarle durante la audiencia, salvo que el juez decida lo contrario. Y si hay daños que reparar, '
          'sus padres responden junto a él.',
      icono: Icons.family_restroom_rounded,
      fuentes: [
        FuenteJuzgado(
          norma: 'LO 5/2000',
          articulo: '22.1 e)',
          boe: _lorpm,
          cita:
              'e) La asistencia afectiva y psicológica en cualquier estado y grado del procedimiento, con la presencia '
              'de los padres o de otra persona que indique el menor, si el Juez de Menores autoriza su presencia.',
        ),
        FuenteJuzgado(
          norma: 'LO 5/2000',
          articulo: '35.1',
          boe: _lorpm,
          cita:
              'La audiencia se celebrará con asistencia (...) del propio menor, el cual podrá estar acompañado de sus '
              'representantes legales, salvo que el Juez, oídos los citados Ministerio Fiscal, letrado del menor y '
              'representante del equipo técnico, acuerde lo contrario. (...)',
        ),
        FuenteJuzgado(
          norma: 'LO 5/2000',
          articulo: '61.3',
          boe: _lorpm,
          cita:
              'Cuando el responsable de los hechos cometidos sea un menor de dieciocho años, responderán solidariamente '
              'con él de los daños y perjuicios causados sus padres, tutores, acogedores y guardadores legales o de '
              'hecho, por este orden. (...)',
        ),
      ],
    ),
  ],
  notas: [
    NotaJuzgado(
      titulo: 'Hoy no hay público',
      texto:
          'El juez de menores puede decidir que la audiencia no sea pública, para proteger al chico o a la víctima. Y los '
          'medios de comunicación nunca pueden difundir imágenes ni datos que permitan saber quién es el menor.',
      icono: Icons.lock_rounded,
      fuente: FuenteJuzgado(
        norma: 'LO 5/2000',
        articulo: '35.2',
        boe: _lorpm,
        cita:
            'El Juez podrá acordar, en interés de la persona imputada o de la víctima, que las sesiones no sean públicas '
            'y en ningún caso se permitirá que los medios de comunicación social obtengan o difundan imágenes del menor '
            'ni datos que permitan su identificación.',
      ),
    ),
    NotaJuzgado(
      titulo: '¿Y Sergio?',
      texto:
          'No tiene que estar en la sala. Como es menor, lo normal es que declare a distancia, por videoconferencia.',
      icono: Icons.videocam_rounded,
      fuente: FuenteJuzgado(
        norma: 'LO 5/2000',
        articulo: '4',
        boe: _lorpm,
        cita:
            'Se garantizará especialmente que las declaraciones o interrogatorios de las partes acusadoras, testigos o '
            'peritos se realicen de forma telemática en los siguientes supuestos, salvo que el Juez, Tribunal o '
            'Ministerio Fiscal, mediante resolución motivada, en atención a las circunstancias del caso concreto, estime '
            'necesaria su presencia física: Cuando sean (...) víctimas menores de edad (...)',
      ),
    ),
  ],
);
