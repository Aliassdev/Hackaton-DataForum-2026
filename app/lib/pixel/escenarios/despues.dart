import '../motor/motor.dart';
import 'escenario_pixel.dart';
import 'teselas.dart';

/// Un parque al atardecer: cielo en franjas (lila, rosa, coral y amarillo), un sol grande que se pone tras las colinas,
/// un árbol, una farola encendida, un banco, flores y el camino donde se ponen los personajes. Unos pájaros baten las
/// alas (dos fotogramas).
final escenarioDespues = EscenarioPixel(
  lugar: 'despues',
  descripcion:
      'Un parque al atardecer: el sol se pone tras las colinas, hay un árbol grande, una farola encendida y un banco '
      'junto al camino.',
  fondo: Sprite.animado('despues', [
    _pintarDespues(0),
    _pintarDespues(1),
  ], animacion: const AnimacionPixel([PasoPixel(0, ms: 450), PasoPixel(1, ms: 450)])),
  puestos: const {'izquierda': (x: 42, y: 87), 'centro': (x: 82, y: 88), 'derecha': (x: 122, y: 87)},
);

const _horizonte = 56;

List<String> _pintarDespues(int fotograma) {
  final l = LienzoPixel(anchoFondo, altoFondo, 'L');
  _cielo(l);

  // El sol, medio escondido, y nubes alargadas iluminadas por debajo.
  l
    ..ovaloEn(82, 32, 32, 32, 'Y')
    ..ovaloEn(84, 34, 28, 28, 'y');
  for (final (x, y, largo) in [(10, 12, 26), (24, 15, 18), (112, 9, 30), (126, 13, 16), (58, 24, 22)]) {
    l
      ..lineaH(x, y, largo, 'P')
      ..lineaH(x + 3, y + 1, largo - 4, 's')
      ..lineaH(x + 2, y - 1, largo - 8, 'P');
  }

  // Colinas lejanas lila y una fila de árboles azul marino.
  l
    ..ovaloEn(-20, 46, 90, 24, 'L')
    ..ovaloEn(56, 48, 70, 20, 'L')
    ..ovaloEn(110, 44, 80, 26, 'L');
  for (var x = -2; x < anchoFondo; x += 9) {
    final r = 7 + (x * 7 % 5);
    l.ovaloEn(x, _horizonte - r + 3, r, r, 'D');
  }

  // Césped, el camino y la hierba de delante.
  l
    ..rect(0, _horizonte, anchoFondo, altoFondo - _horizonte, 'v')
    ..lineaH(0, _horizonte, anchoFondo, 'V')
    ..rect(0, 74, anchoFondo, 16, 'p')
    ..lineaH(0, 74, anchoFondo, 'o')
    ..lineaH(0, 75, anchoFondo, 'u')
    ..lineaH(0, 89, anchoFondo, 'o')
    ..rect(0, 90, anchoFondo, 6, 'v');
  final azar = AzarPixel(53);
  for (var k = 0; k < 40; k++) {
    l.punto(azar.entero(anchoFondo), 77 + azar.entero(11), azar.si(50) ? 'o' : 'P');
  }
  for (var k = 0; k < 70; k++) {
    final x = azar.entero(anchoFondo), y = _horizonte + 2 + azar.entero(16);
    l
      ..punto(x, y, 'V')
      ..punto(x + 1, y - 1, 'V');
  }
  // Flores.
  for (final (x, y, color) in [
    (34, 66, 'Y'),
    (40, 68, 's'),
    (46, 65, 'W'),
    (100, 69, 'Y'),
    (106, 67, 's'),
    (150, 66, 'r'),
    (8, 92, 's'),
    (70, 93, 'Y'),
    (140, 92, 'W'),
  ]) {
    l
      ..punto(x, y, color)
      ..punto(x - 1, y + 1, color)
      ..punto(x + 1, y + 1, color)
      ..punto(x, y + 2, color)
      ..punto(x, y + 1, 'o');
  }

  // El banco y la farola.
  _banco(l, 110, 59);
  _farola(l, 64, 22);
  // El árbol grande de la izquierda.
  _arbol(l, -10, 0);

  // Pájaros: alas arriba o abajo según el fotograma.
  for (final (x, y) in [(60, 10), (68, 14), (76, 8)]) {
    if (fotograma == 0) {
      l.pegar(['D...D', '.D.D.', '..D..'], x, y);
    } else {
      l.pegar(['.....', 'DDDDD', '..D..'], x, y);
    }
  }
  return l.filas;
}

