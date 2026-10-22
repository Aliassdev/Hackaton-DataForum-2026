import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/motor/motor.dart';

void main() {
  test('un fondo de 160 × 96 en un móvil de 1080 píxeles: 6 píxeles físicos por píxel, centrado', () {
    const dpr = 2.75;
    final encaje = EncajePixel(caja: const Size(1080 / dpr, 300), arte: const Size(160, 96), dpr: dpr);
    expect(encaje.fisicos, 6);
    expect(encaje.escala, 6 / dpr);
    expect(encaje.nitido, isTrue);
    expect(encaje.rect.width * dpr, closeTo(960, 1e-9));
    expect(encaje.rect.height * dpr, closeTo(576, 1e-9));
    expect(encaje.rect.left * dpr, closeTo(60, 1e-9));
  });

  test('la escala es entera en píxeles físicos, no en puntos', () {
    // 100 puntos a densidad 2,625 son 262,5 píxeles: caben 13 por cada uno de los 20 píxeles del dibujo.
    final encaje = EncajePixel(caja: const Size(100, 100), arte: const Size(20, 20), dpr: 2.625);
    expect(encaje.fisicos, 13);
    expect(encaje.rect.width, closeTo(260 / 2.625, 1e-9));
  });

  test('la esquina cae en la rejilla de píxeles físicos', () {
    for (final dpr in [1.0, 2.0, 2.625, 2.75, 3.0, 3.5]) {
      for (final ancho in [101.0, 233.3, 391.27]) {
        final encaje = EncajePixel(caja: Size(ancho, 157.7), arte: const Size(24, 32), dpr: dpr);
        expect(encaje.nitido, isTrue);
        final x = encaje.rect.left * dpr;
        final y = encaje.rect.top * dpr;
        expect(x, closeTo(x.roundToDouble(), 1e-6), reason: 'dpr $dpr, ancho $ancho');
        expect(y, closeTo(y.roundToDouble(), 1e-6), reason: 'dpr $dpr, ancho $ancho');
      }
    }
  });

  test('los decimales no le quitan un píxel a la escala', () {
    // 6 × 160 / 2,75 son 349,0909… puntos: en esa caja caben justo 6 píxeles físicos por píxel.
    final encaje = EncajePixel(caja: const Size(6 * 160 / 2.75, 96 * 6 / 2.75), arte: const Size(160, 96), dpr: 2.75);
    expect(encaje.fisicos, 6);
  });

  test('si no cabe ni a un píxel físico por píxel, se encoge y deja de ser nítido', () {
    final encaje = EncajePixel(caja: const Size(10, 10), arte: const Size(40, 40), dpr: 2);
    expect(encaje.fisicos, 0.5);
    expect(encaje.nitido, isFalse);
    expect(encaje.rect, const Rect.fromLTWH(0, 0, 10, 10));
  });

  test('la alineación coloca el dibujo en la caja', () {
    final abajo = EncajePixel(
      caja: const Size(100, 200),
      arte: const Size(10, 10),
      dpr: 1,
      alineacion: Alignment.bottomCenter,
    );
    expect(abajo.rect, const Rect.fromLTWH(0, 100, 100, 100));
    final arriba = EncajePixel(
      caja: const Size(100, 200),
      arte: const Size(10, 10),
      dpr: 1,
      alineacion: Alignment.topLeft,
    );
    expect(arriba.rect.topLeft, Offset.zero);
  });

  test('rectDe pasa de píxeles del dibujo a puntos de la caja', () {
    final encaje = EncajePixel(caja: const Size(400, 300), arte: const Size(40, 20), dpr: 2);
    expect(encaje.escala, 10);
    expect(encaje.rect, const Rect.fromLTWH(0, 50, 400, 200));
    expect(encaje.rectDe(8, 9, 4, 6), const Rect.fromLTWH(80, 140, 40, 60));
    expect(encaje, EncajePixel(caja: const Size(400, 300), arte: const Size(40, 20), dpr: 2));
  });
}
