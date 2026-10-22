import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/api/mock_api.dart';
import 'package:tuturno/core/content_repo.dart';
import 'package:tuturno/core/progreso.dart';
import 'package:tuturno/core/texto.dart';
import 'package:tuturno/features/aprende/curso.dart';
import 'package:tuturno/features/aprende/modelos.dart';
import 'package:tuturno/features/aprende/textos.dart';

import 'ayudantes.dart';

/// Ejemplo de la sección 9.2, tal cual.
const _unidad92 = '''
{
  "id": "U1",
  "titulo": "Tus derechos",
  "conceptos": ["C-ser-oido", "C-fiscalia", "C-defensor", "C-abogado-gratis", "C-comunicar-violencia"],
  "lecciones": [
    {"id": "U1-L1", "titulo": "Que te escuchen", "ejercicios": ["E-001", "E-002", "E-003", "E-004", "E-005", "E-006"]}
  ],
  "validado": true
}
''';

/// Ejemplo de la sección 9.3, tal cual.
const _ejercicios93 = '''
[
  {"id": "E-001", "tipo": "eleccion", "concepto": "C-ser-oido", "dificultad": 1,
   "pregunta": "¿A partir de qué edad la ley da por hecho que tienes madurez para ser oído?",
   "opciones": ["10 años", "12 años", "16 años"], "correcta": 1,
   "explicacion": "A partir de los 12. Y si eres más pequeño, también te escuchan si tienes madurez suficiente.",
   "fuente": "A-003", "validado": true},

  {"id": "E-002", "tipo": "vf", "concepto": "C-defensor", "dificultad": 1,
   "afirmacion": "Para quejarte al Defensor del Pueblo necesitas que te acompañe un adulto.",
   "correcta": false,
   "explicacion": "Ser menor no impide presentar una queja.",
   "fuente": "A-021", "validado": true},

  {"id": "E-003", "tipo": "ordenar", "concepto": "C-proceso", "dificultad": 2,
   "enunciado": "Ordena los pasos de un proceso penal",
   "pasos": ["Denuncia", "Investigación", "Juicio", "Sentencia"],
   "fuente": "A-030", "validado": true},

  {"id": "E-004", "tipo": "emparejar", "concepto": "C-personas", "dificultad": 2,
   "pares": [["Juez o jueza", "Decide"], ["Fiscal", "Acusa y vela por los derechos del menor"]],
   "fuente": "A-031", "validado": true},

  {"id": "E-005", "tipo": "dilo", "concepto": "C-ser-oido", "dificultad": 3,
   "pregunta": "Explica con tus palabras qué significa el derecho a ser oído.",
   "proposiciones": [
     "Tienes derecho a que te escuchen en lo que te afecta",
     "Tu opinión se tiene en cuenta según tu edad y madurez",
     "A partir de los 12 años se da por hecho que tienes madurez"
   ],
   "fuente": "A-003", "validado": true}
]
''';

const _lecciones = '${ContentRepo.raiz}/lecciones';
const _ejercicios = '${ContentRepo.raiz}/ejercicios';

String _vf(String id, {bool validado = true, String fuente = 'LO 1/1996, art. 9'}) => jsonEncode({
  'id': id,
  'tipo': 'vf',
  'concepto': 'C-ser-oido',
  'dificultad': 1,
  'afirmacion': 'Afirmación $id',
  'correcta': true,
  'explicacion': '',
  'fuente': fuente,
  'validado': validado,
});

String _unidad(String id, List<List<String>> lecciones, {bool validado = true}) => jsonEncode({
  'id': id,
  'titulo': 'Unidad $id',
  'conceptos': ['C-ser-oido'],
  'lecciones': [
    for (final (i, ejercicios) in lecciones.indexed)
      {'id': '$id-L${i + 1}', 'titulo': 'Lección ${i + 1} de $id', 'ejercicios': ejercicios},
  ],
  'validado': validado,
});

