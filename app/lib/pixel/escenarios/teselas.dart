// Piezas comunes de los fondos de «Vive el caso»: suelos, paredes, ventanas, estanterías, cuadros, plantas… Todo se
// pinta sobre un LienzoPixel con las claves de PaletaPixel. Las usan los archivos de cada lugar.
import 'dart:math' as math;

import '../motor/motor.dart';

/// Tamaño de todos los fondos, en píxeles del dibujo.
const anchoFondo = 160;
const altoFondo = 96;

/// Azar con semilla para los detalles que no se colocan a mano (el largo de las tablas, los libros de una estantería):
/// sale igual en cada arranque y en todas las plataformas, porque los productos caben en 2^53 (también en web).
class AzarPixel {
  AzarPixel(int semilla) : _estado = semilla.abs() % 2147483646 + 1;

  int _estado;

  /// Un entero de 0 a [tope] - 1.
  int entero(int tope) {
    _estado = _estado * 48271 % 2147483647;
    return _estado % tope;
  }

  /// True con una probabilidad de [porcentaje] sobre 100.
  bool si(int porcentaje) => entero(100) < porcentaje;

  T de<T>(List<T> opciones) => opciones[entero(opciones.length)];
}

/// Una forma: si el píxel (i, j) de su caja está dentro.
typedef FormaPixel = bool Function(int i, int j);

/// Un óvalo que llena una caja de [ancho] × [alto] (un círculo si son iguales).
FormaPixel ovalo(int ancho, int alto) => (i, j) {
  if (i < 0 || j < 0 || i >= ancho || j >= alto) return false;
  final dx = (i + 0.5 - ancho / 2) / (ancho / 2);
  final dy = (j + 0.5 - alto / 2) / (alto / 2);
  return dx * dx + dy * dy <= 1.08;
};

/// Un rectángulo de [ancho] × [alto] con las esquinas recortadas en escalón de [radio] píxeles.
FormaPixel redondeado(int ancho, int alto, [int radio = 1]) => (i, j) {
  if (i < 0 || j < 0 || i >= ancho || j >= alto) return false;
  final x = i < radio ? radio - i : (i >= ancho - radio ? i - (ancho - radio - 1) : 0);
  final y = j < radio ? radio - j : (j >= alto - radio ? j - (alto - radio - 1) : 0);
  return x + y <= radio;
};

/// Las filas de [filas] con «.» donde [forma] da false.
List<String> recortarForma(List<String> filas, FormaPixel forma) => [
  for (var j = 0; j < filas.length; j++)
    String.fromCharCodes([
      for (var i = 0; i < filas[j].length; i++) forma(i, j) ? filas[j].codeUnitAt(i) : 46, // 46 es «.»
    ]),
];

/// Cómo se ve el cielo por una ventana.
enum CieloPixel { dia, noche }

/// Lo que hay al fondo, detrás de una ventana.
enum PaisajePixel { nada, arboles, ciudad }

/// El tono más claro de [clave] para los brillos (el azul con su azul claro, la madera con el rubio…), o la misma
/// clave si no tiene uno más claro.
String luzDe(String clave) =>
    const {
      'D': 'A',
      'A': 'a',
      'a': 'c',
      'c': 'h',
      'h': 'W',
      'o': 'Y',
      'Y': 'y',
      'y': 'P',
      'p': 'P',
      'G': 'g',
      'K': 'G',
      'r': 's',
      'R': 'r',
      'V': 'v',
      'm': 'u',
      't': 'm',
      'T': 't',
      'L': 's',
    }[clave] ??
    clave;

/// Colores de los lomos de los libros.
const coloresLibros = ['A', 'a', 'r', 'R', 'Y', 'v', 'V', 'L', 's', 'o', 'D', 'c', 'W'];

/// Herramientas de pintar fondos sobre un [LienzoPixel], encima de las de siempre (rect, marco, pegar…).
extension DecoradoPixel on LienzoPixel {
  // ---------------------------------------------------------------------------------------------------------------
  // Retoques de color.

  /// Oscurece una zona con la sombra de cada color de la paleta (la madera con su castaño, el papel con su crema…).
  /// Con [trama], solo un píxel de cada dos, en damero: una sombra suave. Para las sombras del suelo, en vez de «x»,
  /// que es semitransparente y en un fondo dejaría ver el margen.
  void sombrear(int x, int y, int ancho, int alto, {bool trama = false, FormaPixel? forma}) =>
      _cada(x, y, ancho, alto, trama, forma, (clave) => PaletaPixel.deClave(clave)?.sombra);

  /// Cambia unas claves por otras en una zona (las que no están en [cambios] se quedan como están).
  void cambiar(
    int x,
    int y,
    int ancho,
    int alto,
    Map<String, String> cambios, {
    bool trama = false,
    FormaPixel? forma,
  }) => _cada(x, y, ancho, alto, trama, forma, (clave) => cambios[clave]);

  void _cada(int x, int y, int ancho, int alto, bool trama, FormaPixel? forma, String? Function(String) nueva) {
    for (var j = 0; j < alto; j++) {
      for (var i = 0; i < ancho; i++) {
        if (trama && (x + i + y + j).isOdd) continue;
        if (forma != null && !forma(i, j)) continue;
        final clave = en(x + i, y + j);
        if (clave == PaletaPixel.transparente) continue;
        final otra = nueva(clave);
        if (otra != null) punto(x + i, y + j, otra);
      }
    }
  }

