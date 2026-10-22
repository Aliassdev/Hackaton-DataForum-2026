// Capturas de los fondos de «Vive el caso», para revisar cómo se ven. No se ejecutan por defecto:
//
//   CAPTURAS=build/capturas-escenarios flutter test test/pixel/escenarios/capturas_test.dart
//
// Deja en la carpeta indicada (build/ no se sube a git):
// - galeria-N.png: todos los fondos en un móvil de 1080 × 2400 (densidad 2,75), como se verán en la app;
// - reparto-N.png: algunos fondos con figurantes en sus puestos, también a tamaño de móvil;
// - fondos/<lugar>.png: cada fondo suelto a 6 píxeles por píxel (y sus otros fotogramas, si se mueve);
// - fondos/<lugar>-reparto.png: el fondo con figurantes en todos sus puestos, para comprobarlos.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/escenarios/escenarios.dart';
import 'package:tuturno/pixel/motor/motor.dart';
import 'package:tuturno/tema.dart' show temaTuTurno;

import 'figurantes.dart';

final _destino = Platform.environment['CAPTURAS'];

const _m = 16.0;
const _s = 8.0;

Future<void> _cargarFuentes() async {
  Future<void> cargar(String familia, List<String> rutas) async {
    final existentes = rutas.where((ruta) => File(ruta).existsSync()).toList();
    if (existentes.isEmpty) return;
    final cargador = FontLoader(familia);
    for (final ruta in existentes) {
      cargador.addFont(Future.value(ByteData.sublistView(File(ruta).readAsBytesSync())));
    }
    await cargador.load();
  }

  // Las del tema de ahora y las del rediseño (MaryKate para los títulos y Nunito para el texto).
  await cargar('AtkinsonHyperlegible', [
    'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
    'assets/fonts/AtkinsonHyperlegible-Bold.ttf',
  ]);
  await cargar('LondrinaSolid', ['assets/fonts/LondrinaSolid-Regular.ttf', 'assets/fonts/LondrinaSolid-Black.ttf']);
  await cargar('Nunito', [
    'assets/fonts/Nunito-Regular.ttf',
    'assets/fonts/Nunito-SemiBold.ttf',
    'assets/fonts/Nunito-Bold.ttf',
    'assets/fonts/Nunito-ExtraBold.ttf',
  ]);
  await cargar('MaryKate', ['assets/fonts/MaryKate-Medium-ES.ttf']);
}

/// Pinta [fondo] a [escala] píxeles de imagen por píxel del dibujo, con [elementos] encima en ese orden, y lo guarda.
Future<void> _guardar(String nombre, Sprite fondo, {int escala = 6, List<ElementoEscena> elementos = const []}) async {
  final grabadora = ui.PictureRecorder();
  final lienzo = Canvas(grabadora);
  Rect rect(Rect pixel) =>
      Rect.fromLTWH(pixel.left * escala, pixel.top * escala, pixel.width * escala, pixel.height * escala);
  ImagenesPixel.pintar(lienzo, ImagenesPixel.de(fondo), rect(Offset.zero & fondo.tamano));
  for (final elemento in elementos) {
    ImagenesPixel.pintar(lienzo, ImagenesPixel.de(elemento.sprite), rect(elemento.rectPixel), espejo: elemento.espejo);
  }
  final dibujo = grabadora.endRecording();
  final imagen = await dibujo.toImage(fondo.ancho * escala, fondo.alto * escala);
  final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
  File('$_destino/fondos/$nombre.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

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

Future<void> _montar(WidgetTester tester, Widget pantalla) async {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(debugShowCheckedModeBanner: false, theme: temaTuTurno(Brightness.light), home: pantalla),
  );
  await tester.pump();
}

/// Un figurante para cada puesto de un lugar: en la sala de vistas, el reparto entero; en los demás, adultos y niños.
Sprite _figuranteDe(String puesto) => switch (puesto) {
  'jueza' => jueza,
  'letrada' => letrada,
  'fiscal' => fiscal,
  'abogada_victima' => abogadaVictima,
  'abogado_defensa' => abogadoDefensa,
  'persona_investigada' => investigada,
  'testigo' => nina,
  'policia' => policia,
  'publico' => publico,
  'centro' || 'sofa' => nino,
  'izquierda' => tia,
  _ => adulta,
};

/// Lugares y quién se pone en cada uno para las capturas de reparto.
const _repartos = <(String, List<String>)>[
  ('sala_vistas', ['jueza', 'letrada', 'fiscal', 'abogada_victima', 'abogado_defensa', 'testigo']),
  ('sala_vistas', ['jueza', 'persona_investigada', 'abogado_defensa', 'testigo', 'policia', 'publico']),
  ('sala_observacion', ['jueza', 'fiscal', 'abogada_victima', 'abogado_defensa', 'letrada']),
  ('fiscalia', ['fiscal', 'izquierda', 'centro']),
  ('comisaria', ['policia', 'izquierda', 'centro']),
  ('sala_gesell', ['sofa', 'sillon']),
  ('juzgado', ['izquierda', 'centro']),
  ('casa', ['izquierda', 'centro', 'derecha']),
];

class _Galeria extends StatelessWidget {
  const _Galeria(this.lugares);

  final List<String> lugares;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        children: [
          for (final lugar in lugares) ...[
            _Titulo(lugar, EscenariosPixel.de(lugar).descripcion),
            EscenaPixel(
              fondo: EscenariosPixel.de(lugar).fondo,
              descripcion: EscenariosPixel.de(lugar).descripcion,
              animar: false,
            ),
          ],
        ],
      ),
    ),
  );
}

