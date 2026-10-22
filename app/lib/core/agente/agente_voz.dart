import 'package:flutter/foundation.dart';

// Agente de voz de Pregunta (docs/ARQUITECTURA.md, sección 5.0, fase 1: ElevenLabs Agents).
// La app nunca le envía audio: la voz del menor se transcribe en el móvil y llega como texto.

enum EstadoAgente { desconectado, conectando, conectado }

/// Un mensaje de la conversación: del agente o del usuario.
@immutable
class MensajeAgente {
  const MensajeAgente({required this.texto, required this.deAgente, this.corrigeA});

  final String texto;
  final bool deAgente;

  /// Si no es null, este mensaje no es nuevo: corrige uno anterior del agente al que se ha interrumpido.
  /// [corrigeA] es el texto original y [texto], lo que llegó a decir antes de la interrupción (puede ser «...»).
  final String? corrigeA;

  bool get esCorreccion => corrigeA != null;
}

abstract interface class AgenteVoz {
  ValueListenable<EstadoAgente> get estado;

  /// true mientras el agente habla. Entonces no se escucha con el micrófono: se transcribiría su voz.
  ValueListenable<bool> get hablando;

  /// Mensajes en orden de llegada.
  Stream<MensajeAgente> get mensajes;

  /// Errores con un texto que se puede enseñar al usuario.
  Stream<String> get errores;

  /// Abre la sesión con las variables de la sección 8.6 y silencia el micrófono de la sesión.
  /// Lanza una excepción si no se puede conectar.
  Future<void> iniciar({required Map<String, String> variables});

  void enviarTexto(String texto);

  /// Mientras el usuario escribe, para que el agente no le interrumpa.
  void avisarQueEscribe();

  Future<void> terminar();

  void dispose();
}
