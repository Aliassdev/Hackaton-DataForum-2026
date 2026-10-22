import 'package:flutter/material.dart';

import '../../../core/mis_preguntas.dart' show TipoApunte;
import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../../../widgets/movimiento/hapticos.dart';
import '../../pasos/linea_pasos.dart' show BotonApuntar;
import '../mi_ticket.dart';
import '../personalizacion.dart';
import '../textos.dart';
import 'comunes.dart';

/// «Lo que te preocupa»: eliges lo que te preocupa (se guarda en tu ticket, sin contar nada de lo que pasó) y te
/// responde una a una con lo que dice la ley, con su fuente, y con consejos prácticos marcados como tales. Debajo de
/// cada respuesta, ideas de preguntas para apuntar en «Mis preguntas».
class LoQueTePreocupa extends StatelessWidget {
  const LoQueTePreocupa({super.key, required this.elegidas, required this.respuestas, required this.alAlternar});

  final Set<Preocupacion> elegidas;
  final List<RespuestaParaTi> respuestas;
  final ValueChanged<Preocupacion> alAlternar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          elegidas.isEmpty ? textoSinPreocupaciones : 'Esto es lo que dice la ley sobre lo que te preocupa:',
          style: tema.textTheme.bodyLarge,
        ),
        const SizedBox(height: Espacio.s),
        Wrap(
          spacing: Espacio.s,
          runSpacing: Espacio.xs,
          children: [
            for (final p in Preocupacion.values)
              FilterChip(
                label: Text(p.etiqueta),
                selected: elegidas.contains(p),
                onSelected: (_) {
                  Hapticos.seleccion();
                  alAlternar(p);
                },
              ),
          ],
        ),
        for (final respuesta in respuestas) ...[const SizedBox(height: Espacio.m), _Respuesta(respuesta: respuesta)],
      ],
    );
  }
}

class _Respuesta extends StatelessWidget {
  const _Respuesta({required this.respuesta});

  final RespuestaParaTi respuesta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final colores = context.colores;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colores.ticket,
        borderRadius: BorderRadius.circular(Radios.m),
        border: Border.all(color: esquema.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.m, Espacio.m, Espacio.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Row(
                children: [
                  const IconoTuTurno(TuIcono.personaConfianza, size: Espacio.l + Espacio.xs, decorativo: true),
                  const SizedBox(width: Espacio.s),
                  Expanded(
                    child: Text(
                      respuesta.titulo,
                      style: tema.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colores.tintaTicket,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final punto in respuesta.puntos)
              Padding(
                padding: const EdgeInsets.only(top: Espacio.s + Espacio.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: Espacio.xs),
                      child: IconoTuTurno(
                        punto.consejo ? TuIcono.idea : TuIcono.ley,
                        size: Espacio.m + 2,
                        estilo: EstiloIcono.mono,
                        color: esquema.primary,
                        decorativo: true,
                      ),
                    ),
                    const SizedBox(width: Espacio.s),
                    Expanded(
                      child: PuntoConFuentes(punto: punto, contexto: respuesta.titulo, color: colores.tintaTicket),
                    ),
                  ],
                ),
              ),
            if (respuesta.ideas.isNotEmpty) ...[
              const SizedBox(height: Espacio.s + Espacio.xs),
              Text(
                'Para preguntarlo tú:',
                style: tema.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: esquema.onSurfaceVariant,
                ),
              ),
              for (final idea in respuesta.ideas)
                Row(
                  children: [
                    Expanded(
                      child: Text('«$idea»', style: tema.textTheme.bodyMedium?.copyWith(color: colores.tintaTicket)),
                    ),
                    BotonApuntar(texto: idea, tipo: TipoApunte.preguntar),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
