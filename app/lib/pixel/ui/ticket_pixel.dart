import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../widgets/movimiento/hapticos.dart';
import 'estilo_pixel.dart';
import 'pintura_pixel.dart';
import 'pulsacion_pixel.dart';

/// El ticket de turno de TuTurno en versión pixel: papel con contorno escalonado, un talón de otro color separado
/// por una línea perforada y dos muescas mordidas justo donde se arranca.
///
/// [child] va en el cuerpo y [talon] (por ejemplo, el número de turno, mejor con `RotuloPixel`) en el talón. El talón
/// mide lo que pide su contenido (al menos [anchoTalon] unidades) y crece con la letra del sistema; si así ocupa más
/// del 45 % del ticket, va debajo del cuerpo, con la perforación en horizontal. El alto sale del contenido: dentro de
/// un `Center` o una celda no se estira.
///
/// Con [onPressed] se puede pulsar como un botón (baja una unidad y vibra). El lector de pantalla lo lee como una sola
/// cosa: [semantica] o, si no hay, todo el texto de dentro.
class TicketPixel extends StatefulWidget {
  const TicketPixel({
    super.key,
    required this.child,
    this.talon,
    this.anchoTalon = 28,
    this.colorPapel = ColoresUiPixel.papel,
    this.colorTalon = ColoresUiPixel.amarillo,
    this.tinta = ColoresUiPixel.noche,
    this.onPressed,
    this.semantica,
  });

  final Widget child;
  final Widget? talon;

  /// Ancho mínimo del talón, en unidades pixel.
  final int anchoTalon;
  final Color colorPapel;
  final Color colorTalon;

  /// Color del texto, del contorno y de la perforación.
  final Color tinta;
  final VoidCallback? onPressed;
  final String? semantica;

  @override
  State<TicketPixel> createState() => _TicketPixelState();
}

class _TicketPixelState extends State<TicketPixel> {
  late final _pulsacion = PulsacionPixel(() {
    if (mounted) setState(() {});
  });

  /// El anillo de foco (solo con teclado).
  bool _foco = false;

  /// Si tiene el foco de verdad (para el lector de pantalla).
  bool _tieneFoco = false;

  bool get _activo => widget.onPressed != null;

  void _activar() {
    final onPressed = widget.onPressed;
    if (onPressed == null) return;
    unawaited(Hapticos.toque());
    onPressed();
  }

  void _activarConTeclado() {
    if (!_activo) return;
    _pulsacion.pulsarYSoltar();
    _activar();
  }

  @override
  void didUpdateWidget(TicketPixel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_activo) {
      _pulsacion.reiniciar();
      _foco = false;
      _tieneFoco = false;
    }
  }

  @override
  void dispose() {
    _pulsacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final activo = _activo;
    final talon = widget.talon;
    final semantica = widget.semantica;
    Widget ticket = AjustePixel(
      child: _Ticket(
        u: u,
        dpr: dpr,
        anchoMinimoTalon: widget.anchoTalon * u,
        pulsado: _pulsacion.pulsada && activo,
        foco: _foco && activo,
        colorPapel: widget.colorPapel,
        colorTalon: widget.colorTalon,
        tinta: widget.tinta,
        filo: filoPixel(context, contorno: widget.tinta),
        cuerpo: FondoPixel(
          color: widget.colorPapel,
          pintar: false,
          child: DefaultTextStyle.merge(
            style: estiloTextoPixel(context, TipoTextoPixel.cuerpo, color: widget.tinta),
            child: widget.child,
          ),
        ),
        talon: talon == null
            ? null
            : FondoPixel(
                color: widget.colorTalon,
                pintar: false,
                child: DefaultTextStyle.merge(
                  style: estiloTextoPixel(context, TipoTextoPixel.etiqueta, color: widget.tinta),
                  textAlign: TextAlign.center,
                  child: talon,
                ),
              ),
      ),
    );
    if (semantica != null) ticket = ExcludeSemantics(child: ticket);
    // Siempre el mismo árbol (con onPressed o sin él): así lo de dentro no se vuelve a montar al activarlo.
    return FocusableActionDetector(
      enabled: activo,
      includeFocusSemantics: false,
      mouseCursor: activo ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (valor) => setState(() => _foco = valor),
      onFocusChange: (valor) => setState(() => _tieneFoco = valor),
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _activarConTeclado())},
      // Un solo nodo para el lector: el botón con todo su texto (o con [semantica]).
      child: MergeSemantics(
        child: Semantics(
          button: activo ? true : null,
          focusable: activo ? true : null,
          focused: activo ? _tieneFoco : null,
          label: semantica,
          onTap: activo ? _activar : null,
          child: GestureDetector(
            excludeFromSemantics: true,
            behavior: HitTestBehavior.opaque,
            onTapDown: activo ? (_) => _pulsacion.bajar() : null,
            onTapUp: activo ? (_) => _pulsacion.soltar() : null,
            onTapCancel: activo ? _pulsacion.cancelar : null,
            onTap: activo ? _activar : null,
            child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: ticket),
          ),
        ),
      ),
    );
  }
}

