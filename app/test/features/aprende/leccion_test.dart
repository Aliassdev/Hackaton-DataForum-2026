import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/api/mock_api.dart';
import 'package:tuturno/core/api/tuturno_api.dart';
import 'package:tuturno/features/aprende/aprende_screen.dart';
import 'package:tuturno/features/aprende/bkt.dart';
import 'package:tuturno/features/aprende/curso.dart' show prefijoDilo;
import 'package:tuturno/features/aprende/leccion_screen.dart' show textoParaLeer, xpAcierto, xpDilo;
import 'package:tuturno/features/aprende/modelos.dart';
import 'package:tuturno/features/aprende/textos.dart';

import 'ayudantes.dart';

final _ejercicios = ejerciciosDeEjemplo();

/// Ejercicios de una lección de ejemplo, en orden.
List<Ejercicio> _deLeccion(String leccionId) {
  for (final MapEntry(:key, :value) in ficherosDeEjemplo().entries) {
    if (!key.contains('/lecciones/')) continue;
    final unidad = Unidad.fromJson(jsonDecode(value))!;
    for (final l in unidad.lecciones) {
      if (l.id == leccionId) return [for (final id in l.ejercicios) _ejercicios[id]!];
    }
  }
  throw StateError('No existe $leccionId');
}

/// Texto que identifica a un ejercicio en pantalla.
String _identificador(Ejercicio e) => switch (e) {
  EjercicioEleccion(:final pregunta) => pregunta,
  EjercicioVf(:final afirmacion) => afirmacion,
  EjercicioOrdenar(:final enunciado) => enunciado,
  EjercicioEmparejar(:final pares) => pares.first.$1,
  EjercicioDilo(:final pregunta) => pregunta,
};

/// El ejercicio de [candidatos] que está en pantalla.
Ejercicio _enPantalla(Iterable<Ejercicio> candidatos) =>
    candidatos.firstWhere((e) => find.text(_identificador(e)).evaluate().isNotEmpty);

Future<void> _continuar(WidgetTester tester) => pulsar(tester, botonContinuar);

/// Textos que se pueden tocar dentro de un párrafo (los términos del Glosario subrayados).
List<String> _enlacesEnPantalla(WidgetTester tester) => [
  for (final texto in tester.widgetList<RichText>(find.byType(RichText))) ..._enlacesDe(texto.text),
];

List<String> _enlacesDe(InlineSpan span) {
  final enlaces = <String>[];
  span.visitChildren((hijo) {
    if (hijo is TextSpan && hijo.recognizer != null) enlaces.add(hijo.text ?? '');
    return true;
  });
  return enlaces;
}

