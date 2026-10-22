// Capturas de los personajes de «Vive el caso» a tamaño de móvil (1080 × 2400, densidad 2,75), para revisar cómo se
// ven. No se ejecuta por defecto:
//
//   CAPTURAS=build/capturas flutter test test/pixel/personajes/capturas_test.dart
//
// Deja los PNG en la carpeta indicada (build/ no se sube a git).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/motor/motor.dart';
import 'package:tuturno/pixel/personajes/personajes.dart';
import 'package:tuturno/tema.dart' show temaTuTurno;

final _destino = Platform.environment['CAPTURAS'];

const _dpr = 2.75;

// Del tema solo se usa temaTuTurno (lo están rediseñando): los espacios y los colores de la marca van aquí.
const _s = 8.0;
const _m = 16.0;
const _noche = Color(0xFF0E1A4F);
const _papel = Color(0xFFFFFBEF);

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

  // Las del tema de ahora y las del rediseño (MaryKate para títulos y Nunito para el texto).
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
    ..devicePixelRatio = _dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: temaTuTurno(brillo), home: pantalla));
  await tester.pump();
}

/// Un sprite quieto con un fotograma concreto de otro.
Sprite _fotograma(Sprite sprite, int fotograma) => Sprite('${sprite.nombre} $fotograma', sprite.fotogramas[fotograma]);

/// [sprite] a [fisicos] píxeles de la pantalla por píxel del dibujo: todos a la misma escala, para compararlos.
Widget _aEscala(Sprite sprite, int fisicos) => SpritePixel(
  sprite: sprite,
  ancho: sprite.ancho * fisicos / _dpr,
  alto: sprite.alto * fisicos / _dpr,
  animar: false,
);

/// Una fila de personajes de pie sobre el mismo suelo, a la misma escala, con su nombre debajo.
class _Fila extends StatelessWidget {
  const _Fila(this.ids);

  final List<String> ids;

  /// Píxeles de la pantalla por píxel del dibujo: la misma escala para todos.
  static const fisicos = 11;
  static const suelo = Color(0xFFF1E6CC);

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final alto = 36 * fisicos / _dpr;
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(height: 9 * fisicos / _dpr, color: suelo),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final id in ids)
                  SizedBox(
                    height: alto,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: _aEscala(PersonajesPixel.porId(id)!, fisicos),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: _s),
        Row(
          children: [
            for (final id in ids)
              Expanded(
                child: Text(
                  PersonajesPixel.ficha(id)!.nombre,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  style: texto.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Galeria extends StatelessWidget {
  const _Galeria({required this.titulo, required this.subtitulo, required this.filas});

  final String titulo;
  final String subtitulo;
  final List<List<String>> filas;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: _m),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _m),
              child: Text(titulo, style: texto.headlineMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(_m, _s, _m, _m),
              child: Text(subtitulo, style: texto.bodyLarge),
            ),
            for (final fila in filas) ...[_Fila(fila), const SizedBox(height: 28)],
          ],
        ),
      ),
    );
  }
}

class _Fotogramas extends StatelessWidget {
  const _Fotogramas(this.ids);

