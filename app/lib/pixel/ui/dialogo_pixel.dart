import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../widgets/movimiento/hapticos.dart';
import 'estilo_pixel.dart';
import 'iconos_pixel.dart';
import 'pintura_pixel.dart';

/// Controla un [DialogoPixel] desde fuera y avisa cuando el texto está completo: sirve para sincronizar la
/// narración en voz alta (TTS) con lo que se ve.
///
/// ```dart
/// final dialogo = ControladorDialogoPixel();
/// tts.alAcabar = dialogo.mostrarTodo;           // si la voz acaba antes, se ve todo
/// dialogo.addListener(() { if (dialogo.completo) … });
/// ```
class ControladorDialogoPixel extends ChangeNotifier {
  _DialogoPixelState? _estado;
  bool _completo = false;

  /// Todo el texto está a la vista.
  bool get completo => _completo;

  /// Caracteres (grafemas) que ya se ven y los que hay en total.
  int get visibles => _estado?._visibles ?? 0;
  int get total => _estado?._caracteres.length ?? 0;

  /// Enseña todo el texto de golpe.
  void mostrarTodo() => _estado?._completar();

  /// Vuelve a escribir el texto desde el principio.
  void reiniciar() => _estado?._reiniciar();

  void _cambiar(bool completo) {
    if (_completo == completo) return;
    _completo = completo;
    notifyListeners();
  }
}

/// Ventana de diálogo de juego de rol: el texto aparece letra a letra (como si se escribiera), con una placa amarilla
/// con el nombre de quien habla ([hablante]).
///
/// - Un toque mientras se escribe enseña todo el texto; con todo a la vista, llama a [onContinuar], y entonces
///   parpadea el ▼ de la placa «Continuar» (unos 8 segundos; luego se queda quieto, a la vista).
/// - Con «reducir animaciones», el texto sale entero de golpe y el ▼ no parpadea.
/// - [onCompletado] y [controlador] avisan cuando el texto está completo (para la voz).
/// - El lector de pantalla lee siempre el texto entero, desde el principio, y, con [anunciar], lo dice solo cada vez
///   que cambia la frase (es una región en vivo). Si la app ya lee la frase en voz alta (TTS), pasa
///   `anunciar: false` mientras haya lector de pantalla, para que no se lea dos veces.
class DialogoPixel extends StatefulWidget {
  const DialogoPixel({
    super.key,
    required this.texto,
    this.hablante,
    this.controlador,
    this.caracteresPorSegundo = 40,
    this.onCompletado,
    this.onContinuar,
    this.etiquetaContinuar = 'Continuar',
    this.focusNode,
    this.autofocus = false,
    this.anunciar = true,
  });

  final String texto;
  final String? hablante;
  final ControladorDialogoPixel? controlador;

  /// Velocidad de escritura. Las comas y los puntos hacen una pausa. Con 0 o menos, el texto sale de golpe.
  final double caracteresPorSegundo;
  final VoidCallback? onCompletado;

  /// Null: no hay nada después (sin placa «Continuar»).
  final VoidCallback? onContinuar;
  final String etiquetaContinuar;
  final FocusNode? focusNode;
  final bool autofocus;

  /// El lector de pantalla dice la frase nueva sin que haya que ir a buscarla (región en vivo).
  final bool anunciar;

  @override
  State<DialogoPixel> createState() => _DialogoPixelState();
}

class _DialogoPixelState extends State<DialogoPixel> with SingleTickerProviderStateMixin {
  late final AnimationController _escritura = AnimationController(vsync: this)
    ..addListener(_alEscribir)
    ..addStatusListener((estado) {
      if (estado == AnimationStatus.completed) _completar();
    });

  List<String> _caracteres = const [];

  /// Momento (en «pesos» de carácter) en que aparece cada carácter; crece de uno en uno.
  List<double> _inicios = const [];
  double _pesoTotal = 0;
  int _visibles = 0;
  bool _completo = false;
  bool _iniciado = false;
  bool _reducir = false;
  bool _tickers = true;

  /// El anillo de foco (solo con teclado).
  bool _foco = false;

  /// Si tiene el foco de verdad (para el lector de pantalla).
  bool _tieneFoco = false;

  bool _indicadorVisible = true;
  Timer? _parpadeo;

  /// El ▼ parpadea unos segundos (ciclos de 1 s: 650 ms a la vista y 350 escondido) y luego se queda quieto.
  static const _ciclosParpadeo = 8;
  int _ciclos = 0;

  @override
  void initState() {
    super.initState();
    widget.controlador?._estado = this;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducir = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _tickers = TickerMode.valuesOf(context).enabled;
    if (!_iniciado) {
      _iniciado = true;
      _empezar();
    } else if (_reducir && !_completo) {
      _completar();
    }
    _actualizarParpadeo();
  }

