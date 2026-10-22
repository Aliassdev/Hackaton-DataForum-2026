import 'dart:math' as math;

import '../motor/motor.dart';
import 'escenario_pixel.dart';
import 'teselas.dart';

/// La habitación de una chica o un chico adolescente, de noche: paredes lavanda, ventana con luna y estrellas, una
/// guirnalda de lucecitas, la cama con el edredón lila y el móvil encendido encima, la mesilla con su lámpara, una
/// guitarra, pósteres y el escritorio con el portátil. El brillo del móvil y las lucecitas se mueven (dos fotogramas).
final escenarioHabitacion = EscenarioPixel(
  lugar: 'habitacion',
  descripcion:
      'Una habitación de noche: la cama con el móvil encendido encima, una ventana con la luna, lucecitas en la pared, '
      'una guitarra y un escritorio.',
  fondo: Sprite.animado('habitacion', [
    _pintarHabitacion(0),
    _pintarHabitacion(1),
  ], animacion: const AnimacionPixel([PasoPixel(0, ms: 1100), PasoPixel(1, ms: 1100)])),
  puestos: const {'izquierda': (x: 40, y: 90), 'centro': (x: 80, y: 91), 'derecha': (x: 122, y: 90)},
);

const _suelo = 60;

List<String> _pintarHabitacion(int fotograma) {
  // De noche: paredes azules, zócalo azul eléctrico y la madera del suelo más oscura.
  final l = LienzoPixel(anchoFondo, altoFondo, 'a')
    ..mosaico(['aaaaaaaaaaaaaac'], 0, 0, anchoFondo, 44)
    ..zocalo(44, _suelo, color: 'A', sombra: 'D', luz: 'a', moldura: 'D', panel: 20, desfase: 2)
    ..tablas(_suelo, madera: 't', junta: 'T', semilla: 23);

  // Ventana con la noche, la luna y estrellas, y cortinas azul marino.
  l
    ..ventana(16, 9, 34, 26, cielo: CieloPixel.noche, paisaje: PaisajePixel.ciudad, semilla: 7)
    ..cortinas(16, 6, 34, 40, tela: 'D', luz: 'A');

  // Pósteres: un planeta y una nota musical.
  l
    ..cuadro(94, 10, 18, 22, _posterPlaneta, color: 'W', luz: 'W')
    ..cuadro(116, 12, 16, 18, _posterMusica, color: 'W', luz: 'W');

  // La lámpara de la mesilla da luz cálida a la pared.
  l.resplandor(78, 40, 9, {'a': 'c', 'c': 'h', 'A': 'a', 'D': 'A'});

  _cama(l, 2, 40, fotograma);
  _mesilla(l, 70, 40);
  l
    ..pegar(_guitarra, 86, 34)
    ..sombraSuelo(86, 66, 10, filas: 1);
  _escritorio(l, 106, 46);

  // Alfombra redonda.
  l
    ..ovaloEn(46, 72, 70, 18, 'R')
    ..ovaloEn(48, 73, 66, 16, 'r')
    ..ovaloEn(58, 76, 46, 10, 's');

  _lucecitas(l, fotograma);
  return l.filas;
}

const _posterPlaneta = [
  'DDDDDDDDDDDDDD',
  'DDhDDDDDDDDyDD',
  'DDDDDDLLLDDDDD',
  'DDDDDLLLLLDDDD',
  'DDYYYYYYYYYYDD',
  'DYDDLLLLLLLDYD',
  'DDYYYYYYYYYYDD',
  'DDDDDLLLLLDDDD',
  'DDDDDDLLLDDDDD',
  'DhDDDDDDDDDDDD',
  'DDDDDDDDDDhDDD',
  'DDDyDDDDDDDDDD',
  'DDDDDDDDDDDDDD',
  'DDDDDhDDDDDDDD',
  'DDDDDDDDDDDDDD',
  'DDDDDDDDDDDDhD',
  'DDDDDDDDDDDDDD',
  'DDDDDDDDDDDDDD',
];