  final List<String> ids;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(_m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quieto · respira · parpadea', style: texto.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: _s),
              for (final id in ids)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 104,
                        child: Text(PersonajesPixel.ficha(id)!.nombre, maxLines: 2, style: texto.labelLarge),
                      ),
                      for (var f = 0; f < 3; f++)
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: _aEscala(_fotograma(PersonajesPixel.porId(id)!, f), 6),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fondo de prueba de una sala de espera (160 × 96): pared crema a rayas, zócalo azul, suelo de madera, ventana y una
/// planta. Solo sirve para ver a los personajes en su sitio; los fondos de verdad son de otro equipo.
final _salaEspera = () {
  final l = LienzoPixel(160, 96, 'P')
    ..mosaico(['PPPPPPp'], 0, 0, 160, 46)
    ..rect(0, 46, 160, 16, 'c')
    ..lineaH(0, 46, 160, 'W')
    ..lineaH(0, 61, 160, 'a')
    ..rect(0, 62, 160, 34, 'm')
    ..lineaH(0, 62, 160, 't');
  for (var y = 70; y < 96; y += 8) {
    l.lineaH(0, y, 160, 't');
  }
  for (var y = 63, i = 0; y < 96; y += 8, i++) {
    for (var x = (i * 29) % 48; x < 160; x += 48) {
      l.lineaV(x, y, 7, 't');
    }
  }
  l
    ..rect(100, 10, 40, 26, 'c')
    ..rect(101, 11, 38, 8, 'h')
    ..marco(100, 10, 40, 26, 'N')
    ..lineaV(120, 11, 24, 'N')
    ..lineaH(98, 36, 44, 'N')
    ..pegar(
      [
        '..NNNN..',
        '.NvvvVN.',
        'NvvVvvVN',
        'NvVvvVvN',
        '.NVvVVN.',
        '..NNNN..',
        '..NRRN..',
        '.NrrrRN.',
        '.NrrrRN.',
        '..NNNN..',
      ],
      6,
      52,
    );
  return Sprite('sala de espera de prueba', l.filas);
}();

/// Fondo de prueba de una sala de vistas: pared con paneles de madera y suelo gris.
final _salaVistas = () {
  final l = LienzoPixel(160, 96, 'p')
    ..rect(0, 30, 160, 32, 'm')
    ..lineaH(0, 30, 160, 'o')
    ..lineaH(0, 31, 160, 't')
    ..rect(0, 62, 160, 34, 'g')
    ..lineaH(0, 62, 160, 'G');
  for (var x = 8; x < 160; x += 24) {
    l.marco(x, 36, 16, 20, 't');
  }
  for (var y = 70; y < 96; y += 9) {
    l.lineaH(0, y, 160, 'G');
  }
  return Sprite('sala de vistas de prueba', l.filas);
}();

/// La mesa de la jueza (el estrado), delante de ella.
final _estrado = Sprite('estrado', [
  for (var y = 0; y < 14; y++)
    switch (y) {
      0 => 'N' * 44,
      1 => 'N${'y' * 42}N',
      2 => 'N${'m' * 42}N',
      13 => 'N' * 44,
      _ => 'Nm${'t' * 40}tN',
    },
]);

class _Escena extends StatelessWidget {
  const _Escena({this.oscuro = false});

