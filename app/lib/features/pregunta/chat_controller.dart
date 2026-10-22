import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/agente/respuesta_agente.dart' show telefonosEn;
import '../../core/api/tuturno_api.dart';
import '../../core/demo.dart' show usarEjemploPreguntaProvider;
import '../../core/entrada.dart' show entradaProvider;
import '../../core/providers.dart';
import '../../core/seguridad.dart';
import '../../core/texto.dart';
import '../../core/voz/stt.dart';
import '../../core/voz/tts.dart';
import 'ejemplos.dart';

// Estado del chat de «Pregunta». Solo vive en memoria: la app no lo guarda en el dispositivo ni lo escribe en los
// logs, y desaparece al salir de la pantalla.
//
// Las respuestas salen, por orden, del agente de voz (modo agente, agente/chat_agente.dart), del modo texto real
// (`apiProvider.ask`: POST /api/agent/ask con el perfil) y, si no responde nadie y se pide, de los ejemplos
// (ejemplos.dart), siempre marcados como ejemplo.

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
    this.ejemplo = false,
    this.telefonos = const [],
    this.ayudaImagenes = false,
  });

  factory MensajeChat.usuario(int id, String texto) => MensajeChat._(id: id, autor: Autor.usuario, texto: texto);

  factory MensajeChat.asistente(
    int id,
    AskResponse respuesta, {
    bool ejemplo = false,
    List<String> telefonos = const [],
    bool ayudaImagenes = false,
  }) => MensajeChat._(
    id: id,
    autor: Autor.asistente,
    texto: respuesta.respuesta,
    respuesta: respuesta,
    ejemplo: ejemplo,
    telefonos: telefonos,
    ayudaImagenes: ayudaImagenes,
  );

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

  /// Respuesta de ejemplo (ejemplos.dart) porque no responde nadie. Siempre se marca como ejemplo.
  final bool ejemplo;

  /// Teléfonos de la respuesta, en cifras y en orden, para enseñarlos como botones (agente/telefonos.dart).
  final List<String> telefonos;

  /// Respuesta de «hechos» a un mensaje que hablaba de fotos, vídeos o imágenes (regla local: no se envía nada). Además
  /// del aviso, el 017 (en [telefonos]) y «Quitar fotos o vídeos de internet» (Canal prioritario de la AEPD).
  final bool ayudaImagenes;

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
    this.agenteHablando = false,
    this.ejemplos = false,
    this.esperandoVoz = false,
    this.conectandoVoz = false,
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

  /// Modo agente: el agente de voz está hablando. Mientras, no se escucha con el micrófono.
  final bool agenteHablando;

  /// Las respuestas salen de los ejemplos (no responde nadie, o se ha forzado en el modo demo). Se queda así hasta
  /// «Volver a TuTurno».
  final bool ejemplos;

  /// Modo agente: la pregunta está esperando la respuesta del agente de voz (a los 8 s se ofrece contestar por escrito).
  final bool esperandoVoz;

  /// Modo agente: se está abriendo la sesión con el agente. Mientras, el micrófono espera: el saludo cortaría el dictado.
  final bool conectandoVoz;

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
    bool? agenteHablando,
    bool? ejemplos,
    bool? esperandoVoz,
    bool? conectandoVoz,
  }) => EstadoChat(
    mensajes: mensajes ?? this.mensajes,
    esperando: esperando ?? this.esperando,
    situacion: situacion != null ? situacion() : this.situacion,
    voz: voz ?? this.voz,
    dictado: dictado ?? this.dictado,
    nivelVoz: nivelVoz ?? this.nivelVoz,
    problemaVoz: problemaVoz != null ? problemaVoz() : this.problemaVoz,
    hablandoId: hablandoId != null ? hablandoId() : this.hablandoId,
    agenteHablando: agenteHablando ?? this.agenteHablando,
    ejemplos: ejemplos ?? this.ejemplos,
    esperandoVoz: esperandoVoz ?? this.esperandoVoz,
    conectandoVoz: conectandoVoz ?? this.conectandoVoz,
  );
}

/// Los teléfonos de [texto], sin mirar dentro de las referencias a fuentes: [A-017] o [ML-INCIBE-017] no son el 017.
List<String> telefonosDeRespuesta(String texto) => telefonosEn(texto.replaceAll(_referenciaFuente, ' '));

