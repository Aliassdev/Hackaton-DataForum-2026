import '../motor/motor.dart';
import 'escenario_pixel.dart';
import 'teselas.dart';

/// El vestíbulo del juzgado: paredes de piedra clara con pilastras, dos ventanales en arco, una gran puerta de madera
/// con una balanza dorada encima, un banco, plantas y el mostrador de información.
final escenarioJuzgado = EscenarioPixel(
  lugar: 'juzgado',
  descripcion:
      'La entrada del juzgado: un vestíbulo grande y luminoso, con ventanales, una puerta de madera con una balanza '
      'encima y un mostrador de información.',
  fondo: Sprite('juzgado', _pintarJuzgado()),
  puestos: const {
    'izquierda': (x: 44, y: 90),
    'centro': (x: 80, y: 91),
    'derecha': (x: 116, y: 90),
    'recepcion': (x: 140, y: 62),
  },
);

const _suelo = 62;

/// Una ventana de [ancho] × [alto] con el remate de arriba en medio punto.
FormaPixel _arco(int ancho, int alto) {
  final r = ancho / 2;
  return (i, j) {
    if (i < 0 || j < 0 || i >= ancho || j >= alto) return false;
    if (j >= r) return true;
    final dx = i + 0.5 - r;
    final dy = j + 0.5 - r;
    return dx * dx + dy * dy <= r * r;
  };
}

List<String> _pintarJuzgado() {
  final l = LienzoPixel(anchoFondo, altoFondo, 'p');
  // Sillares de piedra: una línea clara cada 8 filas y juntas al tresbolillo.
  for (var y = 7; y < _suelo; y += 8) {
    l.lineaH(0, y, anchoFondo, 'P');
    for (var x = (y ~/ 8).isEven ? 0 : 12; x < anchoFondo; x += 24) {
      l.lineaV(x, y + 1, 7, 'P');
    }
  }
  l
    ..rect(0, 0, anchoFondo, 3, 'P')
    ..lineaH(0, 3, anchoFondo, 'o')
    ..rodapie(_suelo - 3, color: 'o', luz: 'P', linea: 't')
    ..baldosas(_suelo, clara: 'P', oscura: 'g', lado: 16, altoFila: 3)
    ..luzEnSuelo(10, 34, _suelo + 1, 92, {'g': 'h', 'P': 'W'});

  _ventanal(l, 8, 8, 28, 40);
  _ventanal(l, 124, 8, 28, 40);
  _pilastra(l, 44, 4);
  _pilastra(l, 110, 4);

  // La gran puerta de madera, de dos hojas, con la balanza encima.
  _puerta(l, 60, 24, 40, _suelo - 24);
  l.pegar(_balanza, 69, 5);

  // Banco de madera bajo la ventana de la izquierda y dos plantas a los lados de la puerta.
  _banco(l, 6, 50);
  l
    ..apoyar(plantaAlta, 46, 64)
    ..sombraSuelo(48, 63, 9, filas: 1)
    ..apoyar(plantaAlta, 102, 64)
    ..sombraSuelo(104, 63, 9, filas: 1);

  // Mostrador de información, con una pantalla, un timbre y una planta.
  _mostrador(l, 120, 47);
  // Placas con flechas en las pilastras.
  l
    ..caja(42, 30, 12, 7, 'A')
    ..pegar(['..W.....', '.WWWWWW.', '..W.....'], 44, 32)
    ..caja(108, 30, 12, 7, 'A')
    ..pegar(['.....W..', '.WWWWWW.', '.....W..'], 110, 32);
  return l.filas;
}

void _ventanal(LienzoPixel l, int x, int y, int ancho, int alto) {
  final forma = _arco(ancho, alto);
  l.figura(x, y, ancho, alto, forma, 'W', contorno: 'N');
  final interior = _arco(ancho - 4, alto - 4);
  final vista = vistaCielo(ancho - 4, alto - 4, paisaje: PaisajePixel.arboles, semilla: x);
  l.pegar(recortarForma(vista, interior), x + 2, y + 2);
  // Parteluz, travesaño y brillos.
  final cx = x + ancho ~/ 2;
  l
    ..lineaV(cx - 1, y + 1, alto - 2, 'W')
    ..lineaV(cx, y + 1, alto - 2, 'h')
    ..lineaH(x + 1, y + ancho ~/ 2, ancho - 2, 'W')
    ..lineaH(x + 2, y + ancho ~/ 2 + 1, ancho - 4, 'h');
  for (var k = 0; k < 3; k++) {
    l.punto(x + 4 + k, y + ancho ~/ 2 + 6 - k, 'W');
  }
  // Alféizar de piedra.
  l
    ..caja(x - 2, y + alto - 1, ancho + 4, 3, 'P')
    ..lineaH(x - 1, y + alto + 1, ancho + 2, 'p');
}

/// Pilastra de 8 de ancho desde la fila [y] hasta el suelo, con capitel y basa.
void _pilastra(LienzoPixel l, int x, int y) {
  final alto = _suelo - y;
  l
    ..rect(x, y, 8, alto, 'P')
    ..lineaV(x, y, alto, 'W')
    ..lineaV(x + 6, y, alto, 'p')
    ..lineaV(x + 7, y, alto, 'o')
    ..lineaV(x + 3, y + 6, alto - 12, 'p')
    ..caja(x - 2, y, 12, 4, 'P', 'o')
    ..lineaH(x - 1, y + 1, 10, 'W')
    ..caja(x - 2, _suelo - 5, 12, 5, 'P', 'o')
    ..lineaH(x - 1, _suelo - 4, 10, 'W');
}

