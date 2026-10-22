import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/progreso.dart';
import '../../tema.dart';
import '../../widgets/movimiento/hapticos.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/estados.dart';
import '../../widgets/modulos.dart' show anchoMaximo;
import '../../widgets/tuturno_scaffold.dart';
import 'caso_screen.dart' show CartaTocable;
import 'juego_providers.dart';
import 'modelos.dart';
import 'textos.dart';
import 'widgets/cabecera_escena.dart';
import 'widgets/carta.dart';
import 'widgets/estilo.dart';
import 'widgets/piezas.dart';

export 'caso_screen.dart' show CasoScreen;

/// «Vive el caso» (sección 4.2): los casos para jugar y la colección de cartas de derechos.
class JuegoScreen extends ConsumerWidget {
  const JuegoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casos = ref.watch(casosProvider);
    return TuTurnoScaffold(
      titulo: tituloJuego,
      body: casos.when(
        skipLoadingOnReload: true,
        data: (casos) => casos.isEmpty
            ? EstadoVacio(
                icono: Icons.style_rounded,
                titulo: sinCasosTitulo,
                mensaje: sinCasosMensaje,
                accion: FilledButton.icon(
                  onPressed: () => context.push('/pregunta'),
                  icon: const Icon(Icons.record_voice_over_rounded),
                  label: const Text('Ir a Pregunta'),
                ),
              )
            : _Portada(casos: casos),
        error: (_, _) => EstadoError(mensaje: errorCasos, onReintentar: () => ref.invalidate(casosProvider)),
        loading: () => const Cargando(mensaje: cargandoCasos),
      ),
    );
  }
}

class _Portada extends ConsumerWidget {
  const _Portada({required this.casos});

