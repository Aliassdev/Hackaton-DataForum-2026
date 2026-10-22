// Capturas de las escenas de los casos oficiales tal como las verá el juego (EscenaCasoPixel en un móvil de 1080 × 2400,
// densidad 2,75). No se ejecutan por defecto:
//
//   CAPTURAS=build/capturas-escenas flutter test test/pixel/escenas/capturas_test.dart
//
// Deja en la carpeta indicada (build/ no se sube a git) una página por cada tres escenas de cada caso, en tema claro, y
// la primera de cada caso en tema oscuro y a densidad 2,625.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/escenas/escenas.dart';

import '../../fuentes_reales.dart';

import 'package:tuturno/tema.dart' show temaTuTurno;

final _destino = Platform.environment['CAPTURAS'];

/// Las fuentes de la app (Nunito, MaryKate, Atkinson Hyperlegible, Pixelify Sans y los iconos de Material).
Future<void> _cargarFuentes() => cargarFuentesReales();

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

/// (id, lugar, personajes, narración) de las escenas de [archivo].
List<(String, String, List<String>, String)> _escenas(String archivo) => [
  for (final escena in ((jsonDecode(File(archivo).readAsStringSync()) as Map)['escenas'] as List).cast<Map>())
    (
      escena['id'] as String,
      escena['lugar'] as String,
      (escena['personajes'] as List).cast<String>(),
      escena['narracion'] as String,
    ),
];

/// Unas escenas como en el reproductor del caso: la escena arriba y, debajo, el principio de la narración.
class _Pagina extends StatelessWidget {
  const _Pagina(this.escenas);

  final List<(String, String, List<String>, String)> escenas;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final (id, lugar, personajes, narracion) in escenas) ...[
              Text('$id · $lugar', style: tema.textTheme.titleMedium),
              const SizedBox(height: 8),
              EscenaCasoPixel(lugar: lugar, personajes: personajes, animar: false),
              const SizedBox(height: 8),
              Text(narracion, maxLines: 2, overflow: TextOverflow.ellipsis, style: tema.textTheme.bodyMedium),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _montar(
  WidgetTester tester,
  Widget pantalla, {
  Brightness brillo = Brightness.light,
  double dpr = 2.75,
}) async {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: temaTuTurno(brillo), home: pantalla));
  // MaterialApp anima el cambio de tema: que termine antes de capturar.
  await tester.pump(const Duration(milliseconds: 400));
}

/// Las portadas de los casos en la lista: la primera escena, compacta, en una caja de 148 de alto.
class _Portadas extends StatelessWidget {
  const _Portadas(this.escenas);

  final List<(String, String, List<String>, String)> escenas;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (_, lugar, personajes, _) in escenas) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 148,
                child: EscenaCasoPixel(lugar: lugar, personajes: personajes, compacta: true),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    if (_destino != null) await _cargarFuentes();
  });

  testWidgets('portadas de los casos', (tester) async {
    await _montar(
      tester,
      _Portadas([
        _escenas('assets/mock/content/juego/caso-sala-gesell.json').first,
        _escenas('assets/mock/content/juego/caso-acoso-escolar.json').first,
      ]),
    );
    await _capturar(tester, 'portadas');
  }, skip: _destino == null);

  for (final (caso, archivo) in [
    ('lucia', 'assets/mock/content/juego/caso-sala-gesell.json'),
    ('sergio', 'assets/mock/content/juego/caso-acoso-escolar.json'),
  ]) {
    testWidgets('escenas del caso de $caso', (tester) async {
      final escenas = _escenas(archivo);
      for (var i = 0; i < escenas.length; i += 3) {
        await _montar(tester, _Pagina(escenas.sublist(i, i + 3 > escenas.length ? escenas.length : i + 3)));
        await _capturar(tester, '$caso-${i ~/ 3 + 1}');
      }
      await _montar(tester, _Pagina(escenas.take(3).toList()), brillo: Brightness.dark);
      await _capturar(tester, '$caso-oscuro');
      await _montar(tester, _Pagina(escenas.take(3).toList()), dpr: 2.625);
      await _capturar(tester, '$caso-2625');
    }, skip: _destino == null);
  }
}
