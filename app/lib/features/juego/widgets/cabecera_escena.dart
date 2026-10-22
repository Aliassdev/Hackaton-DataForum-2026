import 'package:flutter/material.dart';

import '../../../tema.dart';
import '../modelos.dart';
import 'estilo.dart';

// Hueco de la ilustración de cada escena.
//
// Es un marcador de posición sencillo a propósito: el lugar y quién sale, como fichas. El equipo de pixel art está
// dibujando las escenas en lib/pixel/ y las pondrá aquí. [CabeceraEscena] es el ÚNICO widget que hay que cambiar:
// lo usan el reproductor del caso (arriba de cada escena) y la portada de cada caso en la lista (versión compacta).
// Recibe la escena entera (id, lugar y personajes) por si cada escena tiene su propio dibujo.

/// Cabecera visual de una escena: dónde pasa y quién sale.
///
/// Con [compacta], la portada del caso en la lista: más baja, sin fichas y sin semántica propia (la tarjeta del caso
/// ya lo dice todo).
class CabeceraEscena extends StatelessWidget {
  const CabeceraEscena({super.key, required this.escena, this.protagonista = '', this.compacta = false});

  final Escena escena;

  /// Su ficha va destacada.
  final String protagonista;
  final bool compacta;

  /// Alto de la portada del caso.
  static const altoCompacta = 148.0;

  /// Alto mínimo en el reproductor. Crece si las fichas necesitan más sitio (letra grande, muchos personajes).
  static const altoMinimo = 176.0;

  @override
  Widget build(BuildContext context) {
    final lugar = Lugar.desde(escena.lugar);
    final colores = degradadoLugar(context, lugar);
    final tinta = tintaSobre(context, colores);
    final forma = BorderRadius.circular(Radios.l);
    final fondo = Positioned.fill(
      child: _Decorado(icono: iconoLugar(lugar), tinta: tinta, compacta: compacta),
    );
    final panel = DecoratedBox(
      decoration: BoxDecoration(gradient: degradadoDiagonal(colores), borderRadius: compacta ? null : forma),
      child: compacta
          ? Stack(children: [fondo])
          : ClipRRect(
              borderRadius: forma,
              child: Stack(
                children: [
                  fondo,
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: altoMinimo, minWidth: double.infinity),
                    child: Padding(
                      padding: const EdgeInsets.all(Espacio.m),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _PildoraLugar(lugar: lugar),
                          if (escena.personajes.isNotEmpty) ...[
                            const SizedBox(height: Espacio.l),
                            _Aparece(
                              child: Wrap(
                                spacing: Espacio.s,
                                runSpacing: Espacio.s,
                                children: [
                                  for (final p in escena.personajes)
                                    _FichaPersonaje(nombre: p, protagonista: p == protagonista),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
    if (compacta) {
      return ExcludeSemantics(
        child: SizedBox(height: altoCompacta, child: panel),
      );
    }
    final quien = listaNatural(escena.personajes);
    return Semantics(
      container: true,
      label: quien.isEmpty ? lugar.nombre : '${lugar.nombre}. En esta escena: $quien',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: forma, boxShadow: sombrasPapel(context)),
        child: panel,
      ),
    );
  }
}

/// El fondo del marcador: el icono del lugar en grande, translúcido, y dos círculos suaves. Entra una vez, con calma.
class _Decorado extends StatelessWidget {
  const _Decorado({required this.icono, required this.tinta, required this.compacta});

  final IconData icono;
  final Color tinta;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final tamano = compacta ? 112.0 : 148.0;
    return ExcludeSemantics(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: -Espacio.xxl,
            bottom: -Espacio.xxl - Espacio.l,
            child: _Circulo(diametro: 168, color: tinta.withValues(alpha: 0.07)),
          ),
          Positioned(
            right: -Espacio.l,
            top: -Espacio.xl,
            child: _Circulo(diametro: tamano + Espacio.xxl, color: tinta.withValues(alpha: 0.08)),
          ),
          Positioned(
            right: compacta ? Espacio.l : Espacio.m,
            top: compacta ? Espacio.m : Espacio.s,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: duracion(context, Duracion.larga),
              curve: Curves.easeOutBack,
              builder: (context, valor, child) => Opacity(
                opacity: valor.clamp(0.0, 1.0),
                child: Transform.scale(scale: 0.8 + 0.2 * valor, child: child),
              ),
              child: Icon(icono, size: tamano, color: tinta.withValues(alpha: 0.2)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Circulo extends StatelessWidget {
  const _Circulo({required this.diametro, required this.color});

  final double diametro;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diametro,
      height: diametro,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// Las fichas suben un poco al entrar en la escena (una vez).
class _Aparece extends StatelessWidget {
  const _Aparece({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duracion(context, Duracion.larga),
      curve: Curves.easeOutCubic,
      builder: (context, valor, child) => Opacity(
        opacity: valor,
        child: Transform.translate(offset: Offset(0, (1 - valor) * Espacio.m), child: child),
      ),
      child: child,
    );
  }
}

/// «En el colegio», en una pastilla de papel sobre el fondo.
class _PildoraLugar extends StatelessWidget {
  const _PildoraLugar({required this.lugar});

  final Lugar lugar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(color: esquema.surface, shape: const StadiumBorder()),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Espacio.s + Espacio.xs, Espacio.xs + 2, Espacio.m, Espacio.xs + 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconoLugar(lugar), size: Espacio.m + Espacio.xs, color: esquema.primary),
            const SizedBox(width: Espacio.s - 2),
            Flexible(
              child: Text(
                lugar.nombre,
                style: tema.textTheme.labelLarge?.copyWith(color: esquema.onSurface, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ficha de un personaje. La protagonista va en la pegatina amarilla de la marca.
class _FichaPersonaje extends StatelessWidget {
  const _FichaPersonaje({required this.nombre, required this.protagonista});

  final String nombre;
  final bool protagonista;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final juego = context.colores.juego;
    final acento = acentoCalido(context);
    final fondo = protagonista ? acento : esquema.surface;
    final tinta = protagonista ? tintaSobre(context, [acento]) : esquema.onSurface;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: fondo,
        // La protagonista lleva un borde de su tinta: así se distingue también sobre los fondos amarillos.
        shape: StadiumBorder(
          side: BorderSide(color: protagonista ? tinta.withValues(alpha: 0.28) : esquema.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Espacio.xs, Espacio.xs, Espacio.s + Espacio.xs, Espacio.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: protagonista ? degradadoDiagonal(juego) : null,
                color: protagonista ? null : esquema.surfaceContainerHighest,
              ),
              child: Icon(
                iconoPersonaje(nombre, protagonista: protagonista),
                size: Espacio.m + 2,
                color: protagonista ? tintaSobre(context, juego) : esquema.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: Espacio.s - 2),
            Flexible(
              child: Text(
                nombre,
                style: tema.textTheme.labelLarge?.copyWith(color: tinta, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
