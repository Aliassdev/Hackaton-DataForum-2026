import '../motor/motor.dart';
import 'escenario_pixel.dart';
import 'teselas.dart';

/// Los sitios de la sala de vistas: dónde van los pies de cada personaje, en píxeles del fondo (160 × 96). Los que se
/// sientan detrás de un mueble (el estrado, las mesas, el sitio de quien declara) tienen los pies escondidos: con
/// [EscenarioPixel.componer], el mueble se pinta encima y se les ve de la cintura para arriba.
enum PuestoVista {
  /// En el centro del estrado, delante del escudo.
  jueza('jueza', 'La jueza', 80, 50),

  /// En el estrado, a la derecha de la jueza (vista desde el público): la letrada de la Administración de Justicia.
  letrada('letrada', 'La letrada', 109, 51),

  /// En la mesa de la izquierda, la más cercana a la pared.
  fiscal('fiscal', 'La fiscal', 18, 72),

  /// En la mesa de la izquierda, junto a la fiscal: la acusación particular.
  abogadaVictima('abogada_victima', 'La abogada de la víctima', 43, 72),

  /// En la mesa de la derecha, junto a la pared.
  abogadoDefensa('abogado_defensa', 'El abogado de la defensa', 142, 72),

  /// En la mesa de la derecha, junto a su abogado. Una figura neutra.
  personaInvestigada('persona_investigada', 'La persona investigada', 117, 72),

  /// En el centro, en el sitio de quien declara, de cara al estrado.
  testigo('testigo', 'Quien declara', 80, 83),

  /// De pie a la derecha, junto a la puerta.
  policia('policia', 'La policía', 148, 86),

  /// Sentado en el primer banco del público, a la izquierda: se le ve de los hombros para arriba, por encima del
  /// respaldo (los pies quedan fuera de la imagen).
  publico('publico', 'El público', 24, 100);

  const PuestoVista(this.clave, this.nombre, this.x, this.y);

  /// La clave en [EscenarioPixel.puestos]: «abogada_victima».
  final String clave;

  /// Quién se pone ahí, para las personas.
  final String nombre;

  final int x;
  final int y;

  PuntoPixel get punto => (x: x, y: y);
}

/// La sala de vistas, al estilo de las de España: al fondo, el estrado (una tarima con la mesa de la jueza y la de la
/// letrada) y el escudo encima; a la izquierda, la mesa de la fiscal y de la abogada de la víctima; a la derecha, la
/// del abogado de la defensa y la persona investigada; en el centro, el sitio de quien declara, y delante, los bancos
/// del público. Los sitios de cada uno están en [PuestoVista].
final escenarioSalaVistas = EscenarioPixel(
  lugar: 'sala_vistas',
  descripcion:
      'La sala de vistas: al fondo, el estrado con la mesa de la jueza y el escudo; a los lados, las mesas de la '
      'fiscal y de los abogados; en el centro, el sitio de quien declara, y delante, los bancos del público.',
  fondo: Sprite('sala_vistas', _salaVistas.fondo),
  delante: [for (final mueble in _salaVistas.muebles) piezaEn(Sprite(mueble.nombre, mueble.filas), mueble.x, mueble.y)],
  puestos: {
    for (final puesto in PuestoVista.values) puesto.clave: puesto.punto,
    'izquierda': (x: 40, y: 84),
    'centro': (x: 80, y: 95),
    'derecha': (x: 120, y: 84),
  },
);

const _suelo = 58;

typedef _Mueble = ({String nombre, int x, int y, List<String> filas});

final _salaVistas = _pintarSalaVistas();

