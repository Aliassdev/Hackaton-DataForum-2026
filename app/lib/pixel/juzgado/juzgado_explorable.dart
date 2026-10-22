import 'dart:math' as math;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../tema.dart' show duracion;
import '../../widgets/iconos/iconos.dart';
import '../motor/motor.dart';
import '../ui/ui.dart' show ColoresUiPixel, MarcoPixel, unidadPixel;
import 'carta_rol.dart';
import 'roles_juzgado.dart';
import 'sala_juzgado.dart';

/// «¿Quién es quién en el juzgado?»: la sala de vistas en pixel art, con cada persona en su sitio. Al tocar a alguien
/// se abre su carta («Quién es», «Qué hace» y de qué ley sale) y queda descubierto; las chispas amarillas señalan a
/// quien falta por conocer y una barra cuenta «Has conocido a 4 de 9». Cuando se conoce a todo el mundo, se llama una
/// sola vez a [onTodosDescubiertos] (por ejemplo, para desbloquear una carta de derecho).
///
/// Con [modo] = [ModoJuzgado.menores], la sala es la de la audiencia del caso de Sergio en el Juzgado de Menores.
///
/// Si el padre le da un alto fijo (una pantalla entera), la sala y la barra se quedan arriba y la carta se desplaza
/// debajo; dentro de una lista, ocupa lo que necesita. Las animaciones respetan «reducir animaciones». La sala va en
/// el marco de la pantalla de juego (`MarcoPixel`), como las escenas del caso, y a la mayor escala entera que cabe.
///
/// Los textos están pendientes de revisión jurídica (`DatosJuzgado.validado`): mientras tanto, la actividad lo dice en
/// una franja y el juego solo la abre en modo DEMO, con el interruptor de borradores (lib/features/juego/juzgado_screen).
class JuzgadoExplorable extends StatefulWidget {
  const JuzgadoExplorable({
    super.key,
    this.modo = ModoJuzgado.salaVistas,
    this.onTodosDescubiertos,
    this.onDescubierto,
    this.descubiertosIniciales = const {},
    this.conCabecera = true,
    this.animar = true,
  });

  final ModoJuzgado modo;

  /// Se llama una sola vez, al descubrir a la última persona que faltaba.
  final VoidCallback? onTodosDescubiertos;

  /// Se llama con el id del rol (el de `RolJuzgado.id`) la primera vez que se descubre a cada persona.
  final ValueChanged<String>? onDescubierto;

  /// Ids de los roles que ya se conocían (para seguir donde se dejó). Si ya están todos, no se vuelve a celebrar. Si
  /// llegan más tarde (el progreso guardado se lee de forma asíncrona), se suman a los que ya se habían descubierto.
  final Set<String> descubiertosIniciales;

  /// Con el título («¿Quién es quién en el juzgado?») y la indicación de arriba.
  final bool conCabecera;

  /// Con false, nada se mueve (ni las respiraciones ni las chispas).
  final bool animar;

  @override
  State<JuzgadoExplorable> createState() => _JuzgadoExplorableState();
}

class _JuzgadoExplorableState extends State<JuzgadoExplorable> {
  late Set<String> _descubiertos;
  String? _abierto;

  /// Quien se ilumina en la sala al tocar su ficha antes de conocerle.
  String? _pista;
  late bool _celebrado;

  /// Desplaza la carta cuando la sala se queda fija arriba; al abrir otra carta, vuelve al principio.
  final _desplazamiento = ScrollController();

  /// La cabecera de la carta: si al abrirla queda por debajo de lo que se ve (en un móvil pequeño o dentro de una
  /// lista), se desplaza lo justo para que asome.
  final _cabeceraCarta = GlobalKey();

  DatosJuzgado get _datos => DatosJuzgado.de(widget.modo);

  MontajeJuzgado get _montaje => MontajeJuzgado.de(widget.modo);

  @override
  void initState() {
    super.initState();
    _reiniciar();
  }

