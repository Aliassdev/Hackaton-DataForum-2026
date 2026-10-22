import 'package:flutter/widgets.dart';

import 'estilo_pixel.dart';
import 'pintura_pixel.dart';

/// Un dibujo de pocos píxeles: cada '#' es una unidad pixel pintada y cada '.', una vacía.
@immutable
class GlifoPixel {
  const GlifoPixel(this.nombre, this.filas);

  final String nombre;
  final List<String> filas;

  int get ancho => filas.isEmpty ? 0 : filas.first.length;
  int get alto => filas.length;

  /// Si la celda ([x], [y]) está pintada (fuera del dibujo, no).
  bool lleno(int x, int y) => y >= 0 && y < alto && x >= 0 && x < filas[y].length && filas[y].codeUnitAt(x) == 0x23;

  /// Cursor de los menús.
  static const flecha = GlifoPixel('flecha', ['#...', '##..', '###.', '####', '###.', '##..', '#...']);

  /// «Continuar» de los diálogos.
  static const abajo = GlifoPixel('abajo', ['#######', '.#####.', '..###..', '...#...']);

  /// Volver.
  static const atras = GlifoPixel('atras', [
    '...#...',
    '..##...',
    '.######',
    '#######',
    '.######',
    '..##...',
    '...#...',
  ]);

  static const check = GlifoPixel('check', ['.......#', '......##', '#....##.', '##..##..', '.####...', '..##....']);

  static const cruz = GlifoPixel('cruz', ['##...##', '###.###', '.#####.', '..###..', '.#####.', '###.###', '##...##']);

  static const candado = GlifoPixel('candado', [
    '..###..',
    '.#...#.',
    '.#...#.',
    '#######',
    '###.###',
    '###.###',
    '#######',
  ]);

  /// Una carta de la colección, como un naipe con su rombo (de 5 × 5: más pequeño se confundiría con un «+»).
  static const carta = GlifoPixel('carta', [
    '.#######.',
    '#.......#',
    '#.......#',
    '#...#...#',
    '#..###..#',
    '#.#####.#',
    '#..###..#',
    '#...#...#',
    '#.......#',
    '#.......#',
    '.#######.',
  ]);

  static const estrella = GlifoPixel('estrella', [
    '....#....',
    '....#....',
    '...###...',
    '#########',
    '.#######.',
    '..#####..',
    '..##.##..',
    '.##...##.',
    '.#.....#.',
  ]);

  /// La balanza de la justicia.
  static const balanza = GlifoPixel('balanza', [
    '......#......',
    '.###########.',
    '.#....#....#.',
    '#.#...#...#.#',
    '#.#...#...#.#',
    '#####.#.#####',
    '.###..#..###.',
    '......#......',
    '......#......',
    '....#####....',
  ]);

  static const pregunta = GlifoPixel('pregunta', ['.###.', '#...#', '....#', '..##.', '..#..', '.....', '..#..']);

  /// Escuchar la narración.
  static const altavoz = GlifoPixel('altavoz', [
    '...#..#..',
    '..##...#.',
    '####.#..#',
    '####.#..#',
    '####.#..#',
    '..##...#.',
    '...#..#..',
  ]);

  static const values = [flecha, abajo, atras, check, cruz, candado, carta, estrella, balanza, pregunta, altavoz];
}

/// Pinta [glifo] con la esquina de arriba a la izquierda en [origen] y celdas de [u]. Con [contorno], cada celda
/// pintada lleva un borde de una unidad de ese color (para que se vea sobre cualquier fondo), que sobresale una unidad
/// por cada lado.
void pintarGlifo(Canvas canvas, GlifoPixel glifo, Offset origen, double u, Color color, {Color? contorno}) {
  if (contorno != null) {
    final borde = pincelPixel(contorno);
    for (var y = -1; y <= glifo.alto; y++) {
      int? inicio;
      for (var x = -1; x <= glifo.ancho + 1; x++) {
        final esBorde =
            x <= glifo.ancho &&
            !glifo.lleno(x, y) &&
            (glifo.lleno(x - 1, y) || glifo.lleno(x + 1, y) || glifo.lleno(x, y - 1) || glifo.lleno(x, y + 1));
        if (esBorde) {
          inicio ??= x;
        } else if (inicio != null) {
          canvas.drawRect(Rect.fromLTWH(origen.dx + inicio * u, origen.dy + y * u, (x - inicio) * u, u), borde);
          inicio = null;
        }
      }
    }
  }
  final tinta = pincelPixel(color);
  for (var y = 0; y < glifo.alto; y++) {
    int? inicio;
    for (var x = 0; x <= glifo.ancho; x++) {
      if (glifo.lleno(x, y)) {
        inicio ??= x;
      } else if (inicio != null) {
        canvas.drawRect(Rect.fromLTWH(origen.dx + inicio * u, origen.dy + y * u, (x - inicio) * u, u), tinta);
        inicio = null;
      }
    }
  }
}

/// Un [GlifoPixel] como icono. Sin [color], el del [IconTheme] (dentro de un botón, la tinta del botón).
///
/// [escala] hace cada celda de varias unidades. Es decorativo salvo que lleve [semantica].
class IconoPixel extends StatelessWidget {
  const IconoPixel(this.glifo, {super.key, this.color, this.contorno, this.escala = 1, this.semantica});

  final GlifoPixel glifo;
  final Color? color;

  /// Borde de una unidad alrededor del dibujo (suma una unidad por cada lado).
  final Color? contorno;
  final int escala;
  final String? semantica;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context) * escala;
    final color = this.color ?? IconTheme.of(context).color ?? ColoresUiPixel.noche;
    final borde = contorno == null ? 0 : 1;
    final icono = AjustePixel(
      child: CustomPaint(
        size: Size((glifo.ancho + 2 * borde) * u, (glifo.alto + 2 * borde) * u),
        painter: _PintorGlifo(glifo, u, color, contorno),
      ),
    );
    final semantica = this.semantica;
    if (semantica == null) return ExcludeSemantics(child: icono);
    return Semantics(label: semantica, image: true, child: icono);
  }
}

class _PintorGlifo extends CustomPainter {
  const _PintorGlifo(this.glifo, this.u, this.color, this.contorno);

  final GlifoPixel glifo;
  final double u;
  final Color color;
  final Color? contorno;

  @override
  void paint(Canvas canvas, Size size) {
    final borde = contorno == null ? 0.0 : u;
    pintarGlifo(canvas, glifo, Offset(borde, borde), u, color, contorno: contorno);
  }

  @override
  bool shouldRepaint(_PintorGlifo oldDelegate) =>
      oldDelegate.glifo != glifo ||
      oldDelegate.u != u ||
      oldDelegate.color != color ||
      oldDelegate.contorno != contorno;
}
