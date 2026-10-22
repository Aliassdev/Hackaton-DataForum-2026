import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entrada.dart';
import '../../tema.dart';
import '../../widgets/iconos/iconos.dart';
import '../../widgets/modulos.dart' show anchoMaximo;
import '../../widgets/movimiento/hapticos.dart';
import '../../widgets/movimiento/ticket.dart';
import '../../widgets/tuturno_scaffold.dart';
import '../pasos/personalizacion_linea.dart' show EstiloExplicacion;
import 'mi_ticket.dart';
import 'papel.dart';
import 'personalizacion.dart' show resumenTicket;

// «Tu ticket» de Mi situación (plan v2, producto §5.1, ampliado): la edad, el tipo de proceso, el papel y el momento
// (el ticket de la app, entradaProvider) y, además, con quién irás, qué te preocupa más y cómo prefieres que te lo
// cuente (miTicketProvider). Todo es opcional y se puede saltar o borrar. Nunca se pregunta qué pasó.

const tituloTuTicket = 'Tu ticket';
const textoTuTicket =
    'Si me cuentas un poco, te lo explico mejor. Todo es opcional. No te pido tu nombre ni lo que pasó.';
const notaPrivacidadTicket =
    'Tu ticket se guarda en este móvil. Cuando preguntas en Pregunta, la edad, el tipo de proceso, el papel y el '
    'momento se envían, sin tu nombre, para adaptar las respuestas. Lo demás (con quién irás, lo que te preocupa y tu '
    'día) no sale de este móvil. Puedes borrarlo cuando quieras.';
const textoGuardadoTicket = 'Listo. Tu guía ya está adaptada a ti.';
const textoBorradoTicket = 'Hecho. Tu ticket está vacío.';
const botonGuardarTicket = 'Guardar';
const botonBorrarTicket = 'Borrar mis respuestas';

/// Abre «Tu ticket» encima de la pantalla actual. Devuelve el papel del ticket guardado (para llevar a su camino), o
/// null si no se guarda o si el ticket no dice papel. Con [papelSugerido], el papel viene marcado si no había otro.
Future<PapelSituacion?> abrirTuTicket(BuildContext context, {PapelSituacion? papelSugerido}) {
  final quieto = MediaQuery.disableAnimationsOf(context);
  return Navigator.of(context).push<PapelSituacion?>(
    PageRouteBuilder<PapelSituacion?>(
      transitionDuration: quieto ? Duration.zero : Duracion.larga,
      reverseTransitionDuration: quieto ? Duration.zero : Duracion.media,
      pageBuilder: (context, _, _) => TuTicketScreen(papelSugerido: papelSugerido),
      transitionsBuilder: (context, animacion, _, child) {
        final curva = CurvedAnimation(parent: animacion, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curva,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(curva),
            child: child,
          ),
        );
      },
    ),
  );
}

class TuTicketScreen extends ConsumerStatefulWidget {
  const TuTicketScreen({super.key, this.papelSugerido});

  final PapelSituacion? papelSugerido;

  @override
  ConsumerState<TuTicketScreen> createState() => _TuTicketScreenState();
}

class _TuTicketScreenState extends ConsumerState<TuTicketScreen> {
  late final Entrada _inicial = ref.read(entradaProvider);
  late final MiTicket _ticketInicial = ref.read(miTicketProvider);

  late int? _edad = _inicial.edad;
  late Procedimiento? _procedimiento = _inicial.procedimiento;
  late RolEntrada? _rol = _rolPosible(_inicial.rol ?? widget.papelSugerido?.rolEntrada, _edad);
  late Fase? _fase = _inicial.fase;
  late Set<Acompanante> _conQuien = {..._ticketInicial.conQuien};
  late Set<Preocupacion> _preocupaciones = {..._ticketInicial.preocupaciones};
  late EstiloExplicacion? _estilo = _ticketInicial.estilo;

  bool get _hayAlgoGuardado => !_inicial.vacia || !_ticketInicial.sinRespuestas;

