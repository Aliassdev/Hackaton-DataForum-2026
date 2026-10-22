import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../tema.dart';

/// Colores del kit de interfaz pixel de Vive el caso: los de la paleta compartida del motor (`PaletaPixel`), con los
/// mismos nombres y valores, para que la interfaz, los personajes y los fondos sean un solo mundo. (Se repiten aquí
/// como constantes para poder usarlos en widgets `const`; una prueba comprueba que coinciden con `PaletaPixel`.)
///
/// Cada color base va con su luz (la fila de arriba de un botón) y su sombra (la de abajo), como en la paleta. El
/// texto siempre tiene contraste AA o más:
/// - [noche] sobre [amarillo] (12:1), [papel] (16:1), [blanco], [hielo], [cielo] (9:1) y [gris] (6:1).
/// - [papel] o [blanco] sobre [noche] (16:1), [azul] (6,7:1), [teja] (5,3:1) y [verdeOscuro] (5,5:1).
/// - [grisOscuro] sobre [papel] (5,8:1).
///
/// La paleta no tiene rojo: el peligro y la respuesta incorrecta son [teja] (el rojo de la app queda solo para
/// Ayuda) y siempre llevan icono o texto.
abstract final class ColoresUiPixel {
  /// Contorno y sombra dura de todas las piezas; fondo de las ventanas y del HUD (PaletaPixel.noche).
  static const noche = Color(0xFF0E1A4F);

  /// Azules, de oscuro a claro (marino, azul, azulClaro, cielo y hielo de PaletaPixel).
  static const marino = Color(0xFF1B2C9E);
  static const azul = Color(0xFF2846E8);
  static const azulClaro = Color(0xFF6E89FA);
  static const cielo = Color(0xFFAFBEFF);
  static const hielo = Color(0xFFE3E9FF);

  /// El amarillo de la marca, con su luz y su sombra (amarillo, amarilloLuz y ocre de PaletaPixel).
  static const amarillo = Color(0xFFFFDE59);
  static const amarilloLuz = Color(0xFFFFF2AE);
  static const ocre = Color(0xFFDA9A33);

  /// Neutros (blanco, papel y crema de PaletaPixel).
  static const blanco = Color(0xFFFFFFFF);
  static const papel = Color(0xFFFFFBEF);
  static const crema = Color(0xFFF1E6CC);

  /// Grises: desactivado y bloqueado (grisClaro, gris y grisOscuro de PaletaPixel).
  static const grisClaro = Color(0xFFD5D9E8);
  static const gris = Color(0xFF989EBB);
  static const grisOscuro = Color(0xFF5B6287);

  /// Peligro y respuesta incorrecta: teja, con coral de luz y negro de sombra (teja, coral y negro de PaletaPixel).
  static const teja = Color(0xFFB44A2F);
  static const coral = Color(0xFFF2735E);
  static const negro = Color(0xFF3A2D36);

  /// Respuesta correcta: verde oscuro, con verde de luz (verdeOscuro y verde de PaletaPixel).
  static const verdeOscuro = Color(0xFF2E7656);
  static const verde = Color(0xFF5FBA70);
}

