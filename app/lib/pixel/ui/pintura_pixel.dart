import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'estilo_pixel.dart';

// Primitivas de dibujo del kit. Todo se pinta con rectángulos sin suavizado sobre una rejilla de unidades pixel
// (`unidadPixel`, un número entero de píxeles físicos): nada de esquinas redondas, desenfoques ni bordes a medias.
// Las esquinas «redondeadas» son escalones: el perfil de una esquina dice cuántas unidades se recortan en cada fila.
//
// Con Skia (la web), un pincel sin suavizado ya cae en píxeles enteros. Impeller (Android e iOS) suaviza todos los
// bordes que no caen justo en un píxel físico, así que además cada pieza se pinta con su origen ajustado a la
// rejilla de la pantalla ([AjustePixel]).

/// Pincel sin suavizado: los bordes caen justo en los píxeles.
Paint pincelPixel(Color color) => Paint()
  ..color = color
  ..isAntiAlias = false;

/// [valor] (en píxeles lógicos) redondeado al píxel físico más cercano.
double alPixelFisico(double valor, double dpr) => (valor * dpr).roundToDouble() / dpr;

/// Escalones de una esquina de [radio] unidades: cuántas unidades se recortan en cada fila, desde el borde.
///
/// Los perfiles encajan unos dentro de otros ([perfilInterior] de uno es el anterior), así que un contorno, un anillo
/// de foco o una sombra siguen siempre la misma esquina.
List<int> perfilEsquina(int radio) => switch (radio) {
  <= 0 => const [],
  1 => const [1],
  2 => const [2, 1],
  3 => const [3, 1, 1],
  4 => const [4, 2, 1, 1],
  5 => const [5, 3, 2, 1, 1],
  _ => const [6, 4, 3, 2, 1, 1],
};

/// Perfil de la forma una unidad hacia dentro de la de [perfil]: el contorno que queda entre las dos mide una unidad
/// y baja en diagonal por los escalones.
List<int> perfilInterior(List<int> perfil) {
  int s(int y) => y >= 0 && y < perfil.length ? perfil[y] : 0;
  final interior = <int>[];
  for (var y = 1; ; y++) {
    final v = math.max(s(y) + 1, math.max(s(y - 1), s(y + 1))) - 1;
    if (v <= 0) break;
    interior.add(v);
  }
  return interior;
}

/// Rellena la forma de [r] con las esquinas de [perfil] (en unidades de [u]).
void pintarForma(Canvas canvas, Rect r, double u, List<int> perfil, Paint pincel) {
  if (r.width <= 0 || r.height <= 0) return;
  final filas = math.min(perfil.length, (r.height / u / 2).floor());
  for (var y = 0; y < filas; y++) {
    final dx = perfil[y] * u;
    // En una caja más estrecha que sus esquinas, la fila no existe (y un rectángulo al revés no se pinta).
    if (r.width <= 2 * dx) continue;
    canvas
      ..drawRect(Rect.fromLTRB(r.left + dx, r.top + y * u, r.right - dx, r.top + (y + 1) * u), pincel)
      ..drawRect(Rect.fromLTRB(r.left + dx, r.bottom - (y + 1) * u, r.right - dx, r.bottom - y * u), pincel);
  }
  final medio = Rect.fromLTRB(r.left, r.top + filas * u, r.right, r.bottom - filas * u);
  if (medio.height > 0) canvas.drawRect(medio, pincel);
}

