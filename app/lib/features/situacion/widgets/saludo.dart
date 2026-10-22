import 'package:flutter/material.dart';

import '../../../core/entrada.dart';
import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../mi_ticket.dart';
import '../personalizacion.dart';
import '../textos.dart';

/// El saludo de la portada de Mi situación: Tut tranquilo con una frase que cambia con tu ticket (tu papel, tu edad,
/// cómo prefieres que te lo cuente, con quién irás, lo que te preocupa y tu día), el resumen de tu ticket y «Cambiar mi
/// ticket». Si miras un papel que no es el de tu ticket, te ofrece volver al tuyo.
class SaludoSituacion extends StatelessWidget {
  const SaludoSituacion({
    super.key,
    required this.perfil,
    required this.alCambiarTicket,
    this.alVerElMio,
    this.hayQueLlevar = true,
    this.hayRespuestas = true,
  });

  final PerfilSituacion perfil;
  final VoidCallback alCambiarTicket;

  /// Abajo hay cosas que llevar y respuestas a lo que te preocupa (si no, el saludo no las anuncia).
  final bool hayQueLlevar;
  final bool hayRespuestas;

  /// Lleva al camino del papel del ticket (cuando se mira otro).
  final VoidCallback? alVerElMio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final colores = context.colores;
    final saludo = saludoPara(perfil, hayQueLlevar: hayQueLlevar, hayRespuestas: hayRespuestas);
    final etiquetas = _etiquetas(perfil.entrada, perfil.ticket);
    final otro = perfil.papelDelTicket;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colores.ticket,
        borderRadius: BorderRadius.circular(Radios.l),
        border: Border.all(color: esquema.outlineVariant),
        boxShadow: sombrasPapel(context, elevacion: 0.6),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.m, Espacio.m, Espacio.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MascotaTut(
                  size: 64,
                  animada: false,
                  expresion: perfil.esElDia ? ExpresionTut.animo : ExpresionTut.neutral,
                  decorativo: true,
                ),
                const SizedBox(width: Espacio.s + Espacio.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          saludo.titulo,
                          style: tema.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colores.tintaTicket,
                          ),
                        ),
                      ),
                      const SizedBox(height: Espacio.xs),
                      Text(saludo.texto, style: tema.textTheme.bodyLarge?.copyWith(color: colores.tintaTicket)),
                    ],
                  ),
                ),
              ],
            ),
            if (etiquetas.isNotEmpty) ...[
              const SizedBox(height: Espacio.s + Espacio.xs),
              Semantics(
                label: 'Tu ticket: ${etiquetas.join(', ')}',
                excludeSemantics: true,
                child: Wrap(
                  spacing: Espacio.xs + 2,
                  runSpacing: Espacio.xs + 2,
                  children: [for (final etiqueta in etiquetas) _Etiqueta(texto: etiqueta)],
                ),
              ),
            ],
            if (perfil.miraOtroPapel && otro != null && alVerElMio != null) ...[
              const SizedBox(height: Espacio.s),
              Text(
                '$textoTicketOtroPapel «${otro.nombre}».',
                style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
              ),
            ],
            Wrap(
              spacing: Espacio.xs,
              children: [
                TextButton.icon(
                  onPressed: alCambiarTicket,
                  icon: const IconoTuTurno(TuIcono.ticket, estilo: EstiloIcono.mono, decorativo: true),
                  label: Text(perfil.personalizado ? botonCambiarTicket : botonRellenarTicket),
                ),
                if (perfil.miraOtroPapel && otro != null && alVerElMio != null)
                  TextButton.icon(
                    onPressed: alVerElMio,
                    icon: IconoTuTurno(otro.tuIcono, estilo: EstiloIcono.mono, decorativo: true),
                    label: Text('$botonVerElMio: ${otro.nombre}'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Lo que dice el ticket, en etiquetas cortas: «13 años», «Penal», «Víctima», «Durante», «Con tu familia», «Con
  /// ejemplos».
  static List<String> _etiquetas(Entrada entrada, MiTicket ticket) {
    final resumen = resumenTicket(entrada);
    final con = ticket.conQuienEnFrase;
    return [
      if (resumen.isNotEmpty) ...resumen.split(' · '),
      if (con != null) 'Con $con',
      if (ticket.estilo != null) ticket.estilo!.etiqueta,
    ];
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: esquema.surfaceContainerHigh, borderRadius: BorderRadius.circular(Radios.s)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Espacio.s + 2, vertical: Espacio.xs),
        child: Text(
          texto,
          style: tema.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: esquema.onSurface),
        ),
      ),
    );
  }
}