/// Medias anchuras de cada fila de una muesca (sin contar la columna de la perforación), desde el borde.
const _muesca = [3, 3, 2, 1];

/// Radio de las esquinas del ticket, en unidades.
const _esquina = 2;

enum _PiezaTicket { cuerpo, talon }

class _Ticket extends SlottedMultiChildRenderObjectWidget<_PiezaTicket, RenderBox> {
  const _Ticket({
    required this.cuerpo,
    required this.talon,
    required this.u,
    required this.dpr,
    required this.anchoMinimoTalon,
    required this.pulsado,
    required this.foco,
    required this.colorPapel,
    required this.colorTalon,
    required this.tinta,
    required this.filo,
  });

  final Widget cuerpo;
  final Widget? talon;
  final double u;
  final double dpr;
  final double anchoMinimoTalon;
  final bool pulsado;
  final bool foco;
  final Color colorPapel;
  final Color colorTalon;
  final Color tinta;
  final Color? filo;

  @override
  Iterable<_PiezaTicket> get slots => _PiezaTicket.values;

  @override
  Widget? childForSlot(_PiezaTicket slot) => switch (slot) {
    _PiezaTicket.cuerpo => cuerpo,
    _PiezaTicket.talon => talon,
  };

  @override
  _RenderTicket createRenderObject(BuildContext context) => _RenderTicket()..ajustar(this);

  @override
  void updateRenderObject(BuildContext context, _RenderTicket renderObject) => renderObject.ajustar(this);
}

/// Dónde va cada cosa del ticket (en puntos lógicos, desde su esquina de arriba a la izquierda, sin pulsar).
class _Disposicion {
  const _Disposicion({
    required this.tamano,
    required this.cuerpo,
    required this.talon,
    required this.horizontal,
    required this.corte,
  });

  final Size tamano;
  final Offset cuerpo;
  final Offset? talon;

  /// El talón va a la derecha (perforación en vertical) o debajo (perforación en horizontal).
  final bool horizontal;

  /// La columna (en horizontal) o la fila (debajo) de la perforación, desde la esquina de la caja del ticket.
  final double corte;
}

class _RenderTicket extends RenderBox with SlottedContainerRenderObjectMixin<_PiezaTicket, RenderBox> {
  double _u = 3;
  double _dpr = 1;
  double _anchoMinimoTalon = 84;
  bool _pulsado = false;
  bool _foco = false;
  Color _colorPapel = ColoresUiPixel.papel;
  Color _colorTalon = ColoresUiPixel.amarillo;
  Color _tinta = ColoresUiPixel.noche;
  Color? _filo;
  _Disposicion? _disposicion;

