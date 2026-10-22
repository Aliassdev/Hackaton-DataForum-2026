import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/api/models.dart';
import 'package:tuturno/core/entrada.dart';

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
  });
}
