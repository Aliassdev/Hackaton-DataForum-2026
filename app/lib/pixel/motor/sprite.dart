import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

import 'paleta_pixel.dart';

/// Un punto en píxeles del dibujo: x hacia la derecha e y hacia abajo, desde la esquina de arriba a la izquierda.
typedef PuntoPixel = ({int x, int y});

/// Un paso de una animación: qué [fotograma] se ve, durante cuántos milisegundos ([ms]) y, si hace falta, cuántos
/// píxeles se desplaza hacia abajo ([dy]; negativo es hacia arriba, para un balanceo sin dibujar otro fotograma).
@immutable
class PasoPixel {
  const PasoPixel(this.fotograma, {required this.ms, this.dy = 0}) : assert(ms > 0, 'Un paso dura más de 0 ms.');

  final int fotograma;
  final int ms;
  final int dy;

  @override
  bool operator ==(Object other) =>
      other is PasoPixel && other.fotograma == fotograma && other.ms == ms && other.dy == dy;

  @override
  int get hashCode => Object.hash(fotograma, ms, dy);

  @override
  String toString() => 'PasoPixel($fotograma, ms: $ms${dy == 0 ? '' : ', dy: $dy'})';
}

/// Animación en reposo de un sprite: una secuencia de [pasos] que se repite sin fin. El primer paso es la pose de
/// descanso: es la que se ve quieta con «reducir animaciones».
@immutable
class AnimacionPixel {
  const AnimacionPixel(this.pasos);

  /// Parpadeo: [abiertos] casi todo el rato y [cerrados] un instante, una vez cada [cadaMs].
  factory AnimacionPixel.parpadeo({int abiertos = 0, int cerrados = 1, int cadaMs = 3600}) =>
      AnimacionPixel([PasoPixel(abiertos, ms: cadaMs - _parpadeoMs), PasoPixel(cerrados, ms: _parpadeoMs)]);

  /// Respiración: [quieto] y [respira] (por ejemplo, con los hombros un píxel más arriba) se alternan despacio.
  factory AnimacionPixel.respiracion({int quieto = 0, int respira = 1, int ms = 800}) =>
      AnimacionPixel([PasoPixel(quieto, ms: ms), PasoPixel(respira, ms: ms)]);

  /// Balanceo: el mismo [fotograma] sube [altura] píxeles y vuelve a bajar. No hace falta dibujar nada más.
  factory AnimacionPixel.balanceo({int fotograma = 0, int ms = 600, int altura = 1}) =>
      AnimacionPixel([PasoPixel(fotograma, ms: ms), PasoPixel(fotograma, ms: ms, dy: -altura)]);

  /// Reposo de un personaje: respira ([quieto] y [respira]) y, cada tres respiraciones, parpadea ([parpadea] es
  /// [quieto] con los ojos cerrados).
  factory AnimacionPixel.reposo({int quieto = 0, int respira = 1, int parpadea = 2, int ms = 800}) => AnimacionPixel([
    PasoPixel(quieto, ms: ms),
    PasoPixel(respira, ms: ms),
    PasoPixel(quieto, ms: ms),
    PasoPixel(respira, ms: ms),
    PasoPixel(quieto, ms: ms - _parpadeoMs),
    PasoPixel(parpadea, ms: _parpadeoMs),
    PasoPixel(respira, ms: ms),
  ]);

  /// Lo que dura un parpadeo: se ve, pero no distrae.
  static const _parpadeoMs = 140;

  final List<PasoPixel> pasos;

  /// La pose de descanso (el primer paso), o null si no hay pasos.
  PasoPixel? get descanso => pasos.isEmpty ? null : pasos.first;

  /// Lo que dura una vuelta entera.
  int get duracionMs => pasos.fold(0, (total, paso) => total + paso.ms);

  /// Si cambia algo con el tiempo: hacen falta dos pasos o más.
  bool get seMueve => pasos.length > 1 && duracionMs > 0;

  /// Lo más arriba (negativo) y lo más abajo que se desplaza el dibujo, en píxeles.
  int get dyMinimo => pasos.fold(0, (minimo, paso) => paso.dy < minimo ? paso.dy : minimo);
  int get dyMaximo => pasos.fold(0, (maximo, paso) => paso.dy > maximo ? paso.dy : maximo);

