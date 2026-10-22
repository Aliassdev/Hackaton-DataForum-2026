import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../providers.dart';

/// Texto a voz en español. Toda la app comparte una instancia ([ttsProvider]).
///
/// Todo lo que se lee en voz alta también está escrito en pantalla.
abstract interface class Tts {
  /// true mientras se está leyendo algo.
  ValueListenable<bool> get hablando;

  /// Lee [texto] en voz alta, cortando lo que se estuviera leyendo. Termina cuando acaba de leer, cuando
  /// se llama a [parar] o si falla (nunca lanza). [velocidad] va de 0 a 1 (0,5 es la normal); si es nula,
  /// se usa la de Ajustes.
  Future<void> hablar(String texto, {double? velocidad});

  /// Deja de leer. Hay que llamarlo siempre antes de escuchar con el micrófono.
  Future<void> parar();
}

/// Implementación con flutter_tts.
class TtsReal implements Tts {
  TtsReal({FlutterTts? tts, double Function()? velocidadPorDefecto})
    : _tts = tts ?? FlutterTts(),
      _velocidadPorDefecto = velocidadPorDefecto ?? (() => 0.5);

  final FlutterTts _tts;
  final double Function() _velocidadPorDefecto;
  final _hablando = ValueNotifier(false);
  Future<void>? _configuracion;
  Completer<void>? _actual;
  double? _velocidadActual;

  static const idioma = 'es-ES';

  @override
  ValueListenable<bool> get hablando => _hablando;

  Future<void> _configurar() => _configuracion ??= () async {
    try {
      await _tts.setLanguage(idioma);
      // speak() termina al acabar de leer (o al llamar a stop()).
      await _tts.awaitSpeakCompletion(true);
      // En Android, si falla, speak() no termina nunca: se cierra aquí.
      _tts.setErrorHandler((_) => _terminar());
    } catch (_) {
      // Sin motor de voz: hablar() terminará sin leer.
    }
  }();

  @override
  Future<void> hablar(String texto, {double? velocidad}) async {
    // Esta lectura sustituye a la anterior desde ya, aunque haya varias llamadas seguidas.
    final anterior = _actual;
    final lectura = Completer<void>();
    _actual = lectura;
    if (anterior != null && !anterior.isCompleted) anterior.complete();
    _hablando.value = true;
    bool vigente() => identical(_actual, lectura);
    try {
      // En Android, speak() se descarta si ya se está leyendo algo: primero se para.
      await _tts.stop();
      final limpio = texto.trim();
      if (limpio.isEmpty || !vigente()) {
        if (vigente()) _terminar();
        return;
      }
      await _configurar();
      // En Android e iOS 0,5 es la velocidad normal; en web es 1.
      final v = (velocidad ?? _velocidadPorDefecto()).clamp(0.0, 1.0).toDouble();
      final objetivo = kIsWeb ? v * 2 : v;
      if (objetivo != _velocidadActual) {
        await _tts.setSpeechRate(objetivo);
        _velocidadActual = objetivo;
      }
      if (!vigente()) return;
      unawaited(
        _tts.speak(limpio).then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
          if (vigente()) _terminar();
        }),
      );
    } catch (_) {
      if (vigente()) _terminar();
    }
    return lectura.future;
  }

  @override
  Future<void> parar() async {
    final habia = _actual != null;
    _terminar();
    if (!habia) return;
    try {
      await _tts.stop();
    } catch (_) {
      // Nada que parar.
    }
  }

  void _terminar() {
    final lectura = _actual;
    _actual = null;
    _hablando.value = false;
    if (lectura != null && !lectura.isCompleted) lectura.complete();
  }

  void dispose() {
    _terminar();
    unawaited(_tts.stop().then<void>((_) {}, onError: (Object _) {}));
    _hablando.dispose();
  }
}

final _referencia = RegExp(r'\s*\[[A-Za-z]{1,4}-[\w.-]+(?:\s*[,;]\s*[A-Za-z]{1,4}-[\w.-]+)*\]');
final _espacios = RegExp(r'\s+');

/// Quita lo que no se debe leer en voz alta, como las referencias a fuentes ([A-017]).
String textoParaVoz(String texto) => texto.replaceAll(_referencia, '').replaceAll(_espacios, ' ').trim();

/// Una sola instancia para toda la sesión de la app. En los tests se sustituye por una falsa.
final ttsProvider = Provider<Tts>((ref) {
  final tts = TtsReal(velocidadPorDefecto: () => ref.read(ajustesProvider).velocidadVoz);
  ref.onDispose(tts.dispose);
  return tts;
});
