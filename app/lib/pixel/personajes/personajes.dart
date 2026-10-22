/// Los personajes de «Vive el caso» en pixel art: los de los tres casos oficiales (Lucía, Sergio y Sara), las
/// personas del juzgado y la mascota Tut.
///
/// ```dart
/// import 'package:tuturno/pixel/personajes/personajes.dart';
///
/// SpritePixel(sprite: PersonajesPixel.jueza, alto: 120, etiqueta: 'La jueza');
/// ElementoEscena(sprite: PersonajesPixel.porId('lucia')!, x: 80, y: 90, id: 'lucia', resaltado: true);
/// final id = PersonajesPixel.buscar('Ana, la psicóloga'); // 'ana': de los nombres del contenido a un sprite
/// final fiscal = PersonajesPixel.buscar('El fiscal', lugar: 'fiscalia'); // 'fiscal-despacho': sin toga
/// final padres = PersonajesPixel.buscarTodos('Sus padres'); // ['padre-sergio', 'madre-sergio']
/// ```
///
/// Para montar una escena entera del contenido (lugar y personajes) ya hay `EscenaCasoPixel`, en lib/pixel/escenas.
///
/// Cada personaje tiene tres fotogramas con la animación en reposo de [AnimacionPixel.reposo]: 0, quieto (la pose de
/// descanso, la que se ve con «reducir animaciones»); 1, respira (la cabeza y los hombros bajan un píxel); y 2,
/// parpadea. Tut, en vez de respirar, flota: sube un píxel y su sombra se queda en el suelo.
///
/// Para los diálogos, [PersonajesPixel.retrato] da la cabeza y los hombros de cada uno, con los ojos a la misma altura.
///
/// La rejilla es la de lib/pixel/LEEME.md: niños de 24 × 32, adolescentes de 24 × 34, adultos de 24 × 36, el testigo
/// en su silla de ruedas de 28 × 32 y Tut de 24 × 22. El ancla es la de siempre (los pies: el centro del borde de
/// abajo), y la última fila es la sombra en el suelo.
///
/// Dos ids son el mismo personaje en otra situación: 'fiscal-despacho' es el fiscal sin toga, en su despacho (la toga
/// es para la audiencia, LOPJ, art. 187.1), y 'tut-feliz' es Tut sonriendo (la expresión «feliz» de MascotaTut).
library;

import 'package:flutter/foundation.dart';

import '../motor/motor.dart';

part 'caso_lucia.dart';
part 'caso_sara.dart';
part 'caso_sergio.dart';
part 'juzgado.dart';
part 'tut.dart';

/// La ficha de un personaje: su [id], su [nombre] para la pantalla, una [descripcion] para los lectores de pantalla y
/// su [sprite].
@immutable
class PersonajePixel {
  const PersonajePixel({required this.id, required this.nombre, required this.descripcion, required this.sprite});

  /// Identificador estable, en minúsculas y sin tildes («lucia», «abogada-victima»).
  final String id;

  /// Cómo se le llama en el juego («Lucía», «La jueza»), por ejemplo en la placa de un diálogo.
  final String nombre;

  /// Quién es y cómo se le reconoce, para la etiqueta de Semantics («La jueza, con toga negra y medalla»).
  final String descripcion;

  final Sprite sprite;

  @override
  String toString() => 'PersonajePixel($id)';
}

/// El registro de los personajes: [ids], [porId], [ficha], [todos], [buscar], [retrato] y un acceso directo por
/// personaje ([lucia], [jueza], [tut]…).
abstract final class PersonajesPixel {
  /// Todos los ids, en el orden de [todos]: los tres casos, el juzgado y Tut.
  static const ids = <String>[
    'lucia',
    'tutora',
    'elena',
    'ana',
    'sergio',
    'padre-sergio',
    'madre-sergio',
    'laura',
    'sara',
    'amiga-sara',
    'jueza',
    'fiscal',
    'fiscal-despacho',
    'abogada-victima',
    'abogado-defensa',
    'letrada',
    'policia',
    'investigada',
    'testigo',
    'tut',
    'tut-feliz',
  ];

