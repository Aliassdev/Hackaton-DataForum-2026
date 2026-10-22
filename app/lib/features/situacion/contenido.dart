import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entrada.dart';
import '../../core/providers.dart';
import '../pasos/fuentes_paso.dart' show CitaPaso;
import 'mi_ticket.dart';
import 'papel.dart';

// Contenido de «Mi situación» (assets/mock/content/situacion/, o assets/content/situacion/ cuando exista): derechos,
// preocupaciones respondidas, lo que se añade a cada paso y las notas «Para ti». Cada afirmación jurídica sale de
// docs/MARCO_LEGAL.md con su artículo y solo se enseña si está validada y tiene fuente (como el resto del contenido);
// los consejos prácticos ("consejo": true) no son afirmaciones jurídicas y se enseñan marcados como «Consejo».

/// Carpeta del contenido de Mi situación dentro del contenido de la app.
const carpetaSituacion = 'situacion';

/// A quién va dirigido un elemento del contenido. Lo que es null no pone condiciones.
@immutable
class Condicion {
  const Condicion({
    this.papeles,
    this.edadMin,
    this.edadMax,
    this.procedimientos,
    this.fases,
    this.preocupaciones,
    this.conQuien,
  });

  factory Condicion.fromJson(Map<String, dynamic> json, {bool preocupacionesObligatorias = true}) {
    Set<T>? conjunto<T>(Object? lista, T? Function(Object?) leer) {
      if (lista is! List) return null;
      final valores = <T>{for (final e in lista) ?leer(e)};
      return valores.isEmpty ? null : Set.unmodifiable(valores);
    }

    int? edad(Object? v) => v is num ? v.toInt() : null;
    return Condicion(
      papeles: conjunto(json['papeles'], (v) => v is String ? PapelSituacion.deId(v) : null),
      edadMin: edad(json['edad_min']),
      edadMax: edad(json['edad_max']),
      procedimientos: conjunto(
        json['procedimientos'],
        (v) => Procedimiento.values.where((p) => p.valor == v).firstOrNull,
      ),
      fases: conjunto(json['fases'], (v) => Fase.values.where((f) => f.valor == v).firstOrNull),
      preocupaciones: preocupacionesObligatorias ? conjunto(json['preocupaciones'], Preocupacion.deValor) : null,
      conQuien: conjunto(json['con_quien'], (v) => Acompanante.values.where((a) => a.valor == v).firstOrNull),
    );
  }

  final Set<PapelSituacion>? papeles;
  final int? edadMin;
  final int? edadMax;

  /// Solo para estos tipos de proceso (si no se sabe el tipo, no sale).
  final Set<Procedimiento>? procedimientos;

  /// Solo en estos momentos (si no se sabe el momento, sale).
  final Set<Fase>? fases;

  /// Solo si le preocupa alguna de estas.
  final Set<Preocupacion>? preocupaciones;

  /// Solo si irá con alguna de estas personas.
  final Set<Acompanante>? conQuien;

  bool get tieneEdad => edadMin != null || edadMax != null;

  /// Si vale para [papel] con estos datos del ticket. Con la edad sin decir, lo que depende de la edad sale si
  /// [edadDesconocidaVale] (y entonces se enseña con su condición: «Si tienes menos de 14 años»).
  bool cumple({
    required PapelSituacion papel,
    int? edad,
    Procedimiento? procedimiento,
    Fase? fase,
    Set<Preocupacion> preocupacionesDelTicket = const {},
    Set<Acompanante> conQuienDelTicket = const {},
    bool edadDesconocidaVale = true,
  }) {
    if (papeles != null && !papeles!.contains(papel)) return false;
    if (tieneEdad) {
      if (edad == null) {
        if (!edadDesconocidaVale) return false;
      } else if ((edadMin != null && edad < edadMin!) || (edadMax != null && edad > edadMax!)) {
        return false;
      }
    }
    if (procedimientos != null && (procedimiento == null || !procedimientos!.contains(procedimiento))) return false;
    if (fases != null && fase != null && !fases!.contains(fase)) return false;
    if (preocupaciones != null && !preocupaciones!.any(preocupacionesDelTicket.contains)) return false;
    if (conQuien != null && !conQuien!.any(conQuienDelTicket.contains)) return false;
    return true;
  }

