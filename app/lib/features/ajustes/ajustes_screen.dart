import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ajustes.dart';
import '../../core/entrada.dart' show entradaProvider;
import '../../core/providers.dart';
import '../../core/voz/tts.dart';
import '../../tema.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/iconos/iconos.dart';
import '../../widgets/marca/marca.dart';
import '../../widgets/modulos.dart';
import '../../widgets/movimiento/hapticos.dart';
import '../../widgets/tuturno_scaffold.dart';
import '../situacion/mi_ticket.dart' show miTicketProvider;
import '../situacion/textos.dart' show botonCambiarTicket, botonRellenarTicket;
import '../situacion/ticket_screen.dart' show abrirTuTicket;
import 'demo.dart';
import 'para_el_equipo.dart';
import 'piezas.dart';

export 'demo.dart' show esUrlServidorValida, pistaConexion, soloHttps;

/// Tamaños de letra que se pueden elegir (multiplican el del sistema).
const tamanosTexto = [(1.0, 'Normal'), (1.15, 'Grande'), (1.3, 'Enorme')];

const velocidadMinima = 0.3;
const velocidadMaxima = 0.7;

const fraseProbarVoz = 'Hola. Así sonará la voz de TuTurno cuando te lea las respuestas.';

const textoLecturaFacil = 'Una letra más clara, con más espacio entre líneas.';

/// Para qué sirve el ticket. Se cambia aquí mismo («Cambiar mi ticket» abre «Tu ticket», el de Mi situación, en el
/// móvil y en la web), en Pregunta («Cambiar» o «Elegir») y en Mi situación.
const notaTicket = 'Pregunta y Mi situación lo usan para explicártelo mejor.';

/// El pie de Ajustes (su pulsación larga descubre «Para el equipo»). Sin «solo»: el ticket viaja con las preguntas.
const textoPieAjustes = 'Todo esto se guarda en tu móvil, sin cuentas.';
const textoReducirAnimaciones = 'Las pantallas cambian sin moverse y no hay confeti.';
const notaAnimacionesDelSistema = 'Tu móvil ya tiene las animaciones reducidas.';

/// «Tus datos en este móvil» (plan v2, producto §5.3). Sin promesas que no dependan del móvil: lo que se pregunta pasa
/// por el servidor de TuTurno y, con la voz, por ElevenLabs, que lo guarda según cómo esté configurado el agente.
const textoQueSeGuarda =
    'Aquí se guardan tu progreso, tus cartas y sellos, tu ticket (también tu día y lo que te preocupa), tus preguntas '
    'apuntadas y tus palabras guardadas. No hay cuentas.';
const textoQueSale =
    'Lo que preguntas en Pregunta y lo que escribes en «Dilo con tus palabras» se envían, sin tu nombre, para poder '
    'contestarte; con la voz, pasan también por ElevenLabs, la empresa de la voz. Tu ticket va con tus preguntas. '
    'Este móvil no guarda la conversación.';

/// El texto del diálogo de «Borrar todo lo de este móvil».
const textoConfirmarBorrarTodo =
    'Se borran tu progreso, tus cartas y sellos, tu ticket (también tu día y lo que te preocupa), tus preguntas '
    'apuntadas y tus palabras guardadas. Los ajustes de letra y voz se quedan. No se puede deshacer.';

String nombreVelocidad(double v) {
  if (v < 0.45) return 'Más lenta';
  if (v > 0.55) return 'Más rápida';
  return 'Normal';
}

/// Ajustes (sección 6.4): «Leer mejor» (letra, lectura fácil, animaciones y voz), «Tu ticket», «Tus datos en este
/// móvil» con «Borrar todo» y «Acerca de TuTurno». Todo se queda en el móvil.
///
/// «Para el equipo (demo)», con el servidor, solo sale tras una pulsación larga en el pie (auditoría P1-6): ni con DEMO
/// ni en depuración se ve sin ella. Al volver a entrar en Ajustes, se esconde otra vez.
class AjustesScreen extends ConsumerStatefulWidget {
  const AjustesScreen({super.key});

