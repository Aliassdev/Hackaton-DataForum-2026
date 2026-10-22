// Textos de «Vive el caso». Frases cortas, de tú, sin culpar a nadie y sin preguntar nunca qué ha pasado. Dentro del
// juego no se usan «culpable», «condena», «veredicto» ni «caso cerrado», y «Empieza la audiencia» solo donde hay una
// audiencia de verdad (nunca en la Sala Gesell, que es una entrevista).

const tituloJuego = 'Vive el caso';
const textoCabeceraJuego = 'Acompaña a chicos y chicas en su caso, toma decisiones y gana cartas con tus derechos.';
const tituloElegirCaso = 'Elige un caso';
const tituloColeccion = 'Tus cartas de derechos';
const notaCasosInventados =
    'Los casos son inventados y no tienen escenas violentas: tratan de cómo funciona el proceso, no de lo que pasó.';

const cargandoCasos = 'Preparando los casos…';
const cargandoCaso = 'Preparando la sala…';
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

/// Encima de cada decisión: es el turno de quien juega.
const tuDecides = 'Tu turno';
const tituloAcierto = '¡Bien visto!';

/// Al fallar no se castiga ni se dice «casi» (hay respuestas que no están cerca): se explica.
const tituloFallo = 'Mira por qué:';
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
const menuOpciones = 'Más opciones';
const dialogoReiniciarTitulo = '¿Empezar de nuevo?';
const dialogoReiniciarTexto = 'Volverás a la primera escena. Las cartas que ya has ganado se quedan en tu colección.';
const cancelar = 'Cancelar';

const tituloCartaNueva = '¡Carta nueva!';
const botonAMiColeccion = '¡A mi colección!';

const tituloFinal = 'Caso completado';
const tituloCartasDelCaso = 'Tus cartas de este caso';
const tituloYAhora = '¿Y ahora qué?';
const accesoAprende = 'Aprende más';
const accesoAprendeTexto = 'Lecciones cortas sobre tus derechos, a tu ritmo.';
const accesoPregunta = 'Pregunta tus dudas';
const accesoPreguntaTexto = 'Escribe o habla. Te responde y te dice de qué ley sale.';
const botonVolverAJugar = 'Volver a jugar';
const botonVerCasos = 'Ver todos los casos';

/// Al final del caso de Sergio: el juzgado de menores por dentro (la ruta /juzgado).
const accesoJuzgadoMenores = 'Mira un juzgado de menores por dentro';
const accesoJuzgadoMenoresTexto = 'Toca a cada persona y descubre quién es y qué hace.';

/// Al final del caso de Sara: los recursos de Ayuda que le sirven a ella (lib/core/recursos_ayuda.dart).
const tituloSiTePasa = 'Si te pasa algo parecido';
const textoSiTePasa = 'Puedes pedir ayuda: no tienes que pasar por esto sola ni solo.';
const botonVerAyuda = 'Ver toda la ayuda';

/// Lo que dice Tut al abrir un caso, en la primera escena.
String saludoTut(String protagonista) => protagonista.isEmpty
    ? 'Soy Tut. Cuando sea tu turno, decides tú.'
    : 'Soy Tut. Vas a acompañar a $protagonista. Cuando sea tu turno, decides tú.';

/// «Has acompañado a Lucía hasta el final…».
String textoFinal(String protagonista) => protagonista.isEmpty
    ? 'Has llegado al final. Ahora sabes cómo funciona este proceso y qué derechos hay en él.'
    : 'Has acompañado a $protagonista hasta el final. Ahora sabes cómo funciona su proceso y qué derechos tiene.';

/// «Te falta 1 carta…» o «Te faltan 2 cartas…».
String textoCartasQueFaltan(int faltan) => faltan == 1
    ? 'Te falta 1 carta. Vuelve a jugar y prueba otras respuestas: hay cartas escondidas.'
    : 'Te faltan $faltan cartas. Vuelve a jugar y prueba otras respuestas: hay cartas escondidas.';

/// «Cartas de derecho conseguidas: 3».
String textoCartasConseguidas(int conseguidas) => 'Cartas de derecho conseguidas: $conseguidas';

/// «Siguiente caso: Sergio» (el botón lleva además una flecha pixel).
String botonSiguienteCaso(String protagonista) =>
    protagonista.isEmpty ? 'Siguiente caso' : 'Siguiente caso: $protagonista';

/// «Esta carta se consigue en el caso de Lucía.»
String textoCartaBloqueada(String protagonista) => protagonista.isEmpty
    ? 'Esta carta se consigue jugando uno de los casos.'
    : 'Esta carta se consigue en el caso de $protagonista.';

/// «Caso de Lucía».
String tituloCaso(String protagonista) => protagonista.isEmpty ? tituloJuego : 'Caso de $protagonista';

/// « · 11 años», lo que sigue a [tituloCaso] en la primera línea de la escena («Caso de Lucía · 11 años»). Vacío si no
/// se sabe la edad. Con espacio duro entre la cifra y «años».
String edadCaso(int? edad) => edad == null ? '' : ' · $edad\u00A0años';

/// «Lucía, 11 años».
String presentacion(String protagonista, int? edad) => edad == null ? protagonista : '$protagonista, $edad años';
