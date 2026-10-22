import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/progreso.dart';
import 'package:tuturno/features/aprende/aprende_screen.dart';
import 'package:tuturno/features/aprende/curso.dart';

import 'ayudantes.dart';

/// Etiqueta del nodo de una lección para el lector de pantalla (empieza así).
Finder _nodo(String texto) => find.bySemanticsLabel(RegExp(RegExp.escape(texto)));

void main() {
  testWidgets('la primera vez: cabecera, dos unidades y solo la primera lección abierta', (tester) async {
    final semantica = tester.ensureSemantics();
    await montar(tester);

    expect(find.text('¡Empieza a aprender!'), findsOneWidget);
    expect(find.text('Empezar: Que te escuchen'), findsOneWidget);
    expect(find.text('0 XP'), findsOneWidget);
    expect(find.text('0 días'), findsOneWidget);
    expect(find.text('0/6 lecciones'), findsOneWidget);
    expect(find.text('¡Empieza aquí!'), findsOneWidget);
    expect(_nodo('Lección 1 de 3: Que te escuchen. Disponible, 6 ejercicios'), findsOneWidget);
    expect(_nodo('Lección 2 de 3: Fiscalía y Defensor del Pueblo. Bloqueada'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Si te toca declarar'), 300);
    await tester.pumpAndSettle();
    expect(find.text('Se abre al terminar la unidad anterior.'), findsOneWidget);
    expect(_nodo('Lección 1 de 3: La citación y qué puedes pedir. Bloqueada'), findsOneWidget);
    expect(find.text('Lo que dominas'), findsWidgets);
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
    expect(find.text('120 XP'), findsOneWidget);
    expect(find.text('2 días'), findsOneWidget);
    expect(find.text('2/6 lecciones'), findsOneWidget);
    expect(find.text('¡Hoy ya has sumado a tu racha!'), findsOneWidget);
    expect(find.text('Seguir: Abogado y canales seguros'), findsOneWidget);
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
    await pulsar(tester, find.text('Que te escuchen'));
    expect(find.byType(LeccionScreen), findsOneWidget);
    expect(tester.widget<LeccionScreen>(find.byType(LeccionScreen)).leccionId, 'U1-L1');
    m.router.pop();
    await tester.pumpAndSettle();
    await pulsar(tester, find.text('Fiscalía y Defensor del Pueblo'));
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
    await tester.longPress(find.text('Que te escuchen'));
    await tester.pumpAndSettle();
    expect(tester.widget<LeccionScreen>(find.byType(LeccionScreen)).leccionId, '${prefijoDilo}U1-L1');
    expect(find.text('Explica con tus palabras qué significa el derecho a ser oído.'), findsOneWidget);
  });

  testWidgets('fuera del modo demo, mantener pulsada una lección la abre normal', (tester) async {
    await montar(tester);
    await tester.longPress(find.text('Que te escuchen'));
    await tester.pumpAndSettle();
    expect(tester.widget<LeccionScreen>(find.byType(LeccionScreen)).leccionId, 'U1-L1');
  });

  testWidgets('el botón de la cabecera empieza la lección que toca', (tester) async {
    await montar(tester);
    await pulsar(tester, find.byKey(const ValueKey('boton-seguir')));
    expect(tester.widget<LeccionScreen>(find.byType(LeccionScreen)).leccionId, 'U1-L1');
  });

  testWidgets('«Practicar» abre la práctica de su unidad; la unidad cerrada no se puede practicar', (tester) async {
    await montar(tester);
    expect(find.text('Practicar'), findsOneWidget);
    await pulsar(tester, find.text('Practicar'));
    expect(tester.widget<LeccionScreen>(find.byType(LeccionScreen)).leccionId, '${prefijoPractica}U1');
    expect(find.text('Tus derechos'), findsOneWidget);
  });

  testWidgets('con todo hecho: «Repasar lo aprendido» practica la última unidad', (tester) async {
    await montar(
      tester,
      preferencias: progresoGuardado(lecciones: ['U1-L1', 'U1-L2', 'U1-L3', 'U2-L1', 'U2-L2', 'U2-L3']),
    );
    expect(find.text('¡Lo has completado todo!'), findsOneWidget);
    expect(find.text('Repasar'), findsNWidgets(2));
    await pulsar(tester, find.text('Repasar lo aprendido'));
    expect(tester.widget<LeccionScreen>(find.byType(LeccionScreen)).leccionId, '${prefijoPractica}U2');
  });

  testWidgets('si pasó más de un día sin lecciones, la racha vuelve a cero', (tester) async {
    await montar(tester, preferencias: progresoGuardado(racha: 5, ultimoDia: DateTime(2026, 10, 18)));
    expect(find.text('0 días'), findsOneWidget);
    expect(find.text('Completa una lección para empezar tu racha.'), findsOneWidget);
  });

  testWidgets('si la última lección fue ayer, recuerda que hoy toca para no perder la racha', (tester) async {
    await montar(tester, preferencias: progresoGuardado(racha: 5, ultimoDia: DateTime(2026, 10, 20)));
    expect(find.text('5 días'), findsOneWidget);
    expect(find.text('Haz una lección hoy para no perder tu racha.'), findsOneWidget);
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
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
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