({List<String> fondo, List<_Mueble> muebles}) _pintarSalaVistas() {
  final l = LienzoPixel(anchoFondo, altoFondo, 'h')
    ..rect(0, 0, anchoFondo, 3, 'c')
    ..lineaH(0, 3, anchoFondo, 'W')
    ..zocalo(36, _suelo, color: 'c', sombra: 'a', luz: 'h', moldura: 'a', panel: 18, desfase: 2);
  _suelos(l);

  // Ventanas altas a los lados.
  l
    ..ventana(6, 9, 22, 22, hojas: 2, paisaje: PaisajePixel.arboles, alfeizar: false, semilla: 3)
    ..ventana(132, 9, 22, 22, hojas: 2, paisaje: PaisajePixel.arboles, alfeizar: false, semilla: 12);

  // El fondo de madera del estrado, con el escudo.
  l
    ..caja(36, 4, 88, 48, 't', 'T')
    ..lineaH(37, 5, 86, 'm');
  for (var x = 41; x < 122; x += 6) {
    l.lineaV(x, 6, 45, 'T');
  }
  l.pegar(_escudo, 71, 0);

  // La tarima.
  l
    ..caja(26, 49, 108, 9, 'm')
    ..lineaH(27, 50, 106, 'u')
    ..lineaH(27, 52, 106, 't')
    ..lineaH(26, 57, 108, 'N');
  for (var x = 34; x < 130; x += 12) {
    l.lineaV(x, 53, 4, 't');
  }

  // Las sillas, detrás de los muebles.
  _sillaAlta(l, 72, 18, 16, 'D');
  _sillaAlta(l, 102, 27, 13, 'A');
  for (final x in [18, 43, 117, 142]) {
    _sillaAlta(l, x - 6, 50, 12, 'A');
  }
  _sillaAlta(l, 74, 64, 12, 'A');

  final muebles = <_Mueble>[
    (nombre: 'sala_vistas: estrado', x: 36, y: 28, filas: _estrado()),
    (nombre: 'sala_vistas: mesa de la acusación', x: 4, y: 56, filas: _mesaLateral(izquierda: true)),
    (nombre: 'sala_vistas: mesa de la defensa', x: 102, y: 56, filas: _mesaLateral(izquierda: false)),
    (nombre: 'sala_vistas: sitio de quien declara', x: 67, y: 69, filas: _mesaDeclarante()),
    (nombre: 'sala_vistas: banco del público (izquierda)', x: -2, y: 86, filas: _bancoPublico()),
    (nombre: 'sala_vistas: banco del público (derecha)', x: 98, y: 86, filas: _bancoPublico()),
  ];
  for (final mueble in muebles) {
    l.pegar(mueble.filas, mueble.x, mueble.y);
  }
  return (fondo: l.filas, muebles: muebles);
}

/// Suelo de baldosas grises y, en el centro, una moqueta azul desde el estrado hasta el pasillo del público.
void _suelos(LienzoPixel l) {
  l
    ..baldosas(_suelo, clara: 'g', oscura: 'h', lado: 16, altoFila: 3)
    ..rect(22, _suelo, 116, 30, 'a')
    ..rect(64, _suelo + 30, 32, altoFondo - _suelo - 30, 'a')
    ..marco(23, _suelo + 1, 114, 28, 'c')
    ..lineaV(65, _suelo + 29, altoFondo - _suelo - 29, 'c')
    ..lineaV(94, _suelo + 29, altoFondo - _suelo - 29, 'c')
    ..lineaH(22, _suelo, 116, 'A');
}

/// Una silla de respaldo alto de [ancho] desde ([x], [y]) hasta el suelo de la fila en que se apoya (no se ve: la
/// tapa el mueble de delante).
void _sillaAlta(LienzoPixel l, int x, int y, int ancho, String color) {
  final luz = color == 'D' ? 'A' : 'a';
  l
    ..redondo(x, y, ancho, 15, color, contorno: 'N', radio: 2)
    ..lineaH(x + 2, y + 1, ancho - 4, luz)
    ..lineaV(x + 1, y + 3, 9, luz);
}

/// El estrado (88 × 24): la mesa de la jueza en medio, más alta (tablero en la fila 6), y a los lados las de la
/// letrada y del otro sitio (tablero en la fila 10), todas de madera con cuarterones. Encima, micrófonos y papeles.
List<String> _estrado() {
  const alto = 24;
  final l = LienzoPixel(88, alto);
  for (final (x, ancho, arriba) in [(0, 26, 10), (62, 26, 10), (24, 40, 6)]) {
    l
      ..caja(x, arriba, ancho, 3, 'm')
      ..lineaH(x + 1, arriba + 1, ancho - 2, 'u')
      ..caja(x + 1, arriba + 2, ancho - 2, alto - arriba - 2, 'm')
      ..lineaV(x + ancho - 3, arriba + 3, alto - arriba - 4, 't');
    for (var px = x + 4; px + 8 < x + ancho - 2; px += 10) {
      l
        ..marco(px, arriba + 5, 8, alto - arriba - 8, 't')
        ..lineaH(px + 1, alto - 4, 7, 'u');
    }
  }
  // Una moldura dorada en la mesa de la jueza.
  l
    ..lineaH(25, 9, 38, 'o')
    ..lineaH(26, 10, 36, 'Y');
  // Micrófonos: la jueza, la letrada y el otro sitio.
  l
    ..pegar(_microfono, 43, 0)
    ..pegar(_microfono, 70, 4)
    ..pegar(_microfono, 12, 4);
  // Papeles y una carpeta.
  l
    ..pegar(['WWWWWW', 'WGGGGh'], 30, 4)
    ..caja(5, 8, 9, 3, 'A')
    ..lineaH(6, 9, 7, 'a')
    ..pegar(['WWWWW', 'WGGGh'], 76, 8);
  return l.filas;
}

