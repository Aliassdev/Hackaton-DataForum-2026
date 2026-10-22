import 'package:flutter/material.dart';

import '../../tema.dart';
import '../animaciones.dart';
import '../iconos/icono_tuturno.dart';
import '../iconos/tu_icono.dart';
import '../movimiento/hapticos.dart';

/// Lo que tarda la luz del micrófono en encenderse.
const _encendido = Duration(milliseconds: 240);

/// Píldora «Tu turno de palabra» con el micrófono de la sala: el derecho a que te escuchen (LO 1/1996, art. 9.1). Con
/// [activo], su luz se enciende (pasa a amarillo en 240 ms) y late dos veces; apagada, la luz es solo un aro, así que
/// el estado no depende solo del color. Para «Dilo con tus palabras» y las decisiones de Vive el caso.
///
/// **No se usa en Pregunta**: allí no se declara nada, y parecer una declaración podría contaminar un testimonio.
///
/// Al encenderse vibra una vez ([Hapticos.seleccion]), salvo con [vibrar] en false. Con «reducir animaciones», la luz
/// se enciende de golpe y no late. Se lee como «[texto], ahora» (o «en espera» si está apagada).
class AvisoTurnoPalabra extends StatefulWidget {
  const AvisoTurnoPalabra({
    super.key,
    required this.activo,
    this.texto = 'Tu turno de palabra',
    this.compacto = false,
    this.vibrar = true,
  });

  final bool activo;
  final String texto;

  /// Más pequeña, para ir dentro de una tarjeta o junto a otros controles.
  final bool compacto;
  final bool vibrar;

  /// La luz del micrófono (para las pruebas).
  static const claveLuz = ValueKey('AvisoTurnoPalabra.luz');

  @override
  State<AvisoTurnoPalabra> createState() => _AvisoTurnoPalabraState();
}

class _AvisoTurnoPalabraState extends State<AvisoTurnoPalabra> {
  @override
  void initState() {
    super.initState();
    if (widget.activo) _alEncender();
  }

  @override
  void didUpdateWidget(AvisoTurnoPalabra anterior) {
    super.didUpdateWidget(anterior);
    if (widget.activo && !anterior.activo) _alEncender();
  }

  void _alEncender() {
    if (!widget.vibrar) return;
    // Después de este fotograma, nunca en mitad de la construcción.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.activo) Hapticos.seleccion();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = context.colores;
    final papel = colores.ticket;
    final tinta = colores.tintaTicket;
    final compacto = widget.compacto;
    final ladoIcono = compacto ? Espacio.m + 4 : Espacio.l + 4;
    final ladoLuz = compacto ? Espacio.s + 2 : Espacio.m - 2;
    final estilo = (compacto ? tema.textTheme.labelLarge : tema.textTheme.titleMedium)?.copyWith(
      color: tinta,
      fontWeight: FontWeight.w800,
    );

    final luz = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widget.activo ? 1 : 0),
      duration: duracion(context, _encendido),
      curve: Curves.easeOut,
      builder: (context, encendida, _) => Container(
        key: AvisoTurnoPalabra.claveLuz,
        width: ladoLuz,
        height: ladoLuz,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Apagada, del color del papel (un aro); encendida, amarilla con su borde de tinta.
          color: Color.lerp(papel, ColoresMarca.amarillo, encendida),
          border: Border.all(color: tinta, width: 2),
        ),
      ),
    );

    final pildora = DecoratedBox(
      decoration: ShapeDecoration(
        color: papel,
        shape: StadiumBorder(side: BorderSide(color: tinta, width: 2)),
        // Sombra plana de papel, como la de los iconos.
        shadows: [BoxShadow(color: sombraPapelDe(context), offset: const Offset(1.5, 2))],
      ),
      child: Padding(
        padding: compacto
            ? const EdgeInsets.fromLTRB(Espacio.s, Espacio.xs / 2, Espacio.s + 2, Espacio.xs / 2)
            : const EdgeInsets.fromLTRB(Espacio.s + 2, Espacio.xs, Espacio.m - 2, Espacio.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconoTuTurno(TuIcono.turnoPalabra, size: ladoIcono, decorativo: true),
            SizedBox(width: compacto ? Espacio.xs + 2 : Espacio.s),
            Flexible(child: Text(widget.texto, style: estilo)),
            SizedBox(width: compacto ? Espacio.s : Espacio.s + 2),
            // La luz late dentro de su hueco: el anillo crece desde un poco más allá de la luz.
            AnilloPulso(
              activo: widget.activo,
              veces: 2,
              color: tema.colorScheme.primary,
              child: SizedBox.square(
                dimension: ladoLuz + Espacio.s - 2,
                child: Center(child: luz),
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      label: widget.texto,
      value: widget.activo ? 'ahora' : 'en espera',
      child: ExcludeSemantics(child: pildora),
    );
  }
}
