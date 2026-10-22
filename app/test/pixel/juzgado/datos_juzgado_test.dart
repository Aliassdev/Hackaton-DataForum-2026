import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/escenarios/escenarios.dart';
import 'package:tuturno/pixel/juzgado/juzgado.dart';
import 'package:tuturno/pixel/juzgado/reparto_juzgado.dart' show parpadear, respirar;
import 'package:tuturno/pixel/juzgado/sala_juzgado.dart' show pintarSalaMenores;
import 'package:tuturno/pixel/motor/motor.dart';
import 'package:tuturno/pixel/personajes/personajes.dart';

void main() {
  group('textos', () {
    for (final modo in ModoJuzgado.values) {
      final datos = DatosJuzgado.de(modo);

      test('${modo.name}: cada rol tiene quién es, qué hace, icono y fuentes del BOE', () {
        expect(datos.roles, isNotEmpty);
        final ids = datos.roles.map((rol) => rol.id).toList();
        expect(ids.toSet(), hasLength(ids.length), reason: 'ids repetidos');
        for (final rol in datos.roles) {
          expect(rol.titulo.trim(), isNotEmpty);
          expect(rol.corto.trim(), isNotEmpty);
          expect(rol.quienEs.trim().length, greaterThan(40), reason: rol.id);
          expect(rol.queHace.trim().length, greaterThan(40), reason: rol.id);
          expect(rol.fuentes, isNotEmpty, reason: rol.id);
          for (final fuente in rol.fuentes) {
            expect(fuente.boe, matches(RegExp(r'^BOE-A-\d{4}-\d+$')), reason: '${rol.id}: ${fuente.etiqueta}');
            expect(fuente.cita.trim().length, greaterThan(30), reason: '${rol.id}: ${fuente.etiqueta}');
            expect(fuente.articulo.trim(), isNotEmpty);
            expect(nombresNormas, contains(fuente.norma), reason: 'falta el nombre largo de ${fuente.norma}');
            expect(fuente.url, startsWith('https://www.boe.es/buscar/act.php?id=BOE-A-'));
          }
        }
        for (final nota in datos.notas) {
          expect(nota.fuente.cita, isNotEmpty);
        }
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

    test('los textos son para chicos y chicas: frases cortas y sin «etc.» ni abreviaturas de leyes', () {
      for (final rol in [...datosSalaVistas.roles, ...datosMenores.roles]) {
        for (final texto in [rol.quienEs, rol.queHace, ?rol.sabiasQue]) {
          for (final frase in texto.split(RegExp(r'(?<=[.:;?!])\s+'))) {
            expect(frase.split(' ').length, lessThanOrEqualTo(32), reason: '${rol.id}: «$frase»');
          }
          expect(texto, isNot(contains('etc.')));
          expect(texto, isNot(matches(RegExp(r'\b(LO|LECrim|LOPJ|EOMF|art\.)\b'))), reason: rol.id);
        }
      }
    });

    test('la sala de vistas tiene a las nueve personas que se piden', () {
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
      expect(datosSalaVistas.rol('abogadaVictima')!.subtitulo, 'Acusación particular');
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
      expect(montaje.fondo, same(EscenariosPixel.salaVistas.fondo));
      expect(montaje.puesto('jueza')!.sprite, same(PersonajesPixel.jueza));
      expect(montaje.puesto('policia')!.sprite, same(PersonajesPixel.policia));
      expect(montaje.puesto('publico')!.sprite, same(RepartoJuzgado.publico));
      // El fiscal de la audiencia de menores es el mismo que el de las escenas de la Fiscalía.
      expect(MontajeJuzgado.de(ModoJuzgado.menores).puesto('fiscalMenores')!.sprite, same(PersonajesPixel.fiscal));
      // Si falta un personaje, el de reserva.
      expect(spriteDeReserva('juezMenores'), same(RepartoJuzgado.juezMenores));
    });

    test('la chispa visible y la invisible comparten animación y ancla', () {
      expect(MueblesJuzgado.chispa.animacion, MueblesJuzgado.sinChispa.animacion);
      expect(MueblesJuzgado.chispa.ancla, MueblesJuzgado.sinChispa.ancla);
      expect(MueblesJuzgado.chispa.animacion!.descanso!.fotograma, 0, reason: 'quieta, la chispa grande');
      for (final fila in MueblesJuzgado.sinChispa.fotogramas.expand((f) => f)) {
        expect(fila, '.......');
      }
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
