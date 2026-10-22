import 'package:flutter/material.dart';

import '../../core/entrada.dart';
import '../../tema.dart';

// Piezas comunes de Ajustes: el papel de cada sección, su cabecera y los títulos pequeños de dentro. Las usan la
// pantalla (ajustes_screen.dart) y la parte del equipo (para_el_equipo.dart).

/// El ticket en una línea, como en Pregunta: «13 años · Penal · Víctima · Durante». Lo que no se ha respondido (o
/// «No lo sé») no sale; si no queda nada, vacío.
String resumenTicket(Entrada entrada) => [
  if (entrada.edad != null) '${entrada.edad} años',
  if (entrada.procedimiento case final p? when p != Procedimiento.noLoSe) p.etiqueta,
  if (entrada.rol case final r? when r != RolEntrada.noLoSe) r.etiqueta,
  if (entrada.fase != null) entrada.fase!.etiqueta,
].join(' · ');

/// Papel de los ajustes: blanco sobre el papel cálido en claro y un azul algo más claro en oscuro, con su borde y su
/// sombra. Es un Material: las ondas de los interruptores y botones de dentro se ven.
class PapelAjustes extends StatelessWidget {
  const PapelAjustes({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final esquinas = BorderRadius.circular(Radios.l);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: esquinas, boxShadow: sombrasPapel(context, elevacion: 0.8)),
      child: Material(
        color: context.colores.ticket,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: esquinas,
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: child,
      ),
    );
  }
}

/// Una sección: su pegatina, el título en letras recortadas y el contenido.
class SeccionAjustes extends StatelessWidget {
  const SeccionAjustes({super.key, required this.icono, required this.titulo, required this.child});

  final Widget icono;
  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return PapelAjustes(
      child: Padding(
        padding: const EdgeInsets.all(Espacio.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(child: icono),
                const SizedBox(width: Espacio.s + Espacio.xs),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      titulo,
                      style: tema.textTheme.headlineSmall?.copyWith(color: context.colores.tintaTicket),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espacio.m),
            child,
          ],
        ),
      ),
    );
  }
}

/// Título pequeño dentro de una sección («Tamaño de la letra», «Voz»…): en negrita y, para el lector de pantalla, un
/// encabezado.
class SubtituloAjustes extends StatelessWidget {
  const SubtituloAjustes(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(texto, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

/// Una nota corta con un icono delante, en el color secundario del texto (para explicar un interruptor desactivado o
/// dónde se cambia algo).
class NotaAjustes extends StatelessWidget {
  const NotaAjustes({super.key, required this.icono, required this.texto});

  final Widget icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: ExcludeSemantics(child: icono),
        ),
        const SizedBox(width: Espacio.s),
        Expanded(
          child: Text(texto, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}
