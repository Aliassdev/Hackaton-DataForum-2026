import 'package:flutter/widgets.dart';

import 'estilo_pixel.dart';
import 'iconos_pixel.dart';
import 'pintura_pixel.dart';

/// Letra de rótulo de 5 × 7 celdas para números y códigos cortos («2/5», «N.º 3», «A-07»), dibujada en la rejilla
/// pixel del kit.
///
/// En Pixelify Sans, a estos tamaños, el «5» es igual que la «S», el «8» que la «B» y el «0» que la «O»: aquí el 5
/// tiene el trazo de arriba recto y la esquina en ángulo, la B el lomo recto y el 0 una barra. Tiene cifras,
/// mayúsculas (las minúsculas y las tildes se leen como mayúsculas sin tilde; la Ñ sí está) y `/ - . , : ! ? º +`.
/// Lo que no tiene se pinta como «?».
abstract final class LetraRotuloPixel {
  /// Alto de todas las letras, en celdas.
  static const alto = 7;

  /// El dibujo de [caracter].
  static GlifoPixel de(String caracter) {
    final directo = _glifos[caracter];
    if (directo != null) return directo;
    final mayuscula = caracter.toUpperCase();
    return _glifos[mayuscula] ?? _glifos[_sinTilde[mayuscula]] ?? _glifos['?']!;
  }

  /// Si [caracter] tiene dibujo propio (sin contar las minúsculas y las tildes, que se leen como mayúsculas).
  static bool tiene(String caracter) => _glifos.containsKey(caracter);

