import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/agente/agente_provider.dart';
import 'package:tuturno/core/agente/elevenlabs_ws_agente_voz.dart';
import 'package:tuturno/core/api/mock_api.dart';
import 'package:tuturno/features/pregunta/agente/chat_agente.dart';
import 'package:tuturno/features/pregunta/agente/textos_agente.dart';
import 'package:tuturno/features/pregunta/pregunta_screen.dart';
import 'package:tuturno/features/pregunta/widgets/mensajes.dart';
import 'package:tuturno/tema.dart';

import '../../../core/agente/fakes_ws.dart';
import '../fakes.dart';
import 'fake_agente.dart' show saludoAgente;

// «Pregunta» con el agente de voz de verdad (ElevenLabsWsAgenteVoz) sobre un WebSocket falso: cómo encaja con el chat
// del agente el saludo, la voz que suena (micrófono desactivado), un corte a mitad de pregunta y la reconexión sola.

const _campo = Key('campo-pregunta');
const _enviar = Key('boton-enviar');

class _Pantalla {
  _Pantalla(this.servidor, this.reproductor, this.stt, this.lineas);

  final ServidorFalso servidor;
  final ReproductorFalso reproductor;
  final FakeStt stt;
  final List<String> lineas;

  ConexionFalsa get conexion => servidor.ultima;
}