/// Pinta solo el contorno (una unidad) de la forma de [r] con las esquinas de [perfil].
void pintarContorno(Canvas canvas, Rect r, double u, List<int> perfil, Paint pincel) {
  if (r.width <= 2 * (perfil.isEmpty ? 1 : perfil.first) * u || r.height <= 2 * (perfil.length + 1) * u) {
    // Demasiado pequeña para sus escalones: un contorno rectangular.
    canvas
      ..drawRect(Rect.fromLTRB(r.left, r.top, r.right, math.min(r.bottom, r.top + u)), pincel)
      ..drawRect(Rect.fromLTRB(r.left, math.max(r.top, r.bottom - u), r.right, r.bottom), pincel);
    if (r.height > 2 * u && r.width > 2 * u) {
      canvas
        ..drawRect(Rect.fromLTRB(r.left, r.top + u, r.left + u, r.bottom - u), pincel)
        ..drawRect(Rect.fromLTRB(r.right - u, r.top + u, r.right, r.bottom - u), pincel);
    }
    return;
  }
  final interior = perfilInterior(perfil);
  int s(int y) => y < perfil.length ? perfil[y] : 0;
  // Dónde empieza la forma interior en la fila y (y ≥ 1), contando desde el borde de fuera.
  int si(int y) => y - 1 < interior.length ? interior[y - 1] + 1 : 1;
  final p0 = s(0) * u;
  canvas
    ..drawRect(Rect.fromLTRB(r.left + p0, r.top, r.right - p0, r.top + u), pincel)
    ..drawRect(Rect.fromLTRB(r.left + p0, r.bottom - u, r.right - p0, r.bottom), pincel);
  final filas = math.max(perfil.length, interior.length + 1);
  for (var y = 1; y < filas; y++) {
    final a = s(y) * u;
    final b = si(y) * u;
    if (b <= a) continue;
    final arriba = r.top + y * u;
    final abajo = r.bottom - (y + 1) * u;
    canvas
      ..drawRect(Rect.fromLTRB(r.left + a, arriba, r.left + b, arriba + u), pincel)
      ..drawRect(Rect.fromLTRB(r.right - b, arriba, r.right - a, arriba + u), pincel)
      ..drawRect(Rect.fromLTRB(r.left + a, abajo, r.left + b, abajo + u), pincel)
      ..drawRect(Rect.fromLTRB(r.right - b, abajo, r.right - a, abajo + u), pincel);
  }
  final top = r.top + filas * u;
  final bottom = r.bottom - filas * u;
  if (bottom > top) {
    canvas
      ..drawRect(Rect.fromLTRB(r.left, top, r.left + u, bottom), pincel)
      ..drawRect(Rect.fromLTRB(r.right - u, top, r.right, bottom), pincel);
  }
}

/// Pinta la fila de arriba (o la de abajo) de la forma de [r]: la luz o la sombra de un botón.
void pintarFilaBorde(Canvas canvas, Rect r, double u, List<int> perfil, Paint pincel, {required bool arriba}) {
  final dx = (perfil.isEmpty ? 0 : perfil.first) * u;
  if (r.width <= 2 * dx || r.height < u) return;
  final y = arriba ? r.top : r.bottom - u;
  canvas.drawRect(Rect.fromLTRB(r.left + dx, y, r.right - dx, y + u), pincel);
}

/// Cómo se pinta una caja pixel: de fuera adentro, sombra dura, contorno, anillo, relleno y las filas de luz y sombra.
@immutable
class EstiloCajaPixel {
  const EstiloCajaPixel({
    required this.relleno,
    this.contorno = ColoresUiPixel.noche,
    this.anillo,
    this.luz,
    this.sombraInterior,
    this.sombra = ColoresUiPixel.noche,
    this.esquina = 2,
    this.profundidad = 1,
  });

  final Color relleno;

  /// Borde exterior (una unidad). Null: sin borde.
  final Color? contorno;

  /// Segundo borde, por dentro del contorno (el marco blanco de las ventanas de rol).
  final Color? anillo;

  /// Fila de arriba del relleno, más clara.
  final Color? luz;

  /// Fila de abajo del relleno, más oscura.
  final Color? sombraInterior;

  /// Sombra dura debajo de la caja. Null: sin sombra (pero se guarda su sitio, [profundidad]).
  final Color? sombra;

  /// Radio de las esquinas escalonadas, en unidades.
  final int esquina;

  /// Unidades que baja la sombra (y la caja al pulsarla). Se reservan aunque no haya sombra.
  final int profundidad;

  /// La caja pulsada: sin sombra ni luz (ha bajado hasta su sombra) y con la sombra interior arriba.
  EstiloCajaPixel get pulsado => EstiloCajaPixel(
    relleno: relleno,
    contorno: contorno,
    anillo: anillo,
    luz: sombraInterior,
    esquina: esquina,
    profundidad: profundidad,
    sombra: null,
  );

  @override
  bool operator ==(Object other) =>
      other is EstiloCajaPixel &&
      other.relleno == relleno &&
      other.contorno == contorno &&
      other.anillo == anillo &&
      other.luz == luz &&
      other.sombraInterior == sombraInterior &&
      other.sombra == sombra &&
      other.esquina == esquina &&
      other.profundidad == profundidad;

