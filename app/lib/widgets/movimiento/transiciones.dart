import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';

import 'paleta.dart';

/// Transiciones de página de TuTurno.
///
/// Cada página dice también qué le pasa a la de debajo (`delegatedTransition` de Flutter): así, al abrir Ayuda encima
/// de un módulo, el módulo no se rasga.
enum TransicionTuTurno {
  /// La firma de la app, para entrar en los módulos: la pantalla de antes se rasga por una línea de puntos, como un
  /// ticket de turno, y sus dos mitades se van; por la rotura aparece el módulo. Al volver, el módulo cae hacia abajo
  /// y la pantalla de antes ya está entera.
  rasgar(entrada: Duration(milliseconds: 680), salida: Duration(milliseconds: 340)),

  /// El ticket sale del dispensador: la pantalla nueva sube con el borde troquelado y se endereza, y la de antes se
  /// aleja un poco. Para lecciones, Pregunta y Mi situación.
  deslizar(entrada: Duration(milliseconds: 460), salida: Duration(milliseconds: 300)),

  /// Rápida y tranquila (fundido y un pequeño desplazamiento), sin juegos. Para Ayuda, Glosario y Ajustes.
  suave(entrada: Duration(milliseconds: 220), salida: Duration(milliseconds: 160));

  const TransicionTuTurno({required this.entrada, required this.salida});

  final Duration entrada;
  final Duration salida;

  RouteTransitionsBuilder get _constructor => switch (this) {
    TransicionTuTurno.rasgar => _transicionRasgar,
    TransicionTuTurno.deslizar => _transicionDeslizar,
    TransicionTuTurno.suave => _transicionSuave,
  };

  DelegatedTransitionBuilder get _anterior => switch (this) {
    TransicionTuTurno.rasgar => _anteriorRasgar,
    TransicionTuTurno.deslizar => _anteriorDeslizar,
    TransicionTuTurno.suave => _anteriorSuave,
  };
}

/// Página de go_router con una [TransicionTuTurno]. Con [reducirMovimiento], la transición dura cero.
class PaginaTuTurno<T> extends CustomTransitionPage<T> {
  PaginaTuTurno({
    required super.child,
    this.transicion = TransicionTuTurno.suave,
    bool reducirMovimiento = false,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  }) : super(
         transitionsBuilder: transicion._constructor,
         transitionDuration: reducirMovimiento ? Duration.zero : transicion.entrada,
         reverseTransitionDuration: reducirMovimiento ? Duration.zero : transicion.salida,
       );

  final TransicionTuTurno transicion;

  @override
  Route<T> createRoute(BuildContext context) => _RutaTuTurno<T>(this);
}

/// La página de [state] para un `pageBuilder` de go_router, con [transicion] y respetando «reducir animaciones».
PaginaTuTurno<void> paginaTuTurno(
  BuildContext context,
  GoRouterState state,
  Widget child, {
  TransicionTuTurno transicion = TransicionTuTurno.suave,
}) => PaginaTuTurno<void>(
  key: state.pageKey,
  name: state.name ?? state.path,
  arguments: <String, String>{...state.pathParameters, ...state.uri.queryParameters},
  restorationId: state.pageKey.value,
  transicion: transicion,
  reducirMovimiento: MediaQuery.disableAnimationsOf(context),
  child: child,
);

class _RutaTuTurno<T> extends PageRoute<T> {
  _RutaTuTurno(PaginaTuTurno<T> pagina) : super(settings: pagina);

  PaginaTuTurno<T> get _pagina => settings as PaginaTuTurno<T>;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => _pagina.maintainState;

  @override
  bool get fullscreenDialog => _pagina.fullscreenDialog;

  @override
  bool get opaque => _pagina.opaque;

  @override
  Duration get transitionDuration => _pagina.transitionDuration;

  @override
  Duration get reverseTransitionDuration => _pagina.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => _pagina.transicion._anterior;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      Semantics(scopesRoute: true, explicitChildNodes: true, child: _pagina.child);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _pagina.transitionsBuilder(context, animation, secondaryAnimation, child);
}

