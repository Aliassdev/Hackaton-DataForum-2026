import 'package:flutter/material.dart';

import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../../../widgets/justicia/cartel_sala.dart';
import '../../pasos/fuentes_paso.dart';
import '../../pasos/personalizacion_linea.dart' show NotaParaTi;
import '../textos.dart';

/// El título de una sección de Mi situación como el cartel de la puerta de una sala («TU CAMINO»). Es un encabezado
/// para el lector de pantalla.
class CartelSeccion extends StatelessWidget {
  const CartelSeccion({super.key, required this.texto, required this.icono, this.detalle});

  final String texto;
  final TuIcono icono;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: CartelSala(texto: texto, detalle: detalle, icono: icono),
      ),
    );
  }
}

/// Un punto con sus fuentes (etiquetas que abren la hoja «De dónde sale») o, si es un consejo práctico, la etiqueta
/// «Consejo» (no es una afirmación jurídica).
class PuntoConFuentes extends StatelessWidget {
  const PuntoConFuentes({super.key, required this.punto, this.contexto, this.estilo, this.color});

  final NotaParaTi punto;

  /// De qué va, para recordarlo en la hoja de la fuente.
  final String? contexto;
  final TextStyle? estilo;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final citas = CitaPaso.de(punto.fuentes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(punto.texto, style: (estilo ?? tema.textTheme.bodyLarge)?.copyWith(color: color)),
        if (citas.isNotEmpty)
          Wrap(
            spacing: Espacio.s,
            children: [for (final cita in citas) ChipFuentePaso(cita: cita, paso: contexto)],
          )
        else if (punto.consejo)
          Padding(
            padding: const EdgeInsets.only(top: Espacio.xs),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radios.s),
                  border: Border.all(color: color ?? esquema.outline),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Espacio.s, vertical: 2),
                  child: Text(
                    etiquetaConsejo,
                    style: tema.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color ?? esquema.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Una pegatina pequeña de texto («Por tu edad»), amarilla con tinta azul noche (igual en los dos temas).
class Pegatina extends StatelessWidget {
  const Pegatina({super.key, required this.texto, this.icono});

  final String texto;
  final TuIcono? icono;

  @override
  Widget build(BuildContext context) {
    final icono = this.icono;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ColoresMarca.amarillo,
        borderRadius: BorderRadius.circular(Radios.s),
        border: Border.all(color: ColoresMarca.azulNoche, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Espacio.s, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              IconoTuTurno(icono, size: 14, estilo: EstiloIcono.mono, color: ColoresMarca.azulNoche, decorativo: true),
              const SizedBox(width: Espacio.xs),
            ],
            Flexible(
              child: Text(
                texto,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: ColoresMarca.azulNoche, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
