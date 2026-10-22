import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../tema.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/iconos/iconos.dart';
import '../../widgets/modulos.dart';
import '../../widgets/movimiento/fondo_papel.dart';
import '../../widgets/movimiento/hapticos.dart';
import '../../widgets/movimiento/ticket.dart';
import '../../widgets/tuturno_scaffold.dart';
import '../pasos/pasos.dart';
import '../pregunta/widgets/tickets.dart';
import 'roles.dart';

// Mi situación (sección 4.4): qué significa tu papel, la línea de pasos y Pregunta con ese papel. Es parte de
// Pregunta: tranquila y clara, sin puntos ni celebraciones. Nunca se pregunta qué pasó.

class SituacionScreen extends StatelessWidget {
  const SituacionScreen({super.key, required this.rol});

  /// Nulo si la dirección no es un papel válido: entonces se ofrece elegirlo.
  final RolProceso? rol;

  @override
  Widget build(BuildContext context) {
    final rol = this.rol;
    return TuTurnoScaffold(
      titulo: 'Mi situación',
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: anchoMaximo),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.m, Espacio.xl),
            child: rol == null ? const _ElegirRol() : _ConRol(rol: rol),
          ),
        ),
      ),
    );
  }
}

class _ElegirRol extends StatelessWidget {
  const _ElegirRol();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Entrada(child: EncabezadoSelectorRol()),
        const SizedBox(height: Espacio.l),
        SelectorRol(onElegido: (rol) => context.pushReplacement('/situacion/${rol.name}')),
      ],
    );
  }
}

class _ConRol extends StatelessWidget {
  const _ConRol({required this.rol});

  final RolProceso rol;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    var orden = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Entrada(
          orden: orden++,
          child: CabeceraRol(rol: rol),
        ),
        const SizedBox(height: Espacio.l),
        Entrada(
          orden: orden++,
          child: _QueSignifica(rol: rol),
        ),
        const SizedBox(height: Espacio.xl),
        // La línea de pasos ya entra escalonada por su cuenta (features/pasos).
        LineaPasos(rol: rol.name),
        const SizedBox(height: Espacio.l),
        Entrada(
          orden: orden++,
          child: FilledButton.icon(
            onPressed: () {
              Hapticos.toque();
              context.push('/pregunta?situacion=${rol.name}');
            },
            icon: const IconoTuTurno(TuIcono.pregunta, estilo: EstiloIcono.mono, decorativo: true),
            label: Text('Pregunta como ${rol.enFrase}'),
          ),
        ),
        const SizedBox(height: Espacio.s),
        Entrada(
          orden: orden++,
          child: TextButton.icon(
            onPressed: () => mostrarSelectorRol(context, reemplazar: true),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Cambiar de papel'),
          ),
        ),
        const SizedBox(height: Espacio.m),
        Entrada(
          orden: orden++,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconoTuTurno(TuIcono.candado, size: Espacio.l - Espacio.xs, decorativo: true),
              const SizedBox(width: Espacio.s),
              Expanded(
                child: Text(
                  notaNoPreguntamos,
                  style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Cabecera de Mi situación: un ticket de turno con tu papel. El cuerpo es papel azul recortado que flota despacio
/// (unos ciclos, y se para); el talón amarillo lleva la pegatina del papel.
class CabeceraRol extends StatelessWidget {
  const CabeceraRol({super.key, required this.rol});

  final RolProceso rol;

  static const _anchoTalon = 104.0;

  /// Capas del papel del fondo: azules algo más oscuros que el de la marca, para que el texto blanco siga siendo AA.
  static final _capas = [
    Color.lerp(ColoresMarca.azul, ColoresMarca.azulNoche, 0.32)!,
    Color.lerp(ColoresMarca.azul, ColoresMarca.azulNoche, 0.16)!,
    const Color(0xFF3551E6),
  ];

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final forma = TicketBorder(
      radio: Radios.l,
      radioMuesca: 12,
      talon: _anchoTalon,
      colorPerforado: tema.scaffoldBackgroundColor,
    );
    final cuerpo = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Espacio.l - Espacio.xs, Espacio.l, Espacio.m, Espacio.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estás en un proceso como'.toUpperCase(),
            style: tema.textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: Espacio.s),
          Semantics(
            header: true,
            child: Text(rol.nombre, style: tema.textTheme.displaySmall?.copyWith(color: Colors.white, height: 1.05)),
          ),
          const SizedBox(height: Espacio.s + Espacio.xs),
          Text(rol.resumen, style: tema.textTheme.bodyLarge?.copyWith(color: Colors.white)),
        ],
      ),
    );
    // Sombra de papel con la silueta del ticket, muescas incluidas.
    return SombraTicket(
      forma: forma,
      elevacion: 1.2,
      child: DecoratedBox(
        // Encima de todo, solo la línea troquelada.
        decoration: ShapeDecoration(shape: forma),
        position: DecorationPosition.foreground,
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: forma),
          child: Stack(
            children: [
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                end: _anchoTalon,
                child: FondoPapel(
                  color: ColoresMarca.azul,
                  colores: _capas,
                  formas: 5,
                  semilla: rol.index + 4,
                  ciclos: 2,
                ),
              ),
              PositionedDirectional(
                end: 0,
                top: 0,
                bottom: 0,
                width: _anchoTalon,
                child: ColoredBox(
                  color: ColoresMarca.amarillo,
                  child: Center(
                    child: Transform.rotate(
                      angle: -0.1,
                      child: IconoTuTurno(rol.tuIcono, size: 60, pegatina: true, decorativo: true),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: _anchoTalon),
                child: cuerpo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «Qué significa» como ticket: la explicación arriba y, en el talón, una frase para dar tranquilidad.
class _QueSignifica extends StatelessWidget {
  const _QueSignifica({required this.rol});

  final RolProceso rol;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final colores = context.colores;
    // El talón es una nota amarilla: suave en claro y el amarillo de la marca en oscuro (con tinta azul noche).
    final claro = tema.brightness == Brightness.light;
    final tintaTalon = claro ? esquema.onTertiaryContainer : ColoresMarca.azulNoche;
    return TicketVertical(
      color: colores.ticket,
      colorTalon: claro ? esquema.tertiaryContainer : ColoresMarca.amarillo,
      colorPerforado: esquema.outlineVariant,
      borde: BorderSide(color: esquema.outlineVariant),
      sombras: sombrasTicket(context, elevacion: 0.8),
      radio: Radios.l,
      cuerpo: Padding(
        padding: const EdgeInsets.fromLTRB(
          Espacio.l - Espacio.xs,
          Espacio.l - Espacio.xs,
          Espacio.l - Espacio.xs,
          Espacio.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text('Qué significa', style: tema.textTheme.headlineSmall?.copyWith(color: colores.tintaTicket)),
            ),
            const SizedBox(height: Espacio.s),
            Text(rol.explicacion, style: tema.textTheme.bodyLarge?.copyWith(color: colores.tintaTicket, height: 1.45)),
          ],
        ),
      ),
      talon: Padding(
        padding: const EdgeInsets.fromLTRB(
          Espacio.l - Espacio.xs,
          Espacio.m,
          Espacio.l - Espacio.xs,
          Espacio.m + Espacio.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IconoTuTurno(TuIcono.personaConfianza, size: Espacio.xl, decorativo: true),
            const SizedBox(width: Espacio.s + Espacio.xs),
            Expanded(
              child: Text(
                rol.tranquilidad,
                style: tema.textTheme.bodyLarge?.copyWith(color: tintaTalon, fontWeight: FontWeight.w700, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
