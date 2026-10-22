import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tema.dart';
import 'animaciones.dart';
import 'ayuda_button.dart';

/// Scaffold común: Glosario y Ayuda arriba a la derecha en todas las pantallas.
///
/// La barra lleva abajo la línea troquelada de un ticket de turno ([BordeTroquelado]): cada pantalla es un ticket y
/// la barra, su talón. En el inicio, el título es el logotipo ([tituloWidget]).
class TuTurnoScaffold extends StatelessWidget {
  const TuTurnoScaffold({
    super.key,
    required this.titulo,
    required this.body,
    this.tituloWidget,
    this.mostrarAyuda = true,
    this.mostrarGlosario = true,
    this.resaltarAyuda = false,
    this.acciones = const [],
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor,
  });

  final String titulo;
  final Widget body;

  /// Sustituye al texto de [titulo] en la barra (por ejemplo, el logotipo:
  /// `Semantics(header: true, child: LogoTuTurno(alto: 28))`).
  final Widget? tituloWidget;

  /// En la propia pantalla de Ayuda no tiene sentido el botón.
  final bool mostrarAyuda;
  final bool mostrarGlosario;

  /// Un anillo late unas pocas veces alrededor del botón de Ayuda, para que se vea dónde está (bienvenida).
  final bool resaltarAyuda;

  /// Acciones extra, a la izquierda de Glosario y Ayuda.
  final List<Widget> acciones;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;

  /// Lo más que crecen con la letra las acciones de la barra (auditoría P1-1): con letra 1,6, la pastilla «Ayuda»
  /// crecía tanto que se comía el título. Con este límite sigue siendo grande y se lee bien; el título sí crece entero.
  static const escalaMaximaAcciones = 1.2;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    Widget limitada(Widget accion) =>
        MediaQuery.withClampedTextScaling(maxScaleFactor: escalaMaximaAcciones, child: accion);
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: tituloWidget ?? TituloBarra(titulo),
        shape: BordeTroquelado(color: esquema.onSurface.withValues(alpha: 0.18)),
        actions: [
          for (final accion in acciones) limitada(accion),
          if (mostrarGlosario) limitada(const GlosarioButton()),
          if (mostrarAyuda)
            limitada(AnilloPulso(activo: resaltarAyuda, color: context.colores.ayuda, child: const AyudaButton())),
          const SizedBox(width: Espacio.s),
        ],
      ),
      body: SafeArea(top: false, child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// El título de una barra que no se corta (auditoría P1-1 y P1-2): en un móvil estrecho, con Glosario y Ayuda al lado,
/// solo quedan unos 110 puntos. Va con el estilo de la barra (20) si cabe en una línea; si no, más pequeño (hasta 16);
/// si aun así no cabe, en dos líneas, siempre que ninguna palabra se tenga que partir. Si ni así, encogido lo justo, en
/// una línea o en dos (lo que deje la letra más grande). Nunca parte una palabra ni pone «…».
class TituloBarra extends StatelessWidget {
  const TituloBarra(this.texto, {super.key});

  final String texto;

  /// El tamaño más pequeño al que se baja antes de pasar a dos líneas.
  static const tamanoMinimo = 16.0;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style;
    final escalador = MediaQuery.textScalerOf(context);
    final direccion = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, limites) {
        TextPainter medir(String cual, TextStyle estilo, {int? lineas, double ancho = double.infinity}) => TextPainter(
          text: TextSpan(text: cual, style: estilo),
          textDirection: direccion,
          textScaler: escalador,
          maxLines: lineas,
        )..layout(maxWidth: ancho);
        Size medida(String cual, TextStyle estilo, {double ancho = double.infinity}) {
          final pintor = medir(cual, estilo, ancho: ancho);
          final tamano = pintor.size;
          pintor.dispose();
          return tamano;
        }

        bool cabe(TextStyle estilo, int lineas) {
          final pintor = medir(texto, estilo, lineas: lineas, ancho: limites.maxWidth);
          final si = !pintor.didExceedMaxLines && pintor.height <= limites.maxHeight;
          pintor.dispose();
          return si;
        }

        final tamano = base.fontSize ?? 20;
        for (var t = tamano; t >= tamanoMinimo; t -= 2) {
          final estilo = base.copyWith(fontSize: t);
          if (cabe(estilo, 1)) return Text(texto, style: estilo, maxLines: 1, softWrap: false);
        }
        final pequeno = base.copyWith(fontSize: tamanoMinimo, height: 1.1);
        final palabras = texto.split(' ').where((p) => p.isNotEmpty).toList();
        final palabraMasAncha = palabras.fold(0.0, (maximo, p) => math.max(maximo, medida(p, pequeno).width));
        if (palabraMasAncha <= limites.maxWidth && cabe(pequeno, 2)) {
          return Text(texto, style: pequeno, maxLines: 2, softWrap: true);
        }

        // Encogido lo justo. En dos líneas, cortando por la palabra que deja las dos más parecidas.
        final enUna = medida(texto, pequeno);
        var anchoEnDos = enUna.width;
        for (var i = 1; i < palabras.length; i++) {
          final primera = medida(palabras.take(i).join(' '), pequeno).width;
          final segunda = medida(palabras.skip(i).join(' '), pequeno).width;
          anchoEnDos = math.min(anchoEnDos, math.max(primera, segunda));
        }
        anchoEnDos = anchoEnDos.ceilToDouble() + 1;
        final enDos = Size(anchoEnDos, medida(texto, pequeno, ancho: anchoEnDos).height);
        double escala(Size s) => math.min(
          limites.maxWidth / s.width,
          limites.maxHeight.isFinite ? limites.maxHeight / s.height : double.infinity,
        );
        final dosLineas = palabras.length > 1 && escala(enDos) > escala(enUna);
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: dosLineas
              ? SizedBox(
                  width: anchoEnDos,
                  child: Text(texto, style: pequeno, maxLines: 2, softWrap: true),
                )
              : Text(texto, style: pequeno, maxLines: 1, softWrap: false),
        );
      },
    );
  }
}

