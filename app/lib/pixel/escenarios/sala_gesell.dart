import '../motor/motor.dart';
import 'escenario_pixel.dart';
import 'teselas.dart';

/// La Sala Gesell: una sala acogedora con un sofá rosa, un sillón azul, una mesa baja con papeles, ceras y un vaso de
/// agua, una lámpara encendida, un cuadro del mar, una estantería con juguetes y, arriba en la esquina, una cámara
/// pequeña.
final escenarioSalaGesell = EscenarioPixel(
  lugar: 'sala_gesell',
  descripcion:
      'La Sala Gesell: una sala acogedora con un sofá, un sillón, una mesa baja con papeles y ceras, juguetes y una '
      'cámara pequeña arriba, en una esquina.',
  fondo: Sprite('sala_gesell', _pintarSalaGesell()),
  puestos: const {
    'izquierda': (x: 44, y: 89),
    'centro': (x: 82, y: 91),
    'derecha': (x: 124, y: 89),
    'sofa': (x: 60, y: 88),
    'sillon': (x: 126, y: 87),
  },
);

const _suelo = 60;

List<String> _pintarSalaGesell() {
  final l = LienzoPixel(anchoFondo, altoFondo, 'p')
    ..mosaico(['ppppppPp'], 0, 0, anchoFondo, 44)
    ..zocalo(44, _suelo, color: 'h', sombra: 'c', luz: 'W', moldura: 'c', panel: 20, desfase: 1)
    ..tablas(_suelo, semilla: 17);

  // Alfombra redonda bajo la mesa.
  l
    ..ovaloEn(28, 68, 104, 22, 'L')
    ..ovaloEn(31, 69, 98, 20, 's')
    ..ovaloEn(40, 72, 80, 14, 'P');

  // Cuadro del mar con un velero, encima del sofá.
  l.cuadro(54, 10, 32, 22, _mar(28, 18), color: 'W', luz: 'W');

  // Sofá rosa (con sombras lila) y sillón azul.
  l
    ..sofa(34, 37, ancho: 56, color: 's', luz: 'P', sombra: 'L', cojines: ['Y', 'a'])
    ..pegar(_sillon, 108, 40);

  // Lámpara de pie entre los dos, encendida.
  l
    ..resplandor(98, 22, 7, {'p': 'P', 'P': 'W', 'h': 'W', 'c': 'h'})
    ..pegar(pantallaLampara, 92, 16)
    ..lineaV(97, 22, 41, 'N')
    ..lineaV(98, 22, 41, 'K')
    ..caja(94, 62, 9, 3, 'K')
    ..lineaH(95, 63, 7, 'G')
    ..sombraSuelo(93, 65, 10, filas: 1);

  // Estantería baja con juguetes y una planta.
  _estanteJuguetes(l, 4, 36);

  // Mesa baja con papeles, ceras y un vaso de agua.
  _mesaBaja(l, 86, 66);

  // La cámara pequeña, arriba en la esquina, mirando al sofá: oscura y con su lucecita roja, para que se vea (el texto
  // de la escena la nombra).
  l.pegar(camaraPared, 144, 3);
  return l.filas;
}

List<String> _mar(int ancho, int alto) {
  final l = LienzoPixel(ancho, alto, 'h')
    ..rect(0, alto ~/ 2, ancho, alto, 'a')
    ..rect(0, alto ~/ 2 + 3, ancho, alto, 'A')
    ..lineaH(0, alto ~/ 2, ancho, 'c')
    ..ovaloEn(ancho - 9, 2, 6, 6, 'Y')
    // Olas.
    ..lineaH(2, alto ~/ 2 + 5, 3, 'c')
    ..lineaH(12, alto ~/ 2 + 6, 4, 'c')
    ..lineaH(20, alto ~/ 2 + 4, 3, 'c')
    // Velero.
    ..pegar(['..W...', '..WW..', '..WWW.', '..WWWW', 'RRRRRR', '.RRRR.'], 8, alto ~/ 2 - 5);
  return l.filas;
}

