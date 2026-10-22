import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../widgets/movimiento/hapticos.dart';
import 'estilo_pixel.dart';
import 'iconos_pixel.dart';
import 'pintura_pixel.dart';
import 'rotulo_pixel.dart';

/// Duraciones del [SelloPixel].
abstract final class DuracionSelloPixel {
  /// La caída, el golpe y las gotas de tinta.
  static const estampar = Duration(milliseconds: 560);

  /// Lo que espera, por defecto, antes de caer (para que antes se vea la pantalla).
  static const retraso = Duration(milliseconds: 250);
}

/// El sello «COMPLETADO» del final de un caso, en pixel: un tampón rectangular de doble borde con un visto y la palabra
/// en la letra de rótulo ([RotuloPixel]), en tinta azul y un poco gastado. Es un sello de juego, de TuTurno: no imita
/// ningún sello oficial.
///
/// Cae una vez desde arriba a saltos de una celda, golpea el papel (vibración fuerte y [alEstampar]), baja una celda con
/// el golpe y suelta unas gotas de tinta que se secan enseguida. Nunca en bucle. Con «reducir animaciones» aparece ya
/// puesto (y vibra una vez, si [vibrar]).
///
/// Mide lo que pide su dibujo, con la mayor celda entera que cabe en el ancho (como mucho, la de la letra de rótulo, que
/// crece con la letra del sistema). Mientras cae se pinta por encima de su sitio. Va sobre papel: por ejemplo, dentro de
/// un ticket.
class SelloPixel extends StatefulWidget {
  const SelloPixel({
    super.key,
    this.texto = 'COMPLETADO',
    this.color = ColoresUiPixel.azul,
    this.retraso = DuracionSelloPixel.retraso,
    this.vibrar = true,
    this.alEstampar,
    this.semantica = 'Sello: caso completado',
  });

  /// En mayúsculas y corto (la letra de rótulo no tiene minúsculas).
  final String texto;

  /// La tinta.
  final Color color;
  final Duration retraso;

  /// Vibra al golpear (con [Hapticos.sello]).
  final bool vibrar;

  /// Se llama una vez, al golpear el papel (o al aparecer, con «reducir animaciones»).
  final VoidCallback? alEstampar;
  final String semantica;

  /// Celdas que mide de ancho el dibujo de [texto]: bordes, márgenes, el visto y la palabra.
  static int columnas(String texto) => 2 * _margen + GlifoPixel.check.ancho + _huecoVisto + RotuloPixel.columnas(texto);

  /// Celdas que mide de alto.
  static const filas = 2 * _margen + LetraRotuloPixel.alto;

  /// Borde de fuera, hueco, borde de dentro y dos celdas de aire, por cada lado.
  static const _margen = 5;
  static const _huecoVisto = 2;

  @override
  State<SelloPixel> createState() => _SelloPixelState();
}

class _SelloPixelState extends State<SelloPixel> with SingleTickerProviderStateMixin {
  late final AnimationController _animacion = AnimationController(vsync: this, duration: DuracionSelloPixel.estampar)
    ..addListener(_alAvanzar);
  Timer? _espera;
  bool _empezado = false;
  bool _estampado = false;

