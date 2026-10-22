import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'encaje_pixel.dart';
import 'imagenes_pixel.dart';
import 'marcha_pixel.dart';
import 'paleta_pixel.dart';
import 'rejilla_pixel.dart';
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

  /// Con un halo amarillo alrededor de la silueta, para señalar a quién tocar. Si se puede tocar, los lectores de
  /// pantalla lo anuncian como seleccionado.
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
/// escala entera de píxeles físicos que cabe, centrada, con el sitio que sobra del color [colorMarco] (el papel), y
/// con el dibujo en la rejilla de píxeles de la pantalla aunque la caja empiece a medio píxel ([RejillaPixel]).
///
/// Los elementos con [ElementoEscena.id] se pueden tocar si hay [alPulsar]: cada uno tiene una zona de toque del
/// tamaño de su sprite (como mínimo [zonaMinima] × [zonaMinima]) y un nodo de Semantics de botón con su etiqueta. Las
/// animaciones en reposo de los sprites se mueven solas, desfasadas, y se quedan quietas con «reducir animaciones» y
/// mientras la app está en segundo plano.
///
/// En una columna, la escena ocupa todo el ancho y el alto justo para su escala; en un `Center` o en un diálogo, lo
/// justo para su escala ([tamanoPara]). También sabe su tamaño intrínseco, así que se puede poner en un `AlertDialog`
/// o en un `IntrinsicWidth`.
///
/// En el juego, mejor dentro del marco de la pantalla de juego, con el margen del azul noche del marco:
///
/// ```dart
/// MarcoPixel(child: EscenaPixel(fondo: sala, elementos: [...], colorMarco: ColoresUiPixel.noche));
/// ```
///
/// Suelta sobre el papel de la app, lleva un contorno azul noche de un píxel del dibujo ([contorno]): así los fondos
/// claros no se funden con la página.
class EscenaPixel extends StatefulWidget {
  const EscenaPixel({
    super.key,
    required this.fondo,
    this.elementos = const [],
    this.alPulsar,
    this.descripcion,
    this.colorMarco,
    this.contorno,
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

  /// Un contorno azul noche de un píxel del dibujo por dentro del borde de la escena, encima de todo. Null: solo con
  /// los márgenes de papel ([colorMarco] sin dar), que es cuando un fondo claro se fundiría con la página. Dentro de un
  /// marco (`MarcoPixel`, con `colorMarco` azul noche) sobra.
  final bool? contorno;

  /// Con false, nada se mueve.
  final bool animar;

  /// Lado mínimo, en puntos, de la zona de toque de un personaje: lo de cualquier botón de la app.
  static const zonaMinima = 48.0;

  /// Puntos lógicos por píxel del fondo cuando el padre no pone ningún límite.
  static const escalaLibre = 4.0;

  /// El tamaño que ocupa una escena de [arte] píxeles con [limites] a densidad [dpr]. En cada dirección, lo que obligue
  /// el padre si el límite es fijo (un `SizedBox`, un `Expanded`, el ancho de una columna) y, si no, lo justo para la
  /// mayor escala entera de píxeles físicos que cabe en los dos lados con límite (en un `Center`, en un diálogo o en
  /// el alto de una columna). Sin ningún límite, [escalaLibre] puntos por píxel.
  static Size tamanoPara(BoxConstraints limites, Size arte, double dpr) {
    double fisicos(double disponible, double lado) => math.max(1, (disponible * dpr / lado + 1e-6).floorToDouble());
    final enAncho = limites.hasBoundedWidth ? fisicos(limites.maxWidth, arte.width) : null;
    final enAlto = limites.hasBoundedHeight ? fisicos(limites.maxHeight, arte.height) : null;
    final escala = switch ((enAncho, enAlto)) {
      (final double a, final double b) => math.min(a, b) / dpr,
      (final double a, null) || (null, final double a) => a / dpr,
      (null, null) => escalaLibre,
    };
    return limites.constrain(
      Size(
        limites.hasTightWidth ? limites.maxWidth : arte.width * escala,
        limites.hasTightHeight ? limites.maxHeight : arte.height * escala,
      ),
    );
  }

  @override
  State<EscenaPixel> createState() => _EscenaPixelState();
}

class _EscenaPixelState extends State<EscenaPixel> {
  RelojPixel? _reloj;
  late final AppLifecycleListener _ciclo;

  @override
  void initState() {
    super.initState();
    _reloj = _nuevoReloj();
    // En segundo plano no se dibuja nada: que el reloj tampoco despierte a la app en cada fotograma.
    _ciclo = AppLifecycleListener(onStateChange: (_) => _ponerEnMarcha());
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
    if (mounted) ponerEnMarcha(context, _reloj, animar: widget.animar);
  }

  @override
  void dispose() {
    _ciclo.dispose();
    _reloj?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? View.of(context).devicePixelRatio;
    final alPulsar = widget.alPulsar;
    final arte = widget.fondo.tamano;
    // Durante una transición de página la capa de la escena se mueve sin volver a pintarse: repintar con cada paso de
    // la animación de la página deja el dibujo en la rejilla de la pantalla al terminar, aunque nada más se mueva.
    final ruta = ModalRoute.of(context);
    final repintar = Listenable.merge([_reloj, ruta?.animation, ruta?.secondaryAnimation]);
    final escena = _CajaEscena(
      arte: arte,
      dpr: dpr,
      child: LayoutBuilder(
        builder: (context, limites) {
          final caja = limites.biggest;
          final encaje = EncajePixel(caja: caja, arte: arte, dpr: dpr);
          return Stack(
            children: [
              Positioned.fill(
                child: RejillaPixel(
                  child: RepaintBoundary(
                    child: RejillaPixel(
                      child: CustomPaint(
                        painter: _PintorEscena(
                          fondo: widget.fondo,
                          elementos: widget.elementos,
                          encaje: encaje,
                          colorMarco: widget.colorMarco ?? PaletaPixel.papel.color,
                          contorno: widget.contorno ?? widget.colorMarco == null,
                          reloj: _reloj,
                          repintar: repintar,
                        ),
                      ),
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
                        selected: elemento.resaltado ? true : null,
                        label: elemento.etiqueta ?? id,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => alPulsar(id),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
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

/// El tamaño de la escena ([EscenaPixel.tamanoPara]). Lo contesta él mismo, sin preguntar al `LayoutBuilder` de
/// dentro, también cuando le piden el tamaño intrínseco (un `AlertDialog`, un `IntrinsicWidth`).
class _CajaEscena extends SingleChildRenderObjectWidget {
  const _CajaEscena({required this.arte, required this.dpr, required super.child});

  final Size arte;
  final double dpr;

  @override
  _RenderCajaEscena createRenderObject(BuildContext context) => _RenderCajaEscena(arte, dpr);

  @override
  void updateRenderObject(BuildContext context, _RenderCajaEscena renderObject) {
    renderObject
      ..arte = arte
      ..dpr = dpr;
  }
}

class _RenderCajaEscena extends RenderProxyBox {
  _RenderCajaEscena(this._arte, this._dpr);

  Size _arte;
  set arte(Size valor) {
    if (valor == _arte) return;
    _arte = valor;
    markNeedsLayout();
  }

  double _dpr;
  set dpr(double valor) {
    if (valor == _dpr) return;
    _dpr = valor;
    markNeedsLayout();
  }

  /// Píxeles físicos enteros por píxel del dibujo que caben en [disponible] puntos de [lado] píxeles del dibujo.
  double _fisicos(double disponible, double lado) => math.max(1, (disponible * _dpr / lado + 1e-6).floorToDouble());

  @override
  double computeMinIntrinsicWidth(double height) => _arte.width / _dpr;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      height.isFinite ? _arte.width * _fisicos(height, _arte.height) / _dpr : _arte.width * EscenaPixel.escalaLibre;

  @override
  double computeMinIntrinsicHeight(double width) => _arte.height / _dpr;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      width.isFinite ? _arte.height * _fisicos(width, _arte.width) / _dpr : _arte.height * EscenaPixel.escalaLibre;

  @override
  Size computeDryLayout(BoxConstraints constraints) => EscenaPixel.tamanoPara(constraints, _arte, _dpr);

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) => null;

  @override
  void performLayout() {
    size = EscenaPixel.tamanoPara(constraints, _arte, _dpr);
    child?.layout(BoxConstraints.tight(size));
  }
}

class _PintorEscena extends CustomPainter {
  _PintorEscena({
    required this.fondo,
    required this.elementos,
    required this.encaje,
    required this.colorMarco,
    required this.contorno,
    required this.reloj,
    required Listenable repintar,
  }) : super(repaint: repintar);

  final Sprite fondo;
  final List<ElementoEscena> elementos;
  final EncajePixel encaje;
  final Color colorMarco;
  final bool contorno;
  final RelojPixel? reloj;

  int _fotograma(int i, Sprite sprite) => reloj?.fotograma(i) ?? sprite.animacion?.descanso?.fotograma ?? 0;
  int _dy(int i, Sprite sprite) => reloj?.dy(i) ?? sprite.animacion?.descanso?.dy ?? 0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = colorMarco
        ..isAntiAlias = false,
    );
    canvas
      ..save()
      ..clipRect(encaje.rect, doAntiAlias: false);
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
    if (contorno) _pintarContorno(canvas);
    canvas.restore();
  }

  /// Un píxel del dibujo de azul noche por dentro de cada borde, encima de todo.
  void _pintarContorno(Canvas canvas) {
    final tinta = Paint()
      ..color = PaletaPixel.noche.color
      ..isAntiAlias = false;
    final ancho = fondo.ancho, alto = fondo.alto;
    canvas
      ..drawRect(encaje.rectDe(0, 0, ancho, 1), tinta)
      ..drawRect(encaje.rectDe(0, alto - 1, ancho, 1), tinta)
      ..drawRect(encaje.rectDe(0, 1, 1, alto - 2), tinta)
      ..drawRect(encaje.rectDe(ancho - 1, 1, 1, alto - 2), tinta);
  }

  @override
  bool shouldRepaint(_PintorEscena antiguo) =>
      antiguo.fondo != fondo ||
      !listEquals(antiguo.elementos, elementos) ||
      antiguo.encaje != encaje ||
      antiguo.colorMarco != colorMarco ||
      antiguo.contorno != contorno ||
      antiguo.reloj != reloj;
}