  /// [rol], salvo «Investigado» con menos de 14 años (la misma regla que la hoja del perfil de Pregunta:
  /// [puedeSerInvestigado]).
  static RolEntrada? _rolPosible(RolEntrada? rol, int? edad) =>
      rol == RolEntrada.investigado && !puedeSerInvestigado(edad) ? null : rol;

  void _elegirEdad(int? edad) => setState(() {
    _edad = edad;
    _rol = _rolPosible(_rol, edad);
  });

  Entrada get _entrada => Entrada(edad: _edad, procedimiento: _procedimiento, rol: _rol, fase: _fase);

  Future<void> _guardar() async {
    Hapticos.toque();
    final entrada = _entrada;
    ref
        .read(miTicketProvider.notifier)
        .guardarRespuestas(conQuien: _conQuien, preocupaciones: _preocupaciones, estilo: _estilo);
    final mensajes = ScaffoldMessenger.maybeOf(context);
    final navegador = Navigator.of(context);
    if (entrada.vacia) {
      await ref.read(entradaProvider.notifier).borrar();
    } else {
      await ref.read(entradaProvider.notifier).guardar(entrada);
    }
    mensajes?.showSnackBar(const SnackBar(content: Text(textoGuardadoTicket)));
    if (mounted) navegador.pop(PapelSituacion.deEntrada(entrada.rol));
  }

