import 'package:flutter/material.dart';

import '../../tema.dart';
import 'pintor_marca.dart';
import 'trazos_marca.dart';

/// El logotipo TuTurno: las letras recortadas finas que eligió el equipo (opción 4 de
/// assets/marca/fuente/logotipos.svg), en vectorial, nítidas a cualquier tamaño.
///
/// Reglas de uso:
/// - Solo como logotipo, nunca como texto corrido, y con al menos [altoMinimo] de alto (los trazos son finos).
/// - Amarillo sobre azul o azul noche; azul noche sobre papel o amarillo. El amarillo sobre blanco no se lee.
/// - Por defecto toma el tono que se lee sobre la superficie del tema ([TonoMarca.delTema]).
/// - Con [pegatina], las letras llevan borde blanco y sombra, como pegatinas: para fondos de color.
class LogoTuTurno extends StatelessWidget {
  const LogoTuTurno({
    super.key,
    this.alto = 40,
    this.tono,
    this.color,
    this.pegatina = false,
    this.etiqueta = 'TuTurno',
  }) : assert(alto >= altoMinimo, 'El logotipo tiene trazos finos: no lo uses con menos de $altoMinimo de alto.');

  /// Alto mínimo recomendado, en píxeles lógicos.
  static const altoMinimo = 24.0;

  /// Ancho / alto del logotipo.
  static const proporcion = TrazosLogo.ancho / TrazosLogo.alto;

  final double alto;

  /// Tono de la marca. Si no se indica (ni [color]), el del tema.
  final TonoMarca? tono;

  /// Color libre, si ninguno de los tonos sirve. Gana a [tono].
  final Color? color;
  final bool pegatina;

  /// Lo que lee el lector de pantalla. `null` si el logotipo es decorativo (por ejemplo, junto al nombre escrito).
  final String? etiqueta;

  @override
  Widget build(BuildContext context) {
    final dibujo = CustomPaint(
      size: Size(alto * proporcion, alto),
      painter: PintorMarca(
        trazos: TrazosLogo.letras,
        lienzo: const Size(TrazosLogo.ancho, TrazosLogo.alto),
        color: color ?? (tono ?? TonoMarca.delTema(context)).color,
        pegatina: pegatina,
        colorSombra: sombraPapelDe(context),
      ),
    );
    final etiqueta = this.etiqueta;
    return etiqueta == null
        ? ExcludeSemantics(child: dibujo)
        : Semantics(label: etiqueta, image: true, excludeSemantics: true, child: dibujo);
  }
}