const _posterMusica = [
  'YYYYYYYYYYYY',
  'YYYYNNNNNNYY',
  'YYYYNYYYYNYY',
  'YYYYNNNNNNYY',
  'YYYYNYYYYNYY',
  'YYYYNYYYYNYY',
  'YYYYNYYYYNYY',
  'YYNNNYYNNNYY',
  'YNNNNYNNNNYY',
  'YNNNYYNNNYYY',
  'YYYYYYYYYYYY',
  'YYYYYYYYYYYY',
  'oooooooooooo',
  'oooooooooooo',
];

/// La cama vista de lado (66 × 28): cabecero a la derecha, almohada, edredón lila con lunares y el móvil encendido.
void _cama(LienzoPixel l, int x, int y, int fotograma) {
  // Cabecero y piecero de madera.
  l
    ..redondo(x + 58, y - 6, 8, 32, 'm', contorno: 'N', radio: 2)
    ..lineaV(x + 59, y - 4, 27, 'u')
    ..redondo(x, y + 6, 6, 20, 'm', contorno: 'N', radio: 2)
    ..lineaV(x + 1, y + 8, 15, 'u');
  // Colchón, almohada y edredón.
  l
    ..caja(x + 5, y + 8, 54, 4, 'W')
    ..lineaH(x + 6, y + 11, 52, 'h')
    ..redondo(x + 44, y + 2, 14, 8, 'W', contorno: 'N', radio: 2)
    ..lineaH(x + 46, y + 7, 10, 'h')
    ..redondo(x + 5, y + 4, 42, 18, 'L', contorno: 'N', radio: 2)
    ..lineaH(x + 7, y + 5, 38, 's')
    ..lineaH(x + 6, y + 19, 40, 'D');
  for (var j = y + 8, fila = 0; j < y + 18; j += 4, fila++) {
    for (var i = x + 9 + (fila.isOdd ? 3 : 0); i < x + 44; i += 7) {
      l.punto(i, j, 's');
    }
  }
  // Patas y sombra.
  l
    ..rect(x + 6, y + 22, 3, 4, 'T')
    ..rect(x + 52, y + 22, 3, 4, 'T')
    ..rect(x + 6, y + 22, 52, 2, 'K')
    ..sombraSuelo(x + 1, y + 26, 64);
  // El móvil, encendido, sobre el edredón: su luz se agranda y se encoge.
  final mx = x + 34, my = y + 6;
  final radio = fotograma == 0 ? 4 : 6;
  for (var j = -radio; j <= radio; j++) {
    for (var i = -radio; i <= radio; i++) {
      final d = math.sqrt(i * i + j * j);
      if (d > radio) continue;
      if (d > radio - 2 && (mx + i + my + j).isOdd) continue;
      final clave = l.en(mx + 1 + i, my + 2 + j);
      final otra = const {'L': 'c', 's': 'h', 'D': 'a', 'N': 'N'}[clave];
      if (otra != null) l.punto(mx + 1 + i, my + 2 + j, otra);
    }
  }
  l.pegar(['NNN', 'NWN', 'NhN', 'NWN', 'NNN'], mx, my);
  if (fotograma == 1) {
    for (final (dx, dy) in [(-3, -3), (5, -3), (-3, 7), (5, 7)]) {
      l.punto(mx + dx, my + dy, 'h');
    }
  }
}

void _mesilla(LienzoPixel l, int x, int y) {
  l
    ..pegar(
      ['...NNNNNN...', '..NyyyyyYN..', '.NyyyyyyyYN.', 'NNNNNNNNNNNN', '.....NN.....', '....NooN....', '...NNNNNN...'],
      x + 1,
      y - 7,
    )
    ..caja(x, y, 14, 3, 'm')
    ..lineaH(x + 1, y + 1, 12, 'u')
    ..caja(x + 1, y + 3, 12, 22, 'm')
    ..marco(x + 3, y + 5, 8, 7, 't')
    ..marco(x + 3, y + 14, 8, 7, 't')
    ..punto(x + 7, y + 8, 'Y')
    ..punto(x + 7, y + 17, 'Y')
    ..sombraSuelo(x, y + 25, 14, filas: 1);
}

