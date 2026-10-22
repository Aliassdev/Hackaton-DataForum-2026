import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:tuturno/core/voz/tts.dart';

/// flutter_tts sin plataforma: speak() termina cuando el test llama a [terminar] (como con awaitSpeakCompletion).
class _FakeFlutterTts extends FlutterTts {
  final llamadas = <String>[];
  Completer<dynamic>? _lectura;
  ErrorHandler? manejadorError;

  @override
  Future<dynamic> setLanguage(String language) async {
    llamadas.add('idioma:$language');
    return 1;
  }

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async {
    llamadas.add('esperar:$awaitCompletion');
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    llamadas.add('velocidad:$rate');
    return 1;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) {
    llamadas.add('hablar:$text');
    final lectura = _lectura = Completer<dynamic>();
    return lectura.future;
  }

  @override
  Future<dynamic> stop() async {
    llamadas.add('parar');
    _lectura?.complete(0);
    _lectura = null;
    return 1;
  }

  @override
  void setErrorHandler(ErrorHandler handler) => manejadorError = handler;

  void terminar() {
    _lectura?.complete(1);
    _lectura = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeFlutterTts plugin;
  late TtsReal tts;
  var velocidadAjustes = 0.5;

  setUp(() {
    plugin = _FakeFlutterTts();
    velocidadAjustes = 0.5;
    tts = TtsReal(tts: plugin, velocidadPorDefecto: () => velocidadAjustes);
  });

  Future<void> esperar() => Future<void>.delayed(Duration.zero);

  test('se configura en español, espera a terminar y lee con la velocidad de Ajustes', () async {
    var terminado = false;
    final lectura = tts.hablar('Hola').then((_) => terminado = true);
    await esperar();

    expect(plugin.llamadas, containsAllInOrder(['idioma:es-ES', 'esperar:true', 'velocidad:0.5', 'hablar:Hola']));
    expect(tts.hablando.value, isTrue);
    expect(terminado, isFalse);

    plugin.terminar();
    await lectura;
    expect(terminado, isTrue);
    expect(tts.hablando.value, isFalse);
  });

  test('la configuración se hace una vez y la velocidad solo se cambia si cambia', () async {
    final primera = tts.hablar('Uno');
    await esperar();
    plugin.terminar();
    await primera;

    final segunda = tts.hablar('Dos');
    await esperar();
    plugin.terminar();
    await segunda;

    velocidadAjustes = 0.7;
    final tercera = tts.hablar('Tres', velocidad: 0.3);
    await esperar();
    plugin.terminar();
    await tercera;

    expect(plugin.llamadas.where((l) => l.startsWith('idioma:')), hasLength(1));
    expect(plugin.llamadas.where((l) => l.startsWith('velocidad:')), ['velocidad:0.5', 'velocidad:0.3']);
  });

  test('parar corta la lectura y termina su Future', () async {
    var terminado = false;
    final lectura = tts.hablar('Una respuesta larga').then((_) => terminado = true);
    await esperar();

    await tts.parar();
    await lectura;
    expect(terminado, isTrue);
    expect(plugin.llamadas.last, 'parar');
    expect(tts.hablando.value, isFalse);
  });

  test('leer otra cosa corta la anterior (en Android, speak se descartaría si sigue hablando)', () async {
    var primeraTerminada = false;
    final primera = tts.hablar('Primera').then((_) => primeraTerminada = true);
    await esperar();

    final segunda = tts.hablar('Segunda');
    await primera;
    expect(primeraTerminada, isTrue);
    await esperar();
    final i = plugin.llamadas.lastIndexOf('parar');
    expect(i, greaterThan(plugin.llamadas.indexOf('hablar:Primera')));
    expect(plugin.llamadas.last, 'hablar:Segunda');
    expect(tts.hablando.value, isTrue);

    plugin.terminar();
    await segunda;
    expect(tts.hablando.value, isFalse);
  });

  test('si el motor falla, la lectura termina igualmente', () async {
    final lectura = tts.hablar('Hola');
    await esperar();
    plugin.manejadorError!('Error from TextToSpeech (speak) - -5');
    await lectura;
    expect(tts.hablando.value, isFalse);
  });

  test('un texto vacío no se lee', () async {
    await tts.hablar('   ');
    expect(plugin.llamadas.where((l) => l.startsWith('hablar:')), isEmpty);
    expect(tts.hablando.value, isFalse);
  });

  test('las referencias a fuentes no se leen en voz alta', () {
    expect(
      textoParaVoz('Antes de los 14 años no hay responsabilidad penal [A-017]. Lo dice la ley [A-017, A-020].'),
      'Antes de los 14 años no hay responsabilidad penal. Lo dice la ley.',
    );
    expect(textoParaVoz('Llama al 900 20 20 10 [ANAR]'), 'Llama al 900 20 20 10 [ANAR]');
  });
}
