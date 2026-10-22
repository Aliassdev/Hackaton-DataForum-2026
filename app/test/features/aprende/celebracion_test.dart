import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/features/aprende/textos.dart';
import 'package:tuturno/features/aprende/widgets/celebracion.dart';
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/justicia/justicia.dart';
import 'package:tuturno/widgets/movimiento/confeti_papel.dart';
import 'package:tuturno/widgets/movimiento/sello_animado.dart';

// El final de una lección: cae el sello «SUPERADA» y, al golpear el papel, el confeti. Con «reducir animaciones»,
// el sello aparece puesto y no hay confeti.

Future<void> _montar(
  WidgetTester tester, {
  TipoSello sello = TipoSello.leccion,
  int? record,
  List<Mejora> mejoras = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: temaTuTurno(Brightness.light),
      home: Scaffold(
        body: Celebracion(
          sello: sello,
          titulo: sello == TipoSello.leccion ? textoLeccionSuperada : textoRepasoHecho,
          subtitulo: textoSelloConseguido,
          detalle: 'Que te escuchen',
          xp: 55,
          racha: 3,
          rachaSube: true,
          record: record,
          aciertos: 5,
          respondidas: 6,
          mejoras: mejoras,
          botones: [FilledButton(onPressed: () {}, child: const Text('Volver al mapa'))],
        ),
      ),
    ),
  );
}

double _opacidadSello(WidgetTester tester) => tester
    .widget<Opacity>(find.descendant(of: find.byType(SelloAnimado), matching: find.byType(Opacity)).first)
    .opacity;

void main() {
  testWidgets('cae el sello «SUPERADA» con el título «¡Lección superada!» y «Sello conseguido»', (tester) async {
    final semantica = tester.ensureSemantics();
    await _montar(tester);
    final sello = tester.widget<SelloJusticia>(find.byType(SelloJusticia));
    expect(sello.tipo, TipoSello.leccion);
    expect(TipoSello.leccion.texto, 'SUPERADA');
    expect(find.text('¡Lección superada!'), findsOneWidget);
    expect(find.text('Sello conseguido'), findsOneWidget);
    expect(find.text('Que te escuchen'), findsOneWidget);
    // Al principio el sello aún no se ve: cae un poco después.
    expect(_opacidadSello(tester), 0);
    await tester.pumpAndSettle();
    expect(_opacidadSello(tester), 1);
    expect(find.bySemanticsLabel('Sello: lección superada'), findsOneWidget);
    expect(find.bySemanticsLabel('Has ganado 55 puntos de experiencia'), findsOneWidget);
    expect(find.bySemanticsLabel('Racha de 3 días. Ha subido hoy'), findsOneWidget);
    expect(find.text('5/6'), findsOneWidget);
    semantica.dispose();
  });

  testWidgets('el confeti sale cuando el sello golpea el papel, una sola vez', (tester) async {
    await _montar(tester);
    expect(find.byType(ConfetiPapel), findsNothing);
    // 250 ms de espera y el golpe al 42 % de la caída (760 ms).
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(ConfetiPapel), findsNothing);
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byType(ConfetiPapel), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(ConfetiPapel), findsNothing, reason: 'el confeti se va solo');
  });

  testWidgets('con «reducir animaciones», el sello aparece puesto y no hay confeti', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _montar(tester);
    expect(_opacidadSello(tester), 1, reason: 'ya puesto en el primer fotograma');
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(ConfetiPapel), findsNothing);
    expect(_opacidadSello(tester), 1);
  });

  testWidgets('un repaso lleva el sello «REPASADO»', (tester) async {
    await _montar(tester, sello: TipoSello.practica);
    await tester.pumpAndSettle();
    expect(tester.widget<SelloJusticia>(find.byType(SelloJusticia)).tipo.texto, 'REPASADO');
    expect(find.text(textoRepasoHecho), findsOneWidget);
  });

  testWidgets('al batir el récord: «¡Tu mejor racha! 5 días.»; si no, nada', (tester) async {
    await _montar(tester, record: 5);
    await tester.pumpAndSettle();
    expect(find.text('¡Tu mejor racha! 5 días.'), findsOneWidget);
    await _montar(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('mejor racha'), findsNothing);
  });

  testWidgets('los conceptos que mejoran llevan su balanza, que se equilibra al dominarlos', (tester) async {
    await _montar(tester, mejoras: const [(nombre: 'Ser oído y escuchado', antes: 0.6, despues: 0.97)]);
    await tester.pumpAndSettle();
    expect(find.text('Lo que has mejorado'), findsOneWidget);
    expect(find.text('En equilibrio: lo dominas'), findsOneWidget);
    expect(find.text('¡Ya dominas «Ser oído y escuchado»!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
