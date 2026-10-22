import 'package:flutter/foundation.dart';

/// Ajustes del dispositivo (sección 6.4): tamaño de texto, lectura, movimiento y voz. Para la demo, también la URL
/// del backend: la de un túnel rápido cambia cada vez que se reinicia, y así no hay que recompilar.
@immutable
class Ajustes {
  const Ajustes({
    this.tamanoTexto = 1.0,
    this.vozActivada = true,
    this.velocidadVoz = 0.5,
    this.apiUrlManual,
    this.lecturaFacil = false,
    this.reducirMovimiento = false,
  });

  /// Multiplica el tamaño de letra del sistema (1.0, 1.15 o 1.3).
  final double tamanoTexto;

  /// Leer las respuestas en voz alta.
  final bool vozActivada;

  /// Velocidad para FlutterTts.setSpeechRate (0.0-1.0).
  final double velocidadVoz;

  /// Si no es nula, sustituye a API_URL.
  final String? apiUrlManual;

  /// «Lectura fácil»: todo el texto en Atkinson Hyperlegible, con algo más de interlineado. También los títulos y
  /// Vive el caso (`temaTuTurno(brillo, lecturaFacil: …)` y `TemaPixel`, en lib/app.dart).
  final bool lecturaFacil;

  /// «Reducir animaciones» desde la propia app. Se suma a la opción del sistema: con cualquiera de las dos,
  /// `MediaQuery.disableAnimationsOf(context)` es true en todas las pantallas (y `duracion()` da cero).
  final bool reducirMovimiento;

  Ajustes copyWith({
    double? tamanoTexto,
    bool? vozActivada,
    double? velocidadVoz,
    String? Function()? apiUrlManual,
    bool? lecturaFacil,
    bool? reducirMovimiento,
  }) => Ajustes(
    tamanoTexto: tamanoTexto ?? this.tamanoTexto,
    vozActivada: vozActivada ?? this.vozActivada,
    velocidadVoz: velocidadVoz ?? this.velocidadVoz,
    apiUrlManual: apiUrlManual != null ? apiUrlManual() : this.apiUrlManual,
    lecturaFacil: lecturaFacil ?? this.lecturaFacil,
    reducirMovimiento: reducirMovimiento ?? this.reducirMovimiento,
  );
}
