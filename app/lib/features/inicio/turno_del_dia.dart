import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/progreso.dart';
import '../../core/providers.dart';
import '../../widgets/iconos/iconos.dart';
import '../../widgets/modulos.dart';

// «Tu turno del día»: cada día, un ticket con un número y una misión pequeña que lleva a un módulo. Sin presión: no
// hay avisos, ni cuentas atrás, ni nada que se pierda. El número de turno solo sube (los días con la misión hecha) y
// todo se guarda en el móvil, como el resto del progreso.

/// Misiones del turno del día. Solo llevan a Aprende y a Vive el caso: Pregunta y Ayuda nunca se gamifican.
enum Mision {
  leccion(
    texto: 'Completa una lección de Aprende',
    hecha: 'Lección completada',
    icono: TuIcono.aprende,
    modulo: Modulo.aprende,
  ),
  carta(
    texto: 'Consigue una carta en Vive el caso',
    hecha: 'Carta conseguida',
    icono: TuIcono.carta,
    modulo: Modulo.juego,
  ),
  puntos(
    texto: 'Gana $puntosObjetivo XP respondiendo en Aprende',
    hecha: '$puntosObjetivo XP ganados',
    icono: TuIcono.xp,
    modulo: Modulo.aprende,
  );

  const Mision({required this.texto, required this.hecha, required this.icono, required this.modulo});

  /// XP de la misión [puntos]: tres aciertos.
  static const puntosObjetivo = 30;

  final String texto;

  /// Lo que se ha conseguido, para cuando está cumplida.
  final String hecha;
  final TuIcono icono;
  final Modulo modulo;

  String get ruta => modulo.ruta;

  /// La misión del [dia]: van rotando. Si ya hay un caso del juego terminado, en vez de cartas toca sumar puntos.
  static Mision delDia(DateTime dia, Progreso progreso) {
    final mision = values[indiceDia(dia) % values.length];
    return mision == carta && progreso.casosTerminados.isNotEmpty ? puntos : mision;
  }

  /// Si está cumplida el [dia] con [progreso], partiendo de [base] (lo que había al empezar ese día).
  bool cumplida(Recuento base, Progreso progreso, DateTime dia) => switch (this) {
    leccion => progreso.leccionesCompletadas.length > base.lecciones || _mismoDia(progreso.ultimoDiaConLeccion, dia),
    carta => progreso.cartas.length > base.cartas || progreso.casosTerminados.length > base.casos,
    puntos => progreso.xp >= base.xp + puntosObjetivo,
  };
}

/// Lo que hay en el progreso al empezar un día: con eso se sabe si la misión se ha cumplido.
@immutable
class Recuento {
  const Recuento({this.lecciones = 0, this.cartas = 0, this.casos = 0, this.xp = 0});

  factory Recuento.de(Progreso progreso) => Recuento(
    lecciones: progreso.leccionesCompletadas.length,
    cartas: progreso.cartas.length,
    casos: progreso.casosTerminados.length,
    xp: progreso.xp,
  );

  factory Recuento.fromJson(Map<String, dynamic> json) => Recuento(
    lecciones: (json['lecciones'] as num?)?.toInt() ?? 0,
    cartas: (json['cartas'] as num?)?.toInt() ?? 0,
    casos: (json['casos'] as num?)?.toInt() ?? 0,
    xp: (json['xp'] as num?)?.toInt() ?? 0,
  );

  final int lecciones;
  final int cartas;
  final int casos;
  final int xp;

  /// Si no hay menos de nada que en [otro] (si hay menos, el progreso se ha reiniciado).
  bool alcanza(Recuento otro) =>
      lecciones >= otro.lecciones && cartas >= otro.cartas && casos >= otro.casos && xp >= otro.xp;

  Map<String, dynamic> toJson() => {'lecciones': lecciones, 'cartas': cartas, 'casos': casos, 'xp': xp};
}

/// Lo que se guarda del turno del día en el móvil.
@immutable
class RegistroTurno {
  const RegistroTurno({
    required this.dia,
    required this.mision,
    required this.base,
    this.turnos = 0,
    this.celebrada = false,
    this.visto,
  });

  /// El registro de [hoy] a partir del [guardado] (si lo hay): el mismo si es de hoy; uno nuevo si cambió el día
  /// (sumando el turno de ese día si se cumplió) o si el progreso se ha reiniciado (modo DEMO).
  factory RegistroTurno.paraHoy(RegistroTurno? guardado, DateTime hoy, Progreso progreso) {
    final recuento = Recuento.de(progreso);
    final nuevo = RegistroTurno(dia: hoy, mision: Mision.delDia(hoy, progreso), base: recuento);
    if (guardado == null || !recuento.alcanza(guardado.base)) return nuevo;
    if (guardado.dia == hoy) return guardado;
    final cumplida = guardado.mision.cumplida(guardado.base, progreso, guardado.dia);
    return nuevo.copyWith(turnos: guardado.turnos + (cumplida ? 1 : 0), visto: guardado.visto);
  }

