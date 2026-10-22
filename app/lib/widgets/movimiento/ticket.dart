import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../tema.dart';
import 'hapticos.dart';
import 'paleta.dart';

/// Dónde está el talón del ticket: la parte pequeña que se arranca por la línea de puntos.
enum LadoTalon {
  /// Ticket apaisado: el talón a la derecha y las muescas arriba y abajo.
  derecha,

  /// Ticket vertical: el talón abajo y las muescas a los lados.
  abajo,
}

/// Forma de ticket de turno: esquinas redondeadas y dos muescas semicirculares en los bordes, justo donde se arranca.
///
/// Con [talon] (en píxeles lógicos), la línea de corte queda a esa distancia del borde derecho (o del de abajo, según
/// [ladoTalon]); sin él, las muescas van en el centro. Si [perforado], pinta la línea de puntos entre las muescas, y
/// con [colorTalon] el talón va de otro color (tickets a dos tintas, amarillo y azul).
///
/// Sirve en cualquier sitio que acepte un [ShapeBorder]: [ShapeDecoration], [Material], [Card] o
/// `InkWell.customBorder`.
class TicketBorder extends OutlinedBorder {
  const TicketBorder({
    super.side,
    this.radio = 18,
    this.radioMuesca = 10,
    this.talon,
    this.ladoTalon = LadoTalon.derecha,
    this.perforado = true,
    this.colorPerforado,
    this.colorTalon,
  });

  final double radio;
  final double radioMuesca;

  /// Distancia de la línea de corte al borde del talón. Null: muescas en el centro.
  final double? talon;
  final LadoTalon ladoTalon;
  final bool perforado;

  /// Color de los puntos. Por defecto, el del borde o azul noche translúcido.
  final Color? colorPerforado;

  /// Si no es null, el talón se pinta de este color.
  final Color? colorTalon;

  bool get _apaisado => ladoTalon == LadoTalon.derecha;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(math.max(side.strokeInset, 0));

  double _radio(Rect rect) => math.max(0, math.min(radio, rect.shortestSide / 2));

  double _muesca(Rect rect) => math.max(0, math.min(radioMuesca, (_apaisado ? rect.height : rect.width) / 4));

  /// Coordenada de la línea de corte dentro de [rect]: x en un ticket apaisado, y en uno vertical.
  double corte(Rect rect) {
    final inicio = _apaisado ? rect.left : rect.top;
    final largo = _apaisado ? rect.width : rect.height;
    final minimo = inicio + _radio(rect) + _muesca(rect);
    final maximo = inicio + largo - _radio(rect) - _muesca(rect);
    if (minimo >= maximo) return inicio + largo / 2;
    return (inicio + largo - (talon ?? largo / 2)).clamp(minimo, maximo);
  }

  /// Rectángulo del talón dentro de [rect].
  Rect rectTalon(Rect rect) {
    final c = corte(rect);
    return _apaisado
        ? Rect.fromLTRB(c, rect.top, rect.right, rect.bottom)
        : Rect.fromLTRB(rect.left, c, rect.right, rect.bottom);
  }

