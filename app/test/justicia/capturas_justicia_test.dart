// Capturas de la capa «justicia»: los 12 iconos nuevos pintados por el PintorIcono real de la app y las piezas
// compartidas (carteles de sala, sellos, «Tu turno de palabra» y las tarjetas de módulo con su cartel).
//
// Siempre se pintan (así se comprueba que nada falla en claro ni en oscuro); los PNG solo se guardan con:
//
//   CAPTURAS=build/capturas flutter test test/justicia/capturas_justicia_test.dart
//
// (build/ no se sube a git). Con CAPTURAS se cargan las letras reales; sin él, las de los tests.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/iconos/iconos.dart';
import 'package:tuturno/widgets/justicia/justicia.dart';
import 'package:tuturno/widgets/modulos.dart';

final _destino = Platform.environment['CAPTURAS'];

const _nuevos = [
  TuIcono.balanza,
  TuIcono.toga,
  TuIcono.estrado,
  TuIcono.campanilla,
  TuIcono.selloConseguido,
  TuIcono.expediente,
  TuIcono.citacion,
  TuIcono.puertaSala,
  TuIcono.turnoPalabra,
  TuIcono.ley,
  TuIcono.manoAlzada,
  TuIcono.panelTurnos,
];

/// Carga las familias de letra del pubspec que existan en assets/fonts/ (en los tests no se cargan solas).
Future<void> _cargarFuentes() async {
  final familias = {
    'Nunito': ['Nunito-Regular.ttf', 'Nunito-SemiBold.ttf', 'Nunito-Bold.ttf', 'Nunito-ExtraBold.ttf'],
    'AtkinsonHyperlegible': [
      'AtkinsonHyperlegible-Regular.ttf',
      'AtkinsonHyperlegible-Bold.ttf',
      'AtkinsonHyperlegible-Italic.ttf',
      'AtkinsonHyperlegible-BoldItalic.ttf',
    ],
    'MaryKate': ['MaryKate-Medium-ES.ttf'],
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
  expect(tester.takeException(), isNull, reason: nombre);
  final destino = _destino;
  if (destino == null) return;
  final capa = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final imagen = await capa.toImage(Offset.zero & tester.view.physicalSize);
    final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
    File('$destino/$nombre.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// Con [atkinson], todo el texto en Atkinson Hyperlegible, como con «lectura fácil».
Future<void> _mostrar(
  WidgetTester tester,
  Widget contenido, {
  required Brightness brillo,
  required Size tamano,
  double letra = 1,
  bool atkinson = false,
}) async {
  tester.view
    ..devicePixelRatio = 2
    ..physicalSize = tamano * 2;
  addTearDown(tester.view.reset);
  final tema = temaTuTurno(brillo);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: atkinson ? tema.copyWith(textTheme: tema.textTheme.apply(fontFamily: 'AtkinsonHyperlegible')) : tema,
      themeAnimationDuration: Duration.zero,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(letra)),
        child: child!,
      ),
      home: Scaffold(body: contenido),
    ),
  );
}

/// La hoja de la referencia: los 12 iconos en color, pegatina, una tinta y a 24 px.
class _HojaIconos extends StatelessWidget {
  const _HojaIconos();

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final paleta = PaletaIconos.de(context);
    Widget fila(Widget Function(TuIcono icono) celda) =>
        Wrap(spacing: 14, runSpacing: 14, children: [for (final icono in _nuevos) celda(icono)]);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fila((i) => IconoTuTurno(i, size: 72)),
          const SizedBox(height: 16),
          Container(
            color: paleta.azul,
            padding: const EdgeInsets.all(10),
            child: fila((i) => IconoTuTurno(i, size: 56, pegatina: true, decorativo: true)),
          ),
          const SizedBox(height: 16),
          Container(
            color: esquema.primary,
            padding: const EdgeInsets.all(10),
            child: fila(
              (i) => IconoTuTurno(i, size: 32, estilo: EstiloIcono.mono, color: esquema.onPrimary, decorativo: true),
            ),
          ),
          const SizedBox(height: 16),
          fila((i) => IconoTuTurno(i, size: 24, estilo: EstiloIcono.mono, decorativo: true)),
          const SizedBox(height: 16),
          fila((i) => IconoTuTurno(i, size: 24)),
        ],
      ),
    );
  }
}

/// Las piezas compartidas: carteles, sellos, «Tu turno de palabra» y las tarjetas de módulo.
class _HojaPiezas extends StatelessWidget {
  const _HojaPiezas();

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const CartelSala(texto: 'SALA 1'),
              const CartelSala(texto: 'SALA 2', detalle: 'Si te toca declarar'),
              const CartelSala(texto: 'INFORMACIÓN', icono: TuIcono.info),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: degradado(colores.aprende),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: CartelSala(texto: 'SALA 2', detalle: 'Tus derechos', icono: TuIcono.balanza),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: [for (final tipo in TipoSello.values) SelloJusticia(tipo: tipo, animar: false, vibrar: false)],
          ),
          const SizedBox(height: 20),
          const Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AvisoTurnoPalabra(activo: true, vibrar: false),
              AvisoTurnoPalabra(activo: false, vibrar: false),
              AvisoTurnoPalabra(activo: true, compacto: true, vibrar: false),
            ],
          ),
          const SizedBox(height: 20),
          for (final modulo in Modulo.values) ...[
            SizedBox(
              width: 380,
              child: TarjetaModulo(modulo: modulo, onTap: () {}),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

void main() {
  setUpAll(() async {
    if (_destino != null) await _cargarFuentes();
  });

  for (final brillo in Brightness.values) {
    testWidgets('iconos justicia (${brillo.name})', (tester) async {
      await _mostrar(tester, const _HojaIconos(), brillo: brillo, tamano: const Size(1100, 760));
      await _capturar(tester, 'flutter-iconos-justicia-${brillo.name}');
      expect(find.byType(IconoTuTurno), findsNWidgets(_nuevos.length * 5));
    });

    testWidgets('piezas justicia (${brillo.name})', (tester) async {
      await _mostrar(tester, const _HojaPiezas(), brillo: brillo, tamano: const Size(820, 1180));
      await _capturar(tester, 'flutter-piezas-justicia-${brillo.name}');
      expect(find.byType(SelloJusticia), findsNWidgets(TipoSello.values.length));
      expect(find.byType(CartelSala), findsNWidgets(4 + Modulo.values.length));
    });

    testWidgets('piezas justicia con letra grande (${brillo.name})', (tester) async {
      await _mostrar(tester, const _HojaPiezas(), brillo: brillo, tamano: const Size(420, 2000), letra: 1.6);
      await _capturar(tester, 'flutter-piezas-justicia-letra-${brillo.name}');
    });

    testWidgets('piezas justicia con la letra de «lectura fácil» (${brillo.name})', (tester) async {
      await _mostrar(tester, const _HojaPiezas(), brillo: brillo, tamano: const Size(820, 1180), atkinson: true);
      await _capturar(tester, 'flutter-piezas-justicia-atkinson-${brillo.name}');
    });
  }
}
