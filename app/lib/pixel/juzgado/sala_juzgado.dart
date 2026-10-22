// Las dos salas de «¿Quién es quién en el juzgado?» en pixel art, con cada persona en su sitio:
//
// - La sala de vistas (un juicio de personas adultas) es la de lib/pixel/escenarios («sala_vistas»), la misma que sale
//   en las escenas del juego, con los personajes del juzgado de lib/pixel/personajes. El público de espaldas es de
//   esta carpeta.
// - La sala del Juzgado de Menores (la audiencia del caso de Sergio) es de esta carpeta: el estrado, las mesas, el
//   banco del chico y de su madre, los bancos del público vacíos y un cordón que cierra el paso. El fiscal es el de
//   lib/pixel/personajes, el mismo que en las escenas de la Fiscalía; el resto del reparto es de reparto_juzgado.dart.
//
// Si a lib/pixel/personajes le falta algún personaje, o a la sala de vistas algún puesto, se usa el de reserva de esta
// carpeta: la actividad no se rompe mientras los otros equipos cambian sus dibujos.
import 'package:flutter/foundation.dart';

import '../escenarios/escenarios.dart';
import '../motor/motor.dart';
import '../personajes/personajes.dart';
import 'reparto_juzgado.dart';

/// Las dos salas.
enum ModoJuzgado {
  /// Un juicio penal de personas adultas: la jueza, el fiscal, las dos abogacías, la letrada, el testigo, la persona
  /// investigada, un policía y el público.
  salaVistas,

  /// La audiencia del caso de Sergio en el Juzgado de Menores: el juez de menores, el fiscal, la abogada del chico,
  /// el equipo técnico, el chico investigado y su madre. Hoy no hay público.
  menores,
}

/// Una persona en la sala: su [sprite], con los pies en ([x], [y]) en píxeles del fondo.
@immutable
class PuestoJuzgado {
  PuestoJuzgado({required this.id, required this.sprite, required this.x, required this.y})
    : _arriba = y - sprite.ancla.y + _primeraFila(sprite.fotogramas.first);

  /// El id del rol (el de `RolJuzgado.id`).
  final String id;
  final Sprite sprite;
  final int x;
  final int y;

  /// La fila de lo de arriba de la cabeza, en píxeles del fondo.
  final int _arriba;

  /// Más de 32 de ancho: un grupo, como el público.
  bool get _grupo => sprite.ancho > 32;

  /// Un punto de la cara, en píxeles del fondo: siempre se ve y nadie lo tapa, así que sirve para señalarla (o para
  /// tocarla en una prueba).
  PuntoPixel get cara => _grupo ? (x: x, y: _arriba + 5) : (x: x, y: _arriba + 8);

  /// El centro de la chispa que la señala mientras no se la conoce: arriba a la derecha de la cabeza (en un grupo,
  /// encima del centro).
  PuntoPixel get chispa => _grupo ? (x: x, y: _arriba - 4) : (x: x + 9, y: _arriba + 1);

  /// La primera fila de [filas] con algo dibujado.
  static int _primeraFila(List<String> filas) {
    final vacia = '.' * filas.first.length;
    var fila = 0;
    while (fila < filas.length - 1 && filas[fila] == vacia) {
      fila++;
    }
    return fila;
  }
}

/// El sprite de cada rol: el de lib/pixel/personajes si lo tiene y, si no, el de reparto_juzgado.dart. (Los títulos
/// de las cartas van a juego con estos dibujos: el policía de lib/pixel/personajes es un hombre, por ejemplo.)
Sprite spriteDelRol(String id) {
  final personaje = switch (id) {
    'jueza' => 'jueza',
    'fiscal' || 'fiscalMenores' => 'fiscal',
    'abogadaVictima' => 'abogada-victima',
    'abogadoDefensa' => 'abogado-defensa',
    'letrada' => 'letrada',
    'testigo' => 'testigo',
    'investigada' => 'investigada',
    'policia' => 'policia',
    _ => null,
  };
  return (personaje == null ? null : PersonajesPixel.porId(personaje)) ?? spriteDeReserva(id);
}

