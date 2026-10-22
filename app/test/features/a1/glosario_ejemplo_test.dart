// El glosario de ejemplo (assets/mock/content/glosario.json): es el que enseña la app mientras content/ está vacío.
// Está escrito a partir de docs/MARCO_LEGAL.md y sigue el esquema de la sección 9.6. Son borradores para revisar.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/api/mock_api.dart';
import 'package:tuturno/core/content_models.dart';
import 'package:tuturno/core/content_repo.dart';
import 'package:tuturno/core/texto.dart';

/// Los tests se ejecutan desde app/.
const _ruta = '${ContentRepo.raizEjemplos}/glosario.json';

/// Los términos que necesitan los tres casos oficiales (Lucía, Sergio y Sara).
const _terminosDeLosCasos = [
  'Sala Gesell',
  'Prueba preconstituida',
  'Equipo psicosocial',
  'Citación',
  'Denuncia',
  'Víctima',
  'Testigo',
  'Persona investigada',
  'Fiscalía de Menores',
  'Juez de menores',
  'Medida cautelar',
  'Orden de alejamiento',
  'Conciliación',
  'Defensor judicial',
  'Abogado de oficio',
  'Desamparo',
  'Coordinador de bienestar y protección',
  'Derecho a la propia imagen',
  'Canal prioritario',
  'Responsabilidad penal',
];

/// Normas de docs/MARCO_LEGAL.md, tal como se escriben en «fuente». La AEPD y el INCIBE se citan por su web.
const _normas = {
  'LECrim',
  'LO 5/2000',
  'Ley 4/2015',
  'LOPIVI',
  'LO 1/1996',
  'LO 1/1982',
  'LO 3/1981',
  'Ley 1/1996 de asistencia jurídica gratuita',
  'Código Penal',
  'LOPDGDD',
  'RGPD',
  'CDN',
};
const _webs = {'AEPD', 'INCIBE'};

typedef Cita = ({String norma, List<String> articulos});

/// AssetBundle en memoria. No usa helpers.dart para no depender del resto de la app: aquí solo cuentan los datos.
class _Bundle extends CachingAssetBundle {
  _Bundle(this.ficheros);

  final Map<String, String> ficheros;

