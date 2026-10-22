import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/api/models.dart';
import 'package:tuturno/core/mis_preguntas.dart';
import 'package:tuturno/features/mis_preguntas/mis_preguntas_screen.dart';
import 'package:tuturno/features/pasos/pasos.dart';
import 'package:tuturno/features/pregunta/pregunta_screen.dart';
import 'package:tuturno/features/situacion/mi_ticket.dart';
import 'package:tuturno/features/situacion/situacion_screen.dart' show SelloParaTi;
import 'package:tuturno/features/situacion/ticket_screen.dart';
import 'package:tuturno/features/situacion/widgets/derechos.dart' show CartaDerecho;
import 'package:tuturno/features/situacion/widgets/mi_dia.dart';
import 'package:tuturno/widgets/justicia/expediente_caratula.dart';

import 'ayudantes.dart';

// «Mi situación» hecha a medida: con los tickets de Lucía, Sergio y Sara se ve una guía distinta para cada uno (el
// saludo, las notas «Para ti», los pasos de su caso, sus derechos, lo que les preocupa y su día).

/// Abre el paso cuyo nombre es [nombre] si está cerrado.
Future<void> _abrirPaso(WidgetTester tester, String nombre) async {
  final cabecera = find.bySemanticsLabel(RegExp('^Paso \\d+ de \\d+: ${RegExp.escape(nombre)}'));
  await tester.ensureVisible(cabecera);
  await tester.pumpAndSettle();
  if (!isSemantics(isExpanded: true).matches(tester.getSemantics(cabecera), {})) {
    await tester.tap(cabecera);
    await tester.pumpAndSettle();
  }
}

