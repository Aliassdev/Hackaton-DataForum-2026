import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/content_repo.dart';
import 'package:tuturno/core/entrada.dart';
import 'package:tuturno/core/providers.dart';
import 'package:tuturno/features/pasos/pasos.dart';

import 'datos.dart';

/// Itinerario validado de testigo con pasos sin fuentes de verdad (que no se deben enseñar).
const _conPasoSinFuente = '''
{"rol": "testigo", "validado": true, "pasos": [
  {"id": "P1", "nombre": "Te llega una citación", "fuentes": ["Ley 4/2015, art. 4"]},
  {"id": "P2", "nombre": "Paso sin fuente", "fuentes": []},
  {"id": "P3", "nombre": "Paso con fuente vacía", "fuentes": ["  "]},
  {"id": "P4", "nombre": "Declaras", "fuentes": ["LECrim, art. 433"]},
  {"id": "P5", "nombre": "Paso con solo separadores", "fuentes": [";", " ; ", ";;"]}
]}
''';

void main() {
  silenciarAvisos();

  Future<Itinerario?> cargar(ContentRepo repo, String rol) {
    final container = ProviderContainer.test(overrides: [contentProvider.overrideWithValue(repo)]);
    return container.read(itinerarioProvider(rol).future);
  }

  group('itinerarioProvider', () {
    test('carga itinerarios/<rol>.json del contenido (AssetBundle en memoria, sin leer el manifiesto)', () async {
      final (repo, bundle) = repoCon({real('victima'): itinerarioConFases});

      final itinerario = await cargar(repo, 'victima');

      expect(itinerario, isNotNull);
      expect(itinerario!.rol, 'victima');
      expect([for (final p in itinerario.pasos) p.nombre], nombresConFases);
      expect(bundle.lecturas, [real('victima')]);
    });

    test('el ejemplo de la sección 9.5 no se enseña: tiene "validado": false', () async {
      final (repo, _) = repoCon({real('testigo'): itinerarioSeccion95});

      expect(await cargar(repo, 'testigo'), isNull);
    });

    test('en modo DEMO con borradores, el borrador sí se enseña', () async {
      final (repo, _) = repoCon({real('testigo'): itinerarioSeccion95}, mostrarBorradores: true);

      final itinerario = await cargar(repo, 'testigo');

      expect(itinerario!.pasos.single.nombre, 'Te llega una citación');
    });

    test('solo quedan los pasos con alguna cita en sus fuentes (un «;» suelto no cuenta)', () async {
      final (repo, _) = repoCon({real('testigo'): _conPasoSinFuente});

      final itinerario = await cargar(repo, 'testigo');

      expect([for (final p in itinerario!.pasos) p.id], ['P1', 'P4']);
    });

    test(
      'en modo DEMO con borradores se enseña todo, también los pasos sin fuente (como el resto del contenido)',
      () async {
        final (repo, _) = repoCon({real('testigo'): _conPasoSinFuente}, mostrarBorradores: true);

        final itinerario = await cargar(repo, 'testigo');

        expect([for (final p in itinerario!.pasos) p.id], ['P1', 'P2', 'P3', 'P4', 'P5']);
      },
    );

    test('si ningún paso tiene fuente, no hay línea', () async {
      final (repo, _) = repoCon({
        real('testigo'): '{"rol": "testigo", "validado": true, "pasos": [{"id": "P1", "nombre": "Sin fuente"}]}',
      });

      expect(await cargar(repo, 'testigo'), isNull);
    });

    test('mientras content/ está vacío, usa el de assets/mock/content', () async {
      final (repo, bundle) = repoCon({ejemplo('victima'): itinerarioConFases});

      final itinerario = await cargar(repo, 'victima');

      expect(itinerario!.pasos, hasLength(6));
      expect(bundle.lecturas, [real('victima'), ejemplo('victima')]);
    });

    test('el real tiene prioridad sobre el de ejemplo', () async {
      final (repo, _) = repoCon({real('testigo'): _conPasoSinFuente, ejemplo('testigo'): itinerarioConFases});

      final itinerario = await cargar(repo, 'testigo');

      expect(itinerario!.pasos.first.nombre, 'Te llega una citación');
      expect(itinerario.pasos, hasLength(2));
    });

    test('sin fichero, con JSON roto o con otra forma, no hay línea (y no lanza)', () async {
      final (repo, _) = repoCon({
        real('testigo'): '{"rol": ',
        real('victima'): '[1, 2]',
        real('investigado'): '{"rol": "investigado", "validado": true, "pasos": "no es una lista"}',
      });

      expect(await cargar(repo, 'testigo'), isNull);
      expect(await cargar(repo, 'victima'), isNull);
      expect(await cargar(repo, 'investigado'), isNull);
      expect(await cargar(repo, 'escuchado_familia'), isNull);
    });

    test('un fichero con otro papel dentro no se enseña', () async {
      final (repo, _) = repoCon({real('testigo'): itinerarioConFases});

      expect(await cargar(repo, 'testigo'), isNull);
    });

    test('acepta el papel con mayúsculas, tildes o espacios («Víctima»)', () async {
      final (repo, bundle) = repoCon({real('victima'): itinerarioConFases});

      expect(await cargar(repo, ' Víctima '), isNotNull);
      expect(bundle.lecturas, [real('victima')]);
    });

    test('un papel que no puede ser un nombre de fichero no lee nada', () async {
      final (repo, bundle) = repoCon({real('victima'): itinerarioConFases});

      for (final rol in ['', '../glosario', 'victima/../../x', 'testigo.json', 'no lo sé']) {
        expect(await cargar(repo, rol), isNull, reason: rol);
      }
      expect(bundle.lecturas, isEmpty);
    });
  });

  group('faseDeEntrada', () {
    test('la fase del formulario si eligió ese papel, «no lo sé» o ninguno', () {
      expect(faseDeEntrada(const Entrada(rol: RolEntrada.victima, fase: Fase.durante), 'victima'), Fase.durante);
      expect(faseDeEntrada(const Entrada(rol: RolEntrada.noLoSe, fase: Fase.antes), 'testigo'), Fase.antes);
      expect(faseDeEntrada(const Entrada(fase: Fase.despues), 'investigado'), Fase.despues);
      expect(
        faseDeEntrada(const Entrada(rol: RolEntrada.escuchadoFamilia, fase: Fase.antes), 'escuchado_familia'),
        Fase.antes,
      );
    });

    test('null si en el formulario eligió otro papel o no dijo la fase', () {
      expect(faseDeEntrada(const Entrada(rol: RolEntrada.testigo, fase: Fase.durante), 'victima'), isNull);
      expect(faseDeEntrada(const Entrada(rol: RolEntrada.victima), 'victima'), isNull);
      expect(faseDeEntrada(const Entrada(), 'victima'), isNull);
    });
  });
}
