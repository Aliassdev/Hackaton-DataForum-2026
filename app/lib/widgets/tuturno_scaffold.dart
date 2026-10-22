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

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: tituloWidget ?? Text(titulo),
        shape: BordeTroquelado(color: esquema.onSurface.withValues(alpha: 0.18)),
        actions: [
          ...acciones,
          if (mostrarGlosario) const GlosarioButton(),
          if (mostrarAyuda)
            AnilloPulso(activo: resaltarAyuda, color: context.colores.ayuda, child: const AyudaButton()),
          const SizedBox(width: Espacio.s),
        ],
      ),
      body: SafeArea(top: false, child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
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