  /// Las fichas de todos los personajes, en el orden de [ids].
  static final List<PersonajePixel> todos = List.unmodifiable([
    _fichaLucia,
    _fichaTutora,
    _fichaElena,
    _fichaAna,
    _fichaSergio,
    _fichaPadreSergio,
    _fichaMadreSergio,
    _fichaLaura,
    _fichaSara,
    _fichaAmigaSara,
    _fichaJueza,
    _fichaFiscal,
    _fichaFiscalDespacho,
    _fichaAbogadaVictima,
    _fichaAbogadoDefensa,
    _fichaLetrada,
    _fichaPolicia,
    _fichaInvestigada,
    _fichaTestigo,
    _fichaTut,
    _fichaTutFeliz,
  ]);

  static final Map<String, PersonajePixel> _porId = {for (final ficha in todos) ficha.id: ficha};

  /// El sprite del personaje [id], o null si no hay ninguno con ese id.
  static Sprite? porId(String id) => _porId[id]?.sprite;

  /// La ficha del personaje [id], o null si no hay ninguno con ese id.
  static PersonajePixel? ficha(String id) => _porId[id];

  /// Ancho y alto de los retratos, en píxeles del dibujo.
  static const anchoRetrato = 24;
  static const altoRetrato = 20;

  /// La fila de los retratos en la que quedan los ojos (la de su brillo): la misma para todos, para que las caras no
  /// bailen al cambiar de quien habla.
  static const filaOjosRetrato = 9;

  /// El retrato del personaje [id] para los diálogos, o null si no hay ninguno con ese id: la cabeza y los hombros, de
  /// [anchoRetrato] × [altoRetrato], con los ojos en la fila [filaOjosRetrato] y la misma animación que su sprite.
  /// Se recorta una sola vez y se guarda.
  static Sprite? retrato(String id) {
    final ficha = _porId[id];
    if (ficha == null) return null;
    return _retratos[id] ??= _recortarRetrato(ficha.sprite, columnas: _columnasRetrato[id]);
  }

  static final _retratos = <String, Sprite>{};

  /// Las columnas del sprite que entran en el retrato, si no son todas: del testigo, solo él (las mismas que se mueven
  /// al respirar), sin las empuñaduras ni las ruedas de la silla, que en el recorte parecían barrotes.
  static const _columnasRetrato = <String, (int, int)>{'testigo': (7, 21)};

  static Sprite _recortarRetrato(Sprite sprite, {(int, int)? columnas}) {
    final quieto = sprite.fotogramas.first;
    final parpadea = sprite.fotogramas.last;
    // Los ojos están en la primera fila que cambia al parpadear (si nada cambia, se recorta desde arriba).
    var ojos = 0;
    while (ojos < quieto.length && quieto[ojos] == parpadea[ojos]) {
      ojos++;
    }
    if (ojos == quieto.length) ojos = filaOjosRetrato;
    final arriba = ojos - filaOjosRetrato;
    final izquierda = (sprite.ancho - anchoRetrato) ~/ 2;
    final vacia = '.' * anchoRetrato;
    final (desde, hasta) = columnas ?? (0, sprite.ancho);
    String fila(String original) => String.fromCharCodes([
      for (var x = izquierda; x < izquierda + anchoRetrato; x++)
        x >= desde && x < hasta ? original.codeUnitAt(x) : 0x2E, // «.»
    ]);
    List<String> recortar(List<String> filas) => [
      for (var y = arriba; y < arriba + altoRetrato; y++) y < 0 || y >= filas.length ? vacia : fila(filas[y]),
    ];
    return Sprite.animado('${sprite.nombre} (retrato)', [
      for (final filas in sprite.fotogramas) recortar(filas),
    ], animacion: sprite.animacion);
  }

