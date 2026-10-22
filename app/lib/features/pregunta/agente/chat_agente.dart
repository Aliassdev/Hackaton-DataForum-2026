import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agente/agente_provider.dart';
import '../../../core/agente/agente_voz.dart';
import '../../../core/agente/elevenlabs_agente_voz.dart';
import '../../../core/agente/respuesta_agente.dart';
import '../../../core/api/mock_api.dart';
import '../../../core/api/tuturno_api.dart';
import '../../../core/entrada.dart';
import '../../../core/providers.dart';
import '../../../core/seguridad.dart';
import '../../../core/texto.dart';
import '../../../core/voz/stt.dart';
import '../chat_controller.dart';
import 'textos_agente.dart';

// «Pregunta» en modo agente (docs/ARQUITECTURA.md, sección 5.0, fase 1): las preguntas van al agente de voz de
// ElevenLabs, que contesta con su voz y con texto. Es el mismo chat que el modo texto (ChatNotifier): solo cambia de
// dónde sale la respuesta. El micrófono de la sesión va siempre silenciado; la voz del menor se transcribe en el móvil
// (sttProvider) y se envía como texto.
//
// - La sesión se abre al entrar (después de la hoja del perfil, agente/capa_agente.dart), se cierra al salir y al pasar
//   a segundo plano, y se vuelve a abrir al preguntar.
// - El primer mensaje de cada sesión es el saludo fijo del agente: no es una respuesta y no entra en el chat (se enseña
//   arriba).
// - Si en 30 s no llega respuesta (el backend o su túnel están caídos: ElevenLabs no avisa), «TuTurno no responde
//   ahora mismo», con «Reintentar» y la opción de ver respuestas de ejemplo (la API simulada), marcadas como ejemplo.
// - Lo que se enseña pasa por core/agente/respuesta_agente.dart: sin etiquetas de voz, teléfonos en cifras y las
//   plantillas fijas del backend reconocidas (crisis → tarjeta de ayuda; hechos → derivación; fuera de ámbito →
//   sugerencias; respuesta segura → «Reintentar»).

/// Un chat por cada forma de entrar, como [chatProvider], pero con el agente de voz. Crea un [ChatAgenteNotifier].
final chatAgenteProvider = NotifierProvider.autoDispose.family<ChatNotifier, EstadoChat, RolProceso?>(
  ChatAgenteNotifier.new,
);

/// Respuestas de ejemplo cuando el agente no responde: la API simulada (sección 9.7). Nunca se presentan como reales.
final respuestasEjemploProvider = Provider<TuTurnoApi>((ref) => MockTuTurnoApi());

/// En qué punto está la conversación con el agente.
enum FaseAgente {
  /// Todavía no se ha intentado abrir (por ejemplo, con la hoja del perfil abierta).
  preparando,
  conectando,
  conectado,

  /// No se ha podido conectar o se ha cortado. [SesionAgente.aviso] dice por qué.
  sinConexion,

  /// La app ha pasado a segundo plano y se ha cerrado la sesión. Se vuelve a abrir al preguntar.
  pausado,

  /// Se ha elegido ver respuestas de ejemplo: no hay sesión con el agente.
  ejemplo,
}

/// Lo que enseña la banda de estado de arriba (agente/banda_agente.dart).
@immutable
class SesionAgente {
  const SesionAgente({
    this.fase = FaseAgente.preparando,
    this.saludo,
    this.antesDePreguntar = const [],
    this.aviso,
    this.sinRespuesta = false,
    this.conversacionNueva = false,
  });

  final FaseAgente fase;

  /// El saludo del agente en esta sesión, ya limpio. Se oye y se enseña arriba, no como mensaje del chat.
  final String? saludo;

  /// Lo que el agente ha dicho por su cuenta antes de la primera pregunta (por ejemplo, si toma la palabra tras un
  /// silencio). Se enseña debajo del saludo, en la vista inicial, para que se pueda leer sin tapar los ejemplos.
  final List<String> antesDePreguntar;

  /// Por qué no hay conexión, para el usuario.
  final String? aviso;

  /// La última pregunta se quedó sin respuesta.
  final bool sinRespuesta;

