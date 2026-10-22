import 'package:flutter/foundation.dart';

import '../../core/entrada.dart';
import '../pasos/pasos.dart';
import 'contenido.dart';
import 'mi_ticket.dart';
import 'papel.dart';

// La personalización de «Mi situación»: de tu ticket (edad, tipo de proceso, papel, momento, con quién irás, qué te
// preocupa, cómo prefieres que te lo cuente y tu día) a lo que ves: el saludo, las notas «Para ti», los pasos de tu
// caso, tus derechos y las respuestas a lo que te preocupa. Son funciones puras: se prueban sin pantalla.

/// Todo lo que «Mi situación» sabe de quien la mira, para el papel de la pantalla.
@immutable
class PerfilSituacion {
  const PerfilSituacion({
    required this.papel,
    required this.hoy,
    this.entrada = const Entrada(),
    this.ticket = const MiTicket(),
  });

  /// El papel que se está mirando (el de la ruta).
  final PapelSituacion papel;
  final Entrada entrada;
  final MiTicket ticket;

  /// Hoy, a cualquier hora (para la cuenta atrás de «Tu día»).
  final DateTime hoy;

  int? get edad => entrada.edad;
  Procedimiento? get procedimiento => entrada.procedimiento;

  /// El papel que dice el ticket (null si no lo dice).
  PapelSituacion? get papelDelTicket => PapelSituacion.deEntrada(entrada.rol);

  /// Está mirando el papel de su ticket.
  bool get esSuPapel => papelDelTicket == papel;

  /// Está mirando otro papel que no es el de su ticket.
  bool get miraOtroPapel => papelDelTicket != null && papelDelTicket != papel;

  /// El momento que marca «Estás aquí» (solo en su papel, o si el ticket no dice papel).
  Fase? get fase => faseDeEntrada(entrada, papel.id);

  /// El ticket dice algo que cambia lo que se enseña.
  bool get personalizado => edad != null || esSuPapel || procedimiento != null || fase != null || !ticket.sinRespuestas;

  /// Días que faltan para la cita (0 = hoy; negativo = ya pasó). null si no hay fecha.
  int? get diasParaLaCita {
    final fecha = ticket.fecha;
    if (fecha == null) return null;
    final dia = DateTime(hoy.year, hoy.month, hoy.day);
    return DateTime.utc(
      fecha.year,
      fecha.month,
      fecha.day,
    ).difference(DateTime.utc(dia.year, dia.month, dia.day)).inDays;
  }

  /// «Modo día»: hoy es el día de la cita.
  bool get esElDia => diasParaLaCita == 0;

  bool cumple(Condicion condicion, {bool edadDesconocidaVale = true}) => condicion.cumple(
    papel: papel,
    edad: edad,
    procedimiento: procedimiento,
    fase: fase,
    preocupacionesDelTicket: ticket.preocupaciones,
    conQuienDelTicket: ticket.conQuien,
    edadDesconocidaVale: edadDesconocidaVale,
  );
}

/// La ruta de Mi situación que toca según el ticket, o null si el ticket no dice papel (entonces, el selector).
String? rutaSituacionDe(Entrada entrada) => PapelSituacion.deEntrada(entrada.rol)?.ruta;

/// «Tu camino como víctima» si el ticket dice papel; si no, null.
String? tituloCaminoDe(Entrada entrada) => PapelSituacion.deEntrada(entrada.rol)?.tituloCamino;

/// Cambia {edad} por la edad. null si el texto la necesita y no la sabemos.
String? conEdad(String texto, int? edad) {
  if (!texto.contains('{edad}')) return texto;
  if (edad == null) return null;
  return texto.replaceAll('{edad}', '$edad');
}

