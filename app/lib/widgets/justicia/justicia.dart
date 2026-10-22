/// Capa «justicia» de TuTurno: las piezas compartidas del palacio de justicia de papel recortado, con el concepto
/// «Tu turno de palabra» (el ticket de turno y el derecho a ser oído: LO 1/1996, art. 9.1; CDN, art. 12.2).
///
/// - [CartelSala]: el cartel de la puerta de una sala («SALA 1», «INFORMACIÓN»).
/// - [SelloJusticia] y [TipoSello]: el sello de tinta que cae al terminar una lección, un repaso, un caso o el turno
///   del día.
/// - [AvisoTurnoPalabra]: la píldora «Tu turno de palabra», con la luz del micrófono.
///
/// Los iconos de la capa (balanza, toga, estrado, ley, turnoPalabra…) están en `TuIcono` (lib/widgets/iconos/).
/// Ayuda queda fuera de la metáfora y en Pregunta no va ninguna de estas piezas. Lo que solo usa una pantalla (la
/// balanza del dominio, la carátula de Mi situación, el fondo del palacio o el panel de turnos) va en su propio archivo
/// de esta carpeta y se importa directamente.
library;

export 'cartel_sala.dart';
export 'sello_justicia.dart';
export 'turno_palabra.dart';
