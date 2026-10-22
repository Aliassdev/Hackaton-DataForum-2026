import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/tema.dart';

/// Contraste WCAG 2 entre dos colores opacos.
double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
}

/// AA para texto normal (4,5:1) y para iconos, bordes y texto grande (3:1).
const aa = 4.5;
const aaGrande = 3.0;
const aaa = 7.0;

void main() {
  group('marca', () {
    test('el amarillo va sobre azul o azul noche, nunca sobre blanco', () {
      expect(contraste(ColoresMarca.amarillo, ColoresMarca.azul), greaterThanOrEqualTo(aa));
      expect(contraste(ColoresMarca.amarillo, ColoresMarca.azulNoche), greaterThanOrEqualTo(aaa));
      expect(contraste(ColoresMarca.azulNoche, ColoresMarca.amarillo), greaterThanOrEqualTo(aaa));
      // La regla existe por esto: amarillo sobre blanco no llega ni a 1,5:1.
      expect(contraste(ColoresMarca.amarillo, Colors.white), lessThan(1.5));
    });

    test('texto blanco sobre el azul eléctrico es AAA y la tinta sobre el papel también', () {
      expect(contraste(Colors.white, ColoresMarca.azul), greaterThanOrEqualTo(aaa));
      expect(contraste(ColoresMarca.azulNoche, ColoresMarca.papel), greaterThanOrEqualTo(aaa));
      expect(contraste(ColoresMarca.ocre, ColoresMarca.papel), greaterThanOrEqualTo(aa));
      expect(contraste(Colors.white, ColoresMarca.rojoAyuda), greaterThanOrEqualTo(aa));
    });
  });

  for (final brillo in Brightness.values) {
    final nombre = brillo == Brightness.light ? 'claro' : 'oscuro';
    final e = esquemaTuTurno(brillo);
    final c = brillo == Brightness.light ? ColoresTuTurno.claro : ColoresTuTurno.oscuro;

    group('tema $nombre', () {
      test('texto sobre superficies y contenedores', () {
        expect(contraste(e.onSurface, e.surface), greaterThanOrEqualTo(aaa));
        for (final fondo in [
          e.surface,
          e.surfaceContainerLowest,
          e.surfaceContainerLow,
          e.surfaceContainer,
          e.surfaceContainerHigh,
          e.surfaceContainerHighest,
        ]) {
          expect(contraste(e.onSurface, fondo), greaterThanOrEqualTo(aaa), reason: 'onSurface sobre $fondo');
          expect(
            contraste(e.onSurfaceVariant, fondo),
            greaterThanOrEqualTo(aa),
            reason: 'onSurfaceVariant sobre $fondo',
          );
          expect(contraste(e.primary, fondo), greaterThanOrEqualTo(aa), reason: 'primary sobre $fondo');
        }
        expect(contraste(e.outline, e.surface), greaterThanOrEqualTo(aaGrande));
        expect(contraste(e.onInverseSurface, e.inverseSurface), greaterThanOrEqualTo(aaa));
        expect(contraste(e.inversePrimary, e.inverseSurface), greaterThanOrEqualTo(aa));
      });

      test('cada color con su «on»', () {
        final pares = {
          'primary': (e.onPrimary, e.primary),
          'primaryContainer': (e.onPrimaryContainer, e.primaryContainer),
          'secondary': (e.onSecondary, e.secondary),
          'secondaryContainer': (e.onSecondaryContainer, e.secondaryContainer),
          'tertiary': (e.onTertiary, e.tertiary),
          'tertiaryContainer': (e.onTertiaryContainer, e.tertiaryContainer),
          'error': (e.onError, e.error),
          'errorContainer': (e.onErrorContainer, e.errorContainer),
        };
        pares.forEach((rol, par) {
          expect(contraste(par.$1, par.$2), greaterThanOrEqualTo(aa), reason: rol);
        });
      });

      test('color de texto sobre la superficie: terciario, error y éxito', () {
        expect(contraste(e.tertiary, e.surface), greaterThanOrEqualTo(aa));
        expect(contraste(e.error, e.surface), greaterThanOrEqualTo(aa));
        expect(contraste(c.exito, e.surface), greaterThanOrEqualTo(aa));
        expect(contraste(c.sobreExito, c.exito), greaterThanOrEqualTo(aa));
      });

      test('módulos y Ayuda llevan texto blanco AA; su color principal se ve como icono sobre la superficie', () {
        for (final (modulo, colores) in [('juego', c.juego), ('aprende', c.aprende), ('pregunta', c.pregunta)]) {
          for (final color in colores) {
            expect(contraste(Colors.white, color), greaterThanOrEqualTo(aa), reason: '$modulo $color');
          }
          expect(contraste(colores.first, e.surface), greaterThanOrEqualTo(aaGrande), reason: modulo);
        }
        expect(contraste(Colors.white, c.ayuda), greaterThanOrEqualTo(aa));
        expect(contraste(c.ayuda, e.surface), greaterThanOrEqualTo(aaGrande));
      });

      test('tickets y sellos', () {
        expect(contraste(c.tintaTicket, c.ticket), greaterThanOrEqualTo(aaa));
        expect(contraste(c.sello, e.surface), greaterThanOrEqualTo(aa));
        expect(contraste(c.sello, c.ticket), greaterThanOrEqualTo(aa));
      });

      testWidgets('texto sobre los tintes suaves (tinte())', (tester) async {
        late BuildContext contexto;
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
        Color sobre(Color color) => Color.alphaBlend(tinte(contexto, color), e.surface);
        for (final (nombre, color) in [
          ('primary', e.primary),
          ('tertiary', e.tertiary),
          ('error', e.error),
          ('exito', c.exito),
          ('pregunta', c.pregunta.first),
        ]) {
          final fondo = sobre(color);
          expect(contraste(e.onSurface, fondo), greaterThanOrEqualTo(aa), reason: 'onSurface sobre tinte $nombre');
          expect(
            contraste(e.onSurfaceVariant, fondo),
            greaterThanOrEqualTo(aa),
            reason: 'onSurfaceVariant sobre tinte $nombre',
          );
        }
        for (final (nombre, color) in [
          ('primary', e.primary),
          ('tertiary', e.tertiary),
          ('error', e.error),
          ('exito', c.exito),
        ]) {
          expect(contraste(color, sobre(color)), greaterThanOrEqualTo(aa), reason: '$nombre sobre su tinte');
        }
      });
    });
  }
}
