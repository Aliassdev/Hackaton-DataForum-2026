import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/app.dart';
import 'package:tuturno/core/api/mock_api.dart';
import 'package:tuturno/core/api/tuturno_api.dart';
import 'package:tuturno/core/config.dart';
import 'package:tuturno/core/content_repo.dart';
import 'package:tuturno/core/progreso.dart';
import 'package:tuturno/core/providers.dart';
import 'package:tuturno/core/voz/stt.dart';
import 'package:tuturno/core/voz/tts.dart';
import 'package:tuturno/features/ajustes/demo.dart';

import '../a1/helpers.dart' show BundleEnMemoria, glosarioDePrueba, movil;
import '../pregunta/fakes.dart' show FakeStt, FakeTts;

// Piezas comunes de las pruebas de Ajustes («Leer mejor», «Borrar todo» y el modo demo).

/// La hora de las pruebas: jueves 22/10/2026 a las 17:30, con el 017 abierto.
final ahoraDePrueba = DateTime(2026, 10, 22, 17, 30);

/// Lo que «Comprobar antes de salir» pregunta a la red y al móvil, a gusto de cada prueba.
class SondasFalsas implements SondasDemo {
  SondasFalsas({this.red = true, this.voz = VozEspanola.instalada});

  bool red;
  VozEspanola voz;

  @override
  Future<bool> hayRed() async => red;

  @override
  Future<VozEspanola> vozEspanola() async => voz;
}

/// Un servidor que no contesta nunca (por ejemplo, dormido).
class ApiDormida implements TuTurnoApi {
  final _nunca = Completer<Never>();

  @override
  Future<AskResponse> ask(AskRequest request) => _nunca.future;

  @override
  Future<GradeResponse> grade(GradeRequest request) => _nunca.future;

  @override
  Future<HealthResponse> health() => _nunca.future;
}

/// Un servidor que contesta al momento, como el de la demo.
TuTurnoApi apiDespierta() => MockTuTurnoApi(latencia: Duration.zero);

/// El contenido de las pruebas con casos, en memoria: el glosario de prueba, los tres casos oficiales y la unidad 2 de
/// Aprende (la de la Sala Gesell), leídos del disco como están en la app. Los assets de verdad se leen con E/S real, que
/// no avanza con el reloj falso de las pruebas.
Map<String, String> contenidoConCasos() {
  String leer(String ruta) => File('assets/mock/content/$ruta').readAsStringSync();
  return {
    '${ContentRepo.raiz}/glosario.json': glosarioDePrueba,
    for (final caso in ['caso-sala-gesell', 'caso-acoso-escolar', 'caso-difusion-imagenes'])
      '${ContentRepo.raiz}/juego/$caso.json': leer('juego/$caso.json'),
    '${ContentRepo.raiz}/lecciones/unidad-2.json': leer('lecciones/unidad-2.json'),
    '${ContentRepo.raiz}/ejercicios/unidad-2.json': leer('ejercicios/unidad-2.json'),
  };
}

/// Arranca TuTurnoApp como en main(). Por defecto, con mock, sin DEMO, la bienvenida ya vista, el glosario de prueba
/// en memoria, la hora de [ahoraDePrueba] y voz, dictado y sondas falsas.
///
/// Con [conCasos], el contenido es [contenidoConCasos] y responde al interruptor de borradores como en la app (solo con
/// DEMO).
Future<GoRouter> arrancarAjustes(
  WidgetTester tester, {
  bool demo = false,
  bool useMock = true,
  String apiUrl = '',
  bool bienvenidaVista = true,
  Map<String, Object> preferencias = const {},
  bool conCasos = false,
  Size tamano = movil,
  DateTime? ahora,
  Tts? tts,
  Stt? stt,
  SondasDemo? sondas,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = tamano * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({if (bienvenidaVista) 'bienvenida_vista': true, ...preferencias});
  final prefs = await SharedPreferences.getInstance();
  final hora = ahora ?? ahoraDePrueba;
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        configProvider.overrideWithValue(AppConfig(apiUrl: apiUrl, useMock: useMock, demo: demo)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (conCasos)
          contentProvider.overrideWith((ref) {
            final ficheros = contenidoConCasos();
            return ContentRepo(
              bundle: BundleEnMemoria(ficheros),
              listarAssets: () async => ficheros.keys.toList(),
              mostrarBorradores: ref.watch(configProvider).demo && ref.watch(mostrarBorradoresProvider),
            );
          })
        else
          contentProvider.overrideWithValue(
            ContentRepo(bundle: BundleEnMemoria({'${ContentRepo.raiz}/glosario.json': glosarioDePrueba})),
          ),
        relojProvider.overrideWithValue(() => hora),
        ttsProvider.overrideWithValue(tts ?? FakeTts()),
        sttProvider.overrideWithValue(stt ?? FakeStt()),
        sondasDemoProvider.overrideWithValue(sondas ?? SondasFalsas()),
        ...overrides,
      ],
      child: const TuTurnoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(TuTurnoApp))).read(routerProvider);
}

/// El contenedor de providers de la app arrancada.
ProviderContainer contenedor(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(TuTurnoApp)));

/// La ruta que se ve ahora (la de arriba de la pila, también si se abrió con push).
String rutaActual(GoRouter router) => router.state.uri.toString();

/// Navega a [ruta] con push, como hace la app, y espera a que acaben las animaciones.
Future<void> abrir(WidgetTester tester, GoRouter router, String ruta) async {
  unawaited(router.push<void>(ruta));
  await tester.pumpAndSettle();
}

/// Hace visible [finder] (desplazando si hace falta) y lo pulsa.
Future<void> tocar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// La pulsación larga en el pie de Ajustes, que descubre «Para el equipo (demo)». Antes se quitan los avisos de abajo,
/// que taparían el pie.
Future<void> revelarEquipo(WidgetTester tester) async {
  final pie = find.byKey(const Key('pie-ajustes'));
  ScaffoldMessenger.of(tester.element(pie)).clearSnackBars();
  await tester.pumpAndSettle();
  await tester.ensureVisible(pie);
  await tester.pumpAndSettle();
  await tester.longPress(pie);
  await tester.pumpAndSettle();
}

/// Todo lo guardado en shared_preferences, para comparar dos momentos.
Future<Map<String, Object?>> foto() async {
  final prefs = await SharedPreferences.getInstance();
  return {for (final clave in prefs.getKeys()) clave: prefs.get(clave)};
}