  /// Rellena una [forma] dentro de la caja de [ancho] × [alto] con la esquina en ([x], [y]) y, si hay [contorno], con
  /// un borde de 1 píxel por dentro (todo píxel de la forma que toca el exterior por arriba, abajo o un lado).
  void figura(int x, int y, int ancho, int alto, FormaPixel forma, String relleno, {String? contorno}) {
    for (var j = 0; j < alto; j++) {
      for (var i = 0; i < ancho; i++) {
        if (!forma(i, j)) continue;
        final borde =
            contorno != null && (!forma(i - 1, j) || !forma(i + 1, j) || !forma(i, j - 1) || !forma(i, j + 1));
        punto(x + i, y + j, borde ? contorno : relleno);
      }
    }
  }

  /// Una hoja de la base ([bx], [by]) a la punta ([tx], [ty]), más ancha hacia el primer tercio ([ancho] de media
  /// anchura): contorno de 1 píxel, la mitad que da a la luz (arriba a la izquierda) en [claro] y la otra en [oscuro].
  void hoja(double bx, double by, double tx, double ty, double ancho, {String claro = 'v', String oscuro = 'V'}) {
    final dx = tx - bx, dy = ty - by;
    final largo2 = dx * dx + dy * dy;
    bool dentro(int x, int y) {
      final px = x + 0.5 - bx, py = y + 0.5 - by;
      final t = (px * dx + py * dy) / largo2;
      if (t < 0 || t > 1) return false;
      final ox = px - t * dx, oy = py - t * dy;
      final w = math.max(0.6, ancho * math.sin(math.pi * math.pow(t, 0.8)));
      return ox * ox + oy * oy <= w * w;
    }

    final x0 = (math.min(bx, tx) - ancho - 1).floor(), x1 = (math.max(bx, tx) + ancho + 1).ceil();
    final y0 = (math.min(by, ty) - ancho - 1).floor(), y1 = (math.max(by, ty) + ancho + 1).ceil();
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        if (!dentro(x, y)) continue;
        final borde = !dentro(x - 1, y) || !dentro(x + 1, y) || !dentro(x, y - 1) || !dentro(x, y + 1);
        // De qué lado del nervio está: el de la luz es el que mira arriba a la izquierda.
        final lado = (x + 0.5 - bx) * dy - (y + 0.5 - by) * dx;
        punto(x, y, borde ? 'N' : (lado > 0 ? claro : oscuro));
      }
    }
  }

  /// Pega [dibujo] con su esquina izquierda en [x] y su última fila justo encima de la fila [base] (lo que se apoya
  /// en el suelo: una planta, un mueble).
  void apoyar(List<String> dibujo, int x, int base) => pegar(dibujo, x, base - dibujo.length);

  /// Un óvalo relleno, con [contorno] si se da.
  void ovaloEn(int x, int y, int ancho, int alto, String relleno, {String? contorno}) =>
      figura(x, y, ancho, alto, ovalo(ancho, alto), relleno, contorno: contorno);

  /// Un rectángulo con las esquinas recortadas, con [contorno] si se da.
  void redondo(int x, int y, int ancho, int alto, String relleno, {String? contorno, int radio = 1}) =>
      figura(x, y, ancho, alto, redondeado(ancho, alto, radio), relleno, contorno: contorno);

  /// Un rectángulo con contorno de 1 píxel en [contorno] (azul noche por defecto).
  void caja(int x, int y, int ancho, int alto, String relleno, [String contorno = 'N']) {
    rect(x, y, ancho, alto, relleno);
    marco(x, y, ancho, alto, contorno);
  }

  /// Luz cálida alrededor de ([cx], [cy]): los colores de [cambios] (pared → pared iluminada) en un círculo de [radio] y
  /// en damero en un anillo de [radio] + 3 alrededor.
  void resplandor(int cx, int cy, int radio, Map<String, String> cambios) {
    final fuera = radio + 3;
    for (var j = -fuera; j <= fuera; j++) {
      for (var i = -fuera; i <= fuera; i++) {
        final d = math.sqrt(i * i + j * j);
        if (d > fuera) continue;
        if (d > radio && (cx + i + cy + j).isOdd) continue;
        final clave = en(cx + i, cy + j);
        final otra = cambios[clave];
        if (otra != null) punto(cx + i, cy + j, otra);
      }
    }
  }

  // ---------------------------------------------------------------------------------------------------------------
  // Suelos y paredes.

  /// Suelo de tablas desde la fila [desde] hasta abajo, con perspectiva: las filas de tablas crecen hacia abajo (más
  /// cerca) y las juntas van al tresbolillo.
  void tablas(int desde, {String madera = 'm', String junta = 't', int semilla = 3, int altoFila = 3, int largo = 22}) {
    rect(0, desde, ancho, alto - desde, madera);
    final azar = AzarPixel(semilla);
    var y = desde;
    var h = altoFila;
    var fila = 0;
    while (y < alto) {
      lineaH(0, y, ancho, junta);
      final paso = largo + fila * 6;
      var x = -azar.entero(paso);
      while (x < ancho) {
        lineaV(x, y + 1, h - 1, junta);
        x += paso - 3 + azar.entero(7);
      }
      y += h;
      h++;
      fila++;
    }
  }

  /// Suelo de baldosas en damero ([clara] y [oscura]) desde la fila [desde], con las filas más altas hacia abajo.
  void baldosas(int desde, {String clara = 'h', String oscura = 'g', int lado = 16, int altoFila = 4, String? junta}) {
    var y = desde;
    var h = altoFila;
    var fila = 0;
    while (y < alto) {
      for (var x = 0, n = 0; x < ancho; x += lado, n++) {
        rect(x, y, lado, h, (n + fila).isEven ? clara : oscura);
      }
      if (junta != null) lineaH(0, y, ancho, junta);
      y += h;
      h++;
      fila++;
    }
  }

  /// Zócalo de cuarterones de la fila [y] a la [hasta] (sin incluir): moldura arriba, paneles hundidos y rodapié.
  void zocalo(
    int y,
    int hasta, {
    String color = 'P',
    String sombra = 'p',
    String luz = 'W',
    String moldura = 'o',
    int panel = 20,
    int desfase = 2,
  }) {
    rect(0, y, ancho, hasta - y, color);
    lineaH(0, y, ancho, luz);
    lineaH(0, y + 1, ancho, moldura);
    for (var x = desfase; x < ancho; x += panel) {
      final alto = hasta - y - 8;
      if (alto < 3) break;
      // Panel hundido: sombra arriba e izquierda, luz abajo y derecha.
      lineaH(x, y + 4, panel - 4, sombra);
      lineaV(x, y + 4, alto, sombra);
      lineaH(x + 1, y + 3 + alto, panel - 5, luz);
      lineaV(x + panel - 5, y + 5, alto - 1, luz);
    }
    rodapie(hasta - 3, color: sombra, luz: luz, linea: moldura);
  }

  /// Rodapié de 3 filas desde la fila [y]: luz, color y una línea de sombra.
  void rodapie(int y, {String color = 'p', String luz = 'W', String linea = 'o'}) {
    lineaH(0, y, ancho, luz);
    lineaH(0, y + 1, ancho, color);
    lineaH(0, y + 2, ancho, linea);
  }

  /// La luz que entra por una ventana y cae en el suelo: un trapecio en damero desde la fila [desde] (de [x0] a [x1])
  /// hasta la [hasta], que se desplaza [inclinacion] píxeles a la derecha por cada fila (el sol entra de lado) y aclara
  /// los colores del suelo con [cambios].
  void luzEnSuelo(int x0, int x1, int desde, int hasta, Map<String, String> cambios, {double inclinacion = 0.6}) {
    for (var y = desde; y < hasta; y++) {
      final d = ((y - desde) * inclinacion).round();
      final abre = (y - desde) ~/ 3;
      final a = x0 + d - abre, b = x1 + d + abre;
      // Por dentro, luz entera; en los bordes (y en la última fila), en damero.
      final borde = y >= hasta - 2 ? (b - a) ~/ 2 : 2;
      cambiar(a + borde, y, b - a - 2 * borde, 1, cambios);
      cambiar(a, y, borde, 1, cambios, trama: true);
      cambiar(b - borde, y, borde, 1, cambios, trama: true);
    }
  }

  /// Un contorno de 1 píxel de [clave] alrededor de todo lo que no es transparente (por fuera: lo agranda un píxel).
  void contornear(String clave) {
    final opacos = <(int, int)>{};
    for (var y = 0; y < alto; y++) {
      for (var x = 0; x < ancho; x++) {
        if (en(x, y) != PaletaPixel.transparente) opacos.add((x, y));
      }
    }
    for (var y = 0; y < alto; y++) {
      for (var x = 0; x < ancho; x++) {
        if (opacos.contains((x, y))) continue;
        if (opacos.contains((x - 1, y)) ||
            opacos.contains((x + 1, y)) ||
            opacos.contains((x, y - 1)) ||
            opacos.contains((x, y + 1))) {
          punto(x, y, clave);
        }
      }
    }
  }

  // ---------------------------------------------------------------------------------------------------------------
  // Ventanas.

  /// Una ventana de [ancho] × [alto] con marco blanco, contorno azul noche, [hojas] de cristal y alféizar. Por ella se
  /// ve el [cielo] y, abajo, el [paisaje].
  void ventana(
    int x,
    int y,
    int ancho,
    int alto, {
    CieloPixel cielo = CieloPixel.dia,
    PaisajePixel paisaje = PaisajePixel.arboles,
    int hojas = 2,
    String marcoColor = 'W',
    String marcoSombra = 'h',
    bool alfeizar = true,
    bool sol = false,
    int semilla = 1,
  }) {
    pegar(
      vistaCielo(ancho - 2, alto - 2, cielo: cielo, paisaje: paisaje, sol: sol, semilla: semilla, hojas: hojas),
      x + 1,
      y + 1,
    );
    // Marco: contorno, listón blanco por dentro y su sombra.
    marco(x, y, ancho, alto, 'N');
    marco(x + 1, y + 1, ancho - 2, alto - 2, marcoColor);
    lineaH(x + 2, y + 2, ancho - 4, marcoSombra);
    lineaV(x + 2, y + 2, alto - 4, marcoSombra);
    // Hojas de la ventana.
    final interior = ancho - 2;
    for (var h = 1; h < hojas; h++) {
      final cx = x + 1 + interior * h ~/ hojas;
      lineaV(cx - 1, y + 1, alto - 2, marcoColor);
      lineaV(cx, y + 1, alto - 2, marcoColor);
      lineaV(cx + 1, y + 2, alto - 3, marcoSombra);
    }
    // Brillos del cristal: una raya corta en diagonal en la esquina de cada hoja (si la hoja es ancha).
    final brillo = cielo == CieloPixel.noche ? 'a' : 'W';
    if (interior ~/ hojas >= 14 && alto >= 18) {
      for (var h = 0; h < hojas; h++) {
        final x0 = h == 0 ? x + 4 : x + 1 + interior * h ~/ hojas + 3;
        for (var k = 0; k < 3; k++) {
          punto(x0 + k, y + 6 - k, brillo);
        }
      }
    }
    if (alfeizar) {
      caja(x - 2, y + alto - 1, ancho + 4, 3, marcoColor);
      lineaH(x - 1, y + alto, ancho + 2, marcoColor);
      lineaH(x - 1, y + alto + 1, ancho + 2, marcoSombra);
    }
  }

  /// Cortinas a los lados de una ventana que empieza en [x] y mide [ancho], desde la barra (fila [y]) hasta la fila
  /// [hasta]: anchas arriba, recogidas con un lazo a [recogida] de su alto y con vuelo abajo. [tela] y su sombra de la
  /// paleta; [luz], un tono más claro para el pliegue que da a la luz.
  void cortinas(
    int x,
    int y,
    int ancho,
    int hasta, {
    String tela = 'r',
    String? luz,
    double recogida = 0.6,
    int vuelo = 9,
  }) {
    final sombra = PaletaPixel.deClave(tela)!.sombra!;
    final alto = hasta - y - 1;
    final lazo = (alto * recogida).round();
    for (final izquierda in [true, false]) {
      final exterior = izquierda ? x - 4 : x + ancho + 3;
      final paso = izquierda ? 1 : -1;
      for (var j = 0; j < alto; j++) {
        final double t;
        final int w;
        if (j <= lazo) {
          t = j / lazo;
          w = (vuelo - (vuelo - 4) * t * t).round();
        } else {
          t = (j - lazo) / (alto - lazo);
          w = (4 + (vuelo - 6) * math.sqrt(t)).round();
        }
        for (var i = 0; i < w; i++) {
          final borde = i == 0 || i == w - 1 || j == alto - 1;
          final pliegue = i == (w / 3).round() || i == (w * 2 / 3).round();
          final brillo = luz != null && i == 1 && j < alto - 1;
          punto(exterior + paso * i, y + 1 + j, borde ? 'N' : (pliegue ? sombra : (brillo ? luz : tela)));
        }
      }
      // El lazo.
      final lx = izquierda ? exterior : exterior - 4;
      lineaH(lx, y + 1 + lazo, 5, 'Y');
      lineaH(lx, y + 2 + lazo, 5, 'o');
    }
    // La barra, con remates.
    lineaH(x - 6, y, ancho + 12, 'K');
    rect(x - 7, y - 1, 2, 3, 'o');
    rect(x + ancho + 5, y - 1, 2, 3, 'o');
  }

  // ---------------------------------------------------------------------------------------------------------------
  // Muebles y adornos.

  /// Estantería con [baldas] baldas llenas de libros de colores (y algún adorno), de madera con contorno.
  void estanteria(
    int x,
    int y,
    int ancho,
    int alto, {
    int baldas = 4,
    String madera = 'm',
    String fondo = 't',
    String luz = 'u',
    int semilla = 5,
    List<String> colores = coloresLibros,
    bool adornos = true,
  }) {
    caja(x, y, ancho, alto, madera);
    lineaV(x + 1, y + 1, alto - 2, luz);
    lineaH(x + 1, y + 1, ancho - 2, luz);
    final azar = AzarPixel(semilla);
    final interior = alto - 3;
    final hueco = interior ~/ baldas;
    for (var b = 0; b < baldas; b++) {
      final arriba = y + 2 + b * hueco;
      final suelo = arriba + hueco - 2; // la última fila de libros
      rect(x + 2, arriba, ancho - 4, hueco - 1, fondo);
      // La balda (su canto, con luz).
      lineaH(x + 1, arriba + hueco - 1, ancho - 2, madera);
      lineaH(x + 2, arriba + hueco - 1, ancho - 4, luz);
      var bx = x + 2;
      final fin = x + ancho - 2;
      while (bx < fin) {
        final queda = fin - bx;
        if (adornos && queda >= 5 && azar.si(10)) {
          bx += _adorno(bx, suelo, azar);
          continue;
        }
        if (queda >= 6 && azar.si(10)) {
          // Una pila de libros tumbados.
          final pila = 2 + azar.entero(2);
          for (var k = 0; k < pila; k++) {
            final color = azar.de(colores);
            final w = 5 - azar.entero(2);
            rect(bx, suelo - k * 2 - 1, w, 2, color);
            lineaH(bx, suelo - k * 2, w, PaletaPixel.deClave(color)!.sombra ?? 'N');
          }
          bx += 6;
          continue;
        }
        final w = math.min(queda, 2 + azar.entero(2));
        final h = math.max(3, hueco - 2 - azar.entero(3));
        final color = azar.de(colores);
        final sombra = PaletaPixel.deClave(color)!.sombra ?? 'N';
        rect(bx, suelo - h + 1, w, h, color);
        lineaV(bx + w - 1, suelo - h + 1, h, sombra);
        if (h >= 5 && w >= 2 && azar.si(45)) lineaH(bx, suelo - h + 3, w - 1, color == 'Y' ? 'o' : 'Y');
        bx += w;
        if (azar.si(8)) bx++;
      }
    }
  }

  /// Un adorno pequeño en una balda: una maceta, una caja o un bote. Devuelve lo que ocupa.
  int _adorno(int x, int suelo, AzarPixel azar) {
    switch (azar.entero(3)) {
      case 0: // maceta con dos hojas
        pegar(['.v.v.', 'vVvVv', '.vVv.', 'NRRRN', '.NrN.'], x, suelo - 4);
        return 5;
      case 1: // caja
        caja(x, suelo - 2, 5, 3, 'Y');
        lineaH(x + 1, suelo - 1, 3, 'o');
        return 5;
      default: // bote de lápices
        pegar(['r.Y.a', '.NNN.', '.NcN.', '.NcN.'], x, suelo - 3);
        return 5;
    }
  }

  /// Un cuadro de [ancho] × [alto] con marco de [color] y contorno; dentro, las filas de [dibujo] (que mida
  /// ancho − 4 × alto − 4).
  void cuadro(int x, int y, int ancho, int alto, List<String> dibujo, {String color = 'm', String luz = 'u'}) {
    caja(x, y, ancho, alto, color);
    lineaH(x + 1, y + 1, ancho - 2, luz);
    lineaV(x + 1, y + 1, alto - 2, luz);
    pegar(dibujo, x + 2, y + 2);
    marco(x + 2 - 1, y + 2 - 1, ancho - 2, alto - 2, color);
    lineaH(x + 2, y + alto - 2, ancho - 4, PaletaPixel.deClave(color)!.sombra ?? 'N');
  }

  /// Un reloj de pared redondo de 9 × 9 con la esquina en ([x], [y]) y el aro de color [aro].
  void reloj(int x, int y, {String aro = 'Y'}) {
    const filas = [
      '..NNNNN..',
      '.NYYYYYN.',
      'NYWWNWWYN',
      'NYWWNWWYN',
      'NYWWNNWYN',
      'NYWWWWhYN',
      'NYhWWWhYN',
      '.NYYYYoN.',
      '..NNNNN..',
    ];
    final sombra = PaletaPixel.deClave(aro)!.sombra ?? 'N';
    pegar([for (final fila in filas) fila.replaceAll('Y', aro).replaceAll('o', sombra)], x, y);
  }

  /// La sombra de un mueble en el suelo: [ancho] píxeles bajo la fila [y], más estrecha abajo.
  void sombraSuelo(int x, int y, int ancho, {int filas = 2}) {
    for (var f = 0; f < filas; f++) {
      sombrear(x + f, y + f, ancho - 2 * f, 1);
    }
  }

  /// Un sofá visto de frente de [ancho] × 29 con la esquina en ([x], [y]): respaldo, brazos, dos cojines de asiento,
  /// faldón, patas y su sombra; [color] con su [luz] y su [sombra], y un cojín de cada color de [cojines] encima.
  void sofa(
    int x,
    int y, {
    int ancho = 52,
    String color = 'A',
    String luz = 'a',
    String sombra = 'D',
    List<String> cojines = const ['Y', 'r'],
  }) {
    // Respaldo.
    redondo(x + 4, y, ancho - 8, 17, color, contorno: 'N', radio: 2);
    lineaH(x + 7, y + 1, ancho - 14, luz);
    lineaV(x + 5, y + 3, 10, luz);
    for (var bx = x + 12; bx < x + ancho - 8; bx += 9) {
      punto(bx, y + 7, sombra);
    }
    // Brazos.
    for (final bx in [x, x + ancho - 9]) {
      redondo(bx, y + 9, 9, 18, color, contorno: 'N', radio: 2);
      lineaH(bx + 2, y + 10, 5, luz);
      lineaV(bx + 1, y + 12, 12, luz);
      lineaV(bx + 7, y + 12, 13, sombra);
    }
    // Asiento: dos cojines.
    final mitad = x + ancho ~/ 2;
    caja(x + 8, y + 15, ancho - 16, 7, color);
    lineaH(x + 9, y + 16, ancho - 18, luz);
    lineaV(mitad, y + 15, 7, 'N');
    lineaH(x + 9, y + 20, ancho - 18, sombra);
    // Faldón y patas.
    caja(x + 3, y + 21, ancho - 6, 6, color);
    lineaH(x + 4, y + 22, ancho - 8, luz);
    lineaH(x + 4, y + 25, ancho - 8, sombra);
    rect(x + 5, y + 27, 3, 2, 'T');
    rect(x + ancho - 8, y + 27, 3, 2, 'T');
    sombraSuelo(x + 2, y + 29, ancho - 4);
    // Cojines.
    for (final (i, cojin) in cojines.indexed) {
      final cx = i == 0 ? x + 10 : x + ancho - 20;
      pegar(cojinSofa(cojin), cx, y + 8, espejo: i > 0);
    }
  }

  /// Una puerta de [ancho] × [alto] de [color], con jamba clara, dos cuarterones, [ventanilla] de cristal y pomo.
  void puerta(
    int x,
    int y,
    int ancho,
    int alto, {
    String color = 'm',
    String jamba = 'W',
    bool ventanilla = true,
    String pomo = 'Y',
  }) {
    final sombra = PaletaPixel.deClave(color)!.sombra ?? 'N';
    caja(x - 2, y - 2, ancho + 4, alto + 2, jamba);
    caja(x, y, ancho, alto, color);
    lineaV(x + 1, y + 1, alto - 1, PaletaPixel.deClave(jamba)?.sombra ?? 'g');
    final panel = ancho - 6;
    if (ventanilla) {
      caja(x + 3, y + 3, panel, alto * 2 ~/ 5 - 3, 'c');
      lineaH(x + 4, y + 4, panel - 2, 'h');
      punto(x + 4, y + 5, 'W');
    } else {
      marco(x + 3, y + 3, panel, alto * 2 ~/ 5 - 3, sombra);
    }
    marco(x + 3, y + alto * 2 ~/ 5 + 2, panel, alto * 3 ~/ 5 - 5, sombra);
    lineaV(x + ancho - 2, y + 1, alto - 1, sombra);
    final py = y + alto * 11 ~/ 20;
    rect(x + ancho - 5, py, 2, 2, pomo);
    punto(x + ancho - 4, py + 1, PaletaPixel.deClave(pomo)?.sombra ?? 'N');
  }

  /// Una silla vista de frente (10 × 16) con la esquina en ([x], [y]): respaldo de [color] y patas grises.
  void silla(int x, int y, {String color = 'A'}) {
    final sombra = PaletaPixel.deClave(color)!.sombra ?? 'N';
    redondo(x + 1, y, 8, 8, color, contorno: 'N');
    lineaH(x + 2, y + 1, 5, luzDe(color));
    lineaV(x + 7, y + 1, 6, sombra);
    lineaV(x + 2, y + 8, 2, 'N');
    lineaV(x + 7, y + 8, 2, 'N');
    caja(x, y + 9, 10, 3, color);
    lineaH(x + 1, y + 10, 8, sombra);
    for (final px in [x + 1, x + 8]) {
      lineaV(px, y + 12, 4, 'K');
    }
    lineaV(x, y + 12, 4, 'N');
    lineaV(x + 9, y + 12, 4, 'N');
  }

  /// Un tablón de corcho de [ancho] × [alto] con marco de madera; [papeles] son dibujos pequeños que se clavan en él
  /// (cada uno con su chincheta), repartidos de izquierda a derecha.
  void corcho(int x, int y, int ancho, int alto, List<List<String>> papeles, {int semilla = 2}) {
    caja(x, y, ancho, alto, 'o');
    marco(x + 1, y + 1, ancho - 2, alto - 2, 'm');
    lineaH(x + 2, y + 2, ancho - 4, 't');
    final azar = AzarPixel(semilla);
    // Motas del corcho.
    for (var k = 0; k < ancho * alto ~/ 14; k++) {
      punto(x + 3 + azar.entero(ancho - 6), y + 3 + azar.entero(alto - 6), azar.si(50) ? 't' : 'u');
    }
    final libre = ancho - 4;
    var px = x + 3;
    for (final (i, papel) in papeles.indexed) {
      final w = papel.first.length;
      final hueco = libre ~/ papeles.length;
      final py = y + 3 + (i.isEven ? 0 : 2) + azar.entero(2);
      pegar(papel, px + (hueco - w) ~/ 2 - 1, py);
      punto(px + (hueco - w) ~/ 2 - 1 + w ~/ 2, py, azar.de(['r', 'A', 'v', 'Y']));
      px += hueco;
    }
  }

  /// Persiana de lamas sobre una ventana (la parte de arriba, de [alto] filas).
  void persiana(int x, int y, int ancho, int alto) {
    for (var j = 0; j < alto; j++) {
      lineaH(x, y + j, ancho, j.isEven ? 'W' : 'g');
    }
    lineaH(x, y + alto, ancho, 'G');
    lineaV(x + ancho ~/ 3, y + alto, 4, 'G');
    punto(x + ancho ~/ 3, y + alto + 4, 'K');
  }

  /// Una guirnalda de banderines de colores colgada entre ([x0], [y]) y ([x1], [y]), con la cuerda algo combada.
  void banderines(int x0, int x1, int y, {List<String> colores = const ['r', 'Y', 'a', 'v', 's', 'L']}) {
    var c = 0;
    for (var x = x0; x < x1; x++) {
      final t = (x - x0) / (x1 - x0);
      final cuerda = y + (4 * t * (1 - t) * 4).round();
      punto(x, cuerda, 'K');
      if ((x - x0) % 8 == 2 && x + 5 < x1) {
        final color = colores[c++ % colores.length];
        final sombra = PaletaPixel.deClave(color)!.sombra!;
        pegar(
          ['$color$color$color$color$sombra', '.$color$color$sombra.', '.$color$sombra..', '..$sombra..'],
          x,
          cuerda + 1,
        );
      }
    }
  }

  /// Una pantalla de [ancho] × [alto] con marco oscuro; dentro, las filas de [imagen] (que mida ancho − 4 × alto − 4).
  void pantalla(int x, int y, int ancho, int alto, List<String> imagen) {
    caja(x, y, ancho, alto, 'K');
    lineaH(x + 1, y + 1, ancho - 2, 'G');
    pegar(imagen, x + 2, y + 2);
  }
}

