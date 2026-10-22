import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../tema.dart';
import 'iconos/iconos.dart';

/// Botón de Ayuda: siempre arriba a la derecha (sección 4.1).
///
/// Es lo único rojo de la barra, para que sea inconfundible: el salvavidas y la palabra «Ayuda» en blanco sobre el
/// rojo de Ayuda (contraste AA en los dos temas), con un borde blanco de pegatina que lo despega de cualquier fondo.
/// Nunca se gamifica: no salta, no gira y no cambia de sitio.
class AyudaButton extends StatelessWidget {
  const AyudaButton({super.key});

  @override
  Widget build(BuildContext context) {
    final rojo = context.colores.ayuda;
    return Tooltip(
      message: 'Teléfonos de ayuda',
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: rojo,
          foregroundColor: Colors.white,
          overlayColor: Colors.white,
          // Visible de 40 de alto; la zona táctil llega a 48 (MaterialTapTargetSize.padded del tema).
          minimumSize: const Size(48, 40),
          padding: const EdgeInsetsDirectional.fromSTEB(Espacio.s + 2, 0, Espacio.m, 0),
          shape: const StadiumBorder(side: BorderSide(color: Colors.white, width: 2)),
          iconSize: 22,
          elevation: 1.5,
          shadowColor: sombraPapelDe(context),
          textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        onPressed: () => context.push('/ayuda'),
        icon: const IconoTuTurno(TuIcono.ayuda, estilo: EstiloIcono.mono, decorativo: true),
        label: const Text('Ayuda'),
      ),
    );
  }
}

/// Acceso al Glosario: siempre arriba a la derecha (sección 4.1). El libro de la iconografía de TuTurno, a dos
/// tintas.
class GlosarioButton extends StatelessWidget {
  const GlosarioButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Glosario',
      icon: const IconoTuTurno(TuIcono.glosario, size: 28, decorativo: true),
      onPressed: () => context.push('/glosario'),
    );
  }
}
