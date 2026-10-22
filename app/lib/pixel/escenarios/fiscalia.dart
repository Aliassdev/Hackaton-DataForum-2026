import '../motor/motor.dart';
import 'escenario_pixel.dart';
import 'teselas.dart';

/// El despacho de la Fiscalía de Menores: estantería de libros de derecho, un diploma y un dibujo, una ventana con
/// persiana, un perchero con la toga y la mesa del fiscal con una pantalla, expedientes atados con cinta y una lámpara
/// verde. La mesa tapa a quien se sienta detrás (el puesto «fiscal»).
final escenarioFiscalia = EscenarioPixel(
  lugar: 'fiscalia',
  descripcion:
      'El despacho de la Fiscalía de Menores: una mesa con expedientes y una lámpara, una estantería con libros, una '
      'ventana y un perchero con la toga.',
  fondo: Sprite('fiscalia', _fiscalia.fondo),
  delante: [piezaEn(Sprite('fiscalia: mesa', _fiscalia.mesa), _mesaX, _mesaY)],
  puestos: const {
    'fiscal': (x: 102, y: 66),
    'izquierda': (x: 32, y: 90),
    'centro': (x: 66, y: 91),
    'derecha': (x: 138, y: 90),
  },
);

const _suelo = 60;
const _mesaX = 68;
const _mesaY = 42;

final _fiscalia = _pintarFiscalia();

({List<String> fondo, List<String> mesa}) _pintarFiscalia() {
  final l = LienzoPixel(anchoFondo, altoFondo, 'h')
    ..mosaico(['hhhhhhhhhc'], 0, 0, anchoFondo, 38)
    ..rect(0, 0, anchoFondo, 2, 'c')
    ..zocalo(38, _suelo, color: 'm', sombra: 't', luz: 'u', moldura: 't', panel: 20, desfase: 6);
  // Moqueta clara con alguna mota.
  l.rect(0, _suelo, anchoFondo, altoFondo - _suelo, 'g');
  final azar = AzarPixel(41);
  for (var k = 0; k < 80; k++) {
    l.punto(azar.entero(anchoFondo), _suelo + 2 + azar.entero(altoFondo - _suelo - 2), 'G');
  }
  l
    ..lineaH(0, _suelo, anchoFondo, 'G')
    ..lineaH(0, _suelo + 1, anchoFondo, 'G');

  // Estantería de libros de derecho, con lomos de colores serios y bandas doradas.
  l
    ..estanteria(4, 8, 38, 57, baldas: 5, madera: 'T', fondo: 'z', luz: 't', semilla: 4, colores: _lomos)
    ..sombraSuelo(3, 65, 40);

  // Un diploma y un dibujo de un niño, en la pared.
  l
    ..cuadro(52, 12, 20, 16, _diploma, color: 'o', luz: 'Y')
    ..pegar(['WWWWWWWW', 'WYWWWWWW', 'YYYWWWWW', 'WYWWWrrW', 'WWWWrrrW', 'WWWWWWWW', 'vvvvvvvv'], 76, 16)
    ..punto(79, 16, 'r');

  // Ventana con persiana.
  l
    ..ventana(122, 8, 32, 30, paisaje: PaisajePixel.ciudad, semilla: 14)
    ..persiana(123, 9, 30, 9);

  // Planta y archivador con carpetas y otra planta encima.
  l
    ..apoyar(plantaAlta, 46, 64)
    ..sombraSuelo(48, 63, 9, filas: 1);
  _archivador(l, 138, 42);

  // La silla del fiscal, detrás de la mesa.
  l
    ..redondo(94, 34, 16, 18, 'D', contorno: 'N', radio: 2)
    ..lineaH(96, 35, 12, 'A')
    ..lineaV(95, 37, 12, 'A');

  final mesa = _dibujarMesa();
  l.pegar(mesa, _mesaX, _mesaY);
  return (fondo: l.filas, mesa: mesa);
}

