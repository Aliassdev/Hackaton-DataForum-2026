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

/// Los estilos del tema tal y como los ven los widgets: `Theme.of` les añade la geometría de la tipografía (tamaños e
/// interlineados de Material 3; el español usa la «englishLike»).
TextTheme _comoLoVen(ThemeData tema) => ThemeData.localize(tema, tema.typography.englishLike).textTheme;

/// Los estilos de los titulares grandes (display y headline).
List<TextStyle?> _titulares(TextTheme t) => [
  t.displayLarge,
  t.displayMedium,
  t.displaySmall,
  t.headlineLarge,
  t.headlineMedium,
  t.headlineSmall,
];

/// El resto: títulos de barras y tarjetas, cuerpo y etiquetas.
List<TextStyle?> _textos(TextTheme t) => [
  t.titleLarge,
  t.titleMedium,
  t.titleSmall,
  t.bodyLarge,
  t.bodyMedium,
  t.bodySmall,
  t.labelLarge,
  t.labelMedium,
  t.labelSmall,
];

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

      test('titulares grandes con MaryKate (la letra del logotipo); el resto, también las barras, con Nunito', () {
        expect(Fuentes.texto, 'Nunito');
        expect(Fuentes.titulos, 'MaryKate');
        for (final t in [tema.textTheme, tema.primaryTextTheme]) {
          for (final estilo in _titulares(t)) {
            expect(estilo!.fontFamily, Fuentes.titulos);
            // Solo a partir de 22 px: a tamaños pequeños, su trazo fino se lee peor.
            expect(estilo.fontSize, greaterThanOrEqualTo(22));
            // Su único peso, pedido como normal: los signos que le faltan (º, …, –) salen de Nunito normal.
            expect(estilo.fontWeight, FontWeight.w400);
            expect(estilo.fontFamilyFallback, [Fuentes.texto]);
            // Sus espacios entre palabras son muy anchos: el tema los estrecha.
            expect(estilo.wordSpacing, lessThan(0));
          }
          for (final estilo in _textos(t)) {
            expect(estilo!.fontFamily, Fuentes.texto);
          }
        }
        // Los títulos de las barras (titleLarge) y los botones (titleMedium y titleSmall), en Nunito.
        expect(tema.appBarTheme.titleTextStyle!.fontFamily, Fuentes.texto);
        expect(tema.filledButtonTheme.style!.textStyle!.resolve({})!.fontFamily, Fuentes.texto);
        expect(tema.outlinedButtonTheme.style!.textStyle!.resolve({})!.fontFamily, Fuentes.texto);
        expect(tema.textButtonTheme.style!.textStyle!.resolve({})!.fontFamily, Fuentes.texto);
        expect(tema.tooltipTheme.textStyle!.fontFamily, Fuentes.texto);
        // El color del texto sigue siendo la tinta del tema.
        expect(tema.textTheme.headlineMedium!.color, tema.colorScheme.onSurface);
        expect(tema.textTheme.displayLarge!.color, isNotNull);
      });

      group('con «lectura fácil»', () {
        final facil = temaTuTurno(brillo, lecturaFacil: true);

        test('todo el texto en Atkinson Hyperlegible, también los titulares, las barras y los botones', () {
          expect(Fuentes.lecturaFacil, 'AtkinsonHyperlegible');
          for (final t in [facil.textTheme, facil.primaryTextTheme]) {
            for (final estilo in [..._titulares(t), ..._textos(t)]) {
              expect(estilo!.fontFamily, Fuentes.lecturaFacil);
              expect(estilo.wordSpacing ?? 0, 0, reason: 'sin el estrechado de MaryKate');
            }
          }
          expect(facil.appBarTheme.titleTextStyle!.fontFamily, Fuentes.lecturaFacil);
          expect(facil.filledButtonTheme.style!.textStyle!.resolve({})!.fontFamily, Fuentes.lecturaFacil);
          expect(facil.textButtonTheme.style!.textStyle!.resolve({})!.fontFamily, Fuentes.lecturaFacil);
          expect(facil.chipTheme.labelStyle!.fontFamily, Fuentes.lecturaFacil);
          expect(facil.tooltipTheme.textStyle!.fontFamily, Fuentes.lecturaFacil);
        });

        test('con algo más de interlineado y los titulares en negrita, del mismo tamaño', () {
          // Lo que ven los widgets: Theme.of añade a los estilos los tamaños e interlineados de Material 3.
          final t = _comoLoVen(facil);
          final normal = _comoLoVen(tema);
          for (final (nombre, estilo, base) in [
            ('bodyLarge', t.bodyLarge, normal.bodyLarge),
            ('bodyMedium', t.bodyMedium, normal.bodyMedium),
            ('bodySmall', t.bodySmall, normal.bodySmall),
            ('labelLarge', t.labelLarge, normal.labelLarge),
            ('titleLarge', t.titleLarge, normal.titleLarge),
            ('titleMedium', t.titleMedium, normal.titleMedium),
          ]) {
            expect(estilo!.height, greaterThan(base!.height!), reason: nombre);
            expect(estilo.fontSize, base.fontSize, reason: nombre);
          }
          // El cuerpo, a 1,5 o más (WCAG 1.4.12).
          expect(t.bodyLarge!.height, greaterThanOrEqualTo(1.5));
          expect(t.bodyMedium!.height, greaterThanOrEqualTo(1.5));
          for (final (estilo, base) in [
            (t.displayLarge, normal.displayLarge),
            (t.displaySmall, normal.displaySmall),
            (t.headlineLarge, normal.headlineLarge),
            (t.headlineMedium, normal.headlineMedium),
            (t.headlineSmall, normal.headlineSmall),
          ]) {
            // Atkinson tiene negrita de verdad (700): sin MaryKate, es lo que distingue un titular.
            expect(estilo!.fontWeight, FontWeight.w700);
            expect(estilo.fontSize, base!.fontSize);
            expect(estilo.height, greaterThan(base.height!));
          }
          expect(t.headlineMedium!.color, facil.colorScheme.onSurface);
        });

        test('los colores y las formas no cambian', () {
          expect(facil.colorScheme, tema.colorScheme);
          expect(facil.extension<ColoresTuTurno>(), tema.extension<ColoresTuTurno>());
          expect(facil.scaffoldBackgroundColor, tema.scaffoldBackgroundColor);
          expect(facil.materialTapTargetSize, MaterialTapTargetSize.padded);
          expect(
            facil.filledButtonTheme.style!.minimumSize!.resolve({}),
            tema.filledButtonTheme.style!.minimumSize!.resolve({}),
          );
          expect(facil.chipTheme.selectedColor, ColoresMarca.amarillo);
        });
      });

      test('estiloCifras: los contadores en Nunito ExtraBold (y en Atkinson negrita con lectura fácil)', () {
        final cifras = estiloCifras(tema.textTheme.headlineMedium)!;
        expect(cifras.fontFamily, Fuentes.texto);
        expect(cifras.fontWeight, FontWeight.w800);
        expect(cifras.fontSize, tema.textTheme.headlineMedium!.fontSize);
        expect(cifras.color, tema.textTheme.headlineMedium!.color);
        expect(cifras.wordSpacing, 0);
        expect(cifras.fontFeatures, contains(const FontFeature.tabularFigures()));

        final facil = estiloCifras(temaTuTurno(brillo, lecturaFacil: true).textTheme.headlineMedium)!;
        expect(facil.fontFamily, Fuentes.lecturaFacil);
        expect(facil.fontWeight, FontWeight.w700);
        expect(estiloCifras(null), isNull);
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
  });

  group('pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    test('declara solo las cuatro familias de la marca', () {
      final familias = RegExp(r'^\s*- family: (\S+)\s*$', multiLine: true).allMatches(pubspec).map((m) => m[1]);
      expect(familias.toSet(), {Fuentes.texto, Fuentes.titulos, Fuentes.lecturaFacil, 'PixelifySans'});
    });

    test('Nunito con sus cuatro pesos, y cada fichero declara el suyo', () {
      for (final (fichero, peso) in [
        ('Nunito-Regular.ttf', 400),
        ('Nunito-SemiBold.ttf', 600),
        ('Nunito-Bold.ttf', 700),
        ('Nunito-ExtraBold.ttf', 800),
      ]) {
        expect(pubspec, contains('asset: assets/fonts/$fichero'));
        expect(pesoDeclarado(File('assets/fonts/$fichero').readAsBytesSync()), peso, reason: fichero);
      }
      expect(File('assets/fonts/Nunito-OFL.txt').existsSync(), isTrue, reason: 'su licencia va con la app');
    });

    test('Atkinson Hyperlegible (lectura fácil) y Pixelify Sans (Vive el caso) siguen declaradas', () {
      for (final fichero in [
        'AtkinsonHyperlegible-Regular.ttf',
        'AtkinsonHyperlegible-Bold.ttf',
        'PixelifySans-Regular.ttf',
        'PixelifySans-SemiBold.ttf',
        'PixelifySans-Bold.ttf',
      ]) {
        expect(pubspec, contains('asset: assets/fonts/$fichero'));
        expect(File('assets/fonts/$fichero').existsSync(), isTrue, reason: fichero);
      }
    });

    test('el agente de voz y la carpeta de imágenes de la justicia', () {
      expect(pubspec, contains('elevenlabs_agents: ^0.6.1'));
      expect(pubspec, contains('- assets/justicia/'));
      expect(Directory('assets/justicia').existsSync(), isTrue);
    });
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
