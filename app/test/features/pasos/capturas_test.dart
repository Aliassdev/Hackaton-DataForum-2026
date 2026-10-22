// Capturas de la línea de pasos con las fuentes reales y el itinerario de víctima que lleva la app, para revisar el
// diseño y para el PR («El PR tiene una captura», sección 20). No se ejecuta por defecto:
//
//   CAPTURAS=build/capturas-pasos flutter test test/features/pasos/capturas_test.dart
//
// En flutter_test las sombras se pintan sin desenfoque: en el móvil salen suaves.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/features/pasos/fuentes_paso.dart';
import 'package:tuturno/features/pasos/pasos.dart';

import 'datos.dart';

final _destino = Platform.environment['CAPTURAS'];

Future<void> _cargarFuentes() async {
  Future<void> cargar(String familia, List<String> rutas) async {
    final cargador = FontLoader(familia);
    for (final ruta in rutas) {
      cargador.addFont(Future.value(ByteData.sublistView(File(ruta).readAsBytesSync())));
    }
    await cargador.load();
  }

  await cargar('AtkinsonHyperlegible', [
    'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
    'assets/fonts/AtkinsonHyperlegible-Bold.ttf',
    'assets/fonts/AtkinsonHyperlegible-Italic.ttf',
    'assets/fonts/AtkinsonHyperlegible-BoldItalic.ttf',
  ]);
  await cargar('LondrinaSolid', ['assets/fonts/LondrinaSolid-Regular.ttf', 'assets/fonts/LondrinaSolid-Black.ttf']);
  final flutter =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final iconos = '$flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  if (File(iconos).existsSync()) await cargar('MaterialIcons', [iconos]);
}

Future<void> _capturar(WidgetTester tester, String nombre) async {
  await tester.pumpAndSettle();
  final capa = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final imagen = await capa.toImage(Offset.zero & tester.view.physicalSize);
    final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
    File('$_destino/$nombre.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _abrir(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (_destino != null) await _cargarFuentes();
  });

  Future<void> recorrido(WidgetTester tester, Brightness brillo) async {
    final sufijo = brillo == Brightness.dark ? '-oscuro' : '';
    await montarLinea(tester, repo: repoDeLaApp(), faseActual: Fase.durante, brillo: brillo);
    await _capturar(tester, '01-linea$sufijo');

    final declaracion = find.bySemanticsLabel(RegExp(r'^Paso 4 de '));
    await _abrir(tester, declaracion);
    await tester.ensureVisible(declaracion);
    await _capturar(tester, '02-paso-abierto$sufijo');

    await tester.ensureVisible(find.byType(ChipFuentePaso).last);
    await _capturar(tester, '03-fuentes$sufijo');

    await _abrir(tester, find.byType(ChipFuentePaso).first);
    await _capturar(tester, '04-hoja-fuente$sufijo');
  }

  testWidgets('capturas en tema claro', (tester) async {
    await recorrido(tester, Brightness.light);
  }, skip: _destino == null);

  testWidgets('capturas en tema oscuro', (tester) async {
    await recorrido(tester, Brightness.dark);
  }, skip: _destino == null);

  testWidgets('capturas con letra grande en un móvil pequeño, y sin pasos', (tester) async {
    await montarLinea(
      tester,
      repo: repoDeLaApp(),
      faseActual: Fase.antes,
      escalaTexto: 1.3,
      tamano: const Size(320, 640),
    );
    await _abrir(tester, find.bySemanticsLabel(RegExp(r'^Paso 1 de ')));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await _capturar(tester, '05-letra-grande');

    await montarLinea(tester, repo: repoCon({}).$1, rol: 'testigo');
    await _capturar(tester, '06-sin-pasos');
  }, skip: _destino == null);
}
