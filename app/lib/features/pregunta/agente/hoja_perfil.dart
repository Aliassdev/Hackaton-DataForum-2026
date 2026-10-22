import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart';
import '../../../core/entrada.dart';
import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../../../widgets/modulos.dart';
import '../../../widgets/movimiento/hapticos.dart';
import '../widgets/compositor.dart' show ProveedorChat;
import '../widgets/estilo.dart';
import 'textos_agente.dart';

// Hoja amable para el perfil: edad, tipo de proceso, papel y momento (las variables de la sección 8.6, que van a la
// sesión de voz y al modo texto). Es opcional y se puede saltar. Nunca pregunta qué ha pasado. Se guarda en el móvil
// (entradaProvider) y viaja, sin nombre, con las preguntas.

/// La hoja ya ha salido en esta ejecución de la app (solo en memoria): si se salta, no vuelve a salir hasta la próxima
/// vez que se abra la app.
final perfilPreguntadoProvider = NotifierProvider<PerfilPreguntadoNotifier, bool>(PerfilPreguntadoNotifier.new);

class PerfilPreguntadoNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void marcar() => state = true;
}

/// La primera vez que se entra en Pregunta en esta ejecución de la app, si no hay perfil, la hoja (se puede saltar).
/// Lo elegido se guarda. Termina cuando se cierra la hoja (o enseguida, si no hace falta).
Future<void> preguntarPerfilSiHaceFalta(BuildContext context, WidgetRef ref, {RolProceso? situacion}) async {
  if (!ref.read(entradaProvider).vacia || ref.read(perfilPreguntadoProvider)) return;
  ref.read(perfilPreguntadoProvider.notifier).marcar();
  final elegida = await mostrarHojaPerfil(context, situacion: situacion);
  if (!context.mounted) return;
  if (elegida != null && !elegida.vacia) await ref.read(entradaProvider.notifier).guardar(elegida);
}

/// Abre la hoja con [inicial] ya marcado. Devuelve lo elegido con «Listo», o null si se salta o se cierra. Con
/// «Mi situación» ([situacion]), el papel viene marcado si no había otro.
Future<Entrada?> mostrarHojaPerfil(BuildContext context, {Entrada inicial = const Entrada(), RolProceso? situacion}) {
  return showModalBottomSheet<Entrada>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => HojaPerfil(inicial: inicial, situacion: situacion),
  );
}

class HojaPerfil extends StatefulWidget {
  const HojaPerfil({super.key, this.inicial = const Entrada(), this.situacion});

  final Entrada inicial;
  final RolProceso? situacion;

  @override
  State<HojaPerfil> createState() => _HojaPerfilState();
}

class _HojaPerfilState extends State<HojaPerfil> {
  late int? _edad = widget.inicial.edad;
  late Procedimiento? _procedimiento = widget.inicial.procedimiento;
  late RolEntrada? _rol = widget.inicial.rol ?? _rolDeSituacion(widget.situacion);
  late Fase? _fase = widget.inicial.fase;

  /// «Prefiero no decirlo» y «No lo sé» del momento: se envían igual que sin responder, pero se ven marcados.
  var _edadNoDecir = false;
  var _faseNoSe = false;

  static RolEntrada? _rolDeSituacion(RolProceso? situacion) => switch (situacion) {
    RolProceso.testigo => RolEntrada.testigo,
    RolProceso.victima => RolEntrada.victima,
    RolProceso.investigado => RolEntrada.investigado,
    null => null,
  };

  /// «Investigado» solo a partir de 14 años ([puedeSerInvestigado], la misma regla que «Tu ticket»).
  bool get _puedeSerInvestigado => puedeSerInvestigado(_edad);

  void _elegirEdad(int? edad, {bool noDecir = false}) {
    setState(() {
      _edad = edad;
      _edadNoDecir = noDecir;
      if (!_puedeSerInvestigado && _rol == RolEntrada.investigado) _rol = null;
    });
  }

