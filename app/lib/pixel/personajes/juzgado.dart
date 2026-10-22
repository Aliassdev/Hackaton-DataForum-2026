part of 'personajes.dart';

// El juzgado: la jueza, el fiscal, las abogadas, la letrada, la policía, la persona investigada y el testigo.

/// La jueza: media melena canosa con raya a un lado, toga negra con puñetas blancas (los vuelillos de los magistrados,
/// Reglamento 2/2005 del CGPJ, art. 34.2) y la camisa blanca en el cuello. Sin placa ni medalla: son distintivos
/// oficiales y no se dibujan (tema-justicia, §2).
const _juezaFilas = <String>[
  '........................',
  '........NNNNNNNN........',
  '......NNWbbbbbbbNN......',
  '.....NWbbbbbbbbbbGN.....',
  '....NbbbbbbbbbbbbbGN....',
  '....NbbbbbbbbbbbbbGN....',
  '....NbbG33333bbbbbGN....',
  '....NbG33333333bbbGN....',
  '....NbG3333333334bGN....',
  '....NbG3WN3333WN4bGN....',
  '....NbG3NN3333NN4bGN....',
  '....NbGs3333333s4bGN....',
  '....NbG3333RR3334bGN....',
  '....NbGN33333344NbGN....',
  '.....NN.NN4444NN.NN.....',
  '......NNzWW44WWzNN......',
  '.....NKzzzWWWWzzzzN.....',
  '....NKzzzzzWWzzzzzzN....',
  '....NKNzzzzzzzzzzNzN....',
  '....NKNzzzzzzzzzzNzN....',
  '....NKNzzzzzzzzzzNzN....',
  '...NKzNzzzzzzzzzzNzzN...',
  '...NKzNzzzzzzzzzzNzzN...',
  '...NWWNzzzzzzzzzzNWWN...',
  '....N3NzzzzzzzzzzN4N....',
  '.....NNKzKzzzzNzzNN.....',
  '......NKzKzzzzNzzN......',
  '.....NKzzKzzzzNzzzN.....',
  '.....NKzzKzzzzNzzzN.....',
  '.....NKzzKzzzzNzzzN.....',
  '....NKzzzKzzzzNzzzzN....',
  '....NKzzzKzzzzNzzzzN....',
  '....NNNNNNNNNNNNNNNN....',
  '......NgKKN..NgKKN......',
  '......NNNNN..NNNNN......',
  '....xxxxxxxxxxxxxxxx....',
];

final _fichaJueza = PersonajePixel(
  id: 'jueza',
  nombre: 'La jueza',
  descripcion: 'La jueza, con toga negra y puñetas blancas',
  sprite: _personaje('jueza', filas: _juezaFilas, ojos: 9, pecho: 22, piel: '3', ms: 980),
);

/// El fiscal: alto, pelo castaño peinado con raya, gafas redondas plateadas, toga con puñetas, corbata azul y una
/// carpeta azul cielo en la mano.
const _fiscalFilas = <String>[
  '........NNNNNNNN........',
  '......NNttTTTTTTNN......',
  '.....NttTTTTTTTTzzN.....',
  '.....NtTTTTTTTTTTzN.....',
  '.....NTTTzTTTTTTTTN.....',
  '.....NTT2222TTTTTTN.....',
  '.....NT222222222TTN.....',
  '.....NT2222222223TN.....',
  '.....NT2gg2222gg3TN.....',
  '....N2TgWNggggWNgT3N....',
  '....N32gNNg22gNNg33N....',
  '.....N2sgg2222ggs3N.....',
  '......N2222RR2223N......',
  '.......NN222233NN.......',
  '........NN3333NN........',
  '......NNzWW33WWzNN......',
  '.....NKzzzWAAWzzzzN.....',
  '....NKzzzzWAAWzzzzzN....',
  '....NKNzzzzAAzzzzNzN....',
  '....NKNzzzzDDzzzzNzN....',
  '....NKNzzzzzzzzzzNzN....',
  '...NKzNzzzzzzzzzzNzzN...',
  '...NKzNzzzzzzzzzzNzzN...',
  '...NWWNzzzzzzzzzzNWWN...',
  '....N2NzzzzzzzzzzN3N....',
  '.....NNKzKzzzzNzzNNNNN..',
  '......NKzKzzzzNzzNhcaN..',
  '.....NKzzKzzzzNzzNWcaN..',
  '.....NKzzKzzzzNzzNhcaN..',
  '.....NKzzKzzzzNzzNaaaN..',
  '....NKzzzKzzzzNzzNNNNN..',
  '....NKzzzKzzzzNzzzzN....',
  '....NNNNNNNNNNNNNNNN....',
  '......NgKKN..NgKKN......',
  '......NNNNN..NNNNN......',
  '....xxxxxxxxxxxxxxxx....',
];

