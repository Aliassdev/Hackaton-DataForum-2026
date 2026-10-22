import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:tuturno/core/config.dart';

void main() {
  test('en Android (VM) usa los --dart-define y no pide config.json', () async {
    var peticiones = 0;
    final cliente = MockClient((request) async {
      peticiones++;
      throw StateError('No debería pedir ${request.url}');
    });

    final config = await AppConfig.load(client: cliente);

    expect(config.apiUrl, const String.fromEnvironment('API_URL'));
    expect(config.useMock, const bool.fromEnvironment('USE_MOCK'));
    expect(config.demo, const bool.fromEnvironment('DEMO'));
    expect(peticiones, 0);
  });

  test('sin --dart-define: sin URL, sin mock y sin modo demo', () async {
    final config = await AppConfig.load();

    if (!const bool.hasEnvironment('API_URL')) expect(config.apiUrl, isEmpty);
    if (!const bool.hasEnvironment('USE_MOCK')) expect(config.useMock, isFalse);
    if (!const bool.hasEnvironment('DEMO')) expect(config.demo, isFalse);
  });
}
