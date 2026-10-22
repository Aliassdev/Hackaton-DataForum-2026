import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/agente/agente_provider.dart';
import 'package:tuturno/core/agente/agente_voz.dart';
import 'package:tuturno/core/demo.dart';
import 'package:tuturno/core/entrada.dart';
import 'package:tuturno/core/progreso.dart';
import 'package:tuturno/core/providers.dart';
import 'package:tuturno/features/ajustes/demo.dart';
import 'package:tuturno/features/ajustes/para_el_equipo.dart';
import 'package:tuturno/features/ajustes/piezas.dart' show resumenTicket;
import 'package:tuturno/features/aprende/curso.dart' show rutaDemoDilo;
import 'package:tuturno/features/inicio/bienvenida.dart';
import 'package:tuturno/features/juego/juego_providers.dart' show casosProvider, partidaProvider;
import 'package:tuturno/features/juego/juego_screen.dart' show rutaJuzgado;
import 'package:tuturno/features/pasos/personalizacion_linea.dart' show EstiloExplicacion;
import 'package:tuturno/features/situacion/mi_ticket.dart';

import '../pregunta/agente/fake_agente.dart';
import '../pregunta/fakes.dart' show ApiGrabadora, FakeStt;
import 'ayudas_ajustes.dart';

// Ajustes → «Para el equipo (demo)» (plan v2, demo §3.1 y §3.5; auditoría P1-6).

const _equipo = 'Para el equipo (demo)';
final _preparar = find.widgetWithText(FilledButton, 'Preparar demo');

/// Abre Ajustes y descubre la parte del equipo.
Future<void> _abrirEquipo(WidgetTester tester, GoRouter router) async {
  await abrir(tester, router, '/ajustes');
  await revelarEquipo(tester);
}

