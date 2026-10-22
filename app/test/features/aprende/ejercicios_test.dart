import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/voz/stt.dart';
import 'package:tuturno/core/voz/tts.dart';
import 'package:tuturno/features/aprende/modelos.dart';
import 'package:tuturno/features/aprende/textos.dart';
import 'package:tuturno/features/aprende/widgets/comunes.dart';
import 'package:tuturno/features/aprende/widgets/correccion.dart';
import 'package:tuturno/features/aprende/widgets/ejercicio_dilo.dart';
import 'package:tuturno/features/aprende/widgets/ejercicio_eleccion.dart';
import 'package:tuturno/features/aprende/widgets/ejercicio_emparejar.dart';
import 'package:tuturno/features/aprende/widgets/ejercicio_ordenar.dart';
import 'package:tuturno/features/aprende/widgets/opcion.dart';
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/iconos/iconos.dart';

import 'ayudantes.dart';

/// Los iconos de TuTurno de un tipo que hay en pantalla.
Finder _tuIcono(TuIcono icono) => find.byWidgetPredicate((w) => w is IconoTuTurno && w.icono == icono);

const _eleccion = EjercicioEleccion(
  id: 'E-001',
  concepto: 'C-ser-oido',
  dificultad: 1,
  fuente: 'LO 1/1996, art. 9.2',
  validado: true,
  pregunta: '¿A partir de qué edad la ley considera que tienes madurez?',
  opciones: ['10 años', '12 años', '16 años'],
  correcta: 1,
  explicacion: 'A partir de los 12.',
);

const _vf = EjercicioVf(
  id: 'E-002',
  concepto: 'C-defensor',
  dificultad: 1,
  fuente: 'LO 3/1981, art. 10.1',
  validado: true,
  afirmacion: 'Para quejarte al Defensor del Pueblo necesitas un adulto.',
  correcta: false,
);

const _ordenar = EjercicioOrdenar(
  id: 'E-003',
  concepto: 'C-despues',
  dificultad: 2,
  fuente: 'LECrim, art. 703 bis',
  validado: true,
  enunciado: 'Ordena los pasos',
  pasos: ['Primero', 'Segundo', 'Tercero', 'Cuarto'],
);

const _emparejar = EjercicioEmparejar(
  id: 'E-004',
  concepto: 'C-sala-gesell',
  dificultad: 2,
  fuente: 'LECrim, art. 449 ter',
  validado: true,
  pares: [
    ('Sala Gesell', 'Sala preparada'),
    ('Equipo psicosocial', 'Hace la entrevista'),
    ('Grabación', 'Va al juicio'),
  ],
);

const _dilo = EjercicioDilo(
  id: 'E-005',
  concepto: 'C-ser-oido',
  dificultad: 3,
  fuente: 'LO 1/1996, art. 9',
  validado: true,
  pregunta: 'Explica con tus palabras qué significa el derecho a ser oído.',
  proposiciones: ['Idea uno', 'Idea dos'],
);