  static const _sinTilde = {'Á': 'A', 'À': 'A', 'É': 'E', 'È': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U'};

  static const Map<String, GlifoPixel> _glifos = {
    '0': GlifoPixel('0', ['.###.', '#...#', '#..##', '#.#.#', '##..#', '#...#', '.###.']),
    '1': GlifoPixel('1', ['..#..', '.##..', '..#..', '..#..', '..#..', '..#..', '.###.']),
    '2': GlifoPixel('2', ['.###.', '#...#', '....#', '...#.', '..#..', '.#...', '#####']),
    '3': GlifoPixel('3', ['.###.', '#...#', '....#', '..##.', '....#', '#...#', '.###.']),
    '4': GlifoPixel('4', ['...#.', '..##.', '.#.#.', '#..#.', '#####', '...#.', '...#.']),
    '5': GlifoPixel('5', ['#####', '#....', '####.', '....#', '....#', '#...#', '.###.']),
    '6': GlifoPixel('6', ['..##.', '.#...', '#....', '####.', '#...#', '#...#', '.###.']),
    '7': GlifoPixel('7', ['#####', '....#', '...#.', '..#..', '.#...', '.#...', '.#...']),
    '8': GlifoPixel('8', ['.###.', '#...#', '#...#', '.###.', '#...#', '#...#', '.###.']),
    '9': GlifoPixel('9', ['.###.', '#...#', '#...#', '.####', '....#', '...#.', '.##..']),
    'A': GlifoPixel('A', ['.###.', '#...#', '#...#', '#####', '#...#', '#...#', '#...#']),
    'B': GlifoPixel('B', ['####.', '#...#', '#...#', '####.', '#...#', '#...#', '####.']),
    'C': GlifoPixel('C', ['.###.', '#...#', '#....', '#....', '#....', '#...#', '.###.']),
    'D': GlifoPixel('D', ['####.', '#...#', '#...#', '#...#', '#...#', '#...#', '####.']),
    'E': GlifoPixel('E', ['#####', '#....', '#....', '####.', '#....', '#....', '#####']),
    'F': GlifoPixel('F', ['#####', '#....', '#....', '####.', '#....', '#....', '#....']),
    'G': GlifoPixel('G', ['.###.', '#...#', '#....', '#.###', '#...#', '#...#', '.###.']),
    'H': GlifoPixel('H', ['#...#', '#...#', '#...#', '#####', '#...#', '#...#', '#...#']),
    'I': GlifoPixel('I', ['.###.', '..#..', '..#..', '..#..', '..#..', '..#..', '.###.']),
    'J': GlifoPixel('J', ['..###', '...#.', '...#.', '...#.', '...#.', '#..#.', '.##..']),
    'K': GlifoPixel('K', ['#...#', '#..#.', '#.#..', '##...', '#.#..', '#..#.', '#...#']),
    'L': GlifoPixel('L', ['#....', '#....', '#....', '#....', '#....', '#....', '#####']),
    'M': GlifoPixel('M', ['#...#', '##.##', '#.#.#', '#.#.#', '#...#', '#...#', '#...#']),
    'N': GlifoPixel('N', ['#...#', '#...#', '##..#', '#.#.#', '#..##', '#...#', '#...#']),
    'Ñ': GlifoPixel('Ñ', ['.##.#', '#.##.', '#...#', '##..#', '#.#.#', '#..##', '#...#']),
    'O': GlifoPixel('O', ['.###.', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.']),
    'P': GlifoPixel('P', ['####.', '#...#', '#...#', '####.', '#....', '#....', '#....']),
    'Q': GlifoPixel('Q', ['.###.', '#...#', '#...#', '#...#', '#.#.#', '#..#.', '.##.#']),
    'R': GlifoPixel('R', ['####.', '#...#', '#...#', '####.', '#.#..', '#..#.', '#...#']),
    'S': GlifoPixel('S', ['.###.', '#...#', '#....', '.###.', '....#', '#...#', '.###.']),
    'T': GlifoPixel('T', ['#####', '..#..', '..#..', '..#..', '..#..', '..#..', '..#..']),
    'U': GlifoPixel('U', ['#...#', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.']),
    'V': GlifoPixel('V', ['#...#', '#...#', '#...#', '#...#', '#...#', '.#.#.', '..#..']),
    'W': GlifoPixel('W', ['#...#', '#...#', '#...#', '#.#.#', '#.#.#', '#.#.#', '.#.#.']),
    'X': GlifoPixel('X', ['#...#', '#...#', '.#.#.', '..#..', '.#.#.', '#...#', '#...#']),
    'Y': GlifoPixel('Y', ['#...#', '#...#', '.#.#.', '..#..', '..#..', '..#..', '..#..']),
    'Z': GlifoPixel('Z', ['#####', '....#', '...#.', '..#..', '.#...', '#....', '#####']),
    '/': GlifoPixel('/', ['....#', '....#', '...#.', '..#..', '.#...', '#....', '#....']),
    '-': GlifoPixel('-', ['...', '...', '...', '###', '...', '...', '...']),
    '+': GlifoPixel('+', ['.....', '..#..', '..#..', '#####', '..#..', '..#..', '.....']),
    '.': GlifoPixel('.', ['.', '.', '.', '.', '.', '.', '#']),
    ',': GlifoPixel(',', ['..', '..', '..', '..', '..', '.#', '#.']),
    ':': GlifoPixel(':', ['.', '.', '#', '.', '.', '#', '.']),
    '!': GlifoPixel('!', ['#', '#', '#', '#', '#', '.', '#']),
    '?': GlifoPixel('?', ['.###.', '#...#', '....#', '...#.', '..#..', '.....', '..#..']),
    'º': GlifoPixel('º', ['###', '#.#', '###', '...', '###', '...', '...']),
    ' ': GlifoPixel(' ', ['..', '..', '..', '..', '..', '..', '..']),
  };
}

/// Un número o un código corto con la [LetraRotuloPixel]: nítido, en la rejilla del kit y sin letras que se
/// confundan. Para la información que va en cifras: el contador de cartas, el número de una carta, el turno.
///
/// Cada celda mide una unidad pixel (por [escala]) y crece con la letra del sistema, a un número entero de píxeles
/// físicos. Sin [color], el del texto de alrededor. El lector de pantalla lee [semantica] o, si no hay, [texto].
class RotuloPixel extends StatelessWidget {
  const RotuloPixel(this.texto, {super.key, this.color, this.contorno, this.escala = 1, this.semantica});

  final String texto;
  final Color? color;

  /// Borde de una unidad alrededor de cada letra (suma una celda por cada lado).
  final Color? contorno;
  final int escala;
  final String? semantica;

  /// Ancho de [texto] en celdas (con una de separación entre letras).
  static int columnas(String texto) {
    final glifos = [for (final caracter in texto.characters) LetraRotuloPixel.de(caracter)];
    if (glifos.isEmpty) return 0;
    return glifos.fold(0, (suma, glifo) => suma + glifo.ancho) + glifos.length - 1;
  }

  /// El lado de una celda en [context], en píxeles lógicos.
  static double celda(BuildContext context, {int escala = 1}) => ajustarUnidad(
    unidadPixel(context) * escala * escalaTextoPixel(context),
    MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
  );

  @override
  Widget build(BuildContext context) {
    final lado = celda(context, escala: escala);
    final color = this.color ?? DefaultTextStyle.of(context).style.color ?? ColoresUiPixel.noche;
    final glifos = [for (final caracter in texto.characters) LetraRotuloPixel.de(caracter)];
    final borde = contorno == null ? 0 : 1;
    return Semantics(
      label: semantica ?? texto,
      child: ExcludeSemantics(
        child: AjustePixel(
          child: CustomPaint(
            size: Size((columnas(texto) + 2 * borde) * lado, (LetraRotuloPixel.alto + 2 * borde) * lado),
            painter: _PintorRotulo(glifos, lado, color, contorno),
          ),
        ),
      ),
    );
  }
}

class _PintorRotulo extends CustomPainter {
  const _PintorRotulo(this.glifos, this.lado, this.color, this.contorno);

  final List<GlifoPixel> glifos;
  final double lado;
  final Color color;
  final Color? contorno;

  @override
  void paint(Canvas canvas, Size size) {
    final borde = contorno == null ? 0.0 : lado;
    var x = borde;
    for (final glifo in glifos) {
      pintarGlifo(canvas, glifo, Offset(x, borde), lado, color, contorno: contorno);
      x += (glifo.ancho + 1) * lado;
    }
  }

  @override
  bool shouldRepaint(_PintorRotulo oldDelegate) =>
      oldDelegate.lado != lado ||
      oldDelegate.color != color ||
      oldDelegate.contorno != contorno ||
      !_iguales(oldDelegate.glifos, glifos);

  static bool _iguales(List<GlifoPixel> a, List<GlifoPixel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }
}
