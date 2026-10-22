import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../tema.dart';
import 'paleta_iconos.dart';
import 'recorte.dart';

// Tut, la mascota de TuTurno: un ticket de turno amarillo con la cara del monograma «TuT». Las dos T son los ojos
// (la barra es el párpado y el palo, el ojo abierto) y la u es la boca. Cuando está triste, la cara recuerda al
// emoticono TuT; solo se usa para acompañar, nunca para reñir.

/// Expresiones de Tut. [descripcion] es lo que lee el lector de pantalla.
enum ExpresionTut {
  neutral('Tut, la mascota de TuTurno'),
  feliz('Tut sonríe'),
  celebrando('Tut lo celebra'),
  pensando('Tut está pensando'),
  sorprendida('Tut se sorprende'),
  animo('Tut te anima'),
  triste('Tut está triste, te acompaña');

  const ExpresionTut(this.descripcion);

  final String descripcion;
}

/// Gestos sueltos de Tut cuando está quieto: nunca en bucle, cada pocos segundos y solo si hay movimiento.
enum _Gesto { parpadeo, salto, mirar }

const _duracionEntrada = Duration(milliseconds: 520);
const _duracionCambio = Duration(milliseconds: 420);

/// Pausas entre gestos (se recorren en orden: así Tut parece vivo sin ser previsible).
const _pausas = [3200, 4400, 2700, 5100, 3800];

/// La mascota Tut con una [expresion]. Con [animada], aparece con un pequeño salto, parpadea y se mueve de vez en
/// cuando (gestos cortos, sin bucles); al cambiar de expresión, la cara se transforma. Respeta la opción de reducir
/// animaciones. Con [pegatina], lleva borde blanco (para fondos de color).
class MascotaTut extends StatefulWidget {
  const MascotaTut({
    super.key,
    this.expresion = ExpresionTut.neutral,
    this.size = 120,
    this.animada = true,
    this.pegatina = false,
    this.semanticLabel,
    this.decorativo = false,
  });

  final ExpresionTut expresion;
  final double size;
  final bool animada;
  final bool pegatina;
  final String? semanticLabel;
  final bool decorativo;

  @override
  State<MascotaTut> createState() => _MascotaTutState();
}

class _MascotaTutState extends State<MascotaTut> with TickerProviderStateMixin {
  late final AnimationController _entrada = AnimationController(vsync: this, duration: _duracionEntrada, value: 1);
  late final AnimationController _cambio = AnimationController(vsync: this, duration: _duracionCambio, value: 1);
  late final AnimationController _gesto = AnimationController(vsync: this, value: 1)
    ..addStatusListener((estado) {
      if (estado == AnimationStatus.completed) _programar();
    });

