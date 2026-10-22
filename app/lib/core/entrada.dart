import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/models.dart' show RolProceso;
import 'providers.dart';

// Respuestas del formulario de entrada de Pregunta. Se guardan solo en el móvil y viajan como
// variables de la sesión del agente de ElevenLabs. Los nombres son los que usa el prompt del
// agente de B (backend/scripts/setup_agent.py): {{edad}}, {{procedimiento}}, {{rol}} y {{fase}}.

/// Valor que se envía cuando una pregunta no se ha respondido.
const noLoSe = 'no_lo_se';

/// Edades que se pueden elegir. Desde 11: el caso oficial de Lucía tiene 11 años.
const edadesPosibles = [11, 12, 13, 14, 15, 16, 17];

enum Procedimiento {
  penal('penal', 'Penal', 'Se investiga si alguien ha cometido un delito'),
  familia('familia', 'De familia', 'Por ejemplo, si tus padres se separan'),
  proteccion('proteccion', 'De protección', 'Servicios sociales cuidan de que estés bien'),
  noLoSe('no_lo_se', 'No lo sé', 'No pasa nada, te lo explico igual');

  const Procedimiento(this.valor, this.etiqueta, this.explicacion);

  final String valor;
  final String etiqueta;
  final String explicacion;
}

enum RolEntrada {
  victima('victima', 'Víctima', 'Alguien te ha hecho daño'),
  testigo('testigo', 'Testigo', 'Viste u oíste algo'),
  investigado('investigado', 'Investigado', 'Creen que hiciste algo (solo a partir de 14 años)'),
  escuchadoFamilia('escuchado_familia', 'Me van a escuchar', 'En un proceso de familia, por ejemplo una separación'),
  noLoSe('no_lo_se', 'No lo sé', 'No pasa nada, te lo explico igual');

  const RolEntrada(this.valor, this.etiqueta, this.explicacion);

  final String valor;
  final String etiqueta;
  final String explicacion;
}

enum Fase {
  antes('antes', 'Antes', 'Todavía no ha empezado'),
  durante('durante', 'Durante', 'Ya está pasando'),
  despues('despues', 'Después', 'Ya ha terminado');

  const Fase(this.valor, this.etiqueta, this.explicacion);

  final String valor;
  final String etiqueta;
  final String explicacion;
}

@immutable
class Entrada {
  const Entrada({this.edad, this.procedimiento, this.rol, this.fase});

  /// Uno de [edadesPosibles], o null si prefiere no decirlo.
  final int? edad;
  final Procedimiento? procedimiento;
  final RolEntrada? rol;
  final Fase? fase;

  bool get vacia => edad == null && procedimiento == null && rol == null && fase == null;

  /// Variables de la sesión del agente. Van siempre las cuatro (ElevenLabs las exige todas);
  /// lo que no se ha respondido va como «no_lo_se».
  Map<String, String> toVariables() => {
    'edad': edad?.toString() ?? noLoSe,
    'procedimiento': procedimiento?.valor ?? noLoSe,
    'rol': rol?.valor ?? noLoSe,
    'fase': fase?.valor ?? noLoSe,
  };

  /// Variables de la sesión del agente con los valores que lee el backend de B (backend/app/agent/perfil.py):
  /// edad en cifras; procedimiento penal | familia | proteccion; rol victima | testigo | investigado | escuchado;
  /// fase antes | durante | despues. Van siempre las cuatro claves. Lo que no se ha respondido (o «No lo sé») va
  /// vacío: el backend lo trata como «sin dato» y ElevenLabs acepta los valores vacíos (comprobado el 22-10).
  ///
  /// Con «Mi situación» ([situacion]), el papel sale de ahí si aquí no se ha elegido.
  Map<String, String> variablesAgente({RolProceso? situacion}) => {
    'edad': edad?.toString() ?? '',
    'procedimiento': switch (procedimiento) {
      Procedimiento.penal => 'penal',
      Procedimiento.familia => 'familia',
      Procedimiento.proteccion => 'proteccion',
      Procedimiento.noLoSe || null => '',
    },
    'rol': switch (rol) {
      RolEntrada.victima => 'victima',
      RolEntrada.testigo => 'testigo',
      RolEntrada.investigado => 'investigado',
      RolEntrada.escuchadoFamilia => 'escuchado',
      RolEntrada.noLoSe || null => situacion?.name ?? '',
    },
    'fase': fase?.valor ?? '',
  };

  Entrada copyWith({
    int? Function()? edad,
    Procedimiento? Function()? procedimiento,
    RolEntrada? Function()? rol,
    Fase? Function()? fase,
  }) => Entrada(
    edad: edad != null ? edad() : this.edad,
    procedimiento: procedimiento != null ? procedimiento() : this.procedimiento,
    rol: rol != null ? rol() : this.rol,
    fase: fase != null ? fase() : this.fase,
  );
}

final entradaProvider = NotifierProvider<EntradaNotifier, Entrada>(EntradaNotifier.new);

class EntradaNotifier extends Notifier<Entrada> {
  static const _clave = 'entrada';

  @override
  Entrada build() {
    final guardado = ref.watch(sharedPreferencesProvider).getString(_clave);
    if (guardado == null) return const Entrada();
    try {
      final json = jsonDecode(guardado) as Map<String, dynamic>;
      T? buscar<T extends Enum>(List<T> valores, String clave, String Function(T) valor) {
        final v = json[clave];
        return v is String ? valores.where((e) => valor(e) == v).firstOrNull : null;
      }

      final edad = (json['edad'] as num?)?.toInt();
      return Entrada(
        edad: edadesPosibles.contains(edad) ? edad : null,
        procedimiento: buscar(Procedimiento.values, 'procedimiento', (e) => e.valor),
        rol: buscar(RolEntrada.values, 'rol', (e) => e.valor),
        fase: buscar(Fase.values, 'fase', (e) => e.valor),
      );
    } catch (_) {
      return const Entrada();
    }
  }

  Future<void> guardar(Entrada entrada) async {
    state = entrada;
    await ref
        .read(sharedPreferencesProvider)
        .setString(
          _clave,
          jsonEncode({
            'edad': entrada.edad,
            'procedimiento': entrada.procedimiento?.valor,
            'rol': entrada.rol?.valor,
            'fase': entrada.fase?.valor,
          }),
        );
  }

  /// «Borrar mis respuestas» en Ajustes.
  Future<void> borrar() async {
    state = const Entrada();
    await ref.read(sharedPreferencesProvider).remove(_clave);
  }
}
