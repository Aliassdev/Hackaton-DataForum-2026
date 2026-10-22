// El palacio de justicia de papel (FondoJusticia, tema-justicia.md §5 y §7.1): detrás del saludo y del pase del
// inicio, debajo del papel recortado, sin leerse en voz alta, sin tapar ni recibir toques, con paralaje 0,4 y quieto
// con «reducir animaciones». Y los cuatro SVG de assets/justicia/.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/features/inicio/widgets/saludo.dart';
import 'package:tuturno/widgets/justicia/fondo_justicia.dart';
import 'package:tuturno/widgets/movimiento/movimiento.dart';

import '../../widgets/movimiento/entorno.dart';
import '../a1/helpers.dart';

/// El SvgPicture de dentro del palacio.
SvgPicture _dibujo(WidgetTester tester, [Finder? palacio]) => tester.widget<SvgPicture>(
  find.descendant(of: palacio ?? find.byType(FondoJusticia), matching: find.byType(SvgPicture)),
);

String _assetDe(SvgPicture dibujo) => (dibujo.bytesLoader as SvgAssetLoader).assetName;

/// Lo que se ha desplazado el inicio.
double _desplazado(WidgetTester tester) => tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

/// El desplazamiento vertical que el paralaje le da al palacio (0 si no tiene).
double _paralaje(WidgetTester tester) {
  final giro = find.descendant(of: find.byType(FondoJusticia), matching: find.byType(Transform));
  if (giro.evaluate().isEmpty) return 0;
  return tester.widget<Transform>(giro.first).transform.getTranslation().y;
}