// ---------------------------------------------------------------------------------------------------------------------
// Vistas del cielo y del paisaje (dentro de las ventanas).

/// Lo que se ve por una ventana: un cielo de [ancho] × [alto] con nubes, sol, luna o estrellas, y el [paisaje] abajo.
List<String> vistaCielo(
  int ancho,
  int alto, {
  CieloPixel cielo = CieloPixel.dia,
  PaisajePixel paisaje = PaisajePixel.arboles,
  bool sol = false,
  int semilla = 1,
  int hojas = 1,
}) {
  final l = LienzoPixel(ancho, alto);
  final azar = AzarPixel(semilla);
  final hoja = ancho ~/ hojas;
  switch (cielo) {
    case CieloPixel.dia:
      l
        ..rect(0, 0, ancho, alto, 'c')
        ..rect(0, alto * 3 ~/ 5, ancho, alto, 'h');
      // Una nube por hoja (que no la corte el marco), a alturas distintas.
      for (var h = 0; h < hojas; h++) {
        final nube = hoja >= 14 ? _nubeGrande : _nubePequena;
        final w = nube.first.length;
        if (w > hoja - 2) continue;
        final nx = h * hoja + 1 + azar.entero(hoja - w - 1);
        final ny = 3 + (h.isEven ? 0 : 4) + azar.entero(3);
        if (!(sol && h == hojas - 1)) l.pegar(nube, nx, ny);
      }
      if (sol) l.ovaloEn(ancho - 10, 3, 6, 6, 'y', contorno: 'Y');
    case CieloPixel.noche:
      l
        ..rect(0, 0, ancho, alto, 'D')
        ..rect(0, alto * 2 ~/ 3, ancho, alto, 'A');
      for (var k = 0; k < ancho * alto ~/ 40; k++) {
        l.punto(azar.entero(ancho), azar.entero(alto * 2 ~/ 3), azar.si(30) ? 'y' : 'h');
      }
      l
        ..ovaloEn(ancho - 11, 3, 7, 7, 'y')
        ..ovaloEn(ancho - 9, 2, 6, 6, 'D');
  }
  final suelo = alto - 1;
  switch (paisaje) {
    case PaisajePixel.nada:
      break;
    case PaisajePixel.arboles:
      final claro = cielo == CieloPixel.noche ? 'A' : 'v';
      final oscuro = cielo == CieloPixel.noche ? 'D' : 'V';
      // Copas redondas que se solapan: primero la sombra (abajo a la derecha) y encima la copa.
      final maximo = math.max(4, alto * 2 ~/ 5);
      for (var x = -3 + azar.entero(3); x < ancho; x += 6 + azar.entero(4)) {
        final r = math.min(maximo, 7 + azar.entero(4));
        final arriba = suelo - r + 3 + azar.entero(2);
        l
          ..ovaloEn(x + 1, arriba + 1, r, r, oscuro)
          ..ovaloEn(x, arriba, r - 1, r - 1, claro);
      }
      l.rect(0, suelo - 1, ancho, 2, oscuro);
    case PaisajePixel.ciudad:
      // Dos filas de edificios: los de atrás más claros. Ventanas en rejilla, unas encendidas y otras no.
      final noche = cielo == CieloPixel.noche;
      for (final (lejos, tono, ventana) in [
        (true, noche ? 'D' : 'c', noche ? 'A' : 'h'),
        (false, noche ? 'N' : 'a', noche ? 'y' : 'h'),
      ]) {
        for (var x = (lejos ? -3 : 0) + azar.entero(3); x < ancho; x += (lejos ? 7 : 9) + azar.entero(4)) {
          final w = (lejos ? 6 : 7) + azar.entero(3);
          final h = (lejos ? alto ~/ 2 : alto ~/ 3) + azar.entero(alto ~/ 4 + 1);
          final arriba = suelo - h + 1;
          l.rect(x, arriba, w, h, tono);
          for (var vy = arriba + 2; vy < suelo - 1; vy += 3) {
            for (var vx = x + 2; vx < x + w - 1; vx += 2) {
              if (azar.si(noche ? 45 : 70)) l.punto(vx, vy, ventana);
            }
          }
        }
      }
  }
  return l.filas;
}

