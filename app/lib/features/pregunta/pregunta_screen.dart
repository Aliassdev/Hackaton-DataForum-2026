import 'dart:ui' show FlutterView;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/agente/agente_provider.dart';
import '../../core/api/models.dart';
import '../../core/providers.dart';
import '../../tema.dart';
import '../../widgets/movimiento/hapticos.dart';
import '../../widgets/tuturno_scaffold.dart';
import 'agente/banda_agente.dart';
import 'agente/chat_agente.dart';
import 'agente/hoja_perfil.dart';
import 'agente/textos_agente.dart' show textoBorrarAgente;
import 'agente/vista_inicial_agente.dart';
import 'chat_controller.dart';
import 'textos.dart' show textoBorrar;
import 'widgets/compositor.dart';
import 'widgets/mensajes.dart';
import 'widgets/vista_inicial.dart';

/// «Pregunta» (sección 4.4): agente de voz con fuentes, términos del glosario y sugerencias.
///
/// - Con agente (APK con API_URL o agent_id): contesta el agente de voz si hay «Voz» y no hay lector de pantalla; si
///   no, o si la voz falla, el modo texto real (POST /api/agent/ask). En la web, siempre el modo texto, con «Escuchar»
///   (flutter_tts). Los ejemplos solo salen si no responde nadie, y siempre marcados como ejemplo.
/// - Pulsar para hablar: la transcripción se ve en vivo y, al parar, pasa al campo de texto para corregirla antes de
///   enviar. Si la voz no funciona, el campo de texto sigue disponible. El chat solo vive en memoria.
///
/// Pregunta no se gamifica: sin puntos ni confeti, Tut responde quieto y las vibraciones son, como mucho, un toque.
class PreguntaScreen extends ConsumerStatefulWidget {
  const PreguntaScreen({super.key, this.situacion, this.preguntaInicial});

  /// «Mi situación»: si no es nula, se pregunta con ese papel (se puede quitar).
  final RolProceso? situacion;

  /// Texto que aparece ya escrito en el campo (por ejemplo, desde el Glosario). No se envía solo.
  final String? preguntaInicial;

  @override
  ConsumerState<PreguntaScreen> createState() => _PreguntaScreenState();
}

class _PreguntaScreenState extends ConsumerState<PreguntaScreen> with WidgetsBindingObserver {
  final _texto = TextEditingController();
  final _foco = FocusNode();
  final _scroll = ScrollController();
  final _desdeVoz = ValueNotifier(false);
  late final AppLifecycleListener _ciclo;

  /// Mensajes que ya se han enseñado (solo se anima la entrada de los nuevos).
  final _vistos = <int>{};

  /// Texto que había en el campo al empezar a dictar: lo dictado se añade detrás.
  var _base = '';
  var _sincronizarDictado = false;
  String? _puestoPorVoz;

  /// La pregunta del campo se ha dictado: «si preguntas con la voz, te contesto con la voz». Lo escrito en
  /// silencio no se lee en alto (quien escribe para que no le oigan no debe oír al móvil hablar).
  var _preguntaPorVoz = false;

  /// El teclado está abierto. Se mira en la ventana: Scaffold quita el teclado de la MediaQuery del cuerpo.
  var _teclado = false;
  FlutterView? _vista;

  /// Con agente de voz (agente/): se decide al entrar y no cambia mientras dura la pantalla. Que conteste con la voz
  /// o por escrito lo decide el chat del agente (con «Voz», sin lector de pantalla y si la voz responde).
  late final bool _conAgente = ref.read(modoAgenteProvider);

  ProveedorChat get _proveedor => (_conAgente ? chatAgenteProvider : chatProvider)(widget.situacion);

  ChatNotifier get _chat => ref.read(_proveedor.notifier);

  /// Con TalkBack activo, el lector de pantalla ya lee la respuesta: no se lee dos veces.
  bool get _vozAutomatica => !MediaQuery.accessibleNavigationOf(context);

