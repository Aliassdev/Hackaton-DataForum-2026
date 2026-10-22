import 'dart:math' as math;
import 'dart:ui';

import 'pieza.dart';
import 'recorte.dart';
import 'tu_icono.dart';

// Los dibujos de cada icono, en una rejilla de 100 × 100 (el contenido va de ~8 a ~92 para dejar sitio al contorno
// y a la sombra). Reglas del estilo:
// - Formas grandes y un poco irregulares, como recortadas a tijera; giros de pocos grados.
// - Cuerpo azul, acento amarillo; detalles en blanco papel sobre el azul y en azul noche sobre el amarillo.
// - Nada más fino de 3 unidades (a 24 px, ~1 px); los detalles finos llevan `desde` para quitarse en pequeño.

const _azul = TonoIcono.azul;
const _amarillo = TonoIcono.amarillo;
const _tinta = TonoIcono.tinta;
const _papel = TonoIcono.papel;
const _celeste = TonoIcono.celeste;

PiezaIcono _capa(Path forma, TonoIcono tono, {double desde = 0}) => PiezaIcono(forma, tono, desde: desde);

PiezaIcono _tira(Path forma, TonoIcono tono, double grosor) => PiezaIcono(forma, tono, trazo: grosor);

PiezaIcono _detalle(Path forma, TonoIcono tono, {double? trazo, double desde = 0}) =>
    PiezaIcono(forma, tono, trazo: trazo, capa: false, desde: desde);

Path _p(List<double> xy, {double radio = 2.5}) => Recorte.poligono(xy, radio: radio);

Path _juntar(List<Path> caminos) {
  final todo = Path();
  for (final camino in caminos) {
    todo.addPath(camino, Offset.zero);
  }
  return todo;
}

/// Cuerpo de altavoz (se comparte entre [TuIcono.altavoz] y [TuIcono.silencio]).
Path _altavoz() => _p([10, 37, 27, 37, 49, 17, 50, 83, 27, 63, 10, 63], radio: 3.5);

/// Aspa de dos barras giradas, centrada en ([cx], [cy]).
Path _aspa(double cx, double cy, double largo, double grosor) {
  Path barra(double giro) =>
      Recorte.caja(cx - grosor / 2, cy - largo / 2, cx + grosor / 2, cy + largo / 2, radio: grosor * 0.3, giro: giro);
  return Recorte.union([barra(45), barra(-45)]);
}

