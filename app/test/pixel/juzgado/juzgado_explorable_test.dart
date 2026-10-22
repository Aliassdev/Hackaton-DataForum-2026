import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/juzgado/juzgado.dart';
import 'package:tuturno/pixel/motor/motor.dart';

import 'ayudantes.dart';

/// La etiqueta del botón de la sala para [rol], antes y después de descubrirlo.
String _etiquetaPorDescubrir(RolJuzgado rol) => '${rol.titulo}. Toca para saber quién es.';
String _etiquetaDescubierto(RolJuzgado rol) => '${rol.titulo}. Ya sabes quién es: toca para volver a ver su carta.';

/// Los elementos que pinta ahora la escena.
List<ElementoEscena> _elementos(WidgetTester tester) => tester.widget<EscenaPixel>(find.byType(EscenaPixel)).elementos;

Finder _carta(String titulo) => find.descendant(of: find.byType(CartaRol), matching: find.text(titulo));

void main() {
  for (final modo in ModoJuzgado.values) {
    final datos = DatosJuzgado.de(modo);
    final total = datos.roles.length;

    group(modo.name, () {
      testWidgets('cada persona de la sala abre su carta, con quién es, qué hace y la fuente', (tester) async {
        await montarJuzgado(tester, modo: modo);
        expect(find.byType(CartaRol), findsNothing);
        for (final rol in datos.roles) {
          await tocarRol(tester, rol.id, modo: modo);
          expect(_carta(rol.titulo), findsOneWidget, reason: rol.id);
          expect(find.descendant(of: find.byType(CartaRol), matching: find.text('QUIÉN ES')), findsOneWidget);
          expect(find.text(rol.quienEs), findsOneWidget, reason: rol.id);
          expect(find.text(rol.queHace), findsOneWidget, reason: rol.id);
          expect(find.textContaining(rol.fuentes.first.etiqueta), findsOneWidget, reason: rol.id);
          // La persona tocada lleva el halo; nadie más.
          final resaltados = _elementos(tester).where((elemento) => elemento.resaltado).map((e) => e.id).toList();
          expect(resaltados, [rol.id]);
        }
        expect(progreso(total, total), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('el progreso cuenta a cada persona una sola vez', (tester) async {
        final descubiertos = <String>[];
        await montarJuzgado(tester, modo: modo, onDescubierto: descubiertos.add);
        expect(progreso(0, total), findsOneWidget);
        final primero = datos.roles.first.id;
        final segundo = datos.roles.last.id;
        await tocarRol(tester, primero, modo: modo);
        expect(progreso(1, total), findsOneWidget);
        await tocarRol(tester, primero, modo: modo);
        expect(progreso(1, total), findsOneWidget);
        await tocarRol(tester, segundo, modo: modo);
        expect(progreso(2, total), findsOneWidget);
        expect(descubiertos, [primero, segundo]);
      });

      testWidgets('la celebración se dispara una sola vez, al conocer a la última persona', (tester) async {
        var celebraciones = 0;
        await montarJuzgado(tester, modo: modo, onTodosDescubiertos: () => celebraciones++);
        for (final rol in datos.roles.take(total - 1)) {
          await tocarRol(tester, rol.id, modo: modo);
        }
        expect(celebraciones, 0);
        expect(find.byType(EnhorabuenaJuzgado), findsNothing);
        await tocarRol(tester, datos.roles.last.id, modo: modo);
        expect(celebraciones, 1);
        // Volver a tocar a alguien (o a todos) no celebra otra vez.
        for (final rol in datos.roles) {
          await tocarRol(tester, rol.id, modo: modo);
        }
        expect(celebraciones, 1);
        await tester.tap(find.byTooltip('Cerrar'));
        await tester.pumpAndSettle();
        expect(find.byType(EnhorabuenaJuzgado), findsOneWidget);
        expect(find.text('¡Ya sabes quién es quién!'), findsOneWidget);
      });

      testWidgets('cada persona es un botón con su nombre para los lectores de pantalla', (tester) async {
        final semantica = tester.ensureSemantics();
        await montarJuzgado(tester, modo: modo);
        expect(find.bySemanticsLabel(datos.descripcion), findsOneWidget);
        // Las fichas de abajo también son botones: con lector de pantalla se activan igual que con el dedo.
        final ficha = '${datos.roles.first.titulo}. Todavía no: toca para ver dónde está en la sala.';
        expect(
          tester.getSemantics(find.bySemanticsLabel(ficha)),
          // (Puede estar más abajo de lo que se ve, desplazable: por eso «contiene» y no «coincide».)
          isSemantics(label: ficha, isButton: true, hasTapAction: true),
        );
        for (final rol in datos.roles) {
          expect(
            tester.getSemantics(find.bySemanticsLabel(_etiquetaPorDescubrir(rol))),
            matchesSemantics(label: _etiquetaPorDescubrir(rol), isButton: true, hasTapAction: true),
            reason: rol.id,
          );
        }
        final primero = datos.roles.first;
        await tocarRol(tester, primero.id, modo: modo);
        expect(find.bySemanticsLabel(_etiquetaDescubierto(primero)), findsOneWidget);
        expect(find.bySemanticsLabel(_etiquetaPorDescubrir(primero)), findsNothing);
        // La barra se lee como texto.
        expect(find.bySemanticsLabel('Has conocido a 1 de $total'), findsOneWidget);
        semantica.dispose();
      });

      testWidgets('las chispas señalan a quien falta y desaparecen al conocerle, sin reiniciar las animaciones', (
        tester,
      ) async {
        await montarJuzgado(tester, modo: modo);
        List<ElementoEscena> chispas() => _elementos(tester)
            .where((e) => identical(e.sprite, MueblesJuzgado.chispa) || identical(e.sprite, MueblesJuzgado.sinChispa))
            .toList();
        int visibles() => chispas().where((e) => identical(e.sprite, MueblesJuzgado.chispa)).length;
        expect(chispas(), hasLength(total));
        expect(visibles(), total);
        final antes = [for (final e in _elementos(tester)) e.sprite.animacion];
        await tocarRol(tester, datos.roles.first.id, modo: modo);
        expect(visibles(), total - 1);
        // Las mismas animaciones en el mismo orden: el reloj de la escena no se reinicia y nadie da un salto.
        expect(listEquals([for (final e in _elementos(tester)) e.sprite.animacion], antes), isTrue);
      });
    });
  }

  testWidgets('el modo de menores enseña a sus personas y que hoy no hay público', (tester) async {
    await montarJuzgado(tester, modo: ModoJuzgado.menores);
    final menores = DatosJuzgado.de(ModoJuzgado.menores);
    expect(find.text('¿Quién es quién en el Juzgado de Menores?'), findsOneWidget);
    expect(progreso(0, 6), findsOneWidget);
    expect(menores.roles.map((rol) => rol.id), [
      'juezMenores',
      'fiscalMenores',
      'letradaMenor',
      'equipoTecnico',
      'menor',
      'familia',
    ]);
    final enLaSala = _elementos(tester).map((e) => e.id).whereType<String>().toSet();
    expect(enLaSala, menores.roles.map((rol) => rol.id).toSet());
    expect(enLaSala, isNot(contains('publico')));
    expect(enLaSala, isNot(contains('jueza')));
    expect(find.text('Hoy no hay público'), findsOneWidget);
    expect(find.text('¿Y Sergio?'), findsOneWidget);
    await tocarRol(tester, 'equipoTecnico', modo: ModoJuzgado.menores);
    expect(_carta('El equipo técnico'), findsOneWidget);
    expect(find.textContaining('psicología, la educación y el trabajo social'), findsOneWidget);
  });

  testWidgets('la ficha de quien aún no conoces lo ilumina en la sala; la de quien ya conoces abre su carta', (
    tester,
  ) async {
    await montarJuzgado(tester);
    await tester.ensureVisible(find.text('Letrada'));
    await tester.tap(find.text('Letrada'));
    await tester.pumpAndSettle();
    final resaltados = _elementos(tester).where((e) => e.resaltado).map((e) => e.id);
    expect(resaltados, ['letrada']);
    expect(find.byType(CartaRol), findsNothing);
    expect(progreso(0, 9), findsOneWidget);

    await tocarRol(tester, 'letrada');
    expect(progreso(1, 9), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(CartaRol), findsNothing);
    await tester.ensureVisible(find.text('Letrada'));
    await tester.tap(find.text('Letrada'));
    await tester.pumpAndSettle();
    expect(_carta('La letrada de la Administración de Justicia'), findsOneWidget);
  });

  testWidgets('«Qué dice la ley» enseña las citas literales del BOE', (tester) async {
    await montarJuzgado(tester);
    await tocarRol(tester, 'jueza');
    expect(find.textContaining('La justicia emana del pueblo'), findsNothing);
    await tester.ensureVisible(find.text('Qué dice la ley'));
    await tester.tap(find.text('Qué dice la ley'));
    await tester.pumpAndSettle();
    expect(find.textContaining('La justicia emana del pueblo'), findsOneWidget);
    expect(find.textContaining('BOE: BOE-A-1985-12666'), findsWidgets);
  });

  testWidgets('al abrir otra carta se lee desde arriba aunque la anterior se hubiera desplazado', (tester) async {
    await montarJuzgado(tester);
    await tocarRol(tester, 'jueza');
    await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byTooltip('Cerrar')).top, lessThan(tester.getRect(find.byType(EscenaPixel)).bottom));
    await tocarRol(tester, 'fiscal');
    // El botón de cerrar de la carta nueva se ve (está debajo de la sala y de la barra) y se puede tocar.
    expect(tester.getRect(find.byTooltip('Cerrar')).top, greaterThan(tester.getRect(find.byType(EscenaPixel)).bottom));
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(CartaRol), findsNothing);
  });

  testWidgets('con todo ya descubierto al empezar, no se vuelve a celebrar', (tester) async {
    var celebraciones = 0;
    final todos = {for (final rol in datosSalaVistas.roles) rol.id};
    await montarJuzgado(tester, descubiertosIniciales: todos, onTodosDescubiertos: () => celebraciones++);
    expect(progreso(9, 9), findsOneWidget);
    expect(find.byType(EnhorabuenaJuzgado), findsOneWidget);
    await tocarRol(tester, 'testigo');
    expect(celebraciones, 0);
  });

  testWidgets('cambiar de modo empieza de cero', (tester) async {
    const clave = Key('juzgado');
    await montarJuzgado(tester, clave: clave);
    await tocarRol(tester, 'jueza');
    expect(progreso(1, 9), findsOneWidget);
    await montarJuzgado(tester, clave: clave, modo: ModoJuzgado.menores);
    await tester.pumpAndSettle();
    expect(progreso(0, 6), findsOneWidget);
    expect(find.byType(CartaRol), findsNothing);
  });

  testWidgets('dentro de una lista ocupa lo que necesita y se puede jugar', (tester) async {
    await montarJuzgado(tester, enLista: true);
    await tocarRol(tester, 'policia');
    expect(_carta(datosSalaVistas.rol('policia')!.titulo), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('con letra grande en un móvil pequeño no se desborda nada y la carta nueva asoma', (tester) async {
    await montarJuzgado(tester, letra: 1.5, tamano: const Size(720, 1280), dpr: 2);
    await tocarRol(tester, 'abogadaVictima');
    // Aquí se desplaza todo junto: al abrir la carta, su cabecera queda a la vista.
    final alto = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(tester.getRect(find.byType(CartaRol)).top, lessThan(alto - 100));
    await tester.ensureVisible(find.text('Qué dice la ley'));
    await tester.tap(find.text('Qué dice la ley'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('en un móvil de 1080 píxeles la sala sale nítida, a 6 píxeles de pantalla por píxel', (tester) async {
    await montarJuzgado(tester);
    final caja = tester.getRect(find.byType(EscenaPixel));
    final encaje = EncajePixel(caja: caja.size, arte: const Size(160, 96), dpr: 2.75);
    expect(encaje.nitido, isTrue);
    expect(encaje.fisicos, 6);
  });

  group('animaciones', () {
    testWidgets('respiran, parpadean y las chispas laten mientras se ve la sala; al salir, todo se para', (
      tester,
    ) async {
      await montarJuzgado(tester, animar: true);
      expect(RelojPixel.debugEnMarcha, 1);
      // Unos segundos de sala: respiraciones, parpadeos y chispas, sin errores; descubrir a alguien no lo para.
      await tester.pump(const Duration(seconds: 3));
      await tocarRol(tester, 'testigo');
      expect(RelojPixel.debugEnMarcha, 1);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox());
      expect(RelojPixel.debugEnMarcha, 0);
    });

    testWidgets('con «reducir animaciones» nada se mueve y pumpAndSettle termina', (tester) async {
      await montarJuzgado(tester, animar: true, reducir: true);
      await tester.pumpAndSettle();
      expect(RelojPixel.debugEnMarcha, 0);
      await tocarRol(tester, 'jueza');
      expect(RelojPixel.debugEnMarcha, 0);
    });
  });
}
