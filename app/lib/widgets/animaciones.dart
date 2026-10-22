import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tema.dart';

// Movimiento de TuTurno: entradas escalonadas, superficies que se «hunden» al pulsarlas y un anillo
// que señala algo importante. Todo respeta la opción del sistema de reducir animaciones (duracion()).

/// Retraso entre elementos de una entrada escalonada.
const _pasoEscalonado = Duration(milliseconds: 70);

/// Escala de una superficie mientras se mantiene pulsada.
const _escalaPulsada = 0.97;

/// Aparece con un fundido y un pequeño desplazamiento hacia arriba. [orden] escalona la entrada:
/// el elemento 0 entra primero y cada siguiente un poco después. [retraso] espera además antes de empezar (por
/// ejemplo, a que acabe la presentación del logotipo).
class Entrada extends StatefulWidget {
  const Entrada({
    super.key,
    required this.child,
    this.orden = 0,
    this.desplazamiento = Espacio.l,
    this.retraso = Duration.zero,
  });

  final Widget child;
  final int orden;
  final double desplazamiento;
  final Duration retraso;

  @override
  State<Entrada> createState() => _EntradaState();
}

class _EntradaState extends State<Entrada> with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(vsync: this);
  CurvedAnimation? _curva;
  Animation<double>? _progreso;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_progreso != null) return;
    final base = duracion(context, Duracion.larga);
    if (base == Duration.zero) {
      _controlador.value = 1;
      _progreso = _controlador;
      return;
    }
    final retraso = widget.retraso + _pasoEscalonado * widget.orden;
    final total = base + retraso;
    _controlador.duration = total;
    _curva = CurvedAnimation(
      parent: _controlador,
      curve: Interval(retraso.inMicroseconds / total.inMicroseconds, 1, curve: Curves.easeOutCubic),
    );
    _progreso = _curva;
    _controlador.forward();
  }

  @override
  void dispose() {
    _curva?.dispose();
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progreso = _progreso!;
    return FadeTransition(
      opacity: progreso,
      child: AnimatedBuilder(
        animation: progreso,
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, (1 - progreso.value) * widget.desplazamiento), child: child),
        child: widget.child,
      ),
    );
  }
}

/// Superficie pulsable: onda de Material, un pequeño hundimiento mientras se pulsa y, si [vibrar],
/// una vibración suave al soltar. [decoracion] se pinta debajo de la onda (degradado o color).
class Pulsable extends StatefulWidget {
  const Pulsable({
    super.key,
    required this.child,
    required this.onTap,
    this.decoracion,
    this.radio = Radios.l,
    this.sombras = const [],
    this.vibrar = true,
  });

  final Widget child;
  final VoidCallback onTap;
  final BoxDecoration? decoracion;
  final double radio;
  final List<BoxShadow> sombras;
  final bool vibrar;

  @override
  State<Pulsable> createState() => _PulsableState();
}

class _PulsableState extends State<Pulsable> {
  bool _pulsado = false;

  void _alPulsar() {
    if (widget.vibrar) HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(widget.radio);
    return AnimatedScale(
      scale: _pulsado ? _escalaPulsada : 1,
      duration: duracion(context, Duracion.corta),
      curve: Curves.easeOutCubic,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: forma, boxShadow: widget.sombras),
        child: ClipRRect(
          borderRadius: forma,
          child: Material(
            type: MaterialType.transparency,
            child: Ink(
              decoration: widget.decoracion,
              child: InkWell(
                onTap: _alPulsar,
                onHighlightChanged: (pulsado) => setState(() => _pulsado = pulsado),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Anillo que se expande y se desvanece alrededor de [child] unas pocas veces, para señalar algo
/// (por ejemplo, el botón de Ayuda en la bienvenida). No se repite sin fin: así no distrae.
class AnilloPulso extends StatefulWidget {
  const AnilloPulso({super.key, required this.child, required this.color, this.activo = true, this.veces = 3});

  final Widget child;
  final Color color;
  final bool activo;
  final int veces;

  @override
  State<AnilloPulso> createState() => _AnilloPulsoState();
}

class _AnilloPulsoState extends State<AnilloPulso> with SingleTickerProviderStateMixin {
  static const _periodo = Duration(milliseconds: 1400);
  static const _crecimiento = 0.35;

  late final AnimationController _controlador = AnimationController(vsync: this, duration: _periodo);

  /// Para no repetir los pulsos cada vez que cambia algo del entorno (teclado, tamaño de letra…).
  bool _yaPulso = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _actualizar();
  }

  @override
  void didUpdateWidget(AnilloPulso anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.activo != widget.activo) {
      _yaPulso = false;
      _actualizar();
    }
  }

  void _actualizar() {
    final hayMovimiento = duracion(context, _periodo) != Duration.zero;
    if (widget.activo && hayMovimiento) {
      if (_yaPulso) return;
      _yaPulso = true;
      _controlador.repeat(count: widget.veces);
    } else {
      _controlador
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controlador,
              builder: (context, _) {
                // Al acabar, repeat(count:) puede quedarse a medio ciclo: el anillo solo se ve mientras late.
                if (!_controlador.isAnimating) return const SizedBox.shrink();
                final t = Curves.easeOut.transform(_controlador.value);
                return Transform.scale(
                  scale: 1 + t * _crecimiento,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: StadiumBorder(
                        side: BorderSide(color: widget.color.withValues(alpha: 1 - t), width: 3),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}
