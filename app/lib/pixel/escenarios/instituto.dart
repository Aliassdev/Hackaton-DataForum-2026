import '../motor/motor.dart';
import 'escenario_pixel.dart';
import 'teselas.dart';

/// Un pasillo del instituto: taquillas azules y amarillas, ventanas altas, un corcho con carteles y la puerta del
/// despacho de bienestar, con un corazón en el cristal.
final escenarioInstituto = EscenarioPixel(
  lugar: 'instituto',
  descripcion:
      'Un pasillo del instituto: taquillas azules y amarillas, un corcho con carteles y la puerta del despacho de la '
      'coordinadora de bienestar.',
  fondo: Sprite('instituto', _pintarInstituto()),
  puestos: const {'izquierda': (x: 36, y: 90), 'centro': (x: 80, y: 91), 'derecha': (x: 124, y: 90)},
);

const _suelo = 62;

List<String> _pintarInstituto() {
  final l = LienzoPixel(anchoFondo, altoFondo, 'P')
    ..rect(0, 0, anchoFondo, 3, 'p')
    ..rect(0, 38, anchoFondo, _suelo - 38, 'h')
    ..lineaH(0, 37, anchoFondo, 'a')
    ..lineaH(0, 38, anchoFondo, 'c')
    ..rodapie(_suelo - 3, color: 'c', luz: 'W', linea: 'a')
    ..baldosas(_suelo, clara: 'h', oscura: 'g', lado: 14, altoFila: 3);

  // Ventanas altas sobre las taquillas.
  l
    ..ventana(4, 5, 48, 14, hojas: 3, paisaje: PaisajePixel.arboles, alfeizar: false, semilla: 5)
    ..ventana(134, 5, 30, 14, hojas: 2, paisaje: PaisajePixel.arboles, alfeizar: false, semilla: 9);

  _taquillas(l, 0, 22, ['A', 'A', 'Y', 'A', 'A', 'Y']);
  _taquillas(l, 134, 22, ['Y', 'A', 'A']);

  // Corcho con carteles: un corazón, una nota musical y un balón.
  l.corcho(62, 11, 38, 26, [_cartelCorazon, _cartelMusica, _cartelBalon], semilla: 6);

  // La puerta del despacho de bienestar, con un corazón en el cristal.
  l
    ..puerta(108, 20, 18, _suelo - 20, color: 'a', jamba: 'W', pomo: 'Y')
    ..pegar(['.rr.rr.', 'rrrrrrr', '.rrrrr.', '..rrr..', '...r...'], 113, 25);

  // Los contenedores de reciclaje (amarillo, azul y verde) y una planta.
  for (final (i, color) in ['Y', 'A', 'v'].indexed) {
    l.apoyar(_contenedor(color), 76 + i * 9, 64);
  }
  l
    ..sombraSuelo(76, 63, 27, filas: 1)
    ..apoyar(plantaAlta, 60, 64)
    ..sombraSuelo(62, 63, 9, filas: 1);

  // Un banco delante de las taquillas, con una mochila.
  l
    ..caja(6, 52, 40, 3, 'm')
    ..lineaH(7, 53, 38, 'u')
    ..caja(6, 55, 40, 2, 'm');
  for (final px in [9, 41]) {
    l
      ..rect(px, 57, 2, 7, 'K')
      ..lineaV(px - 1, 57, 7, 'N')
      ..lineaV(px + 2, 57, 7, 'N');
  }
  l
    ..sombraSuelo(6, 64, 40, filas: 1)
    ..apoyar(_mochila, 30, 52);
  return l.filas;
}

/// Una fila de taquillas de 9 × 40 (comparten el contorno) desde ([x], [y]), una por color.
void _taquillas(LienzoPixel l, int x, int y, List<String> colores) {
  const alto = _suelo - 22 + 1;
  for (final (i, color) in colores.indexed) {
    final tx = x + i * 9;
    final sombra = PaletaPixel.deClave(color)!.sombra!;
    final luz = color == 'Y' ? 'y' : 'a';
    l
      ..caja(tx, y, 10, alto, color)
      ..lineaV(tx + 1, y + 1, alto - 2, luz)
      ..lineaV(tx + 8, y + 1, alto - 2, sombra)
      // Rejilla de ventilación, placa y tirador.
      ..lineaH(tx + 3, y + 3, 4, sombra)
      ..lineaH(tx + 3, y + 5, 4, sombra)
      ..lineaH(tx + 3, y + 7, 4, sombra)
      ..rect(tx + 3, y + 10, 4, 2, 'W')
      ..rect(tx + 6, y + 19, 1, 4, 'g')
      ..punto(tx + 6, y + 22, 'G')
      ..lineaH(tx + 3, y + alto - 8, 4, sombra)
      ..lineaH(tx + 3, y + alto - 6, 4, sombra);
  }
  // Zócalo de las taquillas.
  l
    ..rect(x, y + alto - 1, colores.length * 9 + 1, 2, 'K')
    ..lineaH(x, y + alto + 1, colores.length * 9 + 1, 'N');
}

const _cartelCorazon = ['sssssss', 'srrsrrs', 'srrrrrs', 'srrrrrs', 'ssrrrss', 'sssrsss', 'sssssss', 'sssssss'];

const _cartelMusica = ['ccccccc', 'ccNNNNc', 'ccNccNc', 'ccNccNc', 'NNNcNNN', 'NNNcNNN', 'ccccccc', 'ccccccc'];

const _cartelBalon = ['yyyyyyy', 'yyNNNyy', 'yNWNWNy', 'yNNWNNy', 'yNWNWNy', 'yyNNNyy', 'yyyyyyy', 'vvvvvvv'];

/// Un contenedor de reciclaje pequeño (8 × 12) de [color], con tapa y una flecha circular clara (sin letras).
List<String> _contenedor(String color) {
  final sombra = PaletaPixel.deClave(color)!.sombra!;
  final luz = color == 'Y' ? 'y' : (color == 'A' ? 'a' : 'W');
  return [
    'NNNNNNNN',
    'N${color * 5}${sombra}N',
    'NNNNNNNN',
    '.N$color$color$color$color${sombra}N',
    '.N$color$luz$luz$color${sombra}N',
    '.N$luz$color$color$luz${sombra}N',
    '.N$luz$color$color$luz${sombra}N',
    '.N$color$luz$luz$color${sombra}N',
    '.N$color$color$color$color${sombra}N',
    '.N$color$color$color$color${sombra}N',
    '.N$sombra$sombra$sombra$sombra${sombra}N',
    '.NNNNNNN',
  ];
}

const _mochila = ['..NNNN..', '.NrrrrN.', 'NrsrrrRN', 'NNNNNNNN', 'NrrRRrRN', 'NrrRRrRN', 'NRRRRRRN', '.NNNNNN.'];
