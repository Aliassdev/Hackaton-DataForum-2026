import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../tema.dart';
import '../../../widgets/movimiento/hapticos.dart';
import '../modelos.dart';
import 'estilo.dart';

// Cartas de derecho: la cara (desbloqueada), la bloqueada de la colección, el dorso y la animación de cuando se
// gana una (sube, se da la vuelta y suelta unas chispas, una sola vez).

/// Cara de una carta. [indice] elige su degradado; [grande] enseña también el texto.
class CartaDerecho extends StatelessWidget {
  const CartaDerecho({super.key, required this.carta, required this.indice, this.grande = false});

  final Carta carta;
  final int indice;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = degradadoCarta(context, indice);
    final tinta = tintaSobre(context, colores);
    final icono = iconoCarta(carta);
    final forma = BorderRadius.circular(Radios.l);
    return Semantics(
      container: true,
      label: 'Carta de derecho: ${carta.titulo}.${grande ? ' ${carta.texto}' : ''} Fuente: ${carta.fuente}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: degradadoDiagonal(colores),
          borderRadius: forma,
          boxShadow: sombrasPapel(context),
        ),
        child: ClipRRect(
          borderRadius: forma,
          child: Stack(
            children: [
              Positioned(
                right: -Espacio.l,
                bottom: -Espacio.l,
                child: Icon(icono, size: grande ? 168 : 96, color: tinta.withValues(alpha: 0.12)),
              ),
              // Brillo en diagonal, como el de una carta de colección.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.16),
                        Colors.white.withValues(alpha: 0),
                      ],
                      stops: const [0.25, 0.45, 0.65],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(grande ? Espacio.l : Espacio.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _IconoRedondo(
                          icono: icono,
                          tinta: tinta,
                          tamano: grande ? Espacio.xxl + Espacio.s : Espacio.xxl,
                        ),
                        if (grande) ...[
                          const SizedBox(width: Espacio.s + Espacio.xs),
                          Expanded(
                            child: Text(
                              'Carta de derecho',
                              style: tema.textTheme.labelLarge?.copyWith(
                                color: tinta.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: grande ? Espacio.m : Espacio.s + Espacio.xs),
                    Text(
                      carta.titulo,
                      style: (grande ? tema.textTheme.headlineSmall : tema.textTheme.titleMedium)?.copyWith(
                        color: tinta,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    if (grande) ...[
                      const SizedBox(height: Espacio.s + Espacio.xs),
                      Text(carta.texto, style: tema.textTheme.bodyLarge?.copyWith(color: tinta, height: 1.4)),
                    ],
                    SizedBox(height: grande ? Espacio.l : Espacio.m),
                    Row(
                      children: [
                        Icon(Icons.gavel_rounded, size: Espacio.m, color: tinta.withValues(alpha: 0.9)),
                        const SizedBox(width: Espacio.xs + 2),
                        Flexible(
                          child: Text(
                            carta.fuente,
                            style: tema.textTheme.labelMedium?.copyWith(
                              color: tinta.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carta que aún no se tiene: gris, con un candado y una pista de dónde se gana.
class CartaBloqueada extends StatelessWidget {
  const CartaBloqueada({super.key, this.pista});

  /// P. ej. «Caso de Lucía».
  final String? pista;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final pista = this.pista;
    return Semantics(
      container: true,
      label: 'Carta bloqueada.${pista == null ? '' : ' $pista.'}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: esquema.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Radios.l),
          border: Border.all(color: esquema.outlineVariant, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Espacio.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: Espacio.xxl,
                height: Espacio.xxl,
                decoration: BoxDecoration(shape: BoxShape.circle, color: esquema.surfaceContainerLow),
                child: Icon(Icons.lock_rounded, color: esquema.onSurfaceVariant),
              ),
              const SizedBox(height: Espacio.s + Espacio.xs),
              Text(
                'Por descubrir',
                style: tema.textTheme.titleMedium?.copyWith(
                  color: esquema.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (pista != null) ...[
                const SizedBox(height: Espacio.xs),
                Text(pista, style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dorso de una carta: el degradado del juego con un dibujo de estrellas y una interrogación.
class DorsoCarta extends StatelessWidget {
  const DorsoCarta({super.key});

  @override
  Widget build(BuildContext context) {
    final colores = context.colores.juego;
    final tinta = tintaSobre(context, colores);
    final forma = BorderRadius.circular(Radios.l);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: degradadoDiagonal(colores),
        borderRadius: forma,
        border: Border.all(color: tinta.withValues(alpha: 0.35), width: 3),
      ),
      child: ClipRRect(
        borderRadius: forma,
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (var fila = 0; fila < 6; fila++)
              for (var columna = 0; columna < 4; columna++)
                Align(
                  alignment: Alignment(-0.9 + columna * 0.6 + (fila.isOdd ? 0.3 : 0), -0.92 + fila * 0.37),
                  child: Icon(Icons.star_rounded, size: Espacio.m, color: tinta.withValues(alpha: 0.12)),
                ),
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tinta.withValues(alpha: 0.16),
                  border: Border.all(color: tinta.withValues(alpha: 0.5), width: 2),
                ),
                child: Icon(Icons.question_mark_rounded, size: 52, color: tinta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconoRedondo extends StatelessWidget {
  const _IconoRedondo({required this.icono, required this.tinta, required this.tamano});

  final IconData icono;
  final Color tinta;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tinta.withValues(alpha: 0.18),
        border: Border.all(color: tinta.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Icon(icono, color: tinta, size: tamano * 0.52),
    );
  }
}

/// Coloca [hijos] en filas de [columnas], todas las de una fila con la misma altura (crece con la letra).
class RejillaCartas extends StatelessWidget {
  const RejillaCartas({super.key, required this.hijos, this.columnas = 2});

  final List<Widget> hijos;
  final int columnas;

  @override
  Widget build(BuildContext context) {
    final filas = <Widget>[];
    for (var i = 0; i < hijos.length; i += columnas) {
      if (filas.isNotEmpty) filas.add(const SizedBox(height: Espacio.m));
      filas.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < columnas; j++) ...[
                if (j > 0) const SizedBox(width: Espacio.m),
                Expanded(child: i + j < hijos.length ? hijos[i + j] : const SizedBox.shrink()),
              ],
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: filas);
  }
}

/// Hoja con una carta de la colección en grande y de dónde sale.
Future<void> mostrarDetalleCarta(BuildContext context, {required Carta carta, required int indice}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Espacio.l, 0, Espacio.l, Espacio.l),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CartaDerecho(carta: carta, indice: indice, grande: true),
              const SizedBox(height: Espacio.m),
              Align(
                alignment: Alignment.centerLeft,
                child: FuenteLegal(fuente: carta.fuente),
              ),
              const SizedBox(height: Espacio.m),
              FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Enseña una carta recién ganada: entra, se da la vuelta y suelta unas chispas. Con «reducir animaciones»
/// aparece ya de cara. [xp] son los puntos que ha sumado (0 para no enseñarlos).
Future<void> mostrarCartaNueva(BuildContext context, {required Carta carta, required int indice, int xp = 0}) {
  final esquema = Theme.of(context).colorScheme;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: esquema.scrim.withValues(alpha: 0.78),
    transitionDuration: duracion(context, Duracion.media),
    pageBuilder: (context, _, _) => RevelarCarta(carta: carta, indice: indice, xp: xp),
    transitionBuilder: (context, animacion, _, child) => FadeTransition(opacity: animacion, child: child),
  );
}

class RevelarCarta extends StatefulWidget {
  const RevelarCarta({super.key, required this.carta, required this.indice, this.xp = 0});

  final Carta carta;
  final int indice;
  final int xp;

  @override
  State<RevelarCarta> createState() => _RevelarCartaState();
}

class _RevelarCartaState extends State<RevelarCarta> with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 1500);

  late final AnimationController _animacion = AnimationController(vsync: this)..addListener(_alAvanzar);
  var _preparada = false;
  var _vibro = false;

  late final Animation<double> _entrada = _animacion.drive(
    CurveTween(curve: const Interval(0, 0.34, curve: Curves.easeOutBack)),
  );
  late final Animation<double> _giro = _animacion.drive(
    CurveTween(curve: const Interval(0.3, 0.68, curve: Curves.easeInOutCubic)),
  );
  late final Animation<double> _destello = _animacion.drive(
    CurveTween(curve: const Interval(0.5, 1, curve: Curves.easeOutCubic)),
  );
  late final Animation<double> _textos = _animacion.drive(
    CurveTween(curve: const Interval(0.62, 1, curve: Curves.easeOut)),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preparada) return;
    _preparada = true;
    final total = duracion(context, _total);
    if (total == Duration.zero) {
      _vibro = true;
      Hapticos.acierto();
      _animacion.value = 1;
    } else {
      _animacion
        ..duration = total
        ..forward();
    }
  }

  /// La vibración llega justo cuando la carta enseña su cara.
  void _alAvanzar() {
    if (!_vibro && _animacion.value >= 0.5) {
      _vibro = true;
      Hapticos.acierto();
    }
  }

  @override
  void dispose() {
    _animacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = degradadoCarta(context, widget.indice);
    final carta = CartaDerecho(carta: widget.carta, indice: widget.indice, grande: true);
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Espacio.l),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _textos,
                    child: Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(
                        '¡Carta nueva!',
                        textAlign: TextAlign.center,
                        style: tema.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Espacio.l),
                  AnimatedBuilder(
                    animation: _animacion,
                    builder: (context, _) {
                      final angulo = _giro.value * math.pi;
                      final deCara = angulo >= math.pi / 2;
                      final escala = 0.55 + 0.45 * _entrada.value;
                      return Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: OverflowBox(
                                maxWidth: 420,
                                maxHeight: 520,
                                child: CustomPaint(
                                  size: const Size(420, 520),
                                  painter: _Destello(progreso: _destello.value, colores: [Colors.white, ...colores]),
                                ),
                              ),
                            ),
                          ),
                          Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0012)
                              ..rotateY(angulo)
                              ..scaleByDouble(escala, escala, 1, 1),
                            child: Stack(
                              children: [
                                // La cara marca el tamaño; el dorso ocupa lo mismo para que el giro no salte.
                                Visibility(
                                  visible: deCara,
                                  maintainSize: true,
                                  maintainAnimation: true,
                                  maintainState: true,
                                  child: Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.rotationY(math.pi),
                                    child: carta,
                                  ),
                                ),
                                if (!deCara) const Positioned.fill(child: DorsoCarta()),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: Espacio.l),
                  FadeTransition(
                    opacity: _textos,
                    child: Column(
                      children: [
                        if (widget.xp > 0) ...[_PuntosGanados(xp: widget.xp), const SizedBox(height: Espacio.m)],
                        FilledButton.icon(
                          onPressed: () {
                            Hapticos.toque();
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.style_rounded),
                          label: const Text('¡A mi colección!'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PuntosGanados extends StatelessWidget {
  const _PuntosGanados({required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(color: esquema.surface, shape: const StadiumBorder()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Espacio.m, vertical: Espacio.s),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, color: esquema.primary),
            const SizedBox(width: Espacio.xs),
            Text(
              '+$xp puntos',
              style: tema.textTheme.titleMedium?.copyWith(color: esquema.onSurface, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resplandor y chispas que salen de detrás de la carta, una sola vez.
class _Destello extends CustomPainter {
  _Destello({required this.progreso, required this.colores});

  final double progreso;
  final List<Color> colores;

  static const _chispas = 18;

  @override
  void paint(Canvas canvas, Size size) {
    if (progreso <= 0) return;
    final centro = size.center(Offset.zero);
    final resplandor = Paint()
      ..shader = RadialGradient(
        colors: [
          colores.last.withValues(alpha: 0.55 * (1 - progreso * 0.5)),
          colores.last.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: centro, radius: 120 + 110 * progreso));
    canvas.drawCircle(centro, 120 + 110 * progreso, resplandor);
    for (var i = 0; i < _chispas; i++) {
      final angulo = 2 * math.pi * i / _chispas + (i.isEven ? 0.12 : -0.08);
      final distancia = (110 + (i % 3) * 22) + 120 * progreso;
      final punto = centro + Offset(math.cos(angulo), math.sin(angulo)) * distancia;
      final pintura = Paint()..color = colores[i % colores.length].withValues(alpha: (1 - progreso).clamp(0, 1));
      canvas.drawCircle(punto, 2 + 4 * (1 - progreso), pintura);
    }
  }

  @override
  bool shouldRepaint(_Destello antiguo) => antiguo.progreso != progreso || antiguo.colores != colores;
}