  @override
  void didUpdateWidget(DialogoPixel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controlador != widget.controlador) {
      if (oldWidget.controlador?._estado == this) oldWidget.controlador?._estado = null;
      widget.controlador?._estado = this;
      // Se avisa después del fotograma: quien escucha puede querer cambiar su estado.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controlador?._cambiar(_completo);
      });
    }
    if (oldWidget.texto != widget.texto ||
        oldWidget.hablante != widget.hablante ||
        oldWidget.caracteresPorSegundo != widget.caracteresPorSegundo) {
      _empezar();
    }
    _actualizarParpadeo();
  }

  @override
  void dispose() {
    _parpadeo?.cancel();
    if (widget.controlador?._estado == this) widget.controlador?._estado = null;
    _escritura.dispose();
    super.dispose();
  }

  static double _peso(String caracter) => switch (caracter) {
    '.' || '!' || '?' || '…' => 8,
    ',' || ';' || ':' => 4,
    '\n' => 6,
    _ => 1,
  };

  /// Prepara el texto y empieza a escribirlo (o lo enseña entero, si no hay que animarlo).
  void _empezar() {
    _caracteres = widget.texto.characters.toList();
    final inicios = <double>[];
    var acumulado = 0.0;
    for (final caracter in _caracteres) {
      inicios.add(acumulado);
      acumulado += _peso(caracter);
    }
    _inicios = inicios;
    _pesoTotal = acumulado;
    _completo = false;
    _visibles = 0;
    _ciclos = 0;
    _escritura.stop();
    // Mientras se escribe, el ▼ no parpadea (y vuelve a estar a la vista para cuando acabe).
    _actualizarParpadeo();
    if (_reducir || widget.caracteresPorSegundo <= 0 || _caracteres.isEmpty) {
      _completar();
      return;
    }
    _avisarCompleto(false);
    _escritura
      ..duration = Duration(microseconds: (_pesoTotal / widget.caracteresPorSegundo * 1e6).round())
      ..forward(from: 0);
    _alEscribir();
  }

  /// [ControladorDialogoPixel.reiniciar]: desde fuera, así que vuelve a construir.
  void _reiniciar() {
    if (mounted) setState(_empezar);
  }

  void _alEscribir() {
    if (_completo) return;
    final transcurrido = _escritura.value * _pesoTotal;
    // Cuántos caracteres han empezado ya (búsqueda binaria en los inicios, que crecen).
    var bajo = 0;
    var alto = _inicios.length;
    while (bajo < alto) {
      final medio = (bajo + alto) >> 1;
      if (_inicios[medio] <= transcurrido) {
        bajo = medio + 1;
      } else {
        alto = medio;
      }
    }
    if (bajo != _visibles && mounted) setState(() => _visibles = bajo);
  }

  void _completar() {
    if (_completo) return;
    _escritura.stop();
    if (mounted) {
      setState(() {
        _completo = true;
        _visibles = _caracteres.length;
      });
    }
    _avisarCompleto(true);
    _actualizarParpadeo();
  }

  /// Avisa a [DialogoPixel.onCompletado] y al controlador. Si se está construyendo la pantalla, después del
  /// fotograma (quien escucha puede querer cambiar su estado).
  void _avisarCompleto(bool completo) {
    void avisar() {
      if (!mounted || completo != _completo) return;
      widget.controlador?._cambiar(completo);
      if (completo) widget.onCompletado?.call();
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => avisar());
    } else {
      avisar();
    }
  }

  void _actualizarParpadeo() {
    final parpadea = _completo && widget.onContinuar != null && !_reducir && _tickers && _ciclos < _ciclosParpadeo;
    if (parpadea) {
      if (_parpadeo == null) _programarParpadeo();
    } else {
      _parpadeo?.cancel();
      _parpadeo = null;
      _indicadorVisible = true;
    }
  }

  /// El ▼ se ve más rato del que se esconde: parpadea, pero se lee. Tras unos ciclos, se queda a la vista.
  void _programarParpadeo() {
    _parpadeo = Timer(Duration(milliseconds: _indicadorVisible ? 650 : 350), () {
      if (!mounted) return;
      setState(() {
        _indicadorVisible = !_indicadorVisible;
        if (_indicadorVisible) _ciclos++;
      });
      if (_ciclos >= _ciclosParpadeo) {
        _parpadeo = null;
        return;
      }
      _programarParpadeo();
    });
  }

  void _tocar() {
    if (!_completo) {
      unawaited(Hapticos.seleccion());
      _completar();
      return;
    }
    final onContinuar = widget.onContinuar;
    if (onContinuar == null) return;
    unawaited(Hapticos.toque());
    onContinuar();
  }

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final hablante = widget.hablante;
    final continuar = widget.onContinuar != null;
    final estiloTexto = estiloTextoPixel(context, TipoTextoPixel.cuerpo, color: ColoresUiPixel.papel);
    final estiloPlaca = estiloTextoPixel(context, TipoTextoPixel.etiqueta, color: ColoresUiPixel.noche);
    // Las placas (nombre y «Continuar») montan sobre el borde de la ventana: la mitad dentro y la mitad fuera.
    final altoPlaca = altoLineaPixel(context, estiloPlaca) + 4 * u;
    final mitad = (altoPlaca / 2 / u).roundToDouble() * u;
    final arriba = hablante == null ? 0.0 : mitad;
    final abajo = continuar ? altoPlaca - mitad : 0.0;
    final margenArriba = hablante == null ? 5 * u : altoPlaca - mitad + 2 * u;
    final margenAbajo = continuar ? mitad + 2 * u : 5 * u;
    final visible = _caracteres.take(_visibles).join();
    final oculto = _caracteres.skip(_visibles).join();

    final ventana = CajaPixel(
      estilo: const EstiloCajaPixel(
        relleno: ColoresUiPixel.noche,
        contorno: ColoresUiPixel.noche,
        anillo: ColoresUiPixel.papel,
        esquina: 3,
      ),
      foco: _foco,
      interior: EdgeInsets.fromLTRB(6, margenArriba / u, 6, margenAbajo / u),
      child: SizedBox(
        width: double.infinity,
        child: Text.rich(
          TextSpan(
            children: [
              textoConCifras(visible, estiloTexto),
              // Lo que falta ocupa ya su sitio (transparente): el texto no se recoloca mientras se escribe. Con las
              // cifras en su letra también lo que falta, para que midan lo mismo antes y después de salir.
              textoConCifras(oculto, estiloTexto.copyWith(color: const Color(0x00000000))),
            ],
          ),
          style: estiloTexto,
        ),
      ),
    );

    final placaNombre = hablante == null
        ? null
        : CajaPixel(
            estilo: const EstiloCajaPixel(
              relleno: ColoresUiPixel.amarillo,
              contorno: ColoresUiPixel.noche,
              luz: ColoresUiPixel.amarilloLuz,
              esquina: 1,
            ),
            // Monta sobre el borde de la ventana: su contorno ya se ve contra el anillo de papel.
            conFilo: false,
            interior: const EdgeInsets.fromLTRB(3, 2, 3, 2),
            child: Text.rich(textoConCifras(hablante, estiloPlaca), maxLines: 1, overflow: TextOverflow.ellipsis),
          );

    final placaContinuar = !continuar
        ? null
        : Opacity(
            // Guarda su sitio mientras se escribe: así la ventana no cambia de tamaño al acabar.
            opacity: _completo ? 1 : 0,
            child: CajaPixel(
              estilo: const EstiloCajaPixel(
                relleno: ColoresUiPixel.papel,
                contorno: ColoresUiPixel.noche,
                luz: ColoresUiPixel.blanco,
                esquina: 1,
              ),
              conFilo: false,
              interior: const EdgeInsets.fromLTRB(3, 2, 3, 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.etiquetaContinuar, style: estiloPlaca),
                  SizedBox(width: 2 * u),
                  Opacity(
                    opacity: _indicadorVisible ? 1 : 0,
                    child: const IconoPixel(GlifoPixel.abajo, color: ColoresUiPixel.noche),
                  ),
                ],
              ),
            ),
          );

    final etiqueta = hablante == null ? widget.texto : '$hablante: ${widget.texto}';
    final puedeTocar = !_completo || continuar;
    // Si tenía el foco cuando deja de haber algo que hacer (acaba de escribirse sin «Continuar»), lo conserva hasta
    // que se vaya a otro sitio: así el teclado no vuelve al principio de la pantalla.
    final enfocable = puedeTocar || _tieneFoco;
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: enfocable,
      includeFocusSemantics: false,
      mouseCursor: puedeTocar ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (valor) => setState(() => _foco = valor),
      onFocusChange: (valor) => setState(() => _tieneFoco = valor),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            if (puedeTocar) _tocar();
            return null;
          },
        ),
      },
      child: Semantics(
        container: true,
        liveRegion: widget.anunciar,
        label: etiqueta,
        focusable: enfocable,
        focused: _tieneFoco,
        onTap: puedeTocar ? _tocar : null,
        onTapHint: !puedeTocar ? null : (_completo ? widget.etiquetaContinuar.toLowerCase() : 'ver todo el texto'),
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: puedeTocar ? _tocar : null,
            child: LayoutBuilder(
              builder: (context, restricciones) => Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: arriba, bottom: abajo),
                    child: ventana,
                  ),
                  if (placaNombre != null)
                    Positioned(
                      left: 4 * u,
                      top: 0,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: restricciones.maxWidth * 0.75),
                        child: placaNombre,
                      ),
                    ),
                  if (placaContinuar != null) Positioned(right: 4 * u, bottom: 0, child: placaContinuar),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