/// El sprite de esta carpeta para el rol [id].
Sprite spriteDeReserva(String id) => switch (id) {
  'jueza' => RepartoJuzgado.jueza,
  'fiscal' || 'fiscalMenores' => RepartoJuzgado.fiscal,
  'abogadaVictima' => RepartoJuzgado.abogadaVictima,
  'abogadoDefensa' => RepartoJuzgado.abogadoDefensa,
  'letrada' => RepartoJuzgado.letrada,
  'testigo' => RepartoJuzgado.testigo,
  'investigada' => RepartoJuzgado.investigada,
  'policia' => RepartoJuzgado.policia,
  'publico' => RepartoJuzgado.publico,
  'juezMenores' => RepartoJuzgado.juezMenores,
  'letradaMenor' => RepartoJuzgado.letradaMenor,
  'equipoTecnico' => RepartoJuzgado.equipoTecnico,
  'menor' => RepartoJuzgado.menor,
  'familia' => RepartoJuzgado.madre,
  _ => throw ArgumentError.value(id, 'id', 'No hay ningún personaje con este id en el juzgado'),
};

/// Una sala montada: el [fondo], los muebles que tapan a quien está detrás y las personas en sus [puestos], lista para
/// una `EscenaPixel`.
class MontajeJuzgado {
  MontajeJuzgado._({required this.modo, required this.fondo, required this.puestos, required this.muebles});

  /// La sala de [modo]. Se monta una sola vez y se guarda.
  factory MontajeJuzgado.de(ModoJuzgado modo) => switch (modo) {
    ModoJuzgado.salaVistas => _salaVistas,
    ModoJuzgado.menores => _menores,
  };

  static final _salaVistas = _montarSalaVistas();
  static final _menores = _montarMenores();

  final ModoJuzgado modo;

  /// La sala vacía, de 160 × 96.
  final Sprite fondo;

  /// Quién está y dónde.
  final List<PuestoJuzgado> puestos;

  /// Los muebles que tapan a quien está detrás (sin id: no se pueden tocar).
  final List<ElementoEscena> muebles;

  /// El puesto del rol [id], o null si no está en esta sala.
  PuestoJuzgado? puesto(String id) => puestos.where((puesto) => puesto.id == id).firstOrNull;

  /// Un punto de la cara del rol [id] (mira [PuestoJuzgado.cara]), o null si no está en esta sala.
  PuntoPixel? cara(String id) => puesto(id)?.cara;

  /// Todo lo que se pinta encima del fondo: las personas (que se pueden tocar, con la [etiqueta] de cada una para los
  /// lectores de pantalla) y los muebles, de más al fondo a más cerca, y, encima de todo, una chispa por persona. La de
  /// los [descubiertos] es invisible: así la lista y sus animaciones no cambian al descubrir a alguien y nadie da un
  /// salto. El [seleccionado] lleva el halo de resaltar.
  List<ElementoEscena> elementos({
    Set<String> descubiertos = const {},
    String? seleccionado,
    String Function(String id)? etiqueta,
  }) => [
    ..._componer(muebles, [
      for (final puesto in puestos)
        ElementoEscena(
          sprite: puesto.sprite,
          x: puesto.x,
          y: puesto.y,
          id: puesto.id,
          etiqueta: etiqueta?.call(puesto.id),
          resaltado: puesto.id == seleccionado,
        ),
    ]),
    for (final puesto in puestos)
      ElementoEscena(
        sprite: descubiertos.contains(puesto.id) ? MueblesJuzgado.sinChispa : MueblesJuzgado.chispa,
        x: puesto.chispa.x,
        y: puesto.chispa.y,
      ),
  ];
}

/// Muebles y personas de más al fondo a más cerca, como `EscenarioPixel.componer`: por la fila de los pies (el borde
/// de abajo de los muebles); a la misma altura, el mueble detrás; y si no, en el orden de las listas.
List<ElementoEscena> _componer(List<ElementoEscena> muebles, List<ElementoEscena> personas) {
  final todos = [
    for (final (i, mueble) in muebles.indexed) (y: mueble.y, tipo: 0, orden: i, elemento: mueble),
    for (final (i, persona) in personas.indexed) (y: persona.y, tipo: 1, orden: i, elemento: persona),
  ]..sort((a, b) => a.y != b.y ? a.y.compareTo(b.y) : (a.tipo != b.tipo ? a.tipo - b.tipo : a.orden - b.orden));
  return [for (final item in todos) item.elemento];
}