/// Borde de una barra con la línea troquelada de un ticket abajo: trazos cortos y redondeados, como los agujeros por
/// donde se arranca. Sirve como `shape` de un [AppBar] (o de cualquier [Material] rectangular).
@immutable
class BordeTroquelado extends ShapeBorder {
  const BordeTroquelado({required this.color, this.trazo = 6, this.hueco = 5, this.grosor = 1.5});

  final Color color;
  final double trazo;
  final double hueco;
  final double grosor;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path()..addRect(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRect(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (rect.isEmpty || color.a == 0) return;
    final pincel = Paint()
      ..color = color
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;
    final y = rect.bottom - grosor;
    final paso = trazo + hueco;
    // Centrada: sobra lo mismo a cada lado.
    final cuantos = ((rect.width + hueco) / paso).floor();
    var x = rect.left + (rect.width - (cuantos * paso - hueco)) / 2;
    for (var i = 0; i < cuantos; i++, x += paso) {
      canvas.drawLine(Offset(x, y), Offset(x + trazo, y), pincel);
    }
  }

  @override
  ShapeBorder scale(double t) => BordeTroquelado(color: color, trazo: trazo * t, hueco: hueco * t, grosor: grosor * t);

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) => a is BordeTroquelado
      ? BordeTroquelado(color: Color.lerp(a.color, color, t)!, trazo: trazo, hueco: hueco, grosor: grosor)
      : super.lerpFrom(a, t);

  @override
  bool operator ==(Object other) =>
      other is BordeTroquelado &&
      other.color == color &&
      other.trazo == trazo &&
      other.hueco == hueco &&
      other.grosor == grosor;

  @override
  int get hashCode => Object.hash(color, trazo, hueco, grosor);
}