  /// El lector de pantalla que se le ha dicho al chat (null hasta [_preparar]).
  bool? _lectorAvisado;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final inicial = widget.preguntaInicial?.trim() ?? '';
    if (inicial.isNotEmpty) _texto.text = inicial;
    _texto.addListener(_alEditar);
    // Al ocultarse la app (antes de pasar a segundo plano) se cierra la sesión de voz: el agente deja de hablar. Al
    // pasar a segundo plano, además, se calla la voz del móvil y deja de escuchar.
    _ciclo = AppLifecycleListener(
      onHide: () => _chat.pausar(),
      onPause: () {
        _chat.pausar();
        _chat.callar();
        _chat.pararEscucha();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _preparar());
  }

  /// Al entrar: con agente, la hoja del perfil (la primera vez, si no hay perfil); después, el chat empieza (con voz,
  /// abre la sesión para que el saludo se oiga enseguida).
  Future<void> _preparar() async {
    if (!mounted) return;
    if (_conAgente) await preguntarPerfilSiHaceFalta(context, ref, situacion: widget.situacion);
    if (!mounted) return;
    final lector = _lectorAvisado = MediaQuery.accessibleNavigationOf(context);
    _chat.empezar(lectorDePantalla: lector);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vista = View.maybeOf(context);
    _teclado = _tecladoAbierto();
    // Si se activa o se quita TalkBack con Pregunta abierta: con lector de pantalla se contesta por escrito.
    final lector = MediaQuery.accessibleNavigationOf(context);
    if (_lectorAvisado != null && lector != _lectorAvisado) {
      _lectorAvisado = lector;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _chat.ponerLectorDePantalla(lector);
      });
    }
  }

  @override
  void didChangeMetrics() {
    final abierto = _tecladoAbierto();
    if (mounted && abierto != _teclado) setState(() => _teclado = abierto);
  }

  bool _tecladoAbierto() => (_vista?.viewInsets.bottom ?? 0) > 0;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ciclo.dispose();
    _texto.removeListener(_alEditar);
    _texto.dispose();
    _foco.dispose();
    _scroll.dispose();
    _desdeVoz.dispose();
    super.dispose();
  }

  /// Si se corrige lo dictado, deja de actualizarse con la voz.
  void _alEditar() {
    if (_texto.text.trim().isEmpty) {
      _preguntaPorVoz = false;
    } else {
      // Modo agente: mientras se escribe o se dicta, el agente no toma la palabra.
      _chat.avisarQueEscribe();
    }
    if (_puestoPorVoz != null && _texto.text != _puestoPorVoz) {
      _puestoPorVoz = null;
      _sincronizarDictado = false;
      _desdeVoz.value = false;
    }
  }

  void _ponerDictado(String dictado) {
    final limpio = dictado.trim();
    if (!_sincronizarDictado || limpio.isEmpty) return;
    final nuevo = [_base, limpio].where((t) => t.isNotEmpty).join(' ');
    _puestoPorVoz = nuevo;
    _texto.value = TextEditingValue(
      text: nuevo,
      selection: TextSelection.collapsed(offset: nuevo.length),
    );
    _desdeVoz.value = true;
    _preguntaPorVoz = true;
  }

  void _dejarDeSincronizar() {
    _sincronizarDictado = false;
    _puestoPorVoz = null;
    _desdeVoz.value = false;
  }

  /// Envía lo escrito o, si se pasa [sugerida], esa pregunta (ejemplos y sugerencias).
  ///
  /// La respuesta solo se lee sola si la pregunta se dictó (y no hay TalkBack). Siempre queda «Escuchar».
  void _enviar([String? sugerida]) {
    final pregunta = (sugerida ?? _texto.text).trim();
    if (pregunta.isEmpty || ref.read(_proveedor).esperando) return;
    Hapticos.toque();
    final porVoz = sugerida == null && _preguntaPorVoz;
    if (sugerida == null) {
      _dejarDeSincronizar();
      _texto.clear();
      _preguntaPorVoz = false;
    }
    // Se cierra el teclado para que se vea la respuesta.
    FocusScope.of(context).unfocus();
    _chat.enviar(pregunta, vozAutomatica: _vozAutomatica && porVoz);
  }

  void _alternarMicro() {
    final estado = ref.read(_proveedor);
    if (estado.esperando) return;
    Hapticos.toque();
    if (!estado.escuchando) {
      FocusScope.of(context).unfocus();
      _base = _texto.text.trim();
      _puestoPorVoz = null;
      _sincronizarDictado = true;
    }
    _chat.alternarMicro();
  }

  Future<void> _borrar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.restart_alt_rounded),
        title: const Text('¿Empezar de nuevo?'),
        content: Text(_conAgente ? textoBorrarAgente : textoBorrar),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Borrar')),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    Hapticos.toque();
    _dejarDeSincronizar();
    _texto.clear();
    _preguntaPorVoz = false;
    _chat.borrar();
  }

  void _alCambiarMensajes(int? antes, int ahora) {
    if (ahora <= (antes ?? 0) || !_scroll.hasClients || _scroll.offset <= 0) return;
    // La lista va al revés: 0 es el final de la conversación.
    final tiempo = duracion(context, Duracion.media);
    if (tiempo == Duration.zero) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(0, duration: tiempo, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(_proveedor.select((s) => s.dictado), (_, dictado) => _ponerDictado(dictado));
    ref.listen(_proveedor.select((s) => s.mensajes.length), _alCambiarMensajes);
    final (:mensajes, :esperando, :hablandoId, :situacion, :esperandoVoz) = ref.watch(
      _proveedor.select(
        (s) => (
          mensajes: s.mensajes,
          esperando: s.esperando,
          hablandoId: s.hablandoId,
          situacion: s.situacion,
          esperandoVoz: s.esperandoVoz,
        ),
      ),
    );
    final chat = _chat;
    final vacio = mensajes.isEmpty && !esperando;
    // Con el teclado abierto, o en pantallas bajas con letra muy grande, el micrófono pasa junto al campo y
    // «Voz» y «Nueva» van al menú de arriba.
    final factorTexto = MediaQuery.textScalerOf(context).scale(16) / 16;
    final compacto = _teclado || MediaQuery.sizeOf(context).height < 560 * factorTexto;

    return TuTurnoScaffold(
      titulo: 'Pregunta',
      acciones: [if (compacto) _MenuOpciones(proveedor: _proveedor, onBorrar: _borrar)],
      body: Column(
        children: [
          // Cómo va la conversación (con agente) y, si salen ejemplos, que son de ejemplo.
          AnimatedSize(
            duration: duracionTamano(context, Duracion.media),
            alignment: Alignment.topCenter,
            child: BandaPregunta(proveedor: _proveedor, compacto: compacto),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: duracion(context, Duracion.media),
              child: vacio
                  ? (_conAgente
                        ? VistaInicialAgente(
                            key: const ValueKey('vista-inicial'),
                            situacion: widget.situacion,
                            onEjemplo: _enviar,
                          )
                        : VistaInicial(
                            key: const ValueKey('vista-inicial'),
                            proveedor: _proveedor,
                            situacion: situacion,
                            onEjemplo: _enviar,
                          ))
                  : _ListaMensajes(
                      key: const ValueKey('lista'),
                      mensajes: mensajes,
                      esperando: esperando,
                      hablandoId: hablandoId,
                      controlador: _scroll,
                      vistos: _vistos,
                      onLeer: (id) => _chat.alternarLectura(id),
                      onReintentar: (id) => _chat.reintentar(id, vozAutomatica: _vozAutomatica),
                      onSugerencia: _enviar,
                      onEjemplo: () => _chat.usarEjemplos(),
                      onPorEscrito: esperandoVoz && chat is ChatAgenteNotifier ? chat.contestarPorEscrito : null,
                    ),
            ),
          ),
          Compositor(
            proveedor: _proveedor,
            texto: _texto,
            foco: _foco,
            desdeVoz: _desdeVoz,
            compacto: compacto,
            onEnviar: _enviar,
            onMicro: _alternarMicro,
            onBorrar: _borrar,
          ),
        ],
      ),
    );
  }
}

