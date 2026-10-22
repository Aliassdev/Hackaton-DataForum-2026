import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../tema.dart';

/// Carta coleccionable holográfica: al arrastrarla con el dedo se inclina en 3D, un reflejo de colores la recorre y se
/// encienden destellos; al soltarla, vuelve a su sitio con un pequeño rebote. Sin sensores: solo el dedo.
///
/// Dentro de una lista vertical, el arrastre horizontal inclina la carta y el vertical desplaza la lista. Con
/// «reducir animaciones» la carta no se mueve y el reflejo queda quieto.
class CartaHolo extends StatefulWidget {
  const CartaHolo({
    super.key,
    required this.child,
    this.radio = Radios.l,
    this.inclinacionMaxima = 0.35,
    this.brillo = true,
    this.colores,
    this.onTap,
  });

  final Widget child;
  final double radio;

  /// Giro máximo en radianes en cada eje (0,35 ≈ 20°).
  final double inclinacionMaxima;
  final bool brillo;

  /// Colores del reflejo, de un extremo al otro. Por defecto, los del tema (`context.colores.holografico`).
  final List<Color>? colores;
  final VoidCallback? onTap;

  @override
  State<CartaHolo> createState() => _CartaHoloState();
}

class _CartaHoloState extends State<CartaHolo> with SingleTickerProviderStateMixin {
  static const _vuelta = Duration(milliseconds: 650);

  /// Inclinación normalizada: x e y entre −1 y 1.
  final _inclinacion = ValueNotifier<Offset>(Offset.zero);
  late final AnimationController _regreso = AnimationController(vsync: this, duration: _vuelta)
    ..addListener(_alRegresar);
  Offset _desde = Offset.zero;
  Offset _hasta = Offset.zero;

  bool get _quieta => duracion(context, _vuelta) == Duration.zero;

  void _alRegresar() {
    final t = Curves.elasticOut.transform(_regreso.value);
    _inclinacion.value = Offset.lerp(_desde, _hasta, t)!;
  }

  void _inclinarHacia(Offset posicion, Size tamano) {
    if (_quieta || tamano.isEmpty) return;
    _regreso.stop();
    _inclinacion.value = Offset(
      (posicion.dx / tamano.width * 2 - 1).clamp(-1.0, 1.0),
      (posicion.dy / tamano.height * 2 - 1).clamp(-1.0, 1.0),
    );
  }

  void _volver({Offset hasta = Offset.zero}) {
    if (_quieta) {
      _inclinacion.value = Offset.zero;
      return;
    }
    _desde = _inclinacion.value;
    _hasta = hasta;
    _regreso.forward(from: 0);
  }

  /// Al tocarla, se balancea un poco: así se descubre que se puede mover.
  void _alTocar() {
    widget.onTap?.call();
    if (_quieta) return;
    _inclinacion.value = const Offset(0.55, -0.35);
    _volver();
  }

  @override
  void dispose() {
    _regreso.dispose();
    _inclinacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(widget.radio);
    final colores = widget.colores ?? context.colores.holografico;
    final carta = ClipRRect(
      borderRadius: forma,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // El contenido se pinta una vez; al inclinarla solo cambian la transformación y el reflejo.
          RepaintBoundary(child: widget.child),
          if (widget.brillo)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PintorHolo(inclinacion: _inclinacion, colores: colores),
                  willChange: true,
                ),
              ),
            ),
        ],
      ),
    );
    return GestureDetector(
      onTap: widget.onTap == null ? null : _alTocar,
      onPanStart: (d) => _inclinarHacia(d.localPosition, context.size ?? Size.zero),
      onPanUpdate: (d) => _inclinarHacia(d.localPosition, context.size ?? Size.zero),
      onPanEnd: (_) => _volver(),
      onPanCancel: _volver,
      child: ValueListenableBuilder<Offset>(
        valueListenable: _inclinacion,
        child: carta,
        builder: (context, inclinacion, carta) => Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateX(-inclinacion.dy * widget.inclinacionMaxima)
            ..rotateY(inclinacion.dx * widget.inclinacionMaxima),
          child: carta,
        ),
      ),
    );
  }
}

