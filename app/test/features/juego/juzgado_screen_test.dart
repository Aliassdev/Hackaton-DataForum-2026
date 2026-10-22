import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/content_repo.dart';
import 'package:tuturno/core/progreso.dart';
import 'package:tuturno/core/providers.dart';
import 'package:tuturno/features/juego/juego_providers.dart' show xpPorCarta;
import 'package:tuturno/features/juego/juzgado_screen.dart';
import 'package:tuturno/features/juego/textos.dart' show botonAMiColeccion, tituloCartaNueva;
import 'package:tuturno/pixel/juzgado/juzgado.dart';
import 'package:tuturno/pixel/ui/ui.dart' show paginaPixel;
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/movimiento/transiciones.dart';

import '../../pixel/juzgado/ayudantes.dart' show tocarRol;

final _salaVistas = idsDelJuzgado(ModoJuzgado.salaVistas).toList();
final _menores = idsDelJuzgado(ModoJuzgado.menores).toList();

/// Progreso guardado (clave «progreso» de shared_preferences) con estas personas conocidas y estas cartas.
Map<String, Object> _progreso({Iterable<String> personas = const [], List<String> cartas = const [], int xp = 0}) => {
  ProgresoNotifier.clave: jsonEncode({'xp': xp, 'cartas': cartas, 'juzgado': personas.toList()}),
};