  late _Cara _desde = _Cara.de(widget.expresion);
  late _Cara _hasta = _desde;
  _Gesto _gestoActual = _Gesto.parpadeo;
  Timer? _reloj;
  var _paso = 0;
  var _movimiento = true;
  var _iniciada = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _movimiento = duracion(context, _duracionCambio) != Duration.zero;
    if (!_iniciada) {
      _iniciada = true;
      if (widget.animada && _movimiento) _entrada.forward(from: 0);
    }
    if (!_movimiento) {
      _entrada.value = 1;
      _cambio.value = 1;
      _gesto.value = 1;
    }
    _programar();
  }

  @override
  void didUpdateWidget(MascotaTut anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.expresion != widget.expresion) {
      _desde = _caraActual();
      _hasta = _Cara.de(widget.expresion);
      if (_movimiento) {
        _cambio.forward(from: 0);
        if (widget.animada && _hasta.alegre) _hacer(_Gesto.salto);
      } else {
        _cambio.value = 1;
      }
    }
    if (anterior.animada != widget.animada) _programar();
  }

  _Cara _caraActual() => _Cara.lerp(_desde, _hasta, Curves.easeOutBack.transform(_cambio.value));

  /// Programa el siguiente gesto. Sin animaciones (o con [MascotaTut.animada] desactivado) no queda ningún reloj.
  void _programar() {
    _reloj?.cancel();
    _reloj = null;
    if (!mounted || !widget.animada || !_movimiento || _gesto.isAnimating) return;
    _reloj = Timer(Duration(milliseconds: _pausas[_paso % _pausas.length]), () {
      final gestos = _gestosDe(widget.expresion);
      _hacer(gestos[_paso % gestos.length]);
      _paso++;
    });
  }

  void _hacer(_Gesto gesto) {
    if (!mounted) return;
    _reloj?.cancel();
    _gestoActual = gesto;
    _gesto
      ..duration = switch (gesto) {
        _Gesto.parpadeo => const Duration(milliseconds: 240),
        _Gesto.salto => const Duration(milliseconds: 620),
        _Gesto.mirar => const Duration(milliseconds: 1100),
      }
      ..forward(from: 0);
  }

  static List<_Gesto> _gestosDe(ExpresionTut expresion) => switch (expresion) {
    ExpresionTut.celebrando => const [_Gesto.salto, _Gesto.salto, _Gesto.mirar],
    ExpresionTut.feliz || ExpresionTut.animo => const [_Gesto.parpadeo, _Gesto.salto, _Gesto.parpadeo],
    ExpresionTut.pensando => const [_Gesto.mirar, _Gesto.parpadeo],
    ExpresionTut.triste || ExpresionTut.sorprendida => const [_Gesto.parpadeo],
    ExpresionTut.neutral => const [_Gesto.parpadeo, _Gesto.parpadeo, _Gesto.mirar, _Gesto.parpadeo, _Gesto.salto],
  };

  @override
  void dispose() {
    _reloj?.cancel();
    _entrada.dispose();
    _cambio.dispose();
    _gesto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paleta = PaletaIconos.de(context);
    final dibujo = AnimatedBuilder(
      animation: Listenable.merge([_entrada, _cambio, _gesto]),
      builder: (context, _) {
        final t = _gesto.value;
        final enCurso = _gesto.isAnimating;
        final entrada = _entrada.value;
        final pintor = _PintorTut(
          cara: _caraActual(),
          paleta: paleta,
          pegatina: widget.pegatina,
          parpadeo: enCurso && _gestoActual == _Gesto.parpadeo ? _triangulo(t) : 0,
          salto: enCurso && _gestoActual == _Gesto.salto ? _Salto.en(t) : const _Salto(),
          mirar: enCurso && _gestoActual == _Gesto.mirar ? -3.2 * math.sin(2 * math.pi * t) : 0,
        );
        final lienzo = CustomPaint(size: Size.square(widget.size), painter: pintor);
        if (entrada >= 1) return lienzo;
        return Transform.rotate(
          angle: (1 - Curves.easeOutCubic.transform(entrada)) * -0.2,
          child: Transform.scale(scale: 0.35 + 0.65 * Curves.easeOutBack.transform(entrada), child: lienzo),
        );
      },
    );
    // Sus gestos solo repintan a Tut, no la pantalla de alrededor.
    final aislado = RepaintBoundary(child: dibujo);
    if (widget.decorativo) return ExcludeSemantics(child: aislado);
    return Semantics(
      label: widget.semanticLabel ?? widget.expresion.descripcion,
      image: true,
      child: ExcludeSemantics(child: aislado),
    );
  }

  static double _triangulo(double t) => t < 0.45 ? t / 0.45 : 1 - (t - 0.45) / 0.55;
}

/// Salto: se agacha, sube estirándose y aterriza aplastándose un poco.
@immutable
class _Salto {
  const _Salto({this.altura = 0, this.aplastar = 0});

  factory _Salto.en(double t) {
    if (t < 0.15) return _Salto(aplastar: 0.08 * math.sin(math.pi * t / 0.15));
    if (t < 0.85) {
      final s = (t - 0.15) / 0.7;
      return _Salto(altura: -8 * math.sin(math.pi * s), aplastar: -0.05 * math.sin(math.pi * s));
    }
    return _Salto(aplastar: 0.06 * math.sin(math.pi * (t - 0.85) / 0.15));
  }