/// Contraste WCAG entre dos colores (de 1 a 21).
double contrastePixel(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Familias de letra del kit. La pixel se declara en pubspec.yaml como 'PixelifySans'.
abstract final class FuentesPixel {
  /// Pixelify Sans (OFL): la letra de todo el juego.
  static const pixel = 'PixelifySans';

  /// «Lectura fácil»: la letra del resto de la app (Atkinson Hyperlegible).
  static const lecturaFacil = Fuentes.texto;
}

/// Ajustes del mundo pixel para todo lo que cuelga de él: la letra (pixel o de lectura fácil), el tamaño de la unidad
/// pixel si hace falta y el scroll del juego ([ScrollPixel]: sin el estirado de Android, que emborronaría el pixel
/// art).
///
/// Va una vez, encima de todas las pantallas de Vive el caso. Sin [TemaPixel] encima, el kit usa Pixelify Sans y la
/// unidad que toca por el ancho de la pantalla (y el scroll de la app).
class TemaPixel extends StatelessWidget {
  const TemaPixel({super.key, this.lecturaFacil = false, this.unidad, required this.child});

  /// Cambia la letra pixel por Atkinson Hyperlegible en todos los textos del kit.
  final bool lecturaFacil;

  /// Tamaño de la unidad pixel en píxeles lógicos (antes de ajustarla a los píxeles físicos). Null: según la
  /// pantalla ([unidadParaPantalla]).
  final double? unidad;

  final Widget child;

  String get familia => lecturaFacil ? FuentesPixel.lecturaFacil : FuentesPixel.pixel;

  static TemaPixel? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TemaPixelHeredado>()?.tema;

  @override
  Widget build(BuildContext context) => _TemaPixelHeredado(
    tema: this,
    child: ScrollPixel(child: child),
  );
}

class _TemaPixelHeredado extends InheritedWidget {
  const _TemaPixelHeredado({required this.tema, required super.child});

  final TemaPixel tema;

  @override
  bool updateShouldNotify(_TemaPixelHeredado oldWidget) =>
      tema.lecturaFacil != oldWidget.tema.lecturaFacil || tema.unidad != oldWidget.tema.unidad;
}

/// La familia de letra de todos los textos del kit. Es el único sitio donde se decide: con
/// `TemaPixel(lecturaFacil: true)` encima, todo el juego pasa a Atkinson Hyperlegible.
String familiaPixel(BuildContext context) => TemaPixel.maybeOf(context)?.familia ?? FuentesPixel.pixel;

/// El scroll del mundo pixel: se para en seco en los extremos (sin el estirado de Android, que reescala la lista y
/// emborrona el pixel art, ni el brillo de otros sistemas). [TemaPixel] ya lo pone; úsalo suelto si una lista del
/// juego queda fuera de él.
class ScrollPixel extends StatelessWidget {
  const ScrollPixel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(overscroll: false, physics: const ClampingScrollPhysics()),
    child: child,
  );
}

/// El color que hay detrás de las piezas pixel de [child] (y, si [pintar], lo pinta).
///
/// Las piezas lo usan para no perderse en un fondo oscuro: el contorno y la sombra dura del kit son azul noche, así
/// que sobre azul noche (el fondo del juego, el del HUD o el del tema oscuro) no se verían. Ahí, las piezas cuyo
/// contorno no se ve llevan un filo de una unidad del color [filo] alrededor (por defecto, el azul que mejor se vea),
/// y dentro del filo se sigue viendo su sombra al pulsarlas.
///
/// ```dart
/// FondoPixel(color: ColoresUiPixel.noche, child: pantallaDeJuego)
/// ```
class FondoPixel extends StatelessWidget {
  const FondoPixel({super.key, required this.color, this.filo, this.pintar = true, required this.child});

  final Color color;

  /// Color del filo de las piezas que no se verían sobre [color]. Null: el primero de azul, azul claro y cielo con
  /// contraste 2:1 o más sobre [color].
  final Color? filo;

  /// Pinta [color] detrás de [child]. Con false solo lo declara (porque ya lo pinta otro, como el HUD).
  final bool pintar;

  final Widget child;

  /// El color del filo que llevan las piezas sobre este fondo.
  Color get colorFilo =>
      filo ??
      [
        ColoresUiPixel.azul,
        ColoresUiPixel.azulClaro,
        ColoresUiPixel.cielo,
      ].firstWhere((candidato) => contrastePixel(candidato, color) >= 2, orElse: () => ColoresUiPixel.noche);

  static FondoPixel? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FondoPixelHeredado>()?.fondo;

  @override
  Widget build(BuildContext context) => _FondoPixelHeredado(
    fondo: this,
    child: pintar ? ColoredBox(color: color, child: child) : child,
  );
}

class _FondoPixelHeredado extends InheritedWidget {
  const _FondoPixelHeredado({required this.fondo, required super.child});

  final FondoPixel fondo;

  @override
  bool updateShouldNotify(_FondoPixelHeredado oldWidget) =>
      fondo.color != oldWidget.fondo.color || fondo.filo != oldWidget.fondo.filo;
}

