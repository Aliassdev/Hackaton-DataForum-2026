import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/demo.dart';
import 'package:tuturno/core/entrada.dart';
import 'package:tuturno/core/progreso.dart';
import 'package:tuturno/core/providers.dart';

// Estado de la demo (plan v2, demo §3.1).

/// Lo que hay en assets/mock/content: ids de lecciones, conceptos y cartas.
({Set<String> lecciones, Set<String> conceptos, Set<String> cartas}) _contenido() {
  Iterable<File> json(String carpeta) =>
      Directory('assets/mock/content/$carpeta').listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
  final lecciones = <String>{};
  final conceptos = <String>{};
  final cartas = <String>{};
  for (final f in json('lecciones')) {
    final unidad = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    conceptos.addAll((unidad['conceptos'] as List).cast<String>());
    lecciones.addAll([for (final l in unidad['lecciones'] as List) (l as Map)['id'] as String]);
  }
  for (final f in json('juego')) {
    final caso = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    cartas.addAll([for (final c in caso['cartas'] as List) (c as Map)['id'] as String]);
  }
  return (lecciones: lecciones, conceptos: conceptos, cartas: cartas);
}

void main() {
  group('progresoDemo', () {
    final ahora = DateTime(2026, 10, 22, 17, 45);

    test('los valores de la demo, con la racha de 4 y la última lección ayer', () {
      final p = progresoDemo(ahora);
      expect(p.xp, 340);
      expect(p.racha, 4);
      expect(p.mejorRacha, 4);
      expect(p.ultimoDiaConLeccion, DateTime(2026, 10, 21));
      expect(p.leccionesCompletadas, {'U1-L1', 'U1-L2'});
      expect(p.dominio, {'C-ser-oido': 0.8, 'C-fiscalia': 0.6, 'C-comunicar-violencia': 0.4});
      expect(p.ultimaPractica.keys, unorderedEquals(p.dominio.keys));
      for (final practica in p.ultimaPractica.values) {
        expect(diasEntre(practica, ahora), 3);
      }
      expect(p.cartas, {'R-ser-escuchada', 'R-sin-cruzarte'});
      expect(p.casosTerminados, isEmpty);
      expect(p.descansoUsado, isNull);
      expect(p.personasConocidas, isEmpty);
    });

    test('sin las cartas que se ganan en directo (la de Lucía en la Sala Gesell, la primera)', () {
      final cartas = progresoDemo(ahora).cartas;
      for (final enDirecto in ['R-una-sola-vez', 'R-entender', 'R-acompanada', 'R-familia']) {
        expect(cartas, isNot(contains(enDirecto)));
      }
    });

    test('todos sus ids existen en assets/mock/content', () {
      final contenido = _contenido();
      final p = progresoDemo(ahora);
      expect(contenido.lecciones, containsAll(p.leccionesCompletadas));
      expect(contenido.conceptos, containsAll(p.dominio.keys));
      expect(contenido.cartas, containsAll(p.cartas));
      expect(contenido.cartas, contains('R-una-sola-vez'));
    });

    test('es el mismo durante todo el día (preparar la demo dos veces deja lo mismo)', () {
      final temprano = progresoDemo(DateTime(2026, 10, 22, 0, 5)).toJson();
      expect(progresoDemo(DateTime(2026, 10, 22, 23, 59)).toJson(), temprano);
      expect(progresoDemo(ahora).toJson(), temprano);
    });

    test('al cambiar de mes, ayer y hace tres días también cuadran', () {
      final p = progresoDemo(DateTime(2026, 11, 1, 10));
      expect(p.ultimoDiaConLeccion, DateTime(2026, 10, 31));
      expect(p.ultimaPractica.values.toSet(), {DateTime(2026, 10, 29, 12)});
    });

    test('la racha se ve pendiente hoy y con una lección en directo sube a 5, que es la mejor', () async {
      expect(
        estadoRacha(progresoDemo(ahora), ahora),
        const EstadoRacha(dias: 4, mejor: 4, tipo: TipoRacha.pendienteHoy),
      );

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs), relojProvider.overrideWithValue(() => ahora)],
      );
      addTearDown(c.dispose);
      await c.read(progresoProvider.notifier).reemplazar(progresoDemo(ahora));
      await c.read(progresoProvider.notifier).completarLeccion('U2-L2');
      expect(c.read(progresoProvider).racha, 5);
      expect(c.read(progresoProvider).mejorRacha, 5);
      expect(c.read(progresoProvider).xp, 340);
    });
  });

  test('entradaDemoSergio: 13 años · penal · víctima · durante', () {
    expect(entradaDemoSergio.variablesAgente(), {
      'edad': '13',
      'procedimiento': 'penal',
      'rol': 'victima',
      'fase': 'durante',
    });
  });

  group('escenaInicialProvider', () {
    late ProviderContainer c;
    setUp(() {
      c = ProviderContainer();
      addTearDown(c.dispose);
    });

    test('empieza sin atajo', () {
      expect(c.read(escenaInicialProvider), isNull);
      expect(c.read(escenaInicialProvider.notifier).consumir('caso-sala-gesell'), isNull);
    });

    test('la escena fijada se consume una sola vez, y solo en su caso', () async {
      final atajo = c.read(escenaInicialProvider.notifier)..fijar('caso-sala-gesell', 'S5');
      expect(c.read(escenaInicialProvider), (casoId: 'caso-sala-gesell', escenaId: 'S5'));
      expect(atajo.consumir('caso-acoso-escolar'), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(escenaInicialProvider), isNotNull, reason: 'sigue esperando a su caso');
      expect(atajo.consumir('caso-sala-gesell'), 'S5');
      expect(atajo.consumir('caso-sala-gesell'), isNull, reason: 'ya se ha consumido, aunque el estado aún no lo diga');
      await Future<void>.delayed(Duration.zero);
      expect(c.read(escenaInicialProvider), isNull);
      expect(atajo.consumir('caso-sala-gesell'), isNull);
    });

    test('fijar otra justo después de consumir no se pierde', () async {
      final atajo = c.read(escenaInicialProvider.notifier)..fijar('caso-sala-gesell', 'S5');
      expect(atajo.consumir('caso-sala-gesell'), 'S5');
      atajo.fijar('caso-sala-gesell', 'S9');
      await Future<void>.delayed(Duration.zero);
      expect(c.read(escenaInicialProvider), (casoId: 'caso-sala-gesell', escenaId: 'S9'));
      expect(atajo.consumir('caso-sala-gesell'), 'S9');
    });

    test('el último atajo manda', () {
      final atajo = c.read(escenaInicialProvider.notifier)
        ..fijar('caso-sala-gesell', 'S5')
        ..fijar('caso-sala-gesell', 'S9');
      expect(atajo.consumir('caso-sala-gesell'), 'S9');
    });

    test('solo en memoria: otro arranque empieza sin atajo', () {
      c.read(escenaInicialProvider.notifier).fijar('caso-sala-gesell', 'S5');
      final otra = ProviderContainer();
      addTearDown(otra.dispose);
      expect(otra.read(escenaInicialProvider), isNull);
    });
  });

  group('escenaInicialProvider en una pantalla', () {
    testWidgets('consumir al abrir el caso (initState y build) no rompe nada', (tester) async {
      final contenedor = ProviderContainer();
      addTearDown(contenedor.dispose);
      contenedor.read(escenaInicialProvider.notifier).fijar('caso-sala-gesell', 'S5');
      final vistas = <String?>[];
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: contenedor,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: _CasoDePrueba(casoId: 'caso-sala-gesell', vistas: vistas),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(vistas.first, 'S5', reason: 'en initState');
      expect(vistas.skip(1), everyElement(isNull), reason: 'en build ya no queda');
      expect(contenedor.read(escenaInicialProvider), isNull);
    });
  });

  group('usarEjemploPreguntaProvider', () {
    test('apagado al empezar; se enciende y se apaga', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(usarEjemploPreguntaProvider), isFalse);
      c.read(usarEjemploPreguntaProvider.notifier).cambiar(true);
      expect(c.read(usarEjemploPreguntaProvider), isTrue);
      c.read(usarEjemploPreguntaProvider.notifier).cambiar(false);
      expect(c.read(usarEjemploPreguntaProvider), isFalse);
    });
  });

  test('el ticket de Sergio usa los valores de los enums (no cambia lo que se guarda)', () {
    expect(entradaDemoSergio.procedimiento?.valor, 'penal');
    expect(entradaDemoSergio.rol, RolEntrada.victima);
    expect(entradaDemoSergio.fase, Fase.durante);
  });
}

/// Como CasoScreen: consume el atajo en initState (y lo vuelve a intentar en build, que ya no encuentra nada).
class _CasoDePrueba extends ConsumerStatefulWidget {
  const _CasoDePrueba({required this.casoId, required this.vistas});

  final String casoId;
  final List<String?> vistas;

  @override
  ConsumerState<_CasoDePrueba> createState() => _CasoDePruebaState();
}

class _CasoDePruebaState extends ConsumerState<_CasoDePrueba> {
  @override
  void initState() {
    super.initState();
    widget.vistas.add(ref.read(escenaInicialProvider.notifier).consumir(widget.casoId));
  }

  @override
  Widget build(BuildContext context) {
    widget.vistas.add(ref.read(escenaInicialProvider.notifier).consumir(widget.casoId));
    return Text('${ref.watch(escenaInicialProvider)}');
  }
}
