import 'bkt.dart';
import 'modelos.dart';

// Política de selección de «Practicar» (docs/ARQUITECTURA.md, sección 10.6):
// 1. Dentro de la unidad actual, se elige el concepto no dominado con menor p.
// 2. Dificultad del ejercicio: 1 si p < 0,4; 2 si p < 0,7; 3 en otro caso.
// 3. No se repite un ejercicio visto en la misma sesión.
// 4. Si un concepto dominado lleva más de un día sin practicarse, entra un ejercicio de repaso.

/// Ejercicio elegido y si es de repaso (de un concepto ya dominado).
typedef Elegido = ({Ejercicio ejercicio, bool repaso});

class PoliticaSeleccion {
  const PoliticaSeleccion();

  /// Ejercicios de una sesión de práctica.
  static const ejerciciosPorSesion = 6;

  /// Un concepto dominado entra en repaso si lleva más de esto sin practicarse.
  static const plazoRepaso = Duration(days: 1);

  /// El siguiente ejercicio de [ejercicios] (los de la unidad actual), o null si ya se han visto todos.
  ///
  /// Primero, un repaso si algún concepto dominado lleva más de un día sin practicarse (el más antiguo).
  /// Si no, el concepto no dominado con menor p. Si todos están dominados y al día, el de menor p,
  /// para que siempre se pueda seguir practicando. Dentro del concepto, el ejercicio con la dificultad
  /// más cercana a la que toca (si hay empate, el más fácil).
  Elegido? siguiente({
    required List<String> conceptos,
    required List<Ejercicio> ejercicios,
    required Map<String, double> dominio,
    required Map<String, DateTime> ultimaPractica,
    required Set<String> vistos,
    required DateTime ahora,
  }) {
    final porConcepto = <String, List<Ejercicio>>{};
    for (final e in ejercicios) {
      if (!vistos.contains(e.id)) (porConcepto[e.concepto] ??= []).add(e);
    }
    if (porConcepto.isEmpty) return null;

    // Los de la unidad en su orden y, al final, los que no estén en su lista (para no perder ninguno).
    final candidatos = [
      for (final c in conceptos)
        if (porConcepto.containsKey(c)) c,
      for (final c in porConcepto.keys)
        if (!conceptos.contains(c)) c,
    ];
    double p(String concepto) => dominioDe(dominio, concepto);

    final pendientesDeRepaso = [
      for (final c in candidatos)
        if (Bkt.dominado(p(c)) && _llevaSinPracticar(ultimaPractica[c], ahora)) c,
    ]..sort((a, b) => ultimaPractica[a]!.compareTo(ultimaPractica[b]!));
    if (pendientesDeRepaso.isNotEmpty) {
      final c = pendientesDeRepaso.first;
      return (ejercicio: _masAdecuado(porConcepto[c]!, dificultadPara(p(c))), repaso: true);
    }

    final noDominados = [
      for (final c in candidatos)
        if (!Bkt.dominado(p(c))) c,
    ];
    final todosDominados = noDominados.isEmpty;
    final c = _menorDominio(todosDominados ? candidatos : noDominados, p);
    return (ejercicio: _masAdecuado(porConcepto[c]!, dificultadPara(p(c))), repaso: todosDominados);
  }

  static bool _llevaSinPracticar(DateTime? ultima, DateTime ahora) =>
      ultima != null && ahora.difference(ultima) > plazoRepaso;

  /// El de menor p; con empate, el que va antes en la unidad.
  static String _menorDominio(List<String> conceptos, double Function(String) p) {
    var mejor = conceptos.first;
    for (final c in conceptos.skip(1)) {
      if (p(c) < p(mejor)) mejor = c;
    }
    return mejor;
  }

  static Ejercicio _masAdecuado(List<Ejercicio> ejercicios, int objetivo) {
    var mejor = ejercicios.first;
    for (final e in ejercicios.skip(1)) {
      final distancia = (e.dificultad - objetivo).abs();
      final distanciaMejor = (mejor.dificultad - objetivo).abs();
      if (distancia < distanciaMejor || (distancia == distanciaMejor && e.dificultad < mejor.dificultad)) mejor = e;
    }
    return mejor;
  }
}
