import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../tema.dart';
import 'ticket.dart';

/// Fondo de papel recortado para cabeceras: unas pocas formas (círculos, tickets, estrellas, ondas) en capas, con su
/// sombra de papel, que flotan despacio. Si recibe [scroll], además se desplazan a distinta velocidad al hacer scroll
/// (profundidad).
///
/// El movimiento lento dura unos [ciclos] y se para (no gasta batería ni distrae); se pausa cuando la pantalla queda
/// tapada por otra. Con «reducir animaciones», las formas están quietas. Un solo pintor que repinta su capa: el
/// contenido de [child] no se vuelve a pintar.
class FondoPapel extends StatefulWidget {
  const FondoPapel({
    super.key,
    this.child,
    this.color,
    this.colores,
    this.acento,
    this.formas = 6,
    this.semilla = 3,
    this.animado = true,
    this.ciclos = 3,
    this.periodo = const Duration(seconds: 9),
    this.radio = 0,
    this.scroll,
  });

  final Widget? child;

  /// Color de fondo, si este widget pinta también el fondo de la cabecera.
  final Color? color;

  /// Colores de las capas, de la más lejana a la más cercana. Por defecto, los del tema (`context.colores.fondoPapel`)
  /// o, si hay [color], tonos suaves de ese color (el texto de encima mantiene su contraste).
  final List<Color>? colores;

  /// Color de una forma pequeña que destaca (por ejemplo, el amarillo). Va en un borde, lejos del texto.
  final Color? acento;
  final int formas;
  final int semilla;
  final bool animado;
  final int ciclos;
  final Duration periodo;
  final double radio;
  final ScrollController? scroll;

  @override
  State<FondoPapel> createState() => _FondoPapelState();
}

class _FondoPapelState extends State<FondoPapel> with SingleTickerProviderStateMixin {
  late final AnimationController _deriva = AnimationController(vsync: this, duration: widget.periodo);
  int _vueltasHechas = 0;
  bool _visible = true;

  /// Las formas se recalculan solo si cambian la semilla, cuántas son o sus colores: así el pintor no repinta su capa
  /// cada vez que la pantalla se reconstruye.
  List<_Forma> _formas = const [];
  (int, int, List<Color>, Color?)? _claveFormas;

  List<_Forma> _formasPara(List<Color> colores) {
    final clave = _claveFormas;
    if (clave == null ||
        clave.$1 != widget.semilla ||
        clave.$2 != widget.formas ||
        !listEquals(clave.$3, colores) ||
        clave.$4 != widget.acento) {
      _claveFormas = (widget.semilla, widget.formas, colores, widget.acento);
      _formas = _Forma.generar(widget.semilla, widget.formas, colores, widget.acento);
    }
    return _formas;
  }

  @override
  void initState() {
    super.initState();
    _deriva.addStatusListener((estado) {
      if (estado == AnimationStatus.completed) {
        _vueltasHechas++;
        if (_vueltasHechas < widget.ciclos && _debeMoverse) _deriva.forward(from: 0);
      }
    });
  }

  bool get _debeMoverse => widget.animado && _visible && duracion(context, widget.periodo) != Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tapada por otra pantalla (o en plena transición hacia otra): quieta.
    _visible = ModalRoute.isCurrentOf(context) ?? true;
    _actualizar();
  }

  @override
  void didUpdateWidget(FondoPapel anterior) {
    super.didUpdateWidget(anterior);
    _deriva.duration = widget.periodo;
    if (anterior.animado != widget.animado || anterior.ciclos != widget.ciclos) _actualizar();
  }

  void _actualizar() {
    if (_debeMoverse && _vueltasHechas < widget.ciclos) {
      if (!_deriva.isAnimating) _deriva.forward();
    } else {
      _deriva.stop();
    }
  }

  @override
  void dispose() {
    _deriva.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final colores =
        widget.colores ??
        (color == null
            ? context.colores.fondoPapel
            : [
                Color.lerp(color, Colors.black, 0.12)!,
                Color.lerp(color, Colors.white, 0.1)!,
                Color.lerp(color, Colors.white, 0.18)!,
              ]);
    final scroll = widget.scroll;
    Widget fondo = RepaintBoundary(
      child: CustomPaint(
        painter: _PintorPapel(
          deriva: _deriva,
          scroll: scroll,
          formas: _formasPara(colores),
          color: color,
          sombra: context.colores.sombraPapel,
        ),
      ),
    );
    fondo = ExcludeSemantics(child: IgnorePointer(child: fondo));
    final child = widget.child;
    final pila = Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: fondo),
        ?child,
        if (child == null) const SizedBox.expand(),
      ],
    );
    return widget.radio > 0
        ? ClipRRect(borderRadius: BorderRadius.circular(widget.radio), child: pila)
        : ClipRect(child: pila);
  }
}

enum _TipoForma { circulo, ticket, estrella, onda, semicirculo }

class _Forma {
  _Forma({
    required this.tipo,
    required this.posicion,
    required this.tamano,
    required this.giro,
    required this.amplitud,
    required this.fase,
    required this.profundidad,
    required this.color,
  });

  final _TipoForma tipo;

  /// Posición relativa (0–1) dentro del fondo.
  final Offset posicion;

