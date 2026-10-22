import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

// De dónde sale el agent_id del agente de ElevenLabs (docs/ARQUITECTURA.md, sección 8.5):
// de Ajustes si se ha puesto ahí (sin recompilar) o de AGENT_ID (app/env/dev.json, fuera de git).

const _agentIdDeArranque = String.fromEnvironment('AGENT_ID');

final agentIdProvider = NotifierProvider<AgentIdNotifier, String>(AgentIdNotifier.new);

class AgentIdNotifier extends Notifier<String> {
  static const _clave = 'ajustes.agent_id';

  @override
  String build() {
    final manual = ref.watch(sharedPreferencesProvider).getString(_clave)?.trim();
    return manual != null && manual.isNotEmpty ? manual : _agentIdDeArranque;
  }

  /// true si viene de Ajustes y no del arranque.
  bool get esManual => ref.read(sharedPreferencesProvider).getString(_clave)?.trim().isNotEmpty ?? false;

  /// null o vacío vuelve al de arranque.
  Future<void> cambiar(String? agentId) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final limpio = agentId?.trim() ?? '';
    if (limpio.isEmpty) {
      await prefs.remove(_clave);
      state = _agentIdDeArranque;
    } else {
      await prefs.setString(_clave, limpio);
      state = limpio;
    }
  }
}