  /// Se ha vuelto a conectar a mitad de una conversación: el agente no recuerda lo anterior.
  final bool conversacionNueva;

  SesionAgente copyWith({
    FaseAgente? fase,
    String? Function()? saludo,
    List<String>? antesDePreguntar,
    String? Function()? aviso,
    bool? sinRespuesta,
    bool? conversacionNueva,
  }) => SesionAgente(
    fase: fase ?? this.fase,
    saludo: saludo != null ? saludo() : this.saludo,
    antesDePreguntar: antesDePreguntar ?? this.antesDePreguntar,
    aviso: aviso != null ? aviso() : this.aviso,
    sinRespuesta: sinRespuesta ?? this.sinRespuesta,
    conversacionNueva: conversacionNueva ?? this.conversacionNueva,
  );
}

class ChatAgenteNotifier extends ChatNotifier {
  ChatAgenteNotifier(super.situacionInicial);

  /// Lo que se espera a la respuesta del agente antes de decir que no responde.
  static const tiempoRespuesta = Duration(seconds: 30);

  /// Lo que se espera a que se abra la sesión.
  static const tiempoConexion = Duration(seconds: 20);

  /// En una sesión recién abierta, lo que se espera al saludo antes de enviar la pregunta.
  static const esperaSaludo = Duration(seconds: 3);

  /// Si falla la conexión, se vuelve a intentar una vez tras esta pausa.
  static const pausaReintento = Duration(milliseconds: 1500);

  // No se libera con ref.onDispose: este notifier no vigila ningún proveedor (build no se repite) y los widgets que lo
  // escuchan se quitan solos al desmontarse.
  final _sesion = ValueNotifier(const SesionAgente());

  /// Estado de la conversación con el agente, para la banda de arriba y la vista inicial.
  ValueListenable<SesionAgente> get sesion => _sesion;

  late Stt _sttAgente;
  AgenteVoz? _agente;
  Future<bool>? _abriendo;

  /// Sube con cada sesión que se abre o se cierra: lo que llegue de una anterior se ignora.
  var _generacion = 0;

  /// Sube al borrar la conversación: las respuestas que lleguen tarde se ignoran.
  var _conversacion = 0;
  var _cerrado = false;

  /// El saludo de la sesión actual todavía no ha llegado.
  var _saludoPendiente = false;
  Completer<void>? _saludo;

  /// Ya se ha enviado algo en la sesión actual.
  var _enviadoEnSesion = false;
  Map<String, String> _variablesDeSesion = const {};

  /// La pregunta enviada que espera respuesta: se completa con el mensaje del agente, o con null si se corta.
  Completer<MensajeAgente?>? _espera;
  String? _errorEspera;

  /// Texto tal como llegó de cada respuesta del agente que está en el chat: para aplicar las correcciones.
  final _originales = <int, String>{};

  /// El aviso de «no responde» que se sustituye si la respuesta llega tarde.
  int? _idSinRespuesta;

  /// Android puede no dejarle el micrófono al dictado mientras la sesión de WebRTC lo tiene (aunque esté silenciado).
  /// Si un dictado con la sesión abierta acaba sin entender nada, desde entonces se cierra la sesión antes de dictar y
  /// se vuelve a abrir al preguntar (el agente empieza otra conversación, pero la voz funciona).
  var _cerrarSesionParaDictar = false;
  var _dictandoConSesion = false;

  @override
  bool get conAgente => true;

  @override
  EstadoChat build() {
    final estado = super.build();
    _sttAgente = ref.read(sttProvider);
    // ref.listen (y no watch): mantiene vivo el agente sin que build se repita y se pierda la conversación.
    final agente = _agente = ref.listen<AgenteVoz?>(agenteVozProvider, (_, _) {}).read();
    final subMensajes = agente?.mensajes.listen(_alMensaje);
    final subErrores = agente?.errores.listen(_alError);
    agente?.estado.addListener(_alCambiarEstado);
    agente?.hablando.addListener(_alCambiarHablando);
    // Para subrayar en las respuestas los términos del glosario.
    ref.read(glosarioProvider);
    listenSelf((anterior, actual) {
      if (anterior == null || !anterior.escuchando || actual.escuchando) return;
      // Acaba un dictado: ¿sin entender nada y con la sesión abierta?
      final sinNada =
          actual.dictado.trim().isEmpty &&
          const {ProblemaVoz.noTeOigo, ProblemaVoz.ocupado, ProblemaVoz.otro}.contains(actual.problemaVoz);
      if (sinNada && _dictandoConSesion) _cerrarSesionParaDictar = true;
      _dictandoConSesion = false;
    });
    ref.onDispose(() {
      _cerrado = true;
      _generacion++;
      _completarEspera(null);
      unawaited(subMensajes?.cancel());
      unawaited(subErrores?.cancel());
      agente?.estado.removeListener(_alCambiarEstado);
      agente?.hablando.removeListener(_alCambiarHablando);
      if (agente != null) unawaited(agente.terminar());
    });
    return estado;
  }

