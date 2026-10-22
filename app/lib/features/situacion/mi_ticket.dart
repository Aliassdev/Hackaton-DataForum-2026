import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/borrar_todo.dart' show borradoProvider;
import '../../core/entrada.dart';
import '../../core/progreso.dart' show relojProvider;
import '../../core/providers.dart';
import '../pasos/personalizacion_linea.dart' show EstiloExplicacion;

// «Tu ticket» de Mi situación, lo que se suma al ticket de la app (Entrada: edad, tipo de proceso, papel y momento,
// en lib/core/entrada.dart): con quién irás, qué te preocupa más, cómo prefieres que te lo cuente y «Tu día» (la
// fecha de la citación y lo que vas a llevar). Todo es opcional, sin nombre ni hechos, y se guarda solo en este móvil
// (clave 'mi_situacion'); nunca sale del móvil ni va a los logs. Se puede borrar.

/// ¿Con quién irás? (se puede elegir más de una).
enum Acompanante {
  familia('familia', 'Mi familia', 'tu familia'),
  confianza('confianza', 'Una persona de confianza', 'una persona de confianza'),
  abogado('abogado', 'Mi abogado o abogada', 'tu abogado o abogada'),

  /// Excluye a las demás.
  aunNoLoSe('aun_no_lo_se', 'Aún no lo sé', null);

  const Acompanante(this.valor, this.etiqueta, this.enFrase);

  final String valor;
  final String etiqueta;

  /// «Tú irás con tu familia». null en [aunNoLoSe].
  final String? enFrase;
}

/// ¿Qué te preocupa más? (se puede elegir más de una). Cada una tiene su respuesta en situacion/preocupaciones.json.
enum Preocupacion {
  verPersona('ver_persona', 'Ver a la persona'),
  noEntender('no_entender', 'No entender lo que dicen'),
  preguntas('preguntas', 'Qué me van a preguntar'),
  familia('familia', 'Mi familia'),
  colegio('colegio', 'El colegio o el instituto'),
  redes('redes', 'Las redes'),
  soledad('solo', 'Estar solo o sola'),
  despues('despues', 'Qué pasará después');

  const Preocupacion(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static Preocupacion? deValor(Object? valor) => values.where((p) => p.valor == valor).firstOrNull;
}

/// Una cosa que llevar que ha escrito quien usa la app.
@immutable
class CosaPropia {
  const CosaPropia({required this.id, required this.texto, this.hecho = false});

  final String id;
  final String texto;
  final bool hecho;

  Map<String, Object?> toJson() => {'id': id, 'texto': texto, 'hecho': hecho};

  static CosaPropia? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    final texto = json['texto'];
    if (id is! String || id.isEmpty || texto is! String || texto.trim().isEmpty) return null;
    return CosaPropia(id: id, texto: limpiarCosaPropia(texto), hecho: json['hecho'] == true);
  }

  CosaPropia copyWith({bool? hecho}) => CosaPropia(id: id, texto: texto, hecho: hecho ?? this.hecho);

  @override
  bool operator ==(Object other) =>
      other is CosaPropia && other.id == id && other.texto == texto && other.hecho == hecho;

  @override
  int get hashCode => Object.hash(id, texto, hecho);
}

/// Hora de la cita (solo horas y minutos).
typedef HoraCita = ({int horas, int minutos});

@immutable
class MiTicket {
  const MiTicket({
    this.conQuien = const {},
    this.preocupaciones = const {},
    this.estilo,
    this.fecha,
    this.hora,
    this.llevarHecho = const {},
    this.llevarPropias = const [],
  });

  final Set<Acompanante> conQuien;
  final Set<Preocupacion> preocupaciones;
  final EstiloExplicacion? estilo;

  /// El día de la citación (a las 00:00), si lo ha puesto.
  final DateTime? fecha;
  final HoraCita? hora;

  /// Las cosas sugeridas que ya tiene preparadas (por su id).
  final Set<String> llevarHecho;
  final List<CosaPropia> llevarPropias;

  /// No ha respondido nada de lo suyo (con quién, preocupaciones, estilo).
  bool get sinRespuestas => conQuien.isEmpty && preocupaciones.isEmpty && estilo == null;

  /// No ha puesto nada en «Tu día».
  bool get sinDia => fecha == null && hora == null && llevarHecho.isEmpty && llevarPropias.isEmpty;

  bool get vacio => sinRespuestas && sinDia;

  /// Las preocupaciones en el orden de siempre (el del enum).
  List<Preocupacion> get preocupacionesOrdenadas => [
    for (final p in Preocupacion.values)
      if (preocupaciones.contains(p)) p,
  ];

  /// Con quién irá, en una frase («tu familia y una persona de confianza»), o null si no lo sabe o no lo ha dicho.
  String? get conQuienEnFrase {
    final partes = [
      for (final a in Acompanante.values)
        if (conQuien.contains(a) && a.enFrase != null) a.enFrase!,
    ];
    if (partes.isEmpty) return null;
    if (partes.length == 1) return partes.single;
    return '${partes.sublist(0, partes.length - 1).join(', ')} y ${partes.last}';
  }