/// En modo compacto, «Voz» y «Nueva» se mueven a este menú de la barra de arriba.
class _MenuOpciones extends ConsumerWidget {
  const _MenuOpciones({required this.proveedor, required this.onBorrar});

  final ProveedorChat proveedor;
  final VoidCallback onBorrar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vozActivada = ref.watch(ajustesProvider.select((a) => a.vozActivada));
    final puedeBorrar = ref.watch(proveedor.select((s) => s.mensajes.isNotEmpty || s.escuchando));
    return PopupMenuButton<String>(
      key: const Key('menu-pregunta'),
      tooltip: 'Más opciones',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (opcion) {
        Hapticos.seleccion();
        switch (opcion) {
          case 'voz':
            ref.read(ajustesProvider.notifier).actualizar((a) => a.copyWith(vozActivada: !a.vozActivada));
          case 'nueva':
            onBorrar();
        }
      },
      itemBuilder: (context) => [
        CheckedPopupMenuItem(value: 'voz', checked: vozActivada, child: const Text('Leer las respuestas en voz alta')),
        PopupMenuItem(
          value: 'nueva',
          enabled: puedeBorrar,
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.restart_alt_rounded),
            title: Text('Empezar de nuevo'),
          ),
        ),
      ],
    );
  }
}

class _ListaMensajes extends StatelessWidget {
  const _ListaMensajes({
    super.key,
    required this.mensajes,
    required this.esperando,
    required this.hablandoId,
    required this.controlador,
    required this.vistos,
    required this.onLeer,
    required this.onReintentar,
    required this.onSugerencia,
    this.onEjemplo,
    this.onPorEscrito,
  });

