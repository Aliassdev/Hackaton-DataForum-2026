import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/motor/motor.dart';

/// El error que lanza [crear], o falla si no lanza nada.
SpriteInvalido errorDe(Sprite Function() crear) {
  try {
    crear();
  } on SpriteInvalido catch (error) {
    return error;
  }
  fail('No ha lanzado SpriteInvalido.');
}

void main() {
  const maceta = ['..NNNN..', '.NvvvVN.', '.NmmmtN.', '..NNNN..'];

  group('Sprite', () {
    test('mide lo que miden sus filas y su ancla por defecto son los pies', () {
      final sprite = Sprite('maceta', maceta);
      expect(sprite.ancho, 8);
      expect(sprite.alto, 4);
      expect(sprite.tamano, const Size(8, 4));
      expect(sprite.ancla, (x: 4, y: 4));
      expect(sprite.fotogramas, hasLength(1));
      expect(sprite.animacion, isNull);
      expect(sprite.toString(), contains('maceta'));
    });

    test('se le puede dar otra ancla', () {
      expect(Sprite('maceta', maceta, ancla: (x: 1, y: 2)).ancla, (x: 1, y: 2));
    });

    test('sus filas no se pueden cambiar desde fuera', () {
      final filas = [...maceta];
      final sprite = Sprite('maceta', filas);
      filas[0] = 'NNNNNNNN';
      expect(sprite.fotogramas.first.first, '..NNNN..');
      expect(() => sprite.fotogramas.first[0] = 'x', throwsUnsupportedError);
    });

    test('con fotogramas y animación', () {
      final sprite = Sprite.animado('ojos', [
        ['NN'],
        ['33'],
      ], animacion: AnimacionPixel.parpadeo());
      expect(sprite.fotogramas, hasLength(2));
      expect(sprite.animacion!.seMueve, isTrue);
      expect(sprite.validar, returnsNormally);
    });
  });

  group('validación', () {
    test('una fila más corta: dice el sprite, el fotograma, la fila y los anchos', () {
      final error = errorDe(() => Sprite('jueza', ['NNNN', 'NNN', 'NNNN']));
      expect(error.sprite, 'jueza');
      expect(error.problemas, hasLength(1));
      expect(error.problemas.single, contains('fotograma 0, fila 1: mide 3 píxeles y la fila 0 mide 4'));
      final mensaje = error.toString();
      expect(mensaje, startsWith('SpriteInvalido: el sprite «jueza» está mal dibujado'));
      expect(mensaje, contains('LEEME.md'));
      expect(mensaje, isNot(contains('Claves válidas')));
    });

    test('un carácter que no está en la paleta: dice dónde y recuerda las claves', () {
      final error = errorDe(() => Sprite('chico', ['NNNN', 'NZNN']));
      expect(error.problemas.single, 'fotograma 0, fila 1, columna 1: «Z» no es una clave de PaletaPixel.');
      expect(error.toString(), contains('Claves válidas: «.» (transparente) y ${PaletaPixel.claves}'));
    });

    test('un espacio tampoco vale como transparente', () {
      final error = errorDe(() => Sprite('hueco', ['N N']));
      expect(error.problemas.single, contains('columna 1: « » no es una clave'));
    });

    test('fotogramas de distinto tamaño', () {
      final error = errorDe(
        () => Sprite.animado('dos', [
          ['NN', 'NN'],
          ['NN'],
        ]),
      );
      expect(error.problemas.single, contains('el fotograma 1 tiene 1 filas y el 0 tiene 2'));
    });

    test('una fila más larga en el segundo fotograma', () {
      final error = errorDe(
        () => Sprite.animado('dos', [
          ['NN', 'NN'],
          ['NN', 'NNN'],
        ]),
      );
      expect(error.problemas.single, contains('fotograma 1, fila 1: mide 3 píxeles'));
    });

    test('una animación que usa un fotograma que no existe', () {
      final error = errorDe(
        () => Sprite.animado('uno', [
          ['NN'],
        ], animacion: AnimacionPixel.parpadeo()),
      );
      expect(error.problemas.single, contains('el paso 1 de la animación usa el fotograma 1, pero solo hay 1'));
    });

    test('una animación sin pasos', () {
      final error = errorDe(
        () => Sprite.animado('nada', [
          ['NN'],
        ], animacion: const AnimacionPixel([])),
      );
      expect(error.problemas.single, contains('no tiene pasos'));
    });

    test('vacío', () {
      expect(errorDe(() => Sprite.animado('sin', [])).problemas.single, 'no tiene fotogramas.');
      expect(errorDe(() => Sprite('vacio', [])).problemas.single, 'el fotograma 0 está vacío.');
      expect(errorDe(() => Sprite('vacio', [''])).problemas.single, 'el fotograma 0 está vacío.');
    });

    test('junta todos los problemas, y si son muchos los resume', () {
      final error = errorDe(() => Sprite('todo mal', ['ZZZZZZZZZZZZZZZZZZZZ', 'N']));
      expect(error.problemas, hasLength(21));
      final mensaje = error.toString();
      expect('  · '.allMatches(mensaje), hasLength(13));
      expect(mensaje, contains('… y 9 más.'));
    });

    test('un paso que no dura nada no se puede ni crear', () {
      expect(() => PasoPixel(0, ms: 0), throwsAssertionError);
      expect(() => AnimacionPixel.parpadeo(cadaMs: 100), throwsAssertionError);
    });
  });

  group('retocar', () {
    test('cambia solo las filas que se le dan', () {
      final abiertos = ['N3N', '333', 'NNN'];
      expect(retocar(abiertos, {0: '333'}), ['333', '333', 'NNN']);
      expect(abiertos.first, 'N3N');
    });

    test('una fila que no existe es un error', () {
      expect(() => retocar(['NN'], {1: 'NN'}), throwsAssertionError);
    });
  });

  group('recolorear', () {
    test('cambia las claves en todos los fotogramas y mantiene la animación y el ancla', () {
      final chico = Sprite.animado(
        'chico',
        [
          ['N3t', 'N4T'],
          ['N3t', 'NNT'],
        ],
        animacion: AnimacionPixel.parpadeo(),
        ancla: (x: 1, y: 1),
      );
      final otra = chico.recolorear({
        ...PaletaPixel.cambio(PaletaPixel.piel3, PaletaPixel.piel6),
        ...PaletaPixel.cambio(PaletaPixel.castanoClaro, PaletaPixel.rubio),
      }, nombre: 'otra');
      expect(otra.nombre, 'otra');
      expect(otra.fotogramas, [
        ['N6u', 'N7o'],
        ['N6u', 'NNo'],
      ]);
      expect(otra.animacion, chico.animacion);
      expect(otra.ancla, (x: 1, y: 1));
      expect(chico.recolorear({}).nombre, 'chico');
    });

    test('los cambios son a la vez: no se encadenan', () {
      expect(Sprite('par', ['34']).recolorear({'3': '4', '4': '5'}).fotogramas.single, ['45']);
    });

    test('a una clave que no existe es un sprite inválido', () {
      expect(() => Sprite('par', ['34']).recolorear({'3': 'Z'}), throwsA(isA<SpriteInvalido>()));
    });

    test('las claves son de un carácter', () {
      expect(() => Sprite('par', ['34']).recolorear({'34': '5'}), throwsAssertionError);
    });
  });

  group('AnimacionPixel', () {
    test('parpadeo: casi siempre abiertos y un instante cerrados', () {
      final parpadeo = AnimacionPixel.parpadeo(abiertos: 0, cerrados: 2, cadaMs: 3000);
      expect(parpadeo.pasos, const [PasoPixel(0, ms: 2860), PasoPixel(2, ms: 140)]);
      expect(parpadeo.duracionMs, 3000);
    });

    test('respiración y balanceo', () {
      expect(AnimacionPixel.respiracion(ms: 500).pasos, const [PasoPixel(0, ms: 500), PasoPixel(1, ms: 500)]);
      final balanceo = AnimacionPixel.balanceo(altura: 2);
      expect(balanceo.pasos.map((paso) => paso.dy), [0, -2]);
      expect(balanceo.dyMinimo, -2);
      expect(balanceo.dyMaximo, 0);
    });

    test('reposo: respira y parpadea una vez por vuelta', () {
      final reposo = AnimacionPixel.reposo(ms: 800);
      expect(reposo.pasos.first, const PasoPixel(0, ms: 800));
      expect(reposo.pasos.where((paso) => paso.fotograma == 2), hasLength(1));
      expect(reposo.pasos.where((paso) => paso.fotograma == 1), hasLength(3));
      expect(reposo.duracionMs, 800 * 6);
    });

    test('un solo paso no se mueve', () {
      expect(const AnimacionPixel([PasoPixel(0, ms: 100)]).seMueve, isFalse);
      expect(const AnimacionPixel([]).seMueve, isFalse);
    });

    test('se comparan por sus pasos', () {
      expect(AnimacionPixel.parpadeo(), AnimacionPixel.parpadeo());
      expect(AnimacionPixel.parpadeo().hashCode, AnimacionPixel.parpadeo().hashCode);
      expect(AnimacionPixel.parpadeo(), isNot(AnimacionPixel.parpadeo(cadaMs: 2000)));
    });
  });
}
