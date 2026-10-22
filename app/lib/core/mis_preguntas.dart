import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'progreso.dart' show relojProvider;
import 'providers.dart';
import 'texto.dart';

// «Mis preguntas» (plan v2, producto §5.2): lo que el chico o la chica quiere pedir (apuntado desde los pasos de Mi
// situación) o preguntar (escrito por él o ella, o elegido de una lista) a las personas que llevan su caso. Tiene
// derecho a que se lo expliquen con palabras que entienda (LO 1/1996, art. 9.1). Se guarda solo en este móvil: nunca
// se envía a ningún sitio ni se escribe en los logs.

/// Cuántos apuntes caben como mucho.
const maxApuntes = 30;

/// Largo máximo de un apunte, en caracteres (lo que pasa de aquí se recorta).
const maxCaracteresApunte = 200;

enum TipoApunte {
  /// «Quiero pedir»: apuntado desde un paso de Mi situación (contenido validado, con su fuente).
  pedir,

  /// «Quiero preguntar»: escrito por el usuario o elegido de las ideas de preguntas.
  preguntar,
}

@immutable
class Apunte {
  const Apunte({
    required this.id,
    required this.texto,
    required this.tipo,
    this.origen,
    this.fuentes = const [],
    this.hecho = false,
  });

  /// Lee un apunte guardado. Lanza [FormatException] si falta el id o el texto; lo demás tiene valor por defecto.
  factory Apunte.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final texto = json['texto'];
    if (id is! String || id.isEmpty || texto is! String) throw const FormatException('Apunte sin id o sin texto');
    final limpio = limpiarApunte(texto);
    if (limpio.isEmpty) throw const FormatException('Apunte vacío');
    final origen = json['origen'];
    final fuentes = json['fuentes'];
    return Apunte(
      id: id,
      texto: limpio,
      tipo: TipoApunte.values.asNameMap()[json['tipo']] ?? TipoApunte.preguntar,
      origen: origen is String && origen.trim().isNotEmpty ? origen.trim() : null,
      fuentes: List.unmodifiable([
        if (fuentes is List)
          for (final f in fuentes)
            if (f is String) f,
      ]),
      hecho: json['hecho'] == true,
    );
  }

  /// Microsegundos del reloj ([relojProvider]) al apuntarlo.
  final String id;

  /// Como mucho [maxCaracteresApunte] caracteres.
  final String texto;
  final TipoApunte tipo;

  /// Nombre del paso del que viene («Te citan para escucharte»), si viene de un paso.
  final String? origen;

  /// Fuentes del paso, para enseñarlas pequeñas.
  final List<String> fuentes;

  /// «Ya lo he preguntado».
  final bool hecho;

  Map<String, dynamic> toJson() => {
    'id': id,
    'texto': texto,
    'tipo': tipo.name,
    'origen': origen,
    'fuentes': fuentes,
    'hecho': hecho,
  };

  Apunte copyWith({String? texto, bool? hecho}) => Apunte(
    id: id,
    texto: texto ?? this.texto,
    tipo: tipo,
    origen: origen,
    fuentes: fuentes,
    hecho: hecho ?? this.hecho,
  );

  @override
  bool operator ==(Object other) =>
      other is Apunte &&
      other.id == id &&
      other.texto == texto &&
      other.tipo == tipo &&
      other.origen == origen &&
      listEquals(other.fuentes, fuentes) &&
      other.hecho == hecho;

  @override
  int get hashCode => Object.hash(id, texto, tipo, origen, Object.hashAll(fuentes), hecho);

  @override
  String toString() => 'Apunte($id, ${tipo.name}${hecho ? ', hecho' : ''})';
}

final _espacios = RegExp(r'\s+');

/// El texto tal como se guarda: sin espacios de sobra y con [maxCaracteresApunte] caracteres como mucho (sin partir
/// letras con tilde ni emojis).
String limpiarApunte(String texto) {
  final limpio = texto.replaceAll(_espacios, ' ').trim();
  final caracteres = limpio.characters;
  return caracteres.length <= maxCaracteresApunte
      ? limpio
      : caracteres.take(maxCaracteresApunte).toString().trimRight();
}

/// Para saber si dos apuntes dicen lo mismo: sin que importen las mayúsculas, las tildes ni los espacios.
String _comparable(String texto) => normalizar(limpiarApunte(texto));

final misPreguntasProvider = NotifierProvider<MisPreguntasNotifier, List<Apunte>>(MisPreguntasNotifier.new);

