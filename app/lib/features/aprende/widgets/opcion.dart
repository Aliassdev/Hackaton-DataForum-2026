import 'package:flutter/material.dart';

import '../../../tema.dart';
import '../../../widgets/movimiento/hapticos.dart';
import 'comunes.dart';

/// Cómo se ve una opción: sin tocar, elegida, y después de comprobar (correcta, incorrecta o apagada).
enum EstadoOpcion { normal, elegida, correcta, incorrecta, apagada }

/// Tarjeta de opción grande (48 px como mínimo) con una chapa a la izquierda (letra, número o icono).
/// Cambia de color con suavidad y da un pequeño salto al elegirla.
class TarjetaOpcion extends StatelessWidget {
  const TarjetaOpcion({
    super.key,
    required this.texto,
    required this.estado,
    required this.semantica,
    this.chapa,
    this.onTap,
    this.colorElegida,
    this.estiloTexto,
  });

  final String texto;
  final EstadoOpcion estado;

  /// Lo que lee el lector de pantalla (incluye el estado).
  final String semantica;

  /// Letra o número de la chapa. Después de comprobar se cambia por un icono.
  final String? chapa;
  final VoidCallback? onTap;

  /// Color de «elegida» (por defecto, el primario). Emparejar usa uno por pareja.
  final Color? colorElegida;
  final TextStyle? estiloTexto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final exito = context.colores.exito;
    final elegida = colorElegida ?? esquema.primary;
    // Una respuesta fallada no va en rojo (el rojo es de Ayuda): fallar es parte de aprender, así que lleva el color
    // terciario y una bombilla, como en Vive el caso.
    final (Color? acento, IconData? icono) = switch (estado) {
      EstadoOpcion.normal || EstadoOpcion.apagada => (null, null),
      EstadoOpcion.elegida => (elegida, null),
      EstadoOpcion.correcta => (exito, Icons.check_rounded),
      EstadoOpcion.incorrecta => (esquema.tertiary, Icons.lightbulb_rounded),
    };
    // Tinta encima del acento: la del tema para acierto y fallo; para «elegida», la que contraste con su color.
    final Color? sobreAcento = switch (estado) {
      EstadoOpcion.correcta => context.colores.sobreExito,
      EstadoOpcion.incorrecta => esquema.onTertiary,
      EstadoOpcion.elegida => colorElegida == null ? esquema.onPrimary : sobreColor(elegida),
      _ => null,
    };
    final fondo = acento == null ? esquema.surfaceContainerLow : fondoAcento(context, acento);
    final borde = acento ?? esquema.outlineVariant.withValues(alpha: estado == EstadoOpcion.apagada ? 0.5 : 1);
    final colorTexto = estado == EstadoOpcion.apagada ? esquema.onSurfaceVariant : esquema.onSurface;
    final forma = BorderRadius.circular(Radios.m);
    final rapida = duracion(context, Duracion.corta);
    final chapa = this.chapa;

    return Semantics(
      button: onTap != null,
      selected: estado == EstadoOpcion.elegida,
      enabled: onTap != null,
      label: semantica,
      excludeSemantics: true,
      onTap: onTap,
      child: AnimatedScale(
        scale: estado == EstadoOpcion.elegida || estado == EstadoOpcion.correcta ? 1.0 : 0.985,
        duration: duracion(context, Duracion.media),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: rapida,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: forma,
            border: Border.all(color: borde, width: acento == null ? 2 : 2.5),
            boxShadow: estado == EstadoOpcion.elegida && tema.brightness == Brightness.light
                ? [BoxShadow(color: elegida.withValues(alpha: 0.18), blurRadius: Espacio.m, offset: const Offset(0, 4))]
                : const [],
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
                constraints: const BoxConstraints(minHeight: Espacio.xxl + Espacio.s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Espacio.m - 2, vertical: Espacio.s + Espacio.xs),
                  child: Row(
                    children: [
                      if (chapa != null || icono != null) ...[
                        AnimatedContainer(
                          duration: rapida,
                          width: Espacio.xl + Espacio.xs,
                          height: Espacio.xl + Espacio.xs,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: acento ?? esquema.surfaceContainerHighest,
                          ),
                          child: AnimatedSwitcher(
                            duration: rapida,
                            transitionBuilder: (hijo, animacion) => ScaleTransition(scale: animacion, child: hijo),
                            child: icono != null
                                ? Icon(icono, key: ValueKey(icono), size: Espacio.l - 2, color: sobreAcento)
                                : Text(
                                    chapa!,
                                    key: ValueKey('chapa-$chapa'),
                                    style: tema.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: sobreAcento ?? esquema.onSurfaceVariant,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: Espacio.m - 4),
                      ],
                      Expanded(
                        child: Text(
                          texto,
                          style: (estiloTexto ?? tema.textTheme.titleMedium)?.copyWith(
                            color: colorTexto,
                            fontWeight: estado == EstadoOpcion.elegida ? FontWeight.w700 : FontWeight.w500,
                          ),
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
