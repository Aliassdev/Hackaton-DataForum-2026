import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/progreso.dart';
import '../../core/providers.dart';
import '../../pixel/juzgado/juzgado.dart';
import '../../pixel/ui/ui.dart';
import '../../tema.dart';
import '../../widgets/ayuda_button.dart';
import 'juego_providers.dart' show casosProvider, coleccionDe, xpPorCarta;
import 'modelos.dart';
import 'widgets/carta.dart' show mostrarCartaNueva;

/// La ruta de «El juzgado por dentro». Con `?modo=menores`, la audiencia del caso de Sergio.
const rutaJuzgado = '/juego/juzgado';

/// Id de la carta que se gana al conocer a todas las personas del juzgado.
const cartaQuienEsQuienId = 'R-quien-es-quien';

/// «Sabes quién es quién en el juzgado»: la carta de «El juzgado por dentro», que va al final de la colección. Es un
/// logro del juego, no una afirmación jurídica: no lleva fuente.
const cartaQuienEsQuien = Carta(
  id: cartaQuienEsQuienId,
  titulo: 'Sabes quién es quién en el juzgado',
  texto: 'Has conocido a todas las personas de la sala y sabes qué hace cada una.',
  fuente: '',
);

/// El edificio de un juzgado (11 × 10): frontón, columnas y escalones, sin escudos ni banderas. Para la entrada de
/// la lista de casos y para la carta.
const glifoJuzgado = GlifoPixel('juzgado', [
  '.....#.....',
  '...#####...',
  '.#########.',
  '###########',
  '.#.#.#.#.#.',
  '.#.#.#.#.#.',
  '.#.#.#.#.#.',
  '.#.#.#.#.#.',
  '.#########.',
  '###########',
]);

const tituloJuzgado = 'El juzgado por dentro';
const tituloJuzgadoMenores = 'Juzgado de Menores';
const tituloEnRevision = 'El juzgado por dentro está en revisión';
const textoEnRevision = 'Sus textos están pendientes de revisión jurídica. Mientras, puedes jugar los casos.';
const botonVolverACasos = 'Volver a los casos';

/// Si se puede abrir «El juzgado por dentro» en [modo]. Sus textos son jurídicos: mientras no estén revisados
/// (`DatosJuzgado.validado`), solo salen en modo DEMO con el interruptor de borradores, como el resto del contenido
/// sin validar (CLAUDE.md). Así lo deciden a la vez la entrada de la lista, la carta y esta pantalla.
final juzgadoVisibleProvider = Provider.family<bool, ModoJuzgado>(
  (ref, modo) => DatosJuzgado.de(modo).validado || ref.watch(contentProvider).mostrarBorradores,
);

/// Los ids de las personas de la sala de [modo].
Set<String> idsDelJuzgado(ModoJuzgado modo) => {for (final rol in DatosJuzgado.de(modo).roles) rol.id};

/// La ruta `juzgado`, hija de /juego ([rutaJuzgado]). Va la primera de las hijas: después, ':casoId' se quedaría con
/// «juzgado». [pagina] hace la página con la transición de la app (en app.dart, la misma que la de /juego/:casoId); sin
/// ella, la de Material.
GoRoute rutaHijaJuzgado({Page<void> Function(BuildContext context, GoRouterState state, Widget pantalla)? pagina}) {
  Widget pantalla(GoRouterState state) => JuzgadoScreen(modo: JuzgadoScreen.modoDe(state.uri.queryParameters['modo']));
  return GoRoute(
    path: 'juzgado',
    builder: pagina == null ? (context, state) => pantalla(state) : null,
    pageBuilder: pagina == null ? null : (context, state) => pagina(context, state, pantalla(state)),
  );
}

/// /juzgado, con su query (`?modo=menores`), lleva a [rutaJuzgado]: es la que usan el final del caso de Sergio y el
/// atajo de la demo.
GoRoute rutaRedireccionJuzgado() => GoRoute(
  path: '/juzgado',
  redirect: (context, state) => Uri(
    path: rutaJuzgado,
    queryParameters: state.uri.queryParameters.isEmpty ? null : state.uri.queryParameters,
  ).toString(),
);

/// «El juzgado por dentro» ([rutaJuzgado]): la sala en pixel art para conocer, persona a persona, quién es quién
/// (`JuzgadoExplorable`, en lib/pixel/juzgado). Lo descubierto se guarda en el progreso (personasConocidas), así que
/// al volver sigue donde se dejó, y al conocer a todo el mundo se gana, una sola vez, la carta [cartaQuienEsQuien].
///
/// Arriba, la barra del juego (volver, Glosario y Ayuda). Si los textos aún no se pueden enseñar
/// ([juzgadoVisibleProvider]), lo dice y deja volver a los casos.
class JuzgadoScreen extends ConsumerStatefulWidget {
  const JuzgadoScreen({super.key, this.modo = ModoJuzgado.salaVistas});