// ---------------------------------------------------------------------------------------------------------------
// Constructores. La propia transición de una página aplica a su secundaria el mismo efecto que delega: es el que se
// ve cuando encima se abre otra página del mismo tipo.

Widget _transicionRasgar(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final reducir = MediaQuery.disableAnimationsOf(context);
  return _Transicion(
    animation: animation,
    efecto: const _EntradaRasgada(),
    reducir: reducir,
    child: _RasgarAnterior(animation: secondaryAnimation, reducir: reducir, permitirCaptura: true, child: child),
  );
}

Widget? _anteriorRasgar(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  bool allowSnapshotting,
  Widget? child,
) => child == null
    ? null
    : _RasgarAnterior(
        animation: secondaryAnimation,
        reducir: MediaQuery.disableAnimationsOf(context),
        permitirCaptura: allowSnapshotting,
        child: child,
      );

Widget _transicionDeslizar(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final reducir = MediaQuery.disableAnimationsOf(context);
  return _Transicion(
    animation: animation,
    efecto: const _EntradaDeslizada(),
    reducir: reducir,
    child: _Transicion(animation: secondaryAnimation, efecto: const _AnteriorAlejada(), reducir: reducir, child: child),
  );
}

Widget? _anteriorDeslizar(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  bool allowSnapshotting,
  Widget? child,
) => child == null
    ? null
    : _Transicion(
        animation: secondaryAnimation,
        efecto: const _AnteriorAlejada(),
        reducir: MediaQuery.disableAnimationsOf(context),
        child: child,
      );

// La página nueva es opaca antes de acabar de subir: así casi no se ven las dos pantallas superpuestas.
final Animatable<double> _opacidadSuave = CurveTween(curve: const Interval(0, 0.6, curve: Curves.easeOut));
final Animatable<Offset> _subidaSuave = Tween<Offset>(
  begin: const Offset(0, 0.025),
  end: Offset.zero,
).chain(CurveTween(curve: Curves.easeOutCubic));

Widget _transicionSuave(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  if (MediaQuery.disableAnimationsOf(context)) return child;
  return FadeTransition(
    opacity: animation.drive(_opacidadSuave),
    child: SlideTransition(position: animation.drive(_subidaSuave), child: child),
  );
}

/// Ayuda y Glosario no mueven la pantalla de debajo.
Widget? _anteriorSuave(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  bool allowSnapshotting,
  Widget? child,
) => child;

// ---------------------------------------------------------------------------------------------------------------
// Motor común: un RenderObject que escucha la animación y solo repinta (no reconstruye la página en cada fotograma).

/// Lo que se pinta en un instante de la transición.
class _Escena {
  const _Escena({this.fondo, this.recorte, this.matriz, this.recorteMovil, this.debajo, this.encima});

  /// Color de fondo de toda la página (asoma por los bordes cuando la página se encoge).
  final Color? fondo;

  /// Recorte fijo, en coordenadas de la pantalla.
  final Path? recorte;

  /// Transformación de la página.
  final Matrix4? matriz;

  /// Recorte que se mueve con la página (el borde troquelado).
  final Path? recorteMovil;

  /// Se pinta debajo de la página y se mueve con ella (su sombra).
  final void Function(Canvas canvas)? debajo;

  /// Se pinta encima de la página, en coordenadas de la pantalla (penumbras y sombras).
  final void Function(Canvas canvas)? encima;
}

abstract class _Efecto {
  const _Efecto();

  /// La página se pinta tal cual (fin de una entrada o inicio de una secundaria).
  bool reposo(double t);

  /// No se ve nada de la página.
  bool oculto(double t, bool salida) => false;

  /// [salida]: la animación vuelve atrás desde el final (se cierra la página, después de haber entrado entera).
  _Escena escena(Size size, double t, bool salida);
}

class _Transicion extends SingleChildRenderObjectWidget {
  const _Transicion({required this.animation, required this.efecto, required this.reducir, super.child});