/// La sala de vistas de lib/pixel/escenarios, con cada persona en su puesto. Si un puesto falta, el de reserva (el de
/// ahora en esa sala).
MontajeJuzgado _montarSalaVistas() {
  final sala = EscenariosPixel.salaVistas;
  PuestoJuzgado en(String id, String clave, PuntoPixel reserva, {int subir = 0}) {
    final punto = sala.puesto(clave) ?? reserva;
    return PuestoJuzgado(id: id, sprite: spriteDelRol(id), x: punto.x, y: punto.y - subir);
  }

  return MontajeJuzgado._(
    modo: ModoJuzgado.salaVistas,
    fondo: sala.fondo,
    muebles: sala.delante,
    puestos: [
      en('jueza', 'jueza', (x: 80, y: 50)),
      en('letrada', 'letrada', (x: 109, y: 51)),
      en('fiscal', 'fiscal', (x: 18, y: 72)),
      en('abogadaVictima', 'abogada_victima', (x: 43, y: 72)),
      en('investigada', 'persona_investigada', (x: 117, y: 72)),
      en('abogadoDefensa', 'abogado_defensa', (x: 142, y: 72)),
      en('testigo', 'testigo', (x: 80, y: 83)),
      en('policia', 'policia', (x: 148, y: 86)),
      // El puesto del público es para alguien de 36 de alto sentado de cara; el público de espaldas mide 22: va 12
      // píxeles más arriba para que se le vean la cabeza y los hombros por encima del respaldo.
      en('publico', 'publico', (x: 24, y: 100), subir: 12),
    ],
  );
}

/// La sala del Juzgado de Menores, de esta carpeta.
MontajeJuzgado _montarMenores() {
  PuestoJuzgado en(String id, int x, int y) => PuestoJuzgado(id: id, sprite: spriteDelRol(id), x: x, y: y);
  return MontajeJuzgado._(
    modo: ModoJuzgado.menores,
    fondo: Sprite('sala del Juzgado de Menores', pintarSalaMenores()),
    muebles: [
      ElementoEscena(sprite: MueblesJuzgado.estrado, x: 80, y: 52),
      ElementoEscena(sprite: MueblesJuzgado.mesa, x: 32, y: 72),
      ElementoEscena(sprite: MueblesJuzgado.mesa, x: 128, y: 72),
      ElementoEscena(sprite: MueblesJuzgado.bancoMenor, x: 81, y: 78),
      ElementoEscena(sprite: MueblesJuzgado.bancoPublico, x: 31, y: 96),
      ElementoEscena(sprite: MueblesJuzgado.bancoPublico, x: 129, y: 96),
    ],
    puestos: [
      en('juezMenores', 80, 50),
      en('fiscalMenores', 20, 70),
      en('equipoTecnico', 44, 70),
      en('letradaMenor', 128, 70),
      en('menor', 70, 76),
      en('familia', 92, 76),
    ],
  );
}

/// Los muebles que tapan a los personajes que tienen detrás, y la chispa que señala a quien falta por conocer.
abstract final class MueblesJuzgado {
  /// El estrado (104 × 18): el tablero con micrófonos y papeles y el frente de madera con cuarterones. Tapa al juez
  /// de cintura para abajo.
  static final estrado = Sprite('estrado', _pintarEstrado());

  /// Una mesa de las partes (56 × 14), con papeles, una carpeta y un micrófono.
  static final mesa = Sprite('mesa', _pintarMesa());

  /// El respaldo de un banco del público, visto desde detrás (62 × 5).
  static final bancoPublico = Sprite('banco del público', _pintarBancoPublico());

  /// El banco del chico y de su madre en la audiencia de menores (48 × 9).
  static final bancoMenor = Sprite('banco del menor', _pintarBancoMenor());

  /// Animación de la chispa: casi siempre grande y, un momento, pequeña. Con «reducir animaciones», grande y quieta.
  static final animacionChispa = AnimacionPixel(const [PasoPixel(0, ms: 760), PasoPixel(1, ms: 440)]);

  /// La chispa amarilla que señala a quien falta por conocer (7 × 7; el ancla es su centro).
  static final chispa = Sprite.animado(
    'chispa',
    [_chispaGrande, _chispaPequena],
    animacion: animacionChispa,
    ancla: _centro,
  );

  /// La misma chispa, invisible y con la misma animación: ocupa su sitio en la escena cuando ya se conoce a esa persona.
  static final sinChispa = Sprite.animado(
    'sin chispa',
    [_chispaVacia, _chispaVacia],
    animacion: animacionChispa,
    ancla: _centro,
  );

  static const PuntoPixel _centro = (x: 3, y: 3);
}

const _chispaGrande = ['...N...', '..NYN..', '.NYWYN.', 'NYWWWYN', '.NYWYN.', '..NYN..', '...N...'];

const _chispaPequena = ['.......', '...N...', '..NYN..', '.NYyYN.', '..NYN..', '...N...', '.......'];

