// Capturas de «Mi situación» con tres perfiles distintos (Lucía, Sergio y Sara), en claro y en oscuro, con las fuentes
// reales y el contenido que lleva la app. Para revisar el diseño a ojo; no se ejecuta por defecto:
//
//   CAPTURAS=build/capturas-situacion flutter test test/features/situacion/capturas_situacion_test.dart
//
// En flutter_test las sombras se pintan sin desenfoque: en el móvil salen suaves.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fuentes_reales.dart';
import 'ayudantes.dart';

final _destino = Platform.environment['CAPTURAS'];

/// Una pantalla alta para que se vea mucho en cada captura (el móvil se desplaza; aquí, se ve más de una vez).
const _alto = Size(390, 1600);

void main() {
  setUpAll(() async {
    if (_destino != null) await cargarFuentesReales();
  });

  Future<void> recorrido(
    WidgetTester tester, {
    required String nombre,
    required Map<String, Object> perfil,
    required Brightness brillo,
    String ruta = '/situacion/victima',
  }) async {
    tester.platformDispatcher.platformBrightnessTestValue = brillo;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final sufijo = brillo == Brightness.dark ? '-oscuro' : '';
    final carpeta = _destino!;
    final router = await arrancarSituacion(tester, preferencias: perfil, tamano: _alto);
    await abrir(tester, router, ruta);
    await capturar(tester, carpeta, '$nombre-1-portada$sufijo');

    // Tu camino, con el paso de su momento abierto.
    final camino = find.textContaining('TU CAMINO');
    await tester.ensureVisible(camino);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -80));
    await tester.pumpAndSettle();
    final suyo = find.bySemanticsLabel(RegExp(r'^Paso \d+ de \d+: .*Estás en esta parte'));
    if (suyo.evaluate().isNotEmpty && find.text('Qué pasa').evaluate().isEmpty) {
      await tester.tap(suyo.first);
      await tester.pumpAndSettle();
    }
    await capturar(tester, carpeta, '$nombre-2-camino$sufijo');

    await tester.ensureVisible(find.textContaining('TUS DERECHOS'));
    await tester.pumpAndSettle();
    await capturar(tester, carpeta, '$nombre-3-derechos$sufijo');

    await tester.ensureVisible(find.textContaining('LO QUE TE PREOCUPA'));
    await tester.pumpAndSettle();
    await capturar(tester, carpeta, '$nombre-4-preocupa$sufijo');

    await tester.ensureVisible(find.textContaining('TU DÍA'));
    await tester.pumpAndSettle();
    await capturar(tester, carpeta, '$nombre-5-dia$sufijo');
  }

  for (final brillo in Brightness.values) {
    testWidgets('Lucía (${brillo.name})', (tester) async {
      await recorrido(tester, nombre: 'lucia', perfil: perfilLucia(), brillo: brillo);
    }, skip: _destino == null);

    testWidgets('Sergio (${brillo.name})', (tester) async {
      await recorrido(tester, nombre: 'sergio', perfil: perfilSergio(), brillo: brillo);
    }, skip: _destino == null);

    testWidgets('Sara (${brillo.name})', (tester) async {
      await recorrido(tester, nombre: 'sara', perfil: perfilSara(), brillo: brillo);
    }, skip: _destino == null);
  }

  Future<void> otras(WidgetTester tester, Brightness brillo) async {
    tester.platformDispatcher.platformBrightnessTestValue = brillo;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final sufijo = brillo == Brightness.dark ? '-oscuro' : '';
    final carpeta = _destino!;
    final router = await arrancarSituacion(
      tester,
      tamano: const Size(390, 1400),
      preferencias: {
        ...perfilLucia(),
        'mis_preguntas':
            '[{"id":"1","texto":"Un descanso si lo necesitas","tipo":"pedir","origen":"Tu declaración",'
            '"fuentes":["Ley 4/2015, art. 25.1"]},{"id":"2","texto":"¿Quién va a estar en la sala?","tipo":"preguntar",'
            '"hecho":true}]',
      },
    );
    await abrir(tester, router, '/situacion/elegir');
    await capturar(tester, carpeta, 'otras-1-portada$sufijo');
    await abrir(tester, router, '/situacion/escuchado_familia');
    await capturar(tester, carpeta, 'otras-2-familia$sufijo');
    await tocar(tester, find.text('Cambiar mi ticket'));
    await capturar(tester, carpeta, 'otras-3-ticket$sufijo');
    await abrir(tester, router, '/mis-preguntas');
    await capturar(tester, carpeta, 'otras-4-mis-preguntas$sufijo');
    await abrir(tester, router, '/mis-preguntas/ensenar');
    await capturar(tester, carpeta, 'otras-5-ensenar$sufijo');
  }

  for (final brillo in Brightness.values) {
    testWidgets('portada, «Me van a escuchar», «Tu ticket», «Mis preguntas» y «Enseñar en grande» (${brillo.name})', (
      tester,
    ) async {
      await otras(tester, brillo);
    }, skip: _destino == null);
  }
}
