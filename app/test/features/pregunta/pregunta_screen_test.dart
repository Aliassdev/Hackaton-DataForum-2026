import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tuturno/app.dart';
import 'package:tuturno/core/api/mock_api.dart';
import 'package:tuturno/core/api/tuturno_api.dart';
import 'package:tuturno/core/providers.dart';
import 'package:tuturno/features/pregunta/pregunta_screen.dart';
import 'package:tuturno/features/pregunta/textos.dart';
import 'package:tuturno/features/pregunta/widgets/mensajes.dart';
import 'package:tuturno/features/pregunta/widgets/tickets.dart';
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/fuente_chip.dart';
import 'package:tuturno/widgets/iconos/iconos.dart';
import 'package:tuturno/widgets/texto_con_terminos.dart';

import 'fakes.dart';

const _preguntaDemo = 'Si tengo 13 años y hago algo malo, ¿me pueden juzgar?';
const _campo = Key('campo-pregunta');
const _enviar = Key('boton-enviar');
const _micro = Key('boton-micro');
const _microPequeno = Key('boton-micro-pequeno');
const _llamarAnar = 'Llamar a ANAR · 900\u00A020\u00A020\u00A010';

class _Pantalla {
  _Pantalla(this.api, this.stt, this.tts, this.router);

  final ApiGrabadora api;
  final FakeStt stt;
  final FakeTts tts;
  final GoRouter router;
}

