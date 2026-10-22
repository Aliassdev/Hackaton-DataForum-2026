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
import 'package:tuturno/features/juego/juego_providers.dart';
import 'package:tuturno/features/juego/juego_screen.dart';
import 'package:tuturno/features/juego/juzgado_screen.dart';
import 'package:tuturno/features/juego/textos.dart';
import 'package:tuturno/pixel/juzgado/juzgado.dart' show ModoJuzgado;
import 'package:tuturno/pixel/motor/motor.dart' show SpritePixel;
import 'package:tuturno/pixel/personajes/personajes.dart';
import 'package:tuturno/pixel/ui/ui.dart';
import 'package:tuturno/tema.dart';

import 'fakes.dart' show BundleEnMemoria, casoPrueba, glosarioPrueba;

/// Pantalla muy alta: la lista se construye a medida que se ve y así está entera a la vista.
const _alto = Size(412, 3600);

/// Un caso mínimo con una escena; [cartas], sus títulos.
String _caso(String id, String titulo, String protagonista, int edad, {List<String> cartas = const []}) => jsonEncode({
  'id': id,
  'titulo': titulo,
  'rol': 'victima',
  'basado_en': <String>[],
  'escenas': [
    {
      'id': 'S1',
      'lugar': 'juzgado',
      'personajes': [protagonista],
      'narracion': '$protagonista tiene $edad años. Hoy va a ver cómo funciona su proceso.',
    },
  ],
  'cartas': [
    for (final (i, carta) in cartas.indexed)
      {'id': 'R-$id-$i', 'titulo': carta, 'texto': 'Lo que dice «$carta».', 'fuente': 'LO 1/1996, art. 9'},
  ],
  'validado': true,
});

const _lucia = 'Lucía y la sala de la entrevista';
const _sergio = 'Sergio y la Fiscalía de Menores';
const _sara = 'Sara y su derecho a la intimidad';

/// Los tres casos oficiales, desordenados: la lista los pone en su orden.
final _oficiales = {
  'caso-difusion-imagenes.json': _caso('caso-difusion-imagenes', _sara, 'Sara', 15),
  'caso-acoso-escolar.json': _caso('caso-acoso-escolar', _sergio, 'Sergio', 13),
  'caso-sala-gesell.json': _caso('caso-sala-gesell', _lucia, 'Lucía', 11, cartas: ['Te tienen que escuchar']),
};

Map<String, Object> _progreso({List<String> cartas = const [], List<String> casos = const [], int xp = 0}) => {
  ProgresoNotifier.clave: jsonEncode({'xp': xp, 'cartas': cartas, 'casos': casos}),
};

