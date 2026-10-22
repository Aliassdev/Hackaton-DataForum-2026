import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

// Formas de «papel recortado» para los iconos y para Tut: polígonos con las esquinas un poco suaves (como cortados
// a tijera), círculos ligeramente irregulares, estrellas, engranajes y la silueta del ticket de turno.
//
// Todas trabajan en coordenadas libres; los iconos usan una rejilla de 100 × 100.

abstract final class Recorte {
  /// Polígono cerrado con las esquinas redondeadas [radio]. [xy] son pares de coordenadas: x0, y0, x1, y1…
  static Path poligono(List<double> xy, {double radio = 2.5}) {
    assert(xy.length >= 6 && xy.length.isEven, 'Hacen falta al menos tres puntos');
    final puntos = [for (var i = 0; i < xy.length; i += 2) Offset(xy[i], xy[i + 1])];
    final n = puntos.length;
    final camino = Path();
    for (var i = 0; i < n; i++) {
      final anterior = puntos[(i - 1 + n) % n];
      final actual = puntos[i];
      final siguiente = puntos[(i + 1) % n];
      final haciaAtras = anterior - actual;
      final haciaDelante = siguiente - actual;
      final r1 = math.min(radio, haciaAtras.distance / 2);
      final r2 = math.min(radio, haciaDelante.distance / 2);
      final a = actual + haciaAtras / haciaAtras.distance * r1;
      final b = actual + haciaDelante / haciaDelante.distance * r2;
      if (i == 0) {
        camino.moveTo(a.dx, a.dy);
      } else {
        camino.lineTo(a.dx, a.dy);
      }
      camino.quadraticBezierTo(actual.dx, actual.dy, b.dx, b.dy);
    }
    return camino..close();
  }

