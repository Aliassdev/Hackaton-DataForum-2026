import 'dart:typed_data';

import 'package:audio_stream_player/audio_stream_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/agente/reproductor_pcm.dart';

// El formato del audio del agente, μ-law y ReproductorAudioStream contra el canal del plugin (sin audio de verdad).

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FormatoAudio', () {
    test('lee la frecuencia de agent_output_audio_format; lo que no entiende, pcm_16000', () {
      expect(FormatoAudio.desde('pcm_16000'), const FormatoAudio(16000));
      expect(FormatoAudio.desde('pcm_22050'), const FormatoAudio(22050));
      expect(FormatoAudio.desde(' PCM_24000 '), const FormatoAudio(24000));
      expect(FormatoAudio.desde('pcm_44100'), const FormatoAudio(44100));
      expect(FormatoAudio.desde('ulaw_8000'), const FormatoAudio(8000, ulaw: true));
      for (final raro in [null, '', 'mp3_44100_128', 'pcm_', 'pcm_96000', 'pcm_100']) {
        expect(FormatoAudio.desde(raro), FormatoAudio.porDefecto, reason: '$raro');
      }
    });

    test('duración de un trozo de PCM de 16 bits mono', () {
      expect(const FormatoAudio(16000).duracion(32000), const Duration(seconds: 1));
      expect(const FormatoAudio(16000).duracion(3200), const Duration(milliseconds: 100));
      expect(const FormatoAudio(22050).duracion(4410), const Duration(milliseconds: 100));
      expect(const FormatoAudio(16000).duracion(0), Duration.zero);
    });
  });

  test('μ-law a PCM de 16 bits (G.711)', () {
    final pcm = ulawAPcm16(Uint8List.fromList([0xFF, 0x7F, 0x00, 0x80, 0xF0, 0x70]));
    final muestras = ByteData.sublistView(pcm);
    expect([for (var i = 0; i < 6; i++) muestras.getInt16(i * 2, Endian.little)], [0, 0, -32124, 32124, 120, -120]);
  });

  group('ReproductorAudioStream', () {
    late List<String> llamadas;
    final mensajero = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() {
      llamadas = [];
      mensajero.setMockMethodCallHandler(AudioStreamPlayer.methodChannel, (llamada) async {
        final args = llamada.arguments as Map<Object?, Object?>;
        llamadas.add(switch (llamada.method) {
          'create' => 'create(${args['sampleRate']}, ${args['channels']}, ${args['format']})',
          'feed' => 'feed(${(args['data']! as Uint8List).length})',
          _ => llamada.method,
        });
        return llamada.method == 'bufferedDurationMicros' ? 250000 : null;
      });
      // Cada reproductor escucha sus eventos en su propio canal.
      for (var id = 0; id < 64; id++) {
        mensajero.setMockMethodCallHandler(MethodChannel('audio_stream_player/events/$id'), (_) async => null);
      }
    });

    tearDown(() {
      mensajero.setMockMethodCallHandler(AudioStreamPlayer.methodChannel, null);
      for (var id = 0; id < 64; id++) {
        mensajero.setMockMethodCallHandler(MethodChannel('audio_stream_player/events/$id'), null);
      }
    });

    test('prepara una vez por frecuencia, arranca con el primer trozo y para descartando lo que queda', () async {
      final reproductor = ReproductorAudioStream();

      await Future.wait([
        reproductor.preparar(16000),
        reproductor.preparar(16000),
        reproductor.anadir(Uint8List(3200)),
        reproductor.anadir(Uint8List(1600)),
        reproductor.parar(),
        reproductor.parar(),
        reproductor.anadir(Uint8List(800)),
      ]);
      expect(await reproductor.pendiente(), const Duration(milliseconds: 250));

      expect(llamadas, [
        'create(16000, 1, s16le)',
        'play',
        'feed(3200)',
        'feed(1600)',
        'stop',
        'play',
        'feed(800)',
        'bufferedDurationMicros',
      ]);
      await reproductor.liberar();
    });

    test('otra frecuencia crea otro reproductor; liberar lo suelta', () async {
      final reproductor = ReproductorAudioStream();

      await reproductor.preparar(16000);
      await reproductor.preparar(22050);
      await reproductor.anadir(Uint8List(0));
      await reproductor.liberar();
      await reproductor.anadir(Uint8List(100));
      await reproductor.preparar(16000);

      expect(llamadas, ['create(16000, 1, s16le)', 'dispose', 'create(22050, 1, s16le)', 'dispose']);
    });

    test('si una llamada falla, las siguientes siguen en orden', () async {
      final reproductor = ReproductorAudioStream();
      await reproductor.preparar(16000);
      mensajero.setMockMethodCallHandler(AudioStreamPlayer.methodChannel, (llamada) async {
        llamadas.add(llamada.method);
        if (llamada.method == 'play') throw PlatformException(code: 'audio_stream_player');
        return null;
      });

      await expectLater(reproductor.anadir(Uint8List(10)), throwsA(isA<PlatformException>()));
      await reproductor.parar();
      await reproductor.liberar();

      expect(llamadas, ['create(16000, 1, s16le)', 'play', 'dispose']);
    });
  });
}
