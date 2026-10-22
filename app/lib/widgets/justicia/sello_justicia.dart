import 'package:flutter/widgets.dart';

import '../iconos/tu_icono.dart';
import '../movimiento/sello_animado.dart';

/// Los sellos de tinta de TuTurno: lo que queda hecho y registrado. Cada uno lleva su palabra en el centro, su texto
/// alrededor y un icono propio grabado (nunca escudos ni nada que imite un sello oficial: todos dicen «TUTURNO»).
enum TipoSello {
  /// Al terminar una lección de Aprende.
  leccion(
    texto: 'SUPERADA',
    circular: 'TUTURNO · APRENDE · LECCIÓN SUPERADA · ',
    icono: TuIcono.balanza,
    lectura: 'lección superada',
  ),

  /// Al terminar un repaso (práctica) de Aprende.
  practica(
    texto: 'REPASADO',
    circular: 'TUTURNO · APRENDE · REPASO HECHO · ',
    icono: TuIcono.ley,
    lectura: 'repaso hecho',
  ),

  /// Al completar un caso de Vive el caso.
  caso(
    texto: 'COMPLETADO',
    circular: 'TUTURNO · VIVE EL CASO · CASO COMPLETADO · ',
    icono: TuIcono.puertaSala,
    lectura: 'caso completado',
  ),

  /// Al cumplir el turno del día.
  turno(texto: 'CUMPLIDO', circular: 'TURNO CUMPLIDO · TUTURNO · ', icono: TuIcono.ticket, lectura: 'turno cumplido');

  const TipoSello({required this.texto, required this.circular, required this.icono, required this.lectura});

  /// Palabra del centro.
  final String texto;

  /// Texto que da la vuelta entre los dos aros.
  final String circular;

  /// Icono del centro, a una tinta.
  final TuIcono icono;

  /// Cómo se lee en voz alta, detrás de «Sello: ».
  final String lectura;
}

/// Sello de tinta que cae sobre el papel al terminar algo: [SelloAnimado] con un [Sello] que lleva el icono de su
/// [tipo] en el centro. Cae [retraso] después de aparecer (o de pasar [estampado] a true), golpea con la vibración
/// fuerte de los sellos y avisa con [alEstampar] (para el confeti). Con [animar] en false aparece ya puesto y sin
/// vibrar (un sello que ya tenías). Con «reducir animaciones» aparece ya estampado y vibra una vez.
///
/// Solo en Aprende, Vive el caso y el turno del día: nunca en Pregunta, Ayuda ni Mi situación.
class SelloJusticia extends StatelessWidget {
  const SelloJusticia({
    super.key,
    required this.tipo,
    this.estampado = true,
    this.animar = true,
    this.retraso = const Duration(milliseconds: 250),
    this.tamano = 132,
    this.vibrar = true,
    this.alEstampar,
    this.semanticLabel,
    this.color,
  });

  final TipoSello tipo;

  /// En false no se ve (deja su hueco); al pasar a true, cae.
  final bool estampado;
  final bool animar;
  final Duration retraso;
  final double tamano;
  final bool vibrar;

  /// Se llama una vez, al golpear el papel.
  final VoidCallback? alEstampar;

  /// Por defecto, «Sello: lección superada» (o lo que diga su [tipo]).
  final String? semanticLabel;

  /// Color de la tinta (también la que se corre al golpear). Por defecto, el de los sellos del tema; sobre papel
  /// amarillo, como el talón del ticket del día, azul noche.
  final Color? color;

  @override
  Widget build(BuildContext context) => SelloAnimado(
    estampado: estampado,
    animar: animar,
    retraso: retraso,
    vibrar: vibrar,
    alEstampar: alEstampar,
    colorTinta: color,
    child: Sello(
      texto: tipo.texto,
      textoCircular: tipo.circular,
      tuIcono: tipo.icono,
      tamano: tamano,
      color: color,
      semanticLabel: semanticLabel ?? 'Sello: ${tipo.lectura}',
    ),
  );
}
