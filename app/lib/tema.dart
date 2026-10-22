import 'package:flutter/material.dart';

// Sistema de diseño de TuTurno: la marca amarilla y azul.
//
// Pensado para chicos y chicas desde los 11 años: letra muy legible (Atkinson Hyperlegible) para todo el texto y
// MaryKate, la letra del logotipo, solo para títulos grandes y números. Contraste AA en los dos temas, zonas táctiles
// grandes y movimiento que respeta la opción del sistema de reducir animaciones.
//
// Reglas de color de la marca:
// - El amarillo TuTurno nunca lleva texto blanco ni va sobre blanco (1,3:1): va sobre azul o azul noche, y encima
//   de él el texto es azul noche.
// - El rojo es solo para Ayuda (y el 112) y para los errores, para que la ayuda sea inconfundible.
// - Tema claro: papel cálido con tinta azul noche y azul eléctrico como color principal.
// - Tema oscuro: superficies azul noche con acentos amarillos.

abstract final class Espacio {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Radios de las esquinas. (Se llama Radios, en plural, para no chocar con el widget Radio de Material.)
abstract final class Radios {
  static const double s = 12;
  static const double m = 20;
  static const double l = 28;
}

/// Nombre antiguo de [Radios], para el código que ya lo usa con `import 'package:flutter/material.dart' hide Radio;`.
/// En código nuevo, usa [Radios] (así no hace falta el `hide`).
abstract final class Radio {
  static const double s = Radios.s;
  static const double m = Radios.m;
  static const double l = Radios.l;
}

abstract final class Duracion {
  static const corta = Duration(milliseconds: 180);
  static const media = Duration(milliseconds: 320);
  static const larga = Duration(milliseconds: 560);
}

/// [normal], o cero si el sistema pide reducir animaciones.
Duration duracion(BuildContext context, Duration normal) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : normal;

/// Como [duracion], pero para AnimatedSize: nunca cero. Con duración cero, AnimatedSize termina su animación dentro de
/// su propio layout y se vuelve a marcar (en debug salta un assert). Con «reducir animaciones», un microsegundo: el
/// cambio de tamaño se ve de golpe, en el fotograma siguiente.
Duration duracionTamano(BuildContext context, Duration normal) {
  final valor = duracion(context, normal);
  return valor == Duration.zero ? const Duration(microseconds: 1) : valor;
}

/// Colores de la marca TuTurno. Son iguales en los dos temas; en las pantallas, usa mejor el esquema del tema
/// (`Theme.of(context).colorScheme`) y [ColoresTuTurno] (`context.colores`), que ya se adaptan al tema.
abstract final class ColoresMarca {
  /// Amarillo TuTurno (el del logotipo). Sobre azul (5,3:1) o azul noche (12,4:1); encima, texto [azulNoche].
  static const amarillo = Color(0xFFFFDE59);

  /// Azul eléctrico: color principal del tema claro. Texto blanco encima: 7,1:1 (AAA).
  static const azul = Color(0xFF2643E0);

  /// Azul noche: la tinta del texto en el tema claro y la superficie del tema oscuro.
  static const azulNoche = Color(0xFF0E1A4F);

  /// Blanco papel, cálido: la superficie del tema claro. Tinta azul noche encima: 15,9:1.
  static const papel = Color(0xFFFFFBEF);

  /// Azul hielo: contenedores claros (con tinta azul noche).
  static const azulHielo = Color(0xFFDDE4FF);

  /// Azul cielo: el azul legible sobre fondos oscuros (con tinta azul noche encima).
  static const azulCielo = Color(0xFFAEBCFF);

  /// Ocre: el amarillo de la marca hecho tinta, para texto sobre papel (6,6:1).
  static const ocre = Color(0xFF7A5400);

  /// Rojo de Ayuda y del 112. Texto blanco encima: 6:1.
  static const rojoAyuda = Color(0xFFC21F2B);
}

/// Familias de letra (declaradas en pubspec.yaml).
abstract final class Fuentes {
  /// Atkinson Hyperlegible: todo el texto (botones, cuerpo, etiquetas y títulos de las barras).
  static const texto = 'AtkinsonHyperlegible';

