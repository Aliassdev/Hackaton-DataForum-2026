// Capturas del sistema de movimiento con las fuentes reales, para revisar el diseño. No se ejecuta por defecto:
//
//   CAPTURAS=build/capturas flutter test test/widgets/movimiento/capturas_movimiento_test.dart
//
// Deja los PNG en la carpeta indicada (build/ no se sube a git). En flutter_test las sombras salen sin desenfoque.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/movimiento/movimiento.dart';

final _destino = Platform.environment['CAPTURAS'];

Future<void> _cargarFuentes() async {
  Future<void> cargar(String familia, List<String> rutas) async {
    final cargador = FontLoader(familia);
    for (final ruta in rutas) {
      cargador.addFont(Future.value(ByteData.sublistView(File(ruta).readAsBytesSync())));
    }
    await cargador.load();
  }

  await cargar('AtkinsonHyperlegible', [
    'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
    'assets/fonts/AtkinsonHyperlegible-Bold.ttf',
  ]);
  await cargar('MaryKate', ['assets/fonts/MaryKate-Medium-ES.ttf']);
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

class _Galeria extends StatelessWidget {
  const _Galeria();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(Espacio.m),
        children: [
          SizedBox(
            height: 150,
            child: FondoPapel(
              color: PaletaMovimiento.azul,
              acento: PaletaMovimiento.amarillo,
              radio: Radios.l,
              animado: false,
              child: Padding(
                padding: const EdgeInsets.all(Espacio.l),
                child: Text(
                  '¡Es tu turno!',
                  style: tema.textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
          const SizedBox(height: Espacio.l),
          TicketTuTurno(
            etiqueta: 'Módulo',
            titulo: 'Vive el caso',
            descripcion: 'Juega un caso y descubre tus derechos.',
            numero: '01',
            inclinacion: -0.015,
            onTap: () {},
          ),
          const SizedBox(height: Espacio.m),
          TicketTuTurno(
            etiqueta: 'Tu turno del día',
            titulo: 'Tres preguntas sobre declarar',
            numero: '07',
            etiquetaNumero: 'Turno',
            ladoTalon: LadoTalon.abajo,
            fondo: PaletaMovimiento.amarillo,
            fondoTalon: PaletaMovimiento.azulNoche,
            inclinacion: 0.012,
            onTap: () {},
          ),
          const SizedBox(height: Espacio.l),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const ContadorFlip(valor: 128, digitos: 3, semanticsLabel: '128 XP'),
              SelloAnimado(
                animar: false,
                child: const Sello(texto: 'Oído', icono: Icons.hearing_rounded, tamano: 110),
              ),
              const PopPegatina(animar: false, child: Chip(label: Text('+10 XP'))),
            ],
          ),
          const SizedBox(height: Espacio.l),
          Center(
            child: CartaHolo(
              child: Container(
                width: 220,
                height: 300,
                color: PaletaMovimiento.azulNoche,
                alignment: Alignment.center,
                child: Text(
                  'Derecho\na ser oído',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.headlineMedium?.copyWith(color: PaletaMovimiento.amarillo),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pagina extends StatelessWidget {
  const _Pagina(this.titulo, this.color);

  final String titulo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: ListView(
        padding: const EdgeInsets.all(Espacio.m),
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Radios.l)),
            padding: const EdgeInsets.all(Espacio.l),
            alignment: Alignment.bottomLeft,
            child: Text(titulo, style: tema.textTheme.headlineMedium?.copyWith(color: Colors.white)),
          ),
          const SizedBox(height: Espacio.m),
          for (var i = 0; i < 6; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Espacio.m),
              child: TicketTuTurno(titulo: 'Ticket $i', descripcion: 'Una línea de texto.', numero: '0$i'),
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

  for (final brillo in Brightness.values) {
    testWidgets('galería ${brillo.name}', (tester) async {
      tester.view.physicalSize = const Size(390, 900) * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(debugShowCheckedModeBanner: false, theme: temaTuTurno(brillo), home: const _Galeria()),
      );
      await tester.pumpAndSettle();
      await _capturar(tester, 'movimiento-galeria-${brillo.name}');
      // La carta, inclinada con el dedo.
      final gesto = await tester.startGesture(tester.getCenter(find.byType(CartaHolo)));
      await gesto.moveBy(const Offset(40, 0));
      await gesto.moveBy(const Offset(50, -40));
      await tester.pump();
      await _capturar(tester, 'movimiento-carta-inclinada-${brillo.name}');
      await gesto.up();
      await tester.pumpAndSettle();
    }, skip: _destino == null);
  }

  testWidgets('transiciones a mitad', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) =>
              paginaTuTurno(context, state, const _Pagina('Inicio', PaletaMovimiento.azul)),
        ),
        for (final transicion in TransicionTuTurno.values)
          GoRoute(
            path: '/${transicion.name}',
            pageBuilder: (context, state) => paginaTuTurno(
              context,
              state,
              _Pagina('Módulo ${transicion.name}', const Color(0xFF1A2AA6)),
              transicion: transicion,
            ),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(debugShowCheckedModeBanner: false, theme: temaTuTurno(Brightness.light), routerConfig: router),
    );
    await tester.pumpAndSettle();
    for (final transicion in TransicionTuTurno.values) {
      router.push('/${transicion.name}');
      await tester.pump();
      var transcurrido = Duration.zero;
      for (final fraccion in [0.12, 0.3, 0.55, 0.8]) {
        final hasta = transicion.entrada * fraccion;
        await tester.pump(hasta - transcurrido);
        transcurrido = hasta;
        await _capturar(tester, 'transicion-${transicion.name}-entrada-${(fraccion * 100).round()}');
      }
      await tester.pumpAndSettle();
      router.pop();
      await tester.pump();
      await tester.pump(transicion.salida * 0.4);
      await _capturar(tester, 'transicion-${transicion.name}-salida-40');
      await tester.pumpAndSettle();
    }
  }, skip: _destino == null);
}