  Path _contorno(Rect rect, double c, double r, double m) {
    final esquina = Radius.circular(r);
    final hueco = Radius.circular(m);
    final path = Path()..moveTo(rect.left + r, rect.top);
    if (_apaisado) {
      if (m > 0) {
        path
          ..lineTo(c - m, rect.top)
          ..arcToPoint(Offset(c + m, rect.top), radius: hueco, clockwise: false);
      }
      path
        ..lineTo(rect.right - r, rect.top)
        ..arcToPoint(Offset(rect.right, rect.top + r), radius: esquina)
        ..lineTo(rect.right, rect.bottom - r)
        ..arcToPoint(Offset(rect.right - r, rect.bottom), radius: esquina);
      if (m > 0) {
        path
          ..lineTo(c + m, rect.bottom)
          ..arcToPoint(Offset(c - m, rect.bottom), radius: hueco, clockwise: false);
      }
      path
        ..lineTo(rect.left + r, rect.bottom)
        ..arcToPoint(Offset(rect.left, rect.bottom - r), radius: esquina);
    } else {
      path
        ..lineTo(rect.right - r, rect.top)
        ..arcToPoint(Offset(rect.right, rect.top + r), radius: esquina);
      if (m > 0) {
        path
          ..lineTo(rect.right, c - m)
          ..arcToPoint(Offset(rect.right, c + m), radius: hueco, clockwise: false);
      }
      path
        ..lineTo(rect.right, rect.bottom - r)
        ..arcToPoint(Offset(rect.right - r, rect.bottom), radius: esquina)
        ..lineTo(rect.left + r, rect.bottom)
        ..arcToPoint(Offset(rect.left, rect.bottom - r), radius: esquina);
      if (m > 0) {
        path
          ..lineTo(rect.left, c + m)
          ..arcToPoint(Offset(rect.left, c - m), radius: hueco, clockwise: false);
      }
    }
    return path
      ..lineTo(rect.left, rect.top + r)
      ..arcToPoint(Offset(rect.left + r, rect.top), radius: esquina)
      ..close();
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _contorno(rect, corte(rect), _radio(rect), _muesca(rect));

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    final d = math.max(side.strokeInset, 0.0);
    return _contorno(rect.deflate(d), corte(rect), math.max(0, _radio(rect) - d), _muesca(rect) + d);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (rect.isEmpty) return;
    final c = corte(rect);
    final r = _radio(rect);
    final m = _muesca(rect);
    final colorTalon = this.colorTalon;
    if (colorTalon != null) {
      canvas
        ..save()
        ..clipPath(_contorno(rect, c, r, m))
        ..drawRect(rectTalon(rect), Paint()..color = colorTalon)
        ..restore();
    }
    if (perforado) _pintarPerforado(canvas, rect, c, m);
    switch (side.style) {
      case BorderStyle.none:
        break;
      case BorderStyle.solid:
        if (side.width == 0) {
          canvas.drawPath(_contorno(rect, c, r, m), side.toPaint());
        } else {
          // strokeOffset > 0: el trazo va por fuera; < 0, por dentro.
          final d = side.strokeOffset / 2;
          canvas.drawPath(_contorno(rect.inflate(d), c, math.max(0, r + d), math.max(0, m - d)), side.toPaint());
        }
    }
  }

  void _pintarPerforado(Canvas canvas, Rect rect, double c, double m) {
    final color = colorPerforado ?? (side.style == BorderStyle.none ? const Color(0x590E1A4F) : side.color);
    final pincel = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    const trazo = 4.0;
    const separacion = 5.0;
    final inicio = (_apaisado ? rect.top : rect.left) + m + separacion;
    final fin = (_apaisado ? rect.bottom : rect.right) - m - separacion;
    final cuantos = ((fin - inicio + separacion) / (trazo + separacion)).floor();
    if (cuantos <= 0) return;
    // Centrados entre las dos muescas.
    final sobra = (fin - inicio) - (cuantos * trazo + (cuantos - 1) * separacion);
    var p = inicio + sobra / 2;
    for (var i = 0; i < cuantos; i++, p += trazo + separacion) {
      if (_apaisado) {
        canvas.drawLine(Offset(c, p), Offset(c, p + trazo), pincel);
      } else {
        canvas.drawLine(Offset(p, c), Offset(p + trazo, c), pincel);
      }
    }
  }

  @override
  TicketBorder scale(double t) => TicketBorder(
    side: side.scale(t),
    radio: radio * t,
    radioMuesca: radioMuesca * t,
    talon: talon == null ? null : talon! * t,
    ladoTalon: ladoTalon,
    perforado: perforado,
    colorPerforado: colorPerforado,
    colorTalon: colorTalon,
  );

  @override
  TicketBorder copyWith({
    BorderSide? side,
    double? radio,
    double? radioMuesca,
    double? talon,
    LadoTalon? ladoTalon,
    bool? perforado,
    Color? colorPerforado,
    Color? colorTalon,
  }) => TicketBorder(
    side: side ?? this.side,
    radio: radio ?? this.radio,
    radioMuesca: radioMuesca ?? this.radioMuesca,
    talon: talon ?? this.talon,
    ladoTalon: ladoTalon ?? this.ladoTalon,
    perforado: perforado ?? this.perforado,
    colorPerforado: colorPerforado ?? this.colorPerforado,
    colorTalon: colorTalon ?? this.colorTalon,
  );

