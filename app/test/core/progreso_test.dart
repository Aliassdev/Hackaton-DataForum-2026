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

    test('dos días sin lecciones la reinician, también con el cambio de hora por medio', () async {
      final c = await _contenedor(ultimoDia: DateTime(2027, 3, 27), ahora: DateTime(2027, 3, 29, 18));
      await c.read(progresoProvider.notifier).completarLeccion('U1-L1');
      expect(c.read(progresoProvider).racha, 1);
    });
  });
}
