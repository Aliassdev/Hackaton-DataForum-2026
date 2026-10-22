import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/tuturno_api.dart';
import '../../core/providers.dart';
import '../../core/voz/stt.dart';
import '../../core/voz/tts.dart';

// Estado del chat de «Pregunta». Solo vive en memoria: no se guarda en el dispositivo ni se escribe en los
// logs, y se borra al salir de la pantalla.

/// Micrófono.
enum EstadoVoz { inactivo, preparando, escuchando }

/// Un mensaje del chat: del usuario, del asistente o un error con «Reintentar».
@immutable
class MensajeChat {
  const MensajeChat._({
    required this.id,
    required this.autor,
    required this.texto,
    this.respuesta,
    this.esError = false,
    this.preguntaOriginal,
    this.historialOriginal = const [],
    this.vozAutomaticaOriginal = false,
  });

  factory MensajeChat.usuario(int id, String texto) => MensajeChat._(id: id, autor: Autor.usuario, texto: texto);

  factory MensajeChat.asistente(int id, AskResponse respuesta) =>
      MensajeChat._(id: id, autor: Autor.asistente, texto: respuesta.respuesta, respuesta: respuesta);

  factory MensajeChat.error(
    int id,
    String mensaje, {
    required String pregunta,
    required List<Mensaje> historial,
    bool vozAutomatica = false,
  }) => MensajeChat._(
    id: id,
    autor: Autor.asistente,
    texto: mensaje,
    esError: true,
    preguntaOriginal: pregunta,
    historialOriginal: historial,
    vozAutomaticaOriginal: vozAutomatica,
  );

  final int id;
  final Autor autor;
  final String texto;

  /// Solo en las respuestas del asistente.
  final AskResponse? respuesta;

  /// Error de la API: [texto] es su mensaje y se puede repetir la pregunta.
  final bool esError;
  final String? preguntaOriginal;
  final List<Mensaje> historialOriginal;

  /// Si la respuesta de la pregunta original se iba a leer sola (se preguntó con la voz).
  final bool vozAutomaticaOriginal;

  bool get esUsuario => autor == Autor.usuario;

  TipoRespuesta get tipo => respuesta?.tipo ?? TipoRespuesta.normal;
}

@immutable
class EstadoChat {
  const EstadoChat({
    this.mensajes = const [],
    this.esperando = false,
    this.situacion,
    this.voz = EstadoVoz.inactivo,
    this.dictado = '',
    this.nivelVoz = 0,
    this.problemaVoz,
    this.hablandoId,
  });

  final List<MensajeChat> mensajes;

  /// Hay una pregunta enviada sin respuesta todavía.
  final bool esperando;

  /// «Mi situación»: si no es nula, se pregunta en modo situacion con este papel.
  final RolProceso? situacion;

  final EstadoVoz voz;

  /// Transcripción en vivo de la última vez que se usó el micrófono.
  final String dictado;

  /// Volumen del micrófono entre 0 y 1.
  final double nivelVoz;

  /// Último problema con el micrófono, para avisar con un mensaje amable.
  final ProblemaVoz? problemaVoz;

  /// Mensaje que se está leyendo en voz alta.
  final int? hablandoId;

  bool get escuchando => voz != EstadoVoz.inactivo;

  EstadoChat copyWith({
    List<MensajeChat>? mensajes,
    bool? esperando,
    RolProceso? Function()? situacion,
    EstadoVoz? voz,
    String? dictado,
    double? nivelVoz,
    ProblemaVoz? Function()? problemaVoz,
    int? Function()? hablandoId,
  }) => EstadoChat(
    mensajes: mensajes ?? this.mensajes,
    esperando: esperando ?? this.esperando,
    situacion: situacion != null ? situacion() : this.situacion,
    voz: voz ?? this.voz,
    dictado: dictado ?? this.dictado,
    nivelVoz: nivelVoz ?? this.nivelVoz,
    problemaVoz: problemaVoz != null ? problemaVoz() : this.problemaVoz,
    hablandoId: hablandoId != null ? hablandoId() : this.hablandoId,
  );
}

/// Un chat por cada forma de entrar: `/pregunta` (null) o `/pregunta?situacion=testigo`.
/// Se borra al salir de la pantalla.
final chatProvider = NotifierProvider.autoDispose.family<ChatNotifier, EstadoChat, RolProceso?>(ChatNotifier.new);

class ChatNotifier extends Notifier<EstadoChat> {
  ChatNotifier(this.situacionInicial);

  final RolProceso? situacionInicial;

  late Stt _stt;
  late Tts _tts;
  var _siguienteId = 0;

  /// Cambia al empezar o cancelar una escucha: lo que llegue de una escucha anterior se ignora.
  var _sesionVoz = 0;

