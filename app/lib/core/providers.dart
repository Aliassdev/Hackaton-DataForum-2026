import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ajustes.dart';
import 'api/http_api.dart';
import 'api/mock_api.dart';
import 'api/tuturno_api.dart';
import 'config.dart';
import 'content_models.dart';
import 'content_repo.dart';
import 'storage.dart';

/// Se sobrescribe en main() con la configuración leída al arrancar.
final configProvider = Provider<AppConfig>((ref) => throw UnimplementedError('Se sobrescribe en main()'));

/// Se sobrescribe en main() con la instancia ya cargada.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Se sobrescribe en main()'),
);

final storageProvider = Provider<Storage>((ref) => Storage(ref.watch(sharedPreferencesProvider)));

final ajustesProvider = NotifierProvider<AjustesNotifier, Ajustes>(AjustesNotifier.new);

class AjustesNotifier extends Notifier<Ajustes> {
  @override
  Ajustes build() => ref.watch(storageProvider).leerAjustes();

  Future<void> actualizar(Ajustes Function(Ajustes actuales) cambio) async {
    state = cambio(state);
    await ref.read(storageProvider).guardarAjustes(state);
  }
}

/// Las pantallas de bienvenida se enseñan solo la primera vez.
final bienvenidaVistaProvider = NotifierProvider<BienvenidaVistaNotifier, bool>(BienvenidaVistaNotifier.new);

class BienvenidaVistaNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(storageProvider).bienvenidaVista;

  Future<void> marcar() async {
    state = true;
    await ref.read(storageProvider).marcarBienvenidaVista();
  }

  /// Para el modo DEMO: la bienvenida vuelve a salir.
  Future<void> desmarcar() async {
    state = false;
    await ref.read(storageProvider).desmarcarBienvenidaVista();
  }
}

/// La URL de Ajustes, si se ha puesto; si no, la de arranque (API_URL o config.json).
final apiUrlProvider = Provider<String>((ref) {
  final manual = ref.watch(ajustesProvider.select((a) => a.apiUrlManual))?.trim();
  return manual != null && manual.isNotEmpty ? manual : ref.watch(configProvider).apiUrl;
});

final apiProvider = Provider<TuTurnoApi>((ref) {
  if (ref.watch(configProvider).useMock) return MockTuTurnoApi();
  final api = HttpTuTurnoApi(baseUrl: ref.watch(apiUrlProvider));
  ref.onDispose(api.close);
  return api;
});

/// Interruptor del modo DEMO (sección 6.8): enseñar también los borradores. Solo tiene efecto con DEMO=true.
final mostrarBorradoresProvider = NotifierProvider<MostrarBorradoresNotifier, bool>(MostrarBorradoresNotifier.new);

class MostrarBorradoresNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void cambiar(bool valor) => state = valor;
}

/// Carga y guarda en memoria los JSON de contenido (sección 6.4). Mientras no haya contenido en content/,
/// se usan los ejemplos de assets/mock/content (escritos a partir de docs/MARCO_LEGAL.md), también sin USE_MOCK:
/// así la demo nunca sale vacía. El contenido real, cuando exista, tiene prioridad.
final contentProvider = Provider<ContentRepo>((ref) {
  final config = ref.watch(configProvider);
  return ContentRepo(usarEjemplos: true, mostrarBorradores: config.demo && ref.watch(mostrarBorradoresProvider));
});

final glosarioProvider = FutureProvider<List<EntradaGlosario>>((ref) => ref.watch(contentProvider).glosario());