  /// Desplazamiento vertical (negativo = arriba), en unidades de la rejilla de 100.
  final double altura;

  /// > 0 aplasta (más ancho y bajo); < 0 estira.
  final double aplastar;
}

/// Un ojo: la T del monograma.
@immutable
class _Ojo {
  const _Ojo({this.cejaY = 0, this.cejaSube = 0, this.arco = 0, this.alto = 17, this.ancho = 5.6});

  /// Desplazamiento de la barra (negativo = arriba). Si sube, se separa del palo: sorpresa.
  final double cejaY;

  /// Cuánto sube el extremo interior de la barra (positivo = tristeza).
  final double cejaSube;

  /// Curva de la barra hacia arriba: con [alto] = 0 son ojos felices (^).
  final double arco;

  /// Alto del palo (0 = ojo cerrado).
  final double alto;
  final double ancho;

  static _Ojo lerp(_Ojo a, _Ojo b, double t) => _Ojo(
    cejaY: lerpDouble(a.cejaY, b.cejaY, t)!,
    cejaSube: lerpDouble(a.cejaSube, b.cejaSube, t)!,
    arco: lerpDouble(a.arco, b.arco, t)!,
    alto: math.max(0, lerpDouble(a.alto, b.alto, t)!),
    ancho: lerpDouble(a.ancho, b.ancho, t)!,
  );
}

/// Parámetros de la cara: se interpolan para pasar de una expresión a otra.
@immutable
class _Cara {
  const _Cara({
    this.izq = const _Ojo(),
    this.der = const _Ojo(),
    this.mirarX = 0,
    this.mirarY = 0,
    this.bocaAncho = 17,
    this.bocaHondo = 12,
    this.bocaCurva = 1,
    this.bocaAbierta = 0,
    this.bocaRedonda = 0,
    this.bocaX = 0,
    this.rubor = 0,
    this.lagrima = 0,
    this.confeti = 0,
    this.burbuja = 0,
    this.destello = 0,
    this.giro = 0,
  });

  factory _Cara.de(ExpresionTut expresion) => switch (expresion) {
    ExpresionTut.neutral => const _Cara(),
    ExpresionTut.feliz => const _Cara(
      izq: _Ojo(alto: 14, cejaY: -1),
      der: _Ojo(alto: 14, cejaY: -1),
      bocaAncho: 21,
      bocaHondo: 13,
      rubor: 1,
      giro: -3,
    ),
    ExpresionTut.celebrando => const _Cara(
      izq: _Ojo(arco: 4.5, alto: 0, cejaY: 2.5),
      der: _Ojo(arco: 4.5, alto: 0, cejaY: 2.5),
      bocaAncho: 20,
      bocaHondo: 13.5,
      bocaAbierta: 1,
      rubor: 1,
      confeti: 1,
      giro: -6,
    ),
    ExpresionTut.pensando => const _Cara(
      izq: _Ojo(cejaY: -4, cejaSube: -2.5, alto: 13),
      der: _Ojo(cejaY: 1, cejaSube: 1.5, alto: 13),
      mirarX: 2.6,
      mirarY: -1.5,
      bocaAncho: 16,
      bocaHondo: 1.5,
      bocaCurva: 0.2,
      bocaX: 4,
      burbuja: 1,
      giro: 3,
    ),
    ExpresionTut.sorprendida => const _Cara(
      izq: _Ojo(cejaY: -6.5, alto: 19, ancho: 6.8),
      der: _Ojo(cejaY: -6.5, alto: 19, ancho: 6.8),
      bocaAncho: 12,
      bocaHondo: 11,
      bocaRedonda: 1,
    ),
    ExpresionTut.animo => const _Cara(
      izq: _Ojo(arco: 4.5, alto: 0, cejaY: 2.5),
      der: _Ojo(alto: 16, cejaY: -2),
      bocaAncho: 21,
      bocaHondo: 13,
      rubor: 0.8,
      destello: 1,
      giro: 4,
    ),
    ExpresionTut.triste => const _Cara(
      izq: _Ojo(cejaY: 1, cejaSube: 4.5, alto: 10),
      der: _Ojo(cejaY: 1, cejaSube: 4.5, alto: 10),
      mirarY: 3,
      bocaAncho: 17,
      bocaHondo: 4,
      bocaCurva: -1,
      lagrima: 1,
    ),
  };

