import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/tema.dart';

/// Un móvil corriente: 390 × 844 puntos (la unidad pixel es 3).
const tamanoMovil = Size(390, 844);

/// Un tema por brillo, siempre el mismo objeto (si cambiara, MaterialApp animaría el cambio de tema).
final _temas = {for (final brillo in Brightness.values) brillo: temaTuTurno(brillo)};

/// Monta [child] con el tema de TuTurno en una pantalla de móvil, con margen alrededor. Con [reducir], como si el
/// sistema pidiera reducir animaciones; [escalaTexto] simula el tamaño de letra del sistema.
Future<void> montar(
  WidgetTester tester,
  Widget child, {
  bool reducir = false,
  Brightness brillo = Brightness.light,
  double escalaTexto = 1,
  Size tamano = tamanoMovil,
  double dpr = 3,
  bool centrar = true,
}) async {
  ponerPantalla(tester, tamano, dpr: dpr);
  await tester.pumpWidget(
    MaterialApp(
      theme: _temas[brillo],
      debugShowCheckedModeBanner: false,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducir, textScaler: TextScaler.linear(escalaTexto)),
        child: app!,
      ),
      home: Scaffold(
        body: centrar
            ? Center(
                child: Padding(padding: const EdgeInsets.all(16), child: child),
              )
            : child,
      ),
    ),
  );
  // MaterialApp pide un fotograma más al arrancar; con este, lo único que puede quedar pendiente es nuestro.
  await tester.pump();
}

/// Pone la pantalla de pruebas a [tamano] puntos con densidad [dpr] (y la deja como estaba al acabar).
void ponerPantalla(WidgetTester tester, Size tamano, {double dpr = 3}) {
  tester.view
    ..devicePixelRatio = dpr
    ..physicalSize = tamano * dpr;
  addTearDown(tester.view.reset);
}

/// Apunta las vibraciones que se piden a la plataforma («HapticFeedbackType.lightImpact»…).
List<String> registrarVibraciones(WidgetTester tester) {
  final vibraciones = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (llamada) async {
    if (llamada.method == 'HapticFeedback.vibrate') vibraciones.add(llamada.arguments as String);
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return vibraciones;
}

/// Quita el widget a mitad de lo que esté haciendo: no debe quedar nada vivo (controladores ni temporizadores).
Future<void> desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  expect(tester.takeException(), isNull);
  expect(tester.binding.hasScheduledFrame, isFalse);
}

/// Píxeles RGBA de un trozo de la pantalla, fila a fila.
class PixelesPantalla {
  PixelesPantalla(this.datos, this.ancho, this.alto);

  final ByteData datos;
  final int ancho;
  final int alto;

  /// El color (RGBA) del píxel ([x], [y]).
  int pixel(int x, int y) => datos.getUint32((y * ancho + x) * 4);

  Iterable<int> get todos sync* {
    for (var i = 0; i < datos.lengthInBytes; i += 4) {
      yield datos.getUint32(i);
    }
  }
}

/// Cuántos píxeles físicos de exactamente [color] se ven en el sitio de [objetivo] (ver [leerPixeles]).
Future<int> contarPixeles(WidgetTester tester, Finder objetivo, Color color) async {
  final buscado = _rgba(color);
  return (await leerPixeles(tester, objetivo)).todos.where((pixel) => pixel == buscado).length;
}

/// Los colores distintos (RGBA) que se ven en el sitio de [objetivo].
Future<Set<int>> coloresPintados(WidgetTester tester, Finder objetivo) async =>
    (await leerPixeles(tester, objetivo)).todos.toSet();

int _rgba(Color color) {
  int canal(double valor) => (valor * 255).round() & 0xFF;
  return canal(color.r) << 24 | canal(color.g) << 16 | canal(color.b) << 8 | canal(color.a);
}

/// [color] como RGBA de 32 bits (lo que devuelven [coloresPintados] y [PixelesPantalla.pixel]).
int rgba(Color color) => _rgba(color);

/// Los píxeles de la pantalla, tal como se ven, en el rectángulo del RepaintBoundary más cercano por encima de
/// [objetivo] (para que quepa lo que se pinta por fuera, como el anillo de foco) o, si no hay, en el suyo.
///
/// Se recortan de la pantalla entera, no de la capa del RepaintBoundary: el ajuste a los píxeles físicos
/// (AjustePixel) es respecto a la pantalla, así que solo ahí se ve lo mismo que en un móvil (también con Impeller).
Future<PixelesPantalla> leerPixeles(WidgetTester tester, Finder objetivo) async {
  final elemento = tester.element(objetivo);
  RenderBox? caja;
  final propio = elemento.renderObject;
  if (propio is RenderRepaintBoundary) {
    caja = propio;
  } else {
    elemento.visitAncestorElements((ancestro) {
      final objeto = ancestro.renderObject;
      if (objeto is RenderRepaintBoundary) {
        caja = objeto;
        return false;
      }
      return true;
    });
  }
  final medida = caja ?? propio! as RenderBox;
  final rect = MatrixUtils.transformRect(medida.getTransformTo(null), Offset.zero & medida.size);
  final dpr = tester.view.devicePixelRatio;
  final capa = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  final pantalla = await tester.runAsync(() async {
    final imagen = await capa.toImage(Offset.zero & tester.view.physicalSize);
    final bytes = await imagen.toByteData();
    final resultado = (bytes!, imagen.width, imagen.height);
    imagen.dispose();
    return resultado;
  });
  final (bytes, anchoPantalla, altoPantalla) = pantalla!;
  final izquierda = (rect.left * dpr).round().clamp(0, anchoPantalla);
  final arriba = (rect.top * dpr).round().clamp(0, altoPantalla);
  final derecha = (rect.right * dpr).round().clamp(izquierda, anchoPantalla);
  final abajo = (rect.bottom * dpr).round().clamp(arriba, altoPantalla);
  final ancho = derecha - izquierda;
  final alto = abajo - arriba;
  final recorte = ByteData(ancho * alto * 4);
  for (var y = 0; y < alto; y++) {
    for (var x = 0; x < ancho; x++) {
      recorte.setUint32((y * ancho + x) * 4, bytes.getUint32(((arriba + y) * anchoPantalla + izquierda + x) * 4));
    }
  }
  return PixelesPantalla(recorte, ancho, alto);
}

/// Carga Pixelify Sans (normal, 600 y 700) como 'PixelifySans' y Atkinson Hyperlegible, para las capturas.
Future<void> cargarFuentesPixel() async {
  Future<void> cargar(String familia, List<String> rutas) async {
    final cargador = FontLoader(familia);
    for (final ruta in rutas) {
      final bytes = File(ruta).readAsBytesSync();
      cargador.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await cargador.load();
  }

  await cargar('PixelifySans', [
    'assets/fonts/PixelifySans-Regular.ttf',
    'assets/fonts/PixelifySans-SemiBold.ttf',
    'assets/fonts/PixelifySans-Bold.ttf',
  ]);
  await cargar('AtkinsonHyperlegible', [
    'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
    'assets/fonts/AtkinsonHyperlegible-Bold.ttf',
  ]);
}

/// Guarda una captura PNG de toda la pantalla en [ruta].
Future<void> capturarPantalla(WidgetTester tester, String ruta) async {
  final capa = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final imagen = await capa.toImage(Offset.zero & tester.view.physicalSize);
    final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
    imagen.dispose();
    File(ruta)
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}
