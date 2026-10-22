import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/tuturno_api.dart';
import '../../core/demo.dart';
import '../../core/progreso.dart';
import '../../core/providers.dart';
import '../../tema.dart';
import '../../widgets/iconos/iconos.dart';
import '../../widgets/movimiento/hapticos.dart';
import 'demo.dart';
import 'piezas.dart';

/// Lo que se ve al terminar «Preparar demo».
String avisoDemoPreparada(Progreso p) =>
    'Demo preparada: ${p.xp} XP, racha de ${p.racha} días y ${p.cartas.length} cartas.';

const avisoComoNuevo = 'Listo. TuTurno está como nuevo.';

/// «Para el equipo (demo)» (plan v2, demo §3.1): preparar cada ensayo, los atajos del guion, «Comprobar antes de
/// salir», el servidor y la galería de iconos. Solo sale tras la pulsación larga en el pie de Ajustes, también con
/// DEMO o en depuración: el jurado no lo ve.
class ParaElEquipo extends StatelessWidget {
  const ParaElEquipo({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CabeceraEquipo(),
        SizedBox(height: Espacio.m),
        _PrepararDemo(),
        SizedBox(height: Espacio.m),
        _Atajos(),
        SizedBox(height: Espacio.m),
        _ComprobarAntesDeSalir(),
        SizedBox(height: Espacio.m),
        ServidorDemo(),
        SizedBox(height: Espacio.m),
        _Galeria(),
      ],
    );
  }
}

class _CabeceraEquipo extends StatelessWidget {
  const _CabeceraEquipo();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const IconoTuTurno(TuIcono.panelTurnos, size: Espacio.xl + Espacio.xs, decorativo: true),
            const SizedBox(width: Espacio.s + Espacio.xs),
            Expanded(
              child: Semantics(header: true, child: Text('Para el equipo (demo)', style: tema.textTheme.headlineSmall)),
            ),
          ],
        ),
        const SizedBox(height: Espacio.xs),
        Text(
          'Solo sale al mantener pulsado el pie de Ajustes. Al volver a entrar, se esconde.',
          style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Un apartado del equipo: papel, título y contenido.
class _Apartado extends StatelessWidget {
  const _Apartado({required this.titulo, this.explicacion, required this.children});

  final String titulo;
  final String? explicacion;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final explicacion = this.explicacion;
    return PapelAjustes(
      child: Padding(
        padding: const EdgeInsets.all(Espacio.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SubtituloAjustes(titulo),
            if (explicacion != null) ...[
              const SizedBox(height: Espacio.xs),
              Text(explicacion, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: Espacio.m),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Pregunta antes de hacer algo que borra. true si se confirma.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String texto,
  required String accion,
}) async {
  final si = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(accion)),
      ],
    ),
  );
  return si ?? false;
}

/// «Preparar demo», «Empezar de cero» y los interruptores de la demo.
class _PrepararDemo extends ConsumerWidget {
  const _PrepararDemo();

