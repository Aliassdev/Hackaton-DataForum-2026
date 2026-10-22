import '../motor/motor.dart';
import 'escenario_pixel.dart';
import 'teselas.dart';

/// Un aula de primaria: pizarra verde con dibujos de tiza, ventana, corcho con dibujos de los niños, la mesa de la
/// tutora con un globo terráqueo y dos pupitres mirando a la pizarra.
final escenarioColegio = EscenarioPixel(
  lugar: 'colegio',
  descripcion:
      'Un aula del colegio: una pizarra verde con dibujos de tiza, la mesa de la tutora, pupitres y un corcho con '
      'dibujos.',
  fondo: Sprite('colegio', _pintarColegio()),
  puestos: const {'izquierda': (x: 42, y: 89), 'centro': (x: 80, y: 91), 'derecha': (x: 120, y: 89)},
);

const _suelo = 60;

List<String> _pintarColegio() {
  final l = LienzoPixel(anchoFondo, altoFondo, 'h')
    ..lineaH(0, 0, anchoFondo, 'c')
    ..zocalo(44, _suelo, color: 'Y', sombra: 'o', luz: 'y', moldura: 'o', panel: 16, desfase: 4)
    ..baldosas(_suelo, clara: 'h', oscura: 'c', lado: 10, altoFila: 3)
    ..luzEnSuelo(8, 34, _suelo + 1, 90, {'c': 'h', 'h': 'W'});

  l.ventana(6, 9, 30, 28, sol: true, semilla: 8);
  _pizarra(l, 46, 8, 68, 30);
  l
    ..corcho(122, 15, 34, 25, [_dibujoSol, _dibujoCorazon, _dibujoCasa])
    ..reloj(134, 3, aro: 'A');

  _mesaTutora(l, 8, 49);
  _pupitre(l, 100, 52, 'r');
  _pupitre(l, 130, 52, 'a');
  // Una mochila amarilla apoyada en el suelo.
  l
    ..pegar(_mochila, 151, 60)
    ..sombraSuelo(150, 70, 9, filas: 1);
  return l.filas;
}

void _pizarra(LienzoPixel l, int x, int y, int ancho, int alto) {
  l
    ..caja(x - 2, y - 2, ancho + 4, alto + 4, 'm')
    ..lineaH(x - 1, y - 1, ancho + 2, 'u')
    ..lineaV(x - 1, y - 1, alto + 2, 'u')
    ..rect(x, y, ancho, alto, 'V')
    ..lineaH(x, y, ancho, 'N')
    ..lineaV(x, y, alto, 'N');
  // Dibujos de tiza: un sol, una casa con su árbol, una flor y un arcoíris.
  l
    ..pegar(_tizaSol, x + 4, y + 3)
    ..pegar(_tizaCasa, x + 18, y + 10)
    ..pegar(_tizaFlor, x + 34, y + 15)
    ..pegar(_tizaArcoiris, x + 44, y + 5);
  // Bandeja con tizas y borrador.
  l
    ..caja(x - 4, y + alto + 1, ancho + 8, 3, 'm')
    ..lineaH(x - 3, y + alto + 1, ancho + 6, 'u')
    ..lineaH(x + 8, y + alto, 3, 'W')
    ..lineaH(x + 13, y + alto, 2, 'Y')
    ..lineaH(x + 17, y + alto, 2, 's')
    ..caja(x + ancho - 14, y + alto - 1, 7, 3, 'K')
    ..lineaH(x + ancho - 13, y + alto - 1, 5, 'm');
}

const _tizaSol = [
  '..y..y..y..',
  '...y.y.y...',
  '.y..yyy..y.',
  '..yyWWWyy..',
  'yyyWWWWWyyy',
  '..yyWWWyy..',
  '.y..yyy..y.',
  '...y.y.y...',
  '..y..y..y..',
];

const _tizaCasa = [
  '......WW...........',
  '.....WWWW.....hhh..',
  '....WW..WW...hhhhh.',
  '...WW....WW.hhhhhhh',
  '..WW......WW.hhhhh.',
  '.WWWWWWWWWWWW.hhh..',
  '..W........W...W...',
  '..W.WW..ss.W...W...',
  '..W.WW..ss.W...W...',
  '..W.....ss.W...W...',
  '..WWWWWWWWWW...W...',
];

const _tizaFlor = ['.s.s.', 'ssyss', '.sss.', '..h..', '.hh..', '..h..'];

