import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/content_models.dart';
import '../../core/demo.dart';
import '../../core/progreso.dart';
import '../../core/providers.dart';
import '../../core/voz/tts.dart';
import '../../pixel/ui/ui.dart';
import '../../tema.dart';
import '../../widgets/ayuda_button.dart';
import '../../widgets/modulos.dart' show anchoMaximo;
import '../../widgets/movimiento/hapticos.dart';
import 'juego_providers.dart';
import 'modelos.dart';
import 'motor.dart';
import 'textos.dart';
import 'widgets/carta.dart';
import 'widgets/escena_juego.dart';
import 'widgets/estilo.dart';
import 'widgets/final_caso.dart';
import 'widgets/piezas_pixel.dart';

export 'widgets/escena_juego.dart' show LecturaCaso, textoEscena, textoExplicacion;

/// Reproductor de un caso (sección 4.2), en pixel art: Vive el caso es un mundo de juego retro dentro de la app.
///
/// Arriba, el HUD del juego (volver, el nombre de la protagonista, Glosario y Ayuda, el progreso y las cartas del caso).
/// Debajo, escena a escena: el lugar y quién sale en pixel art, la narración en una ventana de diálogo letra a letra
/// (al ritmo de la voz), la decisión («Tu turno») con su explicación y su fuente, y las cartas de derecho que se ganan
/// al acertar. Al final, el sello «COMPLETADO» y el siguiente caso. Entre escenas, la transición a bloques del kit.
///
/// La voz: la narración se lee sola al entrar en cada escena si la voz está activada en Ajustes y no hay lector de
/// pantalla (que ya lee él). Se calla al elegir, al salir, al tapar la pantalla con otra y si la app pasa a segundo
/// plano. Los botones de «Escuchar» funcionan siempre, porque los pulsa quien juega.
///
/// El atajo de la demo (`escenaInicialProvider`, desde Ajustes): si hay una escena pendiente para este caso, la partida
/// empieza en ella (Lucía en la Sala Gesell, S5).
class CasoScreen extends ConsumerStatefulWidget {
  const CasoScreen({super.key, required this.casoId});

  final String casoId;

  @override
  ConsumerState<CasoScreen> createState() => _CasoScreenState();
}

class _CasoScreenState extends ConsumerState<CasoScreen> {
  late final Tts _tts;
  late final AppLifecycleListener _ciclo;
  final _leyendo = ValueNotifier<LecturaCaso?>(null);

  /// Cambia con cada lectura: el final de una lectura antigua no borra el estado de la nueva.
  var _lecturas = 0;

  /// Escena que ya se ha leído sola («número:id»): no se repite al reconstruir.
  String? _escenaLeida;
  var _rutaActual = true;

  /// La escena del atajo de la demo, mientras la partida se pone en ella (se ve «Preparando la sala…»).
  String? _escenaInicial;

  /// El diálogo de la escena que se ve: al acabar de leer la narración, se completa.
  ControladorDialogoPixel? _dialogo;