  @override
  bool operator ==(Object other) => other is AnimacionPixel && listEquals(other.pasos, pasos);

  @override
  int get hashCode => Object.hashAll(pasos);
}

/// Un sprite de pixel art: filas de texto, un carácter por píxel, con las claves de [PaletaPixel] («.» es
/// transparente). Puede tener varios fotogramas para una [animacion] en reposo y un [ancla]: el punto del dibujo que
/// se coloca en la posición que se le da en una escena (por defecto, los pies: el centro del borde de abajo).
///
/// ```dart
/// final maceta = Sprite('maceta', [
///   '..NNNN..',
///   '.NvvvVN.',
///   '.NmmmtN.',
///   '..NNNN..',
/// ]);
/// ```
///
/// En debug, si una fila no mide lo mismo que las demás o lleva un carácter que no está en la paleta, el constructor
/// lanza un [SpriteInvalido] que dice el fotograma, la fila y la columna. Crea los sprites una sola vez (en una
/// variable `final` de nivel superior), no en un `build`: cada sprite revela y guarda sus propias imágenes.
@immutable
class Sprite {
  /// Sprite de un solo fotograma.
  Sprite(String nombre, List<String> filas, {PuntoPixel? ancla}) : this.animado(nombre, [filas], ancla: ancla);

  /// Sprite con varios [fotogramas] (todos del mismo tamaño) que se alternan según [animacion].
  Sprite.animado(this.nombre, List<List<String>> fotogramas, {this.animacion, PuntoPixel? ancla})
    : fotogramas = List.unmodifiable([for (final filas in fotogramas) List<String>.unmodifiable(filas)]),
      ancla = ancla ?? _pies(fotogramas) {
    assert(() {
      validar();
      return true;
    }());
  }

  /// Para los mensajes de error y las pruebas.
  final String nombre;

  /// Cada fotograma es una lista de filas del mismo ancho.
  final List<List<String>> fotogramas;

  final AnimacionPixel? animacion;

  /// El punto del dibujo que va en la posición de la escena. Por defecto, el centro del borde de abajo (los pies).
  final PuntoPixel ancla;

  static PuntoPixel _pies(List<List<String>> fotogramas) {
    final filas = fotogramas.isEmpty ? const <String>[] : fotogramas.first;
    return (x: filas.isEmpty ? 0 : filas.first.length ~/ 2, y: filas.length);
  }

  int get ancho => fotogramas.first.first.length;
  int get alto => fotogramas.first.length;
  Size get tamano => Size(ancho.toDouble(), alto.toDouble());

  /// Comprueba el dibujo y lanza un [SpriteInvalido] con todos los problemas que encuentra. El constructor ya la
  /// llama en debug; en release no se comprueba nada.
  void validar() {
    final problemas = <String>[];
    var clavesMal = false;
    if (fotogramas.isEmpty) {
      problemas.add('no tiene fotogramas.');
    } else if (fotogramas.first.isEmpty || fotogramas.first.first.isEmpty) {
      problemas.add('el fotograma 0 está vacío.');
    } else {
      final ancho = fotogramas.first.first.length;
      final alto = fotogramas.first.length;
      for (var f = 0; f < fotogramas.length; f++) {
        final filas = fotogramas[f];
        if (filas.length != alto) {
          problemas.add('el fotograma $f tiene ${filas.length} filas y el 0 tiene $alto: todos miden lo mismo.');
        }
        for (var y = 0; y < filas.length; y++) {
          final fila = filas[y];
          if (fila.length != ancho) {
            problemas.add(
              'fotograma $f, fila $y: mide ${fila.length} píxeles y la fila 0 mide $ancho. Todas las filas miden lo '
              'mismo (rellena con «.»).',
            );
          }
          for (var x = 0; x < fila.length; x++) {
            if (!PaletaPixel.esClave(fila[x])) {
              clavesMal = true;
              problemas.add('fotograma $f, fila $y, columna $x: «${fila[x]}» no es una clave de PaletaPixel.');
            }
          }
        }
      }
    }
    final pasos = animacion?.pasos;
    if (pasos != null) {
      if (pasos.isEmpty) problemas.add('la animación no tiene pasos.');
      for (var i = 0; i < pasos.length; i++) {
        final fotograma = pasos[i].fotograma;
        if (fotograma < 0 || fotograma >= fotogramas.length) {
          problemas.add(
            'el paso $i de la animación usa el fotograma $fotograma, pero solo hay ${fotogramas.length} '
            '(del 0 al ${fotogramas.length - 1}).',
          );
        }
      }
    }
    if (problemas.isNotEmpty) throw SpriteInvalido(nombre, problemas, clavesMal: clavesMal);
  }