  /// «Si tienes menos de 14 años», «Si tienes 12 años o más»… null si no depende de la edad.
  String? get etiquetaEdad {
    final min = edadMin;
    final max = edadMax;
    if (min == null && max == null) return null;
    if (min == null) return 'Si tienes menos de ${max! + 1} años';
    if (max == null) return 'Si tienes $min años o más';
    return 'Si tienes de $min a $max años';
  }
}

/// Un derecho de «Tus derechos», como una carta.
@immutable
class Derecho {
  const Derecho({
    required this.id,
    required this.titulo,
    required this.texto,
    required this.fuentes,
    this.ejemplo,
    this.condicionTexto,
    this.condicion = const Condicion(),
    this.relacionadas = const {},
  });

  final String id;
  final String titulo;
  final String texto;
  final List<String> fuentes;
  final String? ejemplo;

  /// Una condición que no depende de ti y se enseña siempre («Si a quien investigan tiene de 14 a 17 años»).
  final String? condicionTexto;
  final Condicion condicion;

  /// Las preocupaciones con las que tiene que ver (para ponerlo antes si te preocupan).
  final Set<Preocupacion> relacionadas;
}

/// Un punto de una respuesta (o una nota): con sus fuentes, o un consejo práctico sin fuente.
@immutable
class PuntoContenido {
  const PuntoContenido({
    required this.texto,
    this.fuentes = const [],
    this.consejo = false,
    this.condicion = const Condicion(),
  });

  final String texto;
  final List<String> fuentes;
  final bool consejo;
  final Condicion condicion;
}

/// Lo que te preocupa, respondido punto a punto.
@immutable
class RespuestaPreocupacion {
  const RespuestaPreocupacion({
    required this.preocupacion,
    required this.titulo,
    this.puntos = const [],
    this.ideasPregunta = const [],
  });

  final Preocupacion preocupacion;
  final String titulo;
  final List<PuntoContenido> puntos;

  /// Preguntas para «Mis preguntas» (no son afirmaciones jurídicas).
  final List<String> ideasPregunta;
}

/// Lo que «Mi situación» añade a un paso del itinerario, tal como viene en el contenido.
@immutable
class ExtrasPasoContenido {
  const ExtrasPasoContenido({
    this.lugar,
    this.esCita = false,
    this.duda,
    this.palabras = const [],
    this.llevar = const [],
    this.ejemplo,
    this.paraTi = const [],
    this.desdeEdad,
    this.hastaEdad,
  });

  /// 'sala' es en estrados (con toga).
  final String? lugar;
  final bool esCita;
  final String? duda;
  final List<String> palabras;

  /// Ids del catálogo de cosas que llevar.
  final List<String> llevar;
  final String? ejemplo;
  final List<PuntoContenido> paraTi;

  /// Edades a las que se aplica el paso (las dos incluidas).
  final int? desdeEdad;
  final int? hastaEdad;
}

/// Una nota «Para ti» de la cabecera.
@immutable
class NotaSituacion {
  const NotaSituacion({required this.id, required this.titulo, required this.punto, this.enlace});

  final String id;
  final String titulo;
  final PuntoContenido punto;

  /// Otro papel de Mi situación al que lleva la nota (su id), si lleva a alguno.
  final String? enlace;
}

/// Todo el contenido de Mi situación, ya sin lo que no se puede enseñar.
@immutable
class ContenidoSituacion {
  const ContenidoSituacion({
    this.derechos = const [],
    this.preocupaciones = const {},
    this.pasos = const {},
    this.llevar = const {},
    this.notas = const [],
  });