  PartidaNotifier get _partida => ref.read(partidaProvider(widget.casoId).notifier);

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsProvider);
    _tts.hablando.addListener(_alCambiarHablando);
    // Si la app se oculta (otra app, la pantalla apagada o, en web, otra pestaña), se deja de leer.
    _ciclo = AppLifecycleListener(onHide: _callar, onPause: _callar);
    _escenaInicial = ref.read(escenaInicialProvider.notifier).consumir(widget.casoId);
    if (_escenaInicial != null) WidgetsBinding.instance.addPostFrameCallback((_) => _empezarEnEscenaInicial());
    ref.listenManual(partidaProvider(widget.casoId), _alCambiarPartida, fireImmediately: true);
    // «Leer en voz alta» desactivado (aquí o en Ajustes) también calla lo que se esté leyendo.
    ref.listenManual(ajustesProvider.select((a) => a.vozActivada), (_, activada) {
      if (!activada) _callar();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Si otra pantalla o una ventana tapa el caso (Ayuda, Glosario, una carta…), se deja de leer.
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

  Future<void> _empezarEnEscenaInicial() async {
    final escena = _escenaInicial;
    if (escena == null || !mounted) return;
    await _partida.empezarEn(escena);
    if (!mounted) return;
    setState(() => _escenaInicial = null);
    // La escena del atajo se lee como cualquier otra al entrar.
    _alCambiarPartida(null, ref.read(partidaProvider(widget.casoId)));
  }

  void _alCambiarHablando() {
    if (!_tts.hablando.value) _leyendo.value = null;
  }

  void _alCambiarPartida(AsyncValue<Partida>? _, AsyncValue<Partida> valor) {
    final partida = valor.value;
    if (partida == null || _escenaInicial != null) return;
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
      if (mounted && _escenaLeida == clave) _leerSiToca(textoEscena(partida.escena), LecturaCaso.narracion);
    });
  }

  /// Lectura automática: solo con la voz activada, sin lector de pantalla y con el caso a la vista.
  void _leerSiToca(String texto, LecturaCaso que) {
    final voz = ref.read(ajustesProvider).vozActivada;
    if (voz && _rutaActual && !MediaQuery.accessibleNavigationOf(context)) _leer(texto, que);
  }

  void _leer(String texto, LecturaCaso que) {
    final lectura = ++_lecturas;
    _leyendo.value = que;
    unawaited(
      _tts.hablar(textoParaVoz(texto), velocidad: ref.read(ajustesProvider).velocidadVoz).whenComplete(() {
        // Si ya se está leyendo otra cosa (la narración de la escena siguiente, por ejemplo) o se ha callado, nada.
        if (!mounted || lectura != _lecturas) return;
        // La voz ha terminado la narración (o no ha podido leerla): el texto se ve entero.
        if (que == LecturaCaso.narracion) _dialogo?.mostrarTodo();
        _leyendo.value = null;
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
  void _alternarLectura(String texto, LecturaCaso que) {
    Hapticos.seleccion();
    if (_leyendo.value == que && _tts.hablando.value) {
      _callar();
    } else {
      _leer(texto, que);
    }
  }

  void _registrarDialogo(ControladorDialogoPixel dialogo, {required bool activo}) {
    if (activo) {
      _dialogo = dialogo;
    } else if (identical(_dialogo, dialogo)) {
      _dialogo = null;
    }
  }

  Future<void> _elegir(int indice) async {
    unawaited(_callar());
    final guardado = _partida.elegir(indice);
    final opcion = ref.read(partidaProvider(widget.casoId)).value?.opcionElegida;
    // El menú ya vibra al acertar; al fallar, nada de «zumbido de error».
    if (opcion != null) _leerSiToca(textoExplicacion(opcion), LecturaCaso.explicacion);
    await guardado;
  }

  void _reintentar() {
    Hapticos.seleccion();
    _callar();
    _partida.reintentar();
  }

  /// Pasa a la escena siguiente. Al terminar, la vibración llega con el golpe del sello.
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
    await mostrarCartaNueva(
      context,
      carta: carta,
      indice: indiceEnColeccion(casos, carta.id),
      xp: xpPorCarta,
      lecturaFacil: ref.read(ajustesProvider).lecturaFacil,
    );
    if (mounted) await _avanzar();
  }

  Future<void> _reiniciar(Partida partida) async {
    if (partida.empezada && !partida.terminada) {
      final confirmado = await confirmarPixel(
        context,
        titulo: dialogoReiniciarTitulo,
        texto: dialogoReiniciarTexto,
        si: menuEmpezarDeNuevo,
        lecturaFacil: ref.read(ajustesProvider).lecturaFacil,
      );
      if (!confirmado || !mounted) return;
    }
    Hapticos.toque();
    await _callar();
    _partida.reiniciar();
  }

  Future<void> _abrirOpciones(Partida partida) async {
    Hapticos.seleccion();
    final voz = ref.read(ajustesProvider).vozActivada;
    final eleccion = await mostrarVentanaPixel<String>(
      context,
      lecturaFacil: ref.read(ajustesProvider).lecturaFacil,
      (context) => VentanaPixel(
        titulo: menuOpciones,
        botones: [
          BotonPixel(
            etiqueta: voz ? '$menuLeerEnVozAlta: sí' : '$menuLeerEnVozAlta: no',
            semantica: voz
                ? '$menuLeerEnVozAlta: activado. Toca para quitarlo'
                : '$menuLeerEnVozAlta: desactivado. '
                      'Toca para activarlo',
            icono: IconoPixel(voz ? GlifoPixel.altavoz : GlifoPixel.parar),
            variante: VarianteBotonPixel.secundario,
            expandido: true,
            onPressed: () => Navigator.of(context).pop('voz'),
          ),
          BotonPixel(
            etiqueta: menuEmpezarDeNuevo,
            variante: VarianteBotonPixel.secundario,
            expandido: true,
            onPressed: () => Navigator.of(context).pop('reiniciar'),
          ),
          BotonPixel(etiqueta: 'Cerrar', expandido: true, onPressed: () => Navigator.of(context).pop()),
        ],
        children: const [],
      ),
    );
    if (!mounted) return;
    switch (eleccion) {
      case 'voz':
        await ref.read(ajustesProvider.notifier).actualizar((a) => a.copyWith(vozActivada: !a.vozActivada));
      case 'reiniciar':
        await _reiniciar(partida);
    }
  }

  void _verCasos() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/juego');
    }
  }

  /// Abre el siguiente caso de la lista, desde el principio si ya se había terminado.
  void _siguienteCaso(Caso siguiente) {
    Hapticos.toque();
    unawaited(_callar());
    final partida = ref.read(partidaProvider(siguiente.id)).value;
    if (partida != null && partida.terminada) ref.read(partidaProvider(siguiente.id).notifier).reiniciar();
    context.go('/juego/${siguiente.id}');
  }

  void _abrirGlosario(String termino) {
    Hapticos.seleccion();
    context.push(Uri(path: '/glosario', queryParameters: {'q': termino}).toString());
  }

  @override
  Widget build(BuildContext context) {
    final lecturaFacil = ref.watch(ajustesProvider.select((a) => a.lecturaFacil));
    // Un TemaPixel propio (además del de la app): la letra del juego y su scroll, sin el estirado de Android.
    return TemaPixel(
      lecturaFacil: lecturaFacil,
      child: Builder(builder: _pantalla),
    );
  }

  Widget _pantalla(BuildContext context) {
    final estado = ref.watch(partidaProvider(widget.casoId));
    final esperando = _escenaInicial != null;
    final partida = esperando ? null : estado.value;
    final ajustes = ref.watch(ajustesProvider);
    final tenidas = ref.watch(progresoProvider.select((p) => p.cartas));
    final terminos = terminosConVariantes([
      for (final e in ref.watch(glosarioProvider).value ?? const <EntradaGlosario>[]) e.termino,
    ]);
    final lector = MediaQuery.accessibleNavigationOf(context);
    final letras = lector
        ? 0.0
        : (ajustes.vozActivada ? letrasPorSegundoConVoz(ajustes.velocidadVoz) : letrasPorSegundoSinVoz);

    final caso = partida?.caso;
    final conseguidas = caso == null ? 0 : caso.cartas.where((c) => tenidas.contains(c.id)).length;
    final protagonista = caso?.protagonista ?? '';

    final Widget cuerpo = esperando
        ? const CargandoPixel(key: ValueKey('cargando'))
        : estado.when(
            skipLoadingOnReload: true,
            data: (partida) => partida.terminada
                ? FinalCaso(
                    key: const ValueKey('fin'),
                    partida: partida,
                    onReiniciar: () => _reiniciar(partida),
                    onVerCasos: _verCasos,
                    onSiguienteCaso: _siguienteCaso,
                  )
                : VistaEscenaJuego(
                    key: ValueKey('${partida.numeroEscena}:${partida.escena.id}'),
                    partida: partida,
                    terminos: terminos,
                    leyendo: _leyendo,
                    hablando: _tts.hablando,
                    letrasPorSegundo: letras,
                    onElegir: _elegir,
                    onAlternarLectura: _alternarLectura,
                    onTermino: _abrirGlosario,
                    onDialogo: _registrarDialogo,
                  ),
            error: (error, _) => error is CasoNoEncontrado
                ? EstadoPixel(
                    key: const ValueKey('no-esta'),
                    titulo: casoNoEncontradoTitulo,
                    mensaje: casoNoEncontradoMensaje,
                    accion: BotonPixel(etiqueta: botonVerCasos, expandido: true, onPressed: _verCasos),
                  )
                : EstadoPixel(
                    key: const ValueKey('error'),
                    titulo: tituloJuego,
                    mensaje: errorCasos,
                    accion: BotonPixel(
                      etiqueta: botonProbarOtraVez,
                      expandido: true,
                      onPressed: () => ref.invalidate(casosProvider),
                    ),
                  ),
            loading: () => const CargandoPixel(key: ValueKey('cargando')),
          );

    final transicion = duracion(context, DuracionTransicionPixel.entrada);
    return Scaffold(
      backgroundColor: ColoresUiPixel.noche,
      body: FondoPixel(
        color: ColoresUiPixel.noche,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HudPixel(
              titulo: protagonista.isEmpty ? tituloJuego : protagonista,
              progreso: switch (partida) {
                null => 0,
                Partida(terminada: true) => 1,
                final p => p.numeroEscena / p.totalEscenas,
              },
              textoProgreso: switch (partida) {
                null => cargandoCaso,
                Partida(terminada: true) => tituloFinal,
                final p => 'Escena ${p.numeroEscena} de ${p.totalEscenas}',
              },
              cartas: caso == null || caso.cartas.isEmpty ? null : conseguidas,
              totalCartas: caso == null || caso.cartas.isEmpty ? null : caso.cartas.length,
              onVolver: _verCasos,
              acciones: [
                if (partida != null)
                  BotonPixel(
                    icono: const IconoPixel(GlifoPixel.opciones),
                    semantica: menuOpciones,
                    variante: VarianteBotonPixel.secundario,
                    onPressed: () => _abrirOpciones(partida),
                  ),
                const GlosarioButton(),
                const AyudaButton(),
              ],
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: transicion,
                // A bloques, como al entrar en el juego. Mientras dura, no se puede tocar nada.
                transitionBuilder: (child, animacion) => TransicionPixel(animacion: animacion, child: child),
                layoutBuilder: (actual, anteriores) => Stack(fit: StackFit.expand, children: [...anteriores, ?actual]),
                child: cuerpo,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: partida == null
          ? null
          : _BarraAccionesPixel(
              partida: partida,
              onSeguir: _avanzar,
              onReintentar: _reintentar,
              onRecoger: () => _recogerCarta(partida),
            ),
    );
  }
}

/// Los botones de abajo: «Seguir», «Recoger tu carta», «Probar otra vez» o «Terminar el caso», sobre el azul noche
/// del juego. Mientras hay una decisión sin tomar no hay botón: se elige arriba.
class _BarraAccionesPixel extends StatelessWidget {
  const _BarraAccionesPixel({
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
    final u = unidadPixel(context);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final grande = escalaTextoPixel(context) > 1.15 || MediaQuery.sizeOf(context).width < 340;
    final termina = partida.alAvanzarTermina;
    final seguir = BotonPixel(
      etiqueta: termina ? botonTerminar : botonSeguir,
      icono: termina ? const IconoPixel(GlifoPixel.estrella) : null,
      iconoFinal: termina ? null : const IconoPixel(GlifoPixel.siguiente),
      expandido: true,
      onPressed: onSeguir,
    );
    final (String clave, Widget? contenido) = switch (partida) {
      Partida(terminada: true) || Partida(puedeAvanzar: false) => ('nada', null),
      Partida(cartaNueva: _?) => (
        'recoger',
        BotonPixel(
          etiqueta: botonRecogerCarta,
          icono: const IconoPixel(GlifoPixel.carta),
          expandido: true,
          onPressed: onRecoger,
        ),
      ),
      Partida(decision: _?, acierto: false) => (
        'reintentar',
        grande
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _probarOtraVez(),
                  SizedBox(height: 3 * u),
                  seguir,
                ],
              )
            // Los dos del mismo alto, aunque «Probar otra vez» ocupe dos líneas.
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _probarOtraVez()),
                    SizedBox(width: 3 * u),
                    Expanded(child: seguir),
                  ],
                ),
              ),
      ),
      _ => (termina ? 'terminar' : 'seguir', seguir),
    };
    return AnimatedSwitcher(
      duration: duracion(context, Duracion.media),
      transitionBuilder: (child, animacion) => FadeTransition(opacity: animacion, child: child),
      child: contenido == null
          ? const SizedBox.shrink(key: ValueKey('nada'))
          : FondoPixel(
              key: ValueKey(clave),
              color: ColoresUiPixel.noche,
              child: CustomPaint(
                painter: _PintorBordeBarra(u: u, dpr: dpr),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(Espacio.m, 5 * u, Espacio.m, 3 * u),
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
            ),
    );
  }

  Widget _probarOtraVez() => BotonPixel(
    etiqueta: botonProbarOtraVez,
    variante: VarianteBotonPixel.secundario,
    expandido: true,
    onPressed: onReintentar,
  );
}

