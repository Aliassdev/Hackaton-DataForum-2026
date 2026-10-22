// Capturas de Pregunta con el agente de voz, el respaldo por escrito y los ejemplos (tarea B1), con las fuentes reales.
// No se ejecuta por defecto:
//
//   CAPTURAS=build/capturas flutter test test/features/pregunta/capturas_b1_test.dart
//
// En flutter_test las sombras se pintan sin desenfoque (debugDisableShadows): en el móvil salen suaves.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tuturno/core/agente/agente_provider.dart';
import 'package:tuturno/core/agente/respuesta_agente.dart';
import 'package:tuturno/core/api/mock_api.dart';
import 'package:tuturno/core/api/tuturno_api.dart';
import 'package:tuturno/features/pregunta/ejemplos.dart';
import 'package:tuturno/features/pregunta/pregunta_screen.dart';
import 'package:tuturno/tema.dart';

import 'agente/fake_agente.dart';
import 'capturas_comunes.dart';
import 'fakes.dart';

/// El backend real responde en párrafos y con el enlace de cada artículo en el BOE.
class _BackendReal implements TuTurnoApi {
  @override
  Future<AskResponse> ask(AskRequest request) async => const AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'Cuando tus padres denuncian, la Fiscalía de Menores decide si lo que pasó puede ser delito y si sigue '
        'adelante.\n\nEn cualquier momento, el fiscal puede pedir al juez medidas para protegerte, como que no se te '
        'acerquen.',
    fuentes: [
      Fuente(
        id: 'LORPM-16',
        titulo: 'Incoación del expediente',
        norma: 'LO 5/2000',
        articulo: '16.2',
        url: 'https://www.boe.es/buscar/act.php?id=BOE-A-2000-641',
      ),
      Fuente(
        id: 'LORPM-28',
        titulo: 'Medidas cautelares',
        norma: 'LO 5/2000',
        articulo: '28.1',
        url: 'https://www.boe.es/buscar/act.php?id=BOE-A-2000-641',
      ),
    ],
  );

  @override
  Future<GradeResponse> grade(GradeRequest request) => throw UnimplementedError();

  @override
  Future<HealthResponse> health() => throw UnimplementedError();
}

Future<(FakeAgenteVoz, ApiGrabadora)> _abrir(
  WidgetTester tester, {
  bool conAgente = true,
  double escala = 1,
  Size tamano = const Size(412, 915),
  TuTurnoApi? backend,
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = tamano * 2;
  addTearDown(tester.view.reset);
  final agente = FakeAgenteVoz();
  final api = ApiGrabadora(base: backend);
  final router = GoRouter(
    initialLocation: '/pregunta',
    routes: [GoRoute(path: '/pregunta', builder: (context, state) => const PreguntaScreen())],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...await overridesDePrueba(api: api, stt: FakeStt(), tts: FakeTts()),
        modoAgenteProvider.overrideWithValue(conAgente),
        agenteVozProvider.overrideWithValue(conAgente ? agente : null),
        respuestasEjemploProvider.overrideWithValue(RespuestasDeEjemplo.desdeJson(ejemplosPreguntaJson())),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: temaTuTurno(Brightness.light),
        locale: const Locale('es', 'ES'),
        supportedLocales: const [Locale('es', 'ES')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(escala)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (agente, api);
}

Future<void> _enviar(WidgetTester tester, String texto) async {
  await tester.enterText(find.byKey(const Key('campo-pregunta')), texto);
  await tester.pump();
  await tester.tap(find.byKey(const Key('boton-enviar')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() async {
    if (destinoCapturas != null) await cargarFuentesReales();
  });

  testWidgets('capturas del agente de voz', (tester) async {
    final (agente, _) = await _abrir(tester);
    await capturar(tester, 'b1-01-agente-conectado');

    await _enviar(tester, 'Mis padres han ido a la Fiscalía porque me acosan en el instituto. ¿Qué va a pasar ahora?');
    agente.decir(
      'Vale, te cuento. La Fiscalía de Menores recibe la denuncia y decide si abre un expediente. Si te sientes mal, en '
      'ANAR te escuchan: novecientos, veinte, veinte, diez.',
    );
    await tester.pumpAndSettle();
    await capturar(tester, 'b1-02-agente-respuesta');

    await _enviar(tester, 'Un chico de mi clase pasó unas fotos mías');
    agente.decir(plantillasSeguridad[TipoTextoAgente.hechos]![1]);
    await tester.pumpAndSettle();
    await capturar(tester, 'b1-03-hechos-fotos');

    await _enviar(tester, 'Tengo una duda');
    agente.decir(plantillasSeguridad[TipoTextoAgente.crisis]!.single);
    await tester.pumpAndSettle();
    await capturar(tester, 'b1-04-crisis-salir-rapido');
  }, skip: destinoCapturas == null);

  testWidgets('capturas del respaldo: 8 s, modo texto real y ejemplos', (tester) async {
    final (_, api) = await _abrir(tester);
    await _enviar(tester, '¿Qué es la Sala Gesell?');
    await tester.pump(const Duration(seconds: 8));
    await tester.pump();
    await capturar(tester, 'b1-05-ocho-segundos');

    await tester.pump(const Duration(seconds: 13));
    await tester.pumpAndSettle();
    await capturar(tester, 'b1-06-sin-voz-por-escrito');

    api.errores.add(errorApi);
    await _enviar(tester, '¿Qué puedo hacer si difunden fotos mías sin permiso?');
    await tester.pumpAndSettle();
    await capturar(tester, 'b1-07-error-ver-ejemplo');
    await tester.tap(find.byKey(const Key('ver-ejemplo')));
    await tester.pumpAndSettle();
    await capturar(tester, 'b1-08-ejemplo-marcado');
  }, skip: destinoCapturas == null);

  testWidgets('capturas del modo texto (web): párrafos y fuente con enlace al BOE', (tester) async {
    await _abrir(tester, conAgente: false, backend: _BackendReal());
    await capturar(tester, 'b1-09-texto-vacia');
    await _enviar(tester, 'Mis padres han ido a la Fiscalía. ¿Qué va a pasar?');
    await tester.pumpAndSettle();
    await capturar(tester, 'b1-10-texto-parrafos');
    await tester.tap(find.text('LO 5/2000 · art. 16.2'));
    await tester.pumpAndSettle();
    await capturar(tester, 'b1-11-hoja-boe');
  }, skip: destinoCapturas == null);

  testWidgets('capturas con letra a 1,3 en 360×640', (tester) async {
    final (agente, _) = await _abrir(tester, escala: 1.3, tamano: const Size(360, 640));
    await capturar(tester, 'b1-12-pequeno-agente');
    await _enviar(tester, 'El que me insultaba era mi compañero de mesa.');
    agente.decir(MockTuTurnoApi.plantillaHechosAgente);
    await tester.pumpAndSettle();
    await capturar(tester, 'b1-13-pequeno-hechos');
  }, skip: destinoCapturas == null);
}
