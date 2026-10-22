import 'package:flutter/foundation.dart';

import '../motor/motor.dart';

/// Un lugar de «Vive el caso» en pixel art: el [fondo] (160 × 96), las piezas del decorado que tapan a quien está
/// detrás ([delante]: el estrado, las mesas) y los [puestos] donde se colocan los personajes.
///
/// ```dart
/// final lugar = EscenariosPixel.de(escena.lugar);
/// EscenaPixel(
///   fondo: lugar.fondo,
///   descripcion: lugar.descripcion,
///   elementos: lugar.componer([
///     lugar.colocar('jueza', jueza, id: 'jueza', etiqueta: 'La jueza'),
///     lugar.colocar('testigo', lucia, id: 'lucia', etiqueta: 'Lucía', resaltado: true),
///   ]),
/// );
/// ```
@immutable
class EscenarioPixel {
  const EscenarioPixel({
    required this.lugar,
    required this.descripcion,
    required this.fondo,
    this.delante = const [],
    this.puestos = const {},
  });

  /// La clave del lugar: «sala_vistas».
  final String lugar;

  /// Lo que dicen los lectores de pantalla del fondo («La sala de vistas: el estrado de la jueza…»).
  final String descripcion;

  /// El dibujo entero del lugar, con todos sus muebles.
  final Sprite fondo;

  /// Muebles que tapan a quien está detrás, recortados del [fondo] y colocados en el mismo sitio: sin personajes no
  /// cambian nada; con personajes, [componer] los pinta encima de quien tiene los pies más al fondo (más arriba).
  final List<ElementoEscena> delante;

  /// Dónde van los pies de cada personaje, en píxeles del [fondo]. Todos los lugares tienen «izquierda», «centro» y
  /// «derecha»; algunos, también puestos con nombre («jueza», «fiscal»…).
  final Map<String, PuntoPixel> puestos;

  /// El puesto [nombre], o null si este lugar no lo tiene.
  PuntoPixel? puesto(String nombre) => puestos[nombre];

  /// Un personaje con los pies en el puesto [nombre] (o en el centro, si el lugar no tiene ese puesto).
  ElementoEscena colocar(
    String nombre,
    Sprite sprite, {
    String? id,
    String? etiqueta,
    bool espejo = false,
    bool resaltado = false,
  }) {
    final punto = puestos[nombre] ?? puestos['centro'] ?? (x: fondo.ancho ~/ 2, y: fondo.alto - 6);
    return ElementoEscena(
      sprite: sprite,
      x: punto.x,
      y: punto.y,
      id: id,
      etiqueta: etiqueta,
      espejo: espejo,
      resaltado: resaltado,
    );
  }

  /// Los [personajes] y las piezas de [delante] en el orden en que se pintan: de más al fondo (pies más arriba) a más
  /// cerca. Una pieza tapa a los personajes que tienen los pies por encima de su borde de abajo; si están a la misma
  /// altura, el personaje queda delante. Entre personajes a la misma altura se respeta el orden de la lista.
  List<ElementoEscena> componer(Iterable<ElementoEscena> personajes) {
    final todos = [
      for (final (i, pieza) in delante.indexed) (y: pieza.y, tipo: 0, orden: i, elemento: pieza),
      for (final (i, personaje) in personajes.indexed) (y: personaje.y, tipo: 1, orden: i, elemento: personaje),
    ];
    todos.sort((a, b) {
      if (a.y != b.y) return a.y.compareTo(b.y);
      if (a.tipo != b.tipo) return a.tipo.compareTo(b.tipo);
      return a.orden.compareTo(b.orden);
    });
    return [for (final item in todos) item.elemento];
  }

  @override
  String toString() => 'EscenarioPixel($lugar)';
}

/// Una pieza de [delante]: el [sprite] con su esquina de arriba a la izquierda en ([izquierda], [arriba]) del fondo.
ElementoEscena piezaEn(Sprite sprite, int izquierda, int arriba) =>
    ElementoEscena(sprite: sprite, x: izquierda + sprite.ancla.x, y: arriba + sprite.ancla.y);