/// El resumen del ticket: «13 años · Penal · Víctima · Durante». Lo que no se ha respondido no sale; vacío si no hay
/// nada.
String resumenTicket(Entrada entrada) => [
  if (entrada.edad != null) '${entrada.edad} años',
  if (entrada.procedimiento != null && entrada.procedimiento != Procedimiento.noLoSe) entrada.procedimiento!.etiqueta,
  if (entrada.rol != null && entrada.rol != RolEntrada.noLoSe) entrada.rol!.etiqueta,
  if (entrada.fase != null) entrada.fase!.etiqueta,
].join(' · ');

/// El saludo de la portada de Mi situación, que cambia con el ticket: un título corto y una frase. Con la cita cerca,
/// la fecha, no cuánto falta (producto: nada de cuentas atrás que agobien). Solo dice «Abajo tienes qué llevar» o
/// «Abajo te respondo» si abajo hay algo ([hayQueLlevar], [hayRespuestas]).
({String titulo, String texto}) saludoPara(PerfilSituacion p, {bool hayQueLlevar = true, bool hayRespuestas = true}) {
  final dias = p.diasParaLaCita;
  final fecha = p.ticket.fecha;
  final titulo = switch (dias) {
    1 => 'Mañana es tu día',
    final int d when d > 1 && d <= 30 && fecha != null => 'Tu cita: ${fechaEnFrase(fecha)}',
    _ => switch (p.fase) {
      Fase.antes => 'Vamos a prepararlo con calma',
      Fase.durante => 'Vamos paso a paso',
      Fase.despues => 'Vamos a ver lo que viene ahora',
      null => p.personalizado ? 'Esta es tu guía' : 'Esta es una guía general',
    },
  };
  if (!p.personalizado) {
    return (
      titulo: titulo,
      texto:
          'Si rellenas tu ticket (tu edad, tu papel, el momento…), te la adapto. No te pido tu nombre ni lo que pasó.',
    );
  }
  // Frases cortas (lectura fácil): para quién y cómo, tu día, con quién irás y lo que te preocupa.
  final frases = <String>[];
  final edad = p.edad;
  final como = switch (p.ticket.estilo) {
    EstiloExplicacion.corto => 'corto y claro',
    EstiloExplicacion.ejemplos => 'con ejemplos de «Vive el caso»',
    EstiloExplicacion.pasoAPaso => 'paso a paso',
    null => null,
  };
  if (p.miraOtroPapel) frases.add('Estás mirando otro camino: «${p.papel.nombre}».');
  final comoYPara = [if (edad != null) 'para alguien de $edad años', ?como].join(', ');
  frases.add(comoYPara.isEmpty ? 'Te explico cada paso con lo que dice la ley.' : 'Te lo explico $comoYPara.');
  if (dias != null && dias > 0 && dias <= 30 && hayQueLlevar) {
    frases.add('Abajo tienes qué llevar ese día.');
  }
  final con = p.ticket.conQuienEnFrase;
  if (con != null) frases.add('Irás con $con.');
  if (p.ticket.preocupaciones.isNotEmpty && hayRespuestas) frases.add('Abajo te respondo a lo que te preocupa.');
  return (titulo: titulo, texto: frases.join(' '));
}

/// «jueves 24 de octubre», para dentro de una frase.
String fechaEnFrase(DateTime dia) => '${_diasSemana[dia.weekday - 1]} ${dia.day} de ${_meses[dia.month - 1]}';

const _diasSemana = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// Cuánto falta, solo dentro de «Tu día»: «Es hoy», «Es mañana», «Faltan 3 días»… null si no hay fecha.
String? cuentaAtras(PerfilSituacion p) => switch (p.diasParaLaCita) {
  null => null,
  0 => 'Es hoy',
  1 => 'Es mañana',
  final int d when d > 1 => 'Faltan $d días',
  final int d when d == -1 => 'Fue ayer',
  final int d => 'Fue hace ${-d} días',
};

/// Una nota «Para ti» de la cabecera, ya preparada.
@immutable
class NotaPreparada {
  const NotaPreparada({required this.titulo, required this.nota, this.enlace});

