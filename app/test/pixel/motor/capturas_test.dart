// Capturas del motor de pixel art a tamaño de móvil (1080 × 2400, densidad 2,75), para revisar cómo se ve. No se
// ejecuta por defecto:
//
//   CAPTURAS=build/capturas flutter test test/pixel/motor/capturas_test.dart
//
// Deja los PNG en la carpeta indicada (build/ no se sube a git).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/motor/motor.dart';
import 'package:tuturno/tema.dart' show temaTuTurno;

import 'muestras.dart';
import '../../fuentes_reales.dart';

final _destino = Platform.environment['CAPTURAS'];

// Del tema solo se usa temaTuTurno (lo están rediseñando): los espacios y el azul noche van aquí.
const _s = 8.0;
const _m = 16.0;
const _l = 24.0;
const _noche = Color(0xFF0E1A4F);

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

Future<void> _montar(WidgetTester tester, Widget pantalla, {Brightness brillo = Brightness.light}) async {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: temaTuTurno(brillo), home: pantalla));
  await tester.pump();
}

/// Un sprite quieto con un fotograma concreto de otro (para enseñar los fotogramas uno al lado del otro).
Sprite _fotograma(Sprite sprite, int fotograma) => Sprite('${sprite.nombre} $fotograma', sprite.fotogramas[fotograma]);

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(_m, _l, _m, _s),
    child: Text(texto, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
  );
}

class _Paleta extends StatelessWidget {
  const _Paleta();

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(_m),
          children: [
            Text('PaletaPixel', style: texto.headlineMedium),
            const SizedBox(height: _s),
            Wrap(
              spacing: _s,
              runSpacing: _s,
              children: [
                for (final color in PaletaPixel.todos)
                  SizedBox(
                    width: 82,
                    child: Column(
                      children: [
                        Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: color.color,
                            border: Border.all(color: _noche, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            color.clave,
                            style: texto.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: color.color.computeLuminance() > 0.3 || color.color.a < 1 ? _noche : Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(color.nombre, style: texto.labelSmall, textAlign: TextAlign.center, maxLines: 2),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Personajes extends StatelessWidget {
  const _Personajes();

  @override
  Widget build(BuildContext context) {
    Widget fila(List<Sprite> sprites, {double alto = 120}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: _m),
      child: Row(
        children: [
          for (final sprite in sprites)
            Expanded(
              child: SpritePixel(sprite: sprite, alto: alto, animar: false, alineacion: Alignment.bottomCenter),
            ),
        ],
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            const _Titulo('Fotogramas: quieto, respira, parpadea'),
            fila([for (var f = 0; f < 3; f++) _fotograma(chico, f)]),
            const _Titulo('Otra silueta (24 × 36) y un bocadillo'),
            fila([for (var f = 0; f < 3; f++) _fotograma(adulta, f), bocadillo]),
            const _Titulo('Variantes con recolorear'),
            fila(variantes.sublist(0, 3), alto: 110),
            const SizedBox(height: _s),
            fila([...variantes.sublist(3), chico.recolorear(PaletaPixel.cambio(PaletaPixel.piel3, PaletaPixel.piel2))]),
            const _Titulo('A pantalla completa (escala entera)'),
            SizedBox(height: 330, child: SpritePixel(sprite: chico, animar: false)),
          ],
        ),
      ),
    );
  }
}

class _Escena extends StatelessWidget {
  const _Escena({this.colorMarco});

  final Color? colorMarco;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorMarco,
      appBar: AppBar(title: const Text('Vive el caso'), backgroundColor: colorMarco),
      body: ListView(
        children: [
          EscenaPixel(
            fondo: sala,
            elementos: elementosSala(),
            alPulsar: (_) {},
            descripcion: 'La sala de espera',
            colorMarco: colorMarco,
            animar: false,
          ),
          Padding(
            padding: const EdgeInsets.all(_m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('La sala de espera', style: texto.headlineSmall?.copyWith(color: esquema.onSurface)),
                const SizedBox(height: _s),
                Text(
                  'Toca a una persona para hablar con ella. El fondo mide 160 × 96 píxeles y se escala a 6 píxeles '
                  'de la pantalla por píxel del dibujo, sin suavizado.',
                  style: texto.bodyLarge?.copyWith(color: esquema.onSurface),
                ),
              ],
            ),
          ),
          const _Titulo('En una caja más alta que ancha: márgenes arriba y abajo'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _m),
            child: SizedBox(
              height: 300,
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border.all(color: esquema.outline)),
                child: EscenaPixel(
                  fondo: sala,
                  elementos: elementosSala(resaltarChico: false),
                  colorMarco: colorMarco,
                  animar: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(() async {
    if (_destino != null) await _cargarFuentes();
  });

  testWidgets('paleta', (tester) async {
    await _montar(tester, const _Paleta());
    await _capturar(tester, 'motor-01-paleta');
  }, skip: _destino == null);

  testWidgets('personajes', (tester) async {
    await _montar(tester, const _Personajes());
    await _capturar(tester, 'motor-02-personajes');
  }, skip: _destino == null);

  testWidgets('escena', (tester) async {
    await _montar(tester, const _Escena());
    await _capturar(tester, 'motor-03-escena');
  }, skip: _destino == null);

  testWidgets('escena en tema oscuro', (tester) async {
    await _montar(tester, const _Escena(colorMarco: _noche), brillo: Brightness.dark);
    await _capturar(tester, 'motor-04-escena-oscuro');
  }, skip: _destino == null);
}
