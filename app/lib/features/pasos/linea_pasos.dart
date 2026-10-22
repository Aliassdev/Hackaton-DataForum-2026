import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entrada.dart' show Fase, entradaProvider;
import '../../core/texto.dart';
import '../../tema.dart';
import '../../widgets/estados.dart';
import '../../widgets/iconos/iconos.dart';
import 'fuentes_paso.dart';
import 'modelos.dart';
import 'pasos_providers.dart';

// Línea de pasos de «Mi situación» (docs/ARQUITECTURA.md, sección 4.4): una línea vertical con un nodo por paso.
// Al tocar un paso se abre y enseña qué pasa, quién estará, qué puedes pedir y de dónde sale. La fase en la que
// estás (formulario de entrada) lleva la marca «Estás aquí». Habla del proceso, nunca de lo que pasó, y no promete
// resultados. Todo el movimiento respeta la opción de reducir animaciones (duracion()).

/// Título del estado vacío.
const textoSinPasos = 'Todavía no tengo los pasos para este papel';

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
/// - [rol]: 'testigo', 'victima', 'investigado'… Es el nombre del fichero `itinerarios/<rol>.json`
///   ([itinerarioProvider]).
/// - [faseActual]: la fase que se marca con «Estás aquí». Si es null, la del formulario de entrada
///   ([entradaProvider]), pero solo si allí no se eligió otro papel ([faseDeEntrada]).
/// - [encabezado]: el título «Tu camino, paso a paso» y una línea de ayuda encima de los pasos.
///
/// No hace scroll por sí misma: va dentro de una pantalla con scroll (como el SingleChildScrollView de
/// SituacionScreen). Mientras carga, si no hay pasos o si falla, enseña Cargando, EstadoVacio o EstadoError.
class LineaPasos extends ConsumerWidget {
  const LineaPasos({super.key, required this.rol, this.faseActual, this.encabezado = true});

  final String rol;
  final Fase? faseActual;
  final bool encabezado;

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
                titulo: textoSinPasos,
                mensaje:
                    'Los estoy preparando con cuidado. Mientras tanto, puedes preguntarme cómo funciona el proceso.',
              )
            : _Linea(key: ObjectKey(itinerario), itinerario: itinerario, faseActual: fase, encabezado: encabezado),
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

class _Linea extends StatefulWidget {
  const _Linea({super.key, required this.itinerario, required this.faseActual, required this.encabezado});

  final Itinerario itinerario;
  final Fase? faseActual;
  final bool encabezado;

  @override
  State<_Linea> createState() => _LineaState();
}

class _LineaState extends State<_Linea> with SingleTickerProviderStateMixin {
  late final AnimationController _entrada = AnimationController(vsync: this);
  final _abiertos = <int>{};
  Duration _base = Duration.zero;
  bool _preparada = false;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
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
        ),
      );
      fila++;
    }
    hijos.add(_Aparecer(animacion: _entrada, tramo: _tramo(fila - 1), child: const _NotaGuia()));
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: hijos);
  }
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
          ExcludeSemantics(
            child: Icon(Icons.info_outline_rounded, size: Espacio.l - Espacio.xs, color: color),
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

/// «Antes», «Durante» o «Después», sobre los pasos de esa fase. La fase actual lleva «Estás aquí».
class _CabeceraFase extends StatelessWidget {
  const _CabeceraFase({required this.fase, required this.actual, required this.lineaArriba});

  final Fase fase;
  final bool actual;

  /// Si hay un paso antes: la línea pasa por detrás para unirlo con el siguiente.
  final bool lineaArriba;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
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
                Text(
                  fase.etiqueta,
                  style: tema.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: actual ? esquema.primary : esquema.onSurfaceVariant,
                  ),
                ),
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
            child: Text(
              '$numero',
              style: tema.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: tinta),
            ),
          ),
        ),
      ),
    );
  }
}

