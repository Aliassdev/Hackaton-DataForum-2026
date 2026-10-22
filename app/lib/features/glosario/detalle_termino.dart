import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/content_models.dart';
import '../../core/texto.dart';
import '../../tema.dart';
import '../../widgets/iconos/iconos.dart';
import '../../widgets/modulos.dart';
import '../../widgets/movimiento/carta_holo.dart';
import '../../widgets/movimiento/pop_pegatina.dart';

/// Texto de la fuente de un término: «Fuente: A-060», o «Dato de ejemplo» si viene del mock.
/// Sin fuente, nada.
String? textoFuente(EntradaGlosario entrada) {
  final fuente = entrada.fuente.trim();
  if (fuente.isEmpty) return null;
  return fuente == 'MOCK' ? 'Dato de ejemplo' : 'Fuente: $fuente';
}

/// Icono de TuTurno para una palabra del glosario, según de qué trata. Si no encaja con ninguno, el libro.
TuIcono iconoDeTermino(String termino) {
  final t = normalizar(termino);
  for (final (claves, icono) in _iconosPorTema) {
    if (claves.any(t.contains)) return icono;
  }
  return TuIcono.glosario;
}

const _iconosPorTema = <(List<String>, TuIcono)>[
  (['sala gesell', 'preconstituida', 'grabacion'], TuIcono.grabacion),
  (['abogad', 'defensor', 'coordinador', 'psicosocial', 'confianza'], TuIcono.personaConfianza),
  (['propia imagen', 'intimidad'], TuIcono.candado),
  (['canal prioritario', 'internet', 'redes'], TuIcono.web),
  (['victima', 'alejamiento', 'cautelar', 'desamparo', 'proteccion'], TuIcono.escudo),
  (['citacion', 'denuncia', 'sentencia'], TuIcono.fuente),
  (['testigo', 'declar'], TuIcono.microfono),
  (['fiscal', 'juez', 'juzgado', 'tribunal', 'penal', 'investigad'], TuIcono.juzgado),
];

/// Hoja con la carta del término (nombre, definición y su número en la colección), el ejemplo destacado y la fuente.
/// Con [vieneDePregunta], «Pregúntala» vuelve a la conversación en vez de abrir otra vacía.
Future<void> mostrarDetalleTermino(
  BuildContext context,
  EntradaGlosario entrada, {
  bool vieneDePregunta = false,
  int? numero,
  int? total,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        DetalleTermino(entrada: entrada, vieneDePregunta: vieneDePregunta, numero: numero, total: total),
  );
}

/// «Pregúntalo»: si se llegó desde Pregunta, vuelve a esa conversación (con su papel y sus mensajes); si no,
/// abre Pregunta con [pregunta] ya escrita en el campo, para que la revise y la envíe.
void irAPregunta(GoRouter router, {required bool vieneDePregunta, String? pregunta}) {
  if (vieneDePregunta && router.canPop()) {
    router.pop();
  } else {
    router.push(Uri(path: '/pregunta', queryParameters: pregunta == null ? null : {'q': pregunta}).toString());
  }
}

class DetalleTermino extends StatelessWidget {
  const DetalleTermino({super.key, required this.entrada, this.vieneDePregunta = false, this.numero, this.total});

  final EntradaGlosario entrada;
  final bool vieneDePregunta;

