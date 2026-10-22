import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../tema.dart';
import '../iconos/icono_tuturno.dart';
import '../iconos/pieza.dart';
import '../iconos/tu_icono.dart';

/// Cartel de la puerta de una sala: una placa de papel con borde de tinta de 2, dos tornillos y el texto en
/// mayúsculas con algo de espacio entre letras. Para los tickets de módulo («SALA 1»), las unidades de Aprende
/// («SALA 2 · Si te toca declarar»), Pregunta en el inicio («INFORMACIÓN») y Mi situación («PARTICIPA»).
///
/// Es una placa de verdad: papel con tinta azul noche en los dos temas (15,9:1), así que se lee igual sobre el
/// degradado de un módulo que sobre el fondo. Se lee como texto normal, «SALA 1. Tus derechos» (no es un botón). La
/// letra es la del texto del tema (Nunito; Atkinson con «lectura fácil»), crece con el tamaño de letra del sistema y,
/// si no cabe, pasa a otra línea.
class CartelSala extends StatelessWidget {
  const CartelSala({
    super.key,
    required this.texto,
    this.detalle,
    this.icono,
    this.inclinacion = -0.02,
    this.semanticLabel,
  });

  /// Nombre de la sala: «SALA 1», «INFORMACIÓN». Se pinta en mayúsculas.
  final String texto;

  /// Lo que hay dentro, detrás de un punto medio: «Tus derechos».
  final String? detalle;

  /// Icono a la izquierda del texto, a una tinta.
  final TuIcono? icono;

  /// Giro en radianes: pegado a mano, nunca del todo recto.
  final double inclinacion;

  /// Lo que lee el lector de pantalla. Por defecto, «[texto]. [detalle]».
  final String? semanticLabel;

  /// Papel y tinta de la placa: los mismos en los dos temas.
  static const papel = ColoresMarca.papel;
  static const tinta = ColoresMarca.azulNoche;

  /// Grosor del borde de tinta.
  static const borde = 2.0;

  /// Tamaño de la letra (sin escalar): entre 12 y 13, como un cartel pequeño.
  static const tamanoLetra = 13.0;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.labelLarge ?? const TextStyle();
    final fuerte = base.copyWith(
      color: tinta,
      fontSize: tamanoLetra,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      height: 1.2,
    );
    final detalle = this.detalle;
    final icono = this.icono;
    Widget placa = DecoratedBox(
      decoration: BoxDecoration(
        color: papel,
        borderRadius: BorderRadius.circular(Radios.s / 2),
        border: Border.all(color: tinta, width: borde),
        // Sombra plana de papel, como la de los iconos: nítida y barata de pintar.
        boxShadow: [BoxShadow(color: sombraPapelDe(context), offset: const Offset(1.5, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Espacio.s - 2, vertical: Espacio.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Tornillo(),
            const SizedBox(width: Espacio.s - 2),
            if (icono != null) ...[
              IconoTuTurno(icono, size: tamanoLetra + 3, estilo: EstiloIcono.mono, color: tinta, decorativo: true),
              const SizedBox(width: Espacio.xs + 1),
            ],
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: texto.toUpperCase()),
                    if (detalle != null && detalle.isNotEmpty)
                      TextSpan(
                        text: ' · $detalle',
                        style: fuerte.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2),
                      ),
                  ],
                ),
                style: fuerte,
              ),
            ),
            const SizedBox(width: Espacio.s - 2),
            const _Tornillo(),
          ],
        ),
      ),
    );
    if (inclinacion != 0) placa = Transform.rotate(angle: inclinacion, child: placa);
    return Semantics(
      container: true,
      label: semanticLabel ?? (detalle == null || detalle.isEmpty ? texto : '$texto. $detalle'),
      child: ExcludeSemantics(child: placa),
    );
  }
}

/// Un tornillo de la placa: un punto de tinta con su ranura.
class _Tornillo extends StatelessWidget {
  const _Tornillo();

  static const _lado = 6.0;

  @override
  Widget build(BuildContext context) => const CustomPaint(size: Size.square(_lado), painter: _PintorTornillo());
}

class _PintorTornillo extends CustomPainter {
  const _PintorTornillo();

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final radio = size.shortestSide / 2;
    canvas.drawCircle(centro, radio, Paint()..color = CartelSala.tinta);
    // La ranura, un poco torcida (cada tornillo se apretó a su manera).
    final ranura = Offset(math.cos(-0.6), math.sin(-0.6)) * radio * 0.62;
    canvas.drawLine(
      centro - ranura,
      centro + ranura,
      Paint()
        ..color = CartelSala.papel
        ..strokeWidth = radio * 0.42
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PintorTornillo anterior) => false;
}
