import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/api/mock_api.dart';
import 'package:tuturno/core/api/tuturno_api.dart';
import 'package:tuturno/core/config.dart';
import 'package:tuturno/core/content_repo.dart';
import 'package:tuturno/core/progreso.dart';
import 'package:tuturno/core/providers.dart';
import 'package:tuturno/core/voz/stt.dart';
import 'package:tuturno/core/voz/tts.dart';
import 'package:tuturno/features/aprende/aprende_screen.dart';
import 'package:tuturno/features/aprende/modelos.dart';
import 'package:tuturno/features/aprende/widgets/comunes.dart';
import 'package:tuturno/tema.dart';

/// AssetBundle en memoria: los tests no dependen de lo que haya empaquetado.
class BundleEnMemoria extends CachingAssetBundle {
  BundleEnMemoria(this.ficheros);

  final Map<String, String> ficheros;

  @override
  Future<ByteData> load(String key) async {
    final texto = ficheros[key];
    if (texto == null) throw FlutterError('No existe $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(texto)));
  }
}

/// Repositorio con los ficheros indicados (rutas completas, p. ej. assets/content/lecciones/u.json).
ContentRepo repoCon(Map<String, String> ficheros, {bool mostrarBorradores = false}) => ContentRepo(
  bundle: BundleEnMemoria(ficheros),
  usarEjemplos: true,
  mostrarBorradores: mostrarBorradores,
  listarAssets: () async => ficheros.keys.toList(),
);

/// Los ficheros de ejemplo de Aprende que hay en app/assets/mock/content (los que se ven en la demo).
Map<String, String> ficherosDeEjemplo() {
  final ficheros = <String, String>{};
  for (final carpeta in ['lecciones', 'ejercicios']) {
    final dir = Directory('${ContentRepo.raizEjemplos}/$carpeta');
    for (final f in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
      ficheros['${ContentRepo.raizEjemplos}/$carpeta/${f.uri.pathSegments.last}'] = f.readAsStringSync();
    }
  }
  return ficheros;
}

/// Repositorio con el contenido de ejemplo puesto como si fuera el real (así no avisa de que falta).
/// Con [glosario], también el glosario de ejemplo (sus términos salen subrayados en las explicaciones).
ContentRepo repoDeEjemplo({bool glosario = false}) => repoCon({
  for (final MapEntry(:key, :value) in ficherosDeEjemplo().entries)
    key.replaceFirst(ContentRepo.raizEjemplos, ContentRepo.raiz): value,
  if (glosario)
    '${ContentRepo.raiz}/glosario.json': File('${ContentRepo.raizEjemplos}/glosario.json').readAsStringSync(),
});

/// Todos los ejercicios de ejemplo por id.
Map<String, Ejercicio> ejerciciosDeEjemplo() {
  final todos = <String, Ejercicio>{};
  for (final MapEntry(:key, :value) in ficherosDeEjemplo().entries) {
    if (!key.contains('/ejercicios/')) continue;
    for (final e in jsonDecode(value) as List) {
      final ejercicio = Ejercicio.fromJson(e)!;
      todos[ejercicio.id] = ejercicio;
    }
  }
  return todos;
}

/// Voz a texto falsa: el test decide qué se «oye».
class FakeStt implements Stt {
  FakeStt({this.disponible = true});

  bool disponible;
  final registro = <String>[];
  bool escuchando = false;
  void Function(String texto)? _onTexto;
  void Function()? _onFin;
  void Function(double nivel)? _onNivel;
  void Function(ProblemaVoz problema)? _onProblema;

  @override
  Future<bool> inicializar() async {
    registro.add('inicializar');
    return disponible;
  }

  @override
  Future<void> escuchar({
    required void Function(String texto) onTexto,
    required void Function() onFin,
    void Function(double nivel)? onNivel,
    void Function(ProblemaVoz problema)? onProblema,
  }) async {
    registro.add('escuchar');
    escuchando = true;
    _onTexto = onTexto;
    _onFin = onFin;
    _onNivel = onNivel;
    _onProblema = onProblema;
  }

  void oir(String texto) => _onTexto?.call(texto);

  /// Volumen de la voz, de 0 a 1.
  void nivel(double valor) => _onNivel?.call(valor);

  void silencio() {
    escuchando = false;
    _onFin?.call();
  }

  void fallar(ProblemaVoz problema) {
    escuchando = false;
    _onProblema?.call(problema);
    _onFin?.call();
  }

