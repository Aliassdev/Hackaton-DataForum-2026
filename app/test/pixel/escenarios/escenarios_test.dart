import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/escenarios/escenario_pixel.dart';
import 'package:tuturno/pixel/escenarios/escenarios.dart';
import 'package:tuturno/pixel/motor/motor.dart';

import 'figurantes.dart';

/// Todos los lugares, con el de reserva.
final _todos = [...EscenariosPixel.lugares, EscenariosPixel.reserva].map(EscenariosPixel.de).toList();

/// El píxel ([x], [y]) del sprite de [pieza], en coordenadas del fondo, o «.» si cae fuera de la pieza.
String _pixelDePieza(ElementoEscena pieza, int x, int y) {
  final rect = pieza.rectPixel;
  final i = x - rect.left.toInt(), j = y - rect.top.toInt();
  final filas = pieza.sprite.fotogramas.first;
  if (j < 0 || j >= filas.length || i < 0 || i >= filas[j].length) return '.';
  return filas[j][i];
}

/// Si alguna pieza de [escenario] que se pinta encima de quien tiene los pies en la fila [pies] (su borde de abajo
/// está más abajo) tapa el píxel ([x], [y]) del fondo.
bool _tapado(EscenarioPixel escenario, int x, int y, {required int pies}) =>
    escenario.delante.any((pieza) => pieza.y > pies && _pixelDePieza(pieza, x, y) != '.');