  /// [mostrarBorradores]: modo DEMO con borradores (se enseña también lo que no está validado o no tiene fuente).
  factory ContenidoSituacion.desdeJson({
    Object? derechos,
    Object? preocupaciones,
    Object? pasos,
    Object? notas,
    bool mostrarBorradores = false,
  }) {
    bool visible(bool validadoFichero, Map<String, dynamic> item, {bool consejoPorDefecto = false}) {
      if (mostrarBorradores) return true;
      final consejo = item['consejo'] == true || consejoPorDefecto;
      return validadoFichero &&
          item['validado'] == true &&
          (consejo || CitaPaso.de(_textos(item['fuentes'])).isNotEmpty);
    }

    PuntoContenido punto(Map<String, dynamic> item) => PuntoContenido(
      texto: _texto(item['texto']),
      fuentes: _textos(item['fuentes']),
      consejo: item['consejo'] == true,
      condicion: Condicion.fromJson(item),
    );

    // Derechos.
    final listaDerechos = <Derecho>[];
    if (derechos case {'derechos': final List<Object?> lista}) {
      final validado = (derechos as Map)['validado'] == true;
      for (final e in lista) {
        if (e is! Map<String, dynamic> || !visible(validado, e)) continue;
        final titulo = _texto(e['titulo']);
        final texto = _texto(e['texto']);
        if (titulo.isEmpty || texto.isEmpty) continue;
        final relacionadas = <Preocupacion>{
          if (e['preocupaciones'] case final List<Object?> ps)
            for (final p in ps) ?Preocupacion.deValor(p),
        };
        listaDerechos.add(
          Derecho(
            id: _texto(e['id']),
            titulo: titulo,
            texto: texto,
            fuentes: _textos(e['fuentes']),
            ejemplo: _textoONulo(e['ejemplo']),
            condicionTexto: _textoONulo(e['condicion']),
            condicion: Condicion.fromJson(e, preocupacionesObligatorias: e['solo_si_preocupa'] == true),
            relacionadas: Set.unmodifiable(relacionadas),
          ),
        );
      }
    }

    // Preocupaciones.
    final respuestas = <Preocupacion, RespuestaPreocupacion>{};
    if (preocupaciones case {'preocupaciones': final List<Object?> lista}) {
      final validado = (preocupaciones as Map)['validado'] == true;
      for (final e in lista) {
        if (e is! Map<String, dynamic>) continue;
        final preocupacion = Preocupacion.deValor(e['id']);
        if (preocupacion == null) continue;
        final puntos = <PuntoContenido>[
          if (e['puntos'] case final List<Object?> ps)
            for (final p in ps)
              if (p is Map<String, dynamic> && visible(validado, p) && _texto(p['texto']).isNotEmpty) punto(p),
        ];
        respuestas[preocupacion] = RespuestaPreocupacion(
          preocupacion: preocupacion,
          titulo: _texto(e['titulo']).isEmpty ? preocupacion.etiqueta : _texto(e['titulo']),
          puntos: List.unmodifiable(puntos),
          ideasPregunta: _textos(e['ideas_pregunta']),
        );
      }
    }

    // Pasos y catálogo de cosas que llevar.
    final extras = <String, Map<String, ExtrasPasoContenido>>{};
    final catalogo = <String, String>{};
    if (pasos is Map<String, dynamic>) {
      final validado = pasos['validado'] == true;
      if (pasos['llevar'] case final Map<String, dynamic> cosas) {
        for (final MapEntry(:key, :value) in cosas.entries) {
          if (value is Map<String, dynamic> && visible(validado, value, consejoPorDefecto: true)) {
            final texto = _texto(value['texto']);
            if (texto.isNotEmpty) catalogo[key] = texto;
          }
        }
      }
      if (pasos['papeles'] case final Map<String, dynamic> porPapel) {
        for (final MapEntry(key: papel, value: porPaso) in porPapel.entries) {
          if (porPaso is! Map<String, dynamic>) continue;
          final delPapel = <String, ExtrasPasoContenido>{};
          for (final MapEntry(key: idPaso, value: datos) in porPaso.entries) {
            if (datos is! Map<String, dynamic>) continue;
            int? edad(Object? v) => v is num ? v.toInt() : null;
            delPapel[idPaso] = ExtrasPasoContenido(
              lugar: _textoONulo(datos['lugar']),
              esCita: datos['cita'] == true,
              duda: _textoONulo(datos['duda']),
              palabras: _textos(datos['palabras']),
              llevar: _textos(datos['llevar']),
              ejemplo: _textoONulo(datos['ejemplo']),
              paraTi: [
                if (datos['para_ti'] case final List<Object?> ps)
                  for (final p in ps)
                    if (p is Map<String, dynamic> && visible(validado, p) && _texto(p['texto']).isNotEmpty) punto(p),
              ],
              desdeEdad: edad(datos['desde_edad']),
              hastaEdad: edad(datos['hasta_edad']),
            );
          }
          extras[papel] = Map.unmodifiable(delPapel);
        }
      }
    }

    // Notas.
    final listaNotas = <NotaSituacion>[];
    if (notas case {'notas': final List<Object?> lista}) {
      final validado = (notas as Map)['validado'] == true;
      for (final e in lista) {
        if (e is! Map<String, dynamic> || !visible(validado, e)) continue;
        final texto = _texto(e['texto']);
        if (texto.isEmpty) continue;
        listaNotas.add(
          NotaSituacion(
            id: _texto(e['id']),
            titulo: _texto(e['titulo']).isEmpty ? 'Para ti' : _texto(e['titulo']),
            punto: punto(e),
            enlace: _textoONulo(e['enlace']),
          ),
        );
      }
    }

    return ContenidoSituacion(
      derechos: List.unmodifiable(listaDerechos),
      preocupaciones: Map.unmodifiable(respuestas),
      pasos: Map.unmodifiable(extras),
      llevar: Map.unmodifiable(catalogo),
      notas: List.unmodifiable(listaNotas),
    );
  }

