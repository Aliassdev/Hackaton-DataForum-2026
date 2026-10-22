import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../tema.dart' show duracion;
import 'encaje_pixel.dart';
import 'imagenes_pixel.dart';
import 'paleta_pixel.dart';
import 'reloj_pixel.dart';
import 'sprite.dart';

/// Un sprite colocado en una [EscenaPixel]: un personaje o una pieza del decorado (un banco delante de alguien, por
/// ejemplo).
@immutable
class ElementoEscena {
  const ElementoEscena({
    required this.sprite,
    required this.x,
    required this.y,
    this.id,
    this.etiqueta,
    this.espejo = false,
    this.resaltado = false,
  });

  final Sprite sprite;

  /// Dónde va el ancla del sprite (por defecto, sus pies), en píxeles del fondo.
  final int x;
  final int y;

  /// Si tiene id, se puede tocar: [EscenaPixel.alPulsar] recibe este id.
  final String? id;

  /// Lo que dicen los lectores de pantalla del personaje que se puede tocar («La jueza. Toca para hablar con ella»).
  /// Si falta, se usa el [id].
  final String? etiqueta;

  /// Dado la vuelta de izquierda a derecha.
  final bool espejo;

  /// Con un halo amarillo alrededor de la silueta, para señalar a quién tocar.
  final bool resaltado;