/// Como las referencias que numera widgets/texto_con_terminos.dart: [A-017], [ML-LO5-16.2], [A-017, ML-CE-24.2]…
final _referenciaFuente = RegExp(r'\[[A-Za-z]{1,4}-[\w.-]+(?:\s*[,;]\s*[A-Za-z]{1,4}-[\w.-]+)*\]');

/// true si [texto] habla de fotos, vídeos o imágenes (sin que importen tildes ni mayúsculas). Es una regla local: lo
/// que escribe el usuario no sale del móvil por esto.
bool hablaDeImagenes(String texto) => _imagenes.hasMatch(normalizar(texto));

final _imagenes = RegExp(r'\b(fotos?|fotografias?|videos?|imagen|imagenes)\b');

/// Las fuentes de la ayuda para fotos y vídeos (docs/MARCO_LEGAL.md, «INCIBE · 017» y «AEPD · Canal prioritario»).
const fuentesAyudaImagenes = [
  Fuente(
    id: 'ML-INCIBE-017',
    titulo: 'El 017, ayuda con problemas en internet',
    norma: 'INCIBE · 017',
    articulo: '',
    url: 'https://www.incibe.es/linea-de-ayuda-en-ciberseguridad',
  ),
  Fuente(
    id: 'ML-AEPD-CP',
    titulo: 'Canal prioritario de la Agencia Española de Protección de Datos',
    norma: 'AEPD · Canal prioritario',
    articulo: '',
    url: 'https://www.aepd.es/canalprioritario',
  ),
];

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
    // «Usar siempre el ejemplo en Pregunta» (modo demo, lib/core/demo.dart): si la red del recinto va mal.
    return EstadoChat(situacion: situacionInicial, ejemplos: ref.read(usarEjemploPreguntaProvider));
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
    await preguntar(pregunta, historial, vozAutomatica: vozAutomatica);
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
    await preguntar(
      error.preguntaOriginal!,
      error.historialOriginal,
      vozAutomatica: vozAutomatica && error.vozAutomaticaOriginal,
    );
  }

  /// Pide la respuesta de [pregunta] (ya está en la conversación y [EstadoChat.esperando] es true) y la añade: al
  /// modo texto real (`apiProvider.ask`, con el perfil) o, con [EstadoChat.ejemplos], a los ejemplos. El modo agente lo
  /// sobrescribe para preguntar antes al agente de voz.
  @protected
  Future<void> preguntar(String pregunta, List<Mensaje> historial, {required bool vozAutomatica}) async {
    if (state.ejemplos) return responderConEjemplo(pregunta, historial);
    final conversacion = _conversacion;
    final peticion = peticionPara(pregunta, historial);
    MensajeChat mensaje;
    try {
      mensaje = mensajeAsistente(await ref.read(apiProvider).ask(peticion), pregunta: pregunta);
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

  /// La petición de [pregunta] para el modo texto, con el papel de «Mi situación» y el perfil de la hoja (las mismas
  /// variables que la sesión de voz).
  @protected
  AskRequest peticionPara(String pregunta, List<Mensaje> historial) {
    final situacion = state.situacion;
    return AskRequest(
      pregunta: pregunta,
      modo: situacion == null ? ModoPregunta.libre : ModoPregunta.situacion,
      situacion: situacion,
      historial: historial,
      perfil: ref.read(entradaProvider).variablesAgente(situacion: situacion),
    );
  }

  /// Una respuesta (del modo texto, del agente o de ejemplo) lista para la conversación:
  /// - red de seguridad (sección 10.2): si [pregunta] suena a peligro, la tarjeta de Ayuda sale siempre (tipo crisis);
  /// - los teléfonos del texto, para enseñarlos como botones ([telefonos] si ya vienen calculados);
  /// - «hechos» sobre fotos, vídeos o imágenes: además, el 017 y el Canal prioritario de la AEPD, con sus fuentes.
  @protected
  MensajeChat mensajeAsistente(
    AskResponse respuesta, {
    required String? pregunta,
    bool ejemplo = false,
    List<String>? telefonos,
  }) {
    var r = respuesta;
    if (pregunta != null && r.tipo != TipoRespuesta.crisis && pareceCrisis(pregunta)) {
      r = r.copyWith(tipo: TipoRespuesta.crisis);
    }
    final lista = [...(telefonos ?? telefonosDeRespuesta(r.respuesta))];
    final imagenes = r.tipo == TipoRespuesta.hechos && pregunta != null && hablaDeImagenes(pregunta);
    if (imagenes) {
      if (!lista.contains('017')) lista.add('017');
      r = r.copyWith(
        fuentes: [
          ...r.fuentes,
          for (final f in fuentesAyudaImagenes)
            if (!r.fuentes.any((otra) => otra.id == f.id)) f,
        ],
      );
    }
    return MensajeChat.asistente(_nuevoId(), r, ejemplo: ejemplo, telefonos: lista, ayudaImagenes: imagenes);
  }

  /// Contesta [pregunta] con un ejemplo (ejemplos.dart), marcado como ejemplo.
  @protected
  Future<void> responderConEjemplo(String pregunta, List<Mensaje> historial) async {
    final conversacion = _conversacion;
    MensajeChat mensaje;
    try {
      final respuesta = await ref.read(respuestasEjemploProvider).ask(peticionPara(pregunta, historial));
      mensaje = mensajeAsistente(respuesta, pregunta: pregunta, ejemplo: true);
    } catch (_) {
      mensaje = MensajeChat.error(_nuevoId(), ApiException.mensajeSeguro, pregunta: pregunta, historial: historial);
    }
    if (!ref.mounted || conversacion != _conversacion) return;
    state = state.copyWith(mensajes: [...state.mensajes, mensaje], esperando: false);
  }

  /// «Ver una respuesta de ejemplo» (no responde nadie): desde ahora se contesta con ejemplos, marcados como ejemplo,
  /// hasta «Volver a TuTurno». La pregunta que se quedó sin respuesta se contesta ya.
  Future<void> usarEjemplos() async {
    if (!ref.mounted || state.esperando) return;
    state = state.copyWith(ejemplos: true);
    await alPasarAEjemplos();
    if (!ref.mounted) return;
    final ultimo = state.mensajes.lastOrNull;
    final pregunta = ultimo?.preguntaOriginal;
    if (ultimo == null || !ultimo.esError || pregunta == null) return;
    state = state.copyWith(
      mensajes: [
        for (final m in state.mensajes)
          if (m.id != ultimo.id) m,
      ],
      esperando: true,
    );
    await responderConEjemplo(pregunta, ultimo.historialOriginal);
  }

  /// El modo agente cierra aquí la sesión con el agente de voz.
  @protected
  Future<void> alPasarAEjemplos() async {}

  /// «Volver a TuTurno»: deja los ejemplos; la siguiente pregunta va otra vez al asistente.
  void volverATuTurno() {
    if (state.ejemplos) state = state.copyWith(ejemplos: false);
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

  /// Empieza de cero: la conversación desaparece de la pantalla (la app no la guarda en ningún sitio). Si se estaba
  /// con los ejemplos, se sigue con ellos.
  void borrar() {
    _conversacion++;
    _sesionVoz++;
    unawaited(_tts.parar());
    unawaited(_stt.cancelar());
    state = EstadoChat(situacion: state.situacion, ejemplos: state.ejemplos);
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

  /// true en el modo agente (features/pregunta/agente/chat_agente.dart): hay agente de voz, aunque ahora se conteste
  /// por escrito.
  bool get conAgente => false;

  /// Mientras se escribe o se dicta. Solo lo usa el modo agente, para que el agente no interrumpa.
  void avisarQueEscribe() {}

  /// La pantalla ya está lista (después de la hoja del perfil, si ha salido). El modo agente abre aquí la sesión de
  /// voz, salvo con «Sin voz» o con lector de pantalla ([lectorDePantalla]).
  void empezar({required bool lectorDePantalla}) {}

  /// Se ha activado o desactivado el lector de pantalla (TalkBack): con él, el modo agente contesta por escrito.
  void ponerLectorDePantalla(bool activo) {}

  /// La app pasa a segundo plano. El modo agente cierra la sesión de voz.
  void pausar() {}

  /// Ha cambiado el perfil de la hoja. En el modo texto viaja ya en la siguiente pregunta; el modo agente abre otra
  /// sesión, porque las variables solo se leen al abrirla.
  Future<void> cambiarPerfil() async {}

  bool _vigente(int sesion) => ref.mounted && sesion == _sesionVoz;

  /// Para los mensajes que añade el modo agente.
  @protected
  int nuevoId() => _nuevoId();

  int _nuevoId() => _siguienteId++;

  MensajeChat? _buscar(int id) {
    for (final m in state.mensajes) {
      if (m.id == id) return m;
    }
    return null;
  }
}