const _microfono = ['.NN.', 'NKKN', '.NN.', '..N.', '..N.', '.NNN'];

/// Una mesa lateral (54 × 20, el tablero en la fila 6) con carpetas, papeles, un vaso y dos micrófonos.
List<String> _mesaLateral({required bool izquierda}) {
  const ancho = 54;
  final l = LienzoPixel(ancho, 20)
    ..caja(0, 6, ancho, 3, 'm')
    ..lineaH(1, 7, ancho - 2, 'u')
    ..caja(1, 8, ancho - 2, 12, 'm')
    ..lineaV(ancho - 3, 9, 10, 't');
  for (var x = 4; x < ancho - 6; x += 12) {
    l
      ..marco(x, 11, 10, 7, 't')
      ..lineaH(x + 1, 17, 9, 'u');
  }
  // Encima: dos micrófonos (uno por sitio), carpetas, papeles y un vaso.
  for (final x in [12, 37]) {
    l.pegar(_microfono, x, 1);
  }
  l
    ..caja(izquierda ? 2 : 41, 4, 10, 3, izquierda ? 'Y' : 'r')
    ..lineaH(izquierda ? 3 : 42, 5, 8, izquierda ? 'y' : 's')
    ..pegar(['WWWWWW', 'WGGGGh'], izquierda ? 22 : 20, 5)
    ..pegar(vaso, izquierda ? 47 : 4, 2)
    ..caja(izquierda ? 29 : 28, 5, 6, 2, 'A');
  return l.filas;
}

/// El sitio de quien declara (26 × 17, el tablero en la fila 7): una mesa pequeña con un micrófono y un vaso de agua.
List<String> _mesaDeclarante() {
  const ancho = 26;
  final l = LienzoPixel(ancho, 17)
    ..caja(0, 7, ancho, 3, 'm')
    ..lineaH(1, 8, ancho - 2, 'u')
    ..caja(1, 9, ancho - 2, 8, 'm')
    ..lineaV(ancho - 3, 10, 6, 't')
    ..marco(4, 11, ancho - 9, 4, 't')
    ..pegar(_microfono, 11, 2)
    ..pegar(vaso, 19, 3);
  return l.filas;
}

/// Un banco del público visto desde atrás: el respaldo de madera y el asiento (64 × 10). El dibujo mide 20 de alto:
/// las 10 filas de abajo, transparentes, son lo que queda fuera de la imagen (las patas, más cerca de nosotros), y así
/// su borde de abajo, el que cuenta para [EscenarioPixel.componer], queda por debajo del público sentado detrás.
List<String> _bancoPublico() {
  const ancho = 64;
  final l = LienzoPixel(ancho, 20)
    ..caja(0, 0, ancho, 4, 'm')
    ..lineaH(1, 1, ancho - 2, 'u')
    ..lineaH(1, 3, ancho - 2, 't')
    ..caja(0, 5, ancho, 3, 'm')
    ..lineaH(1, 6, ancho - 2, 't');
  for (var x = 6; x < ancho; x += 18) {
    l
      ..rect(x, 4, 2, 1, 'K')
      ..rect(x, 8, 2, 2, 'K')
      ..lineaV(x - 1, 8, 2, 'N')
      ..lineaV(x + 2, 8, 2, 'N');
  }
  return l.filas;
}

/// El escudo de España sencillo (19 × 15): corona, cuarteles (Castilla, León, Aragón y Navarra), Granada en la punta,
/// el óvalo azul en el centro y las columnas a los lados con su cinta.
const _escudo = [
  '.........Y.........',
  '........YoY........',
  '......N.NYN.N......',
  '.....NYNYYYNYN.....',
  '.....NYYYYYYYN.....',
  '.Y...NRYvYvYRN...Y.',
  'NYN..NNNNNNNNN..NYN',
  'NWN..NRRRNWWWN..NWN',
  'RWR..NRYRNWLWN..RWR',
  'NWN..NRRRNWWWN..NWN',
  'NWN..NNNNANNNN..NWN',
  'NWN..NYRYNRYRN..NWN',
  'NWN..NYRYNRRRN..NWN',
  'NgN...NWvrvWN...NgN',
  'NNN....NNNNN....NNN',
];
