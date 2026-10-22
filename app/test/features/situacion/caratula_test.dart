import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/justicia/expediente_caratula.dart';

// La carpeta de «Mi situación» (capa justicia, tema-justicia.md §7.5): se abre despacio una vez por sesión, dice «TU
// GUÍA» (nunca «tu expediente») y, con «reducir animaciones», ya está abierta.

Future<void> _montar(WidgetTester tester, {bool sinAnimaciones = false, Object clave = 'prueba', Widget? child}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: temaTuTurno(Brightness.light),
      builder: (context, hijo) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: sinAnimaciones),
        child: hijo!,
      ),
      home: Scaffold(
        body: ExpedienteCaratula(
          titulo: 'Tu camino como víctima',
          tituloTapa: 'Mi situación',
          papel: 'Tu papel: víctima',
          faseActual: 1,
          clave: clave,
          child: child,
        ),
      ),
    ),
  );
}

/// La tapa de delante (la que gira) está a la vista.
bool _tapaCerrada(WidgetTester tester) => find.text('Mi situación').evaluate().isNotEmpty;

void main() {
  setUp(ExpedienteCaratula.olvidarAperturas);

  testWidgets('la tapa se ve cerrada al entrar y se abre sola en unos 620 ms, sin rebotes', (tester) async {
    await _montar(tester, child: const Text('Dentro'));
    await tester.pump();
    expect(_tapaCerrada(tester), isTrue);
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pump(ExpedienteCaratula.esperaApertura + ExpedienteCaratula.duracionApertura);
    await tester.pumpAndSettle();
    expect(_tapaCerrada(tester), isFalse);
    expect(find.text('Dentro'), findsOneWidget);
  });

  testWidgets('dice «TU GUÍA» y se lee como una frase, con la fase marcada; nunca «expediente»', (tester) async {
    final semantica = tester.ensureSemantics();
    await _montar(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('TU GUÍA'), findsWidgets);
    expect(find.textContaining(RegExp('expediente', caseSensitive: false)), findsNothing);
    expect(
      find.bySemanticsLabel(
        'Tu guía. Tu camino como víctima. Tu papel: víctima. Fases: Antes, Durante, estás aquí, Después.',
      ),
      findsOneWidget,
    );
    expect(find.text('Durante · Estás aquí'), findsOneWidget);
    semantica.dispose();
  });

  testWidgets('una vez por sesión: la segunda vez ya sale abierta', (tester) async {
    await _montar(tester, clave: 'una');
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());

    await _montar(tester, clave: 'una');
    await tester.pump();
    expect(_tapaCerrada(tester), isFalse);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('con «reducir animaciones», la carpeta ya está abierta y no se mueve nada', (tester) async {
    await _montar(tester, sinAnimaciones: true, child: const Text('Dentro'));
    await tester.pump();
    expect(_tapaCerrada(tester), isFalse);
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('Dentro'), findsOneWidget);
  });

  testWidgets('tocar la carpeta cerrada la abre ya', (tester) async {
    await _montar(tester);
    await tester.pump();
    await tester.tap(find.byType(ExpedienteCaratula), warnIfMissed: false);
    await tester.pump(ExpedienteCaratula.duracionApertura);
    await tester.pumpAndSettle();
    expect(_tapaCerrada(tester), isFalse);
  });
}
