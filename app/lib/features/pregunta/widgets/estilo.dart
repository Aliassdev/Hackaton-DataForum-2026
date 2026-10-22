import 'package:flutter/material.dart';

import '../../../tema.dart';

/// Fondo suave de la marca para chips, sugerencias, avisos y botones secundarios: azul hielo en claro y un azul de
/// la marca sobre el azul noche en oscuro (el amarillo mezclado con el azul noche se vería verdoso). Encima va texto
/// en [ColorScheme.primary], con contraste AA en claro y en oscuro.
Color tinteMarca(ColorScheme esquema, {double intensidad = 0.1}) {
  final claro = esquema.brightness == Brightness.light;
  final alfa = (intensidad * (claro ? 8 : 3)).clamp(0.0, 1.0);
  return Color.alphaBlend(
    (claro ? ColoresMarca.azulHielo : ColoresMarca.azul).withValues(alpha: alfa),
    esquema.surface,
  );
}
