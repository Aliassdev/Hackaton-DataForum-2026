import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/agente/agente_provider.dart';
import 'package:tuturno/core/agente/agente_voz.dart';
import 'package:tuturno/core/agente/elevenlabs_ws_agente_voz.dart';
import 'package:tuturno/core/config.dart';
import 'package:tuturno/core/providers.dart';

// Cuándo va Pregunta con el agente de voz y de dónde saca la sesión: URL firmada del backend o agent_id.

Future<ProviderContainer> _contenedor({String apiUrl = '', Map<String, Object> guardado = const {}}) async {
  SharedPreferences.setMockInitialValues(guardado);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer.test(
    overrides: [
      configProvider.overrideWithValue(AppConfig(apiUrl: apiUrl, useMock: true, demo: false)),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('modo agente con API_URL (la APK no necesita el agent_id) o con agent_id; sin nada, modo texto', () async {
    final conBackend = await _contenedor(apiUrl: 'https://backend.example');
    expect(conBackend.read(modoAgenteProvider), isTrue);

    final conAgentId = await _contenedor(guardado: {'ajustes.agent_id': 'agente-de-prueba'});
    expect(conAgentId.read(modoAgenteProvider), isTrue);

    if (!const bool.hasEnvironment('AGENT_ID')) {
      final sinNada = await _contenedor();
      expect(sinNada.read(modoAgenteProvider), isFalse);
      expect(sinNada.read(agenteVozProvider), isNull);
    }
  });

  test('con API_URL, el agente pide la URL firmada a ese backend; sin ella, usa el agent_id', () async {
    final conBackend = await _contenedor(apiUrl: ' https://backend.example ');
    final suscripcion = conBackend.listen<AgenteVoz?>(agenteVozProvider, (_, _) {});
    final agente = suscripcion.read();
    expect(agente, isA<ElevenLabsWsAgenteVoz>());
    expect((agente! as ElevenLabsWsAgenteVoz).urlFirmada?.apiUrl, 'https://backend.example');
    expect(agente.estado.value, EstadoAgente.desconectado);

    final conAgentId = await _contenedor(guardado: {'ajustes.agent_id': 'agente-de-prueba'});
    final otra = conAgentId.listen<AgenteVoz?>(agenteVozProvider, (_, _) {});
    expect((otra.read()! as ElevenLabsWsAgenteVoz).urlFirmada, isNull);
  });
}
