import 'package:flutter/material.dart';

import '../../../core/recursos_ayuda.dart';
import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../../../widgets/movimiento/hapticos.dart';

/// Un botón por cada teléfono que dice el agente. En el texto ya van en cifras («900 20 20 10»), pero dentro del texto
/// no caben zonas táctiles de 48 px. Cada botón lleva el nombre del servicio (lib/core/recursos_ayuda.dart) y el 017,
/// su horario. Llamar funciona sin datos.
class BotonesTelefono extends StatelessWidget {
  const BotonesTelefono({super.key, required this.telefonos, this.sinLosDeLaTarjeta = false});

  /// Tal como los da core/agente/respuesta_agente.dart (`telefonosEn`).
  final List<String> telefonos;

  /// En una respuesta de crisis, ANAR y el 112 ya están en la tarjeta de ayuda de arriba.
  final bool sinLosDeLaTarjeta;

  static const _deLaTarjeta = {'900 20 20 10', '112'};

  @override
  Widget build(BuildContext context) {
    final lista = [
      for (final telefono in telefonos)
        if (!(sinLosDeLaTarjeta && _deLaTarjeta.contains(telefono)) && _recurso(telefono) != null) telefono,
    ];
    if (lista.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Espacio.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final telefono in lista)
            Padding(
              padding: const EdgeInsets.only(bottom: Espacio.s),
              child: _BotonTelefono(telefono: telefono, recurso: _recurso(telefono)!),
            ),
        ],
      ),
    );
  }

  /// El recurso de Ayuda de [telefono]. El 900 116 117 es el WhatsApp del 017.
  static RecursoAyuda? _recurso(String telefono) {
    for (final recurso in recursosAyuda) {
      if (recurso.telefono == telefono || recurso.whatsapp == telefono) return recurso;
    }
    return null;
  }
}

class _BotonTelefono extends StatelessWidget {
  const _BotonTelefono({required this.telefono, required this.recurso});

  final String telefono;
  final RecursoAyuda recurso;

  bool get _esWhatsapp => recurso.whatsapp == telefono && recurso.telefono != telefono;

  Future<void> _abrir(BuildContext context) async {
    Hapticos.toque();
    final mensajero = ScaffoldMessenger.maybeOf(context);
    final abierto = _esWhatsapp ? await abrirWhatsapp(recurso) : await abrirRecurso(recurso);
    if (!abierto) {
      mensajero?.showSnackBar(
        SnackBar(
          content: Text(
            _esWhatsapp
                ? 'No he podido abrir WhatsApp. Escribe al $telefono.'
                : 'No he podido abrir el teléfono. '
                      'Marca el $telefono.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final visible = telefono.replaceAll(' ', ' ');
    final titulo = _esWhatsapp ? 'WhatsApp del 017 · $visible' : 'Llamar al $visible · ${recurso.nombre}';
    final horario = recurso.horario?.texto;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: Espacio.m, vertical: Espacio.s),
      ),
      onPressed: () => _abrir(context),
      icon: const IconoTuTurno(TuIcono.telefono, estilo: EstiloIcono.mono, decorativo: true),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(titulo),
          if (horario != null)
            Text(horario, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