  /// Abre la sesión con el agente si no está abierta. Devuelve false si no se ha podido. La llama la pantalla al
  /// entrar (después de la hoja del perfil), el botón «Conectar» y [preguntar] cuando hace falta.
  Future<bool> abrirSesion() {
    if (_cerrado || _sesion.value.fase == FaseAgente.ejemplo) return Future.value(false);
    final agente = _agente;
    if (agente == null) {
      _ponerSesion(fase: FaseAgente.sinConexion, aviso: TextosAgente.sinConfigurar);
      return Future.value(false);
    }
    if (agente.estado.value == EstadoAgente.conectado && _sesion.value.fase == FaseAgente.conectado) {
      return Future.value(true);
    }
    final enCurso = _abriendo;
    if (enCurso != null) return enCurso;
    final futuro = _abrir(agente);
    _abriendo = futuro;
    return futuro.whenComplete(() {
      if (identical(_abriendo, futuro)) _abriendo = null;
    });
  }

  Future<bool> _abrir(AgenteVoz agente) async {
    final generacion = ++_generacion;
    final aMitad = state.mensajes.isNotEmpty;
    _saludoPendiente = true;
    _saludo = Completer<void>();
    _enviadoEnSesion = false;
    _ponerSesion(
      fase: FaseAgente.conectando,
      saludo: null,
      antesDePreguntar: const [],
      aviso: null,
      conversacionNueva: false,
    );
    final variables = _variablesActuales();
    for (var intento = 0; ; intento++) {
      String mensaje;
      var reintentable = true;
      try {
        await agente.iniciar(variables: variables).timeout(tiempoConexion);
        if (!_vigente(generacion)) return false;
        if (agente.estado.value != EstadoAgente.conectado) throw const ErrorAgente(TextosAgente.sinConexion);
        _variablesDeSesion = variables;
        _ponerSesion(fase: FaseAgente.conectado, conversacionNueva: aMitad);
        return true;
      } on ErrorAgente catch (e) {
        mensaje = e.mensaje;
        reintentable = e.mensaje == TextosAgente.sinConexion;
      } on TimeoutException {
        unawaited(agente.terminar());
        mensaje = TextosAgente.sinConexion;
      } catch (_) {
        mensaje = TextosAgente.sinConexion;
      }
      if (!_vigente(generacion)) return false;
      if (reintentable && intento == 0) {
        await Future<void>.delayed(pausaReintento);
        if (!_vigente(generacion)) return false;
        continue;
      }
      _ponerSesion(fase: FaseAgente.sinConexion, aviso: mensaje);
      return false;
    }
  }