  final List<Derecho> derechos;
  final Map<Preocupacion, RespuestaPreocupacion> preocupaciones;

  /// Por papel ('victima') y por paso ('P3').
  final Map<String, Map<String, ExtrasPasoContenido>> pasos;

  /// Catálogo de cosas que llevar: id → texto.
  final Map<String, String> llevar;
  final List<NotaSituacion> notas;

  bool get vacio => derechos.isEmpty && preocupaciones.isEmpty && pasos.isEmpty && notas.isEmpty;
}

String _texto(Object? valor) => valor is String ? valor.trim() : '';

String? _textoONulo(Object? valor) {
  final texto = _texto(valor);
  return texto.isEmpty ? null : texto;
}

List<String> _textos(Object? valor) => switch (valor) {
  final List<Object?> lista => List.unmodifiable([
    for (final e in lista)
      if (e is String && e.trim().isNotEmpty) e.trim(),
  ]),
  final String texto when texto.trim().isNotEmpty => List.unmodifiable([texto.trim()]),
  _ => const <String>[],
};

/// El contenido de Mi situación. Si falta algún fichero, esa parte sale vacía (nunca falla): la pantalla enseña lo
/// demás.
final contenidoSituacionProvider = FutureProvider<ContenidoSituacion>((ref) async {
  final repo = ref.watch(contentProvider);
  final [derechos, preocupaciones, pasos, notas] = await Future.wait([
    for (final fichero in ['derechos', 'preocupaciones', 'pasos', 'notas'])
      repo.json('$carpetaSituacion/$fichero.json'),
  ]);
  return ContenidoSituacion.desdeJson(
    derechos: derechos,
    preocupaciones: preocupaciones,
    pasos: pasos,
    notas: notas,
    mostrarBorradores: repo.mostrarBorradores,
  );
});