final _fichaFiscal = PersonajePixel(
  id: 'fiscal',
  nombre: 'El fiscal',
  descripcion: 'El fiscal, con toga, gafas y una carpeta',
  sprite: _personaje('fiscal', filas: _fiscalFilas, ojos: 9, pecho: 22, piel: '2', ms: 840),
);

/// El mismo fiscal en su despacho de la Fiscalía de Menores, sin toga (la toga solo se lleva en audiencia pública y en
/// los actos solemnes, LOPJ, art. 187.1): traje gris oscuro con dos botones, camisa blanca, la misma corbata azul y la
/// carpeta azul cielo en la mano.
const _fiscalDespachoFilas = <String>[
  '........NNNNNNNN........',
  '......NNttTTTTTTNN......',
  '.....NttTTTTTTTTzzN.....',
  '.....NtTTTTTTTTTTzN.....',
  '.....NTTTzTTTTTTTTN.....',
  '.....NTT2222TTTTTTN.....',
  '.....NT222222222TTN.....',
  '.....NT2222222223TN.....',
  '.....NT2gg2222gg3TN.....',
  '....N2TgWNggggWNgT3N....',
  '....N32gNNg22gNNg33N....',
  '.....N2sgg2222ggs3N.....',
  '......N2222RR2223N......',
  '.......NN222233NN.......',
  '........NN3333NN........',
  '......NNKWW33WWKNN......',
  '.....NGKKGWAAWGKKKN.....',
  '....NGKKKKGAAGKKKKKN....',
  '....NGNKKKKAAKKKKNKN....',
  '....NGNKKKKDDKKKKNKN....',
  '....NGNKKKKKKKKKKNKN....',
  '...NGKNKKKKGKKKKKNKKN...',
  '...NGKNKKKKKKKKKKNKKN...',
  '...NKKNKKKKGKKKKKNKKN...',
  '....N2NKKKKKKKKKKN3N....',
  '.....NNKKKKKKKKKKNNNNN..',
  '......NGKKKNNGKKKNhcaN..',
  '......NGKKN..NGKKNWcaN..',
  '......NGKKN..NGKKNhcaN..',
  '......NGKKN..NGKKNaaaN..',
  '......NGKKN..NGKKNNNNN..',
  '......NGKKN..NGKKN......',
  '......NGKKN..NGKKN......',
  '.....NKzzzN..NKzzzN.....',
  '.....NNNNNN..NNNNNN.....',
  '......xxxxxxxxxxxx......',
];

final _fichaFiscalDespacho = PersonajePixel(
  id: 'fiscal-despacho',
  nombre: 'El fiscal',
  descripcion: 'El fiscal en su despacho, con traje gris, gafas y una carpeta',
  sprite: _personaje('fiscal-despacho', filas: _fiscalDespachoFilas, ojos: 9, pecho: 22, piel: '2', ms: 840),
);

