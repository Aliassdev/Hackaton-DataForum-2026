import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/features/aprende/bkt.dart';

/// Las fórmulas de la sección 10.6, escritas aparte para comparar.
double _esperado(double p, bool acierto, {double t = 0.15, double g = 0.2, double s = 0.1}) {
  final posterior = acierto ? p * (1 - s) / (p * (1 - s) + (1 - p) * g) : p * s / (p * s + (1 - p) * (1 - g));
  return posterior + (1 - posterior) * t;
}

void main() {
  const bkt = Bkt();

  test('los parámetros son los de la sección 10.6', () {
    expect(Bkt.p0, 0.2);
    expect(bkt.pT, 0.15);
    expect(bkt.pG, 0.2);
    expect(bkt.pS, 0.1);
    expect(Bkt.umbralDominio, 0.95);
  });

  test('un acierto desde p0: 0,2 · 0,9 / (0,18 + 0,16) = 0,5294…, y con el aprendizaje, 0,6', () {
    expect(bkt.actualizar(0.2, true), closeTo(0.6, 1e-12));
  });

  test('un fallo desde p0: 0,02 / 0,66 = 0,0303…, y con el aprendizaje, 0,1758', () {
    expect(bkt.actualizar(0.2, false), closeTo(0.02 / 0.66 + (1 - 0.02 / 0.66) * 0.15, 1e-12));
    expect(bkt.actualizar(0.2, false), closeTo(0.17576, 1e-5));
  });

  test('coincide con las fórmulas en todo el rango, al acertar y al fallar', () {
    for (var i = 0; i <= 20; i++) {
      final p = i / 20;
      expect(bkt.actualizar(p, true), closeTo(_esperado(p, true), 1e-12), reason: 'acierto con p=$p');
      expect(bkt.actualizar(p, false), closeTo(_esperado(p, false), 1e-12), reason: 'fallo con p=$p');
    }
  });

  test('acertar sube, fallar baja (salvo el aprendizaje, que siempre suma T)', () {
    for (final p in [0.1, 0.3, 0.5, 0.7, 0.9]) {
      expect(bkt.actualizar(p, true), greaterThan(p));
      expect(bkt.actualizar(p, false), lessThan(bkt.actualizar(p, true)));
    }
  });

  test('con tres aciertos seguidos desde p0 el concepto queda dominado', () {
    var p = Bkt.p0;
    final historia = <double>[];
    for (var i = 0; i < 3; i++) {
      p = bkt.actualizar(p, true);
      historia.add(p);
    }
    expect(historia[0], closeTo(0.6, 1e-9));
    expect(historia[1], closeTo(0.890323, 1e-6));
    expect(historia[2], closeTo(0.977351, 1e-6));
    expect(Bkt.dominado(historia[1]), isFalse);
    expect(Bkt.dominado(historia[2]), isTrue);
  });

  test('dominado a partir de 0,95', () {
    expect(Bkt.dominado(0.95), isTrue);
    expect(Bkt.dominado(0.9499), isFalse);
    expect(Bkt.dominado(1), isTrue);
  });

  test('la dificultad sale del dominio: 1 si p < 0,4; 2 si p < 0,7; 3 en otro caso', () {
    expect(dificultadPara(0), 1);
    expect(dificultadPara(0.2), 1);
    expect(dificultadPara(0.3999), 1);
    expect(dificultadPara(0.4), 2);
    expect(dificultadPara(0.6999), 2);
    expect(dificultadPara(0.7), 3);
    expect(dificultadPara(0.99), 3);
  });

  test('un concepto sin practicar empieza en p0, y el dominio guardado siempre queda entre 0 y 1', () {
    expect(dominioDe(const {}, 'C-ser-oido'), Bkt.p0);
    expect(dominioDe(const {'C-ser-oido': 0.7}, 'C-ser-oido'), 0.7);
    expect(dominioDe(const {'C-ser-oido': 1.4}, 'C-ser-oido'), 1);
    expect(dominioDe(const {'C-ser-oido': -1}, 'C-ser-oido'), 0);
    expect(dominioDe(const {'C-ser-oido': double.nan}, 'C-ser-oido'), Bkt.p0);
  });

  test('admite otros parámetros', () {
    const otro = Bkt(pT: 0, pG: 0.25, pS: 0.05);
    expect(otro.actualizar(0.5, true), closeTo(_esperado(0.5, true, t: 0, g: 0.25, s: 0.05), 1e-12));
  });
}
