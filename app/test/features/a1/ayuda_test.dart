import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tuturno/core/progreso.dart';
import 'package:tuturno/core/recursos_ayuda.dart';
import 'package:tuturno/features/ayuda/ayuda_screen.dart';

import 'helpers.dart';

/// Simula url_launcher: guarda las direcciones que se piden abrir y responde [abre].
List<String> simularLanzador(WidgetTester tester, {required bool abre}) {
  final pedidas = <String>[];
  const canal = MethodChannel('plugins.flutter.io/url_launcher');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(canal, (llamada) async {
    if (llamada.method == 'launch') pedidas.add((llamada.arguments as Map)['url'] as String);
    return abre;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(canal, null));
  return pedidas;
}

/// Mediodía en la península (21/10/2026, UTC+2): el 017 está abierto.
final _mediodia = DateTime.utc(2026, 10, 21, 10);

/// Las 23:30 en la península: el 017 ya está cerrado.
final _noche = DateTime.utc(2026, 10, 21, 21, 30);

const _horario017 = 'Todos los días, de 8:00 a 23:00';
const _llamarAnar = 'Llamar al 900 20 20 10';
const _llamarCanalJoven = 'Llamar al 900 293 183';

/// Abre la app en Ayuda con la hora fijada (por defecto, a mediodía): así el estado del 017 no depende de cuándo
/// se pasen los tests.
Future<GoRouter> abrirAyuda(
  WidgetTester tester, {
  DateTime? ahora,
  Map<String, Object> preferencias = const {},
  Size tamano = movil,
}) async {
  final router = await arrancarApp(
    tester,
    preferencias: preferencias,
    tamano: tamano,
    overrides: [relojProvider.overrideWithValue(() => ahora ?? _mediodia)],
  );
  await irA(tester, router, '/ayuda');
  return router;
}

/// El botón de tipo [T] (FilledButton, OutlinedButton…) que tiene el texto [texto].
Finder boton<T extends Widget>(String texto) =>
    find.ancestor(of: find.text(texto), matching: find.byWidgetPredicate((w) => w is T));

/// Guarda las vibraciones que se piden a la plataforma («HapticFeedbackType.lightImpact»…).
List<String> registrarVibraciones(WidgetTester tester) {
  final vibraciones = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (llamada) async {
    if (llamada.method == 'HapticFeedback.vibrate') vibraciones.add(llamada.arguments as String);
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return vibraciones;
}

/// Lo alto que empieza en pantalla [finder].
double y(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

void main() {
  testWidgets('Ayuda enseña el 112 arriba y todos los recursos con su botón', (tester) async {
    await abrirAyuda(tester);

    expect(find.byType(AyudaScreen), findsOneWidget);
    expect(find.text('¿Estás en peligro ahora?'), findsOneWidget);
    // En la propia pantalla de Ayuda no hace falta el botón de Ayuda.
    expect(find.byTooltip('Teléfonos de ayuda'), findsNothing);

    for (final recurso in recursosAyuda) {
      expect(find.text(recurso.nombre, skipOffstage: false), findsWidgets, reason: recurso.nombre);
      final telefono = recurso.telefono;
      if (telefono != null) {
        expect(find.text('Llamar al ${recurso.telefonoVisible}'), findsOneWidget, reason: telefono);
      }
    }
    expect(find.text('Canal Joven de la AEPD'), findsOneWidget);
    expect(find.text(_llamarCanalJoven), findsOneWidget);
    expect(find.text('Abrir la web'), findsOneWidget);
    expect(find.text('Escribir por chat'), findsOneWidget);
    expect(find.text('Escribir por WhatsApp'), findsOneWidget);
    expect(find.text(mensajeAdultoDeConfianza), findsOneWidget);
    expect(find.text(avisoLlamar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el 112 aparece una sola vez y es lo primero', (tester) async {
    await abrirAyuda(tester);

    expect(find.text('Llamar al 112'), findsOneWidget);
    final y112 = tester.getTopLeft(find.text('Llamar al 112')).dy;
    final yAnar = tester.getTopLeft(find.text(_llamarAnar)).dy;
    expect(y112, lessThan(yAnar));
  });

  testWidgets('llamar abre el marcador con el número, sin avisos si funciona', (tester) async {
    final pedidas = simularLanzador(tester, abre: true);
    await abrirAyuda(tester);

    await pulsar(tester, find.text('Llamar al 112'));
    await pulsar(tester, find.text(_llamarAnar));
    await pulsar(tester, find.text(_llamarCanalJoven));
    expect(pedidas, ['tel:112', 'tel:900202010', 'tel:900293183']);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('si no se puede abrir el teléfono, avisa con el número', (tester) async {
    final pedidas = simularLanzador(tester, abre: false);
    await abrirAyuda(tester);

    await pulsar(tester, find.text('Llamar al 116 111'));
    expect(pedidas, ['tel:116111']);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('No he podido abrir el teléfono. Marca el 116 111.'), findsOneWidget);
  });

  testWidgets('ANAR se puede llamar o escribir por chat (para quien no puede hablar)', (tester) async {
    final pedidas = simularLanzador(tester, abre: true);
    await abrirAyuda(tester);

    expect(find.text('Escribir por chat'), findsOneWidget);
    await pulsar(tester, find.text('Escribir por chat'));
    expect(pedidas, ['https://chatanar.es']);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('los teléfonos no se parten en dos líneas', (tester) async {
    await abrirAyuda(tester, preferencias: {'ajustes.tamano_texto': 1.3}, tamano: const Size(360, 640));
    final numero = find.text('900 20 20 10');
    expect(numero, findsOneWidget);
    final linea = tester.getSize(find.text('Fundación ANAR')).height;
    expect(tester.getSize(numero).height, lessThan(linea * 2));
  });

  testWidgets('si no se puede abrir la web, avisa con la dirección', (tester) async {
    final pedidas = simularLanzador(tester, abre: false);
    await abrirAyuda(tester);

    await pulsar(tester, find.text('Abrir la web'));
    expect(pedidas, ['https://www.aepd.es/canalprioritario']);
    expect(find.textContaining('aepd.es/canalprioritario'), findsWidgets);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  group('017: horario', () {
    testWidgets('si Ayuda sigue abierta a las 23:00, pasa sola a «Cerrado ahora» y propone ANAR', (tester) async {
      // 22:59:30 en la península; el reloj avanza mientras la pantalla está abierta.
      var ahora = DateTime.utc(2026, 10, 21, 20, 59, 30);
      final router = await arrancarApp(tester, overrides: [relojProvider.overrideWithValue(() => ahora)]);
      await irA(tester, router, '/ayuda');
      await tester.ensureVisible(find.text(textoAbierto));
      await tester.pumpAndSettle();
      expect(find.text(textoAbierto), findsOneWidget);

      ahora = DateTime.utc(2026, 10, 21, 21, 0, 30);
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(find.text(textoCerrado, skipOffstage: false), findsOneWidget);
      expect(find.text(textoAbierto, skipOffstage: false), findsNothing);
      expect(find.text(textoLlamarAnar, skipOffstage: false), findsOneWidget);
    });

    testWidgets('en horario: enseña el horario, «Abierto ahora» y se llama como los demás', (tester) async {
      final semantica = tester.ensureSemantics();
      await abrirAyuda(tester, ahora: _mediodia);
      await tester.ensureVisible(find.text(textoAbierto));
      await tester.pumpAndSettle();

      expect(find.text(_horario017), findsOneWidget);
      expect(find.text(textoAbierto), findsOneWidget);
      expect(find.text(textoCerrado), findsNothing);
      expect(find.byKey(const Key('ayuda-cerrado')), findsNothing);
      expect(boton<FilledButton>('Llamar al 017'), findsOneWidget);
      // El lector de pantalla lo lee todo de una vez.
      expect(find.bySemanticsLabel('Horario: $_horario017. $textoAbierto.'), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('fuera de horario: dice que está cerrado y lleva a ANAR o al 112', (tester) async {
      final pedidas = simularLanzador(tester, abre: true);
      final semantica = tester.ensureSemantics();
      await abrirAyuda(tester, ahora: _noche);
      await tester.ensureVisible(find.text(textoCerrado));
      await tester.pumpAndSettle();

      expect(find.text(textoCerrado), findsOneWidget);
      expect(find.text(textoAbierto), findsNothing);
      expect(find.bySemanticsLabel('Horario: $_horario017. $textoCerrado.'), findsOneWidget);
      final cerrado = find.byKey(const Key('ayuda-cerrado'));
      expect(cerrado, findsOneWidget);
      expect(find.descendant(of: cerrado, matching: find.text('Abre a las 8:00.')), findsOneWidget);
      expect(find.descendant(of: cerrado, matching: find.text(textoAlternativa)), findsOneWidget);
      expect(textoAlternativa, allOf(contains('ANAR'), contains('a cualquier hora'), contains('112')));
      // Que está cerrado ya lo dice la pastilla: el aviso no lo repite.
      expect(find.descendant(of: cerrado, matching: find.textContaining('cerrado')), findsNothing);
      // ANAR pasa a ser el botón principal; el 017 sigue ahí (la persona decide), pero sin destacar.
      expect(find.descendant(of: cerrado, matching: boton<FilledButton>(textoLlamarAnar)), findsOneWidget);
      expect(boton<FilledButton>('Llamar al 017'), findsNothing);
      expect(boton<OutlinedButton>('Llamar al 017'), findsOneWidget);
      // Primero, de un vistazo, el horario; después, para qué sirve; y la alternativa, justo antes de sus botones.
      final incibe = recursosAyuda.singleWhere((r) => r.horario != null);
      expect(y(tester, find.text(textoCerrado)), lessThan(y(tester, find.text(incibe.descripcion))));
      expect(y(tester, find.text(incibe.descripcion)), lessThan(y(tester, cerrado)));
      expect(y(tester, cerrado), lessThan(y(tester, find.text('Llamar al 017'))));
      expect(y(tester, find.text('Llamar al 017')), lessThan(y(tester, find.text('Escribir por WhatsApp'))));

      await pulsar(tester, find.text(textoLlamarAnar));
      await pulsar(tester, find.text('Llamar al 017'));
      expect(pedidas, ['tel:900202010', 'tel:017']);
      semantica.dispose();
    });

    testWidgets('en invierno, a las 23:30 también está cerrado', (tester) async {
      await abrirAyuda(tester, ahora: DateTime.utc(2026, 12, 1, 22, 30));
      expect(find.text(textoCerrado, skipOffstage: false), findsOneWidget);
    });
  });

  testWidgets('los botones vibran con un toque suave: Ayuda no se gamifica', (tester) async {
    simularLanzador(tester, abre: true);
    final vibraciones = registrarVibraciones(tester);
    await abrirAyuda(tester, ahora: _noche);

    await pulsar(tester, find.text('Llamar al 112'));
    await pulsar(tester, find.text('Escribir por chat'));
    await pulsar(tester, find.text(textoLlamarAnar));
    await pulsar(tester, find.text('Escribir por WhatsApp'));
    await pulsar(tester, find.text('Abrir la web'));
    expect(vibraciones, List.filled(5, 'HapticFeedbackType.lightImpact'));
  });

  testWidgets('el WhatsApp del 017 se abre fuera de la app y, si no se puede, da el número', (tester) async {
    final pedidas = simularLanzador(tester, abre: false);
    await abrirAyuda(tester);

    await pulsar(tester, find.text('Escribir por WhatsApp'));
    expect(pedidas, ['https://wa.me/34900116117']);
    expect(find.text('No he podido abrir WhatsApp. Escribe al 900 116 117.'), findsOneWidget);
  });

  testWidgets('el Canal prioritario dice para qué sirve, para qué no y desde qué edad', (tester) async {
    await abrirAyuda(tester);
    final canal = recursosAyuda.singleWhere((r) => r.web != null);

    await tester.ensureVisible(find.text('Abrir la web'));
    await tester.pumpAndSettle();
    expect(find.text('aepd.es/canalprioritario'), findsOneWidget);
    expect(canal.notas, hasLength(3));
    for (final nota in canal.notas) {
      expect(find.text(nota.texto), findsOneWidget, reason: nota.texto);
    }
    // Las notas van antes del botón: se leen antes de abrir la web.
    final yUltimaNota = tester.getTopLeft(find.text(canal.notas.last.texto)).dy;
    expect(yUltimaNota, lessThan(tester.getTopLeft(find.text('Abrir la web')).dy));
  });

  for (final (nombre, ahora) in [('abierto', _mediodia), ('cerrado', _noche)]) {
    testWidgets('Ayuda cabe con letra grande en un móvil pequeño ($nombre)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await abrirAyuda(tester, ahora: ahora, preferencias: {'ajustes.tamano_texto': 1.3}, tamano: const Size(360, 640));
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -6000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    // En una pantalla muy alta cabe todo sin desplazar: así se comprueban todos los textos y botones a la vez, sin
    // ninguno cortado por el borde.
    testWidgets('contraste y zonas táctiles de toda la pantalla, en claro y en oscuro ($nombre)', (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantica = tester.ensureSemantics();
      for (final brillo in Brightness.values) {
        tester.platformDispatcher.platformBrightnessTestValue = brillo;
        await abrirAyuda(tester, ahora: ahora, tamano: const Size(400, 5000));
        final desplazamiento = tester.state<ScrollableState>(
          find.descendant(of: find.byType(AyudaScreen), matching: find.byType(Scrollable)).first,
        );
        expect(desplazamiento.position.maxScrollExtent, 0, reason: 'Tiene que caber todo para comprobarlo todo');
        await expectLater(tester, meetsGuideline(textContrastGuideline), reason: '$brillo');
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline), reason: '$brillo');
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: '$brillo');
      }
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      semantica.dispose();
    });
  }
}