/// La abogada de la víctima: pelo natural negro y voluminoso, toga sin puñetas y una carpeta amarilla contra el pecho.
const _abogadaVictimaFilas = <String>[
  '.......NNNNNNNNNN.......',
  '.....NNKKzzzzzKzzNN.....',
  '....NKKzzzzzzzzzzzzN....',
  '...NKzzzzKzzzzzzKzzzN...',
  '..NKzzzzzzzzzzzzzzzzzN..',
  '..NzzKzzzzzzzzzzzKzzzN..',
  '..NzzzzzzzzzzzzzzzzzzN..',
  '..Nzzzz5555555555zzzzN..',
  '..Nzzz555555555556zzzN..',
  '..Nzzz55WN5555WN56zzzN..',
  '..Nzzz55NN5555NN66zzzN..',
  '..NzzK5R55555555R6KzzN..',
  '..NzzzN5555RR5556NzzzN..',
  '...NzzzN55555566NzzzN...',
  '....NNNNNN6666NNNNNN....',
  '......NNzWW66WWzNN......',
  '.....NKzzzWWWWzzzzN.....',
  '....NKzzzzzWWzzzzzzN....',
  '....NKNzzzzzzzzzzNzN....',
  '....NKNzNNNNNNNNzNzN....',
  '....NKN5NyYYYYoN6NzN....',
  '....NKNzNYWWWYoNzNzN....',
  '....NzNzNYYYYYoNzNzN....',
  '.....NNzNooooooNzNN.....',
  '......NzNNNNNNNNzN......',
  '......NKzKzzzzNzzN......',
  '......NKzKzzzzNzzN......',
  '.....NKzzKzzzzNzzzN.....',
  '.....NKzzKzzzzNzzzN.....',
  '.....NKzzKzzzzNzzzN.....',
  '....NKzzzKzzzzNzzzzN....',
  '....NKzzzKzzzzNzzzzN....',
  '....NNNNNNNNNNNNNNNN....',
  '......NRRRN..NRRRN......',
  '......NNNNN..NNNNN......',
  '....xxxxxxxxxxxxxxxx....',
];

final _fichaAbogadaVictima = PersonajePixel(
  id: 'abogada-victima',
  nombre: 'La abogada de la víctima',
  descripcion: 'La abogada de la víctima, con toga y una carpeta amarilla',
  sprite: _personaje('abogada-victima', filas: _abogadaVictimaFilas, ojos: 9, pecho: 18, piel: '5', ms: 900),
);

/// La misma abogada fuera de la sala (en la Fiscalía, por ejemplo), sin toga: la toga solo se lleva en estrados
/// (Reglamento 2/2005 del CGPJ, art. 33). Chaqueta azul sobre una blusa blanca, pantalón marino y la carpeta amarilla en
/// la mano. El cuerpo es el del traje del fiscal en su despacho.
final _abogadaDespachoFilas = <String>[
  ..._abogadaVictimaFilas.sublist(0, 15),
  for (final (i, fila) in _fiscalDespachoFilas.sublist(15).indexed)
    _cambiarClaves(
      fila,
      i < 11
          // Chaqueta azul con sus brillos; la corbata del fiscal pasa a ser la blusa, y las manos, de su piel.
          ? const {'K': 'A', 'G': 'a', 'A': 'W', 'D': 'W', '2': '5', '3': '6'}
          // Pantalón marino y la carpeta amarilla.
          : const {'K': 'D', 'G': 'A', 'h': 'y', 'c': 'Y', 'a': 'o', 'W': 'y'},
    ),
];

final _fichaAbogadaDespacho = PersonajePixel(
  id: 'abogada-despacho',
  nombre: 'La abogada',
  descripcion: 'La abogada de la víctima fuera de la sala, sin toga: chaqueta azul y una carpeta amarilla',
  sprite: _personaje('abogada-despacho', filas: _abogadaDespachoFilas, ojos: 9, pecho: 22, piel: '5', ms: 900),
);