  /// El id del personaje al que se refiere un nombre como los de las escenas del contenido («Su tía Elena», «Ana, la
  /// psicóloga», «El fiscal», «Su tutora»), o null si no hay ningún personaje para él. No distingue mayúsculas ni
  /// tildes. Con [lugar] (el de la escena, tal como viene en el contenido), el fiscal va sin toga fuera de la sala:
  /// en la Fiscalía es 'fiscal-despacho'. Para un plural («Sus padres»), [buscarTodos].
  static String? buscar(String nombre, {String? lugar}) {
    final palabras = _palabras(nombre);
    bool hay(String raiz) => palabras.any((palabra) => palabra.startsWith(raiz));
    // De lo más concreto a lo más general: «la amiga de Sara» antes que «Sara», «el abogado de la persona
    // investigada» antes que «la persona investigada» y «el padre de Sergio» antes que «Sergio».
    if (palabras.contains('tut')) return 'tut';
    if (hay('amig')) return 'amiga-sara';
    if (hay('tutor') || hay('maestr') || hay('profe')) return 'tutora';
    if (hay('madre') || palabras.contains('mama')) return 'madre-sergio';
    if (hay('padre') || palabras.contains('papa')) return 'padre-sergio';
    if (hay('abogad') || hay('letrad')) {
      if (hay('defens') || hay('investigad') || hay('acusad')) return 'abogado-defensa';
      // «La letrada» a secas es la de la Administración de Justicia; «el letrado de la víctima», un abogado.
      return hay('abogad') || hay('victim') ? 'abogada-victima' : 'letrada';
    }
    if (hay('juez') || hay('juec')) return 'jueza';
    if (hay('fiscal')) return lugar != null && _esDespacho(lugar) ? 'fiscal-despacho' : 'fiscal';
    if (hay('polic') || hay('agente')) return 'policia';
    if (hay('investigad')) return 'investigada';
    if (hay('testig')) return 'testigo';
    if (hay('psicolog') || hay('psicosocial') || palabras.contains('ana')) return 'ana';
    if (hay('coordinador') || hay('bienestar') || palabras.contains('laura')) return 'laura';
    if (palabras.contains('tia') || palabras.contains('elena')) return 'elena';
    if (palabras.contains('lucia')) return 'lucia';
    if (palabras.contains('sergio')) return 'sergio';
    if (palabras.contains('sara')) return 'sara';
    return null;
  }

  /// Los ids de todos los personajes a los que se refiere [nombre]: dos para «Sus padres» o «Los padres de Sergio»
  /// (el padre y la madre) y para «Los abogados» (las dos partes); para el resto, el de [buscar] (o ninguno).
  static List<String> buscarTodos(String nombre, {String? lugar}) {
    final palabras = _palabras(nombre);
    if (palabras.contains('padres')) return const ['padre-sergio', 'madre-sergio'];
    if (palabras.contains('abogados')) return const ['abogada-victima', 'abogado-defensa'];
    final id = buscar(nombre, lugar: lugar);
    return id == null ? const [] : [id];
  }

  static Set<String> _palabras(String texto) =>
      _normalizar(texto).split(RegExp('[^a-z0-9]+')).where((palabra) => palabra.isNotEmpty).toSet();