  /// MaryKate, la letra del logotipo (la eligió Jorge): títulos grandes y números (estilos display y headline). Nunca
  /// para párrafos. Tiene un solo peso y el fichero declara 900, así que pedirle negrita no la engorda (ver
  /// assets/fonts/MaryKate-CREDITOS.txt). Le faltan º, °, …, – y —: salen de [texto] (fontFamilyFallback).
  static const titulos = 'MaryKate';
}

/// Colores propios que no están en [ColorScheme].
///
/// [juego], [aprende], [pregunta] y [ayuda] llevan texto blanco encima con contraste AA en los dos temas. [exito] es
/// para iconos y texto sobre la superficie (AA en los dos temas); si va de fondo, el texto encima es [sobreExito].
@immutable
class ColoresTuTurno extends ThemeExtension<ColoresTuTurno> {
  const ColoresTuTurno({
    required this.juego,
    required this.aprende,
    required this.pregunta,
    required this.ayuda,
    required this.exito,
    this.sobreExito = Colors.white,
    this.ticket = Colors.white,
    this.tintaTicket = ColoresMarca.azulNoche,
    this.sello = ColoresMarca.azul,
    this.sombraPapel = const Color(0x290E1A4F),
    this.confeti = const [ColoresMarca.amarillo, ColoresMarca.azul, ColoresMarca.azulNoche, ColoresMarca.azulCielo],
    this.holografico = const [
      ColoresMarca.amarillo,
      Color(0xFFFFF6C9),
      Color(0xFFBFE9FF),
      Color(0xFFCBC3FF),
      Colors.white,
    ],
    this.fondoPapel = const [Color(0xFFFFF1BF), Color(0xFFE3E8FF), Colors.white],
  });

  /// Degradados de cada módulo (del color principal al secundario).
  final List<Color> juego;
  final List<Color> aprende;
  final List<Color> pregunta;

  /// Botón y tarjetas de Ayuda.
  final Color ayuda;

  /// Acierto, «sirve», conexión correcta… sobre la superficie. Es un verde azulado: se distingue del azul de la marca
  /// y, con daltonismo rojo-verde, también del rojo de error. Siempre con un icono (✓) o texto: el color no va solo.
  final Color exito;

  /// Texto e iconos encima de [exito] cuando se usa de fondo (blanco en claro, azul noche en oscuro).
  final Color sobreExito;

  /// Papel de los tickets de turno (módulos, misión del día…) y su tinta (contraste AA o más).
  final Color ticket;
  final Color tintaTicket;

  /// Tinta de los sellos del pasaporte de derechos.
  final Color sello;

  /// Sombra de los papeles recortados y las pegatinas (con su transparencia).
  final Color sombraPapel;

  /// Confeti de papel: solo colores de la marca que se ven sobre el fondo del tema.
  final List<Color> confeti;

  /// Brillo holográfico de las cartas coleccionables (de un extremo al otro del reflejo).
  final List<Color> holografico;

  /// Capas de papel recortado de los fondos animados, de la más lejana a la más cercana. Suaves: el texto va encima.
  final List<Color> fondoPapel;

  /// Los tres módulos son azules de la marca y se distinguen por la luz y el matiz: Vive el caso, el azul eléctrico
  /// más vivo; Aprende, de azul a verde azulado; Pregunta, de índigo a azul noche (tranquilo).
  static const claro = ColoresTuTurno(
    juego: [ColoresMarca.azul, Color(0xFF1A2AA6)],
    aprende: [Color(0xFF1957C8), Color(0xFF086A80)],
    pregunta: [Color(0xFF24369E), ColoresMarca.azulNoche],
    ayuda: ColoresMarca.rojoAyuda,
    exito: Color(0xFF0B7556),
  );

