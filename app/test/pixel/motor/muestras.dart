// Dibujos de muestra para las pruebas y las capturas del motor. No son los personajes del juego: sirven para ver
// que el motor pinta bien y como ejemplo de la guía (contorno azul noche de 1 píxel, luz de arriba a la izquierda).
import 'package:tuturno/pixel/motor/motor.dart';

/// Chico o chica de 24 × 32: pelo castaño claro (t, sombra T, brillo m), piel 3 (sombra 4), sudadera amarilla (Y,
/// sombra o, luz y), vaqueros (A, sombra D, luz a).
const chicoQuieto = [
  '........NNNNNNNN........',
  '......NNmmmmttttNN......',
  '.....NmmttttttttTTN.....',
  '....NmtttttTttttttTN....',
  '...NmttttttTtttttTTTN...',
  '...NtttttttTTttttttTN...',
  '...NttttttT33TtttttTN...',
  '...NttttT333333TttTTN...',
  '...NttT3333333333TTTN...',
  '...NtT33WN3333WN34TTN...',
  '...Nt333NN3333NN334TN...',
  '...Nt33s33333333s34TN...',
  '....N333333RR333334N....',
  '.....NN3333333344NN.....',
  '.......NNN4444NNN.......',
  '......NyYYo44oYYoN......',
  '.....NyYYYYooYYYYoN.....',
  '....NyYYYYYYYYYYYooN....',
  '....NYNYYYYYYYYYoNoN....',
  '....NYNYYYYYYYYYoNoN....',
  '....NoNYYYYYYYYYoNoN....',
  '....N3NYYYYYYYYYoN4N....',
  '.....NNooooooooooNN.....',
  '......NAAAAAAAAADN......',
  '......NAAAAAAAAADN......',
  '......NaAAANNaAADN......',
  '......NaADN..NaADN......',
  '......NaADN..NaADN......',
  '......NaADN..NaADN......',
  '.....NWWWgN..NWWWgN.....',
  '.....NNNNNN..NNNNNN.....',
  '......xxxxxxxxxxxx......',
];

/// Respira: la cabeza y los hombros bajan un píxel (sobra una fila del cuerpo, que es igual que la de debajo).
final chicoRespira = ['........................', ...chicoQuieto.sublist(0, 18), ...chicoQuieto.sublist(19)];

/// Parpadea: los ojos se quedan en una raya.
final chicoParpadea = retocar(chicoQuieto, {9: '...NtT333333333334TTN...'});

final chico = Sprite.animado('chico', [chicoQuieto, chicoRespira, chicoParpadea], animacion: AnimacionPixel.reposo());

/// Adulta de 24 × 36 (más alta que el chico): moño canoso (b, sombra G), piel 2, rebeca lila (L, sombra D) con blusa
/// blanca y pantalón gris oscuro.
const adultaQuieta = [
  '..........NNNN..........',
  '.........NbbbGN.........',
  '........NNbbGGNN........',
  '......NNbbbbbbbbNN......',
  '.....NbbbbbbbbbbGGN.....',
  '.....NbbbbbbbbbbbGN.....',
  '.....NbbG2222222GGN.....',
  '.....NbG222222222GN.....',
  '.....Nb2222222223GN.....',
  '.....Nb2WN2222WN3GN.....',
  '.....N22NN2222NN33N.....',
  '.....N2s2222222s23N.....',
  '......N2222RR2223N......',
  '.......NN222233NN.......',
  '........NN3333NN........',
  '......NNLLW33WLLNN......',
  '.....NLLLLWWWWLLDDN.....',
  '....NLLLLLWWWWLLLDDN....',
  '....NLNLLLWWWWLLDNDN....',
  '....NLNLLLWWWWLLDNDN....',
  '....NLNLLLWWWWLLDNDN....',
  '....NLNLLLWWWWLLDNDN....',
  '....NLNLLLWWWWLLDNDN....',
  '....NDNLLLWWWWLLDNDN....',
  '....N2NLLLLWWLLLDN3N....',
  '.....NNDDDDDDDDDDNN.....',
  '......NKKKKKKKKKKN......',
  '......NKKKKNNKKKKN......',
  '......NKKKN..NKKKN......',
  '......NKKKN..NKKKN......',
  '......NKKKN..NKKKN......',
  '......NKKKN..NKKKN......',
  '......NKKKN..NKKKN......',
  '.....NRRRRN..NRRRRN.....',
  '.....NNNNNN..NNNNNN.....',
  '......xxxxxxxxxxxx......',
];

