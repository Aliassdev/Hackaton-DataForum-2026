import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/api/mock_api.dart';
import 'package:tuturno/core/api/tuturno_api.dart';
import 'package:tuturno/core/config.dart';
import 'package:tuturno/core/content_repo.dart';
import 'package:tuturno/core/providers.dart';
import 'package:tuturno/core/voz/stt.dart';
import 'package:tuturno/core/voz/tts.dart';

import '../a1/helpers.dart' show BundleEnMemoria;

/// Voz a texto falsa: el test decide qué se «oye».
class FakeStt implements Stt {
  FakeStt({this.disponible = true, this.registro});

  bool disponible;
  final List<String>? registro;
  int inicializaciones = 0;
  int paradas = 0;
  int cancelaciones = 0;
  bool escuchando = false;

  void Function(String texto)? _onTexto;
  void Function()? _onFin;
  void Function(double nivel)? _onNivel;
  void Function(ProblemaVoz problema)? _onProblema;

  @override
  Future<bool> inicializar() async {
    inicializaciones++;
    registro?.add('stt.inicializar');
    return disponible;
  }

  @override
  Future<void> escuchar({
    required void Function(String texto) onTexto,
    required void Function() onFin,
    void Function(double nivel)? onNivel,
    void Function(ProblemaVoz problema)? onProblema,
  }) async {
    registro?.add('stt.escuchar');
    escuchando = true;
    _onTexto = onTexto;
    _onFin = onFin;
    _onNivel = onNivel;
    _onProblema = onProblema;
  }

  /// Llega una transcripción (parcial o final).
  void oir(String texto) => _onTexto?.call(texto);

  void volumen(double nivel) => _onNivel?.call(nivel);

  /// El sistema deja de escuchar solo (silencio).
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
    paradas++;
    registro?.add('stt.parar');
    if (escuchando) silencio();
  }

  @override
  Future<void> cancelar() async {
    cancelaciones++;
    registro?.add('stt.cancelar');
    escuchando = false;
  }
}

/// Texto a voz falso: guarda lo que se lee. Con [terminarAlInstante] en false, sigue «hablando» hasta [parar].
class FakeTts implements Tts {
  FakeTts({this.registro, this.terminarAlInstante = true});

  final List<String>? registro;
  bool terminarAlInstante;
  final leidos = <String>[];
  final velocidades = <double?>[];
  int paradas = 0;
  final _hablando = ValueNotifier(false);
  Completer<void>? _lectura;

  @override
  ValueListenable<bool> get hablando => _hablando;

  @override
  Future<void> hablar(String texto, {double? velocidad}) {
    registro?.add('tts.hablar');
    leidos.add(texto);
    velocidades.add(velocidad);
    if (terminarAlInstante) return Future.value();
    _lectura?.complete();
    final lectura = _lectura = Completer<void>();
    _hablando.value = true;
    return lectura.future;
  }

  @override
  Future<void> parar() async {
    paradas++;
    registro?.add('tts.parar');
    _hablando.value = false;
    _lectura?.complete();
    _lectura = null;
  }
}

/// API que guarda las peticiones. Puede fallar ([errores]) o esperar ([pausa]).
class ApiGrabadora implements TuTurnoApi {
  ApiGrabadora({TuTurnoApi? base}) : base = base ?? MockTuTurnoApi(latencia: Duration.zero);

  final TuTurnoApi base;
  final peticiones = <AskRequest>[];

  /// Se lanzan en orden en las siguientes preguntas.
  final errores = <Object>[];

  /// Si no es nula, las preguntas esperan a que se complete.
  Completer<void>? pausa;

  @override
  Future<AskResponse> ask(AskRequest request) async {
    peticiones.add(request);
    final espera = pausa;
    if (espera != null) await espera.future;
    if (errores.isNotEmpty) throw errores.removeAt(0);
    return base.ask(request);
  }

  @override
  Future<GradeResponse> grade(GradeRequest request) => base.grade(request);

  @override
  Future<HealthResponse> health() => base.health();
}

const errorApi = ApiException('LLM_NO_DISPONIBLE', 'No he podido responder ahora. Prueba otra vez o pulsa Ayuda.');

/// Glosario de las pruebas de Pregunta: tiene «Responsabilidad penal» pero no «Fiscalía de Menores», para
/// comprobar que solo se subraya lo que se puede abrir.
const glosarioPregunta = '''
[
  {"id": "G-resp", "termino": "Responsabilidad penal",
   "definicion": "Tener que responder ante un juez por haber cometido un delito.",
   "ejemplo": "", "fuente": "A-017", "validado": true},
  {"id": "G-citacion", "termino": "Citación",
   "definicion": "Documento del juzgado que te dice cuándo y dónde tienes que ir.",
   "ejemplo": "", "fuente": "A-060", "validado": true}
]
''';

/// El perfil de la hoja que se guarda en las pruebas si no se pide otro.
const perfilDePrueba = <String, Object?>{'edad': 13, 'procedimiento': 'penal', 'rol': 'victima', 'fase': 'durante'};

/// El JSON de las conversaciones de ejemplo, leído del disco (los tests se ejecutan desde app/).
String ejemplosPreguntaJson() => File('assets/mock/content/pregunta_ejemplos.json').readAsStringSync();

/// Overrides comunes: configuración de mock, preferencias en memoria (con el perfil [entrada], o sin perfil si es
/// null), glosario en memoria, API, voz y voz a texto falsas.
Future<List<Override>> overridesDePrueba({
  required ApiGrabadora api,
  required FakeStt stt,
  required FakeTts tts,
  bool vozActivada = true,
  String glosario = glosarioPregunta,
  Map<String, Object?>? entrada = perfilDePrueba,
}) async {
  SharedPreferences.setMockInitialValues({
    'bienvenida_vista': true,
    'ajustes.voz_activada': vozActivada,
    if (entrada != null) 'entrada': jsonEncode(entrada),
  });
  final prefs = await SharedPreferences.getInstance();
  return [
    configProvider.overrideWithValue(const AppConfig(apiUrl: '', useMock: true, demo: false)),
    sharedPreferencesProvider.overrideWithValue(prefs),
    contentProvider.overrideWithValue(
      ContentRepo(bundle: BundleEnMemoria({'${ContentRepo.raiz}/glosario.json': glosario})),
    ),
    apiProvider.overrideWithValue(api),
    sttProvider.overrideWithValue(stt),
    ttsProvider.overrideWithValue(tts),
  ];
}
