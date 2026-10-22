import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/progreso.dart';
import 'package:tuturno/core/providers.dart' show ajustesProvider;
import 'package:tuturno/features/juego/caso_screen.dart';
import 'package:tuturno/features/juego/juego_providers.dart';
import 'package:tuturno/features/juego/modelos.dart';
import 'package:tuturno/features/juego/textos.dart';

import 'fakes.dart';

final _caso = Caso.fromJson(jsonDecode(casoPrueba) as Map<String, dynamic>);
Escena _escena(String id) => _caso.escena(id)!;
Opcion _opcion(String escena, int i) => _escena(escena).decision!.opciones[i];

const _ruta = '/juego/caso-prueba';

/// Elige la opción [i] de [escena] (por su texto).
Future<void> _elegir(WidgetTester tester, String escena, int i) => pulsar(tester, find.text(_opcion(escena, i).texto));

/// Recoge la carta nueva y cierra la animación.
Future<void> _recogerCarta(WidgetTester tester) async {
  await pulsar(tester, find.text(botonRecogerCarta));
  await pulsar(tester, find.text('¡A mi colección!'));
}

/// Juega el caso de prueba hasta la última escena (E4), sin terminarlo.
Future<void> _jugarHastaElFinal(WidgetTester tester) async {
  await _elegir(tester, 'E1', 0);
  await _recogerCarta(tester);
  await pulsar(tester, find.text(botonSeguir));
  await _elegir(tester, 'E3', 1);
  await _recogerCarta(tester);
}

