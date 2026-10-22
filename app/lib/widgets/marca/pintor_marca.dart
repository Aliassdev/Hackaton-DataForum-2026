import 'package:flutter/material.dart';

import '../../tema.dart';
import 'trazos_marca.dart';

/// Tonos de la marca para el logotipo y el monograma. El amarillo va sobre azul o azul noche; el azul noche, sobre
/// papel o amarillo; el blanco, sobre azul, azul noche o fotos oscuras.
enum TonoMarca {
  amarillo(ColoresMarca.amarillo),
  azulNoche(ColoresMarca.azulNoche),
  blanco(Colors.white),
  azul(ColoresMarca.azul);

  const TonoMarca(this.color);

  final Color color;

  /// El que se lee sobre la superficie del tema: azul noche en claro y amarillo en oscuro.
  static TonoMarca delTema(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? TonoMarca.amarillo : TonoMarca.azulNoche;

  /// El color de fondo que mejor acompaña a este tono (para placas y pegatinas).
  Color get fondo => switch (this) {
    TonoMarca.amarillo || TonoMarca.blanco => ColoresMarca.azul,
    TonoMarca.azulNoche || TonoMarca.azul => ColoresMarca.amarillo,
  };
}

final _caminos = <String, Path>{};

/// El [Path] de un trazo de la marca. Se calcula la primera vez y se guarda.
Path caminoDe(Trazo trazo) => _caminos.putIfAbsent(trazo.datos, () => parsearTrazo(trazo.datos));

final _token = RegExp(r'[MLCZ]|-?\d+(?:\.\d+)?');

/// Convierte los datos de un `path` SVG con M, L, C y Z absolutos (los de [Trazo]) en un [Path].
Path parsearTrazo(String datos) {
  final tokens = [for (final m in _token.allMatches(datos)) m[0]!];
  final camino = Path();
  var i = 0;
  String? orden;
  double numero() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    switch (tokens[i]) {
      case 'Z':
        camino.close();
        i++;
        continue;
      case 'M' || 'L' || 'C':
        orden = tokens[i++];
    }
    switch (orden) {
      case 'M':
        camino.moveTo(numero(), numero());
        orden = 'L';
      case 'L':
        camino.lineTo(numero(), numero());
      case 'C':
        camino.cubicTo(numero(), numero(), numero(), numero(), numero(), numero());
      default:
        throw FormatException('Trazo de la marca no válido', datos, i);
    }
  }
  return camino;
}

/// Cómo se pinta cada pieza de la marca: su desplazamiento (en unidades del dibujo), escala, giro y opacidad,
/// alrededor del centro de su caja. Para animar letra a letra.
@immutable
class PosePieza {
  const PosePieza({this.desplazamiento = Offset.zero, this.escala = 1, this.giro = 0, this.opacidad = 1});

  static const reposo = PosePieza();

  final Offset desplazamiento;
  final double escala;

  /// En radianes.
  final double giro;
  final double opacidad;
}

/// Pinta trazos de la marca ajustados (sin deformar) y centrados en el tamaño del widget. Con [pegatina], cada pieza
/// lleva un borde blanco y una sombra suave, como una pegatina recortada.
class PintorMarca extends CustomPainter {
  PintorMarca({
    required this.trazos,
    required this.lienzo,
    required this.color,
    this.pegatina = false,
    this.colorBorde = Colors.white,
    this.colorSombra = const Color(0x400E1A4F),
    this.poses,
    super.repaint,
  });

  final List<Trazo> trazos;

  /// Tamaño del dibujo en sus unidades (p. ej. [TrazosLogo.ancho] x [TrazosLogo.alto]).
  final Size lienzo;
  final Color color;
  final bool pegatina;
  final Color colorBorde;
  final Color colorSombra;

  /// Pose de cada pieza (misma longitud que [trazos]); se lee al pintar, así puede cambiar con una animación.
  final List<PosePieza> Function()? poses;

  /// Grosor del borde de pegatina, en proporción a la altura del dibujo.
  static const _borde = 0.075;

  @override
  void paint(Canvas canvas, Size size) {
    final escala = (size.width / lienzo.width) < (size.height / lienzo.height)
        ? size.width / lienzo.width
        : size.height / lienzo.height;
    final poses = this.poses?.call();
    canvas
      ..save()
      ..translate((size.width - lienzo.width * escala) / 2, (size.height - lienzo.height * escala) / 2)
      ..scale(escala);
    final grosor = lienzo.height * _borde;
    for (var i = 0; i < trazos.length; i++) {
      final pose = poses == null ? PosePieza.reposo : poses[i];
      if (pose.opacidad <= 0) continue;
      final camino = caminoDe(trazos[i]);
      final centro = trazos[i].caja.center;
      canvas
        ..save()
        ..translate(centro.dx + pose.desplazamiento.dx, centro.dy + pose.desplazamiento.dy)
        ..rotate(pose.giro)
        ..scale(pose.escala)
        ..translate(-centro.dx, -centro.dy);
      // Mientras aparece, la pieza entera (sombra, borde y relleno) se funde de una vez, sin transparentarse entre sí.
      final translucida = pose.opacidad < 1;
      if (translucida) {
        canvas.saveLayer(trazos[i].caja.inflate(grosor * 3), Paint()..color = Color.fromRGBO(0, 0, 0, pose.opacidad));
      }
      if (pegatina) {
        final contorno = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = grosor * 2
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true;
        canvas
          ..save()
          ..translate(0, grosor * 0.6)
          ..drawPath(
            camino,
            contorno
              ..color = colorSombra
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, grosor * 0.8),
          )
          ..restore()
          ..drawPath(
            camino,
            contorno
              ..color = colorBorde
              ..maskFilter = null,
          );
      }
      canvas.drawPath(
        camino,
        Paint()
          ..color = color
          ..isAntiAlias = true,
      );
      if (translucida) canvas.restore();
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PintorMarca anterior) =>
      anterior.color != color ||
      anterior.pegatina != pegatina ||
      anterior.colorBorde != colorBorde ||
      anterior.colorSombra != colorSombra ||
      anterior.lienzo != lienzo ||
      !identical(anterior.trazos, trazos) ||
      anterior.poses != poses;
}
