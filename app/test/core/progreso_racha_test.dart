import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/progreso.dart';
import 'package:tuturno/core/providers.dart';

// Racha amable (plan v2, producto §5.5): suma un día cada día con lección, hay un día de descanso cada 7 días y la
// mejor racha nunca baja.

/// Un móvil con [inicial] guardado y un reloj que se puede mover con [_Movil.dia].
class _Movil {
  _Movil._(this.contenedor, this._reloj);

  final ProviderContainer contenedor;
  final List<DateTime> _reloj;

  static Future<_Movil> abrir({Map<String, Object> inicial = const {}, required DateTime ahora}) async {
    SharedPreferences.setMockInitialValues(inicial);
    final prefs = await SharedPreferences.getInstance();
    final reloj = [ahora];
    final contenedor = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        relojProvider.overrideWithValue(() => reloj.first),
      ],
    );
    addTearDown(contenedor.dispose);
    return _Movil._(contenedor, reloj);
  }

  Progreso get progreso => contenedor.read(progresoProvider);

  /// Pone el reloj en el día [n] de octubre de 2026, a las 18:00.
  void dia(int n) => _reloj.first = DateTime(2026, 10, n, 18);

  /// Completa una lección el día [n] de octubre de 2026.
  Future<void> leccionEl(int n) async {
    dia(n);
    await contenedor.read(progresoProvider.notifier).completarLeccion('U1-L1');
  }
}

DateTime _octubre(int n) => DateTime(2026, 10, n);

