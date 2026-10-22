// Capturas de Ayuda (abierto y cerrado el 017, claro y oscuro, letra grande) y del glosario de ejemplo, con las
// fuentes reales, para revisar el diseño y los textos y para los PR. No se ejecuta por defecto:
//
//   CAPTURAS=build/capturas-ayuda flutter test test/features/a1/capturas_ayuda_test.dart
//
// En flutter_test las sombras se pintan sin desenfoque (debugDisableShadows): en el móvil salen suaves.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/content_repo.dart';
import 'package:tuturno/core/progreso.dart';

import 'helpers.dart';
import '../../fuentes_reales.dart';

final _destino = Platform.environment['CAPTURAS'];

/// Mediodía y las 23:30 en la península (21/10/2026, UTC+2): el 017, abierto y cerrado.
final _mediodia = DateTime.utc(2026, 10, 21, 10);
final _noche = DateTime.utc(2026, 10, 21, 21, 30);

/// Tan alta que cabe toda la pantalla: una sola imagen por estado.
const _paginaEntera = Size(390, 2900);

/// Las fuentes de la app (Nunito, MaryKate, Atkinson Hyperlegible, Pixelify Sans y los iconos de Material).
Future<void> _cargarFuentes() => cargarFuentesReales();

Future<void> _capturar(WidgetTester tester, String nombre) async {
  await tester.pumpAndSettle();
  // La capa de la vista ya lleva la escala de píxeles: se pinta entera, hojas modales incluidas.
  final capa = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final imagen = await capa.toImage(Offset.zero & tester.view.physicalSize);
    final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
    File('$_destino/$nombre.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    if (_destino != null) await _cargarFuentes();
  });

  Future<void> ayuda(WidgetTester tester, String nombre, DateTime ahora, {Size tamano = _paginaEntera}) async {
    // Una app nueva en cada captura: la anterior se desmonta antes.
    await tester.pumpWidget(const SizedBox.shrink());
    final router = await arrancarApp(tester, tamano: tamano, overrides: [relojProvider.overrideWithValue(() => ahora)]);
    await irA(tester, router, '/ayuda');
    await _capturar(tester, nombre);
  }

  for (final brillo in Brightness.values) {
    final sufijo = brillo == Brightness.dark ? '-oscuro' : '';
    testWidgets('Ayuda, abierta y cerrada ($brillo)', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brillo;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await ayuda(tester, '01-ayuda-abierto$sufijo', _mediodia);
      await ayuda(tester, '02-ayuda-cerrado$sufijo', _noche);
      await ayuda(tester, '03-ayuda-primera-vista$sufijo', _noche, tamano: movil);
    }, skip: _destino == null);
  }

  testWidgets('Ayuda con letra grande en un móvil pequeño (cerrado)', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final router = await arrancarApp(
      tester,
      preferencias: {'ajustes.tamano_texto': 1.3},
      tamano: const Size(360, 3600),
      overrides: [relojProvider.overrideWithValue(() => _noche)],
    );
    await irA(tester, router, '/ayuda');
    await _capturar(tester, '04-ayuda-letra-grande');
  }, skip: _destino == null);

  testWidgets('glosario de ejemplo: la lista y un término', (tester) async {
    final glosario = File('${ContentRepo.raizEjemplos}/glosario.json').readAsStringSync();
    final lista = await arrancarApp(tester, glosario: glosario, tamano: const Size(390, 2400));
    await irA(tester, lista, '/glosario');
    await _capturar(tester, '05-glosario-ejemplo');
    await tester.pumpWidget(const SizedBox.shrink());
    final detalle = await arrancarApp(tester, glosario: glosario);
    await irA(tester, detalle, '/glosario?q=prueba preconstituida');
    await _capturar(tester, '06-glosario-termino');
  }, skip: _destino == null);
}
