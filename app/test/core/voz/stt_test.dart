import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:tuturno/core/voz/stt.dart';

/// speech_to_text sin plataforma: el test hace de sistema operativo.
class _FakeSpeech extends SpeechToText {
  _FakeSpeech() : super.withMethodChannel();

  bool resultadoInicializar = true;
  int inicializaciones = 0;
  int paradas = 0;
  int cancelaciones = 0;
  bool _disponible = false;
  List<SpeechConfigOption>? opciones;
  SpeechErrorListener? alError;
  SpeechStatusListener? alEstado;
  SpeechResultListener? alResultado;
  SpeechSoundLevelChange? alNivel;
  SpeechListenOptions? opcionesEscucha;

  @override
  bool get isAvailable => _disponible;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async {
    inicializaciones++;
    alError = onError;
    alEstado = onStatus;
    opciones = options;
    _disponible = resultadoInicializar;
    return resultadoInicializar;
  }

  @override
  Future listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    cancelOnError = false,
    partialResults = true,
    onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {
    alResultado = onResult;
    alNivel = onSoundLevelChange;
    opcionesEscucha = listenOptions;
  }

  @override
  Future<void> stop() async => paradas++;

  @override
  Future<void> cancel() async => cancelaciones++;

  void resultado(String texto, {bool esFinal = false}) => alResultado?.call(
    SpeechRecognitionResult.init([
      SpeechRecognitionWords(texto, null, 0.9),
    ], esFinal ? ResultType.finalResult : ResultType.partial),
  );
}

class _Sesion {
  final textos = <String>[];
  final niveles = <double>[];
  final problemas = <ProblemaVoz>[];
  var fines = 0;

  Future<void> escuchar(Stt stt) =>
      stt.escuchar(onTexto: textos.add, onNivel: niveles.add, onFin: () => fines++, onProblema: problemas.add);
}