  final _Ojo izq;
  final _Ojo der;
  final double mirarX;
  final double mirarY;
  final double bocaAncho;
  final double bocaHondo;

  /// 1 = u (sonrisa), 0 = recta, -1 = ∩.
  final double bocaCurva;

  /// 0 = la u del monograma; 1 = boca abierta (D) con lengua.
  final double bocaAbierta;

  /// 1 = boca en «o».
  final double bocaRedonda;
  final double bocaX;
  final double rubor;
  final double lagrima;
  final double confeti;
  final double burbuja;
  final double destello;

  /// Inclinación del cuerpo, en grados.
  final double giro;

  bool get alegre => bocaCurva > 0.5 && bocaAncho >= 20;

  static _Cara lerp(_Cara a, _Cara b, double t) {
    double l(double x, double y) => lerpDouble(x, y, t)!;
    return _Cara(
      izq: _Ojo.lerp(a.izq, b.izq, t),
      der: _Ojo.lerp(a.der, b.der, t),
      mirarX: l(a.mirarX, b.mirarX),
      mirarY: l(a.mirarY, b.mirarY),
      bocaAncho: l(a.bocaAncho, b.bocaAncho),
      bocaHondo: l(a.bocaHondo, b.bocaHondo),
      bocaCurva: l(a.bocaCurva, b.bocaCurva),
      bocaAbierta: l(a.bocaAbierta, b.bocaAbierta),
      bocaRedonda: l(a.bocaRedonda, b.bocaRedonda),
      bocaX: l(a.bocaX, b.bocaX),
      rubor: l(a.rubor, b.rubor),
      lagrima: l(a.lagrima, b.lagrima),
      confeti: l(a.confeti, b.confeti),
      burbuja: l(a.burbuja, b.burbuja),
      destello: l(a.destello, b.destello),
      giro: l(a.giro, b.giro),
    );
  }
}

/// Trocito de confeti: posición final, forma, color y giro.
typedef _Confeti = ({double x, double y, int forma, int color, double giro});

const _confetis = <_Confeti>[
  (x: 9, y: 14, forma: 0, color: 0, giro: 20),
  (x: 27, y: 8, forma: 1, color: 1, giro: 0),
  (x: 72, y: 7, forma: 0, color: 2, giro: -30),
  (x: 92, y: 15, forma: 2, color: 0, giro: 10),
  (x: 5, y: 40, forma: 1, color: 2, giro: 0),
  (x: 96, y: 44, forma: 0, color: 1, giro: 50),
  (x: 8, y: 88, forma: 2, color: 1, giro: -15),
  (x: 50, y: 95, forma: 0, color: 0, giro: 75),
  (x: 93, y: 87, forma: 1, color: 0, giro: 0),
];

class _PintorTut extends CustomPainter {
  _PintorTut({
    required this.cara,
    required this.paleta,
    required this.pegatina,
    required this.parpadeo,
    required this.salto,
    required this.mirar,
  });

  final _Cara cara;
  final PaletaIconos paleta;
  final bool pegatina;
  final double parpadeo;
  final _Salto salto;
  final double mirar;

  static const _centro = Offset(50, 53);
  static const _ojoX = 18.8;
  static const _cejaY = 40.0;
  static const _cejaAncho = 16.6;
  static const _bocaY = 56.0;

  /// Centro vertical de la cara en sus coordenadas de dibujo y aumento con el que se pinta sobre el ticket.
  static const _centroCara = 49.5;
  static const _escalaCara = 1.1;
  static const _zona = Rect.fromLTRB(-30, -30, 130, 130);

