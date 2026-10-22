import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'barra_pixel.dart';
import 'boton_pixel.dart';
import 'estilo_pixel.dart';
import 'iconos_pixel.dart';
import 'pintura_pixel.dart';
import 'rotulo_pixel.dart';

/// La barra de arriba del juego: botón de volver, título del caso, los botones de la app ([acciones]: Glosario y
/// Ayuda, que van arriba a la derecha en todas las pantallas), progreso ([BarraPixel]) y cartas conseguidas.
///
/// Se ordena en dos filas: arriba, volver, el título (hasta dos líneas) y las acciones; debajo, a todo el ancho, la
/// barra con el contador de cartas a su derecha. Si al título le quedan menos de [anchoMinimoTitulo] puntos (pantalla
/// estrecha, letra grande o acciones anchas), pasa a su propia fila, entre las dos. Va encima de la escena, dentro del
/// área segura.
class HudPixel extends StatelessWidget {
  const HudPixel({
    super.key,
    required this.titulo,
    required this.progreso,
    this.cartas,
    this.totalCartas,
    this.onVolver,
    this.acciones = const [],
    this.segmentos = 10,
    this.etiquetaProgreso = 'Progreso del caso',
    this.textoProgreso,
  });

  /// Lo mínimo que se deja al título al lado de los botones; con menos, va en su propia fila.
  static const anchoMinimoTitulo = 140.0;

  final String titulo;

  /// De 0 a 1.
  final double progreso;

  /// Cartas conseguidas (null: sin contador) y cuántas hay.
  final int? cartas;
  final int? totalCartas;
  final VoidCallback? onVolver;

  /// Los botones de la app que van arriba a la derecha (Glosario y Ayuda, en ese orden).
  final List<Widget> acciones;
  final int segmentos;
  final String etiquetaProgreso;

