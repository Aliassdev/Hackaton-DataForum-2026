import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'paleta_iconos.dart';

/// Cómo se pinta un icono.
enum EstiloIcono {
  /// A dos tintas (azul y amarillo) con contorno azul noche y sombra de papel.
  color,

  /// De un solo color, con los detalles calados: para botones, barras y chips (como un `Icon` de Material).
  mono,
}

/// Papel del que está hecha cada pieza del icono.
enum TonoIcono { azul, amarillo, tinta, papel, celeste, rojo, exito, sobreExito, error, sobreError }

/// Una pieza del icono, en una rejilla de 100 × 100.
///
/// Una [capa] es un trozo de papel: lleva contorno, proyecta sombra y forma la silueta (y la pegatina). Un detalle
/// ([capa] = false) va «impreso» encima: sin contorno y, en [EstiloIcono.mono], calado.
@immutable
class PiezaIcono {
  const PiezaIcono(this.forma, this.tono, {this.trazo, this.capa = true, this.desde = 0});

  final Path forma;
  final TonoIcono tono;

  /// Grosor si la pieza es una línea; null si es una forma rellena.
  final double? trazo;
  final bool capa;

  /// Tamaño mínimo del icono (en píxeles lógicos) para pintar esta pieza: los detalles finos se quitan en pequeño.
  final double desde;
}

Color colorDeTono(PaletaIconos paleta, TonoIcono tono) => switch (tono) {
  TonoIcono.azul => paleta.azul,
  TonoIcono.amarillo => paleta.amarillo,
  TonoIcono.tinta => paleta.tinta,
  TonoIcono.papel => paleta.papel,
  TonoIcono.celeste => paleta.celeste,
  TonoIcono.rojo => paleta.rojo,
  TonoIcono.exito => paleta.exito,
  TonoIcono.sobreExito => paleta.sobreExito,
  TonoIcono.error => paleta.error,
  TonoIcono.sobreError => paleta.sobreError,
};

/// Pinta una lista de [PiezaIcono] escalada al tamaño del lienzo (el lado más corto).
class PintorIcono extends CustomPainter {
  const PintorIcono({
    required this.piezas,
    required this.paleta,
    this.estilo = EstiloIcono.color,
    this.pegatina = false,
    this.sombra = true,
    this.colorMono = const Color(0xFF000000),
  });

  final List<PiezaIcono> piezas;
  final PaletaIconos paleta;
  final EstiloIcono estilo;
  final bool pegatina;
  final bool sombra;
  final Color colorMono;

  static const _rejilla = 100.0;

  /// Con borde de pegatina, el dibujo se encoge para que el borde quepa en la caja.
  static const _escalaPegatina = 0.84;

  /// Zona de las capas intermedias (saveLayer): la rejilla con margen para sombras y bordes.
  static const _zona = Rect.fromLTRB(-30, -30, 130, 130);

  static final _borrar = Paint()..blendMode = BlendMode.clear;

  @override
  void paint(Canvas canvas, Size size) {
    final lado = size.shortestSide;
    if (lado <= 0) return;
    var escala = lado / _rejilla;
    canvas
      ..save()
      ..translate((size.width - lado) / 2, (size.height - lado) / 2)
      ..scale(escala);
    final pegatina = this.pegatina && estilo == EstiloIcono.color;
    if (pegatina) {
      canvas
        ..translate(_rejilla / 2, _rejilla / 2)
        ..scale(_escalaPegatina)
        ..translate(-_rejilla / 2, -_rejilla / 2);
      escala *= _escalaPegatina;
    }
    // Un píxel en unidades de la rejilla: los contornos nunca bajan de ~1 px aunque el icono sea pequeño.
    final pixel = 1 / escala;
    final visibles = [
      for (final pieza in piezas)
        if (lado >= pieza.desde) pieza,
    ];
    if (estilo == EstiloIcono.mono) {
      _pintarMono(canvas, visibles, pixel);
    } else {
      _pintarColor(canvas, visibles, pixel, pegatina);
    }
    canvas.restore();
  }

