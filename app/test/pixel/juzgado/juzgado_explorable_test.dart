import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

/// El nombre corto de la ficha del Letrado o Letrada de la Administración de Justicia.
final _letrada = datosSalaVistas.rol('letrada')!.corto;

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
          final fuente = find.descendant(of: find.byType(CartaRol), matching: find.textContaining('Fuente:'));
          if (rol.fuentes.isEmpty) {
            // Una carta que solo presenta a la persona no cita ninguna ley.
            expect(fuente, findsNothing, reason: rol.id);
            expect(find.text('Qué dice la ley'), findsNothing, reason: rol.id);
          } else {
            expect(find.textContaining(rol.fuentes.first.etiqueta), findsOneWidget, reason: rol.id);
          }
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

      testWidgets('las chispas señalan a quien falta y se van al conocerle (una invisible seguiría repintando)', (
        tester,
      ) async {
        await montarJuzgado(tester, modo: modo);
        int chispas() => _elementos(tester).where((e) => identical(e.sprite, MueblesJuzgado.chispa)).length;
        expect(chispas(), total);
        await tocarRol(tester, datos.roles.first.id, modo: modo);
        expect(chispas(), total - 1);
        // Las personas siguen en su sitio y con su animación.
        expect(_elementos(tester).where((e) => e.id != null).map((e) => e.id).toSet(), {
          for (final rol in datos.roles) rol.id,
        });
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
    expect(find.textContaining('ayudan al juez y al fiscal de menores'), findsOneWidget);
  });

  testWidgets('la ficha de quien aún no conoces lo ilumina en la sala; la de quien ya conoces abre su carta', (
    tester,
  ) async {
    await montarJuzgado(tester);
    await tester.ensureVisible(find.text(_letrada));
    await tester.tap(find.text(_letrada));
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
    await tester.ensureVisible(find.text(_letrada));
    await tester.tap(find.text(_letrada));
    await tester.pumpAndSettle();
    expect(_carta('Letrado o Letrada de la Administración de Justicia'), findsOneWidget);
  });

  testWidgets('con «reducir animaciones», abrir y cerrar «Qué dice la ley» no salta ningún assert', (tester) async {
    await montarJuzgado(tester, reducir: true);
    await tocarRol(tester, 'jueza');
    await tester.ensureVisible(find.text('Qué dice la ley'));
    await tester.tap(find.text('Qué dice la ley'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Toda víctima será informada de manera inmediata'), findsOneWidget);
    await tester.ensureVisible(find.text('Ocultar qué dice la ley'));
    await tester.tap(find.text('Ocultar qué dice la ley'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Toda víctima será informada de manera inmediata'), findsNothing);
  });

  testWidgets('el progreso guardado que llega tarde se suma, sin volver a celebrar', (tester) async {
    var celebraciones = 0;
    const clave = Key('juzgado');
    await montarJuzgado(tester, clave: clave, onTodosDescubiertos: () => celebraciones++);
    expect(progreso(0, 9), findsOneWidget);
    await montarJuzgado(
      tester,
      clave: clave,
      descubiertosIniciales: {'jueza', 'fiscal', 'letrada'},
      onTodosDescubiertos: () => celebraciones++,
    );
    expect(progreso(3, 9), findsOneWidget);
    final todos = {for (final rol in datosSalaVistas.roles) rol.id};
    await montarJuzgado(tester, clave: clave, descubiertosIniciales: todos, onTodosDescubiertos: () => celebraciones++);
    await tester.pumpAndSettle();
    expect(progreso(9, 9), findsOneWidget);
    expect(celebraciones, 0);
  });

  testWidgets('con lector de pantalla, la ficha de quien falta abre su carta; sin él, dice dónde está', (tester) async {
    final anuncios = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
      mensaje,
    ) async {
      final datos = (mensaje as Map)['data'] as Map?;
      if (mensaje['type'] == 'announce') anuncios.add(datos!['message'] as String);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
        SystemChannels.accessibility,
        null,
      ),
    );
    await montarJuzgado(tester);
    await tester.ensureVisible(find.text(_letrada));
    await tester.tap(find.text(_letrada));
    await tester.pumpAndSettle();
    expect(find.byType(CartaRol), findsNothing);
    expect(anuncios, ['Letrado o Letrada de la Administración de Justicia: al fondo, a la derecha de la jueza.']);

    tester.platformDispatcher.accessibilityFeaturesTestValue = const _NavegacionAccesible();
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Fiscal'));
    await tester.tap(find.text('Fiscal'));
    await tester.pumpAndSettle();
    expect(_carta('El fiscal'), findsOneWidget);
    expect(progreso(1, 9), findsOneWidget);
  });

  testWidgets('mientras los textos no estén revisados, lo dice una franja de borrador', (tester) async {
    await montarJuzgado(tester);
    expect(find.text('Borrador: textos pendientes de revisión jurídica.'), findsOneWidget);
  });

  testWidgets('«Qué dice la ley» enseña las citas literales del BOE', (tester) async {
    await montarJuzgado(tester);
    await tocarRol(tester, 'jueza');
    expect(find.textContaining('Toda víctima será informada de manera inmediata'), findsNothing);
    await tester.ensureVisible(find.text('Qué dice la ley'));
    await tester.tap(find.text('Qué dice la ley'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Toda víctima será informada de manera inmediata'), findsOneWidget);
    expect(find.textContaining('BOE: BOE-A-2015-4606'), findsWidgets);
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
    for (final modo in ModoJuzgado.values) {
      await montarJuzgado(tester, modo: modo);
      final caja = tester.getRect(find.byType(EscenaPixel));
      final encaje = EncajePixel(caja: caja.size, arte: const Size(160, 96), dpr: 2.75);
      expect(encaje.nitido, isTrue);
      expect(encaje.fisicos, 6);
      // Y en la pantalla de verdad: cada píxel del dibujo es un bloque de 6 × 6 de un solo color.
      final capa = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
      final datos = await tester.runAsync(() async {
        final imagen = await capa.toImage(Offset.zero & tester.view.physicalSize);
        final bytes = await imagen.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
        imagen.dispose();
        return bytes!;
      });
      int color(int x, int y) => datos!.getUint32((y * 1080 + x) * 4);
      final x0 = (caja.left * 2.75).round() + (encaje.rect.left * 2.75).round();
      final y0 = (caja.top * 2.75).round() + (encaje.rect.top * 2.75).round();
      var mezclados = 0;
      for (var j = 0; j < 96; j++) {
        for (var i = 0; i < 160; i++) {
          // Las esquinas escalonadas del marco (MarcoPixel recorta la pantalla con esquinas de pixel) tapan un trozo de
          // los píxeles del dibujo que tienen debajo: no es suavizado, es el marco.
          if ((i < 3 || i >= 157) && (j < 3 || j >= 93)) continue;
          final esquina = color(x0 + i * 6, y0 + j * 6);
          for (var dy = 0; dy < 6; dy++) {
            for (var dx = 0; dx < 6; dx++) {
              if (color(x0 + i * 6 + dx, y0 + j * 6 + dy) != esquina) mezclados++;
            }
          }
        }
      }
      expect(mezclados, 0, reason: '${modo.name}: píxeles de 5 o de 7, o bordes a medias');
    }
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

/// Lo que pone el sistema con TalkBack: navegación accesible.
class _NavegacionAccesible implements ui.AccessibilityFeatures {
  const _NavegacionAccesible();

  @override
  bool get accessibleNavigation => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => false;
}
