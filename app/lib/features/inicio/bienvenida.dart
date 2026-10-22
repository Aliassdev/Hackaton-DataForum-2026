import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../tema.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/iconos/iconos.dart';
import '../../widgets/marca/marca.dart';
import '../../widgets/modulos.dart';
import '../../widgets/movimiento/movimiento.dart';
import '../../widgets/tuturno_scaffold.dart';
import 'widgets/bocadillo.dart';

const _paginas = 2;
const _anchoPuntoActivo = Espacio.l;

/// Lo que dice Tut en la segunda pantalla de la bienvenida (sección 4.1).
const mensajeIA = 'Soy una IA. No te pido tu nombre y lo que hablamos se borra. Si estás en peligro, pulsa Ayuda.';

/// Bienvenida de la primera vez (sección 4.1), en dos pantallas: «¿Qué es TuTurno?», que empieza con el logotipo
/// pegándose letra a letra, y «Antes de empezar», donde Tut cuenta que es una IA y dónde está Ayuda. Ayuda y Glosario
/// siguen arriba a la derecha; en la segunda pantalla el botón de Ayuda late un par de veces para que se vea.
class Bienvenida extends ConsumerStatefulWidget {
  const Bienvenida({super.key});

  @override
  ConsumerState<Bienvenida> createState() => _BienvenidaState();
}

class _BienvenidaState extends ConsumerState<Bienvenida> {
  final _controlador = PageController();
  int _pagina = 0;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  Future<void> _irA(int pagina) async {
    final d = duracion(context, Duracion.larga);
    if (d == Duration.zero) {
      _controlador.jumpToPage(pagina);
    } else {
      await _controlador.animateToPage(pagina, duration: d, curve: Curves.easeOutCubic);
    }
  }

