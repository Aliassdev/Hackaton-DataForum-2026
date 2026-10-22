import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/features/aprende/bkt.dart';
import 'package:tuturno/features/aprende/modelos.dart';
import 'package:tuturno/features/aprende/seleccion.dart';

EjercicioVf _ej(String id, String concepto, int dificultad) => EjercicioVf(
  id: id,
  concepto: concepto,
  dificultad: dificultad,
  fuente: 'LO 1/1996, art. 9',
  validado: true,
  afirmacion: 'Afirmación $id',
  correcta: true,
);

/// Tres conceptos con un ejercicio de cada dificultad.
final _pool = [
  for (final c in ['A', 'B', 'C'])
    for (final d in [1, 2, 3]) _ej('$c$d', c, d),
];
const _conceptos = ['A', 'B', 'C'];
final _ahora = DateTime(2026, 10, 21, 18);

Elegido? _elegir({
  Map<String, double> dominio = const {},
  Map<String, DateTime> ultimaPractica = const {},
  Set<String> vistos = const {},
  List<Ejercicio>? ejercicios,
  List<String> conceptos = _conceptos,
}) => const PoliticaSeleccion().siguiente(
  conceptos: conceptos,
  ejercicios: ejercicios ?? _pool,
  dominio: dominio,
  ultimaPractica: ultimaPractica,
  vistos: vistos,
  ahora: _ahora,
);

void main() {
  test('sin práctica previa empieza por el primer concepto de la unidad y con dificultad 1', () {
    final elegido = _elegir()!;
    expect(elegido.ejercicio.id, 'A1');
    expect(elegido.repaso, isFalse);
  });

  test('elige el concepto no dominado con menor p', () {
    expect(_elegir(dominio: {'A': 0.5, 'B': 0.3, 'C': 0.8})!.ejercicio.concepto, 'B');
  });

  test('la dificultad depende de p: 1 si p < 0,4; 2 si p < 0,7; 3 si no', () {
    expect(_elegir(dominio: {'A': 0.39, 'B': 0.96, 'C': 0.96})!.ejercicio.id, 'A1');
    expect(_elegir(dominio: {'A': 0.5, 'B': 0.96, 'C': 0.96})!.ejercicio.id, 'A2');
    expect(_elegir(dominio: {'A': 0.8, 'B': 0.96, 'C': 0.96})!.ejercicio.id, 'A3');
  });

  test('salta los conceptos dominados aunque tengan menor p que el umbral de otros', () {
    final elegido = _elegir(dominio: {'A': 0.97, 'B': 0.6, 'C': 0.95})!;
    expect(elegido.ejercicio.concepto, 'B');
    expect(elegido.repaso, isFalse);
  });

  test('no repite un ejercicio visto en la sesión', () {
    expect(_elegir(vistos: {'A1'})!.ejercicio.id, 'A2');
    // Con todos los de A vistos, pasa al siguiente concepto con menor p.
    expect(_elegir(vistos: {'A1', 'A2', 'A3'}, dominio: {'B': 0.5, 'C': 0.3})!.ejercicio.id, 'C1');
  });

  test('si falta la dificultad exacta, la más cercana (con empate, la más fácil)', () {
    final pool = [_ej('X1', 'X', 1), _ej('X3', 'X', 3)];
    expect(_elegir(ejercicios: pool, conceptos: ['X'], dominio: {'X': 0.5})!.ejercicio.id, 'X1');
    expect(_elegir(ejercicios: pool, conceptos: ['X'], dominio: {'X': 0.8})!.ejercicio.id, 'X3');
  });

  test('un concepto dominado que lleva más de un día sin practicarse entra como repaso', () {
    final elegido = _elegir(
      dominio: {'A': 0.3, 'B': 0.97, 'C': 0.5},
      ultimaPractica: {'B': _ahora.subtract(const Duration(days: 2))},
    )!;
    expect(elegido.ejercicio.concepto, 'B');
    expect(elegido.ejercicio.dificultad, 3);
    expect(elegido.repaso, isTrue);
  });

  test('no hay repaso si se practicó hace un día o menos', () {
    for (final hace in [const Duration(hours: 12), const Duration(days: 1)]) {
      final elegido = _elegir(dominio: {'A': 0.3, 'B': 0.97, 'C': 0.5}, ultimaPractica: {'B': _ahora.subtract(hace)})!;
      expect(elegido.ejercicio.concepto, 'A', reason: 'hace $hace');
      expect(elegido.repaso, isFalse);
    }
  });

  test('con varios repasos pendientes, primero el que lleva más tiempo sin practicarse', () {
    final elegido = _elegir(
      dominio: {'A': 0.96, 'B': 0.97, 'C': 0.2},
      ultimaPractica: {'A': _ahora.subtract(const Duration(days: 2)), 'B': _ahora.subtract(const Duration(days: 5))},
    )!;
    expect(elegido.ejercicio.concepto, 'B');
    expect(elegido.repaso, isTrue);
  });

  test('si todo está dominado y al día, sigue practicando el de menor p', () {
    final elegido = _elegir(
      dominio: {'A': 0.99, 'B': 0.96, 'C': 0.98},
      ultimaPractica: {for (final c in _conceptos) c: _ahora.subtract(const Duration(hours: 3))},
    )!;
    expect(elegido.ejercicio.concepto, 'B');
    expect(elegido.repaso, isTrue);
  });

  test('cuando ya se han visto todos, no hay más', () {
    expect(_elegir(vistos: {for (final e in _pool) e.id}), isNull);
  });

  test('no pierde ejercicios de un concepto que no está en la lista de la unidad', () {
    final pool = [_ej('Z1', 'Z', 1)];
    expect(_elegir(ejercicios: pool)!.ejercicio.id, 'Z1');
  });

  test('una sesión entera: seis ejercicios distintos que siguen al concepto más flojo', () {
    const bkt = Bkt();
    final dominio = <String, double>{};
    final vistos = <String>{};
    final conceptos = <String>[];
    for (var i = 0; i < PoliticaSeleccion.ejerciciosPorSesion; i++) {
      final elegido = _elegir(dominio: dominio, vistos: vistos)!;
      expect(vistos.add(elegido.ejercicio.id), isTrue, reason: 'no se repite');
      final c = elegido.ejercicio.concepto;
      conceptos.add(c);
      // Acierta siempre: el concepto sube y la política pasa al siguiente más flojo.
      dominio[c] = bkt.actualizar(dominioDe(dominio, c), true);
    }
    expect(conceptos.take(3), ['A', 'B', 'C']);
    expect(vistos, hasLength(6));
  });
}