  @override
  Future<void> preguntar(String pregunta, List<Mensaje> historial, {required bool vozAutomatica}) async {
    final conversacion = _conversacion;
    _ponerSesion(sinRespuesta: false);
    if (_sesion.value.fase == FaseAgente.ejemplo) return _responderConEjemplo(pregunta, historial);

    final agente = _agente;
    // Las variables se leen al abrir la sesión: si han cambiado (se ha quitado «Mi situación» o se ha cambiado el
    // perfil), se empieza otra.
    if (agente != null &&
        agente.estado.value != EstadoAgente.desconectado &&
        !mapEquals(_variablesDeSesion, _variablesActuales())) {
      await _cerrarSesion(FaseAgente.preparando);
    }
    final abierta = await abrirSesion();
    if (!_vigenteConversacion(conversacion)) return;
    if (!abierta || agente == null) {
      _terminarEspera(
        MensajeChat.error(
          nuevoId(),
          _sesion.value.aviso ?? TextosAgente.sinConexion,
          pregunta: pregunta,
          historial: historial,
        ),
      );
      return;
    }

    // En una sesión recién abierta se espera un momento al saludo, para no tomarlo por la respuesta.
    final saludo = _saludo;
    if (_saludoPendiente && saludo != null && !_enviadoEnSesion) {
      await saludo.future.timeout(esperaSaludo, onTimeout: () {});
      if (!_vigenteConversacion(conversacion)) return;
    }

    final espera = _espera = Completer<MensajeAgente?>();
    _errorEspera = null;
    _enviadoEnSesion = true;
    agente.enviarTexto(pregunta);
    final respuesta = await _esperarRespuesta(espera);
    if (identical(_espera, espera)) _espera = null;
    if (!_vigenteConversacion(conversacion)) return;

    if (respuesta == null) {
      final conectado = agente.estado.value == EstadoAgente.conectado;
      final id = nuevoId();
      final texto = _errorEspera ?? (conectado ? textoSinRespuesta : textoCortado);
      if (conectado && _errorEspera == null) {
        _idSinRespuesta = id;
        _ponerSesion(sinRespuesta: true);
      }
      _terminarEspera(MensajeChat.error(id, texto, pregunta: pregunta, historial: historial));
      return;
    }
    _anadirRespuesta(respuesta.texto, pregunta: pregunta, historial: historial);
  }

  /// Espera la respuesta. Si se acaba el tiempo mientras el agente habla (el texto suele llegar antes que la voz,
  /// pero por si acaso), se espera un poco más.
  Future<MensajeAgente?> _esperarRespuesta(Completer<MensajeAgente?> espera) async {
    var limite = tiempoRespuesta;
    for (var prorroga = 0; ; prorroga++) {
      try {
        return await espera.future.timeout(limite);
      } on TimeoutException {
        if (prorroga < 2 && (_agente?.hablando.value ?? false)) {
          limite = const Duration(seconds: 10);
          continue;
        }
        return null;
      }
    }
  }

  void _alMensaje(MensajeAgente mensaje) {
    if (_cerrado || !mensaje.deAgente) return;
    if (mensaje.esCorreccion) {
      _corregir(mensaje);
      return;
    }
    // El saludo: el primer mensaje de la sesión si aún no se ha preguntado nada (o si es el saludo de siempre).
    if (_saludoPendiente && (!_enviadoEnSesion || esSaludoAgente(mensaje.texto))) {
      _saludoPendiente = false;
      _ponerSesion(saludo: quitarEtiquetas(mensaje.texto));
      final saludo = _saludo;
      if (saludo != null && !saludo.isCompleted) saludo.complete();
      return;
    }
    _saludoPendiente = false;
    final espera = _espera;
    if (espera != null && !espera.isCompleted) {
      espera.complete(mensaje);
      return;
    }
    _anadirRespuesta(mensaje.texto);
  }

  void _alError(String texto) {
    if (_cerrado) return;
    final espera = _espera;
    if (espera != null && !espera.isCompleted) {
      _errorEspera = texto;
      espera.complete(null);
    }
  }

  void _alCambiarEstado() {
    final agente = _agente;
    if (_cerrado || agente == null || agente.estado.value != EstadoAgente.desconectado) return;
    _completarEspera(null);
    // Si se ha cerrado sin pedirlo (el agente ha colgado o se ha cortado la red), se vuelve a abrir al preguntar.
    if (_sesion.value.fase == FaseAgente.conectado) {
      _ponerSesion(fase: FaseAgente.sinConexion, aviso: textoCerrado);
    }
  }

  void _alCambiarHablando() {
    if (_cerrado) return;
    final hablando = _agente?.hablando.value ?? false;
    if (state.agenteHablando != hablando) state = state.copyWith(agenteHablando: hablando);
    if (!hablando) return;
    // Nunca se escucha mientras habla el agente: el dictado se corta (lo entendido ya está en el campo).
    if (state.escuchando) {
      state = state.copyWith(voz: EstadoVoz.inactivo, nivelVoz: 0);
      unawaited(_sttAgente.cancelar());
    }
    // Ni suenan dos voces: se para «Escuchar».
    if (state.hablandoId != null) unawaited(callar());
  }