  Future<void> _borrar() async {
    Hapticos.toque();
    final mensajes = ScaffoldMessenger.maybeOf(context);
    final navegador = Navigator.of(context);
    await ref.read(miTicketProvider.notifier).borrarRespuestas();
    await ref.read(entradaProvider.notifier).borrar();
    mensajes?.showSnackBar(const SnackBar(content: Text(textoBorradoTicket)));
    if (mounted) navegador.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final resumen = resumenTicket(_entrada);
    return TuTurnoScaffold(
      titulo: tituloTuTicket,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.m, Espacio.m),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: anchoMaximo),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _guardar, child: const Text(botonGuardarTicket)),
              ),
            ),
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: anchoMaximo),
          // Todo construido de una vez (es corto): el lector de pantalla lo recorre entero.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.m, Espacio.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TicketTuTurno(
                  etiqueta: 'Para tu guía',
                  titulo: tituloTuTicket,
                  descripcion: resumen.isEmpty ? 'Sin rellenar' : resumen,
                  icono: const IconoTuTurno(TuIcono.ticket, size: 44, decorativo: true),
                  talon: const MascotaTut(size: 56, animada: false, decorativo: true),
                  tamanoTalon: Espacio.xxl + Espacio.l,
                ),
                const SizedBox(height: Espacio.m),
                Text(textoTuTicket, style: tema.textTheme.bodyLarge),
                _Grupo(
                  titulo: '¿Cuántos años tienes?',
                  ayuda: _edad == null ? null : _textoEdad(_edad!),
                  opciones: [
                    for (final edad in edadesPosibles)
                      _Opcion(
                        texto: '$edad',
                        elegida: _edad == edad,
                        onElegir: () => _elegirEdad(_edad == edad ? null : edad),
                      ),
                  ],
                ),
                _Grupo(
                  titulo: '¿Qué papel tienes?',
                  ayuda: _rol?.explicacion,
                  opciones: [
                    for (final rol in rolesPara(_edad))
                      _Opcion(
                        texto: rol.etiqueta,
                        elegida: _rol == rol,
                        onElegir: () => setState(() => _rol = _rol == rol ? null : rol),
                      ),
                  ],
                ),
                _Grupo(
                  titulo: '¿Qué tipo de proceso es?',
                  ayuda: _procedimiento?.explicacion,
                  opciones: [
                    for (final p in Procedimiento.values)
                      _Opcion(
                        texto: p.etiqueta,
                        elegida: _procedimiento == p,
                        onElegir: () => setState(() => _procedimiento = _procedimiento == p ? null : p),
                      ),
                  ],
                ),
                _Grupo(
                  titulo: '¿En qué momento estás?',
                  ayuda: _fase?.explicacion,
                  opciones: [
                    for (final f in Fase.values)
                      _Opcion(
                        texto: f.etiqueta,
                        elegida: _fase == f,
                        onElegir: () => setState(() => _fase = _fase == f ? null : f),
                      ),
                  ],
                ),
                _Grupo(
                  titulo: '¿Con quién irás?',
                  ayuda: 'Puedes elegir más de una.',
                  opciones: [
                    for (final a in Acompanante.values)
                      _Opcion(
                        texto: a.etiqueta,
                        elegida: _conQuien.contains(a),
                        multiple: true,
                        onElegir: () => setState(() {
                          final nuevas = {..._conQuien};
                          if (!nuevas.remove(a)) {
                            // «Aún no lo sé» va sola.
                            if (a == Acompanante.aunNoLoSe) nuevas.clear();
                            nuevas
                              ..remove(Acompanante.aunNoLoSe)
                              ..add(a);
                          }
                          _conQuien = nuevas;
                        }),
                      ),
                  ],
                ),
                _Grupo(
                  titulo: '¿Qué te preocupa más?',
                  ayuda: 'Te respondo a cada cosa con lo que dice la ley. Puedes elegir más de una.',
                  opciones: [
                    for (final p in Preocupacion.values)
                      _Opcion(
                        texto: p.etiqueta,
                        elegida: _preocupaciones.contains(p),
                        multiple: true,
                        onElegir: () => setState(() {
                          final nuevas = {..._preocupaciones};
                          if (!nuevas.remove(p)) nuevas.add(p);
                          _preocupaciones = nuevas;
                        }),
                      ),
                  ],
                ),
                _Grupo(
                  titulo: '¿Cómo prefieres que te lo cuente?',
                  ayuda: _estilo?.explicacion,
                  opciones: [
                    for (final e in EstiloExplicacion.values)
                      _Opcion(
                        texto: e.etiqueta,
                        elegida: _estilo == e,
                        onElegir: () => setState(() => _estilo = _estilo == e ? null : e),
                      ),
                  ],
                ),
                const SizedBox(height: Espacio.l),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const IconoTuTurno(TuIcono.candado, size: Espacio.l - Espacio.xs, decorativo: true),
                    const SizedBox(width: Espacio.s),
                    Expanded(
                      child: Text(
                        notaPrivacidadTicket,
                        style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                if (_hayAlgoGuardado) ...[
                  const SizedBox(height: Espacio.s),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(onPressed: _borrar, child: const Text(botonBorrarTicket)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// La edad dice qué cambia: lo explica Mi situación con su fuente (aquí, sin afirmaciones jurídicas).
  String _textoEdad(int edad) => 'Con $edad años, en tu guía verás lo que cambia por tu edad.';
}

/// Un bloque de preguntas con sus opciones (chips) y una ayuda debajo.
class _Grupo extends StatelessWidget {
  const _Grupo({required this.titulo, required this.opciones, this.ayuda});

  final String titulo;
  final List<_Opcion> opciones;
  final String? ayuda;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ayuda = this.ayuda;
    return Padding(
      padding: const EdgeInsets.only(top: Espacio.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(titulo, style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: Espacio.s),
          Wrap(spacing: Espacio.s, runSpacing: Espacio.xs, children: opciones),
          if (ayuda != null) ...[
            const SizedBox(height: Espacio.xs),
            Text(ayuda, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

/// Una opción: se toca para elegirla y, si ya estaba elegida, se toca otra vez para quitarla.
class _Opcion extends StatelessWidget {
  const _Opcion({required this.texto, required this.elegida, required this.onElegir, this.multiple = false});

  final String texto;
  final bool elegida;
  final bool multiple;
  final VoidCallback onElegir;

  @override
  Widget build(BuildContext context) {
    void elegir(bool _) {
      Hapticos.seleccion();
      onElegir();
    }

    // El chip ya dice al lector de pantalla su texto y si está elegido; la explicación sale escrita debajo.
    return multiple
        ? FilterChip(label: Text(texto), selected: elegida, onSelected: elegir)
        : ChoiceChip(label: Text(texto), selected: elegida, onSelected: elegir, showCheckmark: false);
  }
}