// ---------------------------------------------------------------------------------------------------------------------
// Dibujos pequeños que se repiten.

/// Una hoja para [dibujarPlanta]: de la base ([bx], [by]) a la punta ([tx], [ty]), con [ancho] de media anchura en lo
/// más ancho.
typedef HojaPixel = (double bx, double by, double tx, double ty, double ancho);

/// Una planta de [ancho] × [alto]: las [hojas] en orden (las primeras, detrás), cada una con contorno, la mitad que da
/// a la luz (arriba a la izquierda) en verde claro y la otra en verde oscuro; y delante, una maceta de [maceta] de
/// [anchoMaceta] × [altoMaceta], centrada abajo.
List<String> dibujarPlanta(
  int ancho,
  int alto,
  List<HojaPixel> hojas, {
  String maceta = 'r',
  int anchoMaceta = 10,
  int altoMaceta = 7,
}) {
  final l = LienzoPixel(ancho, alto);
  for (final (bx, by, tx, ty, w) in hojas) {
    l.hoja(bx, by, tx, ty, w);
  }
  final sombra = PaletaPixel.deClave(maceta)!.sombra!;
  final mx = (ancho - anchoMaceta) ~/ 2;
  final my = alto - altoMaceta;
  // Boca de la maceta y cuerpo, que se estrecha hacia abajo.
  l
    ..caja(mx, my, anchoMaceta, 3, maceta)
    ..lineaH(mx + 1, my + 2, anchoMaceta - 2, sombra);
  for (var j = 3; j < altoMaceta; j++) {
    final hueco = 1 + (j - 3) * 2 ~/ (altoMaceta - 3);
    final x0 = mx + hueco, x1 = mx + anchoMaceta - 1 - hueco;
    l
      ..rect(x0, my + j, x1 - x0 + 1, 1, j == altoMaceta - 1 ? 'N' : maceta)
      ..punto(x0, my + j, 'N')
      ..punto(x1, my + j, 'N');
    if (j < altoMaceta - 1) l.punto(x1 - 1, my + j, sombra);
  }
  return l.filas;
}

