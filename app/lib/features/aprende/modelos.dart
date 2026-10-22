import 'package:flutter/foundation.dart';

// Esquemas de contenido de Aprende (docs/ARQUITECTURA.md, secciones 9.2 y 9.3).
//
// Un elemento mal formado se salta (fromJson devuelve null): nunca deja sin lecciones al resto.

/// Unidad (9.2): `{"id", "titulo", "conceptos", "lecciones": [{"id", "titulo", "ejercicios"}], "validado"}`.
@immutable
class Unidad {
  const Unidad({
    required this.id,
    required this.titulo,
    required this.conceptos,
    required this.lecciones,
    required this.validado,
  });

  final String id;
  final String titulo;

  /// Ids de los conceptos de la unidad, en orden (p. ej. C-ser-oido).
  final List<String> conceptos;
  final List<Leccion> lecciones;
  final bool validado;

  static Unidad? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = _texto(json['id']);
    final titulo = _texto(json['titulo']);
    final lecciones = json['lecciones'];
    if (id.isEmpty || titulo.isEmpty || lecciones is! List) return null;
    return Unidad(
      id: id,
      titulo: titulo,
      conceptos: _textos(json['conceptos']).where((c) => c.isNotEmpty).toList(),
      lecciones: [for (final l in lecciones) ?Leccion.fromJson(l)],
      validado: json['validado'] == true,
    );
  }

  Unidad conLecciones(List<Leccion> lecciones) =>
      Unidad(id: id, titulo: titulo, conceptos: conceptos, lecciones: lecciones, validado: validado);
}

@immutable
class Leccion {
  const Leccion({required this.id, required this.titulo, required this.ejercicios});

  final String id;
  final String titulo;

  /// Ids de los ejercicios, en el orden en que se juegan.
  final List<String> ejercicios;

  static Leccion? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = _texto(json['id']);
    final titulo = _texto(json['titulo']);
    if (id.isEmpty || titulo.isEmpty) return null;
    return Leccion(id: id, titulo: titulo, ejercicios: _textos(json['ejercicios']).where((e) => e.isNotEmpty).toList());
  }

  Leccion conEjercicios(List<String> ejercicios) => Leccion(id: id, titulo: titulo, ejercicios: ejercicios);
}

enum TipoEjercicio { eleccion, vf, ordenar, emparejar, dilo }

/// Ejercicio (9.3). Todos tienen id, concepto, dificultad (1 a 3), fuente y validado.
@immutable
sealed class Ejercicio {
  const Ejercicio({
    required this.id,
    required this.concepto,
    required this.dificultad,
    required this.fuente,
    required this.validado,
  });

  final String id;
  final String concepto;

  /// 1, 2 o 3.
  final int dificultad;

  /// De dónde sale lo que se afirma: un artículo («LECrim, art. 449 ter») o el id de una tarjeta (A-003).
  final String fuente;
  final bool validado;

  TipoEjercicio get tipo;

  /// Explicación que acompaña a la corrección. Vacía si el esquema no la tiene.
  String get explicacion => '';

