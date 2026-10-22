import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../tema.dart';
import 'hapticos.dart';

/// Un sello oficial que cae sobre el papel: baja desde arriba, golpea (vibración fuerte), se aplasta un poco y la tinta
/// se corre alrededor. Para los sellos del pasaporte de derechos y los logros.
///
/// Con [estampado] en false no se ve (deja su hueco); al pasar a true, cae. Con [animar] en false aparece ya puesto,
/// sin vibrar (los sellos que ya tenías). Con «reducir animaciones», aparece puesto y vibra.
class SelloAnimado extends StatefulWidget {
  const SelloAnimado({
    super.key,
    required this.child,
    this.estampado = true,
    this.animar = true,
    this.retraso = Duration.zero,
    this.inclinacion = -0.16,
    this.colorTinta,
    this.vibrar = true,
    this.alEstampar,
  });

  final Widget child;
  final bool estampado;
  final bool animar;
  final Duration retraso;

  /// Giro final del sello, en radianes (los sellos nunca quedan rectos).
  final double inclinacion;

  /// Color de la tinta que se corre. Por defecto, el de los sellos del tema.
  final Color? colorTinta;
  final bool vibrar;

  /// Se llama al golpear el papel (para sincronizar confeti o un mensaje).
  final VoidCallback? alEstampar;

  @override
  State<SelloAnimado> createState() => _SelloAnimadoState();
}

class _SelloAnimadoState extends State<SelloAnimado> with SingleTickerProviderStateMixin {
  static const _caida = Duration(milliseconds: 760);

  /// Momento del golpe, dentro de la caída.
  static const _golpe = 0.42;

