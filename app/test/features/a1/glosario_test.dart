import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/content_models.dart';
import 'package:tuturno/core/providers.dart';
import 'package:tuturno/features/glosario/detalle_termino.dart';
import 'package:tuturno/features/glosario/glosario_screen.dart';
import 'package:tuturno/features/pregunta/pregunta_screen.dart';
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/iconos/iconos.dart';
import 'package:tuturno/widgets/movimiento/carta_holo.dart';
import 'package:tuturno/widgets/movimiento/contador_flip.dart';

import 'helpers.dart';

const _citacion = EntradaGlosario(
  id: 'G-citacion',
  termino: 'Citación',
  definicion: 'Documento del juzgado que te dice cuándo y dónde tienes que ir.',
  ejemplo: 'A Lucía le llegó una citación.',
  fuente: 'A-060',
  validado: true,
);

void main() {
  group('Glosario', () {
    testWidgets('lista los términos validados agrupados por letra', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/glosario');

      expect(find.byType(GlosarioScreen), findsOneWidget);
      expect(find.text('Abogado o abogada'), findsOneWidget);
      expect(find.text('Citación'), findsOneWidget);
      expect(find.text('Fiscalía de Menores'), findsOneWidget);
      expect(find.text('Borrador oculto'), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('F'), findsOneWidget);
      // El recuento: un panel que gira con el número y el texto (se lee entero: «3 palabras explicadas fácil»).
      expect(tester.widget<ContadorFlip>(find.byType(ContadorFlip)).valor, 3);
      expect(find.text('palabras explicadas fácil'), findsOneWidget);
      // Dentro del glosario no hace falta el botón de Glosario; Ayuda sigue ahí.
      expect(find.byTooltip('Glosario'), findsNothing);
      expect(find.byTooltip('Teléfonos de ayuda'), findsOneWidget);
    });

    testWidgets('busca sin que importen tildes ni mayúsculas y abre el detalle', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/glosario');

      await tester.enterText(find.byType(TextField), 'FISCALIA');
      await tester.pumpAndSettle();
      expect(find.text('Fiscalía de Menores'), findsOneWidget);
      expect(find.text('Citación'), findsNothing);
      expect(find.text('Abogado o abogada'), findsNothing);

      await tester.tap(find.text('Fiscalía de Menores'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Ejemplo'), findsOneWidget);
      expect(find.text('La Fiscalía de Menores vela por los derechos de Sergio.'), findsOneWidget);
      // Fuente «MOCK»: se avisa de que es un dato de ejemplo.
      expect(find.text('Dato de ejemplo'), findsOneWidget);
    });

    testWidgets('el detalle enseña la fuente real', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/glosario');

      await tester.enterText(find.byType(TextField), 'citación');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Citación'));
      await tester.pumpAndSettle();
      expect(find.text('Fuente: A-060'), findsOneWidget);
      expect(find.text('A Lucía le llegó una citación para declarar como testigo.'), findsOneWidget);
    });

    testWidgets('también busca dentro de la definición y se puede borrar la búsqueda', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/glosario');

      await tester.enterText(find.byType(TextField), 'defiende');
      await tester.pumpAndSettle();
      expect(find.text('Abogado o abogada'), findsOneWidget);
      expect(find.text('Citación'), findsNothing);

      await tester.tap(find.byTooltip('Borrar la búsqueda'));
      await tester.pumpAndSettle();
      expect(find.text('Citación'), findsOneWidget);
    });

    testWidgets('sin resultados, ofrece preguntarlo', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/glosario');

      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pumpAndSettle();
      // Con las comillas de la app («»), nunca las inglesas.
      expect(find.text('Aún no tengo «xyz» en el glosario'), findsOneWidget);

      await tester.tap(find.text('Pregúntalo'));
      await esperarTransicion(tester);
      expect(find.byType(PreguntaScreen), findsOneWidget);
      // La duda queda escrita en el campo para revisarla y enviarla.
      expect(find.widgetWithText(TextField, '¿Qué significa «xyz»?'), findsOneWidget);
    });

    testWidgets('con ?q= que coincide con un término, abre su detalle solo', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/glosario?q=citacion');

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Fuente: A-060'), findsOneWidget);
      expect(find.text('A Lucía le llegó una citación para declarar como testigo.'), findsOneWidget);
      // La búsqueda queda escrita.
      expect(find.widgetWithText(TextField, 'citacion'), findsOneWidget);
    });

    testWidgets('con ?q= que no coincide del todo, solo filtra', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/glosario?q=Fiscal');

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Fiscalía de Menores'), findsOneWidget);
      expect(find.text('Citación'), findsNothing);
    });

    testWidgets('glosario vacío: se está preparando', (tester) async {
      final router = await arrancarApp(tester, glosario: '[]');
      await irA(tester, router, '/glosario');
      expect(find.text('El glosario se está preparando'), findsOneWidget);
    });

    testWidgets('si falla la carga, deja reintentar', (tester) async {
      var intentos = 0;
      final router = await arrancarApp(
        tester,
        overrides: [
          glosarioProvider.overrideWith((ref) async {
            intentos++;
            if (intentos == 1) throw Exception('sin glosario');
            return const [_citacion];
          }),
        ],
      );
      await irA(tester, router, '/glosario');
      expect(find.text('Algo no ha ido bien'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Citación'), findsOneWidget);
      expect(intentos, 2);
    });
  });

  group('textoFuente y filtrarGlosario', () {
    test('fuente real, de ejemplo o vacía', () {
      expect(textoFuente(_citacion), 'Fuente: A-060');
      const mock = EntradaGlosario(id: 'x', termino: 'x', definicion: 'x', ejemplo: '', fuente: 'MOCK', validado: true);
      expect(textoFuente(mock), 'Dato de ejemplo');
      const sin = EntradaGlosario(id: 'x', termino: 'x', definicion: 'x', ejemplo: '', fuente: ' ', validado: true);
      expect(textoFuente(sin), isNull);
    });

    test('filtra por término o definición sin tildes', () {
      expect(filtrarGlosario(const [_citacion], 'CITACIÓN'), hasLength(1));
      expect(filtrarGlosario(const [_citacion], 'juzgado'), hasLength(1));
      expect(filtrarGlosario(const [_citacion], 'abogado'), isEmpty);
      expect(filtrarGlosario(const [_citacion], '   '), hasLength(1));
    });
  });

  group('La colección de cartas', () {
    testWidgets('cada palabra es una carta con su número, que no cambia al buscar', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/glosario');

      Finder carta(String termino) => find.ancestor(of: find.text(termino), matching: find.byType(InkWell)).first;
      expect(find.descendant(of: carta('Abogado o abogada'), matching: find.text('01')), findsOneWidget);
      expect(find.descendant(of: carta('Citación'), matching: find.text('02')), findsOneWidget);
      expect(find.descendant(of: carta('Fiscalía de Menores'), matching: find.text('03')), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'fiscalia');
      await tester.pumpAndSettle();
      expect(tester.widget<ContadorFlip>(find.byType(ContadorFlip)).valor, 1);
      expect(find.text('palabra explicada fácil'), findsOneWidget);
      expect(find.descendant(of: carta('Fiscalía de Menores'), matching: find.text('03')), findsOneWidget);
    });

    testWidgets('el recuento y las cartas se leen bien con TalkBack', (tester) async {
      final semantica = tester.ensureSemantics();
      final router = await arrancarApp(tester);
      await irA(tester, router, '/glosario');

      expect(find.bySemanticsLabel('3 palabras explicadas fácil'), findsOneWidget);
      expect(find.bySemanticsLabel('Letra C'), findsOneWidget);
      // La carta es un botón con el nombre y la definición; el número es decorativo.
      final nodo = tester.getSemantics(find.ancestor(of: find.text('Citación'), matching: find.byType(InkWell)).first);
      expect(nodo.label, contains('Citación'));
      expect(nodo.label, contains('Documento del juzgado'));
      expect(nodo.label, isNot(contains('02')));
      semantica.dispose();
    });

    testWidgets('el detalle es una carta holográfica con su número en la colección', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/glosario');
      await tester.tap(find.text('Citación'));
      await tester.pumpAndSettle();

      final hoja = find.byType(BottomSheet);
      expect(find.descendant(of: hoja, matching: find.byType(CartaHolo)), findsOneWidget);
      final numero = find.descendant(of: hoja, matching: find.text('Nº 02/03'));
      expect(numero, findsOneWidget);
      // El número va en la letra de las cifras (estiloCifras: Nunito ExtraBold), que tiene la «º» y no confunde el 0
      // con la O, como la de los títulos.
      final estilo = tester.widget<Text>(numero).style!;
      expect(estilo.fontFamily, Fuentes.texto);
      expect(estilo.fontWeight, FontWeight.w800);
      expect(find.descendant(of: hoja, matching: find.text('Citación')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('al abrirlo con ?q=, el detalle también lleva su número', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/glosario?q=fiscalia de menores');
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Nº 03/03')), findsOneWidget);
    });

    testWidgets('sin resultados, Tut piensa (y no hace fiesta)', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/glosario');
      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pumpAndSettle();
      expect(tester.widget<MascotaTut>(find.byType(MascotaTut)).expresion, ExpresionTut.pensando);
    });

    for (final brillo in Brightness.values) {
      testWidgets('cumple las pautas de accesibilidad en tema ${brillo.name} (lista y carta)', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brillo;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final semantica = tester.ensureSemantics();
        final router = await arrancarApp(tester);
        await irA(tester, router, '/glosario');
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        await tester.tap(find.text('Citación'));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantica.dispose();
      });
    }

    testWidgets('cabe con letra grande en un móvil pequeño (lista, búsqueda y carta)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final router = await arrancarApp(
        tester,
        preferencias: {'ajustes.tamano_texto': 1.3},
        tamano: const Size(360, 640),
      );
      await irA(tester, router, '/glosario');
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'fiscal');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fiscalía de Menores'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('iconoDeTermino', () {
    test('cada palabra lleva el icono de su tema, y el libro si no encaja con ninguno', () {
      expect(iconoDeTermino('Sala Gesell'), TuIcono.grabacion);
      expect(iconoDeTermino('Prueba preconstituida'), TuIcono.grabacion);
      expect(iconoDeTermino('Abogado de oficio'), TuIcono.personaConfianza);
      expect(iconoDeTermino('Coordinador de bienestar y protección'), TuIcono.personaConfianza);
      expect(iconoDeTermino('Víctima'), TuIcono.escudo);
      expect(iconoDeTermino('Orden de alejamiento'), TuIcono.escudo);
      expect(iconoDeTermino('Citación'), TuIcono.citacion);
      expect(iconoDeTermino('Denuncia'), TuIcono.fuente);
      expect(iconoDeTermino('Derecho a ser oído'), TuIcono.turnoPalabra);
      expect(iconoDeTermino('Audiencia del menor'), TuIcono.turnoPalabra);
      expect(iconoDeTermino('Fiscalía de Menores'), TuIcono.juzgado);
      expect(iconoDeTermino('Persona investigada'), TuIcono.juzgado);
      expect(iconoDeTermino('Derecho a la propia imagen'), TuIcono.candado);
      expect(iconoDeTermino('Canal prioritario'), TuIcono.web);
      expect(iconoDeTermino('Testigo'), TuIcono.microfono);
      expect(iconoDeTermino('Conciliación'), TuIcono.glosario);
    });

    test('los números de carta salen del orden alfabético y llevan al menos dos cifras', () {
      const a = EntradaGlosario(id: 'a', termino: 'A', definicion: 'x', ejemplo: '', fuente: 'F', validado: true);
      const b = EntradaGlosario(id: 'b', termino: 'B', definicion: 'x', ejemplo: '', fuente: 'F', validado: true);
      expect(numerosDeCarta(const [a, b]), {'a': 1, 'b': 2});
      expect(cifrasDeCarta(20), 2);
      expect(cifrasDeCarta(140), 3);
    });
  });
}
