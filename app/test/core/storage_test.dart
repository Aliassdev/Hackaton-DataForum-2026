import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/ajustes.dart';
import 'package:tuturno/core/storage.dart';

/// Storage sobre unas preferencias en memoria con [valores] iniciales.
Future<(Storage, SharedPreferences)> _storage([Map<String, Object> valores = const {}]) async {
  SharedPreferences.setMockInitialValues(valores);
  final prefs = await SharedPreferences.getInstance();
  return (Storage(prefs), prefs);
}

/// Simula cerrar y volver a abrir la app: una instancia nueva leída del almacén.
Future<Storage> _reabrir() async {
  SharedPreferences.resetStatic();
  return Storage(await SharedPreferences.getInstance());
}

void main() {
  group('Storage', () {
    test('sin nada guardado: ajustes por defecto y bienvenida sin ver', () async {
      final (storage, _) = await _storage();

      final a = storage.leerAjustes();

      expect(a.tamanoTexto, 1.0);
      expect(a.vozActivada, isTrue);
      expect(a.velocidadVoz, 0.5);
      expect(a.apiUrlManual, isNull);
      expect(storage.bienvenidaVista, isFalse);
    });

    test('ida y vuelta: lo que se guarda se lee igual al volver a abrir la app', () async {
      final (storage, _) = await _storage();

      await storage.guardarAjustes(
        const Ajustes(
          tamanoTexto: 1.3,
          vozActivada: false,
          velocidadVoz: 0.8,
          apiUrlManual: 'https://abc.trycloudflare.com',
        ),
      );
      final a = (await _reabrir()).leerAjustes();

      expect(a.tamanoTexto, 1.3);
      expect(a.vozActivada, isFalse);
      expect(a.velocidadVoz, 0.8);
      expect(a.apiUrlManual, 'https://abc.trycloudflare.com');
    });

    test('la URL manual se guarda sin espacios alrededor', () async {
      final (storage, _) = await _storage();

      await storage.guardarAjustes(const Ajustes(apiUrlManual: '  https://abc.trycloudflare.com/ \n'));

      expect((await _reabrir()).leerAjustes().apiUrlManual, 'https://abc.trycloudflare.com/');
    });

    test('quitar la URL manual borra la clave (se vuelve a la de arranque)', () async {
      final (storage, prefs) = await _storage();
      await storage.guardarAjustes(const Ajustes(apiUrlManual: 'https://abc.trycloudflare.com'));
      expect(prefs.getString('ajustes.api_url'), 'https://abc.trycloudflare.com');

      await storage.guardarAjustes(storage.leerAjustes().copyWith(apiUrlManual: () => null));

      expect(prefs.containsKey('ajustes.api_url'), isFalse);
      expect((await _reabrir()).leerAjustes().apiUrlManual, isNull);
    });

    test('una URL manual vacía o solo con espacios también se borra', () async {
      for (final vacia in ['', '   ']) {
        final (storage, prefs) = await _storage({'ajustes.api_url': 'https://antigua.example.com'});

        await storage.guardarAjustes(Ajustes(apiUrlManual: vacia));

        expect(prefs.containsKey('ajustes.api_url'), isFalse, reason: '"$vacia"');
        expect(storage.leerAjustes().apiUrlManual, isNull);
      }
    });

    test('marcarBienvenidaVista se recuerda al volver a abrir la app', () async {
      final (storage, _) = await _storage();

      await storage.marcarBienvenidaVista();

      expect(storage.bienvenidaVista, isTrue);
      expect((await _reabrir()).bienvenidaVista, isTrue);
    });

    test('lee las claves de siempre (los tests de pantallas usan bienvenida_vista)', () async {
      final (storage, _) = await _storage({
        'bienvenida_vista': true,
        'ajustes.tamano_texto': 1.15,
        'ajustes.voz_activada': false,
        'ajustes.velocidad_voz': 0.3,
        'ajustes.api_url': 'http://localhost:8000',
      });

      final a = storage.leerAjustes();

      expect(storage.bienvenidaVista, isTrue);
      expect(
        [a.tamanoTexto, a.vozActivada, a.velocidadVoz, a.apiUrlManual],
        [1.15, false, 0.3, 'http://localhost:8000'],
      );
    });

    test('no guarda nada más que los ajustes (ni conversaciones ni datos personales)', () async {
      final (storage, prefs) = await _storage();

      await storage.guardarAjustes(const Ajustes(apiUrlManual: 'https://abc.trycloudflare.com'));
      await storage.marcarBienvenidaVista();

      expect(prefs.getKeys(), {
        'bienvenida_vista',
        'ajustes.tamano_texto',
        'ajustes.voz_activada',
        'ajustes.velocidad_voz',
        'ajustes.api_url',
      });
    });
  });

  group('Ajustes.copyWith', () {
    const base = Ajustes(tamanoTexto: 1.15, vozActivada: false, velocidadVoz: 0.7, apiUrlManual: 'https://a.example');

    test('sin argumentos copia todo', () {
      final c = base.copyWith();

      expect([c.tamanoTexto, c.vozActivada, c.velocidadVoz, c.apiUrlManual], [1.15, false, 0.7, 'https://a.example']);
    });

    test('cambia solo lo que se pasa y conserva la URL manual', () {
      final c = base.copyWith(tamanoTexto: 1.3, vozActivada: true, velocidadVoz: 0.4);

      expect([c.tamanoTexto, c.vozActivada, c.velocidadVoz, c.apiUrlManual], [1.3, true, 0.4, 'https://a.example']);
    });

    test('la URL manual se cambia con () => valor y se quita con () => null', () {
      expect(base.copyWith(apiUrlManual: () => 'https://b.example').apiUrlManual, 'https://b.example');
      expect(base.copyWith(apiUrlManual: () => null).apiUrlManual, isNull);
    });

    test('valores por defecto', () {
      const a = Ajustes();

      expect([a.tamanoTexto, a.vozActivada, a.velocidadVoz, a.apiUrlManual], [1.0, true, 0.5, null]);
    });
  });
}