void main() {
  late _FakeSpeech speech;
  late SttReal stt;

  setUp(() {
    speech = _FakeSpeech();
    stt = SttReal(speech: speech);
  });

  test('se inicializa una sola vez y sin pedir el permiso de Bluetooth', () async {
    expect(await stt.inicializar(), isTrue);
    expect(await stt.inicializar(), isTrue);

    expect(speech.inicializaciones, 1);
    expect(speech.opciones, contains(SpeechToText.androidNoBluetooth));
  });

  test('si falla (permiso denegado) devuelve false y lo vuelve a intentar la próxima vez', () async {
    speech.resultadoInicializar = false;
    expect(await stt.inicializar(), isFalse);

    speech.resultadoInicializar = true;
    expect(await stt.inicializar(), isTrue);
    expect(speech.inicializaciones, 2);
  });

  test('escucha en español con resultados parciales y entrega el texto en vivo', () async {
    await stt.inicializar();
    final sesion = _Sesion();
    await sesion.escuchar(stt);

    final opciones = speech.opcionesEscucha!;
    expect(opciones.localeId, 'es-ES');
    expect(opciones.partialResults, isTrue);
    expect(opciones.listenMode, ListenMode.dictation);

    speech.resultado('qué es');
    speech.resultado('qué es la sala gesell', esFinal: true);
    expect(sesion.textos, ['qué es', 'qué es la sala gesell']);

    speech.alNivel!(10);
    speech.alNivel!(-2);
    expect(sesion.niveles, [1.0, 0.0]);
  });

  test('cuando el micrófono se apaga avisa una sola vez, y aún acepta el resultado final', () async {
    await stt.inicializar();
    final sesion = _Sesion();
    await sesion.escuchar(stt);

    speech.alEstado!(SpeechToText.listeningStatus);
    expect(sesion.fines, 0);
    speech.alEstado!(SpeechToText.notListeningStatus);
    speech.alEstado!(SpeechToText.doneStatus);
    expect(sesion.fines, 1);

    // En Android el resultado final puede llegar después de apagarse el micrófono.
    speech.resultado('mis derechos', esFinal: true);
    expect(sesion.textos, ['mis derechos']);
  });

  test('un error de permiso se traduce y termina la escucha', () async {
    await stt.inicializar();
    final sesion = _Sesion();
    await sesion.escuchar(stt);

    speech.alError!(SpeechRecognitionError('error_permission', true));
    expect(sesion.problemas, [ProblemaVoz.sinPermiso]);
    expect(sesion.fines, 1);
  });

  test('con el orden de Android (estados primero, error después) también avisa del problema', () async {
    for (final (codigo, problema) in [
      ('error_no_match', ProblemaVoz.noTeOigo),
      ('error_speech_timeout', ProblemaVoz.noTeOigo),
      ('error_network', ProblemaVoz.sinRed),
      ('error_permission', ProblemaVoz.sinPermiso),
    ]) {
      await stt.inicializar();
      final sesion = _Sesion();
      await sesion.escuchar(stt);

      speech.alEstado!(SpeechToText.listeningStatus);
      speech.alEstado!(SpeechToText.notListeningStatus);
      speech.alEstado!(SpeechToText.doneStatus);
      speech.alError!(SpeechRecognitionError(codigo, true));
      // Algunos móviles repiten el error: se avisa una sola vez.
      speech.alError!(SpeechRecognitionError(codigo, true));

      expect(sesion.problemas, [problema], reason: codigo);
      expect(sesion.fines, 1, reason: codigo);
    }
  });

  test('parar termina la sesión; cancelar descarta lo que llegue tarde', () async {
    await stt.inicializar();
    final primera = _Sesion();
    await primera.escuchar(stt);
    await stt.parar();
    expect(speech.paradas, 1);
    expect(primera.fines, 1);

    final segunda = _Sesion();
    await segunda.escuchar(stt);
    await stt.cancelar();
    speech.resultado('tarde');
    expect(speech.cancelaciones, 1);
    expect(segunda.textos, isEmpty);
    expect(segunda.fines, 1);
  });

  test('lo que llega de una escucha anterior no se mezcla con la nueva', () async {
    await stt.inicializar();
    final primera = _Sesion();
    await primera.escuchar(stt);
    final resultadoAntiguo = speech.alResultado!;

    final segunda = _Sesion();
    await segunda.escuchar(stt);
    resultadoAntiguo(SpeechRecognitionResult.init([SpeechRecognitionWords('viejo', null, 1)], ResultType.partial));
    speech.resultado('nuevo');

    expect(primera.textos, isEmpty);
    expect(segunda.textos, ['nuevo']);
  });

  group('reconocimiento en el propio móvil', () {
    test('por defecto lo pide (onDevice)', () async {
      await stt.inicializar();
      await _Sesion().escuchar(stt);

      expect(stt.enElDispositivo, isTrue);
      expect(speech.opcionesEscucha!.onDevice, isTrue);
    });

    test('se puede desactivar', () async {
      final normal = SttReal(speech: speech, enElDispositivo: false);
      await normal.inicializar();
      await _Sesion().escuchar(normal);

      expect(speech.opcionesEscucha!.onDevice, isFalse);
    });

    test('si no tiene el español, avisa con «prueba otra vez» y la próxima vez usa el normal', () async {
      await stt.inicializar();
      final primera = _Sesion();
      await primera.escuchar(stt);

      speech.alEstado!(SpeechToText.notListeningStatus);
      speech.alError!(SpeechRecognitionError('error_language_unavailable', true));

      expect(primera.problemas, [ProblemaVoz.otro]);
      expect(primera.fines, 1);
      expect(stt.enElDispositivo, isFalse);

      await _Sesion().escuchar(stt);
      expect(speech.opcionesEscucha!.onDevice, isFalse);
    });

    test('los errores de siempre (permiso, no te oigo) no lo cambian', () async {
      await stt.inicializar();
      final sesion = _Sesion();
      await sesion.escuchar(stt);

      speech.alError!(SpeechRecognitionError('error_no_match', true));

      expect(sesion.problemas, [ProblemaVoz.noTeOigo]);
      expect(stt.enElDispositivo, isTrue);
    });

    test('si ya había entendido algo, el error no lo cambia', () async {
      await stt.inicializar();
      final sesion = _Sesion();
      await sesion.escuchar(stt);

      speech.resultado('qué es');
      speech.alError!(SpeechRecognitionError('error_client', true));

      expect(stt.enElDispositivo, isTrue);
    });
  });

  test('traduce los códigos de error de Android y de web', () {
    expect(SttReal.problemaDesdeCodigo('error_permission'), ProblemaVoz.sinPermiso);
    expect(SttReal.problemaDesdeCodigo('not-allowed'), ProblemaVoz.sinPermiso);
    expect(SttReal.problemaDesdeCodigo('audio-capture'), ProblemaVoz.sinPermiso);
    expect(SttReal.problemaDesdeCodigo('error_no_match'), ProblemaVoz.noTeOigo);
    expect(SttReal.problemaDesdeCodigo('error_speech_timeout'), ProblemaVoz.noTeOigo);
    expect(SttReal.problemaDesdeCodigo('no-speech'), ProblemaVoz.noTeOigo);
    expect(SttReal.problemaDesdeCodigo('error_network_timeout'), ProblemaVoz.sinRed);
    expect(SttReal.problemaDesdeCodigo('error_server_disconnected'), ProblemaVoz.sinRed);
    expect(SttReal.problemaDesdeCodigo('error_busy'), ProblemaVoz.ocupado);
    expect(SttReal.problemaDesdeCodigo('error_language_unavailable'), ProblemaVoz.idioma);
    expect(SttReal.problemaDesdeCodigo('error_client'), ProblemaVoz.otro);
  });

  test('el volumen queda siempre entre 0 y 1', () {
    expect(SttReal.normalizarNivel(-2), 0);
    expect(SttReal.normalizarNivel(4), closeTo(0.5, 0.001));
    expect(SttReal.normalizarNivel(30), 1);
    expect(SttReal.normalizarNivel(-25), closeTo(0.5, 0.001));
    expect(SttReal.normalizarNivel(-160), 0);
  });
}
