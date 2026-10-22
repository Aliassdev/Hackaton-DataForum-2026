import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/app.dart';
import 'package:tuturno/core/api/models.dart';
import 'package:tuturno/core/entrada.dart' show EntradaNotifier;
import 'package:tuturno/core/progreso.dart';
import 'package:tuturno/features/ajustes/ajustes_screen.dart';
import 'package:tuturno/features/aprende/aprende_screen.dart';
import 'package:tuturno/features/ayuda/ayuda_screen.dart';
import 'package:tuturno/features/glosario/glosario_screen.dart';
import 'package:tuturno/features/inicio/bienvenida.dart';
import 'package:tuturno/features/inicio/tu_camino.dart' show TuCamino;
import 'package:tuturno/features/inicio/turno_del_dia.dart';
import 'package:tuturno/features/inicio/widgets/saludo.dart';
import 'package:tuturno/features/inicio/widgets/ticket_del_dia.dart';
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/ayuda_button.dart';
import 'package:tuturno/widgets/fuente_chip.dart';
import 'package:tuturno/widgets/iconos/iconos.dart';
import 'package:tuturno/widgets/justicia/fondo_justicia.dart';
import 'package:tuturno/widgets/marca/marca.dart';
import 'package:tuturno/widgets/modulos.dart';
import 'package:tuturno/widgets/movimiento/movimiento.dart';
import 'package:tuturno/features/juego/juego_screen.dart';
import 'package:tuturno/features/pregunta/pregunta_screen.dart';
import 'package:tuturno/features/situacion/papel.dart';
import 'package:tuturno/features/situacion/situacion_screen.dart';

import 'helpers.dart';

/// Jueves 22/10/2026 por la tarde: ese día la misión es «Completa una lección de Aprende».
final _tarde = DateTime(2026, 10, 22, 17, 30);

ProviderContainer _contenedor(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(TuTurnoApp)));

String _progreso(Progreso progreso) => jsonEncode(progreso.toJson());

/// El ticket de Pregunta guardado (lib/core/entrada.dart), con los valores de su `valor`.
Map<String, Object> _entrada({String? rol, String? fase}) => {
  EntradaNotifier.clave: jsonEncode({'edad': 13, 'procedimiento': 'penal', 'rol': rol, 'fase': fase}),
};

/// Textos de privacidad que no son ciertos hoy (auditoría P1-4).
final _seBorra = RegExp(r'se borra|borramos|lo que hablamos', caseSensitive: false);

/// Palabras de pérdida, que la racha amable no usa nunca.
final _perder = RegExp(r'perd|pierd', caseSensitive: false);

/// docs/MARCO_LEGAL.md, o null si no está (por ejemplo, si solo se copia app/). Con `DOCS=<carpeta>`, esa copia.
String? _marcoLegal() {
  final carpeta = Platform.environment['DOCS'];
  final rutas = [if (carpeta != null) '$carpeta/MARCO_LEGAL.md', '../docs/MARCO_LEGAL.md', 'docs/MARCO_LEGAL.md'];
  return rutas.map(File.new).where((f) => f.existsSync()).firstOrNull?.readAsStringSync();
}

