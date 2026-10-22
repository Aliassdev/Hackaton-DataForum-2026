import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../tema.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/iconos/iconos.dart';
import '../../widgets/modulos.dart';
import '../../widgets/movimiento/hapticos.dart';
import '../../widgets/movimiento/ticket.dart';

/// Textos de cada papel en un proceso, con palabras que entiende alguien de 11 años.
/// Hablan del proceso, nunca de lo que pasó.
extension InfoRol on RolProceso {
  String get nombre => switch (this) {
    RolProceso.testigo => 'Testigo',
    RolProceso.victima => 'Víctima',
    RolProceso.investigado => 'Investigado o investigada',
  };

  /// Para usarlo dentro de una frase: «Pregunta como testigo».
  String get enFrase => switch (this) {
    RolProceso.testigo => 'testigo',
    RolProceso.victima => 'víctima',
    RolProceso.investigado => 'investigado o investigada',
  };

  String get resumen => switch (this) {
    RolProceso.testigo => 'Te piden que cuentes lo que viste u oíste.',
    RolProceso.victima => 'Alguien te ha hecho daño y la justicia lo está investigando.',
    RolProceso.investigado => 'La justicia está revisando si hiciste algo que la ley no permite.',
  };

  String get explicacion => switch (this) {
    RolProceso.testigo =>
      'Ser testigo significa que la justicia quiere escuchar lo que sabes. Tu papel es contarlo con tus palabras. '
          'Si no entiendes algo, puedes pedir que te lo expliquen.',
    RolProceso.victima =>
      'Ser víctima significa que la justicia investiga algo que te hizo daño. Su trabajo es protegerte y '
          'explicarte cada paso. Puedes preguntar todo lo que no entiendas.',
    RolProceso.investigado =>
      'Ser investigado o investigada significa que la justicia está revisando si hiciste algo que la ley no '
          'permite. Todavía no se ha decidido nada.',
  };

  /// Una frase para dar tranquilidad.
  String get tranquilidad => switch (this) {
    RolProceso.testigo => 'No estás en ningún lío. Contar lo que sabes ayuda a que la justicia decida bien.',
    RolProceso.victima => 'Nada de esto es culpa tuya. Puedes pedir que te expliquen cada paso.',
    // Sin afirmaciones jurídicas hasta que llegue el itinerario validado (A6): lo que pasa depende de la edad.
    RolProceso.investigado =>
      'Tienes derecho a que te lo expliquen con palabras claras. Lo que pasa después depende de tu edad: '
          'pregúntalo y te lo explico.',
  };

  IconData get icono => switch (this) {
    RolProceso.testigo => Icons.visibility_rounded,
    RolProceso.victima => Icons.shield_rounded,
    RolProceso.investigado => Icons.balance_rounded,
  };

  /// Icono de TuTurno del papel: el micrófono de quien cuenta lo que sabe, el escudo de la protección y el juzgado
  /// donde se revisa lo que pasó (sin juzgar: todavía no se ha decidido nada).
  TuIcono get tuIcono => switch (this) {
    RolProceso.testigo => TuIcono.microfono,
    RolProceso.victima => TuIcono.escudo,
    RolProceso.investigado => TuIcono.juzgado,
  };
}

const notaNoPreguntamos = 'Aquí nunca te preguntamos qué ha pasado. Solo te explicamos cómo funciona el proceso.';

/// Abre una hoja para elegir el papel y lleva a `/situacion/<rol>`. Con [reemplazar], sustituye la pantalla actual.
Future<void> mostrarSelectorRol(BuildContext context, {bool reemplazar = false}) async {
  final rol = await showModalBottomSheet<RolProceso>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _HojaSelectorRol(),
  );
  if (rol == null || !context.mounted) return;
  final ruta = '/situacion/${rol.name}';
  if (reemplazar) {
    context.pushReplacement(ruta);
  } else {
    context.push(ruta);
  }
}

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
                  onElegido: (rol) => Navigator.of(context).pop(rol),
                  colorFondo: Theme.of(context).bottomSheetTheme.backgroundColor,
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

/// Las tres opciones (testigo, víctima, investigado o investigada), como tickets, y la nota de que no se pregunta qué
/// pasó. [colorFondo] es el color de lo que hay detrás (los agujeros de la línea troquelada); por defecto, la página.
class SelectorRol extends StatelessWidget {
  const SelectorRol({super.key, required this.onElegido, this.colorFondo});

  final ValueChanged<RolProceso> onElegido;
  final Color? colorFondo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, rol) in RolProceso.values.indexed) ...[
          Entrada(
            orden: i,
            child: _OpcionRol(
              rol: rol,
              colorFondo: colorFondo,
              onTap: () {
                Hapticos.seleccion();
                onElegido(rol);
              },
            ),
          ),
          const SizedBox(height: Espacio.s + Espacio.xs),
        ],
        const SizedBox(height: Espacio.xs),
        Entrada(
          orden: RolProceso.values.length,
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
class _OpcionRol extends StatelessWidget {
  const _OpcionRol({required this.rol, required this.onTap, this.colorFondo});

  final RolProceso rol;
  final VoidCallback onTap;
  final Color? colorFondo;

  @override
  Widget build(BuildContext context) {
    return TicketTuTurno(
      titulo: rol.nombre,
      descripcion: rol.resumen,
      icono: IconoTuTurno(rol.tuIcono, decorativo: true),
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