  @override
  Future<ByteData> load(String key) async {
    final texto = ficheros[key];
    if (texto == null) throw FlutterError('No existe $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(texto)));
  }
}

/// «LOPIVI, arts. 34.1 y 35; AEPD, Canal prioritario» → LOPIVI [34.1, 35] y AEPD [Canal prioritario].
/// Formato: «Norma, art. X» o «Norma, arts. X, Y y Z»; varias normas, separadas por «; ».
List<Cita> citas(String fuente) => [
  for (final parte in fuente.split('; '))
    if (RegExp(r'^(.+?), (?:(arts?)\. )?(.+)$').firstMatch(parte) case final m?)
      (norma: m.group(1)!, articulos: m.group(3)!.split(RegExp(r', | y ')))
    else
      throw FormatException('La fuente no sigue el formato «Norma, art. X»', parte),
];

void main() {
  final texto = File(_ruta).readAsStringSync();
  final json = jsonDecode(texto) as List<Object?>;
  late List<EntradaGlosario> glosario;

  setUpAll(() async {
    // ContentRepo avisa con debugPrint de que falta assets/content/glosario.json; aquí no hace falta verlo.
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
    try {
      glosario = await ContentRepo(bundle: _Bundle({_ruta: texto}), usarEjemplos: true).glosario();
    } finally {
      debugPrint = original;
    }
  });

  Iterable<String> normalizados(Iterable<String> textos) => textos.map((t) => normalizar(t.trim()));

  test('ContentRepo lo carga como en la app, sin content/, y se ven todos los términos', () {
    // Los 42 de la oleada A (plan v2): unos 40 términos (sección 4.5).
    expect(json.length, inInclusiveRange(42, 45), reason: 'unos 40 términos (sección 4.5)');
    expect(glosario, hasLength(json.length), reason: 'Ninguno se queda fuera por no estar validado o no tener fuente');
  });

  test('los términos salen en orden alfabético, sin que importen las tildes, y el fichero ya está ordenado', () {
    final terminos = [for (final e in glosario) e.termino];
    final ordenados = [...terminos]..sort((a, b) => normalizar(a).compareTo(normalizar(b)));
    expect(terminos, ordenados);
    expect([for (final e in json) (e! as Map)['termino']], terminos, reason: 'Así es más fácil revisarlo');
    expect(terminos.first, 'Abogado de oficio');
    expect(terminos.last, 'Videoconferencia');
  });

  test('sigue el esquema de la sección 9.6 al pie de la letra, con "validado": true', () {
    const campos = {'id', 'termino', 'definicion', 'ejemplo', 'fuente', 'validado'};
    for (final e in json) {
      final entrada = e! as Map<String, Object?>;
      final id = entrada['id'];
      expect(entrada.keys.toSet(), campos, reason: '$id');
      for (final campo in campos.difference({'validado'})) {
        expect(entrada[campo], isA<String>().having((s) => s.trim(), 'sin espacios', isNotEmpty), reason: '$id.$campo');
      }
      expect(entrada['validado'], isTrue, reason: '$id');
      expect(id, matches(RegExp(r'^G-[a-z0-9]+(-[a-z0-9]+)*$')));
    }
  });

  test('ids y términos no se repiten; Citación conserva su id', () {
    expect({for (final e in glosario) e.id}, hasLength(glosario.length));
    expect(normalizados(glosario.map((e) => e.termino)).toSet(), hasLength(glosario.length));
    expect(glosario.singleWhere((e) => e.id == 'G-citacion').termino, 'Citación');
  });

  test('tiene los términos que necesitan los tres casos oficiales', () {
    expect(normalizados(glosario.map((e) => e.termino)), containsAll(normalizados(_terminosDeLosCasos)));
  });

  test('los términos de la respuesta de ejemplo de Pregunta están, así se pueden subrayar y abrir', () {
    final terminos = (MockTuTurnoApi.ejemploAsk['terminos']! as List).cast<String>();
    expect(normalizados(glosario.map((e) => e.termino)), containsAll(normalizados(terminos)));
  });

  test('cada fuente cita artículos de normas del marco legal («LECrim, art. 449 ter»)', () {
    for (final entrada in glosario) {
      for (final parte in entrada.fuente.split('; ')) {
        final cita = citas(parte).single;
        final esWeb = _webs.contains(cita.norma);
        expect(_normas.contains(cita.norma) || esWeb, isTrue, reason: '${entrada.termino}: ${cita.norma}');
        expect(cita.articulos.every((a) => a.trim().isNotEmpty), isTrue, reason: '${entrada.termino}: $parte');
        if (!esWeb) {
          // «art.» con uno, «arts.» con varios.
          expect(parte, contains(cita.articulos.length == 1 ? ', art. ' : ', arts. '), reason: entrada.termino);
        }
      }
    }
  });

  // Con `DOCS=<carpeta>` se comprueba con otra copia de docs/ (por ejemplo, la de main).
  final marcoLegal = _marcoLegal();
  test('cada artículo citado está en docs/MARCO_LEGAL.md', () {
    final encabezados = marcoLegal!.split('\n').where((l) => l.startsWith('### ')).toList();
    for (final entrada in glosario) {
      for (final cita in citas(entrada.fuente)) {
        for (final articulo in cita.articulos) {
          final patron = RegExp('(?<![\\w.])${RegExp.escape(articulo)}(?!\\w)');
          final esta = encabezados.any(
            (e) => e.contains(cita.norma) && patron.hasMatch(e.replaceFirst(cita.norma, '')),
          );
          expect(esta, isTrue, reason: '${entrada.termino}: «${cita.norma}, $articulo» no está en docs/MARCO_LEGAL.md');
        }
      }
    }
  }, skip: marcoLegal == null ? 'No se encuentra docs/MARCO_LEGAL.md' : null);

  group('textos para alguien de 11 años', () {
    List<String> frases(String texto) => texto.split(RegExp(r'(?<=[.!?])\s+')).where((f) => f.isNotEmpty).toList();
    int palabras(String texto) => texto.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).length;

    test('definiciones y ejemplos cortos, con frases cortas', () {
      for (final e in glosario) {
        for (final (campo, texto) in [('definicion', e.definicion), ('ejemplo', e.ejemplo)]) {
          expect(palabras(texto), lessThanOrEqualTo(40), reason: '${e.termino}.$campo');
          for (final frase in frases(texto)) {
            expect(palabras(frase), lessThanOrEqualTo(25), reason: '${e.termino}.$campo: $frase');
          }
        }
      }
    });

    test('sin promesas ni preguntas sobre lo que pasó (sección 2.3)', () {
      const prohibidas = [
        'siempre gratis',
        'carcel',
        'prision',
        '24 horas',
        '¿que paso',
        '¿que te paso',
        '¿que ha pasado',
        'cuentame',
        'te prometo',
        'seguro que',
      ];
      for (final e in glosario) {
        final texto = normalizar('${e.definicion} ${e.ejemplo}');
        for (final prohibida in prohibidas) {
          expect(texto, isNot(contains(prohibida)), reason: '${e.termino}: $prohibida');
        }
      }
    });

    EntradaGlosario termino(String nombre) => glosario.singleWhere((e) => e.termino == nombre);

    test('abogado de oficio: gratis en los casos que marca la ley, no siempre', () {
      final abogado = termino('Abogado de oficio');
      expect(abogado.definicion, contains('Es gratis en los casos que marca la ley'));
      expect(abogado.ejemplo, contains('depende de los ingresos de la familia'));
    });

    test('Canal prioritario: redes sociales y webs, no WhatsApp ni Telegram; desde los 14 años, sin un adulto', () {
      final canal = termino('Canal prioritario');
      expect(canal.definicion, allOf(contains('redes sociales y webs'), contains('no para WhatsApp, Telegram')));
      expect(canal.ejemplo, contains('más de 14 años'));
    });

    test('responsabilidad penal: de 14 a 17, la ley de menores, con medidas y no penas; con menos de 14, no hay', () {
      final responsabilidad = termino('Responsabilidad penal');
      expect(
        responsabilidad.definicion,
        allOf(contains('De 14 a 17 años'), contains('medidas, no penas'), contains('Con menos de 14')),
      );
      expect(responsabilidad.ejemplo, contains('protección de menores'));
    });

    test('Sala Gesell y prueba preconstituida: se graba y, normalmente, no hay que repetirlo', () {
      expect(termino('Sala Gesell').definicion, allOf(contains('se graba'), contains('persona investigada')));
      expect(termino('Prueba preconstituida').ejemplo, contains('normalmente'));
    });

    test('desamparo: la regla es seguir con la familia, sin prometer nada a Lucía', () {
      final desamparo = termino('Desamparo');
      expect(desamparo.ejemplo, contains('seguir viviendo en casa'));
      expect(desamparo.ejemplo, isNot(contains('Lucía')));
    });

    test('con Lucía no se da nada por hecho: ni sobre su familia ni sobre lo que decida el juez', () {
      final deLucia = glosario.where((e) => e.ejemplo.contains('Lucía')).toList();
      expect(deLucia, isNotEmpty);
      for (final e in deLucia) {
        final ejemplo = normalizar(e.ejemplo);
        for (final palabra in ['madre', 'padre', 'culpa', 'castig']) {
          expect(ejemplo, isNot(contains(palabra)), reason: '${e.termino}: $palabra');
        }
      }
      // Lo que decide el juez se cuenta como posibilidad (LECrim, art. 449 ter: «podrá acordar»).
      expect(termino('Equipo psicosocial').ejemplo, contains('puede'));
      expect(termino('Defensor judicial').definicion, contains('por ejemplo'));
    });

    test('las medidas para proteger a Sergio dependen del juez: se cuentan con «puede» o «si»', () {
      expect(termino('Medida cautelar').definicion, contains('puede'));
      expect(termino('Juez de menores').ejemplo, startsWith('Si la Fiscalía se lo pide'));
      expect(termino('Orden de alejamiento').ejemplo, startsWith('Si el juez la pone'));
    });
  });
}

/// docs/MARCO_LEGAL.md, o null si no está (por ejemplo, si solo se copia app/). Con `DOCS=<carpeta>`, esa copia.
String? _marcoLegal() {
  final carpeta = Platform.environment['DOCS'];
  final rutas = [if (carpeta != null) '$carpeta/MARCO_LEGAL.md', '../docs/MARCO_LEGAL.md', 'docs/MARCO_LEGAL.md'];
  return rutas.map(File.new).where((f) => f.existsSync()).firstOrNull?.readAsStringSync();
}
