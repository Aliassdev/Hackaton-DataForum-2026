// Capturas de un caso de «Vive el caso» en pixel art, con las fuentes reales y a tamaño de móvil (412 × 915 a
// densidad 2,625, como un Android de 1080 de ancho), para revisar el diseño. No se ejecuta por defecto:
//
//   CAPTURAS=build/capturas-juego flutter test test/features/juego/capturas_test.dart
//
// Recorre los tres casos oficiales: Lucía (S1, la decisión, el acierto con Tut, la carta nueva, S5 y S6 en la Sala
// Gesell, S9 y el final con el sello), Sergio (la Fiscalía y su final, con el juzgado de menores) y Sara (su
// habitación, la Fiscalía con su abogada sin toga y su final, con la ayuda). También con letra 1,3 en 360 de ancho,
// con «lectura fácil» y con «reducir animaciones».
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
    final existentes = rutas.where((ruta) => File(ruta).existsSync()).toList();
    if (existentes.isEmpty) return;
    final cargador = FontLoader(familia);
    for (final ruta in existentes) {
      cargador.addFont(Future.value(ByteData.sublistView(File(ruta).readAsBytesSync())));
    }
    await cargador.load();
  }

  await cargar('PixelifySans', [
    'assets/fonts/PixelifySans-Regular.ttf',
    'assets/fonts/PixelifySans-SemiBold.ttf',
    'assets/fonts/PixelifySans-Bold.ttf',
  ]);
  await cargar('AtkinsonHyperlegible', [
    'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
    'assets/fonts/AtkinsonHyperlegible-Bold.ttf',
  ]);
  await cargar('Nunito', [
    'assets/fonts/Nunito-Regular.ttf',
    'assets/fonts/Nunito-SemiBold.ttf',
    'assets/fonts/Nunito-Bold.ttf',
    'assets/fonts/Nunito-ExtraBold.ttf',
  ]);
  await cargar('MaryKate', ['assets/fonts/MaryKate-Medium-ES.ttf']);
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

/// Desplaza la escena hasta abajo del todo.
Future<void> _alFinal(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).last, const Offset(0, -3000));
  await tester.pumpAndSettle();
}

Future<void> _empezarEn(WidgetTester tester, String casoId, String escena) async {
  await contenedor(tester).read(partidaProvider(casoId).notifier).empezarEn(escena);
  await tester.pumpAndSettle();
}

Future<void> _elegirCorrecta(WidgetTester tester, String casoId) async {
  final escena = contenedor(tester).read(partidaProvider(casoId)).value!.escena;
  await pulsar(tester, find.text(escena.decision!.opciones.firstWhere((o) => o.correcta).texto));
}

/// Juega hasta el final eligiendo siempre la primera respuesta correcta.
Future<void> _jugarHastaElFinal(WidgetTester tester, String casoId) async {
  for (var i = 0; i < 40 && find.text(tituloFinal).evaluate().isEmpty; i++) {
    if (find.text(botonRecogerCarta).evaluate().isNotEmpty) {
      await pulsar(tester, find.text(botonRecogerCarta));
      await pulsar(tester, find.text(botonAMiColeccion));
    } else if (find.text(botonSeguir).evaluate().isNotEmpty) {
      await pulsar(tester, find.text(botonSeguir));
    } else if (find.text(botonTerminar).evaluate().isNotEmpty) {
      await pulsar(tester, find.text(botonTerminar));
    } else {
      await _elegirCorrecta(tester, casoId);
    }
  }
}

