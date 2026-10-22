import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../tema.dart';
import '../../widgets/animaciones.dart' as anim;
import '../../widgets/iconos/iconos.dart';
import '../../widgets/modulos.dart';
import '../../widgets/movimiento/hapticos.dart';
import '../../widgets/movimiento/ticket.dart';
import 'papel.dart';
import 'textos.dart';
import 'ticket_screen.dart';

export 'papel.dart' show PapelSituacion;
export 'textos.dart' show notaNoPreguntamos;

/// Textos de cada papel del contrato de la API ([RolProceso]), los mismos que los de su [PapelSituacion].
extension InfoRol on RolProceso {
  PapelSituacion get _papel => PapelSituacion.deRolProceso(this);

  String get nombre => _papel.nombre;

  /// Para usarlo dentro de una frase: «Pregunta como testigo».
  String get enFrase => _papel.enFrase;
  String get resumen => _papel.resumen;
  String get explicacion => _papel.explicacion;

  /// Una frase para dar tranquilidad.
  String get tranquilidad => _papel.tranquilidad;

  /// Icono de TuTurno del papel (nunca la balanza: no es «te están juzgando»).
  TuIcono get tuIcono => _papel.tuIcono;
}

/// Abre una hoja para elegir el papel y lleva a `/situacion/<papel>`. Con [reemplazar], sustituye la pantalla actual.
/// Abajo, «Prefiero rellenar mi ticket», que abre «Tu ticket» y, al guardarlo, lleva a tu papel.
Future<void> mostrarSelectorRol(BuildContext context, {bool reemplazar = false}) async {
  final elegido = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _HojaSelectorRol(),
  );
  if (elegido == null || !context.mounted) return;
  PapelSituacion? papel;
  if (elegido is PapelSituacion) {
    papel = elegido;
  } else if (elegido == _rellenarTicket) {
    papel = await abrirTuTicket(context);
  }
  if (papel == null || !context.mounted) return;
  if (reemplazar) {
    context.pushReplacement(papel.ruta);
  } else {
    context.push(papel.ruta);
  }
}

/// Lo que devuelve la hoja si se pide rellenar el ticket.
const _rellenarTicket = 'rellenar-ticket';

class _HojaSelectorRol extends StatelessWidget {
  const _HojaSelectorRol();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Espacio.l, 0, Espacio.l, Espacio.l),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: anchoMaximo),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const EncabezadoSelectorRol(),
                const SizedBox(height: Espacio.l),
                SelectorRol(
                  onElegido: (papel) => Navigator.of(context).pop(papel),
                  colorFondo: Theme.of(context).bottomSheetTheme.backgroundColor,
                ),
                const SizedBox(height: Espacio.s),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(_rellenarTicket),
                  icon: const IconoTuTurno(TuIcono.ticket, estilo: EstiloIcono.mono, decorativo: true),
                  label: const Text('Prefiero rellenar mi ticket'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Título y explicación del selector de papel, con Tut al lado (quieto: aquí no hay prisa ni juego).
class EncabezadoSelectorRol extends StatelessWidget {
  const EncabezadoSelectorRol({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text('¿Qué papel tienes en el caso?', style: tema.textTheme.headlineSmall),
              ),
              const SizedBox(height: Espacio.s),
              Text(
                'Elige el que más se parezca. No tienes que contar qué pasó.',
                style: tema.textTheme.bodyLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: Espacio.s),
        const MascotaTut(size: 72, animada: false, decorativo: true),
      ],
    );
  }
}

/// Los cuatro papeles (testigo, víctima, investigado o investigada, y «Me van a escuchar» en un proceso de familia),
/// como tickets, y la nota de que no se pregunta qué pasó. [colorFondo] es el color de lo que hay detrás (los agujeros
/// de la línea troquelada); por defecto, la página.
class SelectorRol extends StatelessWidget {
  const SelectorRol({super.key, required this.onElegido, this.colorFondo});

  final ValueChanged<PapelSituacion> onElegido;
  final Color? colorFondo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, papel) in PapelSituacion.values.indexed) ...[
          anim.Entrada(
            orden: i,
            child: _OpcionPapel(
              papel: papel,
              colorFondo: colorFondo,
              onTap: () {
                Hapticos.seleccion();
                onElegido(papel);
              },
            ),
          ),
          const SizedBox(height: Espacio.s + Espacio.xs),
        ],
        const SizedBox(height: Espacio.xs),
        anim.Entrada(
          orden: PapelSituacion.values.length,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconoTuTurno(TuIcono.candado, size: Espacio.l - Espacio.xs, decorativo: true),
              const SizedBox(width: Espacio.s),
              Expanded(
                child: Text(
                  notaNoPreguntamos,
                  style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Un papel como ticket de turno: su icono, el nombre en letras recortadas y una frase; en el talón, la flecha.
class _OpcionPapel extends StatelessWidget {
  const _OpcionPapel({required this.papel, required this.onTap, this.colorFondo});

  final PapelSituacion papel;
  final VoidCallback onTap;
  final Color? colorFondo;

  @override
  Widget build(BuildContext context) {
    return TicketTuTurno(
      titulo: papel.nombre,
      descripcion: papel.resumen,
      icono: IconoTuTurno(papel.tuIcono, decorativo: true),
      tamanoTalon: Espacio.xxl + Espacio.s,
      // La flecha de «volver», girada: «por aquí».
      talon: Transform.flip(
        flipX: true,
        child: const IconoTuTurno(
          TuIcono.volver,
          estilo: EstiloIcono.mono,
          color: ColoresMarca.azulNoche,
          size: Espacio.l + Espacio.xs,
          decorativo: true,
        ),
      ),
      colorPerforado: colorFondo,
      elevado: true,
      onTap: onTap,
    );
  }
}