/// El abogado defensor: pelo y barba corta canosos, toga sin puñetas, corbata coral y un maletín de piel en la mano.
const _abogadoDefensaFilas = <String>[
  '........................',
  '........NNNNNNNN........',
  '......NNWbbbbbbbNN......',
  '.....NWbbbbbbbbbbGN.....',
  '.....NbbbbbbbbbbbGN.....',
  '.....Nbb44444444bGN.....',
  '.....Nb4444444444GN.....',
  '.....Nb4GG4444GG5GN.....',
  '.....Nb4444444445GN.....',
  '....N4b4WN4444WN5G5N....',
  '....N544NN4444NN555N....',
  '.....Nb444bbbb455bN.....',
  '.....Nbbb44RR44bGGN.....',
  '......NbbbbbbbbbGN......',
  '.......NNbbbbGGNN.......',
  '.....NNzzWWWWWWzzNN.....',
  '....NKzzzWWrrWWzzzzN....',
  '....NKzzzzWrrWzzzzzN....',
  '....NKNzzzzrrzzzzNzN....',
  '....NKNzzzzRRzzzzNzN....',
  '....NKNzzzzzzzzzzNzN....',
  '...NKzNzzzzzzzzzzNzzN...',
  '...NKzNzzzzzzzzzzNzzN...',
  '...NKzNzzzzzzzzzzNzzN...',
  '....N4NzzzzzzzzzzN5N....',
  '..NNNNNNNKzzzzNzzNN.....',
  '..NmmgmmNKzzzzNzzN......',
  '..NmmmmtNKzzzzNzzzN.....',
  '..NmmmmtNKzzzzNzzzN.....',
  '..NtttttNKzzzzNzzzN.....',
  '..NNNNNNNKzzzzNzzzzN....',
  '....NKzzzKzzzzNzzzzN....',
  '....NNNNNNNNNNNNNNNN....',
  '......NgKKN..NgKKN......',
  '......NNNNN..NNNNN......',
  '....xxxxxxxxxxxxxxxx....',
];

final _fichaAbogadoDefensa = PersonajePixel(
  id: 'abogado-defensa',
  nombre: 'El abogado defensor',
  descripcion: 'El abogado defensor, con toga, barba canosa y un maletín',
  sprite: _personaje('abogado-defensa', filas: _abogadoDefensaFilas, ojos: 9, pecho: 22, piel: '4', ms: 960),
);

/// La letrada de la Administración de Justicia: pelo rubio corto, toga con puñetas y el portátil cerrado contra el
/// pecho (graba y guarda lo que pasa en la sala).
const _letradaFilas = <String>[
  '........................',
  '........NNNNNNNN........',
  '......NNyyuuuuuuNN......',
  '.....NyyuuuuuuuuuoN.....',
  '.....NyuuuuuuuuuuoN.....',
  '.....Nuuuuuuu111uoN.....',
  '.....Nuuu11111111oN.....',
  '.....Nu1111111112oN.....',
  '.....Nu1111111112oN.....',
  '....N1u1WN1111WN2o2N....',
  '....N211NN1111NN222N....',
  '.....N1s11111111s2N.....',
  '......N1111RR1112N......',
  '.......NN111122NN.......',
  '........NN2222NN........',
  '......NNzWW22WWzNN......',
  '.....NKzzzWWWWzzzzN.....',
  '....NKzzzzzWWzzzzzzN....',
  '....NKNzzzzzzzzzzNzN....',
  '....NKNzNNNNNNNNzNzN....',
  '....NWN1NhhccccN2NWN....',
  '.....NNzNhccccaNzNN.....',
  '......NzNccccaaNzN......',
  '......NKNNNNNNNNzN......',
  '......NKzKzzzzNzzN......',
  '......NKzKzzzzNzzN......',
  '.....NKzzKzzzzNzzzN.....',
  '.....NKzzKzzzzNzzzN.....',
  '.....NKzzKzzzzNzzzN.....',
  '.....NKzzKzzzzNzzzN.....',
  '....NKzzzKzzzzNzzzzN....',
  '....NKzzzKzzzzNzzzzN....',
  '....NNNNNNNNNNNNNNNN....',
  '......NRRRN..NRRRN......',
  '......NNNNN..NNNNN......',
  '....xxxxxxxxxxxxxxxx....',
];

