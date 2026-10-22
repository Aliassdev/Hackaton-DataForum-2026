// Textos de «Vive el caso». Frases cortas, de tú, sin culpar a nadie y sin preguntar nunca qué ha pasado.

const tituloJuego = 'Vive el caso';
const textoCabeceraJuego = 'Acompaña a chicos y chicas en su caso, toma decisiones y gana cartas con tus derechos.';
const tituloElegirCaso = 'Elige un caso';
const tituloColeccion = 'Tus cartas de derechos';
const notaCasosInventados =
    'Los casos son inventados y no tienen escenas violentas: tratan de cómo funciona el proceso, no de lo que pasó.';

const cargandoCasos = 'Preparando los casos…';
const cargandoCaso = 'Preparando el caso…';
const errorCasos = 'No hemos podido cargar los casos. Prueba otra vez.';
const sinCasosTitulo = 'Todavía no hay casos';
const sinCasosMensaje = 'Muy pronto podrás jugar el primero. Mientras, puedes preguntar tus dudas.';
const casoNoEncontradoTitulo = 'Este caso no está';
const casoNoEncontradoMensaje = 'Puede que lo hayan cambiado. Vuelve a la lista y elige otro.';

const ctaEmpezar = 'Empezar';
const ctaSeguirCaso = 'Seguir';
const ctaOtraVez = 'Jugar otra vez';
const estadoNuevo = 'Nuevo';
const estadoTerminado = 'Terminado';

const tuDecides = 'Tú decides';
const tituloAcierto = '¡Bien visto!';
const tituloFallo = 'No es así';
const avisoCartaNueva = '¡Has ganado una carta de derecho! Recógela para verla de cerca.';
const avisoCartaRepetida = 'Esta carta ya estaba en tu colección.';
const pistaOtraCarta = 'Pista: en esta escena hay otra carta por descubrir. Vuelve a jugar para encontrarla.';

const botonEscuchar = 'Escuchar';
const botonParar = 'Parar';
const botonSeguir = 'Seguir';
const botonProbarOtraVez = 'Probar otra vez';
const botonRecogerCarta = 'Recoger tu carta';
const botonTerminar = 'Terminar el caso';

const menuLeerEnVozAlta = 'Leer en voz alta';
const menuEmpezarDeNuevo = 'Empezar de nuevo';
const dialogoReiniciarTitulo = '¿Empezar de nuevo?';
const dialogoReiniciarTexto = 'Volverás a la primera escena. Las cartas que ya has ganado se quedan en tu colección.';
const cancelar = 'Cancelar';

const tituloFinal = '¡Caso completado!';
const tituloCartasDelCaso = 'Tus cartas de este caso';
const tituloYAhora = '¿Y ahora qué?';
const accesoAprende = 'Aprende más';
const accesoAprendeTexto = 'Lecciones cortas sobre tus derechos, a tu ritmo.';
const accesoPregunta = 'Pregunta tus dudas';
const accesoPreguntaTexto = 'Escribe o habla. Te responde y te dice de qué ley sale.';
const botonVolverAJugar = 'Volver a jugar';
const botonVerCasos = 'Ver todos los casos';

/// «Has acompañado a Lucía hasta el final…».
String textoFinal(String protagonista) => protagonista.isEmpty
    ? 'Has llegado al final. Ahora sabes cómo funciona este proceso y qué derechos hay en él.'
    : 'Has acompañado a $protagonista hasta el final. Ahora sabes cómo funciona su proceso y qué derechos tiene.';

/// «Te falta 1 carta…» o «Te faltan 2 cartas…».
String textoCartasQueFaltan(int faltan) => faltan == 1
    ? 'Te falta 1 carta. Vuelve a jugar y prueba otras respuestas: hay cartas escondidas.'
    : 'Te faltan $faltan cartas. Vuelve a jugar y prueba otras respuestas: hay cartas escondidas.';

/// «Esta carta se consigue en el caso de Lucía.»
String textoCartaBloqueada(String protagonista) => protagonista.isEmpty
    ? 'Esta carta se consigue jugando uno de los casos.'
    : 'Esta carta se consigue en el caso de $protagonista.';

/// «Caso de Lucía».
String tituloCaso(String protagonista) => protagonista.isEmpty ? tituloJuego : 'Caso de $protagonista';

/// «Lucía, 11 años».
String presentacion(String protagonista, int? edad) => edad == null ? protagonista : '$protagonista, $edad años';
