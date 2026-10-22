import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/motor/motor.dart';
import 'package:tuturno/pixel/personajes/personajes.dart';

/// Los ids de Tut, con sus dos caras.
const _idsTut = {'tut', 'tut-feliz'};

/// Los personajes con cara de persona (todos menos Tut).
final _personas = [
  for (final ficha in PersonajesPixel.todos)
    if (!_idsTut.contains(ficha.id)) ficha,
];

/// Las dos caras de Tut.
final _tuts = [PersonajesPixel.tut, PersonajesPixel.tutFeliz];

/// Tamaño de cada personaje según la rejilla de lib/pixel/LEEME.md.
const _tamanos = <String, (int, int)>{
  'lucia': (24, 32),
  'tutora': (24, 36),
  'madre-sergio': (24, 36),
  'fiscal-despacho': (24, 36),
  'tut-feliz': (24, 22),
  'sergio': (24, 32),
  'sara': (24, 34),
  'amiga-sara': (24, 34),
  'madre-sara': (24, 36),
  'abogada-despacho': (24, 36),
  'elena': (24, 36),
  'ana': (24, 36),
  'padre-sergio': (24, 36),
  'laura': (24, 36),
  'jueza': (24, 36),
  'fiscal': (24, 36),
  'abogada-victima': (24, 36),
  'abogado-defensa': (24, 36),
  'letrada': (24, 36),
  'policia': (24, 36),
  'investigada': (24, 36),
  'testigo': (28, 32),
  'tut': (24, 22),
};

/// Las posiciones (x, y) en las que [a] y [b] son distintos.
List<(int, int)> _diferencias(List<String> a, List<String> b) => [
  for (var y = 0; y < a.length; y++)
    for (var x = 0; x < a[y].length; x++)
      if (a[y][x] != b[y][x]) (x, y),
];

/// La primera fila con algún píxel que no es transparente.
int _primeraFila(List<String> filas) => filas.indexWhere((fila) => fila.contains(RegExp('[^.]')));