  final String titulo;
  final NotaParaTi nota;

  /// Otro papel al que lleva (su ruta), si lleva a alguno.
  final String? enlace;
}

/// Las notas «Para ti» que tocan (como mucho [maximo]): las de la edad solo si la sabemos.
List<NotaPreparada> notasPara(ContenidoSituacion contenido, PerfilSituacion p, {int maximo = 2}) {
  final salida = <NotaPreparada>[];
  for (final nota in contenido.notas) {
    if (!p.cumple(nota.punto.condicion, edadDesconocidaVale: false)) continue;
    final texto = conEdad(nota.punto.texto, p.edad);
    if (texto == null) continue;
    final destino = PapelSituacion.deId(nota.enlace);
    if (destino == p.papel) continue;
    salida.add(
      NotaPreparada(
        titulo: nota.titulo,
        nota: NotaParaTi(texto: texto, fuentes: nota.punto.fuentes, consejo: nota.punto.consejo),
        enlace: destino?.ruta,
      ),
    );
    if (salida.length == maximo) break;
  }
  return salida;
}

/// Lo que «Mi situación» añade a cada paso de [p.papel], ya resuelto: lo que cambia para ti (con tu edad puesta),
/// qué llevar, las palabras, el ejemplo, la duda para Pregunta y si el paso no es para tu edad.
Map<String, ExtrasPaso> extrasPara(ContenidoSituacion contenido, PerfilSituacion p) {
  final delPapel = contenido.pasos[p.papel.id] ?? const <String, ExtrasPasoContenido>{};
  final edad = p.edad;
  return {
    for (final MapEntry(key: id, value: e) in delPapel.entries)
      id: ExtrasPaso(
        enSala: e.lugar == 'sala',
        esCita: e.esCita,
        duda: e.duda,
        palabras: e.palabras,
        ejemplo: e.ejemplo,
        llevar: [
          for (final cosa in e.llevar)
            if (contenido.llevar[cosa] case final String texto) CosaQueLlevar(id: cosa, texto: texto),
        ],
        paraTi: [
          for (final punto in e.paraTi)
            if (p.cumple(punto.condicion, edadDesconocidaVale: false))
              if (conEdad(punto.texto, edad) case final String texto)
                NotaParaTi(texto: texto, fuentes: punto.fuentes, consejo: punto.consejo),
        ],
        noEsParaTi: _noEsParaTi(e, edad),
      ),
  };
}

String? _noEsParaTi(ExtrasPasoContenido e, int? edad) {
  if (edad == null) return null;
  final desde = e.desdeEdad;
  final hasta = e.hastaEdad;
  final fuera = (desde != null && edad < desde) || (hasta != null && edad > hasta);
  if (!fuera) return null;
  if (desde != null && hasta != null) return 'Este paso es para chicos y chicas de $desde a $hasta años';
  if (desde != null) return 'Este paso es para chicos y chicas de $desde a 17 años';
  return 'Este paso es para chicos y chicas de hasta $hasta años';
}

/// Las cosas que llevar el día de la cita: las de los pasos con cita del papel, sin repetir. Si el papel no tiene
/// ninguna, todo el catálogo.
List<CosaQueLlevar> cosasDelDia(ContenidoSituacion contenido, PapelSituacion papel) {
  final delPapel = contenido.pasos[papel.id] ?? const <String, ExtrasPasoContenido>{};
  final ids = <String>[];
  for (final extras in delPapel.values) {
    if (!extras.esCita) continue;
    for (final id in extras.llevar) {
      if (!ids.contains(id) && contenido.llevar.containsKey(id)) ids.add(id);
    }
  }
  if (ids.isEmpty) ids.addAll(contenido.llevar.keys);
  return [for (final id in ids) CosaQueLlevar(id: id, texto: contenido.llevar[id]!)];
}