const _chispaVacia = ['.......', '.......', '.......', '.......', '.......', '.......', '.......'];

List<String> _pintarEstrado() {
  const ancho = 104, alto = 18;
  final l = LienzoPixel(ancho, alto)
    ..rect(0, 2, ancho, 3, 'm')
    ..lineaH(0, 2, ancho, 'N')
    ..lineaH(0, 3, ancho, 'o')
    ..lineaH(0, 5, ancho, 'N')
    ..rect(1, 6, ancho - 2, alto - 6, 't')
    ..lineaV(0, 2, alto - 2, 'N')
    ..lineaV(ancho - 1, 2, alto - 2, 'N');
  for (var x = 4; x < ancho - 8; x += 12) {
    l
      ..marco(x, 8, 9, alto - 11, 'T')
      ..lineaH(x + 1, 9, 7, 'm');
  }
  l.lineaH(1, alto - 1, ancho - 2, 'T');
  // Dos micrófonos y unos papeles.
  for (final x in [52, 80]) {
    l
      ..punto(x, 0, 'N')
      ..punto(x + 1, 0, 'N')
      ..punto(x, 1, 'K');
  }
  l
    ..rect(40, 1, 6, 1, 'W')
    ..rect(70, 1, 5, 1, 'W');
  return l.filas;
}

List<String> _pintarMesa() {
  const ancho = 56, alto = 14;
  final l = LienzoPixel(ancho, alto)
    ..rect(0, 2, ancho, 2, 'm')
    ..lineaH(0, 1, ancho, 'N')
    ..lineaH(0, 2, ancho, 'o')
    ..lineaH(0, 4, ancho, 'N')
    ..rect(1, 5, ancho - 2, alto - 5, 't')
    ..lineaV(0, 1, alto - 1, 'N')
    ..lineaV(ancho - 1, 1, alto - 1, 'N');
  for (var x = 4; x < ancho - 6; x += 12) {
    l.marco(x, 6, 9, alto - 8, 'T');
  }
  l
    ..lineaH(1, alto - 1, ancho - 2, 'T')
    // Papeles, una carpeta amarilla y un micrófono.
    ..rect(8, 0, 7, 1, 'W')
    ..rect(ancho - 18, 0, 6, 1, 'Y')
    ..punto(ancho ~/ 2, 0, 'N')
    ..punto(ancho ~/ 2 + 1, 0, 'N');
  return l.filas;
}

List<String> _pintarBancoPublico() {
  const ancho = 62, alto = 5;
  return (LienzoPixel(ancho, alto, 'T')
        ..lineaH(0, 0, ancho, 'N')
        ..lineaH(0, 1, ancho, 't')
        ..lineaH(0, 3, ancho, 'z')
        ..lineaV(0, 0, alto, 'N')
        ..lineaV(ancho - 1, 0, alto, 'N'))
      .filas;
}

List<String> _pintarBancoMenor() {
  const ancho = 48, alto = 9;
  return (LienzoPixel(ancho, alto)
        ..rect(0, 1, ancho, 2, 'm')
        ..lineaH(0, 0, ancho, 'N')
        ..lineaH(0, 1, ancho, 'o')
        ..lineaH(0, 3, ancho, 'N')
        ..rect(1, 4, ancho - 2, alto - 4, 't')
        ..lineaV(0, 0, alto, 'N')
        ..lineaV(ancho - 1, 0, alto, 'N')
        ..lineaH(1, alto - 1, ancho - 2, 'T'))
      .filas;
}

// ------------------------------------------------------------------------------------------------------------- fondo

const _anchoSala = 160;
const _altoSala = 96;

/// Primera fila del suelo.
const _suelo = 47;

/// Fila de arriba de la barandilla que separa al público.
const _barandilla = 81;

/// La balanza de la justicia en un medallón azul, sobre el estrado.
const _emblema = [
  '....NNNNN....',
  '..NNDDDDDNN..',
  '.NDDDDYDDDDN.',
  '.NDYYYYYYYDN.',
  'NDDYDDYDDYDDN',
  'NDYYYDYDYYYDN',
  'NDDDDDYDDDDDN',
  '.NDDDYYYDDDN.',
  '.NDDDDDDDDDN.',
  '..NNDDDDDNN..',
  '....NNNNN....',
];

/// La cámara que graba la audiencia, arriba a la derecha, con su luz encendida.
const _camara = ['NNNNNN..', 'NKKKKNN.', 'NrcKKKcN', 'NKKKKNN.', 'NNNNNN..', '..NN....', '.NNNN...'];