/// Planta grande de interior en maceta de barro (18 × 24).
final plantaGrande = dibujarPlanta(18, 24, const [
  (9, 17, 1, 6, 2.6),
  (9, 17, 17, 6, 2.6),
  (9, 17, 9, 0, 2.8),
  (9, 17, -1, 13, 2.3),
  (9, 17, 19, 13, 2.3),
  (9, 17, 4, 9, 2.2),
  (9, 17, 14, 9, 2.2),
]);

/// Planta pequeña en maceta amarilla (10 × 13), para mesas y estanterías.
final plantaPequena = dibujarPlanta(
  10,
  13,
  const [(5, 8, 1, 2, 1.7), (5, 8, 9, 2, 1.7), (5, 8, 5, 0, 1.8)],
  maceta: 'Y',
  anchoMaceta: 8,
  altoMaceta: 5,
);

/// Planta alta de hojas de espada (14 × 26), en maceta azul.
final plantaAlta = dibujarPlanta(
  14,
  26,
  const [
    (6, 20, 2, 4, 2.0),
    (8, 20, 12, 4, 2.0),
    (7, 20, 7, 2, 2.2),
    (6, 20, 0, 10, 1.8),
    (8, 20, 14, 10, 1.8),
    (7, 20, 4, 9, 1.8),
    (7, 20, 10, 9, 1.8),
  ],
  maceta: 'A',
  anchoMaceta: 8,
  altoMaceta: 7,
);