  Entrada get _elegida => Entrada(edad: _edad, procedimiento: _procedimiento, rol: _rol, fase: _fase);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final roles = rolesPara(_edad);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: anchoMaximo),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(Espacio.l, 0, Espacio.l, Espacio.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(
                                    tituloHojaPerfil,
                                    style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(height: Espacio.s),
                                Text(
                                  textoHojaPerfil,
                                  style: tema.textTheme.bodyLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: Espacio.s),
                          const MascotaTut(size: 64, animada: false, decorativo: true),
                        ],
                      ),
                      _Grupo(
                        key: const Key('perfil-edad'),
                        titulo: preguntaEdad,
                        opciones: [
                          for (final edad in edadesPosibles)
                            _Opcion(
                              texto: '$edad',
                              semantica: '$edad años',
                              elegida: _edad == edad,
                              onElegir: () => _elegirEdad(_edad == edad ? null : edad),
                            ),
                          _Opcion(
                            texto: opcionNoDecir,
                            elegida: _edadNoDecir,
                            onElegir: () => _elegirEdad(null, noDecir: !_edadNoDecir),
                          ),
                        ],
                      ),
                      _Grupo(
                        key: const Key('perfil-procedimiento'),
                        titulo: preguntaProcedimiento,
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
                        key: const Key('perfil-rol'),
                        titulo: preguntaRol,
                        ayuda: _rol?.explicacion,
                        opciones: [
                          for (final r in roles)
                            _Opcion(
                              texto: r.etiqueta,
                              elegida: _rol == r,
                              onElegir: () => setState(() => _rol = _rol == r ? null : r),
                            ),
                        ],
                      ),
                      _Grupo(
                        key: const Key('perfil-fase'),
                        titulo: preguntaFase,
                        ayuda: _fase?.explicacion,
                        opciones: [
                          for (final f in Fase.values)
                            _Opcion(
                              texto: f.etiqueta,
                              elegida: _fase == f,
                              onElegir: () => setState(() {
                                _fase = _fase == f ? null : f;
                                _faseNoSe = false;
                              }),
                            ),
                          _Opcion(
                            texto: opcionNoLoSe,
                            elegida: _faseNoSe,
                            onElegir: () => setState(() {
                              _faseNoSe = !_faseNoSe;
                              _fase = null;
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(Espacio.l, Espacio.s, Espacio.l, Espacio.m),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: Espacio.m,
                  runSpacing: Espacio.s,
                  children: [
                    TextButton(
                      key: const Key('perfil-saltar'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Saltar'),
                    ),
                    FilledButton(
                      key: const Key('perfil-listo'),
                      onPressed: () {
                        Hapticos.toque();
                        Navigator.of(context).pop(_elegida);
                      },
                      child: const Text('Listo'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Opcion {
  const _Opcion({required this.texto, required this.elegida, required this.onElegir, this.semantica});

  final String texto;
  final String? semantica;
  final bool elegida;
  final VoidCallback onElegir;
}

/// Una pregunta de la hoja: título y opciones de una en una (tocar otra vez la elegida la quita).
class _Grupo extends StatelessWidget {
  const _Grupo({super.key, required this.titulo, required this.opciones, this.ayuda});

  final String titulo;
  final List<_Opcion> opciones;

  /// Explicación corta de lo elegido.
  final String? ayuda;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Espacio.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(titulo, style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: Espacio.s),
          Wrap(
            spacing: Espacio.s,
            runSpacing: Espacio.xs,
            children: [
              for (final opcion in opciones)
                ChoiceChip(
                  label: Text(opcion.texto, semanticsLabel: opcion.semantica),
                  selected: opcion.elegida,
                  onSelected: (_) {
                    Hapticos.seleccion();
                    opcion.onElegir();
                  },
                ),
            ],
          ),
          if (ayuda != null)
            Padding(
              padding: const EdgeInsets.only(top: Espacio.xs),
              child: Text(ayuda!, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}

/// La línea del perfil arriba de la vista inicial: «Te explico para: 13 años · Penal · Víctima · Durante» y «Cambiar»
/// (o, sin perfil, «Elegir»). Abre la hoja; con el agente de voz, cambiar el perfil abre otra sesión (las variables
/// no cambian a mitad).
class ResumenPerfil extends ConsumerWidget {
  const ResumenPerfil({super.key, required this.proveedor});

  final ProveedorChat proveedor;

  Future<void> _cambiar(BuildContext context, WidgetRef ref) async {
    Hapticos.toque();
    final chat = ref.read(proveedor.notifier);
    final elegida = await mostrarHojaPerfil(
      context,
      inicial: ref.read(entradaProvider),
      situacion: ref.read(proveedor).situacion,
    );
    if (elegida == null || !context.mounted) return;
    await ref.read(entradaProvider.notifier).guardar(elegida);
    await chat.cambiarPerfil();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final resumen = resumenPerfil(ref.watch(entradaProvider));
    return Material(
      key: const Key('resumen-perfil'),
      color: tinteMarca(esquema),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radios.m),
        side: BorderSide(color: esquema.primary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Espacio.m, Espacio.s, Espacio.xs, Espacio.s),
        child: Row(
          children: [
            IconoTuTurno(TuIcono.miSituacion, estilo: EstiloIcono.mono, color: esquema.primary, decorativo: true),
            const SizedBox(width: Espacio.s + Espacio.xs),
            Expanded(
              child: Text(
                textoResumenPerfil(resumen),
                style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurface, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              key: const Key('cambiar-perfil'),
              onPressed: () => _cambiar(context, ref),
              child: Text(resumen.isEmpty ? 'Elegir' : 'Cambiar'),
            ),
          ],
        ),
      ),
    );
  }
}