  /// Añade una respuesta del agente. Con [pregunta], es la respuesta de esa pregunta y termina la espera; sin ella,
  /// el agente ha hablado por su cuenta (o ha llegado tarde).
  void _anadirRespuesta(String bruto, {String? pregunta, List<Mensaje> historial = const []}) {
    final espera = pregunta != null;
    var mensajes = state.mensajes;
    var preguntaDeLaRespuesta = pregunta;
    var historialDeLaRespuesta = historial;
    MensajeChat? sustituido;
    if (!espera && mensajes.isEmpty && !state.esperando) {
      // Antes de la primera pregunta no hay conversación que seguir: se lee en la vista inicial, bajo el saludo.
      final texto = prepararRespuestaAgente(bruto).texto;
      final dichos = _sesion.value.antesDePreguntar;
      if (tieneContenido(texto) && dichos.lastOrNull != texto) _ponerSesion(antesDePreguntar: [...dichos, texto]);
      return;
    }
    if (!espera) {
      final ultimo = mensajes.lastOrNull;
      // Respuesta que llega tarde: ocupa el sitio del aviso de «no responde» si sigue siendo lo último.
      if (ultimo != null && ultimo.id == _idSinRespuesta && ultimo.esError) {
        sustituido = ultimo;
        preguntaDeLaRespuesta = ultimo.preguntaOriginal;
        historialDeLaRespuesta = ultimo.historialOriginal;
      }
    }
    final mensaje = _mensajeDeRespuesta(bruto, pregunta: preguntaDeLaRespuesta, historial: historialDeLaRespuesta);
    if (mensaje == null) {
      // Una respuesta sin palabras («...»): para quien pregunta es como si no hubiera respondido.
      if (espera) {
        _terminarEspera(MensajeChat.error(nuevoId(), textoSinRespuesta, pregunta: pregunta, historial: historial));
      }
      return;
    }
    if (sustituido != null) {
      _idSinRespuesta = null;
      _ponerSesion(sinRespuesta: false);
      mensajes = [for (final m in mensajes) m.id == sustituido.id ? mensaje : m];
    } else {
      // Lo mismo que el último mensaje del agente (una plantilla repetida) no se enseña dos veces.
      final ultimo = mensajes.lastOrNull;
      if (!espera && ultimo != null && !ultimo.esUsuario && ultimo.texto == mensaje.texto) return;
      mensajes = [...mensajes, mensaje];
    }
    state = state.copyWith(mensajes: mensajes, esperando: espera ? false : null);
  }

  MensajeChat? _mensajeDeRespuesta(String bruto, {String? pregunta, List<Mensaje> historial = const []}) {
    final respuesta = prepararRespuestaAgente(bruto);
    if (!tieneContenido(respuesta.texto)) return null;
    var tipo = respuesta.tipo;
    // Red de seguridad (sección 10.2): si la pregunta suena a peligro, la tarjeta de ayuda sale siempre.
    if (pregunta != null && tipo != TipoTextoAgente.respuestaSegura && pareceCrisis(pregunta)) {
      tipo = TipoTextoAgente.crisis;
    }
    final id = nuevoId();
    if (tipo == TipoTextoAgente.respuestaSegura && pregunta != null) {
      return MensajeChat.error(id, respuesta.texto, pregunta: pregunta, historial: historial);
    }
    _originales[id] = bruto;
    return MensajeChat.asistente(
      id,
      AskResponse(tipo: _tipoRespuesta(tipo), respuesta: respuesta.texto, terminos: _terminosEn(respuesta.texto)),
      telefonos: respuesta.telefonos,
    );
  }

