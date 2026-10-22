import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../providers.dart';
import 'agente_config.dart';
import 'agente_voz.dart';
import 'elevenlabs_ws_agente_voz.dart';
import 'url_firmada.dart';

/// Pregunta habla con el agente de voz de ElevenLabs si hay API_URL (el backend da la URL firmada de la sesión) o
/// agent_id (Ajustes o AGENT_ID en env/dev.json).
///
/// En la web sigue el modo texto. Con WebSocket la voz podría ir en Chrome, pero falta probarlo: el navegador solo deja
/// sonar audio después de un toque, Safari es más estricto, y el backend tendría que permitir la URL firmada por CORS.
final modoAgenteProvider = Provider<bool>(
  (ref) => !kIsWeb && (ref.watch(agentIdProvider).trim().isNotEmpty || ref.watch(apiUrlProvider).trim().isNotEmpty),
);

/// La última URL firmada. Vive lo que la app, para no pedir otra cada vez que se entra en Pregunta.
final cacheUrlFirmadaProvider = Provider<CacheUrlFirmada>((ref) => CacheUrlFirmada());

/// El agente de voz de Pregunta, o null en el modo texto. Uno por pantalla: al salir de Pregunta se cierra la sesión y
/// se suelta el reproductor. Si cambian la API_URL o el agent_id, se crea otro.
final agenteVozProvider = Provider.autoDispose<AgenteVoz?>((ref) {
  if (!ref.watch(modoAgenteProvider)) return null;
  final apiUrl = ref.watch(apiUrlProvider).trim();
  final cliente = apiUrl.isEmpty ? null : http.Client();
  final agente = ElevenLabsWsAgenteVoz(
    agentId: ref.watch(agentIdProvider),
    urlFirmada: cliente == null
        ? null
        : FuenteUrlFirmada(
            apiUrl: apiUrl,
            cache: ref.watch(cacheUrlFirmadaProvider),
            pedir: (limite) => pedirUrlFirmada(cliente, apiUrl, limite: limite),
          ),
  );
  ref.onDispose(() {
    agente.dispose();
    cliente?.close();
  });
  return agente;
});