void main() {
  group('los fondos', () {
    test('están los doce lugares de los casos, cada uno con su clave', () {
      expect(EscenariosPixel.lugares, [
        'casa',
        'colegio',
        'instituto',
        'juzgado',
        'sala_espera',
        'sala_gesell',
        'sala_observacion',
        'sala_vistas',
        'fiscalia',
        'comisaria',
        'habitacion',
        'despues',
      ]);
      for (final lugar in EscenariosPixel.lugares) {
        expect(EscenariosPixel.de(lugar).lugar, lugar);
      }
      expect(EscenariosPixel.todos.map((e) => e.lugar), EscenariosPixel.lugares);
    });

    test('miden 160 × 96 y todos sus fotogramas son válidos', () {
      for (final escenario in _todos) {
        final fondo = escenario.fondo;
        expect((fondo.ancho, fondo.alto), (160, 96), reason: escenario.lugar);
        fondo.validar();
        final pasos = fondo.animacion?.pasos ?? const <PasoPixel>[];
        for (final paso in pasos) {
          expect(paso.dy, 0, reason: '${escenario.lugar}: el fondo no se desplaza');
        }
        if (fondo.fotogramas.length > 1) {
          expect(fondo.animacion?.descanso?.fotograma, 0, reason: '${escenario.lugar}: el descanso es el fotograma 0');
          expect(fondo.animacion!.seMueve, isTrue);
        }
      }
    });

    test('no tienen huecos: ni píxeles transparentes ni la sombra semitransparente', () {
      // Un «.» dejaría ver el margen de la escena, y la «x» se pintaría sobre el margen, no sobre el suelo.
      for (final escenario in _todos) {
        for (final (f, filas) in escenario.fondo.fotogramas.indexed) {
          for (final (y, fila) in filas.indexed) {
            expect(fila.contains('.'), isFalse, reason: '${escenario.lugar}, fotograma $f, fila $y: «.»');
            expect(fila.contains('x'), isFalse, reason: '${escenario.lugar}, fotograma $f, fila $y: «x»');
          }
        }
      }
    });

    test('los que se mueven cambian poco de un fotograma a otro (unos detalles, no el fondo entero)', () {
      final animados = _todos.where((e) => e.fondo.fotogramas.length > 1).map((e) => e.lugar).toSet();
      expect(animados, {'casa', 'sala_espera', 'habitacion', 'despues'});
      for (final escenario in _todos.where((e) => animados.contains(e.lugar))) {
        final a = escenario.fondo.fotogramas[0], b = escenario.fondo.fotogramas[1];
        var distintos = 0;
        for (var y = 0; y < 96; y++) {
          for (var x = 0; x < 160; x++) {
            if (a[y][x] != b[y][x]) distintos++;
          }
        }
        expect(distintos, inInclusiveRange(1, 160 * 96 ~/ 20), reason: escenario.lugar);
      }
    });

    test('se pintan una vez: pedir el mismo lugar da el mismo fondo', () {
      expect(identical(EscenariosPixel.de('casa'), EscenariosPixel.casa), isTrue);
      expect(identical(EscenariosPixel.porLugar('Sala de vistas'), EscenariosPixel.salaVistas.fondo), isTrue);
    });

    test('tienen una descripción para los lectores de pantalla', () {
      for (final escenario in _todos) {
        expect(escenario.descripcion.length, greaterThan(20), reason: escenario.lugar);
      }
    });
  });

  group('porLugar y de', () {
    test('aceptan las claves de los casos y la forma del enum del juego', () {
      for (final (valor, clave) in [
        ('sala_gesell', 'sala_gesell'),
        ('salaGesell', 'sala_gesell'),
        ('salaEspera', 'sala_espera'),
        ('fiscalia', 'fiscalia'),
        ('despues', 'despues'),
        ('juzgado', 'juzgado'),
      ]) {
        expect(EscenariosPixel.clave(valor), clave, reason: valor);
        expect(EscenariosPixel.de(valor).lugar, clave, reason: valor);
      }
    });

    test('no les importan las tildes, las mayúsculas, los espacios, los guiones ni los artículos', () {
      for (final (valor, clave) in [
        ('  Después ', 'despues'),
        ('En la Sala Gesell', 'sala_gesell'),
        ('En la sala de espera', 'sala_espera'),
        ('sala-de-vistas', 'sala_vistas'),
        ('Sala de Observación', 'sala_observacion'),
        ('LA COMISARÍA', 'comisaria'),
        ('Fiscalía de Menores', 'fiscalia'),
        ('mi habitación', 'habitacion'),
        ('Habitacion', 'habitacion'),
      ]) {
        expect(EscenariosPixel.clave(valor), clave, reason: valor);
      }
    });

    test('entienden algunos sinónimos', () {
      for (final (valor, clave) in [
        ('hogar', 'casa'),
        ('escuela', 'colegio'),
        ('IES', 'instituto'),
        ('tribunal', 'juzgado'),
        ('juicio', 'sala_vistas'),
        ('Cámara Gesell', 'sala_gesell'),
        ('policía', 'comisaria'),
        ('dormitorio', 'habitacion'),
        ('parque', 'despues'),
      ]) {
        expect(EscenariosPixel.clave(valor), clave, reason: valor);
      }
    });

    test('lo que no tiene fondo propio usa el de reserva', () {
      for (final valor in ['otro', 'hospital', '', '   ', 'sala', 'generico']) {
        expect(EscenariosPixel.de(valor).lugar, 'generico', reason: valor);
      }
      expect(EscenariosPixel.clave('hospital'), isNull);
      expect(EscenariosPixel.tiene('hospital'), isFalse);
      expect(EscenariosPixel.tiene('Sala de espera'), isTrue);
      expect(identical(EscenariosPixel.porLugar('hospital'), EscenariosPixel.generico.fondo), isTrue);
    });
  });

  group('los puestos', () {
    test('todos los lugares tienen izquierda, centro y derecha, de izquierda a derecha y sin solaparse', () {
      for (final escenario in _todos) {
        final izquierda = escenario.puesto('izquierda'), centro = escenario.puesto('centro');
        final derecha = escenario.puesto('derecha');
        expect([izquierda, centro, derecha], everyElement(isNotNull), reason: escenario.lugar);
        expect(centro!.x - izquierda!.x, greaterThanOrEqualTo(24), reason: escenario.lugar);
        expect(derecha!.x - centro.x, greaterThanOrEqualTo(24), reason: escenario.lugar);
      }
    });

    test('están dentro del fondo (el público, con los pies algo más abajo, tras el banco)', () {
      for (final escenario in _todos) {
        for (final MapEntry(key: nombre, value: punto) in escenario.puestos.entries) {
          expect(punto.x, inInclusiveRange(10, 150), reason: '${escenario.lugar}: $nombre');
          expect(punto.y, inInclusiveRange(48, nombre == 'publico' ? 104 : 96), reason: '${escenario.lugar}: $nombre');
        }
      }
    });

    test('la sala de vistas tiene el sitio de cada uno, en el orden de la sala', () {
      expect(PuestoVista.values.map((p) => p.clave), [
        'jueza',
        'letrada',
        'fiscal',
        'abogada_victima',
        'abogado_defensa',
        'persona_investigada',
        'testigo',
        'policia',
        'publico',
      ]);
      final sala = EscenariosPixel.salaVistas;
      for (final puesto in PuestoVista.values) {
        expect(sala.puesto(puesto.clave), puesto.punto, reason: puesto.clave);
        expect(EscenariosPixel.puestosSalaVistas[puesto.clave], puesto.punto);
        expect(puesto.nombre, isNotEmpty);
      }
      // Distribución española: la acusación a la izquierda (vista desde el público), la defensa a la derecha, la
      // jueza en el centro y al fondo, quien declara en el centro y delante.
      expect(PuestoVista.fiscal.x, lessThan(PuestoVista.jueza.x));
      expect(PuestoVista.abogadaVictima.x, lessThan(PuestoVista.jueza.x));
      expect(PuestoVista.abogadoDefensa.x, greaterThan(PuestoVista.jueza.x));
      expect(PuestoVista.personaInvestigada.x, greaterThan(PuestoVista.jueza.x));
      expect(PuestoVista.testigo.x, PuestoVista.jueza.x);
      expect(PuestoVista.jueza.y, lessThan(PuestoVista.fiscal.y));
      expect(PuestoVista.fiscal.y, lessThan(PuestoVista.testigo.y));
      expect(PuestoVista.testigo.y, lessThan(PuestoVista.publico.y));
      // Ningún par de puestos en el mismo sitio.
      final puntos = PuestoVista.values.map((p) => p.punto).toSet();
      expect(puntos, hasLength(PuestoVista.values.length));
    });

    test('en la sala de vistas no hay tarima: la mesa de la jueza, a la misma altura que las demás', () {
      // LOPJ, art. 187.2, como guía de dibujo: en estrados, todos se sientan a la misma altura.
      final sala = EscenariosPixel.salaVistas;
      final estrado = sala.delante.firstWhere((p) => p.sprite.nombre.contains('estrado')).sprite.fotogramas.first;
      int tablero(int x) => estrado.indexWhere((fila) => fila[x] == 'm');
      expect(tablero(44), tablero(10), reason: 'la mesa de la jueza y la de la izquierda');
      expect(tablero(44), tablero(75), reason: 'la mesa de la jueza y la de la letrada');
      // Ni el escalón de la tarima a los lados del estrado.
      final fondo = sala.fondo.fotogramas.first;
      expect(fondo[57].substring(26, 36), isNot('N' * 10));
      expect(fondo[57].substring(124, 134), isNot('N' * 10));
    });

    test('quien se sienta detrás de un mueble tiene los pies tapados y la cara a la vista', () {
      final detras = <(EscenarioPixel, List<String>)>[
        (
          EscenariosPixel.salaVistas,
          [
            'jueza',
            'letrada',
            'fiscal',
            'abogada_victima',
            'abogado_defensa',
            'persona_investigada',
            'testigo',
            'publico',
          ],
        ),
        (EscenariosPixel.salaObservacion, ['jueza', 'fiscal', 'abogada_victima', 'abogado_defensa', 'letrada']),
        (EscenariosPixel.fiscalia, ['fiscal']),
        (EscenariosPixel.comisaria, ['policia']),
        (EscenariosPixel.juzgado, ['recepcion']),
      ];
      for (final (escenario, puestos) in detras) {
        for (final nombre in puestos) {
          final p = escenario.puesto(nombre)!;
          final pies = p.y - 2;
          final cara = p.y - 28; // los ojos de un adulto de 36 de alto
          expect(
            pies >= 96 || _tapado(escenario, p.x, pies, pies: p.y),
            isTrue,
            reason: '${escenario.lugar}: los pies de $nombre deberían quedar tapados',
          );
          expect(
            _tapado(escenario, p.x, cara, pies: p.y),
            isFalse,
            reason: '${escenario.lugar}: la cara de $nombre se tapa',
          );
        }
      }
    });
  });

  group('las piezas de delante', () {
    test('son el fondo recortado: pintadas sin nadie, no cambian nada', () {
      for (final escenario in _todos) {
        final fondo = escenario.fondo.fotogramas.first;
        for (final pieza in escenario.delante) {
          final rect = pieza.rectPixel;
          var opacos = 0;
          for (var y = rect.top.toInt(); y < rect.bottom; y++) {
            for (var x = rect.left.toInt(); x < rect.right; x++) {
              final clave = _pixelDePieza(pieza, x, y);
              if (clave == '.' || x < 0 || y < 0 || x >= 160 || y >= 96) continue;
              opacos++;
              expect(clave, fondo[y][x], reason: '${escenario.lugar}, ${pieza.sprite.nombre} en ($x, $y)');
            }
          }
          expect(opacos, greaterThan(0), reason: pieza.sprite.nombre);
        }
      }
    });

    test('los lugares con muebles que tapan los tienen', () {
      final conPiezas = {for (final e in _todos) e.lugar: e.delante.length};
      expect(conPiezas['sala_vistas'], 6);
      expect(conPiezas['sala_observacion'], 1);
      expect(conPiezas['fiscalia'], 1);
      expect(conPiezas['comisaria'], 1);
      expect(conPiezas['juzgado'], 1);
      expect(conPiezas['casa'], 0);
    });
  });

  group('componer', () {
    test('pinta antes a quien está detrás de un mueble y después a quien está delante', () {
      final sala = EscenariosPixel.salaVistas;
      final juez = sala.colocar('jueza', jueza, id: 'jueza');
      final testigo = sala.colocar('testigo', adulta, id: 'testigo');
      final delPublico = sala.colocar('publico', publico, id: 'publico');
      final centro = sala.colocar('centro', adulta, id: 'centro');
      final orden = sala.componer([centro, delPublico, testigo, juez]);
      int posicion(Object elemento) => orden.indexOf(elemento as ElementoEscena);
      ElementoEscena pieza(String nombre) => sala.delante.firstWhere((p) => p.sprite.nombre.contains(nombre));
      expect(orden, hasLength(4 + sala.delante.length));
      expect(posicion(juez), lessThan(posicion(pieza('estrado'))));
      expect(posicion(testigo), lessThan(posicion(pieza('declara'))));
      expect(posicion(delPublico), lessThan(posicion(pieza('público (izquierda)'))));
      expect(posicion(centro), greaterThan(posicion(pieza('declara'))));
    });

    test('a la misma altura, el personaje queda delante, y entre personajes se respeta el orden de la lista', () {
      final mueble = Sprite('mueble', ['NN', 'NN']);
      final pieza = piezaEn(mueble, 10, 10); // su borde de abajo está en la fila 12
      final escenario = EscenarioPixel(lugar: 'prueba', descripcion: 'prueba', fondo: mueble, delante: [pieza]);
      final a = ElementoEscena(sprite: nino, x: 11, y: 12, id: 'a');
      final b = ElementoEscena(sprite: nino, x: 11, y: 12, id: 'b');
      expect(escenario.componer([a, b]), [pieza, a, b]);
      expect(escenario.componer([b, a]), [pieza, b, a]);
    });

    test('colocar pone los pies en el puesto, o en el centro si el lugar no tiene ese puesto', () {
      final casa = EscenariosPixel.casa;
      final enCentro = casa.colocar('jueza', nino, id: 'x', etiqueta: 'X', espejo: true, resaltado: true);
      expect((x: enCentro.x, y: enCentro.y), casa.puesto('centro'));
      expect((enCentro.id, enCentro.etiqueta, enCentro.espejo, enCentro.resaltado), ('x', 'X', true, true));
      final juez = EscenariosPixel.salaVistas.colocar('jueza', jueza);
      expect((x: juez.x, y: juez.y), PuestoVista.jueza.punto);
    });
  });

  group('en una EscenaPixel', () {
    testWidgets('cada fondo se monta, se asienta y deja tocar a quien está en un puesto', (tester) async {
      tester.view
        ..physicalSize = const Size(1080, 2400)
        ..devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      for (final escenario in _todos) {
        final tocados = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  EscenaPixel(
                    key: ValueKey(escenario.lugar),
                    fondo: escenario.fondo,
                    descripcion: escenario.descripcion,
                    alPulsar: tocados.add,
                    elementos: escenario.componer([escenario.colocar('centro', nino, id: 'yo', etiqueta: 'Yo')]),
                  ),
                ],
              ),
            ),
          ),
        );
        // Las animaciones van con temporizadores, no fotograma a fotograma: pumpAndSettle termina.
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Yo'));
        expect(tocados, ['yo'], reason: escenario.lugar);
        expect(find.bySemanticsLabel(escenario.descripcion), findsOneWidget, reason: escenario.lugar);
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('con «reducir animaciones», los fondos que se mueven se quedan en el fotograma 0', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: EscenaPixel(fondo: EscenariosPixel.habitacion.fondo),
          ),
        ),
      );
      // Sin animaciones no queda ningún temporizador: pumpAndSettle termina enseguida.
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
