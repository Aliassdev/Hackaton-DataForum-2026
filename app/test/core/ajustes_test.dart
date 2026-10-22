import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/ajustes.dart';
import 'package:tuturno/core/config.dart';
import 'package:tuturno/core/providers.dart';

/// Un contenedor como el de main() sobre las preferencias que haya ahora en el almacén simulado.
Future<ProviderContainer> _abrirApp() async {
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer.test(
    overrides: [
      configProvider.overrideWithValue(const AppConfig(apiUrl: '', useMock: true, demo: false)),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
}

/// Simula cerrar y volver a abrir la app: lo guardado se queda en el almacén y se vuelve a leer desde cero.
Future<ProviderContainer> _reiniciarApp(ProviderContainer anterior) async {
  anterior.dispose();
  SharedPreferences.resetStatic();
  return _abrirApp();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ajustes: lectura fácil y reducir animaciones', () {
    test('apagados por defecto', () {
      const a = Ajustes();

      expect(a.lecturaFacil, isFalse);
      expect(a.reducirMovimiento, isFalse);
    });

    test('copyWith los cambia y conserva todo lo demás', () {
      const base = Ajustes(tamanoTexto: 1.3, vozActivada: false, velocidadVoz: 0.7, apiUrlManual: 'https://a.example');

      final c = base.copyWith(lecturaFacil: true, reducirMovimiento: true);

      expect([c.lecturaFacil, c.reducirMovimiento], [true, true]);
      expect([c.tamanoTexto, c.vozActivada, c.velocidadVoz, c.apiUrlManual], [1.3, false, 0.7, 'https://a.example']);
      final otra = c.copyWith(tamanoTexto: 1.15);
      expect([otra.lecturaFacil, otra.reducirMovimiento], [true, true], reason: 'sin pasarlos, se conservan');
      expect(c.copyWith(lecturaFacil: false).reducirMovimiento, isTrue, reason: 'son independientes');
    });
  });

  group('ajustesProvider', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('lectura fácil y reducir animaciones se guardan y sobreviven a reiniciar la app', () async {
      var app = await _abrirApp();
      expect(app.read(ajustesProvider).lecturaFacil, isFalse);
      expect(app.read(ajustesProvider).reducirMovimiento, isFalse);

      await app
          .read(ajustesProvider.notifier)
          .actualizar((a) => a.copyWith(lecturaFacil: true, reducirMovimiento: true));
      expect(app.read(ajustesProvider).lecturaFacil, isTrue);

      app = await _reiniciarApp(app);
      expect(app.read(ajustesProvider).lecturaFacil, isTrue);
      expect(app.read(ajustesProvider).reducirMovimiento, isTrue);

      // Y al apagarlos, también se recuerda.
      await app.read(ajustesProvider.notifier).actualizar((a) => a.copyWith(lecturaFacil: false));
      app = await _reiniciarApp(app);
      expect(app.read(ajustesProvider).lecturaFacil, isFalse);
      expect(app.read(ajustesProvider).reducirMovimiento, isTrue);
    });

    test('cambiar uno no toca los demás ajustes guardados', () async {
      SharedPreferences.setMockInitialValues({
        'ajustes.tamano_texto': 1.3,
        'ajustes.voz_activada': false,
        'ajustes.api_url': 'https://abc.trycloudflare.com',
      });
      var app = await _abrirApp();

      await app.read(ajustesProvider.notifier).actualizar((a) => a.copyWith(reducirMovimiento: true));
      app = await _reiniciarApp(app);

      final a = app.read(ajustesProvider);
      expect([a.tamanoTexto, a.vozActivada, a.apiUrlManual], [1.3, false, 'https://abc.trycloudflare.com']);
      expect([a.reducirMovimiento, a.lecturaFacil], [true, false]);
    });

    test('quien escucha solo la lectura fácil se entera al momento', () async {
      final app = await _abrirApp();
      final cambios = <bool>[];
      app.listen(ajustesProvider.select((a) => a.lecturaFacil), (_, valor) => cambios.add(valor));

      await app.read(ajustesProvider.notifier).actualizar((a) => a.copyWith(reducirMovimiento: true));
      await app.read(ajustesProvider.notifier).actualizar((a) => a.copyWith(lecturaFacil: true));

      expect(cambios, [true]);
    });
  });
}
