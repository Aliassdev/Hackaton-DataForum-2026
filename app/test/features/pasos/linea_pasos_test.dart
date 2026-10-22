import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/content_repo.dart';
import 'package:tuturno/features/pasos/linea_pasos.dart' show iconoPersona;
import 'package:tuturno/features/pasos/pasos.dart';
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/estados.dart';
import 'package:tuturno/widgets/iconos/iconos.dart' show IconoTuTurno, TuIcono;

import 'datos.dart';

/// Relleno del nodo con el número [numero] (el círculo sobre la línea).
Color? _rellenoNodo(WidgetTester tester, int numero) {
  final nodo = tester.widget<AnimatedContainer>(
    find.ancestor(of: find.text('$numero'), matching: find.byType(AnimatedContainer)).first,
  );
  return (nodo.decoration as BoxDecoration?)?.color;
}

Color _primario(WidgetTester tester) => Theme.of(tester.element(find.byType(LineaPasos))).colorScheme.primary;

/// Opacidad con la que se ve [finder]: el producto de la de sus antepasados (Opacity y FadeTransition).
double _opacidad(WidgetTester tester, Finder finder) {
  var total = 1.0;
  final fundidos = find.ancestor(
    of: finder,
    matching: find.byWidgetPredicate((w) => w is Opacity || w is FadeTransition),
  );
  for (final widget in tester.widgetList(fundidos)) {
    total *= widget is Opacity ? widget.opacity : (widget as FadeTransition).opacity.value;
  }
  return total;
}

/// Hace visible [finder] (desplazando si hace falta) y lo pulsa.
Future<void> _pulsar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Contenido nuevo en cada test: ContentRepo guarda lo que lee y no debe pasar de un test a otro.
ContentRepo get repoVictima => repoCon({real('victima'): itinerarioConFases}).$1;

/// Itinerario de testigo con 5 pasos muy largos: abierto, ninguno cabe en una pantalla de 360 × 640.
String _itinerarioLargo() {
  final pedir = [
    for (var i = 1; i <= 10; i++) '"Una cosa que puedes pedir, la número $i, explicada con calma y con todo detalle"',
  ].join(', ');
  final pasos = [
    for (var i = 1; i <= 5; i++)
      '{"id": "P$i", "fase": "${i <= 2 ? 'antes' : 'durante'}", "nombre": "Paso largo $i", '
          '"que_pasa": "Lo que pasa en este paso, contado con palabras sencillas para que se entienda bien.", '
          '"quien_esta": ["Tu familia o un adulto de confianza", "El juez o la jueza"], '
          '"que_puedes_pedir": [$pedir], "fuentes": ["LECrim, art. 433", "Ley 4/2015, art. 4"]}',
  ].join(', ');
  return '{"rol": "testigo", "validado": true, "pasos": [$pasos]}';
}

/// La tarjeta del paso cuya cabecera es [cabecera].
Rect _tarjeta(WidgetTester tester, Finder cabecera) =>
    tester.getRect(find.ancestor(of: cabecera, matching: find.byType(AnimatedContainer)).first);

/// La zona visible de la pantalla con scroll.
Rect _ventana(WidgetTester tester) => tester.getRect(find.byType(Scrollable).first);

