// Capturas de «¿Quién es quién en el juzgado?» a tamaño de móvil (1080 × 2400, densidad 2,75) con las fuentes
// reales, para revisar cómo se ve. No se ejecuta por defecto:
//
//   CAPTURAS=build/capturas flutter test test/pixel/juzgado/capturas_test.dart
//
// Deja los PNG en la carpeta indicada (build/ no se sube a git). En flutter_test las sombras se pintan sin
// desenfoque: en el móvil salen suaves.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/juzgado/juzgado.dart';
import 'package:tuturno/pixel/motor/motor.dart';
import 'package:tuturno/tema.dart' show temaTuTurno;

import 'ayudantes.dart';

final _destino = Platform.environment['CAPTURAS'];

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

  // Las del tema: Atkinson (lectura fácil), Nunito (el texto), MaryKate (los títulos) y Pixelify (el kit pixel).
  await cargar('AtkinsonHyperlegible', [
    'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
    'assets/fonts/AtkinsonHyperlegible-Bold.ttf',
    'assets/fonts/AtkinsonHyperlegible-Italic.ttf',
    'assets/fonts/AtkinsonHyperlegible-BoldItalic.ttf',
  ]);
  await cargar('PixelifySans', [
    'assets/fonts/PixelifySans-Regular.ttf',
    'assets/fonts/PixelifySans-SemiBold.ttf',
    'assets/fonts/PixelifySans-Bold.ttf',
  ]);
  await cargar('Nunito', [
    'assets/fonts/Nunito-Regular.ttf',
    'assets/fonts/Nunito-SemiBold.ttf',
    'assets/fonts/Nunito-Bold.ttf',
    'assets/fonts/Nunito-ExtraBold.ttf',
  ]);
  await cargar('MaryKate', ['assets/fonts/MaryKate-Medium-ES.ttf']);
  // Los iconos de Material: de FLUTTER_ROOT o de la carpeta de Flutter deducida de flutter_tester.
  final flutter =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  await cargar('MaterialIcons', ['$flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
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

/// Desplaza hacia abajo lo que hay debajo de la sala (la carta).
Future<void> _bajar(WidgetTester tester, double cuanto) async {
  await tester.drag(find.byType(SingleChildScrollView).last, Offset(0, -cuanto));
  await tester.pumpAndSettle();
}

/// Todos los personajes y los muebles, grandes y con sus fotogramas, para revisar el dibujo.
class _Hoja extends StatelessWidget {
  const _Hoja();

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    Widget fila(String titulo, List<Sprite> sprites, {double alto = 132}) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: texto.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final sprite in sprites)
                Expanded(
                  child: SpritePixel(sprite: sprite, alto: alto, animar: false, alineacion: Alignment.bottomCenter),
                ),
            ],
          ),
        ],
      ),
    );
    Sprite fotograma(Sprite sprite, int f) => Sprite('${sprite.nombre} $f', sprite.fotogramas[f]);
    List<Sprite> reparto(ModoJuzgado modo) => [for (final puesto in MontajeJuzgado.de(modo).puestos) puesto.sprite];
    final vistas = reparto(ModoJuzgado.salaVistas);
    final reserva = RepartoJuzgado.todos;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            fila('La sala de vistas (lib/pixel/personajes y el público de aquí)', vistas.sublist(0, 5), alto: 110),
            fila('', vistas.sublist(5), alto: 110),
            fila('El Juzgado de Menores', reparto(ModoJuzgado.menores), alto: 110),
            fila('De reserva, por si falta alguno en lib/pixel/personajes', reserva.sublist(0, 8), alto: 76),
            fila('Quieto, respira y parpadea', [for (var f = 0; f < 3; f++) fotograma(RepartoJuzgado.juezMenores, f)]),
            fila('La chispa (grande y pequeña)', [
              fotograma(MueblesJuzgado.chispa, 0),
              fotograma(MueblesJuzgado.chispa, 1),
            ], alto: 64),
          ],
        ),
      ),
    );
  }
}

void main() {
  setUpAll(() async {
    if (_destino != null) await _cargarFuentes();
  });

  final claro = temaTuTurno(Brightness.light);
  final oscuro = temaTuTurno(Brightness.dark);

  testWidgets('sala de vistas', (tester) async {
    await montarJuzgado(tester, tema: claro);
    await _capturar(tester, 'juzgado-01-sala');
    await tocarRol(tester, 'jueza');
    await _capturar(tester, 'juzgado-02-carta-jueza');
    await tester.ensureVisible(find.text('Qué dice la ley'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Qué dice la ley'));
    await tester.pumpAndSettle();
    await _bajar(tester, 300);
    await _capturar(tester, 'juzgado-03-que-dice-la-ley');
    for (final id in ['fiscal', 'abogadaVictima', 'abogadoDefensa', 'letrada', 'testigo', 'investigada', 'policia']) {
      await tocarRol(tester, id);
    }
    await _capturar(tester, 'juzgado-04-policia');
    await tocarRol(tester, 'publico');
    await _capturar(tester, 'juzgado-05-publico');
    await tester.tap(find.byTooltip('Cerrar'));
    await _capturar(tester, 'juzgado-06-completo');
  }, skip: _destino == null);

  testWidgets('juzgado de menores', (tester) async {
    await montarJuzgado(tester, tema: claro, modo: ModoJuzgado.menores);
    await _capturar(tester, 'juzgado-07-menores');
    // La ficha de alguien a quien aún no conoce: se ilumina en la sala.
    await tester.ensureVisible(find.text('Equipo técnico'));
    await tester.tap(find.text('Equipo técnico'));
    await _capturar(tester, 'juzgado-08-menores-pista');
    await tocarRol(tester, 'equipoTecnico', modo: ModoJuzgado.menores);
    await _capturar(tester, 'juzgado-09-menores-equipo');
    await tocarRol(tester, 'menor', modo: ModoJuzgado.menores);
    await _capturar(tester, 'juzgado-10-menores-chico');
  }, skip: _destino == null);

  testWidgets('tema oscuro', (tester) async {
    await montarJuzgado(tester, tema: oscuro);
    await tocarRol(tester, 'letrada');
    await _capturar(tester, 'juzgado-11-oscuro');
  }, skip: _destino == null);

  testWidgets('letra grande y móvil pequeño', (tester) async {
    await montarJuzgado(tester, tema: claro, letra: 1.3, tamano: const Size(720, 1520), dpr: 2);
    await tocarRol(tester, 'investigada');
    await _capturar(tester, 'juzgado-12-letra-grande');
  }, skip: _destino == null);

  testWidgets('hoja de personajes', (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: claro, home: const _Hoja()));
    await _capturar(tester, 'juzgado-13-reparto');
  }, skip: _destino == null);
}
