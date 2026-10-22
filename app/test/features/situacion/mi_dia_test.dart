import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/progreso.dart' show relojProvider;
import 'package:tuturno/core/providers.dart';
import 'package:tuturno/features/situacion/mi_ticket.dart';
import 'package:tuturno/features/situacion/widgets/mi_dia.dart';
import 'package:tuturno/tema.dart';

import 'ayudantes.dart';

// «Tu día» (opcional): la fecha de la citación, cuánto falta (solo aquí dentro) y la lista de lo que llevar, solo en el
// móvil; y la tarjeta del «modo día» para la portada y el inicio, que dice la fecha y no cuánto falta.

void main() {
  testWidgets('se pone la fecha con el calendario y sale la cuenta atrás; se marca, se añade y se borra', (
    tester,
  ) async {
    final router = await arrancarSituacion(tester);
    await abrir(tester, router, '/situacion/victima');

    await tocar(tester, find.text('Poner la fecha'));
    // El calendario abre en hoy (22 de octubre): se elige el 25.
    await tester.tap(find.text('25'));
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();

    final c = contenedor(tester);
    expect(c.read(miTicketProvider).fecha, DateTime(2026, 10, 25));
    expect(find.text('Faltan 3 días'), findsOneWidget);
    expect(find.text('Domingo 25 de octubre'), findsOneWidget);
    // El saludo dice la fecha, sin cuenta atrás.
    expect(find.text('Tu cita: domingo 25 de octubre'), findsOneWidget);
    expect(find.text('Faltan 3 días para tu cita'), findsNothing);

    await tocar(tester, find.widgetWithText(CheckboxListTile, 'La citación (el aviso) o una foto de ella'));
    expect(c.read(miTicketProvider).llevarHecho, {'citacion'});
    expect(find.textContaining('(1 de 6 preparadas)'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Añadir otra cosa'), 'Mi libro de dragones');
    await tocar(tester, find.byTooltip('Añadir a la lista'));
    expect(find.text('Mi libro de dragones'), findsOneWidget);
    expect(c.read(miTicketProvider).llevarPropias.single.texto, 'Mi libro de dragones');

    await tocar(tester, find.text('Borrar mi día'));
    expect(c.read(miTicketProvider).fecha, isNull);
    expect(find.text('Poner la fecha'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(MiTicketNotifier.clave), isFalse);
  });

  testWidgets('una fecha que ya pasó lo dice con calma', (tester) async {
    final router = await arrancarSituacion(
      tester,
      preferencias: {
        MiTicketNotifier.clave: jsonEncode({'fecha': '2026-10-20'}),
      },
    );
    await abrir(tester, router, '/situacion/victima');
    await tester.ensureVisible(find.text('Fue hace 2 días'));
    expect(find.text('Esta fecha ya ha pasado. Puedes poner otra o borrarla.'), findsOneWidget);
  });

  group('TarjetaModoDia (para la portada)', () {
    Future<GoRouter> montar(
      WidgetTester tester,
      Map<String, Object> preferencias, {
      TarjetaModoDia tarjeta = const TarjetaModoDia(),
    }) async {
      SharedPreferences.setMockInitialValues(preferencias);
      final prefs = await SharedPreferences.getInstance();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(body: tarjeta),
          ),
          GoRoute(path: '/situacion/:rol', builder: (context, state) => Text('Guía ${state.pathParameters['rol']}')),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            relojProvider.overrideWithValue(() => hoyDemo),
          ],
          child: MaterialApp.router(theme: temaTuTurno(Brightness.light), routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('sin fecha, no ocupa nada', (tester) async {
      await montar(tester, const {});
      expect(find.byType(TarjetaModoDia), findsOneWidget);
      expect(tester.getSize(find.byType(TarjetaModoDia)), Size.zero);
    });

    testWidgets('el día de la cita: «Hoy es tu día» con la hora, y lleva a la guía de su papel', (tester) async {
      await montar(tester, perfilSergio());
      expect(find.text('Hoy es tu día'), findsOneWidget);
      expect(find.textContaining('A las 12:30.'), findsOneWidget);
      await tester.tap(find.text('Hoy es tu día'));
      await tester.pumpAndSettle();
      expect(find.text('Guía victima'), findsOneWidget);
    });

    testWidgets('unos días antes, la fecha (sin cuenta atrás); más de 30 días o ya pasada, nada', (tester) async {
      await montar(tester, perfilLucia());
      expect(find.text('Tu cita'), findsOneWidget);
      expect(find.textContaining('Sábado 24 de octubre · 10:00.'), findsOneWidget);
      expect(find.textContaining('Faltan'), findsNothing);

      await montar(tester, {
        MiTicketNotifier.clave: jsonEncode({'fecha': '2026-12-30'}),
      });
      expect(tester.getSize(find.byType(TarjetaModoDia)), Size.zero);

      await montar(tester, {
        MiTicketNotifier.clave: jsonEncode({'fecha': '2026-10-01'}),
      });
      expect(tester.getSize(find.byType(TarjetaModoDia)), Size.zero);
    });

    testWidgets('en el inicio (soloElDia), solo el día de la cita', (tester) async {
      const delInicio = TarjetaModoDia(soloElDia: true);
      await montar(tester, perfilLucia(), tarjeta: delInicio);
      expect(tester.getSize(find.byType(TarjetaModoDia)), Size.zero);
      await montar(tester, perfilSergio(), tarjeta: delInicio);
      expect(find.text('Hoy es tu día'), findsOneWidget);
    });

    testWidgets('en la portada de Mi situación (soloConPapel), sin papel no sale: llevaría a la misma portada', (
      tester,
    ) async {
      const deLaPortada = TarjetaModoDia(soloConPapel: true);
      await montar(tester, {
        MiTicketNotifier.clave: jsonEncode({'fecha': '2026-10-24'}),
      }, tarjeta: deLaPortada);
      expect(tester.getSize(find.byType(TarjetaModoDia)), Size.zero);
      await montar(tester, perfilLucia(), tarjeta: deLaPortada);
      expect(find.text('Tu cita'), findsOneWidget);
    });
  });
}
