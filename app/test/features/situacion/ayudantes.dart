import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/app.dart';
import 'package:tuturno/core/config.dart';
import 'package:tuturno/core/content_repo.dart';
import 'package:tuturno/core/progreso.dart' show relojProvider;
import 'package:tuturno/core/providers.dart';
import 'package:tuturno/core/voz/tts.dart';
import 'package:tuturno/widgets/justicia/expediente_caratula.dart';

// Ayudantes de las pruebas de «Mi situación»: el contenido de verdad leído del disco (también el nuevo de
// assets/mock/content/situacion/, aunque aún no esté en pubspec.yaml), los perfiles de los tres casos oficiales
// (Lucía, Sergio y Sara), una voz falsa y la app arrancada como en main().

/// Un AssetBundle que lee los ficheros del disco (desde la carpeta app/, donde corren las pruebas). Un fichero que no
/// existe lanza, como rootBundle.
class BundleDeDisco extends AssetBundle {
  BundleDeDisco({this.extra = const {}});

  /// Ficheros en memoria que mandan sobre los del disco.
  final Map<String, String> extra;

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(utf8.encode(await loadString(key)));

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final enMemoria = extra[key];
    if (enMemoria != null) return enMemoria;
    final fichero = File(key);
    if (!fichero.existsSync()) throw FlutterError('Unable to load asset: "$key".');
    return fichero.readAsStringSync();
  }
}

/// El contenido de la app (assets/mock/content, como cuando content/ está vacío), leído del disco.
ContentRepo repoDeDisco({Map<String, String> extra = const {}, bool mostrarBorradores = false}) => ContentRepo(
  bundle: BundleDeDisco(extra: extra),
  usarEjemplos: true,
  mostrarBorradores: mostrarBorradores,
  listarAssets: () async => const [],
);

/// Un contenido sin nada de Mi situación (ni itinerarios ni glosario): la pantalla tiene que salir igual.
ContentRepo repoVacio() => ContentRepo(bundle: BundleDeDisco(), listarAssets: () async => const []);

/// Una voz falsa: apunta lo que lee y cuántas veces se para. La lectura no termina sola ([terminar]).
class TtsFalso implements Tts {
  final leidos = <String>[];
  int paradas = 0;
  final _hablando = ValueNotifier(false);

  @override
  ValueListenable<bool> get hablando => _hablando;

  @override
  Future<void> hablar(String texto, {double? velocidad}) async {
    leidos.add(texto);
    _hablando.value = true;
  }

  @override
  Future<void> parar() async {
    paradas++;
    _hablando.value = false;
  }

  /// La lectura acaba sola.
  void terminar() => _hablando.value = false;
}

/// Jueves 22 de octubre de 2026, a las 10:00: el día de la demo.
final hoyDemo = DateTime(2026, 10, 22, 10);

Map<String, Object> _perfil(Map<String, Object?> entrada, Map<String, Object?> ticket) => {
  'entrada': jsonEncode(entrada),
  'mi_situacion': jsonEncode(ticket),
};

/// Lucía, 11 años: víctima en un proceso penal, en el momento «durante». Irá con una persona de confianza (su tía),
/// le preocupa ver a la persona y no entender lo que dicen, y lo prefiere con ejemplos. Su cita es pasado mañana.
Map<String, Object> perfilLucia() => _perfil(
  {'edad': 11, 'procedimiento': 'penal', 'rol': 'victima', 'fase': 'durante'},
  {
    'con_quien': ['confianza'],
    'preocupaciones': ['ver_persona', 'no_entender'],
    'estilo': 'ejemplos',
    'fecha': '2026-10-24',
    'hora': '10:00',
  },
);

/// Sergio, 13 años: víctima de acoso escolar en un proceso penal (Fiscalía de Menores), «antes». Irá con su familia,
/// le preocupan el instituto y qué le van a preguntar, y lo prefiere paso a paso. Su cita es hoy: modo día.
Map<String, Object> perfilSergio() => _perfil(
  {'edad': 13, 'procedimiento': 'penal', 'rol': 'victima', 'fase': 'antes'},
  {
    'con_quien': ['familia'],
    'preocupaciones': ['colegio', 'preguntas'],
    'estilo': 'paso_a_paso',
    'fecha': '2026-10-22',
    'hora': '12:30',
    'llevar_hecho': ['citacion'],
  },
);

/// Sara, 15 años: víctima de la difusión de imágenes íntimas, al principio del caso oficial («antes»: quitar las
/// imágenes, el 017 y la denuncia). Irá con su familia y su abogada, le preocupan las redes y el instituto, y lo
/// prefiere corto.
Map<String, Object> perfilSara() => _perfil(
  {'edad': 15, 'procedimiento': 'penal', 'rol': 'victima', 'fase': 'antes'},
  {
    'con_quien': ['familia', 'abogado'],
    'preocupaciones': ['redes', 'colegio'],
    'estilo': 'corto',
  },
);

/// Arranca TuTurnoApp como en main(): mock, [preferencias] guardadas, el contenido de verdad, el reloj en [ahora] y
/// la voz falsa [tts]. Devuelve el router. La carpeta de Mi situación se olvida de que ya se abrió.
Future<GoRouter> arrancarSituacion(
  WidgetTester tester, {
  Map<String, Object> preferencias = const {},
  ContentRepo? repo,
  DateTime? ahora,
  Tts? tts,
  Size tamano = const Size(390, 844),
  List<Override> overrides = const [],
}) async {
  ExpedienteCaratula.olvidarAperturas();
  tester.view.physicalSize = tamano * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({'bienvenida_vista': true, ...preferencias});
  final prefs = await SharedPreferences.getInstance();
  final reloj = ahora ?? hoyDemo;
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        configProvider.overrideWithValue(const AppConfig(apiUrl: '', useMock: true, demo: false)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        contentProvider.overrideWithValue(repo ?? repoDeDisco()),
        relojProvider.overrideWithValue(() => reloj),
        ttsProvider.overrideWithValue(tts ?? TtsFalso()),
        ...overrides,
      ],
      child: const TuTurnoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return contenedor(tester).read(routerProvider);
}

ProviderContainer contenedor(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(TuTurnoApp)));

/// Navega a [ruta] con push (como la app) y espera a que acabe todo (la carpeta incluida).
Future<void> abrir(WidgetTester tester, GoRouter router, String ruta) async {
  router.push(ruta);
  await tester.pumpAndSettle();
}

/// Hace visible [finder] (desplazando si hace falta) y lo pulsa.
Future<void> tocar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Guarda una captura de la pantalla en [carpeta]/[nombre].png.
Future<void> capturar(WidgetTester tester, String carpeta, String nombre) async {
  await tester.pumpAndSettle();
  final capa = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final imagen = await capa.toImage(Offset.zero & tester.view.physicalSize);
    final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
    File('$carpeta/$nombre.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}