  /// Tamaño relativo al alto del fondo.
  final double tamano;
  final double giro;

  /// Cuánto flota, en píxeles.
  final double amplitud;
  final double fase;

  /// 0 = lejos (se mueve poco con el scroll), 1 = cerca.
  final double profundidad;
  final Color color;

  /// Formas fijas para una semilla: siempre las mismas, repartidas por los bordes (el centro-izquierda es del texto).
  static List<_Forma> generar(int semilla, int cuantas, List<Color> colores, Color? acento) {
    final azar = math.Random(semilla);
    return <_Forma>[
      for (var i = 0; i < cuantas; i++)
        _Forma(
          tipo: _TipoForma.values[(i + semilla) % _TipoForma.values.length],
          posicion: Offset(
            i.isEven ? 0.62 + azar.nextDouble() * 0.45 : -0.08 + azar.nextDouble() * 0.3,
            -0.1 + azar.nextDouble() * 1.2,
          ),
          tamano: 0.28 + azar.nextDouble() * 0.42,
          giro: (azar.nextDouble() - 0.5) * 0.9,
          amplitud: 5 + azar.nextDouble() * 9,
          fase: azar.nextDouble() * math.pi * 2,
          profundidad: i / math.max(1, cuantas - 1),
          color: colores.isEmpty ? Colors.white24 : colores[i % colores.length],
        ),
      if (acento != null)
        _Forma(
          tipo: _TipoForma.estrella,
          posicion: Offset(0.9, 0.18 + azar.nextDouble() * 0.2),
          tamano: 0.16,
          giro: 0.2,
          amplitud: 6,
          fase: azar.nextDouble() * math.pi * 2,
          profundidad: 1,
          color: acento,
        ),
    ];
  }
}

class _PintorPapel extends CustomPainter {
  _PintorPapel({
    required this.deriva,
    required this.scroll,
    required this.formas,
    required this.color,
    required this.sombra,
  }) : super(repaint: Listenable.merge([deriva, ?scroll]));

  final Animation<double> deriva;
  final ScrollController? scroll;
  final List<_Forma> formas;
  final Color? color;
  final Color sombra;

  static final _contornoTicket = const TicketBorder(
    radio: 0.12,
    radioMuesca: 0.12,
    perforado: false,
  ).getOuterPath(Rect.fromCenter(center: Offset.zero, width: 1.6, height: 1));

  static final _estrella = () {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? 0.5 : 0.22;
      final a = -math.pi / 2 + i * math.pi / 5;
      final punto = Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(punto.dx, punto.dy) : path.lineTo(punto.dx, punto.dy);
    }
    return path..close();
  }();

  static final _onda = () {
    final path = Path()..moveTo(-0.8, 0);
    for (var i = 0; i < 4; i++) {
      final x = -0.8 + i * 0.4;
      path.quadraticBezierTo(x + 0.1, i.isEven ? -0.22 : 0.22, x + 0.2, 0);
      path.quadraticBezierTo(x + 0.3, i.isEven ? 0.22 : -0.22, x + 0.4, 0);
    }
    return path;
  }();

  static final _circulo = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 0.5));

  static final _semicirculo = Path()
    ..addArc(Rect.fromCircle(center: Offset.zero, radius: 0.5), math.pi, math.pi)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final color = this.color;
    if (color != null) canvas.drawRect(Offset.zero & size, Paint()..color = color);
    final angulo = deriva.value * math.pi * 2;
    final desplazado = scroll != null && scroll!.hasClients ? scroll!.offset : 0.0;
    final pincel = Paint();
    final pincelSombra = Paint()..color = sombra;
    final trazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final forma in formas) {
      final lado = forma.tamano * size.height;
      final centro = Offset(
        forma.posicion.dx * size.width + math.sin(angulo + forma.fase) * forma.amplitud,
        forma.posicion.dy * size.height +
            math.cos(angulo + forma.fase) * forma.amplitud * 0.6 -
            desplazado * (0.15 + 0.35 * forma.profundidad),
      );
      final giro = forma.giro + math.sin(angulo + forma.fase) * 0.06;
      void dibujar(Offset en, Paint p) {
        canvas
          ..save()
          ..translate(en.dx, en.dy)
          ..rotate(giro)
          ..scale(lado);
        if (forma.tipo == _TipoForma.onda) {
          canvas.drawPath(
            _onda,
            trazo
              ..color = p.color
              ..strokeWidth = 0.16,
          );
        } else {
          canvas.drawPath(switch (forma.tipo) {
            _TipoForma.circulo => _circulo,
            _TipoForma.ticket => _contornoTicket,
            _TipoForma.estrella => _estrella,
            _TipoForma.semicirculo => _semicirculo,
            _TipoForma.onda => _onda,
          }, p);
        }
        canvas.restore();
      }

      // Sombra nítida y corta, como la de un papel pegado encima de otro.
      dibujar(centro.translate(0, 2.5 + 2 * forma.profundidad), pincelSombra);
      dibujar(centro, pincel..color = forma.color);
    }
  }

  @override
  bool shouldRepaint(_PintorPapel anterior) =>
      anterior.formas != formas || anterior.color != color || anterior.sombra != sombra || anterior.scroll != scroll;
}
