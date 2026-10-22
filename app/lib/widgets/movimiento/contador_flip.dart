import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../tema.dart';
import 'paleta.dart';

/// Número que cambia como un panel de aeropuerto: cada cifra es una paleta partida que gira, cifra a cifra, hasta la
/// nueva (7 → 8 → 9 → 0). Con [desde], al aparecer gira desde ese número. Con «reducir animaciones», cambia sin girar.
class ContadorFlip extends StatelessWidget {
  const ContadorFlip({
    super.key,
    required this.valor,
    this.digitos = 1,
    this.desde,
    this.estilo,
    this.fondo,
    this.color,
    this.semanticsLabel,
  });

  final int valor;

  /// Cifras mínimas (se rellena con ceros: 7 con 2 cifras es «07»).
  final int digitos;
  final int? desde;
  final TextStyle? estilo;
  final Color? fondo;
  final Color? color;

  /// Lo que lee el lector de pantalla (por defecto, el número).
  final String? semanticsLabel;

  static String _texto(int valor, int digitos) {
    final cifras = valor.abs().toString().padLeft(digitos, '0');
    return valor < 0 ? '-$cifras' : cifras;
  }

  @override
  Widget build(BuildContext context) {
    final desde = this.desde;
    return PanelFlip(
      texto: _texto(valor, digitos),
      desde: desde == null ? null : _texto(desde, digitos),
      estilo: estilo,
      fondo: fondo,
      color: color,
      semanticsLabel: semanticsLabel ?? '$valor',
    );
  }
}

/// Panel de paletas partidas para un texto corto («A-12», «07»). Las cifras giran en orden; el resto de caracteres,
/// directamente al nuevo.
class PanelFlip extends StatelessWidget {
  const PanelFlip({
    super.key,
    required this.texto,
    this.desde,
    this.estilo,
    this.fondo,
    this.color,
    this.semanticsLabel,
    this.separacion = 3,
  });

  final String texto;
  final String? desde;

  /// Estilo de los caracteres. Por defecto, el titular del tema (la letra de títulos), en negrita.
  final TextStyle? estilo;

  /// Color de las paletas. Por defecto, azul noche (azul en el tema oscuro).
  final Color? fondo;

