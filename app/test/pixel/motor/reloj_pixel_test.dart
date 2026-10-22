import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/motor/motor.dart';

// Cada prueba libera su reloj al final: si quedara un temporizador vivo, flutter_test la daría por fallida.
void main() {
  setUp(() => RelojPixel.debugEnMarcha = 0);

  const parpadeo = AnimacionPixel([PasoPixel(0, ms: 1000), PasoPixel(1, ms: 100)]);

  testWidgets('avanza cada paso a su tiempo y avisa solo cuando cambia lo que se ve', (tester) async {
    final reloj = RelojPixel([parpadeo]);
    var avisos = 0;
    reloj.addListener(() => avisos++);
    expect(reloj.length, 1);
    expect(reloj.seMueve, isTrue);
    expect(reloj.fotograma(0), 0);
    expect(reloj.enMarcha, isFalse);

    reloj.arrancar();
    expect(reloj.enMarcha, isTrue);
    expect(RelojPixel.debugEnMarcha, 1);
    await tester.pump(const Duration(milliseconds: 999));
    expect((reloj.fotograma(0), avisos), (0, 0));
    await tester.pump(const Duration(milliseconds: 1));
    expect((reloj.fotograma(0), avisos), (1, 1));
    expect(reloj.paso(0), const PasoPixel(1, ms: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect((reloj.fotograma(0), avisos), (0, 2));

    reloj.parar();
    expect(reloj.enMarcha, isFalse);
    expect(RelojPixel.debugEnMarcha, 0);
    await tester.pump(const Duration(seconds: 5));
    expect(avisos, 2);
    reloj.dispose();
  });

  testWidgets('arrancar dos veces no pone dos temporizadores', (tester) async {
    final reloj = RelojPixel([parpadeo]);
    reloj
      ..arrancar()
      ..arrancar();
    expect(RelojPixel.debugEnMarcha, 1);
    reloj
      ..parar()
      ..parar();
    expect(RelojPixel.debugEnMarcha, 0);
    reloj.dispose();
  });

  testWidgets('dos pasos seguidos con el mismo dibujo no avisan', (tester) async {
    final reloj = RelojPixel([
      const AnimacionPixel([PasoPixel(0, ms: 100), PasoPixel(0, ms: 100), PasoPixel(1, ms: 100)]),
    ]);
    var avisos = 0;
    reloj
      ..addListener(() => avisos++)
      ..arrancar();
    await tester.pump(const Duration(milliseconds: 100));
    expect((reloj.fotograma(0), avisos), (0, 0));
    await tester.pump(const Duration(milliseconds: 100));
    expect((reloj.fotograma(0), avisos), (1, 1));
    reloj.dispose();
  });

  testWidgets('el balanceo cambia el desplazamiento y avisa', (tester) async {
    final reloj = RelojPixel([AnimacionPixel.balanceo(ms: 500)]);
    var avisos = 0;
    reloj
      ..addListener(() => avisos++)
      ..arrancar();
    expect(reloj.dy(0), 0);
    await tester.pump(const Duration(milliseconds: 500));
    expect((reloj.fotograma(0), reloj.dy(0), avisos), (0, -1, 1));
    reloj.dispose();
  });

  testWidgets('los desfases se aplican al arrancar, no al crear ni en reposo', (tester) async {
    final reloj = RelojPixel([parpadeo, parpadeo], desfasesMs: [0, 950]);
    var avisos = 0;
    reloj.addListener(() => avisos++);
    expect((reloj.fotograma(0), reloj.fotograma(1)), (0, 0));

    reloj.arrancar();
    // Al segundo le quedan 50 ms de ojos abiertos; al primero, 1000.
    await tester.pump(const Duration(milliseconds: 50));
    expect((reloj.fotograma(0), reloj.fotograma(1)), (0, 1));
    expect(avisos, 1);

    reloj.reposo();
    expect(reloj.enMarcha, isFalse);
    expect((reloj.fotograma(0), reloj.fotograma(1)), (0, 0));
    expect(avisos, 2);
    await tester.pump(const Duration(seconds: 3));
    expect((reloj.fotograma(0), reloj.fotograma(1)), (0, 0));

    // Al volver a arrancar, cada uno sigue a su ritmo otra vez.
    reloj.arrancar();
    await tester.pump(const Duration(milliseconds: 50));
    expect((reloj.fotograma(0), reloj.fotograma(1)), (0, 1));
    reloj.dispose();
  });

  testWidgets('un desfase mayor que la vuelta da la vuelta', (tester) async {
    final reloj = RelojPixel([parpadeo], desfasesMs: [1100 * 3 + 1050]);
    reloj.arrancar();
    expect(reloj.fotograma(0), 1);
    reloj.dispose();
  });

  testWidgets('reposo sin cambios no avisa', (tester) async {
    final reloj = RelojPixel([parpadeo]);
    var avisos = 0;
    reloj
      ..addListener(() => avisos++)
      ..reposo();
    expect(avisos, 0);
    reloj.dispose();
  });

  testWidgets('sin nada que se mueva no se pone en marcha', (tester) async {
    final reloj = RelojPixel([
      null,
      const AnimacionPixel([PasoPixel(2, ms: 10)]),
    ]);
    expect(reloj.seMueve, isFalse);
    reloj.arrancar();
    expect(reloj.enMarcha, isFalse);
    expect(RelojPixel.debugEnMarcha, 0);
    expect(reloj.paso(0), isNull);
    expect((reloj.fotograma(0), reloj.dy(0)), (0, 0));
    expect(reloj.fotograma(1), 2);
    reloj.dispose();
  });

  testWidgets('una animación sin pasos cuenta como ninguna', (tester) async {
    final reloj = RelojPixel([const AnimacionPixel([]), parpadeo], desfasesMs: [500, 0]);
    expect(reloj.paso(0), isNull);
    expect(reloj.fotograma(0), 0);
    reloj.arrancar();
    await tester.pump(const Duration(milliseconds: 1000));
    expect((reloj.fotograma(0), reloj.fotograma(1)), (0, 1));
    reloj.reposo();
    expect(reloj.paso(0), isNull);
    reloj.dispose();
  });

  testWidgets('dispose lo para', (tester) async {
    final reloj = RelojPixel([parpadeo])..arrancar();
    expect(RelojPixel.debugEnMarcha, 1);
    reloj.dispose();
    expect(RelojPixel.debugEnMarcha, 0);
    // Si quedara un temporizador vivo, la prueba fallaría al terminar.
  });
}
