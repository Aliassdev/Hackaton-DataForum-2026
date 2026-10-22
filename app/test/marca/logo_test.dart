import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/marca/marca.dart';

Widget _app(Widget hijo, {Brightness brillo = Brightness.light, bool sinAnimaciones = false}) => MaterialApp(
  theme: temaTuTurno(brillo),
  builder: (context, h) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: sinAnimaciones),
    child: h!,
  ),
  home: Scaffold(body: Center(child: hijo)),
);

PintorMarca _pintor(WidgetTester tester, Finder de) =>
    tester.widget<CustomPaint>(find.descendant(of: de, matching: find.byType(CustomPaint)).first).painter!
        as PintorMarca;

/// Pinta [pintor] en una imagen de [tamano] y devuelve la fracción de píxeles cubiertos con su color.
Future<double> _cobertura(WidgetTester tester, PintorMarca pintor, Size tamano) async {
  final grabadora = ui.PictureRecorder();
  pintor.paint(Canvas(grabadora), tamano);
  final imagen = await tester.runAsync(
    () => grabadora.endRecording().toImage(tamano.width.round(), tamano.height.round()),
  );
  final bytes = (await tester.runAsync(() => imagen!.toByteData()))!;
  final color = pintor.color;
  var cubiertos = 0;
  for (var i = 0; i < bytes.lengthInBytes; i += 4) {
    final r = bytes.getUint8(i), g = bytes.getUint8(i + 1), b = bytes.getUint8(i + 2), a = bytes.getUint8(i + 3);
    final parecido =
        (r - (color.r * 255)).abs() < 8 && (g - (color.g * 255)).abs() < 8 && (b - (color.b * 255)).abs() < 8;
    if (a > 250 && parecido) cubiertos++;
  }
  imagen!.dispose();
  return cubiertos / (bytes.lengthInBytes / 4);
}

