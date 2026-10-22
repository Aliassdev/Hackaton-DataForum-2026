// Capturas de Aprende con las fuentes reales, para revisar el diseño y para el PR («El PR tiene una captura»,
// sección 20). No se ejecuta por defecto:
//
//   CAPTURAS=build/capturas-aprende flutter test test/features/aprende/capturas_test.dart
//
// En flutter_test las sombras se pintan sin desenfoque: en el móvil salen suaves.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/api/tuturno_api.dart';
import 'package:tuturno/features/aprende/modelos.dart';

import 'ayudantes.dart';

final _destino = Platform.environment['CAPTURAS'];

Future<void> _cargarFuentes() async {
  Future<void> cargar(String familia, List<String> rutas) async {
    final cargador = FontLoader(familia);
    for (final ruta in rutas) {
      cargador.addFont(Future.value(ByteData.sublistView(File(ruta).readAsBytesSync())));
    }
    await cargador.load();
  }

  await cargar('AtkinsonHyperlegible', [
    'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
    'assets/fonts/AtkinsonHyperlegible-Bold.ttf',
    'assets/fonts/AtkinsonHyperlegible-Italic.ttf',
    'assets/fonts/AtkinsonHyperlegible-BoldItalic.ttf',
  ]);
  await cargar('LondrinaSolid', ['assets/fonts/LondrinaSolid-Regular.ttf', 'assets/fonts/LondrinaSolid-Black.ttf']);
  final flutter =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final iconos = '$flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  if (File(iconos).existsSync()) await cargar('MaterialIcons', [iconos]);
}