  @override
  int get hashCode => Object.hash(relleno, contorno, anillo, luz, sombraInterior, sombra, esquina, profundidad);
}

/// Pinta una caja pixel en [caja] (sin contar la sombra, que queda debajo).
void pintarCajaPixel(Canvas canvas, Rect caja, double u, EstiloCajaPixel e) {
  if (caja.width <= 0 || caja.height <= 0) return;
  var perfil = perfilEsquina(e.esquina);
  final sombra = e.sombra;
  if (sombra != null && e.profundidad > 0) {
    pintarForma(canvas, caja.shift(Offset(0, e.profundidad * u)), u, perfil, pincelPixel(sombra));
  }
  var r = caja;
  for (final borde in [e.contorno, e.anillo]) {
    if (borde == null) continue;
    pintarForma(canvas, r, u, perfil, pincelPixel(borde));
    r = r.deflate(u);
    perfil = perfilInterior(perfil);
  }
  pintarForma(canvas, r, u, perfil, pincelPixel(e.relleno));
  final luz = e.luz;
  if (luz != null) pintarFilaBorde(canvas, r, u, perfil, pincelPixel(luz), arriba: true);
  final sombraInterior = e.sombraInterior;
  if (sombraInterior != null && r.height > 2 * u) {
    pintarFilaBorde(canvas, r, u, perfil, pincelPixel(sombraInterior), arriba: false);
  }
}

/// Anillo de foco alrededor de [r] (con las esquinas de radio [esquina]): una unidad amarilla pegada a la pieza y otra
/// azul noche por fuera, para que se vea sobre fondos claros y oscuros. Queda fuera de [r].
void pintarAnilloFoco(Canvas canvas, Rect r, double u, int esquina) {
  pintarContorno(canvas, r.inflate(u), u, perfilEsquina(esquina + 1), pincelPixel(ColoresUiPixel.amarillo));
  pintarContorno(canvas, r.inflate(2 * u), u, perfilEsquina(esquina + 2), pincelPixel(ColoresUiPixel.noche));
}

/// Filo de una unidad por dentro de [r] (con las esquinas de radio [esquina] + 1): el borde que separa una pieza de un
/// fondo oscuro (ver [FondoPixel]). Lo de dentro, una unidad más pequeño, es la pieza con su sombra.
void pintarFilo(Canvas canvas, Rect r, double u, int esquina, Color filo) =>
    pintarContorno(canvas, r, u, perfilEsquina(esquina + 1), pincelPixel(filo));

/// Pinta [child] con su origen justo en un píxel físico de la pantalla: lo mueve menos de medio píxel físico, lo que
/// haga falta, al pintarlo (el sitio que ocupa no cambia).
///
/// Así los rectángulos del kit caen enteros en los píxeles también con Impeller, que suaviza cualquier borde a medio
/// píxel (después de una línea de texto de 27,5 puntos, en un `Center` o en una lista desplazada). El ajuste se
/// calcula al pintar: si lo que se mueve es una capa de más arriba que no se vuelve a pintar (una `RepaintBoundary`
/// que se desplaza), se queda con el ajuste de antes. Por eso las listas del juego llevan `addRepaintBoundaries:
/// false` (o son un `SingleChildScrollView`).
class AjustePixel extends SingleChildRenderObjectWidget {
  const AjustePixel({super.key, super.child});

  @override
  RenderAjustePixel createRenderObject(BuildContext context) =>
      RenderAjustePixel(MediaQuery.maybeDevicePixelRatioOf(context) ?? 1);

  @override
  void updateRenderObject(BuildContext context, RenderAjustePixel renderObject) {
    renderObject.dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
  }
}

/// El [RenderBox] de [AjustePixel].
class RenderAjustePixel extends RenderProxyBox {
  RenderAjustePixel(this._dpr, [RenderBox? child]) : super(child);

  double _dpr;
  double get dpr => _dpr;
  set dpr(double valor) {
    if (valor == _dpr) return;
    _dpr = valor;
    markNeedsPaint();
  }