  @override
  Future<void> parar() async {
    registro.add('parar');
    if (escuchando) silencio();
  }

  @override
  Future<void> cancelar() async {
    registro.add('cancelar');
    escuchando = false;
  }
}

/// Texto a voz falso: guarda lo que se lee. Como el de verdad, está «hablando» desde que empieza a leer hasta que
/// termina ([terminar]) o se para.
class FakeTts implements Tts {
  final leidos = <String>[];
  final registro = <String>[];
  final _hablando = ValueNotifier(false);

  @override
  ValueListenable<bool> get hablando => _hablando;

  @override
  Future<void> hablar(String texto, {double? velocidad}) async {
    registro.add('hablar');
    leidos.add(texto);
    _hablando.value = true;
  }

  /// La lectura acaba sola.
  void terminar() => _hablando.value = false;

  @override
  Future<void> parar() async {
    registro.add('parar');
    _hablando.value = false;
  }
}

/// API de prueba: «Dilo» con MockTuTurnoApi sin espera. Puede fallar o esperar a que el test la suelte.
class ApiDePrueba implements TuTurnoApi {
  ApiDePrueba({this.error});

  final base = MockTuTurnoApi(latencia: Duration.zero);
  final notas = <GradeRequest>[];

  /// Si no es null, grade() lo lanza.
  Object? error;

  /// Si no es null, grade() espera a que se complete.
  Completer<void>? pausa;

  @override
  Future<AskResponse> ask(AskRequest request) => base.ask(request);

  @override
  Future<GradeResponse> grade(GradeRequest request) async {
    notas.add(request);
    final espera = pausa;
    if (espera != null) await espera.future;
    final fallo = error;
    if (fallo != null) throw fallo;
    return base.grade(request);
  }

  @override
  Future<HealthResponse> health() => base.health();
}

/// Lo que devuelve [montar].
class Montaje {
  Montaje(this.router, this.contenedor, this.api, this.stt, this.tts);

  final GoRouter router;
  final ProviderContainer contenedor;
  final ApiDePrueba api;
  final FakeStt stt;
  final FakeTts tts;

