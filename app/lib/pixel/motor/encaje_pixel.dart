import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Cómo cabe un dibujo de pixel art de [arte] píxeles en una [caja] de la pantalla: con el mayor número entero de
/// píxeles físicos por píxel del dibujo, para que todos los píxeles midan lo mismo y nada se emborrone.
///
/// La escala es entera en píxeles físicos (los de la pantalla), no en puntos lógicos: con una densidad de 2,75, un
/// píxel del dibujo mide 6 píxeles físicos (2,18 puntos), no 2 puntos (5,5 píxeles, unos de 5 y otros de 6). Si el
/// dibujo no cabe ni a un píxel físico por píxel, se encoge lo justo (ya no es nítido: [nitido] es false).
@immutable
class EncajePixel {
  const EncajePixel._(this.rect, this.escala, this.fisicos);

  /// [dpr] es la densidad de la pantalla (`MediaQuery.devicePixelRatioOf(context)`). La esquina del dibujo se ajusta a
  /// la rejilla de píxeles físicos de la caja.
  factory EncajePixel({
    required Size caja,
    required Size arte,
    required double dpr,
    Alignment alineacion = Alignment.center,
  }) {
    assert(caja.isFinite && !arte.isEmpty && dpr > 0, 'EncajePixel: caja $caja, arte $arte, densidad $dpr.');
    final maximo = math.max(0.0, math.min(caja.width * dpr / arte.width, caja.height * dpr / arte.height));
    // Un pelo de margen: que 5,9999999 por los decimales cuente como 6.
    final entero = (maximo + 1e-6).floorToDouble();
    final fisicos = entero >= 1 ? entero : maximo;
    final escala = fisicos / dpr;
    final tamano = Size(arte.width * escala, arte.height * escala);
    final sitio = alineacion.inscribe(tamano, Offset.zero & caja);
    double ajustar(double valor) => (valor * dpr).roundToDouble() / dpr;
    return EncajePixel._(Offset(ajustar(sitio.left), ajustar(sitio.top)) & tamano, escala, fisicos);
  }

  /// Dónde queda el dibujo dentro de la caja, en puntos lógicos.
  final Rect rect;

  /// Puntos lógicos por píxel del dibujo.
  final double escala;

  /// Píxeles físicos por píxel del dibujo: un entero, salvo que el dibujo no quepa ni a uno.
  final double fisicos;

  /// Si cada píxel del dibujo ocupa un número entero de píxeles de la pantalla.
  bool get nitido => fisicos >= 1 && fisicos == fisicos.roundToDouble();

  /// El rectángulo, en puntos lógicos de la caja, de una zona del dibujo dada en píxeles del dibujo.
  Rect rectDe(num x, num y, num ancho, num alto) =>
      Rect.fromLTWH(rect.left + x * escala, rect.top + y * escala, ancho * escala, alto * escala);

  @override
  bool operator ==(Object other) =>
      other is EncajePixel && other.rect == rect && other.escala == escala && other.fisicos == fisicos;

  @override
  int get hashCode => Object.hash(rect, escala, fisicos);

  @override
  String toString() => 'EncajePixel($rect, ${fisicos}x físicos)';
}