  /// El cuerpo: ticket amarillo «cortado a mano» con una muesca a cada lado.
  static final _cuerpo = Path.combine(
    PathOperation.difference,
    Recorte.poligono([12.5, 26, 87.5, 25, 88.5, 81, 11.5, 81.8], radio: 10),
    Path()
      ..addOval(Rect.fromCircle(center: const Offset(12, 53.5), radius: 6.5))
      ..addOval(Rect.fromCircle(center: const Offset(88, 53), radius: 6.5)),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final lado = size.shortestSide;
    if (lado <= 0) return;
    var escala = lado / 100;
    canvas
      ..save()
      ..translate((size.width - lado) / 2, (size.height - lado) / 2)
      ..scale(escala);
    if (pegatina) {
      canvas
        ..translate(50, 50)
        ..scale(0.88)
        ..translate(-50, -50);
      escala *= 0.88;
    }
    final pixel = 1 / escala;
    // En pequeño, los trazos de la cara engordan un poco para que se lean.
    final optico = lado < 64 ? 1 + (64 - lado) / 64 * 0.45 : 1.0;
    final contorno = math.max(3.0, 1.2 * pixel);

    // Salto: aplastar y estirar desde la base.
    canvas
      ..translate(50, 82 + salto.altura)
      ..scale(1 + salto.aplastar * 0.6, 1 - salto.aplastar)
      ..translate(-50, -82)
      ..translate(_centro.dx, _centro.dy)
      ..rotate(cara.giro * math.pi / 180)
      ..translate(-_centro.dx, -_centro.dy);

    _pintarConfeti(canvas, contorno);
    _pintarCuerpo(canvas, contorno, pixel);
    _pintarRubor(canvas);
    final tinta = Paint()..color = paleta.tinta;
    // La cara se dibuja algo más grande y centrada en el ticket.
    canvas
      ..save()
      ..translate(_centro.dx, _centro.dy)
      ..scale(_escalaCara)
      ..translate(-_centro.dx, -_centroCara);
    _pintarOjo(canvas, tinta, _centro.dx - _ojoX, cara.izq, izquierdo: true, optico: optico, lado: lado);
    _pintarOjo(canvas, tinta, _centro.dx + _ojoX, cara.der, izquierdo: false, optico: optico, lado: lado);
    _pintarBoca(canvas, tinta, optico);
    _pintarLagrima(canvas, contorno);
    canvas.restore();
    _pintarBurbuja(canvas);
    _pintarDestellos(canvas, contorno);
    canvas.restore();
  }