  @override
  void didUpdateWidget(JuzgadoExplorable antiguo) {
    super.didUpdateWidget(antiguo);
    if (antiguo.modo != widget.modo) {
      _reiniciar();
    } else if (!setEquals(antiguo.descubiertosIniciales, widget.descubiertosIniciales)) {
      final ids = {for (final rol in _datos.roles) rol.id};
      _descubiertos.addAll(widget.descubiertosIniciales.where(ids.contains));
      // Lo que ya estaba guardado no se celebra otra vez.
      if (_descubiertos.length == ids.length) _celebrado = true;
    }
  }

  @override
  void dispose() {
    _desplazamiento.dispose();
    super.dispose();
  }

  void _reiniciar() {
    final ids = {for (final rol in _datos.roles) rol.id};
    _descubiertos = widget.descubiertosIniciales.where(ids.contains).toSet();
    _abierto = null;
    _pista = null;
    _celebrado = _descubiertos.length == ids.length;
  }

  void _pulsar(String id) {
    if (_datos.rol(id) == null) return;
    HapticFeedback.selectionClick();
    final nuevo = !_descubiertos.contains(id);
    setState(() {
      _abierto = id;
      _pista = null;
      _descubiertos.add(id);
    });
    _alPrincipio();
    if (nuevo) widget.onDescubierto?.call(id);
    if (!_celebrado && _descubiertos.length == _datos.roles.length) {
      _celebrado = true;
      widget.onTodosDescubiertos?.call();
    }
  }

  /// Una ficha: si ya se conoce a esa persona, se abre su carta; si no, se ilumina en la sala para que la encuentre.
  /// Con lector de pantalla (TalkBack), buscarla en el dibujo no sirve de nada: se abre su carta directamente. Y si
  /// hay un lector de pantalla sin navegación accesible, se le dice dónde está.
  void _tocarFicha(String id) {
    if (_descubiertos.contains(id) || MediaQuery.accessibleNavigationOf(context)) {
      _pulsar(id);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _pista = id);
    final rol = _datos.rol(id);
    final sitio = rol?.sitio;
    if (rol != null && sitio != null) {
      SemanticsService.sendAnnouncement(View.of(context), '${rol.titulo}: $sitio.', Directionality.of(context));
    }
  }

  void _cerrar() {
    setState(() => _abierto = null);
    _alPrincipio();
  }

