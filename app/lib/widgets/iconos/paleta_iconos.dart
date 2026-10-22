import 'package:flutter/material.dart';

import '../../tema.dart';

/// Colores con los que se pintan los iconos de TuTurno y la mascota Tut: amarillo y azul de la marca, azul noche
/// para la tinta (contornos y detalles) y blanco papel para brillos y el borde de pegatina.
///
/// El tema puede registrar su propia paleta en `ThemeData.extensions`. Si no lo hace, se usan los colores de la
/// marca ([claro] u [oscuro] según el brillo) con el rojo de Ayuda, el éxito y la sombra de papel de [ColoresTuTurno]
/// y el error del esquema.
@immutable
class PaletaIconos extends ThemeExtension<PaletaIconos> {
  const PaletaIconos({
    required this.azul,
    required this.amarillo,
    required this.tinta,
    required this.papel,
    required this.celeste,
    required this.rubor,
    required this.sombra,
    required this.rojo,
    required this.exito,
    required this.sobreExito,
    required this.error,
    required this.sobreError,
  });

  /// Cuerpo principal de los iconos. En oscuro es más luminoso para llegar a 3:1 sobre el azul noche.
  final Color azul;

  /// Acento. Siempre con tinta azul noche al lado o encima: sobre blanco no tiene contraste.
  final Color amarillo;

  /// Azul noche: contornos y detalles sobre el amarillo.
  final Color tinta;

  /// Blanco papel: detalles sobre el azul y borde de pegatina.
  final Color papel;

  /// Azul claro para lágrimas, cristales y piezas secundarias.
  final Color celeste;

  /// Mejillas y lengua de Tut.
  final Color rubor;

  /// Sombra del papel (con su transparencia).
  final Color sombra;

  /// Solo para Ayuda.
  final Color rojo;

  /// Fondo del icono de acierto y la marca que va encima (≥ 3:1).
  final Color exito;
  final Color sobreExito;

  /// Fondo del icono de error y la marca que va encima (≥ 3:1).
  final Color error;
  final Color sobreError;

  static const claro = PaletaIconos(
    azul: ColoresMarca.azul,
    amarillo: ColoresMarca.amarillo,
    tinta: ColoresMarca.azulNoche,
    papel: ColoresMarca.papel,
    celeste: ColoresMarca.azulCielo,
    rubor: Color(0xFFFF9E80),
    sombra: Color(0x330E1A4F),
    rojo: ColoresMarca.rojoAyuda,
    exito: Color(0xFF0B7556),
    sobreExito: Colors.white,
    error: Color(0xFFB3261E),
    sobreError: Colors.white,
  );

  static const oscuro = PaletaIconos(
    azul: Color(0xFF4B5EF0),
    amarillo: ColoresMarca.amarillo,
    tinta: ColoresMarca.azulNoche,
    papel: ColoresMarca.papel,
    celeste: ColoresMarca.azulCielo,
    rubor: Color(0xFFFF9E80),
    sombra: Color(0x66000000),
    rojo: Color(0xFFD3313B),
    exito: Color(0xFF5FD9A8),
    sobreExito: ColoresMarca.azulNoche,
    error: Color(0xFFD3313B),
    sobreError: Colors.white,
  );

  /// La paleta del tema de [context].
  static PaletaIconos de(BuildContext context) {
    final tema = Theme.of(context);
    final propia = tema.extension<PaletaIconos>();
    if (propia != null) return propia;
    final oscuro = tema.brightness == Brightness.dark;
    final base = oscuro ? PaletaIconos.oscuro : PaletaIconos.claro;
    final colores = tema.extension<ColoresTuTurno>();
    if (colores == null) return base;
    // En oscuro, el error del esquema es claro (pensado para texto): bajo la cruz blanca va el rojo de Ayuda.
    return base.copyWith(
      rojo: colores.ayuda,
      exito: colores.exito,
      sobreExito: colores.sobreExito,
      sombra: colores.sombraPapel,
      error: oscuro ? colores.ayuda : tema.colorScheme.error,
      sobreError: oscuro ? Colors.white : tema.colorScheme.onError,
    );
  }

  @override
  PaletaIconos copyWith({
    Color? azul,
    Color? amarillo,
    Color? tinta,
    Color? papel,
    Color? celeste,
    Color? rubor,
    Color? sombra,
    Color? rojo,
    Color? exito,
    Color? sobreExito,
    Color? error,
    Color? sobreError,
  }) => PaletaIconos(
    azul: azul ?? this.azul,
    amarillo: amarillo ?? this.amarillo,
    tinta: tinta ?? this.tinta,
    papel: papel ?? this.papel,
    celeste: celeste ?? this.celeste,
    rubor: rubor ?? this.rubor,
    sombra: sombra ?? this.sombra,
    rojo: rojo ?? this.rojo,
    exito: exito ?? this.exito,
    sobreExito: sobreExito ?? this.sobreExito,
    error: error ?? this.error,
    sobreError: sobreError ?? this.sobreError,
  );

  @override
  PaletaIconos lerp(PaletaIconos? other, double t) {
    if (other == null) return this;
    Color mezcla(Color a, Color b) => Color.lerp(a, b, t)!;
    return PaletaIconos(
      azul: mezcla(azul, other.azul),
      amarillo: mezcla(amarillo, other.amarillo),
      tinta: mezcla(tinta, other.tinta),
      papel: mezcla(papel, other.papel),
      celeste: mezcla(celeste, other.celeste),
      rubor: mezcla(rubor, other.rubor),
      sombra: mezcla(sombra, other.sombra),
      rojo: mezcla(rojo, other.rojo),
      exito: mezcla(exito, other.exito),
      sobreExito: mezcla(sobreExito, other.sobreExito),
      error: mezcla(error, other.error),
      sobreError: mezcla(sobreError, other.sobreError),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PaletaIconos &&
      other.azul == azul &&
      other.amarillo == amarillo &&
      other.tinta == tinta &&
      other.papel == papel &&
      other.celeste == celeste &&
      other.rubor == rubor &&
      other.sombra == sombra &&
      other.rojo == rojo &&
      other.exito == exito &&
      other.sobreExito == sobreExito &&
      other.error == error &&
      other.sobreError == sobreError;

  @override
  int get hashCode =>
      Object.hash(azul, amarillo, tinta, papel, celeste, rubor, sombra, rojo, exito, sobreExito, error, sobreError);
}
