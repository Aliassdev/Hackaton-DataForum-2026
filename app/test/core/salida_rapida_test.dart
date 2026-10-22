import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/providers.dart';
import 'package:tuturno/core/salida_rapida.dart';
import 'package:tuturno/core/voz/tts.dart';
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/salida_rapida_button.dart';

// «Salir rápido» (plan v2, producto §5.3), con la plataforma y la voz falsas.

class _SalidaFalsa implements SalidaPlataforma {
  _SalidaFalsa(this.registro, {this.falla = false});

  final List<String> registro;
  final bool falla;
  int salidas = 0;

  @override
  Future<void> salir() async {
    salidas++;
    registro.add('salir');
    if (falla) throw PlatformException(code: 'no');
  }
}

class _TtsFalso implements Tts {
  _TtsFalso(this.registro, {this.falla = false});

  final List<String> registro;
  final bool falla;
  int paradas = 0;
  final _hablando = ValueNotifier(true);

  @override
  ValueListenable<bool> get hablando => _hablando;

  @override
  Future<void> hablar(String texto, {double? velocidad}) async {}

  @override
  Future<void> parar() async {
    paradas++;
    registro.add('tts.parar');
    _hablando.value = false;
    if (falla) throw StateError('sin motor de voz');
  }
}

/// Montaje con dos rutas: '/' con el botón (y una sonda para llamar a [salirRapido]) y '/salida', la pantalla neutra.
class _Montaje {
  _Montaje(this.registro, this.salida, this.tts, this.router, this.prefs);

  final List<String> registro;
  final _SalidaFalsa salida;
  final _TtsFalso tts;
  final GoRouter router;
  final SharedPreferences prefs;

  /// El context y el ref de la sonda, para llamar a [salirRapido] a mano.
  late BuildContext contexto;
  late WidgetRef ref;

  String get ruta => router.routerDelegate.currentConfiguration.uri.path;
}

