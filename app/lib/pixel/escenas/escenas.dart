/// Las escenas del contenido de «Vive el caso» en pixel art, listas para el juego: el lugar de lib/pixel/escenarios,
/// las personas de lib/pixel/personajes en sus sitios y el marco de la pantalla de juego de lib/pixel/ui.
///
/// ```dart
/// import 'package:tuturno/pixel/escenas/escenas.dart';
///
/// // En CabeceraEscena (lib/features/juego/widgets/cabecera_escena.dart):
/// EscenaCasoPixel(lugar: escena.lugar, personajes: escena.personajes);
/// ```
///
/// - [EscenaCasoPixel]: la escena enmarcada, con el alto justo para su escala entera (o compacta, para la portada).
/// - [montarEscenaCaso] y [MontajeEscenaCaso]: lo mismo sin widget, para montarla a mano en una [EscenaPixel].
library;

import '../motor/motor.dart' show EscenaPixel;

export 'escena_caso_pixel.dart';
