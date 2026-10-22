import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/api/models.dart';
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/fuente_chip.dart';
import 'package:tuturno/widgets/texto_con_terminos.dart';

const _fuente = Fuente(id: 'A-017', titulo: 'Antes de los 14 años', norma: 'LO 5/2000', articulo: '3');

void main() {
  group('trocearTexto', () {
    test('marca los términos sin que importen tildes ni mayúsculas', () {
      final trozos = trocearTexto(
        'La fiscalia de menores investiga. Responsabilidad Penal es otra cosa.',
        terminos: ['Fiscalía de Menores', 'responsabilidad penal'],
      );
      final terminos = trozos.where((t) => t.termino != null).toList();
      expect(terminos.map((t) => t.texto), ['fiscalia de menores', 'Responsabilidad Penal']);
      expect(terminos.map((t) => t.termino), ['Fiscalía de Menores', 'responsabilidad penal']);
      expect(
        trozos.map((t) => t.texto).join(),
        'La fiscalia de menores investiga. Responsabilidad Penal es otra cosa.',
      );
    });

    test('solo palabras completas, la primera vez y el término más largo primero', () {
      final trozos = trocearTexto(
        'La pena no es penal. La prueba preconstituida es una prueba. La prueba otra vez.',
        terminos: ['pena', 'prueba', 'prueba preconstituida'],
      );
      final terminos = trozos.where((t) => t.termino != null).map((t) => t.texto).toList();
      expect(terminos, ['pena', 'prueba preconstituida', 'prueba']);
      // «pena» no se marca dentro de «penal».
      expect(trozos.firstWhere((t) => t.termino == 'pena').texto, 'pena');
    });

    test('cambia las referencias conocidas por su número y quita las desconocidas', () {
      final trozos = trocearTexto('No hay responsabilidad penal [A-017]. Otra cosa [B-999].', fuentes: [_fuente]);
      final referencias = trozos.where((t) => t.fuentes.isNotEmpty).toList();
      expect(referencias.single.fuentes, [0]);
      final texto = trozos.map((t) => t.texto).join();
      expect(texto, isNot(contains('[')));
      expect(texto, 'No hay responsabilidad penal. Otra cosa.');
    });
  });

  testWidgets('un término subrayado avisa al tocarlo y la referencia abre la fuente', (tester) async {
    String? tocado;
    Fuente? fuenteTocada;
    await tester.pumpWidget(
      MaterialApp(
        theme: temaTuTurno(Brightness.light),
        home: Scaffold(
          body: TextoConTerminos(
            texto: 'Antes de los 14 años no hay responsabilidad penal [A-017].',
            terminos: const ['Responsabilidad penal'],
            fuentes: const [_fuente],
            onTermino: (t) => tocado = t,
            onFuente: (f) => fuenteTocada = f,
          ),
        ),
      ),
    );

    await tester.tapOnText(find.textRange.ofSubstring('responsabilidad penal'));
    expect(tocado, 'Responsabilidad penal');

    await tester.tap(find.byType(NumeroFuente));
    expect(fuenteTocada?.id, 'A-017');
  });

  testWidgets('sin onFuente, la referencia abre la hoja con la norma', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: temaTuTurno(Brightness.light),
        home: const Scaffold(
          body: TextoConTerminos(texto: 'Lo dice la ley [A-017].', fuentes: [_fuente]),
        ),
      ),
    );
    await tester.tap(find.byType(NumeroFuente));
    await tester.pumpAndSettle();
    expect(find.text('LO 5/2000'), findsOneWidget);
    expect(find.text('Ley de responsabilidad penal de los menores'), findsOneWidget);
  });

  test('etiquetaFuente', () {
    expect(etiquetaFuente(_fuente), 'LO 5/2000 · art. 3');
    expect(etiquetaFuente(const Fuente(id: 'A-1', titulo: 'Título', norma: 'CE', articulo: '')), 'CE');
    expect(etiquetaFuente(const Fuente(id: 'A-1', titulo: 'Título', norma: '', articulo: '')), 'Título');
  });
}
