import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/progreso.dart';
import 'package:tuturno/core/providers.dart';

/// Progreso con la última lección en [ultimoDia] y el reloj puesto en [ahora].
Future<ProviderContainer> _contenedor({required DateTime ultimoDia, required DateTime ahora, int racha = 2}) async {
  SharedPreferences.setMockInitialValues({
    'progreso': jsonEncode(Progreso(racha: racha, ultimoDiaConLeccion: ultimoDia).toJson()),
  });
  final prefs = await SharedPreferences.getInstance();
  final contenedor = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs), relojProvider.overrideWithValue(() => ahora)],
  );
  addTearDown(contenedor.dispose);
  return contenedor;
}

void main() {
  group('racha (sección 10.6: +1 por día con al menos una lección)', () {
    test('sube si la anterior fue ayer y se queda igual si fue hoy', () async {
      final ayer = await _contenedor(ultimoDia: DateTime(2026, 10, 20), ahora: DateTime(2026, 10, 21, 18));
      await ayer.read(progresoProvider.notifier).completarLeccion('U1-L1');
      expect(ayer.read(progresoProvider).racha, 3);
      expect(ayer.read(progresoProvider).ultimoDiaConLeccion, DateTime(2026, 10, 21));

      final hoy = await _contenedor(ultimoDia: DateTime(2026, 10, 21), ahora: DateTime(2026, 10, 21, 20));
      await hoy.read(progresoProvider.notifier).completarLeccion('U1-L2');
      expect(hoy.read(progresoProvider).racha, 2);
    });

    test('sube el día después del cambio de hora de primavera (un día de 23 horas)', () async {
      final c = await _contenedor(ultimoDia: DateTime(2027, 3, 28), ahora: DateTime(2027, 3, 29, 18));
      await c.read(progresoProvider.notifier).completarLeccion('U1-L1');
      expect(c.read(progresoProvider).racha, 3);
    });

    test('tres días sin lecciones la reinician, también con el cambio de hora por medio', () async {
      final c = await _contenedor(ultimoDia: DateTime(2027, 3, 26), ahora: DateTime(2027, 3, 29, 18));
      await c.read(progresoProvider.notifier).completarLeccion('U1-L1');
      expect(c.read(progresoProvider).racha, 1);
    });

    test(
      'un solo día sin lección no la corta: es el día de descanso de la semana (más en progreso_racha_test)',
      () async {
        final c = await _contenedor(ultimoDia: DateTime(2027, 3, 27), ahora: DateTime(2027, 3, 29, 18));
        await c.read(progresoProvider.notifier).completarLeccion('U1-L1');
        expect(c.read(progresoProvider).racha, 3);
        expect(c.read(progresoProvider).descansoUsado, DateTime(2027, 3, 28));
      },
    );
  });

  group('juzgado explorable: conocerPersona', () {
    test('añade la persona una vez y se recuerda al volver a abrir la app', () async {
      final c = await _contenedor(ultimoDia: DateTime(2026, 10, 20), ahora: DateTime(2026, 10, 21, 18));
      final notifier = c.read(progresoProvider.notifier);
      await notifier.conocerPersona('juez');
      await notifier.conocerPersona('fiscal');
      await notifier.conocerPersona('juez');
      await notifier.conocerPersona('');
      expect(c.read(progresoProvider).personasConocidas, {'juez', 'fiscal'});
      expect(c.read(progresoProvider).racha, 2, reason: 'no toca nada más');

      final prefs = c.read(sharedPreferencesProvider);
      final otra = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(otra.dispose);
      expect(otra.read(progresoProvider).personasConocidas, {'juez', 'fiscal'});
      expect(jsonDecode(prefs.getString('progreso')!)['juzgado'], unorderedEquals(['juez', 'fiscal']));
    });
  });

  group('reemplazar', () {
    test('cambia todo el progreso de una vez y lo guarda', () async {
      final c = await _contenedor(ultimoDia: DateTime(2026, 10, 20), ahora: DateTime(2026, 10, 21, 18), racha: 9);
      await c.read(progresoProvider.notifier).sumarXp(500);
      final nuevo = Progreso(
        xp: 340,
        racha: 4,
        mejorRacha: 4,
        ultimoDiaConLeccion: DateTime(2026, 10, 20),
        leccionesCompletadas: const {'U1-L1'},
        cartas: const {'R-ser-escuchada'},
      );
      await c.read(progresoProvider.notifier).reemplazar(nuevo);
      expect(c.read(progresoProvider).toJson(), nuevo.toJson());

      final otra = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(c.read(sharedPreferencesProvider))],
      );
      addTearDown(otra.dispose);
      expect(otra.read(progresoProvider).toJson(), nuevo.toJson());
    });

    test('reemplazar dos veces con lo mismo deja el mismo estado', () async {
      final c = await _contenedor(ultimoDia: DateTime(2026, 10, 20), ahora: DateTime(2026, 10, 21, 18));
      final nuevo = Progreso(xp: 10, racha: 1, ultimoDiaConLeccion: DateTime(2026, 10, 21));
      await c.read(progresoProvider.notifier).reemplazar(nuevo);
      final primero = c.read(sharedPreferencesProvider).getString('progreso');
      await c.read(progresoProvider.notifier).reemplazar(nuevo);
      expect(c.read(sharedPreferencesProvider).getString('progreso'), primero);
    });
  });

  group('Progreso en JSON', () {
    test('ida y vuelta con los campos nuevos', () {
      final p = Progreso(
        xp: 5,
        racha: 2,
        mejorRacha: 7,
        ultimoDiaConLeccion: DateTime(2026, 10, 21),
        descansoUsado: DateTime(2026, 10, 18),
        personasConocidas: const {'laj'},
      );
      final leido = Progreso.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(leido.mejorRacha, 7);
      expect(leido.descansoUsado, DateTime(2026, 10, 18));
      expect(leido.personasConocidas, {'laj'});
      expect(leido.toJson(), p.toJson());
    });
  });
}
