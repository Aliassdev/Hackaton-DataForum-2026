import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/entrada.dart';
import 'package:tuturno/features/situacion/mi_ticket.dart';
import 'package:tuturno/features/situacion/ticket_screen.dart';

import 'ayudantes.dart';

// «Tu ticket» de Mi situación: la edad, el papel, el tipo de proceso y el momento (el ticket de la app) y, además,
// con quién irás, qué te preocupa y cómo prefieres que te lo cuente. Todo opcional; se guarda solo en el móvil.

Future<void> _elegir(WidgetTester tester, String texto) async {
  final chip = find.widgetWithText(ChoiceChip, texto).evaluate().isNotEmpty
      ? find.widgetWithText(ChoiceChip, texto)
      : find.widgetWithText(FilterChip, texto);
  await tocar(tester, chip.first);
}

void main() {
  testWidgets('desde la portada: se rellena en pocos toques, se guarda y lleva a tu camino', (tester) async {
    final router = await arrancarSituacion(tester);
    await abrir(tester, router, '/situacion/elegir');
    await tocar(tester, find.text('Rellenar mi ticket'));
    expect(find.byType(TuTicketScreen), findsOneWidget);

    for (final pregunta in [
      '¿Cuántos años tienes?',
      '¿Qué papel tienes?',
      '¿Qué tipo de proceso es?',
      '¿En qué momento estás?',
      '¿Con quién irás?',
      '¿Qué te preocupa más?',
      '¿Cómo prefieres que te lo cuente?',
    ]) {
      await tester.ensureVisible(find.text(pregunta));
      expect(find.text(pregunta), findsOneWidget);
    }

    await _elegir(tester, '13');
    await _elegir(tester, 'Víctima');
    await _elegir(tester, 'Penal');
    await _elegir(tester, 'Durante');
    await _elegir(tester, 'Mi familia');
    await _elegir(tester, 'El colegio o el instituto');
    await _elegir(tester, 'Paso a paso');
    expect(find.text('13 años · Penal · Víctima · Durante'), findsOneWidget);

    await tocar(tester, find.text('Guardar'));
    expect(find.text('Listo. Tu guía ya está adaptada a ti.'), findsOneWidget);
    expect(router.state.uri.path, '/situacion/victima');

    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString(EntradaNotifier.clave)!), {
      'edad': 13,
      'procedimiento': 'penal',
      'rol': 'victima',
      'fase': 'durante',
    });
    final ticket = jsonDecode(prefs.getString(MiTicketNotifier.clave)!) as Map<String, dynamic>;
    expect(ticket['con_quien'], ['familia']);
    expect(ticket['preocupaciones'], ['colegio']);
    expect(ticket['estilo'], 'paso_a_paso');
    // Y la guía ya es suya.
    expect(find.text('Durante · Estás aquí'), findsOneWidget);
  });

  testWidgets('nada es obligatorio: «Guardar» con todo vacío no rompe nada ni guarda claves', (tester) async {
    final router = await arrancarSituacion(tester);
    // Desde la portada no viene ningún papel marcado (desde un papel, sí: el de la pantalla).
    await abrir(tester, router, '/situacion/elegir');
    await tocar(tester, find.text('Rellenar mi ticket'));
    await tocar(tester, find.text('Guardar'));

    expect(find.byType(TuTicketScreen), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(EntradaNotifier.clave), isFalse);
    expect(prefs.containsKey(MiTicketNotifier.clave), isFalse);
  });

  testWidgets('tocar otra vez una opción la quita, y «Aún no lo sé» va sola', (tester) async {
    final router = await arrancarSituacion(tester);
    await abrir(tester, router, '/situacion/victima');
    await tocar(tester, find.text('Rellenar mi ticket'));

    // El papel de la pantalla viene marcado.
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Víctima')).selected, isTrue);
    await _elegir(tester, 'Víctima');
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Víctima')).selected, isFalse);

    // «Mi familia» sale dos veces (con quién irás y lo que te preocupa): la primera es la de con quién irás.
    await _elegir(tester, 'Mi familia');
    await _elegir(tester, 'Aún no lo sé');
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Mi familia').first).selected, isFalse);
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Aún no lo sé')).selected, isTrue);
  });

  testWidgets('«Investigado» solo desde los 14 años, como en la hoja del perfil de Pregunta', (tester) async {
    final router = await arrancarSituacion(tester);
    // Desde el camino de quien investigan viene marcado su papel…
    await abrir(tester, router, '/situacion/investigado');
    await tocar(tester, find.text('Rellenar mi ticket'));
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Investigado')).selected, isTrue);

    // …pero con 12 años no se puede elegir: se quita y no se guarda.
    await _elegir(tester, '12');
    expect(find.widgetWithText(ChoiceChip, 'Investigado'), findsNothing);
    await _elegir(tester, '15');
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Investigado')).selected, isFalse);
    await _elegir(tester, '12');
    await tocar(tester, find.text('Guardar'));
    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString(EntradaNotifier.clave)!), containsPair('rol', null));
    expect(rolesPara(12), isNot(contains(RolEntrada.investigado)));
    expect(rolesPara(null), contains(RolEntrada.investigado));
    expect(rolesPara(14), contains(RolEntrada.investigado));
  });

  testWidgets('«Borrar mis respuestas» vacía el ticket (y deja tu día)', (tester) async {
    final router = await arrancarSituacion(tester, preferencias: perfilLucia());
    await abrir(tester, router, '/situacion/victima');
    await tocar(tester, find.text('Cambiar mi ticket'));
    await tocar(tester, find.text('Borrar mis respuestas'));

    expect(find.text('Hecho. Tu ticket está vacío.'), findsOneWidget);
    final c = contenedor(tester);
    expect(c.read(entradaProvider).vacia, isTrue);
    expect(c.read(miTicketProvider).sinRespuestas, isTrue);
    expect(c.read(miTicketProvider).fecha, DateTime(2026, 10, 24));
    // La guía vuelve a ser general (con su día, que se queda): invita a rellenar el ticket.
    expect(find.text('Rellenar mi ticket'), findsOneWidget);
    expect(find.text('Tu cita: sábado 24 de octubre'), findsOneWidget);
  });

  testWidgets('dice qué se guarda y qué sale del móvil, sin pedir nombre ni hechos', (tester) async {
    final router = await arrancarSituacion(tester);
    await abrir(tester, router, '/situacion/victima');
    await tocar(tester, find.text('Rellenar mi ticket'));
    expect(find.textContaining('No te pido tu nombre ni lo que pasó.'), findsOneWidget);
    await tester.ensureVisible(find.textContaining('Tu ticket se guarda en este móvil.'));
    expect(find.textContaining('tu día) no sale de este móvil.'), findsOneWidget);
    // Sin «solo en este móvil»: la edad, el proceso, el papel y el momento viajan con las preguntas.
    expect(find.textContaining('solo en este móvil'), findsNothing);
  });

  testWidgets('con letra a 1,3 en un móvil pequeño, no se desborda', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final router = await arrancarSituacion(tester, tamano: const Size(360, 640));
    await abrir(tester, router, '/situacion/victima');
    await tocar(tester, find.text('Rellenar mi ticket'));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