/// «Preparar demo» y confirmar en el diálogo (con el ticket de Sergio, salvo que se desmarque).
Future<void> _prepararDemo(WidgetTester tester, {bool conTicket = true}) async {
  await tocar(tester, _preparar);
  expect(find.text('¿Preparar la demo?'), findsOneWidget);
  if (!conTicket) {
    await tester.tap(find.text('Con el ticket de Sergio'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.widgetWithText(FilledButton, 'Preparar'));
  await tester.pumpAndSettle();
}

/// Carga ya los casos de Vive el caso (en memoria: basta con dejar correr las microtareas).
Future<void> _cargarCasos(WidgetTester tester) async {
  final casos = contenedor(tester).read(casosProvider.future);
  await tester.pump();
  expect((await casos).length, 3);
}

/// [foto] sin el último número que enseñó el panel del turno del día («visto»): es la memoria de su animación (solo lo
/// apunta la primera vez que se construye) y no depende de «Preparar demo».
Future<Map<String, Object?>> _fotoSinPanel() async {
  final todo = await foto();
  final turno = todo['inicio.turno_del_dia'];
  if (turno is String) {
    todo['inicio.turno_del_dia'] = jsonEncode((jsonDecode(turno) as Map<String, dynamic>)..remove('visto'));
  }
  return todo;
}

/// Lo que habría en el móvil después de jugar y practicar.
Map<String, Object> _usado() => {
  'progreso': jsonEncode(
    const Progreso(
      xp: 999,
      racha: 9,
      cartas: {'R-una-sola-vez', 'R-ser-escuchada'},
      casosTerminados: {'caso-sala-gesell'},
    ).toJson(),
  ),
  'entrada': jsonEncode({'edad': 16, 'procedimiento': 'familia', 'rol': 'escuchado_familia', 'fase': 'antes'}),
  'mis_preguntas': '[]',
  'glosario.favoritos': '["G-citacion"]',
  MiTicketNotifier.clave: '{"preocupaciones":["redes"],"fecha":"2026-11-02"}',
  'ajustes.tamano_texto': 1.15,
};

void main() {
  group('la parte del equipo está escondida (auditoría P1-6)', () {
    for (final demo in [false, true]) {
      testWidgets('sin la pulsación larga no sale${demo ? ', tampoco con DEMO' : ''} (ni en depuración)', (
        tester,
      ) async {
        final router = await arrancarAjustes(tester, demo: demo);
        await abrir(tester, router, '/ajustes');
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -6000));
        await tester.pumpAndSettle();

        expect(find.text(_equipo), findsNothing);
        expect(find.text('Servidor (API_URL)'), findsNothing);
        expect(find.text('Preparar demo'), findsNothing);
        expect(find.text('Ver los iconos y a Tut'), findsNothing);
        // Lo que ve el jurado.
        for (final seccion in ['Leer mejor', 'Tu ticket', 'Tus datos en este móvil', 'ACERCA DE']) {
          expect(find.text(seccion, skipOffstage: false), findsOneWidget, reason: seccion);
        }
      });
    }

    testWidgets('con la pulsación larga en el pie sale, y al volver a entrar se esconde', (tester) async {
      final router = await arrancarAjustes(tester, demo: true);
      await _abrirEquipo(tester, router);

      expect(find.text(_equipo), findsOneWidget);
      for (final texto in [
        'Preparar demo',
        'Empezar de cero',
        'Ver borradores',
        'Usar siempre el ejemplo en Pregunta',
        'Atajos del guion',
        'Comprobar antes de salir',
        'Servidor (API_URL)',
        'Ver los iconos y a Tut',
      ]) {
        expect(find.text(texto, skipOffstage: false), findsOneWidget, reason: texto);
      }

      router.pop();
      await tester.pumpAndSettle();
      await abrir(tester, router, '/ajustes');
      expect(find.text(_equipo, skipOffstage: false), findsNothing);
    });

    testWidgets('la parte del equipo cumple las pautas de accesibilidad', (tester) async {
      final semantica = tester.ensureSemantics();
      final router = await arrancarAjustes(tester, demo: true);
      await _abrirEquipo(tester, router);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantica.dispose();
    });

    testWidgets('con letra grande en un móvil pequeño, la parte del equipo cabe', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final router = await arrancarAjustes(
        tester,
        demo: true,
        preferencias: {'ajustes.tamano_texto': 1.3},
        tamano: const Size(360, 640),
      );
      await _abrirEquipo(tester, router);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -9000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('«Preparar demo»', () {
    testWidgets('pide confirmación y «Cancelar» no cambia nada', (tester) async {
      final router = await arrancarAjustes(tester, demo: true, preferencias: _usado());
      await _abrirEquipo(tester, router);
      final antes = await foto();

      await tocar(tester, _preparar);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(await foto(), antes);
      expect(contenedor(tester).read(mostrarBorradoresProvider), isFalse);
    });

    testWidgets('deja cada ensayo igual: dos veces seguidas, el mismo estado, y R-una-sola-vez sigue bloqueada', (
      tester,
    ) async {
      final router = await arrancarAjustes(
        tester,
        demo: true,
        conCasos: true,
        bienvenidaVista: false,
        preferencias: {..._usado(), 'ajustes.reducir_movimiento': true},
      );
      final app = contenedor(tester);
      await _cargarCasos(tester);
      // Una partida a medias del caso de Lucía.
      await app.read(partidaProvider('caso-sala-gesell').future);
      await app.read(partidaProvider('caso-sala-gesell').notifier).empezarEn('S5');
      expect(app.read(partidaProvider('caso-sala-gesell')).value?.escena.id, 'S5');

      await _abrirEquipo(tester, router);
      await _prepararDemo(tester);

      final prefs = await SharedPreferences.getInstance();
      final esperado = progresoDemo(ahoraDePrueba);
      expect(jsonDecode(prefs.getString('progreso')!), jsonDecode(jsonEncode(esperado.toJson())));
      expect(app.read(progresoProvider).cartas, isNot(contains('R-una-sola-vez')));
      expect(app.read(progresoProvider).casosTerminados, isEmpty);
      expect(resumenTicket(app.read(entradaProvider)), '13 años · Penal · Víctima · Durante');
      expect(prefs.getBool('bienvenida_vista'), isTrue);
      expect(prefs.containsKey('mis_preguntas'), isFalse);
      expect(prefs.containsKey('glosario.favoritos'), isFalse);
      // Lo de Mi situación de antes se va y queda el de Sergio: la guía hecha a su medida, con su cita hoy.
      final miTicket = app.read(miTicketProvider);
      expect(miTicket.conQuien, {Acompanante.familia});
      expect(miTicket.preocupaciones, {Preocupacion.colegio, Preocupacion.preguntas});
      expect(miTicket.estilo, EstiloExplicacion.pasoAPaso);
      expect(miTicket.fecha, DateTime(ahoraDePrueba.year, ahoraDePrueba.month, ahoraDePrueba.day));
      expect(miTicket.hora, (horas: 12, minutos: 30));
      expect(prefs.getString(MiTicketNotifier.clave), isNot(contains('redes')));
      expect(prefs.getDouble('ajustes.tamano_texto'), 1.15);
      // Los borradores se ven (DEMO): también «El juzgado por dentro».
      expect(app.read(mostrarBorradoresProvider), isTrue);
      expect(app.read(contentProvider).mostrarBorradores, isTrue);
      // La partida a medias vuelve a empezar.
      expect((await app.read(partidaProvider('caso-sala-gesell').future)).escena.id, 'S1');
      // En el inicio, sin la bienvenida, con el aviso.
      expect(rutaActual(router), '/');
      expect(find.byType(Bienvenida), findsNothing);
      expect(find.text(avisoDemoPreparada(esperado)), findsOneWidget);
      // El turno del día empieza con el progreso de la demo: la misión aún no está hecha.
      final primera = await _fotoSinPanel();
      final turno = jsonDecode(primera['inicio.turno_del_dia']! as String) as Map<String, dynamic>;
      expect(turno['base'], {'lecciones': 2, 'cartas': 2, 'casos': 0, 'xp': 340});
      expect(turno['celebrada'], isFalse);

      await _abrirEquipo(tester, router);
      await _prepararDemo(tester);
      expect(await _fotoSinPanel(), primera);
      expect(app.read(progresoProvider).cartas, isNot(contains('R-una-sola-vez')));
      expect(tester.takeException(), isNull);
    });

    testWidgets('el ticket de Sergio es opcional', (tester) async {
      final router = await arrancarAjustes(tester, demo: true, preferencias: _usado());
      await _abrirEquipo(tester, router);
      await _prepararDemo(tester, conTicket: false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('entrada'), isFalse);
      expect(prefs.containsKey(MiTicketNotifier.clave), isFalse);
      expect(contenedor(tester).read(progresoProvider).xp, 340);
    });

    testWidgets('«Empezar de cero» deja la app sin progreso, sin ticket y con la bienvenida', (tester) async {
      // Sin animaciones: la presentación de la bienvenida dura más que el aviso de abajo.
      final router = await arrancarAjustes(
        tester,
        demo: true,
        preferencias: {..._usado(), 'ajustes.reducir_movimiento': true},
      );
      await _abrirEquipo(tester, router);

      await tocar(tester, find.widgetWithText(OutlinedButton, 'Empezar de cero'));
      expect(find.text('¿Empezar de cero?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Empezar de cero'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('progreso'), isFalse);
      expect(prefs.containsKey('entrada'), isFalse);
      expect(prefs.containsKey('bienvenida_vista'), isFalse);
      expect(prefs.getDouble('ajustes.tamano_texto'), 1.15);
      final app = contenedor(tester);
      expect(app.read(progresoProvider).xp, 0);
      expect(app.read(mostrarBorradoresProvider), isTrue);
      expect(rutaActual(router), '/');
      expect(find.byType(Bienvenida), findsOneWidget);
      expect(find.text(avisoComoNuevo), findsOneWidget);
    });
  });

  group('los atajos del guion', () {
    test('van en el orden del guion y coinciden con las rutas de la app', () {
      expect(AtajoDemo.values.map((a) => a.ruta), [
        '/juego/caso-sala-gesell',
        '/juego/caso-sala-gesell',
        '/juego/caso-acoso-escolar',
        '/juego/caso-difusion-imagenes',
        '/pregunta',
        '/situacion/victima',
        '/aprende/leccion/dilo-U2-L2',
        '/juego/juzgado',
      ]);
      expect(AtajoDemo.diloSalaGesell.ruta, rutaDemoDilo('U2-L2'));
      expect(AtajoDemo.juzgado.ruta, rutaJuzgado);
      expect(AtajoDemo.luciaCamara.escena, 'S5');
      expect(AtajoDemo.luciaMadre.escena, 'S9');
      expect(AtajoDemo.preguntaSergio.detalle, resumenTicket(entradaDemoSergio));
    });

    testWidgets('cada atajo abre su pantalla encima del inicio', (tester) async {
      final router = await arrancarAjustes(
        tester,
        demo: true,
        conCasos: true,
        preferencias: {'ajustes.reducir_movimiento': true, 'ajustes.voz_activada': false},
      );
      await _cargarCasos(tester);
      for (final atajo in [
        AtajoDemo.sergio,
        AtajoDemo.sara,
        AtajoDemo.situacionVictima,
        AtajoDemo.diloSalaGesell,
        AtajoDemo.juzgado,
      ]) {
        await _abrirEquipo(tester, router);
        await tocar(tester, find.text(atajo.titulo));
        await tester.pump(const Duration(seconds: 1));
        expect(rutaActual(router), atajo.ruta, reason: atajo.name);
        router.pop();
        await tester.pumpAndSettle();
        expect(rutaActual(router), '/', reason: '«atrás» desde ${atajo.name} vuelve al inicio');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Lucía empieza en la escena 5 (y en la 9)', (tester) async {
      final router = await arrancarAjustes(
        tester,
        demo: true,
        conCasos: true,
        preferencias: {'ajustes.reducir_movimiento': true, 'ajustes.voz_activada': false},
      );
      final app = contenedor(tester);
      await _cargarCasos(tester);
      for (final (atajo, escena) in [(AtajoDemo.luciaCamara, 'S5'), (AtajoDemo.luciaMadre, 'S9')]) {
        await _abrirEquipo(tester, router);
        await tocar(tester, find.text(atajo.titulo));
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(rutaActual(router), '/juego/caso-sala-gesell');
        expect(app.read(partidaProvider('caso-sala-gesell')).value?.escena.id, escena);
        // El atajo se usa una sola vez.
        expect(app.read(escenaInicialProvider), isNull);
        router.pop();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('«Pregunta con el perfil de Sergio» guarda su ticket y abre Pregunta', (tester) async {
      final router = await arrancarAjustes(tester, demo: true);
      await _abrirEquipo(tester, router);
      await tocar(tester, find.text(AtajoDemo.preguntaSergio.titulo));
      await tester.pump(const Duration(seconds: 1));

      expect(rutaActual(router), '/pregunta');
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('entrada')!), {
        'edad': 13,
        'procedimiento': 'penal',
        'rol': 'victima',
        'fase': 'durante',
      });
    });
  });

  group('la guía de Sergio', () {
    testWidgets('tras «Preparar demo», «Mi situación de víctima» enseña su guía con el modo día', (tester) async {
      final router = await arrancarAjustes(
        tester,
        demo: true,
        preferencias: {'ajustes.reducir_movimiento': true, 'ajustes.voz_activada': false},
      );
      await _abrirEquipo(tester, router);
      await _prepararDemo(tester);
      await _abrirEquipo(tester, router);
      await tocar(tester, find.text(AtajoDemo.situacionVictima.titulo));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(rutaActual(router), '/situacion/victima');
      expect(find.text('Hoy es tu día\u00A0· 12:30'), findsOneWidget);
      expect(find.text('Con tu familia'), findsOneWidget);
      expect(find.text(EstiloExplicacion.pasoAPaso.etiqueta), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('interruptores de la demo', () {
    testWidgets('«Ver borradores» y «Usar siempre el ejemplo en Pregunta» cambian al momento', (tester) async {
      final router = await arrancarAjustes(tester, demo: true);
      await _abrirEquipo(tester, router);
      final app = contenedor(tester);

      await tocar(tester, find.widgetWithText(SwitchListTile, 'Ver borradores'));
      expect(app.read(mostrarBorradoresProvider), isTrue);
      await tocar(tester, find.widgetWithText(SwitchListTile, 'Usar siempre el ejemplo en Pregunta'));
      expect(app.read(usarEjemploPreguntaProvider), isTrue);
      await tocar(tester, find.widgetWithText(SwitchListTile, 'Usar siempre el ejemplo en Pregunta'));
      expect(app.read(usarEjemploPreguntaProvider), isFalse);
    });

    testWidgets('sin DEMO, «Ver borradores» avisa de que no funciona', (tester) async {
      final router = await arrancarAjustes(tester);
      await _abrirEquipo(tester, router);
      expect(find.text('Solo funciona en una versión con DEMO=true.', skipOffstage: false), findsOneWidget);
    });
  });

  group('«Comprobar antes de salir»', () {
    Future<void> comprobarTodo(WidgetTester tester) async {
      await tocar(tester, find.widgetWithText(FilledButton, 'Comprobar'));
      await tester.pumpAndSettle();
    }

    String detalle(WidgetTester tester, Comprobacion c) {
      final fila = find.byKey(ValueKey('comprobacion-${c.name}'));
      final textos = tester.widgetList<Text>(find.descendant(of: fila, matching: find.byType(Text)));
      return textos.map((t) => t.data).join(' | ');
    }

    testWidgets('dice en verde o en rojo qué está listo, sin bloquear nada', (tester) async {
      final router = await arrancarAjustes(tester, demo: true, stt: FakeStt(disponible: false));
      await _abrirEquipo(tester, router);
      await comprobarTodo(tester);

      expect(detalle(tester, Comprobacion.red), contains('Hay conexión'));
      expect(detalle(tester, Comprobacion.servidor), contains('USE_MOCK'));
      expect(detalle(tester, Comprobacion.agente), contains('Sin agente de voz'));
      expect(detalle(tester, Comprobacion.microfono), contains('Sin permiso'));
      expect(detalle(tester, Comprobacion.voz), contains('Hay voz en español'));
      expect(detalle(tester, Comprobacion.demo), contains('Activo'));
      expect(detalle(tester, Comprobacion.ayuda017), contains('Abierto'));
      expect(find.widgetWithText(FilledButton, 'Comprobar otra vez'), findsOneWidget);
    });

    testWidgets('con el servidor y el agente de verdad, todo en verde', (tester) async {
      final agente = FakeAgenteVoz()..saludarAlConectar = false;
      final router = await arrancarAjustes(
        tester,
        demo: true,
        useMock: false,
        apiUrl: 'https://servidor.ejemplo',
        overrides: [
          apiProvider.overrideWithValue(ApiGrabadora()),
          modoAgenteProvider.overrideWithValue(true),
          agenteVozProvider.overrideWith((ref) => agente),
        ],
      );
      await _abrirEquipo(tester, router);
      await comprobarTodo(tester);

      expect(detalle(tester, Comprobacion.servidor), contains('Responde: https://servidor.ejemplo'));
      expect(detalle(tester, Comprobacion.agente), contains('Abre y cierra en'));
      // La sesión de prueba va sin datos del ticket y se cierra.
      expect(agente.sesiones.single.values.every((v) => v.isEmpty), isTrue);
      expect(agente.terminados, 1);
      expect(detalle(tester, Comprobacion.microfono), contains('Se puede dictar'));
    });

    testWidgets('un servidor dormido y un agente que no abre salen en rojo a los 4 y 6 segundos', (tester) async {
      final agente = FakeAgenteVoz()..bloquearInicio = Completer<void>();
      final router = await arrancarAjustes(
        tester,
        demo: true,
        useMock: false,
        apiUrl: 'https://servidor.ejemplo',
        sondas: SondasFalsas(red: false, voz: VozEspanola.conRed),
        overrides: [
          apiProvider.overrideWithValue(ApiDormida()),
          modoAgenteProvider.overrideWithValue(true),
          agenteVozProvider.overrideWith((ref) => agente),
        ],
      );
      await _abrirEquipo(tester, router);
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Comprobar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Comprobar'));
      await tester.pump();
      expect(find.text('Comprobando…'), findsWidgets);

      await tester.pump(limiteServidor);
      await tester.pump();
      expect(detalle(tester, Comprobacion.servidor), contains('No responde en 4 s'));
      await tester.pump(limiteAgente - limiteServidor);
      await tester.pumpAndSettle();
      expect(detalle(tester, Comprobacion.agente), contains('No abre en 6 s'));
      expect(detalle(tester, Comprobacion.red), contains('Sin conexión'));
      expect(detalle(tester, Comprobacion.voz), contains('Solo funciona con red'));
      agente.bloquearInicio!.complete();
    });

    testWidgets('un error del agente se explica con su texto', (tester) async {
      final agente = FakeAgenteVoz()..fallarAlIniciar = const ErrorAgente(TextosAgente.sinConexion);
      final router = await arrancarAjustes(
        tester,
        demo: true,
        overrides: [modoAgenteProvider.overrideWithValue(true), agenteVozProvider.overrideWith((ref) => agente)],
      );
      await _abrirEquipo(tester, router);
      await comprobarTodo(tester);
      expect(detalle(tester, Comprobacion.agente), contains(TextosAgente.sinConexion));
    });

    test('el 017 abre de 8:00 a 23:00 en hora peninsular', () {
      expect(resultado017(DateTime.utc(2026, 10, 22, 10)).estado, EstadoComprobacion.bien);
      // 23:30 en Madrid (verano, UTC+2).
      final cerrado = resultado017(DateTime.utc(2026, 10, 22, 21, 30));
      expect(cerrado.estado, EstadoComprobacion.mal);
      expect(cerrado.detalle, contains('abre a las 8:00'));
    });

    test('cada resultado dice qué hacer', () {
      expect(resultadoDemo(activo: false).detalle, contains('--dart-define=DEMO=true'));
      expect(resultadoRed(hay: false).estado, EstadoComprobacion.mal);
      expect(resultadoMicrofono(permiso: true).estado, EstadoComprobacion.bien);
      expect(resultadoVoz(VozEspanola.no).estado, EstadoComprobacion.mal);
      expect(pistaConexion('SIN_CONEXION'), contains('túnel'));
    });
  });
}
