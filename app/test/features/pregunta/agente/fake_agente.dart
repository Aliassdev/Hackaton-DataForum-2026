import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tuturno/core/agente/agente_voz.dart';

const saludoAgente = 'Hola, soy TuTurno. ¿En qué te puedo ayudar?';

/// Agente de voz falso: el test decide qué dice, si habla, si conecta y si se corta.
class FakeAgenteVoz implements AgenteVoz {
  final _estado = ValueNotifier(EstadoAgente.desconectado);
  final _hablando = ValueNotifier(false);
  final _mensajes = StreamController<MensajeAgente>.broadcast();
  final _errores = StreamController<String>.broadcast();

  /// Las variables de cada sesión que se ha abierto.
  final sesiones = <Map<String, String>>[];
  final enviados = <String>[];
  var actividades = 0;
  var terminados = 0;

  /// Si no es null, iniciar() lo lanza (por ejemplo, un ErrorAgente).
  Object? fallarAlIniciar;

  /// Si no es null, iniciar() espera a que se complete.
  Completer<void>? bloquearInicio;

  /// Al conectar, dice el saludo fijo (como el agente de verdad).
  var saludarAlConectar = true;

  @override
  ValueListenable<EstadoAgente> get estado => _estado;

  @override
  ValueListenable<bool> get hablando => _hablando;

  @override
  Stream<MensajeAgente> get mensajes => _mensajes.stream;

  @override
  Stream<String> get errores => _errores.stream;

  @override
  Future<void> iniciar({required Map<String, String> variables}) async {
    sesiones.add(Map.of(variables));
    _estado.value = EstadoAgente.conectando;
    await bloquearInicio?.future;
    final fallo = fallarAlIniciar;
    if (fallo != null) {
      _estado.value = EstadoAgente.desconectado;
      throw fallo;
    }
    _estado.value = EstadoAgente.conectado;
    if (saludarAlConectar) decir(saludoAgente);
  }

  /// El agente dice [texto] (evento agent_response).
  void decir(String texto) => _mensajes.add(MensajeAgente(texto: texto, deAgente: true));

  /// Se ha interrumpido al agente: de [original] solo llegó a decir [dicho].
  void corregir(String original, String dicho) =>
      _mensajes.add(MensajeAgente(texto: dicho, deAgente: true, corrigeA: original));

  void ponerHablando(bool valor) => _hablando.value = valor;

  /// Se corta la sesión sin pedirlo (red o el agente cuelga).
  void cortar() {
    _hablando.value = false;
    _estado.value = EstadoAgente.desconectado;
  }

  void avisarError(String texto) => _errores.add(texto);

  @override
  void enviarTexto(String texto) => enviados.add(texto);

  @override
  void avisarQueEscribe() => actividades++;

  @override
  Future<void> terminar() async {
    terminados++;
    _hablando.value = false;
    _estado.value = EstadoAgente.desconectado;
  }

  @override
  void dispose() {}
}