void main() {
  group('LineaPasos', () {
    testWidgets('enseña los pasos en orden, agrupados por fase, y cada uno se lee «Paso N de 6: …»', (tester) async {
      await montarLinea(tester, repo: repoVictima);

      expect(find.text('Tu camino, paso a paso'), findsOneWidget);
      for (final nombre in nombresConFases) {
        expect(find.text(nombre), findsOneWidget);
      }
      final alturas = [for (final nombre in nombresConFases) tester.getTopLeft(find.text(nombre)).dy];
      expect(alturas, orderedEquals([...alturas]..sort()));
      // Las fases son carteles de sala (en mayúsculas), con su icono de la capa justicia.
      for (final fase in ['ANTES', 'DURANTE', 'DESPUÉS']) {
        expect(find.text(fase), findsOneWidget);
      }
      for (final icono in [TuIcono.citacion, TuIcono.puertaSala, TuIcono.reloj]) {
        expect(find.byWidgetPredicate((w) => w is IconoTuTurno && w.icono == icono), findsOneWidget);
      }
      expect(find.bySemanticsLabel(RegExp(r'^Paso 1 de 6: Te llega una citación')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Paso 4 de 6: La entrevista en la Sala Gesell')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Paso 6 de 6: Te cuentan cómo acaba')), findsOneWidget);
      expect(find.text('Puedes pedir 2 cosas'), findsOneWidget);
      // Cerrados al empezar, y sin fase elegida no se marca nada.
      expect(find.text('Qué pasa'), findsNothing);
      expect(find.text('Estás aquí'), findsNothing);
      expect(find.textContaining('guía general'), findsOneWidget);
    });

    testWidgets('al tocar un paso se abre con qué pasa, quién estará, qué puedes pedir y las fuentes', (tester) async {
      await montarLinea(tester, repo: repoVictima);
      final entrevista = find.bySemanticsLabel(RegExp(r'^Paso 4 de 6'));
      expect(tester.getSemantics(entrevista), isSemantics(isButton: true, hasExpandedState: true, isExpanded: false));

      await _pulsar(tester, find.text('La entrevista en la Sala Gesell'));

      expect(tester.getSemantics(entrevista), isSemantics(isExpanded: true));
      expect(find.text('Qué pasa'), findsOneWidget);
      expect(find.textContaining('Te hace las preguntas una persona preparada'), findsOneWidget);
      expect(find.text('Quién estará'), findsOneWidget);
      expect(find.text('Una psicóloga o un psicólogo del juzgado'), findsOneWidget);
      // Quién estará, con los personajes de «Vive el caso»: la psicóloga es Ana, la del caso de Lucía.
      expect(find.byWidgetPredicate((w) => w is RetratoPersonaje && w.id == 'ana'), findsOneWidget);
      expect(find.text('Como Ana, la psicóloga del caso de Lucía'), findsOneWidget);
      expect(find.text('Puedes pedir'), findsOneWidget);
      expect(find.text('Un descanso'), findsOneWidget);
      expect(find.text('Que te repitan una pregunta'), findsOneWidget);
      expect(find.text('LECrim · art. 449 ter'), findsOneWidget);
      expect(find.text('LECrim · art. 449 bis'), findsOneWidget);
      // Los demás siguen cerrados.
      expect(find.textContaining('Un aviso oficial'), findsNothing);

      await _pulsar(tester, find.text('La entrevista en la Sala Gesell'));

      expect(find.text('Qué pasa'), findsNothing);
      expect(find.text('Un descanso'), findsNothing);
      expect(tester.getSemantics(entrevista), isSemantics(isExpanded: false));
    });

    testWidgets('marca «Estás aquí» en la fase actual y resalta sus pasos', (tester) async {
      await montarLinea(tester, repo: repoVictima, faseActual: Fase.durante);

      expect(find.text('Estás aquí'), findsOneWidget);
      expect(find.bySemanticsLabel('Durante. Estás aquí'), findsOneWidget);
      // La marca va junto a «Durante»: entre el último paso de antes y el primero de durante.
      final marca = tester.getCenter(find.text('Estás aquí')).dy;
      expect(marca, greaterThan(tester.getCenter(find.text('Te explican tus derechos')).dy));
      expect(marca, lessThan(tester.getCenter(find.text('Llegas al juzgado')).dy));
      // Los pasos de esa fase se resaltan (y se dice al lector de pantalla); los demás, no.
      for (final numero in [3, 4]) {
        expect(find.bySemanticsLabel(RegExp('^Paso $numero de 6: .*Estás en esta parte')), findsOneWidget);
        expect(_rellenoNodo(tester, numero), _primario(tester));
      }
      for (final numero in [1, 2, 5, 6]) {
        expect(find.bySemanticsLabel(RegExp('^Paso $numero de 6: .*Estás en esta parte')), findsNothing);
        expect(_rellenoNodo(tester, numero), isNot(_primario(tester)));
      }
    });

    testWidgets('«Estás aquí» sale una sola vez aunque la fase vuelva a aparecer más abajo', (tester) async {
      final (repo, _) = repoCon({
        real('testigo'): '''
          {"rol": "testigo", "validado": true, "pasos": [
            {"id": "P1", "fase": "durante", "nombre": "Uno", "fuentes": ["LECrim, art. 433"]},
            {"id": "P2", "fase": "antes", "nombre": "Dos", "fuentes": ["Ley 4/2015, art. 4"]},
            {"id": "P3", "fase": "durante", "nombre": "Tres", "fuentes": ["LECrim, art. 433"]}
          ]}
        ''',
      });
      await montarLinea(tester, repo: repo, rol: 'testigo', faseActual: Fase.durante);

      expect(find.text('Estás aquí'), findsOneWidget);
      expect(find.text('DURANTE'), findsNWidgets(2));
      // Los pasos de la fase siguen resaltados en los dos grupos.
      expect(find.bySemanticsLabel(RegExp(r'^Paso 1 de 3: .*Estás en esta parte')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Paso 3 de 3: .*Estás en esta parte')), findsOneWidget);
    });

    testWidgets('sin faseActual, marca la fase del formulario de entrada si el papel es el mismo', (tester) async {
      await montarLinea(
        tester,
        repo: repoVictima,
        preferencias: entradaGuardada(rol: 'victima', fase: 'despues'),
      );

      expect(find.bySemanticsLabel('Después. Estás aquí'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Paso 5 de 6: .*Estás en esta parte')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Paso 6 de 6: .*Estás en esta parte')), findsOneWidget);
    });

    testWidgets('si en el formulario eligió otro papel, no le dice dónde está', (tester) async {
      await montarLinea(
        tester,
        repo: repoVictima,
        preferencias: entradaGuardada(rol: 'testigo', fase: 'durante'),
      );

      expect(find.text('Estás aquí'), findsNothing);
      expect(find.text('Llegas al juzgado'), findsOneWidget);
    });

    testWidgets('cada fuente es una etiqueta que abre una hoja con la referencia', (tester) async {
      await montarLinea(tester, repo: repoVictima);
      await _pulsar(tester, find.text('La entrevista en la Sala Gesell'));

      await _pulsar(tester, find.text('LECrim · art. 449 ter'));

      final hoja = find.byType(BottomSheet);
      expect(hoja, findsOneWidget);
      Finder enHoja(Finder finder) => find.descendant(of: hoja, matching: finder);
      expect(enHoja(find.text('De dónde sale')), findsOneWidget);
      expect(enHoja(find.textContaining('«La entrevista en la Sala Gesell»')), findsOneWidget);
      expect(enHoja(find.text('LECrim · art. 449 ter')), findsOneWidget);
      expect(enHoja(find.text('Ley de Enjuiciamiento Criminal')), findsOneWidget);
      expect(enHoja(find.textContaining('Es la ley en la que se apoya')), findsOneWidget);

      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('el lector de pantalla oye el nombre fácil de cada fuente, y la AEPD no se presenta como una ley', (
      tester,
    ) async {
      final (repo, _) = repoCon({
        real('victima'): '''
          {"rol": "victima", "validado": true, "pasos": [
            {"id": "P1", "fase": "antes", "nombre": "Se pide ayuda",
             "que_pasa": "Se cuenta a la policía o a la Fiscalía.",
             "fuentes": ["LO 5/2000, art. 16.2", "AEPD, Canal prioritario y FAQ 15.03"]}
          ]}
        ''',
      });
      await montarLinea(tester, repo: repo);
      await _pulsar(tester, find.text('Se pide ayuda'));

      final fuente = find.bySemanticsLabel('Fuente: Ley de responsabilidad penal de los menores, artículo 16.2');
      expect(fuente, findsOneWidget);
      expect(tester.getSemantics(fuente), isSemantics(isButton: true, onTapHint: 'ver de dónde sale'));
      expect(
        find.bySemanticsLabel('Fuente: Agencia Española de Protección de Datos, Canal prioritario y FAQ 15.03'),
        findsOneWidget,
      );

      await _pulsar(tester, find.text('AEPD · Canal prioritario y FAQ 15.03'));

      Finder enHoja(Finder finder) => find.descendant(of: find.byType(BottomSheet), matching: finder);
      expect(enHoja(find.text('Agencia Española de Protección de Datos')), findsOneWidget);
      expect(
        enHoja(find.textContaining('información oficial de la Agencia Española de Protección de Datos')),
        findsOneWidget,
      );
      expect(enHoja(find.textContaining('Es la ley')), findsNothing);
    });

    testWidgets('sin pasos para el papel, lo dice con calma', (tester) async {
      final (repo, _) = repoCon({});
      await montarLinea(tester, repo: repo, rol: 'escuchado_familia');

      expect(find.byType(EstadoVacio), findsOneWidget);
      expect(find.text(textoSinPasos), findsOneWidget);
      expect(find.text('Tu camino, paso a paso'), findsNothing);
    });

    testWidgets('un itinerario sin validar tampoco se enseña', (tester) async {
      final (repo, _) = repoCon({real('testigo'): itinerarioSeccion95});
      await montarLinea(tester, repo: repo, rol: 'testigo');

      expect(find.text(textoSinPasos), findsOneWidget);
      expect(find.text('Te llega una citación'), findsNothing);
    });

    testWidgets('mientras carga, enseña Cargando', (tester) async {
      final carga = Completer<Itinerario?>();
      await montarLinea(
        tester,
        repo: repoVictima,
        overrides: [itinerarioProvider.overrideWith((ref, rol) => carga.future)],
        esperar: false,
      );
      await tester.pump();

      expect(find.byType(Cargando), findsOneWidget);
      expect(find.text('Preparando tus pasos…'), findsOneWidget);

      carga.complete(itinerarioDe(itinerarioConFases));
      await tester.pumpAndSettle();
      expect(find.byType(Cargando), findsNothing);
      expect(find.text('Te llega una citación'), findsOneWidget);
    });

    testWidgets('si falla, enseña el error y «Reintentar» lo vuelve a intentar, enseñando que carga', (tester) async {
      var intentos = 0;
      final reintento = Completer<Itinerario?>();
      await montarLinea(
        tester,
        repo: repoVictima,
        overrides: [
          itinerarioProvider.overrideWith((ref, rol) async {
            if (intentos++ == 0) throw StateError('fallo inesperado');
            return reintento.future;
          }),
        ],
      );

      expect(find.byType(EstadoError), findsOneWidget);
      await tester.ensureVisible(find.text('Reintentar'));
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Mientras lo vuelve a intentar no se queda el error: se ve que está cargando.
      expect(intentos, 2);
      expect(find.byType(Cargando), findsOneWidget);
      expect(find.byType(EstadoError), findsNothing);

      reintento.complete(itinerarioDe(itinerarioConFases));
      await tester.pumpAndSettle();
      expect(find.byType(EstadoError), findsNothing);
      expect(find.text('Te llega una citación'), findsOneWidget);
    });

    for (final sinAnimaciones in [false, true]) {
      testWidgets('al abrir abajo un paso que no cabe en la pantalla, lo sube para leerlo desde el principio'
          '${sinAnimaciones ? ', también sin animaciones' : ''}', (tester) async {
        final (repo, _) = repoCon({real('testigo'): _itinerarioLargo()});
        await montarLinea(
          tester,
          repo: repo,
          rol: 'testigo',
          tamano: const Size(360, 640),
          sinAnimaciones: sinAnimaciones,
        );
        final cabecera = find.bySemanticsLabel(RegExp(r'^Paso 4 de 5'));
        // Como si hubiera bajado hasta dejar la cabecera del paso 4 en la parte de abajo de la pantalla.
        await Scrollable.ensureVisible(tester.element(cabecera), alignment: 0.8);
        await tester.pumpAndSettle();
        final ventana = _ventana(tester);
        expect(tester.getRect(cabecera).top, greaterThan(ventana.center.dy));

        // Sin tester.ensureVisible: el desplazamiento lo tiene que hacer la línea de pasos.
        await tester.tap(cabecera);
        await tester.pumpAndSettle();

        expect(tester.getSemantics(cabecera), isSemantics(isExpanded: true));
        expect(_tarjeta(tester, cabecera).height, greaterThan(ventana.height), reason: 'el paso abierto no cabe');
        expect(tester.getRect(cabecera).top, inInclusiveRange(ventana.top, ventana.top + Espacio.xl));
      });
    }

    testWidgets('al abrir abajo un paso que cabe, se desplaza lo justo para verlo entero', (tester) async {
      await montarLinea(tester, repo: repoVictima, tamano: const Size(390, 900));
      final cabecera = find.bySemanticsLabel(RegExp(r'^Paso 6 de 6'));
      await Scrollable.ensureVisible(tester.element(cabecera), alignment: 1);
      await tester.pumpAndSettle();

      await tester.tap(cabecera);
      await tester.pumpAndSettle();

      final ventana = _ventana(tester);
      final tarjeta = _tarjeta(tester, cabecera);
      expect(tarjeta.height, lessThan(ventana.height));
      expect(tarjeta.top, greaterThanOrEqualTo(ventana.top));
      expect(tarjeta.bottom, lessThanOrEqualTo(ventana.bottom));
    });

    testWidgets('un cambio de tamaño de la ventana no hace saltar la página hasta un paso abierto', (tester) async {
      await montarLinea(tester, repo: repoVictima);
      await _pulsar(tester, find.text('Te cuentan cómo acaba'));
      final posicion = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      posicion.jumpTo(0);
      await tester.pumpAndSettle();

      // Gira el móvil o cambia el tamaño de la ventana del navegador: el texto se recoloca y la tarjeta cambia de alto.
      tester.view.physicalSize = const Size(320, 844) * tester.view.devicePixelRatio;
      await tester.pumpAndSettle();

      expect(posicion.pixels, 0);
    });

    testWidgets('al cerrar un paso, su contenido se queda mientras la tarjeta se encoge', (tester) async {
      await montarLinea(tester, repo: repoVictima);
      final entrevista = find.text('La entrevista en la Sala Gesell');
      await _pulsar(tester, entrevista);
      expect(find.semantics.byLabel('Qué pasa'), findsOneWidget);

      await tester.tap(entrevista);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // A mitad: el texto sigue ahí, recortado, pero el lector de pantalla ya no lo lee.
      expect(find.text('Qué pasa'), findsOneWidget);
      expect(find.semantics.byLabel('Qué pasa'), findsNothing);
      expect(tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Paso 4 de 6'))), isSemantics(isExpanded: false));

      await tester.pumpAndSettle();
      expect(find.text('Qué pasa'), findsNothing);
    });

    testWidgets('tocar el número de un paso también lo abre y lo cierra', (tester) async {
      await montarLinea(tester, repo: repoVictima);
      final entrevista = find.bySemanticsLabel(RegExp(r'^Paso 4 de 6'));

      await _pulsar(tester, find.text('4'));
      expect(tester.getSemantics(entrevista), isSemantics(isExpanded: true));
      expect(find.text('Qué pasa'), findsOneWidget);

      await _pulsar(tester, find.text('4'));
      expect(tester.getSemantics(entrevista), isSemantics(isExpanded: false));
      // El número no es otro botón para el lector de pantalla: la acción ya la lleva la cabecera del paso.
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets(
      'con letra a 1,3, tema oscuro y un móvil estrecho no se desborda y cumple las pautas de accesibilidad',
      (tester) async {
        await montarLinea(
          tester,
          repo: repoVictima,
          faseActual: Fase.durante,
          escalaTexto: 1.3,
          brillo: Brightness.dark,
          tamano: const Size(320, 640),
        );
        expect(Theme.of(tester.element(find.byType(LineaPasos))).brightness, Brightness.dark);

        for (final nombre in nombresConFases) {
          await _pulsar(tester, find.text(nombre));
        }

        expect(find.text('Qué pasa'), findsNWidgets(nombresConFases.length));
        expect(_rellenoNodo(tester, 3), _primario(tester));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      },
    );

    testWidgets('con «reducir animaciones», aparece y se abre al momento', (tester) async {
      await montarLinea(tester, repo: repoVictima, faseActual: Fase.antes, sinAnimaciones: true, esperar: false);
      await tester.pump();
      await tester.pump();

      expect(find.text('Te llega una citación'), findsOneWidget);
      expect(find.text('Estás aquí'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);

      await tester.tap(find.text('Te llega una citación'));
      await tester.pump();
      await tester.pump();

      // Abierto del todo en el primer frame: ni crece ni aparece poco a poco. (La onda del toque sí se anima.)
      final quePasa = find.text('Qué pasa');
      expect(quePasa, findsOneWidget);
      expect(_opacidad(tester, quePasa), 1);
      final antes = tester.getRect(quePasa);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.getRect(quePasa), antes);
      expect(tester.takeException(), isNull);
    });
  });

  group('fase marcada y capa justicia', () {
    testWidgets('con la Entrada en víctima · durante, la línea de víctima marca «Estás aquí» en Durante', (
      tester,
    ) async {
      await montarLinea(
        tester,
        repo: repoVictima,
        preferencias: entradaGuardada(rol: 'victima', fase: 'durante'),
      );

      expect(find.text('Estás aquí'), findsOneWidget);
      expect(find.bySemanticsLabel('Durante. Estás aquí'), findsOneWidget);
      final marca = tester.getCenter(find.text('Estás aquí')).dy;
      expect(marca, greaterThan(tester.getCenter(find.text('Te explican tus derechos')).dy));
      expect(marca, lessThan(tester.getCenter(find.text('Llegas al juzgado')).dy));
    });

    testWidgets('quién estará: la jueza con la toga y el fiscal con la ley (nunca un mazo ni la balanza)', (
      tester,
    ) async {
      final (repo, _) = repoCon({real('victima'): _itinerarioJusticia});
      await montarLinea(tester, repo: repo);
      await _pulsar(tester, find.text('Te escuchan'));

      // Fuera de la sala (sin toga en el dibujo), la jueza es su icono: la toga.
      expect(find.byWidgetPredicate((w) => w is IconoTuTurno && w.icono == TuIcono.toga), findsOneWidget);
      // El fiscal sale con su personaje sin toga (el del despacho) y, en la esquina, el icono de la ley.
      expect(find.byWidgetPredicate((w) => w is RetratoPersonaje && w.id == 'fiscal-despacho'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is IconoTuTurno && w.icono == TuIcono.ley), findsWidgets);
      // «De dónde sale» lleva el libro de la ley.
      expect(find.text('De dónde sale'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is IconoTuTurno && w.icono == TuIcono.balanza), findsNothing);
    });

    testWidgets('en la sala (estrados), la jueza y el fiscal salen con su toga', (tester) async {
      final (repo, _) = repoCon({real('victima'): _itinerarioJusticia});
      await montarLinea(
        tester,
        repo: repo,
        personalizacion: const PersonalizacionLinea(extras: {'P2': ExtrasPaso(enSala: true)}),
      );
      await _pulsar(tester, find.text('Te escuchan'));

      expect(find.byWidgetPredicate((w) => w is RetratoPersonaje && w.id == 'jueza'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is RetratoPersonaje && w.id == 'fiscal'), findsOneWidget);
    });
  });

  group('personalizada (Mi situación)', () {
    testWidgets('«Para ti», el ejemplo y con quién irás salen en su paso, con sus fuentes', (tester) async {
      final (repo, _) = repoCon({real('victima'): _itinerarioJusticia});
      await montarLinea(
        tester,
        repo: repo,
        personalizacion: const PersonalizacionLinea(
          estilo: EstiloExplicacion.ejemplos,
          conQuien: 'una persona de confianza',
          extras: {
            'P2': ExtrasPaso(
              esCita: true,
              ejemplo: 'Lucía va con su tía Elena.',
              paraTi: [
                NotaParaTi(texto: 'Como tienes 11 años, se graba.', fuentes: ['LECrim, art. 449 ter']),
              ],
              llevar: [CosaQueLlevar(id: 'agua', texto: 'Agua y algo de comer')],
            ),
          },
        ),
      );
      await _pulsar(tester, find.text('Te escuchan'));

      expect(find.text('Para ti'), findsOneWidget);
      expect(find.text('Como tienes 11 años, se graba.'), findsOneWidget);
      expect(find.text('LECrim · art. 449 ter'), findsWidgets);
      expect(find.textContaining('Lucía va con su tía Elena.'), findsOneWidget);
      expect(find.text('Tú irás con una persona de confianza'), findsOneWidget);
      expect(find.text('Qué llevar'), findsOneWidget);
      expect(find.text('Agua y algo de comer'), findsOneWidget);
      // El ejemplo solo sale si lo prefiere con ejemplos.
    });

    testWidgets('sin «con ejemplos», el ejemplo no sale; con «corto», «Qué pasa» se queda en su primera frase', (
      tester,
    ) async {
      final (repo, _) = repoCon({real('victima'): _itinerarioJusticia});
      await montarLinea(
        tester,
        repo: repo,
        personalizacion: const PersonalizacionLinea(
          estilo: EstiloExplicacion.corto,
          extras: {'P2': ExtrasPaso(ejemplo: 'Lucía va con su tía Elena.')},
        ),
      );
      await _pulsar(tester, find.text('Te escuchan'));

      expect(find.textContaining('Lucía va con su tía Elena.'), findsNothing);
      expect(find.text('Te escuchan en una sala preparada.'), findsOneWidget);
      expect(find.textContaining('Se graba para el juicio'), findsNothing);
      await _pulsar(tester, find.text('Leer todo'));
      expect(find.textContaining('Se graba para el juicio'), findsOneWidget);
    });

    testWidgets('«Paso a paso» abre el paso de tu momento y lleva «Siguiente paso»', (tester) async {
      final (repo, _) = repoCon({real('victima'): _itinerarioJusticia});
      await montarLinea(
        tester,
        repo: repo,
        faseActual: Fase.durante,
        personalizacion: const PersonalizacionLinea(estilo: EstiloExplicacion.pasoAPaso),
      );

      // Abierto al entrar: el primero de «Durante» (el paso 2).
      expect(tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Paso 2 de 3'))), isSemantics(isExpanded: true));
      await _pulsar(tester, find.text('Siguiente paso: El juicio'));
      expect(tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Paso 2 de 3'))), isSemantics(isExpanded: false));
      expect(tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Paso 3 de 3'))), isSemantics(isExpanded: true));
      // El último no tiene siguiente.
      expect(find.textContaining('Siguiente paso'), findsNothing);
    });

    testWidgets('un paso que no es para tu edad lo dice, y el lector de pantalla también', (tester) async {
      final (repo, _) = repoCon({real('victima'): _itinerarioJusticia});
      await montarLinea(
        tester,
        repo: repo,
        personalizacion: const PersonalizacionLinea(
          extras: {'P3': ExtrasPaso(noEsParaTi: 'Este paso es para chicos y chicas de 14 a 17 años')},
        ),
      );
      expect(find.text('Este paso es para chicos y chicas de 14 a 17 años'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'^Paso 3 de 3: El juicio\. Este paso es para chicos y chicas de 14 a 17 años')),
        findsOneWidget,
      );
    });

    testWidgets('«Pregúntaselo a TuTurno» lleva la duda del paso (o una por defecto) ya escrita', (tester) async {
      final preguntas = <(String, String)>[];
      final (repo, _) = repoCon({real('victima'): _itinerarioJusticia});
      await montarLinea(
        tester,
        repo: repo,
        personalizacion: PersonalizacionLinea(
          extras: const {'P2': ExtrasPaso(duda: '¿Cómo será el día que me escuchen?')},
          alPreguntar: (paso, duda) => preguntas.add((paso.id, duda)),
        ),
      );
      await _pulsar(tester, find.text('Te escuchan'));
      expect(find.text('«¿Cómo será el día que me escuchen?»'), findsOneWidget);
      await _pulsar(tester, find.text('Pregúntaselo a TuTurno'));
      expect(preguntas, [('P2', '¿Cómo será el día que me escuchen?')]);

      await _pulsar(tester, find.text('Te escuchan'));
      await _pulsar(tester, find.text('El juicio'));
      await _pulsar(tester, find.text('Pregúntaselo a TuTurno'));
      expect(preguntas.last, ('P3', '¿Me explicas qué pasa en el paso «El juicio»?'));
    });

    testWidgets('sin «alPreguntar», no sale el botón de Pregunta', (tester) async {
      final (repo, _) = repoCon({real('victima'): _itinerarioJusticia});
      await montarLinea(tester, repo: repo);
      await _pulsar(tester, find.text('Te escuchan'));
      expect(find.text('Pregúntaselo a TuTurno'), findsNothing);
    });

    testWidgets('las palabras que oirás salen del Glosario (las pedidas primero) y cada una es un botón', (
      tester,
    ) async {
      final (repo, _) = repoCon({real('victima'): _itinerarioJusticia, '${ContentRepo.raiz}/glosario.json': _glosario});
      await montarLinea(
        tester,
        repo: repo,
        personalizacion: const PersonalizacionLinea(
          extras: {
            'P2': ExtrasPaso(palabras: ['Sala Gesell']),
          },
        ),
      );
      await _pulsar(tester, find.text('Te escuchan'));

      expect(find.text('Palabras que oirás'), findsOneWidget);
      final chips = tester.widgetList<ActionChip>(find.byType(ActionChip)).map((c) => (c.label as Text).data);
      expect(chips, containsAllInOrder(['Sala Gesell', 'Prueba preconstituida']));
      expect(find.bySemanticsLabel('Palabra: Sala Gesell'), findsOneWidget);
    });
  });

  test('el icono de cada persona sale de quién es: manda la palabra que aparece antes', () {
    expect(iconoPersona('Una psicóloga o un psicólogo del juzgado'), TuIcono.idea);
    expect(iconoPersona('El juez o la jueza, que cuida de que todo sea justo'), TuIcono.toga);
    expect(iconoPersona('El fiscal o la fiscal, que defiende tus derechos'), TuIcono.ley);
    expect(iconoPersona('El abogado o la abogada de la persona investigada'), TuIcono.expediente);
    expect(iconoPersona('Policías, fiscales o personas del juzgado'), TuIcono.escudo);
    expect(iconoPersona('Tu familia o un adulto de confianza, que puede acompañarte'), TuIcono.personaConfianza);
    expect(
      iconoPersona(
        'Quien te represente y una persona de confianza que elijas tú, salvo que el juez explique por qué no',
      ),
      TuIcono.personaConfianza,
    );
    expect(iconoPersona('Tu tutor legal'), TuIcono.personaConfianza);
    expect(iconoPersona('En tu colegio o instituto, el coordinador o la coordinadora de bienestar'), TuIcono.aprende);
    expect(iconoPersona('Una trabajadora social'), TuIcono.ayuda);
    // Los de los itinerarios: servicios sociales que ayudan a la familia, no la familia.
    expect(iconoPersona('Servicios sociales, que pueden ayudar a tu familia'), TuIcono.ayuda);
    expect(
      iconoPersona(
        'En un proceso de protección, servicios sociales o de protección de menores, que ayudan a tu familia',
      ),
      TuIcono.ayuda,
    );
    expect(iconoPersona('Otras personas'), TuIcono.miSituacion);
  });
}

/// Itinerario de víctima para la capa justicia y la personalización: la jueza y el fiscal en el paso 2.
const _itinerarioJusticia = """
{"rol": "victima", "validado": true, "pasos": [
  {"id": "P1", "fase": "antes", "nombre": "Te citan", "que_pasa": "Llega un aviso.",
   "quien_esta": ["Tu familia"], "que_puedes_pedir": ["Que te lo expliquen"], "fuentes": ["Ley 4/2015, art. 4"]},
  {"id": "P2", "fase": "durante", "nombre": "Te escuchan",
   "que_pasa": "Te escuchan en una sala preparada. Se graba para el juicio y es la prueba preconstituida.",
   "quien_esta": ["El juez o la jueza, que cuida de que todo sea justo", "El fiscal o la fiscal, que vigila tus derechos"],
   "que_puedes_pedir": ["Un descanso"], "fuentes": ["LECrim, art. 449 ter"]},
  {"id": "P3", "fase": "durante", "nombre": "El juicio", "que_pasa": "Normalmente ponen la grabación.",
   "quien_esta": ["El juez o la jueza"], "que_puedes_pedir": [], "fuentes": ["LECrim, art. 703 bis"]}
]}
""";

/// Glosario mínimo para «Palabras que oirás».
const _glosario = """
[
  {"id": "G-sala-gesell", "termino": "Sala Gesell", "definicion": "Una sala preparada.", "fuente": "LECrim, art. 449 ter", "validado": true},
  {"id": "G-prueba-preconstituida", "termino": "Prueba preconstituida", "definicion": "Se graba.", "fuente": "LECrim, art. 449 ter", "validado": true},
  {"id": "G-juicio", "termino": "Juicio", "definicion": "Donde se decide.", "fuente": "Ley 4/2015, art. 7.1", "validado": true}
]
""";
