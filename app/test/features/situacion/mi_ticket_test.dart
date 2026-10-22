import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/entrada.dart';
import 'package:tuturno/core/progreso.dart' show relojProvider;
import 'package:tuturno/core/providers.dart';
import 'package:tuturno/features/pasos/personalizacion_linea.dart';
import 'package:tuturno/features/situacion/mi_ticket.dart';

// «Tu ticket» de Mi situación (con quién irás, qué te preocupa, cómo prefieres que te lo cuente y tu día): se guarda
// solo en el móvil (clave 'mi_situacion'), sobrevive a reiniciar, se puede borrar y lo roto no rompe nada.

void main() {
  late SharedPreferences prefs;
  late ProviderContainer c;

  Future<void> crear([Map<String, Object> valores = const {}]) async {
    SharedPreferences.setMockInitialValues(valores);
    prefs = await SharedPreferences.getInstance();
    c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        relojProvider.overrideWithValue(() => DateTime(2026, 10, 22, 10)),
      ],
    );
    addTearDown(c.dispose);
  }

  MiTicketNotifier notifier() => c.read(miTicketProvider.notifier);
  MiTicket ticket() => c.read(miTicketProvider);
  Map<String, dynamic> guardado() => jsonDecode(prefs.getString(MiTicketNotifier.clave)!) as Map<String, dynamic>;

  test('vacío al empezar; guardar las respuestas las deja en el móvil y sobreviven a reiniciar', () async {
    await crear();
    expect(ticket().vacio, isTrue);
    notifier().guardarRespuestas(
      conQuien: {Acompanante.familia, Acompanante.confianza},
      preocupaciones: {Preocupacion.redes, Preocupacion.verPersona},
      estilo: EstiloExplicacion.ejemplos,
    );
    expect(guardado(), {
      'con_quien': ['familia', 'confianza'],
      'preocupaciones': ['ver_persona', 'redes'],
      'estilo': 'ejemplos',
      'fecha': null,
      'hora': null,
      'llevar_hecho': <String>[],
      'llevar_propias': <Object>[],
    });

    final otro = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(otro.dispose);
    final releido = otro.read(miTicketProvider);
    expect(releido.conQuien, {Acompanante.familia, Acompanante.confianza});
    expect(releido.preocupacionesOrdenadas, [Preocupacion.verPersona, Preocupacion.redes]);
    expect(releido.estilo, EstiloExplicacion.ejemplos);
    expect(releido.conQuienEnFrase, 'tu familia y una persona de confianza');
  });

  test('«Aún no lo sé» va sola', () async {
    await crear();
    notifier().guardarRespuestas(
      conQuien: {Acompanante.familia, Acompanante.aunNoLoSe},
      preocupaciones: const {},
      estilo: null,
    );
    expect(ticket().conQuien, {Acompanante.aunNoLoSe});
    expect(ticket().conQuienEnFrase, isNull);
  });

  test('una preocupación se marca y se desmarca sin tocar lo demás', () async {
    await crear();
    notifier()
      ..ponerEstilo(EstiloExplicacion.corto)
      ..alternarPreocupacion(Preocupacion.colegio);
    expect(ticket().preocupaciones, {Preocupacion.colegio});
    notifier().alternarPreocupacion(Preocupacion.colegio);
    expect(ticket().preocupaciones, isEmpty);
    expect(ticket().estilo, EstiloExplicacion.corto);
  });

  test('tu día: la fecha (solo el día), la hora y la lista de lo que llevar', () async {
    await crear();
    notifier()
      ..ponerFecha(DateTime(2026, 10, 24, 17, 45))
      ..ponerHora(9, 5)
      ..marcarLlevar('citacion', true);
    expect(ticket().fecha, DateTime(2026, 10, 24));
    expect(ticket().hora, (horas: 9, minutos: 5));
    expect(guardado()['fecha'], '2026-10-24');
    expect(guardado()['hora'], '09:05');
    expect(guardado()['llevar_hecho'], ['citacion']);

    notifier().ponerHora(25, 0);
    expect(ticket().hora, (horas: 9, minutos: 5), reason: 'una hora imposible no se guarda');
    notifier().quitarHora();
    expect(ticket().hora, isNull);
    notifier().marcarLlevar('citacion', false);
    expect(ticket().llevarHecho, isEmpty);
  });

  test('cosas propias: se añaden recortadas, sin repetir y como mucho 10; se marcan y se quitan', () async {
    await crear();
    expect(notifier().anadirLlevar('  Mi   libro  '), isTrue);
    expect(ticket().llevarPropias.single.texto, 'Mi libro');
    expect(notifier().anadirLlevar('mi libro'), isFalse, reason: 'repetida');
    expect(notifier().anadirLlevar('   '), isFalse);
    final largo = 'a' * 100;
    expect(notifier().anadirLlevar(largo), isTrue);
    expect(ticket().llevarPropias.last.texto, hasLength(maxCaracteresCosaPropia));
    for (var i = 0; ticket().llevarPropias.length < maxCosasPropias; i++) {
      notifier().anadirLlevar('Cosa $i');
    }
    expect(notifier().anadirLlevar('Una más'), isFalse);

    final id = ticket().llevarPropias.first.id;
    notifier().marcarLlevar(id, true);
    expect(ticket().llevarPropias.first.hecho, isTrue);
    notifier().quitarLlevar(id);
    expect(ticket().llevarPropias.any((c) => c.id == id), isFalse);
  });

  test('«Borrar mi día» quita la fecha y la lista; «Borrar mis respuestas» deja el día', () async {
    await crear();
    notifier()
      ..guardarRespuestas(conQuien: {Acompanante.abogado}, preocupaciones: {Preocupacion.despues}, estilo: null)
      ..ponerFecha(DateTime(2026, 10, 30))
      ..anadirLlevar('Agua');
    await notifier().borrarRespuestas();
    expect(ticket().sinRespuestas, isTrue);
    expect(ticket().fecha, DateTime(2026, 10, 30));
    notifier().borrarDia();
    expect(ticket().vacio, isTrue);
    expect(prefs.containsKey(MiTicketNotifier.clave), isFalse, reason: 'sin nada que guardar, la clave se quita');
  });

  test('un JSON roto o con datos raros no rompe nada: se queda lo que se entiende', () async {
    await crear({MiTicketNotifier.clave: '{roto'});
    expect(ticket().vacio, isTrue);

    await crear({
      MiTicketNotifier.clave: jsonEncode({
        'con_quien': ['familia', 'marciano', 3],
        'preocupaciones': ['redes', null],
        'estilo': 'telepatico',
        'fecha': 'no es una fecha',
        'hora': '99:99',
        'llevar_propias': [
          {'id': 'p1', 'texto': 'Agua'},
          {'texto': 'sin id'},
          'nada',
        ],
      }),
    });
    expect(ticket().conQuien, {Acompanante.familia});
    expect(ticket().preocupaciones, {Preocupacion.redes});
    expect(ticket().estilo, isNull);
    expect(ticket().fecha, isNull);
    expect(ticket().hora, isNull);
    expect([for (final c in ticket().llevarPropias) c.texto], ['Agua']);
  });

  test('si «Borrar todo» quita la clave e invalida el ticket de la app, aquí tampoco queda nada en memoria', () async {
    await crear({
      EntradaNotifier.clave: jsonEncode({'edad': 13, 'rol': 'victima'}),
    });
    notifier().guardarRespuestas(conQuien: {Acompanante.familia}, preocupaciones: const {}, estilo: null);
    expect(ticket().sinRespuestas, isFalse);
    expect(c.read(entradaProvider).edad, 13);

    // Lo que hace borrarTodo (lib/core/borrar_todo.dart) con la clave en clavesDeUsuario: quita las claves e invalida
    // entradaProvider. Al cambiar el ticket de la app, este se vuelve a leer del móvil.
    await prefs.remove(EntradaNotifier.clave);
    await prefs.remove(MiTicketNotifier.clave);
    c.invalidate(entradaProvider);
    expect(c.read(entradaProvider).vacia, isTrue);
    expect(ticket().vacio, isTrue);
  });
}
