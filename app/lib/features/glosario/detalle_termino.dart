import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/content_models.dart';
import '../../core/providers.dart';
import '../../core/texto.dart';
import '../../core/voz/tts.dart';
import '../../tema.dart';
import '../../widgets/iconos/iconos.dart';
import '../../widgets/modulos.dart';
import '../../widgets/movimiento/carta_holo.dart';
import '../../widgets/movimiento/hapticos.dart';
import '../../widgets/movimiento/pop_pegatina.dart';
import 'favoritos.dart';

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
  // El aviso con el día, la hora y el lugar.
  (['citacion'], TuIcono.citacion),
  // Cuando te toca hablar y que te escuchen.
  (['ser oido', 'audiencia'], TuIcono.turnoPalabra),
  (['denuncia', 'sentencia'], TuIcono.fuente),
  (['testigo', 'declar'], TuIcono.microfono),
  (['fiscal', 'juez', 'juzgado', 'tribunal', 'penal', 'investigad'], TuIcono.juzgado),
];

/// Lo que lee «Escuchar»: el término, la definición y, si lo hay, el ejemplo («Ejemplo: …»). Sin referencias a
/// fuentes, que no se leen en voz alta.
String textoParaEscuchar(EntradaGlosario entrada) {
  String frase(String texto) {
    final limpio = textoParaVoz(texto);
    return limpio.isEmpty || RegExp(r'[.!?…]$').hasMatch(limpio) ? limpio : '$limpio.';
  }

  final ejemplo = frase(entrada.ejemplo);
  return [
    frase(entrada.termino),
    frase(entrada.definicion),
    if (ejemplo.isNotEmpty) 'Ejemplo: $ejemplo',
  ].where((parte) => parte.isNotEmpty).join(' ');
}

/// Lo que confirma el botón de «Mis palabras» al tocarlo (en la hoja, debajo de los botones: un SnackBar quedaría
/// tapado por la propia hoja).
const avisoGuardada = 'Guardada en Mis palabras.';
const avisoQuitada = 'Quitada de Mis palabras.';

/// Hoja con la carta del término (nombre, definición y su número en la colección), «Escuchar» y «Mis palabras», el
/// ejemplo destacado y la fuente. Con [vieneDePregunta], «Pregúntala» vuelve a la conversación en vez de abrir otra
/// vacía.
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

/// El detalle de una palabra. «Escuchar» lee el término, la definición y el ejemplo (aunque la voz de las respuestas
/// esté desactivada en Ajustes: lo pide quien lo pulsa) y se calla al tocar «Parar», al cerrar la hoja y si la app
/// pasa a segundo plano. «Guardar en mis palabras» la añade a [favoritosProvider].
class DetalleTermino extends ConsumerStatefulWidget {
  const DetalleTermino({super.key, required this.entrada, this.vieneDePregunta = false, this.numero, this.total});

  final EntradaGlosario entrada;
  final bool vieneDePregunta;

  /// Número de la carta en la colección y cuántas hay («Nº 07/20»). Si no se sabe, no se enseña.
  final int? numero;
  final int? total;

  @override
  ConsumerState<DetalleTermino> createState() => _DetalleTerminoState();
}

class _DetalleTerminoState extends ConsumerState<DetalleTermino> {
  late final AppLifecycleListener _ciclo;

  /// La voz, solo desde que se pulsa «Escuchar»: abrir una palabra no arranca el motor de voz.
  Tts? _tts;
  bool _leyendo = false;

  /// Cambia con cada lectura: el final de una lectura antigua no cambia el botón de la nueva.
  var _lecturas = 0;

  /// La confirmación del último toque en «Mis palabras».
  String? _aviso;

  @override
  void initState() {
    super.initState();
    // Si la app se oculta (otra app, la pantalla apagada o, en web, otra pestaña), se deja de leer.
    _ciclo = AppLifecycleListener(onHide: _parar, onPause: _parar);
  }

  @override
  void dispose() {
    _ciclo.dispose();
    // Al cerrar la hoja (o la pantalla), la voz se calla.
    if (_leyendo) unawaited(_callar(_tts));
    super.dispose();
  }

  static Future<void> _callar(Tts? tts) async {
    try {
      await tts?.parar();
    } catch (_) {
      // Sin motor de voz no hay nada que parar.
    }
  }

  void _alternarLectura() {
    Hapticos.seleccion();
    if (_leyendo) {
      _parar();
    } else {
      _leer();
    }
  }