void main() {
  testWidgets('al entrar en el caso lee la narración y la pregunta, una sola vez', (tester) async {
    final tts = FakeTts();
    await abrirJuego(
      tester,
      ruta: _ruta,
      overrides: await overridesJuego(tts: tts),
    );

    expect(find.text('Caso de Nora'), findsOneWidget);
    expect(find.text(_escena('E1').narracion), findsOneWidget);
    expect(find.text(_escena('E1').decision!.pregunta), findsOneWidget);
    expect(find.text('Nora'), findsOneWidget, reason: 'los personajes, como fichas');
    expect(find.text('Su tutor'), findsOneWidget);
    expect(find.bySemanticsLabel('Escena 1 de 4'), findsOneWidget);
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

  testWidgets('con lector de pantalla no lee solo (ya lee el lector)', (tester) async {
    final tts = FakeTts();
    await abrirJuego(
      tester,
      ruta: _ruta,
      lectorDePantalla: true,
      overrides: await overridesJuego(tts: tts),
    );
    await _elegir(tester, 'E1', 0);
    expect(tts.leidos, isEmpty);
  });

  testWidgets('acertar: explicación con su fuente, carta nueva animada y siguiente escena', (tester) async {
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
    expect(find.text('Ley 4/2015, art. 4'), findsOneWidget);
    expect(find.text(avisoCartaNueva), findsOneWidget);
    expect(tts.leidos.last, textoExplicacion(_opcion('E1', 0)));
    expect(contenedor(tester).read(progresoProvider).cartas, {'R-entender'}, reason: 'se guarda al acertar');

    await pulsar(tester, find.text(botonRecogerCarta));
    expect(find.text('¡Carta nueva!'), findsOneWidget);
    expect(find.text('Tienes derecho a entender'), findsOneWidget);
    expect(find.text('+10 puntos'), findsOneWidget);

    await pulsar(tester, find.text('¡A mi colección!'));
    expect(find.text('¡Carta nueva!'), findsNothing);
    expect(find.text(_escena('E2').narracion), findsOneWidget);
    expect(find.bySemanticsLabel('Escena 2 de 4'), findsOneWidget);
    expect(tts.leidos.last, textoEscena(_escena('E2')));
  });

  testWidgets('la fuente se puede tocar y explica de qué ley sale', (tester) async {
    await abrirJuego(tester, ruta: _ruta, overrides: await overridesJuego());
    await _elegir(tester, 'E1', 0);
    await pulsar(tester, find.text('Ley 4/2015, art. 4'));
    expect(find.text('De dónde sale'), findsOneWidget);
    expect(find.text('Estatuto de la víctima del delito'), findsOneWidget);
  });

  testWidgets('los términos del glosario se subrayan también en femenino y llevan a su entrada', (tester) async {
    const caso = '''
{"id": "caso-termino", "titulo": "Iris y el instituto", "rol": "victima", "basado_en": [],
 "escenas": [{"id": "S1", "lugar": "colegio", "personajes": ["Iris"],
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

    await tester.tapOnText(find.textRange.ofSubstring('coordinadora de bienestar y protección'));
    await tester.pumpAndSettle();

    expect(find.text('glosario:Coordinador de bienestar y protección'), findsOneWidget);
  });

  testWidgets('fallar no culpa: explica y deja probar otra vez', (tester) async {
    await abrirJuego(tester, ruta: _ruta, overrides: await overridesJuego());

    await _elegir(tester, 'E1', 1);
    expect(find.text(tituloFallo), findsOneWidget);
    expect(find.text(_opcion('E1', 1).feedback), findsOneWidget);
    expect(find.text(avisoCartaNueva), findsNothing);
    expect(find.text(botonProbarOtraVez), findsOneWidget);
    expect(find.text(botonSeguir), findsOneWidget);
    expect(contenedor(tester).read(progresoProvider).cartas, isEmpty);

    await pulsar(tester, find.text(botonProbarOtraVez));
    expect(find.text(tituloFallo), findsNothing);
    await _elegir(tester, 'E1', 0);
    expect(find.text(tituloAcierto), findsOneWidget);
    expect(find.text(botonRecogerCarta), findsOneWidget);
  });

  testWidgets('escena lineal, pista de otra carta, final y resumen con el caso guardado', (tester) async {
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
    expect(find.text(textoFinal('Nora')), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
    expect(find.text('Tienes derecho a entender'), findsOneWidget);
    expect(find.text('Te lo tienen que explicar'), findsOneWidget);
    expect(find.text(textoCartasQueFaltan(1)), findsOneWidget);
    expect(contenedor(tester).read(progresoProvider).casosTerminados, {'caso-prueba'});

    await pulsar(tester, find.text(accesoAprende));
    expect(find.text('pantalla de aprende'), findsOneWidget);
  });

  testWidgets('desde el resumen se vuelve a jugar desde la primera escena', (tester) async {
    await abrirJuego(tester, ruta: _ruta, overrides: await overridesJuego());
    await _jugarHastaElFinal(tester);
    await pulsar(tester, find.text(botonTerminar));

    await pulsar(tester, find.text(botonVolverAJugar));

    expect(find.text(_escena('E1').narracion), findsOneWidget);
    // Las cartas ganadas siguen en la colección: al volver a acertar, ya no es nueva.
    await _elegir(tester, 'E1', 0);
    expect(find.text(avisoCartaRepetida), findsOneWidget);
    expect(find.text(botonRecogerCarta), findsNothing);
    expect(find.text(botonSeguir), findsOneWidget);
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
    expect(find.text(tituloElegirCaso), findsOneWidget);
    expect(tts.hablando.value, isFalse, reason: 'al salir del caso no se queda hablando');
  });

  testWidgets('desactivar la voz (en el menú o en Ajustes) calla la lectura y deja de leer solo', (tester) async {
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

    // El menú del caso tiene el mismo interruptor.
    await pulsar(tester, find.byTooltip('Más opciones'));
    await pulsar(tester, find.byType(CheckedPopupMenuItem<String>));
    expect(contenedor(tester).read(ajustesProvider).vozActivada, isTrue);
    await pulsar(tester, find.byTooltip('Más opciones'));
    await pulsar(tester, find.byType(CheckedPopupMenuItem<String>));
    expect(contenedor(tester).read(ajustesProvider).vozActivada, isFalse);

    final leidos = tts.leidos.length;
    await _elegir(tester, 'E1', 0);
    expect(tts.leidos, hasLength(leidos), reason: 'sin voz, la explicación no se lee sola');
  });

  testWidgets('«Empezar de nuevo» pide confirmación y vuelve a la primera escena', (tester) async {
    await abrirJuego(tester, ruta: _ruta, overrides: await overridesJuego());
    await _elegir(tester, 'E1', 0);
    await _recogerCarta(tester);
    expect(find.text(_escena('E2').narracion), findsOneWidget);

    await pulsar(tester, find.byTooltip('Más opciones'));
    await pulsar(tester, find.text(menuEmpezarDeNuevo));
    expect(find.text(dialogoReiniciarTitulo), findsOneWidget);
    await pulsar(tester, find.widgetWithText(FilledButton, menuEmpezarDeNuevo));

    expect(find.text(_escena('E1').narracion), findsOneWidget);
    expect(contenedor(tester).read(progresoProvider).cartas, {'R-entender'});
  });

  testWidgets('un caso que no existe lo dice con calma y deja volver a la lista', (tester) async {
    await abrirJuego(tester, ruta: '/juego/no-existe', overrides: await overridesJuego());
    expect(find.text(casoNoEncontradoTitulo), findsOneWidget);
    await pulsar(tester, find.text(botonVerCasos));
    expect(find.text(tituloElegirCaso), findsOneWidget);
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

  testWidgets('el caso oficial de Lucía se juega de principio a fin', (tester) async {
    final tts = FakeTts();
    final lucia = Caso.fromJson(jsonDecode(casoOficialDeEjemplo()) as Map<String, dynamic>);
    await abrirJuego(
      tester,
      ruta: '/juego/caso-sala-gesell',
      overrides: await overridesJuego(casos: {'caso-sala-gesell.json': casoOficialDeEjemplo()}, tts: tts),
    );
    expect(find.text('Caso de Lucía'), findsOneWidget);

    for (var i = 0; i < 40 && find.text(tituloFinal).evaluate().isEmpty; i++) {
      final recoger = find.text(botonRecogerCarta);
      final seguir = find.text(botonSeguir);
      final terminar = find.text(botonTerminar);
      if (recoger.evaluate().isNotEmpty) {
        await _recogerCarta(tester);
      } else if (seguir.evaluate().isNotEmpty) {
        await pulsar(tester, seguir);
      } else if (terminar.evaluate().isNotEmpty) {
        await pulsar(tester, terminar);
      } else {
        // Una decisión: la primera respuesta correcta. (La narración lleva términos del glosario subrayados, así
        // que la escena se mira en la partida, no buscando su texto.)
        final escena = contenedor(tester).read(partidaProvider('caso-sala-gesell')).value!.escena;
        await pulsar(tester, find.text(escena.decision!.opciones.firstWhere((o) => o.correcta).texto));
      }
    }

    expect(find.text(tituloFinal), findsOneWidget);
    expect(find.text('5/6'), findsOneWidget, reason: 'una carta queda escondida en la otra respuesta correcta');
    expect(contenedor(tester).read(progresoProvider).casosTerminados, {'caso-sala-gesell'});
    expect(tts.leidos.where((t) => t == textoEscena(lucia.primera)), hasLength(1));
    expect(tts.leidos, contains(textoEscena(lucia.escenas.last)));
  });
}
