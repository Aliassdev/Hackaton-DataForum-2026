import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/entrada.dart';
import 'package:tuturno/core/progreso.dart';
import 'package:tuturno/features/ajustes/ajustes_screen.dart';
import 'package:tuturno/features/ajustes/para_el_equipo.dart' show avisoComoNuevo;
import 'package:tuturno/features/inicio/bienvenida.dart';
import 'package:tuturno/features/inicio/turno_del_dia.dart';
import 'package:tuturno/features/situacion/mi_ticket.dart';
import 'package:tuturno/features/situacion/textos.dart' show botonCambiarTicket, botonRellenarTicket;
import 'package:tuturno/features/situacion/ticket_screen.dart' show TuTicketScreen;

import 'ayudas_ajustes.dart';

// Ajustes → «Tus datos en este móvil» (plan v2, producto §5.3): «Borrar todo lo de este móvil» pide confirmación,
// «Cancelar» no borra nada y, al borrar, la app queda como nueva salvo los ajustes de lectura.

/// Lo que habría en el móvil de alguien que ya ha usado TuTurno, con sus ajustes de lectura.
Map<String, Object> _usado() => {
  'progreso': jsonEncode(const Progreso(xp: 120, racha: 2, cartas: {'R-ser-escuchada'}).toJson()),
  'entrada': jsonEncode({'edad': 15, 'procedimiento': 'penal', 'rol': 'testigo', 'fase': 'antes'}),
  'mis_preguntas': '[]',
  'glosario.favoritos': '["G-citacion"]',
  // Lo que «Tu ticket» de Mi situación guarda además (con quién irás, qué te preocupa…).
  MiTicketNotifier.clave: '{"con_quien":["familia"]}',
  'ajustes.tamano_texto': 1.3,
  'ajustes.lectura_facil': true,
  'ajustes.reducir_movimiento': true,
  'ajustes.voz_activada': false,
};

final _botonBorrar = find.text('Borrar todo lo de este móvil');

