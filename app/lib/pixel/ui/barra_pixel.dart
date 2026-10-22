import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../../tema.dart';
import 'estilo_pixel.dart';
import 'pintura_pixel.dart';

/// Barra de progreso por segmentos, como la vida de un juego de 8 bits.
///
/// Cuando [valor] cambia, el relleno avanza (o retrocede) a saltos de una unidad pixel, con el borde que avanza
/// encendido en blanco. Con «reducir animaciones», salta directamente al valor nuevo.
///
/// Los segmentos que faltan son huecos con borde azul claro (5,2:1 sobre el azul noche de la barra), como los
/// corazones vacíos de un juego de 8 bits: se ve cuánto falta y cuántos hay. Sobre un [FondoPixel] oscuro, la barra
/// lleva un filo alrededor (y ocupa una unidad más por cada lado).
///
/// El lector de pantalla la lee como [etiqueta] con su porcentaje (o [textoValor], como «3 de 10 escenas»).
class BarraPixel extends StatefulWidget {
  const BarraPixel({
    super.key,
    required this.valor,
    this.segmentos = 10,
    this.etiqueta = 'Progreso',
    this.textoValor,
    this.color = ColoresUiPixel.amarillo,
    this.luz = ColoresUiPixel.amarilloLuz,
    this.sombraColor = ColoresUiPixel.ocre,
    this.alto = 4,
    this.sombra = true,
    this.duracion = const Duration(milliseconds: 650),
  }) : assert(segmentos > 0),
       assert(alto >= 2);

  /// De 0 a 1.
  final double valor;
  final int segmentos;
  final String etiqueta;
  final String? textoValor;

  /// Relleno de los segmentos, con su [luz] (fila de arriba) y su [sombraColor] (fila de abajo).
  final Color color;
  final Color luz;
  final Color sombraColor;

  /// Alto de los segmentos, en unidades pixel.
  final int alto;

  /// Sombra dura debajo de la barra (sobre un fondo oscuro, como el del HUD, no hace falta).
  final bool sombra;
  final Duration duracion;

  @override
  State<BarraPixel> createState() => _BarraPixelState();
}

class _BarraPixelState extends State<BarraPixel> with SingleTickerProviderStateMixin {
  late final AnimationController _animacion = AnimationController(vsync: this, value: 1);
  late double _desde = _limitar(widget.valor);
  late double _hasta = _desde;

  static double _limitar(double valor) => valor.isNaN ? 0 : valor.clamp(0.0, 1.0);

  double get _actual => lerpDouble(_desde, _hasta, Curves.easeOutCubic.transform(_animacion.value))!;