/// El filo que lleva una pieza con [contorno] (y, si tiene, [anillo]) sobre el [FondoPixel] de [context], o null si
/// no le hace falta: solo cuando ni el contorno ni el anillo se ven sobre el fondo (contraste menor de 2:1).
Color? filoPixel(BuildContext context, {required Color? contorno, Color? anillo}) {
  final fondo = FondoPixel.maybeOf(context);
  if (fondo == null || contorno == null) return null;
  if (contrastePixel(contorno, fondo.color) >= 2) return null;
  if (anillo != null && contrastePixel(anillo, fondo.color) >= 2) return null;
  return fondo.colorFilo;
}

/// Estilos de texto del kit. Tamaños cómodos (el cuerpo, 18 o más) y mucho interlineado.
enum TipoTextoPixel {
  /// Narración y textos largos: diálogos y opciones.
  cuerpo(20, FontWeight.w400, 1.45, 0.3),

  /// Textos secundarios, como el de las cartas. Nunca por debajo de 18.
  pequeno(18, FontWeight.w400, 1.4, 0.3),

  /// Botones.
  boton(20, FontWeight.w600, 1.2, 0.6),

  /// Etiquetas cortas: el nombre de quien habla, el talón del ticket y el título de las cartas.
  etiqueta(18, FontWeight.w600, 1.25, 0.5),

  /// Títulos: el del caso en el HUD y los de los apartados.
  titulo(22, FontWeight.w700, 1.2, 0.5),

  /// Títulos grandes.
  grande(32, FontWeight.w700, 1.1, 0.8);

  const TipoTextoPixel(this.tamano, this.peso, this.alto, this.espaciado);

  final double tamano;
  final FontWeight peso;

  /// Interlineado (multiplica el tamaño).
  final double alto;

  /// Espacio entre letras con la letra pixel (con la de lectura fácil, ninguno).
  final double espaciado;
}

/// Estilo de [tipo] con la familia de [familiaPixel] y, si se da, [color].
TextStyle estiloTextoPixel(BuildContext context, TipoTextoPixel tipo, {Color? color}) {
  final familia = familiaPixel(context);
  return TextStyle(
    fontFamily: familia,
    fontFamilyFallback: const [Fuentes.texto],
    fontSize: tipo.tamano,
    fontWeight: tipo.peso,
    height: tipo.alto,
    letterSpacing: familia == FuentesPixel.pixel ? tipo.espaciado : 0,
    leadingDistribution: TextLeadingDistribution.even,
    decoration: TextDecoration.none,
    color: color,
  );
}

/// Alto de una línea de [estilo] con el tamaño de letra del sistema.
double altoLineaPixel(BuildContext context, TextStyle estilo) {
  final tamano = estilo.fontSize ?? 14;
  return MediaQuery.textScalerOf(context).scale(tamano) * (estilo.height ?? 1.2);
}

/// Cuánto agranda el sistema la letra (1 sin cambios; 1,3 con letra grande). Nunca menos de 1.
double escalaTextoPixel(BuildContext context) => math.max(1, MediaQuery.textScalerOf(context).scale(18) / 18);

/// Unidad pixel que toca por el lado corto de la pantalla: 2 en pantallas muy estrechas, 3 en un móvil y 4 en una
/// tableta.
double unidadParaPantalla(double ladoCorto) => ladoCorto < 340 ? 2 : (ladoCorto < 600 ? 3 : 4);

/// [unidad] redondeada a un número entero de píxeles físicos: así todos los bordes caen justo en un píxel de la
/// pantalla y miden siempre lo mismo.
double ajustarUnidad(double unidad, double dpr) => math.max(1, (unidad * dpr).round()) / dpr;

/// El tamaño de un pixel del juego, en píxeles lógicos (entre 2 y 4 en un móvil, ajustado a los píxeles físicos).
/// Todos los bordes, sombras y escalones del kit miden un número entero de unidades.
double unidadPixel(BuildContext context) {
  final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
  final pedida = TemaPixel.maybeOf(context)?.unidad;
  final lado = MediaQuery.maybeSizeOf(context)?.shortestSide ?? 400;
  return ajustarUnidad(pedida ?? unidadParaPantalla(lado), dpr);
}
