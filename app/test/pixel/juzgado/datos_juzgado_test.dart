import 'dart:io';
import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/escenarios/escenarios.dart';
import 'package:tuturno/pixel/juzgado/juzgado.dart';
import 'package:tuturno/pixel/juzgado/reparto_juzgado.dart' show parpadear, respirar;
import 'package:tuturno/pixel/juzgado/sala_juzgado.dart' show pintarSalaMenores;
import 'package:tuturno/pixel/motor/motor.dart';
import 'package:tuturno/pixel/personajes/personajes.dart';

/// Las personas cuya carta solo las presenta (quién es y qué hace en la sala), sin afirmaciones jurídicas ni fuente.
/// Ahora, ninguna: la Letrada cita la LOPJ, art. 453.1 (la fe pública y la grabación) y el equipo técnico, la LO 5/2000,
/// art. 7.3 (sus informes cuentan la personalidad y el interés del menor).
const _soloPresentan = <String>{};

/// Cómo se llama cada norma de [nombresNormas] en los títulos de docs/MARCO_LEGAL.md.
const _normaEnMarco = {
  'Constitución': 'CE (Constitución Española)',
  'LECrim': 'LECrim',
  'Ley 4/2015': 'Ley 4/2015 (Estatuto de la víctima)',
  'LO 1/1996': 'LO 1/1996',
  'LO 5/2000': 'LO 5/2000',
  'LOPIVI': 'LOPIVI (LO 8/2021)',
  'LOPJ': 'LOPJ',
};

/// Los apartados de docs/MARCO_LEGAL.md: «norma, art. artículo» → la cita literal (con «[...]» como «(...)»).
Map<String, String> _marcoLegal() {
  final lineas = File('../docs/MARCO_LEGAL.md').readAsLinesSync();
  final apartados = <String, String>{};
  String? titulo;
  for (final linea in lineas) {
    if (linea.startsWith('### ')) {
      titulo = linea.substring(4).split(' · ').first.trim();
    } else if (linea.startsWith('> ') && titulo != null) {
      apartados[titulo] = linea.substring(2).replaceAll('[...]', '(...)');
      titulo = null;
    }
  }
  return apartados;
}

/// Todas las fuentes de las cartas y de los avisos de las dos salas.
List<(String, FuenteJuzgado)> _todasLasFuentes() => [
  for (final datos in [datosSalaVistas, datosMenores]) ...[
    for (final rol in datos.roles)
      for (final fuente in rol.fuentes) (rol.id, fuente),
    for (final nota in datos.notas)
      for (final fuente in nota.fuentes) (nota.titulo, fuente),
  ],
];

