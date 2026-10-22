import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

/// Un color de [PaletaPixel]: la clave de un carácter que se escribe en las filas de un sprite, su nombre, el color y
/// el tono con el que se sombrea.
@immutable
class ColorPixel {
  const ColorPixel(this.clave, this.nombre, this.color, {this.sombra, this.uso = ''});

  /// Un solo carácter: es lo que se escribe en las filas de un sprite.
  final String clave;

  /// Nombre para las personas (el de la constante de [PaletaPixel], con tildes).
  final String nombre;

  final Color color;

  /// Clave del tono con el que se sombrea este color (la luz viene de arriba a la izquierda), o null si no tiene.
  final String? sombra;

  /// Para qué se suele usar.
  final String uso;

  @override
  String toString() => "ColorPixel('$clave', $nombre)";
}

/// La paleta compartida de todo el pixel art de «Vive el caso»: los amarillos y azules de la marca, el azul noche del
/// contorno, el papel, grises, seis tonos de piel, seis colores de pelo y unos pocos acentos para ropa y muebles.
///
/// Cada color tiene una clave de un carácter, que es lo que se escribe en las filas de un sprite; «.» es
/// transparente. La guía de estilo para dibujar con ella está en lib/pixel/LEEME.md.
abstract final class PaletaPixel {
  /// Clave de los píxeles transparentes.
  static const transparente = '.';

  // Contorno.
  static const noche = ColorPixel(
    'N',
    'noche',
    Color(0xFF0E1A4F),
    uso: 'El contorno de 1 píxel de todo, los ojos y las líneas de dentro.',
  );

  // Azules de la marca, de oscuro a claro.
  static const marino = ColorPixel(
    'D',
    'marino',
    Color(0xFF1B2C9E),
    sombra: 'N',
    uso: 'Sombra del azul; togas, uniformes.',
  );
  static const azul = ColorPixel('A', 'azul', Color(0xFF2846E8), sombra: 'D', uso: 'El azul eléctrico de la marca.');
  static const azulClaro = ColorPixel('a', 'azul claro', Color(0xFF6E89FA), sombra: 'A', uso: 'Ropa, carpetas.');
  static const cielo = ColorPixel('c', 'cielo', Color(0xFFAFBEFF), sombra: 'a', uso: 'Cielo, cristales, paredes.');
  static const hielo = ColorPixel('h', 'hielo', Color(0xFFE3E9FF), sombra: 'c', uso: 'Brillos, paredes claras.');

  // Amarillos de la marca.
  static const ocre = ColorPixel('o', 'ocre', Color(0xFFDA9A33), sombra: 't', uso: 'Sombra del amarillo y del rubio.');
  static const amarillo = ColorPixel('Y', 'amarillo', Color(0xFFFFDE59), sombra: 'o', uso: 'El amarillo de la marca.');
  static const amarilloLuz = ColorPixel('y', 'amarillo luz', Color(0xFFFFF2AE), sombra: 'Y', uso: 'Luces y lámparas.');

  // Neutros.
  static const blanco = ColorPixel('W', 'blanco', Color(0xFFFFFFFF), sombra: 'h', uso: 'Ojos, papeles, brillos.');
  static const papel = ColorPixel('P', 'papel', Color(0xFFFFFBEF), sombra: 'p', uso: 'El papel de la app; paredes.');
  static const crema = ColorPixel('p', 'crema', Color(0xFFF1E6CC), sombra: 'o', uso: 'Papel en sombra, paredes.');
  static const grisClaro = ColorPixel('g', 'gris claro', Color(0xFFD5D9E8), sombra: 'G', uso: 'Metal, suelos.');
  static const gris = ColorPixel('G', 'gris', Color(0xFF989EBB), sombra: 'K', uso: 'Sombra del gris claro.');
  static const grisOscuro = ColorPixel('K', 'gris oscuro', Color(0xFF5B6287), sombra: 'N', uso: 'Ropa neutra.');

  // Pieles, de clara a oscura. La sombra de cada una es la siguiente.
  static const piel1 = ColorPixel('1', 'piel 1', Color(0xFFFFE6D1), sombra: '2');
  static const piel2 = ColorPixel('2', 'piel 2', Color(0xFFF6CBA6), sombra: '3');
  static const piel3 = ColorPixel('3', 'piel 3', Color(0xFFE3A97F), sombra: '4');
  static const piel4 = ColorPixel('4', 'piel 4', Color(0xFFC08155), sombra: '5');
  static const piel5 = ColorPixel('5', 'piel 5', Color(0xFF915A37), sombra: '6');
  static const piel6 = ColorPixel('6', 'piel 6', Color(0xFF643B23), sombra: '7');
  static const pielSombra = ColorPixel('7', 'sombra de la piel 6', Color(0xFF43261A), uso: 'Solo sombra de la piel 6.');

