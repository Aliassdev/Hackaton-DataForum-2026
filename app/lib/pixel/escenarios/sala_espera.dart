import 'dart:math' as math;

import '../motor/motor.dart';
import 'escenario_pixel.dart';
import 'teselas.dart';

/// La sala de espera amable del juzgado: un mural con un arcoíris, banderines, una estantería baja con cuentos, una
/// pecera (el pez nada de un lado a otro), una mesita con ceras, una caja de juguetes, un puf y un suelo de puzle.
final escenarioSalaEspera = EscenarioPixel(
  lugar: 'sala_espera',
  descripcion:
      'La sala de espera del juzgado, pensada para niños y niñas: un mural con un arcoíris, cuentos, juegos, una '
      'pecera y una mesita para dibujar.',
  fondo: Sprite.animado('sala_espera', [
    _pintarSalaEspera(0),
    _pintarSalaEspera(1),
  ], animacion: const AnimacionPixel([PasoPixel(0, ms: 1600), PasoPixel(1, ms: 1600)])),
  puestos: const {'izquierda': (x: 40, y: 90), 'centro': (x: 82, y: 91), 'derecha': (x: 122, y: 90)},
);

const _suelo = 60;

List<String> _pintarSalaEspera(int fotograma) {
  final l = LienzoPixel(anchoFondo, altoFondo, 'P');
  _mural(l);
  l.zocalo(44, _suelo, color: 'h', sombra: 'c', luz: 'W', moldura: 'a', panel: 20, desfase: 6);
  _puzle(l, _suelo);
  l
    ..banderines(98, 160, 2)
    ..reloj(104, 13, aro: 'r');

  // Estantería baja con cuentos de cara y la pecera encima.
  _estanteriaCuentos(l, 116, 37);
  _pecera(l, 120, 22, fotograma);

  // Mesita con ceras y papeles, con dos taburetes, y la caja de juguetes.
  _mesita(l, 14, 56);
  _cajaJuguetes(l, 56, 52);
  // Un puf rojo junto a la estantería.
  l
    ..ovaloEn(146, 60, 16, 12, 'r', contorno: 'N')
    ..lineaH(149, 62, 8, 's')
    ..punto(148, 63, 's')
    ..cambiar(150, 67, 10, 4, {'r': 'R'})
    ..sombraSuelo(147, 72, 14, filas: 1);
  return l.filas;
}

/// Un mural pintado en la pared: sol, arcoíris, nubes, colinas y pájaros, sin contorno (es pintura, no un objeto).
void _mural(LienzoPixel l) {
  // Colinas al fondo, hasta el zócalo (que se pinta después y las corta).
  l
    ..ovaloEn(24, 33, 48, 26, 'V')
    ..ovaloEn(-12, 29, 48, 32, 'v')
    ..ovaloEn(62, 31, 50, 30, 'v');
  // Dos árboles de piruleta en las colinas.
  for (final (tx, ty) in [(8, 23), (96, 25)]) {
    l
      ..rect(tx + 3, ty + 6, 2, 4, 't')
      ..ovaloEn(tx, ty, 8, 8, 'V')
      ..ovaloEn(tx + 1, ty, 6, 6, 'v');
  }
  // El arcoíris: cuatro franjas de 2 píxeles.
  const cx = 50.0, cy = 40.0;
  const bandas = ['r', 'Y', 'v', 'a'];
  for (var y = 10; y < 40; y++) {
    for (var x = 18; x < 84; x++) {
      final d = math.sqrt((x + 0.5 - cx) * (x + 0.5 - cx) + (y + 0.5 - cy) * (y + 0.5 - cy));
      final banda = ((26 - d) / 2).floor();
      if (banda >= 0 && banda < bandas.length) l.punto(x, y, bandas[banda]);
    }
  }
  // Nubes en los pies del arcoíris.
  const nube = ['....WWWW......', '..WWWWWWWW....', '.WWWWWWWWWWWW.', 'WWWWWWWWWWWWWW', '.hhhhhhhhhhhh.'];
  l
    ..pegar(nube, 17, 34)
    ..pegar(nube, 70, 34);
  // Sol con rayos y tres pájaros.
  l
    ..ovaloEn(6, 6, 9, 9, 'Y')
    ..ovaloEn(7, 7, 5, 5, 'y');
  for (final (dx, dy) in [(4, -3), (4, 11), (-3, 4), (11, 4), (-1, -1), (9, -1), (-1, 9), (9, 9)]) {
    l.punto(6 + dx, 6 + dy, 'Y');
  }
  for (final (bx, by) in [(86, 12), (93, 9), (99, 14)]) {
    l
      ..punto(bx, by, 'K')
      ..punto(bx + 1, by + 1, 'K')
      ..punto(bx + 2, by, 'K');
  }
}

