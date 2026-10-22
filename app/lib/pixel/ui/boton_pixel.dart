import 'dart:async';

import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';

import '../../widgets/movimiento/hapticos.dart';
import 'estilo_pixel.dart';
import 'pintura_pixel.dart';
import 'pulsacion_pixel.dart';

/// Para qué es un [BotonPixel].
enum VarianteBotonPixel {
  /// La acción principal: amarillo con tinta azul noche.
  primario,

  /// Acciones secundarias: papel con tinta azul noche.
  secundario,

  /// Salir del caso, borrar…: teja con texto blanco (la paleta no tiene rojo: el rojo es solo de Ayuda).
  peligro,
}

/// Colores de un [BotonPixel] según su variante y si está activo.
@immutable
class ColoresBotonPixel {
  const ColoresBotonPixel({
    required this.relleno,
    required this.encima,
    required this.brillo,
    required this.luz,
    required this.sombraInterior,
    required this.tinta,
    this.contorno = ColoresUiPixel.noche,
    this.sombra = ColoresUiPixel.noche,
  });

  factory ColoresBotonPixel.de(VarianteBotonPixel variante, {bool activo = true}) {
    if (!activo) return desactivado;
    return switch (variante) {
      VarianteBotonPixel.primario => primario,
      VarianteBotonPixel.secundario => secundario,
      VarianteBotonPixel.peligro => peligro,
    };
  }

  final Color relleno;

  /// Relleno con el ratón encima.
  final Color encima;

  /// Filo de una unidad por dentro del contorno con el ratón encima: se nota en las tres variantes.
  final Color brillo;
  final Color luz;
  final Color sombraInterior;
  final Color tinta;
  final Color contorno;
  final Color? sombra;

  static const primario = ColoresBotonPixel(
    relleno: ColoresUiPixel.amarillo,
    encima: ColoresUiPixel.amarilloLuz,
    brillo: ColoresUiPixel.blanco,
    luz: ColoresUiPixel.amarilloLuz,
    sombraInterior: ColoresUiPixel.ocre,
    tinta: ColoresUiPixel.noche,
  );

  static const secundario = ColoresBotonPixel(
    relleno: ColoresUiPixel.papel,
    encima: ColoresUiPixel.blanco,
    brillo: ColoresUiPixel.amarillo,
    luz: ColoresUiPixel.blanco,
    sombraInterior: ColoresUiPixel.crema,
    tinta: ColoresUiPixel.noche,
  );

  static const peligro = ColoresBotonPixel(
    relleno: ColoresUiPixel.teja,
    encima: ColoresUiPixel.teja,
    brillo: ColoresUiPixel.coral,
    luz: ColoresUiPixel.coral,
    sombraInterior: ColoresUiPixel.negro,
    tinta: ColoresUiPixel.blanco,
  );

  static const desactivado = ColoresBotonPixel(
    relleno: ColoresUiPixel.grisClaro,
    encima: ColoresUiPixel.grisClaro,
    brillo: ColoresUiPixel.grisClaro,
    luz: ColoresUiPixel.blanco,
    sombraInterior: ColoresUiPixel.gris,
    tinta: ColoresUiPixel.grisOscuro,
    contorno: ColoresUiPixel.gris,
    sombra: null,
  );

  EstiloCajaPixel estilo({bool encima = false}) => EstiloCajaPixel(
    relleno: encima ? this.encima : relleno,
    contorno: contorno,
    anillo: encima ? brillo : null,
    luz: luz,
    sombraInterior: sombraInterior,
    sombra: sombra,
    esquina: 2,
  );
}

/// Botón pixel: caja escalonada con luz arriba, sombra abajo y una sombra dura que lo separa del fondo. Al pulsarlo
/// baja una unidad pixel (hasta su sombra) y vibra un poco; se ve abajo al menos 120 ms, aunque el toque sea rápido
/// o vaya dentro de una lista con scroll. Con el ratón encima, se enciende un filo por dentro.
///
/// Mide al menos 48 × 48, se puede usar con teclado (Intro o Espacio, con anillo de foco) y lo anuncia el lector de
/// pantalla como botón. Con [onPressed] null queda desactivado (gris y sin sombra).
///
/// Lleva [etiqueta], [icono] o los dos; si solo lleva icono, [semantica] dice qué hace. [iconoFinal] va detrás del
/// texto (la flecha de «Siguiente caso»).
class BotonPixel extends StatefulWidget {
  const BotonPixel({
    super.key,
    this.etiqueta,
    required this.onPressed,
    this.variante = VarianteBotonPixel.primario,
    this.icono,
    this.iconoFinal,
    this.semantica,
    this.expandido = false,
    this.focusNode,
    this.autofocus = false,
  }) : assert(etiqueta != null || (icono != null && semantica != null), 'Un botón sin texto necesita semantica.');