  final Animation<double> animation;
  final _Efecto efecto;
  final bool reducir;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTransicion(animation, efecto, reducir);

  @override
  void updateRenderObject(BuildContext context, _RenderTransicion renderObject) {
    renderObject
      ..animation = animation
      ..efecto = efecto
      ..reducir = reducir;
  }
}

class _RenderTransicion extends RenderProxyBox {
  _RenderTransicion(this._animation, this._efecto, this._reducir);

  Animation<double> _animation;
  set animation(Animation<double> valor) {
    if (identical(valor, _animation)) return;
    if (attached) _dejarDeEscuchar();
    _animation = valor;
    _salida = false;
    if (attached) _escuchar();
    markNeedsPaint();
  }

  _Efecto _efecto;
  set efecto(_Efecto valor) {
    if (identical(valor, _efecto)) return;
    _efecto = valor;
    markNeedsPaint();
  }

  bool _reducir;
  set reducir(bool valor) {
    if (valor == _reducir) return;
    _reducir = valor;
    markNeedsPaint();
  }

  bool _salida = false;
  Matrix4? _matriz;

  final _capaRecorte = LayerHandle<ClipPathLayer>();
  final _capaTransformacion = LayerHandle<TransformLayer>();
  final _capaRecorteMovil = LayerHandle<ClipPathLayer>();

  void _alCambiarEstado(AnimationStatus estado) {
    switch (estado) {
      case AnimationStatus.reverse:
        _salida = _animation.value >= 1.0;
      case AnimationStatus.forward:
        _salida = false;
      case AnimationStatus.completed:
      case AnimationStatus.dismissed:
        break;
    }
    markNeedsPaint();
  }

  void _escuchar() {
    _animation
      ..addListener(markNeedsPaint)
      ..addStatusListener(_alCambiarEstado);
  }

  void _dejarDeEscuchar() {
    _animation
      ..removeListener(markNeedsPaint)
      ..removeStatusListener(_alCambiarEstado);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _escuchar();
  }

  @override
  void detach() {
    _dejarDeEscuchar();
    super.detach();
  }

  @override
  void dispose() {
    _soltarCapas();
    super.dispose();
  }

  void _soltarCapas() {
    _capaRecorte.layer = null;
    _capaTransformacion.layer = null;
    _capaRecorteMovil.layer = null;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final t = _animation.value;
    if (_reducir || _efecto.reposo(t) || _efecto.oculto(t, _salida)) {
      _soltarCapas();
      _matriz = null;
      if (!_efecto.oculto(t, _salida) || _reducir) context.paintChild(child, offset);
      return;
    }
    final escena = _efecto.escena(size, t, _salida);
    _matriz = escena.matriz;
    final recorte = escena.recorte;
    if (recorte == null) {
      _capaRecorte.layer = null;
      _pintarEscena(context, offset, escena, child);
    } else {
      _capaRecorte.layer = context.pushClipPath(
        needsCompositing,
        offset,
        Offset.zero & size,
        recorte,
        (context, offset) => _pintarEscena(context, offset, escena, child),
        oldLayer: _capaRecorte.layer,
      );
    }
  }

  void _pintarEscena(PaintingContext context, Offset offset, _Escena escena, RenderBox child) {
    final fondo = escena.fondo;
    if (fondo != null) context.canvas.drawRect(offset & size, Paint()..color = fondo);
    final matriz = escena.matriz;
    if (matriz == null) {
      _capaTransformacion.layer = null;
      _pintarPagina(context, offset, escena, child);
    } else {
      _capaTransformacion.layer = context.pushTransform(
        needsCompositing,
        offset,
        matriz,
        (context, offset) => _pintarPagina(context, offset, escena, child),
        oldLayer: _capaTransformacion.layer,
      );
    }
    final encima = escena.encima;
    if (encima != null) _dibujar(context.canvas, offset, encima);
  }

