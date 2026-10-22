import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tuturno/features/ajustes/ajustes_screen.dart';
import 'package:tuturno/features/aprende/aprende_screen.dart';
import 'package:tuturno/features/ayuda/ayuda_screen.dart';
import 'package:tuturno/features/glosario/glosario_screen.dart';
import 'package:tuturno/features/inicio/inicio_screen.dart';
import 'package:tuturno/features/juego/juego_screen.dart';
import 'package:tuturno/features/pregunta/pregunta_screen.dart';
import 'package:tuturno/features/situacion/situacion_screen.dart';
import 'package:tuturno/pixel/ui/transicion_pixel.dart' show PaginaPixel;
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/movimiento/movimiento.dart';

import '../../features/a1/helpers.dart';

class _Pantalla extends StatelessWidget {
  const _Pantalla(this.nombre);

  final String nombre;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Barra $nombre')),
    body: ListView(
      children: [
        Text(nombre),
        for (var i = 0; i < 20; i++) ListTile(title: Text('Fila $i')),
      ],
    ),
  );
}

/// '/' más una página por transición. Con [web], cada página lleva la transición que tendría en la web
/// ([TransicionTuTurno.enLaWeb]): en un test no se puede cambiar kIsWeb.
Future<GoRouter> _montarRouter(WidgetTester tester, {bool reducir = false, bool web = false}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', pageBuilder: (context, state) => paginaTuTurno(context, state, const _Pantalla('Inicio'))),
      for (final transicion in TransicionTuTurno.values)
        GoRoute(
          path: '/${transicion.name}',
          pageBuilder: (context, state) => paginaTuTurno(
            context,
            state,
            _Pantalla(transicion.name),
            transicion: web ? transicion.enLaWeb : transicion,
          ),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: temaTuTurno(Brightness.light),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducir),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

TransicionTuTurno _transicionDe(WidgetTester tester, Finder pantalla) =>
    (ModalRoute.of(tester.element(pantalla))!.settings as PaginaTuTurno).transicion;

Iterable<SnapshotWidget> _capturando(WidgetTester tester) => tester
    .widgetList<SnapshotWidget>(find.byType(SnapshotWidget, skipOffstage: false))
    .where((captura) => captura.controller.allowSnapshotting);

void main() {
  test('cada transición tiene su duración y, con «reducir animaciones», cero', () {
    for (final transicion in TransicionTuTurno.values) {
      final pagina = PaginaTuTurno<void>(transicion: transicion, child: const SizedBox());
      expect(pagina.transitionDuration, transicion.entrada);
      expect(pagina.reverseTransitionDuration, transicion.salida);
      final quieta = PaginaTuTurno<void>(transicion: transicion, reducirMovimiento: true, child: const SizedBox());
      expect(quieta.transitionDuration, Duration.zero);
      expect(quieta.reverseTransitionDuration, Duration.zero);
    }
    // Ayuda y Glosario se abren rápido.
    expect(TransicionTuTurno.suave.entrada, lessThanOrEqualTo(const Duration(milliseconds: 250)));
  });

  for (final transicion in TransicionTuTurno.values) {
    testWidgets('${transicion.name}: entra y sale, fotograma a fotograma, sin errores', (tester) async {
      final router = await _montarRouter(tester);
      router.push('/${transicion.name}');
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(transicion.entrada ~/ 6);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(find.text(transicion.name), findsOneWidget);
      expect(find.text('Inicio'), findsNothing, reason: 'la pantalla de antes queda oculta');
      expect(_transicionDe(tester, find.text(transicion.name)), transicion);
      expect(tester.binding.hasScheduledFrame, isFalse);

      // Se puede usar la pantalla nueva (los toques llegan bien al acabar).
      await tester.tap(find.text('Fila 2'));
      await tester.pump();

      router.pop();
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(transicion.salida ~/ 4);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text(transicion.name), findsNothing);
    });
  }

  testWidgets('rasgar: la pantalla de antes se rasga sobre una captura; Ayuda encima no rasga nada', (tester) async {
    final router = await _montarRouter(tester);
    router.push('/rasgar');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final capturas = _capturando(tester).toList();
    expect(capturas, hasLength(1));
    expect(find.descendant(of: find.byWidget(capturas.single), matching: find.text('Inicio')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(_capturando(tester), isEmpty, reason: 'en reposo se pinta en vivo');

    router.push('/suave');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_capturando(tester), isEmpty);
    await tester.pumpAndSettle();
    expect(find.text('suave'), findsOneWidget);

    // Al volver del módulo, la pantalla de antes está entera (sin rasgar) mientras el módulo cae.
    router.pop();
    await tester.pumpAndSettle();
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('Inicio'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Inicio'), findsOneWidget);
  });

  testWidgets('rasgar: volver atrás a mitad de la entrada cierra la rotura sin saltos ni errores', (tester) async {
    final router = await _montarRouter(tester);
    router.push('/rasgar');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    router.pop();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('rasgar'), findsNothing);
  });

  test('en la web, rasgar pasa a suave; deslizar y suave no cambian', () {
    expect(
      {for (final transicion in TransicionTuTurno.values) transicion: transicion.enLaWeb},
      {
        TransicionTuTurno.rasgar: TransicionTuTurno.suave,
        TransicionTuTurno.deslizar: TransicionTuTurno.deslizar,
        TransicionTuTurno.suave: TransicionTuTurno.suave,
      },
    );
  });

  testWidgets('en la web, un módulo entra con la suave y la pantalla de antes no se rasga', (tester) async {
    for (final reducir in [false, true]) {
      final router = await _montarRouter(tester, web: true, reducir: reducir);
      router.push('/rasgar');
      await tester.pump();
      await tester.pump(TransicionTuTurno.suave.entrada ~/ 2);
      expect(find.byType(SnapshotWidget, skipOffstage: false), findsNothing, reason: 'reducir: $reducir');
      final pagina = ModalRoute.of(tester.element(find.text('rasgar')))!.settings as PaginaTuTurno;
      expect(pagina.transicion, TransicionTuTurno.suave);
      // Con «reducir animaciones», al momento, como en la app.
      expect(pagina.transitionDuration, reducir ? Duration.zero : TransicionTuTurno.suave.entrada);
      await tester.pumpAndSettle();
      expect(find.text('Inicio'), findsNothing, reason: 'reducir: $reducir');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('con «reducir animaciones», todas las pantallas aparecen y se van al momento', (tester) async {
    final router = await _montarRouter(tester, reducir: true);
    for (final transicion in TransicionTuTurno.values) {
      router.push('/${transicion.name}');
      await tester.pump();
      await tester.pump();
      expect(find.text(transicion.name), findsOneWidget);
      expect(find.text('Inicio'), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse, reason: transicion.name);
      expect(_capturando(tester), isEmpty);
      router.pop();
      await tester.pump();
      await tester.pump();
      expect(find.text('Inicio'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    }
  });

  group('Rutas de la app', () {
    const rutas = <String, (Type, TransicionTuTurno)>{
      '/juego': (JuegoScreen, TransicionTuTurno.rasgar),
      '/aprende': (AprendeScreen, TransicionTuTurno.rasgar),
      '/aprende/leccion/U1-L1': (LeccionScreen, TransicionTuTurno.deslizar),
      '/pregunta': (PreguntaScreen, TransicionTuTurno.deslizar),
      '/situacion/testigo': (SituacionScreen, TransicionTuTurno.deslizar),
      '/ayuda': (AyudaScreen, TransicionTuTurno.suave),
      '/glosario': (GlosarioScreen, TransicionTuTurno.suave),
      '/ajustes': (AjustesScreen, TransicionTuTurno.suave),
    };

    testWidgets('cada ruta se abre con su transición y se vuelve al inicio', (tester) async {
      final router = await arrancarApp(tester);
      expect(_transicionDe(tester, find.byType(InicioScreen)), TransicionTuTurno.suave);
      for (final MapEntry(key: ruta, value: (pantalla, transicion)) in rutas.entries) {
        router.push(ruta);
        await esperarTransicion(tester);
        expect(find.byType(pantalla), findsOneWidget, reason: ruta);
        expect(_transicionDe(tester, find.byType(pantalla)), transicion, reason: ruta);
        router.pop();
        await esperarTransicion(tester);
        expect(find.byType(InicioScreen), findsOneWidget, reason: 'vuelta de $ruta');
      }
    });

    testWidgets('dentro de Vive el caso, un caso y el juzgado entran a bloques (la transición del kit pixel)', (
      tester,
    ) async {
      final router = await arrancarApp(tester);
      for (final (ruta, pantalla) in [('/juego/caso-testigo', CasoScreen), ('/juego/juzgado', JuzgadoScreen)]) {
        router.push(ruta);
        await esperarTransicion(tester);
        expect(find.byType(pantalla), findsOneWidget, reason: ruta);
        expect(ModalRoute.of(tester.element(find.byType(pantalla)))!.settings, isA<PaginaPixel<void>>(), reason: ruta);
        router.pop();
        await esperarTransicion(tester);
        expect(find.byType(InicioScreen), findsOneWidget, reason: 'vuelta de $ruta');
      }
    });

    testWidgets('con «reducir animaciones», las rutas de la app no se animan', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final router = await arrancarApp(tester);
      router.push('/ayuda');
      await tester.pump();
      expect(find.byType(AyudaScreen), findsOneWidget);
      final ruta = ModalRoute.of(tester.element(find.byType(AyudaScreen)))!;
      expect(ruta.animation!.isCompleted, isTrue);
      expect((ruta.settings as PaginaTuTurno).transitionDuration, Duration.zero);
    });
  });
}