void main() {
  group('Registro', () {
    test('hay un id por personaje, sin repetir y en el orden de todos', () {
      expect(PersonajesPixel.ids, hasLength(23));
      expect(PersonajesPixel.ids.toSet(), hasLength(23));
      expect([for (final ficha in PersonajesPixel.todos) ficha.id], PersonajesPixel.ids);
      for (final id in PersonajesPixel.ids) {
        expect(id, matches(RegExp(r'^[a-z]+(-[a-z]+)*$')), reason: 'los ids van en minúsculas, sin tildes');
      }
    });

    test('porId y ficha encuentran a cada personaje; con un id que no existe, null', () {
      for (final ficha in PersonajesPixel.todos) {
        expect(PersonajesPixel.porId(ficha.id), same(ficha.sprite));
        expect(PersonajesPixel.ficha(ficha.id), same(ficha));
        expect(ficha.sprite.nombre, ficha.id);
        expect(ficha.nombre, isNotEmpty);
        expect(ficha.descripcion, isNotEmpty);
      }
      expect(PersonajesPixel.porId('juez'), isNull);
      expect(PersonajesPixel.porId(''), isNull);
      expect(PersonajesPixel.ficha('Lucía'), isNull);
    });

    test('los accesos directos dan los mismos sprites que porId', () {
      final accesos = <String, Sprite>{
        'lucia': PersonajesPixel.lucia,
        'tutora': PersonajesPixel.tutora,
        'elena': PersonajesPixel.elena,
        'ana': PersonajesPixel.ana,
        'sergio': PersonajesPixel.sergio,
        'padre-sergio': PersonajesPixel.padreSergio,
        'madre-sergio': PersonajesPixel.madreSergio,
        'laura': PersonajesPixel.laura,
        'sara': PersonajesPixel.sara,
        'amiga-sara': PersonajesPixel.amigaSara,
        'madre-sara': PersonajesPixel.madreSara,
        'jueza': PersonajesPixel.jueza,
        'fiscal': PersonajesPixel.fiscal,
        'fiscal-despacho': PersonajesPixel.fiscalDespacho,
        'abogada-victima': PersonajesPixel.abogadaVictima,
        'abogada-despacho': PersonajesPixel.abogadaDespacho,
        'abogado-defensa': PersonajesPixel.abogadoDefensa,
        'letrada': PersonajesPixel.letrada,
        'policia': PersonajesPixel.policia,
        'investigada': PersonajesPixel.investigada,
        'testigo': PersonajesPixel.testigo,
        'tut': PersonajesPixel.tut,
        'tut-feliz': PersonajesPixel.tutFeliz,
      };
      expect(accesos.keys, unorderedEquals(PersonajesPixel.ids));
      accesos.forEach((id, sprite) => expect(sprite, same(PersonajesPixel.porId(id)), reason: id));
    });
  });

  group('Dibujo', () {
    test('todos están bien dibujados: filas iguales y solo claves de la paleta', () {
      for (final ficha in PersonajesPixel.todos) {
        expect(ficha.sprite.validar, returnsNormally, reason: ficha.id);
      }
    });

    test('siguen la rejilla: niños 24 × 32, adolescentes 24 × 34, adultos 24 × 36', () {
      expect(_tamanos.keys, unorderedEquals(PersonajesPixel.ids));
      for (final ficha in PersonajesPixel.todos) {
        final (ancho, alto) = _tamanos[ficha.id]!;
        expect((ficha.sprite.ancho, ficha.sprite.alto), (ancho, alto), reason: ficha.id);
      }
    });

    test('el ancla está en los pies: el centro del borde de abajo', () {
      for (final ficha in PersonajesPixel.todos) {
        final sprite = ficha.sprite;
        expect(sprite.ancla, (x: sprite.ancho ~/ 2, y: sprite.alto), reason: ficha.id);
      }
    });

    test('la última fila es la sombra en el suelo y, encima, las suelas (o el aire, si flota)', () {
      for (final ficha in PersonajesPixel.todos) {
        for (final filas in ficha.sprite.fotogramas) {
          expect(filas.last, matches(RegExp(r'^\.*x+\.*$')), reason: '${ficha.id}: la sombra');
          final encima = filas[filas.length - 2];
          if (_idsTut.contains(ficha.id)) {
            expect(encima, matches(RegExp(r'^\.+$')), reason: 'Tut flota sobre su sombra');
          } else {
            expect(encima, contains('N'), reason: '${ficha.id}: las suelas tocan la sombra');
          }
        }
      }
    });

    test('contorno azul noche de un píxel: ningún color toca un hueco ni la sombra', () {
      for (final ficha in PersonajesPixel.todos) {
        for (var f = 0; f < ficha.sprite.fotogramas.length; f++) {
          final filas = ficha.sprite.fotogramas[f];
          String en(int x, int y) => y < 0 || y >= filas.length || x < 0 || x >= filas[y].length ? '.' : filas[y][x];
          for (var y = 0; y < filas.length; y++) {
            for (var x = 0; x < filas[y].length; x++) {
              final clave = filas[y][x];
              if (clave == '.' || clave == 'N' || clave == 'x') continue;
              for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
                final vecino = en(x + dx, y + dy);
                expect(
                  vecino != '.' && vecino != 'x',
                  isTrue,
                  reason: '${ficha.id}, fotograma $f: el píxel «$clave» de la fila $y, columna $x no tiene contorno',
                );
              }
            }
          }
        }
      }
    });

    test('cada persona tiene dos ojos con su brillo, y la cara se ve entera', () {
      for (final ficha in _personas) {
        final quieto = ficha.sprite.fotogramas.first;
        // Solo en la cabeza (la mitad de arriba): un calcetín blanco junto al contorno también es «WN».
        final cabeza = quieto.sublist(0, quieto.length ~/ 2);
        final ojos = cabeza.fold(0, (total, fila) => total + 'WN'.allMatches(fila).length);
        expect(ojos, 2, reason: '${ficha.id}: dos ojos de 2 × 2 con el brillo arriba a la izquierda');
        expect(quieto.join(), contains('RR'), reason: '${ficha.id}: una boca tranquila de dos píxeles');
      }
    });

    test('diversidad: entre todos aparecen los seis tonos de piel', () {
      final pieles = {
        for (final ficha in _personas)
          for (final fila in ficha.sprite.fotogramas.first)
            for (final clave in fila.split(''))
              if (PaletaPixel.pieles.any((piel) => piel.clave == clave)) clave,
      };
      expect(pieles, unorderedEquals(['1', '2', '3', '4', '5', '6']));
    });

    test('la persona investigada es una figura neutra: ropa gris y ningún color de acento', () {
      const permitidas = {
        '.', 'x', 'N', 'W', 'g', 'G', 'K', 'z', // contorno, ojos y ropa gris
        '3', '4', // la piel
        't', 'T', 'm', // el pelo
        'R', // la boca
      };
      final claves = {
        for (final filas in PersonajesPixel.investigada.fotogramas)
          for (final fila in filas) ...fila.split(''),
      };
      expect(claves.difference(permitidas), isEmpty);
    });

    test('Tut es amarillo: el ticket es del amarillo de la marca con la cara azul noche', () {
      for (final tut in _tuts) {
        final claves = {for (final fila in tut.fotogramas.first) ...fila.split('')};
        expect(claves, containsAll(['Y', 'y', 'o', 'N']), reason: tut.nombre);
        expect(claves.difference({'.', 'x', 'N', 'W', 'Y', 'y', 'o', 's'}), isEmpty, reason: tut.nombre);
      }
    });

    test('el fiscal de la Fiscalía es el mismo, sin toga ni puñetas', () {
      final toga = PersonajesPixel.fiscal.fotogramas.first;
      final traje = PersonajesPixel.fiscalDespacho.fotogramas.first;
      // La misma cabeza (cara, pelo y gafas).
      expect(traje.sublist(0, 15), toga.sublist(0, 15));
      // Del cuello a la cadera, nada negro (la toga) ni blanco en los puños (las puñetas).
      for (var y = 15; y < 26; y++) {
        expect(traje[y], isNot(contains('z')), reason: 'fila $y');
      }
      expect(traje[23], isNot(contains('W')));
    });

    test('la jueza, sin placa ni medalla en la toga (son distintivos oficiales)', () {
      final quieto = PersonajesPixel.jueza.fotogramas.first;
      for (var y = 15; y < 26; y++) {
        expect(quieto[y], isNot(contains(RegExp('[Yyo]'))), reason: 'fila $y');
      }
      expect(PersonajesPixel.ficha('jueza')!.descripcion, isNot(contains('medalla')));
    });

    test('la abogada fuera de la sala es la misma, sin toga (Reglamento 2/2005 del CGPJ, art. 33)', () {
      final toga = PersonajesPixel.abogadaVictima.fotogramas.first;
      final traje = PersonajesPixel.abogadaDespacho.fotogramas.first;
      expect(traje.sublist(0, 15), toga.sublist(0, 15), reason: 'la misma cabeza');
      for (var y = 15; y < 33; y++) {
        expect(traje[y], isNot(contains('z')), reason: 'fila $y: nada negro de toga');
      }
    });

    test('la madre de Sara no es la de Sergio: otra piel y otra ropa, con la misma cara tranquila', () {
      final sergio = PersonajesPixel.madreSergio.fotogramas.first;
      final sara = PersonajesPixel.madreSara.fotogramas.first;
      expect(sara.join(), isNot(contains('5')), reason: 'la piel de Sara (6)');
      expect(sara.sublist(15).join(), isNot(contains('r')), reason: 'jersey verde, no coral');
      expect(sara.join(), contains('RR'), reason: 'la boca no cambia de color');
      expect(sara, isNot(sergio));
    });

    test('pieles oscuras con colorete teja; las claras, con rosa', () {
      for (final ficha in _personas) {
        final quieto = ficha.sprite.fotogramas.first;
        final piel = PaletaPixel.pieles.firstWhere((p) => quieto.any((fila) => fila.contains(p.clave))).clave;
        final mejillas = quieto.sublist(8, 13).join();
        if ('456'.contains(piel)) {
          expect(mejillas, isNot(contains('s')), reason: '${ficha.id}: en la piel $piel, el rosa parece una pegatina');
        }
      }
    });
  });

  group('Animación en reposo', () {
    test('tres fotogramas: quieto (la pose de descanso), respira y parpadea', () {
      for (final ficha in PersonajesPixel.todos) {
        final sprite = ficha.sprite;
        expect(sprite.fotogramas, hasLength(3), reason: ficha.id);
        final animacion = sprite.animacion!;
        expect(animacion.seMueve, isTrue);
        expect(animacion.descanso!.fotograma, 0, reason: '${ficha.id}: con «reducir animaciones», quieto');
        expect({for (final paso in animacion.pasos) paso.fotograma}, {0, 1, 2});
        expect(animacion.pasos.every((paso) => paso.dy == 0), isTrue, reason: 'nada se sale de su sitio');
      }
    });

    test('no respiran todos al mismo ritmo', () {
      final ritmos = {for (final ficha in PersonajesPixel.todos) ficha.sprite.animacion!.duracionMs};
      expect(ritmos.length, greaterThan(10));
    });

    test('al parpadear solo se cierran los ojos: el brillo y la mitad de arriba pasan a ser piel', () {
      for (final ficha in _personas) {
        final [quieto, _, parpadea] = ficha.sprite.fotogramas;
        final cambios = _diferencias(quieto, parpadea);
        expect(cambios, hasLength(4), reason: ficha.id);
        expect({for (final (_, y) in cambios) y}, hasLength(1), reason: '${ficha.id}: una sola fila');
        for (final (x, y) in cambios) {
          expect(quieto[y][x], anyOf('W', 'N'));
          expect(PaletaPixel.pieles.map((piel) => piel.clave), contains(parpadea[y][x]));
          expect(quieto[y + 1][x], 'N', reason: '${ficha.id}: debajo queda el ojo, como una raya');
        }
      }
    });

    test('al respirar baja la cabeza un píxel y los pies no se mueven', () {
      for (final ficha in _personas) {
        final [quieto, respira, _] = ficha.sprite.fotogramas;
        expect(_primeraFila(respira), _primeraFila(quieto) + 1, reason: ficha.id);
        final n = quieto.length;
        expect(respira.sublist(n - 4), quieto.sublist(n - 4), reason: '${ficha.id}: los pies y la sombra');
      }
    });

    test('el testigo respira sin mover la silla de ruedas', () {
      final [quieto, respira, _] = PersonajesPixel.testigo.fotogramas;
      for (final (x, _) in _diferencias(quieto, respira)) {
        expect(x, inInclusiveRange(7, 20));
      }
    });

    test('Tut flota: el ticket sube un píxel y la sombra se queda; al parpadear, solo quedan las barras de las T', () {
      for (final tut in _tuts) {
        final [quieto, sube, parpadea] = tut.fotogramas;
        expect(_primeraFila(sube), _primeraFila(quieto) - 1, reason: tut.nombre);
        expect(sube.last, quieto.last);
        final cambios = _diferencias(quieto, parpadea);
        expect(cambios, isNotEmpty);
        for (final (x, y) in cambios) {
          expect(quieto[y][x], anyOf('N', 'W'), reason: '${tut.nombre}: solo se van los palos de las T');
          expect(parpadea[y][x], 'Y');
        }
      }
    });

    test('Tut sonriendo: la barra de cada T se separa del palo y la sonrisa es más ancha', () {
      final neutral = PersonajesPixel.tut.fotogramas.first;
      final feliz = PersonajesPixel.tutFeliz.fotogramas.first;
      // Las barras, una fila más arriba, con una fila amarilla entre la barra y el ojo.
      expect(feliz[4], neutral[5]);
      expect(feliz[5].substring(3, 21), isNot(contains('N')));
      // La boca: el tramo azul noche más largo en la zona de la boca (columnas 7 a 16).
      int boca(List<String> filas) => [
        for (final fila in filas.sublist(8, 12))
          for (final tramo in RegExp('N+').allMatches(fila.substring(7, 17))) tramo.end - tramo.start,
      ].fold(0, (maximo, largo) => largo > maximo ? largo : maximo);
      expect(boca(feliz), greaterThan(boca(neutral)));
    });
  });

  group('Retratos', () {
    test('cada personaje tiene su retrato de 24 × 20, que se recorta una sola vez', () {
      for (final id in PersonajesPixel.ids) {
        final retrato = PersonajesPixel.retrato(id)!;
        expect((retrato.ancho, retrato.alto), (PersonajesPixel.anchoRetrato, PersonajesPixel.altoRetrato), reason: id);
        expect(PersonajesPixel.retrato(id), same(retrato));
        expect(retrato.validar, returnsNormally);
      }
      expect(PersonajesPixel.retrato('nadie'), isNull);
    });

    test('los ojos quedan siempre en la misma fila y se mueven como en su sprite', () {
      for (final ficha in PersonajesPixel.todos) {
        final retrato = PersonajesPixel.retrato(ficha.id)!;
        expect(retrato.animacion, ficha.sprite.animacion, reason: ficha.id);
        expect(retrato.fotogramas, hasLength(ficha.sprite.fotogramas.length));
        final [quieto, _, parpadea] = retrato.fotogramas;
        final filas = {for (final (_, y) in _diferencias(quieto, parpadea)) y};
        expect(filas.reduce((a, b) => a < b ? a : b), PersonajesPixel.filaOjosRetrato, reason: ficha.id);
      }
    });

    test('el retrato del testigo es solo él: sin las empuñaduras ni las ruedas de la silla', () {
      final retrato = PersonajesPixel.retrato('testigo')!;
      for (final filas in retrato.fotogramas) {
        for (final fila in filas) {
          // Columnas 7 a 20 del sprite (28 de ancho, recortado desde la 2): 5 a 18 del retrato.
          expect(fila.substring(0, 5), '.....');
          expect(fila.substring(19), '.....');
        }
      }
    });

    test('la cara entra entera: el pelo de arriba no se corta', () {
      for (final id in PersonajesPixel.ids) {
        final quieto = PersonajesPixel.retrato(id)!.fotogramas.first;
        expect(quieto.first, isNot(contains(RegExp('[^.N]'))), reason: '$id: arriba solo cabe el contorno o aire');
      }
    });
  });

  group('buscar', () {
    test('encuentra a los personajes por los nombres de las escenas del contenido', () {
      const nombres = {
        'Lucía': 'lucia',
        'Su tía Elena': 'elena',
        'Ana, la psicóloga': 'ana',
        'Sergio': 'sergio',
        'Sus padres': 'padre-sergio',
        'Su padre': 'padre-sergio',
        'Su madre': 'madre-sergio',
        'La madre de Sergio': 'madre-sergio',
        'Su tutora': 'tutora',
        'Su maestra': 'tutora',
        'El padre de Sergio': 'padre-sergio',
        'Laura, coordinadora de bienestar': 'laura',
        'Sara': 'sara',
        'La amiga de Sara': 'amiga-sara',
        'La jueza': 'jueza',
        'El juez': 'jueza',
        'El fiscal': 'fiscal',
        'La fiscal': 'fiscal',
        'La abogada de la víctima': 'abogada-victima',
        'Su abogada': 'abogada-victima',
        'La madre de Sara': 'madre-sara',
        'El abogado de la persona investigada': 'abogado-defensa',
        'El abogado defensor': 'abogado-defensa',
        'La letrada de la Administración de Justicia': 'letrada',
        'El letrado de la Administración de Justicia': 'letrada',
        'El letrado de la defensa': 'abogado-defensa',
        'Los jueces': 'jueza',
        'El equipo psicosocial': 'ana',
        'Una agente de policía': 'policia',
        'La persona investigada': 'investigada',
        'Un testigo': 'testigo',
        'Tut': 'tut',
      };
      nombres.forEach((nombre, id) => expect(PersonajesPixel.buscar(nombre), id, reason: nombre));
    });

    test('no distingue mayúsculas ni tildes', () {
      expect(PersonajesPixel.buscar('LUCIA'), 'lucia');
      expect(PersonajesPixel.buscar('ana, la PSICOLOGA'), 'ana');
      expect(PersonajesPixel.buscar('la tia elena'), 'elena');
    });

    test('null si no hay ningún personaje para ese nombre', () {
      expect(PersonajesPixel.buscar('Su perro'), isNull);
      expect(PersonajesPixel.buscar('Mariana'), isNull, reason: '«Ana» es una palabra entera');
      expect(PersonajesPixel.buscar(''), isNull);
    });

    test('en la Fiscalía, el fiscal va sin toga; en la sala de vistas, con ella', () {
      for (final lugar in ['fiscalia', 'Fiscalía de Menores', 'despacho del fiscal']) {
        expect(PersonajesPixel.buscar('El fiscal', lugar: lugar), 'fiscal-despacho', reason: lugar);
      }
      for (final lugar in ['sala_vistas', 'juzgado', null]) {
        expect(PersonajesPixel.buscar('El fiscal', lugar: lugar), 'fiscal', reason: '$lugar');
      }
    });

    test('en la Fiscalía, la abogada también va sin toga', () {
      expect(PersonajesPixel.buscar('Su abogada', lugar: 'fiscalia'), 'abogada-despacho');
      expect(PersonajesPixel.buscar('La abogada de la víctima', lugar: 'Fiscalía de Menores'), 'abogada-despacho');
      expect(PersonajesPixel.buscar('Su abogada', lugar: 'sala_vistas'), 'abogada-victima');
      expect(PersonajesPixel.buscar('La letrada', lugar: 'fiscalia'), 'letrada');
    });

    test('buscarTodos: dos personas para un plural', () {
      expect(PersonajesPixel.buscarTodos('Sus padres'), ['padre-sergio', 'madre-sergio']);
      expect(PersonajesPixel.buscarTodos('Los padres de Sergio'), ['padre-sergio', 'madre-sergio']);
      expect(PersonajesPixel.buscarTodos('Los abogados'), ['abogada-victima', 'abogado-defensa']);
      expect(PersonajesPixel.buscarTodos('Su madre'), ['madre-sergio']);
      expect(PersonajesPixel.buscarTodos('El fiscal', lugar: 'fiscalia'), ['fiscal-despacho']);
      expect(PersonajesPixel.buscarTodos('Su perro'), isEmpty);
    });

    test('todas las personas de las escenas de los casos tienen dibujo', () {
      for (final archivo in Directory('assets/mock/content/juego').listSync().whereType<File>()) {
        if (!archivo.path.endsWith('.json')) continue;
        final caso = jsonDecode(archivo.readAsStringSync()) as Map<String, dynamic>;
        for (final escena in (caso['escenas'] as List).cast<Map<String, dynamic>>()) {
          for (final nombre in (escena['personajes'] as List).cast<String>()) {
            final ids = PersonajesPixel.buscarTodos(nombre, lugar: escena['lugar'] as String?);
            expect(ids, isNotEmpty, reason: '${archivo.path}, ${escena['id']}: «$nombre»');
            for (final id in ids) {
              expect(PersonajesPixel.porId(id), isNotNull, reason: id);
            }
          }
        }
      }
    });

    test('cada id que devuelve existe', () {
      for (final nombre in ['Lucía', 'El fiscal', 'La letrada', 'Tut', 'Un policía']) {
        expect(PersonajesPixel.porId(PersonajesPixel.buscar(nombre)!), isNotNull, reason: nombre);
      }
    });
  });

  group('En pantalla', () {
    final fondo = Sprite('suelo de prueba', (LienzoPixel(160, 96, 'h')..rect(0, 62, 160, 34, 'm')).filas);

    Widget escena({bool reducir = false}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reducir),
          child: Center(
            child: SizedBox(
              width: 360,
              child: EscenaPixel(
                fondo: fondo,
                alPulsar: (_) {},
                elementos: [
                  for (var i = 0; i < PersonajesPixel.todos.length; i++)
                    ElementoEscena(
                      sprite: PersonajesPixel.todos[i].sprite,
                      x: 10 + (i % 9) * 17,
                      y: i < 9 ? 76 : 94,
                      id: PersonajesPixel.todos[i].id,
                      etiqueta: PersonajesPixel.todos[i].descripcion,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('todos juntos en una escena: se pintan, se animan y paran su reloj al salir', (tester) async {
      final antes = RelojPixel.debugEnMarcha;
      await tester.pumpWidget(escena());
      expect(RelojPixel.debugEnMarcha, antes + 1);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 450));
      }
      expect(tester.takeException(), isNull);
      for (final ficha in PersonajesPixel.todos) {
        expect(find.bySemanticsLabel(ficha.descripcion), findsOneWidget, reason: ficha.id);
      }
      await tester.pumpWidget(const SizedBox());
      expect(RelojPixel.debugEnMarcha, antes);
    });

    testWidgets('con «reducir animaciones», nadie se mueve', (tester) async {
      final antes = RelojPixel.debugEnMarcha;
      await tester.pumpWidget(escena(reducir: true));
      await tester.pump(const Duration(seconds: 3));
      expect(RelojPixel.debugEnMarcha, antes);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un personaje suelto, nítido y con su etiqueta', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SpritePixel(
              sprite: PersonajesPixel.jueza,
              alto: 144,
              etiqueta: PersonajesPixel.ficha('jueza')!.nombre,
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('La jueza'), findsOneWidget);
      expect(tester.getSize(find.byType(SpritePixel)), const Size(96, 144));
      await tester.pumpWidget(const SizedBox());
    });
  });
}
