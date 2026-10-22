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
import 'package:tuturno/core/config.dart';
import 'package:tuturno/core/content_repo.dart';
import 'package:tuturno/core/providers.dart';
import 'package:tuturno/core/voz/tts.dart';
import 'package:tuturno/features/juego/juego_screen.dart';
import 'package:tuturno/tema.dart';

// Piezas comunes de las pruebas de «Vive el caso».

/// AssetBundle en memoria: las pruebas no dependen de lo que haya en assets/.
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

/// Texto a voz falso: guarda lo que se lee. Con [terminarAlInstante] en false, sigue «hablando» hasta [parar].
class FakeTts implements Tts {
  FakeTts({this.terminarAlInstante = true});

  bool terminarAlInstante;
  final leidos = <String>[];
  int paradas = 0;
  final _hablando = ValueNotifier(false);
  Completer<void>? _lectura;

  @override
  ValueListenable<bool> get hablando => _hablando;

  @override
  Future<void> hablar(String texto, {double? velocidad}) {
    leidos.add(texto);
    if (terminarAlInstante) return Future.value();
    _lectura?.complete();
    final lectura = _lectura = Completer<void>();
    _hablando.value = true;
    return lectura.future;
  }

  @override
  Future<void> parar() async {
    paradas++;
    _hablando.value = false;
    _lectura?.complete();
    _lectura = null;
  }
}

/// El ejemplo de la sección 9.4 de docs/ARQUITECTURA.md, tal cual.
const ejemploDoc = '''
{
  "id": "caso-sala-gesell",
  "titulo": "Lucía y la sala de la entrevista",
  "rol": "victima",
  "basado_en": ["ids de sentencias del corpus usadas como estructura"],
  "escenas": [
    {
      "id": "S1",
      "lugar": "colegio",
      "personajes": ["Lucía", "Su tutora"],
      "narracion": "Lucía tiene 11 años. Su tutora le cuenta que dentro de unos días unas personas del juzgado quieren hablar con ella, una sola vez, en una sala preparada para niños y niñas.",
      "decision": {
        "pregunta": "¿Por qué quieren hablar con Lucía?",
        "opciones": [
          {"texto": "Para escucharla y poder protegerla", "correcta": true,
           "siguiente": "S2", "feedback": "Correcto. Que te escuchen es un derecho: lo que piensas importa.",
           "fuente": "A-003", "carta": "R-ser-oida"},
          {"texto": "Porque ha hecho algo malo", "correcta": false, "siguiente": "S2",
           "feedback": "No. Lucía no ha hecho nada malo. Quieren escucharla para poder ayudarla.", "fuente": "A-003"}
        ]
      }
    },
    {
      "id": "S2",
      "lugar": "sala_gesell",
      "personajes": ["Lucía", "Psicóloga del juzgado"],
      "narracion": "Una psicóloga le enseña la sala y le explica quién va a ver la entrevista y por qué así no tendrá que contarlo más veces.",
      "siguiente": "S3"
    }
  ],
  "cartas": [
    {"id": "R-ser-oida", "titulo": "Tienes derecho a que te escuchen", "texto": "En lo que te afecta, tu opinión cuenta.", "fuente": "A-003"}
  ],
  "validado": false
}
''';

