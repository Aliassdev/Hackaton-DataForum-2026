import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Por qué no se ha podido usar la voz. Cada pantalla decide qué texto enseña.
enum ProblemaVoz {
  /// No hay permiso de micrófono o el dispositivo no tiene reconocimiento de voz.
  sinPermiso,

  /// No se ha oído nada (silencio o ruido).
  noTeOigo,

  /// El reconocimiento necesita internet y no hay.
  sinRed,

  /// Otra app está usando el micrófono.
  ocupado,

  /// El reconocimiento no tiene el español instalado.
  idioma,
  otro,
}

/// Voz a texto («pulsar para hablar»). Toda la app comparte una instancia ([sttProvider]).
///
/// La transcripción llega en vivo a [escuchar] y siempre se enseña para poder corregirla antes de enviar.
abstract interface class Stt {
  /// Prepara el micrófono (la primera vez pide permiso). Devuelve false si no se puede usar;
  /// en ese caso el campo de texto sigue funcionando.
  Future<bool> inicializar();

  /// Empieza a escuchar en español. [onTexto] recibe la transcripción completa hasta ahora (parcial y final),
  /// [onNivel] el volumen entre 0 y 1, [onFin] se llama una vez cuando el micrófono se apaga (por silencio,
  /// por [parar] o por un error) y [onProblema] si algo falla. Puede llegar un último [onTexto] después de [onFin].
  Future<void> escuchar({
    required void Function(String texto) onTexto,
    required void Function() onFin,
    void Function(double nivel)? onNivel,
    void Function(ProblemaVoz problema)? onProblema,
  });

  /// Deja de escuchar y espera el resultado final.
  Future<void> parar();

  /// Deja de escuchar y descarta lo que quede por llegar.
  Future<void> cancelar();
}

/// Implementación con speech_to_text.
///
/// [SpeechToText.initialize] solo se ejecuta una vez y sus callbacks no se pueden cambiar después, así que se
/// registran aquí una sola vez y se reparten a la sesión de escucha activa.
class SttReal implements Stt {
  SttReal({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  Future<bool>? _inicializando;
  _Sesion? _sesion;

  static const idioma = 'es-ES';

  /// Términos que el reconocimiento suele confundir (solo se usan en las plataformas que lo admiten).
  static const frasesFrecuentes = [
    'Sala Gesell',
    'Fiscalía de Menores',
    'prueba preconstituida',
    'juzgado',
    'denuncia',
    'abogado',
    'abogada',
  ];

  @override
  Future<bool> inicializar() async {
    if (_speech.isAvailable) return true;
    // Si falló antes (por ejemplo, permiso denegado), se vuelve a intentar: puede haberlo dado en Ajustes.
    return _inicializando ??= _intentar().whenComplete(() => _inicializando = null);
  }

  Future<bool> _intentar() async {
    try {
      return await _speech.initialize(
        onError: _alError,
        onStatus: _alCambiarEstado,
        // Sin esto, Android pide además el permiso de Bluetooth.
        options: [SpeechToText.androidNoBluetooth],
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> escuchar({
    required void Function(String texto) onTexto,
    required void Function() onFin,
    void Function(double nivel)? onNivel,
    void Function(ProblemaVoz problema)? onProblema,
  }) async {
    final sesion = _Sesion(onFin: onFin, onProblema: onProblema);
    _sesion = sesion;
    try {
      await _speech.listen(
        onResult: (resultado) {
          if (identical(_sesion, sesion)) onTexto(resultado.recognizedWords);
        },
        onSoundLevelChange: onNivel == null
            ? null
            : (nivel) {
                if (identical(_sesion, sesion)) onNivel(normalizarNivel(nivel));
              },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          localeId: idioma,
          cancelOnError: true,
          // Android corta solo tras unos segundos de silencio; esto es solo un tope.
          listenFor: const Duration(seconds: 45),
          contextualPhrases: frasesFrecuentes,
        ),
      );
    } catch (_) {
      if (identical(_sesion, sesion)) {
        sesion.problema(ProblemaVoz.otro);
        sesion.terminar();
      }
    }
  }

  @override
  Future<void> parar() async {
    try {
      await _speech.stop();
    } catch (_) {
      // Si el micrófono ya estaba apagado no pasa nada.
    }
    _sesion?.terminar();
  }

  @override
  Future<void> cancelar() async {
    final sesion = _sesion;
    _sesion = null;
    try {
      await _speech.cancel();
    } catch (_) {
      // Nada que hacer.
    }
    sesion?.terminar();
  }

  void _alCambiarEstado(String estado) {
    if (estado == SpeechToText.notListeningStatus || estado == SpeechToText.doneStatus) {
      _sesion?.terminar();
    }
  }

  void _alError(SpeechRecognitionError error) {
    final sesion = _sesion;
    if (sesion == null) return;
    sesion.problema(problemaDesdeCodigo(error.errorMsg));
    sesion.terminar();
  }

  /// Traduce los códigos de error del plugin (Android y web).
  static ProblemaVoz problemaDesdeCodigo(String codigo) {
    // En web, «audio-capture» significa que no hay micrófono.
    if (codigo.contains('permission') || codigo.contains('not-allowed') || codigo.contains('audio-capture')) {
      return ProblemaVoz.sinPermiso;
    }
    if (codigo.contains('no_match') || codigo.contains('speech_timeout') || codigo.contains('no-speech')) {
      return ProblemaVoz.noTeOigo;
    }
    if (codigo.contains('network') || codigo.contains('server')) return ProblemaVoz.sinRed;
    if (codigo.contains('busy')) return ProblemaVoz.ocupado;
    if (codigo.contains('language')) return ProblemaVoz.idioma;
    return ProblemaVoz.otro;
  }

  /// Android da el volumen en dB aproximadamente entre -2 y 10; iOS, en dB negativos. Se lleva a 0-1.
  static double normalizarNivel(double nivel) {
    final valor = nivel < -10 ? (nivel + 50) / 50 : (nivel + 2) / 12;
    return valor.clamp(0.0, 1.0).toDouble();
  }
}

class _Sesion {
  _Sesion({required this.onFin, this.onProblema});

  final void Function() onFin;
  final void Function(ProblemaVoz problema)? onProblema;
  var _terminada = false;
  var _avisado = false;

  /// Se avisa una sola vez por sesión, aunque ya haya terminado: en Android el plugin manda primero
  /// «notListening» y «done» y publica el error después (SpeechToTextPlugin.kt, onError → handler.post).
  /// Los errores tras una parada del usuario ya los descarta el plugin, y tras [SttReal.cancelar] no hay sesión.
  void problema(ProblemaVoz problema) {
    if (_avisado) return;
    _avisado = true;
    onProblema?.call(problema);
  }

  void terminar() {
    if (_terminada) return;
    _terminada = true;
    onFin();
  }
}

/// Una sola instancia para toda la sesión de la app. En los tests se sustituye por una falsa.
final sttProvider = Provider<Stt>((ref) => SttReal());