final _fichaLetrada = PersonajePixel(
  id: 'letrada',
  nombre: 'La letrada de la Administración de Justicia',
  descripcion: 'La letrada de la Administración de Justicia, con toga y un portátil',
  sprite: _personaje('letrada', filas: _letradaFilas, ojos: 9, pecho: 18, piel: '1', ms: 870),
);

/// El policía: gorra azul marino con la placa amarilla, uniforme azul marino con cuello azul cielo, la placa en el
/// pecho y cinturón. Sin armas.
const _policiaFilas = <String>[
  '........NNNNNNNN........',
  '......NNaDDDDDDDNN......',
  '.....NaDDDDYYDDDDDN.....',
  '.....NaDDDDooDDDDDN.....',
  '....NNNNNNNNNNNNNNNN....',
  '....NKzzzzzzzzzzzzzN....',
  '.....Nzz66666666zzN.....',
  '.....Nz6666666667zN.....',
  '.....Nz6666666667zN.....',
  '....N6z6WN6666WN7z7N....',
  '....N766NN6666NN777N....',
  '.....N6R66666666R7N.....',
  '......N6666RR6667N......',
  '.......NN666677NN.......',
  '........NN7777NN........',
  '......NNDDc77cDDNN......',
  '.....NADDDccccDDDDN.....',
  '....NADDDDDccDDDDDDN....',
  '....NANDDDDDDDYDDNDN....',
  '....NANDDDDDDDoDDNDN....',
  '....NANDDDDDDDDDDNDN....',
  '....NANDDDDDDDDDDNDN....',
  '....NDNDDDDDDDDDDNDN....',
  '....N6NKKKKggKKKKN7N....',
  '.....NNADDDDDDDDDNN.....',
  '......NADDDDDDDDDN......',
  '......NADDDNNADDDN......',
  '......NADDN..NADDN......',
  '......NADDN..NADDN......',
  '......NADDN..NADDN......',
  '......NADDN..NADDN......',
  '......NADDN..NADDN......',
  '......NADDN..NADDN......',
  '.....NKzzzN..NKzzzN.....',
  '.....NNNNNN..NNNNNN.....',
  '......xxxxxxxxxxxx......',
];

final _fichaPolicia = PersonajePixel(
  id: 'policia',
  nombre: 'El policía',
  descripcion: 'El policía, con uniforme azul y gorra',
  sprite: _personaje('policia', filas: _policiaFilas, ojos: 9, pecho: 21, piel: '6', ms: 800),
);

/// La persona investigada: una figura neutra, sin rasgos de enfado ni de miedo. Pelo corto castaño claro, jersey gris
/// claro y pantalón gris oscuro.
const _investigadaFilas = <String>[
  '........................',
  '........NNNNNNNN........',
  '......NNmmttttttNN......',
  '.....NmtttttttttTTN.....',
  '.....NttttttttttTTN.....',
  '.....NtttttttttttTN.....',
  '.....Ntt33t333333TN.....',
  '.....Nt3333333334TN.....',
  '.....Nt3333333334TN.....',
  '....N3t3WN3333WN4T4N....',
  '....N433NN3333NN444N....',
  '.....N333333333344N.....',
  '......N3333RR3334N......',
  '.......NN333344NN.......',
  '........NN4444NN........',
  '......NNggg44gggNN......',
  '.....NWggggggggggGN.....',
  '....NWggggggggggggGN....',
  '....NWNgggggggggGNGN....',
  '....NWNgggggggggGNGN....',
  '....NgNgggggggggGNGN....',
  '....NgNgggggggggGNGN....',
  '....NgNgggggggggGNGN....',
  '....N3NgggggggggGN4N....',
  '.....NNGGGGGGGGGGNN.....',
  '......NGKKKKKKKKKN......',
  '......NGKKKNNGKKKN......',
  '......NGKKN..NGKKN......',
  '......NGKKN..NGKKN......',
  '......NGKKN..NGKKN......',
  '......NGKKN..NGKKN......',
  '......NGKKN..NGKKN......',
  '......NGKKN..NGKKN......',
  '.....NKzzzN..NKzzzN.....',
  '.....NNNNNN..NNNNNN.....',
  '......xxxxxxxxxxxx......',
];

