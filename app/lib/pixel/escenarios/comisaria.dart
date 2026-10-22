import '../motor/motor.dart';
import 'escenario_pixel.dart';
import 'teselas.dart';

/// Una comisaría amable: paredes blancas y azules, una placa con una estrella (sin escudos reales ni letras), una
/// ventana con persiana, un tablón con carteles de dibujos, sillas de espera, una fuente de agua, plantas y el
/// mostrador de atención. Nada de armas, rejas ni esposas. El mostrador tapa a quien atiende detrás (el puesto
/// «policia»).
final escenarioComisaria = EscenarioPixel(
  lugar: 'comisaria',
  descripcion:
      'Una comisaría: un mostrador de atención con una planta, sillas de espera, una fuente de agua y un tablón con '
      'carteles.',
  fondo: Sprite('comisaria', _comisaria.fondo),
  delante: [piezaEn(Sprite('comisaria: mostrador', _comisaria.mostrador), _mostradorX, _mostradorY)],
  puestos: const {
    'policia': (x: 126, y: 64),
    'izquierda': (x: 34, y: 90),
    'centro': (x: 76, y: 91),
    'derecha': (x: 118, y: 91),
  },
);

const _suelo = 60;
const _mostradorX = 94;
const _mostradorY = 37;

final _comisaria = _pintarComisaria();

({List<String> fondo, List<String> mostrador}) _pintarComisaria() {
  final l = LienzoPixel(anchoFondo, altoFondo, 'h')
    ..rect(0, 0, anchoFondo, 2, 'c')
    ..zocalo(36, _suelo, color: 'a', sombra: 'A', luz: 'c', moldura: 'A', panel: 20, desfase: 4)
    ..lineaH(0, 34, anchoFondo, 'A')
    ..lineaH(0, 35, anchoFondo, 'Y')
    ..baldosas(_suelo, clara: 'P', oscura: 'p', lado: 20, altoFila: 4, junta: 'p');

  // Tablón con carteles de dibujos: un corazón, un teléfono y dos manos.
  l.corcho(6, 9, 42, 22, [_cartelCorazon, _cartelTelefono, _cartelManos], semilla: 3);

  // Ventana con persiana y la fuente de agua debajo.
  l
    ..ventana(56, 8, 30, 24, paisaje: PaisajePixel.ciudad, semilla: 21)
    ..persiana(57, 9, 28, 7)
    ..pegar(_fuente, 64, 36)
    ..sombraSuelo(64, 63, 11, filas: 1);

  // Sillas de espera unidas.
  for (var x = 4; x < 46; x += 13) {
    l.silla(x, 46, color: 'A');
  }
  l
    ..lineaH(4, 58, 42, 'K')
    ..sombraSuelo(4, 62, 42, filas: 1)
    ..apoyar(plantaGrande, 86, 66)
    ..sombraSuelo(91, 64, 12, filas: 1);

  // La placa con la estrella, en la pared detrás del mostrador.
  l.pegar(_placa, 115, 6);

  final mostrador = _dibujarMostrador();
  l.pegar(mostrador, _mostradorX, _mostradorY);
  return (fondo: l.filas, mostrador: mostrador);
}

const _cartelCorazon = ['hhhhhhh', 'hrrhrrh', 'hrrrrrh', 'hrrrrrh', 'hhrrrhh', 'hhhrhhh', 'hhhhhhh'];

const _cartelTelefono = ['yyyyyyy', 'yNNNNNy', 'yNcccNy', 'yNcccNy', 'yNcccNy', 'yNNWNNy', 'yNNNNNy', 'yyyyyyy'];

const _cartelManos = ['WWWWWWW', 'W3W.W5W', '33WWW55', '333W555', 'W33W55W', 'WW3W5WW', 'WWWWWWW'];