  late final AnimationController _controlador = AnimationController(vsync: this)..addListener(_vigilarGolpe);
  double _inicio = 0;
  bool _golpeado = false;
  bool _iniciado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    if (!widget.estampado) return;
    if (widget.animar) {
      _estampar();
    } else {
      _golpeado = true;
      _controlador.value = 1;
    }
  }

  @override
  void didUpdateWidget(SelloAnimado anterior) {
    super.didUpdateWidget(anterior);
    if (widget.estampado == anterior.estampado) return;
    if (widget.estampado) {
      _estampar();
    } else {
      _controlador.value = 0;
      _golpeado = false;
    }
  }

  void _estampar() {
    _golpeado = false;
    final caida = duracion(context, _caida);
    if (caida == Duration.zero) {
      _controlador.value = 1;
      // Sin animación también hay golpe: se avisa después de este fotograma, no durante la construcción.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _alGolpear();
      });
      return;
    }
    final total = widget.retraso + caida;
    _inicio = widget.retraso.inMicroseconds / total.inMicroseconds;
    _controlador
      ..duration = total
      ..forward(from: 0);
  }

  /// Progreso de la caída (0 → 1) sin el retraso.
  double get _t => _inicio >= 1 ? 1 : ((_controlador.value - _inicio) / (1 - _inicio)).clamp(0.0, 1.0);

  void _vigilarGolpe() {
    if (!_golpeado && _controlador.isAnimating && _t >= _golpe) _alGolpear();
  }

  void _alGolpear() {
    _golpeado = true;
    if (widget.vibrar) Hapticos.sello();
    widget.alEstampar?.call();
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tinta = widget.colorTinta ?? context.colores.sello;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controlador,
        // El sello se pinta una vez; en cada fotograma solo cambian su transformación y la tinta.
        child: RepaintBoundary(child: widget.child),
        builder: (context, sello) {
          final t = _t;
          final antes = _controlador.value <= _inicio && _controlador.value < 1;
          final caida = Curves.easeInCubic.transform((t / _golpe).clamp(0.0, 1.0));
          final despues = ((t - _golpe) / (1 - _golpe)).clamp(0.0, 1.0);
          // Aplastado al golpear: baja a 0,92 y vuelve.
          final aplastado = despues < 0.35 ? 1 - 0.08 * math.sin(despues / 0.35 * math.pi) : 1.0;
          final escala = (t < _golpe ? 2.3 - 1.3 * caida : 1.0) * aplastado;
          final giro = widget.inclinacion - 0.45 * (1 - Curves.easeOutCubic.transform((t / _golpe).clamp(0.0, 1.0)));
          final opacidad = antes ? 0.0 : (t / 0.12).clamp(0.0, 1.0);
          return CustomPaint(
            painter: _PintorTinta(progreso: t < _golpe ? -caida : despues, color: tinta),
            child: Opacity(
              opacity: opacidad,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..rotateZ(giro)
                  ..scaleByDouble(escala, escala, 1, 1),
                child: sello,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Debajo del sello: su sombra mientras cae (valores negativos de [progreso], de 0 a −1) y la tinta que se corre
/// después del golpe (de 0 a 1).
class _PintorTinta extends CustomPainter {
  _PintorTinta({required this.progreso, required this.color});

  final double progreso;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final radio = size.shortestSide / 2;
    if (progreso < 0) {
      // La sombra se concentra a medida que el sello se acerca al papel.
      final cerca = -progreso;
      canvas.drawCircle(
        centro.translate(0, radio * 0.08),
        radio * (1.25 - 0.3 * cerca),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18 * cerca)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 - 8 * cerca),
      );
      return;
    }
    if (progreso <= 0 || progreso >= 1) return;
    final e = Curves.easeOutCubic.transform(progreso);
    final desvanecido = 1 - progreso;
    // Un anillo de tinta que se abre y se apaga…
    canvas.drawCircle(
      centro,
      radio * (0.9 + 0.5 * e),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radio * 0.12 * desvanecido
        ..color = color.withValues(alpha: 0.35 * desvanecido),
    );
    // …y unas gotitas que salpican.
    for (var i = 0; i < 7; i++) {
      final angulo = i * 2 * math.pi / 7 + 0.4;
      final distancia = radio * (1.0 + 0.45 * e + 0.08 * (i % 3));
      canvas.drawCircle(
        centro + Offset(math.cos(angulo), math.sin(angulo)) * distancia,
        radio * (0.035 + 0.02 * (i % 2)) * desvanecido,
        Paint()..color = color.withValues(alpha: 0.6 * desvanecido),
      );
    }
  }

  @override
  bool shouldRepaint(_PintorTinta anterior) => anterior.progreso != progreso || anterior.color != color;
}

/// Sello redondo de tinta, como los de los documentos oficiales: doble aro, un texto alrededor y, en el centro, un
/// icono y una palabra. Los aros tienen pequeñas imperfecciones de tinta (siempre las mismas para el mismo texto); las
/// letras quedan limpias.
class Sello extends StatelessWidget {
  const Sello({
    super.key,
    required this.texto,
    this.icono,
    this.textoCircular = 'TUTURNO · PASAPORTE DE DERECHOS · ',
    this.color,
    this.tamano = 120,
    this.semanticLabel,
  });

  /// Palabra del centro (corta: «OÍDO», «HECHO»…).
  final String texto;
  final IconData? icono;
  final String textoCircular;

  /// Color de la tinta. Por defecto, el de los sellos del tema (con contraste sobre la superficie).
  final Color? color;
  final double tamano;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Semantics(
      image: true,
      label: semanticLabel ?? 'Sello: $texto',
      child: ExcludeSemantics(
        child: CustomPaint(
          size: Size.square(tamano),
          painter: _PintorSello(
            texto: texto.toUpperCase(),
            icono: icono,
            textoCircular: textoCircular.toUpperCase(),
            color: color ?? context.colores.sello,
            estiloCentro: tema.textTheme.headlineSmall ?? const TextStyle(),
            estiloCircular: tema.textTheme.labelSmall ?? const TextStyle(),
            escalaTexto: MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.15),
          ),
        ),
      ),
    );
  }
}

class _PintorSello extends CustomPainter {
  _PintorSello({
    required this.texto,
    required this.icono,
    required this.textoCircular,
    required this.color,
    required this.estiloCentro,
    required this.estiloCircular,
    required this.escalaTexto,
  });

