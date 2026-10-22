// Capturas de las pantallas de A1 con las fuentes reales, para revisar el diseño y para los PR
// («El PR tiene una captura», sección 20). No se ejecuta por defecto:
//
//   CAPTURAS=build/capturas flutter test test/features/a1/capturas_test.dart
//
// En flutter_test las sombras se pintan sin desenfoque (debugDisableShadows): en el móvil salen suaves.
//
// Deja los PNG en la carpeta indicada (build/ no se sube a git).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/app.dart';
import 'package:tuturno/core/config.dart';
import 'package:tuturno/core/content_repo.dart';
import 'package:tuturno/core/progreso.dart';
import 'package:tuturno/core/providers.dart';

import 'helpers.dart';

final _destino = Platform.environment['CAPTURAS'];

/// Un día fijo (jueves 22/10/2026, por la tarde) para que las capturas salgan siempre iguales.
final _tarde = DateTime(2026, 10, 22, 17, 30);

Future<void> _cargarFuentes() async {
  Future<void> cargar(String familia, List<String> rutas) async {
    final cargador = FontLoader(familia);
    for (final ruta in rutas) {
      final bytes = File(ruta).readAsBytesSync();
      cargador.addFont(Future.value(ByteData.sublistView(bytes)));
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
  // FLUTTER_ROOT, o la carpeta de Flutter deducida de flutter_tester (bin/cache/artifacts/engine/<plataforma>/).
  final flutter =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final iconos = '$flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  if (File(iconos).existsSync()) await cargar('MaterialIcons', [iconos]);
}

/// Captura lo que hay en pantalla ahora mismo, sin esperar a que acaben las animaciones.
Future<void> _capturarYa(WidgetTester tester, String nombre) async {
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

Future<void> _capturar(WidgetTester tester, String nombre) async {
  await tester.pumpAndSettle();
  await _capturarYa(tester, nombre);
}

/// Como arrancarApp, pero sin esperar a que acaben las animaciones (para capturar la entrada a mitad).
Future<void> _montarSinEsperar(
  WidgetTester tester, {
  bool bienvenidaVista = true,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = movil * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({if (bienvenidaVista) 'bienvenida_vista': true});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        configProvider.overrideWithValue(const AppConfig(apiUrl: '', useMock: true, demo: false)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        contentProvider.overrideWithValue(
          ContentRepo(bundle: BundleEnMemoria({'${ContentRepo.raiz}/glosario.json': glosarioDePrueba})),
        ),
        ...overrides,
      ],
      child: const TuTurnoApp(),
    ),
  );
  await tester.pump();
}

ProviderContainer _contenedor(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(TuTurnoApp)));

/// Progreso de ejemplo: unas lecciones, cartas y racha, con la última lección ayer.
String _progresoDeEjemplo({bool leccionHoy = false}) => jsonEncode(
  Progreso(
    xp: 140,
    racha: 3,
    ultimoDiaConLeccion: leccionHoy ? DateTime(2026, 10, 22) : DateTime(2026, 10, 21),
    leccionesCompletadas: const {'U1-L1', 'U1-L2'},
    cartas: const {'C-oido', 'C-abogado'},
  ).toJson(),
);

void main() {
  setUpAll(() async {
    if (_destino != null) await _cargarFuentes();
  });

  Future<void> recorrido(WidgetTester tester, String sufijo) async {
    final GoRouter router = await arrancarApp(
      tester,
      bienvenidaVista: false,
      overrides: [relojProvider.overrideWithValue(() => _tarde)],
    );
    await _capturar(tester, '01-bienvenida-1$sufijo');
    await tester.tap(find.text('Siguiente'));
    await _capturar(tester, '02-bienvenida-2$sufijo');
    await tester.tap(find.text('Empezar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 330));
    await _capturarYa(tester, '03a-arranque$sufijo');
    await _capturar(tester, '03-inicio$sufijo');
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -560));
    await _capturar(tester, '04-inicio-abajo$sufijo');
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -3000));
    await _capturar(tester, '04b-inicio-final$sufijo');
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Nivel'));
    await _capturar(tester, '04c-progreso$sufijo');
    router.pop();
    await tester.pumpAndSettle();
    await pulsar(tester, find.text('Mi situación'));
    await _capturar(tester, '05-selector-papel$sufijo');
    await tester.tap(find.text('Testigo'));
    await _capturar(tester, '06-situacion-testigo$sufijo');
    await irA(tester, router, '/ayuda');
    await _capturar(tester, '07-ayuda$sufijo');
    await irA(tester, router, '/glosario');
    await _capturar(tester, '08-glosario$sufijo');
    await irA(tester, router, '/glosario?q=citacion');
    await _capturar(tester, '09-glosario-detalle$sufijo');
    await irA(tester, router, '/ajustes');
    await _capturar(tester, '10-ajustes$sufijo');
  }

  testWidgets('capturas en tema claro', (tester) async {
    await recorrido(tester, '');
  }, skip: _destino == null);

  testWidgets('capturas en tema oscuro', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await recorrido(tester, '-oscuro');
  }, skip: _destino == null);

  for (final brillo in Brightness.values) {
    final sufijo = brillo == Brightness.dark ? '-oscuro' : '';
    testWidgets('capturas del inicio con progreso y la misión cumplida ($brillo)', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brillo;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await arrancarApp(
        tester,
        preferencias: {'progreso': _progresoDeEjemplo()},
        overrides: [relojProvider.overrideWithValue(() => _tarde)],
      );
      await _capturar(tester, '13-inicio-progreso$sufijo');
      // El jueves 22/10 toca «Completa una lección»: se cumple y cae el sello.
      await _contenedor(tester).read(progresoProvider.notifier).completarLeccion('U1-L3');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await _capturarYa(tester, '14a-sello-cayendo$sufijo');
      await _capturar(tester, '14-inicio-cumplida$sufijo');
    }, skip: _destino == null);
  }

  testWidgets('capturas de la entrada de la bienvenida a mitad', (tester) async {
    // La presentación de la bienvenida a mitad (las letras cayendo).
    await _montarSinEsperar(tester, bienvenidaVista: false, overrides: [relojProvider.overrideWithValue(() => _tarde)]);
    await tester.pump(const Duration(milliseconds: 420));
    await _capturarYa(tester, '15a-intro-letras');
    await tester.pump(const Duration(milliseconds: 600));
    await _capturarYa(tester, '15b-intro-lema');
    await tester.pumpAndSettle();
  }, skip: _destino == null);

  testWidgets('capturas del ticket del día saliendo del dispensador', (tester) async {
    // El inicio recién abierto: el ticket saliendo del dispensador y el panel girando.
    await _montarSinEsperar(tester, overrides: [relojProvider.overrideWithValue(() => _tarde)]);
    await tester.pump(const Duration(milliseconds: 520));
    await _capturarYa(tester, '16a-ticket-saliendo');
    await tester.pump(const Duration(milliseconds: 360));
    await _capturarYa(tester, '16b-panel-girando');
    await tester.pumpAndSettle();
  }, skip: _destino == null);

  testWidgets('capturas con letra grande', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final router = await arrancarApp(
      tester,
      preferencias: {'ajustes.tamano_texto': 1.3, 'progreso': _progresoDeEjemplo()},
      tamano: const Size(360, 740),
      overrides: [relojProvider.overrideWithValue(() => _tarde)],
    );
    await _capturar(tester, '20-inicio-letra-grande');
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -600));
    await _capturar(tester, '20b-inicio-letra-grande-abajo');
    await irA(tester, router, '/ayuda');
    await _capturar(tester, '21-ayuda-letra-grande');
    await irA(tester, router, '/ajustes');
    await _capturar(tester, '22-ajustes-letra-grande');
  }, skip: _destino == null);

  testWidgets('capturas de la bienvenida con letra grande en un móvil pequeño', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await arrancarApp(
      tester,
      bienvenidaVista: false,
      preferencias: {'ajustes.tamano_texto': 1.3},
      tamano: const Size(360, 640),
      overrides: [relojProvider.overrideWithValue(() => _tarde)],
    );
    await _capturar(tester, '23-bienvenida-1-letra-grande');
    await tester.tap(find.text('Siguiente'));
    await _capturar(tester, '24-bienvenida-2-letra-grande');
  }, skip: _destino == null);
}