/// «Paso 2 de 6: Llegas al juzgado. Estás en esta parte. Puedes pedir 2 cosas».
String _etiquetaPaso(Paso paso, {required int numero, required int total, required bool actual}) {
  final partes = ['Paso $numero de $total: ${paso.nombre}'];
  if (actual) partes.add('Estás en esta parte');
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
  });

  final Paso paso;
  final int numero;
  final int total;
  final bool actual;
  final bool abierto;
  final VoidCallback onAlternar;

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
            Semantics(
              container: true,
              button: true,
              expanded: abierto,
              label: _etiquetaPaso(paso, numero: numero, total: total, actual: actual),
              onTapHint: abierto ? 'cerrar el paso' : 'ver qué pasa en este paso',
              excludeSemantics: true,
              onTap: onAlternar,
              child: InkWell(
                onTap: onAlternar,
                borderRadius: forma,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _altoCabecera),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Espacio.m, _separacion, Espacio.s, _separacion),
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
                                    Icon(Icons.check_circle_rounded, size: Espacio.m, color: _colorPedir(context)),
                                    const SizedBox(width: Espacio.xs),
                                    Flexible(
                                      child: Text(
                                        pedir,
                                        style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                                      ),
                                    ),
                                  ],
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
            _Desplegable(
              abierto: abierto,
              duracion: animacion,
              onAbierto: () => _mostrarEntera(context),
              child: _DetallesPaso(paso: paso),
            ),
          ],
        ),
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

class _DetallesPaso extends StatelessWidget {
  const _DetallesPaso({required this.paso});

  final Paso paso;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final citas = CitaPaso.de(paso.fuentes);
    final secciones = [
      if (paso.quePasa.isNotEmpty)
        _Seccion(
          icono: Icons.lightbulb_rounded,
          titulo: 'Qué pasa',
          child: Text(paso.quePasa, style: tema.textTheme.bodyLarge),
        ),
      if (paso.quienEsta.isNotEmpty)
        _Seccion(
          icono: Icons.groups_rounded,
          titulo: 'Quién estará',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final persona in paso.quienEsta) _Persona(nombre: persona)],
          ),
        ),
      if (paso.quePuedesPedir.isNotEmpty)
        _Seccion(
          icono: Icons.front_hand_rounded,
          titulo: 'Puedes pedir',
          child: Wrap(
            spacing: Espacio.s,
            runSpacing: Espacio.s,
            children: [for (final cosa in paso.quePuedesPedir) _PildoraPedir(texto: cosa)],
          ),
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
  const _Seccion({this.icono, this.tuIcono, required this.titulo, required this.child})
    : assert(icono != null || tuIcono != null);

  final IconData? icono;

  /// Un icono de TuTurno en lugar de [icono] (la ley de «De dónde sale»: nunca un mazo).
  final TuIcono? tuIcono;
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
              ExcludeSemantics(
                child: tuIcono != null
                    ? IconoTuTurno(
                        tuIcono!,
                        estilo: EstiloIcono.mono,
                        size: Espacio.m + Espacio.xs / 2,
                        color: esquema.primary,
                        decorativo: true,
                      )
                    : Icon(icono, size: Espacio.m + Espacio.xs / 2, color: esquema.primary),
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

class _Persona extends StatelessWidget {
  const _Persona({required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = tema.colorScheme.secondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: Espacio.s),
      // Arriba: si el nombre ocupa varias líneas, el icono va con la primera.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Container(
              width: Espacio.xl,
              height: Espacio.xl,
              decoration: BoxDecoration(shape: BoxShape.circle, color: tinte(context, color)),
              child: IconoTuTurno(
                iconoPersona(nombre),
                estilo: EstiloIcono.mono,
                size: Espacio.m + Espacio.xs / 2,
                color: color,
                decorativo: true,
              ),
            ),
          ),
          const SizedBox(width: Espacio.s + Espacio.xs),
          Expanded(child: Text(nombre, style: tema.textTheme.bodyLarge)),
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

/// Color de las marcas ✓ de «Puedes pedir»: el de acierto del tema (verde azulado, AA en los dos temas). Si el tema
/// no trae [ColoresTuTurno], el principal.
Color _colorPedir(BuildContext context) {
  final tema = Theme.of(context);
  return tema.extension<ColoresTuTurno>()?.exito ?? tema.colorScheme.primary;
}

/// Algo que puedes pedir en un paso: una etiqueta clara de papel, con el texto entero (puede ocupar varias líneas).
/// No parece un botón: no se toca, se lee.
class _PildoraPedir extends StatelessWidget {
  const _PildoraPedir({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final color = _colorPedir(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        border: Border.all(color: esquema.outlineVariant),
        borderRadius: BorderRadius.circular(Radios.s),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Espacio.s + Espacio.xs, vertical: Espacio.s),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(Icons.check_circle_rounded, size: Espacio.l - Espacio.xs, color: color),
            ),
            const SizedBox(width: Espacio.s),
            Flexible(
              child: Text(
                texto,
                style: tema.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: esquema.onSurface),
              ),
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