  final String texto;
  final IconData? icono;
  final String textoCircular;
  final Color color;
  final TextStyle estiloCentro;
  final TextStyle estiloCircular;
  final double escalaTexto;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final centro = size.center(Offset.zero);
    final limites = Offset.zero & size;
    // Todo en una capa, para poder «comerse» la tinta con las imperfecciones al final.
    canvas.saveLayer(limites.inflate(2), Paint());
    final aro = Paint()
      ..style = PaintingStyle.stroke
      ..color = color;
    canvas
      ..drawCircle(centro, r * 0.95, aro..strokeWidth = r * 0.07)
      ..drawCircle(centro, r * 0.68, aro..strokeWidth = r * 0.03);

    // Texto alrededor, entre los dos aros.
    final estilo = estiloCircular.copyWith(
      color: color,
      fontSize: r * 0.15,
      fontWeight: FontWeight.w700,
      letterSpacing: r * 0.02,
    );
    final radioTexto = r * 0.815;
    var angulo = -math.pi / 2;
    final caracteres = textoCircular.characters.toList();
    final pintores = [
      for (final c in caracteres)
        TextPainter(
          text: TextSpan(text: c, style: estilo),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    final largo = pintores.fold<double>(0, (suma, p) => suma + p.width);
    // Si el texto no da la vuelta entera, se reparte para que la dé.
    final ajuste = (2 * math.pi * radioTexto) / math.max(largo, 1);
    angulo -= (pintores.first.width * ajuste / radioTexto) / 2;
    for (final pintor in pintores) {
      final paso = pintor.width * ajuste / radioTexto;
      canvas
        ..save()
        ..translate(centro.dx, centro.dy)
        ..rotate(angulo + paso / 2 + math.pi / 2)
        ..translate(-pintor.width / 2, -radioTexto - pintor.height / 2);
      pintor.paint(canvas, Offset.zero);
      canvas.restore();
      angulo += paso;
      pintor.dispose();
    }

    // Centro: icono y palabra.
    final icono = this.icono;
    var alturaIcono = 0.0;
    TextPainter? pintorIcono;
    if (icono != null) {
      pintorIcono = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icono.codePoint),
          style: TextStyle(
            fontFamily: icono.fontFamily,
            package: icono.fontPackage,
            fontSize: r * 0.42,
            color: color,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      alturaIcono = pintorIcono.height;
    }
    final pintorTexto = TextPainter(
      text: TextSpan(
        text: texto,
        style: estiloCentro.copyWith(
          color: color,
          fontSize: r * 0.26 * escalaTexto,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: r * 1.2);
    final altoTotal = alturaIcono + pintorTexto.height;
    var y = centro.dy - altoTotal / 2;
    if (pintorIcono != null) {
      pintorIcono.paint(canvas, Offset(centro.dx - pintorIcono.width / 2, y));
      y += alturaIcono;
      pintorIcono.dispose();
    }
    pintorTexto.paint(canvas, Offset(centro.dx - pintorTexto.width / 2, y));
    pintorTexto.dispose();

    // Imperfecciones de la tinta: motas que no se imprimieron. Solo en los dos aros: en las letras costaría leerlas.
    final borra = Paint()..blendMode = BlendMode.dstOut;
    var semilla = texto.hashCode & 0x7fffffff;
    double azar() {
      semilla = (semilla * 1103515245 + 12345) & 0x7fffffff;
      return semilla / 0x7fffffff;
    }

    for (var i = 0; i < 40; i++) {
      final exterior = i < 28;
      final a = azar() * 2 * math.pi;
      final d = r * (exterior ? 0.93 + 0.055 * azar() : 0.665 + 0.03 * azar());
      final radio = r * (exterior ? 0.012 + 0.02 * azar() : 0.006 + 0.01 * azar());
      canvas.drawCircle(centro + Offset(math.cos(a), math.sin(a)) * d, radio, borra);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorSello anterior) =>
      anterior.texto != texto ||
      anterior.icono != icono ||
      anterior.textoCircular != textoCircular ||
      anterior.color != color ||
      anterior.estiloCentro != estiloCentro ||
      anterior.estiloCircular != estiloCircular ||
      anterior.escalaTexto != escalaTexto;
}
