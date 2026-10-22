import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/mis_preguntas.dart';
import 'package:tuturno/features/mis_preguntas/ensenar_screen.dart';
import 'package:tuturno/features/mis_preguntas/textos.dart';

import '../situacion/ayudantes.dart';

// «Mis preguntas» (plan v2, producto §5.2): «Quiero pedir» (lo apuntado desde Mi situación, tal cual, con de dónde
// viene y su fuente) y «Quiero preguntar» (lo que escribes o eliges de las ideas), con el recordatorio fijo de escribir
// solo la duda. Todo solo en el móvil.

/// Dos apuntes: uno para pedir (de un paso, con fuentes) y otro para preguntar (propio).
Map<String, Object> _apuntes() => {
  MisPreguntasNotifier.clave: jsonEncode([
    {
      'id': '1',
      'texto': 'Un descanso si lo necesitas',
      'tipo': 'pedir',
      'origen': 'Tu declaración',
      'fuentes': ['Ley 4/2015, art. 25.1', 'LOPIVI, art. 11.2'],
    },
    {'id': '2', 'texto': '¿Quién va a estar en la sala?', 'tipo': 'preguntar'},
  ]),
};

List<Apunte> _leer(WidgetTester tester) => contenedor(tester).read(misPreguntasProvider);

void main() {
  testWidgets('las dos secciones, la entradilla con su fuente y el recordatorio fijo', (tester) async {
    final router = await arrancarSituacion(tester, preferencias: _apuntes());
    await abrir(tester, router, '/mis-preguntas');

    expect(find.text(seccionPedir), findsOneWidget);
    expect(find.text(seccionPreguntar), findsOneWidget);
    expect(find.textContaining('Tienes derecho a que te lo expliquen con palabras que entiendas'), findsOneWidget);
    expect(find.text('LO 1/1996 · art. 9.1'), findsOneWidget);
    expect(find.text(recordatorioDuda), findsOneWidget);

    // Lo apuntado desde un paso: tal cual, con «De:» y la fuente pequeña.
    expect(find.text('Un descanso si lo necesitas'), findsOneWidget);
    expect(find.text('De: Tu declaración'), findsOneWidget);
    expect(find.text('Ley 4/2015 · art. 25.1 · LOPIVI · art. 11.2'), findsOneWidget);
    expect(find.text('¿Quién va a estar en la sala?'), findsWidgets);
  });

  testWidgets('«Añadir» guarda la duda escrita en «Quiero preguntar» y limpia el campo', (tester) async {
    final router = await arrancarSituacion(tester);
    await abrir(tester, router, '/mis-preguntas');
    expect(find.text(vacioTodo), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, pistaDuda), '  ¿Puedo llevar a mi perro?  ');
    await tocar(tester, find.text(botonAnadir));

    final apunte = _leer(tester).single;
    expect(apunte.texto, '¿Puedo llevar a mi perro?');
    expect(apunte.tipo, TipoApunte.preguntar);
    expect(apunte.origen, isNull);
    expect(find.text('¿Puedo llevar a mi perro?'), findsOneWidget);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, pistaDuda)).controller!.text, isEmpty);

    // La misma otra vez (con otras mayúsculas) no se repite.
    await tester.enterText(find.widgetWithText(TextField, pistaDuda), '¿PUEDO llevar a mi perro?');
    await tocar(tester, find.text(botonAnadir));
    expect(_leer(tester), hasLength(1));
    expect(find.text(textoRepetida), findsOneWidget);
  });

  testWidgets('una idea se apunta con un toque y se ve marcada; con preocupaciones, «Ideas para ti»', (tester) async {
    final router = await arrancarSituacion(tester, preferencias: perfilLucia());
    await abrir(tester, router, '/mis-preguntas');

    expect(find.text(tituloIdeasParaTi), findsOneWidget);
    expect(find.text('¿Puedo esperar en un sitio aparte?'), findsOneWidget);
    await tocar(tester, find.text(tituloIdeas));
    for (final idea in ideasPreguntas) {
      await tester.ensureVisible(find.text(idea).first);
      expect(find.text(idea), findsWidgets);
    }
    await tocar(tester, find.text('¿Puedo hacer un descanso si lo necesito?').first);
    expect(_leer(tester).single.texto, '¿Puedo hacer un descanso si lo necesito?');
    expect(find.bySemanticsLabel('¿Puedo hacer un descanso si lo necesito?. Ya está apuntada'), findsOneWidget);
  });

  testWidgets('«Ya lo he preguntado» se guarda; lo propio se edita y lo de un paso no', (tester) async {
    final router = await arrancarSituacion(tester, preferencias: _apuntes());
    await abrir(tester, router, '/mis-preguntas');

    await tocar(tester, find.bySemanticsLabel(textoYaPreguntado).first);
    expect(_leer(tester).firstWhere((a) => a.id == '1').hecho, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(MisPreguntasNotifier.clave), contains('"hecho":true'));

    // El menú de lo apuntado desde un paso solo deja quitar.
    await tocar(tester, find.byTooltip('Más opciones').first);
    expect(find.text(textoEditar), findsNothing);
    expect(find.text(textoQuitar), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    // Lo propio sí se edita.
    await tocar(tester, find.byTooltip('Más opciones').last);
    await tocar(tester, find.text(textoEditar));
    await tester.enterText(find.widgetWithText(TextField, pistaDuda).last, '¿Quién estará conmigo?');
    await tocar(tester, find.text('Guardar'));
    expect(_leer(tester).firstWhere((a) => a.id == '2').texto, '¿Quién estará conmigo?');
  });

  testWidgets('«Quitar» quita uno; «Borrar todas» pide confirmación', (tester) async {
    final router = await arrancarSituacion(tester, preferencias: _apuntes());
    await abrir(tester, router, '/mis-preguntas');

    await tocar(tester, find.byTooltip('Más opciones').first);
    await tocar(tester, find.text(textoQuitar));
    expect(_leer(tester).map((a) => a.id), ['2']);

    await tocar(tester, find.text(botonBorrarTodas));
    expect(find.text(confirmarBorrarTodas), findsOneWidget);
    await tocar(tester, find.text(botonCancelar));
    expect(_leer(tester), hasLength(1));

    await tocar(tester, find.text(botonBorrarTodas));
    await tocar(tester, find.text(botonBorrar));
    expect(_leer(tester), isEmpty);
    expect(find.text(textoBorradas), findsOneWidget);
  });

  testWidgets('con 30 apuntes no deja añadir más y lo dice', (tester) async {
    final router = await arrancarSituacion(
      tester,
      preferencias: {
        MisPreguntasNotifier.clave: jsonEncode([
          for (var i = 0; i < maxApuntes; i++) {'id': '$i', 'texto': 'Pregunta $i', 'tipo': 'preguntar'},
        ]),
      },
    );
    await abrir(tester, router, '/mis-preguntas');
    await tester.enterText(find.widgetWithText(TextField, pistaDuda), 'Una más');
    await tocar(tester, find.text(botonAnadir));
    expect(_leer(tester), hasLength(maxApuntes));
    expect(find.text(textoMaximo), findsOneWidget);
  });

  testWidgets('«Enseñar en grande» abre la pantalla grande; sin nada apuntado, no se puede', (tester) async {
    final router = await arrancarSituacion(tester);
    await abrir(tester, router, '/mis-preguntas');
    final botonGrande = find.widgetWithText(FilledButton, botonEnsenar);
    expect(tester.widget<FilledButton>(botonGrande).onPressed, isNull);

    contenedor(tester).read(misPreguntasProvider.notifier).apuntar('¿Qué pasa después?', tipo: TipoApunte.preguntar);
    await tester.pumpAndSettle();
    await tocar(tester, botonGrande);
    expect(find.byType(EnsenarScreen), findsOneWidget);
    expect(find.text('¿Qué pasa después?'), findsOneWidget);
  });

  for (final brillo in Brightness.values) {
    testWidgets('cumple las pautas de accesibilidad en tema ${brillo.name}', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brillo;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final semantica = tester.ensureSemantics();
      final router = await arrancarSituacion(tester, preferencias: _apuntes());
      await abrir(tester, router, '/mis-preguntas');
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantica.dispose();
    });
  }

  testWidgets('con letra a 1,3 en un móvil pequeño, no se desborda', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final router = await arrancarSituacion(tester, preferencias: _apuntes(), tamano: const Size(360, 640));
    await abrir(tester, router, '/mis-preguntas');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
