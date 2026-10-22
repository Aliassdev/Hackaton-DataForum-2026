/// Línea de pasos de «Mi situación» (A6, docs/ARQUITECTURA.md, secciones 4.4 y 9.5).
///
/// Para ponerla en SituacionScreen: en la columna de `_ConRol`, dentro del SingleChildScrollView que ya tiene, en
/// lugar del avance «Muy pronto» (`_PasosProximamente`):
///
/// ```dart
/// import '../pasos/pasos.dart';
///
/// LineaPasos(rol: rol.name) // rol: RolProceso (testigo, victima, investigado)
/// ```
///
/// - No hace scroll por sí misma, y no hace falta envolverla en `Entrada`: ya aparece con su propia entrada escalonada.
/// - Es un ConsumerWidget: le basta el ProviderScope de main() (lee contentProvider y entradaProvider).
/// - La fase de «Estás aquí» sale sola del formulario de entrada (entradaProvider), salvo que allí se eligiera otro
///   papel. Para forzarla: `LineaPasos(rol: 'victima', faseActual: Fase.durante)`.
/// - `encabezado: false` quita el título «Tu camino, paso a paso» si la pantalla pone el suyo.
/// - Lee `itinerarios/<rol>.json` con contentProvider (o el de assets/mock/content mientras content/ esté vacío).
///   También vale `'escuchado_familia'` (RolEntrada.valor). Sin itinerario visible enseña «Todavía no tengo los
///   pasos para este papel».
/// - Los colores salen del tema (tema.dart): vale en claro y en oscuro, con letra grande y con «reducir animaciones».
library;

export '../../core/entrada.dart' show Fase;
export 'linea_pasos.dart' show LineaPasos, textoSinPasos;
export 'modelos.dart' show Itinerario, Paso, faseDe;
export 'pasos_providers.dart' show carpetaItinerarios, faseDeEntrada, itinerarioProvider;
