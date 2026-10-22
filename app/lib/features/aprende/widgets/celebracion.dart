import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../tema.dart';
import '../../../widgets/movimiento/confeti_papel.dart';
import '../bkt.dart';
import '../textos.dart';
import 'comunes.dart';

/// Un concepto que ha subido en la sesión.
typedef Mejora = ({String nombre, double antes, double despues});

/// Pantalla final de una lección o una práctica: medalla, confeti, XP ganados, racha, aciertos y los conceptos
/// que han mejorado (con su barra subiendo).
///
/// Sus botones no responden durante un momento al aparecer: así el segundo toque de un doble toque en «Terminar» no
/// pulsa sin querer «Siguiente», que sale justo debajo del dedo.
class Celebracion extends StatefulWidget {
  const Celebracion({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.xp,
    required this.racha,
    required this.rachaSube,
    required this.aciertos,
    required this.respondidas,
    required this.mejoras,
    required this.botones,
  });

  final String titulo;
  final String subtitulo;
  final int xp;
  final int racha;

  /// La racha ha subido hoy con esta lección.
  final bool rachaSube;
  final int aciertos;
  final int respondidas;
  final List<Mejora> mejoras;
  final List<Widget> botones;

  /// Lo que tardan los botones en responder al aparecer.
  static const esperaBotones = Duration(milliseconds: 450);

  @override
  State<Celebracion> createState() => _CelebracionState();
}

class _CelebracionState extends State<Celebracion> {
  var _botonesActivos = false;
  Timer? _espera;

  @override
  void initState() {
    super.initState();
    _espera = Timer(Celebracion.esperaBotones, () {
      if (mounted) setState(() => _botonesActivos = true);
    });
  }

  @override
  void dispose() {
    _espera?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final colores = context.colores;
    final Celebracion(:titulo, :subtitulo, :xp, :racha, :rachaSube, :aciertos, :respondidas, :mejoras, :botones) =
        widget;
    final dominados = [
      for (final m in mejoras)
        if (Bkt.dominado(m.despues) && !Bkt.dominado(m.antes)) m.nombre,
    ];
    var orden = 0;
    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: anchoMaximoAprende),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.l, Espacio.m, Espacio.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: _Medalla()),
                  const SizedBox(height: Espacio.l),
                  Aparece(
                    orden: orden++,
                    child: Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(titulo, textAlign: TextAlign.center, style: tema.textTheme.headlineMedium),
                    ),
                  ),
                  const SizedBox(height: Espacio.xs),
                  Aparece(
                    orden: orden++,
                    child: Text(
                      subtitulo,
                      textAlign: TextAlign.center,
                      style: tema.textTheme.titleMedium?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: Espacio.l),
                  Aparece(
                    orden: orden++,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _Dato(
                            icono: Icons.bolt_rounded,
                            color: esquema.tertiary,
                            valor: ContadorAnimado(valor: xp, desde: 0, prefijo: '+'),
                            etiqueta: 'puntos XP',
                            semantica: 'Has ganado $xp puntos de experiencia',
                          ),
                        ),
                        const SizedBox(width: Espacio.s),
                        Expanded(
                          child: _Dato(
                            icono: Icons.local_fire_department_rounded,
                            color: colores.juego.first,
                            valor: Text('$racha'),
                            etiqueta: racha == 1 ? 'día de racha' : 'días de racha',
                            insignia: rachaSube ? '+1' : null,
                            semantica:
                                'Racha de $racha ${racha == 1 ? 'día' : 'días'}${rachaSube ? '. Ha subido hoy' : ''}',
                          ),
                        ),
                        const SizedBox(width: Espacio.s),
                        Expanded(
                          child: _Dato(
                            icono: Icons.task_alt_rounded,
                            color: colores.exito,
                            valor: Text('$aciertos/$respondidas'),
                            etiqueta: 'aciertos',
                            semantica: '$aciertos aciertos de $respondidas',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Espacio.m),
                  Aparece(
                    orden: orden++,
                    child: Text(
                      animoFinal(aciertos: aciertos, total: respondidas),
                      textAlign: TextAlign.center,
                      style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: Espacio.l),
                  Aparece(
                    orden: orden++,
                    child: _TarjetaMejoras(mejoras: mejoras, dominados: dominados),
                  ),
                  const SizedBox(height: Espacio.l),
                  for (final boton in botones) ...[
                    Aparece(
                      orden: orden++,
                      child: IgnorePointer(ignoring: !_botonesActivos, child: boton),
                    ),
                    const SizedBox(height: Espacio.s + Espacio.xs),
                  ],
                ],
              ),
            ),
          ),
        ),
        // El confeti de papel de la app, con los colores de la marca, una sola vez (no sale con «reducir animaciones»).
        // Salta desde la medalla y cae por toda la pantalla.
        const Positioned.fill(child: ConfetiPapel(origen: Alignment(0, -0.62))),
      ],
    );
  }
}

