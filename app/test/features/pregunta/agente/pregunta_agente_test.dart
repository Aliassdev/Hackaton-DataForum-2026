import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/agente/agente_provider.dart';
import 'package:tuturno/core/agente/elevenlabs_agente_voz.dart' show ErrorAgente, TextosAgente;
import 'package:tuturno/core/agente/respuesta_agente.dart';
import 'package:tuturno/core/api/mock_api.dart';
import 'package:tuturno/core/api/models.dart';
import 'package:tuturno/core/voz/stt.dart' show ProblemaVoz;
import 'package:tuturno/features/pregunta/agente/chat_agente.dart';
import 'package:tuturno/features/pregunta/agente/textos_agente.dart';
import 'package:tuturno/features/pregunta/chat_controller.dart';
import 'package:tuturno/features/pregunta/pregunta_screen.dart';
import 'package:tuturno/features/pregunta/widgets/mensajes.dart';
import 'package:tuturno/tema.dart';

import '../fakes.dart';
import 'fake_agente.dart';

// «Pregunta» en modo agente con un agente de voz falso: conecta, saludo, envío, respuestas (normal, crisis, hechos,
// fuera de ámbito, respuesta segura), sin respuesta en 30 s, ejemplos, micrófono mientras habla, segundo plano y
// salida.

const _campo = Key('campo-pregunta');
const _enviar = Key('boton-enviar');
const _micro = Key('boton-micro');

/// Perfil guardado: así no sale la hoja del perfil.
const _perfilTestigo = <String, Object?>{'edad': 13, 'procedimiento': 'penal', 'rol': 'testigo', 'fase': 'antes'};

String _nb(String telefono) => telefono.replaceAll(' ', ' ');

class _Pantalla {
  _Pantalla(this.agente, this.stt, this.router, this.prefs);

  final FakeAgenteVoz agente;
  final FakeStt stt;
  final GoRouter router;
  final SharedPreferences prefs;
}

