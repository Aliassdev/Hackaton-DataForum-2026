import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart';
import '../../../core/entrada.dart';
import 'banda_agente.dart';
import 'chat_agente.dart';
import 'hoja_perfil.dart';

/// Lo que añade el modo agente arriba del cuerpo de Pregunta:
/// - la banda con el estado de la conversación ([BandaAgente]);
/// - al entrar, si no hay perfil (y no se ha preguntado ya en esta ejecución), la hoja del perfil, que se puede saltar;
///   después abre la sesión con el agente, para que el saludo se oiga enseguida;
/// - al pasar la app a segundo plano, cierra la sesión (el agente se calla); se vuelve a abrir al preguntar.
///
/// La sesión se cierra al salir de Pregunta: el chat del agente ([chatAgenteProvider]) es autoDispose.
class CapaAgente extends ConsumerStatefulWidget {
  const CapaAgente({super.key, required this.situacion});

  /// La de la ruta: elige el chat.
  final RolProceso? situacion;

  @override
  ConsumerState<CapaAgente> createState() => _CapaAgenteState();
}

class _CapaAgenteState extends ConsumerState<CapaAgente> {
  late final AppLifecycleListener _ciclo;

  ChatAgenteNotifier get _chat => ref.read(chatAgenteProvider(widget.situacion).notifier) as ChatAgenteNotifier;

  @override
  void initState() {
    super.initState();
    // Al ocultarse la app (antes de pasar a segundo plano) se cierra la sesión: el agente deja de hablar.
    _ciclo = AppLifecycleListener(onHide: () => _chat.pausar(), onPause: () => _chat.pausar());
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_preparar()));
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  Future<void> _preparar() async {
    if (!mounted) return;
    final entrada = ref.read(entradaProvider);
    if (entrada.vacia && !ref.read(perfilPreguntadoProvider)) {
      ref.read(perfilPreguntadoProvider.notifier).marcar();
      final elegida = await mostrarHojaPerfil(context, situacion: widget.situacion);
      if (!mounted) return;
      if (elegida != null && !elegida.vacia) await ref.read(entradaProvider.notifier).guardar(elegida);
      if (!mounted) return;
    }
    unawaited(_chat.abrirSesion());
  }

  @override
  Widget build(BuildContext context) => BandaAgente(situacion: widget.situacion);
}
