import 'package:flutter/foundation.dart';

import 'modelos.dart';

// Lo que «Mi situación» (features/situacion) añade a la línea de pasos para una persona concreta: cómo prefiere que se
// lo cuenten, con quién irá y, en cada paso, lo que cambia «para ti», qué llevar, las palabras que oirá, un ejemplo de
// «Vive el caso» y la duda que se lleva escrita a Pregunta. La línea de pasos no sabe de tickets ni de contenido: le
// llega todo ya resuelto.

/// Cómo prefiere que se lo cuenten (pregunta opcional de «Tu ticket»).
enum EstiloExplicacion {
  /// Lo justo: «Qué pasa» se queda en su primera frase, con «Leer todo».
  corto('corto', 'Corto', 'Lo justo, en pocas palabras'),

  /// Con un ejemplo de los casos de «Vive el caso» en cada paso y en cada derecho.
  ejemplos('ejemplos', 'Con ejemplos', 'Con casos como los de «Vive el caso»'),

  /// Un paso cada vez: se abre el de tu momento y cada paso abierto lleva «Siguiente paso».
  pasoAPaso('paso_a_paso', 'Paso a paso', 'Un paso cada vez, sin prisa');

  const EstiloExplicacion(this.valor, this.etiqueta, this.explicacion);

  /// Lo que se guarda en el móvil.
  final String valor;
  final String etiqueta;
  final String explicacion;

  /// El estilo guardado como [valor], o null si no es ninguno.
  static EstiloExplicacion? deValor(Object? valor) => values.where((e) => e.valor == valor).firstOrNull;
}

/// Una nota «para ti» de un paso, ya preparada: el texto con tu edad puesta y sus fuentes. Un [consejo] es práctico, no
/// jurídico, y no lleva fuente.
@immutable
class NotaParaTi {
  const NotaParaTi({required this.texto, this.fuentes = const [], this.consejo = false});

  final String texto;
  final List<String> fuentes;
  final bool consejo;
}

/// Algo que llevar el día de la cita (un consejo práctico).
@immutable
class CosaQueLlevar {
  const CosaQueLlevar({required this.id, required this.texto});

  final String id;
  final String texto;
}

/// Lo que «Mi situación» añade a un paso del itinerario, ya resuelto para quien usa la app.
@immutable
class ExtrasPaso {
  const ExtrasPaso({
    this.enSala = false,
    this.esCita = false,
    this.duda,
    this.palabras = const [],
    this.llevar = const [],
    this.ejemplo,
    this.paraTi = const [],
    this.noEsParaTi,
  });

  /// El paso es en estrados (la sala de vistas): allí sí se lleva toga, y los personajes salen con ella. Fuera de la
  /// sala (la Sala Gesell, la Fiscalía, los pasillos) nadie la lleva (Reglamento 2/2005 del CGPJ, art. 33).
  final bool enSala;

  /// Es el paso de una cita (el día que te escuchan o el juicio): ahí se dice con quién irás.
  final bool esCita;

  /// La pregunta que se lleva escrita a Pregunta con «Pregúntaselo a TuTurno».
  final String? duda;

  /// Términos del glosario que se oyen en este paso (además de los que salen en su texto).
  final List<String> palabras;

  final List<CosaQueLlevar> llevar;

  /// Un ejemplo de «Vive el caso» (se enseña con [EstiloExplicacion.ejemplos]).
  final String? ejemplo;

  /// Lo que cambia para ti en este paso, por tu edad o por tu ticket.
  final List<NotaParaTi> paraTi;

  /// Si por tu edad este paso no es para ti, por qué («Este paso es para chicos y chicas de 14 a 17 años»): se enseña
  /// igual, atenuado, para que sepas qué pasa.
  final String? noEsParaTi;
}

/// Lo que la línea de pasos sabe de quien la mira. Sin ella (null), la línea es la general de siempre.
@immutable
class PersonalizacionLinea {
  const PersonalizacionLinea({
    this.extras = const {},
    this.estilo,
    this.conQuien,
    this.acompanantes = const {},
    this.alPreguntar,
  });

  /// Extras de cada paso, por el id del paso («P3»).
  final Map<String, ExtrasPaso> extras;

  final EstiloExplicacion? estilo;

  /// Con quién irá, ya en una frase: «tu familia y una persona de confianza». Sale en los pasos de una cita.
  final String? conQuien;

  /// Con quién irá, con los valores de «Tu ticket» ('familia', 'confianza', 'abogado', 'aun_no_lo_se'): para que en
  /// «Quién estará» el personaje de «Vive el caso» se parezca a quien le acompaña (con su familia, los padres de
  /// Sergio; no Elena, la tía de Lucía).
  final Set<String> acompanantes;

  /// «Pregúntaselo a TuTurno»: abre Pregunta con [duda] escrita. Sin él, el botón no sale.
  final void Function(Paso paso, String duda)? alPreguntar;

  ExtrasPaso extrasDe(Paso paso) => extras[paso.id] ?? const ExtrasPaso();
}

/// La duda que se lleva a Pregunta desde [paso] si el contenido no trae una.
String dudaPorDefecto(Paso paso) => '¿Me explicas qué pasa en el paso «${paso.nombre}»?';