const _sillon = [
  '...NNNNNNNNNNNNNNNNNN...',
  '..NaaaaaaaaaaaaaaaaaaN..',
  '..NahhhhhhhhhhhhhhhhaN..',
  '..NahaaaaaaaaaaaaaaaAN..',
  '..NahaaaaaaaaaaaaaaaAN..',
  '..NahaaaaaaaaaaaaaaaAN..',
  'NNNNhaaaaaaaaaaaaaaaANNN',
  'NhaaNaaaaaaaaaaaaaaANaaN',
  'NhaaNaaaaaaaaaaaaaaANaAN',
  'NhaaNaaaaaaaaaaaaaaANaAN',
  'NhaaNNNNNNNNNNNNNNNNNaAN',
  'NhaaNhhhhhhhhhhhhhhaNaAN',
  'NhaaNaaaaaaaaaaaaaaANaAN',
  'NhaaNAAAAAAAAAAAAAAANaAN',
  'NhaaNNNNNNNNNNNNNNNNNaAN',
  'NhaaaaaaaaaaaaaaaaaaaaAN',
  'NhaaaaaaaaaaaaaaaaaaaaAN',
  'NAAAAAAAAAAAAAAAAAAAAAAN',
  'NNNNNNNNNNNNNNNNNNNNNNNN',
  '..NTN..............NTN..',
  '..NNN..............NNN..',
];

void _estanteJuguetes(LienzoPixel l, int x, int y) {
  const ancho = 26;
  final alto = _suelo + 4 - y;
  l
    ..caja(x, y, ancho, alto, 'P')
    ..lineaV(x + ancho - 2, y + 1, alto - 2, 'p')
    ..rect(x + 2, y + 3, ancho - 4, 10, 'h')
    ..rect(x + 2, y + 15, ancho - 4, 10, 'h')
    ..lineaH(x + 1, y + 13, ancho - 2, 'P')
    ..lineaH(x + 1, y + 14, ancho - 2, 'p')
    ..lineaH(x + 1, y + 25, ancho - 2, 'p')
    // Un osito, una pelota y unos cubos.
    ..pegar(
      ['.NN..NN.', 'NooNNooN', 'NooooooN', 'NoNooNoN', 'NooWWooN', 'NootttoN', '.NooooN.', 'NooNNooN', '.NN..NN.'],
      x + 3,
      y + 4,
    )
    ..ovaloEn(x + 14, y + 7, 7, 7, 'Y', contorno: 'N')
    ..lineaV(x + 17, y + 8, 5, 'r')
    ..caja(x + 3, y + 20, 5, 5, 'A')
    ..caja(x + 8, y + 20, 5, 5, 'r')
    ..caja(x + 5, y + 16, 5, 5, 'v')
    ..pegar(_libros, x + 15, y + 16)
    ..apoyar(plantaPequena, x + 8, y)
    ..sombraSuelo(x, y + alto, ancho, filas: 1);
}

const _libros = ['.Ya.r.', 'NYaNrN', 'NYaNrN', 'NYaNrN', 'NYaNrN', 'NoANRN', 'NNNNNN', '......', '......'];

void _mesaBaja(LienzoPixel l, int x, int y) {
  l
    ..pegar(['WWWWWWW', 'WWrrWWW', 'WWWWvvW', 'WWWWWWh'], x + 3, y - 3)
    ..lineaH(x + 12, y - 1, 3, 'A')
    ..lineaH(x + 13, y - 2, 3, 'Y')
    ..pegar(vaso, x + 19, y - 5)
    ..ovaloEn(x, y, 28, 6, 'm', contorno: 'N')
    ..lineaH(x + 4, y + 1, 18, 'u')
    ..rect(x + 4, y + 5, 2, 6, 'T')
    ..rect(x + 22, y + 5, 2, 6, 'T')
    ..lineaV(x + 3, y + 5, 6, 'N')
    ..lineaV(x + 6, y + 5, 6, 'N')
    ..lineaV(x + 21, y + 5, 6, 'N')
    ..lineaV(x + 24, y + 5, 6, 'N')
    ..sombraSuelo(x + 2, y + 11, 24, filas: 1);
}