  /// En oscuro, el primer color de cada módulo es más luminoso: con texto blanco encima sigue siendo AA y, como
  /// borde o icono sobre el azul noche, llega a 3:1.
  static const oscuro = ColoresTuTurno(
    juego: [Color(0xFF4B5EF0), Color(0xFF3A57F0)],
    aprende: [Color(0xFF1F72D6), Color(0xFF0E7FA6)],
    pregunta: [Color(0xFF3F5CE6), Color(0xFF24369E)],
    ayuda: Color(0xFFD3313B),
    exito: Color(0xFF5FD9A8),
    sobreExito: ColoresMarca.azulNoche,
    ticket: Color(0xFF1C2A6E),
    tintaTicket: ColoresMarca.papel,
    sello: ColoresMarca.amarillo,
    sombraPapel: Color(0x66000000),
    confeti: [ColoresMarca.amarillo, Color(0xFF4B5EF0), ColoresMarca.azulCielo, ColoresMarca.papel],
    fondoPapel: [Color(0xFF13205C), Color(0xFF1A2A6C), Color(0xFF22337E)],
  );

  @override
  ColoresTuTurno copyWith({
    List<Color>? juego,
    List<Color>? aprende,
    List<Color>? pregunta,
    Color? ayuda,
    Color? exito,
    Color? sobreExito,
    Color? ticket,
    Color? tintaTicket,
    Color? sello,
    Color? sombraPapel,
    List<Color>? confeti,
    List<Color>? holografico,
    List<Color>? fondoPapel,
  }) => ColoresTuTurno(
    juego: juego ?? this.juego,
    aprende: aprende ?? this.aprende,
    pregunta: pregunta ?? this.pregunta,
    ayuda: ayuda ?? this.ayuda,
    exito: exito ?? this.exito,
    sobreExito: sobreExito ?? this.sobreExito,
    ticket: ticket ?? this.ticket,
    tintaTicket: tintaTicket ?? this.tintaTicket,
    sello: sello ?? this.sello,
    sombraPapel: sombraPapel ?? this.sombraPapel,
    confeti: confeti ?? this.confeti,
    holografico: holografico ?? this.holografico,
    fondoPapel: fondoPapel ?? this.fondoPapel,
  );

