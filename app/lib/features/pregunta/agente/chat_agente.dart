import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agente/agente_provider.dart';
import '../../../core/agente/agente_voz.dart';
import '../../../core/agente/respuesta_agente.dart';
import '../../../core/api/tuturno_api.dart';
import '../../../core/entrada.dart';
import '../../../core/providers.dart';
import '../../../core/texto.dart';
import '../../../core/voz/stt.dart';
import '../chat_controller.dart';
import 'textos_agente.dart';

export '../ejemplos.dart' show respuestasEjemploProvider;

// «Pregunta» en modo agente (docs/ARQUITECTURA.md, sección 5.0, fase 1): las preguntas van al agente de voz de
// ElevenLabs, que contesta con su voz y con texto. Es el mismo chat que el modo texto (ChatNotifier): solo cambia de
// dónde sale la respuesta. La sesión no usa el micrófono: la voz del menor se transcribe en el móvil (sttProvider) y se
// envía como texto.
//
// - Con voz solo si se puede: con «Sin voz» o con lector de pantalla se contesta por escrito y no se abre la sesión,
//   porque el agente siempre habla en alto. Lo mismo con los ejemplos.
// - La sesión se abre al entrar (después de la hoja del perfil, agente/capa_agente.dart), se cierra al salir y al pasar
//   a segundo plano, y se vuelve a abrir al preguntar. No reconecta sola al volver.
// - El primer mensaje de cada sesión es el saludo fijo del agente: no es una respuesta y no entra en el chat (se enseña
//   arriba).
// - Respaldo automático: si la voz no conecta (10 s y un reintento), no contesta en 20 s o se pide «Contestar por
//   escrito» (a los 8 s), la pregunta va al modo texto real (POST /api/agent/ask) y se sigue por escrito hasta «Probar
//   con voz». Si la sesión se corta, hay un error o el backend da su respuesta segura, esa pregunta se contesta por
//   escrito y la voz sigue. Los ejemplos solo salen si tampoco responde el modo texto (y se piden).
// - Lo que se enseña pasa por core/agente/respuesta_agente.dart: sin etiquetas de voz, teléfonos en cifras y las
//   plantillas fijas del backend reconocidas (crisis → tarjeta de ayuda; hechos → derivación; fuera de ámbito →
//   sugerencias).

/// Un chat por cada forma de entrar, como [chatProvider], pero con el agente de voz. Crea un [ChatAgenteNotifier].
final chatAgenteProvider = NotifierProvider.autoDispose.family<ChatNotifier, EstadoChat, RolProceso?>(
  ChatAgenteNotifier.new,
);

/// En qué punto está la conversación con el agente.
enum FaseAgente {
  /// Todavía no se ha intentado abrir (por ejemplo, con la hoja del perfil abierta).
  preparando,
  conectando,
  conectado,

  /// Se ha cortado sin pregunta pendiente. [SesionAgente.aviso] dice por qué. Se vuelve a abrir al preguntar.
  sinConexion,

  /// La app ha pasado a segundo plano y se ha cerrado la sesión. Se vuelve a abrir al preguntar.
  pausado,

  /// Por escrito porque así se ha elegido («Sin voz» o lector de pantalla). Sin sesión de voz.
  texto,

  /// Por escrito porque la voz no responde (no conecta, no contesta a tiempo o se ha pedido «Contestar por escrito»).
  /// Sin sesión de voz hasta «Probar con voz».
  sinVoz,
}