  /// El agente se ha interrumpido (se ha enviado otra pregunta mientras hablaba): el mensaje se queda con lo que llegó
  /// a decir. Si no llegó a decir nada («...»), se deja entero.
  void _corregir(MensajeAgente correccion) {
    final original = correccion.corrigeA!;
    if (esSaludoAgente(original) || !tieneContenido(correccion.texto)) return;
    final buscado = comparable(quitarEtiquetas(original));
    final mensajes = state.mensajes;
    for (var i = mensajes.length - 1; i >= 0; i--) {
      final mensaje = mensajes[i];
      final bruto = _originales[mensaje.id];
      final respuesta = mensaje.respuesta;
      if (bruto == null || respuesta == null || comparable(quitarEtiquetas(bruto)) != buscado) continue;
      var texto = prepararRespuestaAgente(correccion.texto).texto;
      if (!RegExp(r'[.!?…]$').hasMatch(texto)) texto = '$texto…';
      final corregido = MensajeChat.asistente(
        mensaje.id,
        AskResponse(tipo: respuesta.tipo, respuesta: texto, terminos: _terminosEn(texto)),
        telefonos: telefonosEn(texto),
        ejemplo: mensaje.ejemplo,
      );
      state = state.copyWith(mensajes: [...mensajes]..[i] = corregido);
      return;
    }
  }

  Future<void> _responderConEjemplo(String pregunta, List<Mensaje> historial) async {
    final conversacion = _conversacion;
    final situacion = state.situacion;
    MensajeChat mensaje;
    try {
      final respuesta = await ref
          .read(respuestasEjemploProvider)
          .ask(
            AskRequest(
              pregunta: pregunta,
              modo: situacion == null ? ModoPregunta.libre : ModoPregunta.situacion,
              situacion: situacion,
              historial: historial,
            ),
          );
      mensaje = MensajeChat.asistente(nuevoId(), respuesta, ejemplo: true);
    } catch (_) {
      mensaje = MensajeChat.error(nuevoId(), ApiException.mensajeSeguro, pregunta: pregunta, historial: historial);
    }
    if (!_vigenteConversacion(conversacion)) return;
    _terminarEspera(mensaje);
  }

  /// «Ver una respuesta de ejemplo»: el agente no responde, así que a partir de ahora se contesta con ejemplos
  /// (marcados como ejemplo). La pregunta que se quedó sin respuesta se contesta ya.
  Future<void> usarEjemplos() async {
    if (_cerrado || state.esperando) return;
    await _cerrarSesion(FaseAgente.ejemplo);
    _ponerSesion(sinRespuesta: false, aviso: null);
    final ultimo = state.mensajes.lastOrNull;
    final pregunta = ultimo?.preguntaOriginal;
    if (ultimo == null || !ultimo.esError || pregunta == null) return;
    _idSinRespuesta = null;
    state = state.copyWith(
      mensajes: [
        for (final m in state.mensajes)
          if (m.id != ultimo.id) m,
      ],
      esperando: true,
    );
    await _responderConEjemplo(pregunta, ultimo.historialOriginal);
  }

  /// Deja los ejemplos y vuelve a conectar con el agente.
  Future<bool> volverAlAgente() {
    if (_sesion.value.fase == FaseAgente.ejemplo) _ponerSesion(fase: FaseAgente.preparando);
    return abrirSesion();
  }

  /// La app pasa a segundo plano: se cierra la sesión (el agente se calla). Se vuelve a abrir al preguntar.
  void pausar() {
    final fase = _sesion.value.fase;
    // Solo si hay sesión (o se está abriendo). onHide y onPause llegan seguidos: la segunda vez ya está en pausa.
    if (_cerrado || fase != FaseAgente.conectado && fase != FaseAgente.conectando) return;
    unawaited(_cerrarSesion(FaseAgente.pausado));
  }

  /// Ha cambiado el perfil (edad, proceso, papel o momento): las variables solo se leen al abrir la sesión.
  Future<void> cambiarPerfil() async {
    final fase = _sesion.value.fase;
    if (_cerrado || fase == FaseAgente.ejemplo || fase == FaseAgente.preparando || state.esperando) return;
    await _cerrarSesion(FaseAgente.preparando);
    await abrirSesion();
  }

  @override
  void quitarSituacion() {
    super.quitarSituacion();
    // Sin mensajes, se empieza ya otra sesión con el papel nuevo; si no, al preguntar (preguntar lo comprueba).
    if (state.mensajes.isEmpty) unawaited(cambiarPerfil());
  }

