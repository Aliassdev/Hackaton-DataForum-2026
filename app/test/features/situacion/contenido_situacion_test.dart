import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/texto.dart';
import 'package:tuturno/features/pasos/fuentes_paso.dart';

// El contenido nuevo de «Mi situación» (assets/mock/content/situacion/) contra docs/MARCO_LEGAL.md: cada fuente tiene
// que estar allí (la norma y el artículo), cada elemento validado, las afirmaciones jurídicas con fuente y los
// consejos marcados como consejos. Y las reglas de la capa justicia en el código: sin mazo ni balanza, sin «tu
// expediente», sin sellos que caen, XP ni confeti en Mi situación.

const _carpeta = 'assets/mock/content/situacion';
final _ficheros = ['derechos', 'preocupaciones', 'pasos', 'notas'];

Object? _json(String ruta) => jsonDecode(File(ruta).readAsStringSync());

/// Encabezados de MARCO_LEGAL: «LECrim, art. 449 ter, párr. 1», «LOPIVI (LO 8/2021), art. 14.1 y 14.3 · …».
final List<String> _encabezados = [
  for (final linea in File('../docs/MARCO_LEGAL.md').readAsLinesSync())
    if (linea.startsWith('### ')) linea.substring(4).trim(),
];

/// Cómo empieza en MARCO_LEGAL cada norma que se cita.
const _normas = {
  'lopivi': 'lopivi',
  'ley 4/2015': 'ley 4/2015',
  'lo 3/1981': 'lo 3/1981',
  'lec': 'lec (ley 1/2000)',
  'lopdgdd': 'lopdgdd',
  'ce': 'ce (constitucion espanola)',
  'aepd': 'aepd',
  'incibe': 'incibe',
  'lecrim': 'lecrim',
  'lo 5/2000': 'lo 5/2000',
  'lo 1/1996': 'lo 1/1996',
  'lo 1/1982': 'lo 1/1982',
  'cdn': 'cdn',
  'ley 1/1996 de asistencia juridica gratuita': 'ley 1/1996 de asistencia juridica gratuita',
};

/// null si la fuente está en MARCO_LEGAL; si no, por qué.
String? _comprobar(String fuente) {
  final cita = CitaPaso.desdeTexto(fuente);
  final norma = normalizar(cita.norma);
  final prefijo = _normas[norma];
  if (prefijo == null) return 'norma desconocida: ${cita.norma}';
  final candidatos = [
    for (final e in _encabezados)
      if (normalizar(e).startsWith(prefijo)) normalizar(e),
  ];
  if (candidatos.isEmpty) return 'no hay encabezados de ${cita.norma}';
  final detalle = normalizar(cita.detalle);
  if (norma == 'aepd' || norma == 'incibe') {
    return candidatos.any((e) => e.contains(detalle)) ? null : 'no está «${cita.detalle}»';
  }
  final articulos = detalle
      .replaceAll(RegExp(r'parrs?\.\s*\d+'), '')
      .replaceFirst(RegExp(r'^arts?\.\s*'), '')
      .split(RegExp(r'\s+y\s+|,\s*'))
      .map((a) => a.trim().replaceAll(RegExp(r'\)$'), '').trim())
      .where((a) => a.isNotEmpty);
  for (final articulo in articulos) {
    final patron = RegExp('(?<![\\d.])${RegExp.escape(articulo).replaceAll(r'\ ', r'\s')}(?![\\d])');
    final esta = candidatos.any((e) {
      final coma = e.indexOf(',');
      return patron.hasMatch(coma < 0 ? e : e.substring(coma));
    });
    if (!esta) return 'no está el art. «$articulo»';
  }
  return null;
}

