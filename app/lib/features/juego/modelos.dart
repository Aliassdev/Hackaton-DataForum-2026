import 'package:flutter/foundation.dart';

import '../../core/texto.dart';

// Caso del juego «Vive el caso» (docs/ARQUITECTURA.md, sección 9.4): escenas con lugar, personajes, narración y,
// a veces, una decisión; cada buena decisión puede desbloquear una carta de derecho.

/// Una carta de derecho que se gana en el juego.
@immutable
class Carta {
  const Carta({required this.id, required this.titulo, required this.texto, required this.fuente});

  factory Carta.fromJson(Map<String, dynamic> json) => Carta(
    id: json['id'] as String,
    titulo: json['titulo'] as String,
    texto: _texto(json['texto']),
    fuente: _texto(json['fuente']),
  );

  final String id;
  final String titulo;
  final String texto;

  /// Artículo que la respalda, p. ej. «LECrim, art. 449 ter».
  final String fuente;
}

/// Una respuesta posible a una decisión.
@immutable
class Opcion {
  const Opcion({
    required this.texto,
    required this.correcta,
    required this.feedback,
    required this.fuente,
    this.siguiente,
    this.carta,
  });

  factory Opcion.fromJson(Map<String, dynamic> json) => Opcion(
    texto: json['texto'] as String,
    correcta: json['correcta'] == true,
    siguiente: _textoONulo(json['siguiente']),
    feedback: _texto(json['feedback']),
    fuente: _texto(json['fuente']),
    carta: _textoONulo(json['carta']),
  );

  final String texto;
  final bool correcta;

  /// Escena a la que lleva. Si falta, el caso termina.
  final String? siguiente;
  final String feedback;
  final String fuente;

  /// Carta que desbloquea, solo si es correcta.
  final String? carta;
}

@immutable
class Decision {
  const Decision({required this.pregunta, required this.opciones});

  factory Decision.fromJson(Map<String, dynamic> json) => Decision(
    pregunta: _texto(json['pregunta']),
    opciones: [for (final o in json['opciones'] as List) Opcion.fromJson(o as Map<String, dynamic>)],
  );

  final String pregunta;
  final List<Opcion> opciones;
}

@immutable
class Escena {
  const Escena({
    required this.id,
    required this.lugar,
    required this.narracion,
    this.personajes = const [],
    this.decision,
    this.siguiente,
  });

  factory Escena.fromJson(Map<String, dynamic> json) {
    final decision = json['decision'];
    final opciones = decision is Map<String, dynamic> ? decision['opciones'] : null;
    return Escena(
      id: json['id'] as String,
      lugar: _texto(json['lugar']),
      personajes: [
        for (final p in json['personajes'] as List? ?? const [])
          if (p is String && p.trim().isNotEmpty) p.trim(),
      ],
      narracion: _texto(json['narracion']),
      // Una decisión sin opciones no se puede jugar: la escena sigue como si no la tuviera.
      decision: opciones is List && opciones.isNotEmpty ? Decision.fromJson(decision as Map<String, dynamic>) : null,
      siguiente: _textoONulo(json['siguiente']),
    );
  }

  final String id;

  /// casa, colegio, instituto, juzgado, sala_espera, sala_gesell, despues, comisaria, fiscalia…
  final String lugar;
  final List<String> personajes;
  final String narracion;
  final Decision? decision;

  /// Escena siguiente cuando no hay decisión. Sin decisión ni siguiente, es el final del caso.
  final String? siguiente;

  /// Escenas a las que se puede ir desde esta.
  List<String> get salidas => switch (decision) {
    final d? => [
      for (final o in d.opciones)
        if (o.siguiente != null) o.siguiente!,
    ],
    null => [?siguiente],
  };
}

/// Un caso completo.
class Caso {
  Caso({
    required this.id,
    required this.titulo,
    required this.rol,
    required this.escenas,
    this.basadoEn = const [],
    this.cartas = const [],
    this.validado = false,
    String? protagonista,
    int? edad,
    String? resumen,
  }) : _porId = {for (final e in escenas) e.id: e},
       _cartas = {for (final c in cartas) c.id: c},
       protagonista = protagonista ?? _protagonistaDe(escenas),
       edad = edad ?? _edadDe(escenas.first.narracion),
       resumen = resumen ?? _resumenDe(escenas.first.narracion);

  /// Lanza si falta algo imprescindible (id, título o escenas). Para no lanzar, [tryParse].
  factory Caso.fromJson(Map<String, dynamic> json) {
    final escenas = [for (final e in json['escenas'] as List) Escena.fromJson(e as Map<String, dynamic>)];
    if (escenas.isEmpty) throw const FormatException('Un caso necesita al menos una escena');
    return Caso._desdeJson(json, escenas);
  }

