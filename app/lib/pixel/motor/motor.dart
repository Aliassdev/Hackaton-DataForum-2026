/// Motor de pixel art de «Vive el caso»: todo se dibuja con código, sin imágenes.
///
/// - [PaletaPixel] y [ColorPixel]: la paleta compartida, con una clave de un carácter por color.
/// - [Sprite], [AnimacionPixel], [PasoPixel] y [retocar]: dibujos hechos de filas de texto, con fotogramas.
/// - [LienzoPixel]: para pintar con código los dibujos grandes, como los fondos.
/// - [ImagenesPixel]: revela cada fotograma en una imagen una sola vez y la guarda.
/// - [SpritePixel]: un sprite nítido, a escala entera, con su animación en reposo.
/// - [EscenaPixel] y [ElementoEscena]: un fondo con personajes que se pueden tocar.
/// - [EncajePixel], [RejillaPixel] y [RelojPixel]: la escala entera, el ajuste a los píxeles de la pantalla y el reloj
///   de las animaciones (por si hay que pintar a mano).
///
/// La guía de estilo para dibujar está en lib/pixel/LEEME.md.
library;

export 'encaje_pixel.dart';
export 'escena_pixel.dart';
export 'imagenes_pixel.dart';
export 'lienzo_pixel.dart';
export 'paleta_pixel.dart';
export 'rejilla_pixel.dart';
export 'reloj_pixel.dart';
export 'sprite.dart';
export 'sprite_pixel.dart';