void main() {
  group('En el inicio', () {
    testWidgets('el palacio en silueta va detrás del saludo y del pase, debajo del papel recortado', (tester) async {
      await arrancarApp(tester);
      final palacio = find.byType(FondoJusticia);
      expect(palacio, findsOneWidget);
      expect(tester.widget<FondoJusticia>(palacio).variante, VarianteFondoJusticia.silueta);
      expect(_assetDe(_dibujo(tester)), 'assets/justicia/palacio-silueta.svg');

      // Ocupa la zona del saludo y del pase.
      final caja = tester.getRect(find.descendant(of: palacio, matching: find.byType(SvgPicture)));
      expect(caja.overlaps(tester.getRect(find.byType(SaludoTut))), isTrue);
      expect(caja.overlaps(tester.getRect(find.byType(PaseProgreso))), isTrue);

      // En la pila del fondo: primero el palacio, luego el papel recortado y encima el contenido (no tapa texto).
      final pila = tester.widget<Stack>(find.ancestor(of: palacio, matching: find.byType(Stack)).first);
      bool contiene(Widget hijo, Finder buscado) =>
          find.descendant(of: find.byWidget(hijo), matching: buscado).evaluate().isNotEmpty;
      expect(contiene(pila.children[0], find.byType(FondoJusticia)), isTrue);
      expect(contiene(pila.children[1], find.byType(FondoPapel)), isTrue);
      expect(contiene(pila.children[2], find.byType(SaludoTut)), isTrue);
      // Hay menos formas de papel que antes: el palacio ya llena el fondo.
      expect(tester.widget<FondoPapel>(find.byType(FondoPapel).first).formas, 3);
    });

    testWidgets('no se lee en voz alta ni recibe los toques: Tut y el pase siguen funcionando encima', (tester) async {
      final semantica = tester.ensureSemantics();
      await arrancarApp(tester);
      final palacio = find.byType(FondoJusticia);
      final sinLeer = tester.widget<ExcludeSemantics>(
        find.descendant(of: palacio, matching: find.byType(ExcludeSemantics)).first,
      );
      expect(sinLeer.excluding, isTrue);
      final sinToques = tester.widget<IgnorePointer>(
        find.descendant(of: palacio, matching: find.byType(IgnorePointer)).first,
      );
      expect(sinToques.ignoring, isTrue);
      expect(_dibujo(tester).excludeFromSemantics, isTrue);

      // Tocar el pase (encima del palacio) abre «Tu progreso».
      await tester.tap(find.byType(PaseProgreso));
      await tester.pumpAndSettle();
      expect(find.text('Tu progreso'), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('al desplazar se queda atrás: se mueve 0,4 veces lo que se desplaza la pantalla', (tester) async {
      await arrancarApp(tester);
      expect(_paralaje(tester), 0);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      final desplazado = _desplazado(tester);
      expect(desplazado, greaterThan(100));
      expect(_paralaje(tester), closeTo(-desplazado * FondoJusticia.paralaje, 0.01));
    });

    testWidgets('con «reducir animaciones» se queda quieto aunque se desplace la pantalla', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await arrancarApp(tester);
      final dibujo = find.descendant(of: find.byType(FondoJusticia), matching: find.byType(SvgPicture));
      final antes = tester.getTopLeft(dibujo);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pump();
      expect(_desplazado(tester), greaterThan(100));
      expect(tester.getTopLeft(dibujo), antes);
      expect(_paralaje(tester), 0);
    });

    testWidgets('también con «reducir animaciones» de Ajustes', (tester) async {
      await arrancarApp(tester, preferencias: {'ajustes.reducir_movimiento': true});
      final dibujo = find.descendant(of: find.byType(FondoJusticia), matching: find.byType(SvgPicture));
      final antes = tester.getTopLeft(dibujo);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pump();
      expect(tester.getTopLeft(dibujo), antes);
    });

    testWidgets('en el tema oscuro usa la silueta oscura', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await arrancarApp(tester);
      expect(_assetDe(_dibujo(tester)), 'assets/justicia/palacio-silueta-oscuro.svg');
    });
  });

  group('FondoJusticia', () {
    test('elige el SVG por variante y tema', () {
      expect(
        FondoJusticia.asset(VarianteFondoJusticia.silueta, Brightness.light),
        'assets/justicia/palacio-silueta.svg',
      );
      expect(
        FondoJusticia.asset(VarianteFondoJusticia.silueta, Brightness.dark),
        'assets/justicia/palacio-silueta-oscuro.svg',
      );
      expect(FondoJusticia.asset(VarianteFondoJusticia.color, Brightness.light), 'assets/justicia/palacio.svg');
      expect(FondoJusticia.asset(VarianteFondoJusticia.color, Brightness.dark), 'assets/justicia/palacio-oscuro.svg');
    });

    testWidgets('ocupa el ancho que tiene, en proporción 360 × 230, y se alinea en su caja', (tester) async {
      await montar(
        tester,
        const SizedBox(width: 720, height: 600, child: FondoJusticia(alineacion: Alignment.topCenter)),
      );
      final caja = tester.getRect(find.byType(SvgPicture));
      final marco = tester.getRect(find.byType(FondoJusticia));
      expect(caja.width, 720);
      expect(caja.height, closeTo(460, 0.01));
      expect(caja.top, marco.top);

      // Si el alto no llega, lo que quepa (sin deformarse), abajo por defecto.
      await montar(tester, const SizedBox(width: 720, height: 230, child: FondoJusticia()));
      final baja = tester.getRect(find.byType(SvgPicture));
      expect(baja.height, closeTo(230, 0.01));
      expect(baja.width, closeTo(360, 0.01));
      expect(baja.bottom, tester.getRect(find.byType(FondoJusticia)).bottom);
    });

    testWidgets('el panel solo va en la versión en color, dentro del hueco de encima de la puerta', (tester) async {
      const panel = SizedBox(key: Key('panel'), width: 30, height: 12);
      await montar(tester, const SizedBox(width: 360, child: FondoJusticia(panel: panel)));
      expect(find.byKey(const Key('panel')), findsNothing);

      await montar(
        tester,
        const SizedBox(
          width: 720,
          child: FondoJusticia(variante: VarianteFondoJusticia.color, panel: panel),
        ),
      );
      final dibujo = tester.getRect(find.byType(SvgPicture));
      final escala = dibujo.width / FondoJusticia.tamanoDibujo.width;
      final hueco = FondoJusticia.huecoPanel;
      final huecoEnPantalla = Rect.fromLTRB(
        dibujo.left + hueco.left * escala,
        dibujo.top + hueco.top * escala,
        dibujo.left + hueco.right * escala,
        dibujo.top + hueco.bottom * escala,
      );
      final caja = tester.getRect(find.byKey(const Key('panel')));
      expect(huecoEnPantalla.inflate(0.01).contains(caja.topLeft), isTrue, reason: '$caja en $huecoEnPantalla');
      expect(huecoEnPantalla.inflate(0.01).contains(caja.bottomRight), isTrue, reason: '$caja en $huecoEnPantalla');
      expect(_assetDe(_dibujo(tester)), 'assets/justicia/palacio.svg');
    });

    testWidgets('sin scroll no hay paralaje', (tester) async {
      await montar(tester, const SizedBox(width: 360, child: FondoJusticia()));
      expect(find.descendant(of: find.byType(FondoJusticia), matching: find.byType(Transform)), findsNothing);
    });
  });

  group('Los SVG de assets/justicia/', () {
    const nombres = ['palacio', 'palacio-oscuro', 'palacio-silueta', 'palacio-silueta-oscuro'];

    for (final nombre in nombres) {
      test('$nombre.svg: transparente (sin rectángulo de fondo) y con el suelo difuminado', () {
        final texto = File('assets/justicia/$nombre.svg').readAsStringSync();
        expect(texto, contains('viewBox="0 0 360 230"'));
        expect(texto, isNot(contains('width="100%"')), reason: 'sin rectángulo de fondo');
        expect(texto, contains('fill="url(#suelo0)"'));
        expect(texto, contains('fill="url(#suelo1)"'));
        expect(RegExp(r'stop-opacity="0"').allMatches(texto), hasLength(2));
      });
    }

    for (final nombre in ['palacio', 'palacio-oscuro']) {
      test('$nombre.svg: el panel de turnos de encima de la puerta, vacío (el número lo pone la app)', () {
        final texto = File('assets/justicia/$nombre.svg').readAsStringSync();
        // El tablero y su luz amarilla siguen; las dos paletas de papel con el «07» y sus bisagras, no.
        expect(texto, contains('<path d="M163 108 L197 108'));
        expect(texto, contains('<circle cx="196" cy="111.5" r="1.4" fill="#FFDE59"/>'));
        expect(texto, isNot(contains('<rect x="166" y="110.5"')));
        expect(texto, isNot(contains('<rect x="181" y="110.5"')));
        expect(texto, isNot(contains('M172.5 119.4155')), reason: 'el 0');
        expect(texto, isNot(contains('M186.1875 119.3945')), reason: 'el 7');
      });
    }

    testWidgets('flutter_svg los lee con su tamaño de 360 × 230', (tester) async {
      for (final nombre in nombres) {
        final texto = File('assets/justicia/$nombre.svg').readAsStringSync();
        final info = await tester.runAsync(() => vg.loadPicture(SvgStringLoader(texto), null));
        expect(info!.size, const Size(360, 230), reason: nombre);
        info.picture.dispose();
      }
    });

    test('están declarados en pubspec.yaml (assets/justicia/)', () {
      expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/justicia/'));
    });
  });
}
