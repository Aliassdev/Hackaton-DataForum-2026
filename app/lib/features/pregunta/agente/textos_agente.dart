import '../../../core/entrada.dart';
import '../textos.dart' show textoPresentacion;

// Textos del modo agente de «Pregunta». Frases cortas, de tú y para alguien de 11 años. Nunca se pregunta qué ha
// pasado.
//
// Sin promesas sobre lo que se guarda. Lo cierto: la app no guarda la conversación (solo vive en memoria y desaparece al
// salir), el backend de TuTurno no escribe lo que se pregunta en sus registros, y la voz pasa por ElevenLabs, que lo
// guarda según cómo esté configurado el agente. Por eso aquí nunca se dice que «se borra» ni que «no se guarda nada».

/// El mismo que en el modo texto: quién responde y qué no contar.
const textoPresentacionAgente = textoPresentacion;

/// Con la voz del agente: que se sepa antes de preguntar que contesta en alto.
const textoAvisoVozAlta =
    'El asistente contesta en voz alta. Baja el volumen o quita la voz si no quieres que se oiga.';

const etiquetaEjemplo = 'TuTurno · ejemplo';

/// La insignia de las respuestas de ejemplo y lo que lee el lector de pantalla.
const insigniaEjemplo = 'Ejemplo';
const semanticaEjemplo = 'Respuesta de ejemplo, no es en directo';

/// El agente ha cerrado la conversación (por ejemplo, por tiempo) o se ha cortado sin pregunta pendiente.
const textoCerrado = 'Se ha cerrado la conexión. Se vuelve a conectar cuando preguntes.';

const textoBorrarAgente = 'Desaparece de la pantalla y empiezas una conversación nueva con TuTurno.';

/// A los 8 s sin respuesta del agente: el enlace para que conteste el modo texto.
const textoContestarPorEscrito = 'Contestar por escrito';

// Banda de estado.
const tituloPreparando = 'Preparando la conversación…';
const tituloConectando = 'Conectando con TuTurno…';
const tituloHablando = 'TuTurno está hablando';
const tituloPensando = 'TuTurno está pensando…';
const tituloEscucho = 'Conectado: Tut te escucha';
const detalleEscucho = 'Escribe tu pregunta o pulsa el micrófono para dictarla.';
const tituloSinConexion = 'Sin conexión con TuTurno';
const tituloPausa = 'Conversación en pausa';
const detallePausa = 'Se vuelve a conectar cuando preguntes.';
const tituloSinVoz = 'La voz no responde ahora';
const detalleSinVoz = 'Te contesto por escrito. Puedes probar otra vez con la voz cuando quieras.';
const accionProbarVoz = 'Probar con voz';
const tituloEjemplo = 'Sin conexión con el asistente';
const detalleEjemplo = 'Estas respuestas son de ejemplo: no son en directo.';
const accionVolverATuTurno = 'Volver a TuTurno';
const detalleConversacionNueva = 'Conversación nueva: TuTurno no recuerda lo que hablasteis antes.';

// Hoja del perfil.
const tituloHojaPerfil = 'Para explicarte mejor';

/// Sin «solo en este móvil»: la edad, el proceso, el papel y el momento viajan, sin nombre, con cada pregunta (al
/// servidor de TuTurno en el modo texto y a ElevenLabs con la voz).
const textoHojaPerfil =
    'Es opcional. No te pregunto qué ha pasado. Solo esto, para explicarte mejor. '
    'Se guarda en este móvil y se envía con tus preguntas, sin tu nombre. Lo puedes cambiar cuando quieras.';
const preguntaEdad = '¿Cuántos años tienes?';
const preguntaProcedimiento = '¿Qué tipo de proceso es?';
const preguntaRol = '¿Qué papel tienes?';
const preguntaFase = '¿En qué momento estás?';
const opcionNoDecir = 'Prefiero no decirlo';
const opcionNoLoSe = 'No lo sé';

/// Resumen del perfil, por ejemplo «13 años · Penal · Víctima · Durante». Vacío si no hay nada.
String resumenPerfil(Entrada entrada) => [
  if (entrada.edad != null) '${entrada.edad} años',
  if (entrada.procedimiento != null && entrada.procedimiento != Procedimiento.noLoSe) entrada.procedimiento!.etiqueta,
  if (entrada.rol != null && entrada.rol != RolEntrada.noLoSe) entrada.rol!.etiqueta,
  if (entrada.fase != null) entrada.fase!.etiqueta,
].join(' · ');

/// La línea del perfil de la vista inicial: «Te explico para: 13 años · Penal · Víctima · Durante».
String textoResumenPerfil(String resumen) =>
    resumen.isEmpty ? 'Si me dices tu edad y tu situación, te lo explico mejor.' : 'Te explico para: $resumen';
