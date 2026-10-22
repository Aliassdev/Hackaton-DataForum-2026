import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Pinta [child] con su origen justo en un píxel físico de la pantalla: al pintarlo lo mueve lo que haga falta (menos
/// de medio píxel físico en cada eje), sin cambiar el sitio que ocupa.
///
/// [EncajePixel] coloca el dibujo en la rejilla de píxeles físicos de su caja, pero la caja puede empezar a medio
/// píxel de la pantalla: tras un margen de 18 puntos a densidad 2,75 (49,5 píxeles), al centrar con un resto impar o al
/// desplazar una lista. Entonces los píxeles del dibujo caen justo en los bordes de los de la pantalla y salen de 5 y
/// de 7 en vez de 6, y con Impeller los bordes se suavizan. [SpritePixel] y [EscenaPixel] ya lo usan dos veces:
///
/// - por fuera de su `RepaintBoundary`, para que la capa caiga en un píxel entero cada vez que se pinta lo de alrededor
///   (al desplazar una lista, por ejemplo);
/// - por dentro, para corregir lo que no vuelve a pintar el padre (una transición de página que mueve la capa): se
///   recalcula con cada cambio de fotograma y con cada paso de la animación de la página.
///
/// Solo hace falta usarlo a mano para pintar pixel art con un `CustomPaint` propio.
class RejillaPixel extends SingleChildRenderObjectWidget {
  const RejillaPixel({super.key, super.child});

  static double _densidad(BuildContext context) =>
      MediaQuery.maybeDevicePixelRatioOf(context) ?? View.maybeOf(context)?.devicePixelRatio ?? 1;

  @override
  RenderRejillaPixel createRenderObject(BuildContext context) => RenderRejillaPixel(_densidad(context));

  @override
  void updateRenderObject(BuildContext context, RenderRejillaPixel renderObject) {
    renderObject.dpr = _densidad(context);
  }
}

/// El [RenderBox] de [RejillaPixel].
class RenderRejillaPixel extends RenderProxyBox {
  RenderRejillaPixel(this._dpr, [RenderBox? child]) : super(child);

  /// La densidad de la pantalla: píxeles físicos por punto lógico.
  double get dpr => _dpr;
  double _dpr;
  set dpr(double valor) {
    if (valor == _dpr) return;
    _dpr = valor;
    markNeedsPaint();
  }

  /// Lo que se movió el hijo la última vez que se pintó, en puntos lógicos (menos de medio píxel físico por eje).
  Offset get desfase => _desfase;
  Offset _desfase = Offset.zero;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    // localToGlobal da puntos lógicos de la pantalla; por la densidad, píxeles físicos. Lo que falta para el entero
    // más cercano es lo que hay que mover el hijo.
    final global = localToGlobal(Offset.zero);
    double resto(double valor) => ((valor * _dpr).roundToDouble() - valor * _dpr) / _dpr;
    _desfase = global.isFinite ? Offset(resto(global.dx), resto(global.dy)) : Offset.zero;
    context.paintChild(child, offset + _desfase);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.translateByDouble(_desfase.dx, _desfase.dy, 0, 1);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => result.addWithPaintOffset(
    offset: _desfase,
    position: position,
    hitTest: (result, transformado) => super.hitTestChildren(result, position: transformado),
  );
}