/// «Pregunta» con un router mínimo (Glosario y Ayuda son pantallas de prueba) y voz falsa.
Future<_Pantalla> _abrir(
  WidgetTester tester, {
  RolProceso? situacion,
  FakeStt? stt,
  FakeTts? tts,
  bool vozActivada = true,
  double escalaTexto = 1,
  Size? tamano,
  String? preguntaInicial,
  Brightness brillo = Brightness.light,
}) async {
  // Tamaño de un móvil Android normal (Pixel 7), salvo que el test pida otro.
  tester.view.physicalSize = (tamano ?? const Size(412, 915)) * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  final api = ApiGrabadora();
  final vozATexto = stt ?? FakeStt();
  final textoAVoz = tts ?? FakeTts();
  final router = GoRouter(
    initialLocation: situacion == null ? '/pregunta' : '/pregunta?situacion=${situacion.name}',
    routes: [
      GoRoute(
        path: '/pregunta',
        builder: (context, state) => PreguntaScreen(
          situacion: RolProceso.values.asNameMap()[state.uri.queryParameters['situacion']],
          preguntaInicial: preguntaInicial,
        ),
      ),
      GoRoute(
        path: '/glosario',
        builder: (context, state) => Scaffold(body: Text('glosario:${state.uri.queryParameters['q']}')),
      ),
      GoRoute(
        path: '/ayuda',
        builder: (context, state) => const Scaffold(body: Text('pantalla de ayuda')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: await overridesDePrueba(api: api, stt: vozATexto, tts: textoAVoz, vozActivada: vozActivada),
      child: MaterialApp.router(
        theme: temaTuTurno(brillo),
        locale: const Locale('es', 'ES'),
        supportedLocales: const [Locale('es', 'ES')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(escalaTexto)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Pantalla(api, vozATexto, textoAVoz, router);
}

Future<void> _escribirYEnviar(WidgetTester tester, String texto) async {
  await tester.enterText(find.byKey(_campo), texto);
  await tester.pump();
  await tester.tap(find.byKey(_enviar));
  await tester.pumpAndSettle();
}

String _textoDelCampo(WidgetTester tester) => tester.widget<TextField>(find.byKey(_campo)).controller!.text;

/// Desplaza la lista (ejemplos o conversación) hasta que se ve [finder]. Con la letra de las pruebas, más ancha que
/// la real, no todo cabe en la pantalla.
Future<void> _desplazarHasta(WidgetTester tester, Finder finder) => tester.scrollUntilVisible(
  finder,
  120,
  scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first,
);

/// Hace visible [finder] (esperando a que se recoloque) y lo pulsa.
Future<void> _pulsar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Las expresiones de todos los Tut que hay en pantalla.
Iterable<ExpresionTut> _expresionesDeTut(WidgetTester tester) =>
    tester.widgetList<MascotaTut>(find.byType(MascotaTut)).map((tut) => tut.expresion);

void main() {
  testWidgets('sin mensajes enseña la presentación de la IA y las preguntas de ejemplo', (tester) async {
    await _abrir(tester);

    expect(find.text(textoPresentacion), findsOneWidget);
    expect(find.text('¿Qué quieres saber?'), findsOneWidget);
    for (final ejemplo in ejemplos) {
      await _desplazarHasta(tester, find.text(ejemplo.texto));
      expect(find.text(ejemplo.texto), findsOneWidget);
    }
    expect(find.text('Pulsa para hablar'), findsOneWidget);
    expect(find.byTooltip('Glosario'), findsOneWidget);
    expect(find.text('Ayuda'), findsOneWidget);
  });

  testWidgets('se envía desde el campo de texto y llega la respuesta con fuentes', (tester) async {
    final p = await _abrir(tester);
    await _escribirYEnviar(tester, _preguntaDemo);

    expect(p.api.peticiones.single.pregunta, _preguntaDemo);
    expect(_textoDelCampo(tester), isEmpty);
    expect(find.textContaining('Antes de los 14 años', findRichText: true), findsOneWidget);
    expect(find.text('LO 5/2000 · art. 3'), findsOneWidget);
    expect(find.text('¿Qué pasa a partir de los 14?'), findsOneWidget);
    // Se ha escrito, no dictado: aunque la voz esté activada, no se lee sola (queda «Escuchar»).
    expect(p.tts.leidos, isEmpty);
    expect(find.text('Escuchar'), findsOneWidget);
    // La pregunta queda encima de la respuesta (si la respuesta es larga, hay que subir para verla).
    await _desplazarHasta(tester, find.text(_preguntaDemo));
    expect(find.text(_preguntaDemo), findsOneWidget);
  });

  testWidgets('lo que se pregunta con la voz se contesta en voz alta', (tester) async {
    final p = await _abrir(tester);
    await tester.tap(find.byKey(_micro));
    await tester.pump();
    p.stt.oir('si tengo 13 años me pueden juzgar');
    await tester.tap(find.byKey(_micro));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_enviar));
    await tester.pumpAndSettle();

    expect(p.api.peticiones.single.pregunta, 'si tengo 13 años me pueden juzgar');
    expect(p.tts.leidos, hasLength(1));

    // La siguiente, escrita, ya no se lee sola.
    await _escribirYEnviar(tester, '¿Qué es una citación?');
    expect(p.tts.leidos, hasLength(1));
  });

  testWidgets('la acción «enviar» del teclado también envía', (tester) async {
    final p = await _abrir(tester);
    await tester.enterText(find.byKey(_campo), '¿Qué es la Sala Gesell?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(p.api.peticiones.single.pregunta, '¿Qué es la Sala Gesell?');
  });

  testWidgets('tocar un ejemplo pregunta directamente', (tester) async {
    final p = await _abrir(tester);
    await _desplazarHasta(tester, find.text('¿Qué hago si difunden fotos mías?'));
    await _pulsar(tester, find.text('¿Qué hago si difunden fotos mías?'));

    expect(p.api.peticiones.single.pregunta, '¿Qué hago si difunden fotos mías?');
    expect(find.text(textoPresentacion), findsNothing);
  });

  testWidgets('tocar una sugerencia pregunta directamente con el historial', (tester) async {
    final p = await _abrir(tester);
    await _escribirYEnviar(tester, _preguntaDemo);

    await tester.tap(find.text('¿Qué pasa a partir de los 14?'));
    await tester.pumpAndSettle();

    expect(p.api.peticiones, hasLength(2));
    expect(p.api.peticiones.last.pregunta, '¿Qué pasa a partir de los 14?');
    expect(p.api.peticiones.last.historial, hasLength(2));
    // Las sugerencias solo salen en la última respuesta.
    expect(find.text('Puedes seguir con…'), findsOneWidget);
  });

  testWidgets('la etiqueta de fuente abre la hoja con el título, la norma y el artículo', (tester) async {
    await _abrir(tester);
    await _escribirYEnviar(tester, _preguntaDemo);

    await tester.tap(find.text('LO 5/2000 · art. 3'));
    await tester.pumpAndSettle();

    expect(find.text('Antes de los 14 años no hay responsabilidad penal'), findsOneWidget);
    expect(find.text('Norma'), findsOneWidget);
    expect(find.text('LO 5/2000'), findsOneWidget);
    expect(find.text('Ley de responsabilidad penal de los menores'), findsOneWidget);
    expect(find.text('Artículo'), findsOneWidget);

    await tester.ensureVisible(find.text('Entendido'));
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    expect(find.text('Norma'), findsNothing);
  });

  testWidgets('tocar un término subrayado abre el Glosario y al volver sigue la conversación', (tester) async {
    final p = await _abrir(tester);
    await _escribirYEnviar(tester, _preguntaDemo);

    await tester.tapOnText(find.textRange.ofSubstring('responsabilidad penal'));
    await tester.pumpAndSettle();
    expect(find.text('glosario:responsabilidad penal'), findsOneWidget);

    p.router.pop();
    await tester.pumpAndSettle();
    expect(find.text('LO 5/2000 · art. 3'), findsOneWidget);
    await _desplazarHasta(tester, find.text(_preguntaDemo));
    expect(find.text(_preguntaDemo), findsOneWidget);
  });

  testWidgets('una respuesta de crisis enseña la tarjeta de Ayuda encima', (tester) async {
    await _abrir(tester);
    await _escribirYEnviar(tester, 'A veces pienso que no quiero vivir');

    final tarjeta = find.byKey(const Key('tarjeta-crisis'));
    expect(tarjeta, findsOneWidget);
    expect(find.descendant(of: tarjeta, matching: find.text(_llamarAnar)), findsOneWidget);
    expect(find.descendant(of: tarjeta, matching: find.text('Emergencias · 112')), findsOneWidget);
    final respuesta = find.textContaining('Siento que estés pasando por esto', findRichText: true);
    expect(tester.getTopLeft(tarjeta).dy, lessThan(tester.getTopLeft(respuesta).dy));
  });

  testWidgets('una respuesta de «hechos» ofrece ir a Ayuda sin preguntar qué pasó', (tester) async {
    await _abrir(tester);
    await _escribirYEnviar(tester, 'Me pegaron en el recreo');

    expect(find.textContaining('Gracias por contármelo', findRichText: true), findsOneWidget);
    // Las sugerencias son las de la respuesta (o, si no trae, las de reserva para «hechos»), y hablan del proceso.
    // (Fuera del reloj falso de la prueba: el mock espera con un Future.delayed.)
    final respuesta = (await tester.runAsync(
      () => MockTuTurnoApi(latencia: Duration.zero).ask(const AskRequest(pregunta: 'Me pegaron en el recreo')),
    ))!;
    final sugerencias = respuesta.sugerencias.isNotEmpty
        ? respuesta.sugerencias.take(3)
        : sugerenciasPorTipo[TipoRespuesta.hechos]!;
    for (final sugerencia in sugerencias) {
      expect(find.text(sugerencia), findsOneWidget);
      expect(sugerencia.toLowerCase(), isNot(contains('qué pasó')));
    }
    await _pulsar(tester, find.text('Ver teléfonos de ayuda'));
    expect(find.text('pantalla de ayuda'), findsOneWidget);
  });

  testWidgets('si el micrófono no está disponible, avisa y se puede escribir', (tester) async {
    final p = await _abrir(tester, stt: FakeStt(disponible: false));

    await tester.tap(find.byKey(_micro));
    await tester.pumpAndSettle();
    expect(find.text('No puedo usar el micrófono. Puedes escribir tu pregunta.'), findsOneWidget);
    expect(find.text('Micrófono no disponible'), findsOneWidget);

    await _escribirYEnviar(tester, _preguntaDemo);
    expect(p.api.peticiones, hasLength(1));
    expect(find.text('LO 5/2000 · art. 3'), findsOneWidget);
  });

  testWidgets('al hablar se ve la transcripción y al parar pasa al campo para corregirla', (tester) async {
    final p = await _abrir(tester);

    await tester.tap(find.byKey(_micro));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('panel-escucha')), findsOneWidget);
    expect(find.text('Te escucho… Pulsa para parar'), findsOneWidget);
    expect(find.text('Habla ahora. Te escucho.'), findsOneWidget);

    p.stt.oir('qué es la sala gesell');
    await tester.pump();
    expect(find.text('qué es la sala gesell'), findsOneWidget);

    await tester.tap(find.byKey(_micro));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('panel-escucha')), findsNothing);
    expect(_textoDelCampo(tester), 'qué es la sala gesell');
    expect(find.text('Revisa lo que he entendido y pulsa enviar.'), findsOneWidget);
    expect(p.api.peticiones, isEmpty);

    await tester.enterText(find.byKey(_campo), '¿Qué es la Sala Gesell?');
    await tester.pump();
    expect(find.text('Revisa lo que he entendido y pulsa enviar.'), findsNothing);
    await tester.tap(find.byKey(_enviar));
    await tester.pumpAndSettle();
    expect(p.api.peticiones.single.pregunta, '¿Qué es la Sala Gesell?');
  });

  testWidgets('el micrófono se desactiva mientras llega la respuesta', (tester) async {
    final p = await _abrir(tester);
    p.api.pausa = Completer<void>();
    await tester.enterText(find.byKey(_campo), _preguntaDemo);
    await tester.pump();
    await tester.tap(find.byKey(_enviar));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(IndicadorEscribiendo), findsOneWidget);
    expect(find.text('Espera a que te conteste…'), findsOneWidget);
    await tester.tap(find.byKey(_micro));
    await tester.pump();
    expect(p.stt.inicializaciones, 0);

    p.api.pausa!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(IndicadorEscribiendo), findsNothing);
    expect(find.text('Pulsa para hablar'), findsOneWidget);
  });

  testWidgets('con «Mi situación» se ve el chip, se envía el papel y se puede quitar', (tester) async {
    final p = await _abrir(tester, situacion: RolProceso.testigo);
    expect(find.text('Preguntas como testigo'), findsOneWidget);

    await _escribirYEnviar(tester, '¿Veré a los acusados?');
    expect(p.api.peticiones.last.modo, ModoPregunta.situacion);
    expect(p.api.peticiones.last.situacion, RolProceso.testigo);

    await tester.tap(find.byTooltip('Quitar y preguntar en general'));
    await tester.pumpAndSettle();
    expect(find.text('Preguntas como testigo'), findsNothing);

    await _escribirYEnviar(tester, '¿Qué es una citación?');
    expect(p.api.peticiones.last.modo, ModoPregunta.libre);
    expect(p.api.peticiones.last.situacion, isNull);
  });

  testWidgets('un error sale como mensaje del asistente con «Reintentar»', (tester) async {
    final p = await _abrir(tester);
    p.api.errores.add(errorApi);
    await _escribirYEnviar(tester, _preguntaDemo);

    expect(find.text(errorApi.mensaje), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text(errorApi.mensaje), findsNothing);
    expect(find.text('LO 5/2000 · art. 3'), findsOneWidget);
    expect(p.api.peticiones, hasLength(2));
  });

  testWidgets('el altavoz de una respuesta la vuelve a leer y la para', (tester) async {
    final tts = FakeTts(terminarAlInstante: false);
    await _abrir(tester, tts: tts, vozActivada: false);
    await _escribirYEnviar(tester, _preguntaDemo);
    expect(tts.leidos, isEmpty);

    await tester.tap(find.text('Escuchar'));
    await tester.pumpAndSettle();
    expect(tts.leidos, hasLength(1));
    expect(find.text('Parar'), findsOneWidget);

    await tester.tap(find.text('Parar'));
    await tester.pumpAndSettle();
    expect(find.text('Escuchar'), findsOneWidget);
  });

  testWidgets('el botón de voz activa y desactiva la lectura en voz alta', (tester) async {
    final p = await _abrir(tester);
    await tester.tap(find.byTooltip('Las respuestas se leen en voz alta'));
    await tester.pumpAndSettle();
    expect(find.text('Sin voz'), findsOneWidget);

    await _escribirYEnviar(tester, _preguntaDemo);
    expect(p.tts.leidos, isEmpty);
  });

  testWidgets('«Nueva» borra la conversación tras confirmar', (tester) async {
    await _abrir(tester);
    await _escribirYEnviar(tester, '¿Qué derechos tengo?');

    await tester.tap(find.byTooltip('Empezar una conversación nueva'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Qué derechos tengo?'), findsNothing);
    expect(find.text(textoPresentacion), findsOneWidget);
  });

  testWidgets('con letra grande en un móvil pequeño no se rompe nada', (tester) async {
    await _abrir(tester, escalaTexto: 1.3 * 1.3, tamano: const Size(360, 740));
    await _escribirYEnviar(tester, 'A veces pienso que no quiero vivir');
    expect(tester.takeException(), isNull);

    // Con tan poco espacio, el micrófono pasa junto al campo de texto.
    expect(find.byKey(_micro), findsNothing);
    await tester.tap(find.byKey(_microPequeno));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('panel-escucha')), findsOneWidget);
  });

  testWidgets('en modo compacto, mientras escucha, hay un botón para parar', (tester) async {
    final semantica = tester.ensureSemantics();
    final p = await _abrir(tester, escalaTexto: 1.3 * 1.3, tamano: const Size(360, 740));
    await tester.tap(find.byKey(_microPequeno));
    // Mientras escucha hay animaciones continuas: no se puede esperar a que se paren.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('panel-escucha')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Pulsa para parar')), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

    p.stt.oir('mis derechos');
    await tester.tap(find.byKey(_microPequeno));
    await tester.pumpAndSettle();
    expect(p.stt.paradas, 1);
    expect(find.byKey(const Key('panel-escucha')), findsNothing);
    expect(_textoDelCampo(tester), 'mis derechos');
    expect(tester.takeException(), isNull);
    semantica.dispose();
  });

  testWidgets('en modo compacto, «Voz» y «Nueva» están en el menú de arriba', (tester) async {
    final p = await _abrir(tester, escalaTexto: 1.3 * 1.3, tamano: const Size(360, 740));
    await _escribirYEnviar(tester, '¿Qué derechos tengo?');

    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckedPopupMenuItem<String>));
    await tester.pumpAndSettle();
    final contenedor = ProviderScope.containerOf(tester.element(find.byType(PreguntaScreen)));
    expect(contenedor.read(ajustesProvider).vozActivada, isFalse);

    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empezar de nuevo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Qué derechos tengo?'), findsNothing);
    expect(p.api.peticiones, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('con el teclado abierto pasa a modo compacto sin desbordarse', (tester) async {
    await _abrir(tester, situacion: RolProceso.testigo, escalaTexto: 1.3, tamano: const Size(360, 740));
    expect(find.byKey(_micro), findsOneWidget);

    await tester.tap(find.byKey(_campo));
    tester.view.viewInsets = FakeViewPadding(bottom: 300 * tester.view.devicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    expect(find.byKey(_microPequeno), findsOneWidget);
    expect(find.byKey(_micro), findsNothing);
    expect(find.byTooltip('Más opciones'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // El campo sigue con el foco: si lo perdiera, el teclado se cerraría y el modo cambiaría otra vez.
    expect(tester.widget<TextField>(find.byKey(_campo)).focusNode!.hasFocus, isTrue);

    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.byKey(_micro), findsOneWidget);
  });

  testWidgets('con letra a 1,3 en un móvil pequeño se mantiene el micrófono grande', (tester) async {
    await _abrir(tester, escalaTexto: 1.3, tamano: const Size(360, 740));
    expect(find.byKey(_micro), findsOneWidget);
    await _escribirYEnviar(tester, _preguntaDemo);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cumple las pautas de accesibilidad (zonas táctiles, etiquetas y contraste)', (tester) async {
    final semantica = tester.ensureSemantics();
    await _abrir(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await _escribirYEnviar(tester, _preguntaDemo);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantica.dispose();
  });

  testWidgets('la tarjeta de crisis se ve entera al llegar la respuesta (móvil pequeño)', (tester) async {
    for (final escala in [1.0, 1.3, 1.3 * 1.3]) {
      await _abrir(tester, escalaTexto: escala, tamano: const Size(360, 740));
      await _escribirYEnviar(tester, 'Tengo miedo de volver a casa');

      final lista = tester.getRect(find.byType(ListView));
      final boton = tester.getRect(find.text(_llamarAnar));
      expect(boton.top, greaterThanOrEqualTo(lista.top), reason: 'escala $escala');
      expect(boton.bottom, lessThanOrEqualTo(lista.bottom), reason: 'escala $escala');
      if (escala == 1.0) {
        final cabecera = tester.getRect(find.text('Pide ayuda ahora'));
        expect(cabecera.top, greaterThanOrEqualTo(lista.top));
      }
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('sin conexión, si la pregunta suena a peligro, salen igualmente los teléfonos', (tester) async {
    final p = await _abrir(tester);
    p.api.errores.add(errorApi);
    await _escribirYEnviar(tester, 'Quiero morir');

    expect(find.text(errorApi.mensaje), findsOneWidget);
    expect(find.byKey(const Key('tarjeta-crisis-sin-conexion')), findsOneWidget);
    await _pulsar(tester, find.text('Teléfonos de ayuda'));
    expect(find.text('pantalla de ayuda'), findsOneWidget);
  });

  testWidgets('un error normal no enseña la tarjeta de crisis, pero sí el acceso a Ayuda', (tester) async {
    final p = await _abrir(tester);
    p.api.errores.add(errorApi);
    await _escribirYEnviar(tester, _preguntaDemo);
    expect(find.byKey(const Key('tarjeta-crisis-sin-conexion')), findsNothing);
    expect(find.text('Teléfonos de ayuda'), findsOneWidget);
  });

  testWidgets('solo se subrayan los términos que están en el Glosario', (tester) async {
    await _abrir(tester);
    await _escribirYEnviar(tester, _preguntaDemo);
    final texto = tester.widget<TextoConTerminos>(find.byType(TextoConTerminos));
    // El mock manda «responsabilidad penal» y «Fiscalía de Menores»; este glosario solo tiene la primera.
    expect(texto.terminos, ['responsabilidad penal']);
  });

  testWidgets('con un papel, los ejemplos son de ese papel; al quitarlo vuelven los generales', (tester) async {
    await _abrir(tester, situacion: RolProceso.testigo);
    for (final ejemplo in ejemplosPorRol[RolProceso.testigo]!) {
      await _desplazarHasta(tester, find.text(ejemplo.texto));
      expect(find.text(ejemplo.texto), findsOneWidget);
    }
    expect(find.text(_preguntaDemo, skipOffstage: false), findsNothing);

    await tester.tap(find.byTooltip('Quitar y preguntar en general'));
    await tester.pumpAndSettle();
    await _desplazarHasta(tester, find.text(_preguntaDemo));
    expect(find.text(_preguntaDemo), findsOneWidget);
  });

  testWidgets('el chip de investigado usa el mismo nombre que Mi situación y no se corta', (tester) async {
    await _abrir(tester, situacion: RolProceso.investigado, escalaTexto: 1.3 * 1.3, tamano: const Size(360, 740));
    expect(find.text('Preguntas como investigado o investigada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('los ejemplos nunca cuentan hechos en primera persona', (tester) async {
    final todos = [...ejemplos, for (final lista in ejemplosPorRol.values) ...lista];
    for (final ejemplo in todos) {
      expect(ejemplo.texto, isNot(contains('Me acosan')));
      expect(ejemplo.texto, endsWith('?'));
    }
  });

  testWidgets('el teclado no aprende lo que se escribe', (tester) async {
    await _abrir(tester);
    expect(tester.widget<TextField>(find.byKey(_campo)).enableIMEPersonalizedLearning, isFalse);
  });

  testWidgets('«Sin voz» calla la respuesta que se está leyendo', (tester) async {
    final tts = FakeTts(terminarAlInstante: false);
    await _abrir(tester, tts: tts);
    await _escribirYEnviar(tester, _preguntaDemo);
    await tester.tap(find.text('Escuchar'));
    await tester.pump();
    expect(find.text('Parar'), findsOneWidget);
    final paradas = tts.paradas;

    await tester.tap(find.byTooltip('Las respuestas se leen en voz alta'));
    await tester.pumpAndSettle();
    expect(tts.paradas, greaterThan(paradas));
    expect(find.text('Escuchar'), findsOneWidget);
  });

  testWidgets('una pregunta inicial queda escrita en el campo, sin enviarse', (tester) async {
    final p = await _abrir(tester, preguntaInicial: '¿Qué significa «xyz»?');
    expect(_textoDelCampo(tester), '¿Qué significa «xyz»?');
    expect(p.api.peticiones, isEmpty);
  });

  testWidgets('desde una respuesta: término → Glosario → «Pregúntala» vuelve a la misma conversación', (tester) async {
    tester.view.physicalSize = const Size(412, 915) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    final api = ApiGrabadora();
    await tester.pumpWidget(
      ProviderScope(
        overrides: await overridesDePrueba(api: api, stt: FakeStt(), tts: FakeTts()),
        child: const TuTurnoApp(),
      ),
    );
    await tester.pumpAndSettle();
    final contenedor = ProviderScope.containerOf(tester.element(find.byType(TuTurnoApp)));
    unawaited(contenedor.read(routerProvider).push('/pregunta?situacion=testigo'));
    await tester.pumpAndSettle();
    await _escribirYEnviar(tester, _preguntaDemo);

    await tester.tapOnText(find.textRange.ofSubstring('responsabilidad penal'));
    await tester.pumpAndSettle();
    // Coincide con un término: se abre su hoja.
    expect(find.byType(BottomSheet), findsOneWidget);
    await _pulsar(tester, find.text('¿Te queda alguna duda? Pregúntala'));

    expect(find.byType(PreguntaScreen, skipOffstage: false), findsOneWidget);
    expect(find.text('Preguntas como testigo'), findsOneWidget);
    await _desplazarHasta(tester, find.text(_preguntaDemo));
    expect(find.text(_preguntaDemo), findsOneWidget);
  });

  testWidgets('la ruta /pregunta?situacion=testigo de la app abre esta pantalla con el chip', (tester) async {
    final api = ApiGrabadora();
    await tester.pumpWidget(
      ProviderScope(
        overrides: await overridesDePrueba(api: api, stt: FakeStt(), tts: FakeTts()),
        child: const TuTurnoApp(),
      ),
    );
    await tester.pumpAndSettle();
    final contenedor = ProviderScope.containerOf(tester.element(find.byType(TuTurnoApp)));
    unawaited(contenedor.read(routerProvider).push('/pregunta?situacion=testigo'));
    await tester.pumpAndSettle();

    expect(find.byType(PreguntaScreen), findsOneWidget);
    expect(find.text('Preguntas como testigo'), findsOneWidget);
  });

  testWidgets('Tut responde: pensando mientras llega la respuesta y serio después, también en crisis y hechos', (
    tester,
  ) async {
    final p = await _abrir(tester);
    // Antes de preguntar, Tut espera quieto en el ticket de presentación.
    expect(_expresionesDeTut(tester), everyElement(ExpresionTut.neutral));
    expect(tester.widgetList<MascotaTut>(find.byType(MascotaTut)).every((tut) => !tut.animada), isTrue);

    p.api.pausa = Completer<void>();
    await tester.enterText(find.byKey(_campo), 'A veces pienso que no quiero vivir');
    await tester.pump();
    await tester.tap(find.byKey(_enviar));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final esperando = find.descendant(of: find.byType(IndicadorEscribiendo), matching: find.byType(MascotaTut));
    expect(tester.widget<MascotaTut>(esperando).expresion, ExpresionTut.pensando);

    p.api.pausa!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tarjeta-crisis')), findsOneWidget);
    // Nunca de fiesta (ni triste) después de una crisis o de unos hechos: serio y quieto.
    expect(_expresionesDeTut(tester), everyElement(ExpresionTut.neutral));

    await _escribirYEnviar(tester, 'Me pegaron en el recreo');
    expect(_expresionesDeTut(tester), everyElement(ExpresionTut.neutral));
    expect(tester.widgetList<MascotaTut>(find.byType(MascotaTut)).every((tut) => !tut.animada), isTrue);
  });

  testWidgets('la respuesta es un ticket: el texto arriba y, en el talón, las fuentes y «Escuchar»', (tester) async {
    await _abrir(tester);
    await _escribirYEnviar(tester, _preguntaDemo);

    final ticket = find.byKey(const Key('ticket-respuesta'));
    expect(ticket, findsOneWidget);
    expect(tester.widget(ticket), isA<TicketVertical>());
    expect(find.descendant(of: ticket, matching: find.byType(TextoConTerminos)), findsOneWidget);
    expect(find.descendant(of: ticket, matching: find.byType(FuenteChip)), findsOneWidget);
    expect(find.descendant(of: ticket, matching: find.text('Escuchar')), findsOneWidget);
    // El talón (fuentes y altavoz) va debajo del texto.
    final texto = tester.getRect(find.descendant(of: ticket, matching: find.byType(TextoConTerminos)));
    expect(tester.getTopLeft(find.byType(FuenteChip)).dy, greaterThan(texto.bottom));
    // Las sugerencias también son tickets que preguntan al tocarlos.
    expect(find.widgetWithText(TicketPregunta, '¿Qué pasa a partir de los 14?'), findsOneWidget);
  });

  testWidgets('en tema oscuro cumple las pautas de accesibilidad (zonas táctiles, etiquetas y contraste)', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    await _abrir(tester, brillo: Brightness.dark);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await _escribirYEnviar(tester, _preguntaDemo);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantica.dispose();
  });

  testWidgets('con «reducir animaciones», la respuesta llega sin animaciones pendientes', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _abrir(tester);
    await tester.enterText(find.byKey(_campo), _preguntaDemo);
    await tester.pump();
    await tester.tap(find.byKey(_enviar));
    // La respuesta del mock llega en el siguiente turno; con «reducir animaciones», sin entradas ni rebotes.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump();
    expect(find.byKey(const Key('ticket-respuesta')), findsOneWidget);
    // Un fotograma para que acaben los cambios de duración cero; después, nada se mueve (ni Tut ni el micrófono).
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