  /// Momento del golpe (de 0 a 1 en la animación).
  static const golpe = 0.45;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_empezado) return;
    _empezado = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _animacion.value = 1;
      SchedulerBinding.instance.addPostFrameCallback((_) => _estampar());
      return;
    }
    _espera = Timer(widget.retraso, () {
      if (mounted) _animacion.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _espera?.cancel();
    _animacion.dispose();
    super.dispose();
  }

  void _alAvanzar() {
    if (!_estampado && _animacion.value >= golpe) _estampar();
  }

  void _estampar() {
    if (_estampado || !mounted) return;
    _estampado = true;
    if (widget.vibrar) unawaited(Hapticos.sello());
    widget.alEstampar?.call();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final celdaMaxima = RotuloPixel.celda(context);
    final columnas = SelloPixel.columnas(widget.texto);
    return Semantics(
      label: widget.semantica,
      image: true,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, restricciones) {
            var fisicos = math.max(1, (celdaMaxima * dpr).round());
            if (restricciones.hasBoundedWidth) {
              fisicos = math.max(1, math.min(fisicos, (restricciones.maxWidth * dpr / columnas).floor()));
            }
            final celda = fisicos / dpr;
            return AjustePixel(
              child: CustomPaint(
                size: Size(columnas * celda, SelloPixel.filas * celda),
                painter: _PintorSello(texto: widget.texto, color: widget.color, celda: celda, animacion: _animacion),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PintorSello extends CustomPainter {
  _PintorSello({required this.texto, required this.color, required this.celda, required this.animacion})
    : super(repaint: animacion);

  final String texto;
  final Color color;
  final double celda;
  final Animation<double> animacion;

  /// Celdas que cae desde arriba.
  static const _caida = 8;

  /// Celdas sin tinta en los bordes: el sello está un poco gastado (siempre en los mismos sitios).
  static const _gastadas = {(7, 0), (8, 0), (23, 0), (41, 0), (15, -1), (16, -1), (33, -1), (52, -1), (0, 9), (-1, 5)};

  @override
  void paint(Canvas canvas, Size size) {
    final t = animacion.value;
    if (t <= 0) return;
    final columnas = SelloPixel.columnas(texto);
    const filas = SelloPixel.filas;
    final tinta = pincelPixel(color);
    if (t < _SelloPixelState.golpe) {
      // Cae a saltos de una celda (cada vez más deprisa) y, donde va a caer, el papel se oscurece un poco.
      final avance = Curves.easeIn.transform(t / _SelloPixelState.golpe);
      final arriba = ((1 - avance) * _caida).round();
      canvas.drawRect(Offset.zero & size, pincelPixel(ColoresUiPixel.crema));
      _pintarSello(canvas, columnas, filas, tinta, dy: -arriba);
      return;
    }
    // El golpe: baja una celda un momento y suelta unas gotas de tinta alrededor.
    final aplastado = t < _SelloPixelState.golpe + 0.12;
    _pintarSello(canvas, columnas, filas, tinta, dy: aplastado ? 1 : 0);
    if (t < 0.8) {
      final lejos = t < 0.62 ? 2 : 3;
      for (final (x, y) in [
        (-lejos, -lejos),
        (columnas ~/ 3, -lejos),
        (columnas * 2 ~/ 3, -lejos - 1),
        (columnas + lejos - 1, -lejos),
        (-lejos - 1, filas ~/ 2),
        (columnas + lejos, filas ~/ 2 - 1),
        (-lejos, filas + lejos - 1),
        (columnas ~/ 2, filas + lejos),
        (columnas + lejos - 1, filas + lejos - 1),
      ]) {
        _celda(canvas, x, y, tinta);
      }
    }
  }

  void _celda(Canvas canvas, int x, int y, Paint tinta) =>
      canvas.drawRect(Rect.fromLTWH(x * celda, y * celda, celda, celda), tinta);

  void _pintarSello(Canvas canvas, int columnas, int filas, Paint tinta, {required int dy}) {
    canvas
      ..save()
      ..translate(0, dy * celda);
    // Los dos bordes, el de fuera con las celdas gastadas.
    for (final (borde, desde) in [(true, 0), (false, 2)]) {
      final ancho = columnas - 2 * desde;
      final alto = filas - 2 * desde;
      for (var x = 0; x < ancho; x++) {
        if (!(borde && _gastadas.contains((x, 0)))) _celda(canvas, desde + x, desde, tinta);
        if (!(borde && _gastadas.contains((x, -1)))) _celda(canvas, desde + x, desde + alto - 1, tinta);
      }
      for (var y = 1; y < alto - 1; y++) {
        if (!(borde && _gastadas.contains((0, y)))) _celda(canvas, desde, desde + y, tinta);
        if (!(borde && _gastadas.contains((-1, y)))) _celda(canvas, desde + ancho - 1, desde + y, tinta);
      }
    }
    // El visto (6 filas: abajo, alineado con la palabra) y la palabra.
    const margen = SelloPixel._margen;
    final visto = GlifoPixel.check;
    pintarGlifo(
      canvas,
      visto,
      Offset(margen * celda, (margen + LetraRotuloPixel.alto - visto.alto) * celda),
      celda,
      color,
    );
    var x = margen + visto.ancho + SelloPixel._huecoVisto;
    for (final caracter in texto.characters) {
      final glifo = LetraRotuloPixel.de(caracter);
      pintarGlifo(canvas, glifo, Offset(x * celda, margen * celda), celda, color);
      x += glifo.ancho + 1;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorSello oldDelegate) =>
      oldDelegate.texto != texto ||
      oldDelegate.color != color ||
      oldDelegate.celda != celda ||
      oldDelegate.animacion != animacion;
}