  void ajustar(_Ticket w) {
    if (w.u != _u ||
        w.anchoMinimoTalon != _anchoMinimoTalon ||
        w.pulsado != _pulsado ||
        (w.filo == null) != (_filo == null)) {
      markNeedsLayout();
    } else if (w.dpr != _dpr ||
        w.foco != _foco ||
        w.colorPapel != _colorPapel ||
        w.colorTalon != _colorTalon ||
        w.tinta != _tinta ||
        w.filo != _filo) {
      markNeedsPaint();
    }
    _u = w.u;
    _dpr = w.dpr;
    _anchoMinimoTalon = w.anchoMinimoTalon;
    _pulsado = w.pulsado;
    _foco = w.foco;
    _colorPapel = w.colorPapel;
    _colorTalon = w.colorTalon;
    _tinta = w.tinta;
    _filo = w.filo;
  }

  RenderBox? get _cuerpo => childForSlot(_PiezaTicket.cuerpo);
  RenderBox? get _talon => childForSlot(_PiezaTicket.talon);

  @override
  Iterable<RenderBox> get children => [?_cuerpo, ?_talon];

  double get _borde => _filo == null ? 0 : _u;

  /// Ancho del talón con su contenido y sus márgenes: tres unidades a cada lado (una es la perforación o el contorno).
  double _anchoTalon(RenderBox talon) =>
      math.max(_anchoMinimoTalon, talon.getMaxIntrinsicWidth(double.infinity) + 6 * _u);