  /// null si [json] no es un ejercicio que se pueda jugar.
  static Ejercicio? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = _texto(json['id']);
    final concepto = _texto(json['concepto']);
    if (id.isEmpty || concepto.isEmpty) return null;
    final dificultad = json['dificultad'] is num ? (json['dificultad'] as num).round().clamp(1, 3) : 1;
    final fuente = _texto(json['fuente']);
    final validado = json['validado'] == true;
    try {
      switch (json['tipo']) {
        case 'eleccion':
          final opciones = _textos(json['opciones']);
          final correcta = json['correcta'];
          final pregunta = _texto(json['pregunta']);
          if (pregunta.isEmpty || opciones.length < 2 || opciones.any((o) => o.isEmpty)) return null;
          if (correcta is! int || correcta < 0 || correcta >= opciones.length) return null;
          return EjercicioEleccion(
            id: id,
            concepto: concepto,
            dificultad: dificultad,
            fuente: fuente,
            validado: validado,
            pregunta: pregunta,
            opciones: opciones,
            correcta: correcta,
            explicacion: _texto(json['explicacion']),
          );
        case 'vf':
          final afirmacion = _texto(json['afirmacion']);
          final correcta = json['correcta'];
          if (afirmacion.isEmpty || correcta is! bool) return null;
          return EjercicioVf(
            id: id,
            concepto: concepto,
            dificultad: dificultad,
            fuente: fuente,
            validado: validado,
            afirmacion: afirmacion,
            correcta: correcta,
            explicacion: _texto(json['explicacion']),
          );
        case 'ordenar':
          final pasos = _textos(json['pasos']);
          // Con pasos repetidos habría más de un orden correcto.
          if (pasos.length < 2 || pasos.any((p) => p.isEmpty) || pasos.toSet().length != pasos.length) return null;
          final enunciado = _texto(json['enunciado']);
          return EjercicioOrdenar(
            id: id,
            concepto: concepto,
            dificultad: dificultad,
            fuente: fuente,
            validado: validado,
            enunciado: enunciado.isEmpty ? 'Ordena los pasos' : enunciado,
            pasos: pasos,
          );
        case 'emparejar':
          final pares = <(String, String)>[];
          for (final par in json['pares'] as List? ?? const []) {
            if (par is! List || par.length != 2) return null;
            final (a, b) = (_texto(par[0]), _texto(par[1]));
            if (a.isEmpty || b.isEmpty) return null;
            pares.add((a, b));
          }
          final izquierda = {for (final p in pares) p.$1};
          final derecha = {for (final p in pares) p.$2};
          if (pares.length < 2 || izquierda.length != pares.length || derecha.length != pares.length) return null;
          return EjercicioEmparejar(
            id: id,
            concepto: concepto,
            dificultad: dificultad,
            fuente: fuente,
            validado: validado,
            pares: pares,
          );
        case 'dilo':
          final pregunta = _texto(json['pregunta']);
          final proposiciones = _textos(json['proposiciones']).where((p) => p.isNotEmpty).toList();
          if (pregunta.isEmpty || proposiciones.isEmpty) return null;
          return EjercicioDilo(
            id: id,
            concepto: concepto,
            dificultad: dificultad,
            fuente: fuente,
            validado: validado,
            pregunta: pregunta,
            proposiciones: proposiciones,
          );
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

/// Elección múltiple: una sola opción correcta ([correcta] es su posición en [opciones]).
class EjercicioEleccion extends Ejercicio {
  const EjercicioEleccion({
    required super.id,
    required super.concepto,
    required super.dificultad,
    required super.fuente,
    required super.validado,
    required this.pregunta,
    required this.opciones,
    required this.correcta,
    this.explicacion = '',
  });

  final String pregunta;
  final List<String> opciones;
  final int correcta;
  @override
  final String explicacion;

  @override
  TipoEjercicio get tipo => TipoEjercicio.eleccion;

  bool esCorrecta(int opcion) => opcion == correcta;
}

/// Verdadero o falso.
class EjercicioVf extends Ejercicio {
  const EjercicioVf({
    required super.id,
    required super.concepto,
    required super.dificultad,
    required super.fuente,
    required super.validado,
    required this.afirmacion,
    required this.correcta,
    this.explicacion = '',
  });

  final String afirmacion;
  final bool correcta;
  @override
  final String explicacion;

  @override
  TipoEjercicio get tipo => TipoEjercicio.vf;

  bool esCorrecta(bool respuesta) => respuesta == correcta;
}

/// Ordena los pasos: [pasos] viene en el orden correcto y se enseña desordenado.
class EjercicioOrdenar extends Ejercicio {
  const EjercicioOrdenar({
    required super.id,
    required super.concepto,
    required super.dificultad,
    required super.fuente,
    required super.validado,
    required this.enunciado,
    required this.pasos,
  });

  final String enunciado;
  final List<String> pasos;

  @override
  TipoEjercicio get tipo => TipoEjercicio.ordenar;

  /// [orden] son las posiciones originales de los pasos tal y como los ha colocado la persona.
  bool esCorrecta(List<int> orden) => listEquals(orden, List<int>.generate(pasos.length, (i) => i));
}

/// Empareja términos: cada par es (izquierda, derecha). La columna derecha se enseña desordenada.
class EjercicioEmparejar extends Ejercicio {
  const EjercicioEmparejar({
    required super.id,
    required super.concepto,
    required super.dificultad,
    required super.fuente,
    required super.validado,
    required this.pares,
  });

  final List<(String, String)> pares;

  @override
  TipoEjercicio get tipo => TipoEjercicio.emparejar;

  /// [uniones]: posición de cada elemento de la izquierda → posición original del de la derecha.
  bool esCorrecta(Map<int, int> uniones) =>
      uniones.length == pares.length && uniones.entries.every((u) => u.key == u.value);
}

/// «Dilo con tus palabras»: el backend comprueba qué [proposiciones] cubre el texto (sección 10.5).
class EjercicioDilo extends Ejercicio {
  const EjercicioDilo({
    required super.id,
    required super.concepto,
    required super.dificultad,
    required super.fuente,
    required super.validado,
    required this.pregunta,
    required this.proposiciones,
  });

  final String pregunta;

  /// Ideas clave, en lenguaje sencillo. Se enseñan si no se puede corregir.
  final List<String> proposiciones;

  @override
  TipoEjercicio get tipo => TipoEjercicio.dilo;
}

String _texto(Object? valor) => valor is String ? valor.trim() : '';

List<String> _textos(Object? valor) => valor is List ? [for (final v in valor) _texto(v)] : const [];
