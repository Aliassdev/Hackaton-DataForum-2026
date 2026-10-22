import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/motor/motor.dart';

import 'ayudantes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('revelar: un píxel de imagen por carácter, con los colores exactos de la paleta', () async {
    final imagen = ImagenesPixel.revelar(['NY.', 'x3A']);
    expect(imagen.width, 3);
    expect(imagen.height, 2);
    final lamina = await leerImagen(imagen);
    expect(lamina.en(0, 0), colorDe('N'));
    expect(lamina.en(1, 0), colorDe('Y'));
    expect(lamina.en(2, 0).a, 0, reason: '«.» es transparente');
    expect(lamina.en(1, 1), colorDe('3'));
    expect(lamina.en(2, 1), colorDe('A'));
    // La sombra del suelo se queda semitransparente (con el redondeo de guardar el alfa premultiplicado).
    final sombra = lamina.en(0, 1);
    expect(sombra.a, closeTo(PaletaPixel.sombraSuelo.color.a, 0.01));
    expect(sombra.b, closeTo(PaletaPixel.sombraSuelo.color.b, 0.05));
  });

  test('revelar junta los tramos iguales sin dejar huecos entre ellos', () async {
    final filas = ['YYYYNNNNYY', 'A.A.AAAA..'];
    final lamina = await leerImagen(ImagenesPixel.revelar(filas));
    for (var y = 0; y < filas.length; y++) {
      for (var x = 0; x < filas[y].length; x++) {
        final clave = filas[y][x];
        expect(lamina.en(x, y), clave == '.' ? const Color(0x00000000) : colorDe(clave), reason: '($x, $y)');
      }
    }
  });

  test('de: cada fotograma se revela una sola vez y se guarda', () {
    final sprite = Sprite.animado('dos', [
      ['NN'],
      ['YY'],
    ]);
    final antes = ImagenesPixel.debugRevelados;
    final primera = ImagenesPixel.de(sprite);
    expect(ImagenesPixel.de(sprite, 0), same(primera));
    expect(ImagenesPixel.debugRevelados, antes + 1);
    final segunda = ImagenesPixel.de(sprite, 1);
    expect(segunda, isNot(same(primera)));
    expect(ImagenesPixel.debugRevelados, antes + 2);
    // Otro sprite con las mismas filas tiene sus propias imágenes.
    expect(
      ImagenesPixel.de(
        Sprite.animado('dos', [
          ['NN'],
          ['YY'],
        ]),
      ),
      isNot(same(primera)),
    );
  });

  test('precargar revela todos los fotogramas', () {
    final sprite = Sprite.animado('tres', [
      ['N'],
      ['Y'],
      ['A'],
    ]);
    final antes = ImagenesPixel.debugRevelados;
    ImagenesPixel.precargar(sprite);
    expect(ImagenesPixel.debugRevelados, antes + 3);
    ImagenesPixel.de(sprite, 2);
    expect(ImagenesPixel.debugRevelados, antes + 3);
  });

  test('halo: amarillo alrededor de la silueta y sombra por fuera; la sombra del suelo no cuenta', () async {
    final sprite = Sprite('punto', ['.N.', 'xxx']);
    final halo = ImagenesPixel.halo(sprite);
    const m = ImagenesPixel.margenHalo;
    expect(halo.width, 3 + 2 * m);
    expect(halo.height, 2 + 2 * m);
    expect(ImagenesPixel.halo(sprite), same(halo));
    final lamina = await leerImagen(halo);
    final amarillo = colorDe('Y');
    // La silueta es solo la N de (1, 0), que en el halo está en (1 + m, m).
    expect(lamina.en(1 + m, m).a, 0, reason: 'la silueta no se pinta');
    for (final (x, y) in [(1 + m, m - 1), (m, m), (2 + m, m), (1 + m, m + 1)]) {
      expect(lamina.en(x, y), amarillo, reason: '($x, $y) toca la silueta');
    }
    expect(lamina.en(m, m - 1).a, closeTo(PaletaPixel.sombraSuelo.color.a, 0.01), reason: 'esquina: sombra');
    expect(lamina.en(1 + m, m - 2).a, closeTo(PaletaPixel.sombraSuelo.color.a, 0.01), reason: 'por fuera: sombra');
    expect(lamina.en(0, 0).a, 0, reason: 'lejos: nada');
    // Debajo de la N está la sombra del suelo: ahí hay halo, no silueta.
    expect(lamina.en(m, m + 1).a, closeTo(PaletaPixel.sombraSuelo.color.a, 0.01));
  });

  test('pintar escala sin suavizar: cada píxel es un bloque de un solo color', () async {
    final imagen = ImagenesPixel.revelar(['NY', 'AW']);
    final grabadora = ui.PictureRecorder();
    final lienzo = Canvas(grabadora);
    ImagenesPixel.pintar(lienzo, imagen, const Rect.fromLTWH(0, 0, 14, 14));
    ImagenesPixel.pintar(lienzo, imagen, const Rect.fromLTWH(14, 0, 14, 14), espejo: true);
    final dibujo = grabadora.endRecording();
    final lamina = await leerImagen(dibujo.toImageSync(28, 14));
    final esperados = [
      ['N', 'Y', 'Y', 'N'],
      ['A', 'W', 'W', 'A'],
    ];
    for (var y = 0; y < 14; y++) {
      for (var x = 0; x < 28; x++) {
        expect(lamina.en(x, y), colorDe(esperados[y ~/ 7][x ~/ 7]), reason: '($x, $y)');
      }
    }
  });
}
