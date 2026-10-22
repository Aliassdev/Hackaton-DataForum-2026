import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/agente/agente_provider.dart';
import 'package:tuturno/core/agente/agente_voz.dart' show ErrorAgente, EstadoAgente, TextosAgente;
import 'package:tuturno/core/agente/respuesta_agente.dart';
import 'package:tuturno/core/api/mock_api.dart';
import 'package:tuturno/core/api/tuturno_api.dart';
import 'package:tuturno/core/demo.dart';
import 'package:tuturno/core/voz/stt.dart' show ProblemaVoz;
import 'package:tuturno/features/pregunta/agente/chat_agente.dart';
import 'package:tuturno/features/pregunta/agente/textos_agente.dart';
import 'package:tuturno/features/pregunta/chat_controller.dart';
import 'package:tuturno/features/pregunta/ejemplos.dart';
import 'package:tuturno/features/pregunta/pregunta_screen.dart';
import 'package:tuturno/features/pregunta/textos.dart';
import 'package:tuturno/features/pregunta/widgets/mensajes.dart';
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/salida_rapida_button.dart';

import '../fakes.dart';
import 'fake_agente.dart';

// «Pregunta» en modo agente con un agente de voz falso: conecta, saludo, envío, respuestas (normal, crisis, hechos,
// hechos con fotos, fuera de ámbito), respaldo automático al modo texto real (no conecta, 20 s sin respuesta,
// «Contestar por escrito» a los 8 s, corte, respuesta segura), ejemplos solo si tampoco responde el modo texto,
// «Sin voz» y lector de pantalla (por escrito, sin sesión), micrófono, segundo plano y salida.

const _campo = Key('campo-pregunta');
const _enviar = Key('boton-enviar');
const _micro = Key('boton-micro');

/// Perfil guardado: así no sale la hoja del perfil.
const _perfilTestigo = <String, Object?>{'edad': 13, 'procedimiento': 'penal', 'rol': 'testigo', 'fase': 'antes'};

/// Los teléfonos de los botones van con espacios que no se cortan.
String _nb(String telefono) => telefono.replaceAll(' ', '\u00A0');

/// Respuestas de ejemplo que siempre son normales, digan lo que digan: para probar la red de seguridad de la app.
class _EjemplosSiempreNormales implements TuTurnoApi {
  @override
  Future<AskResponse> ask(AskRequest request) async =>
      const AskResponse(tipo: TipoRespuesta.normal, respuesta: 'Una respuesta de ejemplo cualquiera.');

  @override
  Future<GradeResponse> grade(GradeRequest request) => throw UnimplementedError();

  @override
  Future<HealthResponse> health() => throw UnimplementedError();
}

/// «Usar siempre el ejemplo en Pregunta» encendido desde el principio (modo demo).
class _UsarEjemploSiempre extends UsarEjemploPreguntaNotifier {
  @override
  bool build() => true;
}

class _Pantalla {
  _Pantalla(this.agente, this.stt, this.router, this.prefs, this.api);

  final FakeAgenteVoz agente;
  final FakeStt stt;
  final GoRouter router;
  final SharedPreferences prefs;

  /// El modo texto real (POST /api/agent/ask): aquí, el mock que guarda las peticiones.
  final ApiGrabadora api;
}

