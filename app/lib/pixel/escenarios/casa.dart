import '../motor/motor.dart';
import 'escenario_pixel.dart';
import 'teselas.dart';

/// El salón de casa: papel pintado amarillo de florecitas, zócalo claro, sofá azul con cojines (y un gato dormido que
/// respira: dos fotogramas), ventana con cortinas, cuadros, lámpara de pie encendida, estantería con libros, una
/// planta, la luz del sol en el suelo y una alfombra donde se ponen los personajes.
final escenarioCasa = EscenarioPixel(
  lugar: 'casa',
  descripcion:
      'El salón de casa: un sofá azul con cojines y un gato dormido, una ventana con cortinas, una estantería con libros '
      'y una lámpara encendida.',
  fondo: Sprite.animado('casa', [
    _pintarCasa(0),
    _pintarCasa(1),
  ], animacion: const AnimacionPixel([PasoPixel(0, ms: 1500), PasoPixel(1, ms: 1500)])),
  puestos: const {'izquierda': (x: 40, y: 89), 'centro': (x: 80, y: 91), 'derecha': (x: 122, y: 89)},
);

const _suelo = 60;

const _papel = [
  '............',
  '.....Y......',
  '....YoY.....',
  '.....Y......',
  '............',
  '............',
  '............',
  '...........Y',
  'Y.........Yo',
  '...........Y',
  '............',
  '............',
];

List<String> _pintarCasa(int fotograma) {
  final l = LienzoPixel(anchoFondo, altoFondo, 'y')..mosaico(_papel, 0, 0, anchoFondo, 42);
  // Zócalo claro con cuarterones y suelo de tablas.
  l
    ..zocalo(42, _suelo, color: 'h', sombra: 'c', luz: 'W', moldura: 'c', panel: 20, desfase: 3)
    ..tablas(_suelo, semilla: 11)
    ..luzEnSuelo(14, 44, _suelo + 1, 86, {'m': 'u', 't': 'm'});

  // Ventana con cortinas y un radiador debajo.
  l
    ..ventana(12, 9, 34, 28, semilla: 4)
    ..cortinas(12, 6, 34, 41, tela: 'r');
  l
    ..caja(15, 45, 28, 11, 'W')
    ..lineaH(16, 46, 26, 'h');
  for (var x = 18; x < 42; x += 3) {
    l.lineaV(x, 47, 8, 'g');
  }
  l
    ..lineaH(16, 54, 26, 'g')
    ..rect(17, 56, 2, 3, 'G')
    ..rect(39, 56, 2, 3, 'G');

  // Cuadros encima del sofá: un paisaje y una foto de familia.
  l
    ..cuadro(62, 13, 24, 17, _paisaje(20, 13))
    ..cuadro(90, 17, 13, 14, _foto, color: 'o', luz: 'y');

  // Sofá azul con cojines y el gato dormido entre ellos.
  l
    ..sofa(56, 37)
    ..pegar(_gato[fotograma], 75, 46);

  // Lámpara de pie con su luz en la pared.
  l.resplandor(114, 25, 7, {'y': 'P', 'Y': 'y', 'o': 'Y', 'h': 'P', 'c': 'h'});
  l
    ..pegar(pantallaLampara, 108, 19)
    ..lineaV(113, 25, 36, 'N')
    ..lineaV(114, 25, 36, 'K')
    ..lineaV(115, 25, 36, 'N')
    ..pegar(['...NNKKKNN..', '..NKKKKKKKN.', '...NNNNNNN..'], 108, 61)
    ..sombraSuelo(110, 66, 9);

  // Estantería con libros y una planta encima.
  l
    ..estanteria(122, 15, 34, 51, baldas: 4, semilla: 21)
    ..apoyar(plantaPequena, 134, 15)
    ..sombraSuelo(121, 66, 36);

  // Planta grande junto a la ventana.
  l
    ..apoyar(plantaGrande, -1, 67)
    ..sombraSuelo(3, 66, 12);

  // Alfombra.
  _alfombra(l, 26, 72, 108, 20);
  return l.filas;
}

/// Un gato naranja dormido, hecho un ovillo (13 × 7): al respirar, el lomo sube un píxel.
const _gato = [
  [
    '.............',
    '.N...N.......',
    'NoN.NoN......',
    'NoooooNNNNNN.',
    'NototoNoootoN',
    'NoosooNotootN',
    'NoooooooottoN',
    '.NNNNNNNNNNN.',
  ],
  [
    '.............',
    '.N...N.......',
    'NoN.NoNNNNN..',
    'NoooooNootooN',
    'NototoNoootoN',
    'NoosooNotootN',
    'NoooooooottoN',
    '.NNNNNNNNNNN.',
  ],
];

/// Un paisaje para un cuadro: cielo, sol y colinas.
List<String> _paisaje(int ancho, int alto) {
  final l = LienzoPixel(ancho, alto, 'c')
    ..rect(0, alto - 6, ancho, 6, 'h')
    ..ovaloEn(ancho - 7, 1, 5, 5, 'Y')
    ..ovaloEn(-4, alto - 6, 16, 12, 'v')
    ..ovaloEn(6, alto - 4, 22, 10, 'V')
    ..ovaloEn(9, alto - 5, 10, 6, 'v');
  return l.filas;
}

/// Foto de familia: tres caras sonrientes sobre fondo azul.
const _foto = [
  'hhhhhhhhh',
  'hhzzhhhhh',
  'hz55hhuuh',
  'hh55hu22h',
  'hhhhhh22h',
  'hAAhTThhh',
  'AAAT33Yrr',
  'AAAT33Yrr',
  'AAAYYYrrr',
  'AAAYYYrrr',
];

/// Alfombra tejida: borde teja, cenefa coral con un zigzag amarillo y campo crema con rombos ocres.
void _alfombra(LienzoPixel l, int x, int y, int ancho, int alto) {
  l
    ..redondo(x, y, ancho, alto, 'R', radio: 3)
    ..redondo(x + 1, y + 1, ancho - 2, alto - 2, 'r', radio: 2)
    ..redondo(x + 4, y + 4, ancho - 8, alto - 8, 'R', radio: 1)
    ..redondo(x + 5, y + 5, ancho - 10, alto - 10, 'p', radio: 1);
  // Zigzag de la cenefa, arriba y abajo.
  for (var i = x + 5; i < x + ancho - 5; i++) {
    final paso = (i - x) % 4;
    final fila = paso < 2 ? 1 : 2;
    l
      ..punto(i, y + fila, 'Y')
      ..punto(i, y + alto - 1 - fila, 'Y');
  }
  // Rombos en el centro.
  const rombo = ['..o..', '.oYo.', 'oYrYo', '.oYo.', '..o..'];
  final cy = y + alto ~/ 2 - 2;
  for (var i = x + 10; i + 5 < x + ancho - 8; i += 14) {
    l.pegar(rombo, i, cy);
  }
  for (var i = x + 17; i + 1 < x + ancho - 10; i += 14) {
    l
      ..punto(i, cy + 2, 'o')
      ..punto(i + 1, cy + 2, 'o');
  }
  // Flecos a los lados.
  for (var j = y + 3; j < y + alto - 3; j += 2) {
    l
      ..punto(x - 1, j, 'p')
      ..punto(x + ancho, j, 'p');
  }
}
