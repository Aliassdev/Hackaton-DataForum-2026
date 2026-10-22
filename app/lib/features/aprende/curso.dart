import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/content_repo.dart';
import '../../core/progreso.dart';
import '../../core/providers.dart';
import 'modelos.dart';

// El curso de Aprende: unidades de content/lecciones y ejercicios de content/ejercicios (secciones 9.2 y 9.3),
// ya filtrados (solo lo validado y con fuente) y con el estado de cada lección.

enum EstadoLeccion { completada, disponible, bloqueada }

/// Prefijo de la ruta de práctica: /aprende/leccion/practica-U1 practica la unidad U1.
const prefijoPractica = 'practica-';

/// Prefijo del atajo de la demo: /aprende/leccion/dilo-U1-L1 empieza U1-L1 en su «Dilo con tus palabras». Solo
/// funciona en modo DEMO (la ruta de la demo, sección 4.6, le da 20 segundos); si no, abre la lección normal.
const prefijoDilo = 'dilo-';

String rutaLeccion(String leccionId) => '/aprende/leccion/${Uri.encodeComponent(leccionId)}';

String rutaPractica(String unidadId) => rutaLeccion('$prefijoPractica$unidadId');

String rutaDemoDilo(String leccionId) => rutaLeccion('$prefijoDilo$leccionId');

@immutable
class Curso {
  const Curso({required this.unidades, required this.ejercicios});

  static const vacio = Curso(unidades: [], ejercicios: {});

  /// Unidades visibles, en orden. Cada lección solo lista ejercicios visibles y ninguna está vacía.
  final List<Unidad> unidades;

  /// Ejercicios visibles por id.
  final Map<String, Ejercicio> ejercicios;

  bool get estaVacio => unidades.isEmpty;

  /// Todas las lecciones en el orden en que se desbloquean.
  List<Leccion> get lecciones => [for (final u in unidades) ...u.lecciones];

  Leccion? leccion(String id) {
    for (final l in lecciones) {
      if (l.id == id) return l;
    }
    return null;
  }

  Unidad? unidad(String id) {
    for (final u in unidades) {
      if (u.id == id) return u;
    }
    return null;
  }

  Unidad? unidadDe(String leccionId) {
    for (final u in unidades) {
      if (u.lecciones.any((l) => l.id == leccionId)) return u;
    }
    return null;
  }

  List<Ejercicio> ejerciciosDe(Leccion leccion) => [for (final id in leccion.ejercicios) ?ejercicios[id]];

  /// Los ejercicios de todas las lecciones de [unidad], sin repetir.
  List<Ejercicio> ejerciciosDeUnidad(Unidad unidad) {
    final vistos = <String>{};
    return [
      for (final l in unidad.lecciones)
        for (final e in ejerciciosDe(l))
          if (vistos.add(e.id)) e,
    ];
  }

  /// La lección anterior en el camino (la que hay que completar para desbloquear [leccionId]).
  Leccion? anterior(String leccionId) {
    final todas = lecciones;
    final i = todas.indexWhere((l) => l.id == leccionId);
    return i > 0 ? todas[i - 1] : null;
  }

  Leccion? posterior(String leccionId) {
    final todas = lecciones;
    final i = todas.indexWhere((l) => l.id == leccionId);
    return i >= 0 && i + 1 < todas.length ? todas[i + 1] : null;
  }

  /// Una lección se desbloquea al completar la anterior. La primera siempre está disponible.
  EstadoLeccion estado(String leccionId, Set<String> completadas) {
    if (completadas.contains(leccionId)) return EstadoLeccion.completada;
    final previa = anterior(leccionId);
    return previa == null || completadas.contains(previa.id) ? EstadoLeccion.disponible : EstadoLeccion.bloqueada;
  }

  /// La primera lección disponible sin completar: la que toca ahora. null si están todas hechas.
  Leccion? siguiente(Set<String> completadas) {
    for (final l in lecciones) {
      if (estado(l.id, completadas) == EstadoLeccion.disponible) return l;
    }
    return null;
  }