/// Lo que enseña la banda de estado de arriba (agente/banda_agente.dart).
@immutable
class SesionAgente {
  const SesionAgente({
    this.fase = FaseAgente.preparando,
    this.saludo,
    this.antesDePreguntar = const [],
    this.aviso,
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

  /// Se ha vuelto a conectar a mitad de una conversación: el agente no recuerda lo anterior.
  final bool conversacionNueva;

  SesionAgente copyWith({
    FaseAgente? fase,
    String? Function()? saludo,
    List<String>? antesDePreguntar,
    String? Function()? aviso,
    bool? conversacionNueva,
  }) => SesionAgente(
    fase: fase ?? this.fase,
    saludo: saludo != null ? saludo() : this.saludo,
    antesDePreguntar: antesDePreguntar ?? this.antesDePreguntar,
    aviso: aviso != null ? aviso() : this.aviso,
    conversacionNueva: conversacionNueva ?? this.conversacionNueva,
  );
}

/// Por qué se ha dejado de esperar la respuesta del agente.
enum _FinEspera {
  /// Se ha acabado el tiempo ([ChatAgenteNotifier.tiempoRespuesta]).
  tiempo,

  /// Se ha pedido «Contestar por escrito».
  porEscrito,

  /// Se ha cerrado o cortado la sesión.
  corte,

  /// El agente ha avisado de un error.
  error,
}

class ChatAgenteNotifier extends ChatNotifier {
  ChatAgenteNotifier(super.situacionInicial);

  /// Lo que se espera a la respuesta del agente antes de pasar al modo texto (en la prueba real tarda unos 2 s).
  static const tiempoRespuesta = Duration(seconds: 20);

  /// Lo que se espera a que se abra la sesión. Si no se abre, se reintenta una vez.
  static const tiempoConexion = Duration(seconds: 10);

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

  /// La pantalla ya ha pasado la hoja del perfil ([empezar]): hasta entonces no se abre la sesión.
  var _empezado = false;
  var _lectorDePantalla = false;

  /// La voz no ha respondido: se sigue por escrito hasta [probarConVoz] o [volverATuTurno].
  var _vozCaida = false;

  /// El saludo de la sesión actual todavía no ha llegado.
  var _saludoPendiente = false;
  Completer<void>? _saludo;

  /// Ya se ha enviado algo en la sesión actual.
  var _enviadoEnSesion = false;
  Map<String, String> _variablesDeSesion = const {};

  /// La pregunta enviada que espera respuesta: se completa con el mensaje del agente, o con null si no llega.
  Completer<MensajeAgente?>? _espera;
  _FinEspera? _finEspera;

  /// Texto tal como llegó de cada respuesta del agente que está en el chat: para aplicar las correcciones.
  final _originales = <int, String>{};

  @override
  bool get conAgente => true;

  /// Se contesta con la voz del agente: hay agente, la voz está permitida («Voz» y sin lector de pantalla), no se ha
  /// caído y no se está con los ejemplos.
  bool get usaVoz =>
      !_cerrado &&
      _agente != null &&
      ref.read(ajustesProvider).vozActivada &&
      !_lectorDePantalla &&
      !_vozCaida &&
      !state.ejemplos;

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
    // «Voz / Sin voz» decide si se contesta con la voz del agente o por escrito. Quitar la voz a propósito olvida que
    // había fallado: si se vuelve a poner, se intenta otra vez.
    ref.listen(ajustesProvider.select((a) => a.vozActivada), (_, activada) {
      if (!activada) _vozCaida = false;
      _actualizarModo();
    });
    // Para subrayar en las respuestas los términos del glosario.
    ref.read(glosarioProvider);
    ref.onDispose(() {
      _cerrado = true;
      _generacion++;
      _completarEspera(null, _FinEspera.corte);
      unawaited(subMensajes?.cancel());
      unawaited(subErrores?.cancel());
      agente?.estado.removeListener(_alCambiarEstado);
      agente?.hablando.removeListener(_alCambiarHablando);
      if (agente != null) unawaited(agente.terminar());
    });
    return estado;
  }

  @override
  void empezar({required bool lectorDePantalla}) {
    if (_cerrado) return;
    _lectorDePantalla = lectorDePantalla;
    _empezado = true;
    _actualizarModo();
  }

  @override
  void ponerLectorDePantalla(bool activo) {
    if (_cerrado || _lectorDePantalla == activo) return;
    _lectorDePantalla = activo;
    _actualizarModo();
  }

  /// Pone la conversación en el modo que toca: con voz (abre la sesión si estaba por escrito o sin empezar; si está en
  /// pausa, espera a la siguiente pregunta) o por escrito (cierra la sesión si la hay).
  void _actualizarModo() {
    if (_cerrado || !_empezado) return;
    final fase = _sesion.value.fase;
    if (usaVoz) {
      if (fase == FaseAgente.preparando || fase == FaseAgente.texto || fase == FaseAgente.sinVoz) {
        unawaited(abrirSesion());
      }
      return;
    }
    final porEscrito = _vozCaida ? FaseAgente.sinVoz : FaseAgente.texto;
    final agente = _agente;
    final abierta = agente != null && (agente.estado.value != EstadoAgente.desconectado || _abriendo != null);
    if (abierta) {
      unawaited(_cerrarSesion(porEscrito));
    } else if (fase != porEscrito) {
      _ponerSesion(fase: porEscrito, saludo: null, aviso: null, conversacionNueva: false);
    }
  }

  /// Abre la sesión con el agente si no está abierta. Devuelve false si no se ha podido o si ahora no toca la voz. La
  /// llaman [empezar], «Conectar», «Probar con voz» y [preguntar] cuando hace falta.
  Future<bool> abrirSesion() {
    if (!usaVoz) return Future.value(false);
    final agente = _agente!;
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
      var reintentable = true;
      try {
        await agente.iniciar(variables: variables).timeout(tiempoConexion);
        if (!_vigente(generacion)) return false;
        if (agente.estado.value != EstadoAgente.conectado) throw const ErrorAgente(TextosAgente.sinConexion);
        _variablesDeSesion = variables;
        _ponerSesion(fase: FaseAgente.conectado, conversacionNueva: aMitad);
        return true;
      } on ErrorAgente catch (e) {
        reintentable = e.mensaje == TextosAgente.sinConexion;
      } on TimeoutException {
        // Solo si este intento sigue siendo el de ahora: si mientras conectaba se ha abierto otra sesión (otro perfil,
        // «Empezar de nuevo»…), el agente es el mismo y terminar() cortaría la nueva.
        if (_vigente(generacion)) unawaited(agente.terminar());
      } catch (_) {
        // Cualquier otro fallo al conectar cuenta como «no conecta».
      }
      if (!_vigente(generacion)) return false;
      if (reintentable && intento == 0) {
        await Future<void>.delayed(pausaReintento);
        if (!_vigente(generacion)) return false;
        continue;
      }
      // No conecta: se sigue por escrito (modo texto real) hasta «Probar con voz».
      _vozCaida = true;
      _ponerSesion(fase: FaseAgente.sinVoz, saludo: null, aviso: null, conversacionNueva: false);
      return false;
    }
  }