  /// Cambia al borrar la conversación: las respuestas que lleguen tarde se ignoran.
  var _conversacion = 0;

  @override
  EstadoChat build() {
    final stt = _stt = ref.read(sttProvider);
    final tts = _tts = ref.read(ttsProvider);
    ref.onDispose(() {
      _sesionVoz++;
      _conversacion++;
      unawaited(tts.parar());
      unawaited(stt.cancelar());
    });
    // «Sin voz» (aquí o en Ajustes) también calla lo que se esté leyendo.
    ref.listen(ajustesProvider.select((a) => a.vozActivada), (_, activada) {
      if (!activada && state.hablandoId != null) unawaited(callar());
    });
    return EstadoChat(situacion: situacionInicial);
  }

  /// Envía una pregunta. Si [vozAutomatica] y la voz está activada en Ajustes, la respuesta se lee en voz alta.
  /// La pantalla solo lo pide si la pregunta se hizo con la voz: lo escrito en silencio no se contesta en alto.
  Future<void> enviar(String texto, {bool vozAutomatica = true}) async {
    final pregunta = texto.trim();
    if (pregunta.isEmpty || state.esperando) return;
    if (state.escuchando) unawaited(_stt.cancelar());
    _sesionVoz++;
    unawaited(_tts.parar());
    final historial = historialPara(state.mensajes);
    state = state.copyWith(
      mensajes: [...state.mensajes, MensajeChat.usuario(_nuevoId(), pregunta)],
      esperando: true,
      voz: EstadoVoz.inactivo,
      dictado: '',
      nivelVoz: 0,
      problemaVoz: () => null,
      hablandoId: () => null,
    );
    await _preguntar(pregunta, historial, vozAutomatica: vozAutomatica);
  }

  /// Repite la pregunta de un mensaje de error. Se lee sola solo si la original se iba a leer.
  Future<void> reintentar(int idError, {bool vozAutomatica = true}) async {
    final error = _buscar(idError);
    if (error == null || !error.esError || state.esperando) return;
    state = state.copyWith(
      mensajes: [
        for (final m in state.mensajes)
          if (m.id != idError) m,
      ],
      esperando: true,
    );
    await _preguntar(
      error.preguntaOriginal!,
      error.historialOriginal,
      vozAutomatica: vozAutomatica && error.vozAutomaticaOriginal,
    );
  }

  Future<void> _preguntar(String pregunta, List<Mensaje> historial, {required bool vozAutomatica}) async {
    final conversacion = _conversacion;
    final situacion = state.situacion;
    final peticion = AskRequest(
      pregunta: pregunta,
      modo: situacion == null ? ModoPregunta.libre : ModoPregunta.situacion,
      situacion: situacion,
      historial: historial,
    );
    MensajeChat mensaje;
    try {
      mensaje = MensajeChat.asistente(_nuevoId(), await ref.read(apiProvider).ask(peticion));
    } on ApiException catch (e) {
      mensaje = MensajeChat.error(
        _nuevoId(),
        e.mensaje,
        pregunta: pregunta,
        historial: historial,
        vozAutomatica: vozAutomatica,
      );
    } catch (_) {
      mensaje = MensajeChat.error(
        _nuevoId(),
        ApiException.mensajeSeguro,
        pregunta: pregunta,
        historial: historial,
        vozAutomatica: vozAutomatica,
      );
    }
    if (!ref.mounted || conversacion != _conversacion) return;
    state = state.copyWith(mensajes: [...state.mensajes, mensaje], esperando: false);
    if (!mensaje.esError && vozAutomatica && ref.read(ajustesProvider).vozActivada) {
      await leer(mensaje.id);
    }
  }

  /// Lee en voz alta una respuesta (texto completo, sin las referencias a fuentes).
  Future<void> leer(int id) async {
    final mensaje = _buscar(id);
    if (mensaje == null || mensaje.esUsuario || mensaje.esError || state.escuchando) return;
    state = state.copyWith(hablandoId: () => id);
    try {
      await _tts.hablar(textoParaVoz(mensaje.texto), velocidad: ref.read(ajustesProvider).velocidadVoz);
    } catch (_) {
      // Sin voz: el texto sigue en pantalla.
    }
    if (ref.mounted && state.hablandoId == id) state = state.copyWith(hablandoId: () => null);
  }

  /// Botón del altavoz de un mensaje: lo lee o, si ya se está leyendo, lo para.
  Future<void> alternarLectura(int id) => state.hablandoId == id ? callar() : leer(id);

  Future<void> callar() async {
    state = state.copyWith(hablandoId: () => null);
    await _tts.parar();
  }

