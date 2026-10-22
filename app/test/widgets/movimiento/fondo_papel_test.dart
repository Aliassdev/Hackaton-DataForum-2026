import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/widgets/movimiento/movimiento.dart';

import 'entorno.dart';

void main() {
  testWidgets('flota unos ciclos y se para; el contenido se ve, se lee y se pulsa', (tester) async {
    final semantica = tester.ensureSemantics();
    var pulsado = 0;
    await montar(
      tester,
      SizedBox(
        width: 360,
        height: 200,
        child: FondoPapel(
          ciclos: 2,
          periodo: const Duration(seconds: 2),
          child: Center(
            child: TextButton(onPressed: () => pulsado++, child: const Text('Hola')),
          ),
        ),
      ),
    );
    expect(find.text('Hola'), findsOneWidget);
    expect(find.bySemanticsLabel('Hola'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Hola'));
    expect(pulsado, 1);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    semantica.dispose();
  });

  testWidgets('con «reducir animaciones» está quieto', (tester) async {
    await montar(tester, reducir: true, const SizedBox(width: 360, height: 200, child: FondoPapel()));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('se pausa cuando otra pantalla lo tapa y sigue al volver', (tester) async {
    await montar(
      tester,
      Builder(
        builder: (context) => SizedBox(
          width: 360,
          height: 300,
          child: FondoPapel(
            ciclos: 1000,
            child: Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const Text('Otra pantalla'))),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.tap(find.text('Abrir'));
    // Con mil ciclos de 9 s, esto no acabaría si el fondo siguiera moviéndose debajo.
    await tester.pumpAndSettle();
    expect(find.text('Otra pantalla'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Abrir'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isTrue);
    await desmontar(tester);
  });

  testWidgets('con color, acento y scroll se pinta y se desplaza sin errores', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await montar(
      tester,
      SizedBox(
        width: 360,
        height: 500,
        child: Stack(
          children: [
            SizedBox(
              height: 200,
              child: FondoPapel(
                color: PaletaMovimiento.azul,
                acento: PaletaMovimiento.amarillo,
                scroll: scroll,
                radio: 28,
              ),
            ),
            ListView(
              controller: scroll,
              children: [for (var i = 0; i < 30; i++) SizedBox(height: 60, child: Text('Fila $i'))],
            ),
          ],
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    await desmontar(tester);
  });
}
