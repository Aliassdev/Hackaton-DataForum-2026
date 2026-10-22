import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../tema.dart';
import 'ticket.dart';

/// Confeti de papel: ticketitos, estrellas y tiras en los colores de la marca, que saltan, dan vueltas como papel y
/// caen. Corto (menos de 2 segundos) y ligero: un solo pintor, sin reconstruir nada.
///
/// Se lanza al aparecer (si [lanzarAlInicio]) y cada vez que cambia [disparo]. Con «reducir animaciones», no se lanza.
/// Para lanzarlo por encima de toda la pantalla, usa [lanzarConfeti].
class ConfetiPapel extends StatefulWidget {
  const ConfetiPapel({
    super.key,
    this.disparo,
    this.lanzarAlInicio = true,
    this.cantidad = 44,
    this.origen = const Alignment(0, -0.1),
    this.colores,
    this.duracion = const Duration(milliseconds: 1700),
    this.semilla = 7,
    this.alTerminar,
  });

  /// Al cambiar, sale otra ráfaga.
  final Object? disparo;
  final bool lanzarAlInicio;
  final int cantidad;

  /// Desde dónde salta (dentro del espacio del widget).
  final Alignment origen;

  /// Por defecto, el confeti del tema (`context.colores.confeti`).
  final List<Color>? colores;
  final Duration duracion;
  final int semilla;
  final VoidCallback? alTerminar;

  @override
  State<ConfetiPapel> createState() => _ConfetiPapelState();
}

class _ConfetiPapelState extends State<ConfetiPapel> with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(vsync: this, duration: widget.duracion)
    ..addStatusListener(_alCambiarEstado);
  List<_Papelito> _papelitos = const [];
  int _rafagas = 0;
  bool _iniciado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    if (widget.lanzarAlInicio) _lanzar();
  }

  @override
  void didUpdateWidget(ConfetiPapel anterior) {
    super.didUpdateWidget(anterior);
    _controlador.duration = widget.duracion;
    if (widget.disparo != anterior.disparo) _lanzar();
  }

  void _lanzar() {
    if (duracion(context, widget.duracion) == Duration.zero) return;
    final azar = math.Random(widget.semilla + _rafagas++);
    _papelitos = List.generate(widget.cantidad, (_) => _Papelito.alAzar(azar));
    _controlador.forward(from: 0);
  }

  void _alCambiarEstado(AnimationStatus estado) {
    if (estado == AnimationStatus.completed) widget.alTerminar?.call();
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _PintorConfeti(
              animacion: _controlador,
              papelitos: _papelitos,
              origen: widget.origen,
              colores: widget.colores ?? context.colores.confeti,
              segundos: widget.duracion.inMilliseconds / 1000,
            ),
          ),
        ),
      ),
    );
  }
}

/// Lanza confeti por encima de toda la pantalla y lo quita al acabar. Con «reducir animaciones», no hace nada.
void lanzarConfeti(
  BuildContext context, {
  Alignment origen = const Alignment(0, -0.2),
  int cantidad = 56,
  List<Color>? colores,
}) {
  if (MediaQuery.disableAnimationsOf(context)) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entrada;
  entrada = OverlayEntry(
    builder: (context) => Positioned.fill(
      child: ConfetiPapel(
        origen: origen,
        cantidad: cantidad,
        colores: colores,
        alTerminar: () {
          if (!entrada.mounted) return;
          entrada
            ..remove()
            ..dispose();
        },
      ),
    ),
  );
  overlay.insert(entrada);
}

enum _Forma { ticket, estrella, tira, punto }

/// Altura de un trozo de papel a los [segundos] de saltar desde [inicio] con velocidad vertical [velocidad] (negativa
/// hacia arriba, en píxeles por segundo). El eje y va hacia abajo: la gravedad lo frena, lo para y lo hace caer, y el
/// aire lo frena en proporción a su velocidad ([rozamiento]). Es la solución exacta de dv/dt = g − k·v:
/// y = y0 + (v0 − g/k)·(1 − e^(−k·t))/k + g·t/k.
@visibleForTesting
double alturaConfeti({
  required double inicio,
  required double velocidad,
  required double gravedad,
  required double segundos,
  double rozamiento = 1.7,
}) {
  final frenado = (1 - math.exp(-rozamiento * segundos)) / rozamiento;
  return inicio + (velocidad - gravedad / rozamiento) * frenado + gravedad * segundos / rozamiento;
}

