import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../widgets/movimiento/hapticos.dart';
import 'estilo_pixel.dart';
import 'iconos_pixel.dart';
import 'pintura_pixel.dart';
import 'pulsacion_pixel.dart';
import 'rotulo_pixel.dart';

/// Cómo se dispone una [CartaPixel].
enum FormatoCartaPixel {
  /// De pie, como un naipe: título, dibujo y texto, uno debajo de otro. Para el detalle de una carta y para rejillas
  /// con columnas de 200 puntos o más.
  vertical,

  /// Tumbada: el título arriba y, debajo, el dibujo a la izquierda y el texto a la derecha. Para listas de una
  /// columna en el móvil: el texto tiene sitio para leerse sin cortes raros. Si aun así no le caben unas catorce
  /// letras por línea (pantalla muy estrecha o letra grande), se pone de pie.
  horizontal,
}

/// Carta de derecho como una carta coleccionable de 8 bits: marco de color, título en una banda amarilla, una
/// ventana con el dibujo ([arte], por ejemplo un sprite del motor, o el [icono]) y el texto corto.
///
/// Las desbloqueadas hacen brillar su dibujo una vez al aparecer (en ola, según su sitio en la pantalla), al
/// desbloquearse y al recibir el foco o el ratón; nunca en bucle, y nada con «reducir animaciones». Las [bloqueada]s
/// salen en gris, con un candado, «???» y la [pista] de cómo conseguirlas.
///
/// Mide lo que le deje el padre de ancho; el alto sale del contenido (con letra grande, crece). En un móvil, en una
/// columna, usa [FormatoCartaPixel.horizontal].
class CartaPixel extends StatefulWidget {
  const CartaPixel({
    super.key,
    required this.titulo,
    required this.texto,
    this.arte,
    this.icono = GlifoPixel.balanza,
    this.numero,
    this.bloqueada = false,
    this.pista = 'Sigue el caso para conseguirla.',
    this.brillo = true,
    this.formato = FormatoCartaPixel.vertical,
    this.color = ColoresUiPixel.azul,
    this.luz = ColoresUiPixel.azulClaro,
    this.sombraColor = ColoresUiPixel.marino,
    this.onPressed,
  });

  final String titulo;
  final String texto;

  /// Lo que va en la ventana del dibujo (un sprite, por ejemplo). Null: [icono], a la mayor escala entera que quepa.
  final Widget? arte;
  final GlifoPixel icono;

  /// Número en la colección («N.º 3»).
  final int? numero;
  final bool bloqueada;
  final String pista;

  /// El brillo del dibujo de las desbloqueadas.
  final bool brillo;
  final FormatoCartaPixel formato;

  /// Color del marco, con su luz y su sombra.
  final Color color;
  final Color luz;
  final Color sombraColor;
  final VoidCallback? onPressed;

  @override
  State<CartaPixel> createState() => _CartaPixelState();
}

class _CartaPixelState extends State<CartaPixel> with SingleTickerProviderStateMixin {
  /// Un barrido del brillo por el dibujo.
  late final AnimationController _brillo = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..addStatusListener((estado) {
      if (estado == AnimationStatus.completed) _brillo.value = 0;
    });

  late final _pulsacion = PulsacionPixel(() {
    if (mounted) setState(() {});
  });

  Timer? _espera;
  bool _reducir = false;
  bool _aparecida = false;
  Size? _pantalla;

  /// El anillo de foco (solo con teclado).
  bool _foco = false;

  /// Si tiene el foco de verdad (para el lector de pantalla).
  bool _tieneFoco = false;

