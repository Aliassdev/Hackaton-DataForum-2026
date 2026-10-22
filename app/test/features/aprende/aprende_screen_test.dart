import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/progreso.dart';
import 'package:tuturno/features/aprende/aprende_screen.dart';
import 'package:tuturno/features/aprende/curso.dart';
import 'package:tuturno/features/aprende/textos.dart';
import 'package:tuturno/widgets/justicia/justicia.dart';

import 'ayudantes.dart';

/// Etiqueta del nodo de una lección para el lector de pantalla (empieza así).
Finder _nodo(String texto) => find.bySemanticsLabel(RegExp(RegExp.escape(texto)));

/// [texto] dentro del botón «Tu turno» de la cabecera.
Finder _enBotonSeguir(String texto) =>
    find.descendant(of: find.byKey(const ValueKey('boton-seguir')), matching: find.text(texto));

/// El título de una lección en el mapa (el último: el primero puede ser el del botón «Tu turno»).
Finder _tituloEnMapa(String titulo) => find.text(titulo).last;

void main() {
  testWidgets('la primera vez: cabecera, dos unidades y solo la primera lección abierta', (tester) async {
    final semantica = tester.ensureSemantics();
    await montar(tester);

    expect(find.text('¡Empieza a aprender!'), findsOneWidget);
    expect(_enBotonSeguir('Tu turno'), findsOneWidget);
    expect(_enBotonSeguir('Que te escuchen'), findsOneWidget);
    expect(find.bySemanticsLabel('0 puntos de experiencia'), findsOneWidget);
    expect(find.text('0 días'), findsOneWidget);
    expect(find.text('0/17 lecciones'), findsOneWidget);
    expect(find.text('¡Empieza aquí!'), findsOneWidget);
    expect(find.text('Completa una lección para empezar tu racha.'), findsOneWidget);
    expect(_nodo('Lección 1 de 3: Que te escuchen. Disponible, 6 ejercicios'), findsOneWidget);
    expect(_nodo('Lección 2 de 3: Fiscalía y Defensor del Pueblo. Bloqueada'), findsOneWidget);
    // Cada unidad es una sala, con su cartel.
    expect(find.widgetWithText(CartelSala, 'SALA 1 · Tus derechos'), findsOneWidget);
    // Sin ninguna lección hecha, aún no hay nada que practicar (auditoría, P2-8).
    expect(find.text('Practicar'), findsNothing);

    await tester.scrollUntilVisible(find.textContaining('Si te toca declarar'), 300);
    await tester.pumpAndSettle();
    expect(find.text(textoSalaCerrada), findsWidgets);
    expect(_nodo('Lección 1 de 3: La citación y qué puedes pedir. Bloqueada'), findsOneWidget);
    expect(find.text('Lo que dominas'), findsWidgets);
    expect(find.text(textoBalanza), findsWidgets);
    expect(find.text('Por aprender'), findsWidgets);
    semantica.dispose();
  });

  testWidgets('con progreso: completadas, la que toca, XP, racha de hoy y barras de dominio', (tester) async {
    final semantica = tester.ensureSemantics();
    await montar(
      tester,
      preferencias: progresoGuardado(
        xp: 120,
        racha: 2,
        ultimoDia: DateTime(2026, 10, 21),
        lecciones: ['U1-L1', 'U1-L2'],
        dominio: {'C-ser-oido': 0.97, 'C-fiscalia': 0.5},
      ),
    );
    expect(find.text('¡Sigue así!'), findsOneWidget);
    expect(find.bySemanticsLabel('120 puntos de experiencia'), findsOneWidget);
    expect(find.text('2 días'), findsOneWidget);
    expect(find.text('2/17 lecciones'), findsOneWidget);
    expect(find.text('¡Hoy ya has sumado a tu racha!'), findsOneWidget);
    expect(_enBotonSeguir('Tu turno'), findsOneWidget);
    expect(_enBotonSeguir('Abogado y canales seguros'), findsOneWidget);
    expect(find.text('Practicar'), findsOneWidget, reason: 'ya hay lecciones hechas en la sala 1');
    expect(_nodo('Lección 1 de 3: Que te escuchen. Completada'), findsOneWidget);
    expect(_nodo('Lección 3 de 3: Abogado y canales seguros. Disponible'), findsOneWidget);
    expect(find.text('Sigue aquí'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Lo que dominas').first, 300);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Ser oído y escuchado: ¡Dominado!'), findsOneWidget);
    expect(find.bySemanticsLabel('Avisar a la Fiscalía: Aprendiendo'), findsOneWidget);
    expect(find.bySemanticsLabel('Abogado de oficio: Por aprender'), findsOneWidget);
    expect(find.text('1 de 5'), findsOneWidget);
    semantica.dispose();
  });

  testWidgets('tocar una lección abierta la empieza; una completada se puede repetir', (tester) async {
    final m = await montar(tester, preferencias: progresoGuardado(lecciones: ['U1-L1']));
    await pulsar(tester, _tituloEnMapa('Que te escuchen'));
    expect(find.byType(LeccionScreen), findsOneWidget);
    expect(tester.widget<LeccionScreen>(find.byType(LeccionScreen)).leccionId, 'U1-L1');
    m.router.pop();
    await tester.pumpAndSettle();
    await pulsar(tester, _tituloEnMapa('Fiscalía y Defensor del Pueblo'));
    expect(tester.widget<LeccionScreen>(find.byType(LeccionScreen)).leccionId, 'U1-L2');
  });

  testWidgets('tocar una lección bloqueada explica cómo se abre y lleva a la que toca', (tester) async {
    await montar(tester);
    await pulsar(tester, find.text('Abogado y canales seguros'));
    expect(find.text('«Abogado y canales seguros» aún está cerrada'), findsOneWidget);
    expect(find.textContaining('Se abre cuando completes «Fiscalía y Defensor del Pueblo»'), findsOneWidget);
    expect(find.text('Abrirla igualmente (modo demo)'), findsNothing);
    await pulsar(tester, find.text('Ir a «Que te escuchen»'));
    expect(tester.widget<LeccionScreen>(find.byType(LeccionScreen)).leccionId, 'U1-L1');
  });

  testWidgets('en modo demo, una lección bloqueada se puede abrir desde el aviso', (tester) async {
    await montar(tester, demo: true);
    await pulsar(tester, find.text('Abogado y canales seguros'));
    await pulsar(tester, find.text('Abrirla igualmente (modo demo)'));
    expect(tester.widget<LeccionScreen>(find.byType(LeccionScreen)).leccionId, 'U1-L3');
  });

  testWidgets('en modo demo, mantener pulsada una lección la abre en su «Dilo con tus palabras»', (tester) async {
    await montar(tester, demo: true);
    await tester.longPress(_tituloEnMapa('Que te escuchen'));
    await tester.pumpAndSettle();
    expect(tester.widget<LeccionScreen>(find.byType(LeccionScreen)).leccionId, '${prefijoDilo}U1-L1');
    expect(find.text('Explica con tus palabras qué significa el derecho a ser oído.'), findsOneWidget);
  });

  testWidgets('fuera del modo demo, mantener pulsada una lección la abre normal', (tester) async {
    await montar(tester);
    await tester.longPress(_tituloEnMapa('Que te escuchen'));
    await tester.pumpAndSettle();
    expect(tester.widget<LeccionScreen>(find.byType(LeccionScreen)).leccionId, 'U1-L1');
  });

  testWidgets('el botón de la cabecera empieza la lección que toca', (tester) async {
    await montar(tester);
    await pulsar(tester, find.byKey(const ValueKey('boton-seguir')));
    expect(tester.widget<LeccionScreen>(find.byType(LeccionScreen)).leccionId, 'U1-L1');
  });

  testWidgets('con el progreso nuevo, «Practicar» no sale (no hay nada que practicar todavía)', (tester) async {
    await montar(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(find.text('Practicar', skipOffstage: false), findsNothing);
    expect(find.text('Repasar', skipOffstage: false), findsNothing);
  });

  testWidgets('«Practicar» abre la práctica de su unidad; la unidad cerrada no se puede practicar', (tester) async {
    await montar(tester, preferencias: progresoGuardado(lecciones: ['U1-L1']));
    expect(find.text('Practicar'), findsOneWidget);
    await pulsar(tester, find.text('Practicar'));
    expect(tester.widget<LeccionScreen>(find.byType(LeccionScreen)).leccionId, '${prefijoPractica}U1');
    expect(find.text('Tus derechos'), findsOneWidget);
  });

  testWidgets('con todo hecho: «Repasar lo aprendido» practica la última unidad', (tester) async {
    await montar(
      tester,
      preferencias: progresoGuardado(
        lecciones: [
          'U1-L1',
          'U1-L2',
          'U1-L3',
          'U2-L1',
          'U2-L2',
          'U2-L3',
          'U3-L1',
          'U3-L2',
          'U4-L1',
          'U4-L2',
          'U5-L1',
          'U5-L2',
          'U5-L3',
          'U6-L1',
          'U6-L2',
          'U7-L1',
          'U7-L2',
        ],
      ),
    );
    expect(find.text('¡Lo has completado todo!'), findsOneWidget);
    expect(find.text('Repasar'), findsNWidgets(7));
    await pulsar(tester, find.text('Repasar lo aprendido'));
    expect(tester.widget<LeccionScreen>(find.byType(LeccionScreen)).leccionId, '${prefijoPractica}U7');
  });

  group('racha amable (producto, apartado 5.5)', () {
    testWidgets('sin racha y con una mejor racha: se empieza otra, y se recuerda la mejor', (tester) async {
      await montar(tester, preferencias: progresoGuardado(racha: 5, ultimoDia: DateTime(2026, 10, 18)));
      expect(find.text('0 días'), findsOneWidget);
      expect(find.text('Cuando quieras, empiezas una racha nueva. Tu mejor racha: 5 días.'), findsOneWidget);
    });

    testWidgets('si la última lección fue ayer: hoy la racha suma un día', (tester) async {
      await montar(tester, preferencias: progresoGuardado(racha: 5, ultimoDia: DateTime(2026, 10, 20)));
      expect(find.text('5 días'), findsOneWidget);
      expect(find.text('Si haces una lección hoy, tu racha suma un día.'), findsOneWidget);
    });

    testWidgets('si ayer no hubo lección pero queda descanso: la racha sigue', (tester) async {
      await montar(tester, preferencias: progresoGuardado(racha: 5, ultimoDia: DateTime(2026, 10, 19)));
      expect(find.text('5 días'), findsOneWidget);
      expect(
        find.text('Ayer descansaste: tienes un día de descanso cada semana. Si haces una lección hoy, tu racha sigue.'),
        findsOneWidget,
      );
    });

    testWidgets('ningún texto de la racha habla de perderla, en ningún estado', (tester) async {
      final casos = <TipoRacha, Map<String, Object>>{
        TipoRacha.sinRacha: progresoGuardado(),
        TipoRacha.hoyHecha: progresoGuardado(racha: 3, ultimoDia: DateTime(2026, 10, 21), lecciones: ['U1-L1']),
        TipoRacha.pendienteHoy: progresoGuardado(racha: 3, ultimoDia: DateTime(2026, 10, 20), lecciones: ['U1-L1']),
        TipoRacha.conDescanso: progresoGuardado(racha: 3, ultimoDia: DateTime(2026, 10, 19), lecciones: ['U1-L1']),
      };
      for (final MapEntry(key: tipo, value: preferencias) in casos.entries) {
        await montar(tester, preferencias: preferencias);
        expect(find.byKey(const ValueKey('texto-racha')), findsOneWidget, reason: tipo.name);
        expect(find.textContaining(RegExp('perd|pierd', caseSensitive: false)), findsNothing, reason: tipo.name);
      }
      // Y una mejor racha que ya pasó.
      await montar(tester, preferencias: progresoGuardado(racha: 9, mejorRacha: 12, ultimoDia: DateTime(2026, 10, 1)));
      expect(find.textContaining('Tu mejor racha: 12 días'), findsOneWidget);
      expect(find.textContaining(RegExp('perd|pierd', caseSensitive: false)), findsNothing);
    });
  });

  testWidgets('después de completar una lección, al volver al mapa la siguiente está abierta', (tester) async {
    final semantica = tester.ensureSemantics();
    final m = await montar(tester);
    m.router.push('/aprende/leccion/U1-L1');
    await tester.pumpAndSettle();
    await m.contenedor.read(progresoProvider.notifier).completarLeccion('U1-L1');
    m.router.pop();
    await tester.pumpAndSettle();
    expect(_nodo('Lección 1 de 3: Que te escuchen. Completada'), findsOneWidget);
    expect(_nodo('Lección 2 de 3: Fiscalía y Defensor del Pueblo. Disponible'), findsOneWidget);
    semantica.dispose();
  });

  testWidgets('sin lecciones, un estado vacío amable que lleva a Pregunta', (tester) async {
    await montar(tester, repo: repoCon(const {}));
    expect(find.text('Las lecciones están en camino'), findsOneWidget);
    await pulsar(tester, find.text('Ir a Pregunta'));
    expect(find.text('pantalla de pregunta'), findsOneWidget);
  });

  testWidgets('si falla la carga, lo dice y se puede reintentar', (tester) async {
    var intentos = 0;
    await montar(
      tester,
      overrides: [
        cursoProvider.overrideWith((ref) async {
          intentos++;
          throw StateError('sin contenido');
        }),
      ],
    );
    expect(find.text('No he podido cargar las lecciones. Prueba otra vez.'), findsOneWidget);
    await pulsar(tester, find.text('Reintentar'));
    expect(intentos, 2);
  });

  testWidgets('Glosario y Ayuda están arriba a la derecha', (tester) async {
    await montar(tester);
    expect(find.byTooltip('Glosario'), findsOneWidget);
    expect(find.text('Ayuda'), findsOneWidget);
  });

  testWidgets('con letra grande, en un móvil pequeño y en oscuro, el mapa cabe entero', (tester) async {
    await montar(
      tester,
      escalaTexto: 1.3,
      tamano: const Size(360, 640),
      brillo: Brightness.dark,
      preferencias: progresoGuardado(xp: 1234, racha: 12, ultimoDia: DateTime(2026, 10, 21), lecciones: ['U1-L1']),
    );
    expect(tester.takeException(), isNull);
    // Las 7 salas, hasta abajo del todo.
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.textContaining('SALA 7'), findsOneWidget);
  });

  testWidgets('accesible: zonas táctiles, etiquetas y contraste en claro y en oscuro', (tester) async {
    final semantica = tester.ensureSemantics();
    for (final brillo in Brightness.values) {
      await montar(
        tester,
        brillo: brillo,
        preferencias: progresoGuardado(lecciones: ['U1-L1']),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline), reason: '$brillo');
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: '$brillo');
      await expectLater(tester, meetsGuideline(textContrastGuideline), reason: '$brillo');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(textContrastGuideline), reason: '$brillo abajo');
    }
    semantica.dispose();
  });

  testWidgets('con «reducir animaciones» aparece todo sin esperar', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await montar(tester);
    expect(tester.binding.hasScheduledFrame, isFalse);
    final opacidades = tester.widgetList<FadeTransition>(
      find.ancestor(of: find.text('¡Empieza a aprender!'), matching: find.byType(FadeTransition)),
    );
    expect(opacidades.every((f) => f.opacity.value == 1), isTrue);
  });
}