  /// Mezcla dos tickets con el mismo [ladoTalon] (para animar la forma).
  static TicketBorder lerp(TicketBorder a, TicketBorder b, double t) => TicketBorder(
    side: BorderSide.lerp(a.side, b.side, t),
    radio: lerpDouble(a.radio, b.radio, t)!,
    radioMuesca: lerpDouble(a.radioMuesca, b.radioMuesca, t)!,
    talon: a.talon == null || b.talon == null ? (t < 0.5 ? a.talon : b.talon) : lerpDouble(a.talon, b.talon, t),
    ladoTalon: t < 0.5 ? a.ladoTalon : b.ladoTalon,
    perforado: t < 0.5 ? a.perforado : b.perforado,
    colorPerforado: Color.lerp(a.colorPerforado, b.colorPerforado, t),
    colorTalon: Color.lerp(a.colorTalon, b.colorTalon, t),
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is TicketBorder && a.ladoTalon == ladoTalon) return TicketBorder.lerp(a, this, t);
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is TicketBorder && b.ladoTalon == ladoTalon) return TicketBorder.lerp(this, b, t);
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) =>
      other is TicketBorder &&
      other.side == side &&
      other.radio == radio &&
      other.radioMuesca == radioMuesca &&
      other.talon == talon &&
      other.ladoTalon == ladoTalon &&
      other.perforado == perforado &&
      other.colorPerforado == colorPerforado &&
      other.colorTalon == colorTalon;

  @override
  int get hashCode => Object.hash(side, radio, radioMuesca, talon, ladoTalon, perforado, colorPerforado, colorTalon);

  @override
  String toString() => 'TicketBorder($side, radio: $radio, muesca: $radioMuesca, talon: $talon, $ladoTalon)';
}

/// Ticket de turno, la pieza central de TuTurno: etiqueta, título, una línea de texto y, en el talón, un número grande.
///
/// Por defecto va a dos tintas: el papel de ticket del tema (`context.colores.ticket`, con su tinta) y el talón
/// amarillo con el número en azul noche (contraste AA o mejor). Los agujeros de la línea de puntos tienen el color de
/// la página ([colorPerforado]), como si estuviera troquelado de verdad.
///
/// Con [onTap] es pulsable: se hunde un poco, vibra suave y la onda respeta la forma del ticket. Para que el número
/// gire como un panel de aeropuerto, pasa un `ContadorFlip` en [talon].
class TicketTuTurno extends StatelessWidget {
  const TicketTuTurno({
    super.key,
    required this.titulo,
    this.descripcion,
    this.etiqueta,
    this.numero,
    this.etiquetaNumero = 'Nº',
    this.talon,
    this.tamanoTalon,
    this.icono,
    this.ladoTalon = LadoTalon.derecha,
    this.fondo,
    this.tinta,
    this.fondoTalon,
    this.tintaTalon,
    this.colorPerforado,
    this.contorno,
    this.inclinacion = 0,
    this.elevado = true,
    this.onTap,
    this.semanticLabel,
  });

  final String titulo;
  final String? descripcion;

  /// Texto corto encima del título («Tu turno», «Módulo»…). Se muestra en mayúsculas.
  final String? etiqueta;

  /// Número del talón («07», «A-12»).
  final String? numero;

  /// Lo que va encima del número («Nº», «Turno»…).
  final String etiquetaNumero;

  /// Contenido propio del talón (sustituye al número). Se encoge si no cabe.
  final Widget? talon;

  /// Ancho del talón (alto, si va abajo). Por defecto se mide con el número y el tamaño de letra.
  final double? tamanoTalon;

  /// Icono o ilustración a la izquierda del título. Es decorativo: no se lee.
  final Widget? icono;
  final LadoTalon ladoTalon;
  final Color? fondo;
  final Color? tinta;
  final Color? fondoTalon;
  final Color? tintaTalon;

  /// Color de los agujeros de la línea de puntos: el del fondo que hay detrás del ticket.
  final Color? colorPerforado;

  /// Contorno de pegatina (por ejemplo, blanco sobre azul noche).
  final Color? contorno;

  /// Inclinación en radianes, para el estilo de papel recortado (−0,02 ya se nota).
  final double inclinacion;
  final bool elevado;
  final VoidCallback? onTap;