/// Abre la app mínima en [ruta], con las rutas del juzgado como en app.dart: [rutaHijaJuzgado] antes de ':casoId'
/// y [rutaRedireccionJuzgado]. [borradores]: el interruptor de borradores del modo DEMO.
Future<GoRouter> _abrir(
  WidgetTester tester, {
  String ruta = rutaJuzgado,
  bool borradores = true,
  Map<String, Object> preferencias = const {},
  bool reducir = false,
  Size tamano = const Size(412, 915),
  double letra = 1,
  ThemeData? tema,
}) async {
  tester.view.physicalSize = tamano * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({...preferencias});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: ruta,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('inicio')),
      ),
      GoRoute(
        path: '/juego',
        builder: (context, state) => const Scaffold(body: Text('lista de casos')),
        routes: [
          rutaHijaJuzgado(),
          GoRoute(
            path: ':casoId',
            builder: (context, state) => Scaffold(body: Text('caso ${state.pathParameters['casoId']}')),
          ),
        ],
      ),
      rutaRedireccionJuzgado(),
      GoRoute(
        path: '/glosario',
        builder: (context, state) => const Scaffold(body: Text('pantalla del glosario')),
      ),
      GoRoute(
        path: '/ayuda',
        builder: (context, state) => const Scaffold(body: Text('pantalla de ayuda')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        contentProvider.overrideWithValue(ContentRepo(mostrarBorradores: borradores)),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: tema ?? temaTuTurno(Brightness.light),
        locale: const Locale('es', 'ES'),
        supportedLocales: const [Locale('es', 'ES')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reducir, textScaler: TextScaler.linear(letra)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String _ubicacion(GoRouter router) => router.state.uri.toString();

ProviderContainer _contenedor(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp).first));

Finder _progresoSala(int conocidos, int total) => find.text('Has conocido a $conocidos de $total');

void main() {
  testWidgets('/juego/juzgado abre la sala de vistas; ?modo=menores, la audiencia de Sergio; /juzgado lleva allí', (
    tester,
  ) async {
    var router = await _abrir(tester);
    expect(find.byType(JuzgadoScreen), findsOneWidget);
    expect(find.text(datosSalaVistas.titulo), findsOneWidget);
    expect(find.text(tituloJuzgado), findsOneWidget, reason: 'el título de la barra del juego');
    expect(_progresoSala(0, _salaVistas.length), findsOneWidget);

    router = await _abrir(tester, ruta: '$rutaJuzgado?modo=menores');
    expect(find.text(datosMenores.titulo), findsOneWidget);
    expect(find.text(tituloJuzgadoMenores), findsOneWidget);

    router = await _abrir(tester, ruta: '/juzgado?modo=menores');
    expect(_ubicacion(router), '$rutaJuzgado?modo=menores');
    expect(find.text(datosMenores.titulo), findsOneWidget);

    router = await _abrir(tester, ruta: '/juzgado');
    expect(_ubicacion(router), rutaJuzgado);
    expect(find.text(datosSalaVistas.titulo), findsOneWidget);
    // Un modo que no existe abre la sala de vistas.
    expect(JuzgadoScreen.modoDe('adultos'), ModoJuzgado.salaVistas);
    expect(JuzgadoScreen.modoDe(null), ModoJuzgado.salaVistas);
    expect(JuzgadoScreen.modoDe('menores'), ModoJuzgado.menores);

    // «Volver» lleva a la lista de casos; el caso con id «juzgado» no existe: la ruta es la del juzgado.
    await tester.tap(find.bySemanticsLabel('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('lista de casos'), findsOneWidget);
    expect(find.text('caso juzgado'), findsNothing);
  });

  testWidgets('la ruta se monta con las transiciones de la app (la de los casos o la pixel), como pide app.dart', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    for (final pagina in <Page<void> Function(BuildContext, GoRouterState, Widget)>[
      (context, state, pantalla) => paginaTuTurno(context, state, pantalla, transicion: TransicionTuTurno.rasgar),
      paginaPixel,
    ]) {
      final router = GoRouter(
        initialLocation: '/juzgado?modo=menores',
        routes: [
          GoRoute(
            path: '/juego',
            builder: (context, state) => const Scaffold(body: Text('lista de casos')),
            routes: [
              rutaHijaJuzgado(pagina: pagina),
              GoRoute(
                path: ':casoId',
                builder: (context, state) => const Scaffold(body: Text('un caso')),
              ),
            ],
          ),
          rutaRedireccionJuzgado(),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            contentProvider.overrideWithValue(ContentRepo(mostrarBorradores: true)),
          ],
          child: MaterialApp.router(theme: temaTuTurno(Brightness.light), routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(datosMenores.titulo), findsOneWidget);
      expect(find.text('un caso'), findsNothing);
    }
  });

  testWidgets('lo descubierto se guarda en el progreso y se recuerda al volver y al abrir otra vez la app', (
    tester,
  ) async {
    final router = await _abrir(tester);
    await tocarRol(tester, 'jueza');
    await tocarRol(tester, 'testigo');
    expect(_progresoSala(2, _salaVistas.length), findsOneWidget);
    expect(_contenedor(tester).read(progresoProvider).personasConocidas, {'jueza', 'testigo'});
    final guardado = (await SharedPreferences.getInstance()).getString(ProgresoNotifier.clave)!;
    expect((jsonDecode(guardado) as Map<String, dynamic>)['juzgado'], unorderedEquals(['jueza', 'testigo']));

    await tester.tap(find.bySemanticsLabel('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('lista de casos'), findsOneWidget);
    router.push(rutaJuzgado);
    await tester.pumpAndSettle();
    expect(_progresoSala(2, _salaVistas.length), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^La jueza\. Ya sabes quién es')), findsWidgets);

    // Con la app cerrada y abierta otra vez, lo mismo (y la sala de menores tiene su propia cuenta).
    await _abrir(tester, preferencias: {ProgresoNotifier.clave: guardado});
    expect(_progresoSala(2, _salaVistas.length), findsOneWidget);
    await _abrir(tester, ruta: '$rutaJuzgado?modo=menores', preferencias: {ProgresoNotifier.clave: guardado});
    expect(_progresoSala(0, _menores.length), findsOneWidget);
  });

  testWidgets('al conocer a todas las personas se gana la carta, una sola vez y con celebración', (tester) async {
    final ultima = _salaVistas.last;
    final router = await _abrir(tester, preferencias: _progreso(personas: _salaVistas.where((id) => id != ultima)));
    expect(find.text(tituloCartaNueva), findsNothing);
    expect(_contenedor(tester).read(progresoProvider).cartas, isNot(contains(cartaQuienEsQuienId)));

    await tocarRol(tester, ultima);
    expect(find.text(tituloCartaNueva), findsOneWidget);
    expect(find.text(cartaQuienEsQuien.titulo), findsOneWidget);
    expect(find.bySemanticsLabel('+$xpPorCarta puntos'), findsOneWidget);
    final progreso = _contenedor(tester).read(progresoProvider);
    expect(progreso.cartas, contains(cartaQuienEsQuienId));
    expect(progreso.xp, xpPorCarta);
    // La misma celebración que las cartas de los casos: se cierra con «¡A mi colección!».
    await tester.tap(find.text(botonAMiColeccion));
    await tester.pumpAndSettle();
    expect(find.text(tituloCartaNueva), findsNothing);
    expect(find.text('¡Ya sabes quién es quién!'), findsNothing, reason: 'la carta de la última persona sigue abierta');

    // Volver a tocar a alguien no la da otra vez.
    await tocarRol(tester, 'jueza');
    expect(find.text(tituloCartaNueva), findsNothing);
    // Ni salir y entrar.
    await tester.tap(find.bySemanticsLabel('Volver'));
    await tester.pumpAndSettle();
    router.push(rutaJuzgado);
    await tester.pumpAndSettle();
    expect(find.text(tituloCartaNueva), findsNothing);
    // Ni conocer a todos en la sala de menores.
    router.push('$rutaJuzgado?modo=menores');
    await tester.pumpAndSettle();
    for (final id in _menores) {
      await tocarRol(tester, id, modo: ModoJuzgado.menores);
    }
    expect(find.text(tituloCartaNueva), findsNothing);
    expect(_contenedor(tester).read(progresoProvider).xp, xpPorCarta, reason: 'los puntos, una sola vez');
  });

  testWidgets('en la sala de menores, conocer a todos también da la carta', (tester) async {
    await _abrir(tester, ruta: '$rutaJuzgado?modo=menores', reducir: true);
    for (final id in _menores) {
      expect(find.text(tituloCartaNueva), findsNothing);
      await tocarRol(tester, id, modo: ModoJuzgado.menores);
    }
    expect(find.text(tituloCartaNueva), findsOneWidget);
    expect(_contenedor(tester).read(progresoProvider).cartas, {cartaQuienEsQuienId});
  });

  testWidgets('si ya conocía a todo el mundo pero no tenía la carta, la gana al entrar; si la tenía, nada', (
    tester,
  ) async {
    await _abrir(tester, preferencias: _progreso(personas: _salaVistas));
    expect(find.text(tituloCartaNueva), findsOneWidget);
    expect(_contenedor(tester).read(progresoProvider).cartas, {cartaQuienEsQuienId});

    await _abrir(
      tester,
      preferencias: _progreso(personas: _salaVistas, cartas: [cartaQuienEsQuienId], xp: 10),
    );
    expect(find.text(tituloCartaNueva), findsNothing);
    expect(_contenedor(tester).read(progresoProvider).xp, 10);
  });

  testWidgets('sin el interruptor de borradores no enseña los textos, que están por revisar, y deja volver', (
    tester,
  ) async {
    expect(DatosJuzgado.de(ModoJuzgado.salaVistas).validado, isFalse);
    await _abrir(tester, borradores: false, preferencias: _progreso(personas: _salaVistas));
    expect(find.byType(JuzgadoExplorable), findsNothing);
    expect(find.text(tituloEnRevision), findsOneWidget);
    expect(find.text(tituloCartaNueva), findsNothing, reason: 'tampoco se gana la carta');
    await tester.tap(find.text(botonVolverACasos));
    await tester.pumpAndSettle();
    expect(find.text('lista de casos'), findsOneWidget);
  });

  testWidgets('mientras los textos no estén revisados, la sala lleva la franja de borrador', (tester) async {
    await _abrir(tester);
    expect(find.text('Borrador: textos pendientes de revisión jurídica.'), findsOneWidget);
  });

  testWidgets('personas, fichas y botones con nombre para el lector de pantalla y zonas táctiles de 48', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    await _abrir(tester, reducir: true);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    for (final rol in datosSalaVistas.roles) {
      expect(find.bySemanticsLabel('${rol.titulo}. Toca para saber quién es.'), findsOneWidget, reason: rol.id);
    }
    expect(find.bySemanticsLabel('Volver'), findsOneWidget);
    expect(find.byTooltip('Glosario'), findsOneWidget);
    expect(find.text('Ayuda'), findsOneWidget);
    semantica.dispose();
  });

  testWidgets('con letra grande en un móvil pequeño y en el tema oscuro no se desborda nada', (tester) async {
    await _abrir(
      tester,
      tamano: const Size(360, 640),
      letra: 1.3,
      reducir: true,
      tema: temaTuTurno(Brightness.dark),
      preferencias: _progreso(personas: _salaVistas.take(8)),
    );
    await tocarRol(tester, _salaVistas.last);
    expect(find.text(tituloCartaNueva), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('capturas', () {
    // CAPTURAS=build/capturas flutter test test/features/juego/juzgado_screen_test.dart
    final destino = Platform.environment['CAPTURAS'];

    testWidgets('el juzgado por dentro y la carta nueva', (tester) async {
      await _cargarFuentes();
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetDevicePixelRatio);
      final ultima = _salaVistas.last;
      await _abrir(
        tester,
        tamano: const Size(1080 / 2.75, 2400 / 2.75),
        reducir: true,
        preferencias: _progreso(personas: _salaVistas.where((id) => id != ultima)),
      );
      await _capturar(tester, '$destino/juzgado-pantalla-01.png');
      await tocarRol(tester, ultima);
      await _capturar(tester, '$destino/juzgado-pantalla-02-carta-nueva.png');
    }, skip: destino == null);
  });
}

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

  await cargar('Nunito', [
    for (final peso in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) 'assets/fonts/Nunito-$peso.ttf',
  ]);
  await cargar('MaryKate', ['assets/fonts/MaryKate-Medium-ES.ttf']);
  await cargar('AtkinsonHyperlegible', ['assets/fonts/AtkinsonHyperlegible-Regular.ttf']);
  // Los iconos de Material: de FLUTTER_ROOT o de la carpeta de Flutter deducida de flutter_tester.
  final flutter =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  await cargar('MaterialIcons', ['$flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  await cargar('PixelifySans', [
    for (final peso in ['Regular', 'SemiBold', 'Bold']) 'assets/fonts/PixelifySans-$peso.ttf',
  ]);
}

Future<void> _capturar(WidgetTester tester, String ruta) async {
  await tester.pumpAndSettle();
  final capa = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final imagen = await capa.toImage(Offset.zero & tester.view.physicalSize);
    final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
    File(ruta)
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}