/// Un derecho para ti, con por qué sale.
@immutable
class DerechoParaTi {
  const DerechoParaTi({
    required this.derecho,
    this.porTuEdad = false,
    this.porLoQueTePreocupa = false,
    this.etiquetaEdad,
  });

  final Derecho derecho;

  /// Sale por tu edad (y la sabemos).
  final bool porTuEdad;

  /// Tiene que ver con algo que te preocupa.
  final bool porLoQueTePreocupa;

  /// Con la edad sin decir, la condición de edad («Si tienes menos de 14 años»).
  final String? etiquetaEdad;
}

/// Tus derechos, filtrados por tu papel, tu edad, tu momento y lo que te preocupa. Van primero los que son justo de
/// lo que te preocupa (los que solo salen si te preocupa algo, como quitar fotos de internet), después los que tienen
/// que ver con ello y, dentro de cada grupo, antes los de tu edad. Si empatan, el orden del contenido.
List<DerechoParaTi> derechosPara(ContenidoSituacion contenido, PerfilSituacion p) {
  final preocupa = p.ticket.preocupaciones;
  final candidatos = <DerechoParaTi>[
    for (final d in contenido.derechos)
      if (p.cumple(d.condicion))
        DerechoParaTi(
          derecho: d,
          porTuEdad: d.condicion.tieneEdad && p.edad != null,
          porLoQueTePreocupa: d.relacionadas.any(preocupa.contains),
          etiquetaEdad: p.edad == null ? d.condicion.etiquetaEdad : null,
        ),
  ];
  int puntos(DerechoParaTi d) =>
      (d.derecho.condicion.preocupaciones != null ? 4 : 0) + (d.porLoQueTePreocupa ? 2 : 0) + (d.porTuEdad ? 1 : 0);
  final indice = {for (final (i, d) in candidatos.indexed) d: i};
  return [...candidatos]..sort((a, b) {
    final diferencia = puntos(b).compareTo(puntos(a));
    return diferencia != 0 ? diferencia : indice[a]!.compareTo(indice[b]!);
  });
}

/// Una respuesta a algo que te preocupa, con los puntos que te tocan.
@immutable
class RespuestaParaTi {
  const RespuestaParaTi({
    required this.preocupacion,
    required this.titulo,
    required this.puntos,
    this.ideas = const [],
  });

  final Preocupacion preocupacion;
  final String titulo;
  final List<NotaParaTi> puntos;
  final List<String> ideas;
}

/// Las respuestas a lo que te preocupa, una por preocupación de tu ticket (en el orden de siempre). Los puntos que
/// dependen de la edad salen solo si la sabemos y te toca.
List<RespuestaParaTi> respuestasPara(ContenidoSituacion contenido, PerfilSituacion p) => [
  for (final preocupacion in p.ticket.preocupacionesOrdenadas)
    if (contenido.preocupaciones[preocupacion] case final RespuestaPreocupacion r)
      RespuestaParaTi(
        preocupacion: preocupacion,
        titulo: r.titulo,
        puntos: [
          for (final punto in r.puntos)
            if (p.cumple(punto.condicion, edadDesconocidaVale: false))
              NotaParaTi(texto: punto.texto, fuentes: punto.fuentes, consejo: punto.consejo),
        ],
        ideas: r.ideasPregunta,
      ),
];

/// Ideas de preguntas para ti (por lo que te preocupa), sin repetir y como mucho [maximo].
List<String> ideasParaTi(ContenidoSituacion contenido, MiTicket ticket, {int maximo = 6}) {
  final salida = <String>[];
  for (final preocupacion in ticket.preocupacionesOrdenadas) {
    for (final idea in contenido.preocupaciones[preocupacion]?.ideasPregunta ?? const <String>[]) {
      if (!salida.contains(idea)) salida.add(idea);
      if (salida.length == maximo) return salida;
    }
  }
  return salida;
}
