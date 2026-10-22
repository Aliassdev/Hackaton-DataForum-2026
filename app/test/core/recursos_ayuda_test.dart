import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/recursos_ayuda.dart';
import 'package:tuturno/core/texto.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final telefonos = recursosAyuda.where((r) => r.telefono != null).toList();
  RecursoAyuda conTelefono(String telefono) => recursosAyuda.singleWhere((r) => r.telefono == telefono);
  final incibe = conTelefono('017');
  final canalJoven = conTelefono('900 293 183');
  final canalPrioritario = recursosAyuda.singleWhere((r) => r.web != null);

  group('recursosAyuda', () {
    test('están los teléfonos de la sección 4.5, con el Canal Joven de la AEPD', () {
      expect(
        telefonos.map((r) => r.telefono!.replaceAll(' ', '')),
        unorderedEquals(['900202010', '116111', '112', '017', '016', '900293183']),
      );
      expect(telefonos.map((r) => r.telefono), containsAll(['900 20 20 10', '116 111', '900 293 183']));
    });

    test('el orden se mantiene: ANAR primero, el Canal Joven con los teléfonos y la web al final', () {
      expect(recursosAyuda.map((r) => r.telefono ?? r.web), [
        '900 20 20 10',
        '116 111',
        '112',
        '017',
        '016',
        '900 293 183',
        'https://www.aepd.es/canalprioritario',
      ]);
    });

    test('los teléfonos se marcan con una URI tel: sin espacios', () {
      for (final r in telefonos) {
        expect(r.uri.scheme, 'tel', reason: r.nombre);
        expect(r.uri.path, matches(RegExp(r'^\d+$')), reason: r.nombre);
        expect(r.uri.toString(), 'tel:${r.telefono!.replaceAll(' ', '')}', reason: r.nombre);
        expect(r.uri.toString(), isNot(contains(' ')), reason: r.nombre);
        expect(r.uri.toString(), isNot(contains('%20')), reason: r.nombre);
      }
    });

    test('ANAR es el primero, se marca como tel:900202010 y atiende a cualquier hora', () {
      expect(recursosAyuda.first.telefono, '900 20 20 10');
      expect(recursosAyuda.first.uri, Uri.parse('tel:900202010'));
      expect(recursosAyuda.first.descripcion, contains('a cualquier hora'));
      expect(recursosAyuda.first.horario, isNull);
    });

    test('el canal prioritario de la AEPD se abre por https y se enseña sin «https://www.»', () {
      expect(canalPrioritario.uri, Uri.parse('https://www.aepd.es/canalprioritario'));
      expect(canalPrioritario.uri.scheme, 'https');
      expect(canalPrioritario.uri.host, 'www.aepd.es');
      expect(canalPrioritario.webVisible, 'aepd.es/canalprioritario');
      expect(canalPrioritario.descripcion, contains('Canal prioritario'));
    });

    test('cada recurso tiene teléfono o web (no los dos), nombre y descripción', () {
      for (final r in recursosAyuda) {
        expect((r.telefono == null) != (r.web == null), isTrue, reason: r.nombre);
        expect(r.nombre.trim(), isNotEmpty);
        expect(r.descripcion.trim(), isNotEmpty);
      }
    });

    test('el 116 111 no dice que siempre lo atienda ANAR: según la comunidad, lo atiende otro servicio', () {
      final infancia = conTelefono('116 111');
      expect(infancia.descripcion, contains('En muchas comunidades lo atiende ANAR'));
      expect(normalizar(infancia.descripcion), isNot(contains('en espana lo atiende anar')));
      expect(infancia.horario, isNull);
    });

    test('ANAR tiene chat (para escribir si no puedes hablar) y se abre por https', () {
      final anar = recursosAyuda.first;
      expect(anar.uriChat, Uri.parse('https://chatanar.es'));
      expect(anar.descripcion, contains('confidencial'));
      expect(recursosAyuda.where((r) => r.chat != null), [anar]);
    });

    test('los teléfonos visibles no se parten en dos líneas', () {
      for (final r in telefonos) {
        expect(r.telefonoVisible, isNot(contains(' ')), reason: r.nombre);
        expect(r.telefonoVisible!.replaceAll(' ', ' '), r.telefono, reason: r.nombre);
      }
    });

    test('solo el 112 es urgente', () {
      expect(recursosAyuda.where((r) => r.urgente).map((r) => r.telefono), ['112']);
    });

    test('mensaje del adulto de confianza (sección 4.5)', () {
      expect(
        mensajeAdultoDeConfianza,
        startsWith('Habla con un adulto de confianza o con el coordinador de bienestar de tu centro'),
      );
    });

    test('ningún recurso promete atender 24 horas', () {
      for (final r in recursosAyuda) {
        final texto = normalizar('${r.nombre} ${r.descripcion} ${r.notas.map((n) => n.texto).join(' ')}');
        expect(texto, isNot(contains('24 horas')), reason: r.nombre);
        expect(texto, isNot(contains('24h')), reason: r.nombre);
      }
    });
  });

  group('017 (INCIBE)', () {
    test('atiende todos los días de 8:00 a 23:00, no a cualquier hora (sección 2.3)', () {
      final horario = incibe.horario!;
      expect(horario.texto, 'Todos los días, de 8:00 a 23:00');
      expect(horario.apertura, const Duration(hours: 8));
      expect(horario.cierre, const Duration(hours: 23));
      expect(horario.textoApertura, '8:00');
      expect(normalizar(incibe.descripcion), isNot(contains('a cualquier hora')));
    });

    test('también por WhatsApp, al 900 116 117, con el enlace que publica el INCIBE', () {
      expect(incibe.whatsapp, '900 116 117');
      expect(incibe.uriWhatsapp, Uri.parse('https://wa.me/34900116117'));
      expect(recursosAyuda.where((r) => r.whatsapp != null), [incibe]);
    });

    test('solo el 017 tiene horario', () {
      expect(recursosAyuda.where((r) => r.horario != null), [incibe]);
    });

    // En octubre de 2026 la península está en UTC+2 hasta el domingo 25; después, en UTC+1.
    test('abierto de 8:00 a 22:59, hora peninsular; cerrado de 23:00 a 7:59', () {
      final horario = incibe.horario!;
      bool abiertoA(int hora, int minuto) => horario.abierto(DateTime.utc(2026, 10, 21, hora - 2, minuto));

      expect(abiertoA(7, 59), isFalse);
      expect(abiertoA(8, 0), isTrue);
      expect(abiertoA(12, 30), isTrue);
      expect(abiertoA(22, 59), isTrue);
      expect(abiertoA(23, 0), isFalse);
      expect(horario.abierto(DateTime.utc(2026, 10, 21, 22, 30)), isFalse, reason: '00:30 en la península');
      expect(horario.abierto(DateTime.utc(2026, 10, 22, 3)), isFalse, reason: '05:00 en la península');
    });

    test('en invierno también cuenta la hora peninsular (UTC+1)', () {
      final horario = incibe.horario!;
      expect(horario.abierto(DateTime.utc(2026, 12, 1, 6, 59)), isFalse, reason: '7:59');
      expect(horario.abierto(DateTime.utc(2026, 12, 1, 7)), isTrue, reason: '8:00');
      expect(horario.abierto(DateTime.utc(2026, 12, 1, 21, 59)), isTrue, reason: '22:59');
      expect(horario.abierto(DateTime.utc(2026, 12, 1, 22)), isFalse, reason: '23:00');
    });

    test('en Canarias, a las 22:30 ya está cerrado: en la península son las 23:30', () {
      // 22:30 en Canarias en verano (UTC+1) son las 21:30 UTC.
      expect(incibe.horario!.abierto(DateTime.utc(2026, 7, 1, 21, 30)), isFalse);
      // Y a las 7:30 de Canarias ya está abierto: son las 8:30 en la península.
      expect(incibe.horario!.abierto(DateTime.utc(2026, 7, 1, 6, 30)), isTrue);
    });

    test('da igual la zona horaria del móvil: se usa el mismo instante', () {
      final local = DateTime(2026, 7, 1, 12);
      expect(horaPeninsular(local), horaPeninsular(local.toUtc()));
      expect(incibe.horario!.abierto(local), incibe.horario!.abierto(local.toUtc()));
    });
  });

  group('horaPeninsular', () {
    test('cambia a la hora de verano el último domingo de marzo, a la 1:00 UTC', () {
      expect(horaPeninsular(DateTime.utc(2026, 3, 29, 0, 59)), DateTime.utc(2026, 3, 29, 1, 59));
      expect(horaPeninsular(DateTime.utc(2026, 3, 29, 1)), DateTime.utc(2026, 3, 29, 3));
      expect(horaPeninsular(DateTime.utc(2027, 3, 28, 1)), DateTime.utc(2027, 3, 28, 3));
    });

    test('vuelve a la de invierno el último domingo de octubre, a la 1:00 UTC', () {
      expect(horaPeninsular(DateTime.utc(2026, 10, 25, 0, 59)), DateTime.utc(2026, 10, 25, 2, 59));
      expect(horaPeninsular(DateTime.utc(2026, 10, 25, 1)), DateTime.utc(2026, 10, 25, 2));
      // En 2027 el último domingo de octubre es el día 31.
      expect(horaPeninsular(DateTime.utc(2027, 10, 31, 0, 30)), DateTime.utc(2027, 10, 31, 2, 30));
      expect(horaPeninsular(DateTime.utc(2027, 10, 31, 1, 30)), DateTime.utc(2027, 10, 31, 2, 30));
    });

    test('cambia de día cuando toca', () {
      expect(horaPeninsular(DateTime.utc(2026, 12, 31, 23, 30)), DateTime.utc(2027, 1, 1, 0, 30));
    });
  });

  group('Canal prioritario de la AEPD (sección 2.3)', () {
    List<String> notas(TipoNota tipo) => [
      for (final n in canalPrioritario.notas)
        if (n.tipo == tipo) n.texto,
    ];

    test('sirve para contenido publicado en internet: redes sociales y webs', () {
      expect(notas(TipoNota.sirve).single, allOf(contains('redes sociales'), contains('webs')));
      expect(canalPrioritario.descripcion, allOf(contains('sexuales o violentos'), contains('sin permiso')));
    });

    test('no sirve para WhatsApp, Telegram ni el correo: entonces, policía o Fiscalía', () {
      final no = notas(TipoNota.noSirve).single;
      for (final palabra in ['WhatsApp', 'Telegram', 'correo', 'policía', 'Fiscalía']) {
        expect(no, contains(palabra));
      }
    });

    test('desde los 14 años se puede usar sin un adulto; con menos, con un adulto de confianza', () {
      final info = notas(TipoNota.info).single;
      expect(info, allOf(contains('Desde los 14 años'), contains('sin un adulto'), contains('adulto de confianza')));
    });

    test('lo puede pedir la víctima u otra persona', () {
      expect(canalPrioritario.descripcion, contains('tuyos o de otra persona'));
    });
  });

  test('Canal Joven de la AEPD: 900 293 183, para dudas o problemas de privacidad', () {
    expect(canalJoven.nombre, 'Canal Joven de la AEPD');
    expect(canalJoven.uri, Uri.parse('tel:900293183'));
    expect(canalJoven.descripcion, allOf(contains('Agencia Española de Protección de Datos'), contains('privacidad')));
    expect(canalJoven.horario, isNull);
  });

  group('abrirRecurso', () {
    const canal = MethodChannel('plugins.flutter.io/url_launcher');
    final mensajero = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => mensajero.setMockMethodCallHandler(canal, null));

    List<MethodCall> grabar({bool abre = true}) {
      final llamadas = <MethodCall>[];
      mensajero.setMockMethodCallHandler(canal, (call) async {
        llamadas.add(call);
        return abre;
      });
      return llamadas;
    }

    test('abre el marcador con tel: fuera de la app y devuelve true', () async {
      final llamadas = grabar();

      final abierto = await abrirRecurso(recursosAyuda.first);

      expect(abierto, isTrue);
      final args = llamadas.single.arguments as Map;
      expect(llamadas.single.method, 'launch');
      expect(args['url'], 'tel:900202010');
      expect(args['useWebView'], isFalse);
    });

    test('el Canal Joven se marca como tel:900293183', () async {
      final llamadas = grabar();

      expect(await abrirRecurso(canalJoven), isTrue);
      expect((llamadas.single.arguments as Map)['url'], 'tel:900293183');
    });

    test('la web de la AEPD se abre en el navegador, no dentro de la app', () async {
      final llamadas = grabar();

      await abrirRecurso(canalPrioritario);

      final args = llamadas.single.arguments as Map;
      expect(args['url'], 'https://www.aepd.es/canalprioritario');
      expect(args['useWebView'], isFalse);
    });

    test('el chat de ANAR se abre en el navegador; sin chat devuelve false', () async {
      final llamadas = grabar();

      expect(await abrirChat(recursosAyuda.first), isTrue);
      expect((llamadas.single.arguments as Map)['url'], 'https://chatanar.es');
      expect(await abrirChat(recursosAyuda.singleWhere((r) => r.telefono == '112')), isFalse);
      expect(llamadas, hasLength(1));
    });

    test('el WhatsApp del 017 se abre fuera de la app; sin WhatsApp devuelve false', () async {
      final llamadas = grabar();

      expect(await abrirWhatsapp(incibe), isTrue);
      final args = llamadas.single.arguments as Map;
      expect(args['url'], 'https://wa.me/34900116117');
      expect(args['useWebView'], isFalse);
      expect(await abrirWhatsapp(recursosAyuda.first), isFalse);
      expect(llamadas, hasLength(1));
    });

    test('si no se puede abrir, devuelve false sin lanzar', () async {
      mensajero.setMockMethodCallHandler(canal, (call) async => throw PlatformException(code: 'ACTIVITY_NOT_FOUND'));
      expect(await abrirRecurso(recursosAyuda.first), isFalse);
      expect(await abrirWhatsapp(incibe), isFalse);

      mensajero.setMockMethodCallHandler(canal, (call) async => false);
      expect(await abrirRecurso(recursosAyuda.first), isFalse);
      expect(await abrirWhatsapp(incibe), isFalse);

      // Sin plugin (MissingPluginException).
      mensajero.setMockMethodCallHandler(canal, null);
      expect(await abrirRecurso(recursosAyuda.first), isFalse);
    });
  });
}
