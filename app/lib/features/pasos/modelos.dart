import 'package:flutter/foundation.dart';

import '../../core/entrada.dart' show Fase;
import '../../core/texto.dart';

// Itinerario de «Mi situación» (docs/ARQUITECTURA.md, secciones 4.4 y 9.5): los pasos de un proceso para un papel
// (testigo, víctima, investigado…), con qué pasa en cada uno, quién estará, qué puedes pedir y de dónde sale.
// Habla del proceso, nunca de lo que pasó.
//
// Además del esquema 9.5, cada paso admite "fase" (antes, durante o despues), opcional, para marcar «Estás aquí»
// con la fase del formulario de entrada.

/// Un paso del itinerario.
@immutable
class Paso {
  const Paso({
    required this.id,
    required this.nombre,
    this.quePasa = '',
    this.quienEsta = const [],
    this.quePuedesPedir = const [],
    this.fuentes = const [],
    this.fase,
  });

  /// Lanza [FormatException] si falta el nombre: un paso sin nombre no se puede enseñar.
  /// Sin id, se usa [idPorDefecto] (p. ej. «P3»).
  factory Paso.fromJson(Map<String, dynamic> json, {String idPorDefecto = ''}) {
    final nombre = _texto(json['nombre']);
    if (nombre.isEmpty) throw FormatException('Paso sin nombre', json['id']);
    final id = _texto(json['id']);
    return Paso(
      id: id.isNotEmpty ? id : idPorDefecto,
      nombre: nombre,
      quePasa: _texto(json['que_pasa']),
      quienEsta: _textos(json['quien_esta']),
      quePuedesPedir: _textos(json['que_puedes_pedir']),
      fuentes: _textos(json['fuentes']),
      fase: faseDe(json['fase']),
    );
  }

  final String id;
  final String nombre;
  final String quePasa;
  final List<String> quienEsta;
  final List<String> quePuedesPedir;

  /// Tarjetas de conocimiento (p. ej. «A-050») o citas («LECrim, art. 449 ter»). Sin fuentes, el paso no se enseña.
  final List<String> fuentes;

  /// En qué momento del proceso está el paso. null si el itinerario no lo dice.
  final Fase? fase;
}

/// Itinerario de un papel: `content/itinerarios/<rol>.json`.
@immutable
class Itinerario {
  const Itinerario({required this.rol, required this.pasos, this.validado = false});

  /// Los pasos mal formados (sin nombre o que no son un objeto) se saltan: no dejan sin línea al resto.
  /// Si el JSON no dice el papel, se usa [rol].
  factory Itinerario.fromJson(Map<String, dynamic> json, {String rol = ''}) {
    final pasos = <Paso>[];
    final lista = json['pasos'];
    if (lista is List) {
      for (final (i, p) in lista.indexed) {
        if (p is! Map<String, dynamic>) continue;
        try {
          pasos.add(Paso.fromJson(p, idPorDefecto: 'P${i + 1}'));
        } on FormatException catch (e) {
          debugPrint('Pasos: paso no válido en el itinerario de «${json['rol'] ?? rol}» (${e.message})');
        }
      }
    }
    final rolJson = _texto(json['rol']);
    return Itinerario(rol: rolJson.isNotEmpty ? rolJson : rol, pasos: pasos, validado: json['validado'] == true);
  }

  /// null si [json] no es un objeto. No lanza nunca.
  static Itinerario? tryParse(Object? json, {String rol = ''}) =>
      json is Map<String, dynamic> ? Itinerario.fromJson(json, rol: rol) : null;

  /// testigo, victima, investigado…
  final String rol;
  final List<Paso> pasos;

  /// "validado": true de verdad (no "true" ni 1), como el resto del contenido.
  final bool validado;

  /// Si algún paso dice en qué fase está.
  bool get tieneFases => pasos.any((p) => p.fase != null);

  Itinerario conPasos(List<Paso> pasos) => Itinerario(rol: rol, pasos: pasos, validado: validado);
}

/// «antes», «durante», «despues» (también «Después» o « DESPUES ») → [Fase]. null si no es ninguna.
Fase? faseDe(Object? valor) {
  if (valor is! String) return null;
  final clave = normalizar(valor.trim());
  for (final fase in Fase.values) {
    if (fase.valor == clave) return fase;
  }
  return null;
}

String _texto(Object? valor) => valor is String ? valor.trim() : '';

/// Una lista de textos (también vale un texto suelto). Se quitan los vacíos.
List<String> _textos(Object? valor) => switch (valor) {
  final List<Object?> lista => [
    for (final e in lista)
      if (e is String && e.trim().isNotEmpty) e.trim(),
  ],
  final String texto when texto.trim().isNotEmpty => [texto.trim()],
  _ => const [],
};
