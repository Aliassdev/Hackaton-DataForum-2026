import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/content_models.dart';
import '../../../core/progreso.dart';
import '../../../core/providers.dart';
import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../../../widgets/modulos.dart';
import '../turno_del_dia.dart';

/// Una palabra del glosario distinta cada día, en una nota adhesiva amarilla pegada con cinta. Al tocarla, se abre en
/// el glosario. Si el glosario no está listo, no ocupa sitio.
class PalabraDelDia extends ConsumerWidget {
  const PalabraDelDia({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entradas = ref.watch(glosarioProvider).value;
    if (entradas == null || entradas.isEmpty) return const SizedBox.shrink();
    final dia = indiceDia(ref.watch(relojProvider)());
    return NotaPalabra(entrada: entradas[dia % entradas.length]);
  }
}

/// La nota de la palabra del día (amarilla en los dos temas, con tinta azul noche: 12:1).
class NotaPalabra extends StatelessWidget {
  const NotaPalabra({super.key, required this.entrada});

  final EntradaGlosario entrada;

  /// Las notas adhesivas nunca quedan rectas.
  static const _inclinacion = 0.012;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    const tinta = ColoresMarca.azulNoche;
    final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.s - 4));
    final contenido = Padding(
      padding: const EdgeInsets.fromLTRB(Espacio.l - 4, Espacio.l, Espacio.l - 4, Espacio.m + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconoTuTurno(TuIcono.idea, size: 26, decorativo: true),
              const SizedBox(width: Espacio.s),
              Expanded(
                child: Text(
                  'Palabra del día',
                  style: textos.labelLarge?.copyWith(color: tinta, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: Espacio.s),
          Text(
            entrada.termino,
            style: textos.headlineSmall?.copyWith(color: tinta, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Espacio.xs),
          Text(
            entrada.definicion,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textos.bodyLarge?.copyWith(color: tinta),
          ),
          const SizedBox(height: Espacio.s + Espacio.xs),
          Row(
            children: [
              Flexible(
                child: Text(
                  'Ver en el glosario',
                  style: textos.labelLarge?.copyWith(
                    color: tinta,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: tinta,
                  ),
                ),
              ),
              const SizedBox(width: Espacio.xs),
              const ExcludeSemantics(
                child: Icon(Icons.arrow_forward_rounded, size: Espacio.m + Espacio.xs, color: tinta),
              ),
            ],
          ),
        ],
      ),
    );
    return Transform.rotate(
      angle: _inclinacion,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          MergeSemantics(
            child: Semantics(
              button: true,
              child: TicketPulsable(
                forma: forma,
                decoracion: ShapeDecoration(color: ColoresMarca.amarillo, shape: forma),
                vibrar: false,
                onTap: () => context.push(Uri(path: '/glosario', queryParameters: {'q': entrada.termino}).toString()),
                child: contenido,
              ),
            ),
          ),
          // Un trozo de cinta adhesiva arriba, algo torcido.
          const Positioned(
            top: -Espacio.s - 2,
            left: 0,
            right: 0,
            child: Center(child: _Cinta()),
          ),
        ],
      ),
    );
  }
}

class _Cinta extends StatelessWidget {
  const _Cinta();

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: Transform.rotate(
        angle: -0.06,
        child: Container(
          width: 76,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: oscuro ? 0.42 : 0.62),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: ColoresMarca.azulNoche.withValues(alpha: 0.08)),
          ),
        ),
      ),
    );
  }
}