  @override
  void didUpdateWidget(BarraPixel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nuevo = _limitar(widget.valor);
    if (nuevo == _hasta) return;
    _desde = _actual;
    _hasta = nuevo;
    final tiempo = duracion(context, widget.duracion);
    if (tiempo == Duration.zero) {
      _animacion.value = 1;
    } else {
      _animacion
        ..duration = tiempo
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final filo = filoPixel(context, contorno: ColoresUiPixel.noche);
    final alto = (widget.alto + 4 + (widget.sombra ? 1 : 0) + (filo == null ? 0 : 2)) * u;
    final valor = widget.textoValor ?? '${(_limitar(widget.valor) * 100).round()} %';
    return Semantics(
      container: true,
      label: widget.etiqueta,
      value: valor,
      child: LayoutBuilder(
        builder: (context, restricciones) {
          final ancho = restricciones.hasBoundedWidth ? restricciones.maxWidth : widget.segmentos * 8 * u;
          return AjustePixel(
            child: CustomPaint(
              size: Size(ancho, alto),
              painter: _PintorBarra(
                animacion: _animacion,
                desde: _desde,
                hasta: _hasta,
                segmentos: widget.segmentos,
                color: widget.color,
                luz: widget.luz,
                sombraColor: widget.sombraColor,
                sombra: widget.sombra,
                filo: filo,
                u: u,
                dpr: dpr,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PintorBarra extends CustomPainter {
  _PintorBarra({
    required this.animacion,
    required this.desde,
    required this.hasta,
    required this.segmentos,
    required this.color,
    required this.luz,
    required this.sombraColor,
    required this.sombra,
    required this.filo,
    required this.u,
    required this.dpr,
  }) : super(repaint: animacion);

  final Animation<double> animacion;

  /// El relleno va de [desde] a [hasta] con [animacion].
  final double desde;
  final double hasta;
  final int segmentos;
  final Color color;
  final Color luz;
  final Color sombraColor;
  final bool sombra;
  final Color? filo;
  final double u;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    var bordes = Rect.fromLTWH(0, 0, alPixelFisico(size.width, dpr), alPixelFisico(size.height, dpr));
    final filo = this.filo;
    if (filo != null) {
      pintarFilo(canvas, bordes, u, 1, filo);
      bordes = bordes.deflate(u);
    }
    final caja = Rect.fromLTWH(bordes.left, bordes.top, bordes.width, bordes.height - (sombra ? u : 0));
    pintarCajaPixel(
      canvas,
      caja,
      u,
      EstiloCajaPixel(
        relleno: ColoresUiPixel.noche,
        contorno: ColoresUiPixel.noche,
        sombra: sombra ? ColoresUiPixel.noche : null,
        esquina: 1,
      ),
    );
    // Dentro: una unidad de margen y los segmentos separados por una unidad.
    final dentro = caja.deflate(2 * u);
    if (dentro.width <= 0 || dentro.height <= 0) return;
    final huecos = (segmentos - 1) * u;
    final anchoSegmentos = dentro.width - huecos;
    if (anchoSegmentos <= 0) return;
    final t = Curves.easeOutCubic.transform(animacion.value);
    var lleno = lerpDouble(desde, hasta, t)! * anchoSegmentos;
    final encendido = animacion.isAnimating && hasta > desde;
    final hueco = pincelPixel(ColoresUiPixel.azulClaro);
    final oscuro = pincelPixel(ColoresUiPixel.noche);
    final relleno = pincelPixel(color);
    final pincelLuz = pincelPixel(luz);
    final pincelSombra = pincelPixel(sombraColor);
    final blanco = pincelPixel(ColoresUiPixel.blanco);
    for (var i = 0; i < segmentos; i++) {
      final izquierda = alPixelFisico(dentro.left + i * (anchoSegmentos / segmentos) + i * u, dpr);
      final derecha = alPixelFisico(dentro.left + (i + 1) * (anchoSegmentos / segmentos) + i * u, dpr);
      final segmento = Rect.fromLTRB(izquierda, dentro.top, derecha, dentro.bottom);
      // El segmento vacío: un hueco con borde de una unidad (si es demasiado pequeño, entero del color del borde).
      canvas.drawRect(segmento, hueco);
      final dentroHueco = segmento.deflate(u);
      if (dentroHueco.width > 0 && dentroHueco.height > 0) canvas.drawRect(dentroHueco, oscuro);
      if (lleno <= 0) continue;
      final anchoSegmento = segmento.width;
      // El relleno avanza a saltos de una unidad; si cubre el segmento entero, lo llena aunque no mida unidades
      // exactas.
      final ocupado = lleno >= anchoSegmento - 0.001 ? anchoSegmento : (lleno / u).floorToDouble() * u;
      lleno -= anchoSegmento;
      if (ocupado <= 0) continue;
      final parte = Rect.fromLTWH(segmento.left, segmento.top, ocupado, segmento.height);
      canvas
        ..drawRect(parte, relleno)
        ..drawRect(Rect.fromLTWH(parte.left, parte.top, parte.width, u), pincelLuz)
        ..drawRect(Rect.fromLTWH(parte.left, parte.bottom - u, parte.width, u), pincelSombra);
      // Mientras sube, la punta del relleno brilla.
      if (encendido && lleno < 0) canvas.drawRect(Rect.fromLTWH(parte.right - u, parte.top, u, parte.height), blanco);
    }
  }

  @override
  bool shouldRepaint(_PintorBarra oldDelegate) =>
      oldDelegate.segmentos != segmentos ||
      oldDelegate.color != color ||
      oldDelegate.luz != luz ||
      oldDelegate.sombraColor != sombraColor ||
      oldDelegate.sombra != sombra ||
      oldDelegate.filo != filo ||
      oldDelegate.u != u ||
      oldDelegate.dpr != dpr ||
      oldDelegate.desde != desde ||
      oldDelegate.hasta != hasta ||
      oldDelegate.animacion != animacion;
}
