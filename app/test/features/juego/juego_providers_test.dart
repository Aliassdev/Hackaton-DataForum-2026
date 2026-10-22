import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/content_repo.dart';
import 'package:tuturno/core/progreso.dart';
import 'package:tuturno/core/providers.dart' show sharedPreferencesProvider;
import 'package:tuturno/features/juego/juego_providers.dart';

import 'fakes.dart';

Future<ProviderContainer> _contenedor({
  Map<String, String> casos = const {'caso-prueba.json': casoPrueba},
  Map<String, Object> preferencias = const {},
}) async {
  final contenedor = ProviderContainer(
    retry: (_, _) => null,
    overrides: await overridesJuego(casos: casos, preferencias: preferencias),
  );
  addTearDown(contenedor.dispose);
  // Mantiene vivo el progreso (como lo hace la pantalla que lo mira).
  contenedor.listen(progresoProvider, (_, _) {});
  return contenedor;
}

Map<String, dynamic> _guardado(ProviderContainer c) =>
    jsonDecode(c.read(sharedPreferencesProvider).getString('progreso')!) as Map<String, dynamic>;

void main() {
  group('casosProvider', () {
    test('solo los validados, con el oficial primero aunque por título vaya después', () async {
      final c = await _contenedor(
        casos: {
          'caso-extra.json': casoExtra,
          'caso-borrador.json': casoBorrador,
          'caso-sala-gesell.json': casoOficialDeEjemplo(),
          'caso-prueba.json': casoPrueba,
        },
      );
      final casos = await c.read(casosProvider.future);
      expect(casos.map((c) => c.id), ['caso-sala-gesell', 'caso-extra', 'caso-prueba']);
    });

    test('un fichero roto no deja sin casos al resto', () async {
      silenciarAvisos();
      final c = await _contenedor(casos: {'roto.json': '{"id": 3', 'caso-prueba.json': casoPrueba});
      expect((await c.read(casosProvider.future)).map((c) => c.id), ['caso-prueba']);
    });

    test('mientras content/ está vacío, usa los ejemplos de assets/mock/content', () async {
      silenciarAvisos();
      final ficheros = {'${ContentRepo.raizEjemplos}/juego/caso-sala-gesell.json': casoOficialDeEjemplo()};
      final c = ProviderContainer(
        retry: (_, _) => null,
        overrides: await overridesJuego(
          repo: ContentRepo(
            bundle: BundleEnMemoria(ficheros),
            usarEjemplos: true,
            listarAssets: () async => ficheros.keys.toList(),
          ),
        ),
      );
      addTearDown(c.dispose);
      final casos = await c.read(casosProvider.future);
      expect(casos.single.protagonista, 'Lucía');
    });

    test('coleccionDe no repite cartas que salen en dos casos', () async {
      final c = await _contenedor(
        casos: {'a.json': casoPrueba, 'b.json': casoPrueba.replaceAll('caso-prueba', 'otro')},
      );
      final casos = await c.read(casosProvider.future);
      expect(coleccionDe(casos).map((e) => e.carta.id), ['R-entender', 'R-acompanada', 'R-explicar']);
      expect(indiceEnColeccion(casos, 'R-explicar'), 2);
    });
  });

  group('partida', () {
    test('al acertar, la carta nueva se guarda en el móvil y suma puntos', () async {
      final c = await _contenedor();
      final partida = partidaProvider('caso-prueba');
      await c.read(partida.future);

      await c.read(partida.notifier).elegir(0);

      expect(c.read(partida).value!.cartaNueva?.id, 'R-entender');
      expect(c.read(progresoProvider).cartas, {'R-entender'});
      expect(c.read(progresoProvider).xp, xpPorCarta);
      expect(_guardado(c)['cartas'], ['R-entender']);
    });

    test('una carta que ya se tenía no vuelve a sumar puntos', () async {
      final c = await _contenedor(preferencias: progresoGuardado(cartas: ['R-entender'], xp: 30));
      final partida = partidaProvider('caso-prueba');
      await c.read(partida.future);

      await c.read(partida.notifier).elegir(0);

      expect(c.read(partida).value!.cartaNueva, isNull);
      expect(c.read(partida).value!.cartasGanadas, ['R-entender']);
      expect(c.read(progresoProvider).xp, 30);
    });

    test('al fallar no se guarda nada; se puede volver a intentar', () async {
      final c = await _contenedor();
      final partida = partidaProvider('caso-prueba');
      await c.read(partida.future);

      await c.read(partida.notifier).elegir(1);
      expect(c.read(progresoProvider).cartas, isEmpty);

      c.read(partida.notifier).reintentar();
      expect(c.read(partida).value!.eleccion, isNull);
      await c.read(partida.notifier).elegir(0);
      expect(c.read(progresoProvider).cartas, {'R-entender'});
    });

    test('al llegar al final, el caso queda guardado como terminado', () async {
      final c = await _contenedor();
      final partida = partidaProvider('caso-prueba');
      final notifier = c.read(partida.notifier);
      await c.read(partida.future);

      await notifier.elegir(0);
      await notifier.avanzar();
      await notifier.avanzar();
      await notifier.elegir(1);
      await notifier.avanzar();
      expect(c.read(progresoProvider).casosTerminados, isEmpty);
      await notifier.avanzar();

      expect(c.read(partida).value!.terminada, isTrue);
      expect(c.read(progresoProvider).casosTerminados, {'caso-prueba'});
      expect(_guardado(c)['casos'], ['caso-prueba']);
      expect(c.read(progresoProvider).cartas, {'R-entender', 'R-explicar'});
    });

    test('la partida se recuerda mientras la app está abierta y se puede reiniciar', () async {
      final c = await _contenedor();
      final partida = partidaProvider('caso-prueba');
      await c.read(partida.future);
      await c.read(partida.notifier).elegir(0);
      await c.read(partida.notifier).avanzar();

      expect(c.read(partida).value!.escena.id, 'E2');

      c.read(partida.notifier).reiniciar();
      expect(c.read(partida).value!.escena.id, 'E1');
      expect(c.read(partida).value!.empezada, isFalse);
      expect(c.read(progresoProvider).cartas, {'R-entender'}, reason: 'las cartas ganadas se quedan');
    });

    test('un caso que no existe da CasoNoEncontrado', () async {
      final c = await _contenedor();
      final partida = partidaProvider('no-existe');
      await expectLater(c.read(partida.future), throwsA(isA<CasoNoEncontrado>()));
    });
  });

  test('SharedPreferences de prueba: empieza sin progreso', () async {
    final c = await _contenedor();
    expect(c.read(sharedPreferencesProvider), isA<SharedPreferences>());
    expect(c.read(progresoProvider).cartas, isEmpty);
  });
}
