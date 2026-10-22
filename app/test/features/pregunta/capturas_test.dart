// Capturas de «Pregunta» con las fuentes reales, para revisar el diseño (y para los PR). No se ejecuta por defecto:
//
//   CAPTURAS=build/capturas flutter test test/features/pregunta/capturas_test.dart
//
// En flutter_test las sombras se pintan sin desenfoque (debugDisableShadows): en el móvil salen suaves.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tuturno/core/api/models.dart';
import 'package:tuturno/features/pregunta/pregunta_screen.dart';
import 'package:tuturno/tema.dart';

import 'capturas_comunes.dart';
import 'fakes.dart';

Future<(ApiGrabadora, FakeStt)> _abrir(
  WidgetTester tester, {
  Brightness brillo = Brightness.light,
  RolProceso? situacion,
  double escala = 1,
  Size tamano = const Size(412, 915),
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = tamano * 2;
  addTearDown(tester.view.reset);
  final api = ApiGrabadora();
  final stt = FakeStt();
  final router = GoRouter(
    initialLocation: situacion == null ? '/pregunta' : '/pregunta?situacion=${situacion.name}',
    routes: [
      GoRoute(
        path: '/pregunta',
        builder: (context, state) =>
            PreguntaScreen(situacion: RolProceso.values.asNameMap()[state.uri.queryParameters['situacion']]),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: await overridesDePrueba(api: api, stt: stt, tts: FakeTts()),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: temaTuTurno(brillo),
        locale: const Locale('es', 'ES'),
        supportedLocales: const [Locale('es', 'ES')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(escala)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (api, stt);
}

Future<void> _preguntar(WidgetTester tester, String texto) async {
  await tester.enterText(find.byKey(const Key('campo-pregunta')), texto);
  await tester.pump();
  await tester.tap(find.byKey(const Key('boton-enviar')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (destinoCapturas != null) await cargarFuentesReales();
  });

  for (final brillo in Brightness.values) {
    final sufijo = brillo == Brightness.dark ? '-oscuro' : '';

    testWidgets('capturas de Pregunta ($sufijo)', (tester) async {
      await _abrir(tester, brillo: brillo);
      await capturar(tester, 'pregunta-01-vacia$sufijo');

      await _preguntar(tester, 'Si tengo 13 años y hago algo malo, ¿me pueden juzgar?');
      await capturar(tester, 'pregunta-02-respuesta$sufijo');

      await _preguntar(tester, 'Me pegaron en el recreo');
      await capturar(tester, 'pregunta-03-hechos$sufijo');

      await _preguntar(tester, 'A veces pienso que no quiero vivir');
      await capturar(tester, 'pregunta-04-crisis$sufijo');
    }, skip: destinoCapturas == null);

    testWidgets('capturas de la voz y la espera ($sufijo)', (tester) async {
      final (api, stt) = await _abrir(tester, brillo: brillo, situacion: RolProceso.testigo);
      await capturar(tester, 'pregunta-05-testigo$sufijo');

      await tester.tap(find.byKey(const Key('boton-micro')));
      await tester.pump();
      stt.oir('qué es la sala gesell');
      stt.volumen(0.7);
      await tester.pump(const Duration(milliseconds: 500));
      await capturar(tester, 'pregunta-06-escuchando$sufijo');

      await tester.tap(find.byKey(const Key('boton-micro')));
      await tester.pumpAndSettle();
      api.pausa = Completer<void>();
      await tester.tap(find.byKey(const Key('boton-enviar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await capturar(tester, 'pregunta-07-esperando$sufijo');
      api.pausa!.complete();
      await tester.pumpAndSettle();
      await capturar(tester, 'pregunta-08-respuesta-testigo$sufijo');
    }, skip: destinoCapturas == null);
  }

  testWidgets('capturas con letra grande en un móvil pequeño', (tester) async {
    final (api, _) = await _abrir(tester, escala: 1.3 * 1.3, tamano: const Size(360, 740));
    await capturar(tester, 'pregunta-10-grande-vacia');
    await _preguntar(tester, 'Tengo miedo de volver a casa');
    await capturar(tester, 'pregunta-11-grande-crisis');
    api.errores.add(errorApi);
    await _preguntar(tester, 'Quiero morir');
    await capturar(tester, 'pregunta-12-grande-sin-conexion');
  }, skip: destinoCapturas == null);
}
