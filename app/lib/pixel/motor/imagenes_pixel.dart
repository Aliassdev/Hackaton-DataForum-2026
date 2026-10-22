import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'paleta_pixel.dart';
import 'sprite.dart';

/// Convierte los fotogramas de los sprites en imágenes ([ui.Image]) de un píxel de imagen por píxel del dibujo. Cada
/// fotograma se revela una sola vez, la primera vez que se pinta, y se guarda con su sprite: cuando el sprite deja de
/// usarse, sus imágenes se van con él.
///
/// Las imágenes se escalan después sin suavizado ([ui.FilterQuality.none]), así que siguen nítidas a cualquier escala
/// entera. [SpritePixel] y [EscenaPixel] ya las usan; esto solo hace falta para pintar a mano.
abstract final class ImagenesPixel {
  static final _imagenes = Expando<List<ui.Image?>>('ImagenesPixel');
  static final _halos = Expando<List<ui.Image?>>('ImagenesPixel.halo');

  /// Cuántos fotogramas se han revelado desde que arrancó la app (para comprobar la caché en las pruebas).
  @visibleForTesting
  static int debugRevelados = 0;

  /// La imagen del [fotograma] de [sprite], del mismo tamaño que el sprite.
  static ui.Image de(Sprite sprite, [int fotograma = 0]) {
    final imagenes = _imagenes[sprite] ??= List<ui.Image?>.filled(sprite.fotogramas.length, null);
    return imagenes[fotograma] ??= revelar(sprite.fotogramas[fotograma]);
  }

  /// Cuántos píxeles del dibujo sobresale el halo por cada lado.
  static const margenHalo = 2;

  /// El halo de [fotograma] de [sprite], para resaltar a un personaje: un anillo amarillo de 1 píxel alrededor de la
  /// silueta y, por fuera, otro de sombra semitransparente que lo separa de cualquier fondo (también de uno amarillo).
  /// Mide [margenHalo] píxeles más que el sprite por cada lado.
  static ui.Image halo(Sprite sprite, [int fotograma = 0]) {
    final halos = _halos[sprite] ??= List<ui.Image?>.filled(sprite.fotogramas.length, null);
    return halos[fotograma] ??= revelar(_filasHalo(sprite.fotogramas[fotograma]));
  }

  /// Revela todos los fotogramas de [sprite] ya, para que el primer parpadeo no tenga que esperar a nada.
  static void precargar(Sprite sprite) {
    for (var fotograma = 0; fotograma < sprite.fotogramas.length; fotograma++) {
      de(sprite, fotograma);
    }
  }

  /// Revela unas filas sin guardar la imagen: un rectángulo por cada tramo de píxeles iguales de una fila, sin
  /// antialiasing, en un dibujo que se convierte en imagen al momento ([ui.Picture.toImageSync]).
  static ui.Image revelar(List<String> filas) {
    final alto = filas.length;
    final ancho = filas.first.length;
    final grabadora = ui.PictureRecorder();
    final lienzo = ui.Canvas(grabadora);
    final pincel = ui.Paint()
      ..isAntiAlias = false
      ..blendMode = ui.BlendMode.src;
    for (var y = 0; y < alto; y++) {
      final fila = filas[y];
      final fin = math.min(fila.length, ancho);
      var x = 0;
      while (x < fin) {
        final codigo = fila.codeUnitAt(x);
        var hasta = x + 1;
        while (hasta < fin && fila.codeUnitAt(hasta) == codigo) {
          hasta++;
        }
        final color = PaletaPixel.colorDe(codigo);
        if (color != null) {
          lienzo.drawRect(
            ui.Rect.fromLTRB(x.toDouble(), y.toDouble(), hasta.toDouble(), y + 1.0),
            pincel..color = color,
          );
        }
        x = hasta;
      }
    }
    final dibujo = grabadora.endRecording();
    final imagen = dibujo.toImageSync(ancho, alto);
    dibujo.dispose();
    debugRevelados++;
    return imagen;
  }

  /// Pinta [imagen] entera en [destino] sin suavizado ni antialiasing; con [espejo], dada la vuelta de izquierda a
  /// derecha. Para que se vea nítida, [destino] debe medir un número entero de píxeles físicos por píxel de la imagen
  /// (lo que da [EncajePixel]).
  static void pintar(ui.Canvas lienzo, ui.Image imagen, ui.Rect destino, {bool espejo = false}) {
    final origen = ui.Rect.fromLTWH(0, 0, imagen.width.toDouble(), imagen.height.toDouble());
    if (!espejo) {
      lienzo.drawImageRect(imagen, origen, destino, _pincel);
      return;
    }
    lienzo
      ..save()
      ..translate(destino.center.dx, 0)
      ..scale(-1, 1)
      ..translate(-destino.center.dx, 0)
      ..drawImageRect(imagen, origen, destino, _pincel)
      ..restore();
  }

  static final _pincel = ui.Paint()
    ..filterQuality = ui.FilterQuality.none
    ..isAntiAlias = false;

  /// Las filas del halo: amarillo en cada píxel vacío que toca (arriba, abajo o a un lado) la silueta y sombra en cada
  /// píxel vacío que toca el amarillo. La sombra del suelo, que es semitransparente, no cuenta como silueta.
  static List<String> _filasHalo(List<String> filas) {
    final alto = filas.length + 2 * margenHalo;
    final ancho = filas.first.length + 2 * margenHalo;
    // 0 vacío, 1 silueta, 2 anillo amarillo, 3 anillo de sombra.
    final celdas = List.generate(alto, (y) {
      final fila = y - margenHalo;
      return List.generate(ancho, (x) {
        final columna = x - margenHalo;
        if (fila < 0 || fila >= filas.length || columna < 0 || columna >= filas[fila].length) return 0;
        final color = PaletaPixel.colorDe(filas[fila].codeUnitAt(columna));
        return color != null && color.a == 1 ? 1 : 0;
      });
    });
    bool toca(int x, int y, int tipo) =>
        (x > 0 && celdas[y][x - 1] == tipo) ||
        (x < ancho - 1 && celdas[y][x + 1] == tipo) ||
        (y > 0 && celdas[y - 1][x] == tipo) ||
        (y < alto - 1 && celdas[y + 1][x] == tipo);
    for (final (tipo, de) in [(2, 1), (3, 2)]) {
      final nuevos = [
        for (var y = 0; y < alto; y++)
          for (var x = 0; x < ancho; x++)
            if (celdas[y][x] == 0 && toca(x, y, de)) (x, y),
      ];
      for (final (x, y) in nuevos) {
        celdas[y][x] = tipo;
      }
    }
    final claves = [
      PaletaPixel.transparente,
      PaletaPixel.transparente,
      PaletaPixel.amarillo.clave,
      PaletaPixel.sombraSuelo.clave,
    ];
    return [for (final fila in celdas) fila.map((celda) => claves[celda]).join()];
  }
}