const _guitarra = [
  '...NN...',
  '..NKKN..',
  '..NKKN..',
  '...NN...',
  '...NN...',
  '...NN...',
  '...NN...',
  '...NN...',
  '...NN...',
  '...NN...',
  '...NN...',
  '..NooN..',
  '.NoooRN.',
  '.NoooRN.',
  '..NoRN..',
  '.NooooN.',
  'NoooNooN',
  'NooNNNoN',
  'NoooNooN',
  'NooooooN',
  'NoooooRN',
  'NoooooRN',
  '.NoooRN.',
  '..NNNN..',
  '........',
  '........',
  '........',
  '........',
  '........',
  '........',
  '........',
  '........',
];

void _escritorio(LienzoPixel l, int x, int y) {
  const ancho = 50;
  // Portátil abierto con la pantalla azul suave, libros, una taza y una planta.
  l
    ..caja(x + 6, y - 11, 18, 11, 'K')
    ..rect(x + 7, y - 10, 16, 8, 'a')
    ..lineaH(x + 8, y - 9, 6, 'c')
    ..lineaH(x + 8, y - 7, 10, 'c')
    ..lineaH(x + 8, y - 5, 4, 'c')
    ..caja(x + 3, y - 2, 24, 2, 'g')
    ..caja(x + 30, y - 4, 10, 2, 'A')
    ..caja(x + 31, y - 6, 9, 2, 'Y')
    ..pegar(taza, x + 42, y - 7)
    ..caja(x, y, ancho, 3, 'W')
    ..lineaH(x + 1, y + 2, ancho - 2, 'g')
    ..rect(x + 2, y + 3, 2, 17, 'K')
    ..rect(x + ancho - 4, y + 3, 2, 17, 'K')
    ..lineaV(x + 1, y + 3, 17, 'N')
    ..lineaV(x + 4, y + 3, 17, 'N')
    ..lineaV(x + ancho - 5, y + 3, 17, 'N')
    ..lineaV(x + ancho - 2, y + 3, 17, 'N')
    ..sombraSuelo(x, y + 20, ancho, filas: 1);
  // La silla, de espaldas.
  l
    ..redondo(x + 14, y + 1, 16, 12, 'r', contorno: 'N', radio: 2)
    ..lineaH(x + 16, y + 2, 12, 's')
    ..lineaV(x + 28, y + 3, 8, 'R')
    ..rect(x + 21, y + 13, 2, 6, 'K')
    ..caja(x + 15, y + 18, 14, 2, 'K')
    ..sombraSuelo(x + 15, y + 20, 14, filas: 1);
}

/// Guirnalda de lucecitas colgada de lado a lado; en cada fotograma se encienden unas u otras.
void _lucecitas(LienzoPixel l, int fotograma) {
  const colores = ['Y', 'r', 'v', 'a', 's'];
  for (var tramo = 0; tramo < 4; tramo++) {
    final x0 = tramo * 40, x1 = x0 + 40;
    for (var x = x0; x < x1; x++) {
      final t = (x - x0) / 40;
      final y = 3 + (4 * t * (1 - t) * 5).round();
      l.punto(x, y, 'K');
      if ((x - x0) % 7 == 3) {
        final n = x ~/ 7;
        final encendida = (n + fotograma).isEven;
        final color = colores[n % colores.length];
        l
          ..punto(x, y + 1, encendida ? 'y' : color)
          ..punto(x, y + 2, color);
        if (encendida) {
          l
            ..punto(x - 1, y + 1, color)
            ..punto(x + 1, y + 1, color);
        }
      }
    }
  }
}
