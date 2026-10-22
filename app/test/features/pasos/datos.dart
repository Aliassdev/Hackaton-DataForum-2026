import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/content_repo.dart';
import 'package:tuturno/core/providers.dart';
import 'package:tuturno/features/pasos/pasos.dart';
import 'package:tuturno/tema.dart';

/// Ejemplo de la sección 9.5 de docs/ARQUITECTURA.md, tal cual.
const itinerarioSeccion95 = '''
{
  "rol": "testigo",
  "pasos": [
    {"id": "P1", "nombre": "Te llega una citación",
     "que_pasa": "El juzgado te dice cuándo y dónde tienes que ir.",
     "quien_esta": ["Tu familia o un adulto de confianza"],
     "que_puedes_pedir": ["Que te expliquen lo que no entiendas"],
     "fuentes": ["A-050"]}
  ],
  "validado": false
}
''';

/// Itinerario de víctima con fase en cada paso (el caso de Lucía). Los textos salen de docs/MARCO_LEGAL.md.
/// La última fase va como «Después», con tilde y mayúscula, para comprobar que se normaliza.
const itinerarioConFases = '''
{
  "rol": "victima",
  "pasos": [
    {"id": "P1", "fase": "antes", "nombre": "Te llega una citación",
     "que_pasa": "Un aviso oficial dice qué día, a qué hora y dónde tienes que ir. Si eres menor, llega a tus padres o a quien te represente.",
     "quien_esta": ["Tu familia o quien te represente"],
     "que_puedes_pedir": ["Que te lo expliquen con palabras claras"],
     "fuentes": ["Ley 4/2015, art. 4"]},
    {"id": "P2", "fase": "antes", "nombre": "Te explican tus derechos",
     "que_pasa": "Desde el primer momento, incluso antes de denunciar, te tienen que explicar tus derechos, por ejemplo cómo pedir protección.",
     "quien_esta": ["La policía o el juzgado"],
     "que_puedes_pedir": ["Que te expliquen cómo pedir protección"],
     "fuentes": ["Ley 4/2015, art. 5.1"]},
    {"id": "P3", "fase": "durante", "nombre": "Llegas al juzgado",
     "que_pasa": "El juzgado se organiza para que ni tú ni tu familia os crucéis con la persona investigada.",
     "quien_esta": ["Tu familia o una persona de confianza"],
     "que_puedes_pedir": ["Ir con una persona de confianza que elijas"],
     "fuentes": ["Ley 4/2015, art. 20", "LECrim, art. 433"]},
    {"id": "P4", "fase": "durante", "nombre": "La entrevista en la Sala Gesell",
     "que_pasa": "Te hace las preguntas una persona preparada, a veces de un equipo psicosocial. Se graba para que no tengas que repetirlo.",
     "quien_esta": ["Una psicóloga o un psicólogo del juzgado", "El abogado o la abogada de la persona investigada"],
     "que_puedes_pedir": ["Un descanso", "Que te repitan una pregunta"],
     "fuentes": ["LECrim, art. 449 ter", "LECrim, art. 449 bis"]},
    {"id": "P5", "fase": "despues", "nombre": "El juicio",
     "que_pasa": "Normalmente se pone la grabación de tu entrevista y no hace falta que vayas.",
     "quien_esta": ["El juez o la jueza"],
     "que_puedes_pedir": [],
     "fuentes": ["LECrim, art. 703 bis"]},
    {"id": "P6", "fase": "Después", "nombre": "Te cuentan cómo acaba",
     "que_pasa": "Os tienen que avisar de las decisiones importantes, como la sentencia.",
     "quien_esta": ["Tu familia o quien te represente"],
     "que_puedes_pedir": ["Que te expliquen lo que se ha decidido"],
     "fuentes": ["Ley 4/2015, art. 7.1"]}
  ],
  "validado": true
}
''';