  /// El registro de [texto], o null si no hay o no se entiende.
  static RegistroTurno? decodificar(String? texto) {
    if (texto == null) return null;
    try {
      final json = jsonDecode(texto) as Map<String, dynamic>;
      final dia = DateTime.tryParse(json['dia'] as String? ?? '');
      final mision = Mision.values.asNameMap()[json['mision']];
      if (dia == null || mision == null) return null;
      return RegistroTurno(
        dia: soloDia(dia),
        mision: mision,
        base: Recuento.fromJson((json['base'] as Map?)?.cast<String, dynamic>() ?? const {}),
        turnos: (json['turnos'] as num?)?.toInt() ?? 0,
        celebrada: json['celebrada'] == true,
        visto: (json['visto'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  final DateTime dia;
  final Mision mision;
  final Recuento base;

  /// Días con la misión cumplida antes de [dia].
  final int turnos;

  /// Si ya se ha celebrado (el sello) la misión de [dia].
  final bool celebrada;

  /// Último número de turno que se ha enseñado (para que el panel gire desde ahí).
  final int? visto;

  RegistroTurno copyWith({int? turnos, bool? celebrada, int? visto}) => RegistroTurno(
    dia: dia,
    mision: mision,
    base: base,
    turnos: turnos ?? this.turnos,
    celebrada: celebrada ?? this.celebrada,
    visto: visto ?? this.visto,
  );

  String codificar() => jsonEncode({
    'dia': _fecha(dia),
    'mision': mision.name,
    'base': base.toJson(),
    'turnos': turnos,
    'celebrada': celebrada,
    'visto': ?visto,
  });

  static String _fecha(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// El turno del día tal como se enseña en el inicio.
@immutable
class TurnoDelDia {
  const TurnoDelDia({
    required this.dia,
    required this.numero,
    required this.mision,
    required this.cumplida,
    this.celebrada = false,
    this.numeroVisto,
  });

  factory TurnoDelDia.de(RegistroTurno registro, Progreso progreso) => TurnoDelDia(
    dia: registro.dia,
    numero: registro.turnos + 1,
    mision: registro.mision,
    cumplida: registro.mision.cumplida(registro.base, progreso, registro.dia),
    celebrada: registro.celebrada,
    numeroVisto: registro.visto,
  );

  final DateTime dia;

  /// Número del ticket de hoy: los turnos cumplidos hasta ayer, más uno.
  final int numero;
  final Mision mision;
  final bool cumplida;
  final bool celebrada;
  final int? numeroVisto;

  /// Cumplida y aún sin celebrar: toca el sello.
  bool get porCelebrar => cumplida && !celebrada;
}

final turnoDelDiaProvider = NotifierProvider<TurnoDelDiaNotifier, TurnoDelDia>(TurnoDelDiaNotifier.new);

class TurnoDelDiaNotifier extends Notifier<TurnoDelDia> {
  static const clave = 'inicio.turno_del_dia';

  @override
  TurnoDelDia build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final progreso = ref.watch(progresoProvider);
    final hoy = soloDia(ref.watch(relojProvider)());
    final registro = RegistroTurno.paraHoy(RegistroTurno.decodificar(prefs.getString(clave)), hoy, progreso);
    _guardar(prefs, registro);
    return TurnoDelDia.de(registro, progreso);
  }

  /// El sello de la misión ya ha caído: no se vuelve a animar hoy.
  void marcarCelebrada() => _actualizar((registro) => registro.copyWith(celebrada: true));

  /// El panel ya ha enseñado [numero]: la próxima vez gira desde aquí.
  void marcarVisto(int numero) {
    if (state.numeroVisto == numero) return;
    _actualizar((registro) => registro.copyWith(visto: numero));
  }

  void _actualizar(RegistroTurno Function(RegistroTurno registro) cambio) {
    final prefs = ref.read(sharedPreferencesProvider);
    final actual = RegistroTurno.decodificar(prefs.getString(clave));
    if (actual == null) return;
    final nuevo = cambio(actual);
    _guardar(prefs, nuevo);
    state = TurnoDelDia.de(nuevo, ref.read(progresoProvider));
  }

  static void _guardar(SharedPreferences prefs, RegistroTurno registro) {
    final texto = registro.codificar();
    if (prefs.getString(clave) != texto) unawaited(prefs.setString(clave, texto));
  }
}

/// La racha que sigue viva hoy, con la racha amable ([estadoRacha]): la del progreso si la última lección fue hoy o
/// ayer, o anteayer si queda día de descanso; si no, 0. (El progreso guarda la última racha hasta la siguiente lección;
/// aquí no se enseña una racha que ya no se puede alargar.)
int rachaViva(Progreso progreso, DateTime hoy) => estadoRacha(progreso, hoy).dias;

/// Si hoy ya hay una lección hecha.
bool leccionHoy(Progreso progreso, DateTime hoy) => _mismoDia(progreso.ultimoDiaConLeccion, hoy);

/// El día de [t], sin la hora.
DateTime soloDia(DateTime t) => DateTime(t.year, t.month, t.day);

/// Días desde el 1/1/2026 (con fechas UTC: los cambios de hora no descuadran la cuenta).
int indiceDia(DateTime dia) => DateTime.utc(dia.year, dia.month, dia.day).difference(DateTime.utc(2026)).inDays;

bool _mismoDia(DateTime? a, DateTime b) => a != null && a.year == b.year && a.month == b.month && a.day == b.day;
