import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'salida_plataforma_stub.dart' if (dart.library.js_interop) 'salida_plataforma_web.dart' as plataforma;
import 'voz/tts.dart';

// «Salir rápido» (plan v2, producto §5.3): para quien no está seguro en casa y necesita quitar TuTurno de la pantalla
// en un toque. No borra nada (para eso está «Borrar todo», lib/core/borrar_todo.dart). No se usa FLAG_SECURE: taparía
// la miniatura de «recientes», pero rompe las capturas y el espejo de scrcpy de la demo.

/// Pantalla neutra: solo el color del papel y un «Volver a TuTurno» discreto (la ruta está en lib/app.dart).
const rutaSalida = '/salida';

/// Cómo se quita TuTurno de la pantalla en cada plataforma. En los tests se sustituye por una falsa.
abstract interface class SalidaPlataforma {
  Future<void> salir();
}

/// En Android cierra la actividad (`SystemNavigator.pop()`); en la web, la pestaña va a una página neutra con
/// `location.replace`, que quita TuTurno del historial de la pestaña (la app ocupa una sola entrada: `routerNeglect`,
/// en lib/app.dart).
class SalidaPlataformaPorDefecto implements SalidaPlataforma {
  const SalidaPlataformaPorDefecto();

  @override
  Future<void> salir() => plataforma.salirDeTuTurno();
}

final salidaPlataformaProvider = Provider<SalidaPlataforma>((ref) => const SalidaPlataformaPorDefecto());

/// Quita TuTurno de la pantalla al momento: para la voz, pasa a la pantalla neutra ([rutaSalida]), espera a que se
/// pinte (así la miniatura de «recientes» es la pantalla neutra) y sale con [salidaPlataformaProvider]. No borra el
/// progreso.
///
/// Al ir a la pantalla neutra se cierran todas las pantallas. Pregunta es autoDispose: se cierran su conversación (que
/// solo estaba en memoria), la sesión del agente y el micrófono si estaba escuchando.
Future<void> salirRapido(BuildContext context, WidgetRef ref) async {
  // Todo se lee antes de navegar: al ir a la pantalla neutra, la pantalla desde la que se llama desaparece, y con ella
  // su [ref] y su [context].
  final salida = ref.read(salidaPlataformaProvider);
  final router = GoRouter.maybeOf(context);
  _pararVoz(ref);
  router?.go(rutaSalida);
  // El fotograma con la pantalla neutra, y uno más para que el móvil ya lo esté enseñando al salir.
  await WidgetsBinding.instance.endOfFrame;
  await WidgetsBinding.instance.endOfFrame;
  try {
    await salida.salir();
  } catch (_) {
    // Si la plataforma no deja salir, se queda la pantalla neutra, que no enseña nada.
  }
}

void _pararVoz(WidgetRef ref) {
  try {
    unawaited(ref.read(ttsProvider).parar().then<void>((_) {}, onError: (Object _) {}));
  } catch (_) {
    // Sin motor de voz no hay nada que parar.
  }
}