class _Reparto extends StatelessWidget {
  const _Reparto(this.repartos);

  final List<(String, List<String>)> repartos;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        children: [
          for (final (lugar, puestos) in repartos) ...[
            _Titulo(lugar, puestos.join(' · ')),
            Builder(
              builder: (context) {
                final escenario = EscenariosPixel.de(lugar);
                return EscenaPixel(
                  fondo: escenario.fondo,
                  descripcion: escenario.descripcion,
                  animar: false,
                  alPulsar: (_) {},
                  elementos: escenario.componer([
                    for (final puesto in puestos)
                      escenario.colocar(
                        puesto,
                        _figuranteDe(puesto),
                        id: puesto,
                        resaltado: puesto == 'testigo' || puesto == 'centro' || puesto == 'sofa',
                      ),
                  ]),
                );
              },
            ),
          ],
        ],
      ),
    ),
  );
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.titulo, this.texto);

  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final estilos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(_m, _m, _m, _s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: estilos.titleLarge),
          Text(texto, style: estilos.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(() async {
    if (_destino != null) await _cargarFuentes();
  });

  test('cada fondo suelto, a 6 píxeles por píxel, y con figurantes en todos sus puestos', () async {
    for (final lugar in [...EscenariosPixel.lugares, EscenariosPixel.reserva]) {
      final escenario = EscenariosPixel.de(lugar);
      await _guardar(lugar, escenario.fondo);
      for (var f = 1; f < escenario.fondo.fotogramas.length; f++) {
        await _guardar('$lugar-$f', Sprite('$lugar $f', escenario.fondo.fotogramas[f]));
      }
      await _guardar(
        '$lugar-reparto',
        escenario.fondo,
        elementos: escenario.componer([
          for (final puesto in escenario.puestos.keys) escenario.colocar(puesto, _figuranteDe(puesto)),
        ]),
      );
    }
  }, skip: _destino == null);

  const paginas = [
    ['casa', 'colegio', 'instituto'],
    ['juzgado', 'sala_espera', 'sala_gesell'],
    ['sala_observacion', 'sala_vistas', 'fiscalia'],
    ['comisaria', 'habitacion', 'despues'],
    ['generico'],
  ];
  for (final (i, lugares) in paginas.indexed) {
    testWidgets('galería ${i + 1}: ${lugares.join(', ')}', (tester) async {
      await _montar(tester, _Galeria(lugares));
      await _capturar(tester, 'galeria-${i + 1}');
    }, skip: _destino == null);
  }

  for (var i = 0; i < _repartos.length; i += 3) {
    final repartos = _repartos.sublist(i, i + 3 > _repartos.length ? _repartos.length : i + 3);
    testWidgets('reparto ${i ~/ 3 + 1}', (tester) async {
      await _montar(tester, _Reparto(repartos));
      await _capturar(tester, 'reparto-${i ~/ 3 + 1}');
    }, skip: _destino == null);
  }
}
