import 'package:flutter/foundation.dart';

// Agente de voz de Pregunta (docs/ARQUITECTURA.md, sección 5.0, fase 1: ElevenLabs Agents).
// La app nunca le envía audio: la voz del menor se transcribe en el móvil y llega como texto. La sesión no usa el
// micrófono para nada; el permiso de micrófono solo lo pide el dictado (core/voz/stt.dart).

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

  /// true mientras suena la voz del agente. Entonces no se escucha con el micrófono: se transcribiría su voz.
  ValueListenable<bool> get hablando;

  /// Mensajes en orden de llegada.
  Stream<MensajeAgente> get mensajes;

  /// Errores con un texto que se puede enseñar al usuario.
  Stream<String> get errores;

  /// Abre la sesión con las variables de la sección 8.6. La sesión no usa el micrófono.
  /// Lanza una excepción si no se puede conectar.
  Future<void> iniciar({required Map<String, String> variables});

  void enviarTexto(String texto);

  /// Mientras el usuario escribe, para que el agente no le interrumpa.
  void avisarQueEscribe();

  Future<void> terminar();

  void dispose();
}

/// No se ha podido abrir la sesión. [mensaje] se puede enseñar tal cual.
class ErrorAgente implements Exception {
  const ErrorAgente(this.mensaje, {this.causa});

  final String mensaje;

  /// Lo que falló por dentro, solo para depurar. No se enseña.
  final Object? causa;

  @override
  String toString() => 'ErrorAgente: $mensaje';
}

/// Textos para el usuario: frases cortas y claras para 11 a 17 años. Sin promesas.
abstract final class TextosAgente {
  static const sinConfigurar =
      'TuTurno no está preparado en este móvil. Puedes usar las respuestas de ejemplo o pulsar Ayuda.';
  static const sinConexion = 'No se puede conectar con TuTurno ahora mismo. Mira si tienes internet y prueba otra vez.';
  static const cortado = 'Se ha cortado la conexión con TuTurno.';
  static const noEnviado = 'Tu mensaje no ha llegado a TuTurno. Prueba a enviarlo otra vez.';
  static const sinSesion = 'Ahora no hay conexión con TuTurno.';
}