  /// Número de la carta en la colección y cuántas hay («Nº 07/20»). Si no se sabe, no se enseña.
  final int? numero;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final fuente = textoFuente(entrada);
    final esEjemplo = entrada.fuente.trim() == 'MOCK';
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Espacio.l, 0, Espacio.l, Espacio.l),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: anchoMaximo),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // La carta sale como una pegatina y, al arrastrarla con el dedo, se inclina y brilla.
                PopPegatina(
                  inclinacion: -0.012,
                  giroInicial: 0.18,
                  child: CartaHolo(
                    inclinacionMaxima: 0.28,
                    child: CartaTermino(entrada: entrada, numero: numero, total: total),
                  ),
                ),
                if (entrada.ejemplo.trim().isNotEmpty) ...[
                  const SizedBox(height: Espacio.l),
                  _Ejemplo(texto: entrada.ejemplo),
                ],
                if (fuente != null) ...[
                  const SizedBox(height: Espacio.m),
                  Row(
                    children: [
                      IconoTuTurno(
                        esEjemplo ? TuIcono.info : TuIcono.fuente,
                        size: Espacio.l - Espacio.xs,
                        decorativo: true,
                      ),
                      const SizedBox(width: Espacio.s),
                      Expanded(
                        child: Text(
                          fuente,
                          style: tema.textTheme.labelLarge?.copyWith(color: esquema.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: Espacio.l),
                OutlinedButton.icon(
                  onPressed: () {
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    irAPregunta(router, vieneDePregunta: vieneDePregunta);
                  },
                  icon: const IconoTuTurno(TuIcono.pregunta, estilo: EstiloIcono.mono, decorativo: true),
                  label: const Text('¿Te queda alguna duda? Pregúntala'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La cara de la carta de un término: «Glosario» y su número, el nombre en letras recortadas, la pegatina de su tema y
/// la definición. Azul noche en claro y azul TuTurno en oscuro, con borde blanco como las cartas de verdad.
class CartaTermino extends StatelessWidget {
  const CartaTermino({super.key, required this.entrada, this.numero, this.total});

  final EntradaGlosario entrada;
  final int? numero;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final claro = tema.brightness == Brightness.light;
    final fondo = claro ? ColoresMarca.azulNoche : ColoresMarca.azul;
    final numero = this.numero;
    final total = this.total;
    final cifras = total == null ? 2 : (total < 100 ? 2 : '$total'.length);
    final inicial = entrada.termino.trim().isEmpty ? '' : entrada.termino.trim().characters.first.toUpperCase();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(Radios.l),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Stack(
        children: [
          // La inicial, enorme y apenas visible: el dibujo de fondo de la carta.
          PositionedDirectional(
            end: -Espacio.s,
            bottom: -Espacio.xxl,
            child: ExcludeSemantics(
              child: Text(
                inicial,
                style: tema.textTheme.displayLarge?.copyWith(
                  fontSize: 180,
                  color: Colors.white.withValues(alpha: 0.07),
                  height: 1,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Espacio.l - Espacio.xs,
              Espacio.m + Espacio.xs,
              Espacio.l - Espacio.xs,
              Espacio.l,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Con la letra muy grande, el número pasa debajo en vez de salirse de la carta.
                ExcludeSemantics(
                  child: SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: Espacio.s,
                      runSpacing: Espacio.xs,
                      children: [
                        Text(
                          'GLOSARIO',
                          style: tema.textTheme.labelLarge?.copyWith(
                            color: ColoresMarca.amarillo,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                          ),
                        ),
                        if (numero != null)
                          Text(
                            'Nº ${'$numero'.padLeft(cifras, '0')}${total == null ? '' : '/${'$total'.padLeft(cifras, '0')}'}',
                            // En la letra de las cifras (con lectura fácil, Atkinson): se leen bien el 0 y la º.
                            style: estiloCifras(tema.textTheme.titleLarge)
                                ?.copyWith(color: ColoresMarca.amarillo, letterSpacing: 0.6),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Espacio.m),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          entrada.termino,
                          style: tema.textTheme.headlineMedium?.copyWith(color: ColoresMarca.amarillo, height: 1.1),
                        ),
                      ),
                    ),
                    const SizedBox(width: Espacio.s + Espacio.xs),
                    Transform.rotate(
                      angle: 0.08,
                      child: IconoTuTurno(iconoDeTermino(entrada.termino), size: 64, pegatina: true, decorativo: true),
                    ),
                  ],
                ),
                const SizedBox(height: Espacio.m),
                Text(entrada.definicion, style: tema.textTheme.titleMedium?.copyWith(color: Colors.white, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Ejemplo extends StatelessWidget {
  const _Ejemplo({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    // Una nota amarilla en claro; en oscuro, papel azul con la etiqueta amarilla (el amarillo apagado se ve verdoso).
    final claro = tema.brightness == Brightness.light;
    final acento = claro ? esquema.onTertiaryContainer : esquema.tertiary;
    final tinta = claro ? esquema.onTertiaryContainer : esquema.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: claro ? esquema.tertiaryContainer : esquema.surfaceContainerHigh,
        border: Border.all(color: claro ? bordeTinte(esquema.tertiary) : esquema.outlineVariant),
        borderRadius: BorderRadius.circular(Radios.m),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Espacio.m),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IconoTuTurno(TuIcono.idea, size: Espacio.l + Espacio.xs, decorativo: true),
            const SizedBox(width: Espacio.s + Espacio.xs),
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ejemplo',
                      style: tema.textTheme.labelLarge?.copyWith(color: acento, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: Espacio.xs),
                    Text(texto, style: tema.textTheme.bodyLarge?.copyWith(color: tinta)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
