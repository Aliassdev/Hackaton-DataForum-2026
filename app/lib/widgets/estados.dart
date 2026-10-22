import 'package:flutter/material.dart';

import '../tema.dart';
import 'iconos/iconos.dart';

/// Estado vacío o informativo: icono, título, mensaje y una acción opcional.
///
/// El icono va en un disco de papel, como una pegatina. Con [tuIcono], es de la iconografía de TuTurno (a dos tintas);
/// con [ilustracion], cualquier dibujo (por ejemplo, Tut) sustituye al disco.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    this.mensaje,
    this.accion,
    this.tuIcono,
    this.ilustracion,
  });

  final IconData icono;
  final String titulo;
  final String? mensaje;
  final Widget? accion;
  final TuIcono? tuIcono;
  final Widget? ilustracion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final tuIcono = this.tuIcono;
    // Papel de ticket del tema (o blanco, si el tema no trae los colores de TuTurno).
    final papel = tema.extension<ColoresTuTurno>()?.ticket ?? esquema.surfaceContainerLowest;
    final dibujo =
        ilustracion ??
        Transform.rotate(
          angle: -0.05,
          child: Container(
            width: Espacio.xxl * 2,
            height: Espacio.xxl * 2,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: papel,
              shape: BoxShape.circle,
              border: Border.all(color: bordeTinte(esquema.primary), width: 1.5),
              boxShadow: sombrasPapel(context),
            ),
            child: tuIcono == null
                ? Icon(icono, size: Espacio.xxl, color: esquema.primary)
                : IconoTuTurno(tuIcono, size: Espacio.xxl + Espacio.s, decorativo: true),
          ),
        );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Espacio.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1),
                duration: duracion(context, Duracion.larga),
                curve: Curves.easeOutBack,
                builder: (context, escala, child) => Transform.scale(scale: escala, child: child),
                child: dibujo,
              ),
            ),
            const SizedBox(height: Espacio.l),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (mensaje != null) ...[
              const SizedBox(height: Espacio.s),
              Text(
                mensaje!,
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurfaceVariant),
              ),
            ],
            if (accion != null) ...[const SizedBox(height: Espacio.l), accion!],
          ],
        ),
      ),
    );
  }
}

/// Error con opción de reintentar. [mensaje] debe poder leerlo cualquiera (nada técnico). Lo acompaña Tut pensando:
/// sin dramas, se vuelve a intentar.
class EstadoError extends StatelessWidget {
  const EstadoError({super.key, required this.mensaje, this.onReintentar});

  final String mensaje;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    return EstadoVacio(
      icono: Icons.cloud_off_rounded,
      ilustracion: const MascotaTut(expresion: ExpresionTut.pensando, size: 120, animada: false, decorativo: true),
      titulo: 'Algo no ha ido bien',
      mensaje: mensaje,
      accion: onReintentar == null
          ? null
          : FilledButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
    );
  }
}

class Cargando extends StatelessWidget {
  const Cargando({super.key, this.mensaje});

  final String? mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: mensaje ?? 'Cargando',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (mensaje != null) ...[
              const SizedBox(height: Espacio.m),
              Text(mensaje!, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ],
        ),
      ),
    );
  }
}
