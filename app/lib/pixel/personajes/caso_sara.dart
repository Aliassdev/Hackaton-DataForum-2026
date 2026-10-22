part of 'personajes.dart';

// El caso de Sara (casi 16 años) y su amiga. Adolescentes: 24 × 34, entre los niños (32) y los adultos (36).

/// Sara, casi 16 años: trenzas largas negras con raya en medio, chaqueta lila abierta sobre una camiseta blanca,
/// vaqueros y zapatillas.
const _saraFilas = <String>[
  '........NNNNNNNN........',
  '......NNzKzzzzKzNN......',
  '.....NzKzzKzzKzzKzN.....',
  '....NzKzzKzzzzKzzKzN....',
  '...NzKzzKzzzzzzKzzKzN...',
  '...NzKzKz666666zKzKzN...',
  '...NzKz6666666667zKzN...',
  '...NzK666666666667KzN...',
  '...NzK66WN6666WN67KzN...',
  '...NzK66NN6666NN77KzN...',
  '...NzK6R66666666R7KzN...',
  '...NzYN6666RR6667NYzN...',
  '...NzKzN66666677NzKzN...',
  '...NzKzzNN7777NNzzKzN...',
  '..NzKzNNLLW77WLLNNzKzN..',
  '..NzKNLLLLWWWWLLDDNKzN..',
  '..NzNLLLLLWWWWLLLDDNzN..',
  '..NzNLNLLLWWWWLLDNDNzN..',
  '..NzNLNLLLWWWWLLDNDNzN..',
  '..NYNLNLLLWWWWLLDNDNYN..',
  '...NNLNLLLWWWWLLDNDNN...',
  '....NLNLLLWWWWLLDNDN....',
  '....N6NLLLWWWWLLDN7N....',
  '.....NNDDDDDDDDDDNN.....',
  '......NaAAAAAAAADN......',
  '......NaAAANNaAADN......',
  '......NaADN..NaADN......',
  '......NaADN..NaADN......',
  '......NaADN..NaADN......',
  '......NaADN..NaADN......',
  '......NaADN..NaADN......',
  '.....NWWWgN..NWWWgN.....',
  '.....NNNNNN..NNNNNN.....',
  '......xxxxxxxxxxxx......',
];

final _fichaSara = PersonajePixel(
  id: 'sara',
  nombre: 'Sara',
  descripcion: 'Sara, de casi 16 años, con trenzas largas y chaqueta lila',
  sprite: _personaje('sara', filas: _saraFilas, ojos: 8, pecho: 18, piel: '6', ms: 820),
);

/// La amiga de Sara: hiyab azul cielo, jersey coral, vaqueros oscuros y zapatillas.
const _amigaSaraFilas = <String>[
  '........NNNNNNNN........',
  '......NNhhccccccNN......',
  '.....NhhccccccccaaN.....',
  '....NhcccccccccccaaN....',
  '...NhcccccccccccccaaN...',
  '...NhcccaaaaaaaacccaN...',
  '...Nhcca44444444accaN...',
  '...Nhca4444444445acaN...',
  '...Nhca4WN4444WN5acaN...',
  '...Nhca4NN4444NN5acaN...',
  '...NhcaR4444444R5acaN...',
  '...Nhcca444RR445accaN...',
  '...Nhccca444455acccaN...',
  '...NhcccccaaaacccccaN...',
  '...NhccccccccccccccaN...',
  '..NhccccccccccccccccaN..',
  '...NNrNcccccccccaNRNN...',
  '....NrNrcccccccaRNRN....',
  '....NrNrrcccccaRRNRN....',
  '....NrNrrrcccarrRNRN....',
  '....NrNrrrrNNrrrRNRN....',
  '....NrNrrrrrrrrrRNRN....',
  '....N4NrrrrrrrrrRN5N....',
  '.....NNRRRRRRRRRRNN.....',
  '......NADDDDDDDDDN......',
  '......NADDDNNADDDN......',
  '......NADDN..NADDN......',
  '......NADDN..NADDN......',
  '......NADDN..NADDN......',
  '......NADDN..NADDN......',
  '......NADDN..NADDN......',
  '.....NWWWgN..NWWWgN.....',
  '.....NNNNNN..NNNNNN.....',
  '......xxxxxxxxxxxx......',
];

final _fichaAmigaSara = PersonajePixel(
  id: 'amiga-sara',
  nombre: 'La amiga de Sara',
  descripcion: 'La amiga de Sara, con hiyab azul y jersey coral',
  sprite: _personaje('amiga-sara', filas: _amigaSaraFilas, ojos: 8, pecho: 21, piel: '4', ms: 880),
);

/// La madre de Sara: la misma figura que la madre de Sergio, con la piel de Sara (6), la cinta y los pendientes lilas y
/// un jersey verde. Así cada caso tiene su familia.
final _madreSaraFilas = <String>[
  for (final (y, fila) in _madreSergioFilas.indexed)
    _cambiarClaves(fila, {
      '5': '6',
      '6': '7',
      'Y': 'L',
      // Del jersey para abajo, el coral pasa a verde (arriba, la «R» es la boca y no cambia).
      if (y >= 15) ...const {'r': 'v', 'R': 'V'},
    }),
];

final _fichaMadreSara = PersonajePixel(
  id: 'madre-sara',
  nombre: 'La madre de Sara',
  descripcion: 'La madre de Sara, con el pelo rizado, una cinta lila y jersey verde',
  sprite: _personaje('madre-sara', filas: _madreSaraFilas, ojos: 9, pecho: 18, piel: '6', ms: 860),
);
