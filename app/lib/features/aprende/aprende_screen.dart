import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/progreso.dart';
import '../../core/providers.dart';
import '../../tema.dart';
import '../../widgets/estados.dart';
import '../../widgets/tuturno_scaffold.dart';
import 'curso.dart';
import 'modelos.dart';
import 'widgets/comunes.dart';
import 'widgets/mapa.dart';

export 'leccion_screen.dart' show LeccionScreen;

// Aprende (sección 4.3): mapa de unidades con las lecciones como un camino de nodos, XP y racha arriba,
// barras de dominio por concepto (BKT) y «Practicar», que elige ejercicios según lo que te cuesta más (10.6).

class AprendeScreen extends ConsumerWidget {
  const AprendeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curso = ref.watch(cursoProvider);
    return TuTurnoScaffold(
      titulo: 'Aprende',
      body: AnimatedSwitcher(
        duration: duracion(context, Duracion.media),
        child: curso.when(
          loading: () => const Cargando(key: ValueKey('cargando'), mensaje: 'Preparando tus lecciones…'),
          error: (_, _) => EstadoError(
            key: const ValueKey('error'),
            mensaje: 'No he podido cargar las lecciones. Prueba otra vez.',
            onReintentar: () => ref.invalidate(cursoProvider),
          ),
          data: (curso) => curso.estaVacio
              ? EstadoVacio(
                  key: const ValueKey('vacio'),
                  icono: Icons.auto_stories_rounded,
                  titulo: 'Las lecciones están en camino',
                  mensaje: 'Muy pronto podrás aprender aquí tus derechos, paso a paso. Mientras, puedes preguntar tus dudas.',
                  accion: FilledButton.icon(
                    onPressed: () => context.push('/pregunta'),
                    icon: const Icon(Icons.record_voice_over_rounded),
                    label: const Text('Ir a Pregunta'),
                  ),
                )
              : _Mapa(key: const ValueKey('mapa'), curso: curso),
        ),
      ),
    );
  }
}

class _Mapa extends ConsumerStatefulWidget {
  const _Mapa({super.key, required this.curso});

  final Curso curso;

  @override
  ConsumerState<_Mapa> createState() => _MapaState();
}