/// Puerta de dos hojas con arco de medio punto.
void _puerta(LienzoPixel l, int x, int y, int ancho, int alto) {
  // Marco de piedra.
  l.figura(x - 3, y - 3, ancho + 6, alto + 3, _arco(ancho + 6, alto + 3), 'P', contorno: 'o');
  l.figura(x, y, ancho, alto, _arco(ancho, alto), 'm', contorno: 'N');
  final mitad = x + ancho ~/ 2;
  l
    ..lineaV(mitad, y + 1, alto - 1, 'N')
    ..lineaV(mitad - 1, y + 2, alto - 2, 't')
    ..lineaV(x + ancho - 2, y + ancho ~/ 2, alto - ancho ~/ 2, 't');
  // Cuarterones de cada hoja, debajo del arco.
  for (final hx in [x + 3, mitad + 3]) {
    final w = ancho ~/ 2 - 6;
    l
      ..marco(hx, y + 21, w, 7, 't')
      ..lineaH(hx + 1, y + 27, w - 1, 'u')
      ..marco(hx, y + 29, w, alto - 32, 't')
      ..lineaH(hx + 1, y + alto - 4, w - 1, 'u');
  }
  // Abanico del arco con cristal.
  l.figura(
    x + 4,
    y + 4,
    ancho - 8,
    ancho ~/ 2 - 6,
    (i, j) => _arco(ancho - 8, ancho - 8)(i, j) && j < ancho ~/ 2 - 6,
    'c',
    contorno: 'N',
  );
  l
    ..lineaV(mitad, y + 5, ancho ~/ 2 - 8, 'N')
    ..punto(x + 9, y + 10, 'h')
    ..punto(x + 10, y + 9, 'h');
  // Tiradores.
  l
    ..rect(mitad - 4, y + 24, 2, 5, 'Y')
    ..rect(mitad + 3, y + 24, 2, 5, 'Y')
    ..punto(mitad - 3, y + 28, 'o')
    ..punto(mitad + 4, y + 28, 'o');
}

const _balanza = [
  '.........NN.........',
  '........NyYN........',
  '.........NN.........',
  '.NNNNNNNNYoNNNNNNNN.',
  'NYYYYYYYYYoYYYYYYYoN',
  '.NNNNNNNNYoNNNNNNNN.',
  '..N.N....Yo....N.N..',
  '..N.N....Yo....N.N..',
  '.N...N...Yo...N...N.',
  'NYYYYYN..Yo..NYYYYYN',
  '.NoooN...Yo...NoooN.',
  '..NNN...NYoN...NNN..',
  '.......NYYYoN.......',
  '......NNNNNNNN......',
];

void _banco(LienzoPixel l, int x, int y) {
  l
    ..caja(x, y, 34, 3, 'm')
    ..lineaH(x + 1, y + 1, 32, 'u')
    ..caja(x, y + 4, 34, 4, 'm')
    ..lineaH(x + 1, y + 5, 32, 'u')
    ..lineaH(x + 1, y + 6, 32, 't');
  for (final px in [x + 3, x + 29]) {
    l
      ..rect(px, y + 8, 2, 6, 'K')
      ..lineaV(px - 1, y + 8, 6, 'N')
      ..lineaV(px + 2, y + 8, 6, 'N');
  }
  l.sombraSuelo(x + 1, y + 14, 32, filas: 1);
}

void _mostrador(LienzoPixel l, int x, int y) {
  const ancho = 38;
  final alto = _suelo + 4 - y;
  // La pantalla y el timbre, encima.
  l
    ..caja(x + 4, y - 9, 13, 9, 'K')
    ..rect(x + 5, y - 8, 11, 6, 'G')
    ..rect(x + 9, y - 1, 3, 1, 'K')
    ..pegar(['.NN.', 'NYYN', 'NNNN'], x + 22, y - 3)
    ..apoyar(plantaPequena, x + 27, y);
  l
    ..caja(x, y, ancho, 3, 'm')
    ..lineaH(x + 1, y + 1, ancho - 2, 'u')
    ..caja(x + 1, y + 3, ancho - 2, alto - 3, 'A')
    ..lineaV(x + 2, y + 4, alto - 5, 'a')
    ..lineaV(x + ancho - 3, y + 4, alto - 5, 'D')
    ..lineaH(x + 2, y + alto - 3, ancho - 4, 'D');
  for (var px = x + 7; px < x + ancho - 4; px += 6) {
    l.lineaV(px, y + 5, alto - 9, 'D');
  }
  // Un bocadillo con tres puntos: «pregunta aquí», sin letras.
  l
    ..pegar(_bocadillo, x + ancho ~/ 2 - 5, y + 5)
    ..sombraSuelo(x, y + alto, ancho, filas: 1);
}

const _bocadillo = ['.NNNNNNNN.', 'NWWWWWWWWN', 'NWAWWAWWAN', 'NWWWWWWWhN', '.NNWNNNNN.', '..NWN.....', '..NN......'];
