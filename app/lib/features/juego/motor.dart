import 'package:flutter/foundation.dart';

import 'modelos.dart';

/// Una partida de un caso: por qué escenas ha pasado, qué se ha elegido en la actual y qué cartas se han ganado.
///
/// Es inmutable y no sabe nada de pantallas ni de lo guardado: cada acción devuelve una partida nueva (o la misma,
/// si la acción no tiene sentido en ese momento). Lo que se guarda en el móvil lo hace PartidaNotifier.
@immutable
class Partida {
  const Partida._({
    required this.caso,
    required this.recorrido,
    this.eleccion,
    this.cartasGanadas = const [],
    this.cartaNueva,
    this.terminada = false,
  });

  /// Empieza por la primera escena.
  factory Partida.nueva(Caso caso) => Partida._(caso: caso, recorrido: [caso.primera.id]);

  final Caso caso;

  /// Escenas visitadas, en orden. La última es la actual.
  final List<String> recorrido;

  /// Opción elegida en la escena actual (null si aún no se ha decidido o la escena no tiene decisión).
  final int? eleccion;

  /// Cartas ganadas en esta partida, en el orden en que se ganaron.
  final List<String> cartasGanadas;

  /// Carta que la elección actual acaba de añadir a la colección (no se tenía de antes): se enseña con una animación.
  final Carta? cartaNueva;

  final bool terminada;

  Escena get escena => caso.escena(recorrido.last) ?? caso.primera;

  Decision? get decision => escena.decision;

  Opcion? get opcionElegida => switch ((decision, eleccion)) {
    (final d?, final i?) => d.opciones[i],
    _ => null,
  };

  /// La opción elegida es correcta.
  bool get acierto => opcionElegida?.correcta ?? false;

  /// Carta que da la opción elegida (aunque ya se tuviera de otra partida).
  Carta? get cartaDeLaEleccion {
    final opcion = opcionElegida;
    final id = opcion?.carta;
    return opcion != null && opcion.correcta && id != null ? caso.carta(id) : null;
  }

  /// Se puede pasar a la siguiente escena: no hay decisión o ya se ha elegido.
  bool get puedeAvanzar => !terminada && (decision == null || eleccion != null);

  /// Escena a la que se irá al avanzar. null si con esta acaba el caso.
  String? get siguienteId {
    final id = decision == null ? escena.siguiente : opcionElegida?.siguiente;
    return id != null && caso.escena(id) != null ? id : null;
  }

  /// Al avanzar desde aquí se termina el caso.
  bool get alAvanzarTermina => puedeAvanzar && siguienteId == null;

  /// Número de la escena actual (empieza en 1).
  int get numeroEscena => recorrido.length;

  /// Total estimado: las escenas ya vistas más las que faltan por el camino más corto.
  int get totalEscenas => recorrido.length + caso.distanciaAlFinal(escena.id);

  /// Ya se ha hecho algo: hay algo que retomar.
  bool get empezada => terminada || recorrido.length > 1 || eleccion != null;

  /// Elige la opción [indice] de la decisión actual. Si es correcta y tiene carta, la carta se gana; si además no
  /// está en [coleccion] (las cartas que ya se tenían), queda como [cartaNueva].
  Partida elegir(int indice, {Set<String> coleccion = const {}}) {
    final d = decision;
    if (terminada || d == null || eleccion != null || indice < 0 || indice >= d.opciones.length) return this;
    final opcion = d.opciones[indice];
    final id = opcion.carta;
    final carta = opcion.correcta && id != null ? caso.carta(id) : null;
    return Partida._(
      caso: caso,
      recorrido: recorrido,
      eleccion: indice,
      cartasGanadas: carta == null || cartasGanadas.contains(carta.id) ? cartasGanadas : [...cartasGanadas, carta.id],
      cartaNueva: carta != null && !coleccion.contains(carta.id) ? carta : null,
    );
  }

  /// Tras una respuesta que no era la correcta, se puede volver a elegir. Con una correcta no hace nada.
  Partida reintentar() {
    if (terminada || eleccion == null || acierto) return this;
    return Partida._(caso: caso, recorrido: recorrido, cartasGanadas: cartasGanadas);
  }

  /// Pasa a la escena siguiente o, si no hay, termina el caso.
  Partida avanzar() {
    if (!puedeAvanzar) return this;
    final siguiente = siguienteId;
    return Partida._(
      caso: caso,
      recorrido: siguiente == null ? recorrido : [...recorrido, siguiente],
      cartasGanadas: cartasGanadas,
      terminada: siguiente == null,
    );
  }
}
