// Capturas de Ajustes («Leer mejor», «Tu ticket», «Tus datos») y de «Para el equipo (demo)» con las fuentes de
// verdad, para revisar el diseño. No se ejecuta por defecto:
//
//   CAPTURAS=build/capturas flutter test test/features/ajustes/capturas_ajustes_test.dart
//
// En flutter_test las sombras se pintan sin desenfoque (debugDisableShadows): en el móvil salen suaves.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fuentes_reales.dart';
import 'ayudas_ajustes.dart';

/// Carpeta de las capturas (`CAPTURAS=build/capturas`), o null si no se piden.
final _destino = Platform.environment['CAPTURAS'];

Future<void> _capturar(WidgetTester tester, String nombre) async {
  final capa = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final imagen = await capa.toImage(Offset.zero & tester.view.physicalSize);
    final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
    File('$_destino/$nombre.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _bajar(WidgetTester tester, double cuanto) async {
  await tester.drag(find.byType(Scrollable).first, Offset(0, -cuanto));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (_destino != null) await cargarFuentesReales();
  });

  const ticket = {'edad': 13, 'procedimiento': 'penal', 'rol': 'victima', 'fase': 'durante'};

  for (final brillo in Brightness.values) {
    final sufijo = brillo == Brightness.dark ? '-oscuro' : '';

    testWidgets('capturas de Ajustes ($sufijo)', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brillo;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = await arrancarAjustes(
        tester,
        demo: true,
        preferencias: {'entrada': jsonEncode(ticket), 'ajustes.reducir_movimiento': true},
      );
      await abrir(tester, router, '/ajustes');
      await _capturar(tester, 'ajustes-b5-01-leer-mejor$sufijo');
      await _bajar(tester, 700);
      await _capturar(tester, 'ajustes-b5-02-ticket-datos$sufijo');
      await _bajar(tester, 3000);
      await _capturar(tester, 'ajustes-b5-03-acerca-de$sufijo');

      await revelarEquipo(tester);
      await _capturar(tester, 'ajustes-b5-04-equipo$sufijo');
      await _bajar(tester, 650);
      await _capturar(tester, 'ajustes-b5-05-atajos$sufijo');
      await _bajar(tester, 650);
      await tocar(tester, find.widgetWithText(FilledButton, 'Comprobar'));
      await _capturar(tester, 'ajustes-b5-06-comprobar$sufijo');

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
      await revelarEquipo(tester);
      await tocar(tester, find.widgetWithText(FilledButton, 'Preparar demo'));
      await _capturar(tester, 'ajustes-b5-07-preparar$sufijo');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tocar(tester, find.text('Borrar todo lo de este móvil'));
      await _capturar(tester, 'ajustes-b5-08-borrar-todo$sufijo');
    }, skip: _destino == null);
  }

  testWidgets('capturas de Ajustes con letra grande y lectura fácil en un móvil pequeño', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = await arrancarAjustes(
      tester,
      demo: true,
      tamano: const Size(360, 740),
      preferencias: {
        'entrada': jsonEncode(ticket),
        'ajustes.tamano_texto': 1.3,
        'ajustes.lectura_facil': true,
        'ajustes.reducir_movimiento': true,
      },
    );
    await abrir(tester, router, '/ajustes');
    await _capturar(tester, 'ajustes-b5-10-grande');
    await _bajar(tester, 900);
    await _capturar(tester, 'ajustes-b5-11-grande');
    await revelarEquipo(tester);
    await _bajar(tester, 900);
    await _capturar(tester, 'ajustes-b5-12-grande-atajos');
  }, skip: _destino == null);
}