/// Suelo de puzle de goma: piezas grandes de colores suaves (sobre todo claras) que encajan con una lengüeta. Las filas
/// crecen hacia abajo para que las piezas parezcan cuadradas vistas desde arriba.
void _puzle(LienzoPixel l, int desde) {
  const colores = ['h', 'y', 'h', 's', 'h', 'c'];
  var y = desde;
  var h = 6;
  var fila = 0;
  while (y < altoFondo) {
    for (var x = -8 + fila * 5 % 11, n = 0; x < anchoFondo; x += 22, n++) {
      final color = colores[(n + fila * 3) % colores.length];
      l
        ..rect(x, y, 22, h, color)
        // La lengüeta: un saliente de cada pieza en la de su derecha.
        ..rect(x + 22, y + h ~/ 2 - 1, 2, 2, color);
    }
    l.lineaH(0, y, anchoFondo, 'W');
    y += h;
    h += 2;
    fila++;
  }
}

void _estanteriaCuentos(LienzoPixel l, int x, int y) {
  const ancho = 40;
  final alto = _suelo + 4 - y;
  l
    ..caja(x, y, ancho, alto, 'm')
    ..lineaH(x + 1, y + 1, ancho - 2, 'u')
    ..lineaV(x + 1, y + 1, alto - 2, 'u')
    ..rect(x + 2, y + 3, ancho - 4, 10, 't')
    ..rect(x + 2, y + 15, ancho - 4, 10, 't')
    ..lineaH(x + 1, y + 13, ancho - 2, 'u')
    ..lineaH(x + 1, y + 14, ancho - 2, 'm')
    ..lineaH(x + 1, y + 25, ancho - 2, 'u');
  // Cuentos de cara: portadas con un dibujo sencillo.
  l
    ..pegar(_cuento('A', 'Y', _estrella), x + 3, y + 4)
    ..pegar(_cuento('r', 'y', _corazon), x + 12, y + 5)
    ..pegar(_cuento('v', 'y', _solCuento), x + 21, y + 4)
    ..rect(x + 30, y + 6, 2, 7, 'L')
    ..rect(x + 32, y + 5, 2, 8, 'Y')
    ..rect(x + 34, y + 7, 2, 6, 'a')
    ..pegar(_cuento('Y', 'r', _corazon), x + 3, y + 16)
    ..pegar(_cuento('L', 'y', _estrella), x + 12, y + 17)
    ..pegar(_juego, x + 22, y + 18)
    ..sombraSuelo(x, y + alto, ancho, filas: 1);
}

/// Dibujos de las portadas de los cuentos (5 × 4; «d» es el dibujo).
const _estrella = ['..d..', '.ddd.', 'ddddd', '.d.d.'];
const _corazon = ['dd.dd', 'ddddd', '.ddd.', '..d..'];
const _solCuento = ['.ddd.', 'ddddd', 'ddddd', '.ddd.'];

/// Un cuento de cara de 8 × 9, de [color], con el [motivo] en [dibujo] y una etiqueta clara abajo (sin letras).
List<String> _cuento(String color, String dibujo, List<String> motivo) {
  final sombra = PaletaPixel.deClave(color)!.sombra!;
  String fila(String m) => 'N${m.replaceAll('d', dibujo).replaceAll('.', color)}${sombra}N';
  return [
    'NNNNNNNN',
    fila('.....'),
    for (final m in motivo) fila(m),
    'N${color}WWW$color${sombra}N',
    'N${sombra * 6}N',
    'NNNNNNNN',
  ];
}

/// Una caja de juego de mesa con un dado encima.
const _juego = [
  '......NNNN',
  '......NWNN',
  '......NNWN',
  'NNNNNNNNNN',
  'NrrrrrrrRN',
  'NrYYrAArRN',
  'NrYYrAArRN',
  'NRRRRRRRRN',
  'NNNNNNNNNN',
];

