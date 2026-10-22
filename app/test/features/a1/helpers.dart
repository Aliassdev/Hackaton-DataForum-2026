import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/app.dart';
import 'package:tuturno/core/config.dart';
import 'package:tuturno/core/content_repo.dart';
import 'package:tuturno/core/providers.dart';

/// AssetBundle en memoria: los tests no dependen de lo que haya en assets/.
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

/// Glosario de prueba: dos con fuente real, uno de ejemplo (MOCK) y un borrador que no debe verse.
const glosarioDePrueba = '''
[
  {"id": "G-citacion", "termino": "Citación",
   "definicion": "Documento del juzgado que te dice cuándo y dónde tienes que ir.",
   "ejemplo": "A Lucía le llegó una citación para declarar como testigo.",
   "fuente": "A-060", "validado": true},
  {"id": "G-fiscalia-menores", "termino": "Fiscalía de Menores",
   "definicion": "Parte del Ministerio Fiscal que investiga los delitos de chicos y chicas de 14 a 17 años.",
   "ejemplo": "La Fiscalía de Menores vela por los derechos de Sergio.",
   "fuente": "MOCK", "validado": true},
  {"id": "G-abogado", "termino": "Abogado o abogada",
   "definicion": "Persona que conoce las leyes y te defiende.",
   "ejemplo": "", "fuente": "A-010", "validado": true},
  {"id": "G-borrador", "termino": "Borrador oculto",
   "definicion": "Esto no se debe ver.", "ejemplo": "", "fuente": "A-999", "validado": false}
]
''';

/// Tamaño de un móvil normal (en píxeles lógicos).
const movil = Size(390, 844);

/// Arranca TuTurnoApp como en main(), con mock, preferencias simuladas y el glosario en memoria.
/// Devuelve el router para navegar directamente a una ruta.
Future<GoRouter> arrancarApp(
  WidgetTester tester, {
  bool bienvenidaVista = true,
  Map<String, Object> preferencias = const {},
  String glosario = glosarioDePrueba,
  bool useMock = true,
  Size tamano = movil,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = tamano * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({if (bienvenidaVista) 'bienvenida_vista': true, ...preferencias});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        configProvider.overrideWithValue(AppConfig(apiUrl: '', useMock: useMock, demo: false)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        contentProvider.overrideWithValue(
          ContentRepo(bundle: BundleEnMemoria({'${ContentRepo.raiz}/glosario.json': glosario})),
        ),
        ...overrides,
      ],
      child: const TuTurnoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(TuTurnoApp))).read(routerProvider);
}

/// Navega a [ruta] (con push, como hace la app) y espera a que acaben las animaciones.
Future<void> irA(WidgetTester tester, GoRouter router, String ruta) async {
  router.push(ruta);
  await tester.pumpAndSettle();
}

/// Para pantallas de otros módulos que pueden tener animaciones continuas: avanza sin esperar a que paren.
Future<void> esperarTransicion(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
}

/// Hace visible [finder] (desplazando si hace falta) y lo pulsa.
Future<void> pulsar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
