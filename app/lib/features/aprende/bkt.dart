// Aprendizaje adaptativo con Bayesian Knowledge Tracing (docs/ARQUITECTURA.md, sección 10.6).
//
// Cada concepto tiene una probabilidad de dominio p que se actualiza después de cada respuesta:
// - Si acierta: p' = p(1−S) / [p(1−S) + (1−p)G]
// - Si falla:   p' = pS / [pS + (1−p)(1−G)]
// - Después, aprendizaje: p_nueva = p' + (1−p')T

class Bkt {
  const Bkt({this.pT = 0.15, this.pG = 0.2, this.pS = 0.1});

  /// T: probabilidad de aprender el concepto en cada intento.
  /// G: probabilidad de acertar por suerte.
  /// S: probabilidad de fallar por despiste.
  final double pT, pG, pS;

  /// Dominio de partida de un concepto que aún no se ha practicado.
  static const p0 = 0.2;

  /// Un concepto está dominado con p ≥ 0,95.
  static const umbralDominio = 0.95;

  double actualizar(double p, bool acierto) {
    final post = acierto ? p * (1 - pS) / (p * (1 - pS) + (1 - p) * pG) : p * pS / (p * pS + (1 - p) * (1 - pG));
    return post + (1 - post) * pT;
  }

  static bool dominado(double p) => p >= umbralDominio;
}

/// Dificultad de ejercicio que toca con el dominio [p]: 1 si p < 0,4; 2 si p < 0,7; 3 en otro caso.
int dificultadPara(double p) => p < 0.4 ? 1 : (p < 0.7 ? 2 : 3);

/// Dominio guardado de [concepto], o [Bkt.p0] si aún no se ha practicado. Siempre entre 0 y 1.
double dominioDe(Map<String, double> dominio, String concepto) {
  final p = dominio[concepto];
  if (p == null || p.isNaN) return Bkt.p0;
  return p.clamp(0.0, 1.0).toDouble();
}