const _tizaArcoiris = [
  '.....ssssssssss.....',
  '...ssyyyyyyyyyyss...',
  '..syyccccccccccyys..',
  '.syccWWWWWWWWWWccys.',
  'syccWW........WWccys',
  'sycWW..........WWcys',
  'sycW............Wcys',
  'sycW............Wcys',
  'WWWW............WWWW',
  'WWW..............WWW',
];

const _dibujoSol = ['WWWWWWW', 'WYWWWWW', 'YYYWWWW', 'WYWWWWW', 'WWWWWWW', 'WWWrWWW', 'WWrrrWW', 'vvvvvvv'];

const _dibujoCorazon = ['yyyyyyy', 'yrryrry', 'yrrrrry', 'yrrrrry', 'yyrrryy', 'yyyryyy', 'yyyyyyy'];

const _dibujoCasa = ['hhhhhhh', 'hhhRhhh', 'hhRRRhh', 'hRRRRRh', 'hhPPPhh', 'hhPAPhh', 'hhPAPhh', 'vvvvvvv'];

/// La mesa de la tutora (40 × 17) con libros, un bote de lápices, una manzana y un globo terráqueo.
void _mesaTutora(LienzoPixel l, int x, int y) {
  // El tablero y el frente, con dos cajones.
  l
    ..caja(x, y, 40, 4, 'm')
    ..lineaH(x + 1, y + 1, 38, 'u')
    ..caja(x + 1, y + 3, 38, 14, 'm')
    ..lineaV(x + 37, y + 4, 12, 't')
    ..marco(x + 25, y + 5, 11, 5, 't')
    ..marco(x + 25, y + 11, 11, 5, 't')
    ..lineaH(x + 29, y + 7, 3, 'Y')
    ..lineaH(x + 29, y + 13, 3, 'Y')
    ..marco(x + 3, y + 5, 19, 11, 't')
    ..sombraSuelo(x, y + 17, 40);
  // Encima: una pila de libros, lápices, una manzana y el globo.
  l
    ..apoyar(_pilaLibros, x + 2, y)
    ..apoyar(['r.Y.a', 'NNNNN', 'NccaN', 'NccaN'], x + 13, y)
    ..apoyar(['..V..', '.NvN.', 'NrrrN', 'NrrRN', '.NNN.'], x + 20, y)
    ..apoyar(_globo, x + 28, y);
}

const _pilaLibros = ['NNNNNNNN.', 'NvvvvvvVN', 'NNNNNNNNN', '.NrrrrrRN', 'NNNNNNNNN', 'NAAAAAADN', 'NNNNNNNNN'];

const _globo = [
  '...NNNN..',
  '..NaavvN.',
  '.NavvvaAN',
  '.NaavaaAN',
  '.NvaaavAN',
  '..NavaAN.',
  '...NNNN..',
  '....NoN..',
  '...NooN..',
  '..NNNNNN.',
  '..NooooN.',
  '..NNNNNN.',
];

/// Un pupitre visto desde atrás: la mesa y, delante, la silla de [color] que mira a la pizarra.
void _pupitre(LienzoPixel l, int x, int y, String color) {
  final sombra = PaletaPixel.deClave(color)!.sombra!;
  l
    ..caja(x, y, 24, 3, 'm')
    ..lineaH(x + 1, y + 1, 22, 'u')
    ..rect(x + 1, y + 3, 2, 10, 'K')
    ..rect(x + 21, y + 3, 2, 10, 'K')
    ..lineaV(x, y + 3, 10, 'N')
    ..lineaV(x + 3, y + 3, 10, 'N')
    ..lineaV(x + 20, y + 3, 10, 'N')
    ..lineaV(x + 23, y + 3, 10, 'N')
    ..sombraSuelo(x, y + 13, 24, filas: 1)
    // La silla, de espaldas.
    ..redondo(x + 6, y + 2, 12, 8, color, contorno: 'N')
    ..lineaH(x + 8, y + 3, 7, luzDe(color))
    ..lineaV(x + 16, y + 3, 5, sombra)
    ..lineaV(x + 8, y + 10, 5, 'K')
    ..lineaV(x + 15, y + 10, 5, 'K')
    ..caja(x + 6, y + 10, 12, 2, sombra)
    ..sombraSuelo(x + 6, y + 15, 12, filas: 1);
}

const _mochila = [
  '..NNNN..',
  '.NYYYYN.',
  'NYyYYYoN',
  'NYYYYYoN',
  'NNNNNNNN',
  'NYYooYoN',
  'NYYooYoN',
  'NYYYYYoN',
  'NoooooNN',
  '.NNNNNN.',
];
