import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/borrar_todo.dart';
import 'package:tuturno/core/entrada.dart';
import 'package:tuturno/core/mis_preguntas.dart';
import 'package:tuturno/core/progreso.dart';
import 'package:tuturno/core/providers.dart';
import 'package:tuturno/features/glosario/favoritos.dart' show FavoritosNotifier;
import 'package:tuturno/features/inicio/turno_del_dia.dart';
import 'package:tuturno/features/situacion/mi_ticket.dart' show MiTicketNotifier;

// «Borrar todo lo de este móvil» (plan v2, producto §5.3): borra lo de la persona y deja los ajustes.

const _ajustes = <String, Object>{
  'ajustes.tamano_texto': 1.3,
  'ajustes.voz_activada': false,
  'ajustes.velocidad_voz': 0.4,
  'ajustes.api_url': 'https://ejemplo.hf.space',
  'ajustes.lectura_facil': true,
  'ajustes.reducir_movimiento': true,
  'ajustes.agent_id': 'agente-de-prueba',
};

final _deUsuario = <String, Object>{
  'progreso': jsonEncode(
    Progreso(
      xp: 340,
      racha: 4,
      mejorRacha: 4,
      ultimoDiaConLeccion: DateTime(2026, 10, 21),
      cartas: const {'R-x'},
    ).toJson(),
  ),
  'entrada': jsonEncode({'edad': 13, 'procedimiento': 'penal', 'rol': 'victima', 'fase': 'durante'}),
  'mis_preguntas': jsonEncode([
    {'id': '1', 'texto': '¿Quién va a estar en la sala?', 'tipo': 'preguntar'},
  ]),
  'inicio.turno_del_dia': '{"dia": "2026-10-22"}',
  'glosario.favoritos': '["fiscal"]',
  'mi_situacion': '{"preocupaciones": ["ver_persona"], "fecha": "2026-10-24"}',
  'bienvenida_vista': true,
};

/// Monta un widget que mira los providers de lib/core (como las pantallas) y devuelve su ref.
Future<(WidgetRef, SharedPreferences)> _montar(WidgetTester tester, Map<String, Object> valores) async {
  SharedPreferences.setMockInitialValues(valores);
  final prefs = await SharedPreferences.getInstance();
  late WidgetRef capturado;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: Consumer(
        builder: (context, ref, _) {
          capturado = ref;
          ref
            ..watch(progresoProvider)
            ..watch(entradaProvider)
            ..watch(misPreguntasProvider)
            ..watch(bienvenidaVistaProvider);
          return const SizedBox();
        },
      ),
    ),
  );
  return (capturado, prefs);
}

void main() {
  testWidgets('borra lo de la persona, conserva todos los ajustes y los providers vuelven a empezar', (tester) async {
    final (ref, prefs) = await _montar(tester, {..._ajustes, ..._deUsuario, 'otra.clave': 'se queda'});
    expect(ref.read(progresoProvider).xp, 340);
    expect(ref.read(entradaProvider).edad, 13);
    expect(ref.read(misPreguntasProvider), hasLength(1));
    expect(ref.read(bienvenidaVistaProvider), isTrue);

    await borrarTodo(ref);
    await tester.pump();

    for (final clave in _deUsuario.keys) {
      expect(prefs.containsKey(clave), isFalse, reason: clave);
    }
    for (final MapEntry(:key, :value) in _ajustes.entries) {
      expect(prefs.get(key), value, reason: key);
    }
    expect(prefs.getString('otra.clave'), 'se queda', reason: 'solo borra las claves de clavesDeUsuario');

    final progreso = ref.read(progresoProvider);
    expect(progreso.xp, 0);
    expect(progreso.racha, 0);
    expect(progreso.mejorRacha, 0);
    expect(progreso.cartas, isEmpty);
    expect(ref.read(entradaProvider).vacia, isTrue);
    expect(ref.read(misPreguntasProvider), isEmpty);
    expect(ref.read(bienvenidaVistaProvider), isFalse);
  });

  testWidgets('con el móvil ya limpio no falla', (tester) async {
    final (ref, prefs) = await _montar(tester, _ajustes);
    await borrarTodo(ref);
    await tester.pump();
    expect(prefs.getKeys(), _ajustes.keys.toSet());
  });

  group('clavesDeUsuario', () {
    test('son las de lib/core y las de las pantallas, y ninguna es un ajuste', () {
      expect(clavesDeUsuario, [
        'progreso',
        'entrada',
        'mis_preguntas',
        'inicio.turno_del_dia',
        'glosario.favoritos',
        'mi_situacion',
        'bienvenida_vista',
      ]);
      expect(clavesDeUsuario.where((c) => c.startsWith('ajustes.')), isEmpty);
      expect(clavesDeUsuario.toSet(), hasLength(clavesDeUsuario.length));
    });

    test('coinciden con las que usan los providers', () {
      expect(clavesDeUsuario, contains(ProgresoNotifier.clave));
      expect(clavesDeUsuario, contains(EntradaNotifier.clave));
      expect(clavesDeUsuario, contains(MisPreguntasNotifier.clave));
      expect(clavesDeUsuario, contains(TurnoDelDiaNotifier.clave));
      expect(clavesDeUsuario, contains(FavoritosNotifier.clave));
      expect(clavesDeUsuario, contains(MiTicketNotifier.clave));
    });

    test('la de la bienvenida es la que lee Storage', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(c.dispose);
      await c.read(bienvenidaVistaProvider.notifier).marcar();
      expect(prefs.getKeys().where(clavesDeUsuario.contains), ['bienvenida_vista']);
    });
  });
}
