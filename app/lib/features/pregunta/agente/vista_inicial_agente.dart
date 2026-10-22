import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart';
import '../../../core/entrada.dart';
import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../../../widgets/movimiento/hapticos.dart';
import '../../../widgets/movimiento/ticket.dart';
import '../textos.dart';
import '../widgets/estilo.dart';
import '../widgets/mensajes.dart';
import '../widgets/tickets.dart';
import 'chat_agente.dart';
import 'hoja_perfil.dart';
import 'textos_agente.dart';

/// Antes de la primera pregunta, en el modo agente: quién responde (una IA que habla en voz alta), el saludo del
/// agente cuando llega (se oye y también se lee), el perfil con «Cambiar» y las preguntas de ejemplo.
class VistaInicialAgente extends ConsumerWidget {
  const VistaInicialAgente({super.key, required this.onEjemplo, this.situacion});

  final ValueChanged<String> onEjemplo;

  /// La de la ruta (elige el chat). La actual puede haberse quitado: se lee del estado.
  final RolProceso? situacion;

  Future<void> _cambiarPerfil(BuildContext context, WidgetRef ref) async {
    Hapticos.toque();
    final chat = ref.read(chatAgenteProvider(situacion).notifier) as ChatAgenteNotifier;
    final elegida = await mostrarHojaPerfil(
      context,
      inicial: ref.read(entradaProvider),
      situacion: ref.read(chatAgenteProvider(situacion)).situacion,
    );
    if (elegida == null || !context.mounted) return;
    await ref.read(entradaProvider.notifier).guardar(elegida);
    await chat.cambiarPerfil();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final chat = ref.watch(chatAgenteProvider(situacion).notifier) as ChatAgenteNotifier;
    final situacionActual = ref.watch(chatAgenteProvider(situacion).select((s) => s.situacion));
    final resumen = resumenPerfil(ref.watch(entradaProvider));
    final ejemplos = ejemplosPara(situacionActual);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.m, Espacio.m, Espacio.l),
      children: [
        const Aparecer(child: _Presentacion()),
        ValueListenableBuilder<SesionAgente>(
          valueListenable: chat.sesion,
          builder: (context, sesion, _) {
            // Lo que el agente dice antes de la primera pregunta: se oye y también se lee aquí.
            final dichos = [
              if (sesion.saludo case final saludo? when saludo.isNotEmpty) saludo,
              ...sesion.antesDePreguntar,
            ];
            if (dichos.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: Espacio.m),
              child: Aparecer(
                child: Semantics(
                  container: true,
                  label: 'TuTurno dice',
                  child: FilaAsistente(
                    child: Container(
                      key: const Key('saludo-agente'),
                      padding: const EdgeInsets.symmetric(horizontal: Espacio.m, vertical: Espacio.s + Espacio.xs),
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
            );
          },
        ),
        const SizedBox(height: Espacio.m),
        Aparecer(
          retraso: Duracion.corta * 0.5,
          child: Material(
            color: tinteMarca(esquema),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radios.m),
              side: BorderSide(color: esquema.primary.withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(Espacio.m, Espacio.s, Espacio.xs, Espacio.s),
              child: Row(
                children: [
                  IconoTuTurno(TuIcono.miSituacion, estilo: EstiloIcono.mono, color: esquema.primary, decorativo: true),
                  const SizedBox(width: Espacio.s + Espacio.xs),
                  Expanded(
                    child: Text(
                      resumen.isEmpty
                          ? 'Si me dices tu edad y tu situación, te lo explico mejor.'
                          : 'Para explicártelo mejor: $resumen',
                      style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurface, fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    key: const Key('cambiar-perfil'),
                    onPressed: () => _cambiarPerfil(context, ref),
                    child: Text(resumen.isEmpty ? 'Elegir' : 'Cambiar'),
                  ),
                ],
              ),
            ),
          ),
        ),
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

/// El ticket de «tu turno de preguntar», como en el modo texto, con el texto del modo agente (sin promesas sobre lo
/// que se guarda: depende de la configuración del agente).
class _Presentacion extends StatelessWidget {
  const _Presentacion();

  static const _letraGrande = 1.2;

  @override
  Widget build(BuildContext context) {
    final grande = MediaQuery.textScalerOf(context).scale(1) > _letraGrande;
    return TicketTuTurno(
      etiqueta: 'Tu turno de preguntar',
      titulo: '¿Qué quieres saber?',
      descripcion: textoPresentacionAgente,
      fondoTalon: ColoresMarca.azul,
      ladoTalon: grande ? LadoTalon.abajo : LadoTalon.derecha,
      tamanoTalon: grande ? 88 : 104,
      talon: MascotaTut(size: grande ? 72 : 88, animada: false, pegatina: true, decorativo: true),
    );
  }
}
