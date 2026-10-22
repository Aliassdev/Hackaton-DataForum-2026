import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../../../widgets/movimiento/hapticos.dart';
import '../bkt.dart';
import '../textos.dart';

// Piezas visuales de Aprende. Todo el color sale del tema (context.colores.aprende, colorScheme) y todo el
// movimiento pasa por duracion(): con «reducir animaciones» las cosas aparecen ya en su sitio.

/// Ancho máximo del contenido en tablet o navegador.
const anchoMaximoAprende = 640.0;

/// Color de texto e iconos encima de [fondo]: blanco sobre colores oscuros y casi negro sobre claros.
/// Así el contraste se mantiene aunque cambie la paleta.
Color sobreColor(Color fondo) => ThemeData.estimateBrightnessForColor(fondo) == Brightness.dark
    ? Colors.white
    : Colors.black.withValues(alpha: 0.87);

LinearGradient degradadoAprende(BuildContext context) =>
    LinearGradient(colors: context.colores.aprende, begin: Alignment.topLeft, end: Alignment.bottomRight);

/// Color principal de Aprende (el primero de su degradado).
Color colorAprende(BuildContext context) => context.colores.aprende.first;

/// Fondo suave de un acento (opción elegida, panel de corrección, pastillas…). Es [tinte], salvo con el amarillo en el
/// tema oscuro: mezclado con el azul noche da un gris apagado. Ahí va una superficie del tema, y el acento se queda en
/// el borde y en los iconos.
Color fondoAcento(BuildContext context, Color acento) {
  final esquema = Theme.of(context).colorScheme;
  final amarillo = acento == esquema.primary || acento == esquema.tertiary;
  return esquema.brightness == Brightness.dark && amarillo ? esquema.surfaceContainerHigh : tinte(context, acento);
}

/// Lo que se ve avanzar en una barra de dominio: 0 sin practicar ([Bkt.p0]) y 1 al dominarlo ([Bkt.umbralDominio]).
/// Así un concepto nuevo no sale ya al 20 % y un primer fallo no quita algo que nunca se había ganado.
double avanceDominio(double p) => ((p - Bkt.p0) / (Bkt.umbralDominio - Bkt.p0)).clamp(0.0, 1.0).toDouble();

bool sinMovimiento(BuildContext context) => duracion(context, Duracion.media) == Duration.zero;

/// Tarjeta de papel, como las del tema: blanca sobre el papel cálido en claro y azul algo más claro en oscuro, con
/// borde fino y sombra de papel recortado.
BoxDecoration decoracionPapel(BuildContext context, {double radio = Radios.l}) {
  final esquema = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: esquema.brightness == Brightness.light ? esquema.surfaceContainerLowest : esquema.surfaceContainerLow,
    border: Border.all(color: esquema.outlineVariant),
    borderRadius: BorderRadius.circular(radio),
    boxShadow: sombrasPapel(context),
  );
}

/// La «pegatina» amarilla de la marca para la acción principal encima del azul: fondo y tinta (azul noche).
({Color fondo, Color tinta}) colorPegatina(BuildContext context) {
  final esquema = Theme.of(context).colorScheme;
  return esquema.brightness == Brightness.light
      ? (fondo: esquema.secondaryContainer, tinta: esquema.onSecondaryContainer)
      : (fondo: esquema.primary, tinta: esquema.onPrimary);
}

/// Semilla estable para un texto (igual en web y en Android), para barajar siempre igual un mismo ejercicio.
int semillaDe(String texto) => texto.codeUnits.fold(17, (h, c) => (h * 31 + c) & 0x3fffffff);

/// Las posiciones 0..n-1 barajadas con [semilla]. Con [evitarIdentidad], nunca salen ya en orden.
List<int> barajar(int n, int semilla, {bool evitarIdentidad = false}) {
  final orden = List<int>.generate(n, (i) => i)..shuffle(math.Random(semilla));
  final enOrden = Iterable<int>.generate(n).every((i) => orden[i] == i);
  if (evitarIdentidad && n > 1 && enOrden) orden.add(orden.removeAt(0));
  return orden;
}

/// Aparece con un fundido y un pequeño desplazamiento. [orden] escalona la entrada de una lista.
class Aparece extends StatefulWidget {
  const Aparece({super.key, required this.child, this.orden = 0, this.desplazamiento = Espacio.l, this.escala});

  final Widget child;
  final int orden;
  final double desplazamiento;

  /// Si no es null, además crece desde esta escala (p. ej. 0.8).
  final double? escala;

  @override
  State<Aparece> createState() => _ApareceState();
}

class _ApareceState extends State<Aparece> with SingleTickerProviderStateMixin {
  static const _paso = Duration(milliseconds: 60);
  static const _maximoEscalonado = 8;

