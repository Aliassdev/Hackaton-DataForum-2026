import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/entrada.dart' show Fase, entradaProvider;
import '../../core/mis_preguntas.dart';
import '../../core/providers.dart' show glosarioProvider;
import '../../core/texto.dart';
import '../../core/voz/tts.dart';
import '../../tema.dart';
import '../../widgets/estados.dart';
import '../../widgets/iconos/iconos.dart';
import '../../widgets/justicia/cartel_sala.dart';
import 'escuchar.dart';
import 'fuentes_paso.dart';
import 'modelos.dart';
import 'palabras.dart';
import 'pasos_providers.dart';
import 'personajes_paso.dart';
import 'personalizacion_linea.dart';

// Línea de pasos de «Mi situación» (docs/ARQUITECTURA.md, sección 4.4): una línea vertical con un nodo por paso.
// Al tocar un paso se abre y enseña qué pasa, quién estará (con los personajes de «Vive el caso»), qué puedes pedir
// (como cartas que se apuntan en «Mis preguntas»), qué llevar, las palabras que oirás y de dónde sale. La fase en la
// que estás lleva la marca «Estás aquí». Cada paso se puede escuchar y llevar a Pregunta como duda ya escrita. Habla
// del proceso, nunca de lo que pasó, y no promete resultados. Todo el movimiento respeta «reducir animaciones».

/// Título del estado vacío.
const textoSinPasos = 'Todavía no tengo los pasos para este papel';

/// Textos de «Apuntar» (plan v2, producto §5.2). El botón dice «Apuntar» (o «Apuntado») con palabras: los textos de
/// Mi situación y Mis preguntas piden «Toca «Apuntar»…».
const etiquetaApuntar = 'Apuntar';
const etiquetaApuntado = 'Apuntado';
const tooltipApuntar = 'Apuntar en Mis preguntas';
const tooltipQuitarApunte = 'Quitar de Mis preguntas';
const textoApuntado = 'Apuntado en Mis preguntas';
const textoQuitadoApunte = 'Quitado de Mis preguntas';
const textoMaximoApuntes = 'Has llegado a 30. Quita alguna para apuntar más.';

/// Textos de «Escuchar este paso».
const tooltipEscuchar = 'Escuchar este paso';
const tooltipParar = 'Parar';

/// Botón que lleva el paso a Pregunta.
const textoPreguntaselo = 'Pregúntaselo a TuTurno';

/// Icono de cada fase (capa justicia, tema-justicia.md §7.9): la citación, la puerta de la sala y el reloj.
TuIcono iconoFase(Fase fase) => switch (fase) {
  Fase.antes => TuIcono.citacion,
  Fase.durante => TuIcono.puertaSala,
  Fase.despues => TuIcono.reloj,
};

const _tamNodo = 40.0;
const _grosorLinea = 3.0;

/// Alto mínimo de la cabecera de cada paso: zona táctil de sobra (48 px como mínimo).
const _altoCabecera = 56.0;

/// El nodo queda centrado con la primera línea de la cabecera del paso.
const _margenNodo = (_altoCabecera - _tamNodo) / 2;
const _centroNodo = _margenNodo + _tamNodo / 2;
const _izquierdaLinea = (_tamNodo - _grosorLinea) / 2;

/// Hueco a la izquierda de las tarjetas, donde van la línea y los nodos.
const _anchoGuia = _tamNodo + Espacio.m;
const _separacion = Espacio.s + Espacio.xs;

/// Retraso entre filas en la entrada escalonada.
const _escalonado = Duration(milliseconds: 80);

/// Línea de pasos de un papel, para «Mi situación».
///
/// - [rol]: 'testigo', 'victima', 'investigado', 'escuchado_familia'… Es el nombre del fichero
///   `itinerarios/<rol>.json` ([itinerarioProvider]).
/// - [faseActual]: la fase que se marca con «Estás aquí». Si es null, la del ticket ([entradaProvider]), pero solo si
///   allí no se eligió otro papel ([faseDeEntrada]).
/// - [encabezado]: el título «Tu camino, paso a paso» y una línea de ayuda encima de los pasos.
/// - [personalizacion]: lo que «Mi situación» sabe de quien la mira (lo que cambia para ti, qué llevar, con quién
///   irás, cómo prefieres que te lo cuente y «Pregúntaselo a TuTurno»). Sin ella, la línea general.
/// - [apuntar]: «Apuntar» junto a cada cosa que puedes pedir (en «Mis preguntas», misPreguntasProvider).
/// - [escuchar]: «Escuchar este paso» en cada tarjeta (ttsProvider, con la velocidad de Ajustes; uno a la vez, y se
///   para al salir, al tocar otro y al pasar a segundo plano).
///
/// No hace scroll por sí misma: va dentro de una pantalla con scroll (como el SingleChildScrollView de
/// SituacionScreen). Mientras carga, si no hay pasos o si falla, enseña Cargando, EstadoVacio o EstadoError.
class LineaPasos extends ConsumerWidget {
  const LineaPasos({
    super.key,
    required this.rol,
    this.faseActual,
    this.encabezado = true,
    this.personalizacion,
    this.apuntar = true,
    this.escuchar = true,
  });

  final String rol;
  final Fase? faseActual;
  final bool encabezado;
  final PersonalizacionLinea? personalizacion;
  final bool apuntar;
  final bool escuchar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(itinerarioProvider(rol));
    final fase = faseActual ?? ref.watch(entradaProvider.select((e) => faseDeEntrada(e, rol)));
    return AnimatedSwitcher(
      duration: duracion(context, Duracion.media),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (actual, anteriores) => Stack(alignment: Alignment.topCenter, children: [...anteriores, ?actual]),
      // skipLoadingOnRefresh: false: al pulsar «Reintentar» se ve que está cargando, y no se queda el mismo error.
      child: estado.when(
        skipLoadingOnRefresh: false,
        data: (itinerario) => itinerario == null || itinerario.pasos.isEmpty
            ? const EstadoVacio(
                key: ValueKey('vacio'),
                icono: Icons.route_rounded,
                tuIcono: TuIcono.miSituacion,
                titulo: textoSinPasos,
                mensaje:
                    'Los estoy preparando con cuidado. Mientras tanto, puedes preguntarme cómo funciona el proceso.',
              )
            : _Linea(
                key: ObjectKey(itinerario),
                itinerario: itinerario,
                faseActual: fase,
                encabezado: encabezado,
                personalizacion: personalizacion ?? const PersonalizacionLinea(),
                apuntar: apuntar,
                escuchar: escuchar,
              ),
        error: (_, _) => EstadoError(
          key: const ValueKey('error'),
          mensaje: 'No he podido cargar los pasos. Prueba otra vez en un momento.',
          onReintentar: () => ref.invalidate(itinerarioProvider(rol)),
        ),
        loading: () => const Cargando(key: ValueKey('cargando'), mensaje: 'Preparando tus pasos…'),
      ),
    );
  }
}

