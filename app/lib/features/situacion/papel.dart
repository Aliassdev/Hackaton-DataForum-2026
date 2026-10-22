import '../../core/api/models.dart';
import '../../core/entrada.dart';
import '../../core/texto.dart';
import '../../widgets/iconos/iconos.dart';

/// Los cuatro papeles de «Mi situación»: los tres del contrato de la API ([RolProceso], sección 8) y «Me van a
/// escuchar», en un proceso de familia. Ese cuarto tiene su itinerario (itinerarios/escuchado_familia.json) y su ruta
/// (/situacion/escuchado_familia), pero no es un papel de la API: desde él, Pregunta se abre sin situación.
///
/// Los textos hablan del proceso, nunca de lo que pasó, con palabras que entiende alguien de 11 años.
enum PapelSituacion {
  testigo('testigo', RolProceso.testigo, RolEntrada.testigo),
  victima('victima', RolProceso.victima, RolEntrada.victima),
  investigado('investigado', RolProceso.investigado, RolEntrada.investigado),
  escuchadoFamilia('escuchado_familia', null, RolEntrada.escuchadoFamilia);

  const PapelSituacion(this.id, this.rolProceso, this.rolEntrada);

  /// El de la ruta (`/situacion/<id>`) y el del fichero del itinerario (`itinerarios/<id>.json`).
  final String id;

  /// El papel para la API y para Pregunta (`/pregunta?situacion=`). null en «Me van a escuchar».
  final RolProceso? rolProceso;

  /// El papel equivalente del ticket (entradaProvider).
  final RolEntrada rolEntrada;

  /// El papel de la ruta (/situacion/:rol), sin que importen las mayúsculas ni las tildes. null si no es ninguno.
  static PapelSituacion? deId(String? id) {
    if (id == null) return null;
    final clave = normalizar(id.trim());
    return values.where((p) => p.id == clave).firstOrNull;
  }

  static PapelSituacion deRolProceso(RolProceso rol) => switch (rol) {
    RolProceso.testigo => testigo,
    RolProceso.victima => victima,
    RolProceso.investigado => investigado,
  };

  /// El papel del ticket, o null si no lo dice («No lo sé» o sin responder).
  static PapelSituacion? deEntrada(RolEntrada? rol) => switch (rol) {
    RolEntrada.testigo => testigo,
    RolEntrada.victima => victima,
    RolEntrada.investigado => investigado,
    RolEntrada.escuchadoFamilia => escuchadoFamilia,
    RolEntrada.noLoSe || null => null,
  };

  String get ruta => '/situacion/$id';

  /// Nombre del papel en el selector y en las cabeceras.
  String get nombre => switch (this) {
    testigo => 'Testigo',
    victima => 'Víctima',
    investigado => 'Investigado o investigada',
    escuchadoFamilia => 'Me van a escuchar',
  };

  /// Para usarlo dentro de una frase: «Pregunta como testigo».
  String get enFrase => switch (this) {
    testigo => 'testigo',
    victima => 'víctima',
    investigado => 'investigado o investigada',
    escuchadoFamilia => 'alguien a quien van a escuchar',
  };

  /// Una frase debajo del nombre.
  String get resumen => switch (this) {
    testigo => 'Te piden que cuentes lo que viste u oíste.',
    victima => 'Alguien te ha hecho daño. La justicia tiene que protegerte.',
    investigado => 'La justicia está revisando si hiciste algo que la ley no permite.',
    escuchadoFamilia => 'En un proceso de familia, por ejemplo una separación.',
  };

  String get explicacion => switch (this) {
    testigo =>
      'Ser testigo significa que la justicia quiere escuchar lo que sabes. Tu papel es contarlo con tus palabras. '
          'Si no entiendes algo, puedes pedir que te lo expliquen.',
    // Sin dar por hecha una investigación: con «Aún no hay proceso» también se es víctima.
    victima =>
      'Ser víctima significa que alguien te ha hecho daño. La justicia tiene que protegerte y explicarte cada paso. '
          'Puedes preguntar todo lo que no entiendas.',
    investigado =>
      'Ser investigado o investigada significa que la justicia está revisando si hiciste algo que la ley no '
          'permite. Todavía no se ha decidido nada.',
    escuchadoFamilia =>
      'Van a decidir algo sobre tu vida, por ejemplo con quién vives, y quieren saber lo que piensas. No es un '
          'examen: no hay respuestas buenas ni malas.',
  };

  /// Una frase para dar tranquilidad.
  String get tranquilidad => switch (this) {
    testigo => 'No estás en ningún lío. Contar lo que sabes ayuda a que la justicia decida bien.',
    victima => 'Nada de esto es culpa tuya. Puedes pedir que te expliquen cada paso.',
    investigado =>
      'Tienes derecho a que te lo expliquen con palabras claras. Lo que pasa después depende de tu edad: '
          'abajo te lo cuento.',
    escuchadoFamilia => 'No estás en ningún lío. Tu opinión cuenta y puedes pedir que te expliquen cada paso.',
  };

  /// Icono de TuTurno del papel: el micrófono de quien cuenta lo que sabe, el escudo de la protección, el juzgado
  /// donde se revisa lo que pasó (sin juzgar: todavía no se ha decidido nada; nunca la balanza) y el micrófono del
  /// turno de palabra de quien va a ser escuchado.
  TuIcono get tuIcono => switch (this) {
    testigo => TuIcono.microfono,
    victima => TuIcono.escudo,
    investigado => TuIcono.juzgado,
    escuchadoFamilia => TuIcono.turnoPalabra,
  };

  /// «Tu camino como víctima».
  String get tituloCamino => switch (this) {
    testigo => 'Tu camino como testigo',
    victima => 'Tu camino como víctima',
    investigado => 'Tu camino si te investigan',
    escuchadoFamilia => 'Tu camino cuando te escuchan',
  };

  /// La línea del papel en la carátula de «Tu guía»: sin nombres ni datos.
  String get papelCaratula => switch (this) {
    escuchadoFamilia => 'Te van a escuchar en un proceso de familia',
    _ => 'Tu papel: $enFrase',
  };

  /// El botón que lleva a Pregunta: con el papel, salvo «Me van a escuchar» (no es un papel de la API).
  String get textoPregunta => rolProceso == null ? 'Pregúntale a TuTurno' : 'Pregunta como $enFrase';
}