  @override
  ColoresTuTurno lerp(ColoresTuTurno? other, double t) {
    if (other == null) return this;
    // Si las listas no miden lo mismo no se pueden mezclar color a color: se cambia de una a otra a mitad.
    List<Color> mezcla(List<Color> a, List<Color> b) =>
        a.length != b.length ? (t < 0.5 ? a : b) : [for (var i = 0; i < a.length; i++) Color.lerp(a[i], b[i], t)!];
    Color uno(Color a, Color b) => Color.lerp(a, b, t)!;
    return ColoresTuTurno(
      juego: mezcla(juego, other.juego),
      aprende: mezcla(aprende, other.aprende),
      pregunta: mezcla(pregunta, other.pregunta),
      ayuda: uno(ayuda, other.ayuda),
      exito: uno(exito, other.exito),
      sobreExito: uno(sobreExito, other.sobreExito),
      ticket: uno(ticket, other.ticket),
      tintaTicket: uno(tintaTicket, other.tintaTicket),
      sello: uno(sello, other.sello),
      sombraPapel: uno(sombraPapel, other.sombraPapel),
      confeti: mezcla(confeti, other.confeti),
      holografico: mezcla(holografico, other.holografico),
      fondoPapel: mezcla(fondoPapel, other.fondoPapel),
    );
  }
}

extension ColoresDelTema on BuildContext {
  ColoresTuTurno get colores => Theme.of(this).extension<ColoresTuTurno>()!;
}

/// Fondo suave teñido con [color]: para notas, iconos, ejemplos y estados vacíos. Con texto onSurface encima el
/// contraste es AA en los dos temas.
///
/// El color principal de cada tema tiñe con un azul claro de la marca (azul hielo en claro y azul cielo en oscuro),
/// porque mezclado con la superficie saldría gris: en claro, el azul eléctrico al 10 % sobre el papel cálido; en
/// oscuro, el amarillo sobre el azul noche, que son casi complementarios.
Color tinte(BuildContext context, Color color) {
  final oscuro = Theme.of(context).brightness == Brightness.dark;
  if (oscuro && color == ColoresMarca.amarillo) return ColoresMarca.azulCielo.withValues(alpha: 0.18);
  if (!oscuro && color == ColoresMarca.azul) return ColoresMarca.azulHielo.withValues(alpha: 0.8);
  return color.withValues(alpha: oscuro ? 0.18 : 0.10);
}

/// Borde a juego con [tinte]. El amarillo pasa a azul cielo: translúcido, sobre azul noche saldría oliva y sobre el
/// papel no se vería.
Color bordeTinte(Color color) =>
    (color == ColoresMarca.amarillo ? ColoresMarca.azulCielo : color).withValues(alpha: 0.3);

/// Color de las sombras de papel del tema. Si el tema no trae [ColoresTuTurno] (por ejemplo, en una prueba con un
/// MaterialApp sin [temaTuTurno]), el del tema claro.
Color sombraPapelDe(BuildContext context) =>
    Theme.of(context).extension<ColoresTuTurno>()?.sombraPapel ?? ColoresTuTurno.claro.sombraPapel;

/// Sombra de papel recortado: una sombra corta y nítida (el grosor del papel) y otra amplia y suave. Para tickets,
/// pegatinas y cartas. [elevacion] la hace más alta (1 = apoyado; 2 o 3 = levantado o mientras se arrastra).
List<BoxShadow> sombrasPapel(BuildContext context, {double elevacion = 1}) {
  final color = sombraPapelDe(context);
  return [
    BoxShadow(color: color, offset: Offset(0, 1.5 * elevacion), blurRadius: elevacion),
    BoxShadow(
      color: color.withValues(alpha: color.a * 0.7),
      offset: Offset(0, 6 * elevacion),
      blurRadius: 18 * elevacion,
    ),
  ];
}

/// [sombrasPapel] para siluetas con entrantes (tickets con muescas, bocadillos con cola), para que en el móvil salgan
/// baratas. Impeller solo calcula sin texturas el desenfoque de rectángulos redondeados y siluetas convexas: con una
/// silueta cóncava desenfocaría una textura aparte en cada fotograma. Por eso aquí la sombra corta no lleva desenfoque
/// (sigue la silueta exacta, muescas incluidas) y la amplia se pinta sobre el rectángulo redondeado del papel.
///
/// Las pintan así `SombraTicket`, `TicketPulsable` y `TicketVertical` (con `pintarSombrasTicket`, en
/// lib/widgets/movimiento/ticket.dart): las sombras sin desenfoque, con la silueta; las desenfocadas, con el rectángulo.
List<BoxShadow> sombrasTicket(BuildContext context, {double elevacion = 1}) {
  final [corta, amplia] = sombrasPapel(context, elevacion: elevacion);
  return [BoxShadow(color: corta.color, offset: corta.offset), amplia];
}

const _esquemaClaro = ColorScheme(
  brightness: Brightness.light,
  primary: ColoresMarca.azul,
  onPrimary: Colors.white,
  primaryContainer: ColoresMarca.azulHielo,
  onPrimaryContainer: ColoresMarca.azulNoche,
  secondary: ColoresMarca.azulNoche,
  onSecondary: ColoresMarca.amarillo,
  secondaryContainer: ColoresMarca.amarillo,
  onSecondaryContainer: ColoresMarca.azulNoche,
  tertiary: ColoresMarca.ocre,
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFFFFEEAD),
  onTertiaryContainer: Color(0xFF3B2900),
  error: ColoresMarca.rojoAyuda,
  onError: Colors.white,
  errorContainer: Color(0xFFFFDAD7),
  onErrorContainer: Color(0xFF7D0F18),
  surface: ColoresMarca.papel,
  onSurface: ColoresMarca.azulNoche,
  onSurfaceVariant: Color(0xFF454E7E),
  surfaceDim: Color(0xFFE6E1D3),
  surfaceBright: Color(0xFFFFFDF7),
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: Color(0xFFF8F6EE),
  surfaceContainer: Color(0xFFF0F1F8),
  surfaceContainerHigh: Color(0xFFE8EBF8),
  surfaceContainerHighest: Color(0xFFDFE4F6),
  outline: Color(0xFF69709A),
  outlineVariant: Color(0xFFCBD1EC),
  shadow: ColoresMarca.azulNoche,
  scrim: ColoresMarca.azulNoche,
  inverseSurface: ColoresMarca.azulNoche,
  onInverseSurface: ColoresMarca.papel,
  inversePrimary: ColoresMarca.amarillo,
  // Sin velo de color al elevar: la profundidad la dan las sombras de papel.
  surfaceTint: Colors.transparent,
);

