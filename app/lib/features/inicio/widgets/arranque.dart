import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../tema.dart';

/// Paso de la bienvenida al inicio, para el `AnimatedSwitcher` de la pantalla de inicio: la bienvenida se arranca
/// como la hoja de un taco de tickets (se suelta de arriba, cuelga un instante de una esquina y cae girando) y deja
/// ver el inicio, que se acerca y sale de la penumbra.
///
/// Solo se mueven capas ya pintadas (la hoja va en su propia capa), así que es barato. Con «reducir animaciones»,
/// el `AnimatedSwitcher` dura cero y el cambio es directo.
abstract final class TransicionArranque {
  static const duracion = Duration(milliseconds: 820);

  /// Clave de la bienvenida en el `AnimatedSwitcher`: es la hoja que se arranca.
  static const claveHoja = ValueKey('bienvenida');

  /// La hoja que se va queda encima de la pantalla que llega.
  static Widget disposicion(Widget? actual, List<Widget> anteriores) =>
      Stack(fit: StackFit.expand, children: [?actual, ...anteriores]);

  static Widget transicion(Widget child, Animation<double> animation) =>
      child.key == claveHoja ? _Hoja(animation: animation, child: child) : _Fondo(animation: animation, child: child);
}

/// La bienvenida: al irse, se arranca.
class _Hoja extends StatefulWidget {
  const _Hoja({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  State<_Hoja> createState() => _HojaState();
}

class _HojaState extends State<_Hoja> {
  late bool _saliendo = _seVa(widget.animation.status);

  static bool _seVa(AnimationStatus estado) => estado == AnimationStatus.reverse || estado == AnimationStatus.dismissed;

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_alCambiar);
  }

  @override
  void didUpdateWidget(_Hoja anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.animation != widget.animation) {
      anterior.animation.removeStatusListener(_alCambiar);
      widget.animation.addStatusListener(_alCambiar);
      _alCambiar(widget.animation.status);
    }
  }

  void _alCambiar(AnimationStatus estado) {
    final saliendo = _seVa(estado);
    if (saliendo != _saliendo && mounted) setState(() => _saliendo = saliendo);
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_alCambiar);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mientras se va, no se puede tocar ni se lee: ya está entrando el inicio.
    return IgnorePointer(
      ignoring: _saliendo,
      child: ExcludeSemantics(
        excluding: _saliendo,
        child: LayoutBuilder(
          builder: (context, restricciones) {
            final size = restricciones.biggest;
            return AnimatedBuilder(
              animation: widget.animation,
              child: RepaintBoundary(child: widget.child),
              builder: (context, hoja) {
                final t = _saliendo ? 1 - widget.animation.value : 0.0;
                final arranque = _Arranque(size, t);
                return CustomPaint(
                  painter: _PintorSombra(arranque),
                  child: Transform(
                    transform: arranque.matriz,
                    child: CustomPaint(
                      foregroundPainter: _PintorFibras(arranque),
                      child: ClipPath(
                        clipper: _Rotura(rota: t > 0),
                        clipBehavior: t > 0 ? Clip.antiAlias : Clip.none,
                        child: hoja,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Dónde está la hoja en el instante [t] (0 = entera, 1 = fuera de la pantalla).
///
/// Primero se suelta por la izquierda y cuelga de la esquina de arriba a la derecha; después cae girando, un poco
/// hacia la izquierda, como un papel.
class _Arranque {
  factory _Arranque(Size size, double t) {
    final suelta = Curves.easeOutCubic.transform((t / 0.3).clamp(0.0, 1.0));
    final caida = Curves.easeInCubic.transform(((t - 0.22) / 0.78).clamp(0.0, 1.0));
    final giro = -0.09 * suelta - 0.34 * caida;
    final pivote = Offset(size.width, 0);
    final matriz = Matrix4.identity()
      ..translateByDouble(pivote.dx - size.width * 0.2 * caida, pivote.dy + size.height * 1.2 * caida, 0, 1)
      ..rotateZ(giro)
      ..translateByDouble(-pivote.dx, -pivote.dy, 0, 1);
    return _Arranque._(size, t, matriz);
  }

  _Arranque._(this.size, this.t, this.matriz);

  final Size size;
  final double t;
  final Matrix4 matriz;

  /// La línea rota de arriba: dientes irregulares, siempre los mismos.
  static Path borde(Size size) {
    final camino = Path()..moveTo(0, 0);
    const paso = 9.0;
    final tramos = (size.width / paso).ceil();
    for (var i = 1; i <= tramos; i++) {
      final x = math.min(size.width, i * paso);
      final hondo = i.isOdd ? 3.0 + 3.0 * _azar(i) : 0.5 * _azar(i + 7);
      camino.lineTo(x, hondo);
    }
    return camino;
  }

  static double _azar(int i) {
    final x = math.sin(i * 91.7 + 13.1) * 43758.5453;
    return x - x.floorToDouble();
  }
}

/// La silueta de la hoja con su borde roto arriba (solo una vez arrancada).
class _Rotura extends CustomClipper<Path> {
  const _Rotura({required this.rota});

  final bool rota;

  @override
  Path getClip(Size size) {
    if (!rota) return Path()..addRect(Offset.zero & size);
    return _Arranque.borde(size)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_Rotura anterior) => anterior.rota != rota;
}

/// Sombra de la hoja sobre el inicio mientras cae (crece al despegarse).
class _PintorSombra extends CustomPainter {
  const _PintorSombra(this.arranque);

  final _Arranque arranque;

  @override
  void paint(Canvas canvas, Size size) {
    final t = arranque.t;
    if (t <= 0) return;
    final hoja = (Path()..addRect(Offset.zero & size)).transform(arranque.matriz.storage);
    canvas.drawShadow(hoja, Colors.black.withValues(alpha: 0.6), 6 + 14 * math.min(1, t * 3), false);
  }

  @override
  bool shouldRepaint(_PintorSombra anterior) => anterior.arranque.t != arranque.t;
}

/// Las fibras del papel roto: un filo claro a lo largo del borde de arriba.
class _PintorFibras extends CustomPainter {
  const _PintorFibras(this.arranque);

  final _Arranque arranque;

  @override
  void paint(Canvas canvas, Size size) {
    if (arranque.t <= 0) return;
    canvas.drawPath(
      _Arranque.borde(size),
      Paint()
        ..color = ColoresMarca.papel
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PintorFibras anterior) => (anterior.arranque.t > 0) != (arranque.t > 0);
}

/// La pantalla que llega (el inicio): se acerca un poco y sale de la penumbra. Si se va (la bienvenida vuelve a
/// salir en el modo DEMO), se funde.
class _Fondo extends StatelessWidget {
  const _Fondo({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, pantalla) {
        final v = animation.value;
        final seVa = animation.status == AnimationStatus.reverse;
        final e = Curves.easeOutCubic.transform(v);
        return Opacity(
          opacity: seVa ? v : 1,
          child: Transform.scale(
            scale: seVa ? 1 : 0.94 + 0.06 * e,
            child: Stack(
              fit: StackFit.expand,
              children: [
                pantalla!,
                IgnorePointer(
                  child: ColoredBox(color: ColoresMarca.azulNoche.withValues(alpha: seVa ? 0 : 0.45 * (1 - e))),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
