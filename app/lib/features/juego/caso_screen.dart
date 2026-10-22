import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/content_models.dart';
import '../../core/progreso.dart';
import '../../core/providers.dart';
import '../../core/voz/tts.dart';
import '../../tema.dart';
import '../../widgets/movimiento/confeti_papel.dart';
import '../../widgets/movimiento/hapticos.dart';
import '../../widgets/movimiento/sello_animado.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/estados.dart';
import '../../widgets/modulos.dart' show anchoMaximo;
import '../../widgets/texto_con_terminos.dart';
import '../../widgets/tuturno_scaffold.dart';
import 'juego_providers.dart';
import 'modelos.dart';
import 'motor.dart';
import 'textos.dart';
import 'widgets/cabecera_escena.dart';
import 'widgets/carta.dart';
import 'widgets/estilo.dart';
import 'widgets/piezas.dart';

/// Lo que se lee en voz alta al entrar en una escena: la narración y, si la hay, la pregunta.
String textoEscena(Escena escena) =>
    [escena.narracion, ?escena.decision?.pregunta].where((t) => t.trim().isNotEmpty).join(' ');

/// Lo que se lee al elegir una opción: si es correcta o no y la explicación.
String textoExplicacion(Opcion opcion) => '${opcion.correcta ? tituloAcierto : tituloFallo} ${opcion.feedback}';

/// Qué se está leyendo en voz alta.
enum _Lectura { narracion, explicacion }

/// Reproductor de un caso (sección 4.2): escena a escena, con su ilustración, sus personajes y la narración en voz
/// alta; las decisiones dan una explicación con su fuente y, si se acierta, una carta de derecho.
///
/// La voz: la narración se lee sola al entrar en cada escena si la voz está activada en Ajustes y no hay lector de
/// pantalla (que ya lee él). Se calla al elegir, al salir, al tapar la pantalla con otra y si la app pasa a segundo
/// plano. Los botones de «Escuchar» funcionan siempre, porque los pulsa quien juega.
class CasoScreen extends ConsumerStatefulWidget {
  const CasoScreen({super.key, required this.casoId});

  final String casoId;

  @override
  ConsumerState<CasoScreen> createState() => _CasoScreenState();
}

class _CasoScreenState extends ConsumerState<CasoScreen> {
  late final Tts _tts;
  late final AppLifecycleListener _ciclo;
  final _leyendo = ValueNotifier<_Lectura?>(null);

  /// Cambia con cada lectura: el final de una lectura antigua no borra el estado de la nueva.
  var _lecturas = 0;

  /// Escena que ya se ha leído sola («número:id»): no se repite al reconstruir.
  String? _escenaLeida;
  var _rutaActual = true;