  /// Copia con otros colores: cada clave de [cambios] se cambia por su valor en todos los fotogramas. Sirve para
  /// variantes de un mismo personaje (piel, pelo, ropa); [PaletaPixel.cambio] da el color y su sombra a la vez:
  ///
  /// ```dart
  /// final amiga = chica.recolorear({
  ///   ...PaletaPixel.cambio(PaletaPixel.piel3, PaletaPixel.piel6),
  ///   ...PaletaPixel.cambio(PaletaPixel.castanoClaro, PaletaPixel.negro),
  /// }, nombre: 'amiga');
  /// ```
  Sprite recolorear(Map<String, String> cambios, {String? nombre}) {
    assert(
      cambios.entries.every((cambio) => cambio.key.length == 1 && cambio.value.length == 1),
      'recolorear: cada cambio es de una clave a otra, de un carácter cada una ($cambios).',
    );
    final tabla = {for (final cambio in cambios.entries) cambio.key.codeUnitAt(0): cambio.value.codeUnitAt(0)};
    String cambiar(String fila) => String.fromCharCodes([for (final codigo in fila.codeUnits) tabla[codigo] ?? codigo]);
    return Sprite.animado(
      nombre ?? this.nombre,
      [
        for (final filas in fotogramas) [for (final fila in filas) cambiar(fila)],
      ],
      animacion: animacion,
      ancla: ancla,
    );
  }

  @override
  String toString() => 'Sprite($nombre, $ancho×$alto, ${fotogramas.length} fotograma(s))';
}

/// Copia de [base] con las filas de [cambios] (número de fila → fila nueva). Para un fotograma que solo cambia en unas
/// filas, como los ojos cerrados de un parpadeo:
///
/// ```dart
/// final cerrados = retocar(quieto, {9: '....NT33NN3333NN33TN....'});
/// ```
List<String> retocar(List<String> base, Map<int, String> cambios) {
  assert(
    cambios.keys.every((fila) => fila >= 0 && fila < base.length),
    'retocar: hay filas fuera del dibujo (de la 0 a la ${base.length - 1}): ${cambios.keys.toList()}.',
  );
  return [for (var y = 0; y < base.length; y++) cambios[y] ?? base[y]];
}

/// Un sprite mal dibujado: filas de distinto ancho, caracteres que no están en [PaletaPixel] o una animación que usa
/// fotogramas que no existen. [problemas] dice dónde está cada uno (fotograma, fila y columna).
class SpriteInvalido extends Error {
  SpriteInvalido(this.sprite, this.problemas, {this.clavesMal = false});

  /// Nombre del sprite.
  final String sprite;

  final List<String> problemas;

  /// Si alguno de los problemas es un carácter que no está en la paleta (el mensaje recuerda las claves).
  final bool clavesMal;

  static const _maximo = 12;

  @override
  String toString() {
    final lista = [for (final problema in problemas.take(_maximo)) '  · $problema'].join('\n');
    final mas = problemas.length > _maximo ? '\n  · … y ${problemas.length - _maximo} más.' : '';
    final claves = clavesMal ? '\nClaves válidas: «.» (transparente) y ${PaletaPixel.claves}.' : '';
    return 'SpriteInvalido: el sprite «$sprite» está mal dibujado:\n$lista$mas$claves\n'
        'La guía de estilo está en lib/pixel/LEEME.md.';
  }
}