void main() {
  late DebugPrintCallback debugPrintOriginal;
  setUp(() {
    debugPrintOriginal = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
  });
  tearDown(() => debugPrint = debugPrintOriginal);

  group('esquemas de la sección 9', () {
    test('lee la unidad del ejemplo 9.2', () {
      final unidad = Unidad.fromJson(jsonDecode(_unidad92))!;
      expect(unidad.id, 'U1');
      expect(unidad.titulo, 'Tus derechos');
      expect(unidad.conceptos, hasLength(5));
      expect(unidad.validado, isTrue);
      expect(unidad.lecciones.single.id, 'U1-L1');
      expect(unidad.lecciones.single.titulo, 'Que te escuchen');
      expect(unidad.lecciones.single.ejercicios, ['E-001', 'E-002', 'E-003', 'E-004', 'E-005', 'E-006']);
    });

    test('lee los cinco tipos de ejercicio del ejemplo 9.3', () {
      final ejercicios = [for (final e in jsonDecode(_ejercicios93) as List) Ejercicio.fromJson(e)!];
      expect([for (final e in ejercicios) e.tipo], TipoEjercicio.values);
      expect(ejercicios.every((e) => e.validado && e.fuente.isNotEmpty), isTrue);

      final eleccion = ejercicios[0] as EjercicioEleccion;
      expect(eleccion.concepto, 'C-ser-oido');
      expect(eleccion.dificultad, 1);
      expect(eleccion.opciones, ['10 años', '12 años', '16 años']);
      expect(eleccion.esCorrecta(1), isTrue);
      expect(eleccion.esCorrecta(0), isFalse);
      expect(eleccion.explicacion, startsWith('A partir de los 12'));
      expect(eleccion.fuente, 'A-003');

      final vf = ejercicios[1] as EjercicioVf;
      expect(vf.esCorrecta(false), isTrue);
      expect(vf.esCorrecta(true), isFalse);

      final ordenar = ejercicios[2] as EjercicioOrdenar;
      expect(ordenar.enunciado, 'Ordena los pasos de un proceso penal');
      expect(ordenar.esCorrecta([0, 1, 2, 3]), isTrue);
      expect(ordenar.esCorrecta([1, 0, 2, 3]), isFalse);
      expect(ordenar.explicacion, isEmpty);

      final emparejar = ejercicios[3] as EjercicioEmparejar;
      expect(emparejar.pares, [('Juez o jueza', 'Decide'), ('Fiscal', 'Acusa y vela por los derechos del menor')]);
      expect(emparejar.esCorrecta({0: 0, 1: 1}), isTrue);
      expect(emparejar.esCorrecta({0: 1, 1: 0}), isFalse);
      expect(emparejar.esCorrecta({0: 0}), isFalse);

      final dilo = ejercicios[4] as EjercicioDilo;
      expect(dilo.dificultad, 3);
      expect(dilo.proposiciones, hasLength(3));
    });

    test('lo que no se puede jugar se descarta', () {
      Map<String, dynamic> base(Map<String, dynamic> resto) => {
        'id': 'E-1',
        'concepto': 'C-x',
        'dificultad': 1,
        'fuente': 'LO 1/1996, art. 9',
        'validado': true,
        ...resto,
      };
      final malos = [
        base({
          'tipo': 'eleccion',
          'pregunta': '¿?',
          'opciones': ['a', 'b'],
          'correcta': 2,
        }),
        base({
          'tipo': 'eleccion',
          'pregunta': '¿?',
          'opciones': ['a'],
          'correcta': 0,
        }),
        base({'tipo': 'vf', 'afirmacion': 'x', 'correcta': 'false'}),
        base({
          'tipo': 'ordenar',
          'enunciado': 'x',
          'pasos': ['a', 'a', 'b'],
        }),
        base({
          'tipo': 'ordenar',
          'enunciado': 'x',
          'pasos': ['a'],
        }),
        base({
          'tipo': 'emparejar',
          'pares': [
            ['a', 'b', 'c'],
            ['d', 'e'],
          ],
        }),
        base({
          'tipo': 'emparejar',
          'pares': [
            ['a', 'b'],
            ['a', 'c'],
          ],
        }),
        base({'tipo': 'dilo', 'pregunta': 'x', 'proposiciones': []}),
        base({'tipo': 'otro'}),
        {'tipo': 'vf', 'concepto': 'C-x', 'afirmacion': 'x', 'correcta': true},
        'no es un objeto',
      ];
      for (final malo in malos) {
        expect(Ejercicio.fromJson(malo), isNull, reason: '$malo');
      }
      expect(Unidad.fromJson({'id': 'U1', 'titulo': 'Sin lecciones'}), isNull);
    });

    test('la dificultad se queda entre 1 y 3 y «validado» tiene que ser true de verdad', () {
      final e = Ejercicio.fromJson({
        'id': 'E-9',
        'tipo': 'vf',
        'concepto': 'C-x',
        'dificultad': 7,
        'afirmacion': 'x',
        'correcta': true,
        'fuente': 'F',
        'validado': 'true',
      })!;
      expect(e.dificultad, 3);
      expect(e.validado, isFalse);
    });
  });

  group('curso', () {
    test('solo se ve lo validado y con fuente; una lección sin ejercicios visibles desaparece', () async {
      final repo = repoCon({
        '$_lecciones/unidad-1.json': _unidad('U1', [
          ['E-1', 'E-2', 'E-3'],
          ['E-4'],
        ]),
        '$_lecciones/unidad-2.json': _unidad('U2', [
          ['E-5'],
        ], validado: false),
        '$_ejercicios/a.json':
            '[${_vf('E-1')}, ${_vf('E-2', validado: false)}, ${_vf('E-3', fuente: '')}, ${_vf('E-4', validado: false)}, ${_vf('E-5')}]',
      });
      final curso = await cargarCurso(repo);
      expect([for (final u in curso.unidades) u.id], ['U1']);
      expect([for (final l in curso.lecciones) l.id], ['U1-L1']);
      expect(curso.lecciones.single.ejercicios, ['E-1']);
      expect(curso.ejercicios.keys, containsAll(['E-1', 'E-5']));
      expect(curso.ejercicios.keys, isNot(contains('E-2')));
    });

    test('en modo demo, con borradores, se ve todo', () async {
      final repo = repoCon({
        '$_lecciones/u.json': _unidad('U1', [
          ['E-1'],
        ], validado: false),
        '$_ejercicios/a.json': '[${_vf('E-1', validado: false)}]',
      }, mostrarBorradores: true);
      expect((await cargarCurso(repo)).lecciones, hasLength(1));
    });

    test('las unidades van en orden natural (U2 antes que U10) y un fichero roto no rompe el resto', () async {
      final repo = repoCon({
        '$_lecciones/a.json': _unidad('U10', [
          ['E-1'],
        ]),
        '$_lecciones/b.json': _unidad('U2', [
          ['E-1'],
        ]),
        '$_lecciones/c.json': '{roto',
        '$_ejercicios/a.json': '[${_vf('E-1')}, {"id": "mal"}]',
      });
      final curso = await cargarCurso(repo);
      expect([for (final u in curso.unidades) u.id], ['U2', 'U10']);
    });

    test('sin contenido real usa los ejemplos de assets/mock/content', () async {
      final curso = await cargarCurso(repoCon(ficherosDeEjemplo()));
      expect(
        [for (final u in curso.unidades) u.titulo],
        [
          'Tus derechos',
          'Si te toca declarar',
          'Quién es quién en el juzgado',
          'Si eres víctima o testigo: tus derechos',
          'Tu imagen es tuya',
          'Si te investigan (14 a 17 años)',
          'Cuando el juez te escucha en familia',
        ],
      );
      expect(curso.lecciones, hasLength(17));
    });

    group('bloqueos', () {
      late Curso curso;
      setUp(() async => curso = await cargarCurso(repoCon(ficherosDeEjemplo())));

      test('al principio solo está abierta la primera lección', () {
        expect(curso.estado('U1-L1', {}), EstadoLeccion.disponible);
        for (final l in curso.lecciones.skip(1)) {
          expect(curso.estado(l.id, {}), EstadoLeccion.bloqueada, reason: l.id);
        }
        expect(curso.siguiente({})!.id, 'U1-L1');
        expect(curso.unidadActual({})!.id, 'U1');
      });

      test('una lección se desbloquea al completar la anterior, también entre unidades', () {
        final hechas = {'U1-L1', 'U1-L2', 'U1-L3'};
        expect(curso.estado('U1-L3', hechas), EstadoLeccion.completada);
        expect(curso.estado('U2-L1', hechas), EstadoLeccion.disponible);
        expect(curso.estado('U2-L2', hechas), EstadoLeccion.bloqueada);
        expect(curso.siguiente(hechas)!.id, 'U2-L1');
        expect(curso.unidadActual(hechas)!.id, 'U2');
        expect(curso.unidadAbierta(curso.unidad('U2')!, hechas), isTrue);
        expect(curso.unidadAbierta(curso.unidad('U2')!, {'U1-L1'}), isFalse);
      });

      test('con todo hecho no hay siguiente y la unidad actual es la última', () {
        final todas = {for (final l in curso.lecciones) l.id};
        expect(curso.siguiente(todas), isNull);
        expect(curso.unidadActual(todas)!.id, 'U7');
      });

      test('anterior y posterior siguen el camino', () {
        expect(curso.anterior('U1-L1'), isNull);
        expect(curso.anterior('U2-L1')!.id, 'U1-L3');
        expect(curso.posterior('U1-L3')!.id, 'U2-L1');
        expect(curso.posterior('U2-L3')!.id, 'U3-L1');
        expect(curso.posterior('U7-L2'), isNull);
      });
    });
  });

  group('racha', () {
    test('se ve si la última lección fue hoy, ayer o anteayer con día de descanso; si no, empieza otra', () {
      final p = Progreso(racha: 4, ultimoDiaConLeccion: DateTime(2026, 10, 20));
      expect(rachaVisible(p, DateTime(2026, 10, 20, 23)), 4);
      expect(rachaDeHoy(p, DateTime(2026, 10, 20, 9)), isTrue);
      expect(rachaVisible(p, DateTime(2026, 10, 21, 8)), 4);
      expect(rachaDeHoy(p, DateTime(2026, 10, 21, 8)), isFalse);
      // Un día sin lección: el día de descanso de la semana la mantiene (racha amable).
      expect(rachaVisible(p, DateTime(2026, 10, 22, 8)), 4);
      expect(rachaDeHoy(p, DateTime(2026, 10, 22, 8)), isFalse);
      // Sin descanso disponible (gastado hace poco) o con más días, 0.
      final sinDescanso = Progreso(
        racha: 4,
        ultimoDiaConLeccion: DateTime(2026, 10, 20),
        descansoUsado: DateTime(2026, 10, 18),
      );
      expect(rachaVisible(sinDescanso, DateTime(2026, 10, 22, 8)), 0);
      expect(rachaVisible(p, DateTime(2026, 10, 23, 8)), 0);
      expect(rachaVisible(const Progreso(), DateTime(2026, 10, 22)), 0);
    });

    test('el cambio de hora de primavera no la rompe: los días se cuentan en el calendario', () {
      // En España, el domingo 28/03/2027 dura 23 horas.
      final p = Progreso(racha: 4, ultimoDiaConLeccion: DateTime(2027, 3, 28));
      expect(rachaDeHoy(p, DateTime(2027, 3, 29, 9)), isFalse);
      expect(rachaVisible(p, DateTime(2027, 3, 29, 9)), 4);
      // Del 27 al 29 son dos días (no uno): sin descanso disponible, ya no sigue.
      final sinDescanso = Progreso(
        racha: 4,
        ultimoDiaConLeccion: DateTime(2027, 3, 27),
        descansoUsado: DateTime(2027, 3, 25),
      );
      expect(rachaVisible(sinDescanso, DateTime(2027, 3, 29, 9)), 0);
      expect(diasEntre(DateTime(2027, 3, 27), DateTime(2027, 3, 29, 23, 59)), 2);
      expect(diasEntre(DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 2, reason: 'y el de otoño, de 25 horas');
    });
  });

  group('contenido de ejemplo (assets/mock/content)', () {
    final ficheros = ficherosDeEjemplo();
    final unidades = [
      for (final MapEntry(:key, :value) in ficheros.entries)
        if (key.contains('/lecciones/')) Unidad.fromJson(jsonDecode(value))!,
    ]..sort((a, b) => a.id.compareTo(b.id));
    final crudos = [
      for (final MapEntry(:key, :value) in ficheros.entries)
        if (key.contains('/ejercicios/')) ...(jsonDecode(value) as List).cast<Map<String, dynamic>>(),
    ];
    final ejercicios = {for (final e in crudos) e['id'] as String: Ejercicio.fromJson(e)};

    test('siete unidades (U1 a U7) de dos o tres lecciones × seis ejercicios, todo validado', () {
      expect([for (final u in unidades) u.id], ['U1', 'U2', 'U3', 'U4', 'U5', 'U6', 'U7']);
      expect(unidades[0].titulo, 'Tus derechos');
      expect(unidades[1].titulo, 'Si te toca declarar');
      for (final u in unidades) {
        expect(u.validado, isTrue);
        expect(u.lecciones.length, inInclusiveRange(2, 3), reason: u.id);
        for (final l in u.lecciones) {
          expect(l.ejercicios, hasLength(6), reason: l.id);
        }
      }
      expect(unidades[0].conceptos, [
        'C-ser-oido',
        'C-fiscalia',
        'C-defensor',
        'C-abogado-gratis',
        'C-comunicar-violencia',
      ]);
    });

    test('cada ejercicio se puede jugar, está validado, cita su fuente y pertenece a un concepto de su unidad', () {
      expect(ejercicios.length, crudos.length, reason: 'ids repetidos');
      final usados = <String>[];
      for (final u in unidades) {
        final conceptosCubiertos = <String>{};
        for (final l in u.lecciones) {
          final tipos = <TipoEjercicio>{};
          for (final id in l.ejercicios) {
            final e = ejercicios[id];
            expect(e, isNotNull, reason: '$id no existe o no se puede jugar');
            expect(e!.validado, isTrue, reason: id);
            expect(e.fuente, matches(RegExp(r'art\.|arts\.|AEPD|INCIBE')), reason: '$id: la fuente cita el artículo');
            expect(normasEn(e.fuente), isNotEmpty, reason: '$id: norma conocida');
            expect(u.conceptos, contains(e.concepto), reason: id);
            expect(e.dificultad, inInclusiveRange(1, 3));
            if (e is EjercicioEleccion || e is EjercicioVf) expect(e.explicacion, isNotEmpty, reason: id);
            if (e is EjercicioDilo) expect(e.proposiciones.length, inInclusiveRange(2, 4), reason: id);
            if (e is EjercicioOrdenar) expect(e.pasos.length, greaterThanOrEqualTo(3), reason: id);
            tipos.add(e.tipo);
            conceptosCubiertos.add(e.concepto);
            usados.add(id);
          }
          expect(tipos.length, greaterThanOrEqualTo(3), reason: '${l.id}: tipos variados');
        }
        expect(conceptosCubiertos, u.conceptos.toSet(), reason: '${u.id}: todos sus conceptos');
      }
      expect(usados.toSet().length, usados.length, reason: 'cada ejercicio, en una sola lección');
      expect(usados.toSet(), ejercicios.keys.toSet(), reason: 'no sobran ejercicios');
    });

    test('salen los cinco tipos de ejercicio', () {
      expect({for (final e in ejercicios.values) e!.tipo}, TipoEjercicio.values.toSet());
    });

    test('salen los tres casos oficiales: Lucía, Sergio y Sara', () {
      final texto = jsonEncode(crudos);
      for (final caso in ['Lucía', 'Sergio', 'Sara']) {
        expect(texto, contains(caso));
      }
    });

    test('cuida los mensajes de la sección 2.3 y no pregunta por los hechos', () {
      final texto = jsonEncode(crudos).toLowerCase();
      expect(texto, isNot(contains('¿qué pasó')));
      expect(texto, isNot(contains('qué te pasó')));
      expect(texto, isNot(contains('12 a 18')));
      expect(texto, isNot(contains('cárcel')));
      expect(texto, isNot(contains('24 horas')));
      // «Gratis siempre» solo aparece como afirmación falsa.
      final gratis = crudos.where((e) => '${e['afirmacion'] ?? ''}'.contains('gratis siempre'));
      expect(gratis.every((e) => e['correcta'] == false), isTrue);
    });

    test('«Dilo» de U1-L1 tiene las ideas del mock de la API: la demo sin backend cuadra', () {
      final dilo = ejercicios.values.whereType<EjercicioDilo>().firstWhere((e) => e.concepto == 'C-ser-oido');
      final mock = MockTuTurnoApi.ejemploGrade;
      final ideas = {...(mock['cubiertas'] as List).cast<String>(), ...(mock['faltan'] as List).cast<String>()};
      expect(dilo.proposiciones.toSet(), ideas);
      expect(unidades[0].lecciones[0].ejercicios, contains(dilo.id));
    });

    test('cada «Dilo» de ejemplo recibe del mock sus propias ideas (sin backend no salen las de otra pregunta)', () {
      for (final dilo in ejercicios.values.whereType<EjercicioDilo>()) {
        final mock = MockTuTurnoApi.ejemploGradePara(dilo.concepto);
        final ideas = {...(mock['cubiertas'] as List).cast<String>(), ...(mock['faltan'] as List).cast<String>()};
        expect(ideas, dilo.proposiciones.toSet(), reason: dilo.id);
        final falta = normalizar((mock['faltan'] as List).single as String);
        expect(normalizar(mock['feedback'] as String), contains(falta), reason: dilo.id);
      }
    });

    test('todos los conceptos tienen un nombre para las barras de dominio', () {
      for (final u in unidades) {
        for (final c in u.conceptos) {
          expect(nombreConcepto(c), isNot(contains('-')), reason: c);
        }
      }
    });
  });
}
