import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/juzgado/juzgado.dart';
import 'package:tuturno/pixel/motor/motor.dart';

/// Monta [JuzgadoExplorable] a pantalla completa en un móvil de [tamano] píxeles físicos y densidad [dpr], dentro de
/// un Scaffold (como lo pondrá el juego). [tema] null: el tema por defecto de Material (las pruebas de comportamiento
/// no dependen del tema de la app, que se está rediseñando).
Future<void> montarJuzgado(
  WidgetTester tester, {
  ModoJuzgado modo = ModoJuzgado.salaVistas,
  VoidCallback? onTodosDescubiertos,
  ValueChanged<String>? onDescubierto,
  Set<String> descubiertosIniciales = const {},
  Size tamano = const Size(1080, 2400),
  double dpr = 2.75,
  ThemeData? tema,
  bool reducir = false,
  bool animar = false,
  double letra = 1,
  bool enLista = false,
  Key? clave,
}) async {
  tester.view
    ..physicalSize = tamano
    ..devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  final actividad = JuzgadoExplorable(
    key: clave,
    modo: modo,
    onTodosDescubiertos: onTodosDescubiertos,
    onDescubierto: onDescubierto,
    descubiertosIniciales: descubiertosIniciales,
    animar: animar,
  );
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: tema,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reducir, textScaler: TextScaler.linear(letra)),
          child: Scaffold(
            appBar: AppBar(title: const Text('Vive el caso')),
            body: SafeArea(child: enLista ? ListView(children: [actividad]) : actividad),
          ),
        ),
      ),
    ),
  );
}

/// El punto de la pantalla donde está la cara del rol [id] (con la escala entera que usa la escena de verdad).
Offset caraEnPantalla(WidgetTester tester, String id, {ModoJuzgado modo = ModoJuzgado.salaVistas}) {
  final montaje = MontajeJuzgado.de(modo);
  final cara = montaje.cara(id)!;
  final caja = tester.getRect(find.byType(EscenaPixel));
  final encaje = EncajePixel(caja: caja.size, arte: montaje.fondo.tamano, dpr: tester.view.devicePixelRatio);
  return caja.topLeft + encaje.rectDe(cara.x + 0.5, cara.y + 0.5, 0, 0).topLeft;
}

/// Toca la cara del rol [id] en la sala y espera a que se abra su carta. Si la sala no se ve entera (con letra muy
/// grande en un móvil pequeño se desplaza todo junto), antes la desplaza hasta verla, como haría quien juega.
Future<void> tocarRol(WidgetTester tester, String id, {ModoJuzgado modo = ModoJuzgado.salaVistas}) async {
  await tester.ensureVisible(find.byType(EscenaPixel));
  await tester.pumpAndSettle();
  await tester.tapAt(caraEnPantalla(tester, id, modo: modo));
  await tester.pumpAndSettle();
}

/// El texto de la barra de progreso.
Finder progreso(int conocidos, int total) => find.text('Has conocido a $conocidos de $total');