  Future<void> _siguiente() async {
    if (_pagina < _paginas - 1) {
      Hapticos.seleccion();
      await _irA(_pagina + 1);
    } else {
      // Se arranca la bienvenida como un ticket y aparece el inicio.
      Hapticos.acierto();
      await ref.read(bienvenidaVistaProvider.notifier).marcar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ultima = _pagina == _paginas - 1;
    return PopScope(
      canPop: _pagina == 0,
      onPopInvokedWithResult: (hecho, _) {
        if (!hecho) _irA(_pagina - 1);
      },
      child: TuTurnoScaffold(
        titulo: 'TuTurno',
        // En la primera pantalla el logotipo grande ya está en la portada; en la segunda, sube a la barra.
        tituloWidget: AnimatedOpacity(
          opacity: _pagina > 0 ? 1 : 0,
          duration: duracion(context, Duracion.media),
          child: const LogoTuTurno(alto: 26),
        ),
        resaltarAyuda: ultima,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: anchoMaximo),
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _controlador,
                    onPageChanged: (pagina) => setState(() => _pagina = pagina),
                    children: [
                      _PaginaDePapel(controlador: _controlador, indice: 0, child: const _QueEsTuTurno()),
                      _PaginaDePapel(controlador: _controlador, indice: 1, child: const _AntesDeEmpezar()),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Espacio.l, Espacio.s, Espacio.l, Espacio.l),
                  child: Column(
                    children: [
                      _Puntos(actual: _pagina),
                      const SizedBox(height: Espacio.m),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          // Un ticket de verdad: con las dos muescas a los lados.
                          style: FilledButton.styleFrom(
                            shape: const TicketBorder(
                              ladoTalon: LadoTalon.abajo,
                              perforado: false,
                              radio: Radios.m - 4,
                              radioMuesca: 9,
                            ),
                          ),
                          onPressed: _siguiente,
                          child: AnimatedSwitcher(
                            duration: duracion(context, Duracion.corta),
                            child: Row(
                              key: ValueKey(ultima),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(child: Text(ultima ? 'Empezar' : 'Siguiente')),
                                const SizedBox(width: Espacio.s),
                                const Icon(Icons.arrow_forward_rounded, size: 22),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Al pasar de pantalla, cada una gira un poco sobre su borde de abajo, como una hoja que se aparta con la mano.
/// Solo transforma su capa: no se vuelve a pintar nada.
class _PaginaDePapel extends StatelessWidget {
  const _PaginaDePapel({required this.controlador, required this.indice, required this.child});

  final PageController controlador;
  final int indice;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final quieta = duracion(context, Duracion.media) == Duration.zero;
    return AnimatedBuilder(
      animation: controlador,
      child: RepaintBoundary(child: child),
      builder: (context, pagina) {
        var d = 0.0;
        if (!quieta && controlador.hasClients && controlador.position.haveDimensions) {
          d = ((controlador.page ?? indice.toDouble()) - indice).clamp(-1.0, 1.0);
        }
        return Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.identity()
            ..rotateZ(-d * 0.08)
            ..scaleByDouble(1 - d.abs() * 0.05, 1 - d.abs() * 0.05, 1, 1),
          child: pagina,
        );
      },
    );
  }
}

class _Puntos extends StatelessWidget {
  const _Puntos({required this.actual});

  final int actual;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Pantalla ${actual + 1} de $_paginas',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _paginas; i++)
              AnimatedContainer(
                duration: duracion(context, Duracion.media),
                curve: Curves.easeOutBack,
                margin: const EdgeInsets.symmetric(horizontal: Espacio.xs),
                width: i == actual ? _anchoPuntoActivo : Espacio.s + 2,
                height: Espacio.s + 2,
                decoration: BoxDecoration(
                  color: i == actual ? esquema.primary : esquema.outlineVariant,
                  borderRadius: BorderRadius.circular(Espacio.xs + 1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Estructura común de las dos pantallas: centradas en vertical si caben y desplazables si no (letra grande).
class _Pagina extends StatelessWidget {
  const _Pagina({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Espacio.l, vertical: Espacio.m),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: math.max(0, restricciones.maxHeight - 2 * Espacio.m)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Primera pantalla. Se mantiene viva al pasar a la segunda: la presentación del logotipo no se repite al volver.
class _QueEsTuTurno extends StatefulWidget {
  const _QueEsTuTurno();

  @override
  State<_QueEsTuTurno> createState() => _QueEsTuTurnoState();
}

class _QueEsTuTurnoState extends State<_QueEsTuTurno> with AutomaticKeepAliveClientMixin {
  /// El texto entra cuando el logotipo ya casi se ha pegado.
  static const _trasLogo = Duration(milliseconds: 700);

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tema = Theme.of(context);
    var orden = 0;
    return _Pagina(
      children: [
        const _PortadaMarca(),
        const SizedBox(height: Espacio.l + Espacio.xs),
        Entrada(
          orden: orden++,
          retraso: _trasLogo,
          child: Semantics(header: true, child: Text('¿Qué es TuTurno?', style: tema.textTheme.headlineMedium)),
        ),
        const SizedBox(height: Espacio.s),
        Entrada(
          orden: orden++,
          retraso: _trasLogo,
          child: Text(
            'Una app para entender cómo funciona la justicia cuando te toca a ti. Con palabras claras.',
            style: tema.textTheme.bodyLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: Espacio.l - Espacio.xs),
        for (final (i, modulo) in Modulo.values.indexed) ...[
          Entrada(
            orden: orden++,
            retraso: _trasLogo,
            child: _FilaModulo(modulo: modulo, orden: i),
          ),
          if (i < Modulo.values.length - 1) const SizedBox(height: Espacio.m),
        ],
      ],
    );
  }
}

/// La portada de la bienvenida: un papel azul donde las letras de TuTurno se pegan una a una, aparece el lema y Tut
/// se asoma por la esquina como una pegatina.
class _PortadaMarca extends StatefulWidget {
  const _PortadaMarca();

  @override
  State<_PortadaMarca> createState() => _PortadaMarcaState();
}

class _PortadaMarcaState extends State<_PortadaMarca> {
  bool _conTut = false;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radios.l),
            boxShadow: sombrasPapel(context, elevacion: 1.5),
          ),
          child: FondoPapel(
            color: ColoresMarca.azul,
            acento: ColoresMarca.amarillo,
            formas: 5,
            semilla: 4,
            ciclos: 1,
            periodo: const Duration(seconds: 10),
            radio: Radios.l,
            child: Padding(
              // Con la letra grande el lema ocupa casi todo el ancho: se deja sitio debajo para Tut.
              padding: EdgeInsets.fromLTRB(
                Espacio.m,
                Espacio.l + Espacio.xs,
                Espacio.m,
                letraGrande(context) ? Espacio.xxl + Espacio.s : Espacio.l + Espacio.s,
              ),
              child: Center(
                child: IntroMarca(
                  alto: 64,
                  tono: TonoMarca.amarillo,
                  lema: Text(
                    '¡Es tu turno!',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.headlineSmall?.copyWith(color: Colors.white),
                  ),
                  onTerminada: () {
                    if (mounted) setState(() => _conTut = true);
                  },
                ),
              ),
            ),
          ),
        ),
        if (_conTut)
          const Positioned(
            right: -Espacio.s,
            bottom: -Espacio.m - 2,
            child: TutAjustado(
              tamano: 96,
              expresion: ExpresionTut.feliz,
              pegatina: true,
              semanticLabel: 'Tut, la mascota de TuTurno, te saluda',
            ),
          ),
      ],
    );
  }
}

/// Un módulo en la primera pantalla: su icono como una pegatina y lo que es.
class _FilaModulo extends StatelessWidget {
  const _FilaModulo({required this.modulo, required this.orden});

  final Modulo modulo;
  final int orden;

  static const _giros = [-0.07, 0.06, -0.05];

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return MergeSemantics(
      child: Row(
        children: [
          PopPegatina(
            orden: orden,
            retraso: const Duration(milliseconds: 900),
            inclinacion: _giros[orden % _giros.length],
            child: IconoTuTurno(modulo.tuIcono, size: 46, decorativo: true),
          ),
          const SizedBox(width: Espacio.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(modulo.titulo, style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: Espacio.xs / 2),
                Text(
                  modulo.descripcion,
                  style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Segunda pantalla: Tut cuenta que es una IA, que no pide tu nombre y dónde está Ayuda. Tranquila: sin juegos.
class _AntesDeEmpezar extends StatelessWidget {
  const _AntesDeEmpezar();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    var orden = 0;
    return _Pagina(
      children: [
        Entrada(
          orden: orden++,
          child: Semantics(
            header: true,
            child: Text('Antes de empezar', textAlign: TextAlign.center, style: tema.textTheme.headlineMedium),
          ),
        ),
        const SizedBox(height: Espacio.m),
        Entrada(
          orden: orden++,
          child: const Center(child: TutAjustado(tamano: 120, semanticLabel: 'Tut, la mascota de TuTurno')),
        ),
        const SizedBox(height: Espacio.xs),
        Entrada(
          orden: orden++,
          child: Bocadillo(
            cola: LadoCola.arriba,
            child: Text(
              mensajeIA,
              style: tema.textTheme.titleMedium?.copyWith(
                color: context.colores.tintaTicket,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ),
        const SizedBox(height: Espacio.l),
        Entrada(
          orden: orden++,
          child: const _Fila(
            icono: TuIcono.pregunta,
            titulo: 'Una IA, no una persona',
            texto: 'Te explico cómo funciona la justicia, con palabras claras.',
          ),
        ),
        const SizedBox(height: Espacio.m),
        Entrada(
          orden: orden++,
          child: const _Fila(
            icono: TuIcono.candado,
            titulo: 'Sin nombre ni cuenta',
            texto: 'No hace falta registrarte. Lo que hablamos en Pregunta se borra al salir.',
          ),
        ),
        const SizedBox(height: Espacio.m),
        Entrada(
          orden: orden++,
          child: const _Fila(
            icono: TuIcono.ayuda,
            titulo: 'Ayuda, siempre arriba',
            texto: 'Es el botón rojo de arriba a la derecha. Ahí tienes teléfonos gratis.',
          ),
        ),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.icono, required this.titulo, required this.texto});

  final TuIcono icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconoTuTurno(icono, size: 36, decorativo: true),
          const SizedBox(width: Espacio.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: Espacio.xs / 2),
                Text(texto, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