  // Pelo.
  static const canoso = ColorPixel('b', 'canoso', Color(0xFFE4E2EA), sombra: 'G');
  static const rubio = ColorPixel('u', 'rubio', Color(0xFFF0C76B), sombra: 'o');
  static const pelirrojo = ColorPixel('f', 'pelirrojo', Color(0xFFD9662F), sombra: 'R');
  static const castanoClaro = ColorPixel('t', 'castaño claro', Color(0xFFA86E42), sombra: 'T');
  static const castano = ColorPixel('T', 'castaño', Color(0xFF6E452B), sombra: 'z');
  static const negro = ColorPixel('z', 'negro', Color(0xFF3A2D36), sombra: 'N');

  // Acentos para ropa y muebles.
  static const coral = ColorPixel('r', 'coral', Color(0xFFF2735E), sombra: 'R', uso: 'Ropa; nunca sangre ni heridas.');
  static const teja = ColorPixel('R', 'teja', Color(0xFFB44A2F), sombra: 'z', uso: 'Bocas, ladrillos, libros.');
  static const verde = ColorPixel('v', 'verde', Color(0xFF5FBA70), sombra: 'V', uso: 'Plantas, ropa.');
  static const verdeOscuro = ColorPixel('V', 'verde oscuro', Color(0xFF2E7656), sombra: 'N', uso: 'Sombra del verde.');
  static const lila = ColorPixel('L', 'lila', Color(0xFFA386EE), sombra: 'D', uso: 'Ropa, cojines.');
  static const rosa = ColorPixel('s', 'rosa', Color(0xFFF7AAC0), sombra: 'L', uso: 'Mejillas, ropa.');
  static const madera = ColorPixel('m', 'madera', Color(0xFFCB8C57), sombra: 't', uso: 'Muebles y suelos.');
  static const sombraSuelo = ColorPixel(
    'x',
    'sombra en el suelo',
    Color(0x400E1A4F),
    uso: 'Semitransparente: la sombra bajo los pies, sobre cualquier suelo.',
  );

  /// Todos los colores, en el orden de la guía.
  static const todos = <ColorPixel>[
    noche,
    marino,
    azul,
    azulClaro,
    cielo,
    hielo,
    ocre,
    amarillo,
    amarilloLuz,
    blanco,
    papel,
    crema,
    grisClaro,
    gris,
    grisOscuro,
    piel1,
    piel2,
    piel3,
    piel4,
    piel5,
    piel6,
    pielSombra,
    canoso,
    rubio,
    pelirrojo,
    castanoClaro,
    castano,
    negro,
    coral,
    teja,
    verde,
    verdeOscuro,
    lila,
    rosa,
    madera,
    sombraSuelo,
  ];

  /// Los seis tonos de piel, de claro a oscuro.
  static const pieles = <ColorPixel>[piel1, piel2, piel3, piel4, piel5, piel6];

  /// Los seis colores de pelo.
  static const pelos = <ColorPixel>[canoso, rubio, pelirrojo, castanoClaro, castano, negro];

  static final Map<String, ColorPixel> _porClave = {for (final color in todos) color.clave: color};

  /// Color de cada clave por su código (solo ASCII): así el revelado no busca en un mapa píxel a píxel.
  static final List<Color?> _porCodigo = () {
    final tabla = List<Color?>.filled(128, null);
    for (final color in todos) {
      tabla[color.clave.codeUnitAt(0)] = color.color;
    }
    return tabla;
  }();

  /// El color de [clave], o null si no está en la paleta (o es «.»).
  static ColorPixel? deClave(String clave) => _porClave[clave];

  /// Si [caracter] se puede escribir en un sprite: una clave de la paleta o «.».
  static bool esClave(String caracter) => caracter == transparente || _porClave.containsKey(caracter);

  /// El color de la clave con código [codigo] (`fila.codeUnitAt(x)`), o null si es transparente o no existe.
  static Color? colorDe(int codigo) => codigo < 128 ? _porCodigo[codigo] : null;

  /// Cambios para [Sprite.recolorear] que pasan de [de] a [a] en el color y en su sombra a la vez. Por ejemplo,
  /// `PaletaPixel.cambio(PaletaPixel.piel3, PaletaPixel.piel5)` cambia «3» por «5» y «4» por «6».
  static Map<String, String> cambio(ColorPixel de, ColorPixel a) => {
    de.clave: a.clave,
    if (de.sombra != null && a.sombra != null) de.sombra!: a.sombra!,
  };

  /// Todas las claves, separadas por espacios (para los mensajes de error).
  static String get claves => [for (final color in todos) color.clave].join(' ');
}