void main() {
  setUpAll(() async {
    if (_destino != null) await _cargarFuentes();
  });

  Future<void> abrir(
    WidgetTester tester,
    String casoId, {
    double escala = 1,
    Size tamano = const Size(412, 915),
    bool lecturaFacil = false,
    bool reducir = false,
  }) async {
    await abrirJuego(
      tester,
      ruta: '/juego/$casoId',
      escalaTexto: escala,
      tamano: tamano,
      densidad: 2.625,
      reducirAnimaciones: reducir,
      overrides: await overridesJuego(casos: casosOficiales(), vozActivada: false, lecturaFacil: lecturaFacil),
    );
  }

  testWidgets('Lucía', (tester) async {
    await abrir(tester, 'caso-sala-gesell');
    await _capturar(tester, 'lucia-01-s1');
    await _alFinal(tester);
    await _capturar(tester, 'lucia-02-s1-decision');
    await _elegirCorrecta(tester, 'caso-sala-gesell');
    await _alFinal(tester);
    await _capturar(tester, 'lucia-03-acierto');
    await tester.tap(find.text(botonRecogerCarta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await _capturar(tester, 'lucia-04-carta-bloqueada', esperar: false);
    await _capturar(tester, 'lucia-05-carta-nueva');
    await pulsar(tester, find.text(botonAMiColeccion));
    await _capturar(tester, 'lucia-06-s2');

    await _empezarEn(tester, 'caso-sala-gesell', 'S4');
    await pulsar(tester, find.text('Sí, porque esperarán en el mismo pasillo'));
    await _alFinal(tester);
    await _capturar(tester, 'lucia-07-fallo');

    await _empezarEn(tester, 'caso-sala-gesell', 'S5');
    await _capturar(tester, 'lucia-08-s5');
    await _alFinal(tester);
    await _capturar(tester, 'lucia-09-s5-decision');
    await _empezarEn(tester, 'caso-sala-gesell', 'S6');
    await _capturar(tester, 'lucia-10-s6');
    await _empezarEn(tester, 'caso-sala-gesell', 'S9');
    await _capturar(tester, 'lucia-11-s9');
    await _alFinal(tester);
    await _capturar(tester, 'lucia-12-s9-decision');

    await _jugarHastaElFinal(tester, 'caso-sala-gesell');
    await tester.pump(const Duration(milliseconds: 120));
    await _capturar(tester, 'lucia-13-final-sello-cayendo', esperar: false);
    await _capturar(tester, 'lucia-14-final');
    await _alFinal(tester);
    await _capturar(tester, 'lucia-15-final-abajo');
  }, skip: _destino == null);

  testWidgets('Sergio', (tester) async {
    await abrir(tester, 'caso-acoso-escolar');
    await _empezarEn(tester, 'caso-acoso-escolar', 'S3');
    await _capturar(tester, 'sergio-01-fiscalia');
    await _empezarEn(tester, 'caso-acoso-escolar', 'S6');
    await _capturar(tester, 'sergio-02-padres-fiscalia');
    await _jugarHastaElFinal(tester, 'caso-acoso-escolar');
    await _capturar(tester, 'sergio-03-final');
    await _alFinal(tester);
    await _capturar(tester, 'sergio-04-final-abajo');
  }, skip: _destino == null);

  testWidgets('Sara', (tester) async {
    await abrir(tester, 'caso-difusion-imagenes');
    await _capturar(tester, 'sara-01-habitacion');
    await _empezarEn(tester, 'caso-difusion-imagenes', 'S3');
    await _capturar(tester, 'sara-02-con-su-madre');
    await _empezarEn(tester, 'caso-difusion-imagenes', 'S4');
    await _capturar(tester, 'sara-03-comisaria');
    await _empezarEn(tester, 'caso-difusion-imagenes', 'S7');
    await _capturar(tester, 'sara-04-fiscalia');
    await _jugarHastaElFinal(tester, 'caso-difusion-imagenes');
    await _capturar(tester, 'sara-05-final');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -700));
    await _capturar(tester, 'sara-06-final-ayuda');
    await _alFinal(tester);
    await _capturar(tester, 'sara-07-final-abajo');
  }, skip: _destino == null);

  testWidgets('letra 1,3 en 360 de ancho', (tester) async {
    await abrir(tester, 'caso-acoso-escolar', escala: 1.3, tamano: const Size(360, 740));
    await _capturar(tester, 'pequeno-01-sergio');
    await _alFinal(tester);
    await _capturar(tester, 'pequeno-02-sergio-abajo');
    await _jugarHastaElFinal(tester, 'caso-acoso-escolar');
    await _capturar(tester, 'pequeno-03-final');
  }, skip: _destino == null);

  testWidgets('lectura fácil y reducir animaciones', (tester) async {
    await abrir(tester, 'caso-sala-gesell', lecturaFacil: true, reducir: true);
    await _empezarEn(tester, 'caso-sala-gesell', 'S5');
    await _capturar(tester, 'facil-01-s5');
    await _jugarHastaElFinal(tester, 'caso-sala-gesell');
    await _capturar(tester, 'facil-02-final');
  }, skip: _destino == null);
}