/// Caso corto para probar el reproductor: decisión, escena lineal, decisión con dos respuestas correctas (cada
/// una con su carta) y final.
const casoPrueba = '''
{
  "id": "caso-prueba",
  "titulo": "Nora y la prueba",
  "rol": "testigo",
  "basado_en": [],
  "escenas": [
    {"id": "E1", "lugar": "colegio", "personajes": ["Nora", "Su tutor"],
     "narracion": "Nora tiene 12 años. Hoy le explican cómo será su día en el juzgado.",
     "decision": {"pregunta": "¿Puede Nora pedir que le repitan una pregunta?", "opciones": [
       {"texto": "Sí, si no la entiende", "correcta": true, "siguiente": "E2",
        "feedback": "Tienes derecho a entender lo que te preguntan.", "fuente": "Ley 4/2015, art. 4", "carta": "R-entender"},
       {"texto": "No, nunca", "correcta": false, "siguiente": "E2",
        "feedback": "Sí que puede: tiene derecho a entender.", "fuente": "Ley 4/2015, art. 4"}
     ]}},
    {"id": "E2", "lugar": "juzgado", "personajes": ["Nora"],
     "narracion": "Nora llega al juzgado con calma.", "siguiente": "E3"},
    {"id": "E3", "lugar": "sala_gesell", "personajes": ["Nora", "La psicóloga"],
     "narracion": "La psicóloga le enseña la sala.",
     "decision": {"pregunta": "¿Qué puede pedir Nora?", "opciones": [
       {"texto": "Ir con alguien de confianza", "correcta": true, "siguiente": "E4",
        "feedback": "Puede ir con una persona de confianza.", "fuente": "LECrim, art. 433", "carta": "R-acompanada"},
       {"texto": "Que le repitan lo que no entienda", "correcta": true, "siguiente": "E4",
        "feedback": "Puede pedir que se lo expliquen.", "fuente": "Ley 4/2015, art. 4", "carta": "R-explicar"},
       {"texto": "Que le prometan el final", "correcta": false, "siguiente": "E4",
        "feedback": "Eso nadie lo puede prometer.", "fuente": "Ley 4/2015, art. 4"}
     ]}},
    {"id": "E4", "lugar": "despues", "personajes": ["Nora"],
     "narracion": "Nora sale tranquila. Ya sabe cómo funciona."}
  ],
  "cartas": [
    {"id": "R-entender", "titulo": "Tienes derecho a entender", "texto": "Te tienen que hablar claro.", "fuente": "Ley 4/2015, art. 4"},
    {"id": "R-acompanada", "titulo": "Puedes ir con alguien de confianza", "texto": "Una persona que tú elijas.", "fuente": "LECrim, art. 433"},
    {"id": "R-explicar", "titulo": "Te lo tienen que explicar", "texto": "Con palabras claras.", "fuente": "Ley 4/2015, art. 4"}
  ],
  "validado": true
}
''';

/// Un caso sin validar: no se debe ver.
const casoBorrador = '''
{"id": "caso-borrador", "titulo": "Borrador oculto", "rol": "victima", "basado_en": [],
 "escenas": [{"id": "S1", "lugar": "casa", "personajes": ["Leo"], "narracion": "Leo tiene 14 años."}],
 "cartas": [{"id": "R-oculta", "titulo": "Carta oculta", "texto": "No se ve.", "fuente": "LO 1/1996, art. 9"}],
 "validado": false}
''';

/// Otro caso validado, con un id que no es oficial: va detrás del oficial aunque su título vaya antes.
const casoExtra = '''
{"id": "caso-extra", "titulo": "Alba y el juzgado", "rol": "victima", "basado_en": [],
 "escenas": [{"id": "S1", "lugar": "juzgado", "personajes": ["Alba"],
   "narracion": "Alba tiene 15 años. Va a declarar por videoconferencia."}],
 "cartas": [], "validado": true}
''';

/// El caso oficial de ejemplo de la app (el que se ve en la demo), leído del disco.
String casoOficialDeEjemplo() => File('assets/mock/content/juego/caso-sala-gesell.json').readAsStringSync();

const glosarioPrueba = '''
[{"id": "G-gesell", "termino": "Sala Gesell", "definicion": "Sala preparada para escuchar a niños y niñas.",
  "ejemplo": "", "fuente": "LECrim, art. 449 ter", "validado": true}]
''';

