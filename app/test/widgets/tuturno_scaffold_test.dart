import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/tuturno_scaffold.dart';

import '../fuentes_reales.dart';

/// Abre una pantalla con [titulo] en la barra (con «atrás», Glosario y Ayuda, como en la app) y devuelve el párrafo del
/// título.
Future<RenderParagraph> _abrir(
  WidgetTester tester,
  String titulo, {
  double ancho = 360,
  double letra = 1,
  bool lecturaFacil = false,
}) async {
  tester.view.devicePixelRatio = 2.75;
  tester.view.physicalSize = Size(ancho, 780) * 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      // Una app nueva cada vez (con su navegador vacío), aunque la prueba abra varias seguidas.
      key: UniqueKey(),
      theme: temaTuTurno(Brightness.light, lecturaFacil: lecturaFacil),
      locale: const Locale('es', 'ES'),
      supportedLocales: const [Locale('es', 'ES')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(letra)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TuTurnoScaffold(titulo: titulo, body: const SizedBox()),
            ),
          ),
          child: const Text('abrir'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return tester.renderObject<RenderParagraph>(find.descendant(of: find.byType(AppBar), matching: find.text(titulo)));
}

void main() {
  setUpAll(cargarFuentesReales);

  group('el título de la barra no se corta (auditoría P1-1 y P1-2)', () {
    const titulos = [
      'Mis preguntas',
      'Mi situación',
      'Enseñar en grande',
      'Glosario',
      'Pregunta',
      'Aprende',
      'Ajustes',
    ];

    for (final lecturaFacil in [false, true]) {
      for (final letra in [1.0, 1.3]) {
        testWidgets('en 360 de ancho, con letra $letra${lecturaFacil ? ' y lectura fácil' : ''}', (tester) async {
          for (final titulo in titulos) {
            final parrafo = await _abrir(tester, titulo, letra: letra, lecturaFacil: lecturaFacil);
            expect(parrafo.didExceedMaxLines, isFalse, reason: '«$titulo» se corta');
            expect(parrafo.text.style!.fontSize, greaterThanOrEqualTo(TituloBarra.tamanoMinimo), reason: titulo);
            expect(tester.takeException(), isNull);
          }
        });
      }
    }

    testWidgets('si cabe, va a 20, más grande que el texto (con 14 se veía más pequeño)', (tester) async {
      for (final titulo in ['Glosario', 'Pregunta', 'Aprende', 'Ajustes']) {
        final parrafo = await _abrir(tester, titulo, ancho: 412);
        expect(parrafo.text.style!.fontSize, 20, reason: titulo);
        expect(parrafo.text.style!.fontWeight, FontWeight.w700);
      }
    });

    testWidgets('si no cabe en una línea ni a 16, en dos', (tester) async {
      final parrafo = await _abrir(tester, 'Enseñar en grande');
      expect(parrafo.text.style!.fontSize, TituloBarra.tamanoMinimo);
      expect(parrafo.maxLines, 2);
      expect(parrafo.didExceedMaxLines, isFalse);
    });
  });
}
