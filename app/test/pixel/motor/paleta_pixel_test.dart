import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/motor/motor.dart';

void main() {
  test('cada color tiene una clave de un carácter ASCII, única y que no es «.»', () {
    final claves = <String>{};
    for (final color in PaletaPixel.todos) {
      expect(color.clave.length, 1, reason: '$color');
      expect(color.clave.codeUnitAt(0), inInclusiveRange(33, 126), reason: '$color');
      // Ni «.» (transparente) ni caracteres que haya que escapar en un String de Dart.
      expect(color.clave, isNot(anyOf('.', r'$', r'\', "'", '"')), reason: '$color');
      expect(claves.add(color.clave), isTrue, reason: 'clave repetida: $color');
    }
    expect(PaletaPixel.claves.split(' '), hasLength(PaletaPixel.todos.length));
  });

  test('las claves que se confunden al leer (l, I, O, 0) no se usan', () {
    for (final clave in ['l', 'I', 'O', '0']) {
      expect(PaletaPixel.deClave(clave), isNull, reason: clave);
    }
  });

  test('cada sombra es una clave de la paleta', () {
    for (final color in PaletaPixel.todos) {
      final sombra = color.sombra;
      if (sombra != null) expect(PaletaPixel.deClave(sombra), isNotNull, reason: '$color → $sombra');
    }
  });

  test('los colores de la marca son los del tema', () {
    expect(PaletaPixel.amarillo.color, const Color(0xFFFFDE59));
    expect(PaletaPixel.noche.color, const Color(0xFF0E1A4F));
    expect(PaletaPixel.papel.color, const Color(0xFFFFFBEF));
    expect(PaletaPixel.azul.color, const Color(0xFF2846E8));
  });

  test('seis pieles de clara a oscura, cada una sombreada con la siguiente', () {
    final pieles = PaletaPixel.pieles;
    expect(pieles, hasLength(6));
    for (var i = 0; i < pieles.length; i++) {
      expect(pieles[i].clave, '${i + 1}');
      expect(pieles[i].sombra, '${i + 2}');
      final siguiente = PaletaPixel.deClave(pieles[i].sombra!)!;
      expect(siguiente.color.computeLuminance(), lessThan(pieles[i].color.computeLuminance()), reason: '${pieles[i]}');
    }
  });

  test('seis colores de pelo, con una sombra más oscura', () {
    expect(PaletaPixel.pelos, hasLength(6));
    for (final pelo in PaletaPixel.pelos) {
      final sombra = PaletaPixel.deClave(pelo.sombra!)!;
      expect(sombra.color.computeLuminance(), lessThan(pelo.color.computeLuminance()), reason: '$pelo');
    }
  });

  test('todos son opacos menos la sombra del suelo', () {
    for (final color in PaletaPixel.todos) {
      expect(color.color.a == 1, color != PaletaPixel.sombraSuelo, reason: '$color');
    }
  });

  test('deClave, esClave y colorDe dicen lo mismo', () {
    for (final color in PaletaPixel.todos) {
      expect(PaletaPixel.deClave(color.clave), same(color));
      expect(PaletaPixel.esClave(color.clave), isTrue);
      expect(PaletaPixel.colorDe(color.clave.codeUnitAt(0)), color.color);
    }
    expect(PaletaPixel.esClave('.'), isTrue);
    expect(PaletaPixel.colorDe('.'.codeUnitAt(0)), isNull);
    expect(PaletaPixel.esClave('Z'), isFalse);
    expect(PaletaPixel.colorDe('Z'.codeUnitAt(0)), isNull);
    expect(PaletaPixel.colorDe('ñ'.codeUnitAt(0)), isNull);
  });

  test('cambio pasa un color y su sombra a otro color y su sombra', () {
    expect(PaletaPixel.cambio(PaletaPixel.piel3, PaletaPixel.piel5), {'3': '5', '4': '6'});
    expect(PaletaPixel.cambio(PaletaPixel.castanoClaro, PaletaPixel.negro), {'t': 'z', 'T': 'N'});
    // Si uno de los dos no tiene sombra, solo cambia el color.
    expect(PaletaPixel.cambio(PaletaPixel.noche, PaletaPixel.marino), {'N': 'D'});
  });
}
