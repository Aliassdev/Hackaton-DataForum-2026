// Hoja de marca con las fuentes reales, para revisar el tema y los widgets de lib/widgets/marca/ (y para los PR).
// No se ejecuta por defecto:
//
//   CAPTURAS=build/capturas flutter test test/marca/capturas_marca_test.dart
//
// Deja marca-claro.png, marca-oscuro.png e intro-*.png en la carpeta indicada (build/ no se sube a git).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/ayuda_button.dart';
import 'package:tuturno/widgets/marca/marca.dart';

final _destino = Platform.environment['CAPTURAS'];

Future<void> _cargarFuentes() async {
  Future<void> cargar(String familia, List<String> rutas) async {
    final cargador = FontLoader(familia);
    for (final ruta in rutas) {
      cargador.addFont(Future.value(ByteData.sublistView(File(ruta).readAsBytesSync())));
    }
    await cargador.load();
  }

  await cargar(Fuentes.texto, [
    'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
    'assets/fonts/AtkinsonHyperlegible-Bold.ttf',
  ]);
  await cargar(Fuentes.titulos, ['assets/fonts/LondrinaSolid-Regular.ttf', 'assets/fonts/LondrinaSolid-Black.ttf']);
  final flutter =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final iconos = '$flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  if (File(iconos).existsSync()) await cargar('MaterialIcons', [iconos]);
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

class _Hoja extends StatelessWidget {
  const _Hoja();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final t = tema.textTheme;
    final c = context.colores;
    Widget panel(Color fondo, Widget hijo) => Container(
      padding: const EdgeInsets.all(Espacio.m),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(Radios.l)),
      child: hijo,
    );
    return Scaffold(
      appBar: AppBar(
        title: const LogoTuTurno(alto: 28),
        actions: const [
          GlosarioButton(),
          AyudaButton(),
          SizedBox(width: Espacio.s),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Espacio.m),
        children: [
          panel(
            ColoresMarca.azul,
            const Center(
              child: IntroMarca(
                alto: 72,
                tono: TonoMarca.amarillo,
                lema: Text('¡Es tu turno!', style: TextStyle(color: Colors.white, fontSize: 20)),
              ),
            ),
          ),
          const SizedBox(height: Espacio.s),
          Row(
            children: [
              Expanded(child: panel(ColoresMarca.amarillo, const LogoTuTurno(alto: 32, tono: TonoMarca.azulNoche))),
              const SizedBox(width: Espacio.s),
              Expanded(child: panel(ColoresMarca.azulNoche, const LogoTuTurno(alto: 32, tono: TonoMarca.amarillo))),
            ],
          ),
          const SizedBox(height: Espacio.s),
          Row(
            children: [
              const PlacaTut(lado: 72),
              const SizedBox(width: Espacio.m),
              const PlacaTut(lado: 48, tono: TonoMarca.azulNoche),
              const SizedBox(width: Espacio.m),
              const MonogramaTut(alto: 48),
              const SizedBox(width: Espacio.m),
              panel(ColoresMarca.azul, const MonogramaTut(alto: 40, tono: TonoMarca.blanco, pegatina: true)),
            ],
          ),
          const SizedBox(height: Espacio.m),
          Text('1.250 XP', style: t.displayLarge),
          Text('¡Es tu turno del día!', style: t.headlineLarge?.copyWith(fontWeight: FontWeight.w700)),
          Text('Vive el caso', style: t.headlineMedium),
          Text('Antes de declarar', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          Text('Título de barra en Atkinson', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          Text(
            'Texto de lectura en Atkinson Hyperlegible: se lee bien con baja visión o dificultades lectoras.',
            style: t.bodyLarge,
          ),
          Text(
            'Texto secundario (onSurfaceVariant)',
            style: t.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Espacio.m),
          Wrap(
            spacing: Espacio.s,
            runSpacing: Espacio.s,
            children: [
              FilledButton(onPressed: () {}, child: const Text('Empezar')),
              OutlinedButton(onPressed: () {}, child: const Text('Ver mapa')),
              TextButton(onPressed: () {}, child: const Text('Saltar')),
              FilterChip(label: const Text('Testigo'), selected: true, onSelected: (_) {}),
              FilterChip(label: const Text('Víctima'), selected: false, onSelected: (_) {}),
            ],
          ),
          const SizedBox(height: Espacio.m),
          Row(
            children: [
              for (final colores in [c.juego, c.aprende, c.pregunta])
                Expanded(
                  child: Container(
                    height: 64,
                    margin: const EdgeInsets.only(right: Espacio.s),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: colores),
                      borderRadius: BorderRadius.circular(Radios.m),
                    ),
                    child: Text('Módulo', style: t.titleMedium?.copyWith(color: Colors.white)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Espacio.m),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Espacio.m),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: c.exito),
                  const SizedBox(width: Espacio.s),
                  Expanded(child: Text('Tarjeta de papel con un acierto', style: t.bodyLarge)),
                ],
              ),
            ),
          ),
          const SizedBox(height: Espacio.s),
          Container(
            padding: const EdgeInsets.all(Espacio.m),
            decoration: BoxDecoration(
              color: c.ticket,
              borderRadius: BorderRadius.circular(Radios.m),
              boxShadow: sombrasPapel(context),
            ),
            child: Text('Ticket nº 042', style: t.headlineSmall?.copyWith(color: c.tintaTicket)),
          ),
          const SizedBox(height: Espacio.s),
          const TextField(decoration: InputDecoration(hintText: 'Escribe tu pregunta')),
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
    testWidgets('hoja de marca ${brillo.name}', (tester) async {
      tester.view.physicalSize = const Size(390, 1100) * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(MaterialApp(theme: temaTuTurno(brillo), home: const _Hoja()));
      await tester.pumpAndSettle();
      await _capturar(tester, 'marca-${brillo == Brightness.light ? 'claro' : 'oscuro'}');
    }, skip: _destino == null);
  }

  testWidgets('fotogramas de la presentación', (tester) async {
    tester.view.physicalSize = const Size(390, 260) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: temaTuTurno(Brightness.light),
        home: const Scaffold(
          backgroundColor: ColoresMarca.azul,
          body: Center(
            child: IntroMarca(
              alto: 72,
              tono: TonoMarca.amarillo,
              lema: Text('¡Es tu turno!', style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
          ),
        ),
      ),
    );
    var anterior = 0;
    for (final ms in [150, 350, 550, 800, 1100]) {
      await tester.pump(Duration(milliseconds: ms - anterior));
      anterior = ms;
      await _capturar(tester, 'intro-$ms');
    }
    await tester.pumpAndSettle();
  }, skip: _destino == null);
}
