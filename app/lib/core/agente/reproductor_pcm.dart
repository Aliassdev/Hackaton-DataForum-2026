import 'dart:async';

import 'package:audio_stream_player/audio_stream_player.dart';
import 'package:flutter/foundation.dart';

// La voz del agente: PCM de 16 bits que llega en trozos por el WebSocket y suena según llega.
//
// Plugin: audio_stream_player 1.1.0 (comparado en pub.dev con flutter_pcm_sound, mp_audio_stream, flutter_soloud,
// sound_stream y flutter_sound). En Android usa un AudioTrack en streaming con USAGE_MEDIA y CONTENT_TYPE_SPEECH: la
// voz va como multimedia (volumen normal; altavoz, auriculares o Bluetooth), nunca como llamada, y no toca el
// micrófono ni el modo de audio del móvil. Su stop() descarta en el acto lo que quedaba (crea un AudioTrack nuevo) y
// bufferedDuration() mide lo que falta por sonar con la posición real de reproducción. Kotlin, compileSdk 36 y
// minSdk 21; tiene versión web (Web Audio).

/// Formato del audio de salida del agente (agent_output_audio_format de conversation_initiation_metadata).
@immutable
class FormatoAudio {
  const FormatoAudio(this.frecuencia, {this.ulaw = false});

  /// pcm_16000: lo que usa ElevenLabs si no se cambia en el agente.
  static const porDefecto = FormatoAudio(16000);

  /// Muestras por segundo (mono).
  final int frecuencia;

  /// ulaw_8000 (telefonía): hay que pasarlo a PCM de 16 bits antes de reproducirlo.
  final bool ulaw;

  /// «pcm_16000», «pcm_22050», «pcm_24000», «pcm_44100»… o «ulaw_8000». Lo que no se entienda, [porDefecto].
  static FormatoAudio desde(String? texto) {
    final limpio = texto?.trim().toLowerCase() ?? '';
    if (limpio == 'ulaw_8000') return const FormatoAudio(8000, ulaw: true);
    final pcm = RegExp(r'^pcm_(\d{4,5})$').firstMatch(limpio);
    final frecuencia = pcm == null ? null : int.parse(pcm[1]!);
    if (frecuencia == null || frecuencia < 8000 || frecuencia > 48000) return porDefecto;
    return FormatoAudio(frecuencia);
  }

  /// Lo que dura [bytes] de PCM de 16 bits mono a esta frecuencia.
  Duration duracion(int bytes) => Duration(microseconds: (bytes ~/ 2) * Duration.microsecondsPerSecond ~/ frecuencia);

  @override
  bool operator ==(Object other) => other is FormatoAudio && other.frecuencia == frecuencia && other.ulaw == ulaw;

  @override
  int get hashCode => Object.hash(frecuencia, ulaw);

  @override
  String toString() => ulaw ? 'ulaw_$frecuencia' : 'pcm_$frecuencia';
}

/// μ-law (G.711) a PCM de 16 bits, little endian.
Uint8List ulawAPcm16(Uint8List ulaw) {
  final salida = Uint8List(ulaw.length * 2);
  final vista = ByteData.sublistView(salida);
  for (var i = 0; i < ulaw.length; i++) {
    final u = ~ulaw[i] & 0xFF;
    final t = (((u & 0x0F) << 3) + 0x84) << ((u & 0x70) >> 4);
    vista.setInt16(i * 2, (u & 0x80) != 0 ? 0x84 - t : t - 0x84, Endian.little);
  }
  return salida;
}

/// Reproductor de PCM de 16 bits mono en streaming. En los tests se sustituye por uno falso.
abstract interface class ReproductorPcm {
  /// Deja la salida lista para [frecuencia] Hz. Si ya lo está, no hace nada.
  Future<void> preparar(int frecuencia);

  /// Añade audio al final de lo que suena y, si no sonaba nada, empieza a sonar.
  Future<void> anadir(Uint8List pcm);

  /// Para en el acto y descarta lo que quedaba por sonar.
  Future<void> parar();

  /// Lo que falta por sonar de lo ya añadido.
  Future<Duration> pendiente();

  Future<void> liberar();
}

/// [ReproductorPcm] con audio_stream_player. Las llamadas van en cola, en orden: así un parar() nunca adelanta a un
/// anadir() anterior ni al revés.
class ReproductorAudioStream implements ReproductorPcm {
  AudioStreamPlayer? _player;
  int? _frecuencia;

  /// Se ha llamado a play() desde que se creó el AudioTrack o desde el último stop().
  var _enMarcha = false;
  var _liberado = false;
  Future<void> _cola = Future.value();

  Future<T> _enCola<T>(Future<T> Function() tarea) {
    final resultado = _cola.then((_) => tarea());
    _cola = resultado.then((_) {}, onError: (Object _) {});
    return resultado;
  }

  @override
  Future<void> preparar(int frecuencia) => _enCola(() async {
    if (_liberado || (_player != null && _frecuencia == frecuencia)) return;
    final anterior = _player;
    _player = null;
    _enMarcha = false;
    if (anterior != null) await anterior.dispose();
    _player = await AudioStreamPlayer.create(sampleRate: frecuencia);
    _frecuencia = frecuencia;
  });

  @override
  Future<void> anadir(Uint8List pcm) => _enCola(() async {
    final player = _player;
    if (player == null || pcm.isEmpty) return;
    if (!_enMarcha) {
      await player.play();
      _enMarcha = true;
    }
    await player.feed(pcm);
  });

  @override
  Future<void> parar() => _enCola(() async {
    final player = _player;
    if (player == null || !_enMarcha) return;
    _enMarcha = false;
    await player.stop();
  });

  @override
  Future<Duration> pendiente() => _enCola(() async {
    final player = _player;
    return player == null ? Duration.zero : await player.bufferedDuration();
  });

  @override
  Future<void> liberar() => _enCola(() async {
    _liberado = true;
    final player = _player;
    _player = null;
    await player?.dispose();
  });
}