void main() {
  testWidgets('lección entera: +10 por acierto, +5 en «Dilo», racha, dominio y celebración', (tester) async {
    final m = await montar(
      tester,
      ruta: '/aprende/leccion/U1-L1',
      preferencias: progresoGuardado(xp: 20, racha: 2, ultimoDia: DateTime(2026, 10, 20)),
    );
    final lista = _deLeccion('U1-L1');
    expect(lista, hasLength(6));
    // En la barra, el título corto (como en el mapa); el de la lección, encima de la barra de progreso.
    expect(find.text('Lección 1'), findsOneWidget);
    expect(find.text('Que te escuchen'), findsOneWidget);

    for (final e in lista) {
      expect(find.text(_identificador(e)), findsOneWidget, reason: e.id);
      expect(tester.widget<FilledButton>(botonComprobar).onPressed, isNull, reason: 'sin respuesta no se comprueba');
      await responderYComprobar(tester, e, bien: true);
      expect(find.byKey(const ValueKey('panel-correccion')), findsOneWidget, reason: e.id);
      if (e is EjercicioDilo) {
        expect(find.text('+$xpDilo XP'), findsOneWidget);
        expect(find.text('Has explicado 2 de 3 ideas'), findsOneWidget);
        expect(find.text('Tu opinión se tiene en cuenta según tu edad y madurez'), findsOneWidget);
      } else {
        expect(find.text('+$xpAcierto XP'), findsOneWidget, reason: e.id);
      }
      expect(find.text(e.fuente), findsOneWidget, reason: '${e.id}: la fuente está a la vista');
      await _continuar(tester);
    }

    expect(find.text('¡Lección completada!'), findsOneWidget);
    expect(find.text('+55'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget, reason: 'la racha ha subido hoy');
    expect(find.text('6/6'), findsOneWidget);
    expect(find.text('¡Ya dominas «Ser oído y escuchado»!'), findsOneWidget);

    final progreso = m.progreso;
    expect(progreso.xp, 20 + 5 * xpAcierto + xpDilo);
    expect(progreso.racha, 3);
    expect(progreso.ultimoDiaConLeccion, DateTime(2026, 10, 21));
    expect(progreso.leccionesCompletadas, {'U1-L1'});
    expect(Bkt.dominado(progreso.dominio['C-ser-oido']!), isTrue);
    expect(progreso.ultimaPractica['C-ser-oido'], hoy);
    expect(m.api.notas.single.conceptoId, 'C-ser-oido');
    expect(m.api.notas.single.texto, respuestaDilo);

    // «Siguiente» abre la lección que se acaba de desbloquear.
    await pulsar(tester, find.byKey(const ValueKey('boton-siguiente')));
    expect(find.text('Fiscalía y Defensor del Pueblo'), findsOneWidget);
    expect(find.text(_identificador(_deLeccion('U1-L2').first)), findsOneWidget);
  });

  testWidgets('al fallar: respuesta correcta, explicación y fuente; sin puntos y el dominio baja', (tester) async {
    final m = await montar(tester, ruta: '/aprende/leccion/U1-L1');
    final e = _deLeccion('U1-L1').first as EjercicioEleccion;
    await responderYComprobar(tester, e, bien: false);

    expect(find.text('Respuesta correcta'), findsOneWidget);
    expect(find.text(e.opciones[e.correcta]), findsNWidgets(2));
    expect(find.text(e.explicacion), findsOneWidget);
    expect(find.textContaining('XP'), findsNothing);
    expect(m.progreso.dominio['C-ser-oido'], closeTo(const Bkt().actualizar(Bkt.p0, false), 1e-9));

    // La fuente se puede abrir y explica la norma.
    await pulsar(tester, find.text(e.fuente));
    expect(find.text('De dónde sale'), findsOneWidget);
    expect(find.text(nombresNormas['LO 1/1996']!), findsOneWidget);
    await pulsar(tester, find.text('Entendido'));
    expect(find.text('De dónde sale'), findsNothing);

    // Y se puede escuchar: el título, la respuesta correcta y la explicación.
    await pulsar(tester, find.byTooltip('Escuchar la explicación'));
    expect(
      m.tts.leidos.last,
      '${tituloCorreccion(acierto: false, vez: 0)} La respuesta correcta es: ${e.opciones[e.correcta]}. '
      '${e.explicacion}',
    );
  });

  testWidgets('«Dilo»: mientras revisa enseña que está revisando y luego las ideas', (tester) async {
    final api = ApiDePrueba()..pausa = Completer<void>();
    final m = await montar(tester, ruta: '/aprende/leccion/U1-L1', api: api);
    final lista = _deLeccion('U1-L1');
    for (final e in lista.take(5)) {
      await responderYComprobar(tester, e, bien: true);
      await _continuar(tester);
    }
    await responder(tester, lista.last, bien: true);
    await tester.tap(botonComprobar);
    await tester.pump();
    expect(find.text('Revisando tu respuesta…'), findsOneWidget);
    expect(tester.widget<TextField>(campoDilo).readOnly, isTrue);

    api.pausa!.complete();
    await tester.pumpAndSettle();
    // 2 de 3 ideas: suma puntos, pero aún falta una. La que falta va aparte, destacada.
    expect(find.text('¡Ya casi!'), findsOneWidget);
    expect(find.text(textoDiloTeFalta), findsOneWidget);
    expect(find.text('Tu opinión se tiene en cuenta según tu edad y madurez'), findsOneWidget);
    // El comentario del evaluador solo repetía el «¡Muy bien!» y la idea que falta: no se enseña dos veces.
    expect(find.text(MockGrade.feedback), findsNothing);
    expect(find.text('¡Muy bien!'), findsNothing);

    // La corrección también se puede escuchar: las ideas explicadas y las que faltan, sin repetir nada.
    await pulsar(tester, find.byKey(const ValueKey('boton-escuchar-correccion')));
    expect(m.tts.leidos.last, startsWith('¡Ya casi! Has explicado: '));
    expect(m.tts.leidos.last, contains('Te falta: Tu opinión se tiene en cuenta según tu edad y madurez.'));
    expect(m.tts.leidos.last, isNot(contains('¡Muy bien!')));
  });

  testWidgets('mientras revisa «Dilo», el botón no parece apagado y el lector de pantalla lo anuncia', (tester) async {
    final semantica = tester.ensureSemantics();
    final api = ApiDePrueba()..pausa = Completer<void>();
    await montar(tester, ruta: '/aprende/leccion/${prefijoDilo}U1-L1', demo: true, api: api);
    await responder(tester, _deLeccion('U1-L1').last, bien: true);
    await tester.tap(botonComprobar);
    await tester.pump();

    final boton = tester.widget<FilledButton>(botonComprobar);
    final esquema = Theme.of(tester.element(botonComprobar)).colorScheme;
    expect(boton.onPressed, isNull);
    expect(boton.style?.backgroundColor?.resolve({WidgetState.disabled}), esquema.primary);
    expect(boton.style?.foregroundColor?.resolve({WidgetState.disabled}), esquema.onPrimary);
    expect(find.bySemanticsLabel('Revisando tu respuesta'), findsOneWidget);

    api.pausa!.complete();
    await tester.pumpAndSettle();
    semantica.dispose();
  });

  testWidgets('«Dilo» sin conexión: lo explica sin mandar a Ayuda, enseña las ideas clave y deja seguir sin puntos', (
    tester,
  ) async {
    const error = ApiException('LLM_NO_DISPONIBLE', ApiException.mensajeSeguro);
    final m = await montar(
      tester,
      ruta: '/aprende/leccion/U1-L1',
      api: ApiDePrueba(error: error),
    );
    final lista = _deLeccion('U1-L1');
    for (final e in lista.take(5)) {
      await responderYComprobar(tester, e, bien: true);
      await _continuar(tester);
    }
    final dominioAntes = m.progreso.dominio['C-ser-oido'];
    await responderYComprobar(tester, lista.last, bien: true);
    expect(find.text(textoDiloSinRevisar), findsOneWidget);
    // Un fallo técnico no manda a Ayuda (los teléfonos son para pedir ayuda) ni dice dos veces «No he podido».
    expect(find.text(error.mensaje), findsNothing);
    expect(find.text(textoDiloSinConexion), findsOneWidget);
    expect(find.text(textoVolverAIntentar), findsOneWidget);
    expect(find.text(textoDiloIdeasClave), findsOneWidget);
    for (final idea in (lista.last as EjercicioDilo).proposiciones) {
      expect(find.text(idea), findsOneWidget);
    }
    expect(m.progreso.dominio['C-ser-oido'], dominioAntes, reason: 'sin corrección no cambia el dominio');

    await pulsar(tester, find.text('Terminar'));
    expect(find.text('¡Lección completada!'), findsOneWidget);
    expect(m.progreso.xp, 5 * xpAcierto);
    expect(m.progreso.leccionesCompletadas, contains('U1-L1'));
  });

  testWidgets('«Dilo» sin conexión: «Volver a intentarlo» envía el mismo texto y, si ya hay red, corrige', (
    tester,
  ) async {
    final api = ApiDePrueba(error: const ApiException('HTTP_502', ApiException.mensajeSeguro));
    final m = await montar(tester, ruta: '/aprende/leccion/${prefijoDilo}U1-L1', demo: true, api: api);
    final dilo = _deLeccion('U1-L1').last as EjercicioDilo;
    await responderYComprobar(tester, dilo, bien: true);
    expect(find.text(textoDiloSinRevisar), findsOneWidget);
    expect(m.progreso.xp, 0);

    api.error = null;
    await pulsar(tester, find.text(textoVolverAIntentar));
    expect(api.notas, hasLength(2));
    expect(api.notas.last.texto, respuestaDilo);
    expect(find.text('Has explicado 2 de 3 ideas'), findsOneWidget);
    expect(find.text('+$xpDilo XP'), findsOneWidget);
    expect(find.text(textoVolverAIntentar), findsNothing);

    await pulsar(tester, find.text('Terminar'));
    expect(m.progreso.xp, xpDilo, reason: 'los puntos de «Dilo», una sola vez');
  });

  group('«Dilo» con algo que suena a peligro (sección 10.2)', () {
    for (final texto in ['A veces quiero morir y no sé qué hacer', 'Tengo miedo de volver a casa por las noches']) {
      testWidgets('«$texto»: no lo corrige ni lo envía, y enseña los teléfonos de ayuda', (tester) async {
        final m = await montar(tester, ruta: '/aprende/leccion/${prefijoDilo}U1-L1', demo: true);
        final dominioAntes = m.progreso.dominio['C-ser-oido'];
        await tester.enterText(campoDilo, texto);
        await tester.pumpAndSettle();
        await pulsar(tester, botonComprobar);

        expect(m.api.notas, isEmpty, reason: 'no se envía a corregir');
        expect(find.text(textoAyudaDiloTitulo), findsOneWidget);
        final tarjeta = find.byKey(const ValueKey('tarjeta-crisis-dilo'));
        expect(tarjeta, findsOneWidget);
        expect(find.descendant(of: tarjeta, matching: find.textContaining('ANAR')), findsOneWidget);
        expect(find.descendant(of: tarjeta, matching: find.textContaining('112')), findsOneWidget);
        // Sin título de acierto o fallo, sin puntos y sin tocar el dominio.
        expect(find.textContaining('XP'), findsNothing);
        expect(find.textContaining('Has explicado'), findsNothing);
        expect(m.progreso.dominio['C-ser-oido'], dominioAntes);

        // Se puede escuchar (la plantilla de crisis entera) y seguir con la lección.
        await pulsar(tester, find.byKey(const ValueKey('boton-escuchar-correccion')));
        expect(m.tts.leidos.last, textoAyudaDiloVoz);
        await pulsar(tester, find.text('Terminar'));
        expect(find.text('¡Lección completada!'), findsOneWidget);
        expect(m.progreso.xp, 0);
      });
    }

    testWidgets('también si, con eso escrito, pulsa «Ahora no puedo»', (tester) async {
      final m = await montar(tester, ruta: '/aprende/leccion/${prefijoDilo}U1-L1', demo: true);
      await tester.enterText(campoDilo, 'no quiero vivir así');
      await tester.pumpAndSettle();
      await pulsar(tester, find.byKey(const ValueKey('boton-saltar')));
      expect(find.byKey(const ValueKey('tarjeta-crisis-dilo')), findsOneWidget);
      expect(find.text(textoDiloIdeasClave), findsNothing);
      expect(m.api.notas, isEmpty);
    });

    testWidgets('el botón de llamar a ANAR se ve sin desplazar; con letra grande en un móvil pequeño, cabe todo', (
      tester,
    ) async {
      // Basta con dos palabras: lo que suena a peligro se puede comprobar aunque sea corto.
      await montar(tester, ruta: '/aprende/leccion/${prefijoDilo}U1-L1', demo: true);
      await tester.enterText(campoDilo, 'quiero morir');
      await tester.pumpAndSettle();
      await pulsar(tester, botonComprobar);
      final llamar = find.textContaining('Llamar a ANAR');
      expect(llamar, findsOneWidget);
      expect(tester.getBottomLeft(llamar).dy, lessThan(movil.height), reason: 'a la vista sin desplazar nada');

      await montar(
        tester,
        ruta: '/aprende/leccion/${prefijoDilo}U1-L1',
        demo: true,
        escalaTexto: 1.3,
        tamano: const Size(360, 640),
        brillo: Brightness.dark,
      );
      await tester.enterText(campoDilo, 'quiero morir');
      await tester.pumpAndSettle();
      await pulsar(tester, botonComprobar);
      expect(tester.takeException(), isNull);
      // Lo que no quepa se desplaza dentro del panel y «Seguir» se queda abajo, a la vista.
      await tester.ensureVisible(find.textContaining('Llamar a ANAR'));
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(find.textContaining('Llamar a ANAR')).dy, lessThan(640));
      expect(tester.getBottomLeft(botonContinuar).dy, lessThanOrEqualTo(640));
    });
  });

  testWidgets('«Dilo»: «Ahora no puedo» enseña las ideas clave sin llamar a la API', (tester) async {
    final m = await montar(tester, ruta: '/aprende/leccion/U1-L1');
    final lista = _deLeccion('U1-L1');
    for (final e in lista.take(5)) {
      await responderYComprobar(tester, e, bien: true);
      await _continuar(tester);
    }
    await pulsar(tester, find.byKey(const ValueKey('boton-saltar')));
    expect(find.text('Mira las ideas clave'), findsOneWidget);
    expect(m.api.notas, isEmpty);
  });

  testWidgets('salir a mitad pide confirmación y no guarda los puntos', (tester) async {
    final m = await montar(tester);
    m.router.push('/aprende/leccion/U1-L1');
    await tester.pumpAndSettle();
    final primero = _deLeccion('U1-L1').first;
    await responderYComprobar(tester, primero, bien: true);
    await _continuar(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(textoSalirTitulo), findsOneWidget);
    await pulsar(tester, find.text('Seguir aprendiendo'));
    expect(find.text(_identificador(_deLeccion('U1-L1')[1])), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await pulsar(tester, find.text('Salir'));
    expect(find.byType(AprendeScreen), findsOneWidget);
    expect(m.progreso.xp, 0);
    expect(m.progreso.leccionesCompletadas, isEmpty);
    expect(m.progreso.dominio['C-ser-oido'], greaterThan(Bkt.p0), reason: 'lo aprendido sí se queda');
  });

  testWidgets('sin haber respondido nada, se sale sin preguntar', (tester) async {
    final m = await montar(tester);
    m.router.push('/aprende/leccion/U1-L1');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(textoSalirTitulo), findsNothing);
    expect(find.byType(AprendeScreen), findsOneWidget);
  });

  testWidgets('una lección bloqueada no se abre por enlace, salvo en modo demo', (tester) async {
    await montar(tester, ruta: '/aprende/leccion/U2-L1');
    expect(find.text('Esta lección aún está cerrada'), findsOneWidget);
    await pulsar(tester, find.text('Ir a «Que te escuchen»'));
    expect(find.text(_identificador(_deLeccion('U1-L1').first)), findsOneWidget);
  });

  testWidgets('en modo demo una lección bloqueada se puede abrir', (tester) async {
    await montar(tester, ruta: '/aprende/leccion/U2-L1', demo: true);
    expect(find.text(_identificador(_deLeccion('U2-L1').first)), findsOneWidget);
  });

  testWidgets('una lección que no existe lo dice y lleva a Aprende', (tester) async {
    await montar(tester, ruta: '/aprende/leccion/U9-L9');
    expect(find.text('No encuentro esta lección'), findsOneWidget);
    await pulsar(tester, find.text('Ir a Aprende'));
    expect(find.byType(AprendeScreen), findsOneWidget);
  });

  testWidgets('en la explicación, los términos del Glosario se pueden tocar y abren su definición', (tester) async {
    final m = await montar(tester, ruta: '/aprende/leccion/U2-L2', demo: true, repo: repoDeEjemplo(glosario: true));
    final e = _deLeccion('U2-L2').first as EjercicioEleccion;
    expect(e.explicacion, contains('equipo psicosocial'));
    // En la pregunta y en las opciones no se subraya nada: la definición podría dar la respuesta.
    expect(_enlacesEnPantalla(tester), isEmpty);

    await responderYComprobar(tester, e, bien: false);
    expect(_enlacesEnPantalla(tester), contains('equipo psicosocial'));
    await tester.tapOnText(find.textRange.ofSubstring('equipo psicosocial').last);
    await tester.pumpAndSettle();
    expect(find.text('pantalla del glosario'), findsOneWidget);
    expect(m.router.state.uri.queryParameters['q'], 'Equipo psicosocial');

    // Al volver, la lección sigue donde estaba.
    m.router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('panel-correccion')), findsOneWidget);
  });

  group('atajo de la demo a «Dilo con tus palabras»', () {
    testWidgets('en modo demo, la lección empieza en su «Dilo» y se puede terminar', (tester) async {
      final m = await montar(tester, ruta: '/aprende/leccion/${prefijoDilo}U1-L1', demo: true);
      final lista = _deLeccion('U1-L1');
      final dilo = lista.last as EjercicioDilo;
      expect(find.text(dilo.pregunta), findsOneWidget);
      expect(find.text('Que te escuchen'), findsOneWidget);

      await responderYComprobar(tester, dilo, bien: true);
      expect(find.text('Has explicado 2 de 3 ideas'), findsOneWidget);
      await pulsar(tester, find.text('Terminar'));
      expect(find.text('¡Lección completada!'), findsOneWidget);
      expect(m.progreso.xp, xpDilo);
    });

    testWidgets('fuera del modo demo, la misma ruta abre la lección por el principio', (tester) async {
      await montar(tester, ruta: '/aprende/leccion/${prefijoDilo}U1-L1');
      expect(find.text(_identificador(_deLeccion('U1-L1').first)), findsOneWidget);
    });

    testWidgets('fuera del modo demo, el atajo no se salta los bloqueos', (tester) async {
      await montar(tester, ruta: '/aprende/leccion/${prefijoDilo}U2-L1');
      expect(find.text('Esta lección aún está cerrada'), findsOneWidget);
    });
  });

  testWidgets('«Escuchar» lee el ejercicio en voz alta y, si se pulsa otra vez, para', (tester) async {
    final m = await montar(tester, ruta: '/aprende/leccion/U1-L1');
    await pulsar(tester, find.byKey(const ValueKey('boton-escuchar')));
    expect(m.tts.leidos.single, textoParaLeer(_deLeccion('U1-L1').first));
    expect(find.byTooltip('Parar la lectura'), findsOneWidget);
    await pulsar(tester, find.byKey(const ValueKey('boton-escuchar')));
    expect(m.tts.hablando.value, isFalse);
    expect(m.tts.leidos, hasLength(1));
  });

  group('la voz no se pisa con nada', () {
    testWidgets('se calla al abrir Ayuda encima, al comprobar y si la app pasa a segundo plano', (tester) async {
      final m = await montar(tester, ruta: '/aprende/leccion/U1-L1');
      final escuchar = find.byKey(const ValueKey('boton-escuchar'));

      await pulsar(tester, escuchar);
      expect(m.tts.hablando.value, isTrue);
      m.router.push('/ayuda');
      await tester.pumpAndSettle();
      expect(m.tts.hablando.value, isFalse, reason: 'Ayuda tapa la lección');
      m.router.pop();
      await tester.pumpAndSettle();

      await pulsar(tester, escuchar);
      await responderYComprobar(tester, _deLeccion('U1-L1').first, bien: true);
      expect(m.tts.hablando.value, isFalse, reason: 'al comprobar sale la corrección');

      await pulsar(tester, find.byKey(const ValueKey('boton-escuchar-correccion')));
      expect(m.tts.hablando.value, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(m.tts.hablando.value, isFalse, reason: 'la app se ha ocultado');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    });

    testWidgets('se calla al tocar un término del Glosario en la explicación', (tester) async {
      final m = await montar(tester, ruta: '/aprende/leccion/U2-L2', demo: true, repo: repoDeEjemplo(glosario: true));
      await responderYComprobar(tester, _deLeccion('U2-L2').first, bien: false);
      await pulsar(tester, find.byKey(const ValueKey('boton-escuchar-correccion')));
      expect(m.tts.hablando.value, isTrue);
      await tester.tapOnText(find.textRange.ofSubstring('equipo psicosocial').last);
      await tester.pumpAndSettle();
      expect(find.text('pantalla del glosario'), findsOneWidget);
      expect(m.tts.hablando.value, isFalse);
    });

    testWidgets('en «Dilo», «Escuchar» apaga antes el micrófono y lo dictado se queda', (tester) async {
      final m = await montar(tester, ruta: '/aprende/leccion/${prefijoDilo}U1-L1', demo: true);
      await tester.tap(find.byKey(const ValueKey('micro-dilo')));
      await tester.pump();
      expect(m.stt.escuchando, isTrue);
      m.stt.oir('el juez me tiene que escuchar');
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('boton-escuchar')));
      await tester.pumpAndSettle();
      expect(m.stt.escuchando, isFalse, reason: 'nunca se escucha mientras se habla (sección 6.5)');
      expect(m.stt.registro.last, 'parar');
      expect(m.tts.leidos.single, (_deLeccion('U1-L1').last as EjercicioDilo).pregunta);
      expect(find.text('el juez me tiene que escuchar'), findsOneWidget);
      expect(find.text('Pulsa para dictar'), findsOneWidget);
    });

    testWidgets('mientras se dicta no se puede comprobar: se corrige el texto final', (tester) async {
      final m = await montar(tester, ruta: '/aprende/leccion/${prefijoDilo}U1-L1', demo: true);
      await tester.tap(find.byKey(const ValueKey('micro-dilo')));
      await tester.pump();
      m.stt.oir('que el juez me tiene que escuchar');
      await tester.pump();
      expect(tester.widget<FilledButton>(botonComprobar).onPressed, isNull, reason: 'transcripción a medias');

      m.stt.oir('que el juez me tiene que escuchar porque tengo doce años');
      m.stt.silencio();
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(botonComprobar).onPressed, isNotNull);
      await pulsar(tester, botonComprobar);
      expect(m.api.notas.single.texto, 'que el juez me tiene que escuchar porque tengo doce años');
    });
  });

  group('doble toque', () {
    testWidgets('dos toques seguidos en «Continuar» no se saltan el ejercicio siguiente', (tester) async {
      final m = await montar(tester, ruta: '/aprende/leccion/U1-L1');
      final lista = _deLeccion('U1-L1');
      await responderYComprobar(tester, lista.first, bien: true);
      final centro = tester.getCenter(botonContinuar);
      await tester.tapAt(centro);
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tapAt(centro);
      await tester.pumpAndSettle();

      expect(find.text(_identificador(lista[1])), findsOneWidget, reason: 'sigue en el ejercicio 2');
      expect(find.byKey(const ValueKey('panel-correccion')), findsNothing);
      expect(tester.widget<FilledButton>(botonComprobar).onPressed, isNull, reason: 'el ejercicio 2, sin responder');
      expect(m.progreso.xp, 0, reason: 'los puntos se guardan al terminar');
    });

    testWidgets('dos toques seguidos en «Terminar» no suman dos veces los puntos', (tester) async {
      final m = await montar(tester, ruta: '/aprende/leccion/${prefijoDilo}U1-L1', demo: true);
      await responderYComprobar(tester, _deLeccion('U1-L1').last, bien: true);
      final centro = tester.getCenter(botonContinuar);
      await tester.tapAt(centro);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tapAt(centro);
      await tester.pumpAndSettle();
      expect(find.text('¡Lección completada!'), findsOneWidget);
      expect(m.progreso.xp, xpDilo);
    });
  });

  group('Practicar', () {
    testWidgets('elige seis ejercicios según el dominio, suma XP y no completa lecciones', (tester) async {
      final m = await montar(tester, ruta: '/aprende/leccion/practica-U1');
      expect(find.text('Practicar'), findsOneWidget);
      expect(find.text('Tus derechos'), findsOneWidget);
      // Sin práctica previa: el primer concepto de la unidad, con dificultad 1.
      expect(find.text(_identificador(_ejercicios['E-101']!)), findsOneWidget);

      final unidad1 = _ejercicios.values.where((e) => e.id.startsWith('E-1'));
      final vistos = <String>{};
      for (var i = 0; i < 6; i++) {
        final e = _enPantalla(unidad1.where((e) => !vistos.contains(e.id)));
        vistos.add(e.id);
        await responderYComprobar(tester, e, bien: true);
        await _continuar(tester);
      }
      expect(vistos, hasLength(6));
      expect(find.text('¡Práctica terminada!'), findsOneWidget);
      expect(m.progreso.leccionesCompletadas, isEmpty);
      expect(m.progreso.racha, 0);
      expect(m.progreso.xp, greaterThan(0));
      // Ha ido a los conceptos más flojos: más de uno.
      expect({for (final id in vistos) _ejercicios[id]!.concepto}.length, greaterThan(1));
    });

    testWidgets('un concepto dominado que lleva días sin practicarse sale como repaso', (tester) async {
      await montar(
        tester,
        ruta: '/aprende/leccion/practica-U1',
        preferencias: progresoGuardado(
          dominio: {'C-ser-oido': 0.97},
          ultimaPractica: {'C-ser-oido': hoy.subtract(const Duration(days: 3))},
        ),
      );
      expect(find.text('Repaso'), findsOneWidget);
      final e = _enPantalla(_ejercicios.values);
      expect(e.concepto, 'C-ser-oido');
      expect(e.dificultad, 3);
    });

    testWidgets('una unidad que no existe lo dice', (tester) async {
      await montar(tester, ruta: '/aprende/leccion/practica-U9');
      expect(find.text('No encuentro esta lección'), findsOneWidget);
    });
  });

  testWidgets('con letra grande, en un móvil pequeño y en tema oscuro, todo cabe (también los paneles)', (
    tester,
  ) async {
    for (final leccion in ['U1-L1', 'U1-L3', 'U2-L2']) {
      await montar(
        tester,
        ruta: '/aprende/leccion/$leccion',
        demo: true,
        escalaTexto: 1.3,
        tamano: const Size(360, 640),
        brillo: Brightness.dark,
      );
      for (final e in _deLeccion(leccion)) {
        await responderYComprobar(tester, e, bien: false);
        expect(tester.takeException(), isNull, reason: '$leccion ${e.id}');
        await _continuar(tester);
        expect(tester.takeException(), isNull, reason: '$leccion ${e.id}');
      }
      expect(find.text('¡Lección completada!'), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$leccion celebración');
    }
  });

  testWidgets('accesible: zonas táctiles, etiquetas y contraste en claro y en oscuro', (tester) async {
    final semantica = tester.ensureSemantics();
    for (final brillo in Brightness.values) {
      await montar(tester, ruta: '/aprende/leccion/U1-L1', brillo: brillo);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline), reason: '$brillo ejercicio');
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: '$brillo ejercicio');
      await expectLater(tester, meetsGuideline(textContrastGuideline), reason: '$brillo ejercicio');
      final lista = _deLeccion('U1-L1');
      await responderYComprobar(tester, lista.first, bien: false);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: '$brillo panel');
      await expectLater(tester, meetsGuideline(textContrastGuideline), reason: '$brillo panel');
      await _continuar(tester);
      await responderYComprobar(tester, lista[1], bien: true);
      await expectLater(tester, meetsGuideline(textContrastGuideline), reason: '$brillo panel de acierto');
    }
    semantica.dispose();
  });
}

/// El comentario que devuelve el mock de la API para C-ser-oido (sección 8.2).
abstract final class MockGrade {
  static final feedback = MockTuTurnoApi.ejemploGrade['feedback']! as String;
}