/// Todas las listas «fuentes» de [dato], con dónde están.
Iterable<(String, String)> _fuentes(Object? dato, [String ruta = '']) sync* {
  if (dato is Map) {
    for (final MapEntry(:key, :value) in dato.entries) {
      if (key == 'fuentes' && value is List) {
        for (final f in value) {
          yield (ruta, f as String);
        }
      } else {
        yield* _fuentes(value, '$ruta/$key');
      }
    }
  } else if (dato is List) {
    for (final (i, v) in dato.indexed) {
      yield* _fuentes(v, '$ruta[$i]');
    }
  }
}

/// Los elementos con texto (derechos, puntos, notas, «para ti»): tienen que estar validados y, si no son consejos,
/// tener fuente.
Iterable<(String, Map<String, dynamic>)> _elementos(Object? dato, [String ruta = '']) sync* {
  if (dato is Map<String, dynamic>) {
    if (dato['texto'] is String && !ruta.contains('/llevar/')) yield (ruta, dato);
    for (final MapEntry(:key, :value) in dato.entries) {
      yield* _elementos(value, '$ruta/$key');
    }
  } else if (dato is List) {
    for (final (i, v) in dato.indexed) {
      yield* _elementos(v, '$ruta[$i]');
    }
  }
}

/// Los textos que se enseñan (para buscar palabras prohibidas).
Iterable<String> _textos(Object? dato) sync* {
  if (dato is String) {
    yield dato;
  } else if (dato is Map) {
    for (final MapEntry(:key, :value) in dato.entries) {
      if (key != 'nota') yield* _textos(value);
    }
  } else if (dato is List) {
    for (final v in dato) {
      yield* _textos(v);
    }
  }
}