Future<_Pantalla> _abrir(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915) * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  final servidor = ServidorFalso();
  final reproductor = ReproductorFalso();
  final lineas = <String>[];
  final stt = FakeStt();
  final overrides = await overridesDePrueba(api: ApiGrabadora(), stt: stt, tts: FakeTts());
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    'entrada',
    jsonEncode({'edad': 13, 'procedimiento': 'penal', 'rol': 'testigo', 'fase': 'antes'}),
  );
  final inicio = tester.binding.clock.now();
  final router = GoRouter(
    initialLocation: '/pregunta',
    routes: [
      GoRoute(path: '/pregunta', builder: (context, state) => const PreguntaScreen()),
      GoRoute(
        path: '/inicio',
        builder: (context, state) => const Scaffold(body: Text('inicio')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        modoAgenteProvider.overrideWithValue(true),
        agenteVozProvider.overrideWith((ref) {
          final agente = ElevenLabsWsAgenteVoz(
            agentId: 'agente-de-prueba',
            reproductor: reproductor,
            abrirConexion: servidor.abrir,
            reloj: () => tester.binding.clock.now().difference(inicio),
            registrar: lineas.add,
          );
          ref.onDispose(agente.dispose);
          return agente;
        }),
        respuestasEjemploProvider.overrideWithValue(MockTuTurnoApi(latencia: Duration.zero)),
      ],
      child: MaterialApp.router(
        theme: temaTuTurno(Brightness.light),
        locale: const Locale('es', 'ES'),
        supportedLocales: const [Locale('es', 'ES')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Pantalla(servidor, reproductor, stt, lineas);
}

Future<void> _escribirYEnviar(WidgetTester tester, String texto) async {
  await tester.enterText(find.byKey(_campo), texto);
  await tester.pump();
  await tester.tap(find.byKey(_enviar));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('saludo con voz (micrófono desactivado mientras suena), pregunta y respuesta', (tester) async {
    final p = await _abrir(tester);
    expect(p.servidor.conexiones, hasLength(1));
    expect(p.conexion.enviados.first['dynamic_variables'], {
      'edad': '13',
      'procedimiento': 'penal',
      'rol': 'testigo',
      'fase': 'antes',
    });

    p.conexion.llegaRespuesta(saludoAgente, id: 0);
    p.conexion.llegaAudio(pcm(1000), id: 0);
    await tester.pump();
    await tester.pump();
    expect(find.text(saludoAgente), findsOneWidget);
    expect(find.byType(BurbujaAsistente), findsNothing, reason: 'el saludo no es un mensaje');
    expect(find.text(tituloHablando), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton-micro')));
    await tester.pump();
    expect(p.stt.inicializaciones, 0, reason: 'no se escucha mientras suena el agente');

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.text(tituloEscucho), findsOneWidget);

    await _escribirYEnviar(tester, '¿Qué es la Sala Gesell?');
    expect(p.conexion.deTipo('user_message').single['text'], '¿Qué es la Sala Gesell?');
    p.conexion.llegaRespuesta('La Sala Gesell es una sala con un espejo especial.', id: 2);
    p.conexion.llegaAudio(pcm(300), id: 2);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.textContaining('espejo especial', findRichText: true), findsOneWidget);
    expect(p.reproductor.trozos, hasLength(2));
    expect(p.lineas, contains('TUTURNO_LAT envio'));
    expect(p.conexion.enviados.where((m) => m.containsKey('user_audio_chunk')), isEmpty);
  });

  testWidgets(
    'corte a mitad de pregunta: el error sale enseguida; «Reintentar» usa la sesión que se ha reabierto sola',
    (tester) async {
      final p = await _abrir(tester);
      p.conexion.llegaRespuesta(saludoAgente, id: 0);
      await tester.pumpAndSettle();

      await _escribirYEnviar(tester, '¿Qué es la Sala Gesell?');
      p.conexion.seCae();
      await tester.pump();
      await tester.pump();
      expect(find.text(textoCortado), findsOneWidget);
      expect(find.text(tituloSinConexion), findsOneWidget);
      expect(p.lineas, contains('TUTURNO_LAT corte motivo=red'));

      // Reconecta sola en segundo plano; su saludo no suena.
      await tester.pump(ElevenLabsWsAgenteVoz.esperasReconexion.first);
      await tester.pump();
      expect(p.servidor.conexiones, hasLength(2));
      p.conexion.llegaRespuesta(saludoAgente, id: 0);
      p.conexion.llegaAudio(pcm(500), id: 0);
      await tester.pump();
      expect(p.reproductor.trozos, isEmpty);

      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(p.servidor.conexiones, hasLength(2), reason: 'no hace falta conectar otra vez');
      expect(p.conexion.deTipo('user_message').single['text'], '¿Qué es la Sala Gesell?');
      p.conexion.llegaRespuesta('Es una sala especial.', id: 2);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('Es una sala especial.', findRichText: true), findsOneWidget);
      expect(find.byType(BurbujaError), findsNothing);
      expect(find.textContaining(detalleConversacionNueva), findsOneWidget);
    },
  );

  testWidgets('si se cae sin pregunta pendiente, para el usuario no cambia nada y la siguiente pregunta va enseguida', (
    tester,
  ) async {
    final p = await _abrir(tester);
    p.conexion.llegaRespuesta(saludoAgente, id: 0);
    await tester.pumpAndSettle();

    p.conexion.cierraServidor(1006);
    await tester.pump();
    expect(find.text(tituloEscucho), findsOneWidget);
    await tester.pump(ElevenLabsWsAgenteVoz.esperasReconexion.first);
    await tester.pump();
    expect(p.servidor.conexiones, hasLength(2));

    await _escribirYEnviar(tester, '¿Quién es el fiscal?');
    expect(p.conexion.deTipo('user_message').single['text'], '¿Quién es el fiscal?');
    p.conexion.llegaRespuesta('El fiscal defiende la ley.', id: 2);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.textContaining('El fiscal defiende la ley.', findRichText: true), findsOneWidget);
  });

  testWidgets('al salir de Pregunta se cierra la conexión y se suelta el reproductor', (tester) async {
    final p = await _abrir(tester);

    GoRouter.of(tester.element(find.byType(PreguntaScreen))).go('/inicio');
    await tester.pumpAndSettle();

    expect(find.text('inicio'), findsOneWidget);
    expect(p.conexion.cerradaPorLaApp, isTrue);
    expect(p.reproductor.llamadas.last, 'liberar');
  });
}
