import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../../../widgets/movimiento/hapticos.dart';
import '../modelos.dart';
import '../textos.dart';
import 'comunes.dart';

/// Ordena los pasos: se arrastran (desde el asa o manteniendo pulsada la tarjeta) o se mueven con las flechas,
/// que son la alternativa accesible. Empieza siempre desordenado y, hasta que se mueve algo, explica por qué
/// «Comprobar» no se puede pulsar todavía.
class VistaOrdenar extends StatefulWidget {
  const VistaOrdenar({super.key, required this.ejercicio, required this.revisado, required this.onRespuesta});

  final EjercicioOrdenar ejercicio;
  final bool revisado;

  /// Posiciones originales de los pasos en el orden actual. Se avisa al mover algo por primera vez.
  final ValueChanged<List<int>> onRespuesta;

  @override
  State<VistaOrdenar> createState() => _VistaOrdenarState();
}

class _VistaOrdenarState extends State<VistaOrdenar> {
  late final List<int> _orden = barajar(
    widget.ejercicio.pasos.length,
    semillaDe(widget.ejercicio.id),
    evitarIdentidad: true,
  );

  /// Ya se ha movido alguna tarjeta (hasta entonces no hay respuesta que comprobar).
  var _movido = false;

  void _mover(int desde, int hasta) {
    if (widget.revisado || desde == hasta || hasta < 0 || hasta >= _orden.length) return;
    Hapticos.seleccion();
    setState(() {
      _orden.insert(hasta, _orden.removeAt(desde));
      _movido = true;
    });
    widget.onRespuesta(List.unmodifiable(_orden));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final pasos = widget.ejercicio.pasos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.ejercicio.enunciado, style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: Espacio.s),
        Row(
          children: [
            ExcludeSemantics(
              child: Icon(Icons.swipe_vertical_rounded, size: Espacio.m + 2, color: esquema.primary),
            ),
            const SizedBox(width: Espacio.s),
            Expanded(
              child: Text(
                'Arrastra las tarjetas o usa las flechas. El primer paso, arriba.',
                style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: duracionTamano(context, Duracion.corta),
          alignment: Alignment.topCenter,
          child: !_movido && !widget.revisado
              ? Padding(
                  key: const ValueKey('aviso-mueve'),
                  padding: const EdgeInsets.only(top: Espacio.xs),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      textoMueveUnaTarjeta,
                      style: tema.textTheme.bodyMedium?.copyWith(color: esquema.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: Espacio.m),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: _mover,
          proxyDecorator: (hijo, indice, animacion) => AnimatedBuilder(
            animation: animacion,
            builder: (context, hijo) {
              final t = Curves.easeOut.transform(animacion.value);
              return Transform.scale(
                scale: lerpDouble(1, 1.03, t),
                child: Material(
                  elevation: lerpDouble(0, 8, t)!,
                  color: Colors.transparent,
                  shadowColor: esquema.shadow.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(Radios.m),
                  child: hijo,
                ),
              );
            },
            child: hijo,
          ),
          children: [
            for (final (posicion, paso) in _orden.indexed)
              Padding(
                key: ValueKey('paso-$paso'),
                padding: const EdgeInsets.only(bottom: Espacio.s + Espacio.xs),
                child: _TarjetaPaso(
                  texto: pasos[paso],
                  posicion: posicion,
                  total: pasos.length,
                  revisado: widget.revisado,
                  bienColocado: paso == posicion,
                  onSubir: () => _mover(posicion, posicion - 1),
                  onBajar: () => _mover(posicion, posicion + 1),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TarjetaPaso extends StatelessWidget {
  const _TarjetaPaso({
    required this.texto,
    required this.posicion,
    required this.total,
    required this.revisado,
    required this.bienColocado,
    required this.onSubir,
    required this.onBajar,
  });

  final String texto;
  final int posicion;
  final int total;
  final bool revisado;
  final bool bienColocado;
  final VoidCallback onSubir;
  final VoidCallback onBajar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    // Un paso fuera de sitio no va en rojo (es el color de Ayuda): terciario, con flechas que dicen «va en otro sitio».
    final acento = !revisado ? null : (bienColocado ? context.colores.exito : esquema.tertiary);
    final forma = BorderRadius.circular(Radios.m);
    final numero = posicion + 1;
    final estado = !revisado ? '' : (bienColocado ? '. Bien colocado' : '. No va aquí');

    final tarjeta = AnimatedContainer(
      duration: duracion(context, Duracion.corta),
      decoration: BoxDecoration(
        color: acento == null ? esquema.surfaceContainerLow : fondoAcento(context, acento),
        borderRadius: forma,
        border: Border.all(color: acento ?? esquema.outlineVariant, width: acento == null ? 2 : 2.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Espacio.s, Espacio.xs, Espacio.xs, Espacio.xs),
        child: Row(
          children: [
            if (!revisado)
              ReorderableDragStartListener(
                index: posicion,
                child: Tooltip(
                  message: 'Arrastrar',
                  excludeFromSemantics: true,
                  child: SizedBox.square(
                    dimension: Espacio.xxl,
                    child: Icon(Icons.drag_indicator_rounded, color: esquema.onSurfaceVariant),
                  ),
                ),
              ),
            Container(
              width: Espacio.xl,
              height: Espacio.xl,
              alignment: Alignment.center,
              margin: EdgeInsets.only(left: revisado ? Espacio.s : 0),
              decoration: BoxDecoration(shape: BoxShape.circle, color: acento ?? esquema.primary),
              child: revisado
                  ? (bienColocado
                        ? IconoTuTurno(
                            TuIcono.check,
                            estilo: EstiloIcono.mono,
                            size: Espacio.m + Espacio.xs,
                            color: context.colores.sobreExito,
                            decorativo: true,
                          )
                        : Icon(Icons.swap_vert_rounded, size: Espacio.m + Espacio.xs, color: esquema.onTertiary))
                  : Text(
                      '$numero',
                      style: tema.textTheme.titleSmall?.copyWith(color: esquema.onPrimary, fontWeight: FontWeight.w700),
                    ),
            ),
            const SizedBox(width: Espacio.m - 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Espacio.s),
                child: Text(
                  texto,
                  style: tema.textTheme.titleMedium?.copyWith(color: esquema.onSurface, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            if (!revisado)
              // Una flecha encima de otra: así el texto tiene más ancho en un móvil estrecho.
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Subir «$texto»',
                    onPressed: posicion == 0 ? null : onSubir,
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  ),
                  IconButton(
                    tooltip: 'Bajar «$texto»',
                    onPressed: posicion == total - 1 ? null : onBajar,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              )
            else
              const SizedBox(width: Espacio.s),
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      label: 'Paso en la posición $numero de $total: $texto$estado',
      child: revisado ? tarjeta : ReorderableDelayedDragStartListener(index: posicion, child: tarjeta),
    );
  }
}
