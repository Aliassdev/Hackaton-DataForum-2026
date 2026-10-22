// Capturas de la galería de iconos y de Tut, para revisar el diseño. No se ejecuta por defecto:
//
//   CAPTURAS=build/capturas flutter test test/widgets/iconos/capturas_test.dart
//
// Deja los PNG en la carpeta indicada (build/ no se sube a git).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/iconos/iconos.dart';

final _destino = Platform.environment['CAPTURAS'];

/// Carga las familias de letra del pubspec que existan en assets/fonts/ (en los tests no se cargan solas).
Future<void> _cargarFuentes() async {
  final familias = {
    'AtkinsonHyperlegible': [
      'AtkinsonHyperlegible-Regular.ttf',
      'AtkinsonHyperlegible-Bold.ttf',
      'AtkinsonHyperlegible-Italic.ttf',
      'AtkinsonHyperlegible-BoldItalic.ttf',
    ],
    'LondrinaSolid': ['LondrinaSolid-Regular.ttf', 'LondrinaSolid-Black.ttf'],
  };
  for (final MapEntry(key: familia, value: ficheros) in familias.entries) {
    final cargador = FontLoader(familia);
    var alguno = false;
    for (final fichero in ficheros) {
      final ruta = File('assets/fonts/$fichero');
      if (!ruta.existsSync()) continue;
      alguno = true;
      cargador.addFont(Future.value(ByteData.sublistView(ruta.readAsBytesSync())));
    }
    if (alguno) await cargador.load();
  }
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

Future<void> _mostrar(WidgetTester tester, Widget contenido, {required Brightness brillo, required Size tamano}) async {
  tester.view
    ..devicePixelRatio = 2
    ..physicalSize = tamano * 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: temaTuTurno(brillo),
      home: Scaffold(body: contenido),
    ),
  );
}

/// Hoja grande de Tut: todas las expresiones a 200 px.
class _HojaTut extends StatelessWidget {
  const _HojaTut();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Wrap(
      spacing: 24,
      runSpacing: 24,
      children: [
        for (final expresion in ExpresionTut.values)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MascotaTut(expresion: expresion, size: 200, animada: false),
              Text(expresion.name, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
      ],
    ),
  );
}

/// Iconos grandes, para ver el detalle.
class _HojaGrande extends StatelessWidget {
  const _HojaGrande({required this.desde, required this.hasta});

  final int desde;
  final int hasta;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Wrap(
      spacing: 28,
      runSpacing: 28,
      children: [
        for (final icono in TuIcono.values.sublist(desde, hasta))
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconoTuTurno(icono, size: 120),
              Text(icono.name, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
      ],
    ),
  );
}

void main() {
  setUpAll(() async {
    if (_destino != null) await _cargarFuentes();
  });

  for (final (brillo, sufijo) in [(Brightness.light, ''), (Brightness.dark, '-oscuro')]) {
    testWidgets('galería$sufijo', (tester) async {
      await _mostrar(tester, const GaleriaIconos(), brillo: brillo, tamano: const Size(1000, 2800));
      await _capturar(tester, 'iconos-galeria$sufijo');
    }, skip: _destino == null);

    testWidgets('Tut en grande$sufijo', (tester) async {
      await _mostrar(tester, const _HojaTut(), brillo: brillo, tamano: const Size(1000, 760));
      await _capturar(tester, 'iconos-tut$sufijo');
    }, skip: _destino == null);

    testWidgets('iconos en grande$sufijo', (tester) async {
      final mitad = (TuIcono.values.length / 2).ceil();
      await _mostrar(
        tester,
        _HojaGrande(desde: 0, hasta: mitad),
        brillo: brillo,
        tamano: const Size(1000, 900),
      );
      await _capturar(tester, 'iconos-grandes-1$sufijo');
      await _mostrar(
        tester,
        _HojaGrande(desde: mitad, hasta: TuIcono.values.length),
        brillo: brillo,
        tamano: const Size(1000, 900),
      );
      await _capturar(tester, 'iconos-grandes-2$sufijo');
    }, skip: _destino == null);
  }
}
