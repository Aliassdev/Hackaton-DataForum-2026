import 'package:flutter/material.dart';

import '../../../core/api/models.dart';
import '../../../widgets/fuente_chip.dart';

export '../../../widgets/fuente_chip.dart' show HojaFuente, abrirEnlaceFuente, esEnlaceBoe;

// Fuentes de las respuestas de Pregunta. El modo texto real (POST /api/agent/ask) trae el enlace de cada artículo en el
// BOE (o la web oficial, como la del Canal prioritario de la AEPD): la hoja de la fuente tiene un botón para leerlo.
// La etiqueta y la hoja son las comunes (widgets/fuente_chip.dart), que ya enseñan el botón cuando hay enlace; aquí
// quedan los nombres que usa Pregunta.

/// Etiqueta de una fuente en el talón de una respuesta. Con enlace, abre la hoja con «Leer la ley en el BOE».
class EtiquetaFuente extends StatelessWidget {
  const EtiquetaFuente({super.key, required this.fuente, this.numero});

  final Fuente fuente;

  /// Número con el que se cita en el texto (1, 2…), si lo hay.
  final int? numero;

  @override
  Widget build(BuildContext context) => FuenteChip(fuente: fuente, numero: numero);
}

/// La hoja de una fuente (con el botón para leerla si trae enlace).
Future<void> mostrarFuentePregunta(BuildContext context, Fuente fuente) => mostrarFuente(context, fuente);

/// El nombre fácil de [norma] («LO 5/2000» o «LORPM» → «Ley de responsabilidad penal de los menores»), si lo hay.
String? nombreFacilNorma(String norma) => nombreNorma(norma);