  /// La carta nueva se lee desde arriba, aunque la anterior se hubiera desplazado, y se asegura de que se vea su
  /// cabecera (sin esconder la sala más de lo necesario).
  void _alPrincipio() {
    if (_desplazamiento.hasClients && _desplazamiento.offset > 0) _desplazamiento.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cabecera = _cabeceraCarta.currentContext;
      if (!mounted || cabecera == null) return;
      Scrollable.ensureVisible(
        cabecera,
        duration: duracion(context, const Duration(milliseconds: 320)),
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  /// Lo que dicen los lectores de pantalla de cada persona de la sala.
  String _etiqueta(String id) {
    final titulo = _datos.rol(id)?.titulo ?? id;
    return _descubiertos.contains(id)
        ? '$titulo. Ya sabes quién es: toca para volver a ver su carta.'
        : '$titulo. Toca para saber quién es.';
  }

  @override
  Widget build(BuildContext context) {
    final datos = _datos;
    final total = datos.roles.length;
    final completo = _descubiertos.length == total;
    final abierto = _abierto == null ? null : datos.rol(_abierto!);

    final cabecera = widget.conCabecera
        ? Padding(
            padding: const EdgeInsets.fromLTRB(_margen, _m, _margen, _m - _xs),
            child: _Cabecera(titulo: datos.titulo, subtitulo: datos.subtitulo),
          )
        : const SizedBox(height: _m - _xs);
    final pantalla = Padding(
      padding: const EdgeInsets.symmetric(horizontal: _margenPantalla),
      child: _Pantalla(
        montaje: _montaje,
        elementos: _montaje.elementos(
          descubiertos: _descubiertos,
          seleccionado: _abierto ?? _pista,
          etiqueta: _etiqueta,
        ),
        descripcion: datos.descripcion,
        alPulsar: _pulsar,
        animar: widget.animar,
      ),
    );
    final progreso = Padding(
      padding: const EdgeInsets.fromLTRB(_margen, _m, _margen, 0),
      child: ProgresoJuzgado(conocidos: _descubiertos.length, total: total),
    );
    final detalle = AnimatedSwitcher(
      duration: duracion(context, const Duration(milliseconds: 280)),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (hijo, animacion) => FadeTransition(
        opacity: animacion,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(animacion),
          child: hijo,
        ),
      ),
      layoutBuilder: (actual, anteriores) => Stack(alignment: Alignment.topCenter, children: [...anteriores, ?actual]),
      child: abierto != null
          ? CartaRol(key: ValueKey('carta-${abierto.id}'), rol: abierto, alCerrar: _cerrar)
          : Column(
              key: ValueKey(completo ? 'enhorabuena' : 'indicacion'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (completo) EnhorabuenaJuzgado(total: total) else const IndicacionJuzgado(),
                const SizedBox(height: _l),
                FichasJuzgado(
                  roles: datos.roles,
                  descubiertos: _descubiertos,
                  pista: _pista,
                  alTocar: _tocarFicha,
                  accesible: MediaQuery.accessibleNavigationOf(context),
                ),
                for (final nota in datos.notas) ...[const SizedBox(height: _m), NotaSala(nota: nota)],
              ],
            ),
    );
    const relleno = EdgeInsets.fromLTRB(_margen, _m + _xs, _margen, _l);
    // Una caja invisible del alto de la cabecera de la carta, para poder desplazarse hasta ella.
    final carta = Stack(
      children: [
        Positioned(top: 0, left: 0, right: 0, height: 120, child: SizedBox(key: _cabeceraCarta)),
        detalle,
      ],
    );
    final conCabecera = datos.validado
        ? carta
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Borrador(),
              const SizedBox(height: _m),
              carta,
            ],
          );

    return LayoutBuilder(
      builder: (context, limites) {
        final cabe = limites.hasBoundedHeight && limites.maxHeight - _altoArriba(context, limites.maxWidth) >= 240;
        if (!cabe) {
          final todo = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cabecera,
              pantalla,
              progreso,
              Padding(padding: relleno, child: conCabecera),
            ],
          );
          return limites.hasBoundedHeight ? SingleChildScrollView(child: todo) : todo;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cabecera,
            pantalla,
            progreso,
            Expanded(
              // La sala no se mueve: que la barra de arriba de la app no crea que algo pasa por debajo de ella, ni al
              // desplazar la carta ni cuando crece al abrir «Qué dice la ley».
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) => true,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (_) => true,
                  child: _DesvanecerArriba(
                    child: SingleChildScrollView(controller: _desplazamiento, padding: relleno, child: conCabecera),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Lo que ocupan, más o menos, la cabecera, la sala y la barra con [ancho] de pantalla (para decidir si la carta
  /// cabe debajo con la sala fija o si mejor se desplaza todo junto).
  double _altoArriba(BuildContext context, double ancho) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final u = unidadPixel(context);
    final arte = _montaje.fondo;
    final interior = ancho - 2 * (_margenPantalla + MarcoPixel.grosor * u);
    final fisicos = math.max(1, (interior * dpr / arte.ancho + 1e-6).floor());
    final sala = arte.alto * fisicos / dpr + (2 * MarcoPixel.grosor + 1) * u;
    final letra = MediaQuery.textScalerOf(context).scale(20);
    return (widget.conCabecera ? 3.6 * letra + _m : _m) + sala + 2.5 * letra + _m;
  }
}

const _xs = 4.0;
const _m = 16.0;
const _l = 24.0;
const _margen = 16.0;

/// El margen a los lados del marco de la sala: con el marco de la pantalla de juego (5 unidades pixel por lado), en un
/// móvil de 1080 píxeles la sala sale a 6 píxeles de pantalla por píxel del dibujo (con 12, saldría a 5).
const _margenPantalla = 4.0;

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.titulo, required this.subtitulo});

  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(titulo, style: tema.textTheme.headlineMedium?.copyWith(color: tema.colorScheme.onSurface)),
        ),
        const SizedBox(height: _xs),
        Text(
          subtitulo,
          style: tema.textTheme.bodyLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant, height: 1.35),
        ),
      ],
    );
  }
}