void main() {
  group('Lucía (11, víctima, durante, con ejemplos, cita en 2 días)', () {
    testWidgets('la carátula marca «Durante» y lleva el sello «PARA TI»; el saludo es suyo', (tester) async {
      final router = await arrancarSituacion(tester, preferencias: perfilLucia());
      await abrir(tester, router, '/situacion/victima');

      expect(find.byType(ExpedienteCaratula), findsOneWidget);
      expect(find.text('Durante · Estás aquí'), findsOneWidget);
      expect(find.byType(SelloParaTi), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Hecha para ti')), findsOneWidget);
      expect(find.text('Tu cita: sábado 24 de octubre'), findsOneWidget);
      expect(find.textContaining('para alguien de 11 años'), findsOneWidget);
      expect(find.text('Con una persona de confianza'), findsOneWidget);
      // La nota «Por tu edad» (y las pegatinas de sus derechos), con su fuente.
      expect(find.text('Por tu edad'), findsWidgets);
      expect(find.textContaining('Con 11 años, en un caso de violencia'), findsOneWidget);
    });

    testWidgets('su paso de «Durante» le dice lo de su edad, el ejemplo de Lucía y con quién irá', (tester) async {
      final router = await arrancarSituacion(tester, preferencias: perfilLucia());
      await abrir(tester, router, '/situacion/victima');
      expect(find.bySemanticsLabel('Durante. Estás aquí'), findsOneWidget);

      await _abrirPaso(tester, 'Tu declaración');
      expect(find.text('Para ti'), findsOneWidget);
      expect(find.textContaining('Como tienes 11 años'), findsOneWidget);
      expect(find.textContaining('Por ejemplo: '), findsWidgets);
      expect(find.text('Tú irás con una persona de confianza'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is RetratoPersonaje && w.id == 'ana'), findsOneWidget);
      expect(find.text('Qué llevar'), findsOneWidget);
      expect(find.text('Palabras que oirás'), findsOneWidget);
      expect(find.text('Sala Gesell'), findsWidgets);
    });

    testWidgets('sus derechos empiezan por los de su edad y lo que le preocupa; sus preocupaciones, respondidas', (
      tester,
    ) async {
      final router = await arrancarSituacion(tester, preferencias: perfilLucia());
      await abrir(tester, router, '/situacion/victima');

      final primero = find.text('Que tu entrevista se grabe para el juicio');
      await tester.ensureVisible(primero);
      expect(primero, findsOneWidget);
      expect(find.text('Por tu edad'), findsWidgets);
      expect(find.text('Por lo que te preocupa'), findsWidgets);

      expect(find.text('Ver a la persona'), findsWidgets);
      expect(find.textContaining('se evita que la veas cara a cara: se puede usar un cristal'), findsOneWidget);
      expect(find.text('Faltan 2 días'), findsOneWidget);
    });
  });

  group('Sergio (13, víctima, antes, paso a paso, su cita es hoy)', () {
    testWidgets('modo día arriba: «Hoy es tu día» con la hora y lo que puede pedir hoy', (tester) async {
      final router = await arrancarSituacion(tester, preferencias: perfilSergio());
      await abrir(tester, router, '/situacion/victima');

      expect(find.byType(PanelModoDia), findsOneWidget);
      // Con un espacio duro antes del punto (la hora no se queda suelta) y la hora en la letra de las cifras.
      expect(find.text('Hoy es tu día\u00A0· 12:30'), findsOneWidget);
      expect(find.text('Un descanso si lo necesitas'), findsWidgets);
      expect(find.text('Antes · Estás aquí'), findsOneWidget);
    });

    testWidgets('paso a paso: el primer paso de su momento ya está abierto y lleva «Siguiente paso»', (tester) async {
      final router = await arrancarSituacion(tester, preferencias: perfilSergio());
      await abrir(tester, router, '/situacion/victima');

      final primero = find.bySemanticsLabel(RegExp(r'^Paso 1 de 7: Se pide ayuda'));
      expect(tester.getSemantics(primero), isSemantics(isExpanded: true));
      final siguiente = find.text('Siguiente paso: Quién lleva tu caso');
      await tocar(tester, siguiente);
      expect(tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Paso 2 de 7'))), isSemantics(isExpanded: true));
    });

    testWidgets('«Pregúntaselo a TuTurno» abre Pregunta como víctima con la duda del paso ya escrita', (tester) async {
      final router = await arrancarSituacion(tester, preferencias: perfilSergio());
      await abrir(tester, router, '/situacion/victima');
      await tocar(tester, find.text('Pregúntaselo a TuTurno').first);
      await tester.pump(const Duration(milliseconds: 600));

      final pregunta = tester.widget<PreguntaScreen>(find.byType(PreguntaScreen));
      expect(pregunta.situacion, RolProceso.victima);
      expect(pregunta.preguntaInicial, '¿Qué derechos me tienen que explicar cuando pido ayuda?');
      expect(router.state.uri.queryParameters['q'], '¿Qué derechos me tienen que explicar cuando pido ayuda?');
    });
  });

  group('Sara (15, víctima, antes, corto, le preocupan las redes)', () {
    testWidgets('corto: «Leer todo» en los pasos y en los derechos; lo de las redes entre los primeros', (
      tester,
    ) async {
      final router = await arrancarSituacion(tester, preferencias: perfilSara());
      await abrir(tester, router, '/situacion/victima');
      // Sara está al principio: quitar las imágenes, el 017 y la denuncia.
      expect(find.text('Antes · Estás aquí'), findsOneWidget);
      expect(
        find.textContaining('Con 15 años puedes pedir tú a la Agencia Española de Protección de Datos'),
        findsOneWidget,
      );

      final canal = find.text('Pedir que quiten fotos o vídeos tuyos de internet');
      await tester.ensureVisible(canal);
      expect(canal, findsOneWidget);
      // En corto, la carta enseña la primera frase y «Leer todo» despliega el resto.
      expect(find.textContaining('Este canal no sirve para WhatsApp'), findsNothing);
      expect(find.textContaining('Con 14 a 17 años, puedes contactar tú directamente'), findsOneWidget);
      final carta = find.ancestor(of: canal, matching: find.byType(CartaDerecho));
      final leerTodo = find.descendant(of: carta, matching: find.text('Leer todo'));
      expect(leerTodo, findsOneWidget);
      await tocar(tester, leerTodo);
      expect(find.textContaining('Este canal no sirve para WhatsApp'), findsOneWidget);

      await _abrirPaso(tester, 'La decisión y lo que viene después');
      expect(find.text('Leer todo'), findsWidgets);
    });
  });

  group('interacción', () {
    testWidgets('elegir una preocupación desde la guía la guarda y la responde al momento', (tester) async {
      final router = await arrancarSituacion(tester, preferencias: perfilLucia());
      await abrir(tester, router, '/situacion/victima');
      final familia = find.widgetWithText(FilterChip, 'Mi familia');
      await tocar(tester, familia);

      expect(contenedor(tester).read(miTicketProvider).preocupaciones, contains(Preocupacion.familia));
      expect(find.textContaining('el fiscal pedirá que te represente un defensor judicial'), findsOneWidget);
    });

    testWidgets('apuntar un derecho lo lleva a «Mis preguntas» con «De: Tus derechos», y el botón cuenta', (
      tester,
    ) async {
      final router = await arrancarSituacion(tester, preferencias: perfilLucia());
      await abrir(tester, router, '/situacion/victima');
      final carta = find.ancestor(
        of: find.text('Que tu entrevista se grabe para el juicio'),
        matching: find.byType(Row),
      );
      await tocar(tester, find.descendant(of: carta.first, matching: find.byTooltip('Apuntar en Mis preguntas')));

      final apunte = contenedor(tester).read(misPreguntasProvider).single;
      expect(apunte.origen, 'Tus derechos');
      expect(apunte.tipo, TipoApunte.pedir);
      expect(apunte.fuentes, ['LECrim, art. 449 ter', 'LECrim, art. 703 bis']);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await tocar(tester, find.text('Mis preguntas (1)'));
      expect(find.byType(MisPreguntasScreen), findsOneWidget);
    });

    testWidgets('«Cambiar mi ticket» abre «Tu ticket»', (tester) async {
      final router = await arrancarSituacion(tester, preferencias: perfilLucia());
      await abrir(tester, router, '/situacion/victima');
      await tocar(tester, find.text('Cambiar mi ticket'));
      expect(find.byType(TuTicketScreen), findsOneWidget);
    });

    testWidgets('el índice baja a cada sección', (tester) async {
      final router = await arrancarSituacion(tester, preferencias: perfilLucia());
      await abrir(tester, router, '/situacion/victima');
      await tocar(tester, find.widgetWithText(ActionChip, 'Tu día'));
      final dia = tester.getRect(find.textContaining('TU DÍA'));
      expect(dia.top, inInclusiveRange(0, 300));
    });

    testWidgets('mirando otro papel, no se le dice dónde está y se le ofrece volver al suyo', (tester) async {
      final router = await arrancarSituacion(tester, preferencias: perfilLucia());
      await abrir(tester, router, '/situacion/testigo');
      expect(find.text('Estás aquí'), findsNothing);
      expect(find.textContaining('Estás mirando otro camino: «Testigo».'), findsOneWidget);
      // Mirando otro camino, la guía no es «para ti»: sin sello.
      expect(find.byType(SelloParaTi), findsNothing);
      await tocar(tester, find.text('Ver mi camino: Víctima'));
      expect(router.state.uri.path, '/situacion/victima');
    });

    testWidgets('sin ticket, la guía es general e invita a rellenarlo; sin sello', (tester) async {
      final router = await arrancarSituacion(tester);
      await abrir(tester, router, '/situacion/victima');
      expect(find.text('Esta es una guía general'), findsOneWidget);
      expect(find.text('Rellenar mi ticket'), findsOneWidget);
      expect(find.byType(SelloParaTi), findsNothing);
      expect(find.text('Estás aquí'), findsNothing);
    });

    testWidgets('sin el contenido nuevo (ni itinerarios ni glosario), la pantalla sale igual y lo dice con calma', (
      tester,
    ) async {
      final router = await arrancarSituacion(tester, preferencias: perfilLucia(), repo: repoVacio());
      await abrir(tester, router, '/situacion/victima');
      expect(tester.takeException(), isNull);
      expect(find.text(textoSinPasos), findsOneWidget);
      expect(find.textContaining('Estoy preparando tus derechos'), findsOneWidget);
    });
  });

  for (final brillo in Brightness.values) {
    testWidgets('con el ticket de Sergio (modo día) cumple las pautas de accesibilidad en ${brillo.name}', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = brillo;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final semantica = tester.ensureSemantics();
      final router = await arrancarSituacion(tester, preferencias: perfilSergio());
      await abrir(tester, router, '/situacion/victima');
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      // Y más abajo: derechos, preocupaciones y tu día.
      await tester.ensureVisible(find.textContaining('TUS DERECHOS'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await tester.ensureVisible(find.textContaining('TU DÍA'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantica.dispose();
    });
  }

  testWidgets('con «reducir animaciones» y un ticket completo, la guía sale quieta', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final router = await arrancarSituacion(tester, preferencias: perfilLucia());
    router.push('/situacion/victima');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.byType(ExpedienteCaratula), findsOneWidget);
    expect(find.text('Durante · Estás aquí'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('con letra a 1,3 en un móvil pequeño y en oscuro, nada se desborda (los tres perfiles)', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    for (final perfil in [perfilLucia(), perfilSergio(), perfilSara()]) {
      final router = await arrancarSituacion(tester, preferencias: perfil, tamano: const Size(360, 640));
      await abrir(tester, router, '/situacion/victima');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Se vuelve a montar la app para el siguiente perfil.
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
