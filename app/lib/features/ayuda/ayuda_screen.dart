import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/progreso.dart' show relojProvider;
import '../../core/recursos_ayuda.dart';
import '../../tema.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/modulos.dart';
import '../../widgets/movimiento/hapticos.dart';
import '../../widgets/tuturno_scaffold.dart';

const avisoLlamar = 'Llamar abre el teclado del teléfono con el número; tú decides si llamas.';

/// Solo en la web: el historial del navegador guarda la visita aunque se use «Salir rápido».
const avisoHistorialWeb =
    'En el navegador, el historial guarda que has entrado en TuTurno. Si no quieres que se vea, ábrelo en una ventana '
    'privada (o de incógnito).';

const textoAbierto = 'Abierto ahora';
const textoCerrado = 'Cerrado ahora';

/// Lo que se propone cuando un recurso con horario (el 017) está cerrado: ANAR, a cualquier hora, o el 112.
const textoAlternativa = 'Mientras, ANAR te atiende a cualquier hora. Si estás en peligro, llama al 112.';
const textoLlamarAnar = 'Llamar a ANAR';

/// Cuándo vuelve a abrir un recurso con horario, p. ej. «Abre a las 8:00.». Que está cerrado ya lo dice la pastilla.
String textoAbre(Horario horario) => 'Abre a las ${horario.textoApertura}.';

/// ANAR atiende a cualquier hora: es la alternativa cuando el 017 está cerrado.
final _anar = recursosAyuda.firstWhere((r) => r.telefono == '900 20 20 10');

