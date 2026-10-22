import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/borrar_todo.dart';
import 'package:tuturno/core/providers.dart';
import 'package:tuturno/features/glosario/detalle_termino.dart';
import 'package:tuturno/features/glosario/favoritos.dart';
import 'package:tuturno/features/glosario/glosario_screen.dart';
import 'package:tuturno/widgets/iconos/iconos.dart';
import 'package:tuturno/widgets/movimiento/contador_flip.dart';

import '../a1/helpers.dart';

// «Mis palabras» del glosario (plan v2, producto §5.7): se guardan en el móvil y se filtran con su chip.

/// Un contenedor con [valores] en el móvil y [favoritosProvider] escuchado (como cuando se ve el glosario).
Future<ProviderContainer> _contenedor(Map<String, Object> valores) async {
  SharedPreferences.setMockInitialValues(valores);
  final prefs = await SharedPreferences.getInstance();
  return _abrir(prefs);
}

ProviderContainer _abrir(SharedPreferences prefs) {
  final contenedor = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
  addTearDown(contenedor.dispose);
  contenedor.listen(favoritosProvider, (_, _) {});
  return contenedor;
}

/// El chip de filtro con el texto [texto].
Finder _chip(String texto) => find.widgetWithText(ChoiceChip, texto);

/// La estrella de las cartas guardadas (se lee «En Mis palabras»).
final _estrella = find.byWidgetPredicate((w) => w is IconoTuTurno && w.semanticLabel == 'En Mis palabras');

/// El número del recuento («3 palabras explicadas fácil»).
int _recuento(WidgetTester tester) => tester.widget<ContadorFlip>(find.byType(ContadorFlip)).valor;