  void _pintarPagina(PaintingContext context, Offset offset, _Escena escena, RenderBox child) {
    final debajo = escena.debajo;
    if (debajo != null) _dibujar(context.canvas, offset, debajo);
    final recorteMovil = escena.recorteMovil;
    if (recorteMovil == null) {
      _capaRecorteMovil.layer = null;
      context.paintChild(child, offset);
    } else {
      _capaRecorteMovil.layer = context.pushClipPath(
        needsCompositing,
        offset,
        Offset.zero & size,
        recorteMovil,
        (context, offset) => context.paintChild(child, offset),
        oldLayer: _capaRecorteMovil.layer,
      );
    }
  }

  static void _dibujar(Canvas canvas, Offset offset, void Function(Canvas canvas) dibujo) {
    canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    dibujo(canvas);
    canvas.restore();
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final matriz = _matriz;
    if (matriz == null) return super.hitTestChildren(result, position: position);
    return result.addWithPaintTransform(
      transform: matriz,
      position: position,
      hitTest: (result, position) => super.hitTestChildren(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final matriz = _matriz;
    if (matriz != null) transform.multiply(matriz);
  }
}

/// Escala [escala] alrededor del centro de [size].
Matrix4 _escalaCentrada(Size size, double escala) => Matrix4.identity()
  ..translateByDouble(size.width / 2, size.height / 2, 0, 1)
  ..scaleByDouble(escala, escala, 1, 1)
  ..translateByDouble(-size.width / 2, -size.height / 2, 0, 1);

/// Baja [dy] y gira [giro] alrededor del centro del borde de arriba.
Matrix4 _caidaDesdeArriba(Size size, double dy, double giro) => Matrix4.identity()
  ..translateByDouble(size.width / 2, dy, 0, 1)
  ..rotateZ(giro)
  ..translateByDouble(-size.width / 2, 0, 0, 1);

/// Al cerrar un módulo o una lección: la página cae hacia abajo girando un poco, con su sombra.
_Escena _escenaCaida(Size size, double t, {double giro = 0.05}) {
  final p = Curves.easeInCubic.transform(1 - t);
  final pagina = Path()..addRect(Offset.zero & size);
  return _Escena(
    matriz: _caidaDesdeArriba(size, p * size.height * 1.04, giro * p),
    debajo: (canvas) => canvas.drawShadow(pagina, const Color(0x99000000), 14, false),
  );
}

// ---------------------------------------------------------------------------------------------------------------
// Rasgar.

/// Dónde está cada mitad de la pantalla rasgada en el instante [t] (de 0 a 1, sin curva).
///
/// Se rasga de izquierda a derecha: las dos mitades giran primero sobre el extremo derecho de la rotura (se abre una
/// cuña) y después se van, la de arriba hacia arriba y la de abajo hacia abajo.
///
/// Cada mitad sobresale de la pantalla un 15 % de su lado largo: al girar, sus bordes de fuera nunca asoman. Lo que
/// queda fuera de la captura se pinta del color del papel, así la hoja parece entera.
class _Rasgado {
  factory _Rasgado(Size size, double t) {
    final margen = size.longestSide * 0.15;
    final corte = size.height * 0.46;
    final ancho = size.width + margen * 2;
    final tramos = math.max(10, (ancho / 13).ceil());
    final puntos = <Offset>[
      for (var i = 0; i <= tramos; i++)
        Offset(-margen + ancho * i / tramos, corte + (i.isEven ? -1 : 1) * (2 + 4.5 * _azar(i))),
    ];
    final borde = Path()..addPolygon(puntos, false);
    final arriba = Path()
      ..addPolygon([Offset(-margen, -margen), Offset(size.width + margen, -margen), ...puntos.reversed], true);
    final abajo = Path()
      ..addPolygon([
        ...puntos,
        Offset(size.width + margen, size.height + margen),
        Offset(-margen, size.height + margen),
      ], true);

    final apertura = Curves.easeOutCubic.transform((t / 0.32).clamp(0.0, 1.0));
    final vuelo = Curves.easeInOutCubic.transform(((t - 0.16) / 0.84).clamp(0.0, 1.0));
    final giro = 0.085 * apertura + 0.07 * vuelo;
    final pivote = Offset(size.width, corte);
    Matrix4 mitad(double signo, double distancia) => Matrix4.identity()
      ..translateByDouble(pivote.dx - signo * 24 * vuelo, pivote.dy + signo * distancia * vuelo, 0, 1)
      ..rotateZ(-signo * giro)
      ..translateByDouble(-pivote.dx, -pivote.dy, 0, 1);
    return _Rasgado._(
      size: size,
      arriba: arriba,
      abajo: abajo,
      borde: borde,
      matrizArriba: mitad(-1, corte + 40),
      matrizAbajo: mitad(1, size.height - corte + 40),
    );
  }

  _Rasgado._({
    required this.size,
    required this.arriba,
    required this.abajo,
    required this.borde,
    required this.matrizArriba,
    required this.matrizAbajo,
  });

  final Size size;
  final Path arriba;
  final Path abajo;
  final Path borde;
  final Matrix4 matrizArriba;
  final Matrix4 matrizAbajo;

  Path get arribaColocada => arriba.transform(matrizArriba.storage);
  Path get abajoColocada => abajo.transform(matrizAbajo.storage);

  /// Lo que queda al descubierto entre las dos mitades: por ahí se ve la página nueva.
  Path hueco(Path arribaColocada, Path abajoColocada) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addPath(arribaColocada, Offset.zero)
    ..addPath(abajoColocada, Offset.zero);

  /// Números pseudoaleatorios fijos: la rotura es irregular, pero siempre la misma.
  static double _azar(int i) {
    final x = math.sin(i * 127.1 + 311.7) * 43758.5453;
    return x - x.floorToDouble();
  }
}

/// La página nueva de [TransicionTuTurno.rasgar]: se ve por la rotura, se acerca un poco y sale de la penumbra.
class _EntradaRasgada extends _Efecto {
  const _EntradaRasgada();

  @override
  bool reposo(double t) => t >= 1;

  @override
  bool oculto(double t, bool salida) => !salida && t <= 0;

  /// Sombra de cada mitad sobre el módulo, a lo largo de la rotura: un trazo difuminado. Es barato porque solo ocupa
  /// la franja de la rotura (difuminar la silueta de media pantalla en cada fotograma costaría mucho más).
  static final _sombraRotura = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0x73000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

  @override
  _Escena escena(Size size, double t, bool salida) {
    if (salida) return _escenaCaida(size, t);
    final rasgado = _Rasgado(size, t);
    final penumbra = PaletaMovimiento.azulNoche.withValues(alpha: 0.5 * (1 - Curves.easeOut.transform(t)));
    return _Escena(
      fondo: PaletaMovimiento.azulNoche,
      recorte: rasgado.hueco(rasgado.arribaColocada, rasgado.abajoColocada),
      matriz: _escalaCentrada(size, 0.92 + 0.08 * Curves.easeOutCubic.transform(t)),
      encima: (canvas) {
        canvas.drawRect(Offset.zero & size, Paint()..color = penumbra);
        // Cada sombra cae hacia el hueco: la de arriba, por debajo de su borde; la de abajo, por encima.
        for (final (matriz, hacia) in [(rasgado.matrizArriba, 1.0), (rasgado.matrizAbajo, -1.0)]) {
          canvas
            ..save()
            ..transform(matriz.storage)
            ..translate(0, 4 * hacia)
            ..drawPath(rasgado.borde, _sombraRotura)
            ..restore();
        }
      },
    );
  }
}

/// La página de debajo en [TransicionTuTurno.rasgar]. Se rasga sobre una captura (una sola imagen que se mueve, muy
/// barata); donde no se puede capturar (web, vistas nativas), se queda entera y la nueva se abre paso igualmente.
class _RasgarAnterior extends StatefulWidget {
  const _RasgarAnterior({
    required this.animation,
    required this.reducir,
    required this.permitirCaptura,
    required this.child,
  });

  final Animation<double> animation;
  final bool reducir;
  final bool permitirCaptura;
  final Widget child;

  @override
  State<_RasgarAnterior> createState() => _RasgarAnteriorState();
}

class _RasgarAnteriorState extends State<_RasgarAnterior> {
  final _captura = SnapshotController();
  late final _PintorRasgado _pintor = _PintorRasgado(widget.animation)..reducir = widget.reducir;

  bool get _puedeCapturar => widget.permitirCaptura && !widget.reducir && !kIsWeb;

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_alCambiarEstado);
    _alCambiarEstado(widget.animation.status);
  }

