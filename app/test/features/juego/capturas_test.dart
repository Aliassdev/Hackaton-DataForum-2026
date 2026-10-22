// Capturas de «Vive el caso» con las fuentes reales, para revisar el diseño y para el PR. No se ejecuta por defecto:
//
//   CAPTURAS=build/capturas-juego flutter test test/features/juego/capturas_test.dart
//
// En flutter_test las sombras se pintan sin desenfoque: en el móvil salen suaves.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/features/juego/juego_providers.dart';
import 'package:tuturno/features/juego/textos.dart';

import 'fakes.dart';

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

Future<void> _capturar(WidgetTester tester, String nombre, {bool esperar = true}) async {
  if (esperar) await tester.pumpAndSettle();
  final capa = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final imagen = await capa.toImage(Offset.zero & tester.view.physicalSize);
    final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
    File('$_destino/$nombre.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _elegirCorrecta(WidgetTester tester) async {
  final escena = contenedor(tester).read(partidaProvider('caso-sala-gesell')).value!.escena;
  await pulsar(tester, find.text(escena.decision!.opciones.firstWhere((o) => o.correcta).texto));
}

Future<void> _recoger(WidgetTester tester) async {
  await pulsar(tester, find.text(botonRecogerCarta));
  await pulsar(tester, find.text('¡A mi colección!'));
}

void main() {
  setUpAll(() async {
    if (_destino != null) await _cargarFuentes();
  });

  Map<String, String> casos() => {
    'caso-sala-gesell.json': casoOficialDeEjemplo(),
    'caso-acoso-escolar.json': File('assets/mock/content/juego/caso-acoso-escolar.json').readAsStringSync(),
  };

  Future<void> recorrido(
    WidgetTester tester,
    String sufijo, {
    bool oscuro = false,
    double escala = 1,
    Size tamano = const Size(412, 915),
  }) async {
    final router = await abrirJuego(
      tester,
      oscuro: oscuro,
      escalaTexto: escala,
      tamano: tamano,
      overrides: await overridesJuego(
        casos: casos(),
        preferencias: progresoGuardado(cartas: ['R-centro-protege']),
      ),
    );
    await _capturar(tester, '01-portada$sufijo');
    await tester.scrollUntilVisible(find.text(tituloColeccion), 500, scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
    await _capturar(tester, '02-coleccion$sufijo');

    router.push('/juego/caso-sala-gesell');
    await _capturar(tester, '03-escena-1$sufijo');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await _capturar(tester, '04-decision$sufijo');
    await _elegirCorrecta(tester);
    await _capturar(tester, '05-acierto$sufijo');

    await tester.tap(find.text(botonRecogerCarta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await _capturar(tester, '06-carta-girando$sufijo', esperar: false);
    await _capturar(tester, '07-carta-nueva$sufijo');
    await pulsar(tester, find.text('¡A mi colección!'));
    await _capturar(tester, '08-escena-2$sufijo');

    await pulsar(tester, find.text(botonSeguir));
    await pulsar(tester, find.text(botonSeguir));
    // S4: una respuesta que no es la correcta.
    await pulsar(tester, find.text('Sí, porque esperarán en el mismo pasillo'));
    await _capturar(tester, '09-fallo$sufijo');
    await pulsar(tester, find.text(botonProbarOtraVez));
    await _elegirCorrecta(tester);
    await _recoger(tester);
    await _capturar(tester, '10-sala-gesell$sufijo');

    for (var i = 0; i < 30 && find.text(tituloFinal).evaluate().isEmpty; i++) {
      if (find.text(botonRecogerCarta).evaluate().isNotEmpty) {
        await _recoger(tester);
      } else if (find.text(botonSeguir).evaluate().isNotEmpty) {
        await pulsar(tester, find.text(botonSeguir));
      } else if (find.text(botonTerminar).evaluate().isNotEmpty) {
        await pulsar(tester, find.text(botonTerminar));
      } else {
        await _elegirCorrecta(tester);
      }
    }
    await _capturar(tester, '11-final$sufijo');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await _capturar(tester, '12-final-abajo$sufijo');
  }

  testWidgets('capturas claras', (tester) => recorrido(tester, ''), skip: _destino == null);
  testWidgets('capturas oscuras', (tester) => recorrido(tester, '-oscuro', oscuro: true), skip: _destino == null);
  testWidgets('capturas con letra 1.3', (tester) => recorrido(tester, '-1.3', escala: 1.3), skip: _destino == null);
  testWidgets(
    'capturas en un móvil pequeño, con letra 1.3 y en oscuro',
    (tester) => recorrido(tester, '-pequeno', escala: 1.3, oscuro: true, tamano: const Size(360, 740)),
    skip: _destino == null,
  );
}