/// Un trozo de papel. Su posición se calcula a partir del tiempo (sin estado): salto con rozamiento del aire y gravedad.
class _Papelito {
  _Papelito.alAzar(math.Random azar)
    : forma = _Forma.values[azar.nextInt(_Forma.values.length)],
      angulo = -math.pi / 2 + (azar.nextDouble() - 0.5) * 2.1,
      velocidad = 0.55 + 0.6 * azar.nextDouble(),
      giro = (azar.nextDouble() - 0.5) * 14,
      giroInicial = azar.nextDouble() * math.pi * 2,
      volteo = 4 + azar.nextDouble() * 8,
      fase = azar.nextDouble() * math.pi * 2,
      tamano = 0.8 + azar.nextDouble() * 0.7,
      color = azar.nextInt(1 << 16);

  final _Forma forma;
  final double angulo;
  final double velocidad;
  final double giro;
  final double giroInicial;
  final double volteo;
  final double fase;
  final double tamano;

  /// Índice del color (se reduce al número de colores al pintar).
  final int color;
}

class _PintorConfeti extends CustomPainter {
  _PintorConfeti({
    required this.animacion,
    required this.papelitos,
    required this.origen,
    required this.colores,
    required this.segundos,
  }) : super(repaint: animacion);

  final Animation<double> animacion;
  final List<_Papelito> papelitos;
  final Alignment origen;
  final List<Color> colores;

  /// Duración total de la ráfaga.
  final double segundos;

  static const _rozamiento = 1.7;

  static final _ticket = const TicketBorder(
    radio: 1.5,
    radioMuesca: 2,
    ladoTalon: LadoTalon.abajo,
    perforado: false,
  ).getOuterPath(Rect.fromCenter(center: Offset.zero, width: 9, height: 14));

  static final _estrella = () {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? 7.0 : 3.0;
      final a = -math.pi / 2 + i * math.pi / 5;
      final punto = Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(punto.dx, punto.dy) : path.lineTo(punto.dx, punto.dy);
    }
    return path..close();
  }();

  static final _tira = Path()
    ..addRRect(RRect.fromRectXY(Rect.fromCenter(center: Offset.zero, width: 4, height: 12), 1.5, 1.5));

  static final _punto = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 3.2));

  @override
  void paint(Canvas canvas, Size size) {
    final progreso = animacion.value;
    if (!animacion.isAnimating || papelitos.isEmpty || colores.isEmpty || size.isEmpty) return;
    final segundos = progreso * this.segundos;
    final escala = (size.shortestSide / 400).clamp(0.8, 1.6);
    final inicio = origen.alongSize(size);
    final gravedad = 1500.0 * escala;
    final impulso = 1050.0 * escala;
    final frenado = (1 - math.exp(-_rozamiento * segundos)) / _rozamiento;
    final opacidad = progreso < 0.72 ? 1.0 : (1 - (progreso - 0.72) / 0.28).clamp(0.0, 1.0);
    final pincel = Paint();
    for (final p in papelitos) {
      final vx = math.cos(p.angulo) * p.velocidad * impulso;
      final vy = math.sin(p.angulo) * p.velocidad * impulso;
      // Movimiento con rozamiento lineal: solución exacta, así no hace falta guardar nada entre fotogramas.
      final x = inicio.dx + vx * frenado + math.sin(segundos * 5 + p.fase) * 10;
      final y = alturaConfeti(
        inicio: inicio.dy,
        velocidad: vy,
        gravedad: gravedad,
        segundos: segundos,
        rozamiento: _rozamiento,
      );
      if (y > size.height + 20) continue;
      final volteo = math.cos(segundos * p.volteo + p.fase);
      pincel.color = colores[p.color % colores.length].withValues(alpha: opacidad);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(p.giroInicial + p.giro * segundos)
        ..scale(p.tamano * escala, p.tamano * escala * (0.25 + 0.75 * volteo.abs()))
        ..drawPath(switch (p.forma) {
          _Forma.ticket => _ticket,
          _Forma.estrella => _estrella,
          _Forma.tira => _tira,
          _Forma.punto => _punto,
        }, pincel)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_PintorConfeti anterior) =>
      anterior.papelitos != papelitos ||
      anterior.origen != origen ||
      anterior.colores != colores ||
      anterior.segundos != segundos;
}
