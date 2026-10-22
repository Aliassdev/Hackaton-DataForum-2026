import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/motor/motor.dart';

/// Clave del RepaintBoundary que envuelve lo que se monta (para leer sus píxeles con [leerPixeles]).
const claveCaptura = ValueKey('captura');

/// Monta [hijo] en una pantalla de [tamano] puntos con densidad [dpr], sobre papel y dentro de un RepaintBoundary
/// ([claveCaptura]). Con [reducir], como un móvil con «reducir animaciones». Para leer píxeles exactos, el tamaño de
/// [hijo] en píxeles físicos debe ser entero (si no, el último píxel del borde sale mezclado).
Future<void> montar(
  WidgetTester tester,
  Widget hijo, {
  double dpr = 2.75,
  Size tamano = const Size(400, 800),
  bool reducir = false,
  bool centrar = true,
}) async {
  tester.view
    ..devicePixelRatio = dpr
    ..physicalSize = tamano * dpr;
  addTearDown(tester.view.reset);
  // El papel va dentro del RepaintBoundary: así sale en los píxeles que se leen.
  final contenido = RepaintBoundary(
    key: claveCaptura,
    child: ColoredBox(color: PaletaPixel.papel.color, child: hijo),
  );
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reducir),
          child: ColoredBox(
            color: PaletaPixel.papel.color,
            child: centrar ? Center(child: contenido) : contenido,
          ),
        ),
      ),
    ),
  );
}

/// Los píxeles (en píxeles físicos) de lo que hay dentro del RepaintBoundary de [claveCaptura] o de [de].
Future<Lamina> leerPixeles(WidgetTester tester, {Finder? de}) async {
  final caja = tester.renderObject<RenderRepaintBoundary>(de ?? find.byKey(claveCaptura));
  final dpr = tester.view.devicePixelRatio;
  final lamina = await tester.runAsync(() async {
    final imagen = await caja.toImage(pixelRatio: dpr);
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    final lamina = Lamina(imagen.width, imagen.height, datos!);
    imagen.dispose();
    return lamina;
  });
  return lamina!;
}

/// Una imagen leída, para preguntar por el color de cada píxel.
class Lamina {
  Lamina(this.ancho, this.alto, this.datos);

  final int ancho;
  final int alto;
  final ByteData datos;

  Color en(int x, int y) {
    final i = (y * ancho + x) * 4;
    return Color.fromARGB(datos.getUint8(i + 3), datos.getUint8(i), datos.getUint8(i + 1), datos.getUint8(i + 2));
  }

  /// Los colores distintos de un rectángulo.
  Set<int> colores(int x0, int y0, int x1, int y1) => {
    for (var y = y0; y < y1; y++)
      for (var x = x0; x < x1; x++) en(x, y).toARGB32(),
  };
}

/// Lee una imagen de un sprite (un píxel por píxel del dibujo).
Future<Lamina> leerImagen(ui.Image imagen) async {
  final datos = await imagen.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  return Lamina(imagen.width, imagen.height, datos!);
}

/// El color de la paleta de [clave], para comparar.
Color colorDe(String clave) => PaletaPixel.deClave(clave)!.color;
