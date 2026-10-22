import 'package:flutter/foundation.dart';

/// Ajustes del dispositivo (sección 6.4): tamaño de texto y voz. Para la demo, también la URL del
/// backend: la de un túnel rápido cambia cada vez que se reinicia, y así no hay que recompilar.
@immutable
class Ajustes {
  const Ajustes({this.tamanoTexto = 1.0, this.vozActivada = true, this.velocidadVoz = 0.5, this.apiUrlManual});

  /// Multiplica el tamaño de letra del sistema (1.0, 1.15 o 1.3).
  final double tamanoTexto;

  /// Leer las respuestas en voz alta.
  final bool vozActivada;

  /// Velocidad para FlutterTts.setSpeechRate (0.0-1.0).
  final double velocidadVoz;

  /// Si no es nula, sustituye a API_URL.
  final String? apiUrlManual;

  Ajustes copyWith({double? tamanoTexto, bool? vozActivada, double? velocidadVoz, String? Function()? apiUrlManual}) =>
      Ajustes(
        tamanoTexto: tamanoTexto ?? this.tamanoTexto,
        vozActivada: vozActivada ?? this.vozActivada,
        velocidadVoz: velocidadVoz ?? this.velocidadVoz,
        apiUrlManual: apiUrlManual != null ? apiUrlManual() : this.apiUrlManual,
      );
}