  @override
  Future<void> preguntar(String pregunta, List<Mensaje> historial, {required bool vozAutomatica}) async {
    // Por escrito (o con los ejemplos): el chat de siempre.
    if (!usaVoz) return super.preguntar(pregunta, historial, vozAutomatica: vozAutomatica);

    final conversacion = _conversacion;
    final agente = _agente!;
    // Las variables se leen al abrir la sesión: si han cambiado (se ha quitado «Mi situación» o se ha cambiado el
    // perfil), se empieza otra.
    if (agente.estado.value != EstadoAgente.desconectado && !mapEquals(_variablesDeSesion, _variablesActuales())) {
      await _cerrarSesion(FaseAgente.preparando);
    }
    final abierta = await abrirSesion();
    if (!_vigenteConversacion(conversacion)) return;
    // No conecta (ya se ha pasado a «sin voz») o se ha quitado la voz mientras conectaba: por escrito.
    if (!abierta || !usaVoz) return super.preguntar(pregunta, historial, vozAutomatica: vozAutomatica);

    // En una sesión recién abierta se espera un momento al saludo, para no tomarlo por la respuesta.
    final saludo = _saludo;
    if (_saludoPendiente && saludo != null && !_enviadoEnSesion) {
      await saludo.future.timeout(esperaSaludo, onTimeout: () {});
      if (!_vigenteConversacion(conversacion)) return;
      if (!usaVoz) return super.preguntar(pregunta, historial, vozAutomatica: vozAutomatica);
    }

    final espera = _espera = Completer<MensajeAgente?>();
    _finEspera = null;
    _enviadoEnSesion = true;
    state = state.copyWith(esperandoVoz: true);
    agente.enviarTexto(pregunta);
    final respuesta = await _esperarRespuesta(espera);
    if (identical(_espera, espera)) _espera = null;
    if (!_cerrado && ref.mounted) state = state.copyWith(esperandoVoz: false);
    if (!_vigenteConversacion(conversacion)) return;

    if (respuesta != null) {
      final preparada = prepararRespuestaAgente(respuesta.texto);
      // Una respuesta sin palabras («...») o la respuesta segura del backend (su modelo de lenguaje ha fallado): esta
      // pregunta, por escrito. La voz sigue.
      if (tieneContenido(preparada.texto) && preparada.tipo != TipoTextoAgente.respuestaSegura) {
        _anadirRespuesta(respuesta.texto, pregunta: pregunta);
        return;
      }
      return super.preguntar(pregunta, historial, vozAutomatica: vozAutomatica);
    }

    // Sin respuesta. Si se acabó el tiempo o se pidió por escrito, se sigue por escrito hasta «Probar con voz»; si se
    // cortó o hubo un error, solo esta pregunta.
    final fin = _finEspera ?? _FinEspera.tiempo;
    if (fin == _FinEspera.tiempo || fin == _FinEspera.porEscrito) {
      _vozCaida = true;
      await _cerrarSesion(FaseAgente.sinVoz);
      if (!_vigenteConversacion(conversacion)) return;
    }
    return super.preguntar(pregunta, historial, vozAutomatica: vozAutomatica);
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
        _finEspera ??= _FinEspera.tiempo;
        return null;
      }
    }
  }

  /// «Contestar por escrito» (a los 8 s sin respuesta): deja de esperar al agente y pregunta al modo texto.
  void contestarPorEscrito() => _completarEspera(null, _FinEspera.porEscrito);

  void _alMensaje(MensajeAgente mensaje) {
    if (_cerrado || !mensaje.deAgente) return;
    // Sin sesión a propósito (por escrito, con la voz caída o en pausa): lo que llegue tarde de la sesión cerrada no se
    // enseña (ya se ha contestado por escrito).
    final fase = _sesion.value.fase;
    if (fase == FaseAgente.texto || fase == FaseAgente.sinVoz || fase == FaseAgente.pausado) return;
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
    _completarEspera(null, _FinEspera.error);
  }

  void _alCambiarEstado() {
    final agente = _agente;
    if (_cerrado || agente == null || agente.estado.value != EstadoAgente.desconectado) return;
    _completarEspera(null, _FinEspera.corte);
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
  /// el agente ha hablado por su cuenta.
  void _anadirRespuesta(String bruto, {String? pregunta}) {
    final espera = pregunta != null;
    final mensajes = state.mensajes;
    if (!espera && mensajes.isEmpty && !state.esperando) {
      // Antes de la primera pregunta no hay conversación que seguir: se lee en la vista inicial, bajo el saludo.
      final texto = prepararRespuestaAgente(bruto).texto;
      final dichos = _sesion.value.antesDePreguntar;
      if (tieneContenido(texto) && dichos.lastOrNull != texto) _ponerSesion(antesDePreguntar: [...dichos, texto]);
      return;
    }
    final preparada = prepararRespuestaAgente(bruto);
    if (!tieneContenido(preparada.texto)) return;
    // Lo mismo que el último mensaje del agente (una plantilla repetida) no se enseña dos veces.
    final ultimo = mensajes.lastOrNull;
    if (!espera && ultimo != null && !ultimo.esUsuario && ultimo.texto == preparada.texto) return;
    final mensaje = mensajeAsistente(
      AskResponse(
        tipo: _tipoRespuesta(preparada.tipo),
        respuesta: preparada.texto,
        terminos: _terminosEn(preparada.texto),
      ),
      pregunta: pregunta,
      telefonos: preparada.telefonos,
    );
    _originales[mensaje.id] = bruto;
    state = state.copyWith(mensajes: [...mensajes, mensaje], esperando: espera ? false : null);
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
      final telefonos = telefonosDeRespuesta(texto);
      final corregido = MensajeChat.asistente(
        mensaje.id,
        respuesta.copyWith(respuesta: texto, terminos: _terminosEn(texto)),
        telefonos: [...telefonos, if (mensaje.ayudaImagenes && !telefonos.contains('017')) '017'],
        ejemplo: mensaje.ejemplo,
        ayudaImagenes: mensaje.ayudaImagenes,
      );
      state = state.copyWith(mensajes: [...mensajes]..[i] = corregido);
      return;
    }
  }

  @override
  Future<void> alPasarAEjemplos() => _cerrarSesion(FaseAgente.texto);

  @override
  void volverATuTurno() {
    super.volverATuTurno();
    _vozCaida = false;
    _actualizarModo();
  }

  /// «Probar con voz»: la voz no respondía; se intenta otra vez la sesión.
  Future<bool> probarConVoz() {
    if (_cerrado) return Future.value(false);
    _vozCaida = false;
    if (!usaVoz) {
      _actualizarModo();
      return Future.value(false);
    }
    _ponerSesion(fase: FaseAgente.preparando, aviso: null);
    return abrirSesion();
  }

  /// La app pasa a segundo plano: se cierra la sesión (el agente se calla). Se vuelve a abrir al preguntar.
  @override
  void pausar() {
    final fase = _sesion.value.fase;
    // Solo si hay sesión (o se está abriendo). onHide y onPause llegan seguidos: la segunda vez ya está en pausa.
    if (_cerrado || fase != FaseAgente.conectado && fase != FaseAgente.conectando) return;
    unawaited(_cerrarSesion(FaseAgente.pausado));
  }

  /// Ha cambiado el perfil (edad, proceso, papel o momento): las variables solo se leen al abrir la sesión.
  @override
  Future<void> cambiarPerfil() async {
    if (_cerrado || !_empezado || state.esperando || !usaVoz) return;
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
    _completarEspera(null, _FinEspera.corte);
    _originales.clear();
    state = state.copyWith(
      agenteHablando: _agente?.hablando.value ?? false,
      conectandoVoz: _sesion.value.fase == FaseAgente.conectando,
    );
    _ponerSesion(antesDePreguntar: const []);
    final fase = _sesion.value.fase;
    if (!usaVoz || !_empezado || fase == FaseAgente.preparando) return;
    // Conversación nueva de verdad: otra sesión, que no recuerda la anterior.
    unawaited(_cerrarSesion(FaseAgente.preparando).then((_) => abrirSesion()));
  }

  @override
  Future<void> empezarEscucha() async {
    // Nunca se escucha mientras suena el agente (se transcribiría su voz) ni mientras conecta (el saludo cortaría el
    // dictado). La sesión no usa el micrófono.
    if (state.agenteHablando || state.conectandoVoz || state.esperando || state.escuchando) return;
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
    _ponerSesion(fase: fase, saludo: null, aviso: null, conversacionNueva: false);
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

  void _completarEspera(MensajeAgente? mensaje, _FinEspera fin) {
    final espera = _espera;
    if (espera == null || espera.isCompleted) return;
    _finEspera ??= fin;
    espera.complete(mensaje);
  }

  bool _vigente(int generacion) => !_cerrado && generacion == _generacion;

  bool _vigenteConversacion(int conversacion) => !_cerrado && ref.mounted && conversacion == _conversacion;

  void _ponerSesion({
    FaseAgente? fase,
    Object? saludo = _sinCambio,
    List<String>? antesDePreguntar,
    Object? aviso = _sinCambio,
    bool? conversacionNueva,
  }) {
    if (_cerrado) return;
    _sesion.value = _sesion.value.copyWith(
      fase: fase,
      saludo: identical(saludo, _sinCambio) ? null : () => saludo as String?,
      antesDePreguntar: antesDePreguntar,
      aviso: identical(aviso, _sinCambio) ? null : () => aviso as String?,
      conversacionNueva: conversacionNueva,
    );
    // El micrófono espera mientras conecta.
    final conectando = _sesion.value.fase == FaseAgente.conectando;
    if (ref.mounted && state.conectandoVoz != conectando) state = state.copyWith(conectandoVoz: conectando);
  }
}

const _sinCambio = Object();
