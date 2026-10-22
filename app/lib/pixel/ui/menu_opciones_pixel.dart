import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../widgets/movimiento/hapticos.dart';
import 'estilo_pixel.dart';
import 'iconos_pixel.dart';
import 'pintura_pixel.dart';
import 'pulsacion_pixel.dart';

/// Cómo está una opción de un [MenuOpcionesPixel].
enum EstadoOpcionPixel {
  /// Se puede elegir.
  normal,

  /// Tiene el cursor (el ratón encima, el foco del teclado o el dedo).
  activa,

  /// La elegida, y era correcta.
  correcta,

  /// La elegida, y no era correcta.
  incorrecta,

  /// No se eligió, pero era la correcta: se enseña después de fallar.
  revelada,

  /// La elegida en un menú sin respuestas correctas.
  elegida,

  /// Ni elegida ni correcta, con la decisión ya tomada.
  apagada,
}

/// Lista de opciones de juego de rol con un cursor ► que va a la opción que tiene el ratón encima, el foco o el dedo.
///
/// Al elegir, [onElegir] recibe el índice; quien lo usa guarda la elección y la pasa en [elegida]. Desde ese momento
/// el menú enseña cómo ha ido: la elegida en verde con ✓ si está en [correctas] o en teja con ✗ si no (y, si
/// [revelarCorrecta], la correcta con su ✓). El color nunca va solo: lleva icono y el lector de pantalla lo dice (con
/// [anunciar], en cuanto se elige, sin tener que ir a buscarlo). Sin [correctas], la elegida solo queda marcada.
///
/// Antes de tocar nada, ninguna opción se resalta: [cursorInicial] solo pone el ► (en un juego de preguntas, una
/// opción resaltada parecería la buena). No pongas siempre la correcta la primera.
///
/// Se maneja con el teclado (flechas o tabulador e Intro). El cursor se balancea unos segundos cada vez que cambia de
/// opción; con «reducir animaciones», no se mueve.
class MenuOpcionesPixel extends StatefulWidget {
  const MenuOpcionesPixel({
    super.key,
    required this.opciones,
    required this.onElegir,
    this.elegida,
    this.correctas,
    this.revelarCorrecta = true,
    this.cursorInicial,
    this.etiqueta,
    this.anunciar = true,
  });

  final List<String> opciones;
  final ValueChanged<int>? onElegir;
  final int? elegida;
  final Set<int>? correctas;
  final bool revelarCorrecta;

  /// Dónde está el ► antes de tocar nada (null: en ninguna). No resalta la opción.
  final int? cursorInicial;

  /// La pregunta, para el lector de pantalla.
  final String? etiqueta;

  /// El lector de pantalla dice el resultado al elegir (la opción elegida es una región en vivo).
  final bool anunciar;

  @override
  State<MenuOpcionesPixel> createState() => _MenuOpcionesPixelState();
}

class _MenuOpcionesPixelState extends State<MenuOpcionesPixel> {
  int? _cursor;

  /// Si el cursor ha llegado por el ratón, el foco o el dedo (y no solo por [MenuOpcionesPixel.cursorInicial]).
  bool _interactuado = false;
  int? _pulsadaIndice;
  late final _pulsacion = PulsacionPixel(() {
    if (mounted) setState(() {});
  });
  List<FocusNode> _focos = const [];
  Timer? _vaiven;
  int _pasos = 0;
  bool _paso = false;
  bool _reducir = false;
  bool _tickers = true;

  /// El cursor se balancea unos 8 segundos (19 pasos de 420 ms) y luego se queda quieto.
  static const _pasosVaiven = 19;

  bool get _decidido => widget.elegida != null;
  bool get _activo => widget.onElegir != null && !_decidido;

  @override
  void initState() {
    super.initState();
    _cursor = widget.elegida ?? widget.cursorInicial;
    _focos = _crearFocos(widget.opciones.length);
  }

  List<FocusNode> _crearFocos(int cuantos) => [
    for (var i = 0; i < cuantos; i++) FocusNode(debugLabel: 'Opción ${i + 1}'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducir = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _tickers = TickerMode.valuesOf(context).enabled;
    _actualizarVaiven();
  }

  @override
  void didUpdateWidget(MenuOpcionesPixel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.opciones.length != widget.opciones.length) {
      for (final foco in _focos) {
        foco.dispose();
      }
      _focos = _crearFocos(widget.opciones.length);
    }
    final elegida = widget.elegida;
    if (elegida != oldWidget.elegida) {
      if (elegida == null) {
        // Se vuelve a preguntar: como al principio.
        _cursor = widget.cursorInicial;
        _interactuado = false;
        _pulsacion.reiniciar();
      } else {
        // La elegida termina de bajar (ya con su resultado) y vuelve a subir.
        _cursor = elegida;
        if (oldWidget.elegida == null && (widget.correctas?.contains(elegida) ?? false)) {
          unawaited(Hapticos.acierto());
        }
      }
      _pasos = 0;
    }
    final cursor = _cursor;
    if (cursor != null && cursor >= widget.opciones.length) _cursor = null;
    _actualizarVaiven();
  }