const _fuente = [
  '..NNNNNNN..',
  '.NhhhhhhcN.',
  '.NhccccccN.',
  '.NhccccccN.',
  '.NhccccacN.',
  '.NhhhhhhcN.',
  '..NNNNNNN..',
  '.NWWWWWWWN.',
  '.NWNNWWWhN.',
  '.NWWWWWWhN.',
  '.NWWWWWWhN.',
  '.NWWWWWWhN.',
  '.NWWWWWWhN.',
  '.NWWWWWWhN.',
  '.NWWWWWWhN.',
  '.NWWWWWWhN.',
  '.NWWWWWWhN.',
  '.NWWWWWWhN.',
  '.NWWWWWWhN.',
  '.NWWWWWWhN.',
  '.NWWWWWWhN.',
  '.NWWWWWWhN.',
  '.NggggggGN.',
  '..NNNNNNN..',
  '...........',
  '...........',
  '...........',
];

/// La placa (26 × 26): un círculo azul con aro amarillo y una estrella.
const _placa = [
  '.........NNNNNNNN.........',
  '.......NNYYYYYYYYNN.......',
  '.....NNYYooooooooYYNN.....',
  '....NYYooAAAAAAAAooYYN....',
  '...NYooAAAAAAAAAAAAooYN...',
  '..NYoAAAAAAAYAAAAAAAAoYN..',
  '..NYoAAAAAAAYAAAAAAAAoYN..',
  '.NYoAAAAAAAYYYAAAAAAAAoYN.',
  '.NYoAAAAAAAYYYAAAAAAAAoYN.',
  'NYoAAAAAAAYYYYYAAAAAAAAoYN',
  'NYoAYYYYYYYYyYYYYYYYYAAoYN',
  'NYoAAYYYYYYyyyYYYYYYAAAoYN',
  'NYoAAAYYYYYyyyYYYYYAAAAoYN',
  'NYoAAAAYYYYYyYYYYYAAAAAoYN',
  'NYoAAAAAYYYYYYYYYAAAAAAoYN',
  'NYoAAAAAYYYYYYYYYAAAAAAoYN',
  'NYoAAAAYYYYYYYYYYYAAAAAoYN',
  '.NYoAAAYYYYAAAYYYYAAAAoYN.',
  '.NYoAAYYYAAAAAAAYYYAAAoYN.',
  '..NYoAYYAAAAAAAAAYYAAoYN..',
  '..NYoAAAAAAAAAAAAAAAAoYN..',
  '...NYooAAAAAAAAAAAAooYN...',
  '....NYYooAAAAAAAAooYYN....',
  '.....NNYYooooooooYYNN.....',
  '.......NNYYYYYYYYNN.......',
  '.........NNNNNNNN.........',
];

/// El mostrador (64 × 31, el tablero en la fila 12): frente azul con la estrella y tablero de madera; encima, una
/// pantalla de espaldas, un timbre y una planta pequeña.
List<String> _dibujarMostrador() {
  const ancho = 64, alto = 31, tablero = 12;
  final l = LienzoPixel(ancho, alto)
    ..caja(0, tablero, ancho, 3, 'm')
    ..lineaH(1, tablero + 1, ancho - 2, 'u')
    ..caja(1, tablero + 2, ancho - 2, alto - tablero - 2, 'A')
    ..lineaV(2, tablero + 3, alto - tablero - 5, 'a')
    ..lineaV(ancho - 3, tablero + 3, alto - tablero - 5, 'D')
    ..lineaH(2, alto - 3, ancho - 4, 'D')
    ..lineaH(2, tablero + 3, ancho - 4, 'D');
  // Una franja amarilla y la estrella en el centro del frente.
  l
    ..lineaH(2, tablero + 7, ancho - 4, 'Y')
    ..lineaH(2, tablero + 8, ancho - 4, 'o')
    ..pegar(
      ['....N....', '...NYN...', 'NNNYYYNNN', 'NYYYyYYYN', '.NYYYYYN.', '.NYYNYYN.', 'NYYN.NYYN', 'NNN...NNN'],
      27,
      tablero + 5,
    )
    // Pantalla de espaldas, timbre y planta.
    ..caja(6, 3, 16, 10, 'K')
    ..lineaH(7, 4, 14, 'G')
    ..pegar(['.NN.', 'NYYN', 'NNNN'], 40, tablero - 3)
    ..apoyar(plantaPequena, 50, tablero);
  return l.filas;
}