  /// El diálogo de «Preparar demo», con lo que se va a cargar ([ejemplo]). Devuelve si se carga también el ticket de
  /// Sergio, o null si se cancela.
  Future<bool?> _confirmarPreparar(BuildContext context, Progreso ejemplo) {
    var conTicket = true;
    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('¿Preparar la demo?'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Se borra lo de este móvil y se carga el progreso de ejemplo: ${ejemplo.xp} XP, racha de '
                '${ejemplo.racha} días, ${ejemplo.leccionesCompletadas.length} lecciones y ${ejemplo.cartas.length} '
                'cartas. La bienvenida se salta y se ven los borradores. Los ajustes se quedan.',
              ),
              const SizedBox(height: Espacio.s),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: conTicket,
                onChanged: (valor) => setState(() => conTicket = valor ?? false),
                title: const Text('Con el ticket de Sergio'),
                subtitle: Text('${resumenTicket(entradaDemoSergio)}. $resumenMiTicketDeSergio'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(context).pop(conTicket), child: const Text('Preparar')),
          ],
        ),
      ),
    );
  }

  Future<void> _preparar(BuildContext context, WidgetRef ref) async {
    Hapticos.seleccion();
    final conTicket = await _confirmarPreparar(context, progresoDemo(ref.read(relojProvider)()));
    if (conTicket == null || !context.mounted) return;
    final router = GoRouter.of(context);
    final mensajero = ScaffoldMessenger.of(context);
    await prepararDemo(ref, conTicket: conTicket);
    final aviso = avisoDemoPreparada(ref.read(progresoProvider));
    Hapticos.toque();
    router.go('/');
    mensajero
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(aviso)));
  }

  Future<void> _deCero(BuildContext context, WidgetRef ref) async {
    Hapticos.seleccion();
    final si = await confirmar(
      context,
      titulo: '¿Empezar de cero?',
      texto:
          'Se borra lo de este móvil, como si alguien abriera TuTurno por primera vez: sin progreso, sin ticket y con '
          'la bienvenida. Los ajustes se quedan y se ven los borradores.',
      accion: 'Empezar de cero',
    );
    if (!si || !context.mounted) return;
    final router = GoRouter.of(context);
    final mensajero = ScaffoldMessenger.of(context);
    await empezarDeCero(ref);
    Hapticos.toque();
    router.go('/');
    mensajero
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(avisoComoNuevo)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(configProvider.select((c) => c.demo));
    return _Apartado(
      titulo: 'Preparar',
      explicacion: 'Pulsa «Preparar demo» antes de cada ensayo: así cada ronda empieza igual.',
      children: [
        FilledButton.icon(
          onPressed: () => _preparar(context, ref),
          icon: const IconoTuTurno(TuIcono.ticket, estilo: EstiloIcono.mono, decorativo: true),
          label: const Text('Preparar demo'),
        ),
        const SizedBox(height: Espacio.s),
        OutlinedButton.icon(
          onPressed: () => _deCero(context, ref),
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Empezar de cero'),
        ),
        const SizedBox(height: Espacio.s),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ver borradores'),
          subtitle: Text(
            demo
                ? 'Enseña también lo que aún no está validado, como «El juzgado por dentro».'
                : 'Solo funciona en una versión con DEMO=true.',
          ),
          value: ref.watch(mostrarBorradoresProvider),
          onChanged: (valor) {
            Hapticos.seleccion();
            ref.read(mostrarBorradoresProvider.notifier).cambiar(valor);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Usar siempre el ejemplo en Pregunta'),
          subtitle: const Text('Por si la red del recinto falla. Las respuestas salen marcadas como «Ejemplo».'),
          value: ref.watch(usarEjemploPreguntaProvider),
          onChanged: (valor) {
            Hapticos.seleccion();
            ref.read(usarEjemploPreguntaProvider.notifier).cambiar(valor);
          },
        ),
      ],
    );
  }
}

/// Atajos grandes, en el orden del guion.
class _Atajos extends ConsumerWidget {
  const _Atajos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Apartado(
      titulo: 'Atajos del guion',
      explicacion: 'Cada uno se abre encima del inicio: «atrás» vuelve al inicio.',
      children: [
        for (final atajo in AtajoDemo.values)
          Padding(
            padding: const EdgeInsets.only(bottom: Espacio.s),
            child: _BotonAtajo(
              atajo: atajo,
              onPressed: () {
                Hapticos.seleccion();
                unawaited(abrirAtajo(ref, GoRouter.of(context), atajo));
              },
            ),
          ),
      ],
    );
  }
}

class _BotonAtajo extends StatelessWidget {
  const _BotonAtajo({required this.atajo, required this.onPressed});

