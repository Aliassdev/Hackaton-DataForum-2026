/// Los fondos de los lugares de «Vive el caso» en pixel art: 160 × 96 píxeles en la paleta compartida, con los muebles
/// que tapan a quien está detrás y los puestos donde van los personajes.
///
/// ```dart
/// import 'package:tuturno/pixel/escenarios/escenarios.dart';
///
/// final lugar = EscenariosPixel.de(escena.lugar); // acepta «Sala de espera», «salaEspera»… y si no, uno neutro
/// EscenaPixel(
///   fondo: lugar.fondo,
///   descripcion: lugar.descripcion,
///   elementos: lugar.componer([
///     lugar.colocar('izquierda', lucia, id: 'lucia', etiqueta: 'Lucía'),
///     lugar.colocar('derecha', tia, id: 'tia', etiqueta: 'Su tía Elena'),
///   ]),
/// );
/// ```
///
/// En la sala de vistas, los sitios de cada uno están en [PuestoVista] (también en `puestos`, por su clave).
library;

import '../motor/motor.dart';
import 'casa.dart';
import 'colegio.dart';
import 'comisaria.dart';
import 'despues.dart';
import 'escenario_pixel.dart';
import 'fiscalia.dart';
import 'generico.dart';
import 'habitacion.dart';
import 'instituto.dart';
import 'juzgado.dart';
import 'sala_espera.dart';
import 'sala_gesell.dart';
import 'sala_observacion.dart';
import 'sala_vistas.dart';

export 'escenario_pixel.dart' show EscenarioPixel;
export 'sala_vistas.dart' show PuestoVista;

/// Todos los lugares con fondo. Cada fondo se pinta la primera vez que se pide y se guarda.
abstract final class EscenariosPixel {
  /// Las claves de los lugares con fondo propio, más o menos en el orden en que salen en los casos.
  static const lugares = <String>[
    'casa',
    'colegio',
    'instituto',
    'juzgado',
    'sala_espera',
    'sala_gesell',
    'sala_observacion',
    'sala_vistas',
    'fiscalia',
    'comisaria',
    'habitacion',
    'despues',
  ];

  /// La clave del lugar de reserva: una sala tranquila para los lugares que no tienen fondo.
  static const reserva = 'generico';

  /// El lugar [lugar] (con o sin tildes, mayúsculas, espacios, guiones, artículos o en camelCase, y con algunos
  /// sinónimos: «Sala de vistas», «salaEspera», «tribunal», «Fiscalía de Menores»…) o, si no tiene fondo, el de
  /// reserva ([generico]).
  static EscenarioPixel de(String lugar) => (_porClave[clave(lugar)] ?? _porClave[reserva]!)();

  /// El fondo del lugar [lugar], con la misma tolerancia y la misma reserva que [de].
  static Sprite porLugar(String lugar) => de(lugar).fondo;

  /// Si [lugar] tiene fondo propio.
  static bool tiene(String lugar) => clave(lugar) != null;

  /// La clave de [lugar] en [lugares], o null si no tiene fondo propio.
  static String? clave(String lugar) {
    final camel = lugar.trim().replaceAllMapped(RegExp('([a-zñáéíóú])([A-ZÑÁÉÍÓÚ])'), (m) => '${m[1]}_${m[2]}');
    final palabras = _sinTildes(camel.toLowerCase())
        .split(RegExp('[^a-z0-9]+'))
        .where((palabra) => palabra.isNotEmpty && !_vacias.contains(palabra));
    final normal = palabras.join('_');
    final alias = _alias[normal] ?? normal;
    return lugares.contains(alias) ? alias : null;
  }

  static EscenarioPixel get casa => escenarioCasa;
  static EscenarioPixel get colegio => escenarioColegio;
  static EscenarioPixel get instituto => escenarioInstituto;
  static EscenarioPixel get juzgado => escenarioJuzgado;
  static EscenarioPixel get salaEspera => escenarioSalaEspera;
  static EscenarioPixel get salaGesell => escenarioSalaGesell;
  static EscenarioPixel get salaObservacion => escenarioSalaObservacion;
  static EscenarioPixel get salaVistas => escenarioSalaVistas;
  static EscenarioPixel get fiscalia => escenarioFiscalia;
  static EscenarioPixel get comisaria => escenarioComisaria;
  static EscenarioPixel get habitacion => escenarioHabitacion;
  static EscenarioPixel get despues => escenarioDespues;