void main() {
  testWidgets('«Tus datos en este móvil» dice qué se guarda y qué sale', (tester) async {
    final router = await arrancarAjustes(tester);
    await abrir(tester, router, '/ajustes');
    await tester.scrollUntilVisible(_botonBorrar, 300, scrollable: find.byType(Scrollable).first);

    expect(find.text('Tus datos en este móvil'), findsOneWidget);
    expect(find.text(textoQueSeGuarda), findsOneWidget);
    expect(find.text(textoQueSale), findsOneWidget);
  });

  testWidgets('pide confirmación y «Cancelar» no borra nada', (tester) async {
    final router = await arrancarAjustes(tester, preferencias: _usado());
    await abrir(tester, router, '/ajustes');
    final antes = await foto();

    await tocar(tester, _botonBorrar);
    expect(find.text('¿Borrar todo?'), findsOneWidget);
    expect(find.textContaining('Los ajustes de letra y voz se quedan'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Borrar todo?'), findsNothing);
    expect(await foto(), antes);
    expect(rutaActual(router), '/ajustes');
    expect(find.byType(AjustesScreen), findsOneWidget);
  });

  testWidgets('al confirmar, borra lo de uso, deja los ajustes y vuelve a la bienvenida', (tester) async {
    final router = await arrancarAjustes(tester, preferencias: _usado());
    final app = contenedor(tester);
    // El inicio ya ha apuntado su turno del día.
    expect(app.read(turnoDelDiaProvider).numero, 1);
    await abrir(tester, router, '/ajustes');

    await tocar(tester, _botonBorrar);
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar todo'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    for (final clave in [
      'progreso',
      'entrada',
      'mis_preguntas',
      'glosario.favoritos',
      'bienvenida_vista',
      MiTicketNotifier.clave,
    ]) {
      expect(prefs.containsKey(clave), isFalse, reason: clave);
    }
    // Los ajustes de lectura y voz se quedan.
    expect(prefs.getDouble('ajustes.tamano_texto'), 1.3);
    expect(prefs.getBool('ajustes.lectura_facil'), isTrue);
    expect(prefs.getBool('ajustes.reducir_movimiento'), isTrue);
    expect(prefs.getBool('ajustes.voz_activada'), isFalse);

    // La app, como nueva: en el inicio, con la bienvenida y el aviso.
    expect(rutaActual(router), '/');
    expect(find.byType(Bienvenida), findsOneWidget);
    expect(find.text(avisoComoNuevo), findsOneWidget);
    expect(app.read(progresoProvider).xp, 0);
    expect(app.read(progresoProvider).cartas, isEmpty);
    expect(app.read(entradaProvider).vacia, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('«Tu ticket» enseña el resumen y «Borrar mis respuestas» lo vacía (y «Tu día» se queda)', (tester) async {
    final router = await arrancarAjustes(
      tester,
      preferencias: {
        'entrada': jsonEncode({'edad': 13, 'procedimiento': 'penal', 'rol': 'victima', 'fase': 'durante'}),
        MiTicketNotifier.clave: jsonEncode({
          'con_quien': ['familia'],
          'preocupaciones': ['colegio'],
          'fecha': '2026-10-24',
        }),
      },
    );
    final app = contenedor(tester);
    await abrir(tester, router, '/ajustes');
    final resumen = find.byKey(const Key('resumen-ticket'));
    await tester.scrollUntilVisible(resumen, 300, scrollable: find.byType(Scrollable).first);

    expect(tester.widget<Text>(resumen).data, '13 años · Penal · Víctima · Durante');
    expect(find.text(notaTicket), findsOneWidget);
    expect(find.text(botonCambiarTicket), findsOneWidget);

    await tocar(tester, find.text('Borrar mis respuestas'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('entrada'), isFalse);
    // Lo mismo que «Borrar mis respuestas» de «Tu ticket»: las respuestas se van y «Tu día» se queda.
    expect(app.read(miTicketProvider).sinRespuestas, isTrue);
    expect(app.read(miTicketProvider).fecha, DateTime(2026, 10, 24));
    expect(prefs.getString(MiTicketNotifier.clave), isNot(contains('colegio')));
    expect(tester.widget<Text>(resumen).data, 'Sin rellenar');
    expect(find.text('Borrar mis respuestas'), findsNothing);
    expect(find.text(botonRellenarTicket), findsOneWidget);
    expect(find.text('Hecho. Tu ticket está vacío.'), findsOneWidget);
  });

  testWidgets('las respuestas de Mi situación se pueden borrar aunque el ticket de la app esté vacío', (tester) async {
    final router = await arrancarAjustes(
      tester,
      preferencias: {
        MiTicketNotifier.clave: jsonEncode({
          'preocupaciones': ['ver_persona'],
        }),
      },
    );
    final app = contenedor(tester);
    await abrir(tester, router, '/ajustes');
    await tester.scrollUntilVisible(find.text('Borrar mis respuestas'), 300, scrollable: find.byType(Scrollable).first);
    expect(tester.widget<Text>(find.byKey(const Key('resumen-ticket'))).data, 'Sin rellenar');

    await tocar(tester, find.text('Borrar mis respuestas'));
    expect(app.read(miTicketProvider).vacio, isTrue);
    expect((await SharedPreferences.getInstance()).containsKey(MiTicketNotifier.clave), isFalse);
  });

  testWidgets('«Cambiar mi ticket» abre «Tu ticket» también en modo texto (la web)', (tester) async {
    final router = await arrancarAjustes(
      tester,
      preferencias: {
        'entrada': jsonEncode({'edad': 13, 'procedimiento': 'penal', 'rol': 'victima', 'fase': 'durante'}),
      },
    );
    await abrir(tester, router, '/ajustes');
    await tester.scrollUntilVisible(find.text(botonCambiarTicket), 300, scrollable: find.byType(Scrollable).first);
    await tocar(tester, find.text(botonCambiarTicket));
    expect(find.byType(TuTicketScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('«Borrar todo» vacía Mi situación aunque el ticket de la app ya estuviera vacío', (tester) async {
    // Quien entra por el selector de papel no guarda el ticket de la app, pero sí puede poner «Tu día».
    final router = await arrancarAjustes(
      tester,
      preferencias: {
        MiTicketNotifier.clave: jsonEncode({
          'preocupaciones': ['ver_persona'],
          'fecha': '2026-10-24',
        }),
      },
    );
    final app = contenedor(tester);
    expect(app.read(miTicketProvider).fecha, DateTime(2026, 10, 24));
    await abrir(tester, router, '/ajustes');

    await tocar(tester, _botonBorrar);
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar todo'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(app.read(miTicketProvider).vacio, isTrue);
    expect(prefs.containsKey(MiTicketNotifier.clave), isFalse);
    // Y lo borrado no vuelve al tocar otra cosa de Mi situación.
    app.read(miTicketProvider.notifier).alternarPreocupacion(Preocupacion.redes);
    expect(app.read(miTicketProvider).fecha, isNull);
    expect(app.read(miTicketProvider).preocupaciones, {Preocupacion.redes});
    expect(prefs.getString(MiTicketNotifier.clave), isNot(contains('2026-10-24')));
  });

  testWidgets('el resumen del ticket se lee como una frase', (tester) async {
    final semantica = tester.ensureSemantics();
    final router = await arrancarAjustes(
      tester,
      preferencias: {
        'entrada': jsonEncode({'edad': 13, 'procedimiento': 'penal', 'rol': 'victima', 'fase': 'durante'}),
      },
    );
    await abrir(tester, router, '/ajustes');
    await tester.scrollUntilVisible(
      find.byKey(const Key('resumen-ticket')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.bySemanticsLabel('Tu ticket: 13 años, Penal, Víctima, Durante'), findsOneWidget);
    semantica.dispose();
  });
}
