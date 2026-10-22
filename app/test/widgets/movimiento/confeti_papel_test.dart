import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/widgets/movimiento/movimiento.dart';

import 'entorno.dart';

void main() {
  testWidgets('una ráfaga corta que se para sola', (tester) async {
    var terminadas = 0;
    await montar(tester, SizedBox.expand(child: ConfetiPapel(alTerminar: () => terminadas++)));
    expect(tester.binding.hasScheduledFrame, isTrue);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(terminadas, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('al cambiar el disparo sale otra ráfaga', (tester) async {
    await montar(tester, const SizedBox.expand(child: ConfetiPapel(disparo: 0, lanzarAlInicio: false)));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await montar(tester, const SizedBox.expand(child: ConfetiPapel(disparo: 1, lanzarAlInicio: false)));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('no tapa los toques ni se lee', (tester) async {
    final semantica = tester.ensureSemantics();
    var pulsado = 0;
    await montar(
      tester,
      Stack(
        children: [
          Center(
            child: TextButton(onPressed: () => pulsado++, child: const Text('Seguir')),
          ),
          const Positioned.fill(child: ConfetiPapel()),
        ],
      ),
    );
    await tester.tap(find.text('Seguir'));
    expect(pulsado, 1);
    await tester.pumpAndSettle();
    semantica.dispose();
  });

  testWidgets('con «reducir animaciones» no se lanza', (tester) async {
    var terminadas = 0;
    await montar(tester, reducir: true, SizedBox.expand(child: ConfetiPapel(alTerminar: () => terminadas++)));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(terminadas, 0);
  });

  testWidgets('lanzarConfeti lo pone encima de todo y lo quita al acabar', (tester) async {
    await montar(
      tester,
      Builder(
        builder: (context) => TextButton(onPressed: () => lanzarConfeti(context), child: const Text('¡Bien!')),
      ),
    );
    await tester.tap(find.text('¡Bien!'));
    await tester.pump();
    expect(find.byType(ConfetiPapel), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.byType(ConfetiPapel), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('lanzarConfeti con «reducir animaciones» no hace nada', (tester) async {
    await montar(
      tester,
      reducir: true,
      Builder(
        builder: (context) => TextButton(onPressed: () => lanzarConfeti(context), child: const Text('¡Bien!')),
      ),
    );
    await tester.tap(find.text('¡Bien!'));
    await tester.pump();
    expect(find.byType(ConfetiPapel), findsNothing);
  });

  testWidgets('se puede quitar a mitad de la ráfaga', (tester) async {
    await montar(tester, const SizedBox.expand(child: ConfetiPapel()));
    await tester.pump(const Duration(milliseconds: 300));
    await desmontar(tester);
  });

  group('la gravedad tira hacia abajo', () {
    // Valores de un móvil de 360 dp: gravedad 1350 px/s² y saltos de 260 a 1090 px/s hacia arriba.
    double altura(double velocidad, double segundos) =>
        alturaConfeti(inicio: 300, velocidad: velocidad, gravedad: 1350, segundos: segundos);

    test('cada trozo sube, se para y cae por debajo de donde salió antes de acabar la ráfaga', () {
      for (final velocidad in [-260.0, -600.0, -1090.0]) {
        expect(altura(velocidad, 0), 300, reason: '$velocidad');
        expect(altura(velocidad, 0.1), lessThan(300), reason: '$velocidad: primero sube');
        expect(altura(velocidad, 1.7), greaterThan(300), reason: '$velocidad: al final ha caído');
        expect(altura(velocidad, 1.7), greaterThan(altura(velocidad, 1.2)), reason: '$velocidad: sigue cayendo');
      }
    });

    test('el más fuerte no se sale de la pantalla por arriba durante mucho rato', () {
      // Sale a un 19 % del alto de un móvil de 640 dp (como en la celebración de Aprende).
      final puntoMasAlto = [
        for (var t = 0.0; t <= 1.7; t += 0.05)
          alturaConfeti(inicio: 122, velocidad: -1090, gravedad: 1350, segundos: t),
      ].reduce((a, b) => a < b ? a : b);
      expect(puntoMasAlto, greaterThan(-260));
    });
  });
}