Future<_Pantalla> _abrir(
  WidgetTester tester, {
  Map<String, Object?>? perfil = _perfilTestigo,
  RolProceso? situacion,
  FakeAgenteVoz? agente,
  bool asentar = true,
}) async {
  tester.view.physicalSize = const Size(412, 915) * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  final voz = agente ?? FakeAgenteVoz();
  final stt = FakeStt();
  final overrides = await overridesDePrueba(api: ApiGrabadora(), stt: stt, tts: FakeTts());
  final prefs = await SharedPreferences.getInstance();
  if (perfil != null) await prefs.setString('entrada', jsonEncode(perfil));
  final router = GoRouter(
    initialLocation: situacion == null ? '/pregunta' : '/pregunta?situacion=${situacion.name}',
    routes: [
      GoRoute(
        path: '/pregunta',
        builder: (context, state) =>
            PreguntaScreen(situacion: RolProceso.values.asNameMap()[state.uri.queryParameters['situacion']]),
      ),
      GoRoute(
        path: '/inicio',
        builder: (context, state) => const Scaffold(body: Text('inicio')),
      ),
      GoRoute(
        path: '/ayuda',
        builder: (context, state) => const Scaffold(body: Text('pantalla de ayuda')),
      ),
      GoRoute(
        path: '/glosario',
        builder: (context, state) => const Scaffold(body: Text('glosario')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        modoAgenteProvider.overrideWithValue(true),
        agenteVozProvider.overrideWithValue(voz),
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
  if (asentar) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  return _Pantalla(voz, stt, router, prefs);
}

/// Escribe y envía. Mientras se espera la respuesta hay animaciones sin fin (los puntos): se avanza a mano.
Future<void> _escribirYEnviar(WidgetTester tester, String texto) async {
  await tester.enterText(find.byKey(_campo), texto);
  await tester.pump();
  await tester.tap(find.byKey(_enviar));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// El agente dice [texto] y se espera a que se vea.
Future<void> _responde(WidgetTester tester, FakeAgenteVoz agente, String texto) async {
  agente.decir(texto);
  await tester.pump();
  await tester.pumpAndSettle();
}

Finder _respuesta(String parte) => find.textContaining(parte, findRichText: true);

/// Desplaza la lista (vista inicial o conversación) hasta que se ve [finder]: con la letra de las pruebas, más ancha que
/// la real, no todo cabe en la pantalla.
Future<void> _desplazarHasta(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first,
  );
  await tester.pumpAndSettle();
}

/// El estado del chat del agente (la conversación de `/pregunta`).
EstadoChat _estado(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(PreguntaScreen))).read(chatAgenteProvider(null));

void main() {
  group('al entrar', () {
    testWidgets('sin perfil sale la hoja; «Saltar» abre la sesión con las cuatro variables vacías', (tester) async {
      final p = await _abrir(tester, perfil: null);

      expect(find.text(tituloHojaPerfil), findsOneWidget);
      expect(find.text(textoHojaPerfil), findsOneWidget);
      expect(p.agente.sesiones, isEmpty, reason: 'la sesión se abre después de la hoja');

      await tester.tap(find.byKey(const Key('perfil-saltar')));
      await tester.pumpAndSettle();

      expect(p.agente.sesiones.single, {'edad': '', 'procedimiento': '', 'rol': '', 'fase': ''});
      expect(p.prefs.getString('entrada'), isNull, reason: 'saltar no guarda nada');
      expect(find.text(tituloEscucho), findsOneWidget);
    });

    testWidgets('en la hoja, lo elegido se guarda y viaja con los valores del backend', (tester) async {
      final p = await _abrir(tester, perfil: null);

      Future<void> elegir(String texto) async {
        final opcion = find.descendant(of: find.byType(ChoiceChip), matching: find.text(texto));
        await tester.ensureVisible(opcion);
        await tester.pumpAndSettle();
        await tester.tap(opcion);
        await tester.pumpAndSettle();
      }

      await elegir('13');
      expect(find.text('Investigado'), findsNothing, reason: 'solo a partir de 14 años');
      await elegir('De familia');
      await elegir('Me van a escuchar');
      await elegir('Antes');
      await tester.tap(find.byKey(const Key('perfil-listo')));
      await tester.pumpAndSettle();

      expect(p.agente.sesiones.single, {'edad': '13', 'procedimiento': 'familia', 'rol': 'escuchado', 'fase': 'antes'});
      expect(jsonDecode(p.prefs.getString('entrada')!), {
        'edad': 13,
        'procedimiento': 'familia',
        'rol': 'escuchado_familia',
        'fase': 'antes',
      });
      const resumen = 'Para explicártelo mejor: 13 años · De familia · Me van a escuchar · Antes';
      await _desplazarHasta(tester, find.text(resumen));
      expect(find.text(resumen), findsOneWidget);
    });

    testWidgets('con «Mi situación», la hoja trae el papel marcado y viaja aunque se salte', (tester) async {
      final p = await _abrir(tester, perfil: null, situacion: RolProceso.testigo);

      final testigo = tester.widget<ChoiceChip>(
        find.ancestor(of: find.text('Testigo'), matching: find.byType(ChoiceChip)),
      );
      expect(testigo.selected, isTrue);
      await tester.tap(find.byKey(const Key('perfil-saltar')));
      await tester.pumpAndSettle();

      expect(p.agente.sesiones.single['rol'], 'testigo');
    });

    testWidgets('con perfil: «Conectando…», después «Te escucho» y el saludo, que no es un mensaje', (tester) async {
      final bloqueo = Completer<void>();
      final p = await _abrir(tester, agente: FakeAgenteVoz()..bloquearInicio = bloqueo, asentar: false);

      expect(find.text(tituloHojaPerfil), findsNothing);
      expect(find.text(tituloConectando), findsOneWidget);
      expect(p.agente.sesiones.single, {'edad': '13', 'procedimiento': 'penal', 'rol': 'testigo', 'fase': 'antes'});

      bloqueo.complete();
      await tester.pumpAndSettle();

      expect(find.text(tituloEscucho), findsOneWidget);
      expect(find.text(detalleEscucho), findsOneWidget);
      expect(find.byKey(const Key('saludo-agente')), findsOneWidget);
      expect(find.text(saludoAgente), findsOneWidget);
      expect(find.text(textoPresentacionAgente), findsOneWidget);
      expect(find.byType(BurbujaAsistente), findsNothing);
      // Sin «Voz / Sin voz» (no callaría al agente) y sin prometer que no se guarda la conversación.
      expect(find.text('Voz'), findsNothing);
      expect(find.text('Sin voz'), findsNothing);
      expect(find.textContaining('No guardo'), findsNothing);
    });
  });

  testWidgets('lo que el agente dice antes de la primera pregunta se lee bajo el saludo, sin tapar los ejemplos', (
    tester,
  ) async {
    final p = await _abrir(tester);

    // Si el agente toma la palabra tras un silencio, el backend de B contesta su respuesta segura.
    await _responde(tester, p.agente, respuestaSeguraBackend);

    expect(find.text(saludoAgente), findsOneWidget);
    expect(find.text(respuestaSeguraBackend), findsOneWidget);
    expect(find.byType(BurbujaAsistente), findsNothing);
    expect(find.byType(BurbujaError), findsNothing);
    expect(_estado(tester).mensajes, isEmpty);
    expect(find.text(textoPresentacionAgente), findsOneWidget);
  });

  group('preguntar', () {
    testWidgets('envía el texto, enseña «pensando» y la respuesta con los teléfonos en cifras y como botones', (
      tester,
    ) async {
      final p = await _abrir(tester);

      await _escribirYEnviar(tester, '¿Qué es la Sala Gesell?');

      expect(p.agente.enviados, ['¿Qué es la Sala Gesell?']);
      expect(find.byType(BurbujaUsuario), findsOneWidget);
      expect(find.byType(IndicadorEscribiendo), findsOneWidget);
      expect(find.text(tituloPensando), findsOneWidget);

      await _responde(
        tester,
        p.agente,
        'La Sala Gesell es una sala preparada para hablar con calma. Si tienes dudas, llama a la Fundación ANAR, en el '
        'novecientos, veinte, veinte, diez.',
      );

      expect(find.byType(IndicadorEscribiendo), findsNothing);
      expect(_respuesta('en el 900 20 20 10.'), findsOneWidget);
      expect(_respuesta('novecientos'), findsNothing);
      expect(find.text('Llamar al ${_nb('900 20 20 10')} · Fundación ANAR'), findsOneWidget);
      expect(find.text('TuTurno · IA'), findsOneWidget);
      expect(find.text(tituloEscucho), findsOneWidget);
    });

    testWidgets('escribir avisa al agente para que no tome la palabra', (tester) async {
      final p = await _abrir(tester);

      await tester.enterText(find.byKey(_campo), '¿Qué');
      await tester.pump();

      expect(p.agente.actividades, greaterThan(0));
    });

    testWidgets('crisis: la tarjeta de ayuda arriba, sin [slow], y botón para el 116 111', (tester) async {
      final p = await _abrir(tester);
      await _escribirYEnviar(tester, 'Tengo una duda');

      await _responde(tester, p.agente, plantillasSeguridad[TipoTextoAgente.crisis]!.single);

      expect(find.byKey(const Key('tarjeta-crisis')), findsOneWidget);
      expect(_respuesta('[slow]'), findsNothing);
      expect(_respuesta('llama al 112.'), findsOneWidget);
      expect(find.text('Llamar al ${_nb('116 111')} · Línea de ayuda a la infancia'), findsOneWidget);
      // ANAR y el 112 ya están en la tarjeta.
      expect(find.text('Llamar al ${_nb('112')} · Emergencias'), findsNothing);
    });

    testWidgets('si la pregunta suena a peligro, la tarjeta sale aunque la respuesta sea normal', (tester) async {
      final p = await _abrir(tester);
      await _escribirYEnviar(tester, 'A veces quiero morir');

      await _responde(tester, p.agente, 'Lo que sientes es importante. Puedes hablar con alguien de confianza.');

      expect(find.byKey(const Key('tarjeta-crisis')), findsOneWidget);
    });

    testWidgets('hechos: aviso de derivación; fuera de ámbito: sugerencias', (tester) async {
      final p = await _abrir(tester);
      await _escribirYEnviar(tester, 'Te cuento una cosa');
      await _responde(tester, p.agente, plantillasSeguridad[TipoTextoAgente.hechos]![1]);

      expect(find.text('Ver teléfonos de ayuda'), findsOneWidget);
      expect(find.text('¿Qué pasa si se denuncia?'), findsOneWidget);
      expect(find.text('Llamar al ${_nb('900 20 20 10')} · Fundación ANAR'), findsOneWidget);

      await _escribirYEnviar(tester, '¿Quién ganó el partido?');
      await _responde(tester, p.agente, plantillasSeguridad[TipoTextoAgente.fueraDeAmbito]!.first);

      expect(find.text('¿Qué es la Fiscalía de Menores?'), findsOneWidget);
    });

    testWidgets('respuesta segura del backend: «Reintentar» vuelve a enviar la pregunta', (tester) async {
      final p = await _abrir(tester);
      await _escribirYEnviar(tester, '¿Qué es la Sala Gesell?');
      await _responde(tester, p.agente, respuestaSeguraBackend);

      expect(find.byType(BurbujaError), findsOneWidget);
      expect(find.text(respuestaSeguraBackend), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(p.agente.enviados, ['¿Qué es la Sala Gesell?', '¿Qué es la Sala Gesell?']);
      await _responde(tester, p.agente, 'La Sala Gesell es una sala con un espejo especial.');
      expect(find.byType(BurbujaError), findsNothing);
      expect(_respuesta('espejo especial'), findsOneWidget);
    });

    testWidgets('una corrección (se interrumpió al agente) deja lo que llegó a decir', (tester) async {
      final p = await _abrir(tester);
      await _escribirYEnviar(tester, '¿Qué es la Sala Gesell?');
      const completo = 'La Sala Gesell es una sala con un espejo. Allí te escuchan con calma.';
      await _responde(tester, p.agente, completo);

      p.agente.corregir(completo, '...');
      await tester.pumpAndSettle();
      expect(_respuesta('Allí te escuchan'), findsOneWidget, reason: '«...» no borra el texto');

      p.agente.corregir(completo, 'La Sala Gesell es una sala');
      await tester.pumpAndSettle();
      expect(_respuesta('La Sala Gesell es una sala…'), findsOneWidget);
      expect(_respuesta('Allí te escuchan'), findsNothing);
    });

    testWidgets('lo que el agente dice por su cuenta también se lee', (tester) async {
      final p = await _abrir(tester);
      await _escribirYEnviar(tester, '¿Qué es la Sala Gesell?');
      await _responde(tester, p.agente, 'Es una sala especial.');

      await _responde(tester, p.agente, '¿Quieres saber algo más?');
      await _responde(tester, p.agente, '¿Quieres saber algo más?');

      expect(find.byType(BurbujaAsistente), findsNWidgets(2), reason: 'lo repetido no se enseña dos veces');
    });
  });

  group('si el agente no responde', () {
    testWidgets('a los 30 s: «TuTurno no responde ahora mismo», Reintentar y respuesta de ejemplo marcada', (
      tester,
    ) async {
      final p = await _abrir(tester);
      await _escribirYEnviar(tester, '¿Qué es la Sala Gesell?');

      await tester.pump(const Duration(seconds: 29));
      expect(find.text(textoSinRespuesta), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text(textoSinRespuesta), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text(tituloNoResponde), findsOneWidget);

      await tester.tap(find.byKey(const Key('ver-ejemplo')));
      await tester.pumpAndSettle();

      expect(find.text(textoSinRespuesta), findsNothing);
      expect(find.text(etiquetaEjemplo), findsOneWidget);
      expect(find.text(tituloEjemplo), findsOneWidget);
      expect(find.text(detalleEjemplo), findsOneWidget);
      expect(p.agente.terminados, 1, reason: 'con ejemplos no hace falta la sesión');

      // Las siguientes también son de ejemplo, y no van al agente.
      await _escribirYEnviar(tester, '¿Y si soy testigo?');
      await tester.pumpAndSettle();
      expect(p.agente.enviados, ['¿Qué es la Sala Gesell?']);
      expect(_estado(tester).mensajes.where((m) => m.ejemplo), hasLength(2));
      expect(find.text(etiquetaEjemplo), findsWidgets);

      // «Volver a TuTurno» abre otra sesión.
      await tester.tap(find.text('Volver a TuTurno'));
      await tester.pumpAndSettle();
      expect(p.agente.sesiones, hasLength(2));
      expect(find.text(tituloEscucho), findsOneWidget);
    });

    testWidgets('si la respuesta llega tarde, ocupa el sitio del aviso', (tester) async {
      final p = await _abrir(tester);
      await _escribirYEnviar(tester, '¿Qué es la Sala Gesell?');
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.text(textoSinRespuesta), findsOneWidget);

      await _responde(tester, p.agente, 'La Sala Gesell es una sala con un espejo especial.');

      expect(find.text(textoSinRespuesta), findsNothing);
      expect(_respuesta('espejo especial'), findsOneWidget);
      expect(find.text(tituloEscucho), findsOneWidget);
    });

    testWidgets('si no puede conectar: banda «Sin conexión», un reintento y, al preguntar, el error', (tester) async {
      final agente = FakeAgenteVoz()..fallarAlIniciar = const ErrorAgente(TextosAgente.sinConexion);
      final p = await _abrir(tester, agente: agente, asentar: false);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(p.agente.sesiones, hasLength(2), reason: 'se reintenta una vez');
      expect(find.text(tituloSinConexion), findsOneWidget);
      expect(find.text(TextosAgente.sinConexion), findsOneWidget);
      expect(find.text('Ver respuestas de ejemplo'), findsOneWidget);

      await _escribirYEnviar(tester, '¿Qué es la Sala Gesell?');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(BurbujaError), findsOneWidget);
      expect(p.agente.enviados, isEmpty);

      await tester.tap(find.byKey(const Key('ver-ejemplo')));
      await tester.pumpAndSettle();
      expect(find.text(etiquetaEjemplo), findsOneWidget);
    });

    testWidgets('sin permiso de micrófono no se reintenta: se explica', (tester) async {
      final agente = FakeAgenteVoz()..fallarAlIniciar = const ErrorAgente(TextosAgente.sinPermiso);
      final p = await _abrir(tester, agente: agente);

      expect(p.agente.sesiones, hasLength(1));
      expect(find.text(TextosAgente.sinPermiso), findsOneWidget);
    });

    testWidgets('si se corta la sesión mientras espera, el error sale enseguida', (tester) async {
      final p = await _abrir(tester);
      await _escribirYEnviar(tester, '¿Qué es la Sala Gesell?');

      p.agente.cortar();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text(textoCortado), findsOneWidget);
      expect(find.text(tituloSinConexion), findsOneWidget);
    });
  });

  group('voz y sesión', () {
    testWidgets('mientras habla el agente, el micrófono está desactivado y no escucha', (tester) async {
      final p = await _abrir(tester);

      p.agente.ponerHablando(true);
      await tester.pump();
      expect(find.text('TuTurno está hablando…'), findsOneWidget);
      expect(find.text(tituloHablando), findsOneWidget);

      await tester.tap(find.byKey(_micro));
      await tester.pump();
      expect(p.stt.inicializaciones, 0);

      p.agente.ponerHablando(false);
      await tester.pumpAndSettle();
      expect(find.text('Pulsa para hablar'), findsOneWidget);
    });

    testWidgets('si el agente empieza a hablar mientras se dicta, deja de escuchar y lo dictado se queda', (
      tester,
    ) async {
      final p = await _abrir(tester);
      await tester.tap(find.byKey(_micro));
      await tester.pump();
      await tester.pump();
      expect(p.stt.escuchando, isTrue);
      p.stt.oir('qué es la sala gesell');
      await tester.pump();

      p.agente.ponerHablando(true);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(p.stt.cancelaciones, 1);
      expect(tester.widget<TextField>(find.byKey(_campo)).controller!.text, 'qué es la sala gesell');
      expect(find.text('TuTurno está hablando…'), findsOneWidget);
    });

    testWidgets('si el dictado no oye nada con la sesión abierta, después se dicta con la sesión cerrada', (
      tester,
    ) async {
      final p = await _abrir(tester);
      await tester.tap(find.byKey(_micro));
      await tester.pump();
      await tester.pump();
      p.stt.fallar(ProblemaVoz.noTeOigo);
      await tester.pumpAndSettle();
      expect(p.agente.terminados, 0);

      // Segundo intento: Android quizá no le daba el micrófono con la llamada abierta. Se cierra antes de dictar.
      await tester.tap(find.byKey(_micro));
      await tester.pump();
      await tester.pump();
      expect(p.agente.terminados, 1);
      expect(p.stt.escuchando, isTrue);
      p.stt.oir('qué es la sala gesell');
      p.stt.silencio();
      await tester.pumpAndSettle();
      expect(find.text(tituloPausa), findsOneWidget);

      await tester.tap(find.byKey(_enviar));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(p.agente.sesiones, hasLength(2), reason: 'al preguntar se vuelve a abrir');
      expect(p.agente.enviados, ['qué es la sala gesell']);
      await _responde(tester, p.agente, 'Es una sala especial.');
      expect(_respuesta('Es una sala especial.'), findsOneWidget);
    });

    testWidgets('al pasar a segundo plano se cierra la sesión; al preguntar se vuelve a abrir', (tester) async {
      final p = await _abrir(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(p.agente.terminados, 1);

      // (Con la app oculta no se pintan fotogramas: la banda se mira al volver.)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text(tituloPausa), findsOneWidget);
      expect(find.text(detallePausa), findsOneWidget);
      expect(p.agente.sesiones, hasLength(1), reason: 'no se reconecta solo al volver');

      await _escribirYEnviar(tester, '¿Qué es la Sala Gesell?');
      await tester.pump(const Duration(milliseconds: 500));
      expect(p.agente.sesiones, hasLength(2));
      expect(p.agente.enviados, ['¿Qué es la Sala Gesell?']);
      await _responde(tester, p.agente, 'Es una sala especial.');
      expect(find.byType(BurbujaAsistente), findsOneWidget, reason: 'el saludo de la sesión nueva no es la respuesta');
      expect(_respuesta('Es una sala especial.'), findsOneWidget);
      expect(find.textContaining(detalleConversacionNueva), findsOneWidget);
    });

    testWidgets('al salir de Pregunta se cierra la sesión', (tester) async {
      final p = await _abrir(tester);

      p.router.go('/inicio');
      await tester.pumpAndSettle();

      expect(find.text('inicio'), findsOneWidget);
      expect(p.agente.terminados, 1);
    });

    testWidgets('«Nueva» borra sin prometer nada y empieza otra sesión', (tester) async {
      final p = await _abrir(tester);
      await _escribirYEnviar(tester, '¿Qué es la Sala Gesell?');
      await _responde(tester, p.agente, 'Es una sala especial.');

      await tester.tap(find.byTooltip('Empezar una conversación nueva'));
      await tester.pumpAndSettle();
      expect(find.text(textoBorrarAgente), findsOneWidget);
      expect(find.textContaining('no la guarda'), findsNothing);
      await tester.tap(find.text('Borrar'));
      await tester.pumpAndSettle();

      expect(find.byType(BurbujaAsistente), findsNothing);
      expect(p.agente.terminados, 1);
      expect(p.agente.sesiones, hasLength(2));
      expect(find.text(tituloEscucho), findsOneWidget);
    });

    testWidgets('«Cambiar» el perfil abre otra sesión con las variables nuevas', (tester) async {
      final p = await _abrir(tester);

      await _desplazarHasta(tester, find.byKey(const Key('cambiar-perfil')));
      await tester.tap(find.byKey(const Key('cambiar-perfil')));
      await tester.pumpAndSettle();
      final victima = find.descendant(of: find.byType(ChoiceChip), matching: find.text('Víctima'));
      await tester.ensureVisible(victima);
      await tester.pumpAndSettle();
      await tester.tap(victima);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('perfil-listo')));
      await tester.pumpAndSettle();

      expect(p.agente.sesiones, hasLength(2));
      expect(p.agente.sesiones.last['rol'], 'victima');
    });
  });
}
