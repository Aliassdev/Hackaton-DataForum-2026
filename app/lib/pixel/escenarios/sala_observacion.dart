import '../motor/motor.dart';
import 'escenario_pixel.dart';
import 'teselas.dart';

/// La sala de observación: en la pared, una pantalla grande en la que se ve la Sala Gesell (el sofá rosa, el sillón
/// azul y dos figuritas); delante, una mesa larga con portátiles, carpetas, vasos de agua y un micrófono para pasarle
/// las preguntas a la psicóloga. La mesa tapa a quien se sienta detrás.
final escenarioSalaObservacion = EscenarioPixel(
  lugar: 'sala_observacion',
  descripcion:
      'La sala de observación: una pantalla grande en la que se ve la Sala Gesell y una mesa larga desde la que la '
      'jueza, la fiscal y los abogados siguen la entrevista.',
  fondo: Sprite('sala_observacion', _salaObservacion.fondo),
  delante: [piezaEn(Sprite('sala_observacion: mesa', _salaObservacion.mesa), _mesaX, _mesaY)],
  puestos: const {
    'abogada_victima': (x: 28, y: 70),
    'fiscal': (x: 54, y: 70),
    'jueza': (x: 80, y: 70),
    'abogado_defensa': (x: 106, y: 70),
    'letrada': (x: 132, y: 70),
    'izquierda': (x: 36, y: 92),
    'centro': (x: 80, y: 93),
    'derecha': (x: 124, y: 92),
  },
);

const _suelo = 58;
const _mesaX = 12;
const _mesaY = 53;

final _salaObservacion = _pintarSalaObservacion();

({List<String> fondo, List<String> mesa}) _pintarSalaObservacion() {
  final l = LienzoPixel(anchoFondo, altoFondo, 'c')
    ..rect(0, 0, anchoFondo, 2, 'a')
    ..zocalo(40, _suelo, color: 'a', sombra: 'A', luz: 'h', moldura: 'A', panel: 20, desfase: 8);
  // Suelo de madera oscura: la mesa, más clara, destaca encima.
  l.tablas(_suelo, madera: 't', junta: 'T', semilla: 37);

  // La pantalla grande con la Sala Gesell y dos altavoces.
  l
    ..pantalla(38, 4, 84, 32, _vistaGesell(80, 28))
    ..caja(28, 12, 7, 12, 'K')
    ..ovaloEn(29, 14, 5, 5, 'G')
    ..ovaloEn(29, 19, 5, 4, 'G')
    ..caja(125, 12, 7, 12, 'K')
    ..ovaloEn(126, 14, 5, 5, 'G')
    ..ovaloEn(126, 19, 5, 4, 'G')
    ..ventana(6, 8, 18, 22, hojas: 1, paisaje: PaisajePixel.arboles, semilla: 6)
    ..reloj(140, 8, aro: 'Y')
    ..apoyar(plantaAlta, 144, 60)
    ..sombraSuelo(146, 59, 9, filas: 1);

  // Las sillas, detrás de la mesa.
  for (final x in [28, 54, 80, 106, 132]) {
    l
      ..redondo(x - 7, 44, 14, 16, 'D', contorno: 'N', radio: 2)
      ..lineaH(x - 5, 45, 10, 'A')
      ..lineaV(x - 6, 47, 10, 'A');
  }

  final mesa = _dibujarMesa();
  l.pegar(mesa, _mesaX, _mesaY);
  return (fondo: l.filas, mesa: mesa);
}

/// Lo que se ve en la pantalla: la Sala Gesell en pequeño, con Lucía en el sofá y la psicóloga en el sillón.
List<String> _vistaGesell(int ancho, int alto) {
  final l = LienzoPixel(ancho, alto, 'p')
    ..mosaico(['pppppPp'], 0, 0, ancho, alto - 8)
    ..rect(0, alto - 8, ancho, 8, 'm')
    ..lineaH(0, alto - 8, ancho, 't')
    ..lineaH(0, alto - 4, ancho, 't')
    ..rect(0, alto - 11, ancho, 3, 'h')
    // Cuadro del mar.
    ..caja(26, 3, 14, 9, 'W')
    ..rect(27, 4, 12, 4, 'h')
    ..rect(27, 8, 12, 3, 'a')
    // Sofá rosa con la niña.
    ..redondo(18, alto - 17, 30, 11, 's', contorno: 'N', radio: 2)
    ..lineaH(21, alto - 16, 24, 'P')
    ..lineaH(20, alto - 9, 26, 'L')
    ..pegar(['.NNN.', 'NTTTN', 'N333N', '.N3N.', 'NYYYN', 'NYYYN'], 28, alto - 16)
    // Sillón azul con la psicóloga.
    ..redondo(54, alto - 16, 14, 10, 'a', contorno: 'N', radio: 2)
    ..lineaH(56, alto - 15, 10, 'h')
    ..pegar(['.NNN.', 'NzzzN', 'N555N', '.N5N.', 'NLLLN', 'NLLLN', 'NLLLN'], 58, alto - 18)
    // Lámpara.
    ..pegar(['.NNN.', 'NyyyN', 'NNNNN', '..K..', '..K..', '..K..', '..K..', '..K..', '..K..'], 48, alto - 21)
    // Indicador de «en directo»: un punto verde.
    ..ovaloEn(2, 2, 3, 3, 'v');
  return l.filas;
}

/// La mesa larga (136 × 20, el tablero en la fila 7) con portátiles, carpetas, vasos y el micrófono. Va encima de
/// quien se sienta detrás.
List<String> _dibujarMesa() {
  const ancho = 136;
  final l = LienzoPixel(ancho, 20)
    ..caja(0, 7, ancho, 3, 'm')
    ..lineaH(1, 8, ancho - 2, 'u')
    ..caja(2, 9, ancho - 4, 11, 'm')
    ..lineaH(3, 10, ancho - 6, 't')
    ..lineaV(ancho - 4, 10, 9, 't');
  for (var x = 6; x < ancho - 8; x += 26) {
    l.marco(x, 12, 22, 6, 't');
  }
  // Encima: portátiles (de espaldas), carpetas, vasos y el micrófono.
  for (final x in [10, 62, 114]) {
    l
      ..caja(x, 2, 14, 6, 'g')
      ..punto(x + 7, 4, 'h')
      ..lineaH(x - 1, 7, 16, 'G');
  }
  l
    ..caja(36, 5, 10, 3, 'A')
    ..lineaH(37, 6, 8, 'a')
    ..caja(90, 5, 11, 3, 'Y')
    ..lineaH(91, 6, 9, 'y')
    ..pegar(vaso, 30, 3)
    ..pegar(vaso, 104, 3)
    ..pegar(['.NN.', 'NKKN', '.NN.', '..K.', '..K.', '.KK.', 'NNNN'], 82, 1)
    ..pegar(['WWWWWW', 'WGGGGW', 'WWWWWh'], 48, 5);
  return l.filas;
}