final adulta = Sprite.animado(
  'adulta',
  [
    adultaQuieta,
    ['........................', ...adultaQuieta.sublist(0, 18), ...adultaQuieta.sublist(19)],
    retocar(adultaQuieta, {9: '.....Nb2222222223GN.....'}),
  ],
  // Un poco más despacio que el chico: no respiran a la vez.
  animacion: AnimacionPixel.reposo(ms: 950),
);

/// Bocadillo de «…» que flota sobre quien se puede tocar. El ancla es la punta de abajo.
final bocadillo = Sprite.animado(
  'bocadillo',
  [
    [
      '..NNNNNNN..',
      '.NWWWWWWWN.',
      'NWWWWWWWWhN',
      'NWNWWNWWNhN',
      'NWWWWWWWWhN',
      '.NhhhhhhhN.',
      '..NNNWNNN..',
      '....NWN....',
      '.....N.....',
    ],
  ],
  animacion: AnimacionPixel.balanceo(),
  ancla: (x: 5, y: 9),
);

/// Variantes del chico con [Sprite.recolorear]: piel, pelo y ropa.
final variantes = <Sprite>[
  chico.recolorear({
    ...PaletaPixel.cambio(PaletaPixel.piel3, PaletaPixel.piel1),
    ...PaletaPixel.cambio(PaletaPixel.castanoClaro, PaletaPixel.rubio),
    'm': 'y',
  }, nombre: 'rubia'),
  chico.recolorear({
    ...PaletaPixel.cambio(PaletaPixel.piel3, PaletaPixel.piel2),
    ...PaletaPixel.cambio(PaletaPixel.castanoClaro, PaletaPixel.pelirrojo),
    ...PaletaPixel.cambio(PaletaPixel.amarillo, PaletaPixel.verde),
    'm': 'o',
    'y': 'v',
  }, nombre: 'pelirrojo'),
  chico.recolorear({
    ...PaletaPixel.cambio(PaletaPixel.piel3, PaletaPixel.piel4),
    ...PaletaPixel.cambio(PaletaPixel.castanoClaro, PaletaPixel.negro),
    'm': 'K',
    'Y': 'L',
    'o': 'D',
    'y': 'L',
  }, nombre: 'lila'),
  chico.recolorear({
    ...PaletaPixel.cambio(PaletaPixel.piel3, PaletaPixel.piel5),
    ...PaletaPixel.cambio(PaletaPixel.castanoClaro, PaletaPixel.negro),
    ...PaletaPixel.cambio(PaletaPixel.amarillo, PaletaPixel.coral),
    'm': 'K',
    'y': 'r',
  }, nombre: 'coral'),
  chico.recolorear({
    ...PaletaPixel.cambio(PaletaPixel.piel3, PaletaPixel.piel6),
    ...PaletaPixel.cambio(PaletaPixel.castanoClaro, PaletaPixel.castano),
    ...PaletaPixel.cambio(PaletaPixel.amarillo, PaletaPixel.azul),
    'm': 't',
    'y': 'a',
    'A': 'K',
    'a': 'G',
    'D': 'N',
  }, nombre: 'azul'),
];

/// Sala de espera de 160 × 96 pintada con [LienzoPixel]: pared azul a rayas, zócalo amarillo, suelo de madera,
/// ventana, tablón de anuncios, reloj, banco y una planta. El suelo empieza en la fila [sueloSala].
const sueloSala = 62;

final sala = Sprite('sala', _pintarSala());