void main() {
  group('Bienvenida', () {
    testWidgets('sale la primera vez, con el logotipo, Tut y Ayuda visible, y lleva al inicio', (tester) async {
      await arrancarApp(tester, bienvenidaVista: false);

      expect(find.byType(IntroMarca), findsOneWidget);
      expect(find.text('¿Qué es TuTurno?'), findsOneWidget);
      expect(find.byTooltip('Teléfonos de ayuda'), findsOneWidget);
      expect(find.byTooltip('Glosario'), findsOneWidget);
      expect(find.byType(TarjetaModulo), findsNothing);
      // Al acabar de pegarse el logotipo, Tut se asoma con cara amable.
      expect(tester.widget<MascotaTut>(find.byType(MascotaTut)).expresion, ExpresionTut.feliz);

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Antes de empezar'), findsOneWidget);
      expect(find.text(mensajeIA), findsOneWidget);
      expect(find.byTooltip('Teléfonos de ayuda'), findsOneWidget);

      await tester.tap(find.text('Empezar'));
      await tester.pumpAndSettle();
      expect(find.byType(TarjetaModulo), findsNWidgets(3));
      expect(find.byType(TicketDelDia), findsOneWidget);
      expect(find.text('¿Qué es TuTurno?'), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('bienvenida_vista'), isTrue);
    });

    testWidgets('la segunda pantalla dice exactamente lo que acordamos (sección 4.1)', (tester) async {
      // Solo lo que es cierto hoy (auditoría P1-4): nada de que lo que hablamos «se borra».
      expect(mensajeIA, 'Soy una IA. No te pido tu nombre ni crear una cuenta. Si estás en peligro, pulsa Ayuda.');
      await arrancarApp(tester, bienvenidaVista: false);
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text(mensajeIA), findsOneWidget);
      // Tut acompaña con cara tranquila (no se ríe al hablar de peligro).
      final tut = tester.widget<MascotaTut>(find.byType(MascotaTut).last);
      expect(tut.expresion, ExpresionTut.neutral);
    });

    testWidgets('se puede pasar de pantalla deslizando y volver con atrás', (tester) async {
      await arrancarApp(tester, bienvenidaVista: false);

      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Antes de empezar'), findsOneWidget);

      // El botón atrás de Android vuelve a la primera pantalla en vez de salir.
      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handled, isTrue);
      expect(find.text('¿Qué es TuTurno?'), findsOneWidget);
      // La presentación del logotipo no se repite al volver.
      expect(find.byType(IntroMarca), findsOneWidget);
    });

    testWidgets('al empezar, la bienvenida se arranca y no se puede tocar mientras se va', (tester) async {
      await arrancarApp(tester, bienvenidaVista: false);
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Empezar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Bienvenida), findsOneWidget);
      expect(find.byType(TicketDelDia), findsOneWidget);
      final bloqueos = tester.widgetList<IgnorePointer>(
        find.ancestor(of: find.byType(Bienvenida), matching: find.byType(IgnorePointer)),
      );
      expect(bloqueos.any((b) => b.ignoring), isTrue);

      await tester.pumpAndSettle();
      expect(find.byType(Bienvenida), findsNothing);
    });

    testWidgets('el botón de Ayuda funciona durante la bienvenida', (tester) async {
      await arrancarApp(tester, bienvenidaVista: false);
      await tester.tap(find.byTooltip('Teléfonos de ayuda'));
      await tester.pumpAndSettle();
      expect(find.byType(AyudaScreen), findsOneWidget);
    });

    testWidgets('no vuelve a salir si ya se vio', (tester) async {
      await arrancarApp(tester);
      expect(find.text('¿Qué es TuTurno?'), findsNothing);
      expect(find.byType(TarjetaModulo), findsNWidgets(3));
    });

    testWidgets('la primera pantalla enseña el palacio en color debajo del logotipo, con tu turno en el panel', (
      tester,
    ) async {
      await arrancarApp(tester, bienvenidaVista: false);
      final palacio = find.byType(FondoJusticia);
      expect(palacio, findsOneWidget);
      expect(tester.widget<FondoJusticia>(palacio).variante, VarianteFondoJusticia.color);
      expect(tester.getTopLeft(palacio).dy, greaterThan(tester.getBottomLeft(find.byType(IntroMarca)).dy));
      expect(tester.getBottomLeft(palacio).dy, lessThan(tester.getTopLeft(find.text('¿Qué es TuTurno?')).dy));
      // De lado a lado: se sale del margen de la página.
      expect(tester.getSize(palacio).width, movil.width);
      // El panel de encima de la puerta gira hasta tu número de turno (el 1, el primer día).
      final panel = tester.widget<PanelFlip>(find.descendant(of: palacio, matching: find.byType(PanelFlip)));
      expect(panel.texto, '01');
      expect(panel.fondo, ColoresMarca.papel);
      expect(panel.color, ColoresMarca.azulNoche);
    });

    testWidgets('dice que tienes derecho a que te escuchen, con su fuente: LO 1/1996, art. 9.1', (tester) async {
      await arrancarApp(tester, bienvenidaVista: false);
      expect(
        textoDerechoASerOido,
        'Cuando algo te afecta, tienes derecho a que te escuchen, tengas la edad que tengas. TuTurno te ayuda a '
        'entender para que puedas hablar en tu turno.',
      );
      expect(find.text(textoDerechoASerOido), findsOneWidget);
      final chip = tester.widget<FuenteChip>(find.byType(FuenteChip));
      expect(chip.fuente.norma, 'LO 1/1996');
      expect(chip.fuente.articulo, '9.1');
      expect(find.text('LO 1/1996 · art. 9.1'), findsOneWidget);

      await pulsar(tester, find.byType(FuenteChip));
      expect(find.text('De dónde sale la respuesta'), findsOneWidget);
      expect(find.text('Ley de protección jurídica del menor'), findsOneWidget);
    });

    test('la fuente del derecho a que te escuchen está en docs/MARCO_LEGAL.md', () {
      final marco = _marcoLegal();
      if (marco == null) {
        markTestSkipped('No está docs/MARCO_LEGAL.md');
        return;
      }
      expect(marco, contains('### LO 1/1996, art. 9.1'));
      expect(marco, contains('sin discriminación alguna por edad'));
    });

    testWidgets('en un móvil pequeño, un degradado abajo avisa de que hay más y se va al llegar al final', (
      tester,
    ) async {
      await arrancarApp(tester, bienvenidaVista: false, tamano: const Size(360, 640));
      double opacidad() =>
          tester.widget<AnimatedOpacity>(find.byKey(const ValueKey('degradado-hay-mas')).first).opacity;
      expect(opacidad(), 1);
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(opacidad(), 0);
      expect(find.text(Modulo.pregunta.titulo), findsOneWidget);
    });
  });

  group('Textos ciertos', () {
    testWidgets('ningún texto de la bienvenida ni del inicio dice que lo que hablamos se borra', (tester) async {
      await arrancarApp(tester, bienvenidaVista: false);
      expect(find.textContaining(_seBorra), findsNothing, reason: 'bienvenida 1');
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.textContaining(_seBorra), findsNothing, reason: 'bienvenida 2');
      expect(find.text(textoSinCuenta), findsOneWidget);
      expect(
        textoSinCuenta,
        'No hace falta registrarte. Tu móvil no guarda la conversación de Pregunta: al salir, desaparece de la pantalla.',
      );
      await tester.tap(find.text('Empezar'));
      await tester.pumpAndSettle();
      // El inicio entero (la portada se construye completa: es un SingleChildScrollView).
      expect(find.textContaining(_seBorra), findsNothing, reason: 'inicio');
      expect(find.text(mensajeIA), findsOneWidget);
    });
  });

  group('Inicio', () {
    testWidgets('la barra lleva el logotipo y el botón de Ayuda rojo', (tester) async {
      await arrancarApp(tester);

      final barra = find.byType(AppBar);
      expect(find.descendant(of: barra, matching: find.byType(LogoTuTurno)), findsOneWidget);
      expect(find.bySemanticsLabel('TuTurno'), findsWidgets);

      final contexto = tester.element(find.byType(AyudaButton));
      final boton = tester.widget<FilledButton>(
        find.descendant(of: find.byType(AyudaButton), matching: find.byType(FilledButton)),
      );
      expect(boton.style?.backgroundColor?.resolve({}), contexto.colores.ayuda);
      expect(boton.style?.foregroundColor?.resolve({}), Colors.white);
      expect(find.descendant(of: find.byType(AyudaButton), matching: find.text('Ayuda')), findsOneWidget);
    });

    testWidgets('las tres tarjetas de módulo navegan', (tester) async {
      final router = await arrancarApp(tester);

      // (Con la letra de los tests, más ancha que la real, algunas tarjetas quedan debajo: pulsar() desplaza.)
      await pulsar(tester, find.text('Vive el caso'));
      expect(find.byType(JuegoScreen), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();

      await pulsar(tester, find.text('Aprende'));
      expect(find.byType(AprendeScreen), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();

      await pulsar(tester, find.text(Modulo.pregunta.tituloEnTarjeta));
      await esperarTransicion(tester);
      expect(find.byType(PreguntaScreen), findsOneWidget);
    });

    testWidgets('los módulos llevan sus iconos propios', (tester) async {
      await arrancarApp(tester);
      for (final modulo in Modulo.values) {
        final tarjeta = find.widgetWithText(TarjetaModulo, modulo.tituloEnTarjeta);
        final icono = tester.widget<IconoTuTurno>(find.descendant(of: tarjeta, matching: find.byType(IconoTuTurno)));
        expect(icono.icono, modulo.tuIcono, reason: modulo.tituloEnTarjeta);
      }
    });

    testWidgets('el ticket del día lleva a su misión y, al cumplirla, cae el sello una sola vez', (tester) async {
      final router = await arrancarApp(tester, overrides: [relojProvider.overrideWithValue(() => _tarde)]);

      expect(find.text('¡Es tu turno!'), findsOneWidget);
      expect(find.textContaining('Completa una lección de Aprende'), findsOneWidget);
      expect(tester.widget<SelloAnimado>(find.byType(SelloAnimado)).estampado, isFalse);
      expect(_contenedor(tester).read(turnoDelDiaProvider).numero, 1);

      await tester.tap(find.text('¡Es tu turno!'));
      await tester.pumpAndSettle();
      expect(find.byType(AprendeScreen), findsOneWidget);

      // La lección se completa en Aprende; el sello espera a que se vuelva a ver el inicio.
      await _contenedor(tester).read(progresoProvider.notifier).completarLeccion('U1-L1');
      await tester.pump();
      expect(_contenedor(tester).read(turnoDelDiaProvider).celebrada, isFalse);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('¡Cumplido!'), findsOneWidget);
      expect(find.textContaining('Lección completada'), findsOneWidget);
      expect(tester.widget<SelloAnimado>(find.byType(SelloAnimado)).estampado, isTrue);
      expect(_contenedor(tester).read(turnoDelDiaProvider).celebrada, isTrue);
    });

    testWidgets('si la misión ya estaba cumplida y celebrada, el sello aparece puesto sin animarse', (tester) async {
      await arrancarApp(
        tester,
        preferencias: {
          'progreso': _progreso(Progreso(racha: 1, ultimoDiaConLeccion: DateTime(2026, 10, 22))),
          TurnoDelDiaNotifier.clave: RegistroTurno(
            dia: DateTime(2026, 10, 22),
            mision: Mision.leccion,
            base: const Recuento(),
            celebrada: true,
          ).codificar(),
        },
        overrides: [relojProvider.overrideWithValue(() => _tarde)],
      );
      final sello = tester.widget<SelloAnimado>(find.byType(SelloAnimado));
      expect(sello.estampado, isTrue);
      expect(sello.animar, isFalse);
    });

    testWidgets('el pase enseña la racha y el nivel, y explica cómo se ganan los puntos', (tester) async {
      await arrancarApp(
        tester,
        preferencias: {'progreso': _progreso(Progreso(xp: 140, racha: 3, ultimoDiaConLeccion: DateTime(2026, 10, 21)))},
        overrides: [relojProvider.overrideWithValue(() => _tarde)],
      );
      final pase = find.byType(PaseProgreso);
      expect(find.descendant(of: pase, matching: find.text('3')), findsOneWidget);
      expect(find.descendant(of: pase, matching: find.text('días')), findsOneWidget);
      expect(find.descendant(of: pase, matching: find.textContaining('Detective de derechos')), findsOneWidget);
      expect(find.descendant(of: pase, matching: find.text('140 XP')), findsOneWidget);

      await tester.tap(pase);
      await tester.pumpAndSettle();
      expect(find.text('Tu progreso'), findsOneWidget);
      expect(find.text('Los niveles'), findsOneWidget);
      expect(find.textContaining('Te faltan 80'), findsOneWidget);
      expect(find.textContaining('no pasa nada'), findsOneWidget);
    });

    testWidgets('una racha que ya no se puede alargar no se enseña (sin reñir)', (tester) async {
      await arrancarApp(
        tester,
        preferencias: {'progreso': _progreso(Progreso(xp: 40, racha: 5, ultimoDiaConLeccion: DateTime(2026, 10, 18)))},
        overrides: [relojProvider.overrideWithValue(() => _tarde)],
      );
      final pase = find.byType(PaseProgreso);
      // Racha amable: en vez de «0 días», una invitación.
      expect(find.descendant(of: pase, matching: find.text(PaseProgreso.empiezaHoy)), findsOneWidget);
      expect(find.descendant(of: pase, matching: find.text('0')), findsNothing);
      expect(find.descendant(of: pase, matching: find.text('5')), findsNothing);
    });

    testWidgets('Tut saluda y, si le tocas, se sorprende y dice otra cosa', (tester) async {
      await arrancarApp(tester, overrides: [relojProvider.overrideWithValue(() => _tarde)]);
      expect(find.text('¡Buenas tardes!'), findsOneWidget);
      MascotaTut tut() => tester.widget<MascotaTut>(find.byType(MascotaTut));
      expect(tut().expresion, ExpresionTut.feliz);

      await tester.tap(find.byType(MascotaTut));
      await tester.pump();
      expect(tut().expresion, ExpresionTut.sorprendida);
      expect(find.text(SaludoTut.frasesAlTocar.first), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(tut().expresion, ExpresionTut.feliz);
      await tester.pumpAndSettle();
    });

    testWidgets('Mi situación abre el selector de papel y lleva a /situacion/<rol>', (tester) async {
      await arrancarApp(tester);

      await pulsar(tester, find.text('Mi situación'));
      expect(find.text('¿Qué papel tienes en el caso?'), findsOneWidget);
      expect(find.text('Testigo'), findsOneWidget);
      expect(find.text('Víctima'), findsOneWidget);
      expect(find.text('Investigado o investigada'), findsOneWidget);
      expect(find.textContaining('nunca te preguntamos qué ha pasado'), findsOneWidget);

      await tester.tap(find.text('Víctima'));
      await tester.pumpAndSettle();
      final pantalla = tester.widget<SituacionScreen>(find.byType(SituacionScreen));
      expect(pantalla.rol, RolProceso.victima);
      expect(find.text('Pregunta como víctima'), findsOneWidget);
    });

    testWidgets('Mi situación es «tu guía»: el expediente y el talón «TU GUÍA», nunca «tu expediente»', (tester) async {
      await arrancarApp(tester);
      final ticket = find.ancestor(of: find.text('Mi situación'), matching: find.byType(TicketTuTurno));
      final icono = tester.widget<IconoTuTurno>(find.descendant(of: ticket, matching: find.byType(IconoTuTurno)));
      expect(icono.icono, TuIcono.expediente);
      expect(find.descendant(of: ticket, matching: find.text('TU')), findsOneWidget);
      expect(find.descendant(of: ticket, matching: find.text('GUÍA')), findsOneWidget);
      expect(find.textContaining(RegExp('tu expediente', caseSensitive: false)), findsNothing);
    });

    testWidgets('con tu papel en el ticket, Mi situación es «Tu camino» (sin decir el papel) y lleva directo', (
      tester,
    ) async {
      await arrancarApp(tester, preferencias: _entrada(rol: 'victima'));
      expect(find.text(TuCamino.tituloNeutro), findsOneWidget);
      expect(find.text('MI SITUACIÓN'), findsOneWidget);
      expect(find.text(TuCamino.descripcionNeutra), findsOneWidget);
      // Móvil compartido: el ticket del inicio no dice el papel a quien lo mire.
      final ticket = find.ancestor(of: find.text(TuCamino.tituloNeutro), matching: find.byType(TicketTuTurno));
      expect(find.descendant(of: ticket, matching: find.textContaining('íctima')), findsNothing);

      await pulsar(tester, find.text(TuCamino.tituloNeutro));
      // Sin la hoja de elegir papel: directo a la línea de la víctima.
      expect(find.text('¿Qué papel tienes en el caso?'), findsNothing);
      final pantalla = tester.widget<SituacionScreen>(find.byType(SituacionScreen));
      expect(pantalla.rolId, 'victima');
      expect(pantalla.rol, RolProceso.victima);
    });

    testWidgets('con el papel y la fase en el ticket, el inicio no dice ninguno de los dos', (tester) async {
      await arrancarApp(
        tester,
        preferencias: _entrada(rol: 'investigado', fase: 'durante'),
      );
      expect(find.text(TuCamino.tituloNeutro), findsOneWidget);
      expect(find.text(PapelSituacion.investigado.tituloCamino), findsNothing);
      final ticket = find.ancestor(of: find.text(TuCamino.tituloNeutro), matching: find.byType(TicketTuTurno));
      expect(find.descendant(of: ticket, matching: find.textContaining('nvestig')), findsNothing);
      expect(find.descendant(of: ticket, matching: find.textContaining('Durante')), findsNothing);
    });

    testWidgets('escuchado en familia lleva a su propia línea, /situacion/escuchado_familia', (tester) async {
      await arrancarApp(tester, preferencias: _entrada(rol: 'escuchado_familia'));
      const titulo = TuCamino.tituloNeutro;
      expect(find.text(titulo), findsOneWidget);
      await pulsar(tester, find.text(titulo));
      expect(tester.widget<SituacionScreen>(find.byType(SituacionScreen)).rolId, 'escuchado_familia');
    });

    testWidgets('con «No lo sé» (o sin ticket), Mi situación abre el selector de siempre', (tester) async {
      await arrancarApp(tester, preferencias: _entrada(rol: 'no_lo_se'));
      expect(find.textContaining('Tu camino'), findsNothing);
      await pulsar(tester, find.text('Mi situación'));
      expect(find.text('¿Qué papel tienes en el caso?'), findsOneWidget);
      expect(find.byType(SituacionScreen), findsNothing);
    });

    testWidgets('el día de tu cita, el «modo día» en la portada, sin decir el papel ni dónde es', (tester) async {
      await arrancarApp(
        tester,
        preferencias: {
          ..._entrada(rol: 'victima'),
          'mi_situacion': jsonEncode({'fecha': '2026-10-22', 'hora': '12:30'}),
        },
        overrides: [relojProvider.overrideWithValue(() => _tarde)],
      );
      expect(find.text('Hoy es tu día'), findsOneWidget);
      expect(find.textContaining('A las 12:30.'), findsOneWidget);
      // Ni el papel ni dónde es la cita.
      final tarjeta = find.ancestor(of: find.text('Hoy es tu día'), matching: find.byType(TicketTuTurno));
      expect(find.descendant(of: tarjeta, matching: find.textContaining('íctima')), findsNothing);
      expect(find.descendant(of: tarjeta, matching: find.textContaining('juzgado')), findsNothing);
    });

    testWidgets('los días de antes de la cita, la portada no la anuncia', (tester) async {
      await arrancarApp(
        tester,
        preferencias: {
          ..._entrada(rol: 'victima'),
          'mi_situacion': jsonEncode({'fecha': '2026-10-24'}),
        },
        overrides: [relojProvider.overrideWithValue(() => _tarde)],
      );
      expect(find.text('Hoy es tu día'), findsNothing);
      expect(find.text('Tu cita'), findsNothing);
      expect(find.textContaining('Faltan'), findsNothing);
    });

    testWidgets('con tu papel, Tut te recuerda tu camino en el saludo (sin decir cuál es)', (tester) async {
      await arrancarApp(
        tester,
        preferencias: _entrada(rol: 'victima'),
        overrides: [relojProvider.overrideWithValue(() => _tarde)],
      );
      expect(find.text(SaludoTut.fraseCamino), findsOneWidget);
      expect(find.descendant(of: find.byType(SaludoTut), matching: find.textContaining('víctima')), findsNothing);
    });

    testWidgets('con racha 0 se ve «¡Empieza hoy!» y «Cómo se ganan» explica el descanso de cada semana', (
      tester,
    ) async {
      await arrancarApp(tester, overrides: [relojProvider.overrideWithValue(() => _tarde)]);
      final pase = find.byType(PaseProgreso);
      expect(find.descendant(of: pase, matching: find.text('¡Empieza hoy!')), findsOneWidget);
      expect(find.descendant(of: pase, matching: find.text('0')), findsNothing);
      expect(find.descendant(of: pase, matching: find.text('días')), findsNothing);
      expect(find.textContaining(_perder), findsNothing);

      await tester.tap(pase);
      await tester.pumpAndSettle();
      expect(find.textContaining('tienes un día de descanso cada semana'), findsOneWidget);
      expect(find.textContaining('tus puntos nunca bajan'), findsOneWidget);
      expect(find.textContaining(_perder), findsNothing);
    });

    testWidgets('sin racha en marcha, «Tu progreso» recuerda tu mejor racha (sin reñir)', (tester) async {
      await arrancarApp(
        tester,
        preferencias: {
          'progreso': _progreso(Progreso(xp: 60, racha: 5, mejorRacha: 5, ultimoDiaConLeccion: DateTime(2026, 10, 18))),
        },
        overrides: [relojProvider.overrideWithValue(() => _tarde)],
      );
      expect(find.text('¡Empieza hoy!'), findsOneWidget);
      await tester.tap(find.byType(PaseProgreso));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tu mejor racha: 5 días.'), findsOneWidget);
      expect(find.textContaining(_perder), findsNothing);
    });

    testWidgets('el engranaje abre Ajustes y la palabra del día abre su detalle', (tester) async {
      final router = await arrancarApp(tester);

      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.byType(AjustesScreen), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('Palabra del día'), findsOneWidget);
      await pulsar(tester, find.text('Palabra del día'));
      expect(find.byType(GlosarioScreen), findsOneWidget);
      // La búsqueda coincide con el término: su detalle se abre solo.
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('sin glosario, la palabra del día no ocupa sitio', (tester) async {
      await arrancarApp(tester, glosario: '[]');
      expect(find.text('Palabra del día'), findsNothing);
      expect(find.byType(TarjetaModulo), findsNWidgets(3));
    });
  });

  test('Tut saluda según la hora del día', () {
    expect(SaludoTut.saludoPara(8), '¡Buenos días!');
    expect(SaludoTut.saludoPara(17), '¡Buenas tardes!');
    expect(SaludoTut.saludoPara(22), '¡Buenas noches!');
    expect(SaludoTut.saludoPara(3), '¡Buenas noches!');
  });

  group('Inicio accesible', () {
    Future<void> recorrerSinDesbordes(WidgetTester tester) async {
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(mensajeIA), findsOneWidget);
    }

    testWidgets('cabe sin desbordarse con la letra de Ajustes a 1,3 en un móvil pequeño', (tester) async {
      await arrancarApp(tester, preferencias: {'ajustes.tamano_texto': 1.3}, tamano: const Size(360, 640));
      await recorrerSinDesbordes(tester);
    });

    testWidgets('cabe sin desbordarse con la letra del sistema a 1,3', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await arrancarApp(tester, tamano: const Size(360, 640));
      await recorrerSinDesbordes(tester);
    });

    testWidgets('cabe con la letra del sistema a 1,3 y la de Ajustes a 1,3 a la vez', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await arrancarApp(
        tester,
        preferencias: {
          'ajustes.tamano_texto': 1.3,
          'progreso': _progreso(Progreso(xp: 1230, racha: 12, ultimoDiaConLeccion: DateTime(2026, 10, 22))),
        },
        tamano: const Size(360, 640),
        overrides: [relojProvider.overrideWithValue(() => _tarde)],
      );
      await recorrerSinDesbordes(tester);
    });

    testWidgets('cabe a 1,3 en un móvil pequeño con tu camino y la fase (investigado, después)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await arrancarApp(
        tester,
        preferencias: {
          ..._entrada(rol: 'investigado', fase: 'despues'),
          'ajustes.tamano_texto': 1.3,
        },
        tamano: const Size(360, 640),
      );
      expect(find.text(TuCamino.tituloNeutro), findsOneWidget);
      await recorrerSinDesbordes(tester);
    });

    testWidgets('la bienvenida cabe sin desbordarse con la letra a 1,6', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await arrancarApp(tester, bienvenidaVista: false, tamano: const Size(360, 640));
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(FuenteChip), findsOneWidget);
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('la bienvenida cabe con la letra a 1,3', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await arrancarApp(
        tester,
        bienvenidaVista: false,
        preferencias: {'ajustes.tamano_texto': 1.3},
        tamano: const Size(360, 640),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('el tema oscuro se pinta bien en inicio, Ayuda, Glosario, Ajustes y módulos', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final router = await arrancarApp(tester);

      final contexto = tester.element(find.byType(TarjetaModulo).first);
      expect(Theme.of(contexto).brightness, Brightness.dark);
      expect(tester.takeException(), isNull);

      for (final ruta in ['/ayuda', '/glosario', '/ajustes', '/juego', '/aprende', '/situacion/testigo']) {
        await irA(tester, router, ruta);
        expect(tester.takeException(), isNull, reason: ruta);
        router.pop();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('con «reducir animaciones» todo aparece ya en su sitio y nada se queda moviéndose', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await arrancarApp(tester, bienvenidaVista: false);
      // La presentación del logotipo y Tut ya están puestos.
      expect(find.byType(MascotaTut), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.tap(find.text('Siguiente'));
      await tester.pump();
      expect(find.text(mensajeIA), findsOneWidget);
      await tester.tap(find.text('Empezar'));
      await tester.pump();
      // Sin arrancar la hoja: el inicio aparece de golpe.
      await tester.pump();
      expect(find.byType(Bienvenida), findsNothing);
      for (final tarjeta in tester.elementList(find.byType(TarjetaModulo))) {
        final opacidades = tester.widgetList<Opacity>(
          find.ancestor(of: find.byElementPredicate((e) => e == tarjeta), matching: find.byType(Opacity)),
        );
        expect(opacidades.every((o) => o.opacity == 1), isTrue);
      }
      final fundidos = tester.widgetList<FadeTransition>(
        find.ancestor(of: find.byType(TicketDelDia), matching: find.byType(FadeTransition)),
      );
      expect(fundidos.every((f) => f.opacity.value == 1), isTrue);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('el texto tiene contraste suficiente en todas las pantallas, en claro y en oscuro', (tester) async {
      final semantica = tester.ensureSemantics();
      for (final brillo in Brightness.values) {
        tester.platformDispatcher.platformBrightnessTestValue = brillo;
        final router = await arrancarApp(
          tester,
          preferencias: {
            'progreso': _progreso(Progreso(xp: 140, racha: 3, ultimoDiaConLeccion: DateTime(2026, 10, 21))),
          },
          overrides: [relojProvider.overrideWithValue(() => _tarde)],
        );
        await expectLater(tester, meetsGuideline(textContrastGuideline), reason: '$brillo inicio');
        await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -3000));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline), reason: '$brillo inicio abajo');
        for (final ruta in ['/ayuda', '/glosario', '/ajustes', '/juego', '/aprende', '/situacion/victima']) {
          await irA(tester, router, ruta);
          await expectLater(tester, meetsGuideline(textContrastGuideline), reason: '$brillo $ruta');
          router.pop();
          await tester.pumpAndSettle();
        }
      }
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      semantica.dispose();
    });

    for (final brillo in Brightness.values) {
      testWidgets('la bienvenida tiene contraste suficiente ($brillo)', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brillo;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final semantica = tester.ensureSemantics();
        await arrancarApp(tester, bienvenidaVista: false);
        await expectLater(tester, meetsGuideline(textContrastGuideline), reason: 'bienvenida 1');
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline), reason: 'bienvenida 2');
        semantica.dispose();
      });
    }

    testWidgets('los botones tienen descripción y zona táctil de 48', (tester) async {
      await arrancarApp(tester);
      expect(find.byTooltip('Ajustes'), findsOneWidget);
      expect(find.byTooltip('Glosario'), findsOneWidget);
      expect(find.byTooltip('Teléfonos de ayuda'), findsOneWidget);
      final semantica = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      // El ticket del día y el pase se leen enteros, como un botón.
      expect(find.bySemanticsLabel(RegExp(r'^Tu turno del día\.')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Racha: ')), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('la bienvenida cumple las pautas de zonas táctiles', (tester) async {
      await arrancarApp(tester, bienvenidaVista: false);
      final semantica = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantica.dispose();
    });
  });
}