Future<_Montaje> _montar(
  WidgetTester tester, {
  Brightness brillo = Brightness.light,
  bool compacto = false,
  bool fallaSalida = false,
  bool fallaVoz = false,
}) async {
  SharedPreferences.setMockInitialValues({'progreso': '{"xp": 120}', 'mis_preguntas': '[]'});
  final prefs = await SharedPreferences.getInstance();
  final registro = <String>[];
  final salida = _SalidaFalsa(registro, falla: fallaSalida);
  final tts = _TtsFalso(registro, falla: fallaVoz);
  late final _Montaje montaje;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SalidaRapidaButton(compacto: compacto),
                Consumer(
                  builder: (context, ref, _) {
                    montaje
                      ..contexto = context
                      ..ref = ref;
                    return TextButton(
                      key: const Key('sonda'),
                      onPressed: () => unawaited(salirRapido(context, ref)),
                      child: const Text('Sonda'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      GoRoute(
        path: rutaSalida,
        builder: (context, state) {
          registro.add('pantalla neutra');
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  montaje = _Montaje(registro, salida, tts, router, prefs);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        salidaPlataformaProvider.overrideWithValue(salida),
        ttsProvider.overrideWithValue(tts),
      ],
      child: MaterialApp.router(
        theme: temaTuTurno(Brightness.light),
        darkTheme: temaTuTurno(Brightness.dark),
        themeMode: brillo == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return montaje;
}

void main() {
  group('salirRapido', () {
    testWidgets('para la voz, enseña la pantalla neutra y después sale una sola vez', (tester) async {
      final m = await _montar(tester);
      await tester.tap(find.byKey(const Key('sonda')));
      await tester.pumpAndSettle();

      expect(m.ruta, rutaSalida);
      expect(m.tts.paradas, 1);
      expect(m.salida.salidas, 1);
      expect(m.registro.first, 'tts.parar');
      expect(m.registro.indexOf('pantalla neutra'), lessThan(m.registro.indexOf('salir')));
      expect(find.byType(SalidaRapidaButton), findsNothing, reason: 'TuTurno ya no está en pantalla');
    });

    testWidgets('no borra nada', (tester) async {
      final m = await _montar(tester);
      await tester.tap(find.byKey(const Key('sonda')));
      await tester.pumpAndSettle();
      expect(m.prefs.getString('progreso'), '{"xp": 120}');
      expect(m.prefs.getString('mis_preguntas'), '[]');
    });

    testWidgets('si la voz falla al parar, sale igual', (tester) async {
      final m = await _montar(tester, fallaVoz: true);
      await tester.tap(find.byKey(const Key('sonda')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(m.ruta, rutaSalida);
      expect(m.salida.salidas, 1);
    });

    testWidgets('si la plataforma no deja salir, se queda la pantalla neutra sin errores', (tester) async {
      final m = await _montar(tester, fallaSalida: true);
      await tester.tap(find.byKey(const Key('sonda')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(m.ruta, rutaSalida);
      expect(m.salida.salidas, 1);
    });

    testWidgets('el Future de salirRapido termina después de salir', (tester) async {
      final m = await _montar(tester);
      var terminado = false;
      unawaited(salirRapido(m.contexto, m.ref).then((_) => terminado = true));
      expect(m.tts.paradas, 1, reason: 'la voz se para al momento');
      expect(m.salida.salidas, 0, reason: 'antes, la pantalla neutra en pantalla');
      await tester.pumpAndSettle();
      expect(terminado, isTrue);
      expect(m.salida.salidas, 1);
      expect(m.ruta, rutaSalida);
    });
  });

  group('SalidaRapidaButton', () {
    for (final brillo in Brightness.values) {
      for (final compacto in [false, true]) {
        testWidgets('${brillo.name}${compacto ? ', compacto' : ''}: neutro, nunca rojo, con su etiqueta y 48 px', (
          tester,
        ) async {
          final m = await _montar(tester, brillo: brillo, compacto: compacto);
          final contexto = tester.element(find.byType(SalidaRapidaButton));
          final esquema = Theme.of(contexto).colorScheme;

          final boton = tester.widget<FilledButton>(
            find.descendant(
              of: find.byType(SalidaRapidaButton),
              matching: find.byWidgetPredicate((w) => w is FilledButton),
            ),
          );
          final fondo = boton.style!.backgroundColor!.resolve({})!;
          expect(fondo, esquema.inverseSurface);
          expect(fondo, brillo == Brightness.light ? ColoresMarca.azulNoche : ColoresMarca.papel);
          for (final rojo in [contexto.colores.ayuda, esquema.error, ColoresMarca.rojoAyuda]) {
            expect(fondo, isNot(rojo));
          }
          expect(boton.style!.foregroundColor!.resolve({}), esquema.onInverseSurface);

          expect(find.text('Salir rápido'), findsOneWidget);
          expect(find.bySemanticsLabel(etiquetaSalidaRapida), findsOneWidget);
          expect(
            tester.getSemantics(find.byType(SalidaRapidaButton)),
            isSemantics(label: etiquetaSalidaRapida, isButton: true, hasTapAction: true),
          );
          expect(tester.getSize(find.byType(SalidaRapidaButton)).height, greaterThanOrEqualTo(48));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));

          await tester.tap(find.byType(SalidaRapidaButton));
          await tester.pumpAndSettle();
          expect(m.ruta, rutaSalida);
          expect(m.salida.salidas, 1);
          expect(m.tts.paradas, 1);
        });
      }
    }

    testWidgets('con letra grande no se corta', (tester) async {
      tester.view.physicalSize = const Size(360, 640) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: temaTuTurno(Brightness.light),
            home: const MediaQuery(
              data: MediaQueryData(size: Size(360, 640), textScaler: TextScaler.linear(1.6)),
              child: Scaffold(
                body: Padding(
                  padding: EdgeInsets.all(Espacio.m),
                  child: Column(children: [SalidaRapidaButton(), SalidaRapidaButton(compacto: true)]),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Salir rápido'), findsNWidgets(2));
    });
  });

  group('plataforma por defecto', () {
    testWidgets('fuera de la web cierra la actividad con SystemNavigator.pop', (tester) async {
      final llamadas = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (llamada) async {
        llamadas.add(llamada.method);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      final contenedor = ProviderContainer();
      addTearDown(contenedor.dispose);
      final salida = contenedor.read(salidaPlataformaProvider);
      expect(salida, isA<SalidaPlataformaPorDefecto>());
      await salida.salir();
      expect(llamadas, ['SystemNavigator.pop']);
    });
  });
}