  void _leer() {
    final lectura = ++_lecturas;
    setState(() => _leyendo = true);
    void terminar() {
      if (mounted && lectura == _lecturas) setState(() => _leyendo = false);
    }

    try {
      final Tts tts = _tts ?? ref.read(ttsProvider);
      _tts = tts;
      unawaited(
        tts
            .hablar(textoParaEscuchar(widget.entrada), velocidad: ref.read(ajustesProvider).velocidadVoz)
            .then<void>((_) {}, onError: (Object _) {})
            .whenComplete(terminar),
      );
    } catch (_) {
      terminar();
    }
  }

  void _parar() {
    _lecturas++;
    if (!_leyendo) return;
    setState(() => _leyendo = false);
    unawaited(_callar(_tts));
  }

  void _alternarFavorita() {
    Hapticos.seleccion();
    final guardada = ref.read(favoritosProvider.notifier).alternar(widget.entrada.id);
    setState(() => _aviso = guardada ? avisoGuardada : avisoQuitada);
  }

  @override
  Widget build(BuildContext context) {
    final entrada = widget.entrada;
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final fuente = textoFuente(entrada);
    final esEjemplo = entrada.fuente.trim() == 'MOCK';
    final guardada = ref.watch(favoritosProvider).contains(entrada.id);
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
                    child: CartaTermino(entrada: entrada, numero: widget.numero, total: widget.total),
                  ),
                ),
                const SizedBox(height: Espacio.l),
                _Acciones(
                  leyendo: _leyendo,
                  guardada: guardada,
                  onEscuchar: _alternarLectura,
                  onGuardar: _alternarFavorita,
                ),
                // La confirmación se lee sola con TalkBack (región viva).
                Semantics(
                  container: true,
                  liveRegion: true,
                  child: AnimatedSize(
                    duration: duracionTamano(context, Duracion.corta),
                    alignment: Alignment.topCenter,
                    child: _aviso == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: Espacio.s),
                            child: Row(
                              children: [
                                IconoTuTurno(
                                  TuIcono.check,
                                  size: Espacio.l - Espacio.xs,
                                  estilo: EstiloIcono.mono,
                                  color: context.colores.exito,
                                  decorativo: true,
                                ),
                                const SizedBox(width: Espacio.s),
                                Expanded(
                                  child: Text(
                                    _aviso!,
                                    style: tema.textTheme.labelLarge?.copyWith(color: esquema.onSurface),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                      // De dónde sale: el libro de la ley, como en las fuentes del resto de la app (FuenteChip).
                      IconoTuTurno(
                        esEjemplo ? TuIcono.info : TuIcono.ley,
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
                    irAPregunta(router, vieneDePregunta: widget.vieneDePregunta);
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

/// «Escuchar» / «Parar» y «Guardar en mis palabras» / «Quitar de mis palabras». En un móvil, uno encima del otro y a
/// todo el ancho; si hay sitio (tableta o web), en una fila.
class _Acciones extends StatelessWidget {
  const _Acciones({required this.leyendo, required this.guardada, required this.onEscuchar, required this.onGuardar});

  final bool leyendo;
  final bool guardada;
  final VoidCallback onEscuchar;
  final VoidCallback onGuardar;

  @override
  Widget build(BuildContext context) {
    final escuchar = FilledButton.tonalIcon(
      key: const Key('glosario-escuchar'),
      onPressed: onEscuchar,
      icon: IconoTuTurno(leyendo ? TuIcono.silencio : TuIcono.altavoz, estilo: EstiloIcono.mono, decorativo: true),
      label: Text(leyendo ? 'Parar' : 'Escuchar'),
    );
    final guardar = OutlinedButton.icon(
      key: const Key('glosario-guardar'),
      // El mismo margen que los botones rellenos: con letra grande, la etiqueta en dos líneas no toca el borde.
      style: ButtonStyle(padding: Theme.of(context).filledButtonTheme.style?.padding),
      onPressed: onGuardar,
      // Guardada: la estrella amarilla, a dos tintas; sin guardar, de un color, como el texto.
      icon: IconoTuTurno(TuIcono.estrella, estilo: guardada ? EstiloIcono.color : EstiloIcono.mono, decorativo: true),
      label: Text(guardada ? 'Quitar de mis palabras' : 'Guardar en mis palabras'),
    );
    return LayoutBuilder(
      builder: (context, limites) {
        if (limites.maxWidth >= 520 && !letraGrande(context)) {
          return Row(
            children: [
              Expanded(child: escuchar),
              const SizedBox(width: Espacio.s + Espacio.xs),
              Expanded(child: guardar),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            escuchar,
            const SizedBox(height: Espacio.s + Espacio.xs),
            guardar,
          ],
        );
      },
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
