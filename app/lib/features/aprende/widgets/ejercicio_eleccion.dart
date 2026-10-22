import 'package:flutter/material.dart';

import '../../../tema.dart';
import '../../../widgets/movimiento/hapticos.dart';
import '../modelos.dart';
import 'comunes.dart';
import 'opcion.dart';

const _letras = 'ABCDEFGH';

/// Elección múltiple: tarjetas de opción (barajadas siempre igual para cada ejercicio).
class VistaEleccion extends StatefulWidget {
  const VistaEleccion({super.key, required this.ejercicio, required this.revisado, required this.onRespuesta});

  final EjercicioEleccion ejercicio;

  /// Después de «Comprobar»: se marcan la correcta y la elegida, y ya no se puede cambiar.
  final bool revisado;
  final ValueChanged<int> onRespuesta;

  @override
  State<VistaEleccion> createState() => _VistaEleccionState();
}

class _VistaEleccionState extends State<VistaEleccion> {
  late final List<int> _orden = barajar(widget.ejercicio.opciones.length, semillaDe(widget.ejercicio.id));
  int? _elegida;

  EstadoOpcion _estado(int i) {
    if (!widget.revisado) return i == _elegida ? EstadoOpcion.elegida : EstadoOpcion.normal;
    if (i == widget.ejercicio.correcta) return EstadoOpcion.correcta;
    return i == _elegida ? EstadoOpcion.incorrecta : EstadoOpcion.apagada;
  }

  String _semantica(int posicion, int i) {
    final base = 'Opción ${_letras[posicion]}: ${widget.ejercicio.opciones[i]}';
    return switch (_estado(i)) {
      EstadoOpcion.elegida => '$base. Elegida',
      EstadoOpcion.correcta => '$base. Respuesta correcta',
      EstadoOpcion.incorrecta => '$base. Tu respuesta, no es la correcta',
      _ => base,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ejercicio = widget.ejercicio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(ejercicio.pregunta, style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: Espacio.l),
        for (final (posicion, i) in _orden.indexed) ...[
          Aparece(
            orden: posicion + 1,
            desplazamiento: Espacio.m,
            child: TarjetaOpcion(
              key: ValueKey('opcion-$i'),
              texto: ejercicio.opciones[i],
              chapa: _letras[posicion % _letras.length],
              estado: _estado(i),
              semantica: _semantica(posicion, i),
              onTap: widget.revisado
                  ? null
                  : () {
                      setState(() => _elegida = i);
                      widget.onRespuesta(i);
                    },
            ),
          ),
          const SizedBox(height: Espacio.s + Espacio.xs),
        ],
      ],
    );
  }
}

/// Verdadero o falso: la afirmación en una tarjeta y dos botones grandes.
class VistaVf extends StatefulWidget {
  const VistaVf({super.key, required this.ejercicio, required this.revisado, required this.onRespuesta});

  final EjercicioVf ejercicio;
  final bool revisado;
  final ValueChanged<bool> onRespuesta;

  @override
  State<VistaVf> createState() => _VistaVfState();
}

class _VistaVfState extends State<VistaVf> {
  bool? _elegida;

  EstadoOpcion _estado(bool valor) {
    if (!widget.revisado) return valor == _elegida ? EstadoOpcion.elegida : EstadoOpcion.normal;
    if (valor == widget.ejercicio.correcta) return EstadoOpcion.correcta;
    return valor == _elegida ? EstadoOpcion.incorrecta : EstadoOpcion.apagada;
  }

  void _elegir(bool valor) {
    setState(() => _elegida = valor);
    widget.onRespuesta(valor);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(Espacio.l),
          decoration: BoxDecoration(
            color: tinte(context, colorAprende(context)),
            border: Border.all(color: bordeTinte(colorAprende(context))),
            borderRadius: BorderRadius.circular(Radios.l),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(Icons.format_quote_rounded, size: Espacio.xl, color: esquema.primary),
              ),
              const SizedBox(height: Espacio.xs),
              Text(
                widget.ejercicio.afirmacion,
                style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: esquema.onSurface),
              ),
            ],
          ),
        ),
        const SizedBox(height: Espacio.l),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Aparece(
                orden: 1,
                desplazamiento: Espacio.m,
                child: _BotonVf(
                  key: const ValueKey('vf-verdadero'),
                  texto: 'Verdadero',
                  icono: Icons.thumb_up_alt_rounded,
                  estado: _estado(true),
                  onTap: widget.revisado ? null : () => _elegir(true),
                ),
              ),
            ),
            const SizedBox(width: Espacio.m),
            Expanded(
              child: Aparece(
                orden: 2,
                desplazamiento: Espacio.m,
                child: _BotonVf(
                  key: const ValueKey('vf-falso'),
                  texto: 'Falso',
                  icono: Icons.thumb_down_alt_rounded,
                  estado: _estado(false),
                  onTap: widget.revisado ? null : () => _elegir(false),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BotonVf extends StatelessWidget {
  const _BotonVf({super.key, required this.texto, required this.icono, required this.estado, this.onTap});

  final String texto;
  final IconData icono;
  final EstadoOpcion estado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    // Fallar no va en rojo (es el color de Ayuda): terciario y una bombilla, como en Vive el caso.
    final Color? acento = switch (estado) {
      EstadoOpcion.elegida => esquema.primary,
      EstadoOpcion.correcta => context.colores.exito,
      EstadoOpcion.incorrecta => esquema.tertiary,
      _ => null,
    };
    final iconoFinal = switch (estado) {
      EstadoOpcion.correcta => Icons.check_circle_rounded,
      EstadoOpcion.incorrecta => Icons.lightbulb_rounded,
      _ => icono,
    };
    final forma = BorderRadius.circular(Radios.l);
    final semantica = switch (estado) {
      EstadoOpcion.elegida => '$texto. Elegido',
      EstadoOpcion.correcta => '$texto. Respuesta correcta',
      EstadoOpcion.incorrecta => '$texto. Tu respuesta, no es la correcta',
      _ => texto,
    };
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      selected: estado == EstadoOpcion.elegida,
      label: semantica,
      excludeSemantics: true,
      onTap: onTap,
      child: AnimatedScale(
        scale: estado == EstadoOpcion.elegida || estado == EstadoOpcion.correcta ? 1.0 : 0.97,
        duration: duracion(context, Duracion.media),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: duracion(context, Duracion.corta),
          decoration: BoxDecoration(
            color: acento == null ? esquema.surfaceContainerLow : fondoAcento(context, acento),
            borderRadius: forma,
            border: Border.all(color: acento ?? esquema.outlineVariant, width: acento == null ? 2 : 3),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: forma,
              onTap: onTap == null
                  ? null
                  : () {
                      Hapticos.seleccion();
                      onTap!();
                    },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 104),
                child: Padding(
                  padding: const EdgeInsets.all(Espacio.m),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: duracion(context, Duracion.corta),
                        transitionBuilder: (hijo, animacion) => ScaleTransition(scale: animacion, child: hijo),
                        child: Icon(
                          iconoFinal,
                          key: ValueKey(iconoFinal),
                          size: Espacio.xl + Espacio.xs,
                          color: acento ?? esquema.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Espacio.s),
                      Text(
                        texto,
                        textAlign: TextAlign.center,
                        style: tema.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: esquema.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