  /// Dónde queda el sprite, en píxeles del fondo.
  Rect get rectPixel {
    final ancla = sprite.ancla;
    final izquierda = espejo ? x - (sprite.ancho - ancla.x) : x - ancla.x;
    return Rect.fromLTWH(
      izquierda.toDouble(),
      (y - ancla.y).toDouble(),
      sprite.ancho.toDouble(),
      sprite.alto.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ElementoEscena &&
      identical(other.sprite, sprite) &&
      other.x == x &&
      other.y == y &&
      other.id == id &&
      other.etiqueta == etiqueta &&
      other.espejo == espejo &&
      other.resaltado == resaltado;

  @override
  int get hashCode => Object.hash(sprite, x, y, id, etiqueta, espejo, resaltado);
}

/// Una escena de pixel art: un [fondo] (de unos 160 × 96 píxeles) con [elementos] encima, colocados en píxeles del
/// fondo y pintados en orden (el último queda delante). Todo se escala junto, como una sola imagen nítida: la mayor
/// escala entera de píxeles físicos que cabe, centrada, con el sitio que sobra del color [colorMarco] (el papel).
///
/// Los elementos con [ElementoEscena.id] se pueden tocar si hay [alPulsar]: cada uno tiene una zona de toque del
/// tamaño de su sprite (como mínimo [zonaMinima] × [zonaMinima]) y un nodo de Semantics de botón con su etiqueta. Las
/// animaciones en reposo de los sprites se mueven solas, desfasadas, y se quedan quietas con «reducir animaciones».
///
/// En una columna (sin límite de alto), la escena ocupa todo el ancho y el alto justo para su escala.
class EscenaPixel extends StatefulWidget {
  const EscenaPixel({
    super.key,
    required this.fondo,
    this.elementos = const [],
    this.alPulsar,
    this.descripcion,
    this.colorMarco,
    this.animar = true,
  });

  final Sprite fondo;
  final List<ElementoEscena> elementos;

  /// Se llama con el id del elemento que se toca.
  final ValueChanged<String>? alPulsar;

  /// Lo que dicen los lectores de pantalla de la escena entera («La sala de espera del juzgado»).
  final String? descripcion;

  /// Color de los márgenes alrededor de la escena. Por defecto, [PaletaPixel.papel].
  final Color? colorMarco;

  /// Con false, nada se mueve.
  final bool animar;

  /// Lado mínimo, en puntos, de la zona de toque de un personaje: lo de cualquier botón de la app.
  static const zonaMinima = 48.0;

  /// Puntos lógicos por píxel del fondo cuando el padre no pone ningún límite.
  static const escalaLibre = 4.0;

  @override
  State<EscenaPixel> createState() => _EscenaPixelState();
}

class _EscenaPixelState extends State<EscenaPixel> {
  RelojPixel? _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = _nuevoReloj();
  }

  List<AnimacionPixel?> _animaciones(EscenaPixel escena) => [
    escena.fondo.animacion,
    for (final elemento in escena.elementos) elemento.sprite.animacion,
  ];

  RelojPixel? _nuevoReloj() {
    final animaciones = _animaciones(widget);
    if (!animaciones.any((animacion) => animacion != null && animacion.seMueve)) return null;
    // Cada personaje va a su ritmo: si todos parpadearan a la vez parecerían muñecos.
    return RelojPixel(animaciones, desfasesMs: [for (var i = 0; i < animaciones.length; i++) i * 1370]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ponerEnMarcha();
  }

  @override
  void didUpdateWidget(EscenaPixel antiguo) {
    super.didUpdateWidget(antiguo);
    // Cambiar quién está resaltado o dónde está no reinicia las animaciones; cambiar los sprites, sí.
    if (!listEquals(_animaciones(antiguo), _animaciones(widget))) {
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

  /// El tamaño de la escena: todo el sitio del padre o, en una dirección sin límite, lo justo para la escala entera.
  Size _caja(BoxConstraints limites, double dpr) {
    final arte = widget.fondo.tamano;
    double fisicos(double disponible, double lado) => math.max(1, (disponible * dpr / lado + 1e-6).floorToDouble());
    final Size caja;
    if (limites.hasBoundedWidth && limites.hasBoundedHeight) {
      caja = limites.biggest;
    } else if (limites.hasBoundedWidth) {
      caja = Size(limites.maxWidth, arte.height * fisicos(limites.maxWidth, arte.width) / dpr);
    } else if (limites.hasBoundedHeight) {
      caja = Size(arte.width * fisicos(limites.maxHeight, arte.height) / dpr, limites.maxHeight);
    } else {
      caja = arte * EscenaPixel.escalaLibre;
    }
    return limites.constrain(caja);
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? View.of(context).devicePixelRatio;
    final alPulsar = widget.alPulsar;
    final escena = LayoutBuilder(
      builder: (context, limites) {
        final caja = _caja(limites, dpr);
        final encaje = EncajePixel(caja: caja, arte: widget.fondo.tamano, dpr: dpr);
        return SizedBox.fromSize(
          size: caja,
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _PintorEscena(
                      fondo: widget.fondo,
                      elementos: widget.elementos,
                      encaje: encaje,
                      colorMarco: widget.colorMarco ?? PaletaPixel.papel.color,
                      reloj: _reloj,
                    ),
                  ),
                ),
              ),
              if (alPulsar != null)
                for (final elemento in widget.elementos)
                  if (elemento.id case final id?)
                    Positioned.fromRect(
                      rect: _zonaDeToque(encaje, elemento),
                      child: Semantics(
                        container: true,
                        button: true,
                        label: elemento.etiqueta ?? id,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => alPulsar(id),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
    final descripcion = widget.descripcion;
    return descripcion == null ? escena : Semantics(container: true, image: true, label: descripcion, child: escena);
  }

  /// La zona de toque de [elemento]: su sprite en la pantalla, agrandada hasta [EscenaPixel.zonaMinima] si es pequeña.
  Rect _zonaDeToque(EncajePixel encaje, ElementoEscena elemento) {
    final pixel = elemento.rectPixel;
    final rect = encaje.rectDe(pixel.left, pixel.top, pixel.width, pixel.height);
    return Rect.fromCenter(
      center: rect.center,
      width: math.max(rect.width, EscenaPixel.zonaMinima),
      height: math.max(rect.height, EscenaPixel.zonaMinima),
    );
  }
}

class _PintorEscena extends CustomPainter {
  _PintorEscena({
    required this.fondo,
    required this.elementos,
    required this.encaje,
    required this.colorMarco,
    required this.reloj,
  }) : super(repaint: reloj);

  final Sprite fondo;
  final List<ElementoEscena> elementos;
  final EncajePixel encaje;
  final Color colorMarco;
  final RelojPixel? reloj;

  int _fotograma(int i, Sprite sprite) => reloj?.fotograma(i) ?? sprite.animacion?.descanso?.fotograma ?? 0;
  int _dy(int i, Sprite sprite) => reloj?.dy(i) ?? sprite.animacion?.descanso?.dy ?? 0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = colorMarco);
    canvas
      ..save()
      ..clipRect(encaje.rect);
    ImagenesPixel.pintar(
      canvas,
      ImagenesPixel.de(fondo, _fotograma(0, fondo)),
      encaje.rectDe(0, _dy(0, fondo), fondo.ancho, fondo.alto),
    );
    for (var i = 0; i < elementos.length; i++) {
      final elemento = elementos[i];
      final sprite = elemento.sprite;
      final fotograma = _fotograma(i + 1, sprite);
      final pixel = elemento.rectPixel.translate(0, _dy(i + 1, sprite).toDouble());
      if (elemento.resaltado) {
        const m = ImagenesPixel.margenHalo;
        ImagenesPixel.pintar(
          canvas,
          ImagenesPixel.halo(sprite, fotograma),
          encaje.rectDe(pixel.left - m, pixel.top - m, pixel.width + 2 * m, pixel.height + 2 * m),
          espejo: elemento.espejo,
        );
      }
      ImagenesPixel.pintar(
        canvas,
        ImagenesPixel.de(sprite, fotograma),
        encaje.rectDe(pixel.left, pixel.top, pixel.width, pixel.height),
        espejo: elemento.espejo,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorEscena antiguo) =>
      antiguo.fondo != fondo ||
      !listEquals(antiguo.elementos, elementos) ||
      antiguo.encaje != encaje ||
      antiguo.colorMarco != colorMarco ||
      antiguo.reloj != reloj;
}