Future<_Pantalla> _abrir(
  WidgetTester tester, {
  Map<String, Object?>? perfil = _perfilTestigo,
  RolProceso? situacion,
  FakeAgenteVoz? agente,
  TuTurnoApi? ejemplos,
  bool asentar = true,
  bool vozActivada = true,
  bool lectorDePantalla = false,
  bool usarEjemplo = false,
}) async {
  tester.view.physicalSize = const Size(412, 915) * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  if (lectorDePantalla) {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      accessibleNavigation: true,
    );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  final voz = agente ?? FakeAgenteVoz();
  final stt = FakeStt();
  final api = ApiGrabadora();
  final overrides = await overridesDePrueba(
    api: api,
    stt: stt,
    tts: FakeTts(),
    entrada: perfil,
    vozActivada: vozActivada,
  );
  final prefs = await SharedPreferences.getInstance();
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
      GoRoute(
        path: '/salida',
        builder: (context, state) => const Scaffold(body: Text('salida')),
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
        respuestasEjemploProvider.overrideWithValue(ejemplos ?? RespuestasDeEjemplo.desdeJson(ejemplosPreguntaJson())),
        if (usarEjemplo) usarEjemploPreguntaProvider.overrideWith(_UsarEjemploSiempre.new),
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
  return _Pantalla(voz, stt, router, prefs, api);
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

/// Pasa [tiempo] esperando la respuesta (hay animaciones sin fin: no vale pumpAndSettle).
Future<void> _esperar(WidgetTester tester, Duration tiempo) async {
  await tester.pump(tiempo);
  await tester.pump();
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

ChatAgenteNotifier _chat(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(PreguntaScreen))).read(chatAgenteProvider(null).notifier)
        as ChatAgenteNotifier;

void main() {
  group('al entrar', () {
    testWidgets('sin perfil sale la hoja; «Saltar» abre la sesión con las cuatro variables vacías', (tester) async {
      final p = await _abrir(tester, perfil: null);

      expect(find.text(tituloHojaPerfil), findsOneWidget);
      expect(find.text(textoHojaPerfil), findsOneWidget);
      expect(textoHojaPerfil, contains('No te pregunto qué ha pasado. Solo esto, para explicarte mejor.'));
      expect(p.agente.sesiones, isEmpty, reason: 'la sesión se abre después de la hoja');

      await tester.tap(find.byKey(const Key('perfil-saltar')));
      await tester.pumpAndSettle();

      expect(p.agente.sesiones.single, {'edad': '', 'procedimiento': '', 'rol': '', 'fase': ''});
      expect(p.prefs.getString('entrada'), isNull, reason: 'saltar no guarda nada');
      expect(find.text(tituloEscucho), findsOneWidget);
    });

    testWidgets('en la hoja, lo elegido se guarda, viaja con los valores del backend y se resume arriba', (
      tester,
    ) async {
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
      const resumen = 'Te explico para: 13 años · De familia · Me van a escuchar · Antes';
      expect(find.text(resumen), findsOneWidget);
      expect(find.text('Cambiar'), findsOneWidget);
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

    testWidgets('con perfil: «Conectando…» (micrófono en espera), después «Conectado: Tut te escucha» y el saludo, '
        'que no es un mensaje', (tester) async {
      final bloqueo = Completer<void>();
      final p = await _abrir(tester, agente: FakeAgenteVoz()..bloquearInicio = bloqueo, asentar: false);

      expect(find.text(tituloHojaPerfil), findsNothing);
      expect(find.text(tituloConectando), findsOneWidget);
      expect(find.text('Conectando…'), findsOneWidget, reason: 'la etiqueta del micrófono');
      expect(p.agente.sesiones.single, {'edad': '13', 'procedimiento': 'penal', 'rol': 'testigo', 'fase': 'antes'});
      await tester.tap(find.byKey(_micro));
      await tester.pump();
      expect(p.stt.inicializaciones, 0, reason: 'el saludo cortaría el dictado');

      bloqueo.complete();
      await tester.pumpAndSettle();

      expect(find.text(tituloEscucho), findsOneWidget);
      expect(tituloEscucho, 'Conectado: Tut te escucha');
      expect(find.text(detalleEscucho), findsOneWidget);
      expect(find.text(textoPresentacionAgente), findsOneWidget);
      expect(find.byType(BurbujaAsistente), findsNothing);
      expect(find.text('Pulsa para hablar'), findsOneWidget);
      // (Con la letra de las pruebas, más ancha que la real, el saludo queda justo debajo: se desplaza.)
      await _desplazarHasta(tester, find.byKey(const Key('saludo-agente')));
      expect(find.text(saludoAgente), findsOneWidget);
      // Que contesta en alto se dice antes de preguntar, y se puede quitar la voz. Nada promete que no se guarda.
      await _desplazarHasta(tester, find.byKey(const Key('aviso-voz-alta')));
      expect(find.byKey(const Key('aviso-voz-alta')), findsOneWidget);
      expect(find.text('Voz'), findsOneWidget);
      expect(find.textContaining('No guardo'), findsNothing);
      expect(find.textContaining('se borra'), findsNothing);
    });
  });

  testWidgets('lo que el agente dice antes de la primera pregunta se lee bajo el saludo, sin tapar los ejemplos', (
    tester,
  ) async {
    final p = await _abrir(tester);

    // Si el agente toma la palabra tras un silencio, el backend de B contesta su respuesta segura.
    await _responde(tester, p.agente, respuestaSeguraBackend);

    expect(find.text(textoPresentacionAgente), findsOneWidget);
    await _desplazarHasta(tester, find.text(respuestaSeguraBackend));
    expect(find.text(saludoAgente), findsOneWidget);
    expect(find.text(respuestaSeguraBackend), findsOneWidget);
    expect(find.byType(BurbujaAsistente), findsNothing);
    expect(find.byType(BurbujaError), findsNothing);
    expect(_estado(tester).mensajes, isEmpty);
  });

  group('preguntar', () {
    testWidgets(
      'envía el texto, enseña el eco y «pensando», y la respuesta con los teléfonos en cifras y como botones',
      (tester) async {
        final p = await _abrir(tester);

        await _escribirYEnviar(tester, '¿Qué es la Sala Gesell?');

        expect(p.agente.enviados, ['¿Qué es la Sala Gesell?']);
        expect(find.byType(BurbujaUsuario), findsOneWidget);
        expect(find.byType(IndicadorEscribiendo), findsOneWidget);
        expect(find.text(tituloPensando), findsOneWidget);
        expect(find.text('Espera a que te conteste…'), findsOneWidget, reason: 'el micrófono espera');

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
        expect(p.api.peticiones, isEmpty, reason: 'ha contestado la voz');
      },
    );

    testWidgets('escribir avisa al agente para que no tome la palabra', (tester) async {
      final p = await _abrir(tester);

      await tester.enterText(find.byKey(_campo), '¿Qué');
      await tester.pump();

      expect(p.agente.actividades, greaterThan(0));
    });

    testWidgets('crisis: la tarjeta de ayuda arriba con «Salir rápido», sin [slow], y botón para el 116 111', (
      tester,
    ) async {
      final p = await _abrir(tester);
      await _escribirYEnviar(tester, 'Tengo una duda');

      await _responde(tester, p.agente, plantillasSeguridad[TipoTextoAgente.crisis]!.single);

      final tarjeta = find.byKey(const Key('tarjeta-crisis'));
      expect(tarjeta, findsOneWidget);
      expect(find.descendant(of: tarjeta, matching: find.byType(SalidaRapidaButton)), findsOneWidget);
      expect(find.descendant(of: tarjeta, matching: find.text('Salir rápido')), findsOneWidget);
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
      expect(find.byKey(const Key('quitar-imagenes')), findsNothing, reason: 'no hablaba de fotos');

      await _escribirYEnviar(tester, '¿Quién ganó el partido?');
      await _responde(tester, p.agente, plantillasSeguridad[TipoTextoAgente.fueraDeAmbito]!.first);

      expect(find.text('¿Qué es la Fiscalía de Menores?'), findsOneWidget);
    });

    testWidgets('hechos con fotos (regla local): además el 017 con su horario y «Quitar fotos o vídeos de internet», '
        'con las fuentes «INCIBE · 017» y «AEPD · Canal prioritario»', (tester) async {
      final p = await _abrir(tester);
      await _escribirYEnviar(tester, 'Un chico de mi clase pasó unas fotos mías');
      await _responde(tester, p.agente, plantillasSeguridad[TipoTextoAgente.hechos]![1]);

      expect(find.text('Ver teléfonos de ayuda'), findsOneWidget);
      await _desplazarHasta(tester, find.byKey(const Key('quitar-imagenes')));
      expect(find.text('Llamar al 017 · Ciberseguridad (INCIBE)'), findsOneWidget);
      expect(find.text('Todos los días, de 8:00 a 23:00'), findsOneWidget);
      expect(find.text('$textoQuitarImagenes · Canal prioritario de la AEPD'), findsOneWidget);
      final fuentes = _estado(tester).mensajes.last.respuesta!.fuentes;
      expect(fuentes.map((f) => f.norma), containsAll(['INCIBE · 017', 'AEPD · Canal prioritario']));
      expect(p.agente.enviados, ['Un chico de mi clase pasó unas fotos mías'], reason: 'la regla no envía nada');
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

  group('respaldo: si la voz no responde, contesta el modo texto real', () {
    testWidgets('a los 8 s, «Sigo buscando en las leyes…» y «Contestar por escrito», que pregunta al modo texto', (
      tester,
    ) async {
      final p = await _abrir(tester);
      await _escribirYEnviar(tester, '¿Qué es la Sala Gesell?');

      await _esperar(tester, const Duration(seconds: 7));
      expect(find.byKey(const Key('contestar-por-escrito')), findsNothing);
      await _esperar(tester, const Duration(seconds: 1));
      expect(find.text('$textoSigoBuscando…'), findsOneWidget);
      expect(find.byKey(const Key('contestar-por-escrito')), findsOneWidget);

      await tester.tap(find.byKey(const Key('contestar-por-escrito')));
      await tester.pumpAndSettle();

      expect(p.api.peticiones.single.pregunta, '¿Qué es la Sala Gesell?');
      expect(_respuesta('Sala Gesell'), findsWidgets);
      expect(_estado(tester).mensajes.last.ejemplo, isFalse);
      expect(find.text(tituloSinVoz), findsOneWidget);
      expect(find.text(detalleSinVoz), findsOneWidget);
      expect(p.agente.terminados, 1, reason: 'se cierra la sesión de voz');
    });

    testWidgets('a los 20 s sin respuesta pasa solo al modo texto real (no a los ejemplos); «Probar con voz» vuelve', (
      tester,
    ) async {
      final p = await _abrir(tester);
      await _escribirYEnviar(tester, '¿Qué es la Sala Gesell?');

      await _esperar(tester, const Duration(seconds: 19));
      expect(p.api.peticiones, isEmpty);
      await _esperar(tester, const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(p.api.peticiones.single.pregunta, '¿Qué es la Sala Gesell?');
      expect(p.api.peticiones.single.perfil, {
        'edad': '13',
        'procedimiento': 'penal',
        'rol': 'testigo',
        'fase': 'antes',
      });
      expect(find.byType(BurbujaError), findsNothing);
      expect(find.text('TuTurno · IA'), findsOneWidget);
      expect(find.text(etiquetaEjemplo), findsNothing);
      expect(find.text(tituloSinVoz), findsOneWidget);

      // La siguiente también va por escrito, y no al agente.
      await _escribirYEnviar(tester, '¿Quién puede acompañarme?');
      await tester.pumpAndSettle();
      expect(p.agente.enviados, ['¿Qué es la Sala Gesell?']);
      expect(p.api.peticiones, hasLength(2));

      // Una respuesta tardía de la sesión cerrada no se enseña.
      p.agente.decir('La Sala Gesell es una sala con un espejo especial.');
      await tester.pumpAndSettle();
      expect(_respuesta('espejo especial'), findsNothing);

      await tester.tap(find.text(accionProbarVoz));
      await tester.pumpAndSettle();
      expect(p.agente.sesiones, hasLength(2));
      expect(find.text(tituloEscucho), findsOneWidget);
    });

    testWidgets('si el modo texto tampoco responde: «Reintentar» y «Ver una respuesta de ejemplo», todo marcado', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      final p = await _abrir(tester);
      p.api.errores.add(errorApi);
      await _escribirYEnviar(
        tester,
        'Mis padres han ido a la Fiscalía porque me acosan en el instituto. ¿Qué va a pasar?',
      );
      await _esperar(tester, const Duration(seconds: 21));
      await tester.pumpAndSettle();

      expect(find.text(errorApi.mensaje), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ver-ejemplo')));
      await tester.pumpAndSettle();

      expect(find.text(errorApi.mensaje), findsNothing);
      expect(find.text(etiquetaEjemplo), findsOneWidget);
      expect(find.byKey(const Key('insignia-ejemplo')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(semanticaEjemplo)), findsOneWidget);
      expect(find.text(tituloEjemplo), findsOneWidget);
      expect(find.text(detalleEjemplo), findsOneWidget);
      // La de Sergio del JSON de ejemplos, con fuentes de MARCO_LEGAL.
      expect(_respuesta('la Fiscalía de Menores decide si lo que pasó puede ser delito'), findsOneWidget);
      expect(_estado(tester).mensajes.last.respuesta!.fuentes.first.url, startsWith('https://www.boe.es/'));

      // Las siguientes también son de ejemplo, sin agente ni modo texto.
      await _escribirYEnviar(tester, '¿Qué puedo hacer si difunden fotos mías sin permiso?');
      await tester.pumpAndSettle();
      expect(p.agente.enviados, [
        'Mis padres han ido a la Fiscalía porque me acosan en el instituto. ¿Qué va a pasar?',
      ]);
      expect(p.api.peticiones, hasLength(1));
      expect(_estado(tester).mensajes.where((m) => m.ejemplo), hasLength(2));

      // «Volver a TuTurno» deja los ejemplos y abre otra sesión de voz.
      await tester.tap(find.text(accionVolverATuTurno));
      await tester.pumpAndSettle();
      expect(find.text(tituloEjemplo), findsNothing);
      expect(p.agente.sesiones, hasLength(2));
      expect(find.text(tituloEscucho), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('con los ejemplos, si la pregunta suena a peligro, la tarjeta de ayuda sale siempre', (tester) async {
      final p = await _abrir(tester, ejemplos: _EjemplosSiempreNormales());
      p.api.errores.add(errorApi);
      await _escribirYEnviar(tester, '¿Qué es la Sala Gesell?');
      await _esperar(tester, const Duration(seconds: 21));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ver-ejemplo')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tarjeta-crisis')), findsNothing);

      await _escribirYEnviar(tester, 'Estoy en peligro, mi padre está borracho');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tarjeta-crisis')), findsOneWidget);
      expect(_estado(tester).mensajes.last.respuesta?.tipo, TipoRespuesta.crisis);
    });

    testWidgets('si no puede conectar (10 s y un reintento), contesta el modo texto sin esperar a la voz', (
      tester,
    ) async {
      final agente = FakeAgenteVoz()..fallarAlIniciar = const ErrorAgente(TextosAgente.sinConexion);
      final p = await _abrir(tester, agente: agente, asentar: false);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(p.agente.sesiones, hasLength(2), reason: 'se reintenta una vez');
      expect(find.text(tituloSinVoz), findsOneWidget);
      expect(find.byKey(const Key('aviso-voz-alta')), findsNothing);

      await _escribirYEnviar(tester, '¿Qué es la Sala Gesell?');
      await tester.pumpAndSettle();
      expect(p.agente.enviados, isEmpty);
      expect(p.api.peticiones.single.pregunta, '¿Qué es la Sala Gesell?');
      expect(find.byType(BurbujaError), findsNothing);
      expect(find.byType(BurbujaAsistente), findsOneWidget);
    });

    testWidgets('si la conexión no se abre en 10 s, también: un reintento y después por escrito', (tester) async {
      final p = await _abrir(tester, agente: FakeAgenteVoz()..bloquearInicio = Completer<void>(), asentar: false);

      await tester.pump(ChatAgenteNotifier.tiempoConexion);
      await tester.pump(ChatAgenteNotifier.pausaReintento);
      await tester.pump(ChatAgenteNotifier.tiempoConexion);
      await tester.pumpAndSettle();
      expect(p.agente.sesiones, hasLength(2));
      expect(find.text(tituloSinVoz), findsOneWidget);
    });

    testWidgets('si se cambia el perfil mientras conecta, el tiempo del intento viejo no corta la sesión nueva', (
      tester,
    ) async {
      final agente = FakeAgenteVoz()..bloquearInicio = Completer<void>();
      final p = await _abrir(tester, agente: agente, asentar: false);
      expect(p.agente.sesiones, hasLength(1));

      // El primer intento se queda colgado. A los 8 s cambia el perfil y la sesión nueva conecta enseguida.
      await tester.pump(const Duration(seconds: 8));
      agente.bloquearInicio = null;
      await _chat(tester).cambiarPerfil();
      await tester.pump();
      expect(p.agente.sesiones, hasLength(2));
      expect(agente.estado.value, EstadoAgente.conectado);
      final terminados = agente.terminados;

      // A los 10 s vence el tiempo del primer intento: ya no es el de ahora, así que no toca el agente.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(agente.terminados, terminados);
      expect(agente.estado.value, EstadoAgente.conectado);
      expect(p.agente.sesiones, hasLength(2), reason: 'sin reintentos del intento viejo');
      expect(find.text(tituloSinVoz), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('si el agente no está preparado no se reintenta: contesta por escrito', (tester) async {
      final agente = FakeAgenteVoz()..fallarAlIniciar = const ErrorAgente(TextosAgente.sinConfigurar);
      final p = await _abrir(tester, agente: agente);

      expect(p.agente.sesiones, hasLength(1));
      expect(find.text(tituloSinVoz), findsOneWidget);
    });

    testWidgets('si se corta la sesión mientras espera, esa pregunta se contesta por escrito y la voz sigue', (
      tester,
    ) async {
      final p = await _abrir(tester);
      await _escribirYEnviar(tester, '¿Qué es la Sala Gesell?');

      p.agente.cortar();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(p.api.peticiones.single.pregunta, '¿Qué es la Sala Gesell?');
      expect(find.byType(BurbujaError), findsNothing);
      expect(find.text(tituloSinConexion), findsOneWidget);
      expect(find.text(textoCerrado), findsOneWidget);

      await _escribirYEnviar(tester, '¿Quién puede acompañarme?');
      await _responde(tester, p.agente, 'Puede acompañarte una persona de confianza.');
      expect(p.agente.sesiones, hasLength(2), reason: 'se vuelve a abrir al preguntar');
      expect(p.agente.enviados.last, '¿Quién puede acompañarme?');
    });

    testWidgets('la respuesta segura del backend (su modelo ha fallado): esa pregunta, por escrito; la voz sigue', (
      tester,
    ) async {
      final p = await _abrir(tester);
      await _escribirYEnviar(tester, '¿Qué es la Sala Gesell?');
      await _responde(tester, p.agente, respuestaSeguraBackend);

      expect(find.byType(BurbujaError), findsNothing);
      expect(p.api.peticiones.single.pregunta, '¿Qué es la Sala Gesell?');
      expect(find.byType(BurbujaAsistente), findsOneWidget);

      await _escribirYEnviar(tester, '¿Y si soy testigo?');
      expect(p.agente.enviados, ['¿Qué es la Sala Gesell?', '¿Y si soy testigo?']);
      expect(p.agente.sesiones, hasLength(1));
    });
  });

  group('por escrito a propósito: sin sesión de voz', () {
    testWidgets('con «Sin voz» no se abre la sesión y contesta el modo texto; con «Voz», se conecta', (tester) async {
      final p = await _abrir(tester, vozActivada: false);

      expect(p.agente.sesiones, isEmpty);
      expect(find.byKey(const Key('banda-agente')), findsNothing);
      expect(find.byKey(const Key('aviso-voz-alta')), findsNothing);
      expect(find.text('Sin voz'), findsOneWidget);

      await _escribirYEnviar(tester, '¿Qué es la Sala Gesell?');
      await tester.pumpAndSettle();
      expect(p.agente.enviados, isEmpty);
      expect(p.api.peticiones.single.pregunta, '¿Qué es la Sala Gesell?');

      await tester.tap(find.byTooltip('Las respuestas no se leen en voz alta'));
      await tester.pumpAndSettle();
      expect(p.agente.sesiones, hasLength(1));
      expect(find.text(tituloEscucho), findsOneWidget);

      // Y quitarla otra vez cierra la sesión.
      await tester.tap(find.byTooltip('Las respuestas se leen en voz alta'));
      await tester.pumpAndSettle();
      expect(p.agente.terminados, 1);
      expect(find.byKey(const Key('banda-agente')), findsNothing);
    });

    testWidgets('con lector de pantalla (TalkBack), por escrito y sin abrir la sesión', (tester) async {
      final p = await _abrir(tester, lectorDePantalla: true);

      expect(p.agente.sesiones, isEmpty);
      await _escribirYEnviar(tester, '¿Qué es la Sala Gesell?');
      await tester.pumpAndSettle();
      expect(p.agente.enviados, isEmpty);
      expect(p.api.peticiones, hasLength(1));
      expect(find.byType(BurbujaAsistente), findsOneWidget);
    });

    testWidgets('con el ejemplo forzado en el modo demo: banda, respuestas marcadas y sin sesión', (tester) async {
      final p = await _abrir(tester, usarEjemplo: true);

      expect(p.agente.sesiones, isEmpty);
      expect(find.text(tituloEjemplo), findsOneWidget);
      await _escribirYEnviar(tester, 'El que me insultaba era mi compañero de mesa.');
      await tester.pumpAndSettle();

      expect(p.api.peticiones, isEmpty);
      expect(_respuesta(MockTuTurnoApi.plantillaHechosAgente), findsOneWidget);
      expect(find.text(etiquetaEjemplo), findsOneWidget);
      expect(find.text('Ver teléfonos de ayuda'), findsOneWidget);
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

    testWidgets('dictar no cierra la sesión (no usa el micrófono), aunque el dictado no oiga nada', (tester) async {
      final p = await _abrir(tester);
      await tester.tap(find.byKey(_micro));
      await tester.pump();
      await tester.pump();
      p.stt.fallar(ProblemaVoz.noTeOigo);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_micro));
      await tester.pump();
      await tester.pump();
      expect(p.stt.escuchando, isTrue);
      p.stt.oir('qué es la sala gesell');
      p.stt.silencio();
      await tester.pumpAndSettle();
      expect(p.agente.terminados, 0);
      expect(find.text(tituloEscucho), findsOneWidget);

      await tester.tap(find.byKey(_enviar));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(p.agente.sesiones, hasLength(1), reason: 'la misma sesión: no hace falta volver a conectar');
      expect(p.agente.enviados, ['qué es la sala gesell']);
      await _responde(tester, p.agente, 'Es una sala especial.');
      expect(_respuesta('Es una sala especial.'), findsOneWidget);
      expect(find.textContaining(detalleConversacionNueva), findsNothing);
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
      expect(find.textContaining('Se borra'), findsNothing);
      await tester.tap(find.text('Borrar'));
      await tester.pumpAndSettle();

      expect(find.byType(BurbujaAsistente), findsNothing);
      expect(p.agente.terminados, 1);
      expect(p.agente.sesiones, hasLength(2));
      expect(find.text(tituloEscucho), findsOneWidget);
    });

    testWidgets('«Cambiar» el perfil abre otra sesión con las variables nuevas', (tester) async {
      final p = await _abrir(tester);

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
      expect(find.text('Te explico para: 13 años · Penal · Víctima · Antes'), findsOneWidget);
    });

    testWidgets('el chat avisa de que la pregunta espera a la voz (y deja de esperar al contestar)', (tester) async {
      final p = await _abrir(tester);
      await _escribirYEnviar(tester, '¿Qué es la Sala Gesell?');
      expect(_estado(tester).esperandoVoz, isTrue);
      expect(_chat(tester).usaVoz, isTrue);

      await _responde(tester, p.agente, 'Es una sala especial.');
      expect(_estado(tester).esperandoVoz, isFalse);
    });
  });
}