const _esquemaOscuro = ColorScheme(
  brightness: Brightness.dark,
  primary: ColoresMarca.amarillo,
  onPrimary: ColoresMarca.azulNoche,
  primaryContainer: ColoresMarca.azul,
  onPrimaryContainer: Colors.white,
  secondary: ColoresMarca.azulCielo,
  onSecondary: ColoresMarca.azulNoche,
  secondaryContainer: Color(0xFF2A3A94),
  onSecondaryContainer: Colors.white,
  tertiary: ColoresMarca.amarillo,
  onTertiary: ColoresMarca.azulNoche,
  tertiaryContainer: Color(0xFF4A3C00),
  onTertiaryContainer: Color(0xFFFFEEAD),
  error: Color(0xFFFFB3AE),
  onError: Color(0xFF5F0A10),
  errorContainer: Color(0xFF8C1620),
  onErrorContainer: Color(0xFFFFDAD7),
  surface: Color(0xFF0B1543),
  onSurface: ColoresMarca.papel,
  onSurfaceVariant: Color(0xFFC5CBEB),
  surfaceDim: Color(0xFF08113A),
  surfaceBright: Color(0xFF2A3780),
  surfaceContainerLowest: Color(0xFF070F33),
  surfaceContainerLow: Color(0xFF101B4F),
  surfaceContainer: Color(0xFF152159),
  surfaceContainerHigh: Color(0xFF1B2865),
  surfaceContainerHighest: Color(0xFF223072),
  outline: Color(0xFF8D95C2),
  outlineVariant: Color(0xFF36437F),
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: ColoresMarca.papel,
  onInverseSurface: ColoresMarca.azulNoche,
  inversePrimary: ColoresMarca.azul,
  surfaceTint: Colors.transparent,
);

/// Barra superior del tema claro cuando hay contenido desplazado debajo: un azul muy pálido (tinta azul noche: 14,7:1).
const _barraDesplazada = Color(0xFFF0F2FF);

/// Esquema de color de TuTurno para [brillo] (público para poder probar sus contrastes).
ColorScheme esquemaTuTurno(Brightness brillo) => brillo == Brightness.light ? _esquemaClaro : _esquemaOscuro;

/// Display y headline con MaryKate, la letra del logotipo; el resto se queda en Atkinson Hyperlegible.
///
/// MaryKate tiene un solo peso y se pide normal (400): así los signos que le faltan salen de Atkinson normal, que pesa
/// lo mismo que sus trazos. Sus espacios entre palabras son muy anchos (0,42 em): se estrechan un 12 % del tamaño de
/// letra para que cada título se lea como una sola frase.
TextTheme _tipografia(TextTheme base) {
  TextStyle? titulo(TextStyle? estilo, double tamano, double alto) => estilo?.copyWith(
    fontFamily: Fuentes.titulos,
    fontFamilyFallback: const [Fuentes.texto],
    fontSize: tamano,
    height: alto,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    wordSpacing: -0.12 * tamano,
  );
  return base.copyWith(
    displayLarge: titulo(base.displayLarge, 57, 1.05),
    displayMedium: titulo(base.displayMedium, 45, 1.08),
    displaySmall: titulo(base.displaySmall, 36, 1.12),
    headlineLarge: titulo(base.headlineLarge, 34, 1.15),
    headlineMedium: titulo(base.headlineMedium, 30, 1.18),
    headlineSmall: titulo(base.headlineSmall, 26, 1.2),
  );
}

