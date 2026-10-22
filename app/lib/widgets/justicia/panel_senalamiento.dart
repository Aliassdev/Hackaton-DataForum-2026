import 'package:flutter/material.dart';

import '../../tema.dart';
import '../movimiento/contador_flip.dart';

/// Fila del panel de turnos de la entrada, como la relación de señalamientos que un juzgado pone a la vista (LOPJ,
/// art. 232.2; aquí solo como guía de dibujo): «TURNO 07 · SALA 2 · APRENDE» en un tablero azul noche, con el número y
/// la sala en paletas partidas de papel (PanelFlip) que giran cifra a cifra. Solo números y salas: nunca nombres.
///
/// Se lee como una frase («Panel de turnos: turno 7, sala 2, Aprende.»). Crece con el tamaño de letra y, si no cabe
/// en una línea, la sala o el destino pasan a la siguiente. Con «reducir animaciones», el número no gira.
class PanelSenalamiento extends StatelessWidget {
  const PanelSenalamiento({
    super.key,
    required this.turno,
    required this.sala,
    this.destino,
    this.desde,
    this.semanticLabel,
  });

  /// El número de turno, con sus ceros: «07», «001».
  final String turno;

  /// La sala: «SALA 2». Su número va en una paleta; un nombre sin número («INFORMACIÓN»), en letras.
  final String sala;

  /// A dónde lleva: «APRENDE». Se pinta en mayúsculas.
  final String? destino;

  /// El turno anterior: si es otro, el número gira desde él al aparecer.
  final String? desde;

  /// Lo que lee el lector de pantalla. Por defecto, «Panel de turnos: turno 7, sala 2, Aprende.».
  final String? semanticLabel;

  /// Paletas: papel con tinta azul noche (15,9:1), las del panel del palacio.
  static const papel = ColoresMarca.papel;
  static const tinta = ColoresMarca.azulNoche;

  /// Letreros («TURNO», «SALA»): amarillo sobre el tablero.
  static const letrero = ColoresMarca.amarillo;

  /// Color del tablero: azul noche en claro y, en oscuro, el del panel de turnos del ticket del día
  /// (`surfaceBright`), que se separa del fondo.
  static Color tablero(BuildContext context) {
    final tema = Theme.of(context);
    return tema.brightness == Brightness.dark ? tema.colorScheme.surfaceBright : ColoresMarca.azulNoche;
  }

  /// «SALA 2» → («SALA», «2»); «INFORMACIÓN» → («INFORMACIÓN», null).
  static (String, String?) partirSala(String sala) {
    final partes = RegExp(r'^(.*?)\s*(\d+)$').firstMatch(sala.trim());
    if (partes == null) return (sala.trim(), null);
    return (partes.group(1)!, partes.group(2));
  }

  /// La frase que se lee: los números sin ceros delante y las palabras como en una frase («Vive el caso»).
  String get _frase {
    final (nombreSala, numeroSala) = partirSala(sala);
    final numero = int.tryParse(turno.trim());
    final destino = this.destino;
    final partes = [
      'turno ${numero ?? turno.trim()}',
      [if (nombreSala.isNotEmpty) nombreSala.toLowerCase(), ?numeroSala].join(' '),
      if (destino != null && destino.trim().isNotEmpty) _comoFrase(destino.trim()),
    ].where((parte) => parte.isNotEmpty);
    return 'Panel de turnos: ${partes.join(', ')}.';
  }

  static String _comoFrase(String texto) => texto[0].toUpperCase() + texto.substring(1).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final estiloLetrero = textos.labelLarge?.copyWith(
      color: letrero,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      height: 1.2,
    );
    final estiloPaletas = textos.titleMedium;
    final (nombreSala, numeroSala) = partirSala(sala);
    final destino = this.destino;

    Widget paletas(String texto, {String? desde}) =>
        PanelFlip(texto: texto, desde: desde, estilo: estiloPaletas, fondo: papel, color: tinta, separacion: 2);

    Widget grupo(String letrero, Widget? paleta) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (letrero.isNotEmpty) Flexible(child: Text(letrero.toUpperCase(), style: estiloLetrero)),
        if (letrero.isNotEmpty && paleta != null) const SizedBox(width: Espacio.xs + 2),
        ?paleta,
      ],
    );

    final tablero = DecoratedBox(
      decoration: BoxDecoration(
        color: PanelSenalamiento.tablero(context),
        borderRadius: BorderRadius.circular(Radios.s),
        // Sombra plana de papel, como la del panel de turnos del ticket: nítida y barata de pintar.
        boxShadow: [BoxShadow(color: sombraPapelDe(context), offset: const Offset(0, 2.5))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Espacio.s + Espacio.xs, vertical: Espacio.xs + 2),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Espacio.m,
          runSpacing: Espacio.xs + 2,
          children: [
            grupo('Turno', paletas(turno.trim(), desde: desde?.trim())),
            grupo(nombreSala, numeroSala == null ? null : paletas(numeroSala)),
            if (destino != null && destino.trim().isNotEmpty)
              Text(destino.trim().toUpperCase(), style: estiloLetrero?.copyWith(color: papel)),
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      label: semanticLabel ?? _frase,
      child: ExcludeSemantics(child: tablero),
    );
  }
}