  @override
  ConsumerState<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends ConsumerState<AjustesScreen> {
  var _equipoRevelado = false;
  final _claveEquipo = GlobalKey();

  void _cambiar(Ajustes Function(Ajustes actuales) cambio) {
    Hapticos.seleccion();
    ref.read(ajustesProvider.notifier).actualizar(cambio);
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  void _probarVoz() {
    Hapticos.seleccion();
    unawaited(ref.read(ttsProvider).hablar(fraseProbarVoz, velocidad: ref.read(ajustesProvider).velocidadVoz));
  }

  /// La pulsación larga en el pie: aparece la parte del equipo, debajo, y se baja hasta ella (sin aviso abajo: taparía
  /// sus botones).
  void _revelarEquipo() {
    if (_equipoRevelado) return;
    Hapticos.toque();
    setState(() => _equipoRevelado = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final destino = _claveEquipo.currentContext;
      if (!mounted || destino == null) return;
      unawaited(
        Scrollable.ensureVisible(destino, duration: duracion(context, Duracion.media), curve: Curves.easeOutCubic),
      );
    });
  }

  Future<void> _borrarMisRespuestas() async {
    Hapticos.seleccion();
    await borrarTicket(ref);
    if (mounted) _avisar('Hecho. Tu ticket está vacío.');
  }

  /// «Borrar todo lo de este móvil»: pide confirmación, deja la app como nueva (los ajustes se quedan) y vuelve al
  /// inicio, que enseña la bienvenida.
  Future<void> _borrarTodo() async {
    Hapticos.seleccion();
    final si = await confirmar(
      context,
      titulo: '¿Borrar todo?',
      texto: textoConfirmarBorrarTodo,
      accion: 'Borrar todo',
    );
    if (!si || !mounted) return;
    final router = GoRouter.of(context);
    final mensajero = ScaffoldMessenger.of(context);
    await reiniciarUso(ref);
    Hapticos.toque();
    router.go('/');
    mensajero
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(avisoComoNuevo)));
  }

  @override
  Widget build(BuildContext context) {
    final ajustes = ref.watch(ajustesProvider);
    // «Reducir animaciones» de Ajustes se suma a la del sistema (lib/app.dart): si aquí está apagado y aun así no hay
    // animaciones, es el sistema.
    final animacionesDelSistema = MediaQuery.disableAnimationsOf(context) && !ajustes.reducirMovimiento;
    var orden = 0;
    return TuTurnoScaffold(
      titulo: 'Ajustes',
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: anchoMaximo),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.m, Espacio.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Entrada(
                  orden: orden++,
                  child: SeccionAjustes(
                    icono: const _PegatinaLetra(),
                    titulo: 'Leer mejor',
                    child: _LeerMejor(
                      ajustes: ajustes,
                      animacionesDelSistema: animacionesDelSistema,
                      onCambio: _cambiar,
                      onProbarVoz: _probarVoz,
                    ),
                  ),
                ),
                const SizedBox(height: Espacio.m),
                Entrada(
                  orden: orden++,
                  child: _TuTicket(onBorrar: _borrarMisRespuestas),
                ),
                const SizedBox(height: Espacio.m),
                Entrada(
                  orden: orden++,
                  child: _TusDatos(onBorrarTodo: _borrarTodo),
                ),
                const SizedBox(height: Espacio.m),
                Entrada(orden: orden++, child: const _AcercaDe()),
                const SizedBox(height: Espacio.l),
                Entrada(
                  orden: orden++,
                  child: _Pie(onPulsacionLarga: _revelarEquipo),
                ),
                if (_equipoRevelado) ...[
                  const SizedBox(height: Espacio.xl),
                  Entrada(child: ParaElEquipo(key: _claveEquipo)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «Aa» en una pegatina amarilla, un poco torcida: el icono de «Leer mejor».
class _PegatinaLetra extends StatelessWidget {
  const _PegatinaLetra();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Transform.rotate(
      angle: -0.08,
      child: SizedBox.square(
        dimension: Espacio.xl + Espacio.xs,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ColoresMarca.amarillo,
            borderRadius: BorderRadius.circular(Radios.s - Espacio.xs),
            border: Border.all(color: ColoresMarca.azulNoche, width: 2),
            boxShadow: sombrasPapel(context, elevacion: 0.5),
          ),
          // Tamaño fijo: es un dibujo, no texto que haya que leer.
          child: Center(
            child: MediaQuery.withNoTextScaling(
              child: Text(
                'Aa',
                style: tema.textTheme.titleLarge?.copyWith(
                  fontFamily: Fuentes.titulos,
                  fontFamilyFallback: const [Fuentes.texto],
                  color: ColoresMarca.azulNoche,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «Leer mejor» (plan v2, producto §5.8): el tamaño de la letra, «Lectura fácil» con la tarjeta «Así se verá»,
/// «Reducir animaciones» y la voz, juntos.
class _LeerMejor extends StatelessWidget {
  const _LeerMejor({
    required this.ajustes,
    required this.animacionesDelSistema,
    required this.onCambio,
    required this.onProbarVoz,
  });

  final Ajustes ajustes;

  /// El sistema ya quita las animaciones: el interruptor sale encendido y desactivado, con una nota.
  final bool animacionesDelSistema;
  final void Function(Ajustes Function(Ajustes actuales) cambio) onCambio;
  final VoidCallback onProbarVoz;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SubtituloAjustes('Tamaño de la letra'),
        const SizedBox(height: Espacio.s),
        _TamanoLetra(
          actual: ajustes.tamanoTexto,
          onCambio: (t) => onCambio((a) => a.copyWith(tamanoTexto: t)),
        ),
        const SizedBox(height: Espacio.s),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Lectura fácil'),
          subtitle: const Text(textoLecturaFacil),
          value: ajustes.lecturaFacil,
          onChanged: (valor) => onCambio((a) => a.copyWith(lecturaFacil: valor)),
        ),
        const SizedBox(height: Espacio.xs),
        const _AsiSeVera(),
        const SizedBox(height: Espacio.s),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Reducir animaciones'),
          subtitle: const Text(textoReducirAnimaciones),
          value: ajustes.reducirMovimiento || animacionesDelSistema,
          onChanged: animacionesDelSistema ? null : (valor) => onCambio((a) => a.copyWith(reducirMovimiento: valor)),
        ),
        if (animacionesDelSistema)
          const NotaAjustes(
            icono: IconoTuTurno(TuIcono.info, size: 20, decorativo: true),
            texto: notaAnimacionesDelSistema,
          ),
        const SizedBox(height: Espacio.l),
        const SubtituloAjustes('Voz'),
        _Voz(
          ajustes: ajustes,
          onVoz: (v) => onCambio((a) => a.copyWith(vozActivada: v)),
          onVelocidad: (v) => onCambio((a) => a.copyWith(velocidadVoz: v)),
          onProbar: onProbarVoz,
        ),
      ],
    );
  }
}

class _TamanoLetra extends StatelessWidget {
  const _TamanoLetra({required this.actual, required this.onCambio});

  final double actual;
  final ValueChanged<double> onCambio;

  /// El tamaño guardado más parecido a uno de los que se ofrecen.
  double get _seleccionado =>
      tamanosTexto.map((t) => t.$1).reduce((a, b) => (a - actual).abs() <= (b - actual).abs() ? a : b);

  @override
  Widget build(BuildContext context) {
    // Lo elegido, como una pegatina amarilla (el tema del botón segmentado).
    return SegmentedButton<double>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(minimumSize: const Size.fromHeight(Espacio.xxl)),
      segments: [
        for (final (valor, nombre) in tamanosTexto)
          ButtonSegment(
            value: valor,
            label: FittedBox(fit: BoxFit.scaleDown, child: Text(nombre)),
          ),
      ],
      selected: {_seleccionado},
      onSelectionChanged: (seleccion) => onCambio(seleccion.first),
    );
  }
}

/// «Así se verá»: una frase con la letra y el tamaño elegidos (también con lectura fácil).
class _AsiSeVera extends StatelessWidget {
  const _AsiSeVera();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return AnimatedContainer(
      duration: duracion(context, Duracion.media),
      padding: const EdgeInsets.all(Espacio.m),
      decoration: BoxDecoration(
        color: tinte(context, esquema.primary),
        border: Border.all(color: bordeTinte(esquema.primary)),
        borderRadius: BorderRadius.circular(Radios.m),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Así se verá', style: tema.textTheme.labelLarge?.copyWith(color: esquema.onSurfaceVariant)),
          const SizedBox(height: Espacio.xs),
          Text('Tienes derecho a que te escuchen y a entender todo lo que pasa.', style: tema.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _Voz extends StatelessWidget {
  const _Voz({required this.ajustes, required this.onVoz, required this.onVelocidad, required this.onProbar});

  final Ajustes ajustes;
  final ValueChanged<bool> onVoz;
  final ValueChanged<double> onVelocidad;
  final VoidCallback onProbar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final velocidad = ajustes.velocidadVoz.clamp(velocidadMinima, velocidadMaxima).toDouble();
    final etiqueta = tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Leer las respuestas en voz alta'),
          subtitle: const Text('Si preguntas con la voz, te contesto también en voz alta. Siempre lo podrás leer.'),
          value: ajustes.vozActivada,
          onChanged: onVoz,
        ),
        const SizedBox(height: Espacio.s),
        Text('Velocidad de la voz', style: tema.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        // Con TalkBack se oye qué controla: «Velocidad de la voz, Normal».
        Semantics(
          label: 'Velocidad de la voz',
          child: Slider(
            min: velocidadMinima,
            max: velocidadMaxima,
            divisions: 4,
            value: velocidad,
            label: nombreVelocidad(velocidad),
            semanticFormatterCallback: nombreVelocidad,
            onChanged: onVelocidad,
          ),
        ),
        ExcludeSemantics(
          child: Row(
            children: [
              Expanded(child: Text('Más lenta', style: etiqueta)),
              Expanded(
                child: Text('Normal', textAlign: TextAlign.center, style: etiqueta),
              ),
              Expanded(
                child: Text('Más rápida', textAlign: TextAlign.end, style: etiqueta),
              ),
            ],
          ),
        ),
        const SizedBox(height: Espacio.m),
        OutlinedButton.icon(
          onPressed: onProbar,
          icon: const IconoTuTurno(TuIcono.altavoz, estilo: EstiloIcono.mono, decorativo: true),
          label: const Text('Probar la voz'),
        ),
      ],
    );
  }
}

/// «Tu ticket»: lo que se ha contado (edad, proceso, papel y momento; y en Mi situación, con quién irás, qué te
/// preocupa y cómo prefieres que te lo cuente), cómo cambiarlo y cómo borrarlo. «Cambiar mi ticket» abre «Tu ticket»
/// (lib/features/situacion/ticket_screen.dart) en todos los modos, también en la web.
class _TuTicket extends ConsumerWidget {
  const _TuTicket({required this.onBorrar});

  final VoidCallback onBorrar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final entrada = ref.watch(entradaProvider);
    final resumen = resumenTicket(entrada);
    // Las respuestas de Mi situación también cuentan: se pueden borrar aunque el ticket de la app esté vacío.
    final hayRespuestas = !entrada.vacia || !ref.watch(miTicketProvider.select((t) => t.sinRespuestas));
    return SeccionAjustes(
      icono: const IconoTuTurno(TuIcono.ticket, size: Espacio.xl + Espacio.xs, decorativo: true),
      titulo: 'Tu ticket',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: 'Tu ticket: ${resumen.isEmpty ? 'sin rellenar' : resumen.replaceAll(' · ', ', ')}',
            excludeSemantics: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tinte(context, esquema.primary),
                border: Border.all(color: bordeTinte(esquema.primary)),
                borderRadius: BorderRadius.circular(Radios.m),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Espacio.m, vertical: Espacio.s + Espacio.xs),
                child: Text(
                  resumen.isEmpty ? 'Sin rellenar' : resumen,
                  key: const Key('resumen-ticket'),
                  style: tema.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: resumen.isEmpty ? esquema.onSurfaceVariant : esquema.onSurface,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Espacio.s + Espacio.xs),
          const NotaAjustes(icono: IconoTuTurno(TuIcono.info, size: 20, decorativo: true), texto: notaTicket),
          const SizedBox(height: Espacio.s),
          Wrap(
            spacing: Espacio.s,
            runSpacing: Espacio.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Hapticos.seleccion();
                  unawaited(abrirTuTicket(context));
                },
                icon: const IconoTuTurno(TuIcono.ticket, estilo: EstiloIcono.mono, decorativo: true),
                label: Text(hayRespuestas ? botonCambiarTicket : botonRellenarTicket),
              ),
              if (hayRespuestas)
                TextButton.icon(
                  onPressed: onBorrar,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Borrar mis respuestas'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// «Tus datos en este móvil»: qué se guarda, qué sale del móvil y «Borrar todo lo de este móvil».
class _TusDatos extends StatelessWidget {
  const _TusDatos({required this.onBorrarTodo});

  final VoidCallback onBorrarTodo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SeccionAjustes(
      icono: const IconoTuTurno(TuIcono.candado, size: Espacio.xl + Espacio.xs, decorativo: true),
      titulo: 'Tus datos en este móvil',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(textoQueSeGuarda, style: tema.textTheme.bodyLarge),
          const SizedBox(height: Espacio.s),
          Text(textoQueSale, style: tema.textTheme.bodyLarge),
          const SizedBox(height: Espacio.m),
          OutlinedButton.icon(
            onPressed: onBorrarTodo,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Borrar todo lo de este móvil'),
          ),
        ],
      ),
    );
  }
}

class _Pie extends StatelessWidget {
  const _Pie({this.onPulsacionLarga});

  /// Descubre la parte del equipo (para preparar la demo, también en una APK release).
  final VoidCallback? onPulsacionLarga;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = tema.colorScheme.onSurfaceVariant;
    return GestureDetector(
      key: const Key('pie-ajustes'),
      onLongPress: onPulsacionLarga,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const IconoTuTurno(TuIcono.candado, size: Espacio.m + Espacio.xs, decorativo: true),
          const SizedBox(width: Espacio.s),
          Flexible(
            child: Text(textoPieAjustes, style: tema.textTheme.bodyMedium?.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

/// «Acerca de TuTurno»: el icono de la app, el logotipo y lo que se queda (y lo que no) en el móvil.
class _AcercaDe extends StatelessWidget {
  const _AcercaDe();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final secundario = tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant);
    return PapelAjustes(
      child: Padding(
        padding: const EdgeInsets.all(Espacio.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                'ACERCA DE',
                style: tema.textTheme.labelLarge?.copyWith(
                  color: esquema.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            const SizedBox(height: Espacio.m),
            Row(
              children: [
                const PlacaTut(lado: 72, etiqueta: null),
                const SizedBox(width: Espacio.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FittedBox(fit: BoxFit.scaleDown, child: LogoTuTurno(alto: 28)),
                      const SizedBox(height: Espacio.s),
                      Text('La justicia, explicada con palabras claras.', style: tema.textTheme.bodyLarge),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espacio.m),
            Text(
              'Sin cuentas ni datos personales. Tus ajustes y tu progreso se quedan en este móvil, y la app no guarda '
              'tus conversaciones.',
              style: secundario,
            ),
            const SizedBox(height: Espacio.s),
            Text('DATAthon DATAfórum Justicia 2026 · Reto 2: infancia y juventud.', style: secundario),
          ],
        ),
      ),
    );
  }
}
