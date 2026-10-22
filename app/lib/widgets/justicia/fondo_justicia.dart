import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../tema.dart';

/// Las dos versiones del palacio de justicia de papel recortado.
enum VarianteFondoJusticia {
  /// Plana y suave, sin contorno ni detalles: para ir detrás de texto (el saludo y el pase del inicio). Sus tonos son
  /// los del papel recortado del tema (`ColoresTuTurno.fondoPapel`): el texto de encima se lee igual.
  silueta,

  /// La ilustración completa, con su panel de turnos encima de la puerta (la bienvenida).
  color,
}

/// Palacio de justicia de papel recortado (tema-justicia.md, §5 y §7.1): frontón con la balanza, cuatro columnas, la
/// puerta con el panel de turnos encima, la escalinata, el sol y el ticket de Tut. Sin banderas, escudos ni nombres.
///
/// [VarianteFondoJusticia.silueta] va detrás de texto (inicio); [VarianteFondoJusticia.color] es la ilustración
/// completa (bienvenida). Claro u oscuro según el tema (assets/justicia/palacio[-silueta][-oscuro].svg). El dibujo es
/// transparente y sus lomas se difuminan hacia abajo: se funde con la página, sin bordes.
///
/// Es decorativo: no se lee en voz alta ni se puede tocar. Con [scroll], se queda atrás al desplazar (paralaje 0,4,
/// como FondoPapel); con «reducir animaciones», quieto. Ocupa el ancho que tiene (alto en proporción, 360 × 230) o,
/// si el alto no llega, lo que quepa; [alineacion] lo coloca en su caja.
class FondoJusticia extends StatelessWidget {
  const FondoJusticia({
    super.key,
    this.variante = VarianteFondoJusticia.silueta,
    this.scroll,
    this.alineacion = Alignment.bottomCenter,
    this.panel,
  });

  final VarianteFondoJusticia variante;

  /// El scroll de la pantalla, para el paralaje. Sin él, el palacio se queda donde está.
  final ScrollController? scroll;
  final Alignment alineacion;

  /// Lo que se ve en el panel de turnos de encima de la puerta (p. ej. un PanelFlip con el número de turno, en papel
  /// con tinta azul noche, como las paletas del dibujo). Se encoge para caber. Solo en [VarianteFondoJusticia.color].
  final Widget? panel;

  /// Tamaño del dibujo: la caja de los SVG.
  static const tamanoDibujo = Size(360, 230);

  /// Hueco del panel en la caja de 360 × 230 del dibujo: el tablero azul noche de encima de la puerta.
  static const huecoPanel = Rect.fromLTRB(160, 108, 200, 123);

  /// Dónde van las paletas dentro del tablero: con un margen y sin tapar la luz amarilla de la esquina (196, 111,5).
  static const _paletas = Rect.fromLTRB(165, 109.5, 194.5, 121.5);

  /// Cuánto se mueve con el scroll: 0,4 veces lo que se desplaza la pantalla (se queda atrás).
  static const paralaje = 0.4;

  /// El SVG de [variante] para el tema de [brillo].
  static String asset(VarianteFondoJusticia variante, Brightness brillo) {
    final silueta = variante == VarianteFondoJusticia.silueta ? '-silueta' : '';
    final oscuro = brillo == Brightness.dark ? '-oscuro' : '';
    return 'assets/justicia/palacio$silueta$oscuro.svg';
  }

  /// Lee y prepara ya el SVG de [variante] para el tema de [context] (queda en la caché de flutter_svg): así, cuando
  /// se pinte, aparece a la primera, sin un hueco vacío. Se puede llamar las veces que haga falta.
  static void precargar(BuildContext context, VarianteFondoJusticia variante) {
    SvgAssetLoader(asset(variante, Theme.of(context).brightness)).loadBytes(context).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final asset = FondoJusticia.asset(variante, Theme.of(context).brightness);
    final panel = variante == VarianteFondoJusticia.color ? this.panel : null;
    Widget dibujo = AspectRatio(
      aspectRatio: tamanoDibujo.aspectRatio,
      child: LayoutBuilder(
        builder: (context, caja) {
          final escala = caja.maxWidth / tamanoDibujo.width;
          return Stack(
            fit: StackFit.expand,
            children: [
              SvgPicture.asset(asset, fit: BoxFit.fill, excludeFromSemantics: true),
              if (panel != null)
                Positioned.fromRect(
                  rect: Rect.fromLTRB(
                    _paletas.left * escala,
                    _paletas.top * escala,
                    _paletas.right * escala,
                    _paletas.bottom * escala,
                  ),
                  child: FittedBox(child: panel),
                ),
            ],
          );
        },
      ),
    );
    // En su propia capa: con el paralaje solo se mueve la capa, el dibujo no se vuelve a pintar.
    dibujo = Align(
      alignment: alineacion,
      child: RepaintBoundary(child: dibujo),
    );
    final scroll = this.scroll;
    if (scroll != null && duracion(context, Duracion.media) != Duration.zero) {
      dibujo = AnimatedBuilder(
        animation: scroll,
        child: dibujo,
        builder: (context, hijo) =>
            Transform.translate(offset: Offset(0, -_desplazado(scroll) * paralaje), child: hijo),
      );
    }
    return ExcludeSemantics(child: IgnorePointer(child: dibujo));
  }

  /// Lo que se ha desplazado la pantalla (0 si el scroll aún no está puesto o lo comparten varias listas).
  static double _desplazado(ScrollController scroll) => scroll.positions.length == 1 ? scroll.offset : 0;
}