void main() {
  group('textos', () {
    for (final modo in ModoJuzgado.values) {
      final datos = DatosJuzgado.de(modo);

      test('${modo.name}: cada rol tiene quién es, qué hace e icono, y lo jurídico lleva su fuente', () {
        expect(datos.roles, isNotEmpty);
        final ids = datos.roles.map((rol) => rol.id).toList();
        expect(ids.toSet(), hasLength(ids.length), reason: 'ids repetidos');
        for (final rol in datos.roles) {
          expect(rol.titulo.trim(), isNotEmpty);
          expect(rol.corto.trim(), isNotEmpty);
          expect(rol.quienEs.trim().length, greaterThan(40), reason: rol.id);
          expect(rol.queHace.trim().length, greaterThan(40), reason: rol.id);
          if (_soloPresentan.contains(rol.id)) {
            expect(rol.fuentes, isEmpty, reason: '${rol.id} solo presenta a la persona');
            expect(rol.sabiasQue, isNull, reason: '${rol.id}: un «¿Sabías que…?» necesitaría fuente');
          } else {
            expect(rol.fuentes, isNotEmpty, reason: rol.id);
          }
          for (final fuente in rol.fuentes) {
            expect(fuente.boe, matches(RegExp(r'^BOE-A-\d{4}-\d+$')), reason: '${rol.id}: ${fuente.etiqueta}');
            expect(fuente.cita.trim().length, greaterThan(30), reason: '${rol.id}: ${fuente.etiqueta}');
            expect(fuente.articulo.trim(), isNotEmpty);
            expect(nombresNormas, contains(fuente.norma), reason: 'falta el nombre largo de ${fuente.norma}');
            expect(fuente.url, startsWith('https://www.boe.es/buscar/act.php?id=BOE-A-'));
          }
        }
        for (final nota in datos.notas) {
          expect(nota.fuentes, isNotEmpty, reason: nota.titulo);
          for (final fuente in nota.fuentes) {
            expect(fuente.cita, isNotEmpty);
            expect(fuente.boe, matches(RegExp(r'^BOE-A-\d{4}-\d+$')));
          }
        }
        // Cada persona sabe decir dónde está, para el lector de pantalla.
        for (final rol in datos.roles) {
          expect(rol.sitio, isNotNull, reason: rol.id);
        }
        // Hasta que alguien con formación jurídica los revise, son un borrador.
        expect(datos.validado, isFalse);
      });

      test('${modo.name}: cada rol tiene su sitio en la sala y en la sala solo hay roles con carta', () {
        final montaje = MontajeJuzgado.de(modo);
        expect(montaje.puestos.map((puesto) => puesto.id).toSet(), datos.roles.map((rol) => rol.id).toSet());
        for (final rol in datos.roles) {
          expect(montaje.cara(rol.id), isNotNull, reason: rol.id);
          expect(datos.rol(rol.id), same(rol));
        }
      });
    }

    test('cada fuente es un artículo de docs/MARCO_LEGAL.md y su cita sale de allí, palabra por palabra', () {
      final marco = _marcoLegal();
      expect(marco, isNotEmpty, reason: 'no se ha podido leer docs/MARCO_LEGAL.md');
      for (final (quien, fuente) in _todasLasFuentes()) {
        final norma = _normaEnMarco[fuente.norma];
        expect(norma, isNotNull, reason: '$quien: ${fuente.norma} no está en MARCO_LEGAL');
        // El artículo es el de un apartado de MARCO_LEGAL o una parte de él («7.3» en «7.1 a), b), c) y d) y 7.3»).
        final apartado = marco.entries.where((entrada) {
          final prefijo = '$norma, art. ';
          return entrada.key.startsWith(prefijo) && entrada.key.substring(prefijo.length).contains(fuente.articulo);
        }).firstOrNull;
        expect(apartado, isNotNull, reason: '$quien: ${fuente.etiqueta} no está en MARCO_LEGAL');
        // Cada trozo de la cita (entre «(...)») está tal cual en la de MARCO_LEGAL.
        for (final trozo in fuente.cita.split('(...)')) {
          final limpio = trozo.trim().replaceAll(RegExp(r'^[.,;:]\s*'), '').replaceAll(RegExp(r'[,;:]$'), '').trim();
          if (limpio.isEmpty) continue;
          expect(apartado!.value, contains(limpio), reason: '$quien: ${fuente.etiqueta}');
        }
      }
    });

    test('las fuentes de una misma norma y artículo citan lo mismo en todas las cartas', () {
      final porArticulo = <String, String>{};
      for (final (quien, fuente) in _todasLasFuentes()) {
        final anterior = porArticulo.putIfAbsent(fuente.etiqueta, () => fuente.cita);
        expect(fuente.cita, anterior, reason: '$quien: ${fuente.etiqueta}');
      }
    });

    test('los textos son para chicos y chicas: frases cortas y sin «etc.» ni abreviaturas de leyes', () {
      final notas = [
        for (final nota in [...datosSalaVistas.notas, ...datosMenores.notas]) nota.texto,
      ];
      for (final rol in [...datosSalaVistas.roles, ...datosMenores.roles]) {
        for (final texto in [rol.quienEs, rol.queHace, ?rol.sabiasQue, ...notas]) {
          for (final frase in texto.split(RegExp(r'(?<=[.:;?!])\s+'))) {
            expect(frase.split(' ').length, lessThanOrEqualTo(22), reason: '${rol.id}: «$frase»');
          }
          expect(texto, isNot(contains('etc.')));
          expect(texto, isNot(matches(RegExp(r'\b(LO|LECrim|LOPJ|EOMF|art\.)\b'))), reason: rol.id);
        }
      }
    });

    test('a un chico de 11 años no le asustan: no se habla de cárcel y nadie le obliga a nada', () {
      for (final rol in [...datosSalaVistas.roles, ...datosMenores.roles]) {
        for (final texto in [rol.quienEs, rol.queHace, ?rol.sabiasQue, for (final f in rol.fuentes) f.cita]) {
          expect(texto, isNot(contains(RegExp('prisión|cárcel|internamiento'))), reason: rol.id);
        }
      }
      // Nadie le puede obligar a Sergio a aceptar unas disculpas.
      expect(datosMenores.rol('fiscalMenores')!.sabiasQue, contains('nadie le puede obligar'));
      // A quien se investiga, la ley lo trata como inocente (Constitución, art. 24.2).
      expect(datosSalaVistas.rol('investigada')!.quienEs, contains('inocente mientras no se demuestre lo contrario'));
      expect(datosMenores.rol('menor')!.quienEs, contains('inocente mientras no se demuestre lo contrario'));
    });

    test('la fuente dice «arts.» si cita varios artículos y «art.» si son apartados o párrafos de uno', () {
      FuenteJuzgado fuente(String articulo) => FuenteJuzgado(norma: 'LECrim', articulo: articulo, cita: '', boe: '');
      expect(fuente('656 y 708').etiqueta, 'LECrim, arts. 656 y 708');
      expect(fuente('1, 12.3 y 13').etiqueta, 'LECrim, arts. 1, 12.3 y 13');
      expect(fuente('35 y 36.1').etiqueta, 'LECrim, arts. 35 y 36.1');
      expect(fuente('118.2 y 118.4').etiqueta, 'LECrim, art. 118.2 y 118.4');
      expect(fuente('22.1 a), b) y d)').etiqueta, 'LECrim, art. 22.1 a), b) y d)');
      expect(fuente('7.1 k) y l) y 7.3').etiqueta, 'LECrim, art. 7.1 k) y l) y 7.3');
      expect(fuente('520.2 bis').etiqueta, 'LECrim, art. 520.2 bis');
      expect(fuente('449 ter').etiqueta, 'LECrim, art. 449 ter');
      expect(fuente('449 ter, párr. 1').etiqueta, 'LECrim, art. 449 ter, párr. 1');
      expect(fuente('703 bis, párrs. 1 y 2').etiqueta, 'LECrim, art. 703 bis, párrs. 1 y 2');
      expect(fuente('4, párrs. 4 y 5').etiqueta, 'LECrim, art. 4, párrs. 4 y 5');
      expect(fuente('17.1 (segundo inciso) y 17.2').etiqueta, 'LECrim, art. 17.1 (segundo inciso) y 17.2');
      expect(fuente('disposición adicional primera').etiqueta, 'LECrim, disposición adicional primera');
    });

    test('la sala de vistas tiene a las nueve personas que se piden, con el nombre de verdad de cada una', () {
      expect(datosSalaVistas.roles.map((rol) => rol.id), [
        'jueza',
        'fiscal',
        'abogadaVictima',
        'abogadoDefensa',
        'letrada',
        'testigo',
        'investigada',
        'policia',
        'publico',
      ]);
      expect(datosSalaVistas.rol('letrada')!.titulo, 'Letrado o Letrada de la Administración de Justicia');
      final todos = [...datosSalaVistas.roles, ...datosMenores.roles];
      for (final rol in todos) {
        for (final texto in [rol.titulo, rol.corto, rol.quienEs, rol.queHace, ?rol.sabiasQue]) {
          expect(texto, isNot(contains(RegExp(r'\bLAJ\b|secretari[oa] judicial', caseSensitive: false))));
        }
      }
    });
  });

  group('fidelidad', () {
    final codigo = {
      for (final fichero in Directory('lib/pixel/juzgado').listSync().whereType<File>())
        fichero.path: fichero.readAsStringSync(),
    };

    test('ni mazo ni iconos de Material de balanza o de policía', () {
      expect(codigo, isNotEmpty);
      for (final MapEntry(key: ruta, value: texto) in codigo.entries) {
        expect(
          texto,
          isNot(contains(RegExp('gavel|Icons\\.balance|Icons\\.local_police|Icons\\.policy'))),
          reason: ruta,
        );
      }
    });

    test('sin placas ni medallas doradas en la toga del juez de menores ni en las de reserva', () {
      for (final sprite in [RepartoJuzgado.juezMenores, RepartoJuzgado.jueza, RepartoJuzgado.fiscal]) {
        final quieto = sprite.fotogramas.first;
        for (var y = 15; y < 25; y++) {
          expect(quieto[y], isNot(contains(RegExp('[Yyo]'))), reason: '${sprite.nombre}, fila $y');
        }
      }
      final letrada = RepartoJuzgado.letrada.fotogramas.first;
      for (final y in [18, 19]) {
        expect(letrada[y].substring(13, 17), isNot(contains(RegExp('[WgG]'))), reason: 'placa de la letrada');
      }
    });

    test('en la sala de menores, la mesa del juez mide lo mismo que las de las partes y no va sobre una tarima', () {
      expect(MueblesJuzgado.estrado.alto, MueblesJuzgado.mesa.alto);
      final filas = pintarSalaMenores();
      // La línea del suelo, entera: sin el escalón de una tarima.
      expect(filas[47], 'N' * 160);
      final montaje = MontajeJuzgado.de(ModoJuzgado.menores);
      final juez = montaje.puesto('juezMenores')!;
      final abogada = montaje.puesto('letradaMenor')!;
      final estrado = montaje.muebles.firstWhere((e) => identical(e.sprite, MueblesJuzgado.estrado));
      final mesa = montaje.muebles.firstWhere((e) => identical(e.sprite, MueblesJuzgado.mesa));
      // El juez está detrás de su mesa igual que la abogada detrás de la suya: se les ve lo mismo por encima.
      expect(juez.sprite.alto, abogada.sprite.alto);
      expect(estrado.y - juez.y, mesa.y - abogada.y);
    });

    test('en la audiencia de Sergio no hay cámaras', () {
      final filas = pintarSalaMenores();
      var iguales = 0;
      var total = 0;
      for (final (j, fila) in camaraPared.indexed) {
        for (final (i, clave) in fila.split('').indexed) {
          if (clave == '.') continue;
          total++;
          if (filas[3 + j][146 + i] == clave) iguales++;
        }
      }
      expect(iguales, lessThan(total ~/ 2), reason: 'la cámara de la pared sigue en la sala de menores');
    });

    test('sobre el estrado de la sala de vistas no hay escudo oficial: hay una balanza', () {
      final escenario = EscenariosPixel.salaVistas.fondo.fotogramas.first;
      final sala = MontajeJuzgado.de(ModoJuzgado.salaVistas).fondo.fotogramas.first;
      expect(sala.any((fila) => fila.contains('NRRRNWWWN')), isFalse, reason: 'los cuarteles del escudo');
      if (escenario[5].startsWith('NRRRNWWWN', 76)) {
        expect(sala[1].substring(78, 83), 'NNNNN', reason: 'el medallón de la balanza');
      }
      // Lo demás es la sala de lib/pixel/escenarios, tal cual.
      for (var y = 0; y < sala.length; y++) {
        for (var x = 0; x < sala[y].length; x++) {
          if (y <= 12 && x >= 74 && x < 87) continue;
          expect(sala[y][x], escenario[y][x], reason: '($x, $y)');
        }
      }
    });
  });

  group('dibujos', () {
    test('todos los personajes son de 24 de ancho, con tres fotogramas y animación en reposo', () {
      for (final sprite in RepartoJuzgado.todos) {
        sprite.validar();
        if (identical(sprite, RepartoJuzgado.publico)) continue;
        expect(sprite.ancho, 24, reason: sprite.nombre);
        expect(sprite.alto, inInclusiveRange(32, 36), reason: sprite.nombre);
        expect(sprite.fotogramas, hasLength(3), reason: sprite.nombre);
        expect(sprite.animacion?.seMueve, isTrue, reason: sprite.nombre);
      }
    });

    test('respirar baja la cabeza un píxel y parpadear solo cambia los ojos', () {
      final quieto = RepartoJuzgado.jueza.fotogramas.first;
      final respira = respirar(quieto);
      expect(respira, hasLength(quieto.length));
      expect(respira.first, '.' * 24);
      expect(respira.sublist(1, 10), quieto.sublist(0, 9));
      expect(respira.last, quieto.last);
      final parpadea = parpadear(quieto);
      for (var y = 0; y < quieto.length; y++) {
        if (y != 9) expect(parpadea[y], quieto[y]);
      }
      expect(parpadea[9], isNot(contains('W')));
      // Cada personaje respira de verdad: el fotograma de respirar no es igual que el quieto.
      for (final sprite in RepartoJuzgado.todos.where((s) => s.fotogramas.length == 3)) {
        expect(sprite.fotogramas[1], isNot(equals(sprite.fotogramas[0])), reason: sprite.nombre);
        expect(sprite.fotogramas[2], isNot(equals(sprite.fotogramas[0])), reason: sprite.nombre);
      }
    });

    test('las salas miden 160 × 96; la de menores solo usa claves de la paleta y tiene el cordón rojo', () {
      final filas = pintarSalaMenores();
      expect(filas, hasLength(96));
      for (final fila in filas) {
        expect(fila.length, 160);
        expect(fila.split('').every(PaletaPixel.esClave), isTrue);
      }
      // El cordón de terciopelo (coral con su sombra) entre los dos postes del pasillo.
      expect(filas[81].substring(71, 91), contains('r'));
      for (final modo in ModoJuzgado.values) {
        expect(MontajeJuzgado.de(modo).fondo.tamano, const Size(160, 96));
      }
    });

    test('la sala de vistas es la de lib/pixel/escenarios, con los personajes de lib/pixel/personajes', () {
      final montaje = MontajeJuzgado.de(ModoJuzgado.salaVistas);
      expect(montaje.fondo.tamano, EscenariosPixel.salaVistas.fondo.tamano);
      expect(montaje.muebles, same(EscenariosPixel.salaVistas.delante));
      expect(montaje.puesto('jueza')!.sprite, same(PersonajesPixel.jueza));
      expect(montaje.puesto('policia')!.sprite, same(PersonajesPixel.policia));
      expect(montaje.puesto('publico')!.sprite, same(RepartoJuzgado.publico));
      // El fiscal de la audiencia de menores es el mismo que el de las escenas de la Fiscalía.
      expect(MontajeJuzgado.de(ModoJuzgado.menores).puesto('fiscalMenores')!.sprite, same(PersonajesPixel.fiscal));
      // Si falta un personaje, el de reserva.
      expect(spriteDeReserva('juezMenores'), same(RepartoJuzgado.juezMenores));
    });

    test('la chispa late, y quieta es la grande; solo la llevan quienes faltan por conocer', () {
      expect(MueblesJuzgado.chispa.animacion!.descanso!.fotograma, 0, reason: 'quieta, la chispa grande');
      expect(MueblesJuzgado.chispa.ancla, (x: 3, y: 3));
      final montaje = MontajeJuzgado.de(ModoJuzgado.salaVistas);
      int chispas(Set<String> descubiertos) =>
          montaje.elementos(descubiertos: descubiertos).where((e) => identical(e.sprite, MueblesJuzgado.chispa)).length;
      expect(chispas({}), montaje.puestos.length);
      expect(chispas({'jueza', 'fiscal'}), montaje.puestos.length - 2);
      expect(chispas({for (final puesto in montaje.puestos) puesto.id}), 0);
    });

    test('cada personaje y cada mueble cabe en la sala', () {
      for (final modo in ModoJuzgado.values) {
        final montaje = MontajeJuzgado.de(modo);
        for (final elemento in montaje.elementos()) {
          final rect = elemento.rectPixel;
          expect(rect.left, greaterThanOrEqualTo(-2), reason: '${elemento.sprite.nombre} se sale por la izquierda');
          expect(rect.right, lessThanOrEqualTo(162), reason: '${elemento.sprite.nombre} se sale por la derecha');
          expect(rect.top, greaterThanOrEqualTo(0), reason: '${elemento.sprite.nombre} se sale por arriba');
        }
      }
    });

    test('las caras no las tapa ningún personaje que esté delante', () {
      for (final modo in ModoJuzgado.values) {
        final montaje = MontajeJuzgado.de(modo);
        final personas = montaje.elementos().where((e) => e.id != null).toList();
        for (var i = 0; i < personas.length; i++) {
          final cara = montaje.cara(personas[i].id!)!;
          final punto = Offset(cara.x + 0.5, cara.y + 0.5);
          expect(personas[i].rectPixel.contains(punto), isTrue);
          for (final delante in personas.skip(i + 1)) {
            expect(
              delante.rectPixel.contains(punto),
              isFalse,
              reason: '${delante.id} tapa la cara de ${personas[i].id}',
            );
          }
        }
      }
    });
  });
}