  PartidaNotifier get _partida => ref.read(partidaProvider(widget.casoId).notifier);

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsProvider);
    _tts.hablando.addListener(_alCambiarHablando);
    // Si la app se oculta (otra app, la pantalla apagada o, en web, otra pestaña), se deja de leer.
    _ciclo = AppLifecycleListener(onHide: _callar, onPause: _callar);
    ref.listenManual(partidaProvider(widget.casoId), _alCambiarPartida, fireImmediately: true);
    // «Leer en voz alta» desactivado (aquí o en Ajustes) también calla lo que se esté leyendo.
    ref.listenManual(ajustesProvider.select((a) => a.vozActivada), (_, activada) {
      if (!activada) _callar();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Si otra pantalla o una hoja tapa el caso (Ayuda, Glosario, una carta…), se deja de leer.
    final actual = ModalRoute.isCurrentOf(context) ?? true;
    if (_rutaActual && !actual) _callar();
    _rutaActual = actual;
  }

  @override
  void dispose() {
    _tts.hablando.removeListener(_alCambiarHablando);
    _ciclo.dispose();
    if (_leyendo.value != null) unawaited(_tts.parar());
    _leyendo.dispose();
    super.dispose();
  }

  void _alCambiarHablando() {
    if (!_tts.hablando.value) _leyendo.value = null;
  }

  void _alCambiarPartida(AsyncValue<Partida>? _, AsyncValue<Partida> valor) {
    final partida = valor.value;
    if (partida == null) return;
    if (partida.terminada) {
      _escenaLeida = null;
      _callar();
      return;
    }
    final clave = '${partida.numeroEscena}:${partida.escena.id}';
    if (clave == _escenaLeida) return;
    _escenaLeida = clave;
    // Después del frame: hace falta el contexto para saber si hay lector de pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _escenaLeida == clave) _leerSiToca(textoEscena(partida.escena), _Lectura.narracion);
    });
  }

  /// Lectura automática: solo con la voz activada, sin lector de pantalla y con el caso a la vista.
  void _leerSiToca(String texto, _Lectura que) {
    final voz = ref.read(ajustesProvider).vozActivada;
    if (voz && _rutaActual && !MediaQuery.accessibleNavigationOf(context)) _leer(texto, que);
  }

  void _leer(String texto, _Lectura que) {
    final lectura = ++_lecturas;
    _leyendo.value = que;
    unawaited(
      _tts.hablar(textoParaVoz(texto), velocidad: ref.read(ajustesProvider).velocidadVoz).whenComplete(() {
        if (mounted && lectura == _lecturas) _leyendo.value = null;
      }),
    );
  }

  Future<void> _callar() async {
    _lecturas++;
    if (_leyendo.value == null && !_tts.hablando.value) return;
    _leyendo.value = null;
    await _tts.parar();
  }

  /// Botón «Escuchar» / «Parar».
  void _alternarLectura(String texto, _Lectura que) {
    Hapticos.seleccion();
    if (_leyendo.value == que && _tts.hablando.value) {
      _callar();
    } else {
      _leer(texto, que);
    }
  }

  Future<void> _elegir(int indice) async {
    unawaited(_callar());
    final guardado = _partida.elegir(indice);
    final opcion = ref.read(partidaProvider(widget.casoId)).value?.opcionElegida;
    if (opcion != null) {
      // Acertar se nota un poco más. Fallar, solo un toque suave: nada de «zumbido de error».
      unawaited(opcion.correcta ? Hapticos.acierto() : Hapticos.toque());
      _leerSiToca(textoExplicacion(opcion), _Lectura.explicacion);
    }
    await guardado;
  }

  void _reintentar() {
    Hapticos.seleccion();
    _callar();
    _partida.reintentar();
  }

  /// Pasa a la escena siguiente. Al terminar, la vibración llega con el sello del resumen.
  Future<void> _avanzar() async {
    Hapticos.toque();
    await _partida.avanzar();
  }

  /// Enseña la carta recién ganada y, al cerrarla, pasa a la escena siguiente.
  Future<void> _recogerCarta(Partida partida) async {
    final carta = partida.cartaNueva;
    if (carta == null) return _avanzar();
    final casos = ref.read(casosProvider).value ?? [partida.caso];
    await _callar();
    if (!mounted) return;
    await mostrarCartaNueva(context, carta: carta, indice: indiceEnColeccion(casos, carta.id), xp: xpPorCarta);
    if (mounted) await _avanzar();
  }

  Future<void> _reiniciar(Partida partida) async {
    if (partida.empezada && !partida.terminada) {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(dialogoReiniciarTitulo),
          content: const Text(dialogoReiniciarTexto),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text(cancelar)),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text(menuEmpezarDeNuevo)),
          ],
        ),
      );
      if (confirmado != true || !mounted) return;
    }
    Hapticos.toque();
    await _callar();
    _partida.reiniciar();
  }

  /// «Caso de Lucía». Con letra grande o en un móvil estrecho (menos de 400 dp), solo «Lucía»: la barra también lleva
  /// el menú, el Glosario y la Ayuda, y el título entero no cabría.
  static String _titulo(BuildContext context, String protagonista) {
    final grande = MediaQuery.textScalerOf(context).scale(1) > 1.15;
    final estrecho = MediaQuery.sizeOf(context).width < 400;
    return (grande || estrecho) && protagonista.isNotEmpty ? protagonista : tituloCaso(protagonista);
  }

  void _verCasos() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/juego');
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(partidaProvider(widget.casoId));
    final partida = estado.value;
    final terminos = terminosConVariantes([
      for (final e in ref.watch(glosarioProvider).value ?? const <EntradaGlosario>[]) e.termino,
    ]);
    return TuTurnoScaffold(
      titulo: partida == null ? tituloJuego : _titulo(context, partida.caso.protagonista),
      acciones: [if (partida != null) _MenuCaso(onReiniciar: () => _reiniciar(partida))],
      body: estado.when(
        skipLoadingOnReload: true,
        data: (partida) => _Contenido(
          partida: partida,
          terminos: terminos,
          leyendo: _leyendo,
          hablando: _tts.hablando,
          onElegir: _elegir,
          onAlternarLectura: _alternarLectura,
          onReiniciar: () => _reiniciar(partida),
          onVerCasos: _verCasos,
        ),
        error: (error, _) => error is CasoNoEncontrado
            ? EstadoVacio(
                icono: Icons.search_off_rounded,
                titulo: casoNoEncontradoTitulo,
                mensaje: casoNoEncontradoMensaje,
                accion: FilledButton(onPressed: _verCasos, child: const Text(botonVerCasos)),
              )
            : EstadoError(mensaje: errorCasos, onReintentar: () => ref.invalidate(casosProvider)),
        loading: () => const Cargando(mensaje: cargandoCaso),
      ),
      bottomNavigationBar: partida == null
          ? null
          : _BarraAcciones(
              partida: partida,
              onSeguir: _avanzar,
              onReintentar: _reintentar,
              onRecoger: () => _recogerCarta(partida),
            ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.partida,
    required this.terminos,
    required this.leyendo,
    required this.hablando,
    required this.onElegir,
    required this.onAlternarLectura,
    required this.onReiniciar,
    required this.onVerCasos,
  });

  final Partida partida;

  /// Términos del glosario que se subrayan (con sus variantes), cada uno con el término al que lleva.
  final Map<String, String> terminos;
  final ValueListenable<_Lectura?> leyendo;
  final ValueListenable<bool> hablando;
  final ValueChanged<int> onElegir;
  final void Function(String texto, _Lectura que) onAlternarLectura;
  final VoidCallback onReiniciar;
  final VoidCallback onVerCasos;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!partida.terminada)
          Padding(
            padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.m, 0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: anchoMaximo),
                child: ProgresoEscenas(actual: partida.numeroEscena, total: partida.totalEscenas),
              ),
            ),
          ),
        Expanded(
          child: AnimatedSwitcher(
            duration: duracion(context, Duracion.larga),
            transitionBuilder: (child, animacion) => _CambioEscena(animacion: animacion, child: child),
            layoutBuilder: (actual, anteriores) =>
                Stack(alignment: Alignment.topCenter, children: [...anteriores, ?actual]),
            child: partida.terminada
                ? _Resumen(
                    key: const ValueKey('fin'),
                    partida: partida,
                    onReiniciar: onReiniciar,
                    onVerCasos: onVerCasos,
                  )
                : _VistaEscena(
                    key: ValueKey('${partida.numeroEscena}:${partida.escena.id}'),
                    partida: partida,
                    terminos: terminos,
                    leyendo: leyendo,
                    hablando: hablando,
                    onElegir: onElegir,
                    onAlternarLectura: onAlternarLectura,
                  ),
          ),
        ),
      ],
    );
  }
}