final _fichaInvestigada = PersonajePixel(
  id: 'investigada',
  nombre: 'La persona investigada',
  descripcion: 'La persona investigada, con ropa gris y gesto tranquilo',
  sprite: _personaje('investigada', filas: _investigadaFilas, ojos: 9, pecho: 21, piel: '3', ms: 900),
);

/// Un testigo: un hombre joven en su silla de ruedas, de frente. Pelo rubio despeinado y barba corta, chaqueta mostaza
/// sobre una camiseta blanca, vaqueros y zapatillas. Es adulto a propósito: en la sala de vistas no sale ningún menor
/// declarando (los menores de 14 años declaran antes, en la prueba preconstituida). La silla: ruedas grandes con el aro plateado, empuñaduras, reposapiés y
/// ruedas pequeñas delante. Mide 28 × 32: al respirar solo se mueve él (columnas 7 a 20), no la silla.
const _testigoFilas = <String>[
  '............................',
  '..........NNNNNNNN..........',
  '........NNyyuuuuuuNN........',
  '.......NyyuuuuuuuuuoN.......',
  '.......NyuuuuuuuuuuoN.......',
  '.......NuuuuuuuuuuuoN.......',
  '.......Nuu1uu1u11uuoN.......',
  '.......Nu1111111112oN.......',
  '.......Nu1111111112oN.......',
  '.......Nu1WN1111WN2oN.......',
  '.......Nu1NN1111NN2oN.......',
  '.......N1s11111111s2N.......',
  '........Nu111RR111oN........',
  '....NNN..NNuuuuooNN..NNN....',
  '....NzN...NN2222NN...NzN....',
  '....NKN.NNooW22WooNN.NKN....',
  '....NKNNYoooWWWWooooNNKN....',
  '..NN.NKNYNooWWWWooNtNKN.NN..',
  '.NKgNNKNYNooWWWWooNtNKNNgKN.',
  'NKKgNNKNYNooWWWWooNtNKNNgKKN',
  'NKKgNNKNoNooWWWWooNtNKNNgKKN',
  'NKKgNNKN1NttttttttN2NKNNgKKN',
  'NKKgNNKNaAAAAAAAAAADNKNNgKKN',
  'NKKgNKKNaAAAANNaAAADNKKNgKKN',
  'NKKgNNN.NaAAN..NaAAN.NNNgKKN',
  'NKKgN...NaAAN..NaAAN...NgKKN',
  'NKKgN...NaAAN..NaAAN...NgKKN',
  'NKKgN..NWWWgNNNNWWWgN..NgKKN',
  'NKKgN.NKKKKKKKKKKKKKKN.NgKKN',
  '.NKgN.NNKNNNNNNNNNNKNN.NgKN.',
  '..NN...NNN........NNN...NN..',
  '.xxxxxxxxxxxxxxxxxxxxxxxxxx.',
];

final _fichaTestigo = PersonajePixel(
  id: 'testigo',
  nombre: 'El testigo',
  descripcion: 'Un testigo, un hombre joven con barba, en silla de ruedas y con chaqueta mostaza',
  sprite: _personaje('testigo', filas: _testigoFilas, ojos: 9, pecho: 19, piel: '1', ms: 850, desde: 7, hasta: 21),
);
