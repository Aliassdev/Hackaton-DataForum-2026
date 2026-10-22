import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../tema.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/iconos/iconos.dart';
import '../../widgets/modulos.dart';
import '../../widgets/tuturno_scaffold.dart';

/// Una cosa que tendrá el módulo cuando esté listo.
class Caracteristica {
  const Caracteristica(this.icono, this.titulo, this.texto);

  final IconData icono;
  final String titulo;
  final String texto;
}

/// Pantalla de un módulo que aún se está preparando: cabecera con su degradado, lo que va a tener
/// y un acceso a Pregunta para no dejar a nadie sin respuesta.
class ModuloProximamente extends StatelessWidget {
  const ModuloProximamente({
    super.key,
    required this.modulo,
    required this.texto,
    required this.caracteristicas,
    this.nota,
  });

  final Modulo modulo;
  final String texto;
  final List<Caracteristica> caracteristicas;

  /// Aviso final opcional (p. ej. que el caso es inventado).
  final String? nota;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = modulo.colores(context);
    final nota = this.nota;
    var orden = 0;
    return TuTurnoScaffold(
      titulo: modulo.titulo,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: anchoMaximo),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.m, Espacio.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Entrada(
                  orden: orden++,
                  child: CabeceraModulo(
                    colores: colores,
                    icono: modulo.icono,
                    insignias: modulo.insignias,
                    tuIcono: modulo.tuIcono,
                    tuInsignias: modulo.tuInsignias,
                    etiqueta: 'Muy pronto',
                    iconoEtiqueta: Icons.schedule_rounded,
                    titulo: modulo.titulo,
                    texto: texto,
                  ),
                ),
                const SizedBox(height: Espacio.l),
                Entrada(
                  orden: orden++,
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Lo que vas a encontrar',
                      style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: Espacio.m),
                for (final c in caracteristicas) ...[
                  Entrada(
                    orden: orden++,
                    child: FilaCaracteristica(caracteristica: c, colores: colores),
                  ),
                  const SizedBox(height: Espacio.m),
                ],
                if (nota != null)
                  Entrada(
                    orden: orden++,
                    child: NotaSuave(icono: Icons.info_rounded, texto: nota),
                  ),
                const SizedBox(height: Espacio.l),
                Entrada(orden: orden++, child: const TarjetaIrAPregunta()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FilaCaracteristica extends StatelessWidget {
  const FilaCaracteristica({super.key, required this.caracteristica, required this.colores});

  final Caracteristica caracteristica;
  final List<Color> colores;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconoDegradado(icono: caracteristica.icono, colores: colores),
          const SizedBox(width: Espacio.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(caracteristica.titulo, style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: Espacio.xs),
                Text(
                  caracteristica.texto,
                  style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Recuadro suave con un icono y un texto corto.
class NotaSuave extends StatelessWidget {
  const NotaSuave({super.key, required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tinte(context, esquema.primary),
        border: Border.all(color: bordeTinte(esquema.primary)),
        borderRadius: BorderRadius.circular(Radios.m),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Espacio.m),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icono, color: esquema.primary)),
            const SizedBox(width: Espacio.s + Espacio.xs),
            Expanded(
              child: Text(texto, style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurface)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mientras un módulo se prepara, Pregunta ya responde.
class TarjetaIrAPregunta extends StatelessWidget {
  const TarjetaIrAPregunta({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Espacio.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconoDegradado(
                  icono: Modulo.pregunta.icono,
                  tuIcono: Modulo.pregunta.tuIcono,
                  colores: context.colores.pregunta,
                ),
                const SizedBox(width: Espacio.m),
                Expanded(
                  child: Text(
                    '¿Tienes una duda ya?',
                    style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espacio.s + Espacio.xs),
            Text(
              'Mientras lo preparamos, puedes preguntar a la IA lo que quieras sobre la justicia.',
              style: tema.textTheme.bodyLarge,
            ),
            const SizedBox(height: Espacio.m),
            FilledButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.push(Modulo.pregunta.ruta);
              },
              icon: const IconoTuTurno(TuIcono.pregunta, estilo: EstiloIcono.mono, decorativo: true),
              label: const Text('Ir a Pregunta'),
            ),
          ],
        ),
      ),
    );
  }
}
