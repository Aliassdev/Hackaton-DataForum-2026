part of 'personajes.dart';

// El caso oficial: Lucía (11 años), su tutora del colegio, su tía Elena y Ana, la psicóloga del equipo psicosocial del
// juzgado.

/// Lucía, 11 años: coletas castañas con gomas amarillas, sudadera amarilla con cuello blanco, falda azul de tablas y
/// zapatos coral. Es la más bajita (empieza en la fila 2).
const _luciaFilas = <String>[
  '........................',
  '........................',
  '........NNNNNNNN........',
  '......NNttTTTTTTNN......',
  '.....NtTTttTTTTTTzN.....',
  '....NtTTttTTTTTTTTzN....',
  '...NtTTTTTTTTTTTTTTzN...',
  '...NtTTTTTTTTTTTTTTzN...',
  '...NtTT2TTT22TTT2TTzN...',
  '..NNtT222222222222TzNN..',
  '.NYNtT22WN2222WN23TzNYN.',
  'NtTNtT22NN2222NN23TzNTzN',
  'NtTNtT2s22222222s3TzNTzN',
  'NtzNN222222RR222223NNTzN',
  'NTzN.NN2222222233NN.NzzN',
  '.NzN...NNN3333NNN...NzN.',
  '..N...NyYWW33WWYoN...N..',
  '.....NyYYWWYYWWYYoN.....',
  '....NyYYYYYYYYYYYooN....',
  '....NYNYYYYYYYYYoNoN....',
  '....NYNYYYYYYYYYoNoN....',
  '....NoNooooooooooNoN....',
  '....N2NaAAAAAAAADN3N....',
  '.....NaAAAAAAAAAADN.....',
  '....NaAAADAAAADAAADN....',
  '....NNNNNNNNNNNNNNNN....',
  '.......N22N..N23N.......',
  '.......N22N..N23N.......',
  '.......NWWN..NWhN.......',
  '......NrrrN..NrrRN......',
  '......NNNNN..NNNNN......',
  '......xxxxxxxxxxxx......',
];

final _fichaLucia = PersonajePixel(
  id: 'lucia',
  nombre: 'Lucía',
  descripcion: 'Lucía, de 11 años, con coletas y sudadera amarilla',
  sprite: _personaje('lucia', filas: _luciaFilas, ojos: 10, pecho: 20, piel: '2', ms: 760),
);

/// La tutora de Lucía, la maestra de su clase: media melena negra con raya a un lado y una horquilla amarilla, piel 6
/// (con el colorete teja de las pieles oscuras), rebeca verde abierta sobre una blusa blanca, un libro rojo contra el
/// pecho y falda azul marino.
const _tutoraFilas = <String>[
  '........................',
  '........NNNNNNNN........',
  '......NNKzzzzzzzNN......',
  '.....NKzzzzzzzzzzzN.....',
  '....NKzzzzzzzzzzzzzN....',
  '....NKzzzzzzzzzzYYzN....',
  '....Nzzz66666zzzzzzN....',
  '....Nzz666666666zzzN....',
  '....Nzz6666666667zzN....',
  '....Nzz6WN6666WN7zzN....',
  '....Nzz6NN6666NN7zzN....',
  '....NzzR6666666R7zzN....',
  '....Nzz6666RR6667zzN....',
  '....NzzN66666677NzzN....',
  '.....NN.NN7777NN.NN.....',
  '......NNvWW77WWvNN......',
  '.....NvvvvWWWWvvVVN.....',
  '....NvvvvvWWWWvvvVVN....',
  '....NvNvvvvWWvvvVNVN....',
  '....NvNvNNNNNNNNVNVN....',
  '....NvN6NrrrrrRN7NVN....',
  '....NvNvNrYYYrRNVNVN....',
  '....NVNvNrrrrrRNVNVN....',
  '.....NNvNRRRRRRNVNN.....',
  '......NvNNNNNNNNVN......',
  '......NDADDDDDDDDN......',
  '......NDADDDDDDDDN......',
  '.....NDADDDDDDDDDDN.....',
  '.....NDADDDDDDDDDDN.....',
  '....NDADDDDDDDDDDDDN....',
  '....NNNNNNNNNNNNNNNN....',
  '.......N66N..N67N.......',
  '.......N66N..N67N.......',
  '......NRRRN..NRRRN......',
  '......NNNNN..NNNNN......',
  '....xxxxxxxxxxxxxxxx....',
];

final _fichaTutora = PersonajePixel(
  id: 'tutora',
  nombre: 'Su tutora',
  descripcion: 'La tutora de Lucía, con media melena negra, rebeca verde y un libro rojo',
  sprite: _personaje('tutora', filas: _tutoraFilas, ojos: 9, pecho: 18, piel: '6', ms: 930),
);

