import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../tema.dart';
import 'paleta_iconos.dart';
import 'pieza.dart';
import 'tu_icono.dart';

/// Aparición «pegatina que se pega»: de pequeña y girada a su sitio, con un pequeño rebote.
const _duracionAparicion = Duration(milliseconds: 460);

/// Rebote al tocar.
const _duracionToque = Duration(milliseconds: 420);

/// Icono propio de TuTurno ([TuIcono]), pintado en código: nítido a cualquier tamaño y con los colores del tema.
///
/// - [EstiloIcono.color] (por defecto): azul y amarillo con contorno azul noche y sombra de papel. Con [pegatina],
///   además, un borde blanco: úsalo sobre fondos de color (azul, amarillo, fotos).
/// - [EstiloIcono.mono]: un solo color ([color], o el del `IconTheme`), como un `Icon`: para botones y barras.
///
/// Como `Icon`, toma el tamaño del `IconTheme` si no se indica [size] (24 por defecto). Se lee con
/// [TuIcono.etiqueta] (o [semanticLabel]); si va junto a un texto que ya lo dice, pasa [decorativo].
///
/// Con [animado], aparece como una pegatina que se pega y rebota al tocarlo (sin quitarle el toque a su botón).
/// Respeta la opción de reducir animaciones.
class IconoTuTurno extends StatefulWidget {
  const IconoTuTurno(
    this.icono, {
    super.key,
    this.size,
    this.estilo = EstiloIcono.color,
    this.pegatina = false,
    this.sombra = true,
    this.color,
    this.semanticLabel,
    this.decorativo = false,
    this.animado = false,
  });

  final TuIcono icono;
  final double? size;
  final EstiloIcono estilo;
  final bool pegatina;

  /// Sombra de papel bajo el icono (solo en [EstiloIcono.color]).
  final bool sombra;

  /// Color en [EstiloIcono.mono].
  final Color? color;
  final String? semanticLabel;
  final bool decorativo;
  final bool animado;

  @override
  State<IconoTuTurno> createState() => _IconoTuTurnoState();
}

class _IconoTuTurnoState extends State<IconoTuTurno> with TickerProviderStateMixin {
  late final AnimationController _aparicion = AnimationController(vsync: this, value: 1);
  late final AnimationController _toque = AnimationController(vsync: this, duration: _duracionToque, value: 1);
  bool _aparecio = false;

  bool get _hayMovimiento => duracion(context, _duracionAparicion) != Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_aparecio) return;
    _aparecio = true;
    if (widget.animado && _hayMovimiento) {
      _aparicion
        ..duration = _duracionAparicion
        ..forward(from: 0);
    }
  }

  void _alTocar(PointerDownEvent _) {
    if (widget.animado && _hayMovimiento) _toque.forward(from: 0);
  }

  @override
  void dispose() {
    _aparicion.dispose();
    _toque.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final temaIconos = IconTheme.of(context);
    final lado = widget.size ?? temaIconos.size ?? 24;
    Widget dibujo = CustomPaint(
      size: Size.square(lado),
      isComplex: true,
      painter: PintorIcono(
        piezas: widget.icono.piezas,
        paleta: PaletaIconos.de(context),
        estilo: widget.estilo,
        pegatina: widget.pegatina,
        sombra: widget.sombra,
        colorMono: widget.color ?? temaIconos.color ?? Theme.of(context).colorScheme.onSurface,
      ),
    );
    if (widget.animado) {
      dibujo = Listener(
        onPointerDown: _alTocar,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_aparicion, _toque]),
            builder: (context, hijo) => _transformar(hijo!),
            child: dibujo,
          ),
        ),
      );
    }
    if (widget.decorativo) return ExcludeSemantics(child: dibujo);
    return Semantics(
      label: widget.semanticLabel ?? widget.icono.etiqueta,
      image: true,
      child: ExcludeSemantics(child: dibujo),
    );
  }

  Widget _transformar(Widget hijo) {
    final aparicion = _aparicion.value;
    final toque = _toque.value;
    if (aparicion >= 1 && toque >= 1) return hijo;
    // Aparición: de 0,4 a 1 con rebote y de -14° a 0°.
    final pop = Curves.easeOutBack.transform(aparicion);
    var escala = 0.4 + 0.6 * pop;
    var giro = (1 - Curves.easeOutCubic.transform(aparicion)) * -14;
    // Toque: se aplasta, rebota y se balancea, cada vez menos.
    if (toque < 1) {
      final aplastado = toque < 0.3 ? math.sin(math.pi * toque / 0.3) : 0.0;
      final rebote = toque < 0.3 ? 0.0 : math.sin(math.pi * (toque - 0.3) / 0.7);
      escala *= 1 - 0.16 * aplastado + 0.08 * rebote;
      giro += 9 * math.sin(toque * 3 * math.pi) * (1 - toque);
    }
    final opacidad = (aparicion * 3).clamp(0.0, 1.0);
    final girado = Transform.rotate(
      angle: giro * math.pi / 180,
      child: Transform.scale(scale: escala, child: hijo),
    );
    return opacidad < 1 ? Opacity(opacity: opacidad, child: girado) : girado;
  }
}