  /// Lo que lee el lector de pantalla de la barra (por defecto, el porcentaje).
  final String? textoProgreso;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final onVolver = this.onVolver;
    final cartas = this.cartas;
    final total = totalCartas;
    final contador = cartas == null
        ? null
        : Semantics(
            container: true,
            label: 'Cartas conseguidas: $cartas${total == null ? '' : ' de $total'}',
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const IconoPixel(GlifoPixel.carta, color: ColoresUiPixel.amarillo),
                  SizedBox(width: 2 * u),
                  // Cifras de la letra de rótulo: en Pixelify, «2/5» se leería «2/S».
                  RotuloPixel(total == null ? '$cartas' : '$cartas/$total', color: ColoresUiPixel.papel),
                ],
              ),
            ),
          );
    return AjustePixel(
      child: CustomPaint(
        painter: _PintorHud(u: u, dpr: dpr),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(3 * u, 3 * u, 3 * u, 5 * u),
            // Las piezas del HUD están sobre su banda azul noche.
            child: FondoPixel(
              color: ColoresUiPixel.noche,
              pintar: false,
              child: _DisposicionHud(
                u: u,
                volver: onVolver == null
                    ? null
                    : BotonPixel(
                        icono: const IconoPixel(GlifoPixel.atras),
                        semantica: 'Volver',
                        variante: VarianteBotonPixel.secundario,
                        onPressed: onVolver,
                      ),
                titulo: Semantics(
                  header: true,
                  child: Text.rich(
                    textoConCifras(
                      titulo,
                      estiloTextoPixel(context, TipoTextoPixel.titulo, color: ColoresUiPixel.amarillo),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                acciones: acciones.isEmpty
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (i, accion) in acciones.indexed) ...[if (i > 0) SizedBox(width: 2 * u), accion],
                        ],
                      ),
                barra: BarraPixel(
                  valor: progreso,
                  segmentos: segmentos,
                  alto: 3,
                  sombra: false,
                  etiqueta: etiquetaProgreso,
                  textoValor: textoProgreso,
                ),
                contador: contador,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Banda azul noche con un filo amarillo abajo y una sombra dura sobre la escena.
class _PintorHud extends CustomPainter {
  const _PintorHud({required this.u, required this.dpr});

  final double u;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    final ancho = alPixelFisico(size.width, dpr);
    final alto = alPixelFisico(size.height, dpr);
    canvas
      ..drawRect(Rect.fromLTWH(0, 0, ancho, alto - 2 * u), pincelPixel(ColoresUiPixel.noche))
      ..drawRect(Rect.fromLTWH(0, alto - 3 * u, ancho, u), pincelPixel(ColoresUiPixel.amarillo))
      ..drawRect(Rect.fromLTWH(0, alto - 2 * u, ancho, u), pincelPixel(ColoresUiPixel.ocre))
      ..drawRect(Rect.fromLTWH(0, alto - u, ancho, u), pincelPixel(ColoresUiPixel.noche));
  }

  @override
  bool shouldRepaint(_PintorHud oldDelegate) => oldDelegate.u != u || oldDelegate.dpr != dpr;
}

enum _PiezaHud { volver, titulo, acciones, barra, contador }

class _DisposicionHud extends SlottedMultiChildRenderObjectWidget<_PiezaHud, RenderBox> {
  const _DisposicionHud({
    required this.u,
    required this.volver,
    required this.titulo,
    required this.acciones,
    required this.barra,
    required this.contador,
  });

  final double u;
  final Widget? volver;
  final Widget titulo;
  final Widget? acciones;
  final Widget barra;
  final Widget? contador;

  @override
  Iterable<_PiezaHud> get slots => _PiezaHud.values;

  @override
  Widget? childForSlot(_PiezaHud slot) => switch (slot) {
    _PiezaHud.volver => volver,
    _PiezaHud.titulo => titulo,
    _PiezaHud.acciones => acciones,
    _PiezaHud.barra => barra,
    _PiezaHud.contador => contador,
  };

  @override
  _RenderDisposicionHud createRenderObject(BuildContext context) => _RenderDisposicionHud(u);

  @override
  void updateRenderObject(BuildContext context, _RenderDisposicionHud renderObject) => renderObject.u = u;
}

class _RenderDisposicionHud extends RenderBox with SlottedContainerRenderObjectMixin<_PiezaHud, RenderBox> {
  _RenderDisposicionHud(this._u);

  double _u;
  set u(double valor) {
    if (valor == _u) return;
    _u = valor;
    markNeedsLayout();
  }

  /// Si el título va en su propia fila (lo dice la última disposición).
  bool tituloEnSuFila = false;

  RenderBox? _pieza(_PiezaHud pieza) => childForSlot(pieza);

  /// En orden de lectura (también para el lector de pantalla).
  @override
  Iterable<RenderBox> get children => [for (final pieza in _PiezaHud.values) ?_pieza(pieza)];

  ({Size tamano, Map<_PiezaHud, Offset> sitios, bool tituloEnSuFila}) _disponer(
    BoxConstraints restricciones,
    Size Function(RenderBox, BoxConstraints) medir,
  ) {
    final hueco = 3 * _u;
    final huecoFila = 2 * _u;
    final ancho = restricciones.hasBoundedWidth ? restricciones.maxWidth : 400.0;
    final suelto = BoxConstraints(maxWidth: ancho);
    Size medida(_PiezaHud pieza, BoxConstraints c) {
      final hijo = _pieza(pieza);
      return hijo == null ? Size.zero : medir(hijo, c);
    }

    final volver = medida(_PiezaHud.volver, suelto);
    final acciones = medida(_PiezaHud.acciones, suelto);
    final hayVolver = _pieza(_PiezaHud.volver) != null;
    final hayAcciones = _pieza(_PiezaHud.acciones) != null;
    final lateral = (hayVolver ? volver.width + hueco : 0) + (hayAcciones ? acciones.width + hueco : 0);
    final enSuFila = ancho - lateral < HudPixel.anchoMinimoTitulo && (hayVolver || hayAcciones);
    final titulo = medida(_PiezaHud.titulo, BoxConstraints(maxWidth: math.max(0, enSuFila ? ancho : ancho - lateral)));
    final contador = medida(_PiezaHud.contador, suelto);
    final hayContador = _pieza(_PiezaHud.contador) != null;
    final barra = medida(
      _PiezaHud.barra,
      BoxConstraints.tightFor(width: math.max(0, ancho - (hayContador ? contador.width + hueco : 0))),
    );

    final sitios = <_PiezaHud, Offset>{};
    final alto1 = math.max(math.max(volver.height, acciones.height), enSuFila ? 0.0 : titulo.height);
    sitios[_PiezaHud.volver] = Offset(0, (alto1 - volver.height) / 2);
    sitios[_PiezaHud.acciones] = Offset(ancho - acciones.width, (alto1 - acciones.height) / 2);
    var y = alto1;
    if (enSuFila) {
      y += huecoFila;
      sitios[_PiezaHud.titulo] = Offset(0, y);
      y += titulo.height;
    } else {
      sitios[_PiezaHud.titulo] = Offset(hayVolver ? volver.width + hueco : 0, (alto1 - titulo.height) / 2);
    }
    y += huecoFila;
    final alto3 = math.max(barra.height, contador.height);
    sitios[_PiezaHud.barra] = Offset(0, y + (alto3 - barra.height) / 2);
    sitios[_PiezaHud.contador] = Offset(ancho - contador.width, y + (alto3 - contador.height) / 2);
    y += alto3;
    return (tamano: restricciones.constrain(Size(ancho, y)), sitios: sitios, tituloEnSuFila: enSuFila);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _disponer(constraints, ChildLayoutHelper.dryLayoutChild).tamano;

  @override
  void performLayout() {
    final disposicion = _disponer(constraints, ChildLayoutHelper.layoutChild);
    size = disposicion.tamano;
    tituloEnSuFila = disposicion.tituloEnSuFila;
    for (final pieza in _PiezaHud.values) {
      final hijo = _pieza(pieza);
      if (hijo != null) (hijo.parentData! as BoxParentData).offset = disposicion.sitios[pieza]!;
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) => HudPixel.anchoMinimoTitulo;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      children.fold(0.0, (suma, hijo) => suma + hijo.getMaxIntrinsicWidth(double.infinity)) + 9 * _u;

  @override
  double computeMinIntrinsicHeight(double width) =>
      _disponer(BoxConstraints(maxWidth: width), ChildLayoutHelper.dryLayoutChild).tamano.height;

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final hijo in children.toList().reversed) {
      final tocado = result.addWithPaintOffset(
        offset: (hijo.parentData! as BoxParentData).offset,
        position: position,
        hitTest: (result, transformado) => hijo.hitTest(result, position: transformado),
      );
      if (tocado) return true;
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final hijo in children) {
      context.paintChild(hijo, offset + (hijo.parentData! as BoxParentData).offset);
    }
  }
}