/// El borde de arriba de la barra de botones: la misma franja amarilla del HUD, como el otro lado de la pantalla.
class _PintorBordeBarra extends CustomPainter {
  const _PintorBordeBarra({required this.u, required this.dpr});

  final double u;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    final ancho = (size.width * dpr).roundToDouble() / dpr;
    Paint pincel(Color color) => Paint()
      ..color = color
      ..isAntiAlias = false;
    canvas
      ..drawRect(Rect.fromLTWH(0, 0, ancho, u), pincel(ColoresUiPixel.noche))
      ..drawRect(Rect.fromLTWH(0, u, ancho, u), pincel(ColoresUiPixel.amarillo))
      ..drawRect(Rect.fromLTWH(0, 2 * u, ancho, u), pincel(ColoresUiPixel.ocre));
  }

  @override
  bool shouldRepaint(_PintorBordeBarra oldDelegate) => oldDelegate.u != u || oldDelegate.dpr != dpr;
}

/// Carta de la colección (fuera del caso, en la lista plana) que se abre en grande al tocarla. Para el lector de
/// pantalla es «Carta: {título}» (auditoría P2-3).
class CartaTocable extends StatelessWidget {
  const CartaTocable({super.key, required this.carta, required this.indice});

  final Carta carta;
  final int indice;

  @override
  Widget build(BuildContext context) {
    void abrir() {
      Hapticos.seleccion();
      mostrarDetalleCarta(context, carta: carta, indice: indice);
    }

    return Semantics(
      container: true,
      button: true,
      label: 'Carta: ${carta.titulo}',
      hint: 'Toca para verla en grande',
      onTap: abrir,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: abrir,
          child: CartaDerecho(carta: carta, indice: indice),
        ),
      ),
    );
  }
}