  void _pintarColor(Canvas canvas, List<PiezaIcono> piezas, double pixel, bool pegatina) {
    final contorno = math.max(3.0, 1.15 * pixel);
    final desplazamiento = Offset(math.max(2.2, 0.9 * pixel), math.max(2.8, 1.1 * pixel));
    if (pegatina) {
      final borde = math.max(6.0, 2.4 * pixel);
      _sombra(canvas, piezas, contorno, borde, desplazamiento * 1.3);
      _silueta(canvas, piezas, Paint()..color = paleta.papel, contorno, borde);
    } else if (sombra) {
      _sombra(canvas, piezas, contorno, 0, desplazamiento);
    }
    final linea = Paint()
      ..color = paleta.tinta
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    for (final pieza in piezas) {
      final color = colorDeTono(paleta, pieza.tono);
      final trazo = pieza.trazo;
      if (trazo == null) {
        canvas.drawPath(pieza.forma, Paint()..color = color);
        if (pieza.capa) canvas.drawPath(pieza.forma, linea..strokeWidth = contorno);
      } else {
        if (pieza.capa) canvas.drawPath(pieza.forma, linea..strokeWidth = trazo + contorno * 2);
        canvas.drawPath(
          pieza.forma,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = trazo
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }
  }

  /// Sombra de papel: la silueta desplazada, plana (sin desenfoque: nítida y barata de pintar).
  void _sombra(Canvas canvas, List<PiezaIcono> piezas, double contorno, double extra, Offset desplazamiento) {
    canvas
      ..saveLayer(_zona, Paint()..color = Color.fromRGBO(0, 0, 0, paleta.sombra.a))
      ..translate(desplazamiento.dx, desplazamiento.dy);
    _silueta(canvas, piezas, Paint()..color = paleta.sombra.withValues(alpha: 1), contorno, extra);
    canvas.restore();
  }

  /// Silueta de todas las capas con su contorno, ensanchada [extra].
  void _silueta(Canvas canvas, List<PiezaIcono> piezas, Paint pincel, double contorno, double extra) {
    pincel
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    for (final pieza in piezas) {
      if (!pieza.capa) continue;
      final trazo = pieza.trazo;
      if (trazo == null) {
        canvas.drawPath(pieza.forma, pincel..style = PaintingStyle.fill);
        canvas.drawPath(
          pieza.forma,
          pincel
            ..style = PaintingStyle.stroke
            ..strokeWidth = contorno + extra * 2,
        );
      } else {
        canvas.drawPath(
          pieza.forma,
          pincel
            ..style = PaintingStyle.stroke
            ..strokeWidth = trazo + contorno * 2 + extra * 2,
        );
      }
    }
  }

  /// Un solo color: cada capa se separa de las de debajo con un hueco y los detalles se calan.
  void _pintarMono(Canvas canvas, List<PiezaIcono> piezas, double pixel) {
    final hueco = math.max(3.2, 1.1 * pixel);
    final relleno = Paint()..color = colorMono.withValues(alpha: 1);
    canvas.saveLayer(_zona, Paint()..color = Color.fromRGBO(0, 0, 0, colorMono.a));
    var primera = true;
    for (final pieza in piezas) {
      if (pieza.capa) {
        if (!primera) _pintar(canvas, pieza, _borrar, ensanche: hueco);
        _pintar(canvas, pieza, relleno);
        primera = false;
      } else {
        _pintar(canvas, pieza, _borrar);
      }
    }
    canvas.restore();
  }

  void _pintar(Canvas canvas, PiezaIcono pieza, Paint pincel, {double ensanche = 0}) {
    pincel
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final trazo = pieza.trazo;
    if (trazo == null) {
      canvas.drawPath(pieza.forma, pincel..style = PaintingStyle.fill);
      if (ensanche > 0) {
        canvas.drawPath(
          pieza.forma,
          pincel
            ..style = PaintingStyle.stroke
            ..strokeWidth = ensanche * 2,
        );
      }
    } else {
      canvas.drawPath(
        pieza.forma,
        pincel
          ..style = PaintingStyle.stroke
          ..strokeWidth = trazo + ensanche * 2,
      );
    }
  }

  @override
  bool shouldRepaint(PintorIcono old) =>
      !identical(old.piezas, piezas) ||
      old.paleta != paleta ||
      old.estilo != estilo ||
      old.pegatina != pegatina ||
      old.sombra != sombra ||
      old.colorMono != colorMono;
}
