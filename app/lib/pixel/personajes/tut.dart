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
