// El panel de turnos (PanelSenalamiento, tema-justicia.md §7.8): «TURNO 07 · SALA 2 · APRENDE» en paletas partidas,
// solo números y salas, que se lee como una frase, crece con la letra y gira el número (quieto con «reducir
// animaciones»). Y en el inicio, encima del ticket del día, con el turno y la sala de la misión.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/app.dart';
import 'package:tuturno/core/progreso.dart';
import 'package:tuturno/features/inicio/turno_del_dia.dart';
import 'package:tuturno/features/inicio/widgets/ticket_del_dia.dart';
import 'package:tuturno/widgets/justicia/panel_senalamiento.dart';
import 'package:tuturno/widgets/movimiento/movimiento.dart';

import '../../widgets/movimiento/entorno.dart';
import '../a1/helpers.dart';

/// Los textos de las paletas del panel, en orden.
List<String> _paletas(WidgetTester tester, [Finder? dentro]) => [
  for (final panel in tester.widgetList<PanelFlip>(
    find.descendant(of: dentro ?? find.byType(PanelSenalamiento), matching: find.byType(PanelFlip)),
  ))
    panel.texto,
];

void main() {
  group('PanelSenalamiento', () {
    testWidgets('enseña el turno y la sala en paletas y el destino en letras, y se lee como una frase', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, const PanelSenalamiento(turno: '07', sala: 'SALA 2', destino: 'Aprende'));
      expect(find.text('TURNO'), findsOneWidget);
      expect(find.text('SALA'), findsOneWidget);
      expect(find.text('APRENDE'), findsOneWidget);
      expect(_paletas(tester), ['07', '2']);
      expect(
        tester.getSemantics(find.byType(PanelSenalamiento)),
        matchesSemantics(label: 'Panel de turnos: turno 7, sala 2, Aprende.'),
      );
      semantica.dispose();
    });

    testWidgets('una sala sin número va en letras; con semanticLabel se lee lo que se pida', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, const PanelSenalamiento(turno: '001', sala: 'INFORMACIÓN', destino: 'VIVE EL CASO'));
      expect(find.text('INFORMACIÓN'), findsOneWidget);
      expect(_paletas(tester), ['001']);
      expect(
        tester.getSemantics(find.byType(PanelSenalamiento)),
        matchesSemantics(label: 'Panel de turnos: turno 1, información, Vive el caso.'),
      );

      await montar(tester, const PanelSenalamiento(turno: '07', sala: 'SALA 1', semanticLabel: 'Turno 7 en la sala 1'));
      expect(tester.getSemantics(find.byType(PanelSenalamiento)), matchesSemantics(label: 'Turno 7 en la sala 1'));
      expect(find.text('APRENDE'), findsNothing);
      semantica.dispose();
    });

    test('parte la sala en su nombre y su número', () {
      expect(PanelSenalamiento.partirSala('SALA 2'), ('SALA', '2'));
      expect(PanelSenalamiento.partirSala(' Sala 12 '), ('Sala', '12'));
      expect(PanelSenalamiento.partirSala('INFORMACIÓN'), ('INFORMACIÓN', null));
    });

    testWidgets('con desde, el número gira al aparecer; con «reducir animaciones», ya está puesto', (tester) async {
      await montar(tester, const PanelSenalamiento(turno: '001', desde: '998', sala: 'SALA 2'));
      final turno = tester.widget<PanelFlip>(find.byType(PanelFlip).first);
      expect(turno.texto, '001');
      expect(turno.desde, '998');
      expect(tester.binding.hasScheduledFrame, isTrue, reason: 'las paletas están girando');
      await tester.pumpAndSettle();

      await montar(tester, const PanelSenalamiento(turno: '002', desde: '001', sala: 'SALA 2'), reducir: true);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await desmontar(tester);
    });

    testWidgets('papel con tinta azul noche y letreros amarillos sobre el tablero, con contraste AA', (tester) async {
      expect(PaletaMovimiento.contraste(PanelSenalamiento.papel, PanelSenalamiento.tinta), greaterThan(4.5));
      for (final brillo in Brightness.values) {
        await montar(
          tester,
          const PanelSenalamiento(turno: '07', sala: 'SALA 2', destino: 'Aprende'),
          brillo: brillo,
        );
        final contexto = tester.element(find.byType(PanelSenalamiento));
        final tablero = PanelSenalamiento.tablero(contexto);
        expect(PaletaMovimiento.contraste(PanelSenalamiento.letrero, tablero), greaterThan(4.5), reason: '$brillo');
        expect(PaletaMovimiento.contraste(PanelSenalamiento.papel, tablero), greaterThan(4.5), reason: '$brillo');
        final paleta = tester.widget<PanelFlip>(find.byType(PanelFlip).first);
        expect(paleta.fondo, PanelSenalamiento.papel);
        expect(paleta.color, PanelSenalamiento.tinta);
        expect(tester.widget<Text>(find.text('TURNO')).style?.color, PanelSenalamiento.letrero);
      }
    });

    testWidgets('crece con la letra y, si no cabe, pasa a otra línea sin desbordarse', (tester) async {
      Widget panel() => const SizedBox(
        width: 300,
        child: Center(
          child: PanelSenalamiento(turno: '001', sala: 'SALA 1', destino: 'Vive el caso'),
        ),
      );
      await montar(tester, panel());
      final normal = tester.getSize(find.byType(PanelSenalamiento)).height;
      for (final escala in [1.3, 2.0]) {
        await montar(tester, panel(), escalaTexto: escala);
        expect(tester.takeException(), isNull, reason: '$escala');
      }
      expect(tester.getSize(find.byType(PanelSenalamiento)).height, greaterThan(normal * 1.5));
      expect(tester.getSize(find.byType(PanelSenalamiento)).width, lessThanOrEqualTo(300));
    });
  });

  group('En el inicio', () {
    testWidgets('va encima del ticket del día, con su número y la sala de la misión', (tester) async {
      // Jueves 22/10: la misión es una lección de Aprende (sala 2).
      await arrancarApp(tester, overrides: [relojProvider.overrideWithValue(() => DateTime(2026, 10, 22, 17))]);
      final panel = find.descendant(of: find.byType(TicketDelDia), matching: find.byType(PanelSenalamiento));
      expect(panel, findsOneWidget);
      final datos = tester.widget<PanelSenalamiento>(panel);
      expect(datos.turno, '001');
      expect(datos.sala, 'SALA 2');
      expect(datos.destino, 'Aprende');
      expect(datos.desde, '998', reason: 'gira a la vez que el número del talón');
      expect(
        tester.getBottomLeft(panel).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.text('TU TURNO DEL DÍA')).dy),
        reason: 'el panel va encima del ticket',
      );
    });

    testWidgets('con una misión de Vive el caso, dice la sala 1', (tester) async {
      // Viernes 23/10: la misión es conseguir una carta en Vive el caso.
      await arrancarApp(tester, overrides: [relojProvider.overrideWithValue(() => DateTime(2026, 10, 23, 17))]);
      final contenedor = ProviderScope.containerOf(tester.element(find.byType(TuTurnoApp)));
      expect(contenedor.read(turnoDelDiaProvider).mision, Mision.carta);
      final datos = tester.widget<PanelSenalamiento>(find.byType(PanelSenalamiento));
      expect(datos.sala, 'SALA 1');
      expect(datos.destino, 'Vive el caso');
    });

    testWidgets('solo lleva números y salas: nada de nombres', (tester) async {
      await arrancarApp(tester, overrides: [relojProvider.overrideWithValue(() => DateTime(2026, 10, 22, 17))]);
      final textos = [
        for (final texto in tester.widgetList<Text>(
          find.descendant(of: find.byType(PanelSenalamiento), matching: find.byType(Text)),
        ))
          texto.data,
      ];
      expect(textos.toSet(), {'TURNO', 'SALA', 'APRENDE', '0', '1', '2'});
    });
  });
}
