import 'package:flutter/material.dart';

import '../../tema.dart';
import 'hapticos.dart';

/// Aparece como una pegatina que se pega: crece de golpe un poco más de la cuenta, gira y se asienta ligeramente
/// torcida. [orden] escalona varias (como `Entrada`); al cambiar [clave], vuelve a hacer «pop» (para un +10 XP, por
/// ejemplo). Con «reducir animaciones», aparece ya puesta.
class PopPegatina extends StatefulWidget {
  const PopPegatina({
    super.key,
    required this.child,
    this.orden = 0,
    this.retraso = Duration.zero,
    this.inclinacion = -0.05,
    this.giroInicial = 0.35,
    this.animar = true,
    this.clave,
    this.vibrar = false,
  });

  final Widget child;
  final int orden;
  final Duration retraso;

  /// Giro final en radianes (las pegatinas nunca quedan rectas).
  final double inclinacion;

  /// Giro extra al empezar, que se deshace al pegarse.
  final double giroInicial;
  final bool animar;
  final Object? clave;

  /// Vibración suave al pegarse.
  final bool vibrar;

  @override
  State<PopPegatina> createState() => _PopPegatinaState();
}

class _PopPegatinaState extends State<PopPegatina> with SingleTickerProviderStateMixin {
  static const _pop = Duration(milliseconds: 520);
  static const _paso = Duration(milliseconds: 70);

  static final _escala = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.14).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 55),
    TweenSequenceItem(tween: Tween(begin: 1.14, end: 0.96).chain(CurveTween(curve: Curves.easeInOut)), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 20),
  ]);

  late final AnimationController _controlador = AnimationController(vsync: this, value: widget.animar ? 0 : 1)
    ..addStatusListener(_alTerminar);
  double _inicio = 0;
  bool _iniciada = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciada) return;
    _iniciada = true;
    if (widget.animar) _hacerPop(conRetraso: true);
  }

  @override
  void didUpdateWidget(PopPegatina anterior) {
    super.didUpdateWidget(anterior);
    if (widget.clave != anterior.clave) _hacerPop(conRetraso: false);
  }

  void _hacerPop({required bool conRetraso}) {
    final pop = duracion(context, _pop);
    if (pop == Duration.zero) {
      _controlador.value = 1;
      return;
    }
    final retraso = conRetraso ? widget.retraso + _paso * widget.orden : Duration.zero;
    final total = retraso + pop;
    _inicio = retraso.inMicroseconds / total.inMicroseconds;
    _controlador
      ..duration = total
      ..forward(from: 0);
  }

  void _alTerminar(AnimationStatus estado) {
    if (estado == AnimationStatus.completed && widget.vibrar && _controlador.duration != null) Hapticos.toque();
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controlador,
      child: widget.child,
      builder: (context, child) {
        final t = _inicio >= 1 ? 1.0 : ((_controlador.value - _inicio) / (1 - _inicio)).clamp(0.0, 1.0);
        final giro = widget.inclinacion + widget.giroInicial * (1 - Curves.easeOutBack.transform(t));
        return Opacity(
          opacity: (t / 0.2).clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..rotateZ(giro)
              ..scaleByDouble(_escala.transform(t), _escala.transform(t), 1, 1),
            child: child,
          ),
        );
      },
    );
  }
}