/// El fondo de la sala del Juzgado de Menores: pared de piedra clara con dos ventanas con cortinas azules, la balanza
/// de la justicia sobre el estrado, una puerta al fondo, la cámara que graba, zócalo y suelo de madera, la tarima del
/// estrado, una alfombra azul en el pasillo y la barandilla del público, con un cordón que cierra el paso: hoy no hay
/// público.
@visibleForTesting
List<String> pintarSalaMenores() {
  final l = LienzoPixel(_anchoSala, _altoSala, 'p');
  // Sillares: una junta clara cada 8 filas y las verticales al tresbolillo.
  for (var y = 6; y < _suelo - 14; y += 8) {
    l.lineaH(0, y, _anchoSala, 'P');
    for (var x = (y ~/ 8).isEven ? 0 : 10; x < _anchoSala; x += 20) {
      l.lineaV(x, y + 1, 7, 'P');
    }
  }
  // Moldura del techo y zócalo de madera con cuarterones.
  const zocalo = _suelo - 14;
  l
    ..rect(0, 0, _anchoSala, 2, 'P')
    ..lineaH(0, 2, _anchoSala, 'o')
    ..rect(0, zocalo, _anchoSala, 14, 'm')
    ..lineaH(0, zocalo, _anchoSala, 'T')
    ..lineaH(0, zocalo + 1, _anchoSala, 'o');
  for (var x = 2; x < _anchoSala; x += 16) {
    l
      ..marco(x, zocalo + 3, 13, 8, 't')
      ..lineaH(x + 1, zocalo + 4, 11, 'o');
  }
  l
    ..lineaH(0, _suelo - 2, _anchoSala, 't')
    ..lineaH(0, _suelo - 1, _anchoSala, 'T')
    // Suelo de tablas, con las juntas al tresbolillo.
    ..rect(0, _suelo, _anchoSala, _altoSala - _suelo, 'm')
    ..lineaH(0, _suelo, _anchoSala, 'N');
  for (var y = _suelo + 6; y < _altoSala; y += 6) {
    l.lineaH(0, y, _anchoSala, 't');
  }
  var tabla = 0;
  for (var y = _suelo + 1; y < _altoSala; y += 6, tabla++) {
    for (var x = (tabla * 17) % 32; x < _anchoSala; x += 32) {
      l.lineaV(x, y, 5, 't');
    }
  }
  // Alfombra azul con ribete amarillo en el pasillo, de la barandilla al atril.
  l
    ..rect(66, 70, 28, _altoSala - 70, 'A')
    ..lineaV(66, 70, _altoSala - 70, 'D')
    ..lineaV(93, 70, _altoSala - 70, 'D')
    ..lineaV(68, 71, _altoSala - 71, 'Y')
    ..lineaV(91, 71, _altoSala - 71, 'Y')
    ..lineaH(66, 70, 28, 'D')
    ..lineaH(68, 71, 24, 'Y');
  // Ventanas con cortinas, la balanza, la puerta y la cámara.
  _ventana(l, 24, 7, 14, 20);
  _ventana(l, 122, 7, 14, 20);
  _cortina(l, 18, 4, 27);
  _cortina(l, 37, 4, 27, espejo: true);
  _cortina(l, 116, 4, 27);
  _cortina(l, 135, 4, 27, espejo: true);
  l
    ..lineaH(16, 3, 28, 'N')
    ..lineaH(114, 3, 28, 'N')
    ..pegar(_emblema, 74, 1);
  _puerta(l, 3, 12, 11, _suelo - 12);
  l
    ..pegar(_camara, 150, 4)
    // Tarima del estrado.
    ..rect(30, _suelo, 100, 5, 'm')
    ..lineaH(30, _suelo, 100, 'o')
    ..lineaH(30, _suelo + 4, 100, 'T')
    ..lineaV(29, _suelo, 5, 'N')
    ..lineaV(130, _suelo, 5, 'N');
  _pintarBarandilla(l);
  _pintarCordon(l);
  return l.filas;
}

