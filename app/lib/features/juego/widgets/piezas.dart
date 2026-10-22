import 'package:flutter/material.dart';

import '../../../tema.dart';
import 'estilo.dart';

/// Puntos de progreso: los hechos en color, el actual alargado y los que faltan en gris. Si hay demasiadas
/// escenas para que quepan, una barra.
class ProgresoEscenas extends StatelessWidget {
  const ProgresoEscenas({super.key, required this.actual, required this.total});

  /// Empieza en 1.
  final int actual;
  final int total;

  static const _punto = 8.0;
  static const _actual = 24.0;
  static const _separacion = 6.0;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final total = this.total < actual ? actual : this.total;
    return Semantics(
      label: 'Escena $actual de $total',
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, medidas) {
                final necesario = (total - 1) * (_punto + _separacion) + _actual;
                if (necesario > medidas.maxWidth) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(_punto),
                    child: LinearProgressIndicator(
                      value: actual / total,
                      minHeight: _punto,
                      color: esquema.primary,
                      backgroundColor: esquema.outlineVariant,
                    ),
                  );
                }
                return Row(
                  children: [
                    for (var i = 1; i <= total; i++) ...[
                      if (i > 1) const SizedBox(width: _separacion),
                      AnimatedContainer(
                        duration: duracion(context, Duracion.media),
                        curve: Curves.easeOutCubic,
                        width: i == actual ? _actual : _punto,
                        height: _punto,
                        decoration: ShapeDecoration(
                          shape: const StadiumBorder(),
                          color: i <= actual ? esquema.primary : esquema.outlineVariant,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: Espacio.s + Espacio.xs),
          Text(
            '$actual/$total',
            style: tema.textTheme.labelLarge?.copyWith(color: esquema.onSurfaceVariant, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Círculo con la inicial de la protagonista, con el degradado del juego.
class AvatarProtagonista extends StatelessWidget {
  const AvatarProtagonista({super.key, required this.nombre, this.tamano = 56});

  final String nombre;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores.juego;
    final esquema = Theme.of(context).colorScheme;
    final inicial = nombre.trim().isEmpty ? '?' : nombre.trim().characters.first.toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: degradadoDiagonal(colores),
          border: Border.all(color: esquema.surface, width: 3),
        ),
        alignment: Alignment.center,
        child: Text(
          inicial,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: tintaSobre(context, colores), fontWeight: FontWeight.w700, height: 1),
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }
}

/// Etiqueta pequeña con fondo suave: «Caso 1», «Víctima», «Borrador»…
class EtiquetaSuave extends StatelessWidget {
  const EtiquetaSuave({super.key, required this.texto, this.icono, this.color});

  final String texto;
  final IconData? icono;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = this.color ?? tema.colorScheme.primary;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: tinte(context, color),
        shape: StadiumBorder(side: BorderSide(color: bordeTinte(color))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Espacio.s + 2, vertical: Espacio.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[Icon(icono, size: Espacio.m, color: color), const SizedBox(width: Espacio.xs)],
            Flexible(
              child: Text(
                texto,
                style: tema.textTheme.labelLarge?.copyWith(
                  color: tema.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
