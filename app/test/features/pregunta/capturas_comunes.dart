// Utilidades de las pruebas de capturas (Pregunta, Glosario, Ajustes y Mi situación): las fuentes reales de la app y
// guardar la pantalla en un PNG. Solo se usan con `CAPTURAS=<carpeta>`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fuentes_reales.dart' as fuentes;

/// Carpeta de las capturas (`CAPTURAS=build/capturas`), o null si no se piden.
final destinoCapturas = Platform.environment['CAPTURAS'];

/// Las fuentes de la app (Nunito, MaryKate, Atkinson Hyperlegible, Pixelify Sans y los iconos de Material), para que
/// las capturas se vean como en el móvil.
Future<void> cargarFuentesReales() => fuentes.cargarFuentesReales();

/// Guarda lo que hay en pantalla (hojas modales incluidas) en `$CAPTURAS/<nombre>.png`.
Future<void> capturar(WidgetTester tester, String nombre) async {
  final capa = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final imagen = await capa.toImage(Offset.zero & tester.view.physicalSize);
    final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
    File('$destinoCapturas/$nombre.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}
