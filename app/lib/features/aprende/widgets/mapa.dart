import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../tema.dart';
import '../../../widgets/movimiento/hapticos.dart';
import '../bkt.dart';
import '../curso.dart';
import '../modelos.dart';
import '../textos.dart';
import 'comunes.dart';

// Mapa de Aprende: cada unidad es un camino de nodos en zigzag unidos por un trazo. Los nodos tienen relieve
// (se hunden al pulsarlos), la lección que toca lleva un aviso que bota y una lección recién desbloqueada
// da un pequeño salto cuando vuelves al mapa.

/// Posición horizontal de cada nodo (de -1, izquierda, a 1, derecha), en zigzag.
const _zigzag = [0.0, 0.55, 0.0, -0.55];

/// Ancho de la columna de cada nodo (nodo y título debajo).
const _anchoColumna = 172.0;
const _diametro = 76.0;
const _relieve = 6.0;
const _altoTramo = 46.0;

double alineacionNodo(int i) => _zigzag[i % _zigzag.length];

/// Centro horizontal de un nodo con alineación [x] en una fila de ancho [ancho].
double _centroNodo(double x, double ancho) {
  final columna = math.min(_anchoColumna, ancho);
  return (ancho - columna) * (x + 1) / 2 + columna / 2;
}

/// El camino de lecciones de una unidad.
class CaminoUnidad extends StatelessWidget {
  const CaminoUnidad({
    super.key,
    required this.unidad,
    required this.estados,
    required this.numeroEjercicios,
    required this.actual,
    required this.onLeccion,
    this.onLeccionLarga,
    this.claveActual,
    this.textoAviso,
  });

  final Unidad unidad;
  final Map<String, EstadoLeccion> estados;
  final Map<String, int> numeroEjercicios;

  /// Id de la lección que toca ahora (puede no estar en esta unidad).
  final String? actual;
  final void Function(Leccion leccion, EstadoLeccion estado) onLeccion;

  /// Al mantener pulsada una lección (solo en modo DEMO).
  final void Function(Leccion leccion)? onLeccionLarga;

  /// Para desplazar el mapa hasta la lección que toca.
  final GlobalKey? claveActual;

  /// Aviso encima de la lección que toca («¡Empieza aquí!»).
  final String? textoAviso;