  /// Rectángulo redondeado, girado [giro] grados sobre su centro.
  static Path caja(double izq, double arriba, double der, double abajo, {double radio = 6, double giro = 0}) {
    final rect = Rect.fromLTRB(izq, arriba, der, abajo);
    final camino = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radio)));
    return giro == 0 ? camino : girar(camino, giro, centro: rect.center);
  }

  /// Círculo «cortado a mano»: un poco irregular, distinto según [semilla] pero siempre el mismo.
  static Path circulo(double cx, double cy, double r, {int semilla = 0, double irregular = 0.025}) =>
      mancha(cx, cy, r, r, semilla: semilla, irregular: irregular);

  /// Óvalo suave e irregular (curva cerrada por 8 puntos).
  static Path mancha(double cx, double cy, double rx, double ry, {int semilla = 0, double irregular = 0.025}) {
    const ruido = [0.6, -0.9, 0.3, 1.0, -0.4, -1.0, 0.8, -0.2, 0.5, -0.7, 0.9, -0.5];
    const lados = 8;
    final puntos = <Offset>[];
    for (var i = 0; i < lados; i++) {
      final angulo = 2 * math.pi * i / lados + semilla * 0.37;
      final factor = 1 + irregular * ruido[(i + semilla * 5) % ruido.length];
      puntos.add(Offset(cx + rx * factor * math.cos(angulo), cy + ry * factor * math.sin(angulo)));
    }
    return suave(puntos);
  }

  /// Curva cerrada y suave que pasa por [puntos] (Catmull-Rom).
  static Path suave(List<Offset> puntos) {
    final n = puntos.length;
    final camino = Path()..moveTo(puntos.first.dx, puntos.first.dy);
    for (var i = 0; i < n; i++) {
      final p0 = puntos[(i - 1 + n) % n];
      final p1 = puntos[i];
      final p2 = puntos[(i + 1) % n];
      final p3 = puntos[(i + 2) % n];
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      camino.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return camino..close();
  }

  /// Estrella de [puntas] puntas con las esquinas un poco suaves.
  static Path estrella(double cx, double cy, double exterior, {double? interior, int puntas = 5, double giro = 0}) {
    final dentro = interior ?? exterior * 0.48;
    final xy = <double>[];
    for (var i = 0; i < puntas * 2; i++) {
      final r = i.isEven ? exterior : dentro;
      final angulo = (giro - 90) * math.pi / 180 + math.pi * i / puntas;
      xy
        ..add(cx + r * math.cos(angulo))
        ..add(cy + r * math.sin(angulo));
    }
    return poligono(xy, radio: exterior * 0.08);
  }

  /// Destello de cuatro puntas (curvas hacia dentro).
  static Path destello(double cx, double cy, double r) {
    final f = r * 0.18;
    return Path()
      ..moveTo(cx, cy - r)
      ..quadraticBezierTo(cx + f, cy - f, cx + r, cy)
      ..quadraticBezierTo(cx + f, cy + f, cx, cy + r)
      ..quadraticBezierTo(cx - f, cy + f, cx - r, cy)
      ..quadraticBezierTo(cx - f, cy - f, cx, cy - r)
      ..close();
  }

  /// Engranaje de [dientes] dientes con un agujero de radio [hueco] en el centro.
  static Path engranaje(
    double cx,
    double cy,
    double exterior,
    double interior,
    int dientes, {
    double hueco = 0,
    double giro = 0,
  }) {
    final xy = <double>[];
    final paso = 2 * math.pi / dientes;
    for (var i = 0; i < dientes; i++) {
      final base = giro * math.pi / 180 + paso * i;
      for (final (fraccion, r) in [(0.0, interior), (0.18, exterior), (0.5, exterior), (0.68, interior)]) {
        final angulo = base + paso * fraccion;
        xy
          ..add(cx + r * math.cos(angulo))
          ..add(cy + r * math.sin(angulo));
      }
    }
    final rueda = poligono(xy, radio: (exterior - interior) * 0.3);
    if (hueco <= 0) return rueda;
    return Path.combine(
      PathOperation.difference,
      rueda,
      Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: hueco)),
    );
  }

  /// Silueta del ticket de turno: rectángulo redondeado con una muesca semicircular en cada lado.
  static Path ticket(Rect rect, {double muesca = 6, double radio = 6, double giro = 0}) {
    final base = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radio)));
    final cortes = Path()
      ..addOval(Rect.fromCircle(center: rect.centerLeft, radius: muesca))
      ..addOval(Rect.fromCircle(center: rect.centerRight, radius: muesca));
    final ticket = Path.combine(PathOperation.difference, base, cortes);
    return giro == 0 ? ticket : girar(ticket, giro, centro: rect.center);
  }

  /// Anillo (círculo con agujero).
  static Path anillo(double cx, double cy, double exterior, double interior) => Path()
    ..fillType = PathFillType.evenOdd
    ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: exterior))
    ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: interior));

  /// Trozo de anillo entre los ángulos [desde] y [desde] + [barrido] (en grados, 0 = derecha, sentido horario).
  static Path sector(double cx, double cy, double interior, double exterior, double desde, double barrido) {
    final a = desde * math.pi / 180;
    final b = barrido * math.pi / 180;
    final fuera = Rect.fromCircle(center: Offset(cx, cy), radius: exterior);
    final dentro = Rect.fromCircle(center: Offset(cx, cy), radius: interior);
    return Path()
      ..arcTo(fuera, a, b, true)
      ..arcTo(dentro, a + b, -b, false)
      ..close();
  }

  /// Línea abierta que une los puntos [xy] (para pintar con grosor).
  static Path linea(List<double> xy) {
    final camino = Path()..moveTo(xy[0], xy[1]);
    for (var i = 2; i < xy.length; i += 2) {
      camino.lineTo(xy[i], xy[i + 1]);
    }
    return camino;
  }

  /// Arco abierto de circunferencia (grados, 0 = derecha, sentido horario).
  static Path arco(double cx, double cy, double r, double desde, double barrido) =>
      Path()
        ..addArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), desde * math.pi / 180, barrido * math.pi / 180);

  /// [camino] partido en trazos de [trazo] separados por [hueco].
  static Path discontinua(Path camino, {required double trazo, required double hueco}) {
    final resultado = Path();
    for (final medida in camino.computeMetrics()) {
      for (var d = 0.0; d < medida.length; d += trazo + hueco) {
        resultado.addPath(medida.extractPath(d, math.min(d + trazo, medida.length)), Offset.zero);
      }
    }
    return resultado;
  }

  /// Unión de varias formas en una sola silueta (sin bordes interiores).
  static Path union(List<Path> formas) =>
      formas.skip(1).fold(formas.first, (suma, forma) => Path.combine(PathOperation.union, suma, forma));

  /// [camino] girado [grados] (sentido horario) alrededor de [centro] (por defecto, el centro de su caja).
  static Path girar(Path camino, double grados, {Offset? centro}) {
    final c = centro ?? camino.getBounds().center;
    final angulo = grados * math.pi / 180;
    final cos = math.cos(angulo);
    final sin = math.sin(angulo);
    final matriz = Float64List.fromList([
      cos, sin, 0, 0, //
      -sin, cos, 0, 0, //
      0, 0, 1, 0, //
      c.dx - cos * c.dx + sin * c.dy, c.dy - sin * c.dx - cos * c.dy, 0, 1, //
    ]);
    return camino.transform(matriz);
  }

  /// [camino] desplazado.
  static Path mover(Path camino, double dx, double dy) => camino.shift(Offset(dx, dy));
}