  /// La unidad en la que se está: la de la siguiente lección, o la última si ya está todo hecho.
  Unidad? unidadActual(Set<String> completadas) {
    final s = siguiente(completadas);
    if (s != null) return unidadDe(s.id);
    return unidades.isEmpty ? null : unidades.last;
  }

  /// Una unidad se puede practicar cuando su primera lección está desbloqueada.
  bool unidadAbierta(Unidad unidad, Set<String> completadas) =>
      unidad.lecciones.isNotEmpty && estado(unidad.lecciones.first.id, completadas) != EstadoLeccion.bloqueada;
}

/// Lee las unidades y los ejercicios de [repo]. Nunca lanza: lo que no se puede leer, se salta.
Future<Curso> cargarCurso(ContentRepo repo) async {
  final ejercicios = <String, Ejercicio>{};
  for (final fichero in await repo.listar('ejercicios')) {
    final json = await repo.json(fichero);
    if (json is! List) continue;
    for (final elemento in json) {
      final ejercicio = Ejercicio.fromJson(elemento);
      if (ejercicio == null) {
        debugPrint('Aprende: ejercicio no válido en $fichero (${elemento is Map ? elemento['id'] : '?'})');
        continue;
      }
      if (repo.visible(validado: ejercicio.validado, fuente: ejercicio.fuente)) {
        ejercicios.putIfAbsent(ejercicio.id, () => ejercicio);
      }
    }
  }

  final unidades = <Unidad>[];
  final leccionesVistas = <String>{};
  for (final fichero in await repo.listar('lecciones')) {
    final unidad = Unidad.fromJson(await repo.json(fichero));
    if (unidad == null) {
      debugPrint('Aprende: unidad no válida en $fichero');
      continue;
    }
    if (!unidad.validado && !repo.mostrarBorradores) continue;
    final lecciones = [
      for (final l in unidad.lecciones)
        if (leccionesVistas.add(l.id))
          l.conEjercicios([
            for (final id in l.ejercicios)
              if (ejercicios.containsKey(id)) id,
          ]),
    ].where((l) => l.ejercicios.isNotEmpty).toList();
    if (lecciones.isNotEmpty) unidades.add(unidad.conLecciones(lecciones));
  }
  unidades.sort((a, b) => _ordenNatural(a.id, b.id));
  return Curso(unidades: unidades, ejercicios: ejercicios);
}

/// «U2» antes que «U10».
int _ordenNatural(String a, String b) {
  final na = int.tryParse(RegExp(r'\d+').firstMatch(a)?.group(0) ?? '');
  final nb = int.tryParse(RegExp(r'\d+').firstMatch(b)?.group(0) ?? '');
  if (na != null && nb != null && na != nb) return na.compareTo(nb);
  return a.compareTo(b);
}

/// Racha que se enseña hoy, con la racha amable ([estadoRacha]): sigue viva si la última lección fue hoy o ayer, o
/// anteayer si queda día de descanso. Si no, 0 (se empieza otra; nunca se habla de perderla).
int rachaVisible(Progreso progreso, DateTime ahora) => estadoRacha(progreso, ahora).dias;

/// La racha ya cuenta hoy (se ha hecho una lección).
bool rachaDeHoy(Progreso progreso, DateTime ahora) => estadoRacha(progreso, ahora).tipo == TipoRacha.hoyHecha;

/// Unidades y ejercicios, cargados una vez y guardados en memoria.
final cursoProvider = FutureProvider<Curso>((ref) => cargarCurso(ref.watch(contentProvider)));

/// Probabilidad de dominio por concepto (BKT, sección 10.6). Se guarda con el progreso, en el móvil.
final dominioProvider = Provider<Map<String, double>>((ref) => ref.watch(progresoProvider.select((p) => p.dominio)));
