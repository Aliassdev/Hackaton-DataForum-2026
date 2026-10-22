import 'dibujos.dart';
import 'pieza.dart';

/// Iconos propios de TuTurno, dibujados en código con el estilo de papel recortado del logo.
///
/// [etiqueta] es lo que lee el lector de pantalla si el icono va solo.
enum TuIcono {
  inicio('Inicio'),
  juego('Vive el caso'),
  aprende('Aprende'),
  pregunta('Pregunta'),
  ayuda('Ayuda'),
  glosario('Glosario'),
  ajustes('Ajustes'),
  miSituacion('Mi situación'),
  racha('Racha'),
  xp('Puntos de experiencia'),
  nivel('Nivel'),
  carta('Carta de derechos'),
  sello('Sello'),
  ticket('Ticket de turno'),
  candado('Bloqueado'),
  check('Correcto'),
  cruz('Incorrecto'),
  microfono('Micrófono'),
  altavoz('Escuchar'),
  silencio('Sin sonido'),
  fuente('Fuente'),
  juzgado('Juzgado'),
  escudo('Protección'),
  grabacion('Grabación'),
  reloj('Hora'),
  personaConfianza('Persona de confianza'),
  telefono('Teléfono'),
  web('Web'),
  enviar('Enviar'),
  volver('Volver'),
  compartir('Compartir'),
  cerrar('Cerrar'),
  estrella('Estrella'),
  comodin('Comodín'),
  pasaporte('Pasaporte de derechos'),
  mision('Misión del día'),
  buscar('Buscar'),
  info('Información'),
  idea('Pista'),
  balanza('Balanza de la justicia'),
  toga('Toga'),
  estrado('Estrado'),
  campanilla('Campanilla'),
  selloConseguido('Sello conseguido'),
  expediente('Expediente'),
  citacion('Citación'),
  puertaSala('Puerta de la sala'),
  turnoPalabra('Tu turno de palabra'),
  ley('Ley'),
  manoAlzada('Pedir la palabra'),
  panelTurnos('Panel de turnos');

  const TuIcono(this.etiqueta);

  final String etiqueta;

  static final _piezas = <TuIcono, List<PiezaIcono>>{};

  /// Las piezas del dibujo (se construyen una vez y se reutilizan).
  List<PiezaIcono> get piezas => _piezas[this] ??= List.unmodifiable(dibujoDe(this));
}
