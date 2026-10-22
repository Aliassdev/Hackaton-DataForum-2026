import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../personalizacion.dart';
import 'comunes.dart';

/// Las notas «Para ti» de la cabecera: lo que cambia por tu edad o por tu tipo de proceso, con su fuente.
class NotasParaTi extends StatelessWidget {
  const NotasParaTi({super.key, required this.notas});

  final List<NotaPreparada> notas;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final tinta = esquema.onTertiaryContainer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final nota in notas)
          Padding(
            padding: const EdgeInsets.only(bottom: Espacio.s + Espacio.xs),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: esquema.tertiaryContainer,
                borderRadius: BorderRadius.circular(Radios.m),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Espacio.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Row(
                        children: [
                          const IconoTuTurno(TuIcono.estrella, size: Espacio.l, decorativo: true),
                          const SizedBox(width: Espacio.s),
                          Expanded(
                            child: Text(
                              nota.titulo,
                              style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: tinta),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Espacio.s),
                    PuntoConFuentes(punto: nota.nota, contexto: nota.titulo, color: tinta),
                    if (nota.enlace case final String enlace)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton(
                          onPressed: () => GoRouter.maybeOf(context)?.push(enlace),
                          child: const Text('Ver ese camino'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