  void _pintarCuerpo(Canvas canvas, double contorno, double pixel) {
    final desplazamiento = Offset(math.max(2.4, pixel), math.max(3.0, 1.2 * pixel));
    final sombra = Paint()..color = paleta.sombra.withValues(alpha: 1);
    final borde = pegatina ? math.max(6.0, 2.4 * pixel) : 0.0;
    canvas
      ..saveLayer(_zona, Paint()..color = Color.fromRGBO(0, 0, 0, paleta.sombra.a))
      ..translate(desplazamiento.dx, desplazamiento.dy)
      ..drawPath(_cuerpo, sombra)
      ..drawPath(
        _cuerpo,
        sombra
          ..style = PaintingStyle.stroke
          ..strokeWidth = contorno + borde * 2
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();
    if (pegatina) {
      canvas.drawPath(
        _cuerpo,
        Paint()
          ..color = paleta.papel
          ..style = PaintingStyle.stroke
          ..strokeWidth = contorno + borde * 2
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas
      ..drawPath(_cuerpo, Paint()..color = paleta.amarillo)
      ..drawPath(
        _cuerpo,
        Paint()
          ..color = paleta.tinta
          ..style = PaintingStyle.stroke
          ..strokeWidth = contorno
          ..strokeJoin = StrokeJoin.round,
      );
  }

  void _pintarRubor(Canvas canvas) {
    if (cara.rubor <= 0.01) return;
    final pincel = Paint()..color = paleta.rubor.withValues(alpha: 0.75 * _unidad(cara.rubor));
    for (final signo in [-1, 1]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(_centro.dx + signo * 28, 66), width: 11, height: 6.4), pincel);
    }
  }

  void _pintarOjo(
    Canvas canvas,
    Paint tinta,
    double cx,
    _Ojo ojo, {
    required bool izquierdo,
    required double optico,
    required double lado,
  }) {
    final grosor = 5.4 * optico;
    // Barra de la T (párpado y ceja): una tira recortada, curva si el ojo está feliz.
    final y = _cejaY + ojo.cejaY;
    final interior = izquierdo ? cx + _cejaAncho / 2 : cx - _cejaAncho / 2;
    final exterior = izquierdo ? cx - _cejaAncho / 2 : cx + _cejaAncho / 2;
    final barra = Path()
      ..moveTo(exterior, y + ojo.cejaSube / 2 + ojo.arco)
      ..quadraticBezierTo(cx, y - ojo.arco * 1.4, interior, y - ojo.cejaSube / 2 + ojo.arco);
    canvas.drawPath(
      barra,
      Paint()
        ..color = tinta.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor
        ..strokeCap = StrokeCap.butt
        ..strokeJoin = StrokeJoin.round,
    );
    // Palo de la T: el ojo abierto. Un poco más estrecho abajo e inclinado, como en el monograma.
    final alto = ojo.alto * (1 - parpadeo);
    if (alto < 0.6) return;
    final ancho = ojo.ancho * optico;
    final x = cx + cara.mirarX + mirar;
    final arriba = _cejaY + grosor / 2 - 0.8 + cara.mirarY;
    final abajo = arriba + alto;
    final palo = Recorte.poligono([
      x - ancho / 2,
      arriba,
      x + ancho / 2,
      arriba,
      x + ancho * 0.44 - 0.5,
      abajo,
      x - ancho * 0.44 - 0.5,
      abajo,
    ], radio: math.min(1.2, alto / 3));
    canvas.drawPath(palo, tinta);
    // Brillo en los ojos grandes.
    if (lado >= 72 && alto > 7) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + ancho * 0.02, arriba + 2.4, ancho * 0.36, math.min(alto * 0.3, 4.2)),
          const Radius.circular(1),
        ),
        Paint()..color = paleta.papel,
      );
    }
  }

  void _pintarBoca(Canvas canvas, Paint tinta, double optico) {
    final grosor = 6.0 * optico;
    final cx = _centro.dx + cara.bocaX;
    final ancho = cara.bocaAncho;
    final hondo = cara.bocaHondo;
    final abierta = _unidad(cara.bocaAbierta);
    final redonda = _unidad(cara.bocaRedonda);
    final cerrada = 1.0 - math.max(abierta, redonda);
    if (cerrada > 0.01) {
      // La u del monograma: un trazo con los extremos cortados rectos.
      final extremos = _bocaY - hondo / 2 * cara.bocaCurva;
      final izq = cx - ancho / 2 + grosor / 2;
      final der = cx + ancho / 2 - grosor / 2;
      // Honda: brazos rectos como la u del monograma. Poco honda: una curva suave (el trazo grueso no se pliega).
      final u = Path()..moveTo(izq, extremos);
      if (hondo >= 6) {
        final control = extremos + hondo * cara.bocaCurva / 0.75;
        u.cubicTo(izq, control, der, control, der, extremos);
      } else {
        u.quadraticBezierTo(cx, extremos + hondo * cara.bocaCurva * 2, der, extremos);
      }
      canvas.drawPath(
        u,
        Paint()
          ..color = tinta.color.withValues(alpha: cerrada)
          ..style = PaintingStyle.stroke
          ..strokeWidth = grosor
          ..strokeCap = StrokeCap.butt,
      );
    }
    if (abierta > 0.01) {
      final arriba = _bocaY - hondo / 2;
      final boca = Path()
        ..moveTo(cx - ancho / 2, arriba)
        ..lineTo(cx + ancho / 2, arriba)
        ..cubicTo(cx + ancho / 2, arriba + hondo / 0.75, cx - ancho / 2, arriba + hondo / 0.75, cx - ancho / 2, arriba)
        ..close();
      canvas
        ..save()
        ..drawPath(boca, Paint()..color = tinta.color.withValues(alpha: abierta))
        ..clipPath(boca)
        ..drawOval(
          Rect.fromCenter(center: Offset(cx, arriba + hondo * 0.95), width: ancho * 0.62, height: hondo * 0.75),
          Paint()..color = paleta.rubor.withValues(alpha: abierta),
        )
        ..restore();
    }
    if (redonda > 0.01) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, _bocaY), width: ancho * 0.66, height: hondo),
        Paint()..color = tinta.color.withValues(alpha: redonda),
      );
    }
  }

  void _pintarLagrima(Canvas canvas, double contorno) {
    final lagrima = _unidad(cara.lagrima);
    if (lagrima <= 0.01) return;
    final x = _centro.dx - _ojoX - 2;
    final y = 61 + 6 * (1 - lagrima);
    final gota = Path()
      ..moveTo(x, y - 5.5)
      ..cubicTo(x + 4.2, y, x + 3.8, y + 4.5, x, y + 4.5)
      ..cubicTo(x - 3.8, y + 4.5, x - 4.2, y, x, y - 5.5)
      ..close();
    canvas
      ..drawPath(gota, Paint()..color = paleta.azul.withValues(alpha: lagrima))
      ..drawCircle(Offset(x - 1.2, y + 1.2), 1.1, Paint()..color = paleta.papel.withValues(alpha: lagrima));
  }

  void _pintarConfeti(Canvas canvas, double contorno) {
    final c = cara.confeti;
    if (c <= 0.01) return;
    final colores = [paleta.amarillo, paleta.azul, paleta.papel];
    final linea = Paint()
      ..color = paleta.tinta
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.min(contorno, 2.2)
      ..strokeJoin = StrokeJoin.round;
    for (final trozo in _confetis) {
      final posicion = Offset.lerp(_centro, Offset(trozo.x, trozo.y), c)!;
      final forma = switch (trozo.forma) {
        0 => Recorte.caja(-3.4, -1.8, 3.4, 1.8, radio: 0.8),
        1 => Recorte.circulo(0, 0, 2.4),
        _ => Recorte.poligono([0, -3, 3, 2.2, -3, 2.2], radio: 0.6),
      };
      final pieza = Recorte.girar(
        forma,
        trozo.giro + 120 * (1 - c),
        centro: Offset.zero,
      ).shift(posicion).transform(_escalar(_unidad(c), posicion));
      canvas.drawPath(pieza, Paint()..color = colores[trozo.color]);
      if (trozo.color != 1) canvas.drawPath(pieza, linea);
    }
  }

  void _pintarBurbuja(Canvas canvas) {
    final b = _unidad(cara.burbuja);
    if (b <= 0.01) return;
    final pincel = Paint()..color = paleta.azul;
    for (final (x, y, r) in [(84.0, 20.0, 2.4), (90.0, 13.0, 3.3), (96.0, 5.0, 4.2)]) {
      canvas.drawCircle(Offset(x, y), r * b, pincel);
    }
  }

  void _pintarDestellos(Canvas canvas, double contorno) {
    final d = _unidad(cara.destello);
    if (d <= 0.01) return;
    final linea = Paint()
      ..color = paleta.tinta
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.min(contorno, 2.4)
      ..strokeJoin = StrokeJoin.round;
    for (final (x, y, r) in [(91.0, 18.0, 7.5 * d), (81.0, 8.0, 4.2 * d)]) {
      final estrella = Recorte.destello(x, y, r);
      canvas
        ..drawPath(estrella, Paint()..color = paleta.amarillo)
        ..drawPath(estrella, linea);
    }
  }

  static Float64List _escalar(double s, Offset centro) => Float64List.fromList([
    s, 0, 0, 0, //
    0, s, 0, 0, //
    0, 0, 1, 0, //
    centro.dx * (1 - s), centro.dy * (1 - s), 0, 1, //
  ]);

  @override
  bool shouldRepaint(_PintorTut old) => true;
}

/// [valor] limitado a [0, 1] (las curvas con rebote se pasan un poco).
double _unidad(double valor) => valor < 0 ? 0 : (valor > 1 ? 1 : valor);
