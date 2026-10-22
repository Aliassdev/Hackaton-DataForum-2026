import '../../../core/entrada.dart';

// Textos del modo agente de «Pregunta». Frases cortas, de tú y para alguien de 11 años. Sin promesas: lo que se guarde
// de la conversación depende de cómo configure B el agente en ElevenLabs. Nunca se pregunta qué ha pasado.

const textoPresentacionAgente =
    'Soy una IA. Pregúntame sobre tus derechos o sobre cómo funciona un juicio. Te contesto en voz alta y por escrito.';

const etiquetaEjemplo = 'TuTurno · ejemplo';

/// La pregunta se ha quedado 30 s sin respuesta.
const textoSinRespuesta = 'TuTurno no responde ahora mismo. Puedes reintentar o ver una respuesta de ejemplo.';

/// Se ha cortado la conexión mientras se esperaba la respuesta.
const textoCortado = 'Se ha cortado la conexión con TuTurno. Puedes reintentar o ver una respuesta de ejemplo.';

/// El agente ha cerrado la conversación (por ejemplo, por tiempo) o se ha cortado sin pregunta pendiente.
const textoCerrado = 'Se ha cerrado la conexión. Se vuelve a conectar cuando preguntes.';

const textoBorrarAgente = 'Se borra de la pantalla y empiezas una conversación nueva con TuTurno.';

// Banda de estado.
const tituloPreparando = 'Preparando la conversación…';
const tituloConectando = 'Conectando con TuTurno…';
const tituloHablando = 'TuTurno está hablando';
const tituloPensando = 'TuTurno está pensando…';
const tituloEscucho = 'Te escucho';
const detalleEscucho = 'Escribe tu pregunta o pulsa el micrófono para dictarla.';
const tituloNoResponde = 'TuTurno no responde ahora mismo';
const detalleNoResponde = 'Puedes reintentar o ver una respuesta de ejemplo.';
const tituloSinConexion = 'Sin conexión con TuTurno';
const tituloPausa = 'Conversación en pausa';
const detallePausa = 'Se vuelve a conectar cuando preguntes.';
const tituloEjemplo = 'Respuestas de ejemplo';
const detalleEjemplo = 'No son de TuTurno: sirven para ver cómo funciona.';
const detalleConversacionNueva = 'Conversación nueva: TuTurno no recuerda lo que hablasteis antes.';

// Hoja del perfil.
const tituloHojaPerfil = 'Para explicarte mejor';
const textoHojaPerfil =
    'Es opcional. No te pregunto qué ha pasado: solo esto, para adaptar lo que te explico. '
    'Se guarda en este móvil y lo puedes cambiar cuando quieras.';
const preguntaEdad = '¿Cuántos años tienes?';
const preguntaProcedimiento = '¿Qué tipo de proceso es?';
const preguntaRol = '¿Qué papel tienes?';
const preguntaFase = '¿En qué momento estás?';
const opcionNoDecir = 'Prefiero no decirlo';
const opcionNoLoSe = 'No lo sé';

/// Resumen del perfil para la vista inicial, por ejemplo «13 años · Testigo · Antes». Vacío si no hay nada.
String resumenPerfil(Entrada entrada) => [
  if (entrada.edad != null) '${entrada.edad} años',
  if (entrada.procedimiento != null && entrada.procedimiento != Procedimiento.noLoSe) entrada.procedimiento!.etiqueta,
  if (entrada.rol != null && entrada.rol != RolEntrada.noLoSe) entrada.rol!.etiqueta,
  if (entrada.fase != null) entrada.fase!.etiqueta,
].join(' · ');