  final List<MensajeChat> mensajes;
  final bool esperando;
  final int? hablandoId;
  final ScrollController controlador;
  final Set<int> vistos;
  final ValueChanged<int> onLeer;
  final ValueChanged<int> onReintentar;
  final ValueChanged<String> onSugerencia;

  /// Ver una respuesta de ejemplo cuando no responde nadie (en el error, con «Reintentar»).
  final VoidCallback? onEjemplo;

  /// Mientras se espera al agente de voz: «Contestar por escrito» (sale a los 8 s).
  final VoidCallback? onPorEscrito;

  static const _claveEscribiendo = ValueKey('escribiendo');

  int get _extra => esperando ? 1 : 0;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controlador,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.m, Espacio.m, Espacio.l),
      itemCount: mensajes.length + _extra,
      findChildIndexCallback: (clave) {
        if (clave == _claveEscribiendo) return esperando ? 0 : null;
        if (clave is! ValueKey<int>) return null;
        final i = mensajes.indexWhere((m) => m.id == clave.value);
        return i < 0 ? null : mensajes.length - 1 - i + _extra;
      },
      itemBuilder: (context, indice) {
        if (esperando && indice == 0) {
          return Padding(
            key: _claveEscribiendo,
            padding: EdgeInsets.only(top: mensajes.isEmpty ? 0 : Espacio.l),
            child: Aparecer(child: IndicadorEscribiendo(onPorEscrito: onPorEscrito)),
          );
        }
        final i = mensajes.length - 1 - (indice - _extra);
        final mensaje = mensajes[i];
        final anterior = i > 0 ? mensajes[i - 1] : null;
        final ultimo = i == mensajes.length - 1;
        // Solo se anima (y, si es de crisis, se desplaza hasta la tarjeta de Ayuda) lo que se ve por primera vez.
        final nuevo = vistos.add(mensaje.id);
        final separacion = anterior == null
            ? 0.0
            : anterior.autor == mensaje.autor
            ? Espacio.s
            : Espacio.l;

        final Widget contenido;
        if (mensaje.esUsuario) {
          contenido = BurbujaUsuario(texto: mensaje.texto);
        } else if (mensaje.esError) {
          contenido = BurbujaError(
            mensaje: mensaje,
            activo: !esperando,
            revelar: nuevo && ultimo,
            onReintentar: () => onReintentar(mensaje.id),
            onEjemplo: ultimo ? onEjemplo : null,
          );
        } else {
          contenido = BurbujaAsistente(
            mensaje: mensaje,
            hablando: hablandoId == mensaje.id,
            onLeer: () => onLeer(mensaje.id),
            onSugerencia: onSugerencia,
            mostrarSugerencias: ultimo && !esperando,
            revelar: nuevo && ultimo,
          );
        }

        return Padding(
          key: ValueKey<int>(mensaje.id),
          padding: EdgeInsets.only(top: separacion),
          child: Aparecer(
            animar: nuevo,
            // La respuesta más nueva se anuncia con TalkBack.
            child: Semantics(container: true, liveRegion: ultimo && !mensaje.esUsuario, child: contenido),
          ),
        );
      },
    );
  }
}
