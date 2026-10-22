import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../tema.dart';

/// Colores y contraste del sistema de movimiento. Los colores son los de la marca ([ColoresMarca]); en las pantallas,
/// mejor los del tema (`context.colores`), que ya se adaptan a claro y oscuro.
abstract final class PaletaMovimiento {
  static const amarillo = ColoresMarca.amarillo;
  static const azul = ColoresMarca.azul;
  static const azulNoche = ColoresMarca.azulNoche;
  static const papel = ColoresMarca.papel;
  static const celeste = ColoresMarca.azulCielo;

  /// Contraste WCAG entre dos colores opacos (de 1 a 21).
  static double contraste(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// La tinta más legible sobre [fondo]: [preferida] si llega a [minimo] (AA, 4,5:1) y, si no, azul noche o blanco,
  /// el que más contraste dé.
  static Color tintaSobre(Color fondo, {Color? preferida, double minimo = 4.5}) {
    if (preferida != null && contraste(preferida, fondo) >= minimo) return preferida;
    const blanco = Color(0xFFFFFFFF);
    return contraste(azulNoche, fondo) >= contraste(blanco, fondo) ? azulNoche : blanco;
  }
}
