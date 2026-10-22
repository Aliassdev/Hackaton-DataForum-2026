import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'estilo_pixel.dart';
import 'pintura_pixel.dart';

/// Duraciones de la transición pixel: corta, para entrar en Vive el caso sin hacer esperar.
abstract final class DuracionTransicionPixel {
  static const entrada = Duration(milliseconds: 460);
  static const salida = Duration(milliseconds: 360);

  /// Con «reducir animaciones», un fundido sencillo.
  static const fundido = Duration(milliseconds: 200);
}

/// Transición de página de juego antiguo: la pantalla de antes se apaga a bloques (un tramado ordenado, como los
/// fundidos de 8 bits) hasta quedar azul noche, y la nueva aparece a bloques del mismo modo. Al volver, al revés.
///
/// Es un `transitionsBuilder` para el `CustomTransitionPage` de go_router (o un `PageRouteBuilder`). Con «reducir
/// animaciones», es un fundido sin movimiento.
///
/// Mientras dura, no se puede tocar nada: ni la página nueva (que en la primera mitad aún no se ve) ni la de debajo.
Widget transicionPixel(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
    return FadeTransition(opacity: animation, child: child);
  }
  return TransicionPixel(animacion: animation, child: child);
}

/// Página de go_router con la [transicionPixel]. Con [reducirMovimiento], un fundido corto.
class PaginaPixel<T> extends CustomTransitionPage<T> {
  const PaginaPixel({
    required super.child,
    bool reducirMovimiento = false,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  }) : super(
         transitionsBuilder: transicionPixel,
         transitionDuration: reducirMovimiento ? DuracionTransicionPixel.fundido : DuracionTransicionPixel.entrada,
         reverseTransitionDuration: reducirMovimiento
             ? DuracionTransicionPixel.fundido
             : DuracionTransicionPixel.salida,
       );
}

/// La [PaginaPixel] de [state] para un `pageBuilder` de go_router, respetando «reducir animaciones»:
///
/// ```dart
/// GoRoute(path: '/juego', pageBuilder: (context, state) => paginaPixel(context, state, const JuegoScreen()))
/// ```
PaginaPixel<void> paginaPixel(BuildContext context, GoRouterState state, Widget child) => PaginaPixel<void>(
  key: state.pageKey,
  name: state.name ?? state.path,
  arguments: <String, String>{...state.pathParameters, ...state.uri.queryParameters},
  restorationId: state.pageKey.value,
  reducirMovimiento: MediaQuery.disableAnimationsOf(context),
  child: child,
);

/// Pinta [child] según [animacion] (de 0 a 1) con el fundido a bloques de [transicionPixel]: hasta la mitad, bloques
/// de [color] van tapando lo que haya debajo; desde la mitad, [child] aparece a bloques sobre [color].
///
/// Los bloques miden el lado corto de la pantalla entre [bloques] y avanzan a saltos (ocho por mitad). Mientras la
/// animación está a medias, se queda con todos los toques (no llegan ni a [child] ni a lo de debajo).
class TransicionPixel extends SingleChildRenderObjectWidget {
  const TransicionPixel({
    super.key,
    required this.animacion,
    this.color = ColoresUiPixel.noche,
    this.bloques = 14,
    super.child,
  }) : assert(bloques > 0);

  final Animation<double> animacion;
  final Color color;
  final int bloques;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTransicionPixel(animacion, color, bloques, MediaQuery.maybeDevicePixelRatioOf(context) ?? 1);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderTransicionPixel)
      ..animacion = animacion
      ..color = color
      ..bloques = bloques
      ..dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
  }
}

