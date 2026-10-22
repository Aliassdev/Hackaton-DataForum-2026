// Capturas de Glosario, Ajustes y Mi situación con la identidad de TuTurno (fuentes reales, glosario e itinerarios de
// ejemplo), para revisar el diseño y para los PR. No se ejecuta por defecto:
//
//   CAPTURAS=build/capturas flutter test test/features/a1/capturas_identidad_test.dart
//
// En flutter_test las sombras se pintan sin desenfoque (debugDisableShadows): en el móvil salen suaves.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/app.dart';
import 'package:tuturno/core/config.dart';
import 'package:tuturno/core/content_repo.dart';
import 'package:tuturno/core/providers.dart';

import '../pregunta/capturas_comunes.dart';
import 'helpers.dart' show BundleEnMemoria;

/// La app con el glosario y los itinerarios de ejemplo (assets/mock/content), como sin content/.
Future<GoRouter> _arrancar(WidgetTester tester, {double escala = 1, Size tamano = const Size(412, 915)}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = tamano * 2;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = escala;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferences.setMockInitialValues({'bienvenida_vista': true});
  final prefs = await SharedPreferences.getInstance();
  String leer(String ruta) => File('${ContentRepo.raizEjemplos}/$ruta').readAsStringSync();
  final ficheros = {
    for (final ruta in ['glosario.json', 'itinerarios/testigo.json', 'itinerarios/victima.json'])
      '${ContentRepo.raiz}/$ruta': leer(ruta),
  };
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        configProvider.overrideWithValue(const AppConfig(apiUrl: '', useMock: true, demo: true)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        contentProvider.overrideWithValue(ContentRepo(bundle: BundleEnMemoria(ficheros))),
      ],
      child: const TuTurnoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(TuTurnoApp))).read(routerProvider);
}

Future<void> _ir(WidgetTester tester, GoRouter router, String ruta) async {
  router.push(ruta);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (destinoCapturas != null) await cargarFuentesReales();
  });

  for (final brillo in Brightness.values) {
    final sufijo = brillo == Brightness.dark ? '-oscuro' : '';

    testWidgets('capturas del glosario ($sufijo)', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brillo;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final router = await _arrancar(tester);
      await _ir(tester, router, '/glosario');
      await capturar(tester, 'glosario-01-lista$sufijo');

      await tester.enterText(find.byType(TextField), 'fiscal');
      await tester.pumpAndSettle();
      await capturar(tester, 'glosario-02-busqueda$sufijo');

      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pumpAndSettle();
      await capturar(tester, 'glosario-03-sin-resultados$sufijo');

      router.pop();
      await tester.pumpAndSettle();
      await _ir(tester, router, '/glosario?q=prueba preconstituida');
      await capturar(tester, 'glosario-04-carta$sufijo');
    }, skip: destinoCapturas == null);

    testWidgets('capturas de ajustes ($sufijo)', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brillo;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final router = await _arrancar(tester);
      await _ir(tester, router, '/ajustes');
      await capturar(tester, 'ajustes-01$sufijo');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      await capturar(tester, 'ajustes-02-abajo$sufijo');
    }, skip: destinoCapturas == null);

    testWidgets('capturas de Mi situación ($sufijo)', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brillo;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final router = await _arrancar(tester);
      // Con los carteles de sala, las tarjetas del inicio son más altas: «Mi situación» puede quedar debajo.
      await tester.ensureVisible(find.text('Mi situación'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mi situación'));
      await tester.pumpAndSettle();
      await capturar(tester, 'situacion-01-selector$sufijo');
      await tester.tap(find.text('Testigo'));
      await tester.pumpAndSettle();
      await capturar(tester, 'situacion-02-testigo$sufijo');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      await capturar(tester, 'situacion-03-pasos$sufijo');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      await capturar(tester, 'situacion-04-abajo$sufijo');
      await _ir(tester, router, '/situacion/investigado');
      await capturar(tester, 'situacion-05-investigado$sufijo');
    }, skip: destinoCapturas == null);
  }

  testWidgets('capturas con letra grande en un móvil pequeño', (tester) async {
    final router = await _arrancar(tester, escala: 1.3, tamano: const Size(360, 740));
    await _ir(tester, router, '/glosario');
    await capturar(tester, 'grande-01-glosario');
    router.pop();
    await tester.pumpAndSettle();
    await _ir(tester, router, '/glosario?q=citacion');
    await capturar(tester, 'grande-02-carta');
    router.pop();
    await tester.pumpAndSettle();
    await _ir(tester, router, '/situacion/victima');
    await capturar(tester, 'grande-03-situacion');
    await _ir(tester, router, '/ajustes');
    await capturar(tester, 'grande-04-ajustes');
  }, skip: destinoCapturas == null);
}
