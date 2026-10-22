import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

// Progreso (docs/ARQUITECTURA.md, sección 6.4): XP, racha, lecciones completadas, dominio por concepto
// (BKT, sección 10.6) y cartas de derecho del juego. Se guarda solo en el móvil.

@immutable
class Progreso {
  const Progreso({
    this.xp = 0,
    this.racha = 0,
    this.ultimoDiaConLeccion,
    this.leccionesCompletadas = const {},
    this.dominio = const {},
    this.ultimaPractica = const {},
    this.cartas = const {},
    this.casosTerminados = const {},
  });

  factory Progreso.fromJson(Map<String, dynamic> json) => Progreso(
    xp: (json['xp'] as num?)?.toInt() ?? 0,
    racha: (json['racha'] as num?)?.toInt() ?? 0,
    ultimoDiaConLeccion: DateTime.tryParse(json['ultimo_dia'] as String? ?? ''),
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
  );

  final int xp;

  /// Días seguidos con al menos una lección.
  final int racha;
  final DateTime? ultimoDiaConLeccion;
  final Set<String> leccionesCompletadas;

  /// Probabilidad de dominio por concepto (BKT).
  final Map<String, double> dominio;

  /// Última vez que se practicó cada concepto (para el repaso).
  final Map<String, DateTime> ultimaPractica;

  /// Cartas de derecho desbloqueadas en el juego.
  final Set<String> cartas;
  final Set<String> casosTerminados;

  Map<String, dynamic> toJson() => {
    'xp': xp,
    'racha': racha,
    'ultimo_dia': ultimoDiaConLeccion?.toIso8601String(),
    'lecciones': leccionesCompletadas.toList(),
    'dominio': dominio,
    'ultima_practica': {for (final e in ultimaPractica.entries) e.key: e.value.toIso8601String()},
    'cartas': cartas.toList(),
    'casos': casosTerminados.toList(),
  };

  Progreso copyWith({
    int? xp,
    int? racha,
    DateTime? ultimoDiaConLeccion,
    Set<String>? leccionesCompletadas,
    Map<String, double>? dominio,
    Map<String, DateTime>? ultimaPractica,
    Set<String>? cartas,
    Set<String>? casosTerminados,
  }) => Progreso(
    xp: xp ?? this.xp,
    racha: racha ?? this.racha,
    ultimoDiaConLeccion: ultimoDiaConLeccion ?? this.ultimoDiaConLeccion,
    leccionesCompletadas: leccionesCompletadas ?? this.leccionesCompletadas,
    dominio: dominio ?? this.dominio,
    ultimaPractica: ultimaPractica ?? this.ultimaPractica,
    cartas: cartas ?? this.cartas,
    casosTerminados: casosTerminados ?? this.casosTerminados,
  );
}

/// Hora actual. Los tests la sustituyen para comprobar la racha y el repaso.
final relojProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final progresoProvider = NotifierProvider<ProgresoNotifier, Progreso>(ProgresoNotifier.new);

class ProgresoNotifier extends Notifier<Progreso> {
  static const _clave = 'progreso';

  @override
  Progreso build() {
    final guardado = ref.watch(sharedPreferencesProvider).getString(_clave);
    if (guardado == null) return const Progreso();
    try {
      return Progreso.fromJson(jsonDecode(guardado) as Map<String, dynamic>);
    } catch (_) {
      return const Progreso();
    }
  }

  Future<void> sumarXp(int puntos) => _guardar(state.copyWith(xp: state.xp + puntos));

  /// Marca la lección y actualiza la racha: +1 si la anterior fue ayer, igual si fue hoy, 1 si no.
  Future<void> completarLeccion(String leccionId) {
    final hoy = _dia(ref.read(relojProvider)());
    final ultimo = state.ultimoDiaConLeccion;
    final racha = switch (ultimo == null ? null : diasEntre(ultimo, hoy)) {
      0 => state.racha,
      1 => state.racha + 1,
      _ => 1,
    };
    return _guardar(
      state.copyWith(
        racha: racha,
        ultimoDiaConLeccion: hoy,
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

  /// Modo DEMO: vuelve a empezar.
  Future<void> reiniciar() => _guardar(const Progreso());

  Future<void> _guardar(Progreso nuevo) async {
    state = nuevo;
    await ref.read(sharedPreferencesProvider).setString(_clave, jsonEncode(nuevo.toJson()));
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
