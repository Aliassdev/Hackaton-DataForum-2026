import 'package:flutter/widgets.dart';

import 'estilo_pixel.dart';
import 'pintura_pixel.dart';

/// El marco de la pantalla de juego: un bisel grueso con esquinas escalonadas, remaches amarillos en las esquinas y la
/// escena ([child]) recortada con esquinas de pixel. Con [titulo], una placa amarilla monta sobre el borde de arriba.
///
/// No añade nada al lector de pantalla (salvo el título, como encabezado): lo que importa es la escena.
class MarcoPixel extends StatelessWidget {
  const MarcoPixel({
    super.key,
    required this.child,
    this.titulo,
    this.color = ColoresUiPixel.marino,
    this.luz = ColoresUiPixel.azul,
    this.sombra = ColoresUiPixel.noche,
    this.adornos = true,
  });

  final Widget child;
  final String? titulo;

  /// Color del bisel, con su luz (arriba y a la izquierda) y su sombra (abajo y a la derecha). Por defecto, marino:
  /// se ve sobre el papel y sobre el azul noche del juego.
  final Color color;
  final Color luz;
  final Color sombra;

  /// Remaches en las esquinas.
  final bool adornos;

  /// Grosor del marco, en unidades: contorno (1), bisel (3) y contorno de la pantalla (1).
  static const grosor = 5;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final marco = AjustePixel(
      child: CustomPaint(
        painter: _PintorMarco(u: u, dpr: dpr, color: color, luz: luz, sombra: sombra, adornos: adornos),
        child: Padding(
          padding: EdgeInsets.fromLTRB(grosor * u, grosor * u, grosor * u, (grosor + 1) * u),
          child: ClipPath(
            clipper: RecortePixel(u: u, esquina: 2),
            clipBehavior: Clip.hardEdge,
            child: child,
          ),
        ),
      ),
    );
    final titulo = this.titulo;
    if (titulo == null) return marco;
    final estilo = estiloTextoPixel(context, TipoTextoPixel.etiqueta, color: ColoresUiPixel.noche);
    // La placa se centra en el bisel de arriba; lo que sobresale por encima del marco se reserva.
    final altoPlaca = altoLineaPixel(context, estilo) + 4 * u;
    final sobresale = ((altoPlaca / 2 - grosor * u / 2) / u).ceilToDouble() * u;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(top: sobresale < 0 ? 0 : sobresale),
          child: marco,
        ),
        Positioned(
          top: sobresale < 0 ? -sobresale : 0,
          left: 6 * u,
          right: 6 * u,
          child: Center(
            child: Semantics(
              header: true,
              child: CajaPixel(
                estilo: const EstiloCajaPixel(
                  relleno: ColoresUiPixel.amarillo,
                  contorno: ColoresUiPixel.noche,
                  luz: ColoresUiPixel.amarilloLuz,
                  sombraInterior: ColoresUiPixel.ocre,
                  esquina: 1,
                ),
                // Monta sobre el bisel, que ya la recorta.
                conFilo: false,
                interior: const EdgeInsets.fromLTRB(4, 2, 4, 2),
                child: Text(titulo, style: estilo, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Recorte rectangular con esquinas escalonadas de [esquina] unidades, sin suavizado (con `Clip.hardEdge`).
class RecortePixel extends CustomClipper<Path> {
  const RecortePixel({required this.u, this.esquina = 2});

  final double u;
  final int esquina;

  @override
  Path getClip(Size size) {
    final perfil = perfilEsquina(esquina);
    final camino = Path();
    final filas = perfil.length;
    for (var y = 0; y < filas; y++) {
      final dx = perfil[y] * u;
      camino
        ..addRect(Rect.fromLTRB(dx, y * u, size.width - dx, (y + 1) * u))
        ..addRect(Rect.fromLTRB(dx, size.height - (y + 1) * u, size.width - dx, size.height - y * u));
    }
    return camino..addRect(Rect.fromLTRB(0, filas * u, size.width, size.height - filas * u));
  }

  @override
  bool shouldReclip(RecortePixel oldClipper) => oldClipper.u != u || oldClipper.esquina != esquina;
}

class _PintorMarco extends CustomPainter {
  const _PintorMarco({
    required this.u,
    required this.dpr,
    required this.color,
    required this.luz,
    required this.sombra,
    required this.adornos,
  });

  final double u;
  final double dpr;
  final Color color;
  final Color luz;
  final Color sombra;
  final bool adornos;

  @override
  void paint(Canvas canvas, Size size) {
    final caja = Rect.fromLTWH(0, 0, alPixelFisico(size.width, dpr), alPixelFisico(size.height - u, dpr));
    final exterior = perfilEsquina(4);
    final tinta = pincelPixel(ColoresUiPixel.noche);
    pintarForma(canvas, caja.shift(Offset(0, u)), u, exterior, tinta);
    pintarForma(canvas, caja, u, exterior, tinta);
    // El bisel, con luz arriba y a la izquierda y sombra abajo y a la derecha.
    final bisel = caja.deflate(u);
    final perfilBisel = perfilInterior(exterior);
    pintarForma(canvas, bisel, u, perfilBisel, pincelPixel(color));
    final luz = pincelPixel(this.luz);
    final sombra = pincelPixel(this.sombra);
    pintarFilaBorde(canvas, bisel, u, perfilBisel, luz, arriba: true);
    pintarFilaBorde(canvas, bisel, u, perfilBisel, sombra, arriba: false);
    final esquinas = perfilBisel.length * u;
    canvas
      ..drawRect(Rect.fromLTRB(bisel.left, bisel.top + esquinas, bisel.left + u, bisel.bottom - esquinas), luz)
      ..drawRect(Rect.fromLTRB(bisel.right - u, bisel.top + esquinas, bisel.right, bisel.bottom - esquinas), sombra);
    // Contorno de la pantalla y su fondo (por si la escena no pinta todo).
    pintarForma(canvas, caja.deflate(4 * u), u, perfilEsquina(3), tinta);
    if (!adornos) return;
    // Remaches: un cuadrado amarillo de 2 × 2 en cada esquina del bisel, con su brillo y su sombra.
    final amarillo = pincelPixel(ColoresUiPixel.amarillo);
    final brillo = pincelPixel(ColoresUiPixel.amarilloLuz);
    final hundido = pincelPixel(ColoresUiPixel.ocre);
    for (final esquina in [
      Offset(caja.left + 2 * u, caja.top + 2 * u),
      Offset(caja.right - 4 * u, caja.top + 2 * u),
      Offset(caja.left + 2 * u, caja.bottom - 4 * u),
      Offset(caja.right - 4 * u, caja.bottom - 4 * u),
    ]) {
      canvas
        ..drawRect(Rect.fromLTWH(esquina.dx, esquina.dy, 2 * u, 2 * u), amarillo)
        ..drawRect(Rect.fromLTWH(esquina.dx, esquina.dy, u, u), brillo)
        ..drawRect(Rect.fromLTWH(esquina.dx + u, esquina.dy + u, u, u), hundido);
    }
  }

  @override
  bool shouldRepaint(_PintorMarco oldDelegate) =>
      oldDelegate.u != u ||
      oldDelegate.dpr != dpr ||
      oldDelegate.color != color ||
      oldDelegate.luz != luz ||
      oldDelegate.sombra != sombra ||
      oldDelegate.adornos != adornos;
}