Future<void> _capturar(WidgetTester tester, String nombre, {bool esperar = true}) async {
  if (esperar) await tester.pumpAndSettle();
  final capa = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final imagen = await capa.toImage(Offset.zero & tester.view.physicalSize);
    final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
    File('$_destino/$nombre.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    if (_destino != null) await _cargarFuentes();
  });

  final ejercicios = ejerciciosDeEjemplo();

  Future<void> recorrido(WidgetTester tester, Brightness brillo) async {
    final sufijo = brillo == Brightness.dark ? '-oscuro' : '';
    await montar(tester, repo: repoDeEjemplo(glosario: true), brillo: brillo);
    await _capturar(tester, '01-mapa$sufijo');

    await montar(
      tester,
      repo: repoDeEjemplo(glosario: true),
      brillo: brillo,
      preferencias: progresoGuardado(
        xp: 185,
        racha: 3,
        ultimoDia: DateTime(2026, 10, 21),
        lecciones: ['U1-L1', 'U1-L2'],
        dominio: {'C-ser-oido': 0.97, 'C-fiscalia': 0.82, 'C-defensor': 0.55, 'C-abogado-gratis': 0.2},
      ),
    );
    await _capturar(tester, '02-mapa-progreso$sufijo');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await _capturar(tester, '03-mapa-abajo$sufijo');

    await montar(tester, repo: repoDeEjemplo(glosario: true), brillo: brillo, ruta: '/aprende/leccion/U1-L1');
    final e101 = ejercicios['E-101'] as EjercicioEleccion;
    await tester.tap(find.byKey(ValueKey('opcion-${e101.correcta}')));
    await _capturar(tester, '04-eleccion$sufijo');
    await tester.tap(botonComprobar);
    await _capturar(tester, '05-acierto$sufijo');
    await tester.tap(botonContinuar);
    await tester.pumpAndSettle();
    await responderYComprobar(tester, ejercicios['E-102']!, bien: false);
    await _capturar(tester, '06-fallo$sufijo');
    await tester.tap(botonContinuar);
    await tester.pumpAndSettle();
    await responder(tester, ejercicios['E-103']!, bien: true);
    await _capturar(tester, '07-vf$sufijo');
    await tester.tap(botonComprobar);
    await tester.pumpAndSettle();
    await tester.tap(botonContinuar);
    await tester.pumpAndSettle();
    await responderYComprobar(tester, ejercicios['E-104']!, bien: true);
    await tester.tap(botonContinuar);
    await tester.pumpAndSettle();
    // Emparejar a medias.
    await tester.tap(find.byKey(const ValueKey('izquierda-0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('derecha-0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('izquierda-1')));
    await _capturar(tester, '08-emparejar$sufijo');
    await responder(tester, ejercicios['E-105']!, bien: true);
    await tester.tap(botonComprobar);
    await tester.pumpAndSettle();
    await tester.tap(botonContinuar);
    await tester.pumpAndSettle();
    await responder(tester, ejercicios['E-106']!, bien: true);
    await _capturar(tester, '09-dilo$sufijo');
    await tester.tap(botonComprobar);
    await _capturar(tester, '10-dilo-ideas$sufijo');
    await tester.tap(botonContinuar);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    await _capturar(tester, '11-celebracion-confeti$sufijo', esperar: false);
    await _capturar(tester, '12-celebracion$sufijo');

    await montar(
      tester,
      repo: repoDeEjemplo(glosario: true),
      brillo: brillo,
      ruta: '/aprende/leccion/U1-L3',
      demo: true,
    );
    for (final id in ['E-113', 'E-114', 'E-115']) {
      await responderYComprobar(tester, ejercicios[id]!, bien: true);
      await tester.tap(botonContinuar);
      await tester.pumpAndSettle();
    }
    await _capturar(tester, '13-ordenar$sufijo');
    await responderYComprobar(tester, ejercicios['E-116']!, bien: false);
    await _capturar(tester, '14-ordenar-fallo$sufijo');

    // «Dilo»: mientras revisa, sin conexión (con «Volver a intentarlo») y con algo que suena a peligro.
    final api = ApiDePrueba()..pausa = Completer<void>();
    await montar(
      tester,
      repo: repoDeEjemplo(glosario: true),
      brillo: brillo,
      ruta: '/aprende/leccion/dilo-U1-L1',
      demo: true,
      api: api,
    );
    await responder(tester, ejercicios['E-106']!, bien: true);
    await tester.tap(botonComprobar);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _capturar(tester, '15-dilo-revisando$sufijo', esperar: false);
    api.error = const ApiException('HTTP_502', ApiException.mensajeSeguro);
    api.pausa!.complete();
    await _capturar(tester, '16-dilo-sin-conexion$sufijo');

    await montar(
      tester,
      repo: repoDeEjemplo(glosario: true),
      brillo: brillo,
      ruta: '/aprende/leccion/dilo-U1-L1',
      demo: true,
    );
    await tester.enterText(campoDilo, 'quiero morir');
    await tester.pumpAndSettle();
    await tester.tap(botonComprobar);
    await _capturar(tester, '17-dilo-ayuda$sufijo');
  }

  testWidgets('capturas en tema claro', (tester) async {
    await recorrido(tester, Brightness.light);
  }, skip: _destino == null);

  testWidgets('capturas en tema oscuro', (tester) async {
    await recorrido(tester, Brightness.dark);
  }, skip: _destino == null);

  testWidgets('capturas con letra grande en un móvil pequeño', (tester) async {
    await montar(tester, repo: repoDeEjemplo(glosario: true), escalaTexto: 1.3, tamano: const Size(360, 640));
    await _capturar(tester, '20-mapa-letra-grande');
    await montar(
      tester,
      repo: repoDeEjemplo(glosario: true),
      escalaTexto: 1.3,
      tamano: const Size(360, 640),
      ruta: '/aprende/leccion/U2-L2',
      demo: true,
    );
    await responderYComprobar(tester, ejercicios['E-207']!, bien: false);
    await _capturar(tester, '21-panel-letra-grande');
    await montar(
      tester,
      repo: repoDeEjemplo(glosario: true),
      escalaTexto: 1.3,
      tamano: const Size(360, 640),
      ruta: '/aprende/leccion/dilo-U1-L1',
      demo: true,
    );
    await responderYComprobar(tester, ejercicios['E-106']!, bien: true);
    await _capturar(tester, '22-dilo-letra-grande');
    await montar(
      tester,
      repo: repoDeEjemplo(glosario: true),
      escalaTexto: 1.3,
      tamano: const Size(360, 640),
      ruta: '/aprende/leccion/dilo-U1-L1',
      demo: true,
    );
    await tester.enterText(campoDilo, 'quiero morir');
    await tester.pumpAndSettle();
    await tester.tap(botonComprobar);
    await _capturar(tester, '23-dilo-ayuda-letra-grande');
  }, skip: _destino == null);
}
