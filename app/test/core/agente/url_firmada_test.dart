import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tuturno/core/agente/url_firmada.dart';

// La URL firmada del backend (GET /api/session/signed-url) y su caché.

const _firmada =
    'wss://api.elevenlabs.io/v1/convai/conversation?agent_id=agente-privado&conversation_signature=firma-de-prueba';

Matcher _error(String motivo, {int? codigoHttp}) => isA<ErrorUrlFirmada>()
    .having((e) => e.motivo, 'motivo', motivo)
    .having((e) => e.codigoHttp, 'codigoHttp', codigoHttp);

void main() {
  group('pedirUrlFirmada', () {
    test('pide GET {API_URL}/api/session/signed-url y devuelve signed_url', () async {
      Uri? pedida;
      final cliente = MockClient((peticion) async {
        pedida = peticion.url;
        expect(peticion.method, 'GET');
        return http.Response(jsonEncode({'signed_url': _firmada}), 200);
      });

      final url = await pedirUrlFirmada(cliente, ' https://backend.example/ ', limite: const Duration(seconds: 4));

      expect(pedida, Uri.parse('https://backend.example/api/session/signed-url'));
      expect(url, Uri.parse(_firmada));
    });

    test('errores sin la URL: API_URL mal, sin red, tiempo agotado, HTTP y respuesta sin signed_url', () async {
      Future<Object?> fallo(http.Client cliente, {String apiUrl = 'https://backend.example'}) async {
        try {
          await pedirUrlFirmada(cliente, apiUrl, limite: const Duration(milliseconds: 50));
          return null;
        } catch (e) {
          return e;
        }
      }

      final bien = MockClient((_) async => http.Response(jsonEncode({'signed_url': _firmada}), 200));
      expect(await fallo(bien, apiUrl: 'backend.example'), _error('API_URL no válida'));
      expect(await fallo(MockClient((_) async => throw http.ClientException('sin red'))), _error('sin conexión'));
      expect(await fallo(MockClient((_) => Completer<http.Response>().future)), _error('tiempo agotado'));
      expect(
        await fallo(MockClient((_) async => http.Response('{"detail":"x"}', 500))),
        _error('respuesta', codigoHttp: 500),
      );
      expect(await fallo(MockClient((_) async => http.Response('no es json', 200))), _error('sin signed_url'));
      expect(
        await fallo(MockClient((_) async => http.Response(jsonEncode({'signed_url': 'https://otra.cosa'}), 200))),
        _error('sin signed_url'),
      );
      expect('${await fallo(MockClient((_) async => http.Response('', 403)))}', isNot(contains('backend.example')));
    });
  });

  group('CacheUrlFirmada', () {
    test('la URL vale 10 minutos y solo para la misma API_URL; olvidar la borra', () {
      var ahora = DateTime(2026, 10, 22, 9);
      final cache = CacheUrlFirmada(reloj: () => ahora);
      final url = Uri.parse(_firmada);

      expect(cache.vigente('https://backend.example'), isNull);
      cache.guardar('https://backend.example', url);
      expect(cache.vigente('https://backend.example'), url);
      expect(cache.vigente('https://otro.example'), isNull);

      ahora = ahora.add(const Duration(minutes: 9, seconds: 59));
      expect(cache.vigente('https://backend.example'), url);
      ahora = ahora.add(const Duration(seconds: 1));
      expect(cache.vigente('https://backend.example'), isNull);

      cache.guardar('https://backend.example', url);
      cache.olvidar();
      expect(cache.vigente('https://backend.example'), isNull);
    });

    test('FuenteUrlFirmada guarda la nueva y da la guardada', () async {
      var pedidas = 0;
      final fuente = FuenteUrlFirmada(
        apiUrl: 'https://backend.example',
        cache: CacheUrlFirmada(),
        pedir: (_) async {
          pedidas++;
          return Uri.parse(_firmada);
        },
      );

      expect(fuente.guardada(), isNull);
      expect(await fuente.nueva(const Duration(seconds: 1)), Uri.parse(_firmada));
      expect(fuente.guardada(), Uri.parse(_firmada));
      fuente.olvidar();
      expect(fuente.guardada(), isNull);
      expect(pedidas, 1);
    });
  });
}
