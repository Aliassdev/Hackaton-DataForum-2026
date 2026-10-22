import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/demo.dart';
import 'package:tuturno/core/progreso.dart';
import 'package:tuturno/core/providers.dart' show ajustesProvider;
import 'package:tuturno/features/juego/caso_screen.dart';
import 'package:tuturno/features/juego/juego_providers.dart';
import 'package:tuturno/features/juego/modelos.dart';
import 'package:tuturno/features/juego/textos.dart';
import 'package:tuturno/features/juego/widgets/cabecera_escena.dart';
import 'package:tuturno/features/juego/juzgado_screen.dart' show JuzgadoScreen, tituloEnRevision;
import 'package:tuturno/features/juego/widgets/escena_juego.dart'
    show ExplicacionPixel, VistaEscenaJuego, ordenDeLasOpciones;
import 'package:tuturno/pixel/escenarios/escenarios.dart';
import 'package:tuturno/pixel/juzgado/juzgado.dart' show ModoJuzgado;
import 'package:tuturno/pixel/motor/motor.dart';
import 'package:tuturno/pixel/personajes/personajes.dart';
import 'package:tuturno/pixel/ui/ui.dart';

import 'fakes.dart';

final _caso = Caso.fromJson(jsonDecode(casoPrueba) as Map<String, dynamic>);
Escena _escena(String id) => _caso.escena(id)!;
Opcion _opcion(String escena, int i) => _escena(escena).decision!.opciones[i];

const _ruta = '/juego/caso-prueba';

/// Elige la opción [i] de [escena] (por su texto).
Future<void> _elegir(WidgetTester tester, String escena, int i) => pulsar(tester, find.text(_opcion(escena, i).texto));

/// Recoge la carta nueva y cierra su ventana.
Future<void> _recogerCarta(WidgetTester tester) async {
  await pulsar(tester, find.text(botonRecogerCarta));
  await pulsar(tester, find.text(botonAMiColeccion));
}

/// Juega el caso de prueba hasta la última escena (E4), sin terminarlo.
Future<void> _jugarHastaElFinal(WidgetTester tester) async {
  await _elegir(tester, 'E1', 0);
  await _recogerCarta(tester);
  await pulsar(tester, find.text(botonSeguir));
  await _elegir(tester, 'E3', 1);
  await _recogerCarta(tester);
}

/// Juega un caso entero eligiendo siempre la primera respuesta correcta.
Future<void> _jugarEntero(WidgetTester tester, String casoId) async {
  for (var i = 0; i < 40 && find.text(tituloFinal).evaluate().isEmpty; i++) {
    if (find.text(botonRecogerCarta).evaluate().isNotEmpty) {
      await _recogerCarta(tester);
    } else if (find.text(botonSeguir).evaluate().isNotEmpty) {
      await pulsar(tester, find.text(botonSeguir));
    } else if (find.text(botonTerminar).evaluate().isNotEmpty) {
      await pulsar(tester, find.text(botonTerminar));
    } else {
      final escena = contenedor(tester).read(partidaProvider(casoId)).value!.escena;
      await pulsar(tester, find.text(escena.decision!.opciones.firstWhere((o) => o.correcta).texto));
    }
  }
}

HudPixel _hud(WidgetTester tester) => tester.widget<HudPixel>(find.byType(HudPixel));

/// El fondo de la escena que se ve en el reproductor.
Sprite _fondoDeLaEscena(WidgetTester tester) => tester
    .widget<EscenaPixel>(find.descendant(of: find.byType(CabeceraEscena), matching: find.byType(EscenaPixel)))
    .fondo;

Finder _botonOpciones() => find.byWidgetPredicate((w) => w is BotonPixel && w.semantica == menuOpciones);

/// Tut, contento, en la explicación de una respuesta.
Finder _tutEnLaExplicacion() => find.descendant(
  of: find.byType(ExplicacionPixel),
  matching: find.byWidgetPredicate((w) => w is SpritePixel && identical(w.sprite, PersonajesPixel.tutFeliz)),
);

