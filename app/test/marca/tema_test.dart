import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/tema.dart';

/// El peso que declara un fichero TrueType (usWeightClass de su tabla OS/2), que es el que usa Flutter.
int pesoDeclarado(Uint8List fuente) {
  final datos = ByteData.sublistView(fuente);
  final tablas = datos.getUint16(4);
  for (var i = 0; i < tablas; i++) {
    final registro = 12 + 16 * i;
    if (String.fromCharCodes(fuente.sublist(registro, registro + 4)) == 'OS/2') {
      return datos.getUint16(datos.getUint32(registro + 8) + 4);
    }
  }
  throw StateError('La fuente no tiene tabla OS/2');
}

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

      test('títulos grandes y números con MaryKate (la letra del logotipo); el resto con Atkinson Hyperlegible', () {
        final t = tema.textTheme;
        expect(Fuentes.titulos, 'MaryKate');
        for (final estilo in [
          t.displayLarge,
          t.displayMedium,
          t.displaySmall,
          t.headlineLarge,
          t.headlineMedium,
          t.headlineSmall,
        ]) {
          expect(estilo!.fontFamily, Fuentes.titulos);
          // Su único peso, pedido como normal: los signos que le faltan (º, …, –) salen de Atkinson normal.
          expect(estilo.fontWeight, FontWeight.w400);
          expect(estilo.fontFamilyFallback, [Fuentes.texto]);
          // Sus espacios entre palabras son muy anchos: el tema los estrecha.
          expect(estilo.wordSpacing, lessThan(0));
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

      test('la barra superior se tiñe de azul al desplazar, nunca de gris', () {
        final barra = tema.appBarTheme;
        final quieta = WidgetStateProperty.resolveAs<Color>(barra.backgroundColor!, {});
        final desplazada = WidgetStateProperty.resolveAs<Color>(barra.backgroundColor!, {WidgetState.scrolledUnder});
        expect(quieta, tema.colorScheme.surface);
        if (brillo == Brightness.light) {
          // Sin velo: el azul del tema sobre el papel cálido daba un gris (#EEEDEE).
          expect(barra.surfaceTintColor, Colors.transparent);
          expect(desplazada, isNot(quieta));
          expect(desplazada.b - desplazada.r, greaterThan(0.03), reason: 'azul pálido, no gris');
          expect(desplazada.computeLuminance(), greaterThan(0.85), reason: 'la tinta azul noche sigue siendo AAA');
        } else {
          expect(barra.surfaceTintColor, ColoresMarca.azulCielo);
        }
      });
    });
  }

  test('MaryKate está declarada y su fichero dice que pesa 900: Flutter nunca le simula la negrita', () {
    // Con un solo peso, Flutter la engorda (y la emborrona) si se pide 600 o más y el fichero declara 200 menos.
    expect(pesoDeclarado(File('assets/fonts/MaryKate-Medium-ES.ttf').readAsBytesSync()), 900);
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: ${Fuentes.titulos}'));
    expect(pubspec, contains('asset: assets/fonts/MaryKate-Medium-ES.ttf'));
    expect(pubspec, isNot(contains('family: LondrinaSolid')));
  });

  testWidgets('tinte() y bordeTinte(): el color principal tiñe con un azul claro de la marca (mezclado saldría gris)', (
    tester,
  ) async {
    late BuildContext contexto;
    Future<void> montar(Brightness brillo) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: temaTuTurno(brillo),
          home: Builder(
            builder: (context) {
              contexto = context;
              return const SizedBox();
            },
          ),
        ),
      );
      // Al cambiar de tema, MaterialApp lo anima: se espera a que acabe.
      await tester.pumpAndSettle();
    }

    await montar(Brightness.dark);
    expect(tinte(contexto, ColoresMarca.amarillo), ColoresMarca.azulCielo.withValues(alpha: 0.18));
    expect(tinte(contexto, ColoresTuTurno.oscuro.exito), ColoresTuTurno.oscuro.exito.withValues(alpha: 0.18));
    final fondo = Color.alphaBlend(tinte(contexto, ColoresMarca.amarillo), esquemaTuTurno(Brightness.dark).surface);
    expect(fondo.b - fondo.r, greaterThan(0.15), reason: 'azul, no gris');

    await montar(Brightness.light);
    // En claro, el azul eléctrico al 10 % sobre el papel cálido salía gris (#E9E9ED): tiñe con azul hielo.
    expect(tinte(contexto, ColoresMarca.azul), ColoresMarca.azulHielo.withValues(alpha: 0.8));
    final claro = Color.alphaBlend(tinte(contexto, ColoresMarca.azul), esquemaTuTurno(Brightness.light).surface);
    expect(claro.b - claro.r, greaterThan(0.06), reason: 'azul claro, no gris');
    expect(tinte(contexto, ColoresMarca.amarillo), ColoresMarca.amarillo.withValues(alpha: 0.10));
    expect(tinte(contexto, ColoresTuTurno.claro.exito), ColoresTuTurno.claro.exito.withValues(alpha: 0.10));

    expect(bordeTinte(ColoresMarca.amarillo), ColoresMarca.azulCielo.withValues(alpha: 0.3));
    expect(bordeTinte(ColoresMarca.azul), ColoresMarca.azul.withValues(alpha: 0.3));
  });

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
    // Las de los tickets: la corta, igual pero sin desenfoque (sigue la silueta); la amplia, la misma.
    final ticket = sombrasTicket(contexto, elevacion: 2);
    expect(ticket, hasLength(2));
    expect(ticket.first.blurRadius, 0);
    expect(ticket.first.color, sombras.first.color);
    expect(ticket.first.offset, sombras.first.offset);
    expect(ticket.last, sombras.last);

    await tester.pumpWidget(app(sinAnimaciones: true));
    expect(duracion(contexto, Duracion.media), Duration.zero);
  });
}