/// Cambio de escena como pasar una página: la nueva entra desde la derecha y la anterior sale hacia la izquierda.
class _CambioEscena extends AnimatedWidget {
  const _CambioEscena({required Animation<double> animacion, required this.child}) : super(listenable: animacion);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animacion = listenable as Animation<double>;
    final avance = Curves.easeOutCubic.transform(animacion.value);
    final saliendo = animacion.status == AnimationStatus.reverse;
    return FadeTransition(
      opacity: animacion,
      child: Transform.translate(offset: Offset((1 - avance) * Espacio.xxl * (saliendo ? -1 : 1), 0), child: child),
    );
  }
}

class _VistaEscena extends StatefulWidget {
  const _VistaEscena({
    super.key,
    required this.partida,
    required this.terminos,
    required this.leyendo,
    required this.hablando,
    required this.onElegir,
    required this.onAlternarLectura,
  });

  final Partida partida;

  /// Términos del glosario que se subrayan (con sus variantes), cada uno con el término al que lleva.
  final Map<String, String> terminos;
  final ValueListenable<_Lectura?> leyendo;
  final ValueListenable<bool> hablando;
  final ValueChanged<int> onElegir;
  final void Function(String texto, _Lectura que) onAlternarLectura;

  @override
  State<_VistaEscena> createState() => _VistaEscenaState();
}

class _VistaEscenaState extends State<_VistaEscena> {
  final _scroll = ScrollController();
  final _claveExplicacion = GlobalKey();

