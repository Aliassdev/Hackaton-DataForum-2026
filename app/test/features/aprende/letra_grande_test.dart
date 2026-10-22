// Letra grande con las fuentes de verdad (Nunito y MaryKate): con la letra de las pruebas cada letra es un cuadrado
// tan ancho como alto y ninguna palabra larga cabría. Comprueba que la cabecera de la corrección no parte palabras con
// letra 1,6 (auditoría, P1-3: nunca «¡Correct / o!») y que el mapa de 7 salas cabe con letra 1,3 en 360 × 640.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/features/aprende/modelos.dart';

import '../../fuentes_reales.dart';
import 'ayudantes.dart';

/// El título del panel de corrección cabe sin partir ninguna palabra: tiene al menos el ancho de su palabra más larga.
void _tituloSinPartir(WidgetTester tester, {required String reason}) {
  final titulo = find.byKey(const ValueKey('titulo-correccion'));
  expect(titulo, findsOneWidget, reason: reason);
  final parrafo = tester.renderObject<RenderParagraph>(find.descendant(of: titulo, matching: find.byType(RichText)));
  expect(parrafo.size.width, greaterThanOrEqualTo(parrafo.getMinIntrinsicWidth(double.infinity) - 0.5), reason: reason);
}

void main() {
  setUpAll(cargarFuentesReales);

  final ejercicios = ejerciciosDeEjemplo();

  testWidgets('con letra 1,6 en un móvil pequeño, la cabecera de la corrección no parte palabras', (tester) async {
    for (final brillo in Brightness.values) {
      await montar(
        tester,
        ruta: '/aprende/leccion/U1-L1',
        escalaTexto: 1.6,
        tamano: const Size(360, 640),
        brillo: brillo,
      );
      // Acierto (con «+10 XP»), fallo y, al final, «Dilo».
      final ids = ['E-101', 'E-102', 'E-103', 'E-104', 'E-105', 'E-106'];
      for (final (i, id) in ids.indexed) {
        final e = ejercicios[id]!;
        await responderYComprobar(tester, e, bien: i != 1);
        expect(tester.takeException(), isNull, reason: '$brillo $id');
        _tituloSinPartir(tester, reason: '$brillo $id');
        if (i == 0) expect(find.text('+10 XP'), findsOneWidget);
        if (e is EjercicioDilo) expect(find.text('+5 XP'), findsOneWidget);
        await tester.tap(botonContinuar);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: '$brillo celebración');
    }
  });

  testWidgets('con letra 1,3 en 360 × 640, las 7 salas caben sin desbordes', (tester) async {
    for (final brillo in Brightness.values) {
      await montar(
        tester,
        escalaTexto: 1.3,
        tamano: const Size(360, 640),
        brillo: brillo,
        preferencias: progresoGuardado(
          xp: 12345,
          racha: 12,
          ultimoDia: DateTime(2026, 10, 20),
          lecciones: ['U1-L1', 'U1-L2', 'U1-L3', 'U2-L1'],
        ),
      );
      expect(tester.takeException(), isNull, reason: '$brillo arriba');
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$brillo, tramo $i');
      }
      expect(find.textContaining('SALA 7'), findsOneWidget);
    }
  });
}