/// Nombres de los pasos de [itinerarioConFases], en orden.
const nombresConFases = [
  'Te llega una citación',
  'Te explican tus derechos',
  'Llegas al juzgado',
  'La entrevista en la Sala Gesell',
  'El juicio',
  'Te cuentan cómo acaba',
];

Itinerario itinerarioDe(String json) => Itinerario.tryParse(jsonDecode(json))!;

/// AssetBundle en memoria que apunta cada lectura. Como rootBundle, un asset que no existe lanza.
class BundleEnMemoria extends AssetBundle {
  BundleEnMemoria(this.ficheros);

  final Map<String, String> ficheros;
  final lecturas = <String>[];

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(utf8.encode(await loadString(key)));

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    lecturas.add(key);
    return ficheros[key] ?? (throw FlutterError('Unable to load asset: "$key".'));
  }
}

/// Ruta del itinerario real de [rol] (assets/content).
String real(String rol) => '${ContentRepo.raiz}/$carpetaItinerarios/$rol.json';

/// Ruta del itinerario de ejemplo de [rol] (assets/mock/content).
String ejemplo(String rol) => '${ContentRepo.raizEjemplos}/$carpetaItinerarios/$rol.json';

/// ContentRepo como el de la app (con los ejemplos de assets/mock), con [ficheros] en un AssetBundle en memoria.
/// La lista de assets (listarAssets) son esos mismos ficheros: nada depende del manifiesto real.
(ContentRepo, BundleEnMemoria) repoCon(Map<String, String> ficheros, {bool mostrarBorradores = false}) {
  final bundle = BundleEnMemoria(ficheros);
  final repo = ContentRepo(
    bundle: bundle,
    usarEjemplos: true,
    mostrarBorradores: mostrarBorradores,
    listarAssets: () async => ficheros.keys.toList(),
  );
  return (repo, bundle);
}

/// ContentRepo con el contenido que lleva la app (los assets reales), como el de contentProvider. Con un AssetBundle
/// nuevo cada vez: rootBundle guarda lo que lee, y un Future que nació en un test no se completa en el siguiente.
ContentRepo repoDeLaApp({bool mostrarBorradores = false}) => ContentRepo(
  bundle: PlatformAssetBundle(),
  usarEjemplos: true,
  mostrarBorradores: mostrarBorradores,
  listarAssets: () async => const [],
);

/// Pinta LineaPasos dentro de una pantalla con scroll, con el tema de la app y el contenido en memoria.
Future<void> montarLinea(
  WidgetTester tester, {
  required ContentRepo repo,
  String rol = 'victima',
  Fase? faseActual,
  Map<String, Object> preferencias = const {},
  double escalaTexto = 1,
  Brightness brillo = Brightness.light,
  bool sinAnimaciones = false,
  Size tamano = const Size(390, 844),
  List<Override> overrides = const [],
  bool esperar = true,
  PersonalizacionLinea? personalizacion,
  bool apuntar = true,
  bool escuchar = true,
}) async {
  tester.view.physicalSize = tamano * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues(preferencias);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        contentProvider.overrideWithValue(repo),
        ...overrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaTuTurno(brillo),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(escalaTexto), disableAnimations: sinAnimaciones),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(Espacio.m),
            child: LineaPasos(
              rol: rol,
              faseActual: faseActual,
              personalizacion: personalizacion,
              apuntar: apuntar,
              escuchar: escuchar,
            ),
          ),
        ),
      ),
    ),
  );
  if (esperar) await tester.pumpAndSettle();
}

/// Respuestas guardadas del formulario de entrada (entradaProvider).
Map<String, Object> entradaGuardada({String? rol, String? fase}) => {
  'entrada': jsonEncode({'rol': rol, 'fase': fase}),
};

/// Silencia los debugPrint de ContentRepo y de los modelos cuando falta o está mal un fichero.
void silenciarAvisos() {
  late DebugPrintCallback original;
  setUp(() {
    original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
  });
  tearDown(() => debugPrint = original);
}