void _pecera(LienzoPixel l, int x, int y, int fotograma) {
  const ancho = 32, alto = 15;
  l
    ..caja(x, y, ancho, alto, 'c')
    ..rect(x + 1, y + 1, ancho - 2, 2, 'h')
    ..rect(x + 1, y + alto - 4, ancho - 2, 3, 'u')
    ..lineaH(x + 1, y + alto - 4, ancho - 2, 'o')
    // Algas.
    ..pegar(['.v..', 'vV.v', '.vVv', 'vVv.', '.Vv.', '.vV.'], x + 3, y + alto - 8)
    ..pegar(['v.', 'Vv', 'vV', '.V', 'vV'], x + ancho - 6, y + alto - 7)
    // Tapa.
    ..caja(x - 1, y - 2, ancho + 2, 3, 'K')
    ..lineaH(x, y - 1, ancho, 'G');
  // El pez nada: en un fotograma a la izquierda mirando a la derecha y en el otro un poco más allá.
  final px = x + (fotograma == 0 ? 9 : 15);
  final py = y + (fotograma == 0 ? 6 : 5);
  l
    ..pegar(['.NN.N', 'NYYNN', 'YNYYN', 'NYYNN', '.NN.N'], px, py)
    ..punto(px + 1, py + 2, 'N')
    ..punto(px + 2, py + 1, 'W');
  // Burbujas.
  final bx = fotograma == 0 ? px + 6 : px + 7;
  l
    ..punto(bx, py - 1, 'W')
    ..punto(bx + 1, py - 3, 'h')
    ..punto(bx, py - 5 + fotograma, 'W');
}

void _mesita(LienzoPixel l, int x, int y) {
  // Taburetes a los lados.
  for (final (tx, color) in [(x - 2, 'a'), (x + 30, 'r')]) {
    l
      ..caja(tx, y + 2, 8, 3, color)
      ..lineaH(tx + 1, y + 3, 6, PaletaPixel.deClave(color)!.sombra!)
      ..rect(tx + 1, y + 5, 1, 5, 'K')
      ..rect(tx + 6, y + 5, 1, 5, 'K');
  }
  l
    ..caja(x + 4, y, 26, 3, 'Y')
    ..lineaH(x + 5, y + 1, 24, 'y')
    ..lineaH(x + 5, y + 2, 24, 'o')
    ..rect(x + 6, y + 3, 2, 8, 'm')
    ..rect(x + 26, y + 3, 2, 8, 'm')
    ..lineaV(x + 5, y + 3, 8, 'N')
    ..lineaV(x + 8, y + 3, 8, 'N')
    ..lineaV(x + 25, y + 3, 8, 'N')
    ..lineaV(x + 28, y + 3, 8, 'N')
    ..sombraSuelo(x + 3, y + 11, 28, filas: 1)
    // Papeles con un dibujo y ceras.
    ..pegar(['WWWWWW', 'WrWWvW', 'WWWWWh'], x + 8, y - 2)
    ..pegar(['WWWWW', 'WaaWh'], x + 16, y - 1)
    ..lineaH(x + 22, y - 1, 3, 'A')
    ..lineaH(x + 23, y - 2, 3, 'v')
    ..lineaH(x + 6, y - 1, 2, 'r');
}

void _cajaJuguetes(LienzoPixel l, int x, int y) {
  // Lo que asoma: un balón, un osito y un cubo.
  l
    ..ovaloEn(x + 1, y - 6, 8, 8, 'r', contorno: 'N')
    ..lineaV(x + 4, y - 5, 6, 'W')
    ..lineaH(x + 2, y - 2, 6, 'W')
    ..pegar(['.NN..NN.', 'NooNNooN', 'NooooooN', 'NoNooNoN', 'NooNNooN', 'NootttoN'], x + 9, y - 6)
    ..caja(x + 15, y - 4, 5, 5, 'A')
    ..punto(x + 17, y - 2, 'Y');
  l
    ..caja(x, y, 20, 12, 'm')
    ..lineaH(x + 1, y + 1, 18, 'u')
    ..lineaH(x + 1, y + 6, 18, 't')
    ..lineaV(x + 18, y + 2, 9, 't')
    ..rect(x + 7, y + 3, 6, 2, 'Y')
    ..sombraSuelo(x, y + 12, 20, filas: 1);
}