ThemeData temaTuTurno(Brightness brillo) {
  final claro = brillo == Brightness.light;
  final esquema = esquemaTuTurno(brillo);
  final base = ThemeData(colorScheme: esquema, fontFamily: Fuentes.texto, useMaterial3: true);
  final texto = _tipografia(base.textTheme);
  final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.m));
  final textoBoton = texto.titleMedium?.copyWith(fontWeight: FontWeight.w700);
  final bordeCampo = OutlineInputBorder(borderRadius: BorderRadius.circular(Radios.m), borderSide: BorderSide.none);

  return base.copyWith(
    extensions: [claro ? ColoresTuTurno.claro : ColoresTuTurno.oscuro],
    textTheme: texto,
    primaryTextTheme: _tipografia(base.primaryTextTheme),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    scaffoldBackgroundColor: esquema.surface,
    appBarTheme: AppBarTheme(
      // Al desplazar, la barra se tiñe un poco de azul en vez de oscurecerse. En claro, con un azul muy pálido: el velo
      // azul del tema sobre el papel cálido saldría gris. En oscuro, con el velo azul cielo sobre el azul noche.
      backgroundColor: claro
          ? WidgetStateColor.resolveWith(
              (estados) => estados.contains(WidgetState.scrolledUnder) ? _barraDesplazada : esquema.surface,
            )
          : esquema.surface,
      foregroundColor: esquema.onSurface,
      centerTitle: false,
      scrolledUnderElevation: 3,
      surfaceTintColor: claro ? Colors.transparent : ColoresMarca.azulCielo,
      shadowColor: Colors.transparent,
      titleTextStyle: texto.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: esquema.onSurface),
    ),
    // Tarjetas de papel: blancas sobre el papel cálido en claro; un azul algo más claro que el fondo en oscuro.
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: claro ? esquema.surfaceContainerLowest : esquema.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radios.l),
        side: BorderSide(color: esquema.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: Espacio.l, vertical: 14),
        shape: forma,
        textStyle: textoBoton,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 52), shape: forma, textStyle: textoBoton).copyWith(
        // Borde grueso del color principal, como un recorte; apagado si el botón está desactivado.
        side: WidgetStateProperty.resolveWith(
          (estados) => BorderSide(
            color: estados.contains(WidgetState.disabled) ? esquema.onSurface.withValues(alpha: 0.12) : esquema.primary,
            width: 2,
          ),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: texto.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
    // Seleccionado = pegatina amarilla con tinta azul noche (igual en los dos temas).
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.s)),
      // El chip resuelve el color de la etiqueta según su estado (WidgetStateColor).
      labelStyle: texto.labelLarge?.copyWith(
        color: WidgetStateColor.resolveWith(
          (estados) => estados.contains(WidgetState.disabled)
              ? esquema.onSurface.withValues(alpha: 0.38)
              : estados.contains(WidgetState.selected)
              ? ColoresMarca.azulNoche
              : esquema.onSurface,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: Espacio.s, vertical: Espacio.xs),
      side: BorderSide(color: esquema.outlineVariant),
      selectedColor: ColoresMarca.amarillo,
      checkmarkColor: ColoresMarca.azulNoche,
      secondaryLabelStyle: texto.labelLarge?.copyWith(color: ColoresMarca.azulNoche, fontWeight: FontWeight.w700),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected) ? ColoresMarca.amarillo : null,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected) ? ColoresMarca.azulNoche : null,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ColoresMarca.amarillo,
      foregroundColor: ColoresMarca.azulNoche,
      shape: forma,
      extendedTextStyle: textoBoton,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: ColoresMarca.amarillo,
      iconTheme: WidgetStateProperty.resolveWith(
        (estados) => IconThemeData(
          color: estados.contains(WidgetState.selected) ? ColoresMarca.azulNoche : esquema.onSurfaceVariant,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: esquema.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: Espacio.m),
      border: bordeCampo,
      enabledBorder: bordeCampo,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radios.m),
        borderSide: BorderSide(color: esquema.primary, width: 2),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: esquema.primary,
      selectionColor: esquema.primary.withValues(alpha: 0.3),
      selectionHandleColor: esquema.primary,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: esquema.primary,
      linearTrackColor: esquema.surfaceContainerHighest,
      circularTrackColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: forma),
    dialogTheme: DialogThemeData(
      backgroundColor: claro ? esquema.surfaceContainerLowest : esquema.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.l)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: claro ? esquema.surface : esquema.surfaceContainerLow,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radios.l))),
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: texto.bodyMedium?.copyWith(color: esquema.onInverseSurface),
      decoration: BoxDecoration(color: esquema.inverseSurface, borderRadius: BorderRadius.circular(Radios.s)),
    ),
    dividerTheme: DividerThemeData(color: esquema.outlineVariant, space: 1),
  );
}
