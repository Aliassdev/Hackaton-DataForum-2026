import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo.dart';
import 'entrada.dart';
import 'mis_preguntas.dart';
import 'progreso.dart';
import 'providers.dart';

// «Borrar todo lo de este móvil» (plan v2, producto §5.3): deja TuTurno como recién instalado, salvo los ajustes de
// letra, voz, lectura, animaciones y servidor (todas las claves 'ajustes.*'), que se quedan.

/// Claves de shared_preferences con lo que hace o cuenta quien usa la app. Cada tarea que guarde algo nuevo de uso
/// añade aquí su clave. Ninguna empieza por 'ajustes.': esas se conservan siempre.
const clavesDeUsuario = <String>[
  ProgresoNotifier.clave, // 'progreso': XP, racha, lecciones, dominio, cartas, casos y personas del juzgado
  EntradaNotifier.clave, // 'entrada': el ticket (edad, proceso, papel y momento)
  MisPreguntasNotifier.clave, // 'mis_preguntas'
  'inicio.turno_del_dia', // TurnoDelDiaNotifier.clave (lib/features/inicio/turno_del_dia.dart)
  'glosario.favoritos', // «Mis palabras» del glosario (lib/features/glosario/favoritos.dart)
  'bienvenida_vista', // la bienvenida ya vista (lib/core/storage.dart)
];

/// Borra [clavesDeUsuario] e invalida los providers de lib/core que las leen ([progresoProvider], [entradaProvider],
/// [misPreguntasProvider] y [bienvenidaVistaProvider]) y el atajo pendiente de la demo ([escenaInicialProvider]). Los
/// providers de las pantallas los invalida quien llama, que también decide adónde volver: el turno del día, los
/// favoritos del glosario, el chat y las partidas a medias de Vive el caso (`partidaProvider`, que vive en memoria
/// mientras la app está abierta: sin invalidarlo, la lista de casos seguiría diciendo «Escena 5 de 11»).
Future<void> borrarTodo(WidgetRef ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  for (final clave in clavesDeUsuario) {
    if (clave.startsWith('ajustes.')) continue;
    await prefs.remove(clave);
  }
  ref
    ..invalidate(progresoProvider)
    ..invalidate(entradaProvider)
    ..invalidate(misPreguntasProvider)
    ..invalidate(bienvenidaVistaProvider)
    ..invalidate(escenaInicialProvider);
}