List<String> _pintarSala() {
  final l = LienzoPixel(160, 96, 'h');
  // Pared: papel pintado a rayas y zócalo amarillo con cuarterones bajo una moldura.
  l.mosaico(['hhhhhhPh'], 0, 0, 160, 44);
  l.rect(0, 46, 160, sueloSala - 46, 'y');
  for (var x = 0; x < 160; x += 20) {
    l.marco(x + 2, 49, 16, 10, 'Y');
  }
  l
    ..lineaH(0, 44, 160, 'W')
    ..lineaH(0, 45, 160, 'o')
    ..lineaH(0, 46, 160, 't');
  // Suelo de tablas de madera, con las juntas al tresbolillo.
  l
    ..rect(0, sueloSala, 160, 96 - sueloSala, 'm')
    ..lineaH(0, sueloSala, 160, 'N')
    ..lineaH(0, sueloSala + 1, 160, 't');
  for (var y = sueloSala + 8; y < 96; y += 8) {
    l.lineaH(0, y, 160, 't');
  }
  var tabla = 0;
  for (var y = sueloSala + 2; y < 96; y += 8, tabla++) {
    for (var x = (tabla * 23) % 40; x < 160; x += 40) {
      l.lineaV(x, y, 6, 't');
    }
  }
  // Ventana con cielo, una nube y el sol.
  const vx = 14, vy = 8, vw = 44, vh = 30;
  l
    ..rect(vx, vy, vw, vh, 'c')
    ..rect(vx + 1, vy + 1, vw - 2, 9, 'h')
    ..marco(vx, vy, vw, vh, 'N')
    ..marco(vx + 1, vy + 1, vw - 2, vh - 2, 'W')
    ..lineaV(vx + vw ~/ 2, vy + 1, vh - 2, 'W')
    ..lineaV(vx + vw ~/ 2 - 1, vy + 1, vh - 2, 'N')
    ..lineaV(vx + vw ~/ 2 + 1, vy + 1, vh - 2, 'N')
    ..pegar(['...WWW....', '.WWhhWWW..', 'WWhhhhWWWW', '.hhhhhhhh.'], vx + 5, vy + 12)
    ..pegar(['..yy..', '.yYYy.', 'yYYYYy', 'yYYYYy', '.yYYy.', '..yy..'], vx + 30, vy + 5)
    ..lineaH(vx - 2, vy + vh, vw + 4, 'N')
    ..lineaH(vx - 1, vy + vh - 1, vw + 2, 'W');
  // Tablón de anuncios con tres papeles.
  const tx = 72, ty = 12;
  l
    ..rect(tx, ty, 34, 24, 'o')
    ..marco(tx, ty, 34, 24, 'N')
    ..marco(tx + 1, ty + 1, 32, 22, 't')
    ..rect(tx + 4, ty + 4, 9, 11, 'W')
    ..lineaH(tx + 5, ty + 6, 6, 'G')
    ..lineaH(tx + 5, ty + 8, 7, 'G')
    ..lineaH(tx + 5, ty + 10, 5, 'G')
    ..punto(tx + 8, ty + 4, 'r')
    ..rect(tx + 15, ty + 6, 8, 8, 'Y')
    ..lineaH(tx + 16, ty + 8, 5, 'o')
    ..lineaH(tx + 16, ty + 10, 6, 'o')
    ..punto(tx + 18, ty + 6, 'A')
    ..rect(tx + 25, ty + 4, 6, 12, 'a')
    ..lineaH(tx + 26, ty + 6, 4, 'h')
    ..lineaH(tx + 26, ty + 8, 4, 'h')
    ..punto(tx + 27, ty + 4, 'Y');
  // Reloj.
  l.pegar(['..NNNN..', '.NWWWWN.', 'NWWNWWhN', 'NWWNWWhN', 'NWWNNNhN', 'NWWWWWhN', '.NhhhhN.', '..NNNN..'], 124, 12);
  // Banco azul contra la pared.
  const bx = 104, by = 48;
  l
    ..rect(bx, by, 46, 4, 'A')
    ..lineaH(bx, by, 46, 'a')
    ..marco(bx - 1, by - 1, 48, 6, 'N')
    ..rect(bx, by + 6, 46, 3, 'A')
    ..lineaH(bx, by + 8, 46, 'D')
    ..marco(bx - 1, by + 5, 48, 5, 'N');
  for (final x in [bx + 2, bx + 42]) {
    l
      ..rect(x, by + 10, 2, 5, 'K')
      ..lineaV(x - 1, by + 10, 5, 'N')
      ..lineaV(x + 2, by + 10, 5, 'N');
  }
  // Planta en maceta.
  l.pegar(
    [
      '....NN.NN...',
      '...NvvNvVN..',
      '..NvvvNvvVN.',
      '.NvVvvvNvVN.',
      '.NvvVvNvvvVN',
      'NvvvVNvVvVN.',
      '.NvVVvvVVN..',
      '..NNVVVVN...',
      '...NNNNNN...',
      '...NRRRRRN..',
      '...NrrrrRN..',
      '....NrrRN...',
      '....NrrRN...',
      '....NNNNN...',
    ],
    2,
    48,
  );
  return l.filas;
}

/// La escena de muestra: la adulta, el chico (resaltado, con el bocadillo encima) y una amiga, en la sala.
List<ElementoEscena> elementosSala({bool resaltarChico = true}) => [
  ElementoEscena(sprite: adulta, x: 40, y: 88, id: 'adulta', etiqueta: 'La orientadora'),
  ElementoEscena(sprite: variantes[3], x: 128, y: 90, id: 'amiga', etiqueta: 'Tu amiga', espejo: true),
  ElementoEscena(sprite: chico, x: 84, y: 93, id: 'chico', etiqueta: 'Tú', resaltado: resaltarChico),
  ElementoEscena(sprite: bocadillo, x: 84, y: 57),
];
