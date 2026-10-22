import 'package:flutter/services.dart';

/// Vibraciones de TuTurno, con el nombre de lo que significan. En web y en móviles sin vibración no hacen nada.
///
/// Pregunta y Ayuda no se gamifican: allí, como mucho, [toque] en los botones.
abstract final class Hapticos {
  /// Elegir algo: una opción, una pestaña, una etiqueta.
  static Future<void> seleccion() => HapticFeedback.selectionClick();

  /// Pulsar un botón o un ticket.
  static Future<void> toque() => HapticFeedback.lightImpact();

  /// Algo encaja: una pegatina que aparece, una respuesta correcta.
  static Future<void> acierto() => HapticFeedback.mediumImpact();

  /// Un sello oficial que cae sobre el papel: el golpe más fuerte, solo para logros.
  static Future<void> sello() => HapticFeedback.heavyImpact();
}
