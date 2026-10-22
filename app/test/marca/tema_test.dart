import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/tema.dart';

void main() {
  for (final brillo in Brightness.values) {
    group('temaTuTurno(${brillo.name})', () {
      final tema = temaTuTurno(brillo);

      test('usa el esquema de la marca y Material 3', () {
        expect(tema.useMaterial3, isTrue);
        expect(tema.brightness, brillo);
        expect(tema.colorScheme, esquemaTuTurno(brillo));
        expect(tema.scaffoldBackgroundColor, tema.colorScheme.surface);
        expect(
          tema.colorScheme.primary,
          brillo == Brightness.light ? ColoresMarca.azul : ColoresMarca.amarillo,
          reason: 'claro: azul eléctrico; oscuro: acentos amarillos',
        );
      });

      test('trae los colores propios de TuTurno', () {
        final colores = tema.extension<ColoresTuTurno>();
        expect(colores, brillo == Brightness.light ? ColoresTuTurno.claro : ColoresTuTurno.oscuro);
        expect(colores!.juego, hasLength(2));
        expect(colores.aprende, hasLength(2));
        expect(colores.pregunta, hasLength(2));
        expect(colores.confeti, isNotEmpty);
        expect(colores.holografico.length, greaterThanOrEqualTo(2));
        expect(colores.fondoPapel, isNotEmpty);
      });

      test('títulos grandes y números con MaryKate; el resto con Atkinson Hyperlegible', () {
        final t = tema.textTheme;
        expect(Fuentes.titulos, 'MaryKate');
        for (final estilo in [t.displayLarge, t.displayMedium, t.displaySmall]) {
          expect(estilo!.fontFamily, Fuentes.titulos);
          // MaryKate tiene un solo peso: se pide normal para que los signos que le faltan salgan de Atkinson normal.
          expect(estilo.fontWeight, FontWeight.w400);
          expect(estilo.fontFamilyFallback, [Fuentes.texto]);
        }
        for (final estilo in [t.headlineLarge, t.headlineMedium, t.headlineSmall]) {
          expect(estilo!.fontFamily, Fuentes.titulos);
        }
        for (final estilo in [
          t.titleLarge,
          t.titleMedium,
          t.titleSmall,
          t.bodyLarge,
          t.bodyMedium,
          t.bodySmall,
          t.labelLarge,
          t.labelMedium,
          t.labelSmall,
        ]) {
          expect(estilo!.fontFamily, Fuentes.texto);
        }
        expect(tema.appBarTheme.titleTextStyle!.fontFamily, Fuentes.texto);
        // El color del texto sigue siendo la tinta del tema.
        expect(t.headlineMedium!.color, tema.colorScheme.onSurface);
        expect(t.displayLarge!.color, isNotNull);
      });

      test('zonas táctiles de 48 px como mínimo', () {
        expect(tema.materialTapTargetSize, MaterialTapTargetSize.padded);
        final relleno = tema.filledButtonTheme.style!.minimumSize!.resolve({})!;
        expect(relleno.height, greaterThanOrEqualTo(48));
        final texto = tema.textButtonTheme.style!.minimumSize!.resolve({})!;
        expect(texto.height, greaterThanOrEqualTo(48));
        final icono = tema.iconButtonTheme.style!.minimumSize!.resolve({})!;
        expect(icono.height, greaterThanOrEqualTo(48));
      });

      test('el chip seleccionado es una pegatina amarilla con tinta azul noche', () {
        expect(tema.chipTheme.selectedColor, ColoresMarca.amarillo);
        final etiqueta = tema.chipTheme.labelStyle!;
        expect(etiqueta.fontFamily, Fuentes.texto);
        final color = etiqueta.color! as WidgetStateColor;
        expect(color.resolve({WidgetState.selected}), ColoresMarca.azulNoche);
        expect(color.resolve({}), tema.colorScheme.onSurface);
      });

      test('el botón con borde apaga el borde si está desactivado', () {
        final borde = tema.outlinedButtonTheme.style!.side!;
        expect(borde.resolve({})!.color, tema.colorScheme.primary);
        expect(borde.resolve({WidgetState.disabled})!.color, isNot(tema.colorScheme.primary));
      });
    });
  }

  test('ColoresTuTurno se mezcla entre temas y copyWith conserva lo que no cambia', () {
    final mitad = ColoresTuTurno.claro.lerp(ColoresTuTurno.oscuro, 0.5);
    expect(mitad.juego, hasLength(2));
    expect(mitad.ayuda, Color.lerp(ColoresTuTurno.claro.ayuda, ColoresTuTurno.oscuro.ayuda, 0.5));
    expect(ColoresTuTurno.claro.lerp(null, 0.5), ColoresTuTurno.claro);
    // Listas de distinta longitud: cambia de una a otra a mitad, sin fallar.
    final otra = ColoresTuTurno.claro.copyWith(confeti: const [Colors.red]);
    expect(ColoresTuTurno.claro.lerp(otra, 0.2).confeti, ColoresTuTurno.claro.confeti);
    expect(ColoresTuTurno.claro.lerp(otra, 0.8).confeti, const [Colors.red]);

    final copia = ColoresTuTurno.claro.copyWith(exito: Colors.teal);
    expect(copia.exito, Colors.teal);
    expect(copia.juego, ColoresTuTurno.claro.juego);
    expect(copia.sello, ColoresTuTurno.claro.sello);
  });

  testWidgets('duracion() y sombrasPapel() responden al entorno', (tester) async {
    late BuildContext contexto;
    Widget app({required bool sinAnimaciones}) => MaterialApp(
      theme: temaTuTurno(Brightness.light),
      builder: (context, hijo) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: sinAnimaciones),
        child: hijo!,
      ),
      home: Builder(
        builder: (context) {
          contexto = context;
          return const SizedBox();
        },
      ),
    );
    await tester.pumpWidget(app(sinAnimaciones: false));
    expect(duracion(contexto, Duracion.media), Duracion.media);
    final sombras = sombrasPapel(contexto, elevacion: 2);
    expect(sombras, hasLength(2));
    expect(sombras.first.color, ColoresTuTurno.claro.sombraPapel);
    expect(sombras.last.blurRadius, greaterThan(sombras.first.blurRadius));

    await tester.pumpWidget(app(sinAnimaciones: true));
    expect(duracion(contexto, Duracion.media), Duration.zero);
  });
}
