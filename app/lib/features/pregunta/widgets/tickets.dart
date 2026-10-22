import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../../../widgets/movimiento/hapticos.dart';
import '../../../widgets/movimiento/ticket.dart';
import 'estilo.dart';

// Tickets de «Pregunta» (y de Mi situación): el papel de turno de la marca, en tranquilo. Sin giros ni confeti.

/// Ticket vertical de alto variable: [cuerpo] arriba, la línea troquelada con una muesca a cada lado y [talon] abajo.
///
/// A diferencia de [TicketBorder] solo, que necesita saber a qué distancia va el corte, aquí el corte sale del alto
/// que acaba teniendo el cuerpo (cambia con el texto y con el tamaño de letra). Ocupa todo el ancho que le dan y no es
/// pulsable: los botones van dentro.
class TicketVertical extends MultiChildRenderObjectWidget {
  TicketVertical({
    super.key,
    required Widget cuerpo,
    required Widget talon,
    required this.color,
    this.colorTalon,
    this.colorPerforado,
    this.borde = BorderSide.none,
    this.sombras = const [],
    this.radio = Radios.m,
    this.radioMuesca = 9,
  }) : super(children: [cuerpo, talon]);

  /// Papel del cuerpo.
  final Color color;

  /// Papel del talón; si es null, el mismo que el cuerpo.
  final Color? colorTalon;

  /// Puntos de la línea troquelada (por defecto, los de [TicketBorder]).
  final Color? colorPerforado;
  final BorderSide borde;

  /// Sombras de papel, mejor las de [sombrasTicket]: las que no tienen desenfoque siguen la silueta y las desenfocadas
  /// van sobre el rectángulo redondeado ([pintarSombrasTicket]).
  final List<BoxShadow> sombras;
  final double radio;
  final double radioMuesca;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderTicketVertical(
    color: color,
    colorTalon: colorTalon,
    colorPerforado: colorPerforado,
    borde: borde,
    sombras: sombras,
    radio: radio,
    radioMuesca: radioMuesca,
  );

  @override
  void updateRenderObject(BuildContext context, RenderTicketVertical renderObject) {
    renderObject
      ..color = color
      ..colorTalon = colorTalon
      ..colorPerforado = colorPerforado
      ..borde = borde
      ..sombras = sombras
      ..radio = radio
      ..radioMuesca = radioMuesca;
  }
}

class _DatosTicket extends ContainerBoxParentData<RenderBox> {}

/// El render de [TicketVertical]: coloca el cuerpo y el talón uno debajo del otro y pinta el papel, con el corte
/// donde acaba el cuerpo.
class RenderTicketVertical extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _DatosTicket>, RenderBoxContainerDefaultsMixin<RenderBox, _DatosTicket> {
  RenderTicketVertical({
    required this._color,
    required this._colorTalon,
    required this._colorPerforado,
    required this._borde,
    required this._sombras,
    required this._radio,
    required this._radioMuesca,
  });

  Color _color;
  set color(Color valor) {
    if (valor == _color) return;
    _color = valor;
    markNeedsPaint();
  }

  Color? _colorTalon;
  set colorTalon(Color? valor) {
    if (valor == _colorTalon) return;
    _colorTalon = valor;
    markNeedsPaint();
  }

  Color? _colorPerforado;
  set colorPerforado(Color? valor) {
    if (valor == _colorPerforado) return;
    _colorPerforado = valor;
    markNeedsPaint();
  }

  BorderSide _borde;
  set borde(BorderSide valor) {
    if (valor == _borde) return;
    _borde = valor;
    markNeedsPaint();
  }

  List<BoxShadow> _sombras;
  set sombras(List<BoxShadow> valor) {
    if (listEquals(valor, _sombras)) return;
    _sombras = valor;
    markNeedsPaint();
  }

  double _radio;
  set radio(double valor) {
    if (valor == _radio) return;
    _radio = valor;
    markNeedsPaint();
  }

  double _radioMuesca;
  set radioMuesca(double valor) {
    if (valor == _radioMuesca) return;
    _radioMuesca = valor;
    markNeedsPaint();
  }

  /// Alto del cuerpo: ahí va la línea troquelada.
  double _corte = 0;