  /// Si [lugar] es un despacho (la Fiscalía): ahí nadie lleva toga.
  static bool _esDespacho(String lugar) {
    final palabras = _palabras(lugar.replaceAllMapped(RegExp('([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}'));
    return palabras.any((palabra) => palabra.startsWith('fiscal') || palabra.startsWith('despacho'));
  }

  static String _normalizar(String texto) {
    const con = 'áàäâéèëêíìïîóòöôúùüûñç';
    const sin = 'aaaaeeeeiiiioooouuuunc';
    final minusculas = texto.toLowerCase();
    final salida = StringBuffer();
    for (final caracter in minusculas.split('')) {
      final i = con.indexOf(caracter);
      salida.write(i < 0 ? caracter : sin[i]);
    }
    return salida.toString();
  }

  /// Lucía, 11 años, la protagonista del caso oficial.
  static Sprite get lucia => _fichaLucia.sprite;

  /// La tutora de Lucía, en el colegio.
  static Sprite get tutora => _fichaTutora.sprite;

  /// Elena, la tía de Lucía: la persona adulta de su confianza.
  static Sprite get elena => _fichaElena.sprite;

  /// Ana, psicóloga del equipo psicosocial del juzgado.
  static Sprite get ana => _fichaAna.sprite;

  /// Sergio, 13 años.
  static Sprite get sergio => _fichaSergio.sprite;

  /// El padre de Sergio.
  static Sprite get padreSergio => _fichaPadreSergio.sprite;

  /// La madre de Sergio.
  static Sprite get madreSergio => _fichaMadreSergio.sprite;

  /// Laura, coordinadora de bienestar y protección del instituto.
  static Sprite get laura => _fichaLaura.sprite;

  /// Sara, casi 16 años.
  static Sprite get sara => _fichaSara.sprite;

  /// La amiga de Sara.
  static Sprite get amigaSara => _fichaAmigaSara.sprite;

  static Sprite get jueza => _fichaJueza.sprite;

  /// El fiscal con toga (en la sala de vistas, en la audiencia).
  static Sprite get fiscal => _fichaFiscal.sprite;

  /// El mismo fiscal en su despacho de la Fiscalía, con traje y sin toga.
  static Sprite get fiscalDespacho => _fichaFiscalDespacho.sprite;
  static Sprite get abogadaVictima => _fichaAbogadaVictima.sprite;
  static Sprite get abogadoDefensa => _fichaAbogadoDefensa.sprite;

  /// La letrada de la Administración de Justicia.
  static Sprite get letrada => _fichaLetrada.sprite;

  static Sprite get policia => _fichaPolicia.sprite;

  /// La persona investigada: una figura neutra.
  static Sprite get investigada => _fichaInvestigada.sprite;

  /// Un testigo adulto, en silla de ruedas.
  static Sprite get testigo => _fichaTestigo.sprite;

  /// Tut, la mascota de TuTurno, con su cara de siempre (la expresión neutral de MascotaTut).
  static Sprite get tut => _fichaTut.sprite;

  /// Tut sonriendo (la expresión «feliz» de MascotaTut).
  static Sprite get tutFeliz => _fichaTutFeliz.sprite;
}

/// Un sprite de personaje con sus tres fotogramas a partir de su pose quieta, [filas]:
///
/// 0. Quieto.
/// 1. Respira: todo lo que está por encima de la fila [pecho] baja un píxel (esa fila desaparece), solo entre las
///    columnas [desde] (incluida) y [hasta] (sin incluir): así la silla del testigo no se mueve con él. [pecho] es una
///    fila del cuerpo que se puede quitar sin que se note (mejor si es igual que la de debajo).
/// 2. Parpadea: en la fila [ojos], la de arriba de los ojos, cada brillo con su ojo («WN») se vuelve [piel]; la fila
///    de debajo, que es la del ojo, se queda como una raya.
///
/// [ms] es lo que dura cada respiración: cada personaje lleva la suya para que no respiren todos a la vez.
Sprite _personaje(
  String nombre, {
  required List<String> filas,
  required int ojos,
  required int pecho,
  required String piel,
  int ms = 800,
  int desde = 0,
  int? hasta,
}) => Sprite.animado(nombre, [
  filas,
  _respirar(filas, pecho, desde: desde, hasta: hasta),
  _cerrarOjos(filas, ojos, piel),
], animacion: AnimacionPixel.reposo(ms: ms));

/// [filas] con lo que hay por encima de la fila [pecho] un píxel más abajo, entre las columnas [desde] y [hasta].
List<String> _respirar(List<String> filas, int pecho, {int desde = 0, int? hasta}) {
  final fin = hasta ?? filas.first.length;
  return [
    for (var y = 0; y < filas.length; y++)
      y > pecho
          ? filas[y]
          : filas[y].replaceRange(desde, fin, y == 0 ? '.' * (fin - desde) : filas[y - 1].substring(desde, fin)),
  ];
}

/// [filas] con los ojos de la fila [fila] cerrados: cada «WN» (el brillo y el ojo) pasa a ser [piel].
List<String> _cerrarOjos(List<String> filas, int fila, String piel) {
  final cerrada = filas[fila].replaceAll('WN', piel * 2);
  assert(filas[fila].split('WN').length == 3, 'La fila $fila no tiene los dos ojos («WN»): ${filas[fila]}');
  return retocar(filas, {fila: cerrada});
}