/// La pantalla encendida de una lámpara de pie (12 × 6); el pie se pinta aparte, con líneas.
const pantallaLampara = [
  '..NNNNNNNN..',
  '.NyyyyyyyyN.',
  '.NyyyyyyyYN.',
  'NyyyyyyyyYYN',
  'NyyyyyyyyYYN',
  'NNNNNNNNNNNN',
];

/// Una taza humeante (6 × 7).
const taza = ['.h.h..', 'h.h...', '......', 'NNNNN.', 'NWWhNN', 'NWWhN.', '.NNN..'];

const _nubeGrande = ['....WWW......', '..WWWWWWW.WW.', '.WWWWWWWWWWWW', 'WWWWWWWWWWWWW', '.hhhhhhhhhhh.'];

const _nubePequena = ['..WW....', '.WWWWWW.', 'WWWWWWWW', '.hhhhhh.'];

/// Un cojín de 10 × 7 de [color], con su sombra de la paleta.
List<String> cojinSofa(String color) {
  final sombra = PaletaPixel.deClave(color)!.sombra!;
  return [
    '..NNNNNNN.',
    '.N${color * 6}N.',
    'N${color * 7}${sombra}N',
    'N${color * 3}$sombra${color * 3}${sombra}N',
    'N${color * 7}${sombra}N',
    '.N$color$color$color$sombra$sombra${sombra}N.',
    '..NNNNNNN.',
  ];
}

/// Un vaso de agua (4 × 5).
const vaso = ['NNNN', 'NhcN', 'NccN', 'NccN', '.NN.'];

/// La cámara que graba (12 × 9), en su soporte de pared y mirando hacia abajo a la izquierda: cuerpo gris oscuro con
/// la luz arriba, el objetivo azul cielo con su brillo y la lucecita roja de que graba. La misma en la Sala Gesell y en
/// la sala del Juzgado de Menores (lib/pixel/juzgado).
const camaraPared = [
  '.........NNN',
  '.........NgN',
  '..NNNNNNNNgN',
  '.NNGGGGGGGNN',
  'NNWcNKKKKKKN',
  'NcccNKKKKrKN',
  'NNcNNKKKKKKN',
  '.NNNKKKKKKKN',
  '...NNNNNNNNN',
];
