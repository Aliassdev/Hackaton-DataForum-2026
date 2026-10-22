import 'texto.dart';

// Red de seguridad dentro de la app (sección 10.2: «ante la duda, ofrecer ayuda»).
//
// La detección de verdad está en el backend. Esto solo sirve para que, si no hay conexión y una pregunta suena a
// peligro, se enseñen igualmente los teléfonos de ayuda (llamar funciona sin datos). No se guarda ni se envía nada.

const _expresionesCrisis = [
  'quiero morir',
  'no quiero vivir',
  'quitarme la vida',
  'matarme',
  'me van a matar',
  'suicid',
  'hacerme dano',
  'autolesion',
  'tengo miedo de volver a casa',
  'estoy en peligro',
  'me va a matar',
  'me quiere matar',
  'me quieren matar',
  'miedo de mi padre',
  'miedo de mi madre',
];

/// true si [texto] contiene alguna expresión de peligro (sin que importen tildes ni mayúsculas).
bool pareceCrisis(String texto) {
  final normal = normalizar(texto);
  return _expresionesCrisis.any(normal.contains);
}