  bool get _activa => widget.onPressed != null;
  bool get _conBrillo => widget.brillo && !widget.bloqueada && !_reducir;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducir = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _pantalla = MediaQuery.maybeSizeOf(context);
    if (!_conBrillo) {
      _apagarBrillo();
    } else if (!_aparecida) {
      _aparecida = true;
      // Al aparecer, un barrido; en ola, según dónde quede la carta (cuando ya se sabe, después de este fotograma).
      SchedulerBinding.instance.addPostFrameCallback((_) => _programarBarrido(_retrasoPorSitio()));
    }
  }

  @override
  void didUpdateWidget(CartaPixel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_activa) {
      _pulsacion.reiniciar();
      _foco = false;
      _tieneFoco = false;
    }
    if (!_conBrillo) {
      _apagarBrillo();
    } else if (oldWidget.bloqueada && !widget.bloqueada) {
      _programarBarrido(const Duration(milliseconds: 250));
    }
  }

  @override
  void dispose() {
    _espera?.cancel();
    _pulsacion.dispose();
    _brillo.dispose();
    super.dispose();
  }

  /// De 0,4 a 1 s: antes las de arriba a la izquierda y después las de abajo a la derecha.
  Duration _retrasoPorSitio() {
    final caja = mounted ? context.findRenderObject() : null;
    final pantalla = _pantalla;
    var t = 0.0;
    if (caja is RenderBox && caja.hasSize && pantalla != null && !pantalla.isEmpty) {
      final sitio = caja.localToGlobal(Offset.zero);
      t = ((sitio.dx + sitio.dy) / (pantalla.width + pantalla.height)).clamp(0.0, 1.0);
    }
    return Duration(milliseconds: 400 + (600 * t).round());
  }

  void _programarBarrido(Duration retraso) {
    if (!mounted || !_conBrillo) return;
    _espera?.cancel();
    _espera = Timer(retraso, _barrer);
  }

  void _barrer() {
    _espera = null;
    if (!mounted || !_conBrillo || _brillo.isAnimating) return;
    _brillo.forward(from: 0);
  }

  void _apagarBrillo() {
    _espera?.cancel();
    _espera = null;
    _brillo
      ..stop()
      ..value = 0;
  }

  void _activar() {
    final onPressed = widget.onPressed;
    if (onPressed == null) return;
    unawaited(Hapticos.toque());
    onPressed();
  }

  void _activarConTeclado() {
    if (!_activa) return;
    _pulsacion.pulsarYSoltar();
    _activar();
  }

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final bloqueada = widget.bloqueada;
    final activa = _activa;
    final pulsada = _pulsacion.pulsada && activa;
    final numero = widget.numero;

    final marco = bloqueada
        ? const EstiloCajaPixel(
            relleno: ColoresUiPixel.grisOscuro,
            luz: ColoresUiPixel.gris,
            sombraInterior: ColoresUiPixel.noche,
            esquina: 2,
          )
        : EstiloCajaPixel(relleno: widget.color, luz: widget.luz, sombraInterior: widget.sombraColor, esquina: 2);
    final filo = CajaPixel.filoDe(context, marco);
    final borde = filo == null ? 0.0 : u;

    final carta = AjustePixel(
      child: CustomPaint(
        painter: PintorCajaPixel(estilo: marco, u: u, dpr: dpr, pulsada: pulsada, foco: _foco && activa, filo: filo),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            4 * u + borde,
            4 * u + borde + (pulsada ? u : 0),
            4 * u + borde,
            4 * u + borde + (pulsada ? 0 : u),
          ),
          // Lo de dentro está sobre el color del marco (no sobre el fondo de la pantalla).
          child: FondoPixel(
            color: marco.relleno,
            pintar: false,
            child: LayoutBuilder(builder: (context, restricciones) => _contenido(context, u, dpr, restricciones)),
          ),
        ),
      ),
    );

    final etiqueta = bloqueada
        ? (numero == null ? 'Carta bloqueada. ${widget.pista}' : 'Carta número $numero, bloqueada. ${widget.pista}')
        : 'Carta${numero == null ? '' : ' número $numero'}: ${widget.titulo}. ${widget.texto}';
    // Siempre el mismo árbol (con onPressed o sin él): así el dibujo (un sprite animado) no se vuelve a montar.
    return FocusableActionDetector(
      enabled: activa,
      includeFocusSemantics: false,
      mouseCursor: activa ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (valor) {
        setState(() => _foco = valor);
        if (valor) _barrer();
      },
      onFocusChange: (valor) => setState(() => _tieneFoco = valor),
      onShowHoverHighlight: (valor) {
        if (valor) _barrer();
      },
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _activarConTeclado())},
      child: Semantics(
        container: true,
        button: activa ? true : null,
        focusable: activa ? true : null,
        focused: activa ? _tieneFoco : null,
        label: etiqueta,
        onTap: activa ? _activar : null,
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: activa ? (_) => _pulsacion.bajar() : null,
            onTapUp: activa ? (_) => _pulsacion.soltar() : null,
            onTapCancel: activa ? _pulsacion.cancelar : null,
            onTap: activa ? _activar : null,
            child: carta,
          ),
        ),
      ),
    );
  }

  Widget _contenido(BuildContext context, double u, double dpr, BoxConstraints restricciones) {
    final bloqueada = widget.bloqueada;
    final titulo = CajaPixel(
      estilo: bloqueada
          ? const EstiloCajaPixel(relleno: ColoresUiPixel.gris, luz: ColoresUiPixel.grisClaro, esquina: 1)
          : const EstiloCajaPixel(
              relleno: ColoresUiPixel.amarillo,
              luz: ColoresUiPixel.amarilloLuz,
              sombraInterior: ColoresUiPixel.ocre,
              esquina: 1,
            ),
      interior: const EdgeInsets.fromLTRB(3, 2, 3, 2),
      child: Text.rich(
        textoConCifras(
          bloqueada ? '???' : widget.titulo,
          estiloTextoPixel(context, TipoTextoPixel.etiqueta, color: ColoresUiPixel.noche),
        ),
        textAlign: TextAlign.center,
      ),
    );
    final texto = CajaPixel(
      estilo: bloqueada
          ? const EstiloCajaPixel(
              relleno: ColoresUiPixel.grisClaro,
              luz: ColoresUiPixel.blanco,
              esquina: 1,
              sombra: null,
            )
          : const EstiloCajaPixel(relleno: ColoresUiPixel.papel, luz: ColoresUiPixel.blanco, esquina: 1, sombra: null),
      // Tres unidades desde el borde (una es el contorno): el texto no queda pegado.
      interior: const EdgeInsets.all(3),
      child: Text.rich(
        textoConCifras(
          bloqueada ? widget.pista : widget.texto,
          estiloTextoPixel(context, TipoTextoPixel.pequeno, color: ColoresUiPixel.noche),
        ),
      ),
    );
    // Tumbada, el dibujo ocupa algo más de un tercio del ancho (y nunca menos que su glifo).
    final glifo = bloqueada ? GlifoPixel.candado : widget.icono;
    final anchoVentana = math.max((glifo.ancho + 6) * u, math.min(restricciones.maxWidth * 0.38, 40 * u));
    final letra = MediaQuery.textScalerOf(context).scale(TipoTextoPixel.pequeno.tamano);
    // Unas catorce letras por línea (en Pixelify, una letra mide de media algo más de media vez su tamaño).
    final cabeTumbada = restricciones.maxWidth - anchoVentana - 8 * u >= 7.5 * letra;
    final formato = widget.formato == FormatoCartaPixel.horizontal && cabeTumbada
        ? FormatoCartaPixel.horizontal
        : FormatoCartaPixel.vertical;
    switch (formato) {
      case FormatoCartaPixel.vertical:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            titulo,
            SizedBox(height: 2 * u),
            // De pie porque tumbada no cabía (una columna, letra grande): ventana más apaisada, para no alargarla.
            _ventana(context, u, dpr, proporcion: widget.formato == FormatoCartaPixel.horizontal ? 1 / 2 : 3 / 4),
            SizedBox(height: 2 * u),
            texto,
          ],
        );
      case FormatoCartaPixel.horizontal:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            titulo,
            SizedBox(height: 2 * u),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: anchoVentana, child: _ventana(context, u, dpr, proporcion: 1)),
                SizedBox(width: 2 * u),
                Expanded(child: texto),
              ],
            ),
          ],
        );
    }
  }

  /// La ventana del dibujo: el número en su propia fila (para no taparlo con letra grande) y el dibujo a la mayor
  /// escala entera que cabe (nunca encogido a medias: se vería borroso). El alto es [proporcion] del ancho, salvo que
  /// el número con letra grande no deje sitio al dibujo: entonces crece.
  Widget _ventana(BuildContext context, double u, double dpr, {required double proporcion}) {
    final bloqueada = widget.bloqueada;
    final numero = widget.numero;
    final dibujo = bloqueada
        ? const _GlifoAjustado(GlifoPixel.candado, color: ColoresUiPixel.gris)
        : widget.arte ?? _GlifoAjustado(widget.icono, color: ColoresUiPixel.noche);
    return LayoutBuilder(
      builder: (context, restricciones) {
        final altoNumero = numero == null ? 0.0 : (LetraRotuloPixel.alto + 2) * RotuloPixel.celda(context) + 2 * u;
        final minimoDibujo = ((bloqueada ? GlifoPixel.candado : widget.icono).alto + 2) * u;
        final altoDibujo = math.max(restricciones.maxWidth * proporcion - 4 * u - altoNumero, minimoDibujo);
        return AjustePixel(
          child: CustomPaint(
            painter: _PintorVentanaArte(u: u, dpr: dpr, bloqueada: bloqueada),
            child: Padding(
              padding: EdgeInsets.all(2 * u),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (numero != null) ...[
                    CajaPixel(
                      estilo: const EstiloCajaPixel(
                        relleno: ColoresUiPixel.noche,
                        esquina: 1,
                        sombra: null,
                        profundidad: 0,
                      ),
                      conFilo: false,
                      interior: const EdgeInsets.fromLTRB(2, 1, 2, 1),
                      child: RotuloPixel('N.º $numero', color: ColoresUiPixel.papel),
                    ),
                    SizedBox(height: 2 * u),
                  ],
                  CustomPaint(
                    foregroundPainter: _conBrillo ? _PintorBrillo(animacion: _brillo, u: u, dpr: dpr) : null,
                    child: SizedBox(
                      width: double.infinity,
                      height: altoDibujo,
                      child: ClipRect(child: Center(child: dibujo)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Un glifo a la mayor escala entera (de 1 a 3) que cabe en su sitio.
class _GlifoAjustado extends StatelessWidget {
  const _GlifoAjustado(this.glifo, {required this.color});

  final GlifoPixel glifo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    return LayoutBuilder(
      builder: (context, restricciones) {
        final cabe = math.min(restricciones.maxWidth / (glifo.ancho * u), restricciones.maxHeight / (glifo.alto * u));
        return IconoPixel(glifo, color: color, escala: cabe.floor().clamp(1, 3));
      },
    );
  }
}

/// Fondo de la ventana del dibujo: cielo claro y suelo, unidos por una franja tramada (en las bloqueadas, de noche).
class _PintorVentanaArte extends CustomPainter {
  const _PintorVentanaArte({required this.u, required this.dpr, required this.bloqueada});

  final double u;
  final double dpr;
  final bool bloqueada;

  @override
  void paint(Canvas canvas, Size size) {
    final caja = Rect.fromLTWH(0, 0, alPixelFisico(size.width, dpr), alPixelFisico(size.height, dpr));
    final cielo = bloqueada ? ColoresUiPixel.noche : ColoresUiPixel.hielo;
    final suelo = bloqueada ? ColoresUiPixel.marino : ColoresUiPixel.cielo;
    pintarCajaPixel(
      canvas,
      caja,
      u,
      EstiloCajaPixel(relleno: cielo, contorno: ColoresUiPixel.noche, sombra: null, esquina: 1, profundidad: 0),
    );
    final dentro = caja.deflate(u);
    final filas = (dentro.height / u).floor();
    final columnas = (dentro.width / u).ceil();
    final horizonte = (filas * 0.68).round();
    canvas
      ..save()
      ..clipRect(dentro, doAntiAlias: false)
      ..drawRect(
        Rect.fromLTRB(dentro.left, dentro.top + (horizonte + 2) * u, dentro.right, dentro.bottom),
        pincelPixel(suelo),
      );
    // Trama en vez de degradado: una fila con una celda de cada cuatro y dos de damero funden el cielo con el suelo.
    final trama = pincelPixel(suelo);
    for (var c = 1; c < columnas; c += 4) {
      canvas.drawRect(Rect.fromLTWH(dentro.left + c * u, dentro.top + (horizonte - 1) * u, u, u), trama);
    }
    for (var f = 0; f < 2; f++) {
      final y = dentro.top + (horizonte + f) * u;
      for (var c = f; c < columnas; c += 2) {
        canvas.drawRect(Rect.fromLTWH(dentro.left + c * u, y, u, u), trama);
      }
    }
    // Unos destellos fijos en el cielo.
    final destello = pincelPixel(bloqueada ? ColoresUiPixel.marino : ColoresUiPixel.blanco);
    for (final (x, y) in [(0.88, 0.16), (0.78, 0.36)]) {
      final cx = dentro.left + (dentro.width * x / u).floor() * u;
      final cy = dentro.top + (dentro.height * y / u).floor() * u;
      canvas
        ..drawRect(Rect.fromLTWH(cx, cy - u, u, 3 * u), destello)
        ..drawRect(Rect.fromLTWH(cx - u, cy, 3 * u, u), destello);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorVentanaArte oldDelegate) =>
      oldDelegate.u != u || oldDelegate.dpr != dpr || oldDelegate.bloqueada != bloqueada;
}

/// El brillo del dibujo: dos franjas en diagonal, hechas de unidades pixel, que lo cruzan una vez (solo el dibujo:
/// nunca el título, el número ni el texto).
class _PintorBrillo extends CustomPainter {
  _PintorBrillo({required this.animacion, required this.u, required this.dpr}) : super(repaint: animacion);

  final Animation<double> animacion;
  final double u;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animacion.value;
    if (t <= 0 || t >= 1) return;
    final caja = Rect.fromLTWH(0, 0, alPixelFisico(size.width, dpr), alPixelFisico(size.height, dpr));
    final filas = (caja.height / u).ceil();
    final columnas = (caja.width / u).ceil();
    // La franja avanza a saltos de una unidad, de fuera a fuera del dibujo.
    final recorrido = columnas + filas + 8;
    final frente = (t * recorrido).floor() - filas - 4;
    final ancha = pincelPixel(const Color(0x8CFFFFFF));
    final fina = pincelPixel(const Color(0x59FFFFFF));
    canvas
      ..save()
      ..clipRect(caja, doAntiAlias: false);
    for (var fila = 0; fila < filas; fila++) {
      final x = frente + (filas - fila);
      final y = caja.top + fila * u;
      canvas
        ..drawRect(Rect.fromLTWH(caja.left + x * u, y, 3 * u, u), ancha)
        ..drawRect(Rect.fromLTWH(caja.left + (x + 5) * u, y, u, u), fina);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorBrillo oldDelegate) =>
      oldDelegate.animacion != animacion || oldDelegate.u != u || oldDelegate.dpr != dpr;
}
