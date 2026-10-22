import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/salida_rapida.dart';
import '../tema.dart';
import 'iconos/iconos.dart';

/// Lo que lee el lector de pantalla en el botón «Salir rápido».
const etiquetaSalidaRapida = 'Salir rápido. Cierra TuTurno al momento.';

/// Botón «Salir rápido» (plan v2, producto §5.3): quita TuTurno de la pantalla en un toque ([salirRapido]).
///
/// Es neutro: azul noche con letra de papel (al revés en el tema oscuro), nunca rojo, para no confundirlo con el 112
/// ni con Ayuda. No vibra ni se anima: que no se note desde fuera. Lleva un borde del color de la letra que lo despega
/// de cualquier fondo, también de la tarjeta roja de crisis de Pregunta.
///
/// [compacto]: más pequeño, para dentro de otras tarjetas. Visible de 40 de alto; la zona táctil llega a 48
/// (MaterialTapTargetSize.padded del tema).
class SalidaRapidaButton extends ConsumerWidget {
  const SalidaRapidaButton({super.key, this.compacto = false});

  final bool compacto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final fondo = tema.colorScheme.inverseSurface;
    final tinta = tema.colorScheme.onInverseSurface;
    final texto = compacto ? tema.textTheme.labelLarge : tema.textTheme.titleMedium;
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: fondo,
        foregroundColor: tinta,
        overlayColor: tinta,
        minimumSize: Size(Espacio.xxl, compacto ? 40 : Espacio.xxl),
        padding: compacto
            ? const EdgeInsetsDirectional.fromSTEB(Espacio.s + 2, Espacio.xs, Espacio.m, Espacio.xs)
            : const EdgeInsetsDirectional.fromSTEB(Espacio.m, Espacio.s, Espacio.l, Espacio.s),
        shape: StadiumBorder(
          side: BorderSide(color: tinta, width: compacto ? 1.5 : 2),
        ),
        iconSize: compacto ? 20 : Espacio.l,
        textStyle: texto?.copyWith(fontWeight: FontWeight.w700),
      ),
      onPressed: () => unawaited(salirRapido(context, ref)),
      icon: const IconoTuTurno(TuIcono.cerrar, estilo: EstiloIcono.mono, decorativo: true),
      label: const Text('Salir rápido', semanticsLabel: etiquetaSalidaRapida),
    );
  }
}