  @override
  void didUpdateWidget(_RasgarAnterior anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.animation != widget.animation) {
      anterior.animation.removeStatusListener(_alCambiarEstado);
      widget.animation.addStatusListener(_alCambiarEstado);
      _pintor.animation = widget.animation;
    }
    _pintor.reducir = widget.reducir;
    _alCambiarEstado(widget.animation.status);
  }

  void _alCambiarEstado(AnimationStatus estado) {
    _captura.allowSnapshotting = estado.isAnimating && _puedeCapturar;
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_alCambiarEstado);
    _captura.dispose();
    _pintor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _pintor.papel = Theme.of(context).scaffoldBackgroundColor;
    return SnapshotWidget(controller: _captura, mode: SnapshotMode.permissive, painter: _pintor, child: widget.child);
  }
}

class _PintorRasgado extends SnapshotPainter {
  _PintorRasgado(this._animation) {
    _escuchar();
  }

  Animation<double> _animation;
  set animation(Animation<double> valor) {
    if (identical(valor, _animation)) return;
    _dejarDeEscuchar();
    _animation = valor;
    _salida = false;
    _escuchar();
    notifyListeners();
  }

  bool reducir = false;

  /// Color del papel de la página: rellena lo que cada mitad tiene fuera de la captura.
  Color papel = PaletaMovimiento.papel;
  bool _salida = false;
  final _capa = LayerHandle<TransformLayer>();

