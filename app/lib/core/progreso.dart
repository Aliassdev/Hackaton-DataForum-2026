import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

// Progreso (docs/ARQUITECTURA.md, sección 6.4): XP, racha, lecciones completadas, dominio por concepto
// (BKT, sección 10.6), cartas de derecho del juego y personas conocidas del juzgado. Se guarda solo en el móvil.
//
// Racha amable: suma un día cada día con al menos una lección. Si un día no se puede, hay un día de descanso cada
// semana, y la mejor racha nunca baja. Sin avisos, sin cuenta atrás y sin textos de pérdida.

@immutable
class Progreso {
  const Progreso({
    this.xp = 0,
    this.racha = 0,
    this.mejorRacha = 0,
    this.ultimoDiaConLeccion,
    this.descansoUsado,
    this.leccionesCompletadas = const {},
    this.dominio = const {},
    this.ultimaPractica = const {},
    this.cartas = const {},
    this.casosTerminados = const {},
    this.personasConocidas = const {},
  });

  /// Los campos que faltan (un JSON de una versión anterior) se leen con su valor inicial: 0, null o vacío.
  factory Progreso.fromJson(Map<String, dynamic> json) => Progreso(
    xp: (json['xp'] as num?)?.toInt() ?? 0,
    racha: (json['racha'] as num?)?.toInt() ?? 0,
    mejorRacha: _entero(json['mejor_racha']),
    ultimoDiaConLeccion: DateTime.tryParse(json['ultimo_dia'] as String? ?? ''),
    descansoUsado: _fecha(json['descanso']),
    leccionesCompletadas: {...?(json['lecciones'] as List?)?.cast<String>()},
    dominio: {
      for (final e in ((json['dominio'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toDouble(),
    },
    ultimaPractica: {
      for (final e in ((json['ultima_practica'] as Map?) ?? const {}).entries)
        e.key as String: ?DateTime.tryParse(e.value as String),
    },
    cartas: {...?(json['cartas'] as List?)?.cast<String>()},
    casosTerminados: {...?(json['casos'] as List?)?.cast<String>()},
    personasConocidas: _textos(json['juzgado']),
  );

  final int xp;

  /// Días con al menos una lección, seguidos o con un día de descanso en medio (el día de descanso no suma). Es la de
  /// la última lección: para saber la que se enseña hoy, [estadoRacha].
  final int racha;

  /// La racha más larga conseguida. Nunca baja.
  final int mejorRacha;
  final DateTime? ultimoDiaConLeccion;

  /// Último día de descanso que se ha gastado (el día sin lección que no cortó la racha). Hay uno como mucho cada 7
  /// días: [descansoDisponible].
  final DateTime? descansoUsado;
  final Set<String> leccionesCompletadas;

  /// Probabilidad de dominio por concepto (BKT).
  final Map<String, double> dominio;

  /// Última vez que se practicó cada concepto (para el repaso).
  final Map<String, DateTime> ultimaPractica;

  /// Cartas de derecho desbloqueadas en el juego.
  final Set<String> cartas;
  final Set<String> casosTerminados;

  /// Personas del juzgado explorable que ya se han conocido (ids de lib/pixel/juzgado).
  final Set<String> personasConocidas;

  Map<String, dynamic> toJson() => {
    'xp': xp,
    'racha': racha,
    'mejor_racha': mejorRacha,
    'ultimo_dia': ultimoDiaConLeccion?.toIso8601String(),
    'descanso': descansoUsado?.toIso8601String(),
    'lecciones': leccionesCompletadas.toList(),
    'dominio': dominio,
    'ultima_practica': {for (final e in ultimaPractica.entries) e.key: e.value.toIso8601String()},
    'cartas': cartas.toList(),
    'casos': casosTerminados.toList(),
    'juzgado': personasConocidas.toList(),
  };

  Progreso copyWith({
    int? xp,
    int? racha,
    int? mejorRacha,
    DateTime? ultimoDiaConLeccion,
    DateTime? descansoUsado,
    Set<String>? leccionesCompletadas,
    Map<String, double>? dominio,
    Map<String, DateTime>? ultimaPractica,
    Set<String>? cartas,
    Set<String>? casosTerminados,
    Set<String>? personasConocidas,
  }) => Progreso(
    xp: xp ?? this.xp,
    racha: racha ?? this.racha,
    mejorRacha: mejorRacha ?? this.mejorRacha,
    ultimoDiaConLeccion: ultimoDiaConLeccion ?? this.ultimoDiaConLeccion,
    descansoUsado: descansoUsado ?? this.descansoUsado,
    leccionesCompletadas: leccionesCompletadas ?? this.leccionesCompletadas,
    dominio: dominio ?? this.dominio,
    ultimaPractica: ultimaPractica ?? this.ultimaPractica,
    cartas: cartas ?? this.cartas,
    casosTerminados: casosTerminados ?? this.casosTerminados,
    personasConocidas: personasConocidas ?? this.personasConocidas,
  );

  static int _entero(Object? valor) => valor is num ? valor.toInt() : 0;

  static DateTime? _fecha(Object? valor) => valor is String ? DateTime.tryParse(valor) : null;

  static Set<String> _textos(Object? valor) => {
    if (valor is List)
      for (final e in valor)
        if (e is String) e,
  };
}

/// Hora actual. Los tests la sustituyen para comprobar la racha y el repaso.
final relojProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final progresoProvider = NotifierProvider<ProgresoNotifier, Progreso>(ProgresoNotifier.new);

class ProgresoNotifier extends Notifier<Progreso> {
  /// Clave en shared_preferences (también la borra «Borrar todo», lib/core/borrar_todo.dart).
  static const clave = 'progreso';

  @override
  Progreso build() {
    final guardado = ref.watch(sharedPreferencesProvider).getString(clave);
    if (guardado == null) return const Progreso();
    try {
      return Progreso.fromJson(jsonDecode(guardado) as Map<String, dynamic>);
    } catch (_) {
      return const Progreso();
    }
  }

  Future<void> sumarXp(int puntos) => _guardar(state.copyWith(xp: state.xp + puntos));

  /// Marca la lección y actualiza la racha según los días desde la anterior: el mismo día, igual; al día siguiente,
  /// +1; con un día sin lección en medio, +1 si queda día de descanso (y se gasta: el descanso es ayer); si no, o con
  /// más días, vuelve a empezar en 1. La mejor racha nunca baja.
  Future<void> completarLeccion(String leccionId) {
    final hoy = _dia(ref.read(relojProvider)());
    final ultimo = state.ultimoDiaConLeccion;
    var descanso = state.descansoUsado;
    final int racha;
    switch (ultimo == null ? null : diasEntre(ultimo, hoy)) {
      case null:
        racha = 1;
      // Hoy ya había una lección. (Con el reloj hacia atrás la última sale «en el futuro»: tampoco se corta.)
      case <= 0:
        racha = math.max(state.racha, 1);
      case 1:
        racha = state.racha + 1;
      case 2 when descansoDisponible(state, hoy):
        racha = state.racha + 1;
        descanso = DateTime(hoy.year, hoy.month, hoy.day - 1);
      default:
        racha = 1;
    }
    return _guardar(
      state.copyWith(
        racha: racha,
        mejorRacha: math.max(math.max(state.mejorRacha, state.racha), racha),
        ultimoDiaConLeccion: hoy,
        descansoUsado: descanso,
        leccionesCompletadas: {...state.leccionesCompletadas, leccionId},
      ),
    );
  }

  Future<void> actualizarDominio(String conceptoId, double p) => _guardar(
    state.copyWith(
      dominio: {...state.dominio, conceptoId: p},
      ultimaPractica: {...state.ultimaPractica, conceptoId: ref.read(relojProvider)()},
    ),
  );

  Future<void> desbloquearCarta(String cartaId) => _guardar(state.copyWith(cartas: {...state.cartas, cartaId}));

  Future<void> terminarCaso(String casoId) =>
      _guardar(state.copyWith(casosTerminados: {...state.casosTerminados, casoId}));

  /// Juzgado explorable: [id] ya se ha conocido (se recuerda al volver).
  Future<void> conocerPersona(String id) async {
    if (id.isEmpty || state.personasConocidas.contains(id)) return;
    await _guardar(state.copyWith(personasConocidas: {...state.personasConocidas, id}));
  }

  /// Cambia todo el progreso de una vez (modo DEMO: «Preparar demo» carga `progresoDemo`, de lib/core/demo.dart).
  Future<void> reemplazar(Progreso p) => _guardar(p);

  /// Modo DEMO: vuelve a empezar.
  Future<void> reiniciar() => _guardar(const Progreso());

  Future<void> _guardar(Progreso nuevo) async {
    state = nuevo;
    await ref.read(sharedPreferencesProvider).setString(clave, jsonEncode(nuevo.toJson()));
  }

  static DateTime _dia(DateTime t) => DateTime(t.year, t.month, t.day);
}

/// Días de calendario de [desde] a [hasta]. Se cuentan en UTC: con medianoches locales, el día del cambio de hora de
/// primavera dura 23 horas y `inDays` daría 0 en vez de 1 (y la racha no subiría).
int diasEntre(DateTime desde, DateTime hasta) => DateTime.utc(
  hasta.year,
  hasta.month,
  hasta.day,
).difference(DateTime.utc(desde.year, desde.month, desde.day)).inDays;

/// Si queda día de descanso para [hoy], el día de una lección después de un día sin ella (el descanso sería ayer): hay
/// uno como mucho cada 7 días, así que entre un descanso y el siguiente pasan al menos 7 días (del 2 al 9, no antes).
bool descansoDisponible(Progreso p, DateTime hoy) {
  final usado = p.descansoUsado;
  return usado == null || diasEntre(usado, hoy) >= 8;
}

/// Cómo está la racha hoy, para la cabecera de Aprende y el saludo de Inicio. Nunca se habla de perderla.
enum TipoRacha {
  /// No hay racha en marcha (nunca la ha habido o hace días que no hay lecciones): se puede empezar una nueva.
  sinRacha,

  /// Hoy ya hay una lección: la racha ya ha sumado.
  hoyHecha,

  /// La última lección fue ayer: con una hoy, la racha suma un día.
  pendienteHoy,

  /// Ayer no hubo lección, pero queda día de descanso: con una lección hoy, la racha sigue.
  conDescanso,
}

/// La racha que se enseña hoy ([dias], 0 si no hay ninguna en marcha), la mejor conseguida ([mejor]) y su [tipo].
@immutable
class EstadoRacha {
  const EstadoRacha({required this.dias, required this.mejor, required this.tipo});

  final int dias;
  final int mejor;
  final TipoRacha tipo;

  @override
  bool operator ==(Object other) =>
      other is EstadoRacha && other.dias == dias && other.mejor == mejor && other.tipo == tipo;

  @override
  int get hashCode => Object.hash(dias, mejor, tipo);

  @override
  String toString() => 'EstadoRacha(${tipo.name}, dias: $dias, mejor: $mejor)';
}

/// La racha de [p] vista en el día de [ahora]: según los días desde la última lección, 0 → [TipoRacha.hoyHecha],
/// 1 → [TipoRacha.pendienteHoy], 2 con descanso disponible → [TipoRacha.conDescanso] y, si no, [TipoRacha.sinRacha]
/// (con 0 días). [EstadoRacha.mejor] nunca es menor que la racha guardada.
EstadoRacha estadoRacha(Progreso p, DateTime ahora) {
  final mejor = math.max(p.mejorRacha, p.racha);
  final ultimo = p.ultimoDiaConLeccion;
  final tipo = ultimo == null || p.racha <= 0
      ? TipoRacha.sinRacha
      : switch (diasEntre(ultimo, ahora)) {
          <= 0 => TipoRacha.hoyHecha,
          1 => TipoRacha.pendienteHoy,
          2 when descansoDisponible(p, ahora) => TipoRacha.conDescanso,
          _ => TipoRacha.sinRacha,
        };
  return EstadoRacha(dias: tipo == TipoRacha.sinRacha ? 0 : p.racha, mejor: mejor, tipo: tipo);
}