  Progreso get progreso => contenedor.read(progresoProvider);
}

/// Día fijo de los tests: miércoles 21/10/2026 a las 18:00.
final hoy = DateTime(2026, 10, 21, 18);

/// Tamaño de un Android normal (Pixel 7).
const movil = Size(412, 915);

/// Progreso guardado como lo deja ProgresoNotifier.
Map<String, Object> progresoGuardado({
  int xp = 0,
  int racha = 0,
  DateTime? ultimoDia,
  List<String> lecciones = const [],
  Map<String, double> dominio = const {},
  Map<String, DateTime> ultimaPractica = const {},
}) => {
  'progreso': jsonEncode(
    Progreso(
      xp: xp,
      racha: racha,
      ultimoDiaConLeccion: ultimoDia,
      leccionesCompletadas: {...lecciones},
      dominio: dominio,
      ultimaPractica: ultimaPractica,
    ).toJson(),
  ),
};

/// Monta Aprende con su router (Pregunta, Ayuda y Glosario son pantallas de prueba), el contenido de ejemplo
/// en memoria, el reloj fijo, la API de prueba y la voz falsa.
Future<Montaje> montar(
  WidgetTester tester, {
  String ruta = '/aprende',
  Map<String, Object> preferencias = const {},
  ContentRepo? repo,
  ApiDePrueba? api,
  FakeStt? stt,
  FakeTts? tts,
  DateTime? ahora,
  bool demo = false,
  double escalaTexto = 1,
  Size tamano = movil,
  Brightness brillo = Brightness.light,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = tamano * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({'bienvenida_vista': true, ...preferencias});
  final prefs = await SharedPreferences.getInstance();
  final laApi = api ?? ApiDePrueba();
  final elStt = stt ?? FakeStt();
  final elTts = tts ?? FakeTts();
  final router = GoRouter(
    initialLocation: ruta,
    routes: [
      GoRoute(
        path: '/aprende',
        builder: (context, state) => const AprendeScreen(),
        routes: [
          GoRoute(
            path: 'leccion/:leccionId',
            builder: (context, state) => LeccionScreen(leccionId: state.pathParameters['leccionId']!),
          ),
        ],
      ),
      GoRoute(
        path: '/pregunta',
        builder: (context, state) => const Scaffold(body: Text('pantalla de pregunta')),
      ),
      GoRoute(
        path: '/ayuda',
        builder: (context, state) => const Scaffold(body: Text('pantalla de ayuda')),
      ),
      GoRoute(
        path: '/glosario',
        builder: (context, state) => const Scaffold(body: Text('pantalla del glosario')),
      ),
    ],
  );
  addTearDown(router.dispose);
  final contenedor = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      configProvider.overrideWithValue(AppConfig(apiUrl: '', useMock: true, demo: demo)),
      sharedPreferencesProvider.overrideWithValue(prefs),
      contentProvider.overrideWithValue(repo ?? repoDeEjemplo()),
      apiProvider.overrideWithValue(laApi),
      sttProvider.overrideWithValue(elStt),
      ttsProvider.overrideWithValue(elTts),
      relojProvider.overrideWithValue(() => ahora ?? hoy),
      ...overrides,
    ],
  );
  addTearDown(contenedor.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: contenedor,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: temaTuTurno(Brightness.light),
        darkTheme: temaTuTurno(Brightness.dark),
        themeMode: brillo == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        locale: const Locale('es', 'ES'),
        supportedLocales: const [Locale('es', 'ES')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(escalaTexto)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return Montaje(router, contenedor, laApi, elStt, elTts);
}

/// Hace visible [finder] (desplazando si hace falta), lo pulsa y espera a que acaben las animaciones.
Future<void> pulsar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

final botonComprobar = find.byKey(const ValueKey('boton-comprobar'));
final botonContinuar = find.byKey(const ValueKey('boton-continuar'));
final campoDilo = find.byKey(const ValueKey('campo-dilo'));

/// Texto de «Dilo» que se envía en los tests.
const respuestaDilo = 'Que el juez tiene que escucharte si tienes 12 años';

/// Responde [ejercicio] en pantalla, bien o mal (sin pulsar «Comprobar»).
Future<void> responder(WidgetTester tester, Ejercicio ejercicio, {required bool bien}) async {
  switch (ejercicio) {
    case EjercicioEleccion(:final opciones, :final correcta):
      final elegida = bien ? correcta : (correcta + 1) % opciones.length;
      await pulsar(tester, find.byKey(ValueKey('opcion-$elegida')));
    case EjercicioVf(:final correcta):
      final valor = bien ? correcta : !correcta;
      await pulsar(tester, find.byKey(ValueKey(valor ? 'vf-verdadero' : 'vf-falso')));
    case EjercicioOrdenar(:final id, :final pasos):
      final orden = barajar(pasos.length, semillaDe(id), evitarIdentidad: true);
      if (bien) {
        // Sube cada paso hasta su sitio con las flechas (la alternativa accesible al arrastre).
        for (var objetivo = 0; objetivo < pasos.length; objetivo++) {
          var actual = orden.indexOf(objetivo);
          while (actual > objetivo) {
            await pulsar(tester, find.byTooltip('Subir «${pasos[objetivo]}»'));
            orden.insert(actual - 1, orden.removeAt(actual));
            actual--;
          }
        }
      } else {
        // Un solo movimiento (subir un paso) que no deje los pasos en orden.
        var desde = 1;
        while (true) {
          final prueba = [...orden];
          prueba.insert(desde - 1, prueba.removeAt(desde));
          if (!listEquals(prueba, List.generate(pasos.length, (i) => i))) break;
          desde++;
        }
        await pulsar(tester, find.byTooltip('Subir «${pasos[orden[desde]]}»'));
      }
    case EjercicioEmparejar(:final pares):
      for (var i = 0; i < pares.length; i++) {
        final pareja = bien ? i : (i + 1) % pares.length;
        await pulsar(tester, find.byKey(ValueKey('izquierda-$i')));
        await pulsar(tester, find.byKey(ValueKey('derecha-$pareja')));
      }
    case EjercicioDilo():
      await tester.ensureVisible(campoDilo);
      await tester.enterText(campoDilo, bien ? respuestaDilo : 'No lo sé muy bien');
      await tester.pumpAndSettle();
  }
}

/// Responde, comprueba y deja el panel de corrección a la vista.
Future<void> responderYComprobar(WidgetTester tester, Ejercicio ejercicio, {required bool bien}) async {
  await responder(tester, ejercicio, bien: bien);
  await pulsar(tester, botonComprobar);
}