  final String? etiqueta;
  final VoidCallback? onPressed;
  final VarianteBotonPixel variante;

  /// Normalmente un `IconoPixel`; toma el color de la tinta del botón.
  final Widget? icono;

  /// Un icono detrás del texto (solo con [etiqueta]), como el de [icono].
  final Widget? iconoFinal;

  /// Lo que lee el lector de pantalla. Por defecto, [etiqueta].
  final String? semantica;

  /// Ocupa todo el ancho disponible.
  final bool expandido;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<BotonPixel> createState() => _BotonPixelState();
}

class _BotonPixelState extends State<BotonPixel> {
  late final _pulsacion = PulsacionPixel(() {
    if (mounted) setState(() {});
  });
  bool _encima = false;

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

  /// Con el teclado no hay dedo que levantar: el botón baja un momento y vuelve.
  void _activarConTeclado() {
    if (!_activo) return;
    _pulsacion.pulsarYSoltar();
    _activar();
  }

  @override
  void didUpdateWidget(BotonPixel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_activo) {
      _pulsacion.reiniciar();
      _encima = false;
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
    final colores = ColoresBotonPixel.de(widget.variante, activo: _activo);
    final etiqueta = widget.etiqueta;
    final icono = widget.icono;
    final iconoFinal = etiqueta == null ? null : widget.iconoFinal;
    final soloIcono = etiqueta == null;
    final estilo = estiloTextoPixel(context, TipoTextoPixel.boton, color: colores.tinta);
    final contenido = IconTheme(
      data: IconThemeData(color: colores.tinta),
      child: DefaultTextStyle.merge(
        style: estilo,
        textAlign: TextAlign.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null)
              soloIcono
                  ? icono
                  // Con texto, el alto lo pone el texto: el icono va centrado en la fila y, si es más alto (la carta
                  // mide 11 unidades), sobresale por el margen en vez de hacer el botón más alto que los de al lado.
                  : SizedBox(
                      height: 0,
                      child: OverflowBox(
                        fit: OverflowBoxFit.deferToChild,
                        minHeight: 0,
                        maxHeight: double.infinity,
                        child: icono,
                      ),
                    ),
            if (icono != null && etiqueta != null) SizedBox(width: 2 * u),
            if (etiqueta != null) Flexible(child: Text.rich(textoConCifras(etiqueta, estilo))),
            if (iconoFinal != null) ...[
              SizedBox(width: 2 * u),
              SizedBox(
                height: 0,
                child: OverflowBox(
                  fit: OverflowBoxFit.deferToChild,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: iconoFinal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    final caja = CajaPixel(
      estilo: colores.estilo(encima: _encima && _activo),
      interior: soloIcono ? const EdgeInsets.all(4) : const EdgeInsets.fromLTRB(6, 4, 6, 4),
      pulsada: _pulsacion.pulsada && _activo,
      foco: _foco && _activo,
      child: Center(widthFactor: 1, heightFactor: 1, child: contenido),
    );
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: _activo,
      includeFocusSemantics: false,
      mouseCursor: _activo ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (valor) => setState(() => _foco = valor),
      onFocusChange: (valor) => setState(() => _tieneFoco = valor),
      onShowHoverHighlight: (valor) => setState(() => _encima = valor),
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _activarConTeclado())},
      child: Semantics(
        container: true,
        button: true,
        enabled: _activo,
        focusable: _activo,
        focused: _tieneFoco,
        label: widget.semantica ?? etiqueta,
        onTap: _activo ? _activar : null,
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _activo ? (_) => _pulsacion.bajar() : null,
            onTapUp: _activo ? (_) => _pulsacion.soltar() : null,
            onTapCancel: _activo ? _pulsacion.cancelar : null,
            onTap: _activo ? _activar : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: widget.expandido ? double.infinity : 48,
                minHeight: 48 + u * caja.estilo.profundidad,
              ),
              child: caja,
            ),
          ),
        ),
      ),
    );
  }
}
