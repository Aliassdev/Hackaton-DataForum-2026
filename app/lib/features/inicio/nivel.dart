import 'package:flutter/foundation.dart';

/// Niveles de experiencia: se suben con los puntos (XP) de Aprende. Cada uno tiene un título divertido, sin género
/// (vale para chicos y chicas) y sin presión: los puntos solo suben.
///
/// Con +10 XP por acierto, el nivel 2 llega con la primera lección.
@immutable
class Nivel {
  const Nivel._({required this.numero, required this.titulo, required this.desde, required this.hasta});

  /// El nivel que corresponde a [xp] puntos.
  factory Nivel.de(int xp) {
    final puntos = xp < 0 ? 0 : xp;
    var numero = 1;
    while (_desde(numero + 1) <= puntos) {
      numero++;
    }
    return Nivel.numero(numero);
  }

  /// El nivel [numero] (desde 1).
  factory Nivel.numero(int numero) {
    final n = numero < 1 ? 1 : numero;
    return Nivel._(
      numero: n,
      titulo: titulosNivel[(n - 1).clamp(0, titulosNivel.length - 1)],
      desde: _desde(n),
      hasta: _desde(n + 1),
    );
  }

  /// Títulos de los niveles, en orden. A partir del último, se repite con el número de nivel.
  ///
  /// Ninguno es un papel de un proceso (testigo, víctima…): quien usa la app puede estar viviendo uno de verdad, y
  /// declarar no es algo que se gane con puntos.
  static const titulosNivel = [
    'Ticket en mano',
    'Mente curiosa',
    'Detective de derechos',
    'Voz con poder',
    'Estrella de los derechos',
    'Brújula de la justicia',
    'Leyenda de TuTurno',
  ];

  /// XP con la que empieza cada nivel de la lista; después, uno nuevo cada [_pasoFinal] XP.
  static const _umbrales = [0, 50, 120, 220, 350, 520, 750];
  static const _pasoFinal = 250;

  static int _desde(int numero) =>
      numero <= _umbrales.length ? _umbrales[numero - 1] : _umbrales.last + (numero - _umbrales.length) * _pasoFinal;

  final int numero;
  final String titulo;

  /// XP con la que empieza este nivel y con la que empieza el siguiente.
  final int desde;
  final int hasta;

  /// Lo que lleva del nivel, de 0 a 1.
  double progreso(int xp) => ((xp - desde) / (hasta - desde)).clamp(0.0, 1.0);

  /// XP que faltan para el siguiente nivel.
  int faltan(int xp) => (hasta - xp).clamp(0, hasta - desde);

  Nivel get siguiente => Nivel.numero(numero + 1);

  @override
  bool operator ==(Object other) => other is Nivel && other.numero == numero;

  @override
  int get hashCode => numero.hashCode;

  @override
  String toString() => 'Nivel $numero ($titulo, $desde–$hasta XP)';
}
