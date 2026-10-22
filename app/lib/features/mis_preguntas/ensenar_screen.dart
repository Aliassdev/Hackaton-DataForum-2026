import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/mis_preguntas.dart';
import '../../tema.dart';
import '../../widgets/iconos/iconos.dart';
import 'textos.dart';

/// «Enseñar en grande» (/mis-preguntas/ensenar, plan v2, producto §5.2): tus apuntes a pantalla completa, uno por
/// página, en letra muy grande y con mucho contraste (azul noche sobre papel; papel sobre azul noche en oscuro), para
/// enseñárselos a tu abogado o abogada, a la psicóloga o a la fiscal. Encima, «QUIERO PEDIR» o «QUIERO PREGUNTAR»;
/// abajo, «Anterior», «Ya lo he preguntado» y «Siguiente». Sin barra: solo «Cerrar». Con «reducir animaciones», las
/// páginas cambian sin moverse.
class EnsenarScreen extends ConsumerStatefulWidget {
  const EnsenarScreen({super.key});

  @override
  ConsumerState<EnsenarScreen> createState() => _EnsenarScreenState();
}

class _EnsenarScreenState extends ConsumerState<EnsenarScreen> {
  final _paginas = PageController();
  var _actual = 0;

  /// El orden de las páginas se fija al entrar: marcar «Ya lo he preguntado» no mueve nada.
  late final List<String> _orden = () {
    final apuntes = ref.read(misPreguntasProvider);
    return [
      for (final a in apuntes)
        if (a.tipo == TipoApunte.pedir) a.id,
      for (final a in apuntes)
        if (a.tipo == TipoApunte.preguntar) a.id,
    ];
  }();

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  void _cerrar() {
    HapticFeedback.selectionClick();
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      router.pop();
    } else if (router != null) {
      router.go('/mis-preguntas');
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _ir(int pagina) {
    HapticFeedback.selectionClick();
    final movimiento = duracion(context, Duracion.media);
    if (movimiento == Duration.zero) {
      _paginas.jumpToPage(pagina);
    } else {
      _paginas.animateToPage(pagina, duration: movimiento, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final oscuro = tema.brightness == Brightness.dark;
    final fondo = oscuro ? ColoresMarca.azulNoche : ColoresMarca.papel;
    final tinta = oscuro ? ColoresMarca.papel : ColoresMarca.azulNoche;
    final porId = {for (final a in ref.watch(misPreguntasProvider)) a.id: a};
    final apuntes = [
      for (final id in _orden)
        if (porId[id] case final Apunte a) a,
    ];
    final total = apuntes.length;
    final actual = total == 0 ? 0 : _actual.clamp(0, total - 1);
    return Scaffold(
      backgroundColor: fondo,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.s, 0),
              child: Row(
                children: [
                  Expanded(
                    child: total == 0
                        ? const SizedBox.shrink()
                        : Text(
                            '${actual + 1} de $total',
                            style: estiloCifras(tema.textTheme.titleLarge)?.copyWith(color: tinta),
                          ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: tinta, minimumSize: const Size(48, 48)),
                    onPressed: _cerrar,
                    icon: IconoTuTurno(TuIcono.cerrar, estilo: EstiloIcono.mono, color: tinta, decorativo: true),
                    label: const Text(botonCerrar),
                  ),
                ],
              ),
            ),
            Expanded(
              child: total == 0
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(Espacio.xl),
                        child: Text(
                          vacioEnsenar,
                          textAlign: TextAlign.center,
                          style: tema.textTheme.titleLarge?.copyWith(color: tinta),
                        ),
                      ),
                    )
                  : PageView.builder(
                      controller: _paginas,
                      itemCount: total,
                      onPageChanged: (pagina) => setState(() => _actual = pagina),
                      itemBuilder: (context, i) => _Pagina(apunte: apuntes[i], tinta: tinta, fondo: fondo),
                    ),
            ),
            if (total > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.m, Espacio.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BotonHecho(apunte: apuntes[actual], tinta: tinta, fondo: fondo),
                    const SizedBox(height: Espacio.s),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: tinta,
                              side: BorderSide(color: tinta, width: 2),
                            ),
                            onPressed: actual == 0 ? null : () => _ir(actual - 1),
                            child: const Text(botonAnterior),
                          ),
                        ),
                        const SizedBox(width: Espacio.s),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: tinta, foregroundColor: fondo),
                            onPressed: actual >= total - 1 ? null : () => _ir(actual + 1),
                            child: const Text(botonSiguiente),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Una página: la etiqueta y el apunte en letra muy grande (Nunito ExtraBold, o Atkinson Hyperlegible con «lectura
/// fácil»). Si no cabe, se desplaza.
class _Pagina extends StatelessWidget {
  const _Pagina({required this.apunte, required this.tinta, required this.fondo});

  final Apunte apunte;
  final Color tinta;
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    // La letra del texto del tema (Nunito o Atkinson): a un metro se lee mejor que la de los titulares.
    final familia = tema.textTheme.bodyLarge?.fontFamily;
    // Corto (lo normal): todavía más grande. Largo: un poco menos, para que quepa sin desplazar.
    final base = apunte.texto.length <= 60 ? tema.textTheme.displayMedium : tema.textTheme.displaySmall;
    final grande = base?.copyWith(
      fontFamily: familia,
      fontWeight: FontWeight.w800,
      height: 1.25,
      letterSpacing: 0,
      wordSpacing: 0,
      color: tinta,
    );
    final etiqueta = apunte.tipo == TipoApunte.pedir ? etiquetaPedir : etiquetaPreguntar;
    return Semantics(
      container: true,
      label: '$etiqueta. ${apunte.texto}${apunte.hecho ? '. $textoYaPreguntado' : ''}',
      excludeSemantics: true,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: Espacio.l, vertical: Espacio.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: ColoresMarca.amarillo,
                  borderRadius: BorderRadius.circular(Radios.s),
                  border: Border.all(color: ColoresMarca.azulNoche, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Espacio.s + 2, vertical: Espacio.xs),
                  child: Text(
                    etiqueta,
                    style: tema.textTheme.titleMedium?.copyWith(
                      color: ColoresMarca.azulNoche,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Espacio.l),
              Text(apunte.texto, style: grande),
              if (apunte.hecho) ...[
                const SizedBox(height: Espacio.l),
                Text(
                  '✓ $textoYaPreguntado',
                  style: tema.textTheme.titleLarge?.copyWith(color: tinta, fontWeight: FontWeight.w800),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// «Ya lo he preguntado»: se marca (y se desmarca) en la página que se está enseñando.
class _BotonHecho extends ConsumerWidget {
  const _BotonHecho({required this.apunte, required this.tinta, required this.fondo});

  final Apunte apunte;
  final Color tinta;
  final Color fondo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hecho = apunte.hecho;
    return Semantics(
      toggled: hecho,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: hecho ? ColoresMarca.amarillo : null,
          foregroundColor: hecho ? ColoresMarca.azulNoche : tinta,
          side: BorderSide(color: hecho ? ColoresMarca.azulNoche : tinta, width: 2),
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          ref.read(misPreguntasProvider.notifier).marcar(apunte.id, !hecho);
        },
        icon: IconoTuTurno(
          TuIcono.check,
          estilo: EstiloIcono.mono,
          color: hecho ? ColoresMarca.azulNoche : tinta,
          decorativo: true,
        ),
        label: const Text(textoYaPreguntado),
      ),
    );
  }
}