class _Linea extends ConsumerStatefulWidget {
  const _Linea({
    super.key,
    required this.itinerario,
    required this.faseActual,
    required this.encabezado,
    required this.personalizacion,
    required this.apuntar,
    required this.escuchar,
  });

  final Itinerario itinerario;
  final Fase? faseActual;
  final bool encabezado;
  final PersonalizacionLinea personalizacion;
  final bool apuntar;
  final bool escuchar;

  @override
  ConsumerState<_Linea> createState() => _LineaState();
}

class _LineaState extends ConsumerState<_Linea> with SingleTickerProviderStateMixin {
  late final AnimationController _entrada = AnimationController(vsync: this);
  final _abiertos = <int>{};
  Duration _base = Duration.zero;
  bool _preparada = false;

  /// La voz de la app (una para todas las pantallas), guardada al empezar: al cerrar la pantalla ya no se puede leer.
  late final Tts _tts = ref.read(ttsProvider);

  /// El paso que se está leyendo en voz alta (su id), si lo ha pedido esta línea.
  String? _leyendo;
  late final AppLifecycleListener _ciclo;

  /// Una fila por paso y otra por cada cambio de fase.
  late final int _filas = () {
    var filas = 0;
    Fase? anterior;
    for (final paso in widget.itinerario.pasos) {
      if (paso.fase != null && paso.fase != anterior) filas++;
      if (paso.fase != null) anterior = paso.fase;
      filas++;
    }
    return filas;
  }();

  @override
  void initState() {
    super.initState();
    _tts.hablando.addListener(_alCambiarVoz);
    _ciclo = AppLifecycleListener(onHide: _callar, onPause: _callar);
    // «Paso a paso»: se abre el primer paso de tu momento (o el primero), para empezar por ahí.
    if (widget.personalizacion.estilo == EstiloExplicacion.pasoAPaso) {
      final pasos = widget.itinerario.pasos;
      final suyo = pasos.indexWhere((p) => p.fase != null && p.fase == widget.faseActual);
      _abiertos.add(suyo >= 0 ? suyo : 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Si otra pantalla tapa esta (Pregunta, el Glosario…), la voz se calla: «se para al salir».
    if (!TickerMode.valuesOf(context).enabled) _callar();
    if (_preparada) return;
    _preparada = true;
    _base = duracion(context, Duracion.larga);
    if (_base == Duration.zero) {
      _entrada.value = 1;
      return;
    }
    _entrada.duration = _base + _escalonado * (_filas - 1);
    _entrada.forward();
  }

  @override
  void dispose() {
    _tts.hablando.removeListener(_alCambiarVoz);
    _ciclo.dispose();
    if (_leyendo != null) unawaited(_tts.parar().then<void>((_) {}, onError: (Object _) {}));
    _entrada.dispose();
    super.dispose();
  }

  /// La parte de la entrada que le toca a [fila]: cada fila empieza un poco después que la anterior.
  /// Con [desde], solo el final de esa parte (para el trazo que baja hasta el paso siguiente).
  Curve _tramo(int fila, {double desde = 0, Curve curva = Curves.easeOutCubic}) {
    final total = _entrada.duration?.inMicroseconds ?? 0;
    if (total == 0) return curva;
    final inicio = (_escalonado * fila).inMicroseconds / total;
    final fin = (_escalonado * fila + _base).inMicroseconds / total;
    return Interval(inicio + (fin - inicio) * desde, fin.clamp(0.0, 1.0), curve: curva);
  }

  void _alternar(int indice) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_abiertos.remove(indice)) _abiertos.add(indice);
    });
  }

  /// «Siguiente paso»: cierra este y abre el siguiente (que se desplaza solo hasta quedar a la vista).
  void _siguiente(int indice) {
    HapticFeedback.selectionClick();
    setState(() {
      _abiertos
        ..remove(indice)
        ..add(indice + 1);
    });
  }

  /// La voz ha terminado (o la ha parado otra pantalla): el botón vuelve a «Escuchar».
  void _alCambiarVoz() {
    if (!_tts.hablando.value && _leyendo != null && mounted) setState(() => _leyendo = null);
  }

  void _callar() {
    if (_leyendo == null) return;
    unawaited(_tts.parar().then<void>((_) {}, onError: (Object _) {}));
    if (mounted) setState(() => _leyendo = null);
  }

  /// Lee [paso] en voz alta; si ya se estaba leyendo, para. Leer otro corta el anterior (uno a la vez).
  void _escuchar(Paso paso) {
    if (_leyendo == paso.id) {
      _callar();
      return;
    }
    setState(() => _leyendo = paso.id);
    final texto = textoParaEscuchar(paso, extras: widget.personalizacion.extrasDe(paso));
    unawaited(_tts.hablar(texto).then<void>((_) {}, onError: (Object _) {}));
  }

  @override
  Widget build(BuildContext context) {
    final pasos = widget.itinerario.pasos;
    final hijos = <Widget>[
      if (widget.encabezado) _Aparecer(animacion: _entrada, tramo: _tramo(0), child: const _Encabezado()),
    ];
    var fila = 0;
    Fase? faseAnterior;
    var marcada = false;
    for (final (i, paso) in pasos.indexed) {
      final fase = paso.fase;
      if (fase != null && fase != faseAnterior) {
        // «Estás aquí» sale una sola vez, aunque la fase vuelva a aparecer más abajo.
        final actual = fase == widget.faseActual && !marcada;
        if (actual) marcada = true;
        hijos.add(
          _Aparecer(
            animacion: _entrada,
            tramo: _tramo(fila++),
            child: _CabeceraFase(fase: fase, actual: actual, lineaArriba: i > 0),
          ),
        );
      }
      if (fase != null) faseAnterior = fase;
      final siguiente = i < pasos.length - 1 ? pasos[i + 1] : null;
      hijos.add(
        _FilaPaso(
          paso: paso,
          numero: i + 1,
          total: pasos.length,
          actual: fase != null && fase == widget.faseActual,
          abierto: _abiertos.contains(i),
          lineaArriba: i > 0,
          lineaAbajo: i < pasos.length - 1,
          animacion: _entrada,
          tramo: _tramo(fila),
          tramoLinea: _tramo(fila, desde: 0.35, curva: Curves.easeInOutCubic),
          onAlternar: () => _alternar(i),
          detalles: _OpcionesPaso(
            extras: widget.personalizacion.extrasDe(paso),
            estilo: widget.personalizacion.estilo,
            conQuien: widget.personalizacion.conQuien,
            acompanantes: widget.personalizacion.acompanantes,
            apuntar: widget.apuntar,
            alPreguntar: widget.personalizacion.alPreguntar == null
                ? null
                : (duda) {
                    _callar();
                    widget.personalizacion.alPreguntar!(paso, duda);
                  },
            siguiente: widget.personalizacion.estilo == EstiloExplicacion.pasoAPaso && siguiente != null
                ? (nombre: siguiente.nombre, alPulsar: () => _siguiente(i))
                : null,
            alSalir: _callar,
          ),
          escuchar: widget.escuchar ? (leyendo: _leyendo == paso.id, alPulsar: () => _escuchar(paso)) : null,
        ),
      );
      fila++;
    }
    hijos.add(_Aparecer(animacion: _entrada, tramo: _tramo(fila - 1), child: const _NotaGuia()));
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: hijos);
  }
}

