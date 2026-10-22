import 'package:flutter/widgets.dart';

import '../../tema.dart' show duracion;
import 'encaje_pixel.dart';
import 'imagenes_pixel.dart';
import 'reloj_pixel.dart';
import 'sprite.dart';

/// Un sprite a la mayor escala entera que cabe en su sitio, nítido (sin suavizado) y con su animación en reposo si la
/// tiene. Con «reducir animaciones» (`duracion()` del tema) o [animar] a false se queda quieto en su pose de descanso.
///
/// Ocupa [ancho] × [alto] (si solo se da uno, el otro sale de la proporción del sprite) o, sin ninguno, lo que le
/// obligue el padre; si el padre le deja elegir, [escalaLibre] puntos por píxel del sprite. Dentro de ese sitio, el
/// dibujo se coloca según [alineacion] con un número entero de píxeles físicos por píxel del sprite.
class SpritePixel extends StatefulWidget {
  const SpritePixel({
    super.key,
    required this.sprite,
    this.ancho,
    this.alto,
    this.animar = true,
    this.espejo = false,
    this.alineacion = Alignment.center,
    this.etiqueta,
    this.desfaseMs = 0,
  });

  final Sprite sprite;
  final double? ancho;
  final double? alto;

  /// Con false, la animación en reposo no se mueve.
  final bool animar;

  /// Dado la vuelta de izquierda a derecha (un personaje que mira al otro lado).
  final bool espejo;

  final Alignment alineacion;

  /// Lo que dicen los lectores de pantalla. Sin etiqueta, el sprite es decorativo y no se anuncia.
  final String? etiqueta;

  /// Adelanta la animación estos milisegundos (para que dos sprites iguales no parpadeen a la vez).
  final int desfaseMs;

  /// Puntos lógicos por píxel del sprite cuando nada fija el tamaño.
  static const escalaLibre = 4.0;

  @override
  State<SpritePixel> createState() => _SpritePixelState();
}

class _SpritePixelState extends State<SpritePixel> {
  RelojPixel? _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = _nuevoReloj();
  }

  RelojPixel? _nuevoReloj() {
    final animacion = widget.sprite.animacion;
    if (animacion == null || !animacion.seMueve) return null;
    return RelojPixel([animacion], desfasesMs: [widget.desfaseMs]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ponerEnMarcha();
  }

  @override
  void didUpdateWidget(SpritePixel antiguo) {
    super.didUpdateWidget(antiguo);
    if (antiguo.sprite.animacion != widget.sprite.animacion || antiguo.desfaseMs != widget.desfaseMs) {
      _reloj?.dispose();
      _reloj = _nuevoReloj();
    }
    _ponerEnMarcha();
  }

  void _ponerEnMarcha() {
    final reloj = _reloj;
    if (reloj == null) return;
    if (!widget.animar || duracion(context, const Duration(seconds: 1)) == Duration.zero) {
      reloj.reposo();
    } else if (TickerMode.valuesOf(context).enabled) {
      reloj.arrancar();
    } else {
      reloj.parar();
    }
  }

  @override
  void dispose() {
    _reloj?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sprite = widget.sprite;
    final proporcion = sprite.ancho / sprite.alto;
    final ancho =
        widget.ancho ?? (widget.alto == null ? sprite.ancho * SpritePixel.escalaLibre : widget.alto! * proporcion);
    final alto = widget.alto ?? ancho / proporcion;
    final dibujo = CustomPaint(
      size: Size(ancho, alto),
      painter: _PintorSprite(
        sprite: sprite,
        reloj: _reloj,
        dpr: MediaQuery.maybeDevicePixelRatioOf(context) ?? View.of(context).devicePixelRatio,
        espejo: widget.espejo,
        alineacion: widget.alineacion,
      ),
    );
    final etiqueta = widget.etiqueta;
    return etiqueta == null ? dibujo : Semantics(image: true, label: etiqueta, child: dibujo);
  }
}

class _PintorSprite extends CustomPainter {
  _PintorSprite({
    required this.sprite,
    required this.reloj,
    required this.dpr,
    required this.espejo,
    required this.alineacion,
  }) : super(repaint: reloj);

  final Sprite sprite;
  final RelojPixel? reloj;
  final double dpr;
  final bool espejo;
  final Alignment alineacion;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final animacion = sprite.animacion;
    // Sitio para el balanceo: el dibujo sube y baja sin salirse de la caja.
    final arriba = -(animacion?.dyMinimo ?? 0);
    final abajo = animacion?.dyMaximo ?? 0;
    final encaje = EncajePixel(
      caja: size,
      arte: Size(sprite.ancho.toDouble(), (sprite.alto + arriba + abajo).toDouble()),
      dpr: dpr,
      alineacion: alineacion,
    );
    final reloj = this.reloj;
    final fotograma = reloj?.fotograma(0) ?? animacion?.descanso?.fotograma ?? 0;
    final dy = reloj?.dy(0) ?? animacion?.descanso?.dy ?? 0;
    ImagenesPixel.pintar(
      canvas,
      ImagenesPixel.de(sprite, fotograma),
      encaje.rectDe(0, arriba + dy, sprite.ancho, sprite.alto),
      espejo: espejo,
    );
  }

  @override
  bool shouldRepaint(_PintorSprite antiguo) =>
      antiguo.sprite != sprite ||
      antiguo.reloj != reloj ||
      antiguo.dpr != dpr ||
      antiguo.espejo != espejo ||
      antiguo.alineacion != alineacion;
}