  late final AnimationController _control = AnimationController(vsync: this);
  Animation<double>? _curva;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_curva != null) return;
    final base = duracion(context, Duracion.larga);
    if (base == Duration.zero) {
      _control.value = 1;
      _curva = _control;
      return;
    }
    final retraso = _paso * math.min(widget.orden, _maximoEscalonado);
    final total = base + retraso;
    _control.duration = total;
    _curva = CurvedAnimation(
      parent: _control,
      curve: Interval(retraso.inMicroseconds / total.inMicroseconds, 1, curve: Curves.easeOutCubic),
    );
    _control.forward();
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curva = _curva!;
    final escala = widget.escala;
    return FadeTransition(
      opacity: curva,
      child: AnimatedBuilder(
        animation: curva,
        builder: (context, child) {
          final t = curva.value;
          Widget hijo = Transform.translate(offset: Offset(0, (1 - t) * widget.desplazamiento), child: child);
          if (escala != null) hijo = Transform.scale(scale: escala + (1 - escala) * t, child: hijo);
          return hijo;
        },
        child: widget.child,
      ),
    );
  }
}

/// Sacude [child] de lado a lado una vez cada vez que cambia [disparo] (para una respuesta incorrecta).
class Sacudida extends StatefulWidget {
  const Sacudida({super.key, required this.child, required this.disparo});

  final Widget child;
  final int disparo;

  @override
  State<Sacudida> createState() => _SacudidaState();
}

class _SacudidaState extends State<Sacudida> with SingleTickerProviderStateMixin {
  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  @override
  void didUpdateWidget(Sacudida anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.disparo != widget.disparo && !sinMovimiento(context)) _control.forward(from: 0);
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _control,
      builder: (context, child) {
        final t = _control.value;
        final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

/// Número que cuenta hasta [valor] (desde [desde] la primera vez, y desde el anterior cuando cambia).
class ContadorAnimado extends StatelessWidget {
  const ContadorAnimado({super.key, required this.valor, this.desde, this.style, this.prefijo = '', this.sufijo = ''});

  final int valor;
  final int? desde;
  final TextStyle? style;
  final String prefijo;
  final String sufijo;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: (desde ?? valor).toDouble(), end: valor.toDouble()),
      duration: duracion(context, const Duration(milliseconds: 900)),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('$prefijo${v.round()}$sufijo', style: style),
    );
  }
}

/// Barra redondeada con el degradado de Aprende y un brillo arriba. Se anima al cambiar.
class BarraProgreso extends StatelessWidget {
  const BarraProgreso({
    super.key,
    required this.valor,
    required this.etiqueta,
    required this.valorTexto,
    this.alto = Espacio.m,
    this.desde,
    this.colores,
    this.fondo,
  });

  /// Entre 0 y 1.
  final double valor;
  final double? desde;
  final String etiqueta;
  final String valorTexto;
  final double alto;