  @override
  Widget build(BuildContext context) {
    final lecciones = unidad.lecciones;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, leccion) in lecciones.indexed) ...[
          if (i > 0)
            _Tramo(
              desde: alineacionNodo(i - 1),
              hasta: alineacionNodo(i),
              activo: estados[leccion.id] != EstadoLeccion.bloqueada,
            ),
          Align(
            alignment: Alignment(alineacionNodo(i), 0),
            child: SizedBox(
              key: leccion.id == actual ? claveActual : null,
              width: _anchoColumna,
              child: NodoLeccion(
                leccion: leccion,
                numero: i + 1,
                total: lecciones.length,
                ejercicios: numeroEjercicios[leccion.id] ?? leccion.ejercicios.length,
                estado: estados[leccion.id] ?? EstadoLeccion.bloqueada,
                actual: leccion.id == actual,
                textoAviso: leccion.id == actual ? textoAviso : null,
                onTap: () => onLeccion(leccion, estados[leccion.id] ?? EstadoLeccion.bloqueada),
                onLongPress: onLeccionLarga == null ? null : () => onLeccionLarga!(leccion),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Trazo curvo entre dos nodos: lleno y del color de Aprende si lleva a una lección abierta; a rayas si no.
class _Tramo extends StatelessWidget {
  const _Tramo({required this.desde, required this.hasta, required this.activo});

  final double desde;
  final double hasta;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox(
        height: _altoTramo,
        child: CustomPaint(
          painter: _PintorTramo(
            desde: desde,
            hasta: hasta,
            color: activo ? colorAprende(context) : esquema.outlineVariant,
            discontinuo: !activo,
          ),
        ),
      ),
    );
  }
}

class _PintorTramo extends CustomPainter {
  _PintorTramo({required this.desde, required this.hasta, required this.color, required this.discontinuo});

  final double desde;
  final double hasta;
  final Color color;
  final bool discontinuo;

  @override
  void paint(Canvas canvas, Size size) {
    final x1 = _centroNodo(desde, size.width);
    final x2 = _centroNodo(hasta, size.width);
    final h = size.height;
    final camino = Path()
      ..moveTo(x1, 12)
      ..cubicTo(x1, h * 0.7, x2, h * 0.4, x2, h - 2);
    final pintura = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    if (!discontinuo) {
      canvas.drawPath(camino, pintura);
      return;
    }
    for (final PathMetric tramo in camino.computeMetrics()) {
      const raya = 8.0, hueco = 9.0;
      for (var d = 0.0; d < tramo.length; d += raya + hueco) {
        canvas.drawPath(tramo.extractPath(d, math.min(d + raya, tramo.length)), pintura);
      }
    }
  }

  @override
  bool shouldRepaint(_PintorTramo anterior) =>
      anterior.desde != desde ||
      anterior.hasta != hasta ||
      anterior.color != color ||
      anterior.discontinuo != discontinuo;
}

/// Nodo de una lección: un botón redondo con relieve y el título debajo.
class NodoLeccion extends StatefulWidget {
  const NodoLeccion({
    super.key,
    required this.leccion,
    required this.numero,
    required this.total,
    required this.ejercicios,
    required this.estado,
    required this.actual,
    required this.onTap,
    this.onLongPress,
    this.textoAviso,
  });

  final Leccion leccion;
  final int numero;
  final int total;
  final int ejercicios;
  final EstadoLeccion estado;
  final bool actual;
  final String? textoAviso;
  final VoidCallback onTap;

  /// Solo en modo DEMO (atajo a «Dilo con tus palabras»). No se anuncia al lector de pantalla.
  final VoidCallback? onLongPress;

  @override
  State<NodoLeccion> createState() => _NodoLeccionState();
}

class _NodoLeccionState extends State<NodoLeccion> with TickerProviderStateMixin {
  late final AnimationController _desbloqueo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _halo = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  var _pulsado = false;
  var _haloLanzado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lanzarHalo();
  }

  @override
  void didUpdateWidget(NodoLeccion anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.estado == EstadoLeccion.bloqueada && widget.estado != EstadoLeccion.bloqueada) {
      if (!sinMovimiento(context)) _desbloqueo.forward(from: 0);
      _haloLanzado = false;
    }
    if (widget.actual != anterior.actual) _haloLanzado = false;
    _lanzarHalo();
  }

  /// El halo de la lección que toca late tres veces y para: llama la atención sin distraer.
  void _lanzarHalo() {
    if (!widget.actual || _haloLanzado || sinMovimiento(context)) return;
    _haloLanzado = true;
    _halo.repeat(count: 3);
  }

  @override
  void dispose() {
    _desbloqueo.dispose();
    _halo.dispose();
    super.dispose();
  }

  void _tocar() {
    Hapticos.toque();
    widget.onTap();
  }

  void _mantener() {
    Hapticos.seleccion();
    widget.onLongPress?.call();
  }

  String get _semantica {
    final base = 'Lección ${widget.numero} de ${widget.total}: ${widget.leccion.titulo}';
    return switch (widget.estado) {
      EstadoLeccion.completada => '$base. Completada. Toca para repetirla',
      EstadoLeccion.disponible => '$base. Disponible, ${widget.ejercicios} ejercicios. Toca para empezar',
      EstadoLeccion.bloqueada => '$base. Bloqueada: se abre al completar la anterior',
    };
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final colores = context.colores.aprende;
    final estado = widget.estado;
    final bloqueada = estado == EstadoLeccion.bloqueada;
    final arriba = bloqueada ? esquema.surfaceContainerHighest : null;
    final base = bloqueada ? esquema.outlineVariant : Color.lerp(colores.last, esquema.shadow, 0.35)!;
    final colorIcono = bloqueada ? esquema.onSurfaceVariant : sobreColor(colores.first);
    final icono = switch (estado) {
      EstadoLeccion.completada => Icons.check_rounded,
      EstadoLeccion.disponible => Icons.play_arrow_rounded,
      EstadoLeccion.bloqueada => Icons.lock_rounded,
    };
    final aviso = widget.textoAviso;
    final hundido = _pulsado ? _relieve - 2 : 0.0;

    final boton = SizedBox(
      width: _diametro + Espacio.l,
      height: _diametro + _relieve + Espacio.l,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // Halo de la lección que toca.
          if (widget.actual)
            Positioned(
              top: Espacio.l / 2 - Espacio.s,
              child: AnimatedBuilder(
                animation: _halo,
                builder: (context, _) {
                  final t = _halo.isAnimating ? Curves.easeOut.transform(_halo.value) : 0.0;
                  return Transform.scale(
                    scale: 1 + t * 0.3,
                    child: Container(
                      width: _diametro + Espacio.m,
                      height: _diametro + Espacio.m,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colores.first.withValues(alpha: _halo.isAnimating ? 0.22 * (1 - t) + 0.06 : 0.16),
                      ),
                    ),
                  );
                },
              ),
            ),
          // Base (el «relieve»).
          Positioned(
            top: Espacio.l / 2 + _relieve,
            child: Container(
              width: _diametro,
              height: _diametro,
              decoration: BoxDecoration(shape: BoxShape.circle, color: base),
            ),
          ),
          // Cara del botón.
          AnimatedPositioned(
            duration: duracion(context, const Duration(milliseconds: 90)),
            top: Espacio.l / 2 + hundido,
            child: AnimatedBuilder(
              animation: _desbloqueo,
              builder: (context, hijo) {
                final t = _desbloqueo.value;
                final escala = _desbloqueo.isAnimating ? 1 + 0.22 * math.sin(math.pi * t) * (1 - t * 0.5) : 1.0;
                return Transform.scale(scale: escala, child: hijo);
              },
              child: Container(
                width: _diametro,
                height: _diametro,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: arriba,
                  gradient: bloqueada
                      ? null
                      : LinearGradient(colors: colores, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  border: widget.actual ? Border.all(color: esquema.surface, width: 4) : null,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _tocar,
                    onLongPress: widget.onLongPress == null ? null : _mantener,
                    onHighlightChanged: (valor) => setState(() => _pulsado = valor),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: duracion(context, Duracion.media),
                        transitionBuilder: (hijo, animacion) => RotationTransition(
                          turns: Tween(begin: -0.15, end: 0.0).animate(animacion),
                          child: ScaleTransition(scale: animacion, child: hijo),
                        ),
                        child: Icon(icono, key: ValueKey(icono), size: Espacio.xl + Espacio.s, color: colorIcono),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: _semantica,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (aviso != null) _Aviso(texto: aviso),
          boton,
          const SizedBox(height: Espacio.xs),
          // El título también abre la lección: es más fácil acertar.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _tocar,
            onLongPress: widget.onLongPress == null ? null : _mantener,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.leccion.titulo,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: bloqueada ? esquema.onSurfaceVariant : esquema.onSurface,
                  ),
                ),
                Text(
                  estado == EstadoLeccion.completada
                      ? 'Completada'
                      : 'Lección ${widget.numero} · ${widget.ejercicios} ejercicios',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.labelMedium?.copyWith(color: esquema.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Globo encima de la lección que toca. Bota tres veces y se queda quieto.
class _Aviso extends StatefulWidget {
  const _Aviso({required this.texto});

  final String texto;

  @override
  State<_Aviso> createState() => _AvisoState();
}

class _AvisoState extends State<_Aviso> with SingleTickerProviderStateMixin {
  late final AnimationController _bote = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  var _lanzado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lanzado || sinMovimiento(context)) return;
    _lanzado = true;
    _bote.repeat(reverse: true, count: 6);
  }

  @override
  void dispose() {
    _bote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final globo = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: esquema.surface,
            borderRadius: BorderRadius.circular(Radios.s),
            border: Border.all(color: esquema.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: esquema.shadow.withValues(alpha: 0.12),
                blurRadius: Espacio.s,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Espacio.s + Espacio.xs, vertical: Espacio.xs + 2),
            child: Text(
              widget.texto,
              textAlign: TextAlign.center,
              style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        CustomPaint(
          size: const Size(16, 9),
          painter: _PintorPico(relleno: esquema.surface, borde: esquema.primary),
        ),
      ],
    );
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _bote,
        builder: (context, hijo) =>
            Transform.translate(offset: Offset(0, -Curves.easeInOut.transform(_bote.value) * 6), child: hijo),
        child: globo,
      ),
    );
  }
}

class _PintorPico extends CustomPainter {
  _PintorPico({required this.relleno, required this.borde});

  final Color relleno;
  final Color borde;

  @override
  void paint(Canvas canvas, Size size) {
    final pico = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(pico, Paint()..color = relleno);
    canvas.drawPath(
      pico,
      Paint()
        ..color = borde
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_PintorPico anterior) => anterior.relleno != relleno || anterior.borde != borde;
}

/// Cabecera de una unidad: número, título, lecciones hechas y «Practicar».
class BannerUnidad extends StatelessWidget {
  const BannerUnidad({
    super.key,
    required this.numero,
    required this.unidad,
    required this.completadas,
    required this.abierta,
    required this.onPracticar,
  });

  final int numero;
  final Unidad unidad;
  final int completadas;
  final bool abierta;
  final VoidCallback onPracticar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final colores = context.colores.aprende;
    final total = unidad.lecciones.length;
    final terminada = completadas >= total;
    return Container(
      padding: const EdgeInsets.all(Espacio.l - Espacio.xs),
      decoration: decoracionPapel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: Espacio.xxl,
                  height: Espacio.xxl,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: colores, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  ),
                  child: terminada
                      ? Icon(Icons.emoji_events_rounded, color: sobreColor(colores.first))
                      : Text(
                          '$numero',
                          style: tema.textTheme.titleLarge?.copyWith(
                            color: sobreColor(colores.first),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: Espacio.m - 4),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unidad $numero',
                        style: tema.textTheme.labelLarge?.copyWith(
                          color: esquema.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        unidad.titulo,
                        style: tema.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: esquema.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Espacio.m),
          Row(
            children: [
              Expanded(
                child: BarraProgreso(
                  valor: total == 0 ? 0 : completadas / total,
                  alto: Espacio.s + 2,
                  etiqueta: 'Lecciones completadas de la unidad $numero',
                  valorTexto: '$completadas de $total',
                ),
              ),
              const SizedBox(width: Espacio.s + Espacio.xs),
              ExcludeSemantics(
                child: Text(
                  '$completadas/$total',
                  style: tema.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: esquema.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: Espacio.m - 4),
          if (abierta)
            Align(
              alignment: AlignmentDirectional.centerStart,
              // Secundario: la acción principal (la lección que toca) es la pegatina amarilla de la cabecera.
              child: OutlinedButton.icon(
                onPressed: onPracticar,
                icon: const Icon(Icons.fitness_center_rounded),
                label: Text(terminada ? 'Repasar' : 'Practicar'),
              ),
            )
          else
            Row(
              children: [
                Icon(Icons.lock_rounded, size: Espacio.m + 2, color: esquema.onSurfaceVariant),
                const SizedBox(width: Espacio.s),
                Expanded(
                  child: Text(
                    'Se abre al terminar la unidad anterior.',
                    style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Barras de dominio de los conceptos de una unidad (probabilidad BKT).
class TarjetaDominio extends StatelessWidget {
  const TarjetaDominio({super.key, required this.conceptos, required this.dominio});

  final List<String> conceptos;
  final Map<String, double> dominio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final dominados = conceptos.where((c) => Bkt.dominado(dominioDe(dominio, c))).length;
    return Container(
      padding: const EdgeInsets.all(Espacio.l - Espacio.xs),
      decoration: decoracionPapel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(child: Icon(Icons.insights_rounded, color: esquema.primary)),
              const SizedBox(width: Espacio.s),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Lo que dominas',
                    style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              Text(
                '$dominados de ${conceptos.length}',
                style: tema.textTheme.labelLarge?.copyWith(
                  color: esquema.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: Espacio.m),
          for (final c in conceptos) ...[
            BarraDominio(nombre: nombreConcepto(c), p: dominioDe(dominio, c), compacta: true),
            const SizedBox(height: Espacio.m - 4),
          ],
        ],
      ),
    );
  }
}
