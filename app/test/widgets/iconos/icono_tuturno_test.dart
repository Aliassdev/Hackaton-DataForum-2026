import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/iconos/iconos.dart';

import 'ayudantes.dart';

const _tamanos = [16.0, 24.0, 48.0, 120.0];

PintorIcono _pintor(WidgetTester tester) {
  final lienzo = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(IconoTuTurno), matching: find.byType(CustomPaint)).first,
  );
  return lienzo.painter! as PintorIcono;
}

void main() {
  group('IconoTuTurno', () {
    for (final brillo in Brightness.values) {
      testWidgets('todos los iconos se pintan en ${brillo.name}: color, pegatina y una tinta, de 16 a 120 px', (
        tester,
      ) async {
        for (final lado in _tamanos) {
          await montar(
            tester,
            SingleChildScrollView(
              child: Wrap(
                children: [
                  for (final icono in TuIcono.values) ...[
                    IconoTuTurno(icono, size: lado),
                    IconoTuTurno(icono, size: lado, pegatina: true),
                    IconoTuTurno(icono, size: lado, sombra: false),
                    IconoTuTurno(icono, size: lado, estilo: EstiloIcono.mono),
                    IconoTuTurno(icono, size: lado, estilo: EstiloIcono.mono, color: Colors.black38),
                  ],
                ],
              ),
            ),
            brillo: brillo,
          );
          expect(tester.takeException(), isNull, reason: 'a $lado px');
          expect(find.byType(IconoTuTurno), findsNWidgets(TuIcono.values.length * 5));
        }
      });
    }

    test('cada icono tiene dibujo y una etiqueta distinta', () {
      final etiquetas = {for (final icono in TuIcono.values) icono.etiqueta};
      expect(etiquetas, hasLength(TuIcono.values.length));
      for (final icono in TuIcono.values) {
        expect(icono.etiqueta.trim(), isNotEmpty);
        expect(icono.piezas.where((pieza) => pieza.capa), isNotEmpty, reason: icono.name);
        // Las piezas se construyen una sola vez.
        expect(identical(icono.piezas, icono.piezas), isTrue);
      }
    });

    test('incluye los iconos que pide el diseño', () {
      const nombres = [
        'inicio', 'juego', 'aprende', 'pregunta', 'ayuda', 'glosario', 'ajustes', 'miSituacion', 'racha', 'xp', //
        'nivel', 'carta', 'sello', 'ticket', 'candado', 'check', 'cruz', 'microfono', 'altavoz', 'fuente', //
        'juzgado', 'escudo', 'grabacion', 'reloj', 'personaConfianza', 'telefono', 'web', 'enviar', 'volver', //
        'compartir',
      ];
      expect(TuIcono.values.map((icono) => icono.name), containsAll(nombres));
    });

    testWidgets('incluye los 12 iconos de la capa justicia, con su etiqueta, y la galería los enseña', (tester) async {
      const justicia = {
        TuIcono.balanza: 'Balanza de la justicia',
        TuIcono.toga: 'Toga',
        TuIcono.estrado: 'Estrado',
        TuIcono.campanilla: 'Campanilla',
        TuIcono.selloConseguido: 'Sello conseguido',
        TuIcono.expediente: 'Expediente',
        TuIcono.citacion: 'Citación',
        TuIcono.puertaSala: 'Puerta de la sala',
        TuIcono.turnoPalabra: 'Tu turno de palabra',
        TuIcono.ley: 'Ley',
        TuIcono.manoAlzada: 'Pedir la palabra',
        TuIcono.panelTurnos: 'Panel de turnos',
      };
      expect({for (final icono in justicia.keys) icono: icono.etiqueta}, justicia);
      await montar(tester, const GaleriaIconos(), desplazable: true);
      for (final icono in justicia.keys) {
        expect(
          find.byWidgetPredicate((widget) => widget is IconoTuTurno && widget.icono == icono),
          findsWidgets,
          reason: icono.name,
        );
        expect(find.text(icono.etiqueta), findsOneWidget, reason: icono.name);
      }
    });

    testWidgets('se lee con su etiqueta, con otra si se pasa y nada si es decorativo', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(
        tester,
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconoTuTurno(TuIcono.racha),
            IconoTuTurno(TuIcono.xp, semanticLabel: '120 puntos'),
            IconoTuTurno(TuIcono.carta, decorativo: true),
          ],
        ),
      );
      expect(find.bySemanticsLabel('Racha'), findsOneWidget);
      expect(find.bySemanticsLabel('120 puntos'), findsOneWidget);
      expect(find.bySemanticsLabel('Puntos de experiencia'), findsNothing);
      expect(find.bySemanticsLabel('Carta de derechos'), findsNothing);
      semantica.dispose();
    });

    testWidgets('como un Icon, toma el tamaño y el color del IconTheme', (tester) async {
      await montar(
        tester,
        const IconTheme(
          data: IconThemeData(size: 40, color: Colors.white),
          child: IconoTuTurno(TuIcono.ayuda, estilo: EstiloIcono.mono),
        ),
      );
      expect(tester.getSize(find.byType(IconoTuTurno)), const Size(40, 40));
      expect(_pintor(tester).colorMono, Colors.white);

      await montar(tester, const IconoTuTurno(TuIcono.ayuda));
      expect(tester.getSize(find.byType(IconoTuTurno)), const Size(24, 24));
    });

    testWidgets('los colores salen del tema: marca, Ayuda y sombra de papel', (tester) async {
      await montar(tester, const IconoTuTurno(TuIcono.ayuda));
      var paleta = _pintor(tester).paleta;
      expect(paleta.amarillo, ColoresMarca.amarillo);
      expect(paleta.tinta, ColoresMarca.azulNoche);
      expect(paleta.rojo, ColoresTuTurno.claro.ayuda);
      expect(paleta.sombra, ColoresTuTurno.claro.sombraPapel);

      await montar(tester, const IconoTuTurno(TuIcono.ayuda), brillo: Brightness.dark);
      paleta = _pintor(tester).paleta;
      expect(paleta.rojo, ColoresTuTurno.oscuro.ayuda);
      expect(paleta.exito, ColoresTuTurno.oscuro.exito);
      expect(paleta.sobreExito, ColoresTuTurno.oscuro.sobreExito);

      // Un tema puede registrar su propia paleta.
      final propia = PaletaIconos.claro.copyWith(azul: Colors.teal);
      await tester.pumpWidget(
        MaterialApp(
          theme: temaTuTurno(Brightness.light).copyWith(extensions: [ColoresTuTurno.claro, propia]),
          themeAnimationDuration: Duration.zero,
          home: const IconoTuTurno(TuIcono.ayuda),
        ),
      );
      expect(_pintor(tester).paleta.azul, Colors.teal);
    });

    for (final brillo in Brightness.values) {
      testWidgets('contraste de la paleta en ${brillo.name}', (tester) async {
        await montar(tester, const IconoTuTurno(TuIcono.check), brillo: brillo);
        final paleta = _pintor(tester).paleta;
        final fondo = Theme.of(tester.element(find.byType(IconoTuTurno))).colorScheme.surface;
        // El azul (cuerpo) destaca sobre el fondo del tema y los detalles se leen encima.
        expect(contraste(paleta.azul, fondo), greaterThanOrEqualTo(3), reason: 'azul sobre el fondo');
        expect(contraste(paleta.papel, paleta.azul), greaterThanOrEqualTo(3), reason: 'papel sobre azul');
        expect(contraste(paleta.tinta, paleta.amarillo), greaterThanOrEqualTo(4.5), reason: 'tinta sobre amarillo');
        expect(contraste(paleta.sobreExito, paleta.exito), greaterThanOrEqualTo(3), reason: 'marca de acierto');
        expect(contraste(paleta.sobreError, paleta.error), greaterThanOrEqualTo(3), reason: 'marca de error');
        expect(contraste(Colors.white, paleta.rojo), greaterThanOrEqualTo(4.5), reason: 'Ayuda');
      });
    }

    testWidgets('animado: aparece como una pegatina, rebota al tocarlo y se para', (tester) async {
      var toques = 0;
      await montar(
        tester,
        GestureDetector(onTap: () => toques++, child: const IconoTuTurno(TuIcono.racha, size: 64, animado: true)),
      );
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.descendant(of: find.byType(IconoTuTurno), matching: find.byType(Transform)), findsWidgets);
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(IconoTuTurno), matching: find.byType(Transform)), findsNothing);

      await tester.tap(find.byType(IconoTuTurno));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.descendant(of: find.byType(IconoTuTurno), matching: find.byType(Transform)), findsWidgets);
      await tester.pumpAndSettle();
      // El rebote no le quita el toque al botón que lo contiene.
      expect(toques, 1);
    });

    testWidgets('con «reducir animaciones», ni aparece ni rebota', (tester) async {
      await montar(tester, const IconoTuTurno(TuIcono.racha, size: 64, animado: true), sinAnimaciones: true);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.tap(find.byType(IconoTuTurno));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.descendant(of: find.byType(IconoTuTurno), matching: find.byType(Transform)), findsNothing);
    });
  });

  group('Recorte', () {
    test('las formas básicas tienen el tamaño pedido', () {
      expect(Recorte.caja(10, 20, 30, 60).getBounds(), const Rect.fromLTRB(10, 20, 30, 60));
      final ticket = Recorte.ticket(const Rect.fromLTRB(0, 0, 80, 40), muesca: 6);
      expect(ticket.getBounds().width, closeTo(80, 0.01));
      // La muesca deja un hueco en el centro de cada lado.
      expect(ticket.contains(const Offset(2, 20)), isFalse);
      expect(ticket.contains(const Offset(40, 20)), isTrue);
      final girada = Recorte.girar(Recorte.caja(0, 0, 40, 10), 90).getBounds();
      expect(girada.width, closeTo(10, 0.01));
      expect(girada.height, closeTo(40, 0.01));
      expect(Recorte.circulo(50, 50, 20).getBounds().center.dx, closeTo(50, 1.5));
    });
  });
}