void main() {
  test('la comprobación de fuentes rechaza lo que no está en MARCO_LEGAL', () {
    expect(_comprobar('LO 1/1996, art. 9.1'), isNull);
    expect(_comprobar('LECrim, art. 449 ter, párr. 3'), isNull);
    expect(_comprobar('AEPD, FAQ 15.03'), isNull);
    expect(_comprobar('LO 1/1996, art. 99'), isNotNull);
    expect(_comprobar('LECrim, art. 449 quater'), isNotNull);
    expect(_comprobar('LOPIVI, art. 50.2.z)'), isNotNull);
    expect(_comprobar('AEPD, Canal secreto'), isNotNull);
    expect(_comprobar('Ley inventada, art. 1'), isNotNull);
  });

  for (final fichero in _ficheros) {
    group('$fichero.json', () {
      final datos = _json('$_carpeta/$fichero.json');

      test('está validado y cada fuente está en docs/MARCO_LEGAL.md, con su artículo y su nombre fácil', () {
        expect((datos! as Map)['validado'], isTrue);
        final fuentes = _fuentes(datos).toList();
        expect(fuentes, isNotEmpty);
        for (final (ruta, fuente) in fuentes) {
          expect(_comprobar(fuente), isNull, reason: '$fichero$ruta: «$fuente»');
          final cita = CitaPaso.desdeTexto(fuente);
          expect(cita.detalle, isNotEmpty, reason: '$fichero$ruta: «$fuente» no dice el artículo');
          expect(nombreFacilDeNorma(cita.norma), isNotNull, reason: '$fichero$ruta: no se conoce «${cita.norma}»');
        }
      });

      test('cada elemento está validado y, si no es un consejo, tiene fuente', () {
        for (final (ruta, elemento) in _elementos(datos)) {
          expect(elemento['validado'], isTrue, reason: '$fichero$ruta');
          final consejo = elemento['consejo'] == true;
          final fuentes = (elemento['fuentes'] as List?) ?? const [];
          expect(consejo || fuentes.isNotEmpty, isTrue, reason: '$fichero$ruta: afirmación sin fuente');
          expect(!consejo || fuentes.isEmpty, isTrue, reason: '$fichero$ruta: un consejo no lleva fuente jurídica');
        }
      });

      // «culpable» sí puede salir: es el derecho a no tener que decir que lo eres (CE, art. 24.2), no un juego.
      test('no dice «tu expediente», no promete, no pregunta qué pasó y no usa palabras de juego', () {
        final prohibidas = [
          'tu expediente',
          'te creerán',
          'no tendrás que ver',
          'todo saldrá bien',
          'será rápido',
          'es secreto',
          'nadie lo verá',
          'confidencial',
          '¿qué pasó',
          '¿qué te pasó',
          'cuéntame qué',
          'veredicto',
          'caso cerrado',
          'mazo',
        ];
        for (final texto in _textos(datos)) {
          final t = texto.toLowerCase();
          for (final palabra in prohibidas) {
            expect(t, isNot(contains(palabra)), reason: '«$texto»');
          }
        }
      });
    });
  }

  test('las palabras de cada paso están en el glosario y los pasos existen en su itinerario', () {
    final glosario = {
      for (final e in _json('assets/mock/content/glosario.json')! as List) normalizar((e as Map)['termino'] as String),
    };
    final pasos = (_json('$_carpeta/pasos.json')! as Map)['papeles'] as Map;
    for (final MapEntry(key: papel, value: porPaso) in pasos.entries) {
      final itinerario = _json('assets/mock/content/itinerarios/$papel.json')! as Map;
      final ids = {for (final p in itinerario['pasos'] as List) (p as Map)['id']};
      for (final MapEntry(key: id, value: extras) in (porPaso as Map).entries) {
        expect(ids, contains(id), reason: '$papel/$id no está en itinerarios/$papel.json');
        for (final palabra in ((extras as Map)['palabras'] as List?) ?? const []) {
          expect(
            glosario,
            contains(normalizar(palabra as String)),
            reason: '$papel/$id: «$palabra» no está en el glosario',
          );
        }
        for (final cosa in (extras['llevar'] as List?) ?? const []) {
          expect(((_json('$_carpeta/pasos.json')! as Map)['llevar'] as Map).keys, contains(cosa), reason: '$papel/$id');
        }
      }
    }
  });

  group('capa justicia en el código de Mi situación', () {
    final codigo = {
      for (final carpeta in ['lib/features/situacion', 'lib/features/pasos', 'lib/features/mis_preguntas'])
        for (final f in Directory(carpeta).listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.dart')) f.path: f.readAsStringSync(),
      'lib/widgets/justicia/expediente_caratula.dart': File('lib/widgets/justicia/expediente_caratula.dart')
          .readAsStringSync(),
    };

    test('ni el mazo (Icons.gavel_rounded) ni la balanza (Icons.balance_rounded)', () {
      for (final MapEntry(key: ruta, value: texto) in codigo.entries) {
        expect(texto, isNot(contains('Icons.gavel')), reason: ruta);
        expect(texto, isNot(contains('Icons.balance')), reason: ruta);
      }
    });

    test('nunca «tu expediente» en lo que se enseña (LO 5/2000, art. 16): la carátula dice «TU GUÍA»', () {
      for (final MapEntry(key: ruta, value: texto) in codigo.entries) {
        // Solo en los comentarios se explica por qué no se usa.
        final sinComentarios = texto.split('\n').where((l) => !l.trimLeft().startsWith('//')).join('\n');
        expect(sinComentarios.toLowerCase(), isNot(contains("'tu expediente")), reason: ruta);
        expect(sinComentarios.toLowerCase(), isNot(contains('«tu expediente»')), reason: ruta);
      }
      expect(codigo['lib/widgets/justicia/expediente_caratula.dart'], contains("this.etiqueta = 'TU GUÍA'"));
    });

    test('Mi situación no se gamifica: sin sellos que caen, XP, rachas ni confeti', () {
      for (final MapEntry(key: ruta, value: texto) in codigo.entries) {
        for (final prohibido in [
          'SelloAnimado',
          'SelloJusticia',
          'lanzarConfeti',
          'ConfetiPapel',
          'progresoProvider',
          'Hapticos.sello',
        ]) {
          expect(texto, isNot(contains(prohibido)), reason: '$ruta usa $prohibido');
        }
      }
    });
  });
}