  /// Color de los caracteres. Por defecto, amarillo si tiene contraste AA con [fondo].
  final Color? color;
  final String? semanticsLabel;
  final double separacion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final fondo =
        this.fondo ?? (tema.brightness == Brightness.dark ? PaletaMovimiento.azul : PaletaMovimiento.azulNoche);
    final color = this.color ?? PaletaMovimiento.tintaSobre(fondo, preferida: PaletaMovimiento.amarillo);
    final base = this.estilo ?? tema.textTheme.headlineMedium ?? const TextStyle(fontSize: 28);
    final estilo = base.copyWith(
      color: color,
      fontWeight: FontWeight.w700,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final caracteres = texto.characters.toList();
    final previos = desde?.characters.toList();
    final celda = _medirCelda(estilo, MediaQuery.textScalerOf(context), {...caracteres, ...?previos});
    String? previo(int i) {
      if (previos == null) return null;
      final j = previos.length - (caracteres.length - i);
      return j >= 0 ? previos[j] : null;
    }

    return Semantics(
      container: true,
      label: semanticsLabel ?? texto,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < caracteres.length; i++) ...[
                if (i > 0) SizedBox(width: separacion),
                _Paleta(
                  // Alineadas por la derecha: al pasar de 99 a 100, las unidades siguen siendo la misma paleta.
                  key: ValueKey(caracteres.length - i),
                  caracter: caracteres[i],
                  desde: previo(i),
                  estilo: estilo,
                  fondo: fondo,
                  tamano: celda,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Size _medirCelda(TextStyle estilo, TextScaler escala, Set<String> caracteres) {
    var ancho = 0.0;
    var alto = 0.0;
    for (final c in {...caracteres, '0', '8'}) {
      final pintor = TextPainter(
        text: TextSpan(text: c, style: estilo),
        textDirection: TextDirection.ltr,
        textScaler: escala,
        maxLines: 1,
      )..layout();
      ancho = math.max(ancho, pintor.width);
      alto = math.max(alto, pintor.height);
      pintor.dispose();
    }
    return Size((ancho + alto * 0.36).ceilToDouble(), (alto * 1.32).ceilToDouble());
  }
}

class _Paleta extends StatefulWidget {
  const _Paleta({
    super.key,
    required this.caracter,
    required this.desde,
    required this.estilo,
    required this.fondo,
    required this.tamano,
  });

  final String caracter;
  final String? desde;
  final TextStyle estilo;
  final Color fondo;
  final Size tamano;

  @override
  State<_Paleta> createState() => _PaletaState();
}

class _PaletaState extends State<_Paleta> with SingleTickerProviderStateMixin {
  /// Tiempo máximo de un cambio, con todas sus vueltas.
  static const _total = Duration(milliseconds: 720);

  late final AnimationController _giro = AnimationController(vsync: this)..addStatusListener(_alTerminarVuelta);
  late String _actual = widget.desde ?? widget.caracter;
  String? _siguiente;
  final _cola = <String>[];
  bool _iniciada = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciada) return;
    _iniciada = true;
    if (_actual != widget.caracter) _irA(widget.caracter);
  }

  @override
  void didUpdateWidget(_Paleta anterior) {
    super.didUpdateWidget(anterior);
    if (widget.caracter != anterior.caracter) _irA(widget.caracter);
  }

  void _irA(String destino) {
    if (duracion(context, _total) == Duration.zero) {
      _giro.stop();
      _cola.clear();
      _siguiente = null;
      _actual = destino;
      return;
    }
    final origen = _siguiente ?? _actual;
    _cola
      ..clear()
      ..addAll(_recorrido(origen, destino));
    final vueltas = _cola.length + (_siguiente == null ? 0 : 1);
    _giro.duration = Duration(milliseconds: (_total.inMilliseconds / math.max(1, vueltas)).clamp(70, 200).round());
    if (_siguiente == null) _siguienteVuelta();
  }

  /// Cifras: una a una hacia delante, como un panel de verdad. Lo demás: directo al nuevo.
  static List<String> _recorrido(String desde, String hasta) {
    final a = int.tryParse(desde);
    final b = int.tryParse(hasta);
    if (a == null || b == null || desde.length != 1 || hasta.length != 1 || a == b) return [hasta];
    final pasos = <String>[];
    var d = a;
    do {
      d = (d + 1) % 10;
      pasos.add('$d');
    } while (d != b);
    return pasos;
  }

  void _siguienteVuelta() {
    if (_cola.isEmpty) return;
    _siguiente = _cola.removeAt(0);
    _giro.forward(from: 0);
  }

  void _alTerminarVuelta(AnimationStatus estado) {
    if (estado != AnimationStatus.completed || !mounted) return;
    setState(() {
      _actual = _siguiente ?? _actual;
      _siguiente = null;
      _siguienteVuelta();
    });
  }

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  Widget _cara(String caracter) => Container(
    width: widget.tamano.width,
    height: widget.tamano.height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(widget.tamano.width * 0.16),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(widget.fondo, Colors.white, 0.1)!, widget.fondo],
      ),
    ),
    child: Text(caracter, style: widget.estilo, textAlign: TextAlign.center, maxLines: 1),
  );

  Widget _mitad(String caracter, {required bool arriba, double sombra = 0}) => ClipRect(
    child: Align(
      alignment: arriba ? Alignment.topCenter : Alignment.bottomCenter,
      heightFactor: 0.5,
      child: Container(
        foregroundDecoration: sombra > 0
            ? BoxDecoration(
                color: Colors.black.withValues(alpha: sombra),
                borderRadius: BorderRadius.circular(widget.tamano.width * 0.16),
              )
            : null,
        child: _cara(caracter),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final alto = widget.tamano.height;
    // La bisagra: la raya que parte la paleta en dos.
    final bisagra = Positioned(
      left: 0,
      right: 0,
      top: alto / 2 - 0.75,
      height: 1.5,
      child: ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
    );
    final siguiente = _siguiente;
    if (siguiente == null) {
      return SizedBox.fromSize(
        size: widget.tamano,
        child: Stack(children: [_cara(_actual), bisagra]),
      );
    }
    return AnimatedBuilder(
      animation: _giro,
      builder: (context, _) {
        final p = _giro.value;
        final perspectiva = Matrix4.identity()..setEntry(3, 2, 0.006);
        return SizedBox.fromSize(
          size: widget.tamano,
          child: Stack(
            children: [
              Positioned(top: 0, left: 0, right: 0, height: alto / 2, child: _mitad(siguiente, arriba: true)),
              Positioned(bottom: 0, left: 0, right: 0, height: alto / 2, child: _mitad(_actual, arriba: false)),
              if (p < 0.5)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: alto / 2,
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: perspectiva..rotateX(math.pi * p),
                    child: _mitad(_actual, arriba: true, sombra: 0.4 * p),
                  ),
                )
              else
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: alto / 2,
                  child: Transform(
                    alignment: Alignment.topCenter,
                    transform: perspectiva..rotateX(-math.pi * (1 - p)),
                    child: _mitad(siguiente, arriba: false, sombra: 0.4 * (1 - p)),
                  ),
                ),
              bisagra,
            ],
          ),
        );
      },
    );
  }
}
