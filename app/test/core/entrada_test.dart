import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/api/models.dart';
import 'package:tuturno/core/entrada.dart';
import 'package:tuturno/core/providers.dart';

// Las variables de la sesión del agente con los valores que lee el backend de B (backend/app/agent/perfil.py,
// origin/feat/api-base): edad en cifras; penal | familia | proteccion; victima | testigo | investigado | escuchado;
// antes | durante | despues. Lo no respondido va vacío.

void main() {
  group('variablesAgente', () {
    test('sin responder nada: las cuatro claves, vacías', () {
      expect(const Entrada().variablesAgente(), {'edad': '', 'procedimiento': '', 'rol': '', 'fase': ''});
    });

    test('con todo respondido, los valores del backend (la edad 11 en cifras)', () {
      const entrada = Entrada(edad: 11, procedimiento: Procedimiento.penal, rol: RolEntrada.victima, fase: Fase.antes);
      expect(entrada.variablesAgente(), {'edad': '11', 'procedimiento': 'penal', 'rol': 'victima', 'fase': 'antes'});
    });

    test('«Me van a escuchar» se manda como escuchado, sin cambiar el nombre interno', () {
      const entrada = Entrada(rol: RolEntrada.escuchadoFamilia, procedimiento: Procedimiento.familia);
      expect(entrada.variablesAgente()['rol'], 'escuchado');
      expect(entrada.variablesAgente()['procedimiento'], 'familia');
      expect(RolEntrada.escuchadoFamilia.valor, 'escuchado_familia');
    });

    test('«No lo sé» va vacío, no como no_lo_se', () {
      const entrada = Entrada(procedimiento: Procedimiento.noLoSe, rol: RolEntrada.noLoSe);
      expect(entrada.variablesAgente(), {'edad': '', 'procedimiento': '', 'rol': '', 'fase': ''});
    });

    test('protección, investigado, durante y después', () {
      expect(
        const Entrada(
          edad: 16,
          procedimiento: Procedimiento.proteccion,
          rol: RolEntrada.investigado,
          fase: Fase.durante,
        ).variablesAgente(),
        {'edad': '16', 'procedimiento': 'proteccion', 'rol': 'investigado', 'fase': 'durante'},
      );
      expect(const Entrada(fase: Fase.despues).variablesAgente()['fase'], 'despues');
    });

    test('con «Mi situación», el papel sale de ahí si no se ha elegido otro', () {
      expect(const Entrada().variablesAgente(situacion: RolProceso.testigo)['rol'], 'testigo');
      expect(
        const Entrada(rol: RolEntrada.noLoSe).variablesAgente(situacion: RolProceso.investigado)['rol'],
        'investigado',
      );
      expect(const Entrada(rol: RolEntrada.victima).variablesAgente(situacion: RolProceso.testigo)['rol'], 'victima');
    });

    test('toVariables no cambia (lo usa la documentación de la sección 8.6)', () {
      expect(const Entrada().toVariables(), {'edad': noLoSe, 'procedimiento': noLoSe, 'rol': noLoSe, 'fase': noLoSe});
    });

    test('«Aún no hay proceso» viaja como ninguno, que no es lo mismo que «No lo sé»', () {
      const entrada = Entrada(
        edad: 15,
        procedimiento: Procedimiento.ninguno,
        rol: RolEntrada.victima,
        fase: Fase.antes,
      );
      expect(entrada.variablesAgente(), {'edad': '15', 'procedimiento': 'ninguno', 'rol': 'victima', 'fase': 'antes'});
      expect(const Entrada(procedimiento: Procedimiento.noLoSe).variablesAgente()['procedimiento'], '');
      expect(entrada.toVariables()['procedimiento'], 'ninguno');
    });

    test('las claves son siempre exactamente edad, procedimiento, rol y fase', () {
      for (final procedimiento in [null, ...Procedimiento.values]) {
        final variables = Entrada(procedimiento: procedimiento).variablesAgente(situacion: RolProceso.victima);
        expect(variables.keys, ['edad', 'procedimiento', 'rol', 'fase']);
        expect(variables['procedimiento'], isNot(noLoSe));
      }
    });
  });

  group('opciones del formulario', () {
    test('«Aún no hay proceso» (solo quiero informarme) va antes de «No lo sé», que sigue al final', () {
      expect(Procedimiento.values.map((p) => p.valor), ['penal', 'familia', 'proteccion', 'ninguno', 'no_lo_se']);
      expect(Procedimiento.ninguno.etiqueta, 'Aún no hay proceso');
      expect(Procedimiento.ninguno.explicacion, contains('informarte'));
      expect(Procedimiento.values.last, Procedimiento.noLoSe);
    });

    test('las etiquetas de los chips son cortas: con más de 20 letras se cortan con la letra a 1,3 en 360 px', () {
      final etiquetas = [
        for (final p in Procedimiento.values) p.etiqueta,
        for (final r in RolEntrada.values) r.etiqueta,
        for (final f in Fase.values) f.etiqueta,
      ];
      for (final etiqueta in etiquetas) {
        expect(etiqueta.length, lessThanOrEqualTo(20), reason: etiqueta);
      }
    });

    test('«Investigado» se explica sin dar por hecho nada, y con la edad desde la que se aplica', () {
      // Sin edad («Prefiero no decirlo»), la hoja enseña el papel: que se vea que la ley de menores es desde los 14.
      expect(
        RolEntrada.investigado.explicacion,
        'La justicia revisa si hiciste algo que la ley no permite (desde los 14 años).',
      );
    });

    test('los valores guardados no cambian', () {
      expect(RolEntrada.values.map((r) => r.valor), [
        'victima',
        'testigo',
        'investigado',
        'escuchado_familia',
        'no_lo_se',
      ]);
      expect(Fase.values.map((f) => f.valor), ['antes', 'durante', 'despues']);
      expect(EntradaNotifier.clave, 'entrada');
    });
  });

  group('EntradaNotifier', () {
    Future<ProviderContainer> contenedor([Map<String, Object> valores = const {}]) async {
      SharedPreferences.setMockInitialValues(valores);
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(c.dispose);
      return c;
    }

    test('guarda «Aún no hay proceso» y lo lee al volver a abrir', () async {
      final c = await contenedor();
      await c.read(entradaProvider.notifier).guardar(const Entrada(edad: 15, procedimiento: Procedimiento.ninguno));
      final guardado = c.read(sharedPreferencesProvider).getString('entrada')!;
      expect(jsonDecode(guardado), {'edad': 15, 'procedimiento': 'ninguno', 'rol': null, 'fase': null});

      final otra = await contenedor({'entrada': guardado});
      expect(otra.read(entradaProvider).procedimiento, Procedimiento.ninguno);
      expect(otra.read(entradaProvider).edad, 15);
    });

    test('un valor que no conoce se lee como sin responder, y un JSON roto da el ticket vacío', () async {
      final c = await contenedor({
        'entrada': jsonEncode({'edad': 9, 'procedimiento': 'otro', 'rol': 'testigo'}),
      });
      expect(c.read(entradaProvider).procedimiento, isNull);
      expect(c.read(entradaProvider).edad, isNull, reason: 'solo de 11 a 17');
      expect(c.read(entradaProvider).rol, RolEntrada.testigo);

      final rota = await contenedor({'entrada': '{"edad": '});
      expect(rota.read(entradaProvider).vacia, isTrue);
    });

    test('«Borrar mis respuestas» quita la clave', () async {
      final c = await contenedor({
        'entrada': jsonEncode({'edad': 13}),
      });
      await c.read(entradaProvider.notifier).borrar();
      expect(c.read(entradaProvider).vacia, isTrue);
      expect(c.read(sharedPreferencesProvider).getString('entrada'), isNull);
    });
  });
}