void main() {
  group('favoritosProvider', () {
    test('guardar y quitar se guardan en el móvil y sobreviven a cerrar la app', () async {
      final c = await _contenedor({});
      final notifier = c.read(favoritosProvider.notifier);
      expect(c.read(favoritosProvider), isEmpty);

      notifier.guardar('G-citacion');
      notifier.guardar('G-testigo');
      notifier.guardar('G-citacion');
      expect(c.read(favoritosProvider), {'G-citacion', 'G-testigo'});
      final prefs = c.read(sharedPreferencesProvider);
      expect(prefs.getString(FavoritosNotifier.clave), '["G-citacion","G-testigo"]');

      // Como si se cerrara la app: otro contenedor con lo que hay en el móvil.
      expect(_abrir(prefs).read(favoritosProvider), {'G-citacion', 'G-testigo'});

      notifier.quitar('G-testigo');
      expect(c.read(favoritosProvider), {'G-citacion'});
      expect(prefs.getString(FavoritosNotifier.clave), '["G-citacion"]');
    });

    test('alternar guarda y quita, y dice cómo queda', () async {
      final c = await _contenedor({});
      final notifier = c.read(favoritosProvider.notifier);
      expect(notifier.alternar('G-citacion'), isTrue);
      expect(notifier.contiene('G-citacion'), isTrue);
      expect(notifier.alternar('G-citacion'), isFalse);
      expect(c.read(favoritosProvider), isEmpty);
    });

    test('un valor roto o de otro tipo da la lista vacía', () async {
      for (final roto in <Object>['{no es json', '{"a": 1}', 7, '[1, "", "  ", "G-citacion"]']) {
        final c = await _contenedor({FavoritosNotifier.clave: roto});
        expect(c.read(favoritosProvider), roto is String && roto.startsWith('[') ? {'G-citacion'} : isEmpty);
      }
    });

    test('usa la clave que borra «Borrar todo»', () {
      expect(FavoritosNotifier.clave, 'glosario.favoritos');
      expect(clavesDeUsuario, contains(FavoritosNotifier.clave));
    });

    test('después de «Borrar todo», al volver al glosario no queda ninguna guardada', () async {
      SharedPreferences.setMockInitialValues({FavoritosNotifier.clave: '["G-citacion"]'});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(c.dispose);
      final glosario = c.listen(favoritosProvider, (_, _) {});
      expect(c.read(favoritosProvider), {'G-citacion'});

      // Se cierra el glosario, se borra todo desde Ajustes y se vuelve a abrir.
      glosario.close();
      await Future<void>.delayed(Duration.zero);
      await prefs.remove(FavoritosNotifier.clave);
      c.listen(favoritosProvider, (_, _) {});
      expect(c.read(favoritosProvider), isEmpty);
    });
  });

  group('chip «Mis palabras»', () {
    testWidgets('cuenta las guardadas que existen y filtra la lista', (tester) async {
      final router = await arrancarApp(
        tester,
        // Un id que ya no está en el glosario se ignora.
        preferencias: {FavoritosNotifier.clave: '["G-citacion", "G-ya-no-existe"]'},
      );
      await irA(tester, router, '/glosario');

      expect(_chip('Todas'), findsOneWidget);
      expect(_chip('Mis palabras (1)'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(_chip('Todas')).selected, isTrue);
      expect(_recuento(tester), 3);
      // La carta guardada lleva su estrella.
      expect(_estrella, findsOneWidget);

      await tester.tap(_chip('Mis palabras (1)'));
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(_chip('Mis palabras (1)')).selected, isTrue);
      expect(find.text('Citación'), findsOneWidget);
      expect(find.text('Abogado o abogada'), findsNothing);
      expect(find.text('Fiscalía de Menores'), findsNothing);
      expect(_recuento(tester), 1);
      expect(find.text('palabra explicada fácil'), findsOneWidget);

      // Con la búsqueda: lo que no está en Mis palabras se busca en todas.
      await tester.enterText(find.byType(TextField), 'fiscalia');
      await tester.pumpAndSettle();
      expect(find.text('No está en Mis palabras'), findsOneWidget);
      expect(find.text('Pero en el glosario sí hay palabras con «fiscalia».'), findsOneWidget);
      await tester.tap(find.text('Buscar en todas'));
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(_chip('Todas')).selected, isTrue);
      expect(find.text('Fiscalía de Menores'), findsOneWidget);
    });

    testWidgets('vacío: explica cómo guardar una palabra y deja volver a todas', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/glosario');

      await tester.tap(_chip('Mis palabras (0)'));
      await tester.pumpAndSettle();
      expect(find.text(tituloMisPalabrasVacia), findsOneWidget);
      expect(find.text(pistaMisPalabrasVacia), findsOneWidget);
      expect(pistaMisPalabrasVacia, 'Abre una carta y toca «Guardar en mis palabras».');
      expect(find.text('Citación'), findsNothing);

      await tester.tap(find.text('Ver todas las palabras'));
      await tester.pumpAndSettle();
      expect(find.text('Citación'), findsOneWidget);
      expect(_recuento(tester), 3);
    });

    testWidgets('desde el detalle se guarda y se quita, con su confirmación, y el chip lo cuenta', (tester) async {
      final router = await arrancarApp(tester);
      await irA(tester, router, '/glosario');
      final prefs = ProviderScope.containerOf(tester.element(find.byType(GlosarioScreen)))
          .read(sharedPreferencesProvider);

      await tester.tap(find.text('Citación'));
      await tester.pumpAndSettle();
      expect(find.text('Guardar en mis palabras'), findsOneWidget);
      expect(find.text(avisoGuardada), findsNothing);

      await pulsar(tester, find.text('Guardar en mis palabras'));
      expect(find.text('Quitar de mis palabras'), findsOneWidget);
      expect(find.text(avisoGuardada), findsOneWidget);
      expect(prefs.getString(FavoritosNotifier.clave), '["G-citacion"]');

      await pulsar(tester, find.text('Quitar de mis palabras'));
      expect(find.text('Guardar en mis palabras'), findsOneWidget);
      expect(find.text(avisoQuitada), findsOneWidget);
      expect(prefs.getString(FavoritosNotifier.clave), '[]');

      await pulsar(tester, find.text('Guardar en mis palabras'));
      Navigator.of(tester.element(find.byType(DetalleTermino))).pop();
      await tester.pumpAndSettle();
      expect(_chip('Mis palabras (1)'), findsOneWidget);
      expect(_estrella, findsOneWidget);
    });

    testWidgets('si se quita desde el detalle con «Mis palabras» elegido, sale de la lista', (tester) async {
      final router = await arrancarApp(tester, preferencias: {FavoritosNotifier.clave: '["G-citacion", "G-abogado"]'});
      await irA(tester, router, '/glosario');
      await tester.tap(_chip('Mis palabras (2)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Citación'));
      await tester.pumpAndSettle();
      await pulsar(tester, find.text('Quitar de mis palabras'));
      Navigator.of(tester.element(find.byType(DetalleTermino))).pop();
      await tester.pumpAndSettle();

      expect(_chip('Mis palabras (1)'), findsOneWidget);
      expect(find.text('Citación'), findsNothing);
      expect(find.text('Abogado o abogada'), findsOneWidget);
    });
  });
}