/// Lo que la línea pasa a cada paso para sus detalles.
@immutable
class _OpcionesPaso {
  const _OpcionesPaso({
    required this.extras,
    required this.estilo,
    required this.conQuien,
    required this.acompanantes,
    required this.apuntar,
    required this.alPreguntar,
    required this.siguiente,
    required this.alSalir,
  });

  final ExtrasPaso extras;
  final EstiloExplicacion? estilo;
  final String? conQuien;
  final Set<String> acompanantes;
  final bool apuntar;
  final ValueChanged<String>? alPreguntar;
  final ({String nombre, VoidCallback alPulsar})? siguiente;

  /// Antes de ir a otra pantalla (el Glosario, Mis preguntas): calla la voz.
  final VoidCallback alSalir;
}

class _Encabezado extends StatelessWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Espacio.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Tu camino, paso a paso',
              style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: Espacio.xs),
          Text(
            'Toca cada paso para ver qué pasa, quién estará y qué puedes pedir.',
            style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _NotaGuia extends StatelessWidget {
  const _NotaGuia();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = tema.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: Espacio.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconoTuTurno(
            TuIcono.info,
            estilo: EstiloIcono.mono,
            size: Espacio.l - Espacio.xs,
            color: color,
            decorativo: true,
          ),
          const SizedBox(width: Espacio.s),
          Expanded(
            child: Text(
              'Es una guía general: en tu caso puede haber pasos distintos o en otro orden.',
              style: tema.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// «Antes», «Durante» o «Después» sobre los pasos de esa fase, como el cartel de la puerta de una sala, con su icono
/// (la citación, la puerta de la sala y el reloj). La fase actual lleva «Estás aquí».
class _CabeceraFase extends StatelessWidget {
  const _CabeceraFase({required this.fase, required this.actual, required this.lineaArriba});

  final Fase fase;
  final bool actual;

  /// Si hay un paso antes: la línea pasa por detrás para unirlo con el siguiente.
  final bool lineaArriba;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        if (lineaArriba)
          const Positioned(left: _izquierdaLinea, top: 0, bottom: 0, width: _grosorLinea, child: _Trazo()),
        Padding(
          padding: EdgeInsets.only(left: _anchoGuia, top: lineaArriba ? Espacio.xs : 0, bottom: _separacion),
          child: Semantics(
            header: true,
            label: actual ? '${fase.etiqueta}. Estás aquí' : fase.etiqueta,
            excludeSemantics: true,
            child: Wrap(
              spacing: Espacio.s,
              runSpacing: Espacio.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CartelSala(texto: fase.etiqueta, icono: iconoFase(fase), inclinacion: actual ? -0.03 : -0.015),
                if (actual) const _MarcaEstasAqui(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Píldora «Estás aquí». Late un par de veces al aparecer y se queda quieta: señala sin distraer.
class _MarcaEstasAqui extends StatefulWidget {
  const _MarcaEstasAqui();

  @override
  State<_MarcaEstasAqui> createState() => _MarcaEstasAquiState();
}

class _MarcaEstasAquiState extends State<_MarcaEstasAqui> with SingleTickerProviderStateMixin {
  static const _periodo = Duration(milliseconds: 1600);
  static const _veces = 2;
  static const _crecimiento = 0.25;

  late final AnimationController _pulso = AnimationController(vsync: this, duration: _periodo);
  bool _yaLatio = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_yaLatio) return;
    _yaLatio = true;
    if (duracion(context, _periodo) != Duration.zero) _pulso.repeat(count: _veces);
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulso,
              builder: (context, _) {
                if (!_pulso.isAnimating) return const SizedBox.shrink();
                final t = Curves.easeOut.transform(_pulso.value);
                return Transform.scale(
                  scale: 1 + t * _crecimiento,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: StadiumBorder(
                        side: BorderSide(color: esquema.primary.withValues(alpha: (1 - t) * 0.6), width: 2),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        DecoratedBox(
          decoration: ShapeDecoration(color: esquema.primary, shape: const StadiumBorder()),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Espacio.s + Espacio.xs, vertical: Espacio.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.place_rounded, size: Espacio.m, color: esquema.onPrimary),
                const SizedBox(width: Espacio.xs),
                Flexible(
                  child: Text(
                    'Estás aquí',
                    style: tema.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: esquema.onPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Un paso: el nodo con su número sobre la línea y la tarjeta que se abre.
class _FilaPaso extends StatelessWidget {
  const _FilaPaso({
    required this.paso,
    required this.numero,
    required this.total,
    required this.actual,
    required this.abierto,
    required this.lineaArriba,
    required this.lineaAbajo,
    required this.animacion,
    required this.tramo,
    required this.tramoLinea,
    required this.onAlternar,
    required this.detalles,
    required this.escuchar,
  });

  final Paso paso;
  final int numero;
  final int total;

  /// Es de la fase en la que estás.
  final bool actual;
  final bool abierto;
  final bool lineaArriba;
  final bool lineaAbajo;
  final Animation<double> animacion;
  final Curve tramo;
  final Curve tramoLinea;
  final VoidCallback onAlternar;
  final _OpcionesPaso detalles;
  final ({bool leyendo, VoidCallback alPulsar})? escuchar;

  @override
  Widget build(BuildContext context) {
    return _Aparecer(
      animacion: animacion,
      tramo: tramo,
      // Los trazos van con top y bottom: miden lo mismo que la fila, también mientras la tarjeta se abre.
      child: Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          if (lineaArriba)
            const Positioned(left: _izquierdaLinea, top: 0, height: _centroNodo, width: _grosorLinea, child: _Trazo()),
          if (lineaAbajo)
            Positioned(
              left: _izquierdaLinea,
              top: _centroNodo,
              bottom: 0,
              width: _grosorLinea,
              child: _Trazo(animacion: animacion, tramo: tramoLinea),
            ),
          Padding(
            padding: EdgeInsets.only(left: _anchoGuia, bottom: lineaAbajo ? _separacion : 0),
            child: _TarjetaPaso(
              paso: paso,
              numero: numero,
              total: total,
              actual: actual,
              abierto: abierto,
              onAlternar: onAlternar,
              detalles: detalles,
              escuchar: escuchar,
            ),
          ),
          // Tocar el número también abre y cierra el paso: parece el sitio donde tocar. Para el lector de pantalla no
          // es otro botón (la acción ya la lleva la cabecera del paso).
          Positioned(
            left: 0,
            top: 0,
            width: _anchoGuia,
            height: _altoCabecera,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: onAlternar,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _Nodo(numero: numero, actual: actual, abierto: abierto),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Trozo de la línea. Con [animacion], se dibuja de arriba abajo durante [tramo].
class _Trazo extends StatelessWidget {
  const _Trazo({this.animacion, this.tramo});

  final Animation<double>? animacion;
  final Curve? tramo;

  @override
  Widget build(BuildContext context) {
    final trazo = DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(_grosorLinea / 2),
      ),
    );
    final animacion = this.animacion;
    final tramo = this.tramo;
    if (animacion == null || tramo == null) return trazo;
    return AnimatedBuilder(
      animation: animacion,
      builder: (context, child) =>
          Transform.scale(scaleY: tramo.transform(animacion.value), alignment: Alignment.topCenter, child: child),
      child: trazo,
    );
  }
}

class _Nodo extends StatelessWidget {
  const _Nodo({required this.numero, required this.actual, required this.abierto});

  final int numero;
  final bool actual;
  final bool abierto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    // Relleno opaco siempre: la línea pasa por detrás del nodo. Colores enteros del esquema y no tintes: un tinte
    // amarillo sobre el azul noche del tema oscuro sale grisáceo.
    final relleno = actual
        ? esquema.primary
        : abierto
        ? esquema.surfaceContainerHighest
        : esquema.surface;
    final tinta = actual
        ? esquema.onPrimary
        : abierto
        ? esquema.primary
        : esquema.onSurface;
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: duracion(context, Duracion.media),
        curve: Curves.easeOutCubic,
        width: _tamNodo,
        height: _tamNodo,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: relleno,
          border: Border.all(color: actual || abierto ? esquema.primary : esquema.outline, width: 2),
          // Brillo suave en los pasos de la fase actual.
          boxShadow: [
            BoxShadow(
              color: esquema.primary.withValues(alpha: actual ? 0.4 : 0),
              blurRadius: actual ? Espacio.m : 0,
              spreadRadius: actual ? 1 : 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(Espacio.xs),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('$numero', style: estiloCifras(tema.textTheme.labelLarge)?.copyWith(color: tinta)),
          ),
        ),
      ),
    );
  }
}

/// «Paso 2 de 6: Llegas al juzgado. Estás en esta parte. Puedes pedir 2 cosas».
String _etiquetaPaso(Paso paso, {required int numero, required int total, required bool actual, String? noEsParaTi}) {
  final partes = ['Paso $numero de $total: ${paso.nombre}'];
  if (actual) partes.add('Estás en esta parte');
  if (noEsParaTi != null) partes.add(noEsParaTi);
  final pedir = _textoPedir(paso.quePuedesPedir.length);
  if (pedir != null) partes.add(pedir);
  return partes.join('. ');
}

String? _textoPedir(int cuantas) => switch (cuantas) {
  0 => null,
  1 => 'Puedes pedir una cosa',
  _ => 'Puedes pedir $cuantas cosas',
};

class _TarjetaPaso extends StatelessWidget {
  const _TarjetaPaso({
    required this.paso,
    required this.numero,
    required this.total,
    required this.actual,
    required this.abierto,
    required this.onAlternar,
    required this.detalles,
    required this.escuchar,
  });

  final Paso paso;
  final int numero;
  final int total;
  final bool actual;
  final bool abierto;
  final VoidCallback onAlternar;
  final _OpcionesPaso detalles;
  final ({bool leyendo, VoidCallback alPulsar})? escuchar;

  /// Al abrir un paso, lo deja a la vista. Va después del frame, cuando la tarjeta ya tiene su tamaño nuevo.
  void _mostrarEntera(BuildContext context) =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _desplazarHastaVerla(context));

  /// - Si la tarjeta abierta cabe en la pantalla, se desplaza lo justo para verla entera (si ya se ve, no se mueve).
  /// - Si no cabe (lo normal con los pasos de verdad), se lee desde arriba: si la cabecera ha quedado en la mitad de
  ///   abajo de la pantalla, o se sale por arriba, la tarjeta sube hasta arriba. Si está en la mitad de arriba, ya se
  ///   ve buena parte del paso y no se mueve.
  void _desplazarHastaVerla(BuildContext context) {
    if (!context.mounted) return;
    final caja = context.findRenderObject();
    final posicion = Scrollable.maybeOf(context)?.position;
    final viewport = RenderAbstractViewport.maybeOf(caja);
    if (caja is! RenderBox || !caja.hasSize || posicion == null || viewport == null) return;
    final movimiento = duracion(context, Duracion.media);
    if (caja.size.height <= posicion.viewportDimension) {
      Scrollable.ensureVisible(
        context,
        duration: movimiento,
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      return;
    }
    // Distancia desde arriba de la pantalla hasta arriba de la tarjeta.
    final arriba = viewport.getOffsetToReveal(caja, 0).offset - posicion.pixels;
    if (arriba >= 0 && arriba <= posicion.viewportDimension / 2) return;
    Scrollable.ensureVisible(
      context,
      duration: movimiento,
      curve: Curves.easeOutCubic,
      alignment: 0,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final forma = BorderRadius.circular(Radios.m);
    final pedir = _textoPedir(paso.quePuedesPedir.length);
    final animacion = duracion(context, Duracion.media);
    final noEsParaTi = detalles.extras.noEsParaTi;
    final escuchar = this.escuchar;

    // La fase actual, en el contenedor más marcado del esquema (azul claro o azul noche más claro); abierto, como un
    // papel levantado con el borde del color principal.
    final fondo = actual ? esquema.surfaceContainerHighest : esquema.surfaceContainerLow;
    final borde = abierto
        ? esquema.primary
        : actual
        ? esquema.primary.withValues(alpha: 0.6)
        : esquema.outlineVariant;
    return AnimatedContainer(
      duration: animacion,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: forma,
        // Siempre del mismo grosor: el borde mete el contenido hacia dentro y, si cambiara, lo movería.
        border: Border.all(color: borde, width: 1.5),
        boxShadow: abierto ? sombrasPapel(context) : const [],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Semantics(
                    container: true,
                    button: true,
                    expanded: abierto,
                    label: _etiquetaPaso(paso, numero: numero, total: total, actual: actual, noEsParaTi: noEsParaTi),
                    onTapHint: abierto ? 'cerrar el paso' : 'ver qué pasa en este paso',
                    excludeSemantics: true,
                    onTap: onAlternar,
                    child: InkWell(
                      onTap: onAlternar,
                      borderRadius: forma,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: _altoCabecera),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            Espacio.m,
                            _separacion,
                            escuchar == null ? Espacio.s : 0,
                            _separacion,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      paso.nombre,
                                      style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    if (pedir != null) ...[
                                      const SizedBox(height: Espacio.xs),
                                      Row(
                                        children: [
                                          IconoTuTurno(
                                            TuIcono.manoAlzada,
                                            estilo: EstiloIcono.mono,
                                            size: Espacio.m + 2,
                                            color: colorPedir(context),
                                            decorativo: true,
                                          ),
                                          const SizedBox(width: Espacio.xs),
                                          Flexible(
                                            child: Text(
                                              pedir,
                                              style: tema.textTheme.bodyMedium?.copyWith(
                                                color: esquema.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (noEsParaTi != null) ...[
                                      const SizedBox(height: Espacio.xs),
                                      Text(
                                        noEsParaTi,
                                        style: tema.textTheme.bodyMedium?.copyWith(
                                          color: esquema.onSurfaceVariant,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: Espacio.s),
                              AnimatedRotation(
                                turns: abierto ? 0.5 : 0,
                                duration: animacion,
                                curve: Curves.easeOutCubic,
                                child: Icon(Icons.expand_more_rounded, color: esquema.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (escuchar != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Espacio.xs, right: Espacio.xs),
                    child: _BotonEscuchar(leyendo: escuchar.leyendo, alPulsar: escuchar.alPulsar),
                  ),
              ],
            ),
            _Desplegable(
              abierto: abierto,
              duracion: animacion,
              onAbierto: () => _mostrarEntera(context),
              child: _DetallesPaso(paso: paso, opciones: detalles),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Escuchar este paso» / «Parar», con el altavoz de TuTurno. 48 px.
class _BotonEscuchar extends StatelessWidget {
  const _BotonEscuchar({required this.leyendo, required this.alPulsar});

  final bool leyendo;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: leyendo ? tooltipParar : tooltipEscuchar,
      isSelected: leyendo,
      onPressed: alPulsar,
      style: IconButton.styleFrom(
        backgroundColor: leyendo ? esquema.primaryContainer : null,
        minimumSize: const Size.square(Espacio.xxl),
      ),
      icon: IconoTuTurno(
        leyendo ? TuIcono.silencio : TuIcono.altavoz,
        estilo: EstiloIcono.mono,
        color: leyendo ? esquema.onPrimaryContainer : esquema.primary,
        decorativo: true,
      ),
    );
  }
}

/// Lo de dentro de un paso: se despliega al abrirlo y se recoge al cerrarlo, de arriba abajo.
///
/// - Mientras se recoge, el contenido sigue ahí (recortado y fuera del lector de pantalla), para que no quede una
///   tarjeta vacía encogiéndose. Al terminar, se quita.
/// - [onAbierto] llega una vez por cada apertura, cuando ya está abierto del todo. Un cambio de tamaño de la ventana
///   (girar el móvil, el zoom del navegador) no lo repite: AnimatedAlign solo anima cuando se abre o se cierra.
/// - Con «reducir animaciones», se abre y se cierra al momento, sin AnimatedAlign.
class _Desplegable extends StatefulWidget {
  const _Desplegable({required this.abierto, required this.duracion, required this.onAbierto, required this.child});

  final bool abierto;
  final Duration duracion;
  final VoidCallback onAbierto;
  final Widget child;

  @override
  State<_Desplegable> createState() => _DesplegableState();
}

class _DesplegableState extends State<_Desplegable> {
  /// El contenido está montado: abierto, o recogiéndose.
  late bool _montado = widget.abierto;

  @override
  void didUpdateWidget(_Desplegable anterior) {
    super.didUpdateWidget(anterior);
    if (widget.abierto) {
      _montado = true;
      // Sin animación no hay onEnd: se avisa ya (onAbierto espera al final del frame, con el paso abierto).
      if (!anterior.abierto && widget.duracion == Duration.zero) widget.onAbierto();
    } else if (widget.duracion == Duration.zero) {
      _montado = false;
    }
  }

  void _alTerminar() {
    if (!mounted) return;
    if (widget.abierto) {
      widget.onAbierto();
    } else if (_montado) {
      setState(() => _montado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const cerrado = SizedBox(width: double.infinity);
    if (widget.duracion == Duration.zero) return widget.abierto ? widget.child : cerrado;
    return ClipRect(
      child: AnimatedAlign(
        alignment: Alignment.topCenter,
        heightFactor: widget.abierto ? 1 : 0,
        duration: widget.duracion,
        curve: Curves.easeOutCubic,
        onEnd: _alTerminar,
        child: _montado ? ExcludeSemantics(excluding: !widget.abierto, child: widget.child) : cerrado,
      ),
    );
  }
}

class _DetallesPaso extends ConsumerWidget {
  const _DetallesPaso({required this.paso, required this.opciones});

  final Paso paso;
  final _OpcionesPaso opciones;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final extras = opciones.extras;
    final citas = CitaPaso.de(paso.fuentes);
    final glosario = ref.watch(glosarioProvider).value ?? const [];
    final palabras = palabrasDelPaso(
      paso,
      glosario: [for (final entrada in glosario) entrada.termino],
      pedidas: extras.palabras,
    );
    final conQuien = opciones.conQuien;
    final ejemplo = extras.ejemplo;
    final siguiente = opciones.siguiente;
    final alPreguntar = opciones.alPreguntar;
    final secciones = [
      if (extras.paraTi.isNotEmpty) _ParaTi(notas: extras.paraTi, paso: paso.nombre),
      if (paso.quePasa.isNotEmpty)
        _Seccion(
          tuIcono: TuIcono.info,
          titulo: 'Qué pasa',
          child: opciones.estilo == EstiloExplicacion.corto
              ? TextoCorto(texto: paso.quePasa)
              : Text(paso.quePasa, style: tema.textTheme.bodyLarge),
        ),
      if (opciones.estilo == EstiloExplicacion.ejemplos && ejemplo != null) _Ejemplo(texto: ejemplo),
      if (paso.quienEsta.isNotEmpty || (extras.esCita && conQuien != null))
        _Seccion(
          tuIcono: TuIcono.personaConfianza,
          titulo: 'Quién estará',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (extras.esCita && conQuien != null) _IrasCon(conQuien: conQuien),
              for (final persona in paso.quienEsta)
                _Persona(nombre: persona, enSala: extras.enSala, acompanantes: opciones.acompanantes),
            ],
          ),
        ),
      if (paso.quePuedesPedir.isNotEmpty)
        _Seccion(
          tuIcono: TuIcono.manoAlzada,
          titulo: 'Puedes pedir',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final cosa in paso.quePuedesPedir)
                Padding(
                  padding: const EdgeInsets.only(bottom: Espacio.s),
                  child: _CartaPedir(texto: cosa, paso: paso, apuntar: opciones.apuntar, alSalir: opciones.alSalir),
                ),
            ],
          ),
        ),
      if (extras.llevar.isNotEmpty)
        _Seccion(
          tuIcono: TuIcono.ticket,
          titulo: 'Qué llevar',
          child: _QueLlevar(cosas: extras.llevar),
        ),
      if (palabras.isNotEmpty)
        _Seccion(
          tuIcono: TuIcono.glosario,
          titulo: 'Palabras que oirás',
          child: _Palabras(palabras: palabras, alSalir: opciones.alSalir),
        ),
      if (citas.isNotEmpty)
        _Seccion(
          tuIcono: TuIcono.ley,
          titulo: 'De dónde sale',
          child: Wrap(
            spacing: Espacio.s,
            children: [for (final cita in citas) ChipFuentePaso(cita: cita, paso: paso.nombre)],
          ),
        ),
      if (alPreguntar != null) _Preguntaselo(duda: extras.duda ?? dudaPorDefecto(paso), alPreguntar: alPreguntar),
      if (siguiente != null)
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: siguiente.alPulsar,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_downward_rounded),
            label: Text('Siguiente paso: ${siguiente.nombre}'),
          ),
        ),
    ];
    return _AparecerSuave(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Espacio.m, 0, Espacio.m, Espacio.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            for (final seccion in secciones)
              Padding(
                padding: const EdgeInsets.only(top: Espacio.m),
                child: seccion,
              ),
          ],
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.tuIcono, required this.titulo, required this.child});

  final TuIcono tuIcono;
  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Row(
            children: [
              IconoTuTurno(
                tuIcono,
                estilo: EstiloIcono.mono,
                size: Espacio.m + Espacio.xs / 2,
                color: esquema.primary,
                decorativo: true,
              ),
              const SizedBox(width: Espacio.s),
              Flexible(
                child: Text(
                  titulo,
                  style: tema.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: esquema.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Espacio.s),
        child,
      ],
    );
  }
}

/// La primera frase de [texto] (para «Corto»). Si solo tiene una, el texto entero.
String primeraFrase(String texto) {
  final corte = RegExp(r'(?<=[.!?])\s+(?=[A-ZÁÉÍÓÚÑ¿¡«])').firstMatch(texto);
  return corte == null ? texto : texto.substring(0, corte.start);
}

/// En corto (estilo «Corto»): la primera frase y «Leer todo», que despliega el resto. Lo usan «Qué pasa» de cada paso
/// y las cartas de «Tus derechos».
class TextoCorto extends StatefulWidget {
  const TextoCorto({super.key, required this.texto, this.estilo});

  final String texto;

  /// Por defecto, bodyLarge.
  final TextStyle? estilo;

  @override
  State<TextoCorto> createState() => _TextoCortoState();
}

class _TextoCortoState extends State<TextoCorto> {
  var _entero = false;

  @override
  Widget build(BuildContext context) {
    final estilo = widget.estilo ?? Theme.of(context).textTheme.bodyLarge;
    final corta = primeraFrase(widget.texto);
    if (_entero || corta == widget.texto) return Text(widget.texto, style: estilo);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(corta, style: estilo),
        TextButton(onPressed: () => setState(() => _entero = true), child: const Text('Leer todo')),
      ],
    );
  }
}

/// Lo que cambia para ti en este paso (por tu edad o tu ticket), en una nota amarilla con sus fuentes.
class _ParaTi extends StatelessWidget {
  const _ParaTi({required this.notas, required this.paso});

  final List<NotaParaTi> notas;
  final String paso;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final tinta = esquema.onTertiaryContainer;
    return DecoratedBox(
      decoration: BoxDecoration(color: esquema.tertiaryContainer, borderRadius: BorderRadius.circular(Radios.s)),
      child: Padding(
        padding: const EdgeInsets.all(Espacio.s + Espacio.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Row(
                children: [
                  IconoTuTurno(TuIcono.estrella, size: Espacio.l - Espacio.xs, decorativo: true),
                  const SizedBox(width: Espacio.s),
                  Text(
                    'Para ti',
                    style: tema.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: tinta),
                  ),
                ],
              ),
            ),
            for (final nota in notas) ...[
              const SizedBox(height: Espacio.s),
              Text(nota.texto, style: tema.textTheme.bodyLarge?.copyWith(color: tinta)),
              if (nota.fuentes.isNotEmpty)
                Wrap(
                  spacing: Espacio.s,
                  children: [for (final cita in CitaPaso.de(nota.fuentes)) ChipFuentePaso(cita: cita, paso: paso)],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// «Por ejemplo»: un momento de «Vive el caso» parecido a este paso.
class _Ejemplo extends StatelessWidget {
  const _Ejemplo({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tinte(context, esquema.primary),
        borderRadius: BorderRadius.circular(Radios.s),
        border: Border.all(color: bordeTinte(esquema.primary)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Espacio.s + Espacio.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconoTuTurno(TuIcono.juego, size: Espacio.l, decorativo: true),
            const SizedBox(width: Espacio.s),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Por ejemplo: ',
                      style: TextStyle(fontWeight: FontWeight.w800, color: esquema.onSurface),
                    ),
                    TextSpan(text: texto),
                  ],
                ),
                style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Tú irás con…»: lo que dijo en su ticket, en los pasos de una cita.
class _IrasCon extends StatelessWidget {
  const _IrasCon({required this.conQuien});

  final String conQuien;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Espacio.s),
      child: DecoratedBox(
        decoration: BoxDecoration(color: esquema.secondaryContainer, borderRadius: BorderRadius.circular(Radios.s)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Espacio.s + Espacio.xs, vertical: Espacio.s),
          child: Row(
            children: [
              const IconoTuTurno(TuIcono.personaConfianza, size: Espacio.l + Espacio.xs, decorativo: true),
              const SizedBox(width: Espacio.s + Espacio.xs),
              Expanded(
                child: Text(
                  'Tú irás con $conQuien',
                  style: tema.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: esquema.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Persona extends StatelessWidget {
  const _Persona({required this.nombre, required this.enSala, this.acompanantes = const {}});

  final String nombre;
  final bool enSala;

  /// Con quién irá ([PersonalizacionLinea.acompanantes]).
  final Set<String> acompanantes;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = tema.colorScheme.secondary;
    final personaje = personajeDePersona(nombre, enSala: enSala, acompanantes: acompanantes);
    return Padding(
      padding: const EdgeInsets.only(bottom: Espacio.s),
      // Arriba: si el nombre ocupa varias líneas, el dibujo va con la primera.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (personaje != null)
            // El personaje de «Vive el caso» con el icono de quién es en la esquina (la toga, la ley…).
            ExcludeSemantics(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  RetratoPersonaje(id: personaje.id, tamano: Espacio.xl + Espacio.s),
                  PositionedDirectional(
                    end: -Espacio.xs - 2,
                    bottom: -Espacio.xs - 2,
                    child: Container(
                      width: Espacio.l - 2,
                      height: Espacio.l - 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tema.colorScheme.surface,
                        border: Border.all(color: tema.colorScheme.outlineVariant),
                      ),
                      alignment: Alignment.center,
                      child: IconoTuTurno(
                        iconoPersona(nombre),
                        estilo: EstiloIcono.mono,
                        size: Espacio.m - 2,
                        color: color,
                        decorativo: true,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ExcludeSemantics(
              child: Container(
                width: Espacio.xl + Espacio.s,
                height: Espacio.xl + Espacio.s,
                decoration: BoxDecoration(shape: BoxShape.circle, color: tinte(context, color)),
                child: IconoTuTurno(
                  iconoPersona(nombre),
                  estilo: EstiloIcono.mono,
                  size: Espacio.m + Espacio.xs,
                  color: color,
                  decorativo: true,
                ),
              ),
            ),
          const SizedBox(width: Espacio.s + Espacio.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: tema.textTheme.bodyLarge),
                if (personaje != null)
                  Text(
                    personaje.como,
                    style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Palabras (sin tildes) que dicen quién es cada persona, con su icono de TuTurno. Justicia de verdad: la jueza o el
/// juez llevan la toga, la Fiscalía la ley y la policía el escudo; nunca un mazo ni la balanza como icono de persona.
const _iconosPersona = <(TuIcono, List<String>)>[
  (TuIcono.idea, ['psicolog', 'psicosocial']),
  (TuIcono.toga, ['juez', 'jueza', 'tribunal']),
  (TuIcono.ley, ['fiscal']),
  (TuIcono.expediente, ['abogad', 'letrad', 'defensor']),
  (TuIcono.escudo, ['polic', 'guardia civil', 'agente']),
  (TuIcono.personaConfianza, ['familia', 'madre', 'padre', 'confianza', 'represent', 'tutor legal', 'abuel', 'herman']),
  (TuIcono.ayuda, ['trabajador', 'social', 'educador']),
  (TuIcono.aprende, ['tutor', 'profe', 'colegio', 'instituto', 'coordinador']),
];

/// Icono de quien está en un paso, según quién es. Manda la palabra que sale antes, que suele ser de quién se habla:
/// en «Quien te represente y una persona de confianza, salvo que el juez…», es «represente» y no «juez». Si dos
/// empiezan en el mismo sitio («tutor legal» y «tutor»), gana la que va antes en [_iconosPersona].
TuIcono iconoPersona(String persona) {
  final clave = normalizar(persona);
  var icono = TuIcono.miSituacion;
  int? primera;
  for (final (candidato, palabras) in _iconosPersona) {
    for (final palabra in palabras) {
      final posicion = clave.indexOf(palabra);
      if (posicion >= 0 && (primera == null || posicion < primera)) {
        primera = posicion;
        icono = candidato;
      }
    }
  }
  return icono;
}

/// Color de las marcas de «Puedes pedir»: el de acierto del tema (verde azulado, AA en los dos temas). Si el tema no
/// trae [ColoresTuTurno], el principal.
Color colorPedir(BuildContext context) {
  final tema = Theme.of(context);
  return tema.extension<ColoresTuTurno>()?.exito ?? tema.colorScheme.primary;
}

/// Algo que puedes pedir en un paso, como una carta de derecho: la mano alzada, el texto entero (puede ocupar varias
/// líneas) y, a la derecha, «Apuntar» en «Mis preguntas» (se desmarca al volver a tocarlo).
class _CartaPedir extends StatelessWidget {
  const _CartaPedir({required this.texto, required this.paso, required this.apuntar, required this.alSalir});

  final String texto;
  final Paso paso;
  final bool apuntar;
  final VoidCallback alSalir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final color = colorPedir(context);
    final esquinas = BorderRadius.circular(Radios.s / 2);
    // La carta: papel con borde fino y, a la izquierda, una franja del color de «puedes pedir» (como el canto de una
    // carta de derecho). La franja va dentro, recortada a las esquinas: un borde de colores distintos no admite radio.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        border: Border.all(color: esquema.outlineVariant),
        borderRadius: esquinas,
        boxShadow: [BoxShadow(color: sombraPapelDe(context), offset: const Offset(0, 1.5))],
      ),
      child: ClipRRect(
        borderRadius: esquinas,
        child: Stack(
          children: [
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: Espacio.xs,
              child: ColoredBox(color: color),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(Espacio.m, Espacio.xs, apuntar ? 0 : Espacio.s, Espacio.xs),
              child: _contenidoCarta(context, color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contenidoCarta(BuildContext context, Color color) {
    final tema = Theme.of(context);
    // Todo arriba: con un texto largo, el icono y «Apuntar» se quedan con la primera línea.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Espacio.s + Espacio.xs),
          child: IconoTuTurno(
            TuIcono.manoAlzada,
            estilo: EstiloIcono.mono,
            size: Espacio.l - 2,
            color: color,
            decorativo: true,
          ),
        ),
        const SizedBox(width: Espacio.s),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Espacio.s + Espacio.xs),
            child: Text(
              texto,
              style: tema.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: tema.colorScheme.onSurface,
              ),
            ),
          ),
        ),
        if (apuntar) BotonApuntar(texto: texto, origen: paso.nombre, fuentes: paso.fuentes, alSalir: alSalir),
      ],
    );
  }
}

/// «Apuntar» (o «Quitar») [texto] en «Mis preguntas», con de dónde viene ([origen]: el nombre del paso o «Tus
/// derechos») y sus [fuentes]. Con la palabra a la vista («Apuntar» / «Apuntado»: un ⊕ solo no se entiende con 11
/// años) y 48 px. Al apuntar, el SnackBar «Apuntado en Mis preguntas» con «Ver». Lo que se apunta desde un paso o un
/// derecho es «Quiero pedir» ([TipoApunte.pedir]); una idea de pregunta, «Quiero preguntar».
class BotonApuntar extends ConsumerWidget {
  const BotonApuntar({
    super.key,
    required this.texto,
    this.origen,
    this.fuentes = const [],
    this.tipo = TipoApunte.pedir,
    this.alSalir,
  });

  final String texto;
  final String? origen;
  final List<String> fuentes;
  final TipoApunte tipo;

  /// Antes de ir a «Mis preguntas» con «Ver».
  final VoidCallback? alSalir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clave = normalizar(limpiarApunte(texto));
    final apuntado = ref.watch(
      misPreguntasProvider.select((apuntes) => apuntes.any((a) => normalizar(limpiarApunte(a.texto)) == clave)),
    );
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    // La palabra debajo del icono: cabe en las filas estrechas (320 px con la letra a 1,3) sin quitarle sitio al texto.
    return Tooltip(
      message: apuntado ? tooltipQuitarApunte : tooltipApuntar,
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(Espacio.xxl, Espacio.xxl),
          padding: const EdgeInsets.symmetric(horizontal: Espacio.xs, vertical: Espacio.xs),
          tapTargetSize: MaterialTapTargetSize.padded,
          textStyle: tema.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        onPressed: () => _alternar(context, ref, apuntado),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (apuntado)
              IconoTuTurno(TuIcono.check, estilo: EstiloIcono.mono, color: colorPedir(context), decorativo: true)
            else
              Icon(Icons.add_circle_outline_rounded, color: esquema.primary),
            Text(apuntado ? etiquetaApuntado : etiquetaApuntar, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _alternar(BuildContext context, WidgetRef ref, bool apuntado) {
    final notas = ref.read(misPreguntasProvider.notifier);
    final mensajes = ScaffoldMessenger.maybeOf(context);
    final router = GoRouter.maybeOf(context);
    HapticFeedback.selectionClick();
    if (apuntado) {
      notas.quitarTexto(texto);
      mensajes
        ?..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(textoQuitadoApunte)));
      return;
    }
    final ok = notas.apuntar(texto, tipo: tipo, origen: origen, fuentes: fuentes);
    mensajes?.hideCurrentSnackBar();
    if (!ok) {
      mensajes?.showSnackBar(const SnackBar(content: Text(textoMaximoApuntes)));
      return;
    }
    mensajes?.showSnackBar(
      SnackBar(
        content: const Text(textoApuntado),
        action: router == null
            ? null
            : SnackBarAction(
                label: 'Ver',
                onPressed: () {
                  alSalir?.call();
                  router.push('/mis-preguntas');
                },
              ),
      ),
    );
  }
}

/// «Qué llevar»: consejos prácticos para el día de la cita.
class _QueLlevar extends StatelessWidget {
  const _QueLlevar({required this.cosas});

  final List<CosaQueLlevar> cosas;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final cosa in cosas)
          Padding(
            padding: const EdgeInsets.only(bottom: Espacio.xs + 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: IconoTuTurno(
                    TuIcono.check,
                    estilo: EstiloIcono.mono,
                    size: Espacio.m + 2,
                    color: colorPedir(context),
                    decorativo: true,
                  ),
                ),
                const SizedBox(width: Espacio.s),
                Expanded(child: Text(cosa.texto, style: tema.textTheme.bodyLarge)),
              ],
            ),
          ),
        Text(
          'Son consejos para ese día, no obligaciones.',
          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// «Palabras que oirás»: cada una abre su ficha del Glosario.
class _Palabras extends StatelessWidget {
  const _Palabras({required this.palabras, required this.alSalir});

  final List<String> palabras;
  final VoidCallback alSalir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Wrap(
      spacing: Espacio.s,
      runSpacing: Espacio.xs,
      children: [
        for (final palabra in palabras)
          Semantics(
            button: true,
            label: 'Palabra: $palabra',
            onTapHint: 'ver qué significa en el Glosario',
            excludeSemantics: true,
            child: ActionChip(
              avatar: IconoTuTurno(
                TuIcono.glosario,
                estilo: EstiloIcono.mono,
                color: esquema.primary,
                decorativo: true,
              ),
              label: Text(palabra),
              labelStyle: tema.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: esquema.onSurface),
              materialTapTargetSize: MaterialTapTargetSize.padded,
              backgroundColor: esquema.surfaceContainerLowest,
              side: BorderSide(color: esquema.outlineVariant),
              onPressed: () {
                HapticFeedback.selectionClick();
                final router = GoRouter.maybeOf(context);
                if (router == null) return;
                alSalir();
                router.push(Uri(path: '/glosario', queryParameters: {'q': palabra}).toString());
              },
            ),
          ),
      ],
    );
  }
}

/// «Pregúntaselo a TuTurno»: la duda que irá escrita a Pregunta y el botón. No se envía sola.
class _Preguntaselo extends StatelessWidget {
  const _Preguntaselo({required this.duda, required this.alPreguntar});

  final String duda;
  final ValueChanged<String> alPreguntar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radios.s),
        border: Border.all(color: esquema.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Espacio.s + Espacio.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '¿Te queda una duda? Llévala a Pregunta, ya escrita:',
              style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
            ),
            const SizedBox(height: Espacio.xs),
            Text('«$duda»', style: tema.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: Espacio.s),
            OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                alPreguntar(duda);
              },
              icon: const IconoTuTurno(TuIcono.pregunta, estilo: EstiloIcono.mono, decorativo: true),
              label: const Text(textoPreguntaselo),
            ),
          ],
        ),
      ),
    );
  }
}

/// Entrada escalonada de una fila: fundido y un pequeño desplazamiento hacia arriba durante [tramo].
class _Aparecer extends StatelessWidget {
  const _Aparecer({required this.animacion, required this.tramo, required this.child});

  final Animation<double> animacion;
  final Curve tramo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animacion,
      builder: (context, child) {
        final t = tramo.transform(animacion.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * Espacio.m), child: child),
        );
      },
      child: child,
    );
  }
}

/// Fundido suave al abrir un paso.
class _AparecerSuave extends StatelessWidget {
  const _AparecerSuave({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duracion(context, Duracion.media),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: child,
    );
  }
}