const _lomos = ['R', 'D', 'V', 'T', 'R', 'D', 'A', 'o'];

const _diploma = [
  'WWWWWWWWWWWWWWWW',
  'WWGGGGGGGGGGGGWW',
  'WWWWWWWWWWWWWWWW',
  'WWGGGGGGGGGGWWWW',
  'WWWWWWWWWWWWWWWW',
  'WWGGGGGGGGGGGWWW',
  'WWWWWWWWWWWWWrrW',
  'WWWWWWWWWWWWrrrr',
  'WWGGGGGWWWWWWrrW',
  'hhhhhhhhhhhhhRhR',
  'hhhhhhhhhhhhhhhh',
  'hhhhhhhhhhhhhhhh',
];

/// Un archivador metálico de tres cajones (16 × 24 desde ([x], [y])), con carpetas y una planta pequeña encima.
void _archivador(LienzoPixel l, int x, int y) {
  const ancho = 16, alto = 24;
  l
    ..caja(x, y, ancho, alto, 'g')
    ..lineaV(x + 1, y + 1, alto - 2, 'h')
    ..lineaV(x + ancho - 2, y + 1, alto - 2, 'G');
  for (var k = 0; k < 3; k++) {
    final cy = y + 1 + k * 7;
    l
      ..marco(x + 2, cy + 1, ancho - 4, 6, 'G')
      ..rect(x + 6, cy + 2, 4, 2, 'W')
      ..lineaH(x + 6, cy + 4, 4, 'K');
  }
  l
    ..sombraSuelo(x, y + alto, ancho, filas: 1)
    ..apoyar(['NNNNNNN', 'NYYYYoN', 'NNNNNNN', 'NaaaaAN', 'NNNNNNN'], x + 1, y)
    ..apoyar(plantaPequena, x + 7, y);
}

/// La mesa del fiscal (66 × 29, el tablero en la fila 10): madera oscura con cuarterones; encima, una pantalla de
/// espaldas, una pila de expedientes atados con cinta rosa, un bote de bolígrafos y una lámpara verde.
List<String> _dibujarMesa() {
  const ancho = 66, alto = 29, tablero = 10;
  final l = LienzoPixel(ancho, alto)
    ..caja(0, tablero, ancho, 3, 'T')
    ..lineaH(1, tablero + 1, ancho - 2, 't')
    ..caja(1, tablero + 2, ancho - 2, alto - tablero - 2, 'T')
    ..lineaV(ancho - 3, tablero + 3, alto - tablero - 4, 'z');
  for (final x in [4, 24, 44]) {
    l
      ..marco(x, tablero + 5, 17, alto - tablero - 8, 'z')
      ..lineaH(x + 1, alto - 4, 16, 't');
  }
  // La pantalla, de espaldas.
  l
    ..caja(4, 0, 18, 11, 'K')
    ..lineaH(5, 1, 16, 'G')
    ..rect(11, 9, 4, 2, 'K');
  // Expedientes atados con cinta.
  for (var k = 0; k < 4; k++) {
    final y = tablero - 2 - k * 2;
    final color = k.isEven ? 'p' : 'o';
    l
      ..caja(42 - (k.isOdd ? 1 : 0), y, 14, 3, color)
      ..punto(48, y + 1, 's')
      ..punto(48 - (k.isOdd ? 1 : 0), y, 's');
  }
  l
    ..lineaV(48, tablero - 8, 9, 's')
    ..pegar(['.s.s.', 'ss.ss'], 46, tablero - 9)
    // Bote de bolígrafos.
    ..pegar(['A.r', 'NNN', 'NgN', 'NgN'], 34, tablero - 4)
    // Lámpara verde de despacho.
    ..pegar(
      ['.NNNNNNN.', 'NvvvvvvVN', 'NVVVVVVVN', '.NNNNNNN.', '....NoN..', '....NoN..', '..NNNNNN.'],
      56,
      tablero - 7,
    );
  return l.filas;
}