  final bool oscuro;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final marco = oscuro ? _noche : _papel;
    return Scaffold(
      backgroundColor: marco,
      appBar: AppBar(title: const Text('Vive el caso'), backgroundColor: marco),
      body: ListView(
        children: [
          EscenaPixel(
            fondo: _salaEspera,
            colorMarco: marco,
            animar: false,
            alPulsar: (_) {},
            descripcion: 'La sala de espera del juzgado',
            elementos: [
              ElementoEscena(sprite: PersonajesPixel.ana, x: 40, y: 88, id: 'ana'),
              ElementoEscena(sprite: PersonajesPixel.tut, x: 132, y: 70),
              ElementoEscena(sprite: PersonajesPixel.elena, x: 108, y: 90, id: 'elena', espejo: true),
              ElementoEscena(sprite: PersonajesPixel.lucia, x: 80, y: 93, id: 'lucia', resaltado: true),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(_m),
            child: Text(
              'Ana recibe a Lucía y a su tía Elena en la sala de espera. Toca a Lucía para empezar.',
              style: texto.bodyLarge?.copyWith(color: esquema.onSurface),
            ),
          ),
          EscenaPixel(
            fondo: _salaVistas,
            colorMarco: marco,
            animar: false,
            alPulsar: (_) {},
            descripcion: 'La sala de vistas',
            elementos: [
              ElementoEscena(sprite: PersonajesPixel.jueza, x: 80, y: 66, id: 'jueza'),
              ElementoEscena(sprite: _estrado, x: 80, y: 70),
              ElementoEscena(sprite: PersonajesPixel.letrada, x: 128, y: 70, id: 'letrada', espejo: true),
              ElementoEscena(sprite: PersonajesPixel.policia, x: 150, y: 80, id: 'policia', espejo: true),
              ElementoEscena(sprite: PersonajesPixel.fiscal, x: 22, y: 90, id: 'fiscal'),
              ElementoEscena(sprite: PersonajesPixel.abogadaVictima, x: 48, y: 92, id: 'abogada-victima'),
              ElementoEscena(sprite: PersonajesPixel.testigo, x: 80, y: 94, id: 'testigo', resaltado: true),
              ElementoEscena(
                sprite: PersonajesPixel.abogadoDefensa,
                x: 116,
                y: 92,
                id: 'abogado-defensa',
                espejo: true,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(_m),
            child: Text(
              'En la sala de vistas: la jueza en el estrado, la letrada, el policía, el fiscal, las abogadas y '
              'el testigo.',
              style: texto.bodyLarge?.copyWith(color: esquema.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

/// Los retratos de todos y unos diálogos de muestra (con widgets sencillos: la ventana de diálogo de verdad es de otro
/// equipo).
class _Retratos extends StatelessWidget {
  const _Retratos();

  static const _dialogos = [
    ('ana', 'Hola, Lucía. Soy Ana. Aquí puedes preguntarme todo lo que quieras, sin prisa.'),
    ('lucia', '¿Tendré que contarlo muchas veces?'),
    ('elena', 'Estoy aquí al lado todo el rato.'),
    ('tut', '¡Es tu turno! Ayuda a Lucía a encontrar las respuestas.'),
  ];

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(_m),
          children: [
            Text('Retratos', style: texto.headlineMedium),
            const SizedBox(height: _s),
            Text('Para los diálogos: 24 × 20, con los ojos a la misma altura.', style: texto.bodyLarge),
            const SizedBox(height: _m),
            Wrap(
              spacing: _s,
              runSpacing: _s,
              children: [
                for (final id in PersonajesPixel.ids)
                  Container(color: const Color(0xFFE3E9FF), child: _aEscala(PersonajesPixel.retrato(id)!, 8)),
              ],
            ),
            const SizedBox(height: _m),
            for (final (id, frase) in _dialogos) ...[_Dialogo(id: id, frase: frase), const SizedBox(height: _s)],
          ],
        ),
      ),
    );
  }
}

class _Dialogo extends StatelessWidget {
  const _Dialogo({required this.id, required this.frase});

  final String id;
  final String frase;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(_s),
      decoration: BoxDecoration(
        color: _noche,
        border: Border.all(color: _papel, width: 3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(color: const Color(0xFFE3E9FF), child: _aEscala(PersonajesPixel.retrato(id)!, 8)),
          const SizedBox(width: _s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: _s, vertical: 2),
                  color: const Color(0xFFFFDE59),
                  child: Text(
                    PersonajesPixel.ficha(id)!.nombre,
                    style: texto.labelLarge?.copyWith(color: _noche, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 4),
                Text(frase, style: texto.bodyLarge?.copyWith(color: Colors.white)),
              ],
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

  testWidgets('los tres casos', (tester) async {
    await _montar(
      tester,
      const _Galeria(
        titulo: 'Personajes',
        subtitulo: 'Los tres casos oficiales, a la misma escala (11 píxeles de pantalla por píxel del dibujo).',
        filas: [
          ['lucia', 'tutora', 'elena', 'ana'],
          ['sergio', 'padre-sergio', 'madre-sergio', 'laura'],
          ['sara', 'amiga-sara'],
        ],
      ),
    );
    await _capturar(tester, 'personajes-01-casos');
  }, skip: _destino == null);

  testWidgets('el juzgado y Tut', (tester) async {
    await _montar(
      tester,
      const _Galeria(
        titulo: 'En el juzgado',
        subtitulo:
            'En la sala, toga; puñetas blancas en la jueza, el fiscal y la letrada. En su despacho, el fiscal va de '
            'traje. Tut, con su cara de siempre y sonriendo.',
        filas: [
          ['jueza', 'fiscal', 'fiscal-despacho'],
          ['letrada', 'abogada-victima', 'abogado-defensa'],
          ['policia', 'investigada', 'testigo'],
          ['tut', 'tut-feliz'],
        ],
      ),
    );
    await _capturar(tester, 'personajes-02-juzgado');
  }, skip: _destino == null);

  testWidgets('fotogramas', (tester) async {
    for (var i = 0; i * 7 < PersonajesPixel.ids.length; i++) {
      final ids = PersonajesPixel.ids.skip(i * 7).take(7).toList();
      await _montar(tester, _Fotogramas(ids));
      await _capturar(tester, 'personajes-03-fotogramas-${i + 1}');
    }
  }, skip: _destino == null);

  testWidgets('retratos', (tester) async {
    await _montar(tester, const _Retratos());
    await _capturar(tester, 'personajes-06-retratos');
  }, skip: _destino == null);

  testWidgets('en escena', (tester) async {
    await _montar(tester, const _Escena());
    await _capturar(tester, 'personajes-04-escenas');
  }, skip: _destino == null);

  testWidgets('en escena, tema oscuro', (tester) async {
    await _montar(tester, const _Escena(oscuro: true), brillo: Brightness.dark);
    await _capturar(tester, 'personajes-05-escenas-oscuro');
  }, skip: _destino == null);
}