/// Umbrales de un tramado ordenado (Bayer 8 × 8): el orden en que se encienden los bloques.
const _bayer = [
  0, 32, 8, 40, 2, 34, 10, 42, //
  48, 16, 56, 24, 50, 18, 58, 26,
  12, 44, 4, 36, 14, 46, 6, 38,
  60, 28, 52, 20, 62, 30, 54, 22,
  3, 35, 11, 43, 1, 33, 9, 41,
  51, 19, 59, 27, 49, 17, 57, 25,
  15, 47, 7, 39, 13, 45, 5, 37,
  63, 31, 55, 23, 61, 29, 53, 21,
];

class _RenderTransicionPixel extends RenderProxyBox {
  _RenderTransicionPixel(this._animacion, this._color, this._bloques, this._dpr);

  Animation<double> _animacion;
  set animacion(Animation<double> valor) {
    if (identical(valor, _animacion)) return;
    if (attached) _animacion.removeListener(markNeedsPaint);
    _animacion = valor;
    if (attached) _animacion.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  Color _color;
  set color(Color valor) {
    if (valor == _color) return;
    _color = valor;
    markNeedsPaint();
  }

  int _bloques;
  set bloques(int valor) {
    if (valor == _bloques) return;
    _bloques = valor;
    markNeedsPaint();
  }

  double _dpr;
  set dpr(double valor) {
    if (valor == _dpr) return;
    _dpr = valor;
    markNeedsPaint();
  }

  final _recorte = LayerHandle<ClipPathLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animacion.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _animacion.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _recorte.layer = null;
    super.dispose();
  }

  /// A medias, los toques no pasan: en la primera mitad la página nueva no se ve (se tocaría un botón invisible) y en
  /// la segunda aún está tapada en parte. Tampoco llegan a la página de debajo (que se iría dos veces).
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final t = _animacion.value;
    if (t > 0 && t < 1) {
      if (!size.contains(position)) return false;
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return super.hitTest(result, position: position);
  }

  /// Avanza a saltos: ocho por cada mitad de la transición (llega a 1 un poco antes del final de la mitad).
  static double _escalon(double p) => math.min(1, (p * 9).floorToDouble() / 8);

  /// El momento (de 0 a 1) en que se enciende el bloque de la columna [c] y la fila [f].
  static double _orden(int c, int f) => (_bayer[(f % 8) * 8 + c % 8] + 0.5) / 64;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    final t = _animacion.value;
    if (child == null || t >= 1) {
      _recorte.layer = null;
      if (child != null) context.paintChild(child, offset);
      return;
    }
    if (t <= 0 || size.isEmpty) {
      _recorte.layer = null;
      return;
    }
    final lado = math.max(8.0, alPixelFisico(size.shortestSide / _bloques, _dpr));
    final columnas = (size.width / lado).ceil();
    final filas = (size.height / lado).ceil();
    final pincel = pincelPixel(_color);
    if (t < 0.5) {
      // Primera mitad: los bloques tapan lo de debajo; la página nueva aún no se ve.
      _recorte.layer = null;
      final umbral = _escalon(t / 0.5);
      final canvas = context.canvas;
      for (var f = 0; f < filas; f++) {
        for (var c = 0; c < columnas; c++) {
          if (_orden(c, f) < umbral) {
            canvas.drawRect(Rect.fromLTWH(offset.dx + c * lado, offset.dy + f * lado, lado, lado), pincel);
          }
        }
      }
      return;
    }
    // Segunda mitad: todo azul noche y la página nueva aparece a bloques, en el mismo orden.
    context.canvas.drawRect(offset & size, pincel);
    final umbral = _escalon((t - 0.5) / 0.5);
    final visibles = Path();
    for (var f = 0; f < filas; f++) {
      for (var c = 0; c < columnas; c++) {
        if (_orden(c, f) < umbral) visibles.addRect(Rect.fromLTWH(c * lado, f * lado, lado, lado));
      }
    }
    _recorte.layer = context.pushClipPath(
      needsCompositing,
      offset,
      Offset.zero & size,
      visibles,
      (context, offset) => context.paintChild(child, offset),
      clipBehavior: Clip.hardEdge,
      oldLayer: _recorte.layer,
    );
  }
}