  _Disposicion _disponer(BoxConstraints restricciones, Size Function(RenderBox, BoxConstraints) medir) {
    final u = _u;
    final borde = _borde;
    final cuerpo = _cuerpo;
    final talon = _talon;
    final anchoTalon = talon == null ? 0.0 : _anchoTalon(talon);
    final natural = (cuerpo?.getMaxIntrinsicWidth(double.infinity) ?? 0) + 9 * u + anchoTalon + 2 * borde;
    final ancho = restricciones.hasBoundedWidth ? restricciones.maxWidth : restricciones.constrainWidth(natural);
    final anchoCaja = math.max(0.0, ancho - 2 * borde);
    final altoMinimo = math.max(14 * u, restricciones.minHeight - u - 2 * borde);
    Size medida(RenderBox? hijo, double maximo) =>
        hijo == null ? Size.zero : medir(hijo, BoxConstraints(maxWidth: math.max(0.0, maximo)));

    if (talon == null) {
      final c = medida(cuerpo, anchoCaja - 9 * u);
      final altoCaja = math.max(altoMinimo, c.height + 10 * u);
      return _Disposicion(
        tamano: restricciones.constrain(Size(ancho, altoCaja + u + 2 * borde)),
        cuerpo: Offset(borde + 5 * u, borde + (altoCaja - c.height) / 2),
        talon: null,
        horizontal: true,
        corte: anchoCaja,
      );
    }
    if (anchoTalon <= anchoCaja * 0.45) {
      final c = medida(cuerpo, anchoCaja - anchoTalon - 9 * u);
      final t = medida(talon, anchoTalon - 6 * u);
      final altoCaja = math.max(altoMinimo, math.max(c.height + 10 * u, t.height + 8 * u));
      final corte = anchoCaja - anchoTalon;
      return _Disposicion(
        tamano: restricciones.constrain(Size(ancho, altoCaja + u + 2 * borde)),
        cuerpo: Offset(borde + 5 * u, borde + (altoCaja - c.height) / 2),
        talon: Offset(borde + corte + 3 * u + (anchoTalon - 6 * u - t.width) / 2, borde + (altoCaja - t.height) / 2),
        horizontal: true,
        corte: corte,
      );
    }
    // No cabe al lado: el talón va debajo.
    final c = medida(cuerpo, anchoCaja - 10 * u);
    final t = medida(talon, anchoCaja - 8 * u);
    final corte = c.height + 9 * u;
    final altoCaja = math.max(altoMinimo, corte + t.height + 6 * u);
    return _Disposicion(
      tamano: restricciones.constrain(Size(ancho, altoCaja + u + 2 * borde)),
      cuerpo: Offset(borde + 5 * u, borde + 5 * u),
      talon: Offset(borde + (anchoCaja - t.width) / 2, borde + corte + 3 * u),
      horizontal: false,
      corte: corte,
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _disponer(constraints, ChildLayoutHelper.dryLayoutChild).tamano;

  @override
  void performLayout() {
    final disposicion = _disponer(constraints, ChildLayoutHelper.layoutChild);
    _disposicion = disposicion;
    size = disposicion.tamano;
    final baja = Offset(0, _pulsado ? _u : 0);
    final cuerpo = _cuerpo;
    if (cuerpo != null) (cuerpo.parentData! as BoxParentData).offset = disposicion.cuerpo + baja;
    final talon = _talon;
    final sitioTalon = disposicion.talon;
    if (talon != null && sitioTalon != null) (talon.parentData! as BoxParentData).offset = sitioTalon + baja;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final cuerpo = _cuerpo?.getMinIntrinsicWidth(double.infinity) ?? 0;
    final talon = _talon?.getMinIntrinsicWidth(double.infinity);
    final caja = talon == null ? cuerpo + 9 * _u : math.max(cuerpo + 10 * _u, talon + 8 * _u);
    return caja + 2 * _borde;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final talon = _talon;
    return (_cuerpo?.getMaxIntrinsicWidth(double.infinity) ?? 0) +
        9 * _u +
        (talon == null ? 0 : _anchoTalon(talon)) +
        2 * _borde;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _disponer(BoxConstraints(maxWidth: width), ChildLayoutHelper.dryLayoutChild).tamano.height;

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final cuerpo = _cuerpo;
    if (cuerpo == null) return null;
    final distancia = cuerpo.getDistanceToActualBaseline(baseline);
    return distancia == null ? null : distancia + (cuerpo.parentData! as BoxParentData).offset.dy;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final hijo in children.toList().reversed) {
      final offset = (hijo.parentData! as BoxParentData).offset;
      final tocado = result.addWithPaintOffset(
        offset: offset,
        position: position,
        hitTest: (result, transformado) => hijo.hitTest(result, position: transformado),
      );
      if (tocado) return true;
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final disposicion = _disposicion;
    if (disposicion != null) {
      final canvas = context.canvas
        ..save()
        ..translate(offset.dx, offset.dy);
      _pintarTicket(canvas, disposicion);
      canvas.restore();
    }
    for (final hijo in children) {
      context.paintChild(hijo, offset + (hijo.parentData! as BoxParentData).offset);
    }
  }

  void _pintarTicket(Canvas canvas, _Disposicion disposicion) {
    final u = _u;
    final filo = _filo;
    final bordes = Rect.fromLTWH(0, 0, alPixelFisico(size.width, _dpr), alPixelFisico(size.height, _dpr));
    if (_foco) pintarAnilloFoco(canvas, bordes, u, _esquina + (filo == null ? 0 : 1));
    final silueta = bordes.deflate(_borde);
    final caja = Rect.fromLTWH(silueta.left, silueta.top + (_pulsado ? u : 0), silueta.width, silueta.height - u);
    // Una capa propia: las muescas se borran (se ve el fondo a través).
    canvas.saveLayer(bordes.inflate(u), Paint());
    if (filo != null) pintarFilo(canvas, bordes, u, _esquina, filo);
    pintarCajaPixel(
      canvas,
      caja,
      u,
      EstiloCajaPixel(
        relleno: _colorPapel,
        contorno: _tinta,
        sombra: _pulsado ? null : ColoresUiPixel.noche,
        esquina: _esquina,
      ),
    );
    if (_talon != null) {
      if (disposicion.horizontal) {
        _pintarTalonALaDerecha(canvas, caja, caja.left + disposicion.corte);
      } else {
        _pintarTalonDebajo(canvas, caja, caja.top + disposicion.corte);
      }
    }
    canvas.restore();
  }

  void _pintarTalonALaDerecha(Canvas canvas, Rect caja, double corte) {
    final u = _u;
    if (corte <= caja.left + 4 * u || caja.height < 2 * (_muesca.length + 1) * u) return;
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(corte + u, caja.top, caja.right, caja.bottom), doAntiAlias: false);
    pintarForma(canvas, caja.deflate(u), u, perfilInterior(perfilEsquina(_esquina)), pincelPixel(_colorTalon));
    canvas.restore();
    final puntos = pincelPixel(_tinta);
    final hasta = caja.bottom - (_muesca.length + 2) * u;
    for (var y = caja.top + (_muesca.length + 2) * u; y + u <= hasta; y += 2 * u) {
      canvas.drawRect(Rect.fromLTWH(corte, y, u, u), puntos);
    }
    if (!_pulsado) {
      // La sombra dura también lleva la muesca de abajo.
      _morder(
        canvas,
        (dx, k) => Rect.fromLTWH(corte + dx * u, caja.bottom + u - (k + 1) * u, u, u),
        conContorno: false,
      );
    }
    _morder(canvas, (dx, k) => Rect.fromLTWH(corte + dx * u, caja.top + k * u, u, u), conContorno: true);
    _morder(canvas, (dx, k) => Rect.fromLTWH(corte + dx * u, caja.bottom - (k + 1) * u, u, u), conContorno: true);
  }

  void _pintarTalonDebajo(Canvas canvas, Rect caja, double corte) {
    final u = _u;
    if (corte + 4 * u >= caja.bottom || caja.width < 2 * (_muesca.length + 1) * u) return;
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(caja.left, corte + u, caja.right, caja.bottom), doAntiAlias: false);
    pintarForma(canvas, caja.deflate(u), u, perfilInterior(perfilEsquina(_esquina)), pincelPixel(_colorTalon));
    canvas.restore();
    final puntos = pincelPixel(_tinta);
    final hasta = caja.right - (_muesca.length + 2) * u;
    for (var x = caja.left + (_muesca.length + 2) * u; x + u <= hasta; x += 2 * u) {
      canvas.drawRect(Rect.fromLTWH(x, corte, u, u), puntos);
    }
    _morder(canvas, (dx, k) => Rect.fromLTWH(caja.left + k * u, corte + dx * u, u, u), conContorno: true);
    _morder(canvas, (dx, k) => Rect.fromLTWH(caja.right - (k + 1) * u, corte + dx * u, u, u), conContorno: true);
  }