/// Elena, la tía de Lucía: pelo castaño claro rizado por la barbilla (el contorno hace ondas de dos filas, los rizos van
/// por dentro), chaqueta de punto coral abierta sobre una camiseta crema y falda larga verde de lunares. Cuerpo grande
/// y redondeado.
const _elenaFilas = <String>[
  '........................',
  '........NNNNNNNN........',
  '......NNmmTmmtTtNN......',
  '.....NmmttTmmttTtTN.....',
  '....NmtTmmtTmmtTmtTN....',
  '...NmtTmttTmttTmtTTTN...',
  '..NmtTmttTtmtTmttTmTTN..',
  '.NmmtTtT2222TTmtTtmTtTN.',
  '.NtmtT22222222TTmtTmtTN.',
  '..NmtT22WN2222WN23TmTN..',
  '.NmtTT22NN2222NN33TtTTN.',
  '.NmtTT2s22222222s3TmtTN.',
  '..NtTTN2222RR2223NTtTN..',
  '..NtTtTN22222233NTmTTN..',
  '...NNNN.NN3333NN.NNNN...',
  '......NNrrP33PrrNN......',
  '....NNsrrrPPPPrrrRNN....',
  '...NsrrrrrPPPPrrrrRRN...',
  '...NsNrrrrPPPPrrrRNRN...',
  '...NsNrrrrPPPPrrrRNRN...',
  '...NrNrrrrPPPPrrrRNRN...',
  '...NrNrrrrPPPPrrrRNRN...',
  '...NrNrrrrPPPPrrrRNRN...',
  '...N2NrrrrPPPPrrrRN3N...',
  '....NNRRRRppppRRRRNN....',
  '.....NvVVVVVVVVVVVN.....',
  '.....NvVvVVVVVvVVVN.....',
  '....NvVVVVVVVVVVVVVN....',
  '....NvVVVVVvVVVVVvVN....',
  '....NvVVVVVVVVVVVVVN....',
  '...NvvVVvVVVVVvVVVVvN...',
  '...NvVVVVVVVVVVVVVVVN...',
  '...NNNNNNNNNNNNNNNNNN...',
  '......NRRRN..NRRRN......',
  '......NNNNN..NNNNN......',
  '.....xxxxxxxxxxxxxx.....',
];

final _fichaElena = PersonajePixel(
  id: 'elena',
  nombre: 'Elena',
  descripcion: 'Elena, la tía de Lucía, con el pelo rizado y una chaqueta coral',
  sprite: _personaje('elena', filas: _elenaFilas, ojos: 9, pecho: 19, piel: '2', ms: 900),
);

/// Ana, la psicóloga: moño negro, chaqueta de punto lila sobre una camisa azul cielo y la tarjeta del juzgado colgada
/// de un cordón amarillo.
const _anaFilas = <String>[
  '..........NNNN..........',
  '.........NKzzzN.........',
  '........NKzzzzzN........',
  '......NNNzzzzzzNNN......',
  '.....NKzzzzzzzzzzzN.....',
  '.....NKzzzzzzzzzzzN.....',
  '.....Nz4444444444zN.....',
  '.....Nz4444444445zN.....',
  '.....Nz4444444445zN.....',
  '....N4z4WN4444WN5z5N....',
  '....N544NN4444NN555N....',
  '....NY4R4444444R45YN....',
  '.....NN4444RR4445NN.....',
  '.......NN444455NN.......',
  '........NN5555NN........',
  '......NNLLY55YLLNN......',
  '.....NLLLLYccYLLDDN.....',
  '....NLLLLLcYYcLLLDDN....',
  '....NLNLLLcWWcLLDNDN....',
  '....NLNLLLcAAcLLDNDN....',
  '....NLNLLLcWWcLLDNDN....',
  '....NLNLLLccccLLDNDN....',
  '....NLNLLLccccLLDNDN....',
  '....NDNLLLccccLLDNDN....',
  '....N4NLLLLccLLLDN5N....',
  '.....NNDDDDDDDDDDNN.....',
  '......NKKKKKKKKKKN......',
  '......NKKKKNNKKKKN......',
  '......NGKKN..NGKKN......',
  '......NGKKN..NGKKN......',
  '......NGKKN..NGKKN......',
  '......NGKKN..NGKKN......',
  '......NGKKN..NGKKN......',
  '.....NRRRRN..NRRRRN.....',
  '.....NNNNNN..NNNNNN.....',
  '......xxxxxxxxxxxx......',
];

final _fichaAna = PersonajePixel(
  id: 'ana',
  nombre: 'Ana',
  descripcion: 'Ana, la psicóloga del juzgado, con moño y chaqueta lila',
  sprite: _personaje('ana', filas: _anaFilas, ojos: 9, pecho: 22, piel: '4', ms: 860),
);