  void _escuchar() {
    _animation
      ..addListener(notifyListeners)
      ..addStatusListener(_alCambiarEstado);
  }

  void _dejarDeEscuchar() {
    _animation
      ..removeListener(notifyListeners)
      ..removeStatusListener(_alCambiarEstado);
  }

  void _alCambiarEstado(AnimationStatus estado) {
    switch (estado) {
      case AnimationStatus.reverse:
        _salida = _animation.value >= 1.0;
      case AnimationStatus.forward:
        _salida = false;
      case AnimationStatus.completed:
      case AnimationStatus.dismissed:
        break;
    }
  }

  /// Al cerrar el módulo, la pantalla de antes está entera, un poco alejada y en penumbra, y vuelve a su sitio.
  double get _alejamiento => 1 - 0.06 * _animation.value;
  Color get _penumbra => PaletaMovimiento.azulNoche.withValues(alpha: 0.35 * _animation.value);

  @override
  void paint(PaintingContext context, Offset offset, Size size, PaintingContextCallback painter) {
    if (reducir || !_salida || _animation.value <= 0) {
      _capa.layer = null;
      painter(context, offset);
      return;
    }
    context.canvas.drawRect(offset & size, Paint()..color = PaletaMovimiento.azulNoche);
    _capa.layer = context.pushTransform(
      true,
      offset,
      _escalaCentrada(size, _alejamiento),
      painter,
      oldLayer: _capa.layer,
    );
    context.canvas.drawRect(offset & size, Paint()..color = _penumbra);
  }