  /// Si no es null, sustituye a todo lo que se leería del ticket.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final textos = tema.textTheme;
    final colores = context.colores;
    final fondo = this.fondo ?? colores.ticket;
    final fondoTalon = this.fondoTalon ?? PaletaMovimiento.amarillo;
    final tinta =
        this.tinta ?? PaletaMovimiento.tintaSobre(fondo, preferida: this.fondo == null ? colores.tintaTicket : null);
    final talonOscuro = ThemeData.estimateBrightnessForColor(fondoTalon) == Brightness.dark;
    final tintaTalon =
        this.tintaTalon ??
        PaletaMovimiento.tintaSobre(fondoTalon, preferida: talonOscuro ? PaletaMovimiento.amarillo : null);
    final apaisado = ladoTalon == LadoTalon.derecha;
    final escala = MediaQuery.textScalerOf(context);

    final estiloNumero = textos.displaySmall?.copyWith(
      color: tintaTalon,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final estiloEtiquetaNumero = textos.labelLarge?.copyWith(
      color: tintaTalon,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    );
    final numero = this.numero;
    final hayTalon = talon != null || numero != null;
    final talonMedido = hayTalon
        ? tamanoTalon ?? _medirTalon(apaisado, escala, estiloNumero, estiloEtiquetaNumero, numero)
        : null;

    TicketBorder formaPara(double? tamanoTalon) => TicketBorder(
      talon: tamanoTalon,
      ladoTalon: ladoTalon,
      colorTalon: hayTalon ? fondoTalon : null,
      perforado: hayTalon,
      colorPerforado: colorPerforado ?? tema.scaffoldBackgroundColor,
      side: contorno == null
          ? BorderSide.none
          : BorderSide(color: contorno!, width: 3, strokeAlign: BorderSide.strokeAlignOutside),
    );

    final etiqueta = this.etiqueta;
    final descripcion = this.descripcion;
    final cuerpo = Padding(
      padding: const EdgeInsets.fromLTRB(Espacio.l - Espacio.xs, Espacio.m + 2, Espacio.m, Espacio.m + 2),
      child: Row(
        children: [
          if (icono != null) ...[
            ExcludeSemantics(
              child: IconTheme.merge(
                data: IconThemeData(color: tinta, size: 40),
                child: icono!,
              ),
            ),
            const SizedBox(width: Espacio.m),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (etiqueta != null) ...[
                  Text(
                    etiqueta.toUpperCase(),
                    style: textos.labelLarge?.copyWith(color: tinta, fontWeight: FontWeight.w700, letterSpacing: 1.4),
                  ),
                  const SizedBox(height: Espacio.xs),
                ],
                Text(titulo, style: textos.headlineSmall?.copyWith(color: tinta, height: 1.15)),
                if (descripcion != null) ...[
                  const SizedBox(height: Espacio.xs),
                  Text(descripcion, style: textos.bodyLarge?.copyWith(color: tinta)),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    Widget? contenidoTalon;
    if (hayTalon) {
      final propio = talon;
      final porDefecto = propio == null
          ? Semantics(
              label: '$etiquetaNumero $numero',
              child: ExcludeSemantics(
                child: Flex(
                  direction: apaisado ? Axis.vertical : Axis.horizontal,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: apaisado ? CrossAxisAlignment.center : CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(etiquetaNumero.toUpperCase(), style: estiloEtiquetaNumero),
                    SizedBox(width: apaisado ? 0 : Espacio.s, height: apaisado ? Espacio.xs : 0),
                    Text(numero!, style: estiloNumero),
                  ],
                ),
              ),
            )
          : DefaultTextStyle.merge(
              style: TextStyle(color: tintaTalon),
              child: propio,
            );
      // Centrado, pero con el alto de su contenido: el alto del ticket lo marca el cuerpo.
      contenidoTalon = Padding(
        padding: const EdgeInsets.all(Espacio.s),
        child: Center(
          heightFactor: 1,
          child: FittedBox(fit: BoxFit.scaleDown, child: porDefecto),
        ),
      );
    }

    Widget ticket = LayoutBuilder(
      builder: (context, restricciones) {
        // El talón nunca se come el ticket: como mucho, un 40 % del ancho (el número se encoge si no cabe).
        final tamanoTalon = talonMedido == null || !apaisado || !restricciones.hasBoundedWidth
            ? talonMedido
            : math.min(talonMedido, restricciones.maxWidth * 0.4);
        final forma = formaPara(tamanoTalon);
        final contenido = !hayTalon
            ? cuerpo
            : apaisado
            ? Row(
                children: [
                  Expanded(child: cuerpo),
                  SizedBox(width: tamanoTalon, child: contenidoTalon),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  cuerpo,
                  SizedBox(height: tamanoTalon, child: contenidoTalon),
                ],
              );
        final decoracion = ShapeDecoration(color: fondo, shape: forma);
        final onTap = this.onTap;
        if (onTap == null) {
          return SombraTicket(
            forma: forma,
            elevacion: elevado ? 1 : 0,
            child: DecoratedBox(decoration: decoracion, child: contenido),
          );
        }
        return TicketPulsable(
          forma: forma,
          decoracion: decoracion,
          elevacion: elevado ? 1 : 0,
          recortar: false,
          onTap: onTap,
          child: contenido,
        );
      },
    );
    if (inclinacion != 0) ticket = Transform.rotate(angle: inclinacion, child: ticket);

    final etiquetaSemantica = semanticLabel;
    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        label: etiquetaSemantica,
        excludeSemantics: etiquetaSemantica != null,
        child: ticket,
      ),
    );
  }

  /// Tamaño del talón para que el número quepa con el tamaño de letra actual.
  double _medirTalon(bool apaisado, TextScaler escala, TextStyle? numero, TextStyle? etiqueta, String? texto) {
    if (texto == null) return escala.scale(apaisado ? 96 : 64);
    Size medir(String cadena, TextStyle? estilo) {
      final pintor = TextPainter(
        text: TextSpan(text: cadena, style: estilo),
        textDirection: TextDirection.ltr,
        textScaler: escala,
        maxLines: 1,
      )..layout();
      final tamano = pintor.size;
      pintor.dispose();
      return tamano;
    }

    final cifra = medir(texto, numero);
    final arriba = medir(etiquetaNumero.toUpperCase(), etiqueta);
    if (apaisado) return math.max(76, math.max(cifra.width, arriba.width) + Espacio.l + Espacio.s);
    return math.max(56, cifra.height + Espacio.l);
  }
}

/// Superficie pulsable con forma libre (un ticket, por ejemplo): la decoración y la onda respetan [forma], se hunde un
/// poco mientras se pulsa y vibra suave al soltar. Con [recortar], lo que se pinta dentro se recorta a la forma.
///
/// El hundido sigue el resaltado del InkWell: si el dedo acaba desplazando la lista, deja de estar hundida. La sombra
/// es la de papel de los tickets ([SombraTicket]), barata de pintar aunque la forma tenga muescas.
///
/// Es la pieza de todos los tickets que se pulsan: [TicketTuTurno], los módulos y el ticket del día del inicio, las
/// preguntas de ejemplo de Pregunta y las cartas del Glosario.
class TicketPulsable extends StatefulWidget {
  const TicketPulsable({
    super.key,
    required this.forma,
    required this.decoracion,
    required this.onTap,
    required this.child,
    this.elevacion = 1,
    this.vibrar = true,
    this.recortar = true,
  });

  final ShapeBorder forma;
  final Decoration decoracion;
  final VoidCallback onTap;
  final Widget child;

  /// Altura de la sombra de papel (0: sin sombra).
  final double elevacion;

  /// Un toque suave al soltar ([Hapticos.toque]). Sin él, quien lo usa decide si vibra (Pregunta, como mucho, con
  /// [Hapticos.seleccion]).
  final bool vibrar;

  /// Recorta el contenido a la [forma] (por ejemplo, un papel recortado de fondo que se saldría por las muescas).
  final bool recortar;

  @override
  State<TicketPulsable> createState() => _TicketPulsableState();
}

class _TicketPulsableState extends State<TicketPulsable> {
  static const _escalaPulsada = 0.97;
  bool _pulsado = false;

  void _alResaltar(bool pulsado) {
    if (mounted && pulsado != _pulsado) setState(() => _pulsado = pulsado);
  }

  @override
  Widget build(BuildContext context) {
    final forma = widget.forma;
    return AnimatedScale(
      scale: _pulsado ? _escalaPulsada : 1,
      duration: duracion(context, Duracion.corta),
      curve: Curves.easeOutCubic,
      // La sombra va fuera del Material: dentro, la tinta la recortaría.
      child: SombraTicket(
        forma: forma,
        elevacion: widget.elevacion,
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            decoration: widget.decoracion,
            child: InkWell(
              customBorder: forma,
              onTap: () {
                if (widget.vibrar) Hapticos.toque();
                widget.onTap();
              },
              onHighlightChanged: _alResaltar,
              child: widget.recortar
                  ? ClipPath(
                      clipper: ShapeBorderClipper(shape: forma),
                      child: widget.child,
                    )
                  : widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Sombra de papel de un ticket (o de cualquier silueta con entrantes, como un bocadillo) debajo de [child]: la de
/// [sombrasTicket], pintada con [pintarSombrasTicket]. Se ve igual que [sombrasPapel], pero en el móvil no obliga a
/// desenfocar una textura en cada fotograma.
class SombraTicket extends StatelessWidget {
  const SombraTicket({
    super.key,
    required this.forma,
    required this.child,
    this.elevacion = 1,
    this.radio,
    this.margen = EdgeInsets.zero,
  });

  /// Silueta del papel: solo se usa su contorno (lo que pinte la forma, como el talón o los puntos, no).
  final ShapeBorder forma;
  final Widget child;

  /// Altura de la sombra (1 = apoyado; 0 = sin sombra).
  final double elevacion;

  /// Radio del rectángulo de la sombra amplia. Por defecto, el de [forma] ([radioDeForma]).
  final double? radio;

  /// Lo que se encoge el rectángulo de la sombra amplia (por ejemplo, el hueco de la cola de un bocadillo).
  final EdgeInsets margen;

  @override
  Widget build(BuildContext context) {
    if (elevacion <= 0) return child;
    return CustomPaint(
      painter: _PintorSombraTicket(
        silueta: forma,
        sombras: sombrasTicket(context, elevacion: elevacion),
        radio: radio ?? radioDeForma(forma),
        margen: margen,
        direccion: Directionality.maybeOf(context),
      ),
      child: child,
    );
  }
}

class _PintorSombraTicket extends CustomPainter {
  const _PintorSombraTicket({
    required this.silueta,
    required this.sombras,
    required this.radio,
    required this.margen,
    required this.direccion,
  });

  final ShapeBorder silueta;
  final List<BoxShadow> sombras;
  final double radio;
  final EdgeInsets margen;
  final TextDirection? direccion;

  @override
  void paint(Canvas canvas, Size size) => pintarSombrasTicket(
    canvas,
    Offset.zero & size,
    silueta: silueta,
    sombras: sombras,
    radio: radio,
    margen: margen,
    textDirection: direccion,
  );

  /// La sombra no se lleva toques: los recibe lo que haya dentro (o detrás).
  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_PintorSombraTicket anterior) =>
      anterior.silueta != silueta ||
      !listEquals(anterior.sombras, sombras) ||
      anterior.radio != radio ||
      anterior.margen != margen ||
      anterior.direccion != direccion;
}

/// Radio de las esquinas de [forma]: el de un [TicketBorder] o un [RoundedRectangleBorder] (su esquina de arriba a la
/// izquierda); 0 si no se sabe.
double radioDeForma(ShapeBorder forma) => switch (forma) {
  TicketBorder(:final radio) => radio,
  RoundedRectangleBorder(:final borderRadius) => borderRadius.resolve(TextDirection.ltr).topLeft.x,
  _ => 0,
};

/// Pinta [sombras] debajo de un papel con la silueta [silueta] que ocupa [rect], como las pide [sombrasTicket]: las
/// que no tienen desenfoque siguen la silueta exacta (muescas, cola…) y las desenfocadas, el rectángulo redondeado del
/// papel ([radio]; [margen] lo encoge). Impeller desenfoca un rectángulo redondeado sin texturas: así la sombra es
/// barata aunque la silueta tenga entrantes.
void pintarSombrasTicket(
  Canvas canvas,
  Rect rect, {
  required ShapeBorder silueta,
  required List<BoxShadow> sombras,
  double radio = 0,
  EdgeInsets margen = EdgeInsets.zero,
  TextDirection? textDirection,
}) {
  for (final sombra in sombras) {
    if (sombra.blurRadius <= 0) {
      final contorno = rect.shift(sombra.offset).inflate(sombra.spreadRadius);
      canvas.drawPath(silueta.getOuterPath(contorno, textDirection: textDirection), Paint()..color = sombra.color);
    } else {
      final papel = margen.deflateRect(rect).shift(sombra.offset).inflate(sombra.spreadRadius);
      canvas.drawRRect(RRect.fromRectAndRadius(papel, Radius.circular(radio)), sombra.toPaint());
    }
  }
}
