import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/entrada.dart';
import '../../core/mis_preguntas.dart';
import '../../core/texto.dart';
import '../../tema.dart';
import '../../widgets/iconos/iconos.dart';
import '../../widgets/modulos.dart' show anchoMaximo;
import '../../widgets/movimiento/hapticos.dart';
import '../../widgets/tuturno_scaffold.dart';
import '../pasos/fuentes_paso.dart';
import '../situacion/contenido.dart';
import '../situacion/mi_ticket.dart';
import '../situacion/personalizacion.dart' show ideasParaTi, rutaSituacionDe;
import 'textos.dart';

/// Mis preguntas (/mis-preguntas, plan v2, producto §5.2): lo que quieres pedir (apuntado desde los pasos y los
/// derechos de Mi situación, con de dónde viene y su fuente, sin reescribirlo) y lo que quieres preguntar (escrito por
/// ti o elegido de las ideas), para enseñárselo a las personas que llevan tu caso. Tienes derecho a que te lo
/// expliquen con palabras que entiendas (LO 1/1996, art. 9.1).
///
/// Todo se guarda solo en este móvil (misPreguntasProvider): nunca se envía a ningún sitio ni va a los logs. Un
/// recordatorio fijo pide escribir solo la duda, no lo que pasó.
class MisPreguntasScreen extends ConsumerStatefulWidget {
  const MisPreguntasScreen({super.key});

  @override
  ConsumerState<MisPreguntasScreen> createState() => _MisPreguntasScreenState();
}

class _MisPreguntasScreenState extends ConsumerState<MisPreguntasScreen> {
  final _duda = TextEditingController();
  final _foco = FocusNode();

  @override
  void dispose() {
    _duda.dispose();
    _foco.dispose();
    super.dispose();
  }

  MisPreguntasNotifier get _notas => ref.read(misPreguntasProvider.notifier);

  void _avisar(String texto) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  /// Apunta [texto] en «Quiero preguntar». Dice por qué no si ya está o si no caben más.
  bool _apuntarPregunta(String texto) {
    if (texto.trim().isEmpty) return false;
    if (_notas.contiene(texto)) {
      _avisar(textoRepetida);
      return false;
    }
    if (!_notas.apuntar(texto, tipo: TipoApunte.preguntar)) {
      _avisar(textoMaximo);
      return false;
    }
    Hapticos.seleccion();
    return true;
  }

  void _anadirEscrita() {
    if (_apuntarPregunta(_duda.text)) {
      _duda.clear();
      _avisar(textoApuntada);
    }
  }