/// Franjas del cielo, de arriba abajo, con una fila en damero entre cada dos para que no haya escalones bruscos.
void _cielo(LienzoPixel l) {
  const franjas = [('L', 0), ('s', 12), ('r', 24), ('o', 34), ('Y', 42), ('y', 49)];
  for (final (i, (color, desde)) in franjas.indexed) {
    l.rect(0, desde, anchoFondo, _horizonte - desde, color);
    if (i > 0) {
      for (var x = 0; x < anchoFondo; x += 2) {
        l
          ..punto(x, desde, franjas[i - 1].$1)
          ..punto(x + 1, desde - 1, color);
      }
    }
  }
}

void _banco(LienzoPixel l, int x, int y) {
  const ancho = 30;
  l
    ..caja(x, y, ancho, 3, 'm')
    ..lineaH(x + 1, y + 1, ancho - 2, 'u')
    ..caja(x, y + 4, ancho, 3, 'm')
    ..lineaH(x + 1, y + 5, ancho - 2, 'u')
    ..caja(x - 1, y + 8, ancho + 2, 3, 'm')
    ..lineaH(x, y + 9, ancho, 't');
  for (final px in [x + 2, x + ancho - 4]) {
    l
      ..rect(px, y + 3, 2, 1, 'K')
      ..rect(px, y + 7, 2, 1, 'K')
      ..rect(px, y + 11, 2, 4, 'K')
      ..lineaV(px - 1, y + 11, 4, 'N')
      ..lineaV(px + 2, y + 11, 4, 'N');
  }
  l.sombraSuelo(x, y + 15, ancho, filas: 1);
}

void _farola(LienzoPixel l, int x, int y) {
  l
    ..resplandor(x + 4, y + 4, 6, {'s': 'P', 'r': 's', 'L': 's', 'o': 'u', 'Y': 'y', 'y': 'P'})
    ..pegar(['..NNNNN..', '.NKKKKKN.', 'NKyyyyyKN', 'NKyWWWyKN', 'NKyyyyyKN', '.NKKKKKN.', '..NNKNN..'], x, y)
    ..rect(x + 3, y + 7, 3, 44, 'K')
    ..lineaV(x + 2, y + 7, 44, 'N')
    ..lineaV(x + 6, y + 7, 44, 'N')
    ..lineaV(x + 4, y + 7, 44, 'G')
    ..caja(x + 1, y + 50, 7, 3, 'K')
    ..sombraSuelo(x, y + 53, 9, filas: 1);
}

/// Un árbol grande: una copa de racimos redondos, con la luz del sol por la derecha (el lado de la izquierda y el de
/// abajo, en verde oscuro), y el tronco.
void _arbol(LienzoPixel l, int x, int y) {
  l
    ..rect(x + 20, y + 30, 7, 42, 'T')
    ..lineaV(x + 19, y + 30, 42, 'N')
    ..lineaV(x + 27, y + 30, 42, 'N')
    ..lineaV(x + 25, y + 34, 36, 't')
    ..pegar(['N.......N', '.N.....N.', '..N...N..'], x + 19, y + 70)
    ..sombraSuelo(x + 12, y + 72, 24, filas: 2);
  // La copa se pinta aparte: racimos de atrás a delante, cada uno con su lado de sombra, y un solo contorno por fuera.
  final copa = LienzoPixel(52, 46);
  for (final (cx, cy, r) in [
    (8, 10, 22),
    (20, 1, 24),
    (34, 6, 18),
    (6, 24, 20),
    (22, 16, 22),
    (36, 20, 14),
    (18, 30, 14),
  ]) {
    final forma = ovalo(r, r);
    copa
      ..figura(cx, cy, r, r, forma, 'v')
      ..cambiar(cx, cy, r, r, {'v': 'V'}, forma: (i, j) => forma(i, j) && (r / 2 - i) + (j - r / 2) > r * 0.12);
  }
  copa.contornear('N');
  l.pegar(copa.filas, x - 8, y - 2);
}
