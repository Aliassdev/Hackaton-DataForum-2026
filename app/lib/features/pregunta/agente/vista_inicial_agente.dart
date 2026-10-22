import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart';
import '../../../core/providers.dart';
import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../textos.dart';
import '../widgets/mensajes.dart';
import '../widgets/tickets.dart';
import 'chat_agente.dart';
import 'hoja_perfil.dart';
import 'textos_agente.dart';

/// Antes de la primera pregunta, en el modo agente: para quién se explica (el perfil, con «Cambiar»), quién responde
/// (una IA), el saludo del agente cuando llega (se oye y también se lee), el aviso de que contesta en voz alta y las
/// preguntas de ejemplo.
class VistaInicialAgente extends ConsumerWidget {
  const VistaInicialAgente({super.key, required this.onEjemplo, this.situacion});

  final ValueChanged<String> onEjemplo;

  /// La de la ruta (elige el chat). La actual puede haberse quitado: se lee del estado.
  final RolProceso? situacion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final proveedor = chatAgenteProvider(situacion);
    final chat = ref.watch(proveedor.notifier) as ChatAgenteNotifier;
    final (:situacionActual, :ejemplos) = ref.watch(
      proveedor.select((s) => (situacionActual: s.situacion, ejemplos: s.ejemplos)),
    );
    final preguntas = ejemplosPara(situacionActual);
    // Con «Sin voz» o con lector de pantalla se contesta por escrito: no hace falta el aviso de la voz.
    final vozPosible =
        ref.watch(ajustesProvider.select((a) => a.vozActivada)) && !MediaQuery.accessibleNavigationOf(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.m, Espacio.m, Espacio.l),
      children: [
        Aparecer(child: ResumenPerfil(proveedor: proveedor)),
        const SizedBox(height: Espacio.m),
        const Aparecer(child: BurbujaPresentacion()),
        ValueListenableBuilder<SesionAgente>(
          valueListenable: chat.sesion,
          builder: (context, sesion, _) {
            // Lo que el agente dice antes de la primera pregunta: se oye y también se lee aquí.
            final dichos = [
              if (sesion.saludo case final saludo? when saludo.isNotEmpty) saludo,
              ...sesion.antesDePreguntar,
            ];
            final conVoz =
                vozPosible && !ejemplos && sesion.fase != FaseAgente.texto && sesion.fase != FaseAgente.sinVoz;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (dichos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: Espacio.m),
                    child: Aparecer(
                      child: Semantics(
                        container: true,
                        label: 'TuTurno dice',
                        child: FilaAsistente(
                          child: Container(
                            key: const Key('saludo-agente'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: Espacio.m,
                              vertical: Espacio.s + Espacio.xs,
                            ),
                            decoration: BoxDecoration(
                              color: context.colores.ticket,
                              border: Border.all(color: esquema.outlineVariant),
                              borderRadius: formaBurbuja(usuario: false),
                              boxShadow: sombrasPapel(context, elevacion: 0.6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final (i, dicho) in dichos.indexed)
                                  Padding(
                                    padding: EdgeInsets.only(top: i == 0 ? 0 : Espacio.s),
                                    child: Text(
                                      dicho,
                                      style: tema.textTheme.bodyLarge?.copyWith(
                                        color: context.colores.tintaTicket,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Con la voz del agente: que se sepa antes de preguntar que contesta en alto.
                if (conVoz) ...[
                  const SizedBox(height: Espacio.s + Espacio.xs),
                  _Nota(key: const Key('aviso-voz-alta'), icono: TuIcono.altavoz, texto: textoAvisoVozAlta),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: Espacio.s + Espacio.xs),
        Aparecer(
          retraso: Duracion.corta * 0.5,
          child: const _Nota(icono: TuIcono.info, texto: textoAvisoIa),
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
        for (var i = 0; i < preguntas.length; i++) ...[
          Aparecer(
            retraso: Duracion.corta * (i + 2) * 0.5,
            child: TicketPregunta(
              texto: preguntas[i].texto,
              icono: preguntas[i].icono,
              onTap: () => onEjemplo(preguntas[i].texto),
            ),
          ),
          const SizedBox(height: Espacio.s + Espacio.xs),
        ],
      ],
    );
  }
}

/// Una nota pequeña con su icono (decorativo).
class _Nota extends StatelessWidget {
  const _Nota({super.key, required this.icono, required this.texto});

  final TuIcono icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconoTuTurno(icono, estilo: EstiloIcono.mono, color: esquema.onSurfaceVariant, decorativo: true),
        const SizedBox(width: Espacio.s),
        Expanded(
          child: Text(texto, style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
        ),
      ],
    );
  }
}