/// Reflejo holográfico, en capas baratas (tres degradados y unos pocos destellos):
/// - una banda de colores en diagonal que recorre la carta al inclinarla. Se suma a la luz (`BlendMode.plus`): aclara
///   la carta con los colores del reflejo en vez de taparla; un velo muy suave la deja ver también en cartas claras;
/// - destellos de purpurina que se encienden según hacia dónde se inclina;
/// - un brillo blanco donde «da la luz».
///
/// En reposo apenas se nota; cuanto más se inclina, más brilla.
class _PintorHolo extends CustomPainter {
  _PintorHolo({required this.inclinacion, required this.colores}) : super(repaint: inclinacion);

  final ValueListenable<Offset> inclinacion;
  final List<Color> colores;

  /// Mitad del ancho de la banda, en unidades de [Alignment] a lo largo de la diagonal.
  static const _mitadBanda = 0.55;

  /// Destellos: dónde están (0–1 dentro de la carta), hacia qué inclinación miran y su tamaño relativo. Fijos, para que
  /// cada destello se encienda siempre en el mismo sitio, como la purpurina de una carta de verdad.
  static final _destellos = () {
    final azar = math.Random(11);
    return [
      for (var i = 0; i < 9; i++)
        (
          posicion: Offset(0.1 + 0.8 * azar.nextDouble(), 0.08 + 0.84 * azar.nextDouble()),
          direccion: Offset.fromDirection(i * 2 * math.pi / 9 + 0.5 * azar.nextDouble()),
          tamano: 0.6 + 0.6 * azar.nextDouble(),
        ),
    ];
  }();

  /// Estrella de cuatro puntas de radio 1.
  static final _estrella = () {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final r = i.isEven ? 1.0 : 0.24;
      final a = i * math.pi / 4 - math.pi / 2;
      i == 0 ? path.moveTo(math.cos(a) * r, math.sin(a) * r) : path.lineTo(math.cos(a) * r, math.sin(a) * r);
    }
    return path..close();
  }();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || colores.isEmpty) return;
    final v = inclinacion.value;
    final fuerza = math.min(1.0, v.distance);
    final rect = Offset.zero & size;

    // La banda recorre la diagonal en sentido contrario a la inclinación, como un reflejo.
    final centro = -(v.dx + v.dy) * 0.75;
    Shader banda(double alfa) => LinearGradient(
      begin: Alignment(centro - _mitadBanda, centro - _mitadBanda),
      end: Alignment(centro + _mitadBanda, centro + _mitadBanda),
      colors: [
        Colors.transparent,
        for (final c in colores) c.withValues(alpha: c.a * alfa),
        Colors.transparent,
      ],
    ).createShader(rect);
    canvas
      ..drawRect(rect, Paint()..shader = banda(0.05 + 0.07 * fuerza))
      ..drawRect(
        rect,
        Paint()
          ..shader = banda(0.1 + 0.24 * fuerza)
          ..blendMode = BlendMode.plus,
      );

    if (fuerza > 0.05) {
      final hacia = v / v.distance;
      final destello = Paint()..blendMode = BlendMode.plus;
      for (final d in _destellos) {
        final alineado = math.max(0.0, hacia.dx * d.direccion.dx + hacia.dy * d.direccion.dy);
        final luz = math.pow(alineado, 4).toDouble() * fuerza;
        if (luz < 0.04) continue;
        final lado = size.shortestSide * 0.035 * d.tamano * (0.6 + 0.4 * luz);
        canvas
          ..save()
          ..translate(d.posicion.dx * size.width, d.posicion.dy * size.height)
          ..scale(lado)
          ..drawPath(_estrella, destello..color = Colors.white.withValues(alpha: 0.9 * luz))
          ..restore();
      }
    }

    final intensidad = 0.06 + 0.22 * fuerza;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(v.dx * 0.9, v.dy * 0.9),
          radius: 0.85,
          colors: [
            Colors.white.withValues(alpha: intensidad),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_PintorHolo anterior) =>
      anterior.inclinacion != inclinacion || !listEquals(anterior.colores, colores);
}
