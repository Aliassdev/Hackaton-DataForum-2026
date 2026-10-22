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
  // «Tu ticket» de Mi situación (MiTicketNotifier.clave, lib/features/situacion/mi_ticket.dart): con quién irás, qué
  // te preocupa, cómo prefieres que te lo cuente y «Tu día» (la fecha y la hora de la cita y qué llevar).
  'mi_situacion',
  'bienvenida_vista', // la bienvenida ya vista (lib/core/storage.dart)
];

/// Cuántas veces se ha borrado todo en esta ejecución de la app. Los providers de las pantallas que guardan una clave
/// de [clavesDeUsuario] y viven mientras la app está abierta lo vigilan (`ref.watch`) para volver a leer el móvil
/// después de [borrarTodo], sin que lib/core tenga que conocerlos. Por ejemplo, «Tu ticket» de Mi situación: sin esto,
/// con el ticket de la app ya vacío, nada le avisaba y seguía enseñando (y volvía a guardar) la fecha de la cita.
final borradoProvider = NotifierProvider<BorradoNotifier, int>(BorradoNotifier.new);

class BorradoNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void marcar() => state++;
}

/// Borra [clavesDeUsuario] e invalida los providers de lib/core que las leen ([progresoProvider], [entradaProvider],
/// [misPreguntasProvider] y [bienvenidaVistaProvider]) y el atajo pendiente de la demo ([escenaInicialProvider]), y
/// avisa con [borradoProvider] a los de las pantallas que lo vigilan (como «Tu ticket» de Mi situación). Los demás
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
  ref.read(borradoProvider.notifier).marcar();
}