void main() {
  group('trazos de la marca', () {
    test('el logotipo tiene sus 7 letras y el monograma sus 3 piezas', () {
      expect(TrazosLogo.letras, hasLength(7));
      expect(TrazosMonograma.piezas, hasLength(3));
      expect(LogoTuTurno.proporcion, closeTo(3.58, 0.05));
      expect(MonogramaTut.proporcion, closeTo(1.43, 0.05));
    });

    test('cada trazo se convierte en un camino que ocupa su caja', () {
      for (final (dibujo, trazos) in [
        (const Size(TrazosLogo.ancho, TrazosLogo.alto), TrazosLogo.letras),
        (const Size(TrazosMonograma.ancho, TrazosMonograma.alto), TrazosMonograma.piezas),
      ]) {
        for (final trazo in trazos) {
          final limites = parsearTrazo(trazo.datos).getBounds();
          // Los límites del camino pueden incluir puntos de control (algo más grandes), nunca algo más pequeño.
          final holgura = dibujo.height * 0.05;
          expect(limites.left, inInclusiveRange(trazo.caja.left - holgura, trazo.caja.left + 0.01));
          expect(limites.top, inInclusiveRange(trazo.caja.top - holgura, trazo.caja.top + 0.01));
          expect(limites.right, inInclusiveRange(trazo.caja.right - 0.01, trazo.caja.right + holgura));
          expect(limites.bottom, inInclusiveRange(trazo.caja.bottom - 0.01, trazo.caja.bottom + holgura));
          // Y todo el dibujo cabe en su lienzo.
          expect(trazo.caja.left, greaterThanOrEqualTo(0));
          expect(trazo.caja.top, greaterThanOrEqualTo(0));
          expect(trazo.caja.right, lessThanOrEqualTo(dibujo.width + 0.01));
          expect(trazo.caja.bottom, lessThanOrEqualTo(dibujo.height + 0.01));
        }
      }
    });

    test('un trazo sin orden inicial no es válido', () {
      expect(() => parsearTrazo('1 2'), throwsFormatException);
      expect(caminoDe(TrazosLogo.letras.first), same(caminoDe(TrazosLogo.letras.first)));
    });
  });

  group('LogoTuTurno', () {
    testWidgets('mide lo que pide y se lee como «TuTurno»', (tester) async {
      await tester.pumpWidget(_app(const LogoTuTurno(alto: 40)));
      expect(tester.getSize(find.byType(LogoTuTurno)), Size(40 * LogoTuTurno.proporcion, 40));
      expect(find.bySemanticsLabel('TuTurno'), findsOneWidget);
    });

    testWidgets('toma el tono del tema: azul noche en claro y amarillo en oscuro', (tester) async {
      await tester.pumpWidget(_app(const LogoTuTurno()));
      expect(_pintor(tester, find.byType(LogoTuTurno)).color, ColoresMarca.azulNoche);
      await tester.pumpWidget(_app(const LogoTuTurno(), brillo: Brightness.dark));
      await tester.pumpAndSettle();
      expect(_pintor(tester, find.byType(LogoTuTurno)).color, ColoresMarca.amarillo);
    });

    testWidgets('el color libre gana al tono y sin etiqueta es decorativo', (tester) async {
      await tester.pumpWidget(
        _app(const LogoTuTurno(tono: TonoMarca.blanco, color: Colors.red, pegatina: true, etiqueta: null)),
      );
      final pintor = _pintor(tester, find.byType(LogoTuTurno));
      expect(pintor.color, Colors.red);
      expect(pintor.pegatina, isTrue);
      expect(find.bySemanticsLabel('TuTurno'), findsNothing);
    });

    test('no se puede usar más pequeño que su alto mínimo', () {
      expect(() => LogoTuTurno(alto: LogoTuTurno.altoMinimo - 1), throwsAssertionError);
    });

    testWidgets('pinta las letras con su color', (tester) async {
      await tester.pumpWidget(_app(const LogoTuTurno(tono: TonoMarca.azul)));
      final pintor = _pintor(tester, find.byType(LogoTuTurno));
      final cobertura = await _cobertura(tester, pintor, const Size(358, 100));
      // Letras finas: ocupan más o menos una cuarta parte de su caja.
      expect(cobertura, inInclusiveRange(0.15, 0.40));
    });
  });

  group('MonogramaTut y PlacaTut', () {
    testWidgets('el monograma mide lo que pide y pinta sus tres piezas', (tester) async {
      await tester.pumpWidget(_app(const MonogramaTut(alto: 60, tono: TonoMarca.amarillo)));
      expect(tester.getSize(find.byType(MonogramaTut)), Size(60 * MonogramaTut.proporcion, 60));
      expect(find.bySemanticsLabel('TuTurno'), findsOneWidget);
      final pintor = _pintor(tester, find.byType(MonogramaTut));
      expect(pintor.trazos, TrazosMonograma.piezas);
      expect(await _cobertura(tester, pintor, const Size(286, 200)), inInclusiveRange(0.2, 0.5));
    });

    testWidgets('la placa es el icono de la app: amarillo sobre azul', (tester) async {
      await tester.pumpWidget(_app(const PlacaTut(lado: 96)));
      expect(tester.getSize(find.byType(PlacaTut)), const Size(96, 96));
      expect(find.bySemanticsLabel('TuTurno'), findsOneWidget);
      final caja = tester.widget<Container>(
        find.descendant(of: find.byType(PlacaTut), matching: find.byType(Container)).first,
      );
      expect((caja.decoration! as BoxDecoration).color, ColoresMarca.azul);
      expect(_pintor(tester, find.byType(PlacaTut)).color, ColoresMarca.amarillo);
    });
  });

  group('IntroMarca', () {
    testWidgets('las letras llegan una a una, aparece el lema y avisa al terminar', (tester) async {
      var terminadas = 0;
      await tester.pumpWidget(_app(IntroMarca(lema: const Text('¡Es tu turno!'), onTerminada: () => terminadas++)));
      final pintor = _pintor(tester, find.byType(IntroMarca));
      expect(pintor.poses!().every((p) => p.opacidad == 0), isTrue, reason: 'al principio no se ve ninguna letra');

      await tester.pump(const Duration(milliseconds: 300));
      final aMedias = pintor.poses!();
      expect(aMedias.first.opacidad, greaterThan(0), reason: 'la primera letra ya ha llegado');
      expect(aMedias.last.opacidad, 0, reason: 'la última todavía no');

      await tester.pump(IntroMarca.duracionTotal);
      expect(terminadas, 1);
      final finales = pintor.poses!();
      expect(finales.every((p) => p.opacidad == 1 && p.escala == 1 && p.giro == 0), isTrue);
      expect(
        tester.widget<Opacity>(find.ancestor(of: find.text('¡Es tu turno!'), matching: find.byType(Opacity))).opacity,
        1,
      );
      expect(find.bySemanticsLabel('TuTurno'), findsOneWidget);
    });

    testWidgets('con un retraso, espera antes de empezar', (tester) async {
      var terminada = false;
      await tester.pumpWidget(
        _app(IntroMarca(retraso: const Duration(milliseconds: 500), onTerminada: () => terminada = true)),
      );
      final pintor = _pintor(tester, find.byType(IntroMarca));
      await tester.pump(const Duration(milliseconds: 400));
      expect(pintor.poses!().every((p) => p.opacidad == 0), isTrue);
      await tester.pump(const Duration(milliseconds: 150) + IntroMarca.duracionTotal);
      expect(terminada, isTrue);
    });

    testWidgets('con «reducir animaciones» aparece ya terminada', (tester) async {
      var terminada = false;
      await tester.pumpWidget(
        _app(IntroMarca(lema: const Text('¡Es tu turno!'), onTerminada: () => terminada = true), sinAnimaciones: true),
      );
      await tester.pump();
      expect(terminada, isTrue);
      final pintor = _pintor(tester, find.byType(IntroMarca));
      expect(pintor.poses!().every((p) => p.opacidad == 1 && p.escala == 1), isTrue);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  testWidgets('los widgets de la marca también funcionan fuera del tema de TuTurno', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(children: [LogoTuTurno(pegatina: true), MonogramaTut(), PlacaTut(), IntroMarca()]),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('TuTurno'), findsNWidgets(4));
  });

  group('archivos de la marca', () {
    final svgs = [
      for (final carpeta in ['assets/marca/logotipo', 'assets/marca/monograma'])
        ...Directory(carpeta).listSync().whereType<File>().where((f) => f.path.endsWith('.svg')),
    ]..sort((a, b) => a.path.compareTo(b.path));

    test('hay logotipo y monograma en los cuatro tonos', () {
      final nombres = [for (final f in svgs) f.uri.pathSegments.last];
      for (final tono in ['amarillo', 'azul-noche', 'blanco', 'azul']) {
        expect(nombres, contains('tuturno-$tono.svg'));
        expect(nombres, contains('tut-$tono.svg'));
      }
    });

    testWidgets('flutter_svg lee cada SVG con el tamaño y el color de su nombre', (tester) async {
      const colores = {'amarillo': '#FFDE59', 'azul-noche': '#0E1A4F', 'blanco': '#FFFFFF', 'azul': '#2643E0'};
      for (final archivo in svgs) {
        final texto = archivo.readAsStringSync();
        final tono = colores.keys.lastWhere((t) => archivo.path.endsWith('-$t.svg'));
        expect(texto, contains('fill="${colores[tono]}"'), reason: archivo.path);
        final caja = RegExp(r'viewBox="0 0 ([\d.]+) ([\d.]+)"').firstMatch(texto)!;
        final info = await tester.runAsync(() => vg.loadPicture(SvgStringLoader(texto), null));
        expect(info!.size.width, closeTo(double.parse(caja[1]!), 0.01), reason: archivo.path);
        expect(info.size.height, closeTo(double.parse(caja[2]!), 0.01), reason: archivo.path);
        info.picture.dispose();
      }
    });

    test('el icono de Android es el monograma amarillo sobre azul, con capa monocroma', () {
      const res = 'android/app/src/main/res';
      final adaptativo = File('$res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync();
      expect(adaptativo, contains('@drawable/ic_launcher_foreground'));
      expect(adaptativo, contains('@drawable/ic_launcher_monochrome'));
      expect(File('$res/drawable/ic_launcher_foreground.xml').readAsStringSync(), contains('#FFFFDE59'));
      expect(File('$res/drawable/ic_launcher_background.xml').readAsStringSync(), contains('#FF2643E0'));
      for (final dpi in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        expect(File('$res/mipmap-$dpi/ic_launcher.png').existsSync(), isTrue, reason: dpi);
      }
    });

    test('la web usa los colores de la marca y config.json sigue igual', () {
      final manifiesto = jsonDecode(File('web/manifest.json').readAsStringSync()) as Map<String, dynamic>;
      expect(manifiesto['theme_color'], '#0E1A4F');
      expect(manifiesto['background_color'], '#0E1A4F');
      expect(File('web/favicon.svg').existsSync(), isTrue);
      expect(jsonDecode(File('web/config.json').readAsStringSync()), {'api_url': ''});
    });
  });
}
