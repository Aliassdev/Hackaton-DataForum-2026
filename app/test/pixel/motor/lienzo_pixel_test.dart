import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/motor/motor.dart';

void main() {
  test('empieza relleno y da filas para un Sprite', () {
    expect(LienzoPixel(3, 2).filas, ['...', '...']);
    final lienzo = LienzoPixel(3, 2, 'P');
    expect(lienzo.filas, ['PPP', 'PPP']);
    expect(Sprite('lienzo', lienzo.filas).tamano.width, 3);
  });

  test('punto, rect y marco', () {
    final lienzo = LienzoPixel(5, 4)
      ..rect(1, 1, 3, 2, 'Y')
      ..punto(0, 0, 'N')
      ..marco(0, 0, 5, 4, 'D')
      ..punto(2, 1, 'N');
    expect(lienzo.filas, ['DDDDD', 'DYNYD', 'DYYYD', 'DDDDD']);
    expect(lienzo.en(2, 1), 'N');
    expect(lienzo.en(-1, 0), '.');
    expect(lienzo.en(5, 0), '.');
  });

  test('líneas rectas y en diagonal, con los dos extremos', () {
    final lienzo = LienzoPixel(5, 5)
      ..lineaH(0, 0, 5, 'N')
      ..lineaV(4, 0, 5, 'A')
      ..linea(0, 4, 3, 1, 'Y');
    expect(lienzo.filas, ['NNNNA', '...YA', '..Y.A', '.Y..A', 'Y...A']);
  });

  test('pegar no tapa con los «.» y puede ir en espejo', () {
    final lienzo = LienzoPixel(4, 2, 'P')
      ..pegar(['N.', 'YY'], 0, 0)
      ..pegar(['N.', 'AY'], 2, 0, espejo: true);
    expect(lienzo.filas, ['NPPN', 'YYYA']);
  });

  test('mosaico repite la tesela desde la esquina del rectángulo', () {
    final lienzo = LienzoPixel(5, 3, 'P')..mosaico(['Ya', 'aY'], 1, 0, 4, 3);
    expect(lienzo.filas, ['PYaYa', 'PaYaY', 'PYaYa']);
  });

  test('lo que se sale se recorta sin avisar', () {
    final lienzo = LienzoPixel(3, 3)
      ..rect(-5, -5, 7, 7, 'N')
      ..linea(-2, 2, 5, 2, 'Y')
      ..pegar(['AAAA'], 1, 1);
    expect(lienzo.filas, ['NN.', 'NAA', 'YYY']);
  });

  test('una clave que no está en la paleta es un error claro', () {
    expect(() => LienzoPixel(2, 2, 'Z'), throwsA(isA<AssertionError>()));
    expect(
      () => LienzoPixel(2, 2).rect(0, 0, 1, 1, 'Z'),
      throwsA(isA<AssertionError>().having((e) => e.message, 'message', contains('«Z» no es una clave'))),
    );
    expect(() => LienzoPixel(2, 2).pegar(['?'], 0, 0), throwsAssertionError);
    expect(() => LienzoPixel(2, 2).punto(0, 0, 'NN'), throwsAssertionError);
  });
}
