import '../motor/motor.dart';
import 'escenario_pixel.dart';
import 'teselas.dart';

/// Un lugar cualquiera, para cuando una escena pasa en un sitio que no tiene fondo propio: una sala tranquila con una
/// ventana, una planta y un cuadro, sin nada que la ate a ningún sitio concreto.
final escenarioGenerico = EscenarioPixel(
  lugar: 'generico',
  descripcion: 'Una sala tranquila con una ventana y una planta.',
  fondo: Sprite('generico', _pintarGenerico()),
  puestos: const {'izquierda': (x: 40, y: 89), 'centro': (x: 80, y: 91), 'derecha': (x: 120, y: 89)},
);

const _suelo = 60;

List<String> _pintarGenerico() {
  final l = LienzoPixel(anchoFondo, altoFondo, 'P')
    ..mosaico(['PPPPPPPh'], 0, 0, anchoFondo, 44)
    ..zocalo(44, _suelo, color: 'c', sombra: 'a', luz: 'h', moldura: 'a', panel: 20, desfase: 4)
    ..tablas(_suelo, semilla: 29)
    ..luzEnSuelo(62, 98, _suelo + 1, 90, {'m': 'u', 't': 'm'});
  l
    ..ventana(60, 9, 40, 28, hojas: 2, sol: true, semilla: 30)
    ..cortinas(60, 6, 40, 41, tela: 'Y', luz: 'y')
    ..cuadro(20, 14, 20, 16, _flor, color: 'm', luz: 'u')
    ..apoyar(plantaGrande, 131, 67)
    ..sombraSuelo(135, 65, 12);
  return l.filas;
}

const _flor = [
  'hhhhhhhhhhhhhhhh',
  'hhhhhhsshhhhhhhh',
  'hhhhhssYsshhhhhh',
  'hhhhhsYYYshhhhhh',
  'hhhhhhssshhhhhhh',
  'hhhhhhhvhhhhhhhh',
  'hhhhhvvvhhhhhhhh',
  'hhhhhhhvvhhhhhhh',
  'hhhhhhhvhhhhhhhh',
  'hhhhhhRRRRhhhhhh',
  'hhhhhhRrrRhhhhhh',
  'hhhhhhhRRhhhhhhh',
];
