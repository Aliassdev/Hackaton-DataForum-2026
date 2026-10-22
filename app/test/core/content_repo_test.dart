import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/content_models.dart';
import 'package:tuturno/core/content_repo.dart';

/// AssetBundle en memoria que apunta cada lectura.
class _BundleEnMemoria extends AssetBundle {
  _BundleEnMemoria(this.ficheros);

  final Map<String, String> ficheros;
  final lecturas = <String>[];

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(utf8.encode(await loadString(key)));

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    lecturas.add(key);
    // Como rootBundle: un asset que no existe lanza.
    return ficheros[key] ?? (throw FlutterError('Unable to load asset: "$key".'));
  }
}

const _real = '${ContentRepo.raiz}/glosario.json';
const _ejemplo = '${ContentRepo.raizEjemplos}/glosario.json';

String _entrada(String id, String termino, {bool validado = true, String? fuente = 'A-060'}) => jsonEncode({
  'id': id,
  'termino': termino,
  'definicion': 'Definición de $termino.',
  'ejemplo': 'Ejemplo de $termino.',
  'fuente': ?fuente,
  'validado': validado,
});

String _glosario(List<String> entradas) => '[${entradas.join(',')}]';

void main() {
  late DebugPrintCallback debugPrintOriginal;

  // ContentRepo avisa con debugPrint cuando falta un fichero; aquí no hace falta verlo.
  setUp(() {
    debugPrintOriginal = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
  });
  tearDown(() => debugPrint = debugPrintOriginal);

  List<String> terminos(List<EntradaGlosario> entradas) => [for (final e in entradas) e.termino];

  group('validado', () {
    test('solo devuelve las entradas validadas', () async {
      final bundle = _BundleEnMemoria({
        _real: _glosario([
          _entrada('G-citacion', 'Citación'),
          _entrada('G-prueba', 'Prueba preconstituida', validado: false),
          _entrada('G-fiscal', 'Fiscal'),
        ]),
      });

      final glosario = await ContentRepo(bundle: bundle).glosario();

      expect(terminos(glosario), ['Citación', 'Fiscal']);
      expect(glosario.every((e) => e.validado), isTrue);
    });

    test('"validado" tiene que ser true de verdad (no "true" ni 1)', () async {
      final bundle = _BundleEnMemoria({
        _real:
            '[{"id": "G-a", "termino": "A", "definicion": "d", "fuente": "A-1", "validado": "true"},'
            '{"id": "G-b", "termino": "B", "definicion": "d", "fuente": "A-1", "validado": 1},'
            '{"id": "G-c", "termino": "C", "definicion": "d", "fuente": "A-1"}]',
      });

      expect(await ContentRepo(bundle: bundle).glosario(), isEmpty);
    });

    test('contenido jurídico sin fuente no se enseña aunque esté validado', () async {
      final bundle = _BundleEnMemoria({
        _real: _glosario([
          _entrada('G-a', 'Abogado', fuente: null),
          _entrada('G-b', 'Bienestar', fuente: '  '),
          _entrada('G-c', 'Citación'),
        ]),
      });

      expect(terminos(await ContentRepo(bundle: bundle).glosario()), ['Citación']);
    });

    test('con mostrarBorradores (modo DEMO) también salen los borradores', () async {
      final bundle = _BundleEnMemoria({
        _real: _glosario([
          _entrada('G-citacion', 'Citación'),
          _entrada('G-prueba', 'Prueba preconstituida', validado: false),
          _entrada('G-sin-fuente', 'Sala Gesell', validado: false, fuente: null),
        ]),
      });

      final glosario = await ContentRepo(bundle: bundle, mostrarBorradores: true).glosario();

      expect(terminos(glosario), ['Citación', 'Prueba preconstituida', 'Sala Gesell']);
    });
  });

  group('ficheros de ejemplo (USE_MOCK)', () {
    final ejemplo = _glosario([_entrada('G-ejemplo', 'Ejemplo')]);

    test('si falta el real y usarEjemplos, usa assets/mock/content', () async {
      final bundle = _BundleEnMemoria({_ejemplo: ejemplo});

      final glosario = await ContentRepo(bundle: bundle, usarEjemplos: true).glosario();

      expect(terminos(glosario), ['Ejemplo']);
      expect(bundle.lecturas, [_real, _ejemplo]);
    });

    test('sin usarEjemplos nunca mira los de ejemplo', () async {
      final bundle = _BundleEnMemoria({_ejemplo: ejemplo});

      expect(await ContentRepo(bundle: bundle).glosario(), isEmpty);
      expect(bundle.lecturas, [_real]);
    });

    test('si el real existe, se usa el real aunque haya ejemplos', () async {
      final bundle = _BundleEnMemoria({
        _real: _glosario([_entrada('G-real', 'Real')]),
        _ejemplo: ejemplo,
      });

      final glosario = await ContentRepo(bundle: bundle, usarEjemplos: true).glosario();

      expect(terminos(glosario), ['Real']);
      expect(bundle.lecturas, [_real]);
    });

    test('si el real está roto y usarEjemplos, también recurre a los de ejemplo', () async {
      final bundle = _BundleEnMemoria({_real: '[{"id": ', _ejemplo: ejemplo});

      expect(terminos(await ContentRepo(bundle: bundle, usarEjemplos: true).glosario()), ['Ejemplo']);
    });
  });

  group('ficheros que faltan o están mal', () {
    test('fichero que no existe → lista vacía (no lanza)', () async {
      expect(await ContentRepo(bundle: _BundleEnMemoria({})).glosario(), isEmpty);
      expect(await ContentRepo(bundle: _BundleEnMemoria({}), usarEjemplos: true).glosario(), isEmpty);
    });

    test('JSON mal formado → lista vacía (no lanza)', () async {
      for (final roto in ['[{"id": "G-a",', '', 'no es json', '{"a": }']) {
        expect(await ContentRepo(bundle: _BundleEnMemoria({_real: roto})).glosario(), isEmpty, reason: roto);
      }
    });

    test('JSON que no es una lista → lista vacía', () async {
      for (final otro in ['{"id": "G-a"}', '"glosario"', 'null', '42']) {
        expect(await ContentRepo(bundle: _BundleEnMemoria({_real: otro})).glosario(), isEmpty, reason: otro);
      }
    });

    test('una entrada mal formada se salta y no deja sin glosario al resto', () async {
      final bundle = _BundleEnMemoria({
        _real:
            '[${_entrada('G-citacion', 'Citación')},'
            '{"id": "G-roto", "definicion": "Falta el término", "fuente": "A-1", "validado": true},'
            '{"id": 7, "termino": "Id que no es texto", "definicion": "d", "fuente": "A-1", "validado": true},'
            '"no soy un objeto", null, 3,'
            '${_entrada('G-fiscal', 'Fiscal')}]',
      });

      expect(terminos(await ContentRepo(bundle: bundle).glosario()), ['Citación', 'Fiscal']);
    });
  });

  test('ordena alfabéticamente sin que importen tildes ni mayúsculas', () async {
    final bundle = _BundleEnMemoria({
      _real: _glosario([
        _entrada('G-1', 'Órgano judicial'),
        _entrada('G-2', 'juez o jueza'),
        _entrada('G-3', 'Abogado'),
        _entrada('G-4', 'Ámbito'),
        _entrada('G-5', 'Fiscalía de Menores'),
        _entrada('G-6', 'Ofendido'),
        _entrada('G-7', 'Fiscal'),
      ]),
    });

    final glosario = await ContentRepo(bundle: bundle).glosario();

    expect(terminos(glosario), [
      'Abogado',
      'Ámbito',
      'Fiscal',
      'Fiscalía de Menores',
      'juez o jueza',
      'Ofendido',
      'Órgano judicial',
    ]);
  });

  group('caché en memoria', () {
    test('el fichero se lee una sola vez aunque se pida varias veces', () async {
      final bundle = _BundleEnMemoria({
        _real: _glosario([_entrada('G-citacion', 'Citación')]),
      });
      final repo = ContentRepo(bundle: bundle);

      await repo.glosario();
      await repo.glosario();

      expect(bundle.lecturas, [_real]);
    });

    test('dos pantallas que lo piden a la vez comparten la misma lectura', () async {
      final bundle = _BundleEnMemoria({
        _real: _glosario([_entrada('G-citacion', 'Citación')]),
      });
      final repo = ContentRepo(bundle: bundle);

      final resultados = await Future.wait([repo.glosario(), repo.glosario(), repo.glosario()]);

      expect(bundle.lecturas, [_real]);
      expect(resultados.map(terminos), everyElement(['Citación']));
    });

    test('un fichero que falta tampoco se vuelve a buscar', () async {
      final bundle = _BundleEnMemoria({});
      final repo = ContentRepo(bundle: bundle, usarEjemplos: true);

      await repo.glosario();
      await repo.glosario();

      expect(bundle.lecturas, [_real, _ejemplo]);
    });

    test('cada lista es nueva: cambiarla no estropea la caché', () async {
      final bundle = _BundleEnMemoria({
        _real: _glosario([_entrada('G-citacion', 'Citación')]),
      });
      final repo = ContentRepo(bundle: bundle);

      (await repo.glosario()).clear();

      expect(terminos(await repo.glosario()), ['Citación']);
    });
  });

  group('EntradaGlosario.fromJson (sección 9.6)', () {
    test('lee el ejemplo del documento', () {
      final e = EntradaGlosario.fromJson(
        jsonDecode(
          '{"id": "G-citacion", "termino": "Citación",'
          ' "definicion": "Documento del juzgado que te dice cuándo y dónde tienes que ir.",'
          ' "ejemplo": "A Lucía le llegó una citación para declarar como testigo.",'
          ' "fuente": "A-060", "validado": true}',
        ) as Map<String, dynamic>,
      );

      expect(e.id, 'G-citacion');
      expect(e.termino, 'Citación');
      expect(e.definicion, 'Documento del juzgado que te dice cuándo y dónde tienes que ir.');
      expect(e.ejemplo, 'A Lucía le llegó una citación para declarar como testigo.');
      expect(e.fuente, 'A-060');
      expect(e.validado, isTrue);
    });

    test('sin ejemplo ni fuente → textos vacíos; sin validado → false', () {
      final e = EntradaGlosario.fromJson({'id': 'G-a', 'termino': 'A', 'definicion': 'd'});

      expect([e.ejemplo, e.fuente], ['', '']);
      expect(e.validado, isFalse);
    });
  });
}
