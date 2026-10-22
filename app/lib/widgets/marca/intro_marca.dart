import 'package:flutter/material.dart';

import '../../tema.dart';
import 'logo_tuturno.dart';
import 'pintor_marca.dart';
import 'trazos_marca.dart';

/// Presentación animada del logotipo, para la bienvenida: las letras de TuTurno caen una a una como pegatinas que
/// alguien pega con la mano (llegan grandes y torcidas, se aplastan un poco al tocar y se quedan rectas) y después
/// aparece el [lema]. Se reproduce una sola vez.
///
/// Con «reducir animaciones», todo aparece ya en su sitio y [onTerminada] se llama tras el primer fotograma.
class IntroMarca extends StatefulWidget {
  const IntroMarca({
    super.key,
    this.alto = 64,
    this.tono,
    this.pegatina = true,
    this.lema,
    this.retraso = Duration.zero,
    this.onTerminada,
    this.etiqueta = 'TuTurno',
  }) : assert(alto >= LogoTuTurno.altoMinimo);

  /// Lo que dura la animación (sin contar [retraso]).
  static const duracionTotal = Duration(milliseconds: 1400);

  final double alto;

  /// Tono de las letras; por defecto, el del tema. Sobre un fondo de color, mejor [TonoMarca.amarillo] o
  /// [TonoMarca.blanco] (sobre azul) o [TonoMarca.azulNoche] (sobre amarillo).
  final TonoMarca? tono;

  /// Borde blanco y sombra de pegatina en cada letra.
  final bool pegatina;

  /// Lo que aparece debajo al final (por ejemplo, `Text('¡Es tu turno!')`).
  final Widget? lema;

  /// Espera antes de empezar (por ejemplo, para enlazar con la pantalla de arranque).
  final Duration retraso;
  final VoidCallback? onTerminada;
  final String? etiqueta;

  @override
  State<IntroMarca> createState() => _IntroMarcaState();
}

class _IntroMarcaState extends State<IntroMarca> with SingleTickerProviderStateMixin {
  /// Cada letra empieza [_paso] después de la anterior y tarda [_porLetra] en asentarse.
  static const _paso = 75.0;
  static const _porLetra = 430.0;

  /// Cuándo empieza a aparecer el lema y cuánto tarda (ms desde el inicio, sin el retraso).
  static const _inicioLema = 820.0;
  static const _duracionLema = 480.0;

  /// Giro inicial de cada letra (radianes): alterno, para que parezcan pegadas a mano.
  static const _giros = [-0.32, 0.24, -0.2, 0.3, -0.26, 0.2, -0.3];
  static const _escalaInicial = 1.8;

  late final AnimationController _controlador = AnimationController(vsync: this);
  bool _preparada = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preparada) return;
    _preparada = true;
    if (duracion(context, IntroMarca.duracionTotal) == Duration.zero) {
      _controlador.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onTerminada?.call();
      });
      return;
    }
    // El retraso va dentro de la propia animación: así no hay temporizadores sueltos.
    _controlador
      ..duration = widget.retraso + IntroMarca.duracionTotal
      ..addStatusListener((estado) {
        if (estado == AnimationStatus.completed) widget.onTerminada?.call();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  /// Milisegundos de animación transcurridos, sin contar el retraso.
  double get _ms {
    final total = (widget.retraso + IntroMarca.duracionTotal).inMilliseconds;
    return _controlador.value * total - widget.retraso.inMilliseconds;
  }

  List<PosePieza> _poses() {
    final ms = _ms;
    return [for (var i = 0; i < TrazosLogo.letras.length; i++) _pose(i, ms)];
  }

  PosePieza _pose(int i, double ms) {
    final t = ((ms - i * _paso) / _porLetra).clamp(0.0, 1.0);
    if (t >= 1) return PosePieza.reposo;
    if (t <= 0) return const PosePieza(opacidad: 0);
    final caida = Curves.easeOutCubic.transform(t);
    return PosePieza(
      desplazamiento: Offset(0, -(1 - caida) * TrazosLogo.alto * 0.45),
      // easeOutBack se pasa un poco de 1: la letra se aplasta al tocar el papel y vuelve a su tamaño.
      escala: _escalaInicial + (1 - _escalaInicial) * Curves.easeOutBack.transform(t),
      giro: _giros[i % _giros.length] * (1 - caida),
      opacidad: (t / 0.25).clamp(0.0, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logo = CustomPaint(
      size: Size(widget.alto * LogoTuTurno.proporcion, widget.alto),
      painter: PintorMarca(
        trazos: TrazosLogo.letras,
        lienzo: const Size(TrazosLogo.ancho, TrazosLogo.alto),
        color: (widget.tono ?? TonoMarca.delTema(context)).color,
        pegatina: widget.pegatina,
        colorSombra: sombraPapelDe(context),
        poses: _poses,
        repaint: _controlador,
      ),
    );
    final etiqueta = widget.etiqueta;
    final lema = widget.lema;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (etiqueta == null)
          ExcludeSemantics(child: logo)
        else
          Semantics(label: etiqueta, image: true, excludeSemantics: true, child: logo),
        if (lema != null) ...[
          const SizedBox(height: Espacio.m),
          AnimatedBuilder(
            animation: _controlador,
            builder: (context, hijo) {
              final t = Curves.easeOutCubic.transform(((_ms - _inicioLema) / _duracionLema).clamp(0.0, 1.0));
              return Opacity(
                opacity: t,
                child: Transform.translate(offset: Offset(0, (1 - t) * Espacio.m), child: hijo),
              );
            },
            child: lema,
          ),
        ],
      ],
    );
  }
}