List<PiezaIcono> dibujoDe(TuIcono icono) => switch (icono) {
  TuIcono.inicio => [
    _capa(_p([63, 19, 73, 20, 73, 42, 63, 36]), _azul),
    _capa(_p([21, 46, 79, 45, 80, 88, 20, 89], radio: 3), _azul),
    _capa(_p([8, 52, 50, 12, 92, 50], radio: 4), _amarillo),
    _capa(_p([41, 88, 41, 70, 45, 63, 55, 63, 59, 70, 59, 88], radio: 2.5), _amarillo),
  ],
  TuIcono.juego => [
    _capa(_p([16, 34, 34, 28, 66, 28, 84, 34, 95, 70, 84, 81, 67, 65, 33, 65, 16, 81, 5, 70], radio: 10), _azul),
    _capa(
      _p([
        26.5, 37, 33.5, 37, 33.5, 44, 41, 44, 41, 51, 33.5, 51, 33.5, 58, 26.5, 58, 26.5, 51, 19, 51, 19, 44, //
        26.5, 44,
      ], radio: 1.8),
      _amarillo,
    ),
    _capa(Recorte.circulo(66, 42, 5.8), _amarillo),
    _capa(Recorte.circulo(77, 53, 5.8, semilla: 2), _papel),
  ],
  TuIcono.aprende => [
    _capa(_p([27, 45, 73, 45, 72, 69, 50, 77, 28, 69], radio: 6), _azul),
    _capa(_p([50, 17, 94, 37, 50, 57, 6, 37], radio: 3), _azul),
    _tira(Recorte.linea([50, 37, 79, 47, 80, 62]), _amarillo, 4.5),
    _capa(_p([75, 60, 85, 60, 88, 78, 72, 78], radio: 2), _amarillo),
    _capa(Recorte.circulo(50, 37, 5.5), _amarillo),
  ],
  TuIcono.pregunta => [
    _capa(Recorte.caja(50, 6, 92, 36, radio: 12, giro: 7), _amarillo),
    _detalle(
      Recorte.girar(
        _juntar([Recorte.circulo(62, 18, 2.8), Recorte.circulo(71, 18, 2.8), Recorte.circulo(80, 18, 2.8)]),
        7,
        centro: const Offset(71, 21),
      ),
      _tinta,
      desde: 40,
    ),
    _capa(
      Recorte.union([
        Recorte.caja(8, 26, 80, 76, radio: 19),
        _p([19, 68, 15, 92, 42, 72], radio: 2),
      ]),
      _azul,
    ),
    _detalle(
      Path()
        ..moveTo(34, 43)
        ..cubicTo(34, 31, 54, 30, 54, 42)
        ..cubicTo(54, 49, 44.5, 49, 44.5, 57),
      _papel,
      trazo: 8,
    ),
    _detalle(Recorte.circulo(44.5, 66.5, 4.8), _papel),
  ],
  TuIcono.ayuda => [
    _capa(Recorte.anillo(50, 50, 40, 18), _papel),
    for (final centro in const [-75.0, 15.0, 105.0, 195.0])
      _capa(Recorte.sector(50, 50, 18, 40, centro - 23, 46), TonoIcono.rojo),
  ],
  TuIcono.glosario => [
    _capa(_p([6, 28, 50, 35, 94, 28, 94, 83, 50, 89, 6, 83], radio: 4), _azul),
    _capa(
      Path()
        ..moveTo(12, 25)
        ..quadraticBezierTo(33, 17, 48, 29)
        ..lineTo(48, 81)
        ..quadraticBezierTo(33, 70, 12, 75)
        ..close(),
      _papel,
    ),
    _capa(
      Path()
        ..moveTo(52, 29)
        ..quadraticBezierTo(67, 17, 88, 25)
        ..lineTo(88, 75)
        ..quadraticBezierTo(67, 70, 52, 81)
        ..close(),
      _papel,
    ),
    _detalle(
      _juntar([
        Recorte.linea([19, 38, 41, 40]),
        Recorte.linea([19, 48, 41, 50]),
        Recorte.linea([19, 58, 35, 60]),
        Recorte.linea([59, 40, 81, 38]),
        Recorte.linea([59, 50, 81, 48]),
      ]),
      _tinta,
      trazo: 3.4,
      desde: 40,
    ),
    _capa(_p([62, 72, 71, 70, 72, 95, 66.5, 89, 62, 95], radio: 1.5), _amarillo),
  ],
  TuIcono.ajustes => [
    _capa(Recorte.engranaje(41, 57, 34, 25, 8, hueco: 10, giro: 8), _azul),
    _capa(Recorte.engranaje(76, 25, 18, 12.5, 6, hueco: 5, giro: 14), _amarillo),
  ],
  TuIcono.miSituacion => () {
    final camino = Path()
      ..moveTo(12, 88)
      ..cubicTo(36, 91, 52, 78, 41, 66)
      ..cubicTo(32, 57, 40, 47, 57, 50);
    return [
      // Puntos de un recorrido que acaba en la chincheta (trazos de largo casi cero con el extremo redondo).
      _tira(Recorte.discontinua(camino, trazo: 0.1, hueco: 11.5), _amarillo, 8),
      _capa(
        Path()
          ..moveTo(67, 68)
          ..cubicTo(58, 56, 48, 46, 48, 31)
          ..cubicTo(48, 20, 56.5, 11, 67, 11)
          ..cubicTo(77.5, 11, 86, 20, 86, 31)
          ..cubicTo(86, 46, 76, 56, 67, 68)
          ..close(),
        _azul,
      ),
      _detalle(Recorte.circulo(67, 31, 7.5), _papel),
    ];
  }(),
  TuIcono.racha => [
    _capa(
      Path()
        ..moveTo(50, 92)
        ..cubicTo(27, 92, 14, 76, 16, 58)
        ..cubicTo(18, 44, 28, 37, 30, 22)
        ..cubicTo(40, 28, 43, 36, 43, 44)
        ..cubicTo(47, 32, 53, 19, 64, 8)
        ..cubicTo(68, 24, 80, 36, 84, 53)
        ..cubicTo(88, 74, 74, 92, 50, 92)
        ..close(),
      _amarillo,
    ),
    _capa(
      Path()
        ..moveTo(50, 85)
        ..cubicTo(38, 85, 32, 76, 34.5, 68)
        ..cubicTo(37, 60, 44, 57, 46, 48)
        ..cubicTo(51, 54, 55, 57, 58.5, 51)
        ..cubicTo(64.5, 59, 67.5, 67, 66.5, 73)
        ..cubicTo(65.5, 81, 59, 85, 50, 85)
        ..close(),
      _azul,
    ),
  ],
  TuIcono.xp => [
    _capa(Recorte.circulo(50, 52, 35, semilla: 3), _azul),
    _capa(_p([58, 5, 23, 53, 46, 53, 37, 95, 79, 41, 55, 41, 67, 5], radio: 2.5), _amarillo),
  ],
  TuIcono.nivel => [
    _capa(_p([22, 6, 42, 6, 57, 44, 40, 51], radio: 2), _azul),
    _capa(_p([78, 6, 58, 6, 43, 44, 60, 51], radio: 2), _azul),
    _capa(Recorte.circulo(50, 64, 28, semilla: 3), _amarillo),
    _capa(Recorte.estrella(50, 65.5, 15, giro: 4), _azul),
  ],
  TuIcono.carta => [
    _capa(Recorte.caja(16, 14, 62, 80, radio: 7, giro: -13), _amarillo),
    _capa(Recorte.caja(34, 16, 82, 88, radio: 7, giro: 7), _azul),
    _detalle(Recorte.caja(40.5, 23, 75.5, 81, radio: 4, giro: 7), _papel, trazo: 2.6, desde: 48),
    _capa(Recorte.girar(Recorte.estrella(58, 52, 14), 7, centro: const Offset(58, 52)), _amarillo),
  ],
  TuIcono.sello => [
    _capa(
      Recorte.union([
        Recorte.circulo(50, 21, 14, semilla: 1),
        _p([43, 30, 57, 30, 59.5, 54, 40.5, 54], radio: 2),
      ]),
      _amarillo,
    ),
    _capa(_p([15, 52, 85, 51, 87, 73, 13, 74], radio: 4), _azul),
    _capa(_p([18, 74, 82, 73, 82, 85, 18, 86], radio: 2), _celeste),
  ],
  TuIcono.ticket => () {
    const centro = Offset(52, 59);
    return [
      _capa(Recorte.ticket(const Rect.fromLTRB(14, 16, 80, 60), muesca: 6.5, giro: -9), _azul),
      _capa(Recorte.ticket(const Rect.fromLTRB(14, 35, 90, 83), muesca: 7.5, radio: 7, giro: 5), _amarillo),
      _detalle(
        Recorte.girar(Recorte.discontinua(Recorte.linea([70, 41, 70, 78]), trazo: 3.2, hueco: 3.4), 5, centro: centro),
        _tinta,
        trazo: 2.8,
        desde: 32,
      ),
      _detalle(
        Recorte.girar(
          Recorte.union([
            _p([25, 45, 52, 44, 52, 51.5, 25, 52.5], radio: 1.2),
            _p([34.5, 52, 42, 52, 41.5, 75, 35, 75], radio: 1.2),
          ]),
          5,
          centro: centro,
        ),
        _tinta,
      ),
    ];
  }(),
  TuIcono.candado => [
    _tira(
      Path()
        ..moveTo(31, 50)
        ..lineTo(31, 34)
        ..arcToPoint(const Offset(69, 34), radius: const Radius.circular(19))
        ..lineTo(69, 50),
      _amarillo,
      9,
    ),
    _capa(_p([18, 45, 82, 44, 83, 91, 17, 92], radio: 9), _azul),
    _detalle(
      Recorte.union([
        Recorte.circulo(50, 63, 7),
        _p([46, 65, 54, 65, 56, 80, 44, 80], radio: 1.5),
      ]),
      _papel,
    ),
  ],
  TuIcono.check => [
    _capa(Recorte.circulo(50, 50, 41, semilla: 4), TonoIcono.exito),
    _capa(_p([22, 51, 32, 41, 44, 53, 68, 26, 79, 36, 45, 73], radio: 2.5), TonoIcono.sobreExito),
  ],
  TuIcono.cruz => [
    _capa(Recorte.circulo(50, 50, 41, semilla: 5), TonoIcono.error),
    _capa(_aspa(50, 50, 52, 14), TonoIcono.sobreError),
  ],
  TuIcono.microfono => [
    _tira(
      _juntar([
        Path()
          ..moveTo(24, 44)
          ..cubicTo(24, 75, 76, 75, 76, 44),
        Recorte.linea([50, 68, 50, 86]),
        Recorte.linea([34, 88, 66, 88]),
      ]),
      _amarillo,
      7,
    ),
    _capa(Recorte.caja(34, 7, 66, 61, radio: 16), _azul),
    _detalle(Recorte.linea([43, 19, 43, 33]), _papel, trazo: 5),
  ],
  TuIcono.altavoz => [
    _capa(_altavoz(), _azul),
    _tira(_juntar([Recorte.arco(50, 50, 16, -48, 96), Recorte.arco(50, 50, 32, -52, 104)]), _amarillo, 7),
  ],
  TuIcono.silencio => [_capa(_altavoz(), _azul), _capa(_aspa(74, 50, 34, 10), _amarillo)],
  TuIcono.fuente => [
    _capa(_p([18, 6, 61, 6, 83, 28, 83, 94, 18, 94], radio: 4), _azul),
    _capa(_p([61, 6, 83, 28, 61, 28], radio: 2), _amarillo),
    _detalle(
      _juntar([
        Recorte.linea([30, 42, 71, 42]),
        Recorte.linea([30, 55, 71, 55]),
        Recorte.linea([30, 68, 51, 68]),
      ]),
      _papel,
      trazo: 5.5,
    ),
    _capa(Recorte.estrella(69, 77, 11, interior: 7.5, puntas: 8), _amarillo),
  ],
  TuIcono.juzgado => [
    _capa(_p([7, 38, 50, 10, 93, 38, 93, 46, 7, 46], radio: 3), _amarillo),
    for (final x in const [15.0, 34.0, 56.0, 75.0])
      _capa(_p([x, 50, x + 10, 50, x + 10, 77, x, 77], radio: 1.5), _azul),
    _capa(_p([5, 81, 95, 81, 95, 93, 5, 93], radio: 2.5), _azul),
  ],
  TuIcono.escudo => () {
    final escudo = Path()
      ..moveTo(50, 6)
      ..cubicTo(62, 13, 74, 16, 87, 17)
      ..cubicTo(88, 52, 75, 79, 50, 94)
      ..cubicTo(25, 79, 12, 52, 13, 17)
      ..cubicTo(26, 16, 38, 13, 50, 6)
      ..close();
    return [
      _capa(escudo, _azul),
      _capa(
        Path.combine(PathOperation.intersect, escudo, Path()..addRect(const Rect.fromLTRB(0, 0, 50, 100))),
        _amarillo,
      ),
    ];
  }(),
  TuIcono.grabacion => [
    _capa(_p([66, 44, 92, 30, 93, 72, 66, 58], radio: 3), _azul),
    _capa(Recorte.caja(6, 27, 68, 77, radio: 11), _azul),
    _capa(Recorte.circulo(37, 52, 15, semilla: 2), _amarillo),
    _detalle(Recorte.circulo(37, 52, 6), _tinta),
    _detalle(Recorte.circulo(17, 37.5, 3.8), _papel, desde: 32),
  ],
  TuIcono.reloj => [
    _capa(Recorte.circulo(50, 50, 42, semilla: 7), _azul),
    _capa(Recorte.circulo(50, 50, 31, semilla: 8), _amarillo),
    _detalle(
      _juntar([
        for (final angulo in const [0.0, 90.0, 180.0, 270.0])
          Recorte.circulo(50 + 24 * math.cos(angulo * math.pi / 180), 50 + 24 * math.sin(angulo * math.pi / 180), 2.6),
      ]),
      _tinta,
      desde: 48,
    ),
    _detalle(
      _juntar([
        Recorte.linea([50, 50, 50, 30]),
        Recorte.linea([50, 50, 65, 59]),
      ]),
      _tinta,
      trazo: 6.5,
    ),
    _detalle(Recorte.circulo(50, 50, 5), _tinta),
  ],
  TuIcono.personaConfianza => [
    _capa(Recorte.circulo(37, 27, 14, semilla: 1), _azul),
    _capa(
      Path()
        ..moveTo(12, 91)
        ..lineTo(12, 67)
        ..cubicTo(12, 52, 25, 45, 37, 45)
        ..cubicTo(49, 45, 62, 52, 62, 67)
        ..lineTo(62, 91)
        ..close(),
      _azul,
    ),
    _capa(Recorte.circulo(70, 48, 11, semilla: 2), _amarillo),
    _capa(
      Path()
        ..moveTo(50, 93)
        ..lineTo(50, 80)
        ..cubicTo(50, 69, 59, 64, 70, 64)
        ..cubicTo(81, 64, 90, 69, 90, 80)
        ..lineTo(90, 93)
        ..close(),
      _amarillo,
    ),
    _capa(
      Path()
        ..moveTo(79, 31)
        ..cubicTo(69, 25, 67, 15, 73, 12.5)
        ..cubicTo(76, 11.3, 79, 13, 79, 16)
        ..cubicTo(79, 13, 82, 11.3, 85, 12.5)
        ..cubicTo(91, 15, 89, 25, 79, 31)
        ..close(),
      _amarillo,
      desde: 32,
    ),
  ],
  TuIcono.telefono => [
    _capa(
      Recorte.girar(
        Path()
          ..moveTo(34, 8)
          ..lineTo(62, 10)
          ..lineTo(63, 31)
          ..lineTo(49, 32)
          ..cubicTo(43, 42, 43, 58, 49, 68)
          ..lineTo(63, 69)
          ..lineTo(62, 90)
          ..lineTo(34, 92)
          ..cubicTo(17, 70, 17, 30, 34, 8)
          ..close(),
        -38,
        centro: const Offset(44, 52),
      ),
      _azul,
    ),
    _tira(_juntar([Recorte.arco(56, 44, 14, -88, 76), Recorte.arco(56, 44, 27, -90, 80)]), _amarillo, 6.5),
  ],
  TuIcono.web => [
    _capa(Recorte.circulo(46, 46, 38, semilla: 9), _azul),
    _detalle(
      _juntar([
        Path()..addOval(Rect.fromCenter(center: const Offset(46, 46), width: 30, height: 72)),
        Recorte.linea([11, 46, 81, 46]),
        Recorte.linea([46, 11, 46, 81]),
        Path()
          ..moveTo(18, 27)
          ..quadraticBezierTo(46, 35, 74, 27),
        Path()
          ..moveTo(18, 65)
          ..quadraticBezierTo(46, 57, 74, 65),
      ]),
      _papel,
      trazo: 3.6,
    ),
    _capa(_p([60, 56, 92, 70, 78, 74, 87, 88, 80, 92, 71, 78, 61, 86], radio: 1.8), _amarillo),
  ],
  TuIcono.enviar => [
    _detalle(
      Recorte.discontinua(
        Path()
          ..moveTo(9, 86)
          ..quadraticBezierTo(14, 70, 32, 70),
        trazo: 4,
        hueco: 4,
      ),
      _tinta,
      trazo: 3.4,
      desde: 48,
    ),
    _capa(_p([40, 60, 93, 9, 64, 89], radio: 2.5), _azul),
    _capa(_p([7, 46, 93, 9, 40, 60], radio: 2.5), _amarillo),
    _capa(_p([40, 60, 49, 84, 56, 69], radio: 2), _azul),
  ],
  TuIcono.volver => () {
    // Flecha azul con la cola amarilla: dos papeles pegados.
    return [
      _capa(_p([44, 36, 90, 37, 91, 64, 44, 65], radio: 3), _amarillo),
      _capa(_p([7, 50, 46, 14, 47, 34, 58, 35, 58, 66, 47, 66, 46, 86], radio: 3.5), _azul),
    ];
  }(),
  TuIcono.compartir => [
    _tira(Recorte.linea([72, 22, 28, 50, 72, 78]), _azul, 7),
    _capa(Recorte.circulo(72, 22, 14, semilla: 1), _amarillo),
    _capa(Recorte.circulo(28, 50, 14, semilla: 2), _azul),
    _capa(Recorte.circulo(72, 78, 14, semilla: 3), _amarillo),
  ],
  TuIcono.cerrar => [_capa(_aspa(50, 50, 84, 16), _azul)],
  TuIcono.estrella => [_capa(Recorte.estrella(50, 54, 44, giro: -4), _amarillo)],
  TuIcono.comodin => [
    _capa(Recorte.ticket(const Rect.fromLTRB(8, 25, 92, 77), muesca: 8, radio: 7, giro: -8), _azul),
    _capa(Recorte.estrella(50, 51, 19, giro: -8), _amarillo),
  ],
  TuIcono.pasaporte => () {
    const centro = Offset(50, 50);
    Path girado(Path camino) => Recorte.girar(camino, -4, centro: centro);
    return [
      _capa(Recorte.caja(19, 7, 81, 93, radio: 7, giro: -4), _azul),
      _capa(girado(Recorte.circulo(50, 40, 16, semilla: 3)), _amarillo),
      _detalle(girado(Recorte.estrella(50, 40, 9)), _tinta),
      _detalle(
        girado(
          _juntar([
            Recorte.linea([35, 69, 65, 69]),
            Recorte.linea([39, 79, 61, 79]),
          ]),
        ),
        _papel,
        trazo: 5,
      ),
    ];
  }(),
  TuIcono.mision => [
    _capa(Recorte.circulo(45, 55, 39, semilla: 2), _azul),
    _capa(Recorte.circulo(45, 55, 26, semilla: 3), _papel),
    _capa(Recorte.circulo(45, 55, 13, semilla: 4), _amarillo),
    _tira(Recorte.linea([45, 55, 82, 18]), _azul, 5),
    _capa(_p([80, 8, 86, 4, 88, 14, 96, 16, 92, 22, 82, 20], radio: 1.5), _amarillo),
  ],
  TuIcono.buscar => [
    _tira(Recorte.linea([63, 63, 86, 86]), _amarillo, 14),
    _capa(Recorte.circulo(41, 41, 31, semilla: 5), _azul),
    _detalle(Recorte.circulo(41, 41, 20, semilla: 6), _celeste),
    _detalle(Recorte.arco(41, 41, 13, 195, 70), _papel, trazo: 4.5, desde: 32),
  ],
  TuIcono.info => [
    _capa(Recorte.circulo(50, 50, 42, semilla: 6), _azul),
    _detalle(Recorte.circulo(50, 28, 7), _papel),
    _detalle(_p([43, 41, 57, 41, 56.5, 77, 43.5, 77], radio: 3), _papel),
  ],
  TuIcono.idea => [
    _tira(
      _juntar([
        for (final angulo in const [-160.0, -125.0, -90.0, -55.0, -20.0])
          Recorte.linea([
            50 + 31 * math.cos(angulo * math.pi / 180),
            39 + 31 * math.sin(angulo * math.pi / 180),
            50 + 40 * math.cos(angulo * math.pi / 180),
            39 + 40 * math.sin(angulo * math.pi / 180),
          ]),
      ]),
      _azul,
      5,
    ),
    _capa(
      Recorte.union([
        Recorte.circulo(50, 40, 24),
        _p([37, 52, 63, 52, 61, 70, 39, 70], radio: 3),
      ]),
      _amarillo,
    ),
    _detalle(Recorte.arco(50, 40, 15, 195, 65), _papel, trazo: 4.5, desde: 32),
    _capa(_p([38, 71, 62, 71, 61, 86, 39, 86], radio: 3), _azul),
    _detalle(Recorte.linea([43, 78.5, 57, 78.5]), _papel, trazo: 3.2, desde: 32),
  ],
};
