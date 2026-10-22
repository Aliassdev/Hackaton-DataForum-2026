import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/api/http_api.dart';
import 'package:tuturno/core/api/mock_api.dart';
import 'package:tuturno/core/api/tuturno_api.dart';
import 'package:tuturno/core/config.dart';
import 'package:tuturno/core/providers.dart';
import 'package:tuturno/core/storage.dart';
import 'package:tuturno/core/texto.dart';

const _urlArranque = 'https://arranque.example.com';
const _urlManual = 'https://abc.trycloudflare.com';

/// Contenedor como el de main(): configuración de arranque y preferencias con [guardado].
Future<(ProviderContainer, SharedPreferences)> _contenedor({
  String apiUrl = _urlArranque,
  bool useMock = false,
  bool demo = false,
  Map<String, Object> guardado = const {},
}) async {
  SharedPreferences.setMockInitialValues(guardado);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer.test(
    overrides: [
      configProvider.overrideWithValue(AppConfig(apiUrl: apiUrl, useMock: useMock, demo: demo)),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  return (container, prefs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('apiUrlProvider', () {
    test('sin URL manual usa la de arranque (API_URL o config.json)', () async {
      final (container, _) = await _contenedor();

      expect(container.read(apiUrlProvider), _urlArranque);
    });

    test('la URL manual de Ajustes tiene preferencia sobre la de arranque', () async {
      final (container, _) = await _contenedor(guardado: {'ajustes.api_url': _urlManual});

      expect(container.read(apiUrlProvider), _urlManual);
    });

    test('una URL manual solo con espacios no cuenta', () async {
      final (container, _) = await _contenedor(guardado: {'ajustes.api_url': '   '});

      expect(container.read(apiUrlProvider), _urlArranque);
    });

    test('cambia al momento al poner o quitar la URL en Ajustes, y se guarda', () async {
      final (container, prefs) = await _contenedor();
      final notifier = container.read(ajustesProvider.notifier);
      expect(container.read(apiUrlProvider), _urlArranque);

      await notifier.actualizar((a) => a.copyWith(apiUrlManual: () => _urlManual));
      expect(container.read(apiUrlProvider), _urlManual);
      expect(prefs.getString('ajustes.api_url'), _urlManual);

      await notifier.actualizar((a) => a.copyWith(apiUrlManual: () => null));
      expect(container.read(apiUrlProvider), _urlArranque);
      expect(prefs.containsKey('ajustes.api_url'), isFalse);
    });
  });

  group('apiProvider', () {
    test('con USE_MOCK devuelve MockTuTurnoApi (aunque haya URL)', () async {
      final (container, _) = await _contenedor(useMock: true, guardado: {'ajustes.api_url': _urlManual});

      expect(container.read(apiProvider), isA<MockTuTurnoApi>());
    });

    test('sin USE_MOCK devuelve HttpTuTurnoApi', () async {
      final (container, _) = await _contenedor();

      expect(container.read(apiProvider), isA<HttpTuTurnoApi>());
    });

    test('sin USE_MOCK y sin ninguna URL, las llamadas fallan con SIN_API_URL (sin red)', () async {
      final (container, _) = await _contenedor(apiUrl: '');

      await expectLater(
        container.read(apiProvider).health(),
        throwsA(isA<ApiException>().having((e) => e.codigo, 'codigo', 'SIN_API_URL')),
      );
    });

    test('se vuelve a crear cuando cambia la URL manual', () async {
      final (container, _) = await _contenedor();
      final antes = container.read(apiProvider);

      await container.read(ajustesProvider.notifier).actualizar((a) => a.copyWith(apiUrlManual: () => _urlManual));

      expect(container.read(apiProvider), isNot(same(antes)));
    });

    test('no se vuelve a crear si cambia otro ajuste (p. ej. el tamaño de letra)', () async {
      final (container, _) = await _contenedor();
      final antes = container.read(apiProvider);

      await container.read(ajustesProvider.notifier).actualizar((a) => a.copyWith(tamanoTexto: 1.3));

      expect(container.read(apiProvider), same(antes));
    });
  });

  group('ajustes y bienvenida', () {
    test('ajustesProvider empieza con lo guardado y actualizar lo guarda', () async {
      final (container, prefs) = await _contenedor(guardado: {'ajustes.voz_activada': false});
      expect(container.read(ajustesProvider).vozActivada, isFalse);

      await container
          .read(ajustesProvider.notifier)
          .actualizar((a) => a.copyWith(vozActivada: true, velocidadVoz: 0.7, tamanoTexto: 1.15));

      final guardado = Storage(prefs).leerAjustes();
      expect([guardado.vozActivada, guardado.velocidadVoz, guardado.tamanoTexto], [true, 0.7, 1.15]);
      expect(container.read(ajustesProvider).velocidadVoz, 0.7);
    });

    test('bienvenidaVistaProvider.marcar() la marca y la guarda', () async {
      final (container, prefs) = await _contenedor();
      expect(container.read(bienvenidaVistaProvider), isFalse);

      await container.read(bienvenidaVistaProvider.notifier).marcar();

      expect(container.read(bienvenidaVistaProvider), isTrue);
      expect(prefs.getBool('bienvenida_vista'), isTrue);
    });

    test('bienvenidaVistaProvider.desmarcar() vuelve a enseñarla (modo DEMO)', () async {
      final (container, prefs) = await _contenedor(guardado: {'bienvenida_vista': true});
      expect(container.read(bienvenidaVistaProvider), isTrue);

      await container.read(bienvenidaVistaProvider.notifier).desmarcar();

      expect(container.read(bienvenidaVistaProvider), isFalse);
      expect(prefs.getBool('bienvenida_vista'), isNull);
    });
  });

  group('contenido', () {
    test('con USE_MOCK, el glosario carga los datos de ejemplo: validados, con fuente y ordenados', () async {
      final (container, _) = await _contenedor(useMock: true);
      expect(container.read(contentProvider).usarEjemplos, isTrue);

      final glosario = await container.read(glosarioProvider.future);

      expect(glosario, isNotEmpty);
      expect(glosario.every((e) => e.validado && e.fuente.isNotEmpty), isTrue);
      final claves = [for (final e in glosario) normalizar(e.termino)];
      expect(claves, [...claves]..sort());
    });

    test('también sin USE_MOCK se usan los ejemplos si falta el contenido real, pero no los borradores', () async {
      final (container, _) = await _contenedor();

      expect(container.read(contentProvider).usarEjemplos, isTrue);
      expect(container.read(contentProvider).mostrarBorradores, isFalse);
    });

    test('los borradores solo se ven con DEMO y el interruptor encendido', () async {
      final (sinDemo, _) = await _contenedor();
      sinDemo.read(mostrarBorradoresProvider.notifier).cambiar(true);
      expect(sinDemo.read(contentProvider).mostrarBorradores, isFalse);

      final (conDemo, _) = await _contenedor(demo: true);
      expect(conDemo.read(contentProvider).mostrarBorradores, isFalse);
      conDemo.read(mostrarBorradoresProvider.notifier).cambiar(true);
      expect(conDemo.read(contentProvider).mostrarBorradores, isTrue);
    });
  });
}