  final List<Caso> casos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final progreso = ref.watch(progresoProvider);
    final coleccion = coleccionDe(casos);
    final conseguidas = coleccion.where((e) => progreso.cartas.contains(e.carta.id)).length;
    final terminados = casos.where((c) => progreso.casosTerminados.contains(c.id)).length;
    final columnas = MediaQuery.sizeOf(context).width >= 600 ? 3 : 2;
    var orden = 0;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: anchoMaximo),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.m, Espacio.xl),
          children: [
            Entrada(
              orden: orden++,
              child: _Cabecera(
                conseguidas: conseguidas,
                total: coleccion.length,
                terminados: terminados,
                casos: casos.length,
                puntos: progreso.xp,
              ),
            ),
            const SizedBox(height: Espacio.l),
            Entrada(orden: orden++, child: const _TituloSeccion(tituloElegirCaso)),
            const SizedBox(height: Espacio.m),
            for (var i = 0; i < casos.length; i++) ...[
              Entrada(
                orden: orden++,
                child: _TarjetaCaso(caso: casos[i], numero: i + 1),
              ),
              const SizedBox(height: Espacio.m),
            ],
            if (coleccion.isNotEmpty) ...[
              const SizedBox(height: Espacio.s),
              Entrada(
                orden: orden++,
                child: _TituloColeccion(conseguidas: conseguidas, total: coleccion.length),
              ),
              const SizedBox(height: Espacio.m),
              Entrada(
                orden: orden++,
                child: RejillaCartas(
                  columnas: columnas,
                  hijos: [
                    for (var i = 0; i < coleccion.length; i++)
                      if (progreso.cartas.contains(coleccion[i].carta.id))
                        CartaTocable(carta: coleccion[i].carta, indice: i)
                      else
                        _CartaBloqueadaTocable(caso: coleccion[i].caso),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Espacio.l),
            Entrada(
              orden: orden++,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(child: Icon(Icons.info_outline_rounded, color: tema.colorScheme.onSurfaceVariant)),
                  const SizedBox(width: Espacio.s),
                  Expanded(
                    child: Text(
                      notaCasosInventados,
                      style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                    ),
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

/// Cabecera con el degradado del juego, un abanico de cartas y lo que llevas conseguido.
class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.conseguidas,
    required this.total,
    required this.terminados,
    required this.casos,
    required this.puntos,
  });

  final int conseguidas;
  final int total;
  final int terminados;
  final int casos;
  final int puntos;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = context.colores.juego;
    final tinta = tintaSobre(context, colores);
    final grande = MediaQuery.textScalerOf(context).scale(1) > 1.15;
    final forma = BorderRadius.circular(Radios.l);
    final textos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            tituloJuego,
            style: tema.textTheme.headlineMedium?.copyWith(color: tinta, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: Espacio.xs),
        Text(textoCabeceraJuego, style: tema.textTheme.bodyLarge?.copyWith(color: tinta)),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: degradadoDiagonal(colores),
        borderRadius: forma,
        boxShadow: sombrasPapel(context),
      ),
      child: ClipRRect(
        borderRadius: forma,
        child: Stack(
          children: [
            Positioned(
              right: -Espacio.xxl,
              bottom: -Espacio.xxl,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(shape: BoxShape.circle, color: tinta.withValues(alpha: 0.07)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Espacio.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (grande)
                    textos
                  else
                    Row(
                      children: [
                        Expanded(child: textos),
                        const SizedBox(width: Espacio.m),
                        _Abanico(tinta: tinta),
                      ],
                    ),
                  const SizedBox(height: Espacio.m + Espacio.xs),
                  Wrap(
                    spacing: Espacio.s,
                    runSpacing: Espacio.s,
                    children: [
                      _Dato(icono: Icons.style_rounded, texto: '$conseguidas de $total cartas', tinta: tinta),
                      _Dato(
                        icono: Icons.flag_rounded,
                        texto: '$terminados de $casos ${casos == 1 ? 'caso' : 'casos'}',
                        tinta: tinta,
                      ),
                      _Dato(icono: Icons.bolt_rounded, texto: '$puntos puntos', tinta: tinta),
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

/// Tres cartas en abanico (decoración).
class _Abanico extends StatelessWidget {
  const _Abanico({required this.tinta});

  final Color tinta;

  @override
  Widget build(BuildContext context) {
    const iconos = [Icons.hearing_rounded, Icons.videocam_rounded, Icons.shield_rounded];
    return ExcludeSemantics(
      child: SizedBox(
        width: 104,
        height: 96,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Transform.translate(
                offset: Offset((i - 1) * 22.0, (i - 1).abs() * 6.0),
                child: Transform.rotate(
                  angle: (i - 1) * 0.26,
                  child: Container(
                    width: 52,
                    height: 72,
                    decoration: BoxDecoration(
                      color: tinta.withValues(alpha: 0.16 + i * 0.05),
                      borderRadius: BorderRadius.circular(Radios.s),
                      border: Border.all(color: tinta.withValues(alpha: 0.55), width: 1.5),
                    ),
                    child: Icon(iconos[i], color: tinta, size: 24),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto, required this.tinta});

  final IconData icono;
  final String texto;
  final Color tinta;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: tinta.withValues(alpha: 0.14),
        shape: StadiumBorder(side: BorderSide(color: tinta.withValues(alpha: 0.35))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Espacio.s + Espacio.xs, vertical: Espacio.xs + 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(icono, size: Espacio.m + 2, color: tinta),
            ),
            const SizedBox(width: Espacio.xs + 2),
            Flexible(
              child: Text(
                texto,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: tinta, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de un caso: la ilustración de su primera escena, quién lo protagoniza, de qué va y cómo vas.
class _TarjetaCaso extends ConsumerWidget {
  const _TarjetaCaso({required this.caso, required this.numero});

  final Caso caso;
  final int numero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final progreso = ref.watch(progresoProvider);
    final partida = ref.watch(partidaProvider(caso.id)).value;
    final terminado = progreso.casosTerminados.contains(caso.id);
    final enCurso = partida != null && partida.empezada && !partida.terminada;
    final ganadas = caso.cartas.where((c) => progreso.cartas.contains(c.id)).length;
    final (estado, iconoEstado) = enCurso
        ? ('Escena ${partida.numeroEscena} de ${partida.totalEscenas}', Icons.play_circle_rounded)
        : terminado
        ? (estadoTerminado, Icons.check_circle_rounded)
        : (estadoNuevo, Icons.auto_awesome_rounded);
    final cta = enCurso ? ctaSeguirCaso : (terminado || (partida?.terminada ?? false) ? ctaOtraVez : ctaEmpezar);
    final rol = nombreRol(caso.rol);
    final forma = BorderRadius.circular(Radios.l);

    void abrir() {
      // Un caso ya terminado se vuelve a jugar desde el principio; uno a medias sigue donde se dejó.
      if (!enCurso && (partida?.terminada ?? false)) ref.read(partidaProvider(caso.id).notifier).reiniciar();
      context.push('/juego/${caso.id}');
    }

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Pulsable(
          onTap: abrir,
          decoracion: BoxDecoration(
            color: esquema.surfaceContainerLow,
            borderRadius: forma,
            border: Border.all(color: esquema.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: CabeceraEscena.altoCompacta,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Portada: la cabecera de la primera escena (el hueco que ocupará el pixel art).
                    CabeceraEscena(escena: caso.primera, protagonista: caso.protagonista, compacta: true),
                    Positioned(
                      left: Espacio.m,
                      bottom: Espacio.s + Espacio.xs,
                      child: AvatarProtagonista(nombre: caso.protagonista),
                    ),
                    Positioned(
                      right: Espacio.s + Espacio.xs,
                      top: Espacio.s + Espacio.xs,
                      child: _PildoraEstado(texto: estado, icono: iconoEstado),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espacio.m + Espacio.xs,
                  Espacio.m,
                  Espacio.m + Espacio.xs,
                  Espacio.m,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: Espacio.s,
                      runSpacing: Espacio.s,
                      children: [
                        EtiquetaSuave(texto: 'Caso $numero'),
                        if (rol.isNotEmpty) EtiquetaSuave(texto: rol, icono: Icons.shield_rounded),
                        if (!caso.validado)
                          EtiquetaSuave(texto: 'Borrador', icono: Icons.edit_note_rounded, color: esquema.tertiary),
                      ],
                    ),
                    const SizedBox(height: Espacio.s + Espacio.xs),
                    Text(caso.titulo, style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: Espacio.xs),
                    Text(
                      presentacion(caso.protagonista, caso.edad),
                      style: tema.textTheme.titleSmall?.copyWith(color: esquema.primary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: Espacio.s),
                    Text(
                      caso.resumen,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                    if (caso.cartas.isNotEmpty) ...[
                      const SizedBox(height: Espacio.m),
                      _BarraCartas(ganadas: ganadas, total: caso.cartas.length),
                    ],
                    const SizedBox(height: Espacio.m),
                    _BotonFalso(texto: cta, icono: enCurso ? Icons.play_arrow_rounded : Icons.arrow_forward_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PildoraEstado extends StatelessWidget {
  const _PildoraEstado({required this.texto, required this.icono});

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(color: esquema.surface.withValues(alpha: 0.94), shape: const StadiumBorder()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Espacio.s + Espacio.xs, vertical: Espacio.xs + 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: Espacio.m + 2, color: esquema.primary),
            const SizedBox(width: Espacio.xs),
            Text(
              texto,
              style: tema.textTheme.labelLarge?.copyWith(color: esquema.onSurface, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarraCartas extends StatelessWidget {
  const _BarraCartas({required this.ganadas, required this.total});

  final int ganadas;
  final int total;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Row(
      children: [
        ExcludeSemantics(
          child: Icon(Icons.style_rounded, size: Espacio.l - Espacio.xs, color: esquema.primary),
        ),
        const SizedBox(width: Espacio.s),
        Text(
          '$ganadas de $total cartas',
          style: tema.textTheme.labelLarge?.copyWith(color: esquema.onSurface, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: Espacio.m),
        Expanded(
          child: ExcludeSemantics(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: total == 0 ? 0 : ganadas / total),
              duration: duracion(context, Duracion.larga),
              curve: Curves.easeOutCubic,
              builder: (context, valor, _) => ClipRRect(
                borderRadius: BorderRadius.circular(Espacio.s),
                child: LinearProgressIndicator(
                  value: valor,
                  minHeight: Espacio.s,
                  color: esquema.primary,
                  backgroundColor: esquema.surfaceContainerHighest,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Aspecto de botón dentro de una tarjeta que ya es pulsable entera (un solo objetivo para el lector de pantalla).
class _BotonFalso extends StatelessWidget {
  const _BotonFalso({required this.texto, required this.icono});

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: esquema.primary, borderRadius: BorderRadius.circular(Radios.m)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Espacio.l, vertical: Espacio.s + Espacio.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  texto,
                  style: tema.textTheme.titleMedium?.copyWith(color: esquema.onPrimary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: Espacio.s),
              ExcludeSemantics(child: Icon(icono, color: esquema.onPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(texto, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

class _TituloColeccion extends StatelessWidget {
  const _TituloColeccion({required this.conseguidas, required this.total});

  final int conseguidas;
  final int total;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _TituloSeccion(tituloColeccion)),
            Text(
              '$conseguidas/$total',
              semanticsLabel: '$conseguidas de $total cartas',
              style: tema.textTheme.titleMedium?.copyWith(color: esquema.primary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: Espacio.xs),
        Text(
          conseguidas == total
              ? '¡Las tienes todas! Ya conoces todos los derechos de estos casos.'
              : 'Cada buena decisión en un caso te da una carta. Toca una para verla en grande.',
          style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Carta bloqueada de la colección: al tocarla, dice en qué caso se gana y deja ir a jugarlo.
class _CartaBloqueadaTocable extends StatelessWidget {
  const _CartaBloqueadaTocable({required this.caso});

  final Caso caso;

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(Radios.l);
    return Semantics(
      button: true,
      hint: 'Toca para saber dónde se consigue',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: forma,
          onTap: () {
            Hapticos.seleccion();
            final router = GoRouter.of(context);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(textoCartaBloqueada(caso.protagonista)),
                  action: SnackBarAction(label: 'Jugar', onPressed: () => router.push('/juego/${caso.id}')),
                ),
              );
          },
          child: CartaBloqueada(pista: tituloCaso(caso.protagonista)),
        ),
      ),
    );
  }
}
