import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'agente_config.dart';
import 'agente_voz.dart';
import 'elevenlabs_agente_voz.dart';

/// Pregunta habla con el agente de voz de ElevenLabs si hay agent_id (Ajustes o AGENT_ID en env/dev.json).
///
/// No depende de USE_MOCK: el agente no usa nuestra API_URL, sino el backend que tiene configurado en ElevenLabs.
/// En la web sigue el modo texto: el SDK solo declara Android e iOS y en Chrome no está probado.
final modoAgenteProvider = Provider<bool>((ref) => !kIsWeb && ref.watch(agentIdProvider).trim().isNotEmpty);

/// El agente de voz de Pregunta, o null si no hay agent_id (modo texto). Uno por pantalla: al salir de Pregunta se
/// cierra la sesión y se suelta la sala de LiveKit (y con ella el modo llamada y el foco de audio de Android). Si
/// cambia el agent_id, se crea otro.
final agenteVozProvider = Provider.autoDispose<AgenteVoz?>((ref) {
  if (!ref.watch(modoAgenteProvider)) return null;
  final agente = ElevenLabsAgenteVoz(agentId: ref.watch(agentIdProvider));
  ref.onDispose(agente.dispose);
  return agente;
});