  factory Caso._desdeJson(Map<String, dynamic> json, List<Escena> escenas) => Caso(
    id: json['id'] as String,
    titulo: json['titulo'] as String,
    rol: _texto(json['rol']),
    basadoEn: [
      for (final b in json['basado_en'] as List? ?? const [])
        if (b is String) b,
    ],
    escenas: escenas,
    cartas: [for (final c in json['cartas'] as List? ?? const []) Carta.fromJson(c as Map<String, dynamic>)],
    validado: json['validado'] == true,
    // No están en el esquema 9.4: si algún día se añaden, mandan; si no, se deducen de la primera escena.
    protagonista: _textoONulo(json['protagonista']),
    edad: (json['edad'] as num?)?.toInt(),
    resumen: _textoONulo(json['resumen']),
  );

  /// null si el JSON no es un caso jugable (falta algo o tiene un tipo que no toca). No lanza nunca.
  static Caso? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      return Caso.fromJson(json);
    } catch (e) {
      debugPrint('Juego: caso no válido (${json['id']}): $e');
      return null;
    }
  }

  final String id;
  final String titulo;

  /// testigo, victima o investigado.
  final String rol;
  final List<String> basadoEn;
  final List<Escena> escenas;
  final List<Carta> cartas;
  final bool validado;

  /// Quien protagoniza el caso: por defecto, el primer personaje de la primera escena.
  final String protagonista;

  /// Por defecto, la que dice la primera escena («Lucía tiene 11 años…»).
  final int? edad;

  /// Planteamiento corto para la tarjeta del caso: la primera escena sin la frase de presentación.
  final String resumen;

  final Map<String, Escena> _porId;
  final Map<String, Carta> _cartas;

  Escena get primera => escenas.first;

  Escena? escena(String id) => _porId[id];

  Carta? carta(String id) => _cartas[id];

  /// Número de decisiones del caso.
  int get decisiones => escenas.where((e) => e.decision != null).length;

  /// Cuántas escenas quedan después de [desde] por el camino más corto hasta un final (0 si [desde] es el final).
  /// Una salida a una escena que no existe cuenta como final, igual que en el motor.
  int distanciaAlFinal(String desde) {
    final vistas = {desde};
    var frontera = [desde];
    var pasos = 0;
    while (frontera.isNotEmpty) {
      final siguientes = <String>[];
      for (final id in frontera) {
        final salidas = escena(id)?.salidas.where((s) => _porId.containsKey(s)).toList() ?? const [];
        if (salidas.isEmpty) return pasos;
        for (final s in salidas) {
          if (vistas.add(s)) siguientes.add(s);
        }
      }
      if (siguientes.isEmpty) return pasos;
      frontera = siguientes;
      pasos++;
    }
    return pasos;
  }

  static String _protagonistaDe(List<Escena> escenas) {
    for (final e in escenas) {
      if (e.personajes.isNotEmpty) return e.personajes.first;
    }
    return '';
  }

  static final _edad = RegExp(r'(\d{1,2})\s+años');

  static int? _edadDe(String narracion) => int.tryParse(_edad.firstMatch(narracion)?.group(1) ?? '');

  static final _finDeFrase = RegExp(r'(?<=[.!?…])\s+');

  static String _resumenDe(String narracion) {
    final frases = narracion.trim().split(_finDeFrase);
    // «Lucía tiene 11 años y va a sexto.» ya sale en la tarjeta como «Lucía, 11 años».
    if (frases.length > 1 && _edad.hasMatch(frases.first)) frases.removeAt(0);
    return frases.join(' ');
  }
}

/// Dónde pasa una escena. Los valores del JSON se aceptan con o sin tildes y con espacios o guiones.
enum Lugar {
  casa('En casa'),
  colegio('En el colegio'),
  instituto('En el instituto'),
  juzgado('En el juzgado'),
  salaEspera('En la sala de espera'),
  salaGesell('En la Sala Gesell'),
  despues('Después'),
  comisaria('En la comisaría'),
  fiscalia('En la Fiscalía'),
  otro('Escena');

  const Lugar(this.nombre);

  /// Para la etiqueta de la ilustración y para el lector de pantalla.
  final String nombre;

  static const _alias = {
    'casa': casa,
    'hogar': casa,
    'colegio': colegio,
    'instituto': instituto,
    'ies': instituto,
    'escuela': colegio,
    'centro_educativo': colegio,
    'juzgado': juzgado,
    'tribunal': juzgado,
    'juicio': juzgado,
    'sala_de_vistas': juzgado,
    'sala_espera': salaEspera,
    'sala_de_espera': salaEspera,
    'espera': salaEspera,
    'sala_gesell': salaGesell,
    'gesell': salaGesell,
    'despues': despues,
    'comisaria': comisaria,
    'policia': comisaria,
    'fiscalia': fiscalia,
    'fiscalia_de_menores': fiscalia,
  };

  static Lugar desde(String valor) => _alias[normalizar(valor.trim()).replaceAll(RegExp(r'[\s-]+'), '_')] ?? Lugar.otro;
}

String _texto(Object? valor) => valor is String ? valor.trim() : '';

String? _textoONulo(Object? valor) {
  final texto = _texto(valor);
  return texto.isEmpty ? null : texto;
}