  /// El lugar de reserva.
  static EscenarioPixel get generico => escenarioGenerico;

  /// Los de [lugares], en orden (pinta todos los que no se hayan pintado aún).
  static List<EscenarioPixel> get todos => [for (final lugar in lugares) _porClave[lugar]!()];

  /// Los sitios de la sala de vistas por su clave («jueza», «abogada_victima»…), en píxeles del fondo.
  static Map<String, PuntoPixel> get puestosSalaVistas => {
    for (final puesto in PuestoVista.values) puesto.clave: puesto.punto,
  };

  // Funciones y no los lugares en sí: así cada fondo se pinta cuando se pide por primera vez.
  static final Map<String, EscenarioPixel Function()> _porClave = {
    'casa': () => escenarioCasa,
    'colegio': () => escenarioColegio,
    'instituto': () => escenarioInstituto,
    'juzgado': () => escenarioJuzgado,
    'sala_espera': () => escenarioSalaEspera,
    'sala_gesell': () => escenarioSalaGesell,
    'sala_observacion': () => escenarioSalaObservacion,
    'sala_vistas': () => escenarioSalaVistas,
    'fiscalia': () => escenarioFiscalia,
    'comisaria': () => escenarioComisaria,
    'habitacion': () => escenarioHabitacion,
    'despues': () => escenarioDespues,
    'generico': () => escenarioGenerico,
  };

  /// Palabras que no cuentan: «En la sala de espera» es «sala_espera».
  static const _vacias = {'el', 'la', 'los', 'las', 'lo', 'de', 'del', 'en', 'un', 'una', 'al', 'mi', 'su'};

  static const _alias = {
    'hogar': 'casa',
    'salon': 'casa',
    'piso': 'casa',
    'escuela': 'colegio',
    'cole': 'colegio',
    'aula': 'colegio',
    'clase': 'colegio',
    'primaria': 'colegio',
    'centro_educativo': 'colegio',
    'ies': 'instituto',
    'insti': 'instituto',
    'secundaria': 'instituto',
    'pasillo': 'instituto',
    'tribunal': 'juzgado',
    'juzgados': 'juzgado',
    'vestibulo': 'juzgado',
    'entrada_juzgado': 'juzgado',
    'palacio_justicia': 'juzgado',
    'ciudad_justicia': 'juzgado',
    'espera': 'sala_espera',
    'sala_amigable': 'sala_espera',
    'gesell': 'sala_gesell',
    'camara_gesell': 'sala_gesell',
    'sala_entrevista': 'sala_gesell',
    'entrevista': 'sala_gesell',
    'observacion': 'sala_observacion',
    'otra_sala': 'sala_observacion',
    'sala_control': 'sala_observacion',
    'sala_vista': 'sala_vistas',
    'vistas': 'sala_vistas',
    'vista': 'sala_vistas',
    'juicio': 'sala_vistas',
    'sala_juicio': 'sala_vistas',
    'sala_juicios': 'sala_vistas',
    'audiencia': 'sala_vistas',
    'sala_audiencias': 'sala_vistas',
    'fiscalia_menores': 'fiscalia',
    'despacho_fiscal': 'fiscalia',
    'policia': 'comisaria',
    'comisaria_policia': 'comisaria',
    'oficina_denuncias': 'comisaria',
    'dormitorio': 'habitacion',
    'cuarto': 'habitacion',
    'parque': 'despues',
    'atardecer': 'despues',
    'final': 'despues',
    'epilogo': 'despues',
  };

  static String _sinTildes(String texto) => texto.replaceAllMapped(
    RegExp('[áàäâéèëêíìïîóòöôúùüûñç]'),
    (m) => const {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', //
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ñ': 'n', 'ç': 'c',
    }[m[0]]!,
  );
}
