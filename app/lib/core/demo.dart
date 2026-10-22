import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'entrada.dart';
import 'progreso.dart';

// Estado para preparar la demo (plan v2, demo §3.1 y §3.5): lo usan Ajustes → «Para el equipo (demo)», Vive el caso
// (atajos a una escena) y Pregunta (forzar el ejemplo). Nada de esto se enseña sin el modo DEMO.

/// Progreso con el que empieza cada ensayo: el mismo durante todo el día, por muchas veces que se prepare.
///
/// - 340 XP y una racha de 4 días con la última lección ayer: al completar una lección en directo sube a 5 (y es la
///   mejor racha).
/// - U1-L1 y U1-L2 hechas: el mapa tiene camino recorrido.
/// - Dominio a medias en C-ser-oido (0,8), C-fiscalia (0,6) y C-comunicar-violencia (0,4), practicados hace 3 días.
/// - Dos cartas, R-ser-escuchada y R-sin-cruzarte. Sin R-una-sola-vez, R-entender, R-acompanada ni R-familia: se
///   ganan en directo y su animación tiene que salir.
/// - Ningún caso terminado: el final de Lucía no se estropea.
Progreso progresoDemo(DateTime ahora) {
  final ayer = DateTime(ahora.year, ahora.month, ahora.day - 1);
  final haceTresDias = DateTime(ahora.year, ahora.month, ahora.day - 3, 12);
  return Progreso(
    xp: 340,
    racha: 4,
    mejorRacha: 4,
    ultimoDiaConLeccion: ayer,
    leccionesCompletadas: const {'U1-L1', 'U1-L2'},
    dominio: const {'C-ser-oido': 0.8, 'C-fiscalia': 0.6, 'C-comunicar-violencia': 0.4},
    ultimaPractica: {'C-ser-oido': haceTresDias, 'C-fiscalia': haceTresDias, 'C-comunicar-violencia': haceTresDias},
    cartas: const {'R-ser-escuchada', 'R-sin-cruzarte'},
  );
}

/// El ticket de Sergio para la demo: 13 años · Penal · Víctima · Durante.
const entradaDemoSergio = Entrada(
  edad: 13,
  procedimiento: Procedimiento.penal,
  rol: RolEntrada.victima,
  fase: Fase.durante,
);

/// Escena por la que empieza un caso de Vive el caso (atajos de la demo, como Lucía en la escena S5).
typedef EscenaInicial = ({String casoId, String escenaId});

/// Atajo pendiente a una escena, solo en memoria. Ajustes lo fija antes de abrir el caso y Vive el caso lo consume al
/// abrirlo: una sola vez.
final escenaInicialProvider = NotifierProvider<EscenaInicialNotifier, EscenaInicial?>(EscenaInicialNotifier.new);

class EscenaInicialNotifier extends Notifier<EscenaInicial?> {
  /// Lo que manda: [consumir] lo cambia al momento, aunque el estado visible se ponga al día un poco después.
  EscenaInicial? _pendiente;

  @override
  EscenaInicial? build() => _pendiente = null;

  void fijar(String casoId, String escenaId) => state = _pendiente = (casoId: casoId, escenaId: escenaId);

  /// La escena pendiente si es de [casoId], que deja de estar pendiente (una segunda llamada ya da null). Si no hay
  /// ninguna o es de otro caso, null, y la de otro caso sigue esperando a su caso.
  ///
  /// Se puede llamar al abrir el caso: en initState, en build o en el build de un provider. Ahí Riverpod no deja
  /// cambiar el estado de un provider, así que el estado visible pasa a null justo después (en una microtarea).
  String? consumir(String casoId) {
    final pendiente = _pendiente;
    if (pendiente == null || pendiente.casoId != casoId) return null;
    _pendiente = null;
    scheduleMicrotask(() {
      if (ref.mounted && _pendiente == null) state = null;
    });
    return pendiente.escenaId;
  }
}

/// «Usar siempre el ejemplo en Pregunta» (solo en memoria): si la red del recinto va mal, Pregunta enseña la
/// conversación de ejemplo, siempre marcada «Ejemplo».
final usarEjemploPreguntaProvider = NotifierProvider<UsarEjemploPreguntaNotifier, bool>(
  UsarEjemploPreguntaNotifier.new,
);

class UsarEjemploPreguntaNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void cambiar(bool valor) => state = valor;
}
