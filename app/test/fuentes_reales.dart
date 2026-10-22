// Las fuentes de verdad de la app para las pruebas de capturas (con las de las pruebas, cada letra es un cuadrado). Las
// usan todas las pruebas que guardan PNG con `CAPTURAS=<carpeta>`, para que se vean como en el móvil.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:tuturno/pixel/ui/estilo_pixel.dart' show FuentesPixel;
import 'package:tuturno/tema.dart' show Fuentes;

/// Carga, con los nombres de familia que usa la app: Nunito (sus 4 pesos) como [Fuentes.texto], MaryKate como
/// [Fuentes.titulos], Atkinson Hyperlegible como [Fuentes.lecturaFacil], Pixelify Sans como [FuentesPixel.pixel] y
/// los iconos de Material. Si falta un fichero, esa familia se queda con la letra de las pruebas.
Future<void> cargarFuentesReales() async {
  Future<void> cargar(String familia, List<String> rutas) async {
    final existentes = rutas.where((ruta) => File(ruta).existsSync()).toList();
    if (existentes.isEmpty) return;
    final cargador = FontLoader(familia);
    for (final ruta in existentes) {
      cargador.addFont(Future.value(ByteData.sublistView(File(ruta).readAsBytesSync())));
    }
    await cargador.load();
  }

  await cargar(Fuentes.texto, [
    for (final peso in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) 'assets/fonts/Nunito-$peso.ttf',
  ]);
  await cargar(Fuentes.titulos, ['assets/fonts/MaryKate-Medium-ES.ttf']);
  await cargar(Fuentes.lecturaFacil, [
    'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
    'assets/fonts/AtkinsonHyperlegible-Bold.ttf',
  ]);
  await cargar(FuentesPixel.pixel, [
    for (final peso in ['Regular', 'SemiBold', 'Bold']) 'assets/fonts/PixelifySans-$peso.ttf',
  ]);
  // Los iconos de Material: de FLUTTER_ROOT o de la carpeta de Flutter deducida de flutter_tester.
  final flutter =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  await cargar('MaterialIcons', ['$flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}