/// Abre la app mínima del juego en [ruta], con las rutas de app.dart (la del juzgado antes de ':casoId'); el caso,
/// Pregunta, Glosario y Ayuda son pantallas de prueba. [borradores]: el interruptor de borradores del modo DEMO.
Future<GoRouter> _abrir(
  WidgetTester tester, {
  Map<String, String>? casos,
  bool borradores = false,
  Map<String, Object> preferencias = const {},
  Size tamano = _alto,
  double letra = 1,
  bool oscuro = false,
  bool lecturaFacil = false,
}) async {
  tester.view.physicalSize = tamano * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({...preferencias});
  final prefs = await SharedPreferences.getInstance();
  final ficheros = {
    for (final e in (casos ?? _oficiales).entries) '${ContentRepo.raiz}/juego/${e.key}': e.value,
    '${ContentRepo.raiz}/glosario.json': glosarioPrueba,
  };
  final repo = ContentRepo(
    bundle: BundleEnMemoria(ficheros),
    listarAssets: () async => ficheros.keys.toList(),
    mostrarBorradores: borradores,
  );
  Widget prueba(String texto) => Scaffold(body: Text(texto));
  final router = GoRouter(
    initialLocation: '/juego',
    routes: [
      GoRoute(path: '/', builder: (context, state) => prueba('inicio')),
      GoRoute(
        path: '/juego',
        builder: (context, state) => const JuegoScreen(),
        routes: [
          rutaHijaJuzgado(),
          GoRoute(path: ':casoId', builder: (context, state) => prueba('caso ${state.pathParameters['casoId']}')),
        ],
      ),
      rutaRedireccionJuzgado(),
      GoRoute(path: '/pregunta', builder: (context, state) => prueba('pantalla de pregunta')),
      GoRoute(path: '/glosario', builder: (context, state) => prueba('pantalla del glosario')),
      GoRoute(path: '/ayuda', builder: (context, state) => prueba('pantalla de ayuda')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs), contentProvider.overrideWithValue(repo)],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: temaTuTurno(Brightness.light),
        darkTheme: temaTuTurno(Brightness.dark),
        themeMode: oscuro ? ThemeMode.dark : ThemeMode.light,
        locale: const Locale('es', 'ES'),
        supportedLocales: const [Locale('es', 'ES')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(letra)),
          // Como en app.dart: el kit pixel de todo el juego, con la letra de «lectura fácil» si se pide.
          child: TemaPixel(lecturaFacil: lecturaFacil, child: child!),
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

/// Un texto del juego con las cifras en la letra que las distingue ([TextoPixel]).
Finder _conCifras(String texto) => find.byWidgetPredicate((widget) => widget is TextoPixel && widget.texto == texto);

Future<void> _pulsar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('enseña los tres casos en orden, cada uno con el retrato pixel de su protagonista, y «N de 3 casos»', (
    tester,
  ) async {
    await _abrir(tester, preferencias: _progreso(casos: ['caso-acoso-escolar']));
    final titulos = [_lucia, _sergio, _sara].map((titulo) => tester.getTopLeft(find.text(titulo)).dy).toList();
    expect(titulos, orderedEquals([...titulos]..sort()), reason: 'Lucía, Sergio y Sara, en ese orden');
    expect(_conCifras('Caso 1 · Lucía, 11 años'), findsOneWidget);
    expect(_conCifras('Caso 2 · Sergio, 13 años'), findsOneWidget);
    expect(_conCifras('Caso 3 · Sara, 15 años'), findsOneWidget);
    final retratos = tester.widgetList<SpritePixel>(find.byType(SpritePixel)).map((sprite) => sprite.sprite);
    expect(retratos, [
      PersonajesPixel.retrato('lucia'),
      PersonajesPixel.retrato('sergio'),
      PersonajesPixel.retrato('sara'),
    ]);
    expect(find.byType(TicketPixel), findsNWidgets(3), reason: 'sin borradores, no sale la entrada del juzgado');
    expect(find.bySemanticsLabel('1 de 3 casos'), findsOneWidget);
    expect(_conCifras(estadoTerminado), findsOneWidget);
    expect(_conCifras(estadoNuevo), findsNWidgets(2));
  });

  testWidgets('cada ticket es un solo botón para el lector de pantalla, con todo lo importante', (tester) async {
    await _abrir(tester, preferencias: _progreso(cartas: ['R-caso-sala-gesell-0']));
    final lucia = tester.getSemantics(find.bySemanticsLabel(RegExp('^${RegExp.escape(_lucia)}')));
    expect(lucia.label, contains(_lucia));
    expect(lucia.label, contains('Caso 1: Lucía, 11 años'));
    expect(lucia.label, contains('Víctima'));
    expect(lucia.label, contains(estadoNuevo));
    expect(lucia.label, contains('1 de 1 carta'));
    expect(lucia.label, contains(ctaEmpezar));
    expect(lucia.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
  });

  testWidgets('con borradores, «El juzgado por dentro» va debajo de los casos y abre el juzgado', (tester) async {
    final router = await _abrir(tester, borradores: true);
    final juzgado = find.text(tituloJuzgado);
    expect(juzgado, findsOneWidget);
    expect(tester.getTopLeft(juzgado).dy, greaterThan(tester.getTopLeft(find.text(_sara)).dy));
    expect(tester.getTopLeft(juzgado).dy, lessThan(tester.getTopLeft(find.text(tituloColeccion)).dy));
    final entrada = tester.getSemantics(find.bySemanticsLabel(RegExp('^${RegExp.escape(tituloJuzgado)}')));
    expect(entrada.label, contains('Has conocido a 0 de 9 personas'));
    expect(entrada.label, contains(etiquetaBorrador));
    expect(_conCifras(etiquetaBorrador), findsOneWidget, reason: 'sus textos están por revisar');

    await _pulsar(tester, juzgado);
    expect(_ubicacion(router), rutaJuzgado);
    expect(find.byType(JuzgadoScreen), findsOneWidget);
  });

  testWidgets('la entrada del juzgado cuenta a quién conoces y, si ya conoces a todos, invita a repasar', (
    tester,
  ) async {
    final todos = idsDelJuzgado(ModoJuzgado.salaVistas);
    await _abrir(
      tester,
      borradores: true,
      preferencias: {
        ProgresoNotifier.clave: jsonEncode({
          'juzgado': ['jueza', 'fiscal', 'juezMenores'],
        }),
      },
    );
    expect(_conCifras('Has conocido a 2 de ${todos.length}'), findsOneWidget, reason: 'solo cuenta la sala de vistas');
    expect(find.bySemanticsLabel(RegExp('Has conocido a 2 de ${todos.length} personas')), findsOneWidget);

    await _abrir(
      tester,
      borradores: true,
      preferencias: {
        ProgresoNotifier.clave: jsonEncode({'juzgado': todos.toList()}),
      },
    );
    expect(_conCifras(estadoJuzgadoCompleto), findsOneWidget);
    expect(find.text(ctaRepasarJuzgado), findsOneWidget);
  });

  testWidgets('sin el interruptor de borradores, ni la entrada del juzgado ni su carta: sus textos están por revisar', (
    tester,
  ) async {
    await _abrir(tester);
    expect(find.text(tituloJuzgado), findsNothing);
    final cartas = tester.widgetList<CartaPixel>(find.byType(CartaPixel)).map((carta) => carta.titulo);
    expect(cartas, isNot(contains(cartaQuienEsQuien.titulo)));
    expect(cartas, hasLength(1));
  });

  testWidgets('la colección: «Carta: título» o «Carta por descubrir», numeradas, y la del juzgado al final', (
    tester,
  ) async {
    await _abrir(
      tester,
      casos: {'caso-prueba.json': casoPrueba},
      borradores: true,
      preferencias: _progreso(cartas: ['R-acompanada'], xp: 10),
    );
    expect(find.text(tituloColeccion), findsOneWidget);
    expect(find.bySemanticsLabel('Carta: Puedes ir con alguien de confianza'), findsOneWidget);
    expect(find.bySemanticsLabel('Carta por descubrir'), findsNWidgets(3));
    expect(find.bySemanticsLabel('1 de 4 cartas'), findsOneWidget);
    expect(find.bySemanticsLabel('Cartas conseguidas: 1 de 4'), findsOneWidget, reason: 'en la barra del juego');
    expect(find.text('Tienes derecho a entender'), findsNothing, reason: 'una carta bloqueada no se destripa');
    final cartas = tester.widgetList<CartaPixel>(find.byType(CartaPixel)).toList();
    expect(cartas.map((carta) => carta.numero), [1, 2, 3, 4]);
    expect(cartas.map((carta) => carta.bloqueada), [true, false, true, true]);
    expect(cartas.last.titulo, cartaQuienEsQuien.titulo);
    expect(cartas.last.icono, glifoJuzgado);
    expect(cartas.last.pista, pistaCartaJuzgado);
  });

  testWidgets('una carta conseguida se ve en grande, con la ley de la que sale', (tester) async {
    await _abrir(
      tester,
      casos: {'caso-prueba.json': casoPrueba},
      preferencias: _progreso(cartas: ['R-acompanada']),
    );
    await _pulsar(tester, find.bySemanticsLabel('Carta: Puedes ir con alguien de confianza'));
    // La misma ventana que al final de un caso: la carta de pie y su fuente, que se puede tocar.
    final fuente = find.bySemanticsLabel(RegExp(r'^Fuente: LECrim, art\. 433'));
    expect(fuente, findsOneWidget);
    await _pulsar(tester, find.text(botonCerrar));
    expect(fuente, findsNothing);
  });

  testWidgets('una carta por descubrir dice dónde se consigue y lleva allí, también la del juzgado', (tester) async {
    final router = await _abrir(tester, casos: {'caso-prueba.json': casoPrueba}, borradores: true);
    await _pulsar(tester, find.bySemanticsLabel('Carta por descubrir').first);
    expect(find.text(textoCartaBloqueada('Nora')), findsWidgets);
    await _pulsar(tester, find.text(botonJugarCaso('Nora')));
    expect(_ubicacion(router), '/juego/caso-prueba');

    router.pop();
    await tester.pumpAndSettle();
    await _pulsar(tester, find.bySemanticsLabel('Carta por descubrir').last);
    expect(find.text(pistaCartaJuzgado), findsWidgets);
    await _pulsar(tester, find.text(botonEntrarJuzgado));
    expect(_ubicacion(router), rutaJuzgado);

    router.pop();
    await tester.pumpAndSettle();
    await _pulsar(tester, find.bySemanticsLabel('Carta por descubrir').first);
    await _pulsar(tester, find.text(botonCerrar));
    expect(_ubicacion(router), '/juego');
  });

  testWidgets('al tocar un caso se abre; a medias dice «Seguir» y por qué escena vas', (tester) async {
    final router = await _abrir(tester, casos: {'caso-prueba.json': casoPrueba});
    await _pulsar(tester, find.text('Nora y la prueba'));
    expect(_ubicacion(router), '/juego/caso-prueba');
    final contenedor = _contenedor(tester);
    await contenedor.read(partidaProvider('caso-prueba').notifier).elegir(0);
    await contenedor.read(partidaProvider('caso-prueba').notifier).avanzar();
    router.pop();
    await tester.pumpAndSettle();

    expect(find.text(ctaSeguirCaso), findsOneWidget);
    expect(_conCifras('Escena 2 de 4'), findsOneWidget);
    expect(find.bySemanticsLabel('1 de 3 cartas'), findsWidgets);
  });

  testWidgets('un caso terminado dice «Terminado» y «Jugar otra vez»', (tester) async {
    await _abrir(
      tester,
      casos: {'caso-prueba.json': casoPrueba},
      preferencias: _progreso(cartas: ['R-entender'], casos: ['caso-prueba']),
    );
    expect(_conCifras(estadoTerminado), findsOneWidget);
    expect(find.text(ctaOtraVez), findsOneWidget);
    expect(find.bySemanticsLabel('1 de 1 caso'), findsOneWidget);
  });

  testWidgets('sin casos, un aviso amable que lleva a Pregunta', (tester) async {
    final router = await _abrir(tester, casos: const {});
    expect(find.text(sinCasosTitulo), findsOneWidget);
    expect(find.text(sinCasosMensaje), findsOneWidget);
    await _pulsar(tester, find.text('Ir a Pregunta'));
    expect(_ubicacion(router), '/pregunta');
  });

  testWidgets('Glosario y Ayuda, arriba a la derecha; «Volver» sale del juego', (tester) async {
    final router = await _abrir(tester);
    expect(find.byTooltip('Glosario'), findsOneWidget);
    await _pulsar(tester, find.text('Ayuda'));
    expect(find.text('pantalla de ayuda'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await _pulsar(tester, find.bySemanticsLabel('Volver'));
    expect(_ubicacion(router), '/');
  });

  testWidgets('tickets, cartas y botones con nombre y zonas táctiles de 48', (tester) async {
    final semantica = tester.ensureSemantics();
    await _abrir(
      tester,
      casos: {..._oficiales, 'caso-prueba.json': casoPrueba},
      borradores: true,
      preferencias: _progreso(cartas: ['R-acompanada']),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantica.dispose();
  });

  testWidgets('con «lectura fácil», el juego pasa a Atkinson Hyperlegible', (tester) async {
    await _abrir(tester, lecturaFacil: true);
    expect(tester.widget<Text>(find.text(_lucia)).style?.fontFamily, FuentesPixel.lecturaFacil);
  });

  testWidgets('con letra grande, en un móvil pequeño y en el tema oscuro, no se desborda nada', (tester) async {
    await _abrir(
      tester,
      casos: {..._oficiales, 'caso-prueba.json': casoPrueba},
      borradores: true,
      letra: 1.3,
      oscuro: true,
      tamano: const Size(360, 740),
      preferencias: _progreso(cartas: ['R-acompanada', 'R-caso-sala-gesell-0']),
    );
    await tester.scrollUntilVisible(find.text(notaCasosInventados), 400, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text(notaCasosInventados), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('capturas', () {
    // CAPTURAS=build/capturas flutter test test/features/juego/juego_screen_test.dart
    final destino = Platform.environment['CAPTURAS'];

    testWidgets('lista de casos y colección', (tester) async {
      await _cargarFuentes();
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetDevicePixelRatio);
      await _abrir(
        tester,
        casos: {..._oficiales, 'caso-prueba.json': casoPrueba},
        borradores: true,
        tamano: const Size(1080 / 2.75, 2400 / 2.75),
        preferencias: _progreso(cartas: ['R-acompanada', 'R-caso-sala-gesell-0'], casos: ['caso-sala-gesell']),
      );
      await _capturar(tester, '$destino/juego-lista-01.png');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await _capturar(tester, '$destino/juego-lista-02.png');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await _capturar(tester, '$destino/juego-lista-03-juzgado.png');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1400));
      await _capturar(tester, '$destino/juego-lista-04-coleccion.png');
      await _pulsar(tester, find.bySemanticsLabel('Carta: Puedes ir con alguien de confianza'));
      await _capturar(tester, '$destino/juego-lista-05-carta.png');
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
