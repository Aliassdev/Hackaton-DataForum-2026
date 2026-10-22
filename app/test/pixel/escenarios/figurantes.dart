// Figurantes para probar los puestos de los fondos en las capturas: no son los personajes del juego (esos los dibuja
// otro equipo). Son el chico y la adulta de muestra del motor (test/pixel/motor/muestras.dart), copiados aquí para no
// depender de sus pruebas, y recoloreados: togas, uniforme, ropa gris neutra…
import 'package:tuturno/pixel/motor/motor.dart';

const _nino = [
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

const _adulta = [
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

final nino = Sprite('niño', _nino);
final adulta = Sprite('adulta', _adulta);

/// Una adulta con toga negra y puñetas blancas, con otra piel y otro pelo.
Sprite toga(String nombre, {String piel = '2', String pelo = 'b'}) => adulta.recolorear({
  'L': 'z',
  'D': 'N',
  'K': 'z',
  ...PaletaPixel.cambio(PaletaPixel.piel2, PaletaPixel.deClave(piel)!),
  ...PaletaPixel.cambio(PaletaPixel.canoso, PaletaPixel.deClave(pelo)!),
}, nombre: nombre);

final jueza = toga('jueza', piel: '4', pelo: 'z');
final fiscal = toga('fiscal', piel: '2', pelo: 'T');
final abogadaVictima = toga('abogada', piel: '5', pelo: 'z');
final abogadoDefensa = toga('abogado', piel: '1', pelo: 'u');
final letrada = toga('letrada', piel: '3', pelo: 'f');

/// Uniforme azul marino con camisa azul clara.
final policia = adulta.recolorear({
  'L': 'D',
  'D': 'N',
  'W': 'a',
  ...PaletaPixel.cambio(PaletaPixel.piel2, PaletaPixel.piel4),
  ...PaletaPixel.cambio(PaletaPixel.canoso, PaletaPixel.negro),
}, nombre: 'policía');

/// La persona investigada: una figura neutra, en gris.
final investigada = adulta.recolorear({
  'L': 'G',
  'D': 'K',
  'W': 'g',
  ...PaletaPixel.cambio(PaletaPixel.canoso, PaletaPixel.castano),
}, nombre: 'persona investigada');

final publico = adulta.recolorear({
  'L': 'v',
  'D': 'V',
  'W': 'y',
  ...PaletaPixel.cambio(PaletaPixel.piel2, PaletaPixel.piel6),
}, nombre: 'público');

final nina = nino.recolorear({
  ...PaletaPixel.cambio(PaletaPixel.piel3, PaletaPixel.piel5),
  ...PaletaPixel.cambio(PaletaPixel.castanoClaro, PaletaPixel.negro),
  ...PaletaPixel.cambio(PaletaPixel.amarillo, PaletaPixel.coral),
  'm': 'K',
  'y': 'r',
}, nombre: 'niña');

final tia = adulta.recolorear({
  'L': 'A',
  'D': 'D',
  ...PaletaPixel.cambio(PaletaPixel.piel2, PaletaPixel.piel3),
  ...PaletaPixel.cambio(PaletaPixel.canoso, PaletaPixel.pelirrojo),
}, nombre: 'tía');