  RenderBox get _cuerpo => firstChild!;
  RenderBox get _talon => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _DatosTicket) child.parentData = _DatosTicket();
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      math.max(_cuerpo.getMinIntrinsicWidth(double.infinity), _talon.getMinIntrinsicWidth(double.infinity));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      math.max(_cuerpo.getMaxIntrinsicWidth(double.infinity), _talon.getMaxIntrinsicWidth(double.infinity));

  @override
  double computeMinIntrinsicHeight(double width) =>
      _cuerpo.getMinIntrinsicHeight(width) + _talon.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _cuerpo.getMaxIntrinsicHeight(width) + _talon.getMaxIntrinsicHeight(width);

  /// Los dos trozos miden lo mismo de ancho: todo el disponible (o, sin límite, lo que pida el más ancho).
  BoxConstraints _paraHijos(BoxConstraints restricciones) {
    final ancho = restricciones.hasBoundedWidth
        ? restricciones.maxWidth
        : restricciones.constrainWidth(computeMaxIntrinsicWidth(double.infinity));
    return BoxConstraints.tightFor(width: ancho);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final hijos = _paraHijos(constraints);
    final alto = _cuerpo.getDryLayout(hijos).height + _talon.getDryLayout(hijos).height;
    return constraints.constrain(Size(hijos.maxWidth, alto));
  }

  @override
  void performLayout() {
    final hijos = _paraHijos(constraints);
    _cuerpo.layout(hijos, parentUsesSize: true);
    _talon.layout(hijos, parentUsesSize: true);
    (_cuerpo.parentData! as _DatosTicket).offset = Offset.zero;
    (_talon.parentData! as _DatosTicket).offset = Offset(0, _cuerpo.size.height);
    _corte = _cuerpo.size.height;
    size = constraints.constrain(Size(hijos.maxWidth, _cuerpo.size.height + _talon.size.height));
  }

  TicketBorder get _forma => TicketBorder(
    side: _borde,
    radio: _radio,
    radioMuesca: _radioMuesca,
    talon: math.max(0, size.height - _corte),
    ladoTalon: LadoTalon.abajo,
    colorTalon: _colorTalon,
    colorPerforado: _colorPerforado,
  );

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final rect = offset & size;
    final forma = _forma;
    // Como en los demás tickets: las sombras sin desenfoque siguen la silueta, muescas incluidas, y las desenfocadas
    // van sobre el rectángulo redondeado (baratas en el móvil; ver sombrasTicket).
    pintarSombrasTicket(canvas, rect, silueta: forma, sombras: _sombras, radio: _radio);
    canvas.drawPath(forma.getOuterPath(rect), Paint()..color = _color);
    // Talón de otro color, línea troquelada y borde.
    forma.paint(canvas, rect);
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);
}

/// Ticket pulsable para preguntar algo con un toque: preguntas de ejemplo (con su icono) y, con [compacto],
/// sugerencias para seguir. El texto va en el cuerpo y el avión de papel de «enviar», en el talón. Se hunde un poco
/// mientras se pulsa; la onda respeta la forma del ticket.
class TicketPregunta extends StatelessWidget {
  const TicketPregunta({super.key, required this.texto, required this.onTap, this.icono, this.compacto = false});

  final String texto;
  final VoidCallback onTap;

  /// Icono a la izquierda (solo en los ejemplos). Es decorativo.
  final TuIcono? icono;

  /// Sugerencia: más pequeño, sin sombra y con el texto del color principal.
  final bool compacto;

  /// Ancho del talón con el avión de papel.
  static const anchoTalon = 44.0;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final colores = context.colores;
    final icono = this.icono;
    final fondo = compacto ? tinteMarca(esquema) : colores.ticket;
    final tinta = compacto ? esquema.primary : colores.tintaTicket;
    final forma = TicketBorder(
      radio: compacto ? Radios.s : Radios.m - Espacio.xs,
      radioMuesca: compacto ? 6 : 8,
      talon: TicketPregunta.anchoTalon,
      colorTalon: esquema.primary,
      colorPerforado: fondo,
      side: BorderSide(color: compacto ? bordeTinte(esquema.primary) : esquema.outlineVariant),
    );
    final estilo = compacto
        ? tema.textTheme.labelLarge?.copyWith(color: tinta, fontWeight: FontWeight.w700)
        : tema.textTheme.titleMedium?.copyWith(color: tinta, fontWeight: FontWeight.w700);

    final cuerpo = Padding(
      padding: compacto
          ? const EdgeInsetsDirectional.fromSTEB(Espacio.m, Espacio.s, Espacio.s + Espacio.xs, Espacio.s)
          : const EdgeInsetsDirectional.fromSTEB(Espacio.m, Espacio.s + Espacio.xs, Espacio.m, Espacio.s + Espacio.xs),
      child: Row(
        mainAxisSize: compacto ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (icono != null) ...[
            IconoTuTurno(icono, size: Espacio.xl, decorativo: true),
            const SizedBox(width: Espacio.m - Espacio.xs),
          ],
          Flexible(
            fit: compacto ? FlexFit.loose : FlexFit.tight,
            child: Text(texto, style: estilo),
          ),
        ],
      ),
    );

    return TicketPulsable(
      forma: forma,
      decoracion: ShapeDecoration(color: fondo, shape: forma),
      elevacion: compacto ? 0 : 0.7,
      // Pregunta no se gamifica: como mucho, un clic suave.
      vibrar: false,
      recortar: false,
      onTap: () {
        Hapticos.seleccion();
        onTap();
      },
      child: Semantics(
        button: true,
        hint: 'Preguntar',
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: compacto ? Espacio.xxl : Espacio.xxl + Espacio.s),
          child: Row(
            mainAxisSize: compacto ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Flexible(fit: compacto ? FlexFit.loose : FlexFit.tight, child: cuerpo),
              SizedBox(
                width: anchoTalon,
                child: Center(
                  child: IconoTuTurno(
                    TuIcono.enviar,
                    estilo: EstiloIcono.mono,
                    color: esquema.onPrimary,
                    size: compacto ? Espacio.m + Espacio.xs : Espacio.l - Espacio.xs,
                    decorativo: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