  @override
  void dispose() {
    _vaiven?.cancel();
    _pulsacion.dispose();
    for (final foco in _focos) {
      foco.dispose();
    }
    super.dispose();
  }

  /// El cursor se balancea (una unidad adelante y atrás) unos segundos mientras se puede elegir.
  void _actualizarVaiven() {
    if (_cursor != null && _activo && !_reducir && _tickers && _pasos < _pasosVaiven) {
      _vaiven ??= Timer.periodic(const Duration(milliseconds: 420), (_) {
        if (!mounted) return;
        setState(() {
          _paso = !_paso;
          _pasos++;
        });
        if (_pasos >= _pasosVaiven) _parar();
      });
    } else {
      _parar();
    }
  }

  void _parar() {
    _vaiven?.cancel();
    _vaiven = null;
    _paso = false;
  }

  void _mover(int indice) {
    if (!_activo || (_cursor == indice && _interactuado)) return;
    setState(() {
      _cursor = indice;
      _interactuado = true;
      _pasos = 0;
    });
    _actualizarVaiven();
  }

  void _elegir(int indice) {
    final onElegir = widget.onElegir;
    if (onElegir == null || _decidido) return;
    unawaited(Hapticos.seleccion());
    setState(() {
      _cursor = indice;
      _interactuado = true;
    });
    onElegir(indice);
  }

  void _bajar(int indice) {
    _mover(indice);
    _pulsadaIndice = indice;
    _pulsacion.bajar();
  }

  EstadoOpcionPixel _estado(int indice) {
    final elegida = widget.elegida;
    final correctas = widget.correctas;
    if (elegida == null) {
      return _cursor == indice && _interactuado ? EstadoOpcionPixel.activa : EstadoOpcionPixel.normal;
    }
    if (correctas == null) return elegida == indice ? EstadoOpcionPixel.elegida : EstadoOpcionPixel.apagada;
    final correcta = correctas.contains(indice);
    if (elegida == indice) return correcta ? EstadoOpcionPixel.correcta : EstadoOpcionPixel.incorrecta;
    return correcta && widget.revelarCorrecta ? EstadoOpcionPixel.revelada : EstadoOpcionPixel.apagada;
  }