  @override
  void borrar() {
    super.borrar();
    _conversacion++;
    _completarEspera(null);
    _originales.clear();
    _idSinRespuesta = null;
    state = state.copyWith(agenteHablando: _agente?.hablando.value ?? false);
    _ponerSesion(sinRespuesta: false, antesDePreguntar: const []);
    final fase = _sesion.value.fase;
    if (fase == FaseAgente.ejemplo || fase == FaseAgente.preparando) return;
    // Conversación nueva de verdad: otra sesión, que no recuerda la anterior.
    unawaited(_cerrarSesion(FaseAgente.preparando).then((_) => abrirSesion()));
  }

  @override
  Future<void> empezarEscucha() async {
    // Nunca se escucha mientras habla el agente: se transcribiría su voz.
    if (state.agenteHablando || state.esperando || state.escuchando) return;
    final fase = _sesion.value.fase;
    if (_cerrarSesionParaDictar && (fase == FaseAgente.conectado || fase == FaseAgente.conectando)) {
      await _cerrarSesion(FaseAgente.pausado);
    }
    _dictandoConSesion = _sesion.value.fase == FaseAgente.conectado;
    await super.empezarEscucha();
  }

  @override
  Future<void> leer(int id) async {
    // La voz del móvil no se mezcla con la del agente.
    if (state.agenteHablando) return;
    await super.leer(id);
  }

  @override
  void avisarQueEscribe() {
    if (_sesion.value.fase == FaseAgente.conectado) _agente?.avisarQueEscribe();
  }

  /// Cierra la sesión y deja la banda en [fase]. Lo que estuviera llegando de la sesión cerrada se ignora.
  Future<void> _cerrarSesion(FaseAgente fase) async {
    _generacion++;
    _abriendo = null;
    _saludoPendiente = false;
    _ponerSesion(fase: fase, saludo: null, conversacionNueva: false);
    await _agente?.terminar();
  }

  Map<String, String> _variablesActuales() => ref.read(entradaProvider).variablesAgente(situacion: state.situacion);

  /// Los términos del glosario que aparecen en [texto], para subrayarlos (como en el modo texto).
  List<String> _terminosEn(String texto) {
    final glosario = ref.read(glosarioProvider).value;
    if (glosario == null) return const [];
    final normal = normalizar(texto);
    return [
      for (final entrada in glosario)
        if (entrada.termino.trim().isNotEmpty && normal.contains(normalizar(entrada.termino.trim()))) entrada.termino,
    ];
  }

  static TipoRespuesta _tipoRespuesta(TipoTextoAgente tipo) => switch (tipo) {
    TipoTextoAgente.crisis => TipoRespuesta.crisis,
    TipoTextoAgente.hechos => TipoRespuesta.hechos,
    TipoTextoAgente.fueraDeAmbito => TipoRespuesta.fueraDeAmbito,
    TipoTextoAgente.normal || TipoTextoAgente.respuestaSegura => TipoRespuesta.normal,
  };

  void _terminarEspera(MensajeChat mensaje) {
    if (_cerrado) return;
    state = state.copyWith(mensajes: [...state.mensajes, mensaje], esperando: false);
  }

  void _completarEspera(MensajeAgente? mensaje) {
    final espera = _espera;
    if (espera != null && !espera.isCompleted) espera.complete(mensaje);
  }

  bool _vigente(int generacion) => !_cerrado && generacion == _generacion;

  bool _vigenteConversacion(int conversacion) => !_cerrado && ref.mounted && conversacion == _conversacion;

  void _ponerSesion({
    FaseAgente? fase,
    Object? saludo = _sinCambio,
    List<String>? antesDePreguntar,
    Object? aviso = _sinCambio,
    bool? sinRespuesta,
    bool? conversacionNueva,
  }) {
    if (_cerrado) return;
    _sesion.value = _sesion.value.copyWith(
      fase: fase,
      saludo: identical(saludo, _sinCambio) ? null : () => saludo as String?,
      antesDePreguntar: antesDePreguntar,
      aviso: identical(aviso, _sinCambio) ? null : () => aviso as String?,
      sinRespuesta: sinRespuesta,
      conversacionNueva: conversacionNueva,
    );
  }
}

const _sinCambio = Object();