class _Medalla extends StatelessWidget {
  const _Medalla();

  static const _tamano = 132.0;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores.aprende;
    final lenta = duracion(context, const Duration(milliseconds: 2400));
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: _tamano + Espacio.xxl,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Rayos que giran despacio una sola vez.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: lenta,
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => Transform.rotate(
                angle: t * math.pi / 3,
                child: Opacity(
                  opacity: lenta == Duration.zero ? 1 : t.clamp(0.0, 1.0),
                  child: CustomPaint(
                    size: const Size.square(_tamano + Espacio.xxl),
                    painter: _PintorRayos(color: colores.last.withValues(alpha: 0.22)),
                  ),
                ),
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.3, end: 1),
              duration: duracion(context, const Duration(milliseconds: 1100)),
              curve: Curves.elasticOut,
              builder: (context, escala, hijo) => Transform.scale(scale: escala, child: hijo),
              child: Container(
                width: _tamano,
                height: _tamano,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: colores, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  border: Border.all(color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7), width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: colores.last.withValues(alpha: 0.35),
                      blurRadius: Espacio.l,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(Icons.emoji_events_rounded, size: 72, color: sobreColor(colores.first)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PintorRayos extends CustomPainter {
  _PintorRayos({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final radio = size.shortestSide / 2;
    final pintura = Paint()..color = color;
    const rayos = 12;
    for (var i = 0; i < rayos; i++) {
      final a = i * 2 * math.pi / rayos;
      final ancho = math.pi / rayos * 0.55;
      final camino = Path()
        ..moveTo(centro.dx, centro.dy)
        ..lineTo(centro.dx + radio * math.cos(a - ancho), centro.dy + radio * math.sin(a - ancho))
        ..lineTo(centro.dx + radio * math.cos(a + ancho), centro.dy + radio * math.sin(a + ancho))
        ..close();
      canvas.drawPath(camino, pintura);
    }
  }

  @override
  bool shouldRepaint(_PintorRayos anterior) => anterior.color != color;
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.icono,
    required this.color,
    required this.valor,
    required this.etiqueta,
    required this.semantica,
    this.insignia,
  });

  final IconData icono;
  final Color color;
  final Widget valor;
  final String etiqueta;
  final String semantica;
  final String? insignia;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final insignia = this.insignia;
    return Semantics(
      container: true,
      label: semantica,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Espacio.s, vertical: Espacio.m),
        decoration: BoxDecoration(
          color: fondoAcento(context, color),
          border: Border.all(color: bordeTinte(color)),
          borderRadius: BorderRadius.circular(Radios.m),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icono, color: color, size: Espacio.xl),
                if (insignia != null)
                  Positioned(
                    right: -Espacio.m,
                    top: -Espacio.xs,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: duracion(context, const Duration(milliseconds: 900)),
                      curve: Curves.elasticOut,
                      builder: (context, t, hijo) => Transform.scale(scale: t, child: hijo),
                      child: DecoratedBox(
                        decoration: ShapeDecoration(color: color, shape: const StadiumBorder()),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Espacio.xs + 2, vertical: 1),
                          child: Text(
                            insignia,
                            style: tema.textTheme.labelMedium?.copyWith(
                              color: sobreColor(color),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Espacio.xs),
            DefaultTextStyle.merge(
              style: tema.textTheme.headlineSmall?.copyWith(color: esquema.onSurface),
              child: FittedBox(fit: BoxFit.scaleDown, child: valor),
            ),
            Text(
              etiqueta,
              textAlign: TextAlign.center,
              style: tema.textTheme.labelLarge?.copyWith(color: esquema.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaMejoras extends StatelessWidget {
  const _TarjetaMejoras({required this.mejoras, required this.dominados});

  final List<Mejora> mejoras;
  final List<String> dominados;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Container(
      padding: const EdgeInsets.all(Espacio.l - Espacio.xs),
      decoration: decoracionPapel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(child: Icon(Icons.trending_up_rounded, color: esquema.primary)),
              const SizedBox(width: Espacio.s),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    mejoras.isEmpty ? 'Lo que has practicado' : 'Lo que has mejorado',
                    style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Espacio.m),
          if (mejoras.isEmpty)
            Text(
              'Esta vez no ha subido ningún concepto. No pasa nada: cada intento te ayuda a aprender.',
              style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurface),
            )
          else
            for (final m in mejoras) ...[
              BarraDominio(nombre: m.nombre, p: m.despues, desde: m.antes, compacta: true),
              const SizedBox(height: Espacio.m - 4),
            ],
          for (final nombre in dominados)
            Padding(
              padding: const EdgeInsets.only(top: Espacio.xs),
              child: Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, color: context.colores.exito),
                  const SizedBox(width: Espacio.s),
                  Expanded(
                    child: Text(
                      '¡Ya dominas «$nombre»!',
                      style: tema.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: esquema.onSurface),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