/// Lo que se desplaza por debajo de la barra se desvanece en sus primeros píxeles, en vez de cortarse en seco.
class _DesvanecerArriba extends StatelessWidget {
  const _DesvanecerArriba({required this.child});

  final Widget child;

  static const _alto = 18.0;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (rect) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
      stops: [0, rect.height <= 0 ? 0 : math.min(1, _alto / rect.height)],
    ).createShader(rect),
    child: child,
  );
}

/// La sala en el marco de la pantalla de juego, como las escenas del caso. El marco (`MarcoPixel`) y la escena se
/// ajustan a la rejilla de píxeles de la pantalla, así que la sala sale nítida aunque quede a medio píxel.
class _Pantalla extends StatelessWidget {
  const _Pantalla({
    required this.montaje,
    required this.elementos,
    required this.descripcion,
    required this.alPulsar,
    required this.animar,
  });

  final MontajeJuzgado montaje;
  final List<ElementoEscena> elementos;
  final String descripcion;
  final ValueChanged<String> alPulsar;
  final bool animar;

  @override
  Widget build(BuildContext context) => MarcoPixel(
    child: EscenaPixel(
      fondo: montaje.fondo,
      elementos: elementos,
      alPulsar: alPulsar,
      descripcion: descripcion,
      colorMarco: ColoresUiPixel.noche,
      animar: animar,
    ),
  );
}

/// «Borrador: pendiente de revisión jurídica», mientras nadie con formación jurídica haya revisado los textos.
class _Borrador extends StatelessWidget {
  const _Borrador();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return MergeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: esquema.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: esquema.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _m - _xs, vertical: _xs + 2),
          child: Row(
            children: [
              Icon(Icons.edit_note_rounded, color: esquema.onSurfaceVariant),
              const SizedBox(width: _xs + 4),
              Expanded(
                child: Text(
                  'Borrador: textos pendientes de revisión jurídica.',
                  style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «Has conocido a 4 de 9» y una barra de [total] tramos, amarillos los ya conocidos.
class ProgresoJuzgado extends StatelessWidget {
  const ProgresoJuzgado({super.key, required this.conocidos, required this.total});

  final int conocidos;
  final int total;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final oscuro = tema.brightness == Brightness.dark;
    final amarillo = PaletaPixel.amarillo.color;
    final noche = PaletaPixel.noche.color;
    final completo = conocidos >= total;
    final tiempo = duracion(context, const Duration(milliseconds: 320));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Has conocido a $conocidos de $total',
                style: tema.textTheme.titleMedium?.copyWith(color: esquema.onSurface, fontWeight: FontWeight.w800),
              ),
            ),
            if (completo)
              IconoTuTurno(
                TuIcono.check,
                estilo: EstiloIcono.mono,
                color: oscuro ? amarillo : esquema.primary,
                decorativo: true,
              ),
          ],
        ),
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                Expanded(
                  child: AnimatedContainer(
                    duration: tiempo,
                    curve: Curves.easeOutCubic,
                    height: 14,
                    decoration: BoxDecoration(
                      color: i < conocidos ? amarillo : (oscuro ? esquema.surfaceContainerHighest : Colors.white),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: i < conocidos ? noche : (oscuro ? esquema.outline : esquema.outlineVariant),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
