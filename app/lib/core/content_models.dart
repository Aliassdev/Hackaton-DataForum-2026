// Esquemas de contenido (docs/ARQUITECTURA.md, sección 9). Por ahora, el glosario (9.6).

class EntradaGlosario {
  const EntradaGlosario({
    required this.id,
    required this.termino,
    required this.definicion,
    required this.ejemplo,
    required this.fuente,
    required this.validado,
  });

  factory EntradaGlosario.fromJson(Map<String, dynamic> json) => EntradaGlosario(
    id: json['id'] as String,
    termino: json['termino'] as String,
    definicion: json['definicion'] as String,
    ejemplo: json['ejemplo'] as String? ?? '',
    fuente: json['fuente'] as String? ?? '',
    validado: json['validado'] == true,
  );

  final String id;
  final String termino;
  final String definicion;
  final String ejemplo;

  /// Id de la tarjeta de conocimiento que respalda la definición (p. ej. A-060).
  final String fuente;
  final bool validado;
}