  final AtajoDemo atajo;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final tinta = tema.colorScheme.onSecondaryContainer;
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(Espacio.xxl + Espacio.m),
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: Espacio.m, vertical: Espacio.s + Espacio.xs),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.m)),
      ),
      child: Row(
        children: [
          IconoTuTurno(atajo.icono, estilo: EstiloIcono.mono, color: tinta, size: 28, decorativo: true),
          const SizedBox(width: Espacio.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  atajo.titulo,
                  style: tema.textTheme.titleMedium?.copyWith(color: tinta, fontWeight: FontWeight.w700),
                ),
                Text(atajo.detalle, style: tema.textTheme.bodyMedium?.copyWith(color: tinta)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// «Comprobar antes de salir»: una lista en verde o en rojo. No bloquea nada.
class _ComprobarAntesDeSalir extends ConsumerStatefulWidget {
  const _ComprobarAntesDeSalir();

  @override
  ConsumerState<_ComprobarAntesDeSalir> createState() => _ComprobarAntesDeSalirState();
}

class _ComprobarAntesDeSalirState extends ConsumerState<_ComprobarAntesDeSalir> {
  final _resultados = <Comprobacion, ResultadoComprobacion>{};
  var _comprobando = false;

  Future<void> _comprobar() async {
    Hapticos.seleccion();
    setState(() {
      _comprobando = true;
      for (final c in Comprobacion.values) {
        _resultados[c] = ResultadoComprobacion.comprobando;
      }
    });
    await Future.wait([
      for (final c in Comprobacion.values)
        comprobar(ref, c).then((resultado) {
          if (mounted) setState(() => _resultados[c] = resultado);
        }),
    ]);
    if (!mounted) return;
    Hapticos.toque();
    setState(() => _comprobando = false);
  }

  @override
  Widget build(BuildContext context) {
    return _Apartado(
      titulo: 'Comprobar antes de salir',
      explicacion: 'Red, servidor, voz de Pregunta, micrófono, voz en español, DEMO y el horario del 017.',
      children: [
        FilledButton.tonalIcon(
          onPressed: _comprobando ? null : _comprobar,
          icon: _comprobando
              ? const SizedBox.square(
                  dimension: Espacio.m + Espacio.xs,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const IconoTuTurno(TuIcono.check, estilo: EstiloIcono.mono, decorativo: true),
          label: Text(
            _comprobando
                ? 'Comprobando…'
                : _resultados.isEmpty
                ? 'Comprobar'
                : 'Comprobar otra vez',
          ),
        ),
        for (final c in Comprobacion.values)
          if (_resultados[c] case final resultado?) _FilaComprobacion(comprobacion: c, resultado: resultado),
      ],
    );
  }
}

class _FilaComprobacion extends StatelessWidget {
  const _FilaComprobacion({required this.comprobacion, required this.resultado});

  final Comprobacion comprobacion;
  final ResultadoComprobacion resultado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final (icono, color, estado) = switch (resultado.estado) {
      EstadoComprobacion.comprobando => (null, esquema.onSurfaceVariant, 'Comprobando'),
      EstadoComprobacion.bien => (TuIcono.check, context.colores.exito, 'Bien'),
      EstadoComprobacion.mal => (TuIcono.cruz, esquema.error, 'Falla'),
      EstadoComprobacion.noAplica => (TuIcono.info, esquema.onSurfaceVariant, 'No hace falta'),
    };
    return Padding(
      key: ValueKey('comprobacion-${comprobacion.name}'),
      padding: const EdgeInsets.only(top: Espacio.m),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: Espacio.l,
              child: icono == null
                  ? Semantics(
                      label: estado,
                      child: const Padding(
                        padding: EdgeInsets.all(Espacio.xs),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  : IconoTuTurno(icono, estilo: EstiloIcono.mono, color: color, semanticLabel: estado),
            ),
            const SizedBox(width: Espacio.s + Espacio.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(comprobacion.titulo, style: tema.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(resultado.detalle, style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurface)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El servidor (API_URL): la dirección de un túnel cambia cada vez que se reinicia, y así no hay que recompilar.
class ServidorDemo extends ConsumerStatefulWidget {
  const ServidorDemo({super.key});

  @override
  ConsumerState<ServidorDemo> createState() => _ServidorDemoState();
}

class _ServidorDemoState extends ConsumerState<ServidorDemo> {
  late final _url = TextEditingController(text: ref.read(ajustesProvider).apiUrlManual ?? '');
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  void _usar() {
    final url = _url.text.trim();
    if (!esUrlServidorValida(url)) {
      setState(() => _error = 'Escribe una dirección que empiece por http:// o https://');
      return;
    }
    if (Uri.parse(url).scheme == 'http' && soloHttps(esquemaPagina: kIsWeb ? Uri.base.scheme : '')) {
      setState(() => _error = 'En esta versión solo funciona https://');
      return;
    }
    setState(() => _error = null);
    FocusScope.of(context).unfocus();
    Hapticos.seleccion();
    unawaited(ref.read(ajustesProvider.notifier).actualizar((a) => a.copyWith(apiUrlManual: () => url)));
    _avisar('Listo. Ahora uso este servidor.');
  }

  void _volverAlDeSerie() {
    _url.clear();
    setState(() => _error = null);
    FocusScope.of(context).unfocus();
    Hapticos.seleccion();
    unawaited(ref.read(ajustesProvider.notifier).actualizar((a) => a.copyWith(apiUrlManual: () => null)));
    _avisar('Vuelvo a usar el servidor de serie.');
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final apiUrl = ref.watch(apiUrlProvider).trim();
    final simulado = ref.watch(configProvider.select((c) => c.useMock));
    return PapelAjustes(
      child: Theme(
        // Sin las líneas que ExpansionTile pinta al abrirse.
        data: tema.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radios.l))),
          collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radios.l))),
          tilePadding: const EdgeInsets.symmetric(horizontal: Espacio.l, vertical: Espacio.xs),
          childrenPadding: const EdgeInsets.fromLTRB(Espacio.l, 0, Espacio.l, Espacio.l),
          leading: const IconoTuTurno(TuIcono.web, size: Espacio.xl + Espacio.xs, decorativo: true),
          title: Text('Servidor (API_URL)', style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          subtitle: Text(apiUrl.isEmpty ? 'sin configurar' : apiUrl),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (simulado) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tinte(context, esquema.primary),
                  border: Border.all(color: bordeTinte(esquema.primary)),
                  borderRadius: BorderRadius.circular(Radios.s),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Espacio.s + Espacio.xs),
                  child: Text(
                    'Ahora mismo las respuestas son simuladas: la app está en modo de prueba y no usa ningún servidor.',
                    style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurface),
                  ),
                ),
              ),
              const SizedBox(height: Espacio.m),
            ],
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _usar(),
              decoration: InputDecoration(
                labelText: 'Dirección del servidor',
                hintText: 'https://…',
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: Espacio.m),
            FilledButton.tonalIcon(
              onPressed: _usar,
              icon: const IconoTuTurno(TuIcono.check, estilo: EstiloIcono.mono, decorativo: true),
              label: const Text('Usar este servidor'),
            ),
            const SizedBox(height: Espacio.s),
            const _ProbarConexion(),
            const SizedBox(height: Espacio.s),
            TextButton.icon(
              onPressed: _volverAlDeSerie,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Volver al de serie'),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Probar la conexión»: llama a /api/health y dice qué pasa con palabras claras (para montar la demo).
class _ProbarConexion extends ConsumerStatefulWidget {
  const _ProbarConexion();

  @override
  ConsumerState<_ProbarConexion> createState() => _ProbarConexionState();
}

class _ProbarConexionState extends ConsumerState<_ProbarConexion> {
  var _probando = false;
  String? _resultado;
  var _bien = false;

  Future<void> _probar() async {
    Hapticos.seleccion();
    setState(() {
      _probando = true;
      _resultado = null;
    });
    final simulado = ref.read(configProvider).useMock;
    String texto;
    var bien = false;
    try {
      final salud = await ref.read(apiProvider).health();
      bien = salud.estado == 'ok';
      texto = bien
          ? 'Conectado: el servidor responde${simulado ? ' (respuestas simuladas)' : ''}.'
          : 'El servidor responde, pero dice «${salud.estado}».';
    } on ApiException catch (e) {
      texto = pistaConexion(e.codigo);
    } catch (_) {
      texto = pistaConexion('');
    }
    if (!mounted) return;
    Hapticos.toque();
    setState(() {
      _probando = false;
      _resultado = texto;
      _bien = bien;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final resultado = _resultado;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _probando ? null : _probar,
          icon: _probando
              ? const SizedBox.square(
                  dimension: Espacio.m + Espacio.xs,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.wifi_tethering_rounded),
          label: Text(_probando ? 'Probando…' : 'Probar la conexión'),
        ),
        AnimatedSize(
          duration: duracionTamano(context, Duracion.media),
          alignment: Alignment.topCenter,
          child: resultado == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: Espacio.s),
                  child: Semantics(
                    liveRegion: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconoTuTurno(_bien ? TuIcono.check : TuIcono.cruz, decorativo: true),
                        const SizedBox(width: Espacio.s),
                        Expanded(
                          child: Text(
                            resultado,
                            key: const Key('resultado-conexion'),
                            style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// La galería de iconos y de Tut, para revisarlos en el móvil.
class _Galeria extends StatelessWidget {
  const _Galeria();

  void _abrir(BuildContext context) {
    Hapticos.seleccion();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Iconos de TuTurno')),
          body: const GaleriaIconos(animada: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _abrir(context),
      icon: const IconoTuTurno(TuIcono.estrella, estilo: EstiloIcono.mono, decorativo: true),
      label: const Text('Ver los iconos y a Tut'),
    );
  }
}