void main() {
  group('una escena', () {
    testWidgets('el HUD lleva el nombre; la primera línea, el caso y la edad; la escena es pixel art', (tester) async {
      await abrirJuego(
        tester,
        ruta: _ruta,
        overrides: await overridesJuego(tts: FakeTts()),
      );

      expect(_hud(tester).titulo, 'Nora', reason: 'el título no se corta: solo el nombre (P1-1)');
      expect(find.text(saludoTut('Nora')), findsOneWidget, reason: 'al abrir el caso, Tut saluda');
      expect(
        find.byWidgetPredicate((w) => w is SpritePixel && identical(w.sprite, PersonajesPixel.tutFeliz)),
        findsOneWidget,
        reason: 'con su cara contenta',
      );
      expect(_hud(tester).textoProgreso, 'Escena 1 de 4');
      expect(_hud(tester).cartas, 0);
      expect(_hud(tester).totalCartas, 3);
      expect(find.text('Caso de Nora'), findsOneWidget);
      expect(find.text(edadCaso(12)), findsOneWidget);
      expect(find.byType(EscenaPixel), findsOneWidget);
      expect(_fondoDeLaEscena(tester), same(EscenariosPixel.colegio.fondo));
      expect(find.text('Nora'), findsNWidgets(2), reason: 'en el HUD y en su ficha');
      expect(find.text('Su tutor'), findsOneWidget, reason: 'las fichas de quién sale, debajo de la escena');
      expect(find.byType(DialogoPixel), findsOneWidget);
      expect(find.text(_escena('E1').narracion), findsOneWidget);
      expect(find.text(tuDecides), findsOneWidget);
      expect(find.text(_escena('E1').decision!.pregunta), findsOneWidget);
      expect(find.byType(MenuOpcionesPixel), findsOneWidget);
    });

    testWidgets('cada lugar tiene su fondo, también la habitación de Sara', (tester) async {
      await abrirJuego(
        tester,
        ruta: '/juego/caso-difusion-imagenes',
        overrides: await overridesJuego(casos: casosOficiales()),
      );
      expect(_fondoDeLaEscena(tester), same(EscenariosPixel.habitacion.fondo));

      await contenedor(tester).read(partidaProvider('caso-difusion-imagenes').notifier).empezarEn('S7');
      await tester.pumpAndSettle();
      expect(_fondoDeLaEscena(tester), same(EscenariosPixel.fiscalia.fondo));
      final personajes = tester
          .widget<EscenaPixel>(find.descendant(of: find.byType(CabeceraEscena), matching: find.byType(EscenaPixel)))
          .elementos
          .map((e) => e.sprite)
          .toList();
      expect(personajes, contains(same(PersonajesPixel.fiscalDespacho)), reason: 'en la Fiscalía, el fiscal sin toga');
      expect(personajes, contains(same(PersonajesPixel.abogadaDespacho)), reason: 'y la abogada, también sin toga');
      expect(personajes, isNot(contains(same(PersonajesPixel.abogadaVictima))));
    });

    testWidgets('la decisión sale cuando la narración está entera (un toque la completa)', (tester) async {
      await abrirJuego(
        tester,
        ruta: _ruta,
        asentar: false,
        overrides: await overridesJuego(tts: FakeTts(), vozActivada: false),
      );
      // Ya ha acabado la transición a bloques de la escena (mientras dura, no se puede tocar nada), pero la narración
      // aún se está escribiendo (sin voz, a 40 letras por segundo).
      await tester.pump(DuracionTransicionPixel.entrada + const Duration(milliseconds: 100));
      expect(find.byType(DialogoPixel), findsOneWidget);
      expect(find.byType(MenuOpcionesPixel), findsNothing, reason: 'aún se está escribiendo');

      await tester.tap(find.byType(DialogoPixel));
      await tester.pump();
      await tester.pump();
      expect(find.byType(MenuOpcionesPixel), findsOneWidget, reason: 'el toque la ha completado');
      expect(find.text(_opcion('E1', 0).texto), findsOneWidget);
    });

    testWidgets('al aparecer la decisión, la narración no se sale por arriba', (tester) async {
      // 412 × 915: la escena se queda fija arriba y lo de debajo se desplaza.
      await abrirJuego(
        tester,
        ruta: _ruta,
        asentar: false,
        overrides: await overridesJuego(tts: FakeTts(), vozActivada: false),
      );
      await tester.pump(DuracionTransicionPixel.entrada + const Duration(milliseconds: 100));
      await tester.tap(find.byType(DialogoPixel));
      await tester.pumpAndSettle();

      expect(find.byType(MenuOpcionesPixel), findsOneWidget);
      final vista = tester.getRect(_scrollDeLaEscena(tester));
      expect(tester.getTopLeft(find.byType(DialogoPixel)).dy, greaterThanOrEqualTo(vista.top - 0.5));
    });

    testWidgets('con «reducir animaciones», la escena no salta: se lee desde arriba y la decisión espera debajo', (
      tester,
    ) async {
      await abrirJuego(
        tester,
        ruta: _ruta,
        reducirAnimaciones: true,
        overrides: await overridesJuego(vozActivada: false),
      );

      expect(find.byType(MenuOpcionesPixel), findsOneWidget);
      expect(tester.state<ScrollableState>(_scrollDeLaEscena(tester)).position.pixels, 0);
    });

    testWidgets('con «reducir animaciones» la narración sale entera de golpe', (tester) async {
      await abrirJuego(
        tester,
        ruta: _ruta,
        asentar: false,
        reducirAnimaciones: true,
        overrides: await overridesJuego(vozActivada: false),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(MenuOpcionesPixel), findsOneWidget);
    });

    testWidgets('con «lectura fácil», todo el juego va en Atkinson Hyperlegible', (tester) async {
      await abrirJuego(tester, ruta: _ruta, overrides: await overridesJuego(lecturaFacil: true));
      final tema = tester.widget<TemaPixel>(
        find.ancestor(of: find.byType(HudPixel), matching: find.byType(TemaPixel)).first,
      );
      expect(tema.lecturaFacil, isTrue);
      expect(familiaPixel(tester.element(find.byType(DialogoPixel))), 'AtkinsonHyperlegible');

      // También en la ventana de la carta nueva.
      await _elegir(tester, 'E1', 0);
      await pulsar(tester, find.text(botonRecogerCarta));
      expect(familiaPixel(tester.element(find.byType(CartaPixel))), 'AtkinsonHyperlegible');
    });

    testWidgets('las palabras del glosario de la narración llevan a su entrada (también en femenino)', (tester) async {
      const caso = '''
{"id": "caso-termino", "titulo": "Iris y el instituto", "rol": "victima", "basado_en": [],
 "escenas": [{"id": "S1", "lugar": "instituto", "personajes": ["Iris"],
   "narracion": "Iris tiene 13 años. Habla con la coordinadora de bienestar y protección de su instituto."}],
 "cartas": [], "validado": true}
''';
      const glosario = '''
[{"id": "G-coord", "termino": "Coordinador de bienestar y protección",
  "definicion": "La persona del centro a la que puedes contar si sufres violencia.",
  "ejemplo": "", "fuente": "LOPIVI, art. 35", "validado": true}]
''';
      await abrirJuego(
        tester,
        ruta: '/juego/caso-termino',
        overrides: await overridesJuego(repo: repoDePrueba({'caso-termino.json': caso}, glosario: glosario)),
      );

      await pulsar(tester, find.text('coordinadora de bienestar y protección'));

      expect(find.text('glosario:Coordinador de bienestar y protección'), findsOneWidget);
    });
  });

  group('la voz', () {
    testWidgets('al entrar en el caso lee la narración y la pregunta, una sola vez', (tester) async {
      final tts = FakeTts();
      await abrirJuego(
        tester,
        ruta: _ruta,
        overrides: await overridesJuego(tts: tts),
      );

      expect(tts.leidos, [textoEscena(_escena('E1'))]);
      await tester.pump(const Duration(seconds: 2));
      expect(tts.leidos, hasLength(1), reason: 'no se repite al reconstruir');
    });

    testWidgets('con la voz desactivada no lee nada solo, pero «Escuchar» sí funciona', (tester) async {
      final tts = FakeTts();
      await abrirJuego(
        tester,
        ruta: _ruta,
        overrides: await overridesJuego(tts: tts, vozActivada: false),
      );

      await _elegir(tester, 'E1', 0);
      await _recogerCarta(tester);
      expect(find.text(_escena('E2').narracion), findsOneWidget);
      expect(tts.leidos, isEmpty);

      await pulsar(tester, find.byKey(const Key('boton-escuchar')));
      expect(tts.leidos, [textoEscena(_escena('E2'))]);
    });

    testWidgets('con lector de pantalla no lee solo (ya lee el lector) y el texto sale entero', (tester) async {
      final tts = FakeTts();
      await abrirJuego(
        tester,
        ruta: _ruta,
        lectorDePantalla: true,
        asentar: false,
        overrides: await overridesJuego(tts: tts),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(MenuOpcionesPixel), findsOneWidget, reason: 'sin máquina de escribir');
      await tester.pumpAndSettle();
      await _elegir(tester, 'E1', 0);
      expect(tts.leidos, isEmpty);
    });

    testWidgets('«Escuchar» lee y «Parar» se calla', (tester) async {
      final tts = FakeTts(terminarAlInstante: false);
      await abrirJuego(
        tester,
        ruta: _ruta,
        overrides: await overridesJuego(tts: tts, vozActivada: false),
      );

      await pulsar(tester, find.byKey(const Key('boton-escuchar')));
      expect(tts.leidos, [textoEscena(_escena('E1'))]);
      expect(find.text(botonParar), findsOneWidget);

      await pulsar(tester, find.byKey(const Key('boton-escuchar')));
      expect(tts.paradas, greaterThan(0));
      expect(find.text(botonEscuchar), findsOneWidget);
    });

    testWidgets('se calla al elegir, al abrir Ayuda y al salir del caso', (tester) async {
      final tts = FakeTts(terminarAlInstante: false);
      final router = await abrirJuego(
        tester,
        ruta: _ruta,
        overrides: await overridesJuego(tts: tts),
      );
      expect(tts.hablando.value, isTrue, reason: 'leyendo la narración');
      // Mientras la voz lee, el texto se escribe a su ritmo: se completa a mano para poder decidir.
      await tester.tap(find.byType(DialogoPixel));
      await tester.pumpAndSettle();

      await _elegir(tester, 'E1', 1);
      expect(tts.paradas, 1, reason: 'elegir corta la narración');
      expect(tts.leidos.last, textoExplicacion(_opcion('E1', 1)));

      router.push('/ayuda');
      await tester.pumpAndSettle();
      expect(tts.hablando.value, isFalse);
      expect(tts.paradas, 2);

      router.pop();
      await tester.pumpAndSettle();
      await pulsar(tester, find.byKey(const Key('boton-escuchar')));
      expect(tts.hablando.value, isTrue);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(CasoScreen), findsNothing);
      expect(tts.hablando.value, isFalse, reason: 'al salir del caso no se queda hablando');
    });

    testWidgets('al acabar de leer la narración, el texto se ve entero', (tester) async {
      final tts = FakeTts(terminarAlInstante: false);
      await abrirJuego(
        tester,
        ruta: _ruta,
        asentar: false,
        overrides: await overridesJuego(tts: tts),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tts.hablando.value, isTrue);
      expect(find.byType(MenuOpcionesPixel), findsNothing);

      await tts.parar();
      await tester.pump();
      await tester.pump();
      expect(find.byType(MenuOpcionesPixel), findsOneWidget);
    });

    testWidgets('al pasar de escena, el final de la lectura anterior no completa la narración nueva', (tester) async {
      final tts = FakeTts(terminarAlInstante: false);
      await abrirJuego(
        tester,
        ruta: _ruta,
        overrides: await overridesJuego(tts: tts),
      );
      await tester.tap(find.byType(DialogoPixel));
      await tester.pumpAndSettle();
      await _elegir(tester, 'E1', 1);
      await pulsar(tester, find.text(botonSeguir));
      expect(tts.leidos.last, textoEscena(_escena('E2')));

      await tester.tap(find.text(botonSeguir));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tts.leidos.last, textoEscena(_escena('E3')));
      expect(find.byType(MenuOpcionesPixel), findsNothing, reason: 'la narración de E3 sigue escribiéndose con la voz');
      await tester.pumpAndSettle();
      expect(find.byType(MenuOpcionesPixel), findsOneWidget);
    });

    testWidgets('desactivar la voz (en las opciones o en Ajustes) calla la lectura y deja de leer solo', (
      tester,
    ) async {
      final tts = FakeTts(terminarAlInstante: false);
      await abrirJuego(
        tester,
        ruta: _ruta,
        overrides: await overridesJuego(tts: tts),
      );
      expect(tts.hablando.value, isTrue);

      // Como si se cambiara en Ajustes mientras lee.
      await contenedor(tester).read(ajustesProvider.notifier).actualizar((a) => a.copyWith(vozActivada: false));
      await tester.pumpAndSettle();
      expect(tts.hablando.value, isFalse);

      // Las opciones del caso tienen el mismo interruptor.
      await pulsar(tester, _botonOpciones());
      await pulsar(tester, find.text('$menuLeerEnVozAlta: no'));
      expect(contenedor(tester).read(ajustesProvider).vozActivada, isTrue);
      await pulsar(tester, _botonOpciones());
      await pulsar(tester, find.text('$menuLeerEnVozAlta: sí'));
      expect(contenedor(tester).read(ajustesProvider).vozActivada, isFalse);

      final leidos = tts.leidos.length;
      await tester.tap(find.byType(DialogoPixel));
      await tester.pumpAndSettle();
      await _elegir(tester, 'E1', 0);
      expect(tts.leidos, hasLength(leidos), reason: 'sin voz, la explicación no se lee sola');
    });
  });

  group('decidir', () {
    testWidgets('acertar: «¡Bien visto!», Tut, la fuente y la carta nueva, que sale una sola vez', (tester) async {
      final tts = FakeTts();
      await abrirJuego(
        tester,
        ruta: _ruta,
        overrides: await overridesJuego(tts: tts),
      );
      expect(find.text(botonSeguir), findsNothing, reason: 'mientras no se decide, no hay botón para seguir');

      await _elegir(tester, 'E1', 0);

      expect(find.text(tituloAcierto), findsOneWidget);
      expect(find.text(_opcion('E1', 0).feedback), findsOneWidget);
      expect(_tutEnLaExplicacion(), findsOneWidget);
      expect(find.text('Ley 4/2015, art. 4'), findsOneWidget);
      expect(find.text(avisoCartaNueva), findsOneWidget);
      expect(tts.leidos.last, textoExplicacion(_opcion('E1', 0)));
      expect(contenedor(tester).read(progresoProvider).cartas, {'R-entender'}, reason: 'se guarda al acertar');
      expect(_hud(tester).cartas, 1);

      await pulsar(tester, find.text(botonRecogerCarta));
      expect(find.text(tituloCartaNueva), findsOneWidget);
      expect(find.byType(CartaPixel), findsOneWidget);
      expect(find.text('Tienes derecho a entender'), findsOneWidget, reason: 'ya desbloqueada');
      expect(find.byWidgetPredicate((w) => w is RotuloPixel && w.texto == '+10'), findsOneWidget);
      expect(find.text('puntos'), findsOneWidget);

      await pulsar(tester, find.text(botonAMiColeccion));
      expect(find.text(tituloCartaNueva), findsNothing);
      expect(find.text(_escena('E2').narracion), findsOneWidget);
      expect(_hud(tester).textoProgreso, 'Escena 2 de 4');
      expect(tts.leidos.last, textoEscena(_escena('E2')));

      // La misma carta no vuelve a salir como nueva.
      await pulsar(tester, _botonOpciones());
      await pulsar(tester, find.text(menuEmpezarDeNuevo));
      await pulsar(tester, find.widgetWithText(BotonPixel, menuEmpezarDeNuevo));
      await _elegir(tester, 'E1', 0);
      expect(find.text(avisoCartaRepetida), findsOneWidget);
      expect(find.text(botonRecogerCarta), findsNothing);
      expect(find.text(botonSeguir), findsOneWidget);
    });

    testWidgets('la carta nueva sale bloqueada y se desbloquea al momento; el fondo casi no deja ver nada', (
      tester,
    ) async {
      await abrirJuego(tester, ruta: _ruta, overrides: await overridesJuego());
      await _elegir(tester, 'E1', 0);
      await tester.tap(find.text(botonRecogerCarta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<CartaPixel>(find.byType(CartaPixel)).bloqueada, isTrue);

      await tester.pumpAndSettle();
      expect(tester.widget<CartaPixel>(find.byType(CartaPixel)).bloqueada, isFalse);
      final barrera = tester.widgetList<ModalBarrier>(find.byType(ModalBarrier)).last;
      expect(barrera.color!.a, greaterThanOrEqualTo(0.9), reason: 'auditoría P2-2');
    });

    testWidgets('la fuente se puede tocar y explica de qué ley sale', (tester) async {
      await abrirJuego(tester, ruta: _ruta, overrides: await overridesJuego());
      await _elegir(tester, 'E1', 0);
      await pulsar(tester, find.text('Ley 4/2015, art. 4'));
      expect(find.text('De dónde sale'), findsOneWidget);
      expect(find.text('Estatuto de la víctima del delito'), findsOneWidget);
    });

    testWidgets('fallar no castiga: «Mira por qué:», Tut contento y se puede probar otra vez', (tester) async {
      await abrirJuego(tester, ruta: _ruta, overrides: await overridesJuego());

      await _elegir(tester, 'E1', 1);
      expect(find.text(tituloFallo), findsOneWidget);
      expect(find.text(_opcion('E1', 1).feedback), findsOneWidget);
      expect(_tutEnLaExplicacion(), findsOneWidget, reason: 'nunca triste');
      expect(find.text(avisoCartaNueva), findsNothing);
      expect(find.text(botonProbarOtraVez), findsOneWidget);
      expect(find.text(botonSeguir), findsOneWidget);
      expect(contenedor(tester).read(progresoProvider).cartas, isEmpty);
      expect(
        tester.widget<MenuOpcionesPixel>(find.byType(MenuOpcionesPixel)).revelarCorrecta,
        isFalse,
        reason: 'la buena no se destapa: se puede probar otra vez',
      );

      await pulsar(tester, find.text(botonProbarOtraVez));
      expect(find.text(tituloFallo), findsNothing);
      await _elegir(tester, 'E1', 0);
      expect(find.text(tituloAcierto), findsOneWidget);
      expect(find.text(botonRecogerCarta), findsOneWidget);
    });

    testWidgets('«Empezar de nuevo» pide confirmación y vuelve a la primera escena', (tester) async {
      await abrirJuego(tester, ruta: _ruta, overrides: await overridesJuego());
      await _elegir(tester, 'E1', 0);
      await _recogerCarta(tester);
      expect(find.text(_escena('E2').narracion), findsOneWidget);

      await pulsar(tester, _botonOpciones());
      await pulsar(tester, find.text(menuEmpezarDeNuevo));
      expect(find.text(dialogoReiniciarTitulo), findsOneWidget);
      await pulsar(tester, find.text(cancelar));
      expect(find.text(_escena('E2').narracion), findsOneWidget, reason: 'cancelar no cambia nada');

      await pulsar(tester, _botonOpciones());
      await pulsar(tester, find.text(menuEmpezarDeNuevo));
      await pulsar(tester, find.widgetWithText(BotonPixel, menuEmpezarDeNuevo));
      expect(find.text(_escena('E1').narracion), findsOneWidget);
      expect(contenedor(tester).read(progresoProvider).cartas, {'R-entender'});
    });
  });

  group('el final', () {
    testWidgets('escena lineal, pista de otra carta y final con el sello y las cartas conseguidas', (tester) async {
      final semantica = tester.ensureSemantics();
      await abrirJuego(tester, ruta: _ruta, overrides: await overridesJuego());

      await _elegir(tester, 'E1', 0);
      await _recogerCarta(tester);
      await pulsar(tester, find.text(botonSeguir));
      expect(find.text(_escena('E3').narracion), findsOneWidget);

      await _elegir(tester, 'E3', 1);
      expect(find.text(pistaOtraCarta), findsOneWidget, reason: 'la otra respuesta correcta da otra carta');
      await _recogerCarta(tester);
      expect(find.text(_escena('E4').narracion), findsOneWidget);
      expect(find.text(botonTerminar), findsOneWidget);
      expect(contenedor(tester).read(progresoProvider).casosTerminados, isEmpty);

      await pulsar(tester, find.text(botonTerminar));

      expect(find.text(tituloFinal), findsOneWidget);
      expect(find.byType(SelloPixel), findsOneWidget);
      expect(find.bySemanticsLabel(textoCartasConseguidas(2)), findsOneWidget);
      expect(find.text(textoFinal('Nora')), findsOneWidget);
      expect(find.bySemanticsLabel('Carta: Tienes derecho a entender'), findsOneWidget, reason: 'P2-3');
      expect(find.bySemanticsLabel('Carta: Te lo tienen que explicar'), findsOneWidget);
      expect(find.bySemanticsLabel('Carta por descubrir'), findsOneWidget);
      expect(find.text(textoCartasQueFaltan(1)), findsOneWidget);
      expect(contenedor(tester).read(progresoProvider).casosTerminados, {'caso-prueba'});
      expect(find.text(botonSiguienteCaso('')), findsNothing, reason: 'no hay otro caso: se vuelve a la lista');

      await pulsar(tester, find.text(accesoAprende));
      expect(find.text('pantalla de aprende'), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('desde el final se vuelve a jugar desde la primera escena', (tester) async {
      await abrirJuego(tester, ruta: _ruta, overrides: await overridesJuego());
      await _jugarHastaElFinal(tester);
      await pulsar(tester, find.text(botonTerminar));

      await pulsar(tester, find.text(botonVolverAJugar));

      expect(find.text(_escena('E1').narracion), findsOneWidget);
      await _elegir(tester, 'E1', 0);
      expect(find.text(avisoCartaRepetida), findsOneWidget);
      expect(find.text(botonRecogerCarta), findsNothing);
    });

    testWidgets('con «reducir animaciones», el sello aparece ya puesto', (tester) async {
      await abrirJuego(tester, ruta: _ruta, reducirAnimaciones: true, overrides: await overridesJuego());
      await _jugarHastaElFinal(tester);
      await pulsar(tester, find.text(botonTerminar));
      expect(find.text(tituloFinal), findsOneWidget);
      expect(find.byType(SelloPixel), findsOneWidget);
    });

    testWidgets('el caso de Lucía se juega entero y su final lleva al de Sergio', (tester) async {
      final tts = FakeTts();
      final lucia = Caso.fromJson(jsonDecode(casoOficialDeEjemplo()) as Map<String, dynamic>);
      await abrirJuego(
        tester,
        ruta: '/juego/caso-sala-gesell',
        overrides: await overridesJuego(casos: casosOficiales(), tts: tts),
      );
      expect(_hud(tester).titulo, 'Lucía');

      await _jugarEntero(tester, 'caso-sala-gesell');

      expect(find.text(tituloFinal), findsOneWidget);
      expect(contenedor(tester).read(progresoProvider).cartas, hasLength(5), reason: 'una queda escondida');
      expect(contenedor(tester).read(progresoProvider).casosTerminados, {'caso-sala-gesell'});
      expect(tts.leidos.where((t) => t == textoEscena(lucia.primera)), hasLength(1));
      expect(tts.leidos, contains(textoEscena(lucia.escenas.last)));

      await pulsar(tester, find.text(botonSiguienteCaso('Sergio')));
      expect(_hud(tester).titulo, 'Sergio');
      expect(find.text('Caso de Sergio'), findsOneWidget);
    });

    testWidgets('el final de Sergio lleva al juzgado de menores (con «Ver borradores») y al caso de Sara', (
      tester,
    ) async {
      await abrirJuego(
        tester,
        ruta: '/juego/caso-acoso-escolar',
        overrides: await overridesJuego(casos: casosOficiales(), vozActivada: false, borradores: true),
      );
      await _jugarEntero(tester, 'caso-acoso-escolar');
      expect(find.text(botonSiguienteCaso('Sara')), findsOneWidget);

      await pulsar(tester, find.text(accesoJuzgadoMenores));
      expect(find.byType(JuzgadoScreen), findsOneWidget, reason: 'la ruta de verdad, no una de prueba');
      expect(tester.widget<JuzgadoScreen>(find.byType(JuzgadoScreen)).modo, ModoJuzgado.menores);
      expect(find.text(tituloEnRevision), findsNothing);
    });

    testWidgets('sin borradores, el final de Sergio no lleva al juzgado (sus textos están en revisión)', (
      tester,
    ) async {
      await abrirJuego(
        tester,
        ruta: '/juego/caso-acoso-escolar',
        overrides: await overridesJuego(casos: casosOficiales(), vozActivada: false),
      );
      await _jugarEntero(tester, 'caso-acoso-escolar');

      expect(find.text(botonSiguienteCaso('Sara')), findsOneWidget);
      expect(find.text(accesoJuzgadoMenores), findsNothing);
    });

    testWidgets('el caso de Sara se juega entero; su final da la ayuda para quitar imágenes', (tester) async {
      await abrirJuego(
        tester,
        ruta: '/juego/caso-difusion-imagenes',
        overrides: await overridesJuego(casos: casosOficiales(), vozActivada: false),
      );
      expect(_hud(tester).titulo, 'Sara');

      await _jugarEntero(tester, 'caso-difusion-imagenes');

      expect(find.text(tituloFinal), findsOneWidget);
      expect(contenedor(tester).read(progresoProvider).cartas, hasLength(5));
      expect(find.text(tituloSiTePasa), findsOneWidget);
      expect(find.text('Quitar fotos o vídeos de internet'), findsOneWidget);
      expect(find.text('Canal Joven de la AEPD'), findsOneWidget);
      expect(find.text(accesoJuzgadoMenores), findsNothing);
      expect(find.text(botonSiguienteCaso('Lucía')), findsOneWidget, reason: 'después del último, el que falta');

      await pulsar(tester, find.text(botonVerAyuda));
      expect(find.text('pantalla de ayuda'), findsOneWidget);
    });
  });

  group('el atajo de la demo', () {
    testWidgets('con la escena pendiente, la partida empieza en ella (Lucía, S5) y el atajo se gasta', (tester) async {
      final tts = FakeTts();
      final router = await abrirJuego(
        tester,
        ruta: '/ayuda',
        overrides: await overridesJuego(casos: casosOficiales(), tts: tts),
      );
      contenedor(tester).read(escenaInicialProvider.notifier).fijar('caso-sala-gesell', 'S5');

      router.push('/juego/caso-sala-gesell');
      await tester.pumpAndSettle();

      final partida = contenedor(tester).read(partidaProvider('caso-sala-gesell')).value!;
      expect(partida.escena.id, 'S5');
      expect(_hud(tester).textoProgreso, 'Escena 5 de 11');
      expect(_fondoDeLaEscena(tester), same(EscenariosPixel.salaGesell.fondo));
      expect(find.text('¿Para qué sirve la cámara?'), findsOneWidget);
      expect(tts.leidos, [textoEscena(partida.escena)], reason: 'se lee la escena del atajo, no la primera');
      expect(contenedor(tester).read(escenaInicialProvider), isNull);
    });

    testWidgets('un atajo de otro caso no cambia este', (tester) async {
      final router = await abrirJuego(
        tester,
        ruta: '/ayuda',
        overrides: await overridesJuego(casos: casosOficiales()),
      );
      contenedor(tester).read(escenaInicialProvider.notifier).fijar('caso-acoso-escolar', 'S4');

      router.push('/juego/caso-sala-gesell');
      await tester.pumpAndSettle();

      expect(contenedor(tester).read(partidaProvider('caso-sala-gesell')).value!.escena.id, 'S1');
      expect(contenedor(tester).read(escenaInicialProvider), isNotNull, reason: 'espera a su caso');
    });
  });

  testWidgets('un caso que no existe lo dice con calma y deja volver a la lista', (tester) async {
    await abrirJuego(tester, ruta: '/juego/no-existe', overrides: await overridesJuego());
    expect(find.text(casoNoEncontradoTitulo), findsOneWidget);
    await pulsar(tester, find.text(botonVerCasos));
    expect(find.byType(CasoScreen), findsNothing);
  });

  testWidgets('con letra grande, modo oscuro y un móvil pequeño se juega entero sin desbordarse', (tester) async {
    await abrirJuego(
      tester,
      ruta: _ruta,
      escalaTexto: 1.3,
      oscuro: true,
      tamano: const Size(360, 740),
      overrides: await overridesJuego(),
    );
    await _elegir(tester, 'E1', 1);
    expect(find.text(botonProbarOtraVez), findsOneWidget);
    await pulsar(tester, find.text(botonProbarOtraVez));
    await _jugarHastaElFinal(tester);
    await pulsar(tester, find.text(botonTerminar));
    expect(find.text(tituloFinal), findsOneWidget);
  });

  testWidgets('con «reducir animaciones» todo funciona igual', (tester) async {
    await abrirJuego(tester, ruta: _ruta, reducirAnimaciones: true, overrides: await overridesJuego());
    await _jugarHastaElFinal(tester);
    await pulsar(tester, find.text(botonTerminar));
    expect(find.text(tituloFinal), findsOneWidget);
  });

  testWidgets('entre escenas, la transición a bloques del kit', (tester) async {
    await abrirJuego(tester, ruta: _ruta, overrides: await overridesJuego());
    await _elegir(tester, 'E1', 1);
    await tester.tap(find.text(botonSeguir));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(TransicionPixel), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text(_escena('E2').narracion), findsOneWidget);
  });

  test(
    'las opciones se enseñan en otro orden según la escena (la buena no va siempre la primera), siempre el mismo',
    () {
      expect(ordenDeLasOpciones('caso/S1', 3), ordenDeLasOpciones('caso/S1', 3));
      for (final clave in ['a/S1', 'b/S2', 'c/S3']) {
        expect(ordenDeLasOpciones(clave, 3).toSet(), {0, 1, 2}, reason: 'es una permutación');
      }
      expect(ordenDeLasOpciones('caso/S1', 1), [0]);
      // En los casos oficiales, la correcta (casi siempre la primera del contenido) no sale siempre arriba.
      var arriba = 0;
      var total = 0;
      for (final json in casosOficiales().values) {
        final caso = Caso.fromJson(jsonDecode(json) as Map<String, dynamic>);
        for (final escena in caso.escenas) {
          final opciones = escena.decision?.opciones;
          if (opciones == null) continue;
          total++;
          if (opciones[ordenDeLasOpciones('${caso.id}/${escena.id}', opciones.length).first].correcta) arriba++;
        }
      }
      expect(arriba, lessThan(total * 2 ~/ 3));
    },
  );

  testWidgets('elegir una opción descolocada elige la del contenido (con su explicación y su carta)', (tester) async {
    await abrirJuego(tester, ruta: _ruta, overrides: await overridesJuego());
    await _elegir(tester, 'E1', 0);
    expect(contenedor(tester).read(partidaProvider('caso-prueba')).value!.eleccion, 0);
    expect(find.text(_opcion('E1', 0).feedback), findsOneWidget);
  });
}

/// La lista que se desplaza bajo la escena fija (o con ella).
Finder _scrollDeLaEscena(WidgetTester tester) =>
    find.descendant(of: find.byType(VistaEscenaJuego), matching: find.byType(Scrollable)).first;