  @override
  void didUpdateWidget(_VistaEscena anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.partida.eleccion == null && widget.partida.eleccion != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _mostrarExplicacion());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Desplaza lo justo para que se vea la explicación entera, sin que su principio se salga por arriba.
  void _mostrarExplicacion() {
    final caja = _claveExplicacion.currentContext?.findRenderObject();
    if (!mounted || caja == null || !_scroll.hasClients) return;
    final vista = RenderAbstractViewport.maybeOf(caja);
    if (vista == null) return;
    final arriba = vista.getOffsetToReveal(caja, 0).offset - Espacio.m;
    final abajo = vista.getOffsetToReveal(caja, 1).offset + Espacio.m;
    final posicion = _scroll.position;
    final destino = math.min(arriba, math.max(posicion.pixels, abajo)).clamp(0.0, posicion.maxScrollExtent);
    if ((destino - posicion.pixels).abs() < 1) return;
    final tiempo = duracion(context, Duracion.larga);
    if (tiempo == Duration.zero) {
      _scroll.jumpTo(destino);
    } else {
      _scroll.animateTo(destino, duration: tiempo, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final partida = widget.partida;
    final escena = partida.escena;
    final decision = escena.decision;
    var orden = 0;
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.m, Espacio.m, Espacio.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: anchoMaximo),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // El hueco de la ilustración (lo sustituirán las escenas en pixel art): lugar y personajes.
              CabeceraEscena(escena: escena, protagonista: partida.caso.protagonista),
              const SizedBox(height: Espacio.m),
              Entrada(
                orden: orden++,
                child: _EscuchaLectura(
                  leyendo: widget.leyendo,
                  hablando: widget.hablando,
                  que: _Lectura.narracion,
                  builder: (leyendo) => _Narracion(
                    texto: escena.narracion,
                    terminos: widget.terminos,
                    leyendo: leyendo,
                    onAlternar: () => widget.onAlternarLectura(textoEscena(escena), _Lectura.narracion),
                  ),
                ),
              ),
              if (decision != null) ...[
                const SizedBox(height: Espacio.l),
                Entrada(
                  orden: orden++,
                  child: _Decision(
                    partida: partida,
                    claveExplicacion: _claveExplicacion,
                    leyendo: widget.leyendo,
                    hablando: widget.hablando,
                    onElegir: widget.onElegir,
                    onAlternarLectura: widget.onAlternarLectura,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Reconstruye [builder] con true mientras se está leyendo [que].
class _EscuchaLectura extends StatelessWidget {
  const _EscuchaLectura({required this.leyendo, required this.hablando, required this.que, required this.builder});

  final ValueListenable<_Lectura?> leyendo;
  final ValueListenable<bool> hablando;
  final _Lectura que;
  final Widget Function(bool leyendo) builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([leyendo, hablando]),
      builder: (context, _) => builder(hablando.value && leyendo.value == que),
    );
  }
}

class _Narracion extends StatelessWidget {
  const _Narracion({required this.texto, required this.terminos, required this.leyendo, required this.onAlternar});

  final String texto;

  /// Términos del glosario que se subrayan (con sus variantes), cada uno con el término al que lleva.
  final Map<String, String> terminos;
  final bool leyendo;
  final VoidCallback onAlternar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: esquema.surfaceContainerLow, borderRadius: BorderRadius.circular(Radios.l)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Espacio.l, Espacio.l, Espacio.l, Espacio.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextoConTerminos(
              texto: texto,
              terminos: terminos.keys.toList(),
              onTermino: (termino) =>
                  context.push(Uri(path: '/glosario', queryParameters: {'q': terminos[termino] ?? termino}).toString()),
              style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurface, height: 1.5),
            ),
            const SizedBox(height: Espacio.s + Espacio.xs),
            _BotonLectura(leyendo: leyendo, onPressed: onAlternar, que: 'la narración'),
          ],
        ),
      ),
    );
  }
}

class _BotonLectura extends StatelessWidget {
  const _BotonLectura({required this.leyendo, required this.onPressed, required this.que});

  final bool leyendo;
  final VoidCallback onPressed;

  /// «la narración»: para la ayuda del lector de pantalla.
  final String que;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: leyendo ? 'Parar la lectura' : 'Escuchar $que',
      child: FilledButton.tonalIcon(
        key: const Key('boton-escuchar'),
        onPressed: onPressed,
        icon: AnimatedSwitcher(
          duration: duracion(context, Duracion.corta),
          child: Icon(leyendo ? Icons.stop_rounded : Icons.volume_up_rounded, key: ValueKey(leyendo)),
        ),
        label: Text(leyendo ? botonParar : botonEscuchar),
      ),
    );
  }
}

enum _EstadoOpcion { libre, acierto, fallo, apagada }

class _Decision extends StatelessWidget {
  const _Decision({
    required this.partida,
    required this.claveExplicacion,
    required this.leyendo,
    required this.hablando,
    required this.onElegir,
    required this.onAlternarLectura,
  });

  final Partida partida;
  final GlobalKey claveExplicacion;
  final ValueListenable<_Lectura?> leyendo;
  final ValueListenable<bool> hablando;
  final ValueChanged<int> onElegir;
  final void Function(String texto, _Lectura que) onAlternarLectura;