/// Contenido en memoria: los ficheros de `assets/content/juego/` que se pasen (nombre → JSON) y el glosario.
ContentRepo repoDePrueba(Map<String, String> casos, {String glosario = glosarioPrueba}) {
  final ficheros = {
    for (final e in casos.entries) '${ContentRepo.raiz}/juego/${e.key}': e.value,
    '${ContentRepo.raiz}/glosario.json': glosario,
  };
  return ContentRepo(bundle: BundleEnMemoria(ficheros), listarAssets: () async => ficheros.keys.toList());
}

/// Overrides comunes: configuración sin backend, preferencias en memoria, contenido y voz falsa.
Future<List<Override>> overridesJuego({
  Map<String, String> casos = const {'caso-prueba.json': casoPrueba},
  ContentRepo? repo,
  FakeTts? tts,
  bool vozActivada = true,
  Map<String, Object> preferencias = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'bienvenida_vista': true,
    'ajustes.voz_activada': vozActivada,
    ...preferencias,
  });
  final prefs = await SharedPreferences.getInstance();
  return [
    configProvider.overrideWithValue(const AppConfig(apiUrl: '', useMock: true, demo: false)),
    sharedPreferencesProvider.overrideWithValue(prefs),
    contentProvider.overrideWithValue(repo ?? repoDePrueba(casos)),
    ttsProvider.overrideWithValue(tts ?? FakeTts()),
  ];
}

/// Progreso guardado con estas cartas y casos terminados (clave «progreso» de shared_preferences).
Map<String, Object> progresoGuardado({List<String> cartas = const [], List<String> casos = const [], int xp = 0}) => {
  'progreso': jsonEncode({'xp': xp, 'cartas': cartas, 'casos': casos}),
};

/// Abre la app mínima del juego en [ruta], con un router como el de app.dart (Aprende, Pregunta, Glosario y Ayuda
/// son pantallas de prueba). Devuelve el router.
Future<GoRouter> abrirJuego(
  WidgetTester tester, {
  String ruta = '/juego',
  required List<Override> overrides,
  double escalaTexto = 1,
  bool oscuro = false,
  bool lectorDePantalla = false,
  bool reducirAnimaciones = false,
  Size tamano = const Size(412, 915),
}) async {
  tester.view.physicalSize = tamano * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  final router = GoRouter(
    initialLocation: ruta,
    routes: [
      GoRoute(
        path: '/juego',
        builder: (context, state) => const JuegoScreen(),
        routes: [
          GoRoute(
            path: ':casoId',
            builder: (context, state) => CasoScreen(casoId: state.pathParameters['casoId']!),
          ),
        ],
      ),
      GoRoute(
        path: '/aprende',
        builder: (context, state) => const Scaffold(body: Text('pantalla de aprende')),
      ),
      GoRoute(
        path: '/pregunta',
        builder: (context, state) => const Scaffold(body: Text('pantalla de pregunta')),
      ),
      GoRoute(
        path: '/glosario',
        builder: (context, state) => Scaffold(body: Text('glosario:${state.uri.queryParameters['q']}')),
      ),
      GoRoute(
        path: '/ayuda',
        builder: (context, state) => const Scaffold(body: Text('pantalla de ayuda')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: overrides,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: temaTuTurno(Brightness.light),
        darkTheme: temaTuTurno(Brightness.dark),
        themeMode: oscuro ? ThemeMode.dark : ThemeMode.light,
        locale: const Locale('es', 'ES'),
        supportedLocales: const [Locale('es', 'ES')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(escalaTexto),
            accessibleNavigation: lectorDePantalla,
            disableAnimations: reducirAnimaciones,
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// Contenedor de Riverpod de la app que hay en pantalla.
ProviderContainer contenedor(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp).first));

/// Hace visible [finder] (desplazando si hace falta) y lo pulsa.
Future<void> pulsar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Silencia los avisos de ContentRepo (ficheros que faltan) durante la prueba. Solo en test(), no en testWidgets():
/// ahí debugPrint tiene que estar restaurado antes de que acabe el cuerpo de la prueba.
void silenciarAvisos() {
  final original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {};
  addTearDown(() => debugPrint = original);
}