/// Ayuda (sección 4.5): tranquila, pero imposible de no ver. Arriba, el 112; después, todos los recursos.
class AyudaScreen extends StatelessWidget {
  const AyudaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final urgentes = recursosAyuda.where((r) => r.urgente).toList();
    final resto = recursosAyuda.where((r) => !r.urgente).toList();
    var orden = 0;
    return TuTurnoScaffold(
      titulo: 'Ayuda',
      mostrarAyuda: false,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: anchoMaximo),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.m, Espacio.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final recurso in urgentes) ...[
                  Entrada(
                    orden: orden++,
                    child: _BloquePeligro(recurso: recurso),
                  ),
                  const SizedBox(height: Espacio.l),
                ],
                Entrada(
                  orden: orden++,
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Teléfonos y webs que te ayudan',
                      style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: Espacio.s),
                Entrada(
                  orden: orden++,
                  child: _Linea(icono: Icons.dialpad_rounded, texto: avisoLlamar),
                ),
                const SizedBox(height: Espacio.m),
                for (final recurso in resto) ...[
                  Entrada(
                    orden: orden++,
                    child: _TarjetaRecurso(recurso: recurso),
                  ),
                  const SizedBox(height: Espacio.m),
                ],
                const SizedBox(height: Espacio.s),
                Entrada(orden: orden++, child: const _TarjetaAdulto()),
                // En la web, «Salir rápido» quita TuTurno de la pestaña, pero el historial del navegador guarda la visita.
                if (kIsWeb) ...[
                  const SizedBox(height: Espacio.m),
                  Entrada(
                    orden: orden++,
                    child: const _Linea(icono: Icons.history_rounded, texto: avisoHistorialWeb),
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

/// Abre el marcador (o la web). Si no se puede, enseña el número para marcarlo a mano.
Future<void> _abrir(BuildContext context, RecursoAyuda recurso) async {
  Hapticos.toque();
  final avisos = ScaffoldMessenger.of(context);
  final abierto = await abrirRecurso(recurso);
  if (abierto) return;
  final telefono = recurso.telefono;
  _avisar(
    avisos,
    telefono != null
        ? 'No he podido abrir el teléfono. Marca el $telefono.'
        : 'No he podido abrir la web. Búscala en ${recurso.web}',
  );
}

String _textoBoton(RecursoAyuda recurso) =>
    recurso.telefono != null ? 'Llamar al ${recurso.telefonoVisible}' : 'Abrir la web';

/// Abre el chat del recurso. Si no se puede, enseña la dirección.
Future<void> _abrirChat(BuildContext context, RecursoAyuda recurso) async {
  Hapticos.toque();
  final avisos = ScaffoldMessenger.of(context);
  if (await abrirChat(recurso)) return;
  _avisar(avisos, 'No he podido abrir el chat. Búscalo en ${recurso.chat}');
}

/// Abre WhatsApp. Si no se puede, enseña el número para escribir a mano.
Future<void> _abrirWhatsapp(BuildContext context, RecursoAyuda recurso) async {
  Hapticos.toque();
  final avisos = ScaffoldMessenger.of(context);
  if (await abrirWhatsapp(recurso)) return;
  _avisar(avisos, 'No he podido abrir WhatsApp. Escribe al ${recurso.whatsapp}.');
}

void _avisar(ScaffoldMessengerState avisos, String texto) {
  avisos
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

/// Texto e iconos encima de [fondo]: blanco sobre un color oscuro y negro sobre uno claro. Así el bloque del 112
/// sigue leyéndose bien aunque cambie el color de Ayuda de la paleta.
Color _colorSobre(Color fondo) =>
    ThemeData.estimateBrightnessForColor(fondo) == Brightness.dark ? Colors.white : Colors.black;

class _BloquePeligro extends StatelessWidget {
  const _BloquePeligro({required this.recurso});

  final RecursoAyuda recurso;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final rojo = context.colores.ayuda;
    final sobreRojo = _colorSobre(rojo);
    final forma = BorderRadius.circular(Radios.l);
    return DecoratedBox(
      decoration: BoxDecoration(color: rojo, borderRadius: forma, boxShadow: sombraDe(context, [rojo, rojo])),
      child: Padding(
        padding: const EdgeInsets.all(Espacio.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: Espacio.xxl,
                    height: Espacio.xxl,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: sobreRojo.withValues(alpha: 0.2)),
                    child: Icon(recurso.icono, color: sobreRojo),
                  ),
                ),
                const SizedBox(width: Espacio.m),
                Expanded(
                  child: Text(
                    recurso.nombre,
                    style: tema.textTheme.titleMedium?.copyWith(color: sobreRojo, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espacio.m),
            Semantics(
              header: true,
              child: Text(
                '¿Estás en peligro ahora?',
                style: tema.textTheme.headlineSmall?.copyWith(color: sobreRojo, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: Espacio.s),
            Text(
              'Llama al ${recurso.telefono ?? ''}. Es gratis y te atienden a cualquier hora.',
              style: tema.textTheme.bodyLarge?.copyWith(color: sobreRojo),
            ),
            const SizedBox(height: Espacio.m + Espacio.xs),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: sobreRojo,
                foregroundColor: rojo,
                minimumSize: const Size.fromHeight(Espacio.xxl + Espacio.s),
              ),
              onPressed: () => _abrir(context, recurso),
              icon: const Icon(Icons.call_rounded),
              label: Text(_textoBoton(recurso)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaRecurso extends ConsumerStatefulWidget {
  const _TarjetaRecurso({required this.recurso});

  final RecursoAyuda recurso;

  @override
  ConsumerState<_TarjetaRecurso> createState() => _TarjetaRecursoState();
}

class _TarjetaRecursoState extends ConsumerState<_TarjetaRecurso> {
  Timer? _reloj;
  AppLifecycleListener? _ciclo;

  @override
  void initState() {
    super.initState();
    // Con horario (el 017), «Abierto ahora» o «Cerrado ahora» se vuelve a mirar cada minuto y al volver a la app: si la
    // pantalla sigue abierta a las 23:00, deja de proponer el 017 como principal y propone ANAR.
    if (widget.recurso.horario != null) {
      _reloj = Timer.periodic(const Duration(minutes: 1), (_) => _actualizar());
      _ciclo = AppLifecycleListener(onResume: _actualizar);
    }
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _ciclo?.dispose();
    super.dispose();
  }

  void _actualizar() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final recurso = widget.recurso;
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final telefono = recurso.telefonoVisible;
    final web = recurso.webVisible;
    final horario = recurso.horario;
    final abierto = horario == null || horario.abierto(ref.watch(relojProvider)());
    final conBorde = _estiloConBorde(context);
    final destacado = tema.textTheme.titleLarge?.copyWith(color: esquema.primary, fontWeight: FontWeight.w700);
    final titulos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(recurso.nombre, style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        // El número, en grande y siempre en una línea: si no cabe, se encoge un poco antes que partirse.
        if (telefono != null)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(telefono, maxLines: 1, softWrap: false, style: destacado),
          )
        // Una web: su dirección, para saber adónde lleva y poder escribirla a mano.
        else if (web != null)
          Text(
            web,
            style: tema.textTheme.titleSmall?.copyWith(color: esquema.primary, fontWeight: FontWeight.w700),
          ),
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Espacio.m + Espacio.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Con letra grande, el icono va encima: así el número tiene todo el ancho.
            if (letraGrande(context)) ...[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconoSuave(icono: recurso.icono),
              ),
              const SizedBox(height: Espacio.s + Espacio.xs),
              titulos,
            ] else
              Row(
                children: [
                  IconoSuave(icono: recurso.icono),
                  const SizedBox(width: Espacio.m),
                  Expanded(child: titulos),
                ],
              ),
            // El horario y si ahora atiende, de un vistazo, debajo del número.
            if (horario != null) ...[
              const SizedBox(height: Espacio.s + Espacio.xs),
              _Horario(horario: horario, abierto: abierto),
            ],
            const SizedBox(height: Espacio.s + Espacio.xs),
            Text(recurso.descripcion, style: tema.textTheme.bodyLarge),
            for (final nota in recurso.notas) ...[const SizedBox(height: Espacio.s), _Nota(nota: nota)],
            // Cerrado: a quién llamar mientras tanto, justo antes de sus botones.
            if (horario != null && !abierto) ...[const SizedBox(height: Espacio.m), _Cerrado(horario: horario)],
            const SizedBox(height: Espacio.m),
            if (telefono != null && abierto)
              FilledButton.icon(
                onPressed: () => _abrir(context, recurso),
                icon: const Icon(Icons.call_rounded),
                label: Text(_textoBoton(recurso)),
              )
            // Cerrado: el botón sigue (la persona decide), pero sin destacar; lo destacado es la alternativa.
            else if (telefono != null)
              OutlinedButton.icon(
                style: conBorde,
                onPressed: () => _abrir(context, recurso),
                icon: const Icon(Icons.call_rounded),
                label: Text(_textoBoton(recurso)),
              )
            else
              FilledButton.tonalIcon(
                onPressed: () => _abrir(context, recurso),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(_textoBoton(recurso)),
              ),
            // Para escribir en vez de llamar: si te da vergüenza o no puedes hablar sin que te oigan.
            if (recurso.chat != null) ...[
              const SizedBox(height: Espacio.s),
              OutlinedButton.icon(
                key: ValueKey('chat-${recurso.nombre}'),
                style: conBorde,
                onPressed: () => _abrirChat(context, recurso),
                icon: const Icon(Icons.chat_rounded),
                label: const Text('Escribir por chat'),
              ),
            ],
            if (recurso.whatsapp != null) ...[
              const SizedBox(height: Espacio.s),
              OutlinedButton.icon(
                key: ValueKey('whatsapp-${recurso.nombre}'),
                style: conBorde,
                onPressed: () => _abrirWhatsapp(context, recurso),
                icon: const Icon(Icons.chat_rounded),
                label: const Text('Escribir por WhatsApp'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Los botones con borde del tema no tienen margen vertical: con letra grande, una etiqueta de dos líneas tocaría el
/// borde. Llevan el mismo margen que los botones rellenos del tema.
ButtonStyle? _estiloConBorde(BuildContext context) {
  final margen = Theme.of(context).filledButtonTheme.style?.padding;
  return margen == null ? null : ButtonStyle(padding: margen);
}

/// El horario y si ahora atiende, en dos pastillas. Se lee de una vez: «Horario: … Abierto ahora».
class _Horario extends StatelessWidget {
  const _Horario({required this.horario, required this.abierto});

  final Horario horario;
  final bool abierto;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final estado = abierto ? textoAbierto : textoCerrado;
    return Semantics(
      container: true,
      label: 'Horario: ${horario.texto}. $estado.',
      child: ExcludeSemantics(
        child: Wrap(
          spacing: Espacio.s,
          runSpacing: Espacio.s,
          children: [
            _Pastilla(
              icono: Icon(Icons.schedule_rounded, size: Espacio.m + Espacio.xs / 2, color: esquema.onSurfaceVariant),
              texto: horario.texto,
            ),
            _Pastilla(
              icono: abierto
                  ? _Punto(color: context.colores.exito)
                  : Icon(Icons.bedtime_rounded, size: Espacio.m + Espacio.xs / 2, color: esquema.onSurfaceVariant),
              texto: estado,
              destacada: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _Pastilla extends StatelessWidget {
  const _Pastilla({required this.icono, required this.texto, this.destacada = false});

  final Widget icono;
  final String texto;
  final bool destacada;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: esquema.surfaceContainerHighest,
        shape: StadiumBorder(side: BorderSide(color: esquema.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Espacio.s + Espacio.xs, vertical: Espacio.xs + Espacio.xs / 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icono,
            const SizedBox(width: Espacio.xs + Espacio.xs / 2),
            Flexible(
              child: Text(
                texto,
                style: tema.textTheme.labelLarge?.copyWith(
                  color: esquema.onSurface,
                  fontWeight: destacada ? FontWeight.w700 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Punto de color de «abierto ahora».
class _Punto extends StatelessWidget {
  const _Punto({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    const tamano = Espacio.s + Espacio.xs / 2;
    return Padding(
      padding: const EdgeInsets.all(Espacio.xs / 2),
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

/// Panel suave dentro de la pantalla: se distingue del fondo y de las tarjetas en los dos temas.
BoxDecoration _panel(ColorScheme esquema, double radio) => BoxDecoration(
  color: esquema.surfaceContainerHigh,
  border: Border.all(color: esquema.outlineVariant),
  borderRadius: BorderRadius.circular(radio),
);

/// Fuera de horario: cuándo abre y a quién llamar mientras (ANAR o el 112). Que está cerrado ya lo dice la pastilla
/// del horario; aquí, lo que puedes hacer ahora. ANAR pasa a ser el botón principal de la tarjeta.
class _Cerrado extends StatelessWidget {
  const _Cerrado({required this.horario});

  final Horario horario;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return DecoratedBox(
      key: const Key('ayuda-cerrado'),
      decoration: _panel(esquema, Radios.m),
      child: Padding(
        padding: const EdgeInsets.all(Espacio.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    textoAbre(horario),
                    style: tema.textTheme.titleSmall?.copyWith(color: esquema.onSurface, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: Espacio.xs),
                  Text(textoAlternativa, style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurface)),
                ],
              ),
            ),
            const SizedBox(height: Espacio.s + Espacio.xs),
            FilledButton.icon(
              onPressed: () => _abrir(context, _anar),
              icon: const Icon(Icons.support_agent_rounded),
              label: const Text(textoLlamarAnar),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aclaración de un recurso: el icono ayuda a verla de un vistazo, pero el texto se entiende solo.
class _Nota extends StatelessWidget {
  const _Nota({required this.nota});

  final NotaRecurso nota;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final (icono, color) = switch (nota.tipo) {
      TipoNota.sirve => (Icons.check_circle_rounded, context.colores.exito),
      TipoNota.noSirve => (Icons.do_not_disturb_on_rounded, esquema.error),
      TipoNota.info => (Icons.info_rounded, esquema.primary),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.only(top: Espacio.xs / 4),
            child: Icon(icono, size: Espacio.l - Espacio.xs, color: color),
          ),
        ),
        const SizedBox(width: Espacio.s),
        Expanded(
          child: Text(nota.texto, style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurface)),
        ),
      ],
    );
  }
}

class _TarjetaAdulto extends StatelessWidget {
  const _TarjetaAdulto();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return DecoratedBox(
      decoration: _panel(esquema, Radios.l),
      child: Padding(
        padding: const EdgeInsets.all(Espacio.l),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconoSuave(icono: Icons.diversity_3_rounded, fondo: esquema.surface, color: esquema.primary),
            const SizedBox(width: Espacio.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No estás solo ni sola',
                    style: tema.textTheme.titleMedium?.copyWith(color: esquema.onSurface, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: Espacio.xs),
                  Text(mensajeAdultoDeConfianza, style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurface)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = tema.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(icono, size: Espacio.l - Espacio.xs, color: color),
        ),
        const SizedBox(width: Espacio.s),
        Expanded(
          child: Text(texto, style: tema.textTheme.bodyMedium?.copyWith(color: color)),
        ),
      ],
    );
  }
}