  static const _letras = 'ABCDEFGH';

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final decision = partida.decision!;
    final eleccion = partida.eleccion;
    final opcion = partida.opcionElegida;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ExcludeSemantics(
              child: Icon(Icons.alt_route_rounded, size: Espacio.l - Espacio.xs, color: esquema.primary),
            ),
            const SizedBox(width: Espacio.xs + 2),
            Text(
              tuDecides,
              style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: Espacio.xs + 2),
        Semantics(
          header: true,
          child: Text(decision.pregunta, style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: Espacio.m),
        for (var i = 0; i < decision.opciones.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Espacio.s + Espacio.xs),
            child: _BotonOpcion(
              letra: _letras[i % _letras.length],
              texto: decision.opciones[i].texto,
              estado: switch (eleccion) {
                null => _EstadoOpcion.libre,
                final e when e == i => decision.opciones[i].correcta ? _EstadoOpcion.acierto : _EstadoOpcion.fallo,
                _ => _EstadoOpcion.apagada,
              },
              onTap: eleccion == null ? () => onElegir(i) : null,
            ),
          ),
        if (opcion != null)
          _EscuchaLectura(
            leyendo: leyendo,
            hablando: hablando,
            que: _Lectura.explicacion,
            builder: (leyendo) => _Explicacion(
              key: claveExplicacion,
              partida: partida,
              opcion: opcion,
              leyendo: leyendo,
              onAlternar: () => onAlternarLectura(textoExplicacion(opcion), _Lectura.explicacion),
            ),
          ),
      ],
    );
  }
}

class _BotonOpcion extends StatefulWidget {
  const _BotonOpcion({required this.letra, required this.texto, required this.estado, this.onTap});

  final String letra;
  final String texto;
  final _EstadoOpcion estado;
  final VoidCallback? onTap;

  @override
  State<_BotonOpcion> createState() => _BotonOpcionState();
}