  /// Lo que se movió el hijo al pintarlo por última vez (menos de medio píxel físico en cada eje).
  Offset get desfase => _desfase;
  Offset _desfase = Offset.zero;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    // localToGlobal da puntos lógicos de la pantalla (sin la densidad): por la densidad, píxeles físicos.
    final global = localToGlobal(Offset.zero);
    double resto(double valor) => ((valor * _dpr).roundToDouble() - valor * _dpr) / _dpr;
    _desfase = global.isFinite ? Offset(resto(global.dx), resto(global.dy)) : Offset.zero;
    context.paintChild(child, offset + _desfase);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.translateByDouble(_desfase.dx, _desfase.dy, 0, 1);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => result.addWithPaintOffset(
    offset: _desfase,
    position: position,
    hitTest: (result, transformado) => super.hitTestChildren(result, position: transformado),
  );
}

/// Caja pixel detrás de [child]: contorno escalonado, relleno con luz y sombra y una sombra dura debajo.
///
/// [interior] es el margen de dentro, en unidades pixel. Con [pulsada], la caja baja hasta su sombra y [child] baja
/// con ella; con [foco], lleva el anillo de foco alrededor.
///
/// Sobre un [FondoPixel] oscuro, si su contorno no se ve, lleva un filo de una unidad alrededor (la caja ocupa una
/// unidad más por cada lado). [conFilo] lo fuerza (true) o lo quita (false); null, según el fondo.
class CajaPixel extends StatelessWidget {
  const CajaPixel({
    super.key,
    required this.estilo,
    this.interior = EdgeInsets.zero,
    this.pulsada = false,
    this.foco = false,
    this.conFilo,
    this.child,
  });

  final EstiloCajaPixel estilo;
  final EdgeInsets interior;
  final bool pulsada;
  final bool foco;
  final bool? conFilo;
  final Widget? child;

  /// El filo que lleva una caja de [estilo] en [context] (null: ninguno).
  static Color? filoDe(BuildContext context, EstiloCajaPixel estilo, {bool? conFilo}) => switch (conFilo) {
    false => null,
    true => FondoPixel.maybeOf(context)?.colorFilo ?? ColoresUiPixel.azul,
    null => filoPixel(context, contorno: estilo.contorno, anillo: estilo.anillo),
  };

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final filo = filoDe(context, estilo, conFilo: conFilo);
    final borde = filo == null ? 0.0 : u;
    final profundidad = estilo.profundidad * u;
    final baja = pulsada ? profundidad : 0.0;
    return AjustePixel(
      child: CustomPaint(
        painter: PintorCajaPixel(estilo: estilo, u: u, dpr: dpr, pulsada: pulsada, foco: foco, filo: filo),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            interior.left * u + borde,
            interior.top * u + baja + borde,
            interior.right * u + borde,
            interior.bottom * u + profundidad - baja + borde,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// El pintor de [CajaPixel], para usarlo también en otros CustomPaint. Con [filo], la caja va una unidad hacia dentro
/// y el filo ocupa el borde.
class PintorCajaPixel extends CustomPainter {
  const PintorCajaPixel({
    required this.estilo,
    required this.u,
    this.dpr = 1,
    this.pulsada = false,
    this.foco = false,
    this.filo,
  });

  final EstiloCajaPixel estilo;
  final double u;
  final double dpr;
  final bool pulsada;
  final bool foco;
  final Color? filo;

  @override
  void paint(Canvas canvas, Size size) {
    final profundidad = estilo.profundidad * u;
    final bordes = Rect.fromLTWH(0, 0, alPixelFisico(size.width, dpr), alPixelFisico(size.height, dpr));
    final filo = this.filo;
    final esquinaExterior = estilo.esquina + (filo == null ? 0 : 1);
    if (foco) pintarAnilloFoco(canvas, bordes, u, esquinaExterior);
    var silueta = bordes;
    if (filo != null) {
      pintarFilo(canvas, bordes, u, estilo.esquina, filo);
      silueta = bordes.deflate(u);
    }
    final caja = Rect.fromLTWH(
      silueta.left,
      silueta.top + (pulsada ? profundidad : 0),
      silueta.width,
      silueta.height - profundidad,
    );
    pintarCajaPixel(canvas, caja, u, pulsada ? estilo.pulsado : estilo);
  }

  @override
  bool shouldRepaint(PintorCajaPixel oldDelegate) =>
      oldDelegate.estilo != estilo ||
      oldDelegate.u != u ||
      oldDelegate.dpr != dpr ||
      oldDelegate.pulsada != pulsada ||
      oldDelegate.foco != foco ||
      oldDelegate.filo != filo;
}