/// Ventana alta con el remate en escalón, cielo con una nube y el marco blanco en cruz.
void _ventana(LienzoPixel l, int x, int y, int ancho, int alto) {
  l
    ..rect(x, y + 2, ancho, alto - 2, 'c')
    ..rect(x + 2, y, ancho - 4, 2, 'c')
    ..rect(x + 1, y + 1, ancho - 2, 1, 'c')
    ..rect(x + 1, y + 3, ancho - 2, 6, 'h')
    ..pegar(const ['..WW...', '.WhhWW.', 'WhhhhhW'], x + 2, y + 9);
  for (var j = 2; j < alto; j++) {
    l
      ..punto(x - 1, y + j, 'N')
      ..punto(x + ancho, y + j, 'N');
  }
  l
    ..lineaH(x + 2, y - 1, ancho - 4, 'N')
    ..punto(x + 1, y, 'N')
    ..punto(x + ancho - 2, y, 'N')
    ..punto(x, y + 1, 'N')
    ..punto(x + ancho - 1, y + 1, 'N')
    ..lineaV(x + ancho ~/ 2, y, alto, 'W')
    ..lineaH(x, y + alto ~/ 2, ancho, 'W')
    ..lineaH(x - 2, y + alto, ancho + 4, 'N')
    ..lineaH(x - 1, y + alto - 1, ancho + 2, 'P');
}

/// Cortina azul de [alto] filas, recogida con un lazo amarillo; con [espejo], la que va a la derecha de la ventana.
void _cortina(LienzoPixel l, int x, int y, int alto, {bool espejo = false}) {
  for (var j = 0; j < alto; j++) {
    // Ancha arriba, estrecha donde se recoge y un poco más ancha abajo.
    final ancho = j * 100 < alto * 55 ? 5 : (j * 100 < alto * 70 ? 3 : 4);
    for (var i = 0; i < ancho; i++) {
      final color = switch (i) {
        0 => 'N',
        1 => 'a',
        _ when i == ancho - 1 => 'D',
        _ => 'A',
      };
      l.punto(x + (espejo ? ancho - 1 - i : i), y + j, color);
    }
  }
  l.lineaH(espejo ? x + 1 : x, y + alto * 55 ~/ 100, 4, 'Y');
}

void _puerta(LienzoPixel l, int x, int y, int ancho, int alto) {
  l
    ..rect(x, y, ancho, alto, 'm')
    ..marco(x - 1, y - 1, ancho + 2, alto + 1, 'N')
    ..marco(x + 2, y + 2, ancho - 4, alto ~/ 2 - 3, 't')
    ..marco(x + 2, y + alto ~/ 2 + 1, ancho - 4, alto ~/ 2 - 3, 't')
    ..lineaV(x + ancho - 1, y, alto, 't')
    ..punto(x + ancho - 4, y + alto ~/ 2, 'Y')
    ..punto(x + ancho - 4, y + alto ~/ 2 + 1, 'o');
}

/// La barandilla de madera que separa la sala del público, con la puerta abierta en el pasillo.
void _pintarBarandilla(LienzoPixel l) {
  const y = _barandilla;
  for (final (desde, hasta) in const [(0, 64), (96, _anchoSala)]) {
    final largo = hasta - desde;
    l
      ..rect(desde, y, largo, 2, 'm')
      ..lineaH(desde, y - 1, largo, 'N')
      ..lineaH(desde, y, largo, 'o')
      ..lineaH(desde, y + 2, largo, 'T');
    for (var x = desde + 1; x < hasta - 1; x += 4) {
      l
        ..rect(x, y + 3, 2, 5, 't')
        ..lineaV(x + 2, y + 3, 5, 'T');
    }
    l.lineaH(desde, y + 8, largo, 'T');
  }
  for (final x in const [63, 96]) {
    l
      ..rect(x - 1, y - 3, 3, 12, 'm')
      ..marco(x - 2, y - 4, 5, 13, 'N')
      ..punto(x, y - 3, 'y');
  }
}

/// Sin público: un cordón de terciopelo entre dos postes dorados cierra el paso del pasillo.
void _pintarCordon(LienzoPixel l) {
  const y = _barandilla;
  for (final x in const [68, 91]) {
    l
      ..rect(x, y - 2, 2, 9, 'Y')
      ..lineaV(x + 1, y - 1, 8, 'o')
      ..marco(x - 1, y - 3, 4, 11, 'N')
      ..rect(x - 1, y - 5, 4, 2, 'Y')
      ..marco(x - 2, y - 6, 6, 4, 'N')
      ..rect(x - 2, y + 7, 6, 2, 'N');
  }
  const caida = [0, 1, 1, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 2, 2, 2, 1, 1, 0];
  for (var i = 0; i < caida.length; i++) {
    l
      ..punto(71 + i, y - 1 + caida[i], 'r')
      ..punto(71 + i, y + caida[i], 'R');
  }
}