  /// El modo de la query `modo` de la ruta: `menores` o, con cualquier otro valor o sin él, la sala de vistas.
  static ModoJuzgado modoDe(String? valor) => valor == 'menores' ? ModoJuzgado.menores : ModoJuzgado.salaVistas;

  final ModoJuzgado modo;

  @override
  ConsumerState<JuzgadoScreen> createState() => _JuzgadoScreenState();
}

class _JuzgadoScreenState extends ConsumerState<JuzgadoScreen> {
  var _ganando = false;

  @override
  void initState() {
    super.initState();
    // Si ya se conocía a todo el mundo (de otra vez) pero aún no estaba la carta, se gana al entrar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.read(juzgadoVisibleProvider(widget.modo))) return;
      final conocidas = ref.read(progresoProvider).personasConocidas;
      if (conocidas.containsAll(idsDelJuzgado(widget.modo))) unawaited(_ganarCarta());
    });
  }

  /// La carta, una sola vez: con sus puntos y la misma celebración que las cartas de los casos (sale bloqueada, se
  /// desbloquea con brillo y vibra). Va la última de la colección, con el dibujo del edificio.
  Future<void> _ganarCarta() async {
    if (_ganando || ref.read(progresoProvider).cartas.contains(cartaQuienEsQuienId)) return;
    _ganando = true;
    final progreso = ref.read(progresoProvider.notifier);
    await progreso.desbloquearCarta(cartaQuienEsQuienId);
    await progreso.sumarXp(xpPorCarta);
    if (!mounted) return;
    final casos = ref.read(casosProvider).value ?? const <Caso>[];
    await mostrarCartaNueva(
      context,
      carta: cartaQuienEsQuien,
      indice: coleccionDe(casos).length,
      xp: xpPorCarta,
      icono: glifoJuzgado,
    );
  }

  void _volver() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/juego');
    }
  }

  @override
  Widget build(BuildContext context) {
    final modo = widget.modo;
    final visible = ref.watch(juzgadoVisibleProvider(modo));
    final conocidas = ref.watch(progresoProvider.select((p) => p.personasConocidas));
    final tieneCarta = ref.watch(progresoProvider.select((p) => p.cartas.contains(cartaQuienEsQuienId)));
    final ids = idsDelJuzgado(modo);
    final conocidos = conocidas.where(ids.contains).length;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HudPixel(
            titulo: modo == ModoJuzgado.menores ? tituloJuzgadoMenores : tituloJuzgado,
            progreso: visible && ids.isNotEmpty ? conocidos / ids.length : 0,
            segmentos: ids.isEmpty ? 1 : ids.length,
            etiquetaProgreso: 'Personas que conoces',
            textoProgreso: 'Has conocido a $conocidos de ${ids.length}',
            cartas: visible ? (tieneCarta ? 1 : 0) : null,
            totalCartas: visible ? 1 : null,
            onVolver: _volver,
            acciones: const [GlosarioButton(), AyudaButton()],
          ),
          Expanded(
            child: SafeArea(
              top: false,
              // El scroll del juego: sin el estirado de Android, que reescalaría (y emborronaría) la sala.
              child: ScrollPixel(
                child: visible
                    ? JuzgadoExplorable(
                        modo: modo,
                        descubiertosIniciales: conocidas,
                        onDescubierto: (id) => unawaited(ref.read(progresoProvider.notifier).conocerPersona(id)),
                        onTodosDescubiertos: () => unawaited(_ganarCarta()),
                      )
                    : _EnRevision(onVolver: _volver),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mientras los textos no se pueden enseñar: qué pasa y cómo volver.
class _EnRevision extends StatelessWidget {
  const _EnRevision({required this.onVolver});

  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Espacio.l),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconoPixel(glifoJuzgado, escala: 3, color: tema.colorScheme.primary),
              const SizedBox(height: Espacio.l),
              Semantics(
                header: true,
                child: Text(tituloEnRevision, textAlign: TextAlign.center, style: tema.textTheme.titleLarge),
              ),
              const SizedBox(height: Espacio.s),
              Text(
                textoEnRevision,
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: Espacio.l),
              BotonPixel(etiqueta: botonVolverACasos, onPressed: onVolver),
            ],
          ),
        ),
      ),
    );
  }
}
