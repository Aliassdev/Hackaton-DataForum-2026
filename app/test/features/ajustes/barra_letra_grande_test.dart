import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/ayuda_button.dart';
import 'package:tuturno/widgets/tuturno_scaffold.dart';

import '../../fuentes_reales.dart';

// Auditoría P1-1 y P1-2: con letra 1,6 los títulos de las barras no se cortan por las acciones. Las acciones crecen
// como mucho ×1,2 y el título nunca parte una palabra ni pone «…».

/// Abre una pantalla con [titulo] en la barra (con «atrás», Glosario y, si [conAyuda], Ayuda) y devuelve el párrafo
/// del título.
Future<RenderParagraph> _abrir(
  WidgetTester tester,
  String titulo, {
  double ancho = 360,
  double letra = 1.6,
  bool lecturaFacil = false,
  bool conAyuda = true,
  List<Widget> acciones = const [],
}) async {
  tester.view.devicePixelRatio = 2.75;
  tester.view.physicalSize = Size(ancho, 780) * 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
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
              builder: (_) =>
                  TuTurnoScaffold(titulo: titulo, body: const SizedBox(), mostrarAyuda: conAyuda, acciones: acciones),
            ),
          ),
          child: const Text('abrir'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  final titular = find.descendant(of: find.byType(AppBar), matching: find.text(titulo)).first;
  return tester.renderObject<RenderParagraph>(titular);
}

/// Las líneas en que ha quedado el título solo se cortan en un espacio: donde el cursor baja de línea, al lado hay
/// uno.
void _sinPalabrasPartidas(RenderParagraph parrafo, String titulo) {
  final texto = parrafo.text.toPlainText();
  double altura(int posicion) => parrafo.getOffsetForCaret(TextPosition(offset: posicion), Rect.zero).dy;
  var anterior = altura(0);
  for (var i = 1; i < texto.length; i++) {
    final actual = altura(i);
    if (actual > anterior + 1) {
      expect(texto[i - 1] == ' ' || texto[i] == ' ', isTrue, reason: '«$titulo» parte una palabra en $i');
    }
    anterior = actual;
  }
}

void main() {
  setUpAll(cargarFuentesReales);

  const titulos = [
    'Mis preguntas',
    'Mi situación',
    'Enseñar en grande',
    'Glosario',
    'Pregunta',
    'Aprende',
    'Ajustes',
    'TuTurno',
    'Lección 2',
    'Practicar',
    'La Sala Gesell',
  ];

  for (final lecturaFacil in [false, true]) {
    for (final ancho in [360.0, 390.0]) {
      testWidgets('con letra 1,6 en $ancho de ancho${lecturaFacil ? ' y lectura fácil' : ''}, nada se corta', (
        tester,
      ) async {
        for (final titulo in titulos) {
          final parrafo = await _abrir(tester, titulo, ancho: ancho, lecturaFacil: lecturaFacil);
          expect(parrafo.didExceedMaxLines, isFalse, reason: '«$titulo» se corta');
          _sinPalabrasPartidas(parrafo, titulo);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('la pastilla «Ayuda» crece como mucho ×1,2 y el título, más', (tester) async {
    await _abrir(tester, 'Ajustes', ancho: 412, letra: 1.2);
    final conLetra12 = tester.getSize(find.byType(AyudaButton));
    await _abrir(tester, 'Ajustes', ancho: 412);
    final conLetra16 = tester.getSize(find.byType(AyudaButton));
    expect(conLetra16.width, closeTo(conLetra12.width, 0.5));

    final enLaPastilla = find.descendant(of: find.byType(AyudaButton), matching: find.text('Ayuda'));
    expect(
      MediaQuery.textScalerOf(tester.element(enLaPastilla)).scale(1),
      closeTo(TuTurnoScaffold.escalaMaximaAcciones, 0.001),
    );
    // El título no lo limita TuTurnoScaffold (AppBar lo deja crecer hasta ×1,34, su máximo para los títulos).
    final titulo = find.descendant(of: find.byType(AppBar), matching: find.text('Ajustes'));
    expect(MediaQuery.textScalerOf(tester.element(titulo)).scale(1), greaterThan(TuTurnoScaffold.escalaMaximaAcciones));
  });

  testWidgets('con letra normal, las acciones no cambian', (tester) async {
    await _abrir(tester, 'Ajustes', ancho: 412, letra: 1);
    final enLaPastilla = find.descendant(of: find.byType(AyudaButton), matching: find.text('Ayuda'));
    expect(MediaQuery.textScalerOf(tester.element(enLaPastilla)).scale(1), closeTo(1, 0.001));
  });

  testWidgets('las acciones de cada pantalla también se limitan (el menú de Pregunta en modo compacto)', (
    tester,
  ) async {
    for (final ancho in [360.0, 390.0]) {
      final parrafo = await _abrir(
        tester,
        'Pregunta',
        ancho: ancho,
        acciones: [IconButton(tooltip: 'Más opciones', onPressed: () {}, icon: const Text('⋮'))],
      );
      expect(parrafo.didExceedMaxLines, isFalse);
      _sinPalabrasPartidas(parrafo, 'Pregunta');
      final menu = find.descendant(of: find.byType(AppBar), matching: find.text('⋮'));
      expect(MediaQuery.textScalerOf(tester.element(menu)).scale(1), closeTo(1.2, 0.001));
    }
  });

  testWidgets('en la pantalla de Ayuda (sin la pastilla) el título tampoco se corta', (tester) async {
    final parrafo = await _abrir(tester, 'Ayuda', conAyuda: false);
    expect(parrafo.didExceedMaxLines, isFalse);
    _sinPalabrasPartidas(parrafo, 'Ayuda');
  });

  testWidgets('un título largo de lección se encoge entero, sin «…»', (tester) async {
    for (final titulo in ['Fiscalía y Defensor del Pueblo', 'La citación y qué puedes pedir']) {
      final parrafo = await _abrir(tester, titulo);
      expect(parrafo.didExceedMaxLines, isFalse, reason: titulo);
      expect(parrafo.text.style!.fontSize, greaterThanOrEqualTo(TituloBarra.tamanoMinimo), reason: titulo);
      _sinPalabrasPartidas(parrafo, titulo);
      expect(tester.takeException(), isNull);
    }
  });
}
