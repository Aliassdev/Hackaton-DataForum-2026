/// «¿Quién es quién en el juzgado?»: la sala de vistas de «Vive el caso» para explorar, persona a persona.
///
/// - [JuzgadoExplorable]: la actividad entera (la sala, la barra «Has conocido a 4 de 9» y las cartas), con
///   [ModoJuzgado.salaVistas] (un juicio de personas adultas) o [ModoJuzgado.menores] (la audiencia del caso de
///   Sergio en el Juzgado de Menores, sin público).
/// - [RolJuzgado], [FuenteJuzgado], [NotaJuzgado] y [DatosJuzgado]: los textos, con sus fuentes del BOE.
/// - [CartaRol]: la carta de una persona, por si se quiere enseñar fuera de la sala.
/// - [MontajeJuzgado], [RepartoJuzgado] y [MueblesJuzgado]: el pixel art. La sala de vistas y sus personajes son los
///   de lib/pixel/escenarios y lib/pixel/personajes; la sala de menores, su reparto y el público son de esta carpeta.
///
/// ```dart
/// JuzgadoExplorable(
///   modo: ModoJuzgado.menores,
///   onTodosDescubiertos: () => ref.read(progresoProvider.notifier).desbloquear('R-quien-es-quien'),
/// );
/// ```
///
/// Los textos están pendientes de revisión jurídica: `DatosJuzgado.de(modo).validado` es false y la actividad lo dice
/// en una franja. Hasta que alguien con formación jurídica los revise, el juego solo debería abrirla en modo DEMO, con
/// el interruptor de borradores (la misma regla que el contenido con «validado»).
library;

export 'carta_rol.dart' show CartaRol, EnhorabuenaJuzgado, IndicacionJuzgado, NotaSala;
export 'juzgado_explorable.dart';
export 'reparto_juzgado.dart' show RepartoJuzgado;
export 'roles_juzgado.dart';
export 'sala_juzgado.dart'
    show ModoJuzgado, MontajeJuzgado, MueblesJuzgado, PuestoJuzgado, spriteDeReserva, spriteDelRol;