  /// Botón del micrófono: pulsar para hablar y pulsar para parar.
  Future<void> alternarMicro() => state.escuchando ? pararEscucha() : empezarEscucha();

  Future<void> empezarEscucha() async {
    if (state.esperando || state.escuchando) return;
    final sesion = ++_sesionVoz;
    state = state.copyWith(
      voz: EstadoVoz.preparando,
      dictado: '',
      nivelVoz: 0,
      problemaVoz: () => null,
      hablandoId: () => null,
    );
    // Nunca se escucha mientras se lee en voz alta: el micrófono oiría la respuesta.
    await _tts.parar();
    if (!_vigente(sesion)) return;
    bool disponible;
    try {
      disponible = await _stt.inicializar();
    } catch (_) {
      disponible = false;
    }
    if (!_vigente(sesion)) return;
    if (!disponible) {
      state = state.copyWith(voz: EstadoVoz.inactivo, problemaVoz: () => ProblemaVoz.sinPermiso);
      return;
    }
    state = state.copyWith(voz: EstadoVoz.escuchando);
    try {
      await _escuchar(sesion);
    } catch (_) {
      if (_vigente(sesion)) {
        state = state.copyWith(voz: EstadoVoz.inactivo, nivelVoz: 0, problemaVoz: () => ProblemaVoz.otro);
      }
    }
  }

  Future<void> _escuchar(int sesion) {
    return _stt.escuchar(
      onTexto: (texto) {
        if (_vigente(sesion)) state = state.copyWith(dictado: texto);
      },
      onNivel: (nivel) {
        if (_vigente(sesion) && state.voz == EstadoVoz.escuchando && (nivel - state.nivelVoz).abs() >= 0.05) {
          state = state.copyWith(nivelVoz: nivel);
        }
      },
      onFin: () {
        if (_vigente(sesion) && state.escuchando) state = state.copyWith(voz: EstadoVoz.inactivo, nivelVoz: 0);
      },
      onProblema: (problema) {
        if (!_vigente(sesion)) return;
        // Si ya se ha entendido algo, lo entendido vale: algunos móviles mandan un error (sin coincidencias,
        // error de cliente…) después de un buen resultado. Solo se avisa siempre de que falta el permiso.
        final ignorar = problema != ProblemaVoz.sinPermiso && state.dictado.trim().isNotEmpty;
        state = state.copyWith(voz: EstadoVoz.inactivo, nivelVoz: 0, problemaVoz: ignorar ? null : () => problema);
      },
    );
  }

  Future<void> pararEscucha() async {
    if (!state.escuchando) return;
    if (state.voz == EstadoVoz.preparando) _sesionVoz++;
    state = state.copyWith(voz: EstadoVoz.inactivo, nivelVoz: 0);
    await _stt.parar();
  }

  void cerrarAvisoVoz() => state = state.copyWith(problemaVoz: () => null);

  /// Quita «Mi situación»: a partir de ahora se pregunta en modo libre.
  void quitarSituacion() => state = state.copyWith(situacion: () => null);

  /// Empieza de cero. No queda nada guardado.
  void borrar() {
    _conversacion++;
    _sesionVoz++;
    unawaited(_tts.parar());
    unawaited(_stt.cancelar());
    state = EstadoChat(situacion: state.situacion);
  }

  /// Los últimos turnos que se envían como contexto (sin errores ni preguntas que no tuvieron respuesta).
  ///
  /// Lo que el backend marcó como crisis o hechos personales no se vuelve a enviar: el relato no debe llegar
  /// al modelo de lenguaje en las preguntas siguientes. La plantilla del asistente sí, para no perder el hilo.
  static List<Mensaje> historialPara(List<MensajeChat> mensajes) {
    final turnos = <Mensaje>[];
    for (var i = 0; i < mensajes.length; i++) {
      final m = mensajes[i];
      if (m.esError) continue;
      if (m.esUsuario) {
        final siguiente = i + 1 < mensajes.length ? mensajes[i + 1] : null;
        if (siguiente == null || siguiente.esError || siguiente.esUsuario) continue;
        if (siguiente.tipo == TipoRespuesta.crisis || siguiente.tipo == TipoRespuesta.hechos) continue;
      }
      turnos.add(Mensaje(autor: m.autor, texto: m.texto));
    }
    return turnos.length <= AskRequest.maxHistorial ? turnos : turnos.sublist(turnos.length - AskRequest.maxHistorial);
  }

  bool _vigente(int sesion) => ref.mounted && sesion == _sesionVoz;

  int _nuevoId() => _siguienteId++;

  MensajeChat? _buscar(int id) {
    for (final m in state.mensajes) {
      if (m.id == id) return m;
    }
    return null;
  }
}