/// Un ejercicio solo, en una pantalla con el tema de la app y la voz falsa.
Future<void> _montar(
  WidgetTester tester,
  Widget ejercicio, {
  FakeStt? stt,
  FakeTts? tts,
  Brightness brillo = Brightness.light,
  Size tamano = movil,
  double escalaTexto = 1,
  bool desplazable = true,
}) async {
  tester.view.physicalSize = tamano * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      // Una clave por tema: así el segundo montaje empieza de cero.
      key: ValueKey(brillo),
      overrides: [sttProvider.overrideWithValue(stt ?? FakeStt()), ttsProvider.overrideWithValue(tts ?? FakeTts())],
      child: MaterialApp(
        theme: temaTuTurno(brillo),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(escalaTexto)),
          child: child!,
        ),
        home: Scaffold(
          body: desplazable
              ? SingleChildScrollView(padding: const EdgeInsets.all(16), child: ejercicio)
              : Align(alignment: Alignment.bottomCenter, child: ejercicio),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Envuelve un ejercicio para poder cambiar «revisado» desde el test.
class _ConRevision extends StatefulWidget {
  const _ConRevision({required this.constructor, super.key});

  final Widget Function(bool revisado) constructor;

  @override
  State<_ConRevision> createState() => _ConRevisionState();
}

class _ConRevisionState extends State<_ConRevision> {
  var revisado = false;

  void revisar() => setState(() => revisado = true);

  @override
  Widget build(BuildContext context) => widget.constructor(revisado);
}

void main() {
  group('Elección', () {
    testWidgets('al tocar una opción avisa con su posición original; correcta e incorrecta se marcan', (tester) async {
      final respuestas = <int>[];
      final clave = GlobalKey<_ConRevisionState>();
      await _montar(
        tester,
        _ConRevision(
          key: clave,
          constructor: (revisado) =>
              VistaEleccion(ejercicio: _eleccion, revisado: revisado, onRespuesta: respuestas.add),
        ),
      );
      expect(find.text(_eleccion.pregunta), findsOneWidget);
      for (final o in _eleccion.opciones) {
        expect(find.text(o), findsOneWidget);
      }

      await pulsar(tester, find.text('16 años'));
      expect(respuestas, [2]);
      expect(_eleccion.esCorrecta(respuestas.last), isFalse);
      await pulsar(tester, find.text('12 años'));
      expect(respuestas.last, 1);
      expect(_eleccion.esCorrecta(respuestas.last), isTrue);

      clave.currentState!.revisar();
      await tester.pumpAndSettle();
      final semantica = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp(r'12 años\. Respuesta correcta')), findsOneWidget);
      semantica.dispose();
      // Después de comprobar ya no se puede cambiar.
      await pulsar(tester, find.text('10 años'));
      expect(respuestas.last, 1);
    });

    testWidgets('si falla, la elegida queda marcada como incorrecta', (tester) async {
      final clave = GlobalKey<_ConRevisionState>();
      await _montar(
        tester,
        _ConRevision(
          key: clave,
          constructor: (revisado) => VistaEleccion(ejercicio: _eleccion, revisado: revisado, onRespuesta: (_) {}),
        ),
      );
      await pulsar(tester, find.text('10 años'));
      clave.currentState!.revisar();
      await tester.pumpAndSettle();
      final semantica = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp(r'10 años\. Tu respuesta, no es la correcta')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'12 años\. Respuesta correcta')), findsOneWidget);
      semantica.dispose();
      // Fallar no va en rojo (el rojo es de Ayuda): una bombilla de TuTurno, como en Vive el caso.
      expect(_tuIcono(TuIcono.idea), findsOneWidget);
      expect(_tuIcono(TuIcono.cruz), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      final tarjeta = tester.widget<TarjetaOpcion>(find.byKey(const ValueKey('opcion-0')));
      expect(tarjeta.estado, EstadoOpcion.incorrecta);
    });

    testWidgets('las opciones se barajan siempre igual para el mismo ejercicio', (tester) async {
      await _montar(tester, VistaEleccion(ejercicio: _eleccion, revisado: false, onRespuesta: (_) {}));
      final orden = barajar(3, semillaDe(_eleccion.id));
      final ys = [for (final i in orden) tester.getTopLeft(find.text(_eleccion.opciones[i])).dy];
      expect(ys, orderedEquals([...ys]..sort()));
    });
  });

  group('Verdadero o falso', () {
    testWidgets('los dos botones responden true y false', (tester) async {
      final respuestas = <bool>[];
      await _montar(tester, VistaVf(ejercicio: _vf, revisado: false, onRespuesta: respuestas.add));
      expect(find.text(_vf.afirmacion), findsOneWidget);
      await pulsar(tester, find.text('Verdadero'));
      await pulsar(tester, find.text('Falso'));
      expect(respuestas, [true, false]);
      expect(_vf.esCorrecta(respuestas.first), isFalse);
      expect(_vf.esCorrecta(respuestas.last), isTrue);
    });

    testWidgets('al comprobar se marca la correcta', (tester) async {
      final clave = GlobalKey<_ConRevisionState>();
      await _montar(
        tester,
        _ConRevision(
          key: clave,
          constructor: (revisado) => VistaVf(ejercicio: _vf, revisado: revisado, onRespuesta: (_) {}),
        ),
      );
      await pulsar(tester, find.text('Verdadero'));
      clave.currentState!.revisar();
      await tester.pumpAndSettle();
      final semantica = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Falso. Respuesta correcta'), findsOneWidget);
      expect(find.bySemanticsLabel('Verdadero. Tu respuesta, no es la correcta'), findsOneWidget);
      semantica.dispose();
      expect(_tuIcono(TuIcono.idea), findsOneWidget);
      expect(_tuIcono(TuIcono.check), findsOneWidget);
      expect(_tuIcono(TuIcono.cruz), findsNothing);
      expect(find.byIcon(Icons.cancel_rounded), findsNothing);
    });
  });

  group('Ordenar', () {
    testWidgets('empieza desordenado y se ordena con las flechas (alternativa accesible)', (tester) async {
      final respuestas = <List<int>>[];
      await _montar(tester, VistaOrdenar(ejercicio: _ordenar, revisado: false, onRespuesta: respuestas.add));
      final inicial = barajar(4, semillaDe(_ordenar.id), evitarIdentidad: true);
      expect(_ordenar.esCorrecta(inicial), isFalse);
      expect(find.byTooltip('Subir «${_ordenar.pasos[inicial.first]}»'), findsOneWidget);
      // Hasta mover algo no hay respuesta: se dice por qué aún no se puede comprobar (auditoría, P2-4).
      expect(find.text(textoMueveUnaTarjeta), findsOneWidget);

      await responder(tester, _ordenar, bien: true);
      expect(_ordenar.esCorrecta(respuestas.last), isTrue);
      expect(find.text(textoMueveUnaTarjeta), findsNothing);
      // En pantalla, de arriba abajo, en el orden correcto.
      final ys = [for (final p in _ordenar.pasos) tester.getTopLeft(find.text(p)).dy];
      expect(ys, orderedEquals([...ys]..sort()));
    });

    testWidgets('un orden equivocado no es correcto y, al comprobar, se marca lo que no va en su sitio', (
      tester,
    ) async {
      final respuestas = <List<int>>[];
      final clave = GlobalKey<_ConRevisionState>();
      await _montar(
        tester,
        _ConRevision(
          key: clave,
          constructor: (revisado) => VistaOrdenar(ejercicio: _ordenar, revisado: revisado, onRespuesta: respuestas.add),
        ),
      );
      await responder(tester, _ordenar, bien: false);
      expect(_ordenar.esCorrecta(respuestas.last), isFalse);
      clave.currentState!.revisar();
      await tester.pumpAndSettle();
      final semantica = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp(r'No va aquí')), findsWidgets);
      semantica.dispose();
      expect(find.byTooltip(RegExp('Subir')), findsNothing);
      // Lo que no va en su sitio lleva flechas («va en otro sitio»), no una cruz roja.
      expect(find.byIcon(Icons.swap_vert_rounded), findsWidgets);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('también se puede arrastrar desde el asa', (tester) async {
      final respuestas = <List<int>>[];
      await _montar(tester, VistaOrdenar(ejercicio: _ordenar, revisado: false, onRespuesta: respuestas.add));
      final asa = find.byIcon(Icons.drag_indicator_rounded).first;
      final gesto = await tester.startGesture(tester.getCenter(asa));
      await tester.pump(const Duration(milliseconds: 100));
      await gesto.moveBy(const Offset(0, 300));
      await tester.pump();
      await gesto.up();
      await tester.pumpAndSettle();
      expect(respuestas, isNotEmpty);
    });
  });

  group('Emparejar', () {
    testWidgets('tocando una de cada lado se forman parejas; todas bien es correcto', (tester) async {
      final respuestas = <Map<int, int>?>[];
      await _montar(tester, VistaEmparejar(ejercicio: _emparejar, revisado: false, onRespuesta: respuestas.add));
      expect(find.text('0 de 3'), findsOneWidget);
      await responder(tester, _emparejar, bien: true);
      expect(find.text('3 de 3'), findsOneWidget);
      expect(respuestas.last, isNotNull);
      expect(_emparejar.esCorrecta(respuestas.last!), isTrue);
    });

    testWidgets('parejas cambiadas no son correctas; tocar una pareja la deshace', (tester) async {
      final respuestas = <Map<int, int>?>[];
      await _montar(tester, VistaEmparejar(ejercicio: _emparejar, revisado: false, onRespuesta: respuestas.add));
      await responder(tester, _emparejar, bien: false);
      expect(_emparejar.esCorrecta(respuestas.last!), isFalse);

      await pulsar(tester, find.text('Sala Gesell'));
      expect(respuestas.last, isNull);
      expect(find.text('2 de 3'), findsOneWidget);
    });

    testWidgets('se puede empezar por la derecha', (tester) async {
      final respuestas = <Map<int, int>?>[];
      await _montar(tester, VistaEmparejar(ejercicio: _emparejar, revisado: false, onRespuesta: respuestas.add));
      await pulsar(tester, find.text('Hace la entrevista'));
      await pulsar(tester, find.text('Equipo psicosocial'));
      expect(find.text('1 de 3'), findsOneWidget);
    });

    testWidgets('cada pareja lleva su propio color, igual a los dos lados, en claro y en oscuro', (tester) async {
      for (final brillo in Brightness.values) {
        await _montar(
          tester,
          VistaEmparejar(ejercicio: _emparejar, revisado: false, onRespuesta: (_) {}),
          brillo: brillo,
        );
        Color? color(String clave) => tester.widget<TarjetaOpcion>(find.byKey(ValueKey(clave))).colorElegida;
        // Elegida sin pareja: el primario. Ninguna pareja lo usa, para no confundirlas.
        await pulsar(tester, find.byKey(const ValueKey('izquierda-0')));
        final primario = color('izquierda-0');
        await pulsar(tester, find.byKey(const ValueKey('izquierda-0')));

        await responder(tester, _emparejar, bien: true);
        final colores = [for (var i = 0; i < _emparejar.pares.length; i++) color('izquierda-$i')];
        expect(colores.toSet(), hasLength(_emparejar.pares.length), reason: '$brillo: colores repetidos');
        expect(colores, isNot(contains(primario)), reason: '$brillo: el primario es para la elegida');
        for (var i = 0; i < _emparejar.pares.length; i++) {
          expect(color('derecha-$i'), colores[i], reason: '$brillo: pareja $i');
        }
      }
    });
  });

  group('Dilo con tus palabras', () {
    testWidgets('con menos de tres palabras no se puede comprobar; con tres, sí', (tester) async {
      final respuestas = <String?>[];
      await _montar(tester, VistaDilo(ejercicio: _dilo, bloqueado: false, onRespuesta: respuestas.add));
      expect(find.text(_dilo.pregunta), findsOneWidget);
      expect(find.text(textoDiloAyuda), findsOneWidget);
      expect(find.text(textoDiloComprueba), findsOneWidget);
      await tester.enterText(campoDilo, 'Me escuchan');
      await tester.pump();
      expect(respuestas.last, isNull);
      expect(find.text('2 palabras'), findsOneWidget);
      await tester.enterText(campoDilo, 'Me tienen que escuchar');
      await tester.pump();
      expect(respuestas.last, 'Me tienen que escuchar');
      expect(find.text('4 palabras'), findsOneWidget);
    });

    testWidgets('el micrófono para la voz de la app, escucha y deja lo dictado en el campo para revisarlo', (
      tester,
    ) async {
      final stt = FakeStt();
      final tts = FakeTts();
      final respuestas = <String?>[];
      await _montar(
        tester,
        VistaDilo(ejercicio: _dilo, bloqueado: false, onRespuesta: respuestas.add),
        stt: stt,
        tts: tts,
      );
      await tester.tap(find.byKey(const ValueKey('micro-dilo')));
      await tester.pump();
      expect(tts.registro, contains('parar'));
      expect(stt.registro, ['inicializar', 'escuchar']);
      expect(find.text('Te escucho… Pulsa para parar'), findsOneWidget);

      stt.oir('tengo derecho a que me escuchen');
      await tester.pump();
      expect(find.text('tengo derecho a que me escuchen'), findsOneWidget);
      expect(find.text('Revisa lo que he entendido antes de comprobar.'), findsOneWidget);
      expect(respuestas.last, isNull, reason: 'mientras se dicta, la transcripción va a medias: no se comprueba');

      await tester.tap(find.byKey(const ValueKey('micro-dilo')));
      await tester.pumpAndSettle();
      expect(stt.registro.last, 'parar');
      expect(find.text('Pulsa para dictar'), findsOneWidget);
      expect(respuestas.last, 'tengo derecho a que me escuchen');
    });

    testWidgets('el halo del micrófono late con la voz sin mover nada de alrededor', (tester) async {
      final stt = FakeStt();
      await _montar(
        tester,
        VistaDilo(ejercicio: _dilo, bloqueado: false, onRespuesta: (_) {}),
        stt: stt,
      );
      final micro = find.byKey(const ValueKey('micro-dilo'));
      await tester.tap(micro);
      await tester.pump();
      final antes = tester.getRect(micro);
      final texto = find.text('Te escucho… Pulsa para parar');
      final posicion = tester.getTopLeft(texto);
      for (final nivel in [1.0, 0.0, 0.6]) {
        stt.nivel(nivel);
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.getRect(micro), antes, reason: 'nivel $nivel');
        expect(tester.getTopLeft(texto), posicion, reason: 'nivel $nivel');
      }
    });

    testWidgets('lo que llega del micrófono cuando ya se está corrigiendo no cambia el texto', (tester) async {
      final stt = FakeStt();
      final clave = GlobalKey<_ConRevisionState>();
      await _montar(
        tester,
        _ConRevision(
          key: clave,
          constructor: (revisado) => VistaDilo(ejercicio: _dilo, bloqueado: revisado, onRespuesta: (_) {}),
        ),
        stt: stt,
      );
      await tester.tap(find.byKey(const ValueKey('micro-dilo')));
      await tester.pump();
      stt.oir('que el juez me tiene que escuchar');
      await tester.pump();
      clave.currentState!.revisar();
      await tester.pump();
      stt.oir('que el juez me tiene que escuchar porque tengo doce años');
      await tester.pumpAndSettle();
      expect(find.text('que el juez me tiene que escuchar'), findsOneWidget);
    });

    testWidgets('si no hay micrófono, lo dice y el campo de texto sigue funcionando', (tester) async {
      final respuestas = <String?>[];
      await _montar(
        tester,
        VistaDilo(ejercicio: _dilo, bloqueado: false, onRespuesta: respuestas.add),
        stt: FakeStt(disponible: false),
      );
      await tester.tap(find.byKey(const ValueKey('micro-dilo')));
      await tester.pumpAndSettle();
      expect(find.text(mensajeVozDilo(ProblemaVoz.sinPermiso)), findsOneWidget);
      await tester.enterText(campoDilo, 'Lo escribo con mis palabras');
      await tester.pump();
      expect(respuestas.last, 'Lo escribo con mis palabras');
    });

    testWidgets('si la voz falla mientras escucha, avisa sin borrar lo escrito', (tester) async {
      final stt = FakeStt();
      await _montar(
        tester,
        VistaDilo(ejercicio: _dilo, bloqueado: false, onRespuesta: (_) {}),
        stt: stt,
      );
      await tester.enterText(campoDilo, 'Ya había escrito');
      await tester.tap(find.byKey(const ValueKey('micro-dilo')));
      await tester.pump();
      stt.oir('algo más');
      stt.fallar(ProblemaVoz.noTeOigo);
      await tester.pumpAndSettle();
      expect(find.text('Ya había escrito algo más'), findsOneWidget);
      expect(find.text(mensajeVozDilo(ProblemaVoz.noTeOigo)), findsOneWidget);
    });

    testWidgets('bloqueado no deja escribir ni dictar', (tester) async {
      await _montar(tester, VistaDilo(ejercicio: _dilo, bloqueado: true, onRespuesta: (_) {}));
      expect(find.byKey(const ValueKey('micro-dilo')), findsNothing);
      expect(tester.widget<TextField>(campoDilo).readOnly, isTrue);
    });
  });

  group('Panel de corrección', () {
    testWidgets('con letra 1,6 en un móvil estrecho, el título no se parte y los puntos bajan de línea', (
      tester,
    ) async {
      await _montar(
        tester,
        PanelCorreccion(tipo: TipoCorreccion.acierto, titulo: '¡Lo has clavado!', xp: 10, onContinuar: () {}),
        tamano: const Size(320, 640),
        escalaTexto: 1.6,
        desplazable: false,
      );
      expect(tester.takeException(), isNull);
      final titulo = find.byKey(const ValueKey('titulo-correccion'));
      final parrafo = tester.renderObject<RenderParagraph>(
        find.descendant(of: titulo, matching: find.byType(RichText)),
      );
      expect(parrafo.size.width, greaterThanOrEqualTo(parrafo.getMinIntrinsicWidth(double.infinity) - 0.5));
      expect(find.text('+10 XP'), findsOneWidget);
      expect(find.byKey(const ValueKey('tut-feliz')), findsOneWidget);
    });

    testWidgets('si se falla, Tut anima (nunca triste) y no hay rojo de error', (tester) async {
      await _montar(
        tester,
        PanelCorreccion(tipo: TipoCorreccion.fallo, titulo: '¡Casi!', onContinuar: () {}),
        desplazable: false,
      );
      expect(find.byKey(const ValueKey('tut-animo')), findsOneWidget);
      expect(find.byKey(const ValueKey('tut-triste')), findsNothing);
      expect(find.byWidgetPredicate((w) => w is MascotaTut && w.expresion == ExpresionTut.triste), findsNothing);
    });

    testWidgets('«Dilo» corregido en el móvil lo dice: «Corrección aproximada sin conexión»', (tester) async {
      await _montar(
        tester,
        PanelCorreccion(
          tipo: TipoCorreccion.fallo,
          titulo: 'Vas por buen camino',
          aproximada: true,
          onContinuar: () {},
        ),
        desplazable: false,
      );
      expect(find.text(textoDiloAproximada), findsOneWidget);
    });
  });

  test('cuenta palabras sin contar signos ni espacios', () {
    expect(contarPalabras(''), 0);
    expect(contarPalabras('  ¡Hola!  '), 1);
    expect(contarPalabras('Me escuchan, ¿verdad? Sí.'), 4);
    expect(contarPalabras('Tengo 12 años'), 3);
  });
}
