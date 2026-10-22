/// Sistema de movimiento y ecosistema de tickets de TuTurno.
///
/// - [TicketBorder] y [TicketTuTurno]: la forma y la pieza del ticket de turno.
/// - [PaginaTuTurno], [paginaTuTurno] y [TransicionTuTurno]: transiciones de página (rasgar, deslizar, suave).
/// - [ContadorFlip] y [PanelFlip]: números como un panel de aeropuerto.
/// - [SelloAnimado] y [Sello]: sellos oficiales que caen sobre el papel.
/// - [ConfetiPapel] y [lanzarConfeti]: confeti de papel en los colores de la marca.
/// - [CartaHolo]: carta coleccionable que se inclina con el dedo.
/// - [FondoPapel]: papel recortado que flota detrás de las cabeceras.
/// - [PopPegatina]: aparecer como una pegatina.
/// - [Hapticos]: vibraciones con nombre.
///
/// Todo respeta «reducir animaciones» (`duracion()` del tema): sin animación, cada pieza aparece ya en su sitio.
library;

export 'carta_holo.dart';
export 'confeti_papel.dart';
export 'contador_flip.dart';
export 'fondo_papel.dart';
export 'hapticos.dart';
export 'paleta.dart';
export 'pop_pegatina.dart';
export 'sello_animado.dart';
export 'ticket.dart';
export 'transiciones.dart';