  @override
  void paintSnapshot(
    PaintingContext context,
    Offset offset,
    Size size,
    ui.Image image,
    Size sourceSize,
    double pixelRatio,
  ) {
    final canvas = context.canvas;
    final origen = Offset.zero & sourceSize;
    final pincel = Paint()..filterQuality = FilterQuality.medium;
    final t = _animation.value;
    if (reducir || t <= 0) {
      canvas.drawImageRect(image, origen, offset & size, pincel);
      return;
    }
    canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    if (_salida) {
      canvas
        ..drawRect(Offset.zero & size, Paint()..color = PaletaMovimiento.azulNoche)
        ..save()
        ..transform(_escalaCentrada(size, _alejamiento).storage)
        ..drawImageRect(image, origen, Offset.zero & size, pincel)
        ..restore()
        ..drawRect(Offset.zero & size, Paint()..color = _penumbra)
        ..restore();
      return;
    }
    final rasgado = _Rasgado(size, t);
    // Las fibras del papel roto: un filo claro a lo largo de la rotura.
    final fibras = Paint()
      ..color = PaletaMovimiento.papel
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeJoin = StrokeJoin.round;
    final fondo = Paint()..color = papel;
    for (final (mitad, matriz) in [(rasgado.arriba, rasgado.matrizArriba), (rasgado.abajo, rasgado.matrizAbajo)]) {
      canvas
        ..save()
        ..transform(matriz.storage)
        ..clipPath(mitad)
        ..drawPaint(fondo)
        ..drawImageRect(image, origen, Offset.zero & size, pincel)
        ..drawPath(rasgado.borde, fibras)
        ..restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorRasgado oldPainter) => oldPainter != this;

  @override
  void dispose() {
    _dejarDeEscuchar();
    _capa.layer = null;
    super.dispose();
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Deslizar.

const _curvaDeslizar = Cubic(0.18, 0.9, 0.28, 1);

/// Borde de arriba troquelado (medios círculos mordidos), de [profundidad] píxeles.
Path _bordeTroquelado(Size size, double profundidad) {
  final path = Path()..moveTo(0, 0);
  if (profundidad > 0.5) {
    final tramos = math.max(6, (size.width / 22).round());
    final paso = size.width / tramos;
    final radio = math.min(profundidad, paso / 2.5);
    for (var i = 0; i < tramos; i++) {
      final centro = paso * (i + 0.5);
      path
        ..lineTo(centro - radio, 0)
        ..arcToPoint(Offset(centro + radio, 0), radius: Radius.circular(radio), clockwise: false);
    }
  }
  return path
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();
}

/// La página nueva de [TransicionTuTurno.deslizar]: sube con el borde troquelado, inclinada, y se endereza al llegar.
/// El troquel se ve mientras sube y se alisa en la última parte, cuando ya casi ha llegado.
class _EntradaDeslizada extends _Efecto {
  const _EntradaDeslizada();

  static const _alisado = Interval(0.55, 1, curve: Curves.easeInOut);

  @override
  bool reposo(double t) => t >= 1;

  @override
  bool oculto(double t, bool salida) => t <= 0;

  @override
  _Escena escena(Size size, double t, bool salida) {
    if (salida) return _escenaCaida(size, t, giro: 0.035);
    final resto = 1 - _curvaDeslizar.transform(t);
    // La sombra es la del rectángulo de la página: el motor la calcula directamente, sin difuminar una imagen en cada
    // fotograma (con la silueta troquelada sí tendría que hacerlo). Por los mordiscos del troquel asoma un poco.
    final pagina = Path()..addRect(Offset.zero & size);
    return _Escena(
      matriz: _caidaDesdeArriba(size, resto * size.height, 0.05 * resto),
      recorteMovil: _bordeTroquelado(size, 7 * (1 - _alisado.transform(t))),
      debajo: (canvas) => canvas.drawShadow(pagina, const Color(0x88000000), 16, false),
    );
  }
}

/// La página de debajo de [TransicionTuTurno.deslizar]: se aleja un poco y queda en penumbra.
class _AnteriorAlejada extends _Efecto {
  const _AnteriorAlejada();

  @override
  bool reposo(double t) => t <= 0;

  @override
  _Escena escena(Size size, double t, bool salida) {
    final e = Curves.easeOutCubic.transform(t);
    final penumbra = Paint()..color = PaletaMovimiento.azulNoche.withValues(alpha: 0.32 * e);
    return _Escena(
      fondo: PaletaMovimiento.azulNoche,
      matriz: _escalaCentrada(size, 1 - 0.06 * e),
      encima: (canvas) => canvas.drawRect(Offset.zero & size, penumbra),
    );
  }
}