  Future<void> _borrarTodas() async {
    final borrar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text(confirmarBorrarTodas),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text(botonCancelar)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text(botonBorrar)),
        ],
      ),
    );
    if (borrar != true || !mounted) return;
    await _notas.borrarTodas();
    if (mounted) _avisar(textoBorradas);
  }

  Future<void> _editar(Apunte apunte) async {
    final nuevo = await showDialog<String>(
      context: context,
      builder: (context) => _DialogoEditar(texto: apunte.texto),
    );
    if (nuevo == null || !mounted) return;
    final clave = normalizar(limpiarApunte(nuevo));
    final repetida = ref
        .read(misPreguntasProvider)
        .any((a) => a.id != apunte.id && normalizar(limpiarApunte(a.texto)) == clave);
    if (repetida) {
      _avisar(textoRepetida);
      return;
    }
    _notas.editar(apunte.id, nuevo);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final apuntes = ref.watch(misPreguntasProvider);
    final pedir = [
      for (final a in apuntes)
        if (a.tipo == TipoApunte.pedir) a,
    ];
    final preguntar = [
      for (final a in apuntes)
        if (a.tipo == TipoApunte.preguntar) a,
    ];
    final contenido = ref.watch(contenidoSituacionProvider).value ?? const ContenidoSituacion();
    final paraTi = ideasParaTi(contenido, ref.watch(miTicketProvider));
    final ruta = rutaSituacionDe(ref.watch(entradaProvider)) ?? '/situacion/elegir';
    return TuTurnoScaffold(
      titulo: tituloMisPreguntas,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.m, Espacio.m),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: anchoMaximo),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: apuntes.isEmpty ? null : () => context.push('/mis-preguntas/ensenar'),
                  icon: const IconoTuTurno(TuIcono.pregunta, estilo: EstiloIcono.mono, decorativo: true),
                  label: const Text(botonEnsenar),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: anchoMaximo),
          // Todo construido de una vez (como mucho 30 apuntes): el lector de pantalla lo recorre entero.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.m, Espacio.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(entradillaMisPreguntas, style: tema.textTheme.bodyLarge),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ChipFuentePaso(cita: CitaPaso.desdeTexto(fuenteEntradilla), paso: tituloMisPreguntas),
                ),
                if (apuntes.isEmpty) ...[
                  const SizedBox(height: Espacio.s),
                  Text(vacioTodo, style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurfaceVariant)),
                ],
                const SizedBox(height: Espacio.l),
                const _Encabezado(texto: seccionPedir, icono: TuIcono.manoAlzada),
                const SizedBox(height: Espacio.s),
                if (pedir.isEmpty) ...[
                  Text(vacioPedir, style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(onPressed: () => context.push(ruta), child: const Text(botonIrMiSituacion)),
                  ),
                ],
                for (final apunte in pedir)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Espacio.s),
                    child: _TarjetaApunte(
                      key: ValueKey(apunte.id),
                      apunte: apunte,
                      alMarcar: (hecho) => _notas.marcar(apunte.id, hecho),
                      alQuitar: () => _notas.quitar(apunte.id),
                    ),
                  ),
                const SizedBox(height: Espacio.l),
                const _Encabezado(texto: seccionPreguntar, icono: TuIcono.pregunta),
                const SizedBox(height: Espacio.s),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _duda,
                        focusNode: _foco,
                        maxLength: maxCaracteresApunte,
                        minLines: 1,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _anadirEscrita(),
                        decoration: const InputDecoration(labelText: pistaDuda),
                      ),
                    ),
                    const SizedBox(width: Espacio.s),
                    Padding(
                      padding: const EdgeInsets.only(top: Espacio.xs),
                      child: FilledButton(onPressed: _anadirEscrita, child: const Text(botonAnadir)),
                    ),
                  ],
                ),
                // El recordatorio fijo: siempre a la vista, no desaparece al escribir.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconoTuTurno(
                      TuIcono.candado,
                      size: Espacio.m + 2,
                      estilo: EstiloIcono.mono,
                      color: esquema.onSurfaceVariant,
                      decorativo: true,
                    ),
                    const SizedBox(width: Espacio.s),
                    Expanded(
                      child: Text(
                        recordatorioDuda,
                        style: tema.textTheme.bodyMedium?.copyWith(
                          color: esquema.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Espacio.s),
                // Tus dudas, justo debajo del campo; las ideas, después.
                if (preguntar.isEmpty)
                  Text(vacioPreguntar, style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
                for (final apunte in preguntar)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Espacio.s),
                    child: _TarjetaApunte(
                      key: ValueKey(apunte.id),
                      apunte: apunte,
                      alMarcar: (hecho) => _notas.marcar(apunte.id, hecho),
                      alQuitar: () => _notas.quitar(apunte.id),
                      alEditar: () => _editar(apunte),
                    ),
                  ),
                const SizedBox(height: Espacio.s),
                // Con clave: al apuntar, la lista de arriba cambia de largo y, sin ella, el desplegable se cerraría solo. Si
                // cambia [abierta] (al llegar las ideas para ti), empieza otra vez como toca.
                _Ideas(
                  key: ValueKey('ideas-${paraTi.isEmpty}'),
                  titulo: tituloIdeas,
                  ideas: ideasPreguntas,
                  alElegir: _apuntarPregunta,
                  abierta: paraTi.isEmpty,
                ),
                if (paraTi.isNotEmpty) ...[
                  const SizedBox(height: Espacio.s),
                  _Ideas(
                    key: const ValueKey('ideas-para-ti'),
                    titulo: tituloIdeasParaTi,
                    ideas: paraTi,
                    alElegir: _apuntarPregunta,
                    abierta: true,
                  ),
                ],
                if (apuntes.isNotEmpty) ...[
                  const SizedBox(height: Espacio.l),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: _borrarTodas,
                      icon: const IconoTuTurno(TuIcono.cerrar, estilo: EstiloIcono.mono, decorativo: true),
                      label: const Text(botonBorrarTodas),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.texto, required this.icono});

  final String texto;
  final TuIcono icono;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Semantics(
      header: true,
      child: Row(
        children: [
          IconoTuTurno(icono, size: Espacio.l + Espacio.xs, decorativo: true),
          const SizedBox(width: Espacio.s),
          Expanded(
            child: Text(texto, style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

/// Las ideas de preguntas, en un desplegable: cada una se apunta con un toque (y se ve marcada si ya está).
class _Ideas extends ConsumerWidget {
  const _Ideas({super.key, required this.titulo, required this.ideas, required this.alElegir, this.abierta = false});

  final String titulo;
  final List<String> ideas;
  final bool Function(String idea) alElegir;
  final bool abierta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    ref.watch(misPreguntasProvider);
    final notas = ref.read(misPreguntasProvider.notifier);
    return Card(
      child: ExpansionTile(
        initiallyExpanded: abierta,
        leading: IconoTuTurno(TuIcono.idea, estilo: EstiloIcono.mono, color: esquema.primary, decorativo: true),
        title: Text(titulo, style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(Espacio.s, 0, Espacio.s, Espacio.s),
        children: [
          for (final idea in ideas) _Idea(texto: idea, apuntada: notas.contiene(idea), alElegir: () => alElegir(idea)),
        ],
      ),
    );
  }
}

class _Idea extends StatelessWidget {
  const _Idea({required this.texto, required this.apuntada, required this.alElegir});

  final String texto;
  final bool apuntada;
  final VoidCallback alElegir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Semantics(
      button: !apuntada,
      label: apuntada ? '$texto. Ya está apuntada' : texto,
      onTapHint: apuntada ? null : 'apuntar en Quiero preguntar',
      excludeSemantics: true,
      child: InkWell(
        onTap: apuntada ? null : alElegir,
        borderRadius: BorderRadius.circular(Radios.s),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Espacio.xxl),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Espacio.s, vertical: Espacio.xs),
            child: Row(
              children: [
                Expanded(child: Text(texto, style: tema.textTheme.bodyLarge)),
                const SizedBox(width: Espacio.s),
                apuntada
                    ? IconoTuTurno(
                        TuIcono.check,
                        estilo: EstiloIcono.mono,
                        color: context.colores.exito,
                        decorativo: true,
                      )
                    : Icon(Icons.add_circle_outline_rounded, color: esquema.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Un apunte: «Ya lo he preguntado», el texto, de dónde viene y sus fuentes (pequeñas), y un menú para quitarlo (y
/// editarlo, si es tuyo: lo apuntado desde Mi situación no se reescribe).
class _TarjetaApunte extends StatelessWidget {
  const _TarjetaApunte({
    super.key,
    required this.apunte,
    required this.alMarcar,
    required this.alQuitar,
    this.alEditar,
  });

  final Apunte apunte;
  final ValueChanged<bool> alMarcar;
  final VoidCallback alQuitar;
  final VoidCallback? alEditar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final colores = context.colores;
    final origen = apunte.origen;
    final citas = CitaPaso.de(apunte.fuentes);
    final alEditar = this.alEditar;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colores.ticket,
        borderRadius: BorderRadius.circular(Radios.m),
        border: Border.all(color: apunte.hecho ? colores.exito : esquema.outlineVariant, width: apunte.hecho ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Espacio.xs, Espacio.xs, 0, Espacio.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: apunte.hecho,
              semanticLabel: textoYaPreguntado,
              onChanged: (valor) {
                HapticFeedback.selectionClick();
                alMarcar(valor ?? false);
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Espacio.s + 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apunte.texto,
                      style: tema.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colores.tintaTicket,
                      ),
                    ),
                    if (origen != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Espacio.xs),
                        child: Text(
                          textoOrigen(origen),
                          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                        ),
                      ),
                    if (citas.isNotEmpty)
                      Semantics(
                        label: 'Fuentes: ${[for (final c in citas) c.etiquetaLector].join('; ')}',
                        excludeSemantics: true,
                        child: Text(
                          [for (final c in citas) c.etiqueta].join(' · '),
                          style: tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant),
                        ),
                      ),
                    if (apunte.hecho)
                      Padding(
                        padding: const EdgeInsets.only(top: Espacio.xs),
                        child: Text(
                          textoYaPreguntado,
                          style: tema.textTheme.labelMedium?.copyWith(
                            color: colores.exito,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Más opciones',
              icon: Icon(Icons.more_vert_rounded, color: esquema.onSurfaceVariant),
              onSelected: (accion) => accion == 'editar' ? alEditar?.call() : alQuitar(),
              itemBuilder: (context) => [
                if (alEditar != null) const PopupMenuItem(value: 'editar', child: Text(textoEditar)),
                const PopupMenuItem(value: 'quitar', child: Text(textoQuitar)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Editar una duda propia (con el mismo recordatorio).
class _DialogoEditar extends StatefulWidget {
  const _DialogoEditar({required this.texto});

  final String texto;

  @override
  State<_DialogoEditar> createState() => _DialogoEditarState();
}

class _DialogoEditarState extends State<_DialogoEditar> {
  late final _controlador = TextEditingController(text: widget.texto);

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(textoEditar),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controlador,
            autofocus: true,
            maxLength: maxCaracteresApunte,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(labelText: pistaDuda),
          ),
          Text(recordatorioDuda, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(botonCancelar)),
        FilledButton(onPressed: () => Navigator.of(context).pop(_controlador.text), child: const Text('Guardar')),
      ],
    );
  }
}