  /// Por defecto, el degradado de Aprende.
  final List<Color>? colores;
  final Color? fondo;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final colores = this.colores ?? context.colores.aprende;
    final objetivo = valor.clamp(0.0, 1.0).toDouble();
    return Semantics(
      label: etiqueta,
      value: valorTexto,
      excludeSemantics: true,
      child: SizedBox(
        height: alto,
        child: DecoratedBox(
          decoration: ShapeDecoration(color: fondo ?? esquema.surfaceContainerHighest, shape: const StadiumBorder()),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: (desde ?? objetivo).clamp(0.0, 1.0).toDouble(), end: objetivo),
            duration: duracion(context, Duracion.larga),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: v,
              child: v <= 0
                  ? const SizedBox.shrink()
                  : DecoratedBox(
                      decoration: ShapeDecoration(
                        gradient: LinearGradient(colors: colores),
                        shape: const StadiumBorder(),
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(alto / 2, alto * 0.2, alto / 2, 0),
                          child: Container(
                            height: math.max(2, alto * 0.22),
                            decoration: ShapeDecoration(
                              color: Colors.white.withValues(alpha: 0.35),
                              shape: const StadiumBorder(),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila con el nombre de un concepto, cómo va y su barra de dominio (probabilidad BKT).
class BarraDominio extends StatelessWidget {
  const BarraDominio({super.key, required this.nombre, required this.p, this.desde, this.compacta = false});

  final String nombre;
  final double p;

  /// Para animar una mejora (de [desde] a [p]).
  final double? desde;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final dominado = Bkt.dominado(p);
    final avance = avanceDominio(p);
    final desde = this.desde;
    final exito = context.colores.exito;
    return Semantics(
      container: true,
      label: '$nombre: ${nivelDominio(p)}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  nombre,
                  style: (compacta ? tema.textTheme.bodyMedium : tema.textTheme.bodyLarge)?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: esquema.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: Espacio.s),
              if (dominado) ...[
                Icon(Icons.workspace_premium_rounded, size: Espacio.m + Espacio.xs, color: exito),
                const SizedBox(width: Espacio.xs),
              ],
              Text(
                nivelDominio(p),
                style: tema.textTheme.labelLarge?.copyWith(
                  color: dominado ? exito : esquema.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: Espacio.xs + 2),
          BarraProgreso(
            valor: avance,
            desde: desde == null ? null : avanceDominio(desde),
            alto: compacta ? Espacio.s + 2 : Espacio.m - 4,
            etiqueta: nombre,
            valorTexto: nivelDominio(p),
            colores: dominado ? [exito, exito] : null,
          ),
        ],
      ),
    );
  }
}

/// Etiqueta con la fuente legal de un ejercicio. Al tocarla, una hoja explica de qué norma se trata.
class ChipFuente extends StatelessWidget {
  const ChipFuente({super.key, required this.fuente, this.colorTexto});

  final String fuente;
  final Color? colorTexto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final color = colorTexto ?? esquema.onSurface;
    return Semantics(
      button: true,
      label: 'Fuente: $fuente. Toca para ver de dónde sale',
      excludeSemantics: true,
      child: Material(
        color: esquema.surface.withValues(alpha: 0.7),
        shape: StadiumBorder(side: BorderSide(color: esquema.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Hapticos.seleccion();
            mostrarFuenteEjercicio(context, fuente);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Espacio.xxl),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Espacio.m, vertical: Espacio.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // La ley, nunca un mazo (en España no se usan).
                  IconoTuTurno(
                    TuIcono.ley,
                    estilo: EstiloIcono.mono,
                    size: Espacio.m + 2,
                    color: esquema.primary,
                    decorativo: true,
                  ),
                  const SizedBox(width: Espacio.s),
                  Flexible(
                    child: Text(
                      fuente,
                      style: tema.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
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

Future<void> mostrarFuenteEjercicio(BuildContext context, String fuente) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _HojaFuente(fuente: fuente),
);

class _HojaFuente extends StatelessWidget {
  const _HojaFuente({required this.fuente});

  final String fuente;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final colores = context.colores.aprende;
    final normas = normasEn(fuente);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Espacio.l, 0, Espacio.l, Espacio.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: Espacio.xxl,
                  height: Espacio.xxl,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: colores),
                  ),
                  child: IconoTuTurno(
                    TuIcono.ley,
                    estilo: EstiloIcono.mono,
                    color: sobreColor(colores.first),
                    decorativo: true,
                  ),
                ),
              ),
              const SizedBox(width: Espacio.m),
              Expanded(
                child: Text(
                  'De dónde sale',
                  style: tema.textTheme.labelLarge?.copyWith(color: esquema.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: Espacio.m),
          Semantics(header: true, child: Text(fuente, style: tema.textTheme.headlineSmall)),
          const SizedBox(height: Espacio.m),
          for (final (sigla, nombre) in normas)
            Padding(
              padding: const EdgeInsets.only(bottom: Espacio.m),
              child: MergeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.menu_book_rounded, color: esquema.primary),
                    const SizedBox(width: Espacio.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sigla, style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          if (nombre != sigla) Text(nombre, style: tema.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(Espacio.m),
            decoration: BoxDecoration(
              color: fondoAcento(context, esquema.primary),
              borderRadius: BorderRadius.circular(Radios.m),
            ),
            child: Text(
              'Es la ley en la que se apoya lo que acabas de aprender. Puedes enseñársela a una persona adulta '
              'de confianza o a tu abogado o abogada.',
              style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurface),
            ),
          ),
          const SizedBox(height: Espacio.l),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Entendido')),
        ],
      ),
    );
  }
}

/// Pastilla con un icono y un dato (XP, racha…), para ir encima del degradado de Aprende.
class PastillaDato extends StatelessWidget {
  const PastillaDato({
    super.key,
    required this.icono,
    required this.texto,
    required this.semantica,
    required this.colorTexto,
    this.fondo,
    this.colorIcono,
  });

  final IconData icono;
  final Widget texto;
  final String semantica;
  final Color colorTexto;
  final Color? fondo;
  final Color? colorIcono;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantica,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: fondo ?? colorTexto.withValues(alpha: 0.16), shape: const StadiumBorder()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Espacio.s + Espacio.xs, vertical: Espacio.xs + 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: Espacio.m + Espacio.xs, color: colorIcono ?? colorTexto),
              const SizedBox(width: Espacio.xs + 2),
              Flexible(
                child: DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: colorTexto, fontWeight: FontWeight.w700),
                  child: texto,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