  /// Lo que lee el lector de pantalla de la opción [i] en [estado]: la elegida lo dice todo en su etiqueta (al
  /// cambiar, la región en vivo lo anuncia una sola vez).
  String _etiqueta(int i, EstadoOpcionPixel estado) {
    final texto = widget.opciones[i];
    switch (estado) {
      case EstadoOpcionPixel.correcta:
        return '$texto. Tu respuesta: correcta.';
      case EstadoOpcionPixel.incorrecta:
        final correctas = [
          for (final (j, opcion) in widget.opciones.indexed)
            if (widget.correctas?.contains(j) ?? false) opcion,
        ];
        final cual = widget.revelarCorrecta && correctas.isNotEmpty
            ? ' La correcta era: ${correctas.join(' o ')}.'
            : '';
        return '$texto. Tu respuesta: no es correcta.$cual';
      case EstadoOpcionPixel.elegida:
        return '$texto. Tu respuesta.';
      case EstadoOpcionPixel.normal ||
          EstadoOpcionPixel.activa ||
          EstadoOpcionPixel.revelada ||
          EstadoOpcionPixel.apagada:
        return texto;
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.etiqueta,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < widget.opciones.length; i++) ...[
            if (i > 0) SizedBox(height: 2 * u),
            _opcion(context, i, u),
          ],
        ],
      ),
    );
  }

  Widget _opcion(BuildContext context, int i, double u) {
    final estado = _estado(i);
    final colores = _ColoresOpcion.de(estado);
    final icono = switch (estado) {
      EstadoOpcionPixel.correcta || EstadoOpcionPixel.revelada || EstadoOpcionPixel.elegida => GlifoPixel.check,
      EstadoOpcionPixel.incorrecta => GlifoPixel.cruz,
      _ => null,
    };
    final activo = _activo;
    final conFoco = _focos[i].hasFocus;
    final conCursor = _cursor == i;
    final cursor = SizedBox(
      width: 8 * u,
      child: conCursor
          ? Padding(
              padding: EdgeInsets.only(left: _paso ? u : 0, bottom: u),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: IconoPixel(GlifoPixel.flecha, color: ColoresUiPixel.amarillo, contorno: ColoresUiPixel.noche),
              ),
            )
          : null,
    );
    final caja = CajaPixel(
      estilo: colores.estilo,
      pulsada: _pulsacion.pulsada && _pulsadaIndice == i,
      interior: const EdgeInsets.fromLTRB(4, 3, 4, 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.opciones[i],
              style: estiloTextoPixel(context, TipoTextoPixel.cuerpo, color: colores.tinta),
            ),
          ),
          if (icono != null) ...[SizedBox(width: 2 * u), IconoPixel(icono, color: colores.icono)],
        ],
      ),
    );
    return FocusableActionDetector(
      focusNode: _focos[i],
      // La que tiene el foco lo conserva al decidir (si no, el teclado volvería al principio de la pantalla).
      enabled: activo || conFoco,
      includeFocusSemantics: false,
      mouseCursor: activo ? SystemMouseCursors.click : MouseCursor.defer,
      onShowHoverHighlight: (encima) {
        if (encima) _mover(i);
      },
      onFocusChange: (foco) {
        if (foco) _mover(i);
        setState(() {});
      },
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _elegir(i))},
      child: Semantics(
        container: true,
        liveRegion: widget.anunciar && widget.elegida == i,
        // Antes de elegir, botones; después, texto con su resultado (ni botón ni «desactivado»).
        button: activo ? true : null,
        enabled: activo ? true : null,
        selected: _decidido ? widget.elegida == i : null,
        focusable: activo || conFoco,
        focused: conFoco,
        label: _etiqueta(i, estado),
        value: estado == EstadoOpcionPixel.revelada ? 'Esta era la respuesta correcta' : null,
        onTap: activo ? () => _elegir(i) : null,
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: activo ? (_) => _bajar(i) : null,
            onTapUp: activo ? (_) => _pulsacion.soltar() : null,
            onTapCancel: activo ? _pulsacion.cancelar : null,
            onTap: activo ? () => _elegir(i) : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: 48 + u),
              child: Row(
                children: [
                  cursor,
                  Expanded(child: caja),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Colores de cada [EstadoOpcionPixel].
class _ColoresOpcion {
  const _ColoresOpcion(this.estilo, this.tinta, this.icono);

  factory _ColoresOpcion.de(EstadoOpcionPixel estado) => switch (estado) {
    EstadoOpcionPixel.normal => const _ColoresOpcion(
      EstiloCajaPixel(relleno: ColoresUiPixel.papel, luz: ColoresUiPixel.blanco, sombraInterior: ColoresUiPixel.hielo),
      ColoresUiPixel.noche,
      ColoresUiPixel.noche,
    ),
    EstadoOpcionPixel.activa || EstadoOpcionPixel.elegida => const _ColoresOpcion(
      EstiloCajaPixel(
        relleno: ColoresUiPixel.amarillo,
        luz: ColoresUiPixel.amarilloLuz,
        sombraInterior: ColoresUiPixel.ocre,
      ),
      ColoresUiPixel.noche,
      ColoresUiPixel.noche,
    ),
    EstadoOpcionPixel.correcta => const _ColoresOpcion(
      EstiloCajaPixel(
        relleno: ColoresUiPixel.verdeOscuro,
        luz: ColoresUiPixel.verde,
        sombraInterior: ColoresUiPixel.noche,
      ),
      ColoresUiPixel.blanco,
      ColoresUiPixel.blanco,
    ),
    EstadoOpcionPixel.incorrecta => const _ColoresOpcion(
      EstiloCajaPixel(relleno: ColoresUiPixel.teja, luz: ColoresUiPixel.coral, sombraInterior: ColoresUiPixel.negro),
      ColoresUiPixel.blanco,
      ColoresUiPixel.blanco,
    ),
    EstadoOpcionPixel.revelada => const _ColoresOpcion(
      EstiloCajaPixel(
        relleno: ColoresUiPixel.papel,
        anillo: ColoresUiPixel.verdeOscuro,
        luz: ColoresUiPixel.blanco,
        sombraInterior: ColoresUiPixel.hielo,
      ),
      ColoresUiPixel.noche,
      ColoresUiPixel.verdeOscuro,
    ),
    EstadoOpcionPixel.apagada => const _ColoresOpcion(
      EstiloCajaPixel(relleno: ColoresUiPixel.papel, contorno: ColoresUiPixel.gris, sombra: null),
      ColoresUiPixel.grisOscuro,
      ColoresUiPixel.grisOscuro,
    ),
  };

  final EstiloCajaPixel estilo;
  final Color tinta;
  final Color icono;
}
