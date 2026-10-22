import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

// «Mis palabras» del glosario (plan v2, producto §5.7): las palabras que alguien guarda para tenerlas a mano. Solo
// se guardan en el móvil, como el resto del progreso. «Borrar todo» borra su clave (lib/core/borrar_todo.dart).

/// Los ids de las palabras guardadas en «Mis palabras». Los ids que ya no están en el glosario se ignoran al enseñar
/// la lista (no se borran: si la palabra vuelve, vuelve a estar guardada).
///
/// Vive solo mientras se ve el glosario (autoDispose) y al volver se lee otra vez del móvil: así, después de «Borrar
/// todo» (que se hace desde Ajustes, con el glosario cerrado), no quedan palabras guardadas en memoria.
final favoritosProvider = NotifierProvider.autoDispose<FavoritosNotifier, Set<String>>(FavoritosNotifier.new);

class FavoritosNotifier extends Notifier<Set<String>> {
  /// Clave en shared_preferences: una lista JSON de ids, p. ej. `["G-citacion"]`.
  static const clave = 'glosario.favoritos';

  /// Un valor roto o de otro tipo da la lista vacía.
  @override
  Set<String> build() {
    try {
      final guardado = ref.watch(sharedPreferencesProvider).getString(clave);
      if (guardado == null) return const {};
      final datos = jsonDecode(guardado);
      if (datos is! List) return const {};
      return Set.unmodifiable({
        for (final id in datos)
          if (id is String && id.trim().isNotEmpty) id.trim(),
      });
    } catch (_) {
      return const {};
    }
  }

  bool contiene(String id) => state.contains(id);

  void guardar(String id) {
    if (id.trim().isEmpty || state.contains(id)) return;
    _cambiar({...state, id});
  }

  void quitar(String id) {
    if (!state.contains(id)) return;
    _cambiar({...state}..remove(id));
  }

  /// Guarda la palabra si no estaba y la quita si estaba. Devuelve si queda guardada.
  bool alternar(String id) {
    if (state.contains(id)) {
      quitar(id);
      return false;
    }
    guardar(id);
    return state.contains(id);
  }

  void _cambiar(Set<String> ids) {
    state = Set.unmodifiable(ids);
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString(clave, jsonEncode([...ids]))
          .then<void>((_) {}, onError: (Object _) {}),
    );
  }
}