class _BotonOpcionState extends State<_BotonOpcion> {
  var _pulsado = false;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final exito = context.colores.exito;
    final fallo = esquema.tertiary;
    final (fondo, borde, grosor) = switch (widget.estado) {
      _EstadoOpcion.acierto => (tinte(context, exito), exito, 2.5),
      _EstadoOpcion.fallo => (tinte(context, fallo), fallo, 2.5),
      _ => (esquema.surfaceContainerLow, esquema.outlineVariant, 1.5),
    };
    final forma = BorderRadius.circular(Radios.m);
    final resultado = switch (widget.estado) {
      _EstadoOpcion.acierto => '. Correcta',
      _EstadoOpcion.fallo => '. No es la correcta',
      _ => '',
    };
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      selected: widget.estado == _EstadoOpcion.acierto || widget.estado == _EstadoOpcion.fallo,
      label: 'Opción ${widget.letra}: ${widget.texto}$resultado',
      excludeSemantics: true,
      onTap: widget.onTap,
      child: AnimatedOpacity(
        opacity: widget.estado == _EstadoOpcion.apagada ? 0.45 : 1,
        duration: duracion(context, Duracion.media),
        child: AnimatedScale(
          scale: _pulsado ? 0.97 : 1,
          duration: duracion(context, Duracion.corta),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: duracion(context, Duracion.media),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: forma,
              border: Border.all(color: borde, width: grosor),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: forma,
                onTap: widget.onTap,
                onHighlightChanged: (pulsado) => setState(() => _pulsado = pulsado),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Espacio.m, vertical: Espacio.s + Espacio.xs),
                    child: Row(
                      children: [
                        _InsigniaOpcion(letra: widget.letra, estado: widget.estado),
                        const SizedBox(width: Espacio.m),
                        Expanded(
                          child: Text(
                            widget.texto,
                            style: tema.textTheme.titleMedium?.copyWith(
                              color: esquema.onSurface,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InsigniaOpcion extends StatelessWidget {
  const _InsigniaOpcion({required this.letra, required this.estado});

  final String letra;
  final _EstadoOpcion estado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final exito = context.colores.exito;
    final Widget contenido = switch (estado) {
      _EstadoOpcion.acierto => _Disco(
        key: const ValueKey('acierto'),
        color: exito,
        child: Icon(Icons.check_rounded, color: context.colores.sobreExito),
      ),
      _EstadoOpcion.fallo => _Disco(
        key: const ValueKey('fallo'),
        color: esquema.tertiary,
        child: Icon(Icons.lightbulb_rounded, color: esquema.onTertiary),
      ),
      _ => _Disco(
        key: const ValueKey('letra'),
        color: tinte(context, esquema.primary),
        borde: bordeTinte(esquema.primary),
        child: Text(
          letra,
          style: tema.textTheme.titleMedium?.copyWith(color: esquema.primary, fontWeight: FontWeight.w700),
          textScaler: TextScaler.noScaling,
        ),
      ),
    };
    return AnimatedSwitcher(
      duration: duracion(context, Duracion.media),
      transitionBuilder: (child, animacion) => ScaleTransition(
        scale: animacion.drive(CurveTween(curve: Curves.easeOutBack)),
        child: FadeTransition(opacity: animacion, child: child),
      ),
      child: contenido,
    );
  }
}

class _Disco extends StatelessWidget {
  const _Disco({super.key, required this.color, required this.child, this.borde});

  final Color color;
  final Color? borde;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: borde == null ? null : Border.all(color: borde!, width: 1.5),
      ),
      child: child,
    );
  }
}

/// Explicación tras elegir: si es correcta o no, por qué y de qué ley sale. Avisa si hay carta.
class _Explicacion extends ConsumerWidget {
  const _Explicacion({
    super.key,
    required this.partida,
    required this.opcion,
    required this.leyendo,
    required this.onAlternar,
  });

  final Partida partida;
  final Opcion opcion;
  final bool leyendo;
  final VoidCallback onAlternar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final acierto = opcion.correcta;
    final color = acierto ? context.colores.exito : esquema.tertiary;
    final coleccion = ref.watch(progresoProvider.select((p) => p.cartas));
    final elegida = opcion.carta;
    // Otra respuesta correcta de esta escena da una carta que aún no se tiene: se puede volver a buscarla.
    final hayOtraCarta =
        acierto &&
        partida.decision!.opciones.any(
          (o) => o.correcta && o.carta != null && o.carta != elegida && !coleccion.contains(o.carta),
        );
    return _Aparicion(
      child: Semantics(
        container: true,
        liveRegion: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tinte(context, color),
            borderRadius: BorderRadius.circular(Radios.l),
            border: Border.all(color: bordeTinte(color), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Espacio.m + Espacio.xs, Espacio.s, Espacio.s, Espacio.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        acierto ? Icons.check_circle_rounded : Icons.lightbulb_rounded,
                        color: color,
                        size: Espacio.l + Espacio.xs,
                      ),
                    ),
                    const SizedBox(width: Espacio.s + Espacio.xs),
                    Expanded(
                      child: Text(
                        acierto ? tituloAcierto : tituloFallo,
                        style: tema.textTheme.titleLarge?.copyWith(
                          color: esquema.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: leyendo ? 'Parar la lectura' : 'Escuchar la explicación',
                      onPressed: onAlternar,
                      icon: Icon(leyendo ? Icons.stop_rounded : Icons.volume_up_rounded),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: Espacio.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opcion.feedback,
                        style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurface, height: 1.45),
                      ),
                      if (opcion.fuente.isNotEmpty) ...[
                        const SizedBox(height: Espacio.xs),
                        FuenteLegal(fuente: opcion.fuente),
                      ],
                      if (partida.cartaNueva != null)
                        const _Aviso(icono: Icons.style_rounded, texto: avisoCartaNueva, destacado: true)
                      else if (partida.cartaDeLaEleccion != null)
                        const _Aviso(icono: Icons.collections_bookmark_rounded, texto: avisoCartaRepetida),
                      if (hayOtraCarta) const _Aviso(icono: Icons.travel_explore_rounded, texto: pistaOtraCarta),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Entra con un fundido y subiendo un poco. Ocupa su tamaño desde el principio (así se puede desplazar hasta ella).
class _Aparicion extends StatelessWidget {
  const _Aparicion({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duracion(context, Duracion.media),
      curve: Curves.easeOutCubic,
      builder: (context, valor, child) => Opacity(
        opacity: valor,
        child: Transform.translate(offset: Offset(0, (1 - valor) * Espacio.l), child: child),
      ),
      child: child,
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.texto, this.destacado = false});

  final IconData icono;
  final String texto;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: Espacio.s),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: destacado ? esquema.primaryContainer : esquema.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(Radios.s),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Espacio.s + Espacio.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  icono,
                  size: Espacio.l - Espacio.xs,
                  color: destacado ? esquema.onPrimaryContainer : esquema.primary,
                ),
              ),
              const SizedBox(width: Espacio.s),
              Expanded(
                child: Text(
                  texto,
                  style: tema.textTheme.bodyMedium?.copyWith(
                    color: destacado ? esquema.onPrimaryContainer : esquema.onSurface,
                    fontWeight: destacado ? FontWeight.w700 : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botones de abajo: «Seguir», «Recoger tu carta», «Probar otra vez» o «Terminar el caso». Mientras hay una
/// decisión sin tomar, no hay botón: se elige arriba.
class _BarraAcciones extends StatelessWidget {
  const _BarraAcciones({
    required this.partida,
    required this.onSeguir,
    required this.onReintentar,
    required this.onRecoger,
  });

  final Partida partida;
  final VoidCallback onSeguir;
  final VoidCallback onReintentar;
  final VoidCallback onRecoger;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final grande = MediaQuery.textScalerOf(context).scale(1) > 1.15;
    final seguir = FilledButton.icon(
      onPressed: onSeguir,
      icon: Icon(partida.alAvanzarTermina ? Icons.flag_rounded : Icons.arrow_forward_rounded),
      label: Text(partida.alAvanzarTermina ? botonTerminar : botonSeguir),
    );
    final (String clave, Widget? contenido) = switch (partida) {
      Partida(terminada: true) || Partida(puedeAvanzar: false) => ('nada', null),
      Partida(cartaNueva: _?) => (
        'recoger',
        FilledButton.icon(
          onPressed: onRecoger,
          icon: const Icon(Icons.style_rounded),
          label: const Text(botonRecogerCarta),
        ),
      ),
      Partida(decision: _?, acierto: false) => (
        'reintentar',
        Flex(
          direction: grande ? Axis.vertical : Axis.horizontal,
          // En fila, estirar haría los botones tan altos como la pantalla.
          crossAxisAlignment: grande ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (grande)
              OutlinedButton.icon(
                onPressed: onReintentar,
                icon: const Icon(Icons.replay_rounded),
                label: const Text(botonProbarOtraVez),
              )
            else
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReintentar,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text(botonProbarOtraVez),
                ),
              ),
            const SizedBox(width: Espacio.s + Espacio.xs, height: Espacio.s),
            seguir,
          ],
        ),
      ),
      _ => (partida.alAvanzarTermina ? 'terminar' : 'seguir', seguir),
    };
    return AnimatedSwitcher(
      duration: duracion(context, Duracion.media),
      transitionBuilder: (child, animacion) => FadeTransition(
        opacity: animacion,
        child: SlideTransition(
          position: animacion.drive(
            Tween(begin: const Offset(0, 0.25), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic)),
          ),
          child: child,
        ),
      ),
      child: contenido == null
          ? const SizedBox.shrink(key: ValueKey('nada'))
          : DecoratedBox(
              key: ValueKey(clave),
              decoration: BoxDecoration(
                color: esquema.surface,
                border: Border(top: BorderSide(color: esquema.outlineVariant)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Espacio.m,
                    Espacio.s + Espacio.xs,
                    Espacio.m,
                    Espacio.s + Espacio.xs,
                  ),
                  child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: anchoMaximo),
                      child: contenido,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _MenuCaso extends ConsumerWidget {
  const _MenuCaso({required this.onReiniciar});

  final VoidCallback onReiniciar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voz = ref.watch(ajustesProvider.select((a) => a.vozActivada));
    return PopupMenuButton<String>(
      tooltip: 'Más opciones',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (valor) {
        Hapticos.seleccion();
        switch (valor) {
          case 'voz':
            ref.read(ajustesProvider.notifier).actualizar((a) => a.copyWith(vozActivada: !a.vozActivada));
          case 'reiniciar':
            onReiniciar();
        }
      },
      itemBuilder: (context) => [
        CheckedPopupMenuItem(value: 'voz', checked: voz, child: const Text(menuLeerEnVozAlta)),
        const PopupMenuItem(
          value: 'reiniciar',
          child: ListTile(
            leading: Icon(Icons.replay_rounded),
            title: Text(menuEmpezarDeNuevo),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

/// Pantalla final: las cartas del caso, lo que falta por descubrir y adónde seguir.
class _Resumen extends ConsumerWidget {
  const _Resumen({super.key, required this.partida, required this.onReiniciar, required this.onVerCasos});

  final Partida partida;
  final VoidCallback onReiniciar;
  final VoidCallback onVerCasos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final caso = partida.caso;
    final tenidas = ref.watch(progresoProvider.select((p) => p.cartas));
    final casos = ref.watch(casosProvider).value ?? [caso];
    final conseguidas = caso.cartas.where((c) => tenidas.contains(c.id)).length;
    final faltan = caso.cartas.length - conseguidas;
    var orden = 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.l, Espacio.m, Espacio.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: anchoMaximo),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SelloFinal(protagonista: caso.protagonista),
              const SizedBox(height: Espacio.m),
              Entrada(
                orden: orden++,
                child: Semantics(
                  header: true,
                  child: Text(
                    tituloFinal,
                    textAlign: TextAlign.center,
                    style: tema.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: Espacio.s),
              Entrada(
                orden: orden++,
                child: Text(
                  textoFinal(caso.protagonista),
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: Espacio.l),
              Entrada(
                orden: orden++,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _Marcador(
                          icono: Icons.style_rounded,
                          valor: '$conseguidas/${caso.cartas.length}',
                          etiqueta: 'cartas de este caso',
                        ),
                      ),
                      const SizedBox(width: Espacio.m),
                      Expanded(
                        child: _Marcador(
                          icono: Icons.alt_route_rounded,
                          valor: '${caso.decisiones}',
                          etiqueta: caso.decisiones == 1 ? 'decisión tomada' : 'decisiones tomadas',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (caso.cartas.isNotEmpty) ...[
                const SizedBox(height: Espacio.l),
                Entrada(orden: orden++, child: const _TituloSeccion(tituloCartasDelCaso)),
                const SizedBox(height: Espacio.m),
                Entrada(
                  orden: orden++,
                  child: RejillaCartas(
                    hijos: [
                      for (final carta in caso.cartas)
                        if (tenidas.contains(carta.id))
                          CartaTocable(carta: carta, indice: indiceEnColeccion(casos, carta.id))
                        else
                          const CartaBloqueada(pista: 'Vuelve a jugar para encontrarla'),
                    ],
                  ),
                ),
                if (faltan > 0)
                  Entrada(
                    orden: orden++,
                    child: _Aviso(icono: Icons.travel_explore_rounded, texto: textoCartasQueFaltan(faltan)),
                  ),
              ],
              const SizedBox(height: Espacio.l),
              Entrada(orden: orden++, child: const _TituloSeccion(tituloYAhora)),
              const SizedBox(height: Espacio.m),
              Entrada(
                orden: orden++,
                child: _AccesoModulo(
                  colores: context.colores.aprende,
                  icono: Icons.school_rounded,
                  titulo: accesoAprende,
                  texto: accesoAprendeTexto,
                  onTap: () => context.push('/aprende'),
                ),
              ),
              const SizedBox(height: Espacio.m),
              Entrada(
                orden: orden++,
                child: _AccesoModulo(
                  colores: context.colores.pregunta,
                  icono: Icons.record_voice_over_rounded,
                  titulo: accesoPregunta,
                  texto: accesoPreguntaTexto,
                  onTap: () => context.push('/pregunta'),
                ),
              ),
              const SizedBox(height: Espacio.l),
              Entrada(
                orden: orden++,
                child: OutlinedButton.icon(
                  onPressed: onReiniciar,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text(botonVolverAJugar),
                ),
              ),
              const SizedBox(height: Espacio.s),
              Entrada(
                orden: orden++,
                child: TextButton(onPressed: onVerCasos, child: const Text(botonVerCasos)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carta de la colección que se abre en grande al tocarla.
class CartaTocable extends StatelessWidget {
  const CartaTocable({super.key, required this.carta, required this.indice});

  final Carta carta;
  final int indice;

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(Radios.l);
    return Semantics(
      button: true,
      hint: 'Toca para verla en grande',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: forma,
          onTap: () {
            Hapticos.seleccion();
            mostrarDetalleCarta(context, carta: carta, indice: indice);
          },
          child: CartaDerecho(carta: carta, indice: indice),
        ),
      ),
    );
  }
}

/// Sello de «caso completado»: cae una vez sobre el papel, vibra y suelta un poco de confeti. Con «reducir
/// animaciones», aparece ya puesto y sin confeti.
class _SelloFinal extends StatelessWidget {
  const _SelloFinal({required this.protagonista});

  final String protagonista;

  @override
  Widget build(BuildContext context) {
    final alrededor = protagonista.isEmpty ? 'VIVE EL CASO' : 'CASO DE ${protagonista.toUpperCase()}';
    return Center(
      child: SelloAnimado(
        retraso: Duracion.media,
        vibrar: false,
        alEstampar: () {
          if (!context.mounted) return;
          Hapticos.acierto();
          lanzarConfeti(context, origen: const Alignment(0, -0.5), cantidad: 40);
        },
        child: Sello(
          texto: 'Hecho',
          icono: Icons.check_rounded,
          textoCircular: '$alrededor · COMPLETADO · ',
          tamano: 136,
          semanticLabel: 'Sello de caso completado',
        ),
      ),
    );
  }
}

class _Marcador extends StatelessWidget {
  const _Marcador({required this.icono, required this.valor, required this.etiqueta});

  final IconData icono;
  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return MergeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(color: esquema.surfaceContainerLow, borderRadius: BorderRadius.circular(Radios.l)),
        child: Padding(
          padding: const EdgeInsets.all(Espacio.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: Icon(icono, color: esquema.primary)),
              const SizedBox(height: Espacio.s),
              Text(valor, style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text(etiqueta, style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(texto, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

class _AccesoModulo extends StatelessWidget {
  const _AccesoModulo({
    required this.colores,
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.onTap,
  });

  final List<Color> colores;
  final IconData icono;
  final String titulo;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Pulsable(
          onTap: onTap,
          decoracion: BoxDecoration(
            color: esquema.surfaceContainerLow,
            borderRadius: BorderRadius.circular(Radios.l),
            border: Border.all(color: esquema.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Espacio.m),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: Espacio.xxl + Espacio.s,
                    height: Espacio.xxl + Espacio.s,
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: degradadoDiagonal(colores)),
                    child: Icon(icono, color: tintaSobre(context, colores)),
                  ),
                ),
                const SizedBox(width: Espacio.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: Espacio.xs / 2),
                      Text(texto, style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
                    ],
                  ),
                ),
                ExcludeSemantics(child: Icon(Icons.chevron_right_rounded, color: esquema.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