  MiTicket copyWith({
    Set<Acompanante>? conQuien,
    Set<Preocupacion>? preocupaciones,
    EstiloExplicacion? Function()? estilo,
    DateTime? Function()? fecha,
    HoraCita? Function()? hora,
    Set<String>? llevarHecho,
    List<CosaPropia>? llevarPropias,
  }) => MiTicket(
    conQuien: conQuien ?? this.conQuien,
    preocupaciones: preocupaciones ?? this.preocupaciones,
    estilo: estilo != null ? estilo() : this.estilo,
    fecha: fecha != null ? fecha() : this.fecha,
    hora: hora != null ? hora() : this.hora,
    llevarHecho: llevarHecho ?? this.llevarHecho,
    llevarPropias: llevarPropias ?? this.llevarPropias,
  );

  Map<String, Object?> toJson() => {
    'con_quien': [
      for (final a in Acompanante.values)
        if (conQuien.contains(a)) a.valor,
    ],
    'preocupaciones': [for (final p in preocupacionesOrdenadas) p.valor],
    'estilo': estilo?.valor,
    'fecha': fecha == null ? null : _dia(fecha!),
    'hora': hora == null ? null : '${_dos(hora!.horas)}:${_dos(hora!.minutos)}',
    'llevar_hecho': llevarHecho.toList()..sort(),
    'llevar_propias': [for (final c in llevarPropias) c.toJson()],
  };

