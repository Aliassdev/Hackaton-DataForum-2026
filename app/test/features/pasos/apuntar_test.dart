import 'package:flutter/widgets.dart';

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/mis_preguntas.dart';
import 'package:tuturno/core/progreso.dart' show relojProvider;
import 'package:tuturno/core/providers.dart';
import 'package:tuturno/features/pasos/linea_pasos.dart' show textoApuntado, tooltipApuntar, tooltipQuitarApunte;

import 'datos.dart';

// «Apuntar» en Mis preguntas desde un paso (plan v2, producto §5.2): junto a cada cosa que puedes pedir, un botón de
// 48 px. Guarda el texto, el paso de origen y sus fuentes; vuelve a tocarlo y se quita; y la lista sobrevive a
// reiniciar la app (shared_preferences).

/// La entrevista en la Sala Gesell (paso 4 del itinerario de prueba), con sus dos cosas que pedir.
const _paso = 'La entrevista en la Sala Gesell';
const _descanso = 'Un descanso';

ProviderContainer _contenedor(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.text(_paso)));

/// El botón «Apuntar» que va con [texto].
Finder _botonDe(String texto, {String tooltip = tooltipApuntar}) => find.descendant(
  of: find.ancestor(of: find.text(texto), matching: find.byType(Row)).first,
  matching: find.byTooltip(tooltip),
);

/// Hace visible [finder] y lo pulsa.
Future<void> _tocar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _abrirEntrevista(WidgetTester tester) async {
  await tester.ensureVisible(find.text(_paso));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_paso));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('apuntar guarda el texto, el paso de origen y sus fuentes, y sale «Apuntado en Mis preguntas»', (
    tester,
  ) async {
    await montarLinea(
      tester,
      repo: repoCon({real('victima'): itinerarioConFases}).$1,
      overrides: [relojProvider.overrideWithValue(() => DateTime(2026, 10, 22, 10))],
    );
    await _abrirEntrevista(tester);

    final boton = _botonDe(_descanso);
    expect(boton, findsOneWidget);
    // Zona táctil de 48 px.
    expect(tester.getSize(boton).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(boton).height, greaterThanOrEqualTo(48));

    await tester.ensureVisible(boton);
    await tester.pumpAndSettle();
    await tester.tap(boton);
    await tester.pump();

    final apuntes = _contenedor(tester).read(misPreguntasProvider);
    expect(apuntes, hasLength(1));
    final apunte = apuntes.single;
    expect(apunte.texto, _descanso);
    expect(apunte.tipo, TipoApunte.pedir);
    expect(apunte.origen, _paso);
    expect(apunte.fuentes, ['LECrim, art. 449 ter', 'LECrim, art. 449 bis']);
    expect(find.text(textoApuntado), findsOneWidget);
    // Sin router (la línea suelta), la acción «Ver» no sale; con la app, lleva a /mis-preguntas.
    await tester.pumpAndSettle();

    // Ahora está marcado: el mismo botón dice «Quitar de Mis preguntas».
    expect(_botonDe(_descanso, tooltip: tooltipQuitarApunte), findsOneWidget);
  });

  testWidgets('tocarlo otra vez lo quita de Mis preguntas', (tester) async {
    await montarLinea(tester, repo: repoCon({real('victima'): itinerarioConFases}).$1);
    await _abrirEntrevista(tester);

    await _tocar(tester, _botonDe(_descanso));
    expect(_contenedor(tester).read(misPreguntasProvider), hasLength(1));

    await _tocar(tester, _botonDe(_descanso, tooltip: tooltipQuitarApunte));
    expect(_contenedor(tester).read(misPreguntasProvider), isEmpty);
    expect(_botonDe(_descanso), findsOneWidget);
  });

  testWidgets('lo apuntado sobrevive a reiniciar la app (se guarda en el móvil)', (tester) async {
    await montarLinea(tester, repo: repoCon({real('victima'): itinerarioConFases}).$1);
    await _abrirEntrevista(tester);
    await _tocar(tester, _botonDe(_descanso));

    final prefs = await SharedPreferences.getInstance();
    final guardado = jsonDecode(prefs.getString(MisPreguntasNotifier.clave)!) as List<Object?>;
    expect(guardado, hasLength(1));
    expect((guardado.single! as Map<String, Object?>)['origen'], _paso);

    // «Reiniciar»: un contenedor nuevo con las mismas preferencias lee lo mismo.
    final nuevo = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(nuevo.dispose);
    final releidos = nuevo.read(misPreguntasProvider);
    expect(releidos.single.texto, _descanso);
    expect(releidos.single.origen, _paso);
    expect(releidos.single.fuentes, ['LECrim, art. 449 ter', 'LECrim, art. 449 bis']);
  });

  testWidgets('con 30 apuntes, no apunta más y lo dice', (tester) async {
    await montarLinea(
      tester,
      repo: repoCon({real('victima'): itinerarioConFases}).$1,
      preferencias: {
        MisPreguntasNotifier.clave: jsonEncode([
          for (var i = 0; i < maxApuntes; i++) {'id': '$i', 'texto': 'Pregunta $i', 'tipo': 'preguntar'},
        ]),
      },
    );
    await _abrirEntrevista(tester);

    await _tocar(tester, _botonDe(_descanso));
    expect(_contenedor(tester).read(misPreguntasProvider), hasLength(maxApuntes));
    expect(find.text('Has llegado a 30. Quita alguna para apuntar más.'), findsOneWidget);
  });

  testWidgets('con apuntar: false, no hay botones', (tester) async {
    await montarLinea(tester, repo: repoCon({real('victima'): itinerarioConFases}).$1, apuntar: false);
    await _abrirEntrevista(tester);
    expect(find.text(_descanso), findsOneWidget);
    expect(find.byTooltip(tooltipApuntar), findsNothing);
  });
}
