import 'dart:typed_data';

import 'paleta_pixel.dart';

/// Una cuadrícula de claves de [PaletaPixel] que se pinta con código, para los dibujos grandes (un fondo de 160 × 96
/// a mano son 96 filas de 160 caracteres). Al terminar, [filas] da las filas para un `Sprite`. Lo que se sale del
/// lienzo se recorta sin avisar.
///
/// ```dart
/// final sala = LienzoPixel(160, 96, 'P')       // pared de papel
///   ..rect(0, 70, 160, 26, 'm')                // suelo de madera
///   ..lineaH(0, 70, 160, 'N')                  // el borde del suelo
///   ..pegar(ventana, 24, 14);                  // un dibujo pequeño encima («.» no tapa)
/// final fondo = Sprite('sala', sala.filas);
/// ```
class LienzoPixel {
  /// Un lienzo de [ancho] × [alto] píxeles con todo de [relleno] (transparente si no se dice).
  LienzoPixel(this.ancho, this.alto, [String relleno = PaletaPixel.transparente])
    : assert(ancho > 0 && alto > 0, 'LienzoPixel: $ancho × $alto.'),
      _celdas = Uint8List(ancho * alto)..fillRange(0, ancho * alto, _codigo(relleno));

  final int ancho;
  final int alto;
  final Uint8List _celdas;

  static final _transparente = PaletaPixel.transparente.codeUnitAt(0);

  static int _codigo(String clave) {
    assert(clave.length == 1, 'LienzoPixel: «$clave» no es una clave (las claves son de un carácter).');
    return _comprobado(clave.codeUnitAt(0));
  }

  /// [codigo], tras comprobar en debug que es una clave de la paleta o «.».
  static int _comprobado(int codigo) {
    assert(
      codigo == _transparente || PaletaPixel.colorDe(codigo) != null,
      'LienzoPixel: «${String.fromCharCode(codigo)}» no es una clave de PaletaPixel (ni «.»). '
      'Claves: ${PaletaPixel.claves}.',
    );
    return codigo;
  }

  /// La clave del píxel ([x], [y]), o «.» si está fuera.
  String en(int x, int y) => x < 0 || y < 0 || x >= ancho || y >= alto
      ? PaletaPixel.transparente
      : String.fromCharCode(_celdas[y * ancho + x]);

  void _poner(int x, int y, int codigo) {
    if (x >= 0 && y >= 0 && x < ancho && y < alto) _celdas[y * ancho + x] = codigo;
  }

  void punto(int x, int y, String clave) => _poner(x, y, _codigo(clave));

  /// Un rectángulo relleno con la esquina de arriba a la izquierda en ([x], [y]).
  void rect(int x, int y, int ancho, int alto, String clave) {
    final codigo = _codigo(clave);
    for (var j = y; j < y + alto; j++) {
      for (var i = x; i < x + ancho; i++) {
        _poner(i, j, codigo);
      }
    }
  }

  /// El borde de 1 píxel de un rectángulo.
  void marco(int x, int y, int ancho, int alto, String clave) {
    rect(x, y, ancho, 1, clave);
    rect(x, y + alto - 1, ancho, 1, clave);
    rect(x, y, 1, alto, clave);
    rect(x + ancho - 1, y, 1, alto, clave);
  }

  void lineaH(int x, int y, int largo, String clave) => rect(x, y, largo, 1, clave);

  void lineaV(int x, int y, int largo, String clave) => rect(x, y, 1, largo, clave);

  /// Una línea de 1 píxel de ([x0], [y0]) a ([x1], [y1]), los dos incluidos (Bresenham, sin antialiasing).
  void linea(int x0, int y0, int x1, int y1, String clave) {
    final codigo = _codigo(clave);
    final dx = (x1 - x0).abs();
    final dy = -(y1 - y0).abs();
    final pasoX = x0 < x1 ? 1 : -1;
    final pasoY = y0 < y1 ? 1 : -1;
    var error = dx + dy;
    var x = x0;
    var y = y0;
    while (true) {
      _poner(x, y, codigo);
      if (x == x1 && y == y1) return;
      final doble = 2 * error;
      if (doble >= dy) {
        error += dy;
        x += pasoX;
      }
      if (doble <= dx) {
        error += dx;
        y += pasoY;
      }
    }
  }

  /// Pega un dibujo de filas con su esquina en ([x], [y]). Los «.» del dibujo no tapan lo que hay debajo. Con
  /// [espejo], dado la vuelta de izquierda a derecha.
  void pegar(List<String> filas, int x, int y, {bool espejo = false}) {
    for (var j = 0; j < filas.length; j++) {
      final fila = filas[j];
      for (var i = 0; i < fila.length; i++) {
        final codigo = _comprobado(fila.codeUnitAt(espejo ? fila.length - 1 - i : i));
        if (codigo != _transparente) _poner(x + i, y + j, codigo);
      }
    }
  }

  /// Repite [tesela] (como un azulejo) para llenar el rectángulo de [ancho] × [alto] con la esquina en ([x], [y]). Las
  /// teselas empiezan en la esquina del rectángulo; sus «.» no tapan.
  void mosaico(List<String> tesela, int x, int y, int ancho, int alto) {
    final altoTesela = tesela.length;
    final anchoTesela = tesela.first.length;
    for (var j = 0; j < alto; j++) {
      final fila = tesela[j % altoTesela];
      for (var i = 0; i < ancho; i++) {
        final codigo = _comprobado(fila.codeUnitAt(i % anchoTesela));
        if (codigo != _transparente) _poner(x + i, y + j, codigo);
      }
    }
  }

  /// Las filas del lienzo, para un `Sprite`.
  List<String> get filas => [for (var y = 0; y < alto; y++) String.fromCharCodes(_celdas, y * ancho, (y + 1) * ancho)];
}