void main() {
  group('completarLeccion', () {
    test('1 · el día siguiente suma uno', () async {
      final m = await _Movil.abrir(ahora: DateTime(2026, 10, 1, 18));
      await m.leccionEl(1);
      expect(m.progreso.racha, 1);
      await m.leccionEl(2);
      expect(m.progreso.racha, 2);
      await m.leccionEl(2);
      expect(m.progreso.racha, 2, reason: 'el mismo día no suma otra vez');
      expect(m.progreso.descansoUsado, isNull, reason: 'sin huecos no se gasta el descanso');
    });

    test('2 · con un día sin lección en medio y descanso disponible, suma uno y el descanso es ayer', () async {
      final m = await _Movil.abrir(ahora: DateTime(2026, 10, 1, 18));
      await m.leccionEl(1);
      await m.leccionEl(2);
      await m.leccionEl(4);
      expect(m.progreso.racha, 3);
      expect(m.progreso.descansoUsado, _octubre(3));
      expect(m.progreso.ultimoDiaConLeccion, _octubre(4));
    });

    test('3 · otro hueco de un día antes de 7 días: la racha vuelve a empezar', () async {
      final m = await _Movil.abrir(ahora: DateTime(2026, 10, 1, 18));
      await m.leccionEl(1);
      await m.leccionEl(3); // descanso el 2
      await m.leccionEl(4);
      await m.leccionEl(6); // el 5 sin lección: solo han pasado 4 días desde el último descanso
      expect(m.progreso.racha, 1);
      expect(m.progreso.descansoUsado, _octubre(2), reason: 'no se gasta otro');
      expect(m.progreso.mejorRacha, 3);
    });

    test('4 · a los 7 días del último descanso, vuelve a haber uno (y no antes)', () async {
      final m = await _Movil.abrir(ahora: DateTime(2026, 10, 1, 18));
      await m.leccionEl(1);
      await m.leccionEl(3); // descanso el 2
      for (final dia in [4, 5, 6, 7, 8]) {
        await m.leccionEl(dia);
      }
      expect(m.progreso.racha, 7);
      await m.leccionEl(10); // el 9 sin lección: 7 días después del descanso del 2
      expect(m.progreso.racha, 8);
      expect(m.progreso.descansoUsado, _octubre(9));

      // Con el hueco un día antes (el 8, a 6 días del descanso del 2), ya no hay: serían dos en la misma semana.
      final antes = await _Movil.abrir(ahora: DateTime(2026, 10, 1, 18));
      await antes.leccionEl(1);
      await antes.leccionEl(3); // descanso el 2
      for (final dia in [4, 5, 6, 7]) {
        await antes.leccionEl(dia);
      }
      await antes.leccionEl(9);
      expect(antes.progreso.racha, 1);
      expect(antes.progreso.descansoUsado, _octubre(2));
    });

    test('5 · la mejor racha nunca baja', () async {
      final m = await _Movil.abrir(ahora: DateTime(2026, 10, 1, 18));
      for (final dia in [1, 2, 3]) {
        await m.leccionEl(dia);
      }
      expect(m.progreso.mejorRacha, 3);
      await m.leccionEl(10);
      expect(m.progreso.racha, 1);
      expect(m.progreso.mejorRacha, 3);
      await m.leccionEl(11);
      expect(m.progreso.mejorRacha, 3);
      for (final dia in [12, 13]) {
        await m.leccionEl(dia);
      }
      expect(m.progreso.racha, 4);
      expect(m.progreso.mejorRacha, 4);
    });

    test('6 · un JSON antiguo, sin los campos nuevos, se lee bien y sigue sumando', () async {
      final antiguo = {
        'xp': 120,
        'racha': 5,
        'ultimo_dia': _octubre(19).toIso8601String(),
        'lecciones': ['U1-L1', 'U1-L2'],
        'dominio': {'C-ser-oido': 0.5},
        'ultima_practica': {'C-ser-oido': DateTime(2026, 10, 19, 17).toIso8601String()},
        'cartas': ['R-ser-escuchada'],
        'casos': <String>[],
      };
      final p = Progreso.fromJson(antiguo);
      expect(p.mejorRacha, 0);
      expect(p.descansoUsado, isNull);
      expect(p.personasConocidas, isEmpty);
      expect(p.xp, 120);
      expect(p.racha, 5);
      expect(p.leccionesCompletadas, {'U1-L1', 'U1-L2'});
      expect(p.dominio, {'C-ser-oido': 0.5});
      expect(p.cartas, {'R-ser-escuchada'});

      final m = await _Movil.abrir(inicial: {'progreso': jsonEncode(antiguo)}, ahora: DateTime(2026, 10, 20, 18));
      expect(m.progreso.racha, 5);
      expect(
        estadoRacha(m.progreso, DateTime(2026, 10, 20, 9)).mejor,
        5,
        reason: 'la mejor no es menor que la guardada',
      );
      await m.leccionEl(20);
      expect(m.progreso.racha, 6);
      expect(m.progreso.mejorRacha, 6);

      // Una racha antigua cortada también cuenta como la mejor.
      final cortada = await _Movil.abrir(inicial: {'progreso': jsonEncode(antiguo)}, ahora: DateTime(2026, 10, 28, 18));
      await cortada.leccionEl(28);
      expect(cortada.progreso.racha, 1);
      expect(cortada.progreso.mejorRacha, 5);
    });

    test('6b · los campos nuevos con valores raros se leen con su valor inicial', () {
      final p = Progreso.fromJson({'mejor_racha': 'mucho', 'descanso': 3, 'juzgado': 'juez'});
      expect(p.mejorRacha, 0);
      expect(p.descansoUsado, isNull);
      expect(p.personasConocidas, isEmpty);
      expect(
        Progreso.fromJson({
          'juzgado': ['juez', 3, 'fiscal'],
        }).personasConocidas,
        {'juez', 'fiscal'},
      );
    });

    test('7 · el cambio de hora de primavera no rompe la cuenta (días contados en UTC)', () async {
      // En España, el 28 de marzo de 2027 dura 23 horas.
      final m = await _Movil.abrir(ahora: DateTime(2027, 3, 27, 18));
      await m.contenedor.read(progresoProvider.notifier).completarLeccion('U1-L1');
      m._reloj.first = DateTime(2027, 3, 28, 18);
      await m.contenedor.read(progresoProvider.notifier).completarLeccion('U1-L1');
      expect(m.progreso.racha, 2);
      m._reloj.first = DateTime(2027, 3, 30, 9);
      await m.contenedor.read(progresoProvider.notifier).completarLeccion('U1-L1');
      expect(m.progreso.racha, 3, reason: 'el 29 es el día de descanso');
      expect(m.progreso.descansoUsado, DateTime(2027, 3, 29));

      // Con el cambio de hora en el hueco: del 27 al 29 son dos días, no uno.
      final otro = await _Movil.abrir(ahora: DateTime(2027, 3, 27, 18));
      await otro.contenedor.read(progresoProvider.notifier).completarLeccion('U1-L1');
      otro._reloj.first = DateTime(2027, 3, 29, 8);
      await otro.contenedor.read(progresoProvider.notifier).completarLeccion('U1-L1');
      expect(otro.progreso.racha, 2);
      expect(otro.progreso.descansoUsado, DateTime(2027, 3, 28));
    });

    test('con el reloj hacia atrás, la racha no se corta', () async {
      final m = await _Movil.abrir(ahora: DateTime(2026, 10, 1, 18));
      for (final dia in [10, 11]) {
        await m.leccionEl(dia);
      }
      await m.leccionEl(9);
      expect(m.progreso.racha, 2);
    });
  });

  group('descansoDisponible', () {
    test('sin estrenar, o cuando el nuevo descanso (ayer) quedaría 7 días después del último', () {
      expect(descansoDisponible(const Progreso(), _octubre(1)), isTrue);
      final usado = Progreso(descansoUsado: _octubre(2));
      // El 9, el descanso sería el 8: a 6 días del anterior.
      expect(descansoDisponible(usado, DateTime(2026, 10, 9, 23, 59)), isFalse);
      // El 10, el descanso sería el 9: a 7 días.
      expect(descansoDisponible(usado, DateTime(2026, 10, 10, 0, 1)), isTrue);
    });
  });

  group('estadoRacha', () {
    final ahora = DateTime(2026, 10, 22, 9);

    test('sinRacha: sin lecciones, con la racha cortada o con un hueco sin descanso', () {
      expect(estadoRacha(const Progreso(), ahora), const EstadoRacha(dias: 0, mejor: 0, tipo: TipoRacha.sinRacha));
      expect(
        estadoRacha(Progreso(racha: 4, mejorRacha: 6, ultimoDiaConLeccion: _octubre(18)), ahora),
        const EstadoRacha(dias: 0, mejor: 6, tipo: TipoRacha.sinRacha),
      );
      expect(
        estadoRacha(
          Progreso(racha: 4, mejorRacha: 4, ultimoDiaConLeccion: _octubre(20), descansoUsado: _octubre(17)),
          ahora,
        ),
        const EstadoRacha(dias: 0, mejor: 4, tipo: TipoRacha.sinRacha),
      );
    });

    test('hoyHecha: la última lección es de hoy', () {
      expect(
        estadoRacha(Progreso(racha: 3, mejorRacha: 5, ultimoDiaConLeccion: _octubre(22)), ahora),
        const EstadoRacha(dias: 3, mejor: 5, tipo: TipoRacha.hoyHecha),
      );
    });

    test('pendienteHoy: la última fue ayer', () {
      expect(
        estadoRacha(
          Progreso(racha: 3, mejorRacha: 3, ultimoDiaConLeccion: _octubre(21)),
          DateTime(2026, 10, 22, 23, 59),
        ),
        const EstadoRacha(dias: 3, mejor: 3, tipo: TipoRacha.pendienteHoy),
      );
    });

    test('conDescanso: ayer no hubo lección, pero queda día de descanso', () {
      expect(
        estadoRacha(Progreso(racha: 3, mejorRacha: 3, ultimoDiaConLeccion: _octubre(20)), ahora),
        const EstadoRacha(dias: 3, mejor: 3, tipo: TipoRacha.conDescanso),
      );
      expect(
        estadoRacha(
          Progreso(racha: 3, mejorRacha: 3, ultimoDiaConLeccion: _octubre(20), descansoUsado: _octubre(14)),
          ahora,
        ),
        const EstadoRacha(dias: 3, mejor: 3, tipo: TipoRacha.conDescanso),
      );
    });

    test('la mejor nunca es menor que la racha guardada', () {
      expect(estadoRacha(Progreso(racha: 3, ultimoDiaConLeccion: _octubre(22)), ahora).mejor, 3);
    });

    test('el día después del cambio de hora, la de ayer sigue pendiente', () {
      final p = Progreso(racha: 4, mejorRacha: 4, ultimoDiaConLeccion: DateTime(2027, 3, 28));
      expect(estadoRacha(p, DateTime(2027, 3, 29, 9)).tipo, TipoRacha.pendienteHoy);
    });

    test('lo que guarda completarLeccion se ve como hoyHecha ese día', () async {
      final m = await _Movil.abrir(ahora: DateTime(2026, 10, 1, 18));
      await m.leccionEl(1);
      await m.leccionEl(2);
      expect(
        estadoRacha(m.progreso, DateTime(2026, 10, 2, 22)),
        const EstadoRacha(dias: 2, mejor: 2, tipo: TipoRacha.hoyHecha),
      );
      expect(estadoRacha(m.progreso, DateTime(2026, 10, 3, 8)).tipo, TipoRacha.pendienteHoy);
      expect(estadoRacha(m.progreso, DateTime(2026, 10, 4, 8)).tipo, TipoRacha.conDescanso);
      expect(
        estadoRacha(m.progreso, DateTime(2026, 10, 5, 8)),
        const EstadoRacha(dias: 0, mejor: 2, tipo: TipoRacha.sinRacha),
      );
    });
  });
}