  /// Borra una muesca. [celda] da el rectángulo de la celda a `dx` celdas de la perforación, a lo largo del borde, y
  /// `k` celdas hacia dentro del ticket (con `k = -1`, la de fuera: el filo). Con [conContorno], la rodea de contorno
  /// (las celdas que tocan la muesca por un lado); sobre un fondo oscuro, del color del filo, que se abre para
  /// seguirla.
  void _morder(Canvas canvas, Rect Function(int dx, int k) celda, {required bool conContorno}) {
    bool dentro(int dx, int k) => k >= 0 && k < _muesca.length && dx.abs() <= _muesca[k];
    final borrar = Paint()
      ..blendMode = BlendMode.clear
      ..isAntiAlias = false;
    final filo = _filo;
    for (var k = filo == null ? 0 : -1; k < _muesca.length; k++) {
      final m = _muesca[math.max(0, k)];
      for (var dx = -m; dx <= m; dx++) {
        canvas.drawRect(celda(dx, k), borrar);
      }
    }
    if (!conContorno) return;
    final contorno = pincelPixel(filo ?? _tinta);
    final maximo = _muesca.first + 1;
    for (var k = 0; k <= _muesca.length; k++) {
      for (var dx = -maximo; dx <= maximo; dx++) {
        if (dentro(dx, k)) continue;
        if (dentro(dx - 1, k) || dentro(dx + 1, k) || dentro(dx, k - 1) || dentro(dx, k + 1)) {
          canvas.drawRect(celda(dx, k), contorno);
        }
      }
    }
  }
}
