import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/texto.dart';

void main() {
  group('normalizar', () {
    test('pasa a minúsculas y quita las tildes', () {
      expect(normalizar('Fiscalía de Menores'), 'fiscalia de menores');
      expect(normalizar('ÁÉÍÓÚ'), 'aeiou');
      expect(normalizar('àèìòù âêîôû äëïöü'), 'aeiou aeiou aeiou');
      expect(normalizar('Sala Gesell'), 'sala gesell');
    });

    test('ñ, ü y ç cuentan como n, u y c', () {
      expect(normalizar('Ñandú'), 'nandu');
      expect(normalizar('Hacerme DAÑO'), 'hacerme dano');
      expect(normalizar('pingüino VERGÜENZA'), 'pinguino verguenza');
      expect(normalizar('Ça va'), 'ca va');
    });

    test('tildes descompuestas (NFD), como las de algunos textos copiados', () {
      expect(normalizar('Fiscalía'), 'fiscalia');
      expect(normalizar('año'), 'ano');
      expect(normalizar('Fiscalía'), normalizar('Fiscalía'));
    });

    test('deja igual números, signos y emojis', () {
      expect(normalizar('¿Me pueden juzgar con 13 años? ¡Vale! 👍'), '¿me pueden juzgar con 13 anos? ¡vale! 👍');
      expect(normalizar('LO 5/2000, art. 3'), 'lo 5/2000, art. 3');
    });

    test('texto vacío → vacío', () {
      expect(normalizar(''), '');
    });

    test('sirve para buscar sin tildes', () {
      expect(normalizar('Prueba preconstituida').contains(normalizar('PRECONSTITUÍDA')), isTrue);
      expect(normalizar('Citación').contains(normalizar('citacion')), isTrue);
    });

    test('sirve para ordenar sin que importen tildes ni mayúsculas', () {
      final palabras = ['Órgano', 'abogado', 'Ámbito', 'Zona', 'oído'];

      palabras.sort((a, b) => normalizar(a).compareTo(normalizar(b)));

      expect(palabras, ['abogado', 'Ámbito', 'oído', 'Órgano', 'Zona']);
    });
  });
}