  /// Lee lo guardado. Lo que no se entiende se ignora (un dato roto no borra el resto).
  factory MiTicket.fromJson(Map<String, dynamic> json) {
    Set<T> conjunto<T>(Object? lista, T? Function(Object?) leer) => {
      if (lista is List)
        for (final e in lista) ?leer(e),
    };
    return MiTicket(
      conQuien: conjunto(json['con_quien'], (v) => Acompanante.values.where((a) => a.valor == v).firstOrNull),
      preocupaciones: conjunto(json['preocupaciones'], Preocupacion.deValor),
      estilo: EstiloExplicacion.deValor(json['estilo']),
      fecha: _leerDia(json['fecha']),
      hora: _leerHora(json['hora']),
      llevarHecho: conjunto(json['llevar_hecho'], (v) => v is String && v.isNotEmpty ? v : null),
      llevarPropias: [
        if (json['llevar_propias'] case final List<Object?> lista)
          for (final e in lista) ?CosaPropia.tryParse(e),
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MiTicket &&
      setEquals(other.conQuien, conQuien) &&
      setEquals(other.preocupaciones, preocupaciones) &&
      other.estilo == estilo &&
      other.fecha == fecha &&
      other.hora == hora &&
      setEquals(other.llevarHecho, llevarHecho) &&
      listEquals(other.llevarPropias, llevarPropias);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(conQuien),
    Object.hashAllUnordered(preocupaciones),
    estilo,
    fecha,
    hora,
    Object.hashAllUnordered(llevarHecho),
    Object.hashAll(llevarPropias),
  );
}

String _dos(int n) => n.toString().padLeft(2, '0');

String _dia(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_dos(d.month)}-${_dos(d.day)}';

DateTime? _leerDia(Object? valor) {
  if (valor is! String) return null;
  final fecha = DateTime.tryParse(valor);
  return fecha == null ? null : DateTime(fecha.year, fecha.month, fecha.day);
}

HoraCita? _leerHora(Object? valor) {
  if (valor is! String) return null;
  final partes = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(valor.trim());
  if (partes == null) return null;
  final horas = int.parse(partes[1]!);
  final minutos = int.parse(partes[2]!);
  if (horas > 23 || minutos > 59) return null;
  return (horas: horas, minutos: minutos);
}

/// Cuántas cosas propias caben en la lista de «Tu día».
const maxCosasPropias = 10;

/// Largo máximo de una cosa propia (lo que pasa se recorta).
const maxCaracteresCosaPropia = 60;

/// El texto de una cosa propia como se guarda: sin espacios de sobra y con [maxCaracteresCosaPropia] como mucho.
String limpiarCosaPropia(String texto) {
  final limpio = texto.replaceAll(RegExp(r'\s+'), ' ').trim();
  final letras = limpio.characters;
  return letras.length <= maxCaracteresCosaPropia
      ? limpio
      : letras.take(maxCaracteresCosaPropia).toString().trimRight();
}

final miTicketProvider = NotifierProvider<MiTicketNotifier, MiTicket>(MiTicketNotifier.new);

class MiTicketNotifier extends Notifier<MiTicket> {
  /// Clave en shared_preferences. Está en `clavesDeUsuario` (lib/core/borrar_todo.dart): «Borrar todo» la borra.
  static const clave = 'mi_situacion';

  @override
  MiTicket build() {
    // Se vuelve a leer lo guardado después de «Borrar todo» (borradoProvider), aunque el ticket de la app ya estuviera
    // vacío y no cambie; y cada vez que cambia el ticket de la app.
    ref
      ..watch(borradoProvider)
      ..watch(entradaProvider);
    final guardado = ref.watch(sharedPreferencesProvider).getString(clave);
    if (guardado == null) return const MiTicket();
    try {
      final json = jsonDecode(guardado);
      return json is Map<String, dynamic> ? MiTicket.fromJson(json) : const MiTicket();
    } catch (_) {
      return const MiTicket();
    }
  }

  /// Guarda las respuestas de «Tu ticket» (con quién, preocupaciones y estilo). «Tu día» se queda como estaba.
  void guardarRespuestas({
    required Set<Acompanante> conQuien,
    required Set<Preocupacion> preocupaciones,
    required EstiloExplicacion? estilo,
  }) {
    final soloNoLoSe = conQuien.contains(Acompanante.aunNoLoSe) ? {Acompanante.aunNoLoSe} : conQuien;
    _cambiar(
      state.copyWith(
        conQuien: Set.unmodifiable(soloNoLoSe),
        preocupaciones: Set.unmodifiable(preocupaciones),
        estilo: () => estilo,
      ),
    );
  }

  /// Marca o desmarca una preocupación (desde «Lo que te preocupa», sin abrir el ticket).
  void alternarPreocupacion(Preocupacion preocupacion) {
    final nuevas = {...state.preocupaciones};
    if (!nuevas.remove(preocupacion)) nuevas.add(preocupacion);
    _cambiar(state.copyWith(preocupaciones: Set.unmodifiable(nuevas)));
  }

  void ponerEstilo(EstiloExplicacion? estilo) => _cambiar(state.copyWith(estilo: () => estilo));

  /// El día de la citación (se guarda solo el día).
  void ponerFecha(DateTime dia) => _cambiar(state.copyWith(fecha: () => DateTime(dia.year, dia.month, dia.day)));

  void ponerHora(int horas, int minutos) {
    if (horas < 0 || horas > 23 || minutos < 0 || minutos > 59) return;
    _cambiar(state.copyWith(hora: () => (horas: horas, minutos: minutos)));
  }

  void quitarHora() => _cambiar(state.copyWith(hora: () => null));

  /// Marca como preparada (o no) una cosa sugerida o propia.
  void marcarLlevar(String id, bool hecho) {
    final propia = state.llevarPropias.indexWhere((c) => c.id == id);
    if (propia >= 0) {
      _cambiar(
        state.copyWith(
          llevarPropias: List.unmodifiable([
            for (final c in state.llevarPropias) c.id == id ? c.copyWith(hecho: hecho) : c,
          ]),
        ),
      );
      return;
    }
    final hechas = {...state.llevarHecho};
    if (hecho ? !hechas.add(id) : !hechas.remove(id)) return;
    _cambiar(state.copyWith(llevarHecho: Set.unmodifiable(hechas)));
  }

  /// Añade una cosa propia. false si está vacía, si ya está o si ya hay [maxCosasPropias].
  bool anadirLlevar(String texto) {
    final limpio = limpiarCosaPropia(texto);
    if (limpio.isEmpty || state.llevarPropias.length >= maxCosasPropias) return false;
    final igual = limpio.toLowerCase();
    if (state.llevarPropias.any((c) => c.texto.toLowerCase() == igual)) return false;
    var id = ref.read(relojProvider)().microsecondsSinceEpoch;
    final usados = {for (final c in state.llevarPropias) c.id};
    while (usados.contains('p$id')) {
      id++;
    }
    _cambiar(
      state.copyWith(
        llevarPropias: List.unmodifiable([...state.llevarPropias, CosaPropia(id: 'p$id', texto: limpio)]),
      ),
    );
    return true;
  }

  void quitarLlevar(String id) => _cambiar(
    state.copyWith(
      llevarPropias: List.unmodifiable([
        for (final c in state.llevarPropias)
          if (c.id != id) c,
      ]),
      llevarHecho: Set.unmodifiable({...state.llevarHecho}..remove(id)),
    ),
  );

  /// «Borrar mi día»: la fecha, la hora y la lista de lo que llevar.
  void borrarDia() =>
      _cambiar(state.copyWith(fecha: () => null, hora: () => null, llevarHecho: const {}, llevarPropias: const []));

  /// «Borrar mis respuestas» de Mi situación: con quién, preocupaciones y estilo (y «Tu día», si [tambienDia]).
  Future<void> borrarRespuestas({bool tambienDia = false}) async {
    final limpio = tambienDia
        ? const MiTicket()
        : MiTicket(
            fecha: state.fecha,
            hora: state.hora,
            llevarHecho: state.llevarHecho,
            llevarPropias: state.llevarPropias,
          );
    if (limpio.vacio) {
      state = const MiTicket();
      await ref.read(sharedPreferencesProvider).remove(clave);
      return;
    }
    _cambiar(limpio);
  }

  void _cambiar(MiTicket nuevo) {
    if (nuevo == state) return;
    state = nuevo;
    final prefs = ref.read(sharedPreferencesProvider);
    // El caché de shared_preferences cambia ya (antes de escribir en el disco): si build() vuelve a leer, lee esto.
    final escritura = nuevo.vacio ? prefs.remove(clave) : prefs.setString(clave, jsonEncode(nuevo.toJson()));
    unawaited(escritura.then<void>((_) {}, onError: (Object _) {}));
  }
}