class MisPreguntasNotifier extends Notifier<List<Apunte>> {
  /// Clave en shared_preferences (también la borra «Borrar todo», lib/core/borrar_todo.dart).
  static const clave = 'mis_preguntas';

  /// Un JSON roto da la lista vacía; un apunte roto se salta.
  @override
  List<Apunte> build() {
    final guardado = ref.watch(sharedPreferencesProvider).getString(clave);
    if (guardado == null) return const [];
    try {
      final datos = jsonDecode(guardado);
      if (datos is! List) return const [];
      final apuntes = <Apunte>[];
      final ids = <String>{};
      for (final dato in datos) {
        if (apuntes.length >= maxApuntes) break;
        if (dato is! Map<String, dynamic>) continue;
        try {
          final apunte = Apunte.fromJson(dato);
          if (ids.add(apunte.id)) apuntes.add(apunte);
        } on FormatException {
          continue;
        }
      }
      return List.unmodifiable(apuntes);
    } catch (_) {
      return const [];
    }
  }

  /// Apunta [texto]. Devuelve false, sin cambiar nada, si está vacío, si ya está apuntado (sin que importen las
  /// mayúsculas, las tildes ni los espacios) o si ya hay [maxApuntes].
  bool apuntar(String texto, {required TipoApunte tipo, String? origen, List<String> fuentes = const []}) {
    final limpio = limpiarApunte(texto);
    if (limpio.isEmpty || state.length >= maxApuntes || contiene(limpio)) return false;
    final nombrePaso = origen?.trim();
    _cambiar([
      ...state,
      Apunte(
        id: _nuevoId(),
        texto: limpio,
        tipo: tipo,
        origen: nombrePaso == null || nombrePaso.isEmpty ? null : nombrePaso,
        fuentes: List.unmodifiable(fuentes),
      ),
    ]);
    return true;
  }

  /// Quita el apunte que dice [texto] (para el botón «Apuntar» de un paso, que se desmarca al volver a tocarlo).
  void quitarTexto(String texto) {
    final buscado = _comparable(texto);
    if (buscado.isEmpty || !state.any((a) => _comparable(a.texto) == buscado)) return;
    _cambiar([
      for (final a in state)
        if (_comparable(a.texto) != buscado) a,
    ]);
  }

  /// «Ya lo he preguntado».
  void marcar(String id, bool hecho) {
    if (!state.any((a) => a.id == id && a.hecho != hecho)) return;
    _cambiar([for (final a in state) a.id == id ? a.copyWith(hecho: hecho) : a]);
  }

  /// Cambia el texto de un apunte propio ([TipoApunte.preguntar]). Lo apuntado desde un paso no se reescribe: es
  /// contenido validado, con su fuente. No hace nada si el texto nuevo está vacío o ya está en otro apunte.
  void editar(String id, String texto) {
    final apunte = state.where((a) => a.id == id).firstOrNull;
    if (apunte == null || apunte.tipo != TipoApunte.preguntar) return;
    final limpio = limpiarApunte(texto);
    final nuevo = _comparable(limpio);
    if (nuevo.isEmpty || limpio == apunte.texto) return;
    if (state.any((a) => a.id != id && _comparable(a.texto) == nuevo)) return;
    _cambiar([for (final a in state) a.id == id ? a.copyWith(texto: limpio) : a]);
  }

  void quitar(String id) {
    if (!state.any((a) => a.id == id)) return;
    _cambiar([
      for (final a in state)
        if (a.id != id) a,
    ]);
  }

  /// «Borrar todas» (con confirmación en la pantalla).
  Future<void> borrarTodas() async {
    state = const [];
    await ref.read(sharedPreferencesProvider).remove(clave);
  }

  /// Si [texto] ya está apuntado (sin que importen las mayúsculas, las tildes ni los espacios).
  bool contiene(String texto) {
    final buscado = _comparable(texto);
    return buscado.isNotEmpty && state.any((a) => _comparable(a.texto) == buscado);
  }

  String _nuevoId() {
    var id = ref.read(relojProvider)().microsecondsSinceEpoch;
    final usados = {for (final a in state) a.id};
    while (usados.contains('$id')) {
      id++;
    }
    return '$id';
  }

  void _cambiar(List<Apunte> apuntes) {
    state = List.unmodifiable(apuntes);
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString(clave, jsonEncode([for (final a in apuntes) a.toJson()]))
          .then<void>((_) {}, onError: (Object _) {}),
    );
  }
}