class _MapaState extends ConsumerState<_Mapa> {
  final _claveActual = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Si la lección que toca está más abajo, el mapa baja hasta ella.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final completadas = ref.read(progresoProvider).leccionesCompletadas;
      final siguiente = widget.curso.siguiente(completadas);
      final posicion = siguiente == null ? -1 : widget.curso.lecciones.indexWhere((l) => l.id == siguiente.id);
      final contexto = _claveActual.currentContext;
      // Solo si el mapa está maquetado: con una lección abierta encima (al entrar por un enlace a la lección, o con
      // go), Aprende está debajo, sin maquetar, y no hay adónde desplazarse.
      final caja = contexto?.findRenderObject();
      if (posicion >= 2 && contexto != null && caja is RenderBox && caja.hasSize) {
        Scrollable.ensureVisible(
          contexto,
          alignment: 0.45,
          duration: duracion(context, Duracion.larga),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _abrir(Leccion leccion, EstadoLeccion estado) {
    if (estado != EstadoLeccion.bloqueada) {
      context.push(rutaLeccion(leccion.id));
      return;
    }
    _explicarBloqueo(leccion);
  }

  Future<void> _explicarBloqueo(Leccion leccion) {
    final curso = widget.curso;
    final completadas = ref.read(progresoProvider).leccionesCompletadas;
    final anterior = curso.anterior(leccion.id);
    final siguiente = curso.siguiente(completadas);
    final demo = ref.read(configProvider).demo;
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (hoja) {
        final tema = Theme.of(hoja);
        final esquema = tema.colorScheme;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Espacio.l, 0, Espacio.l, Espacio.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: Espacio.xxl + Espacio.m,
                  height: Espacio.xxl + Espacio.m,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: esquema.surfaceContainerHighest),
                  child: Icon(Icons.lock_rounded, size: Espacio.xl, color: esquema.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: Espacio.m),
              Semantics(
                header: true,
                child: Text(
                  '«${leccion.titulo}» aún está cerrada',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: Espacio.s),
              Text(
                anterior == null
                    ? 'Termina las lecciones anteriores para abrirla.'
                    : 'Se abre cuando completes «${anterior.titulo}». ¡Vas muy bien!',
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurfaceVariant),
              ),
              const SizedBox(height: Espacio.l),
              if (siguiente != null)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(hoja).pop();
                    context.push(rutaLeccion(siguiente.id));
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text('Ir a «${siguiente.titulo}»'),
                ),
              if (demo) ...[
                const SizedBox(height: Espacio.s),
                TextButton(
                  onPressed: () {
                    Navigator.of(hoja).pop();
                    context.push(rutaLeccion(leccion.id));
                  },
                  child: const Text('Abrirla igualmente (modo demo)'),
                ),
              ],
              TextButton(onPressed: () => Navigator.of(hoja).pop(), child: const Text('Vale')),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final curso = widget.curso;
    final progreso = ref.watch(progresoProvider);
    final ahora = ref.watch(relojProvider)();
    final completadas = progreso.leccionesCompletadas;
    final siguiente = curso.siguiente(completadas);
    final estados = {for (final l in curso.lecciones) l.id: curso.estado(l.id, completadas)};
    final ejercicios = {for (final l in curso.lecciones) l.id: curso.ejerciciosDe(l).length};
    final hechas = curso.lecciones.where((l) => completadas.contains(l.id)).length;
    final primeraVez = hechas == 0;
    // Modo DEMO: mantener pulsada una lección la abre en su «Dilo con tus palabras» (ruta de la demo, sección 4.6).
    final demo = ref.watch(configProvider).demo;
    var orden = 0;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: anchoMaximoAprende),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.m, Espacio.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Aparece(
                orden: orden++,
                child: _Cabecera(
                  xp: progreso.xp,
                  racha: rachaVisible(progreso, ahora),
                  rachaHoy: rachaDeHoy(progreso, ahora),
                  hechas: hechas,
                  total: curso.lecciones.length,
                  siguiente: siguiente,
                  onSeguir: () {
                    if (siguiente != null) {
                      context.push(rutaLeccion(siguiente.id));
                    } else {
                      final unidad = curso.unidadActual(completadas);
                      if (unidad != null) context.push(rutaPractica(unidad.id));
                    }
                  },
                ),
              ),
              for (final (i, unidad) in curso.unidades.indexed) ...[
                const SizedBox(height: Espacio.xl),
                Aparece(
                  orden: orden++,
                  child: BannerUnidad(
                    numero: i + 1,
                    unidad: unidad,
                    completadas: unidad.lecciones.where((l) => completadas.contains(l.id)).length,
                    abierta: curso.unidadAbierta(unidad, completadas),
                    onPracticar: () => context.push(rutaPractica(unidad.id)),
                  ),
                ),
                const SizedBox(height: Espacio.l),
                Aparece(
                  orden: orden++,
                  child: CaminoUnidad(
                    unidad: unidad,
                    estados: estados,
                    numeroEjercicios: ejercicios,
                    actual: siguiente?.id,
                    claveActual: _claveActual,
                    textoAviso: primeraVez ? '¡Empieza aquí!' : 'Sigue aquí',
                    onLeccion: _abrir,
                    onLeccionLarga: demo ? (leccion) => context.push(rutaDemoDilo(leccion.id)) : null,
                  ),
                ),
                const SizedBox(height: Espacio.l),
                Aparece(
                  orden: orden++,
                  child: TarjetaDominio(conceptos: unidad.conceptos, dominio: progreso.dominio),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabecera con el degradado de Aprende: XP, racha, lecciones hechas y el botón para seguir.
class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.xp,
    required this.racha,
    required this.rachaHoy,
    required this.hechas,
    required this.total,
    required this.siguiente,
    required this.onSeguir,
  });

  final int xp;
  final int racha;
  final bool rachaHoy;
  final int hechas;
  final int total;
  final Leccion? siguiente;
  final VoidCallback onSeguir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = context.colores.aprende;
    final texto = sobreColor(colores.first);
    final pegatina = colorPegatina(context);
    final siguiente = this.siguiente;
    final mensajeRacha = racha == 0
        ? 'Completa una lección para empezar tu racha.'
        : (rachaHoy ? '¡Hoy ya has sumado a tu racha!' : 'Haz una lección hoy para no perder tu racha.');
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: degradadoAprende(context),
        borderRadius: BorderRadius.circular(Radios.l),
        boxShadow: tema.brightness == Brightness.dark
            ? const []
            : [
                BoxShadow(
                  color: colores.last.withValues(alpha: 0.28),
                  blurRadius: Espacio.l,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radios.l),
        child: Stack(
          children: [
            Positioned(
              right: -Espacio.xxl,
              top: -Espacio.xxl,
              child: ExcludeSemantics(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: texto.withValues(alpha: 0.08)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Espacio.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: Espacio.s,
                    runSpacing: Espacio.s,
                    children: [
                      PastillaDato(
                        icono: Icons.bolt_rounded,
                        texto: ContadorAnimado(valor: xp, sufijo: ' XP'),
                        semantica: '$xp puntos de experiencia',
                        colorTexto: texto,
                      ),
                      PastillaDato(
                        icono: Icons.local_fire_department_rounded,
                        texto: Text(racha == 1 ? '1 día' : '$racha días'),
                        semantica: 'Racha de $racha ${racha == 1 ? 'día' : 'días'}',
                        colorTexto: texto,
                      ),
                    ],
                  ),
                  const SizedBox(height: Espacio.m),
                  Semantics(
                    header: true,
                    child: Text(
                      siguiente == null
                          ? '¡Lo has completado todo!'
                          : (hechas == 0 ? '¡Empieza a aprender!' : '¡Sigue así!'),
                      style: tema.textTheme.headlineMedium?.copyWith(color: texto),
                    ),
                  ),
                  const SizedBox(height: Espacio.xs),
                  Text(mensajeRacha, style: tema.textTheme.bodyLarge?.copyWith(color: texto)),
                  const SizedBox(height: Espacio.m),
                  Row(
                    children: [
                      Expanded(
                        child: BarraProgreso(
                          valor: total == 0 ? 0 : hechas / total,
                          etiqueta: 'Lecciones completadas',
                          valorTexto: '$hechas de $total',
                          alto: Espacio.s + 2,
                          colores: [texto, texto],
                          fondo: texto.withValues(alpha: 0.25),
                        ),
                      ),
                      const SizedBox(width: Espacio.s + Espacio.xs),
                      // La barra ya lo dice al lector de pantalla.
                      ExcludeSemantics(
                        child: Text(
                          '$hechas/$total lecciones',
                          style: tema.textTheme.labelLarge?.copyWith(color: texto, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Espacio.l - Espacio.xs),
                  FilledButton.icon(
                    key: const ValueKey('boton-seguir'),
                    // Amarillo sobre azul: la acción principal, como una pegatina de la marca.
                    style: FilledButton.styleFrom(backgroundColor: pegatina.fondo, foregroundColor: pegatina.tinta),
                    onPressed: onSeguir,
                    icon: Icon(siguiente == null ? Icons.fitness_center_rounded : Icons.play_arrow_rounded),
                    label: Text(
                      siguiente == null
                          ? 'Repasar lo aprendido'
                          : '${hechas == 0 ? 'Empezar' : 'Seguir'}: ${siguiente.titulo}',
                      textAlign: TextAlign.center,
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
