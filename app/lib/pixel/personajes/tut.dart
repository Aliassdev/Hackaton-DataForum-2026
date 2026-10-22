part of 'personajes.dart';

// Tut, la mascota de TuTurno, en pixel art: el ticket de turno amarillo con la cara del monograma (las dos T son los
// ojos, con la barra como párpado, y la u es la boca), como MascotaTut de lib/widgets/iconos/. Flota sobre su sombra.

/// Tut quieto: el ticket con una muesca a cada lado, la luz arriba a la izquierda y la sombra del ticket abajo.
const _tutFilas = <String>[
  '........................',
  '........................',
  '...NNNNNNNNNNNNNNNNNN...',
  '..NyyyyyyyyyyyyyyyyyoN..',
  '.NyYYYYYYYYYYYYYYYYYYoN.',
  '.NyYNNNNYYYYYYYYNNNNYoN.',
  '.NyYYWNYYYYYYYYYYWNYYoN.',
  '.NyYYNNYYYYYYYYYYNNYYoN.',
  '.NyYYNNYYYYYYYYYYNNYYoN.',
  '..NYYNNYYYNYYNYYYNNYoN..',
  '...NYYYYYYNYYNYYYYYYN...',
  '..NYssYYYYYNNYYYYYssoN..',
  '.NYYYYYYYYYYYYYYYYYYYoN.',
  '.NYYYYYYYYYYYYYYYYYYYoN.',
  '.NYYYYYYYYYYYYYYYYYYooN.',
  '..NooooooooooooooooooN..',
  '...NNNNNNNNNNNNNNNNNN...',
  '........................',
  '........................',
  '........................',
  '........................',
  '.......xxxxxxxxxx.......',
];

/// Ojos cerrados: solo quedan las barras de las T.
final _tutParpadea = retocar(_tutFilas, {
  6: '.NyYYYYYYYYYYYYYYYYYYoN.',
  7: '.NyYYYYYYYYYYYYYYYYYYoN.',
  8: '.NyYYYYYYYYYYYYYYYYYYoN.',
  9: '..NYYYYYYYNYYNYYYYYYoN..',
});

/// Flota: el ticket sube un píxel y la sombra se queda en el suelo.
final _tutSube = [..._tutFilas.sublist(1, 17), '.' * 24, ..._tutFilas.sublist(17)];

final _fichaTut = PersonajePixel(
  id: 'tut',
  nombre: 'Tut',
  descripcion: 'Tut, la mascota de TuTurno: un ticket amarillo con cara',
  sprite: Sprite.animado('tut', [_tutFilas, _tutSube, _tutParpadea], animacion: AnimacionPixel.reposo(ms: 700)),
);

/// Tut sonríe: la expresión «feliz» de MascotaTut (`ExpresionTut.feliz`) en pixel art. La barra de cada T sube un
/// píxel sobre el palo, como una ceja contenta, y la u es más ancha. A tamaño de móvil, la cara de siempre ([_tutFilas],
/// con la barra pegada al ojo) puede leerse desganada; esta no. Cuál abre el juego lo decide quien cuida la marca.
const _tutFelizFilas = <String>[
  '........................',
  '........................',
  '...NNNNNNNNNNNNNNNNNN...',
  '..NyyyyyyyyyyyyyyyyyoN..',
  '.NyYNNNNYYYYYYYYNNNNYoN.',
  '.NyYYYYYYYYYYYYYYYYYYoN.',
  '.NyYYWNYYYYYYYYYYWNYYoN.',
  '.NyYYNNYYYYYYYYYYNNYYoN.',
  '.NyYYNNYYNYYYYNYYNNYYoN.',
  '..NYYYYYYNYYYYNYYYYYoN..',
  '...NYYYYYYNNNNYYYYYYN...',
  '..NYssYYYYYYYYYYYYssoN..',
  '.NYYYYYYYYYYYYYYYYYYYoN.',
  '.NYYYYYYYYYYYYYYYYYYYoN.',
  '.NYYYYYYYYYYYYYYYYYYooN.',
  '..NooooooooooooooooooN..',
  '...NNNNNNNNNNNNNNNNNN...',
  '........................',
  '........................',
  '........................',
  '........................',
  '.......xxxxxxxxxx.......',
];

/// Tut sonriendo con los ojos cerrados: se van los palos de las T; la barra y la sonrisa se quedan.
final _tutFelizParpadea = retocar(_tutFelizFilas, {
  6: '.NyYYYYYYYYYYYYYYYYYYoN.',
  7: '.NyYYYYYYYYYYYYYYYYYYoN.',
  8: '.NyYYYYYYNYYYYNYYYYYYoN.',
});

final _tutFelizSube = [..._tutFelizFilas.sublist(1, 17), '.' * 24, ..._tutFelizFilas.sublist(17)];

final _fichaTutFeliz = PersonajePixel(
  id: 'tut-feliz',
  nombre: 'Tut',
  descripcion: 'Tut sonríe: un ticket amarillo con cara',
  sprite: Sprite.animado('tut-feliz', [
    _tutFelizFilas,
    _tutFelizSube,
    _tutFelizParpadea,
  ], animacion: AnimacionPixel.reposo(ms: 660)),
);
