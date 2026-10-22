import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../../../widgets/movimiento/ticket.dart';

/// Hacia dónde sale la cola del bocadillo (donde está quien habla).
enum LadoCola { izquierda, arriba }

/// Bocadillo de cómic de papel recortado: lo que dice Tut. Papel de ticket del tema con su tinta (contraste AAA) y
/// sombra de papel; la cola apunta a Tut.
class Bocadillo extends StatelessWidget {
  const Bocadillo({
    super.key,
    required this.child,
    this.cola = LadoCola.izquierda,
    this.posicionCola = 0.5,
    this.padding = const EdgeInsets.symmetric(horizontal: Espacio.m + 2, vertical: Espacio.m - 2),
  });

  final Widget child;
  final LadoCola cola;

  /// Dónde sale la cola a lo largo de su lado, de 0 a 1.
  final double posicionCola;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final forma = BocadilloBorder(cola: cola, posicionCola: posicionCola);
    final hueco = switch (cola) {
      LadoCola.izquierda => const EdgeInsets.only(left: BocadilloBorder.largoCola),
      LadoCola.arriba => const EdgeInsets.only(top: BocadilloBorder.largoCola),
    };
    // La sombra amplia va sobre el cuerpo redondeado (sin la cola), barata en el móvil; la corta sigue la silueta.
    return SombraTicket(
      forma: forma,
      radio: forma.radio,
      margen: hueco,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: colores.ticket, shape: forma),
        child: Padding(
          padding: hueco + padding,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: colores.tintaTicket),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Forma del [Bocadillo]: rectángulo redondeado con una cola triangular, un poco torcida (cortada a mano). La cola
/// queda dentro de la caja del widget: a su lado se reserva [largoCola].
@immutable
class BocadilloBorder extends ShapeBorder {
  const BocadilloBorder({this.cola = LadoCola.izquierda, this.posicionCola = 0.5, this.radio = Radios.m});

  static const largoCola = 12.0;
  static const _anchoCola = 18.0;

  final LadoCola cola;
  final double posicionCola;
  final double radio;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final cuerpo = switch (cola) {
      LadoCola.izquierda => Rect.fromLTRB(rect.left + largoCola, rect.top, rect.right, rect.bottom),
      LadoCola.arriba => Rect.fromLTRB(rect.left, rect.top + largoCola, rect.right, rect.bottom),
    };
    final r = math.min(radio, cuerpo.shortestSide / 2);
    final camino = Path()..addRRect(RRect.fromRectAndRadius(cuerpo, Radius.circular(r)));
    final punta = Path();
    switch (cola) {
      case LadoCola.izquierda:
        final margen = r + _anchoCola / 2;
        final y = (cuerpo.top + cuerpo.height * posicionCola).clamp(cuerpo.top + margen, cuerpo.bottom - margen);
        punta
          ..moveTo(cuerpo.left + 1, y - _anchoCola / 2)
          ..lineTo(rect.left, y + 2)
          ..lineTo(cuerpo.left + 1, y + _anchoCola / 2)
          ..close();
      case LadoCola.arriba:
        final margen = r + _anchoCola / 2;
        final x = (cuerpo.left + cuerpo.width * posicionCola).clamp(cuerpo.left + margen, cuerpo.right - margen);
        punta
          ..moveTo(x - _anchoCola / 2, cuerpo.top + 1)
          ..lineTo(x - 3, rect.top)
          ..lineTo(x + _anchoCola / 2, cuerpo.top + 1)
          ..close();
    }
    return Path.combine(PathOperation.union, camino, punta);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => BocadilloBorder(cola: cola, posicionCola: posicionCola, radio: radio * t);

  @override
  bool operator ==(Object other) =>
      other is BocadilloBorder && other.cola == cola && other.posicionCola == posicionCola && other.radio == radio;

  @override
  int get hashCode => Object.hash(cola, posicionCola, radio);
}

/// Tut ([MascotaTut]) en una caja ajustada a su ticket: el lienzo de Tut es cuadrado y deja sitio arriba para el
/// confeti y las burbujas, que siguen viéndose porque sobresalen de la caja sin recortarse.
class TutAjustado extends StatelessWidget {
  const TutAjustado({
    super.key,
    required this.tamano,
    this.expresion = ExpresionTut.neutral,
    this.animada = true,
    this.pegatina = false,
    this.semanticLabel,
    this.decorativo = false,
  });

  /// Lado del lienzo de Tut. La caja mide [tamano] × 0,86 de ancho y × 0,7 de alto.
  final double tamano;
  final ExpresionTut expresion;
  final bool animada;
  final bool pegatina;
  final String? semanticLabel;
  final bool decorativo;

  static const anchoRelativo = 0.86;
  static const altoRelativo = 0.7;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamano * anchoRelativo,
      height: tamano * altoRelativo,
      child: OverflowBox(
        minWidth: tamano,
        maxWidth: tamano,
        minHeight: tamano,
        maxHeight: tamano,
        // El ticket de Tut ocupa del 25 % al 82 % del alto de su lienzo: así queda centrado en la caja.
        alignment: const Alignment(0, 0.3),
        child: MascotaTut(
          expresion: expresion,
          size: tamano,
          animada: animada,
          pegatina: pegatina,
          semanticLabel: semanticLabel,
          decorativo: decorativo,
        ),
      ),
    );
  }
}
