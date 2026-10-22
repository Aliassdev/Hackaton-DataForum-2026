import 'package:flutter/material.dart';

import '../../../core/api/models.dart';
import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../textos.dart';
import 'mensajes.dart';
import 'tickets.dart';

/// Antes de la primera pregunta: el ticket de «tu turno de preguntar» (quién responde: una IA) y preguntas de
/// ejemplo, las del papel si lo hay. Tranquila: Tut no se mueve y nada pide prisa.
class VistaInicial extends StatelessWidget {
  const VistaInicial({super.key, required this.onEjemplo, this.situacion});

  final ValueChanged<String> onEjemplo;
  final RolProceso? situacion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final ejemplos = ejemplosPara(situacion);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.m, Espacio.m, Espacio.l),
      children: [
        const Aparecer(child: BurbujaPresentacion()),
        const SizedBox(height: Espacio.s + Espacio.xs),
        Aparecer(
          retraso: Duracion.corta * 0.5,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconoTuTurno(TuIcono.info, estilo: EstiloIcono.mono, color: esquema.onSurfaceVariant, decorativo: true),
              const SizedBox(width: Espacio.s),
              Expanded(
                child: Text(textoAvisoIa, style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
              ),
            ],
          ),
        ),
        const SizedBox(height: Espacio.l),
        Aparecer(
          retraso: Duracion.corta,
          child: Semantics(
            header: true,
            child: Text(
              'Prueba con una de estas preguntas',
              style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: Espacio.s + Espacio.xs),
        for (var i = 0; i < ejemplos.length; i++) ...[
          Aparecer(
            retraso: Duracion.corta * (i + 2) * 0.5,
            child: TicketPregunta(
              texto: ejemplos[i].texto,
              icono: ejemplos[i].icono,
              onTap: () => onEjemplo(ejemplos[i].texto),
            ),
          ),
          const SizedBox(height: Espacio.s + Espacio.xs),
        ],
      ],
    );
  }
}
