// Textos de «Mis preguntas» y «Enseñar en grande» (plan v2, producto §5.2): de tú, en lectura fácil, sin preguntar
// nunca qué pasó.

const tituloMisPreguntas = 'Mis preguntas';
const entradillaMisPreguntas =
    'Apunta lo que quieres pedir o preguntar y enséñaselo a las personas que llevan tu caso. Tienes derecho a que te '
    'lo expliquen con palabras que entiendas.';
const fuenteEntradilla = 'LO 1/1996, art. 9.1';

const seccionPedir = 'Quiero pedir';
const seccionPreguntar = 'Quiero preguntar';

const pistaDuda = 'Escribe tu duda';
const recordatorioDuda = 'Escribe solo tu duda, no lo que pasó. Esto se guarda solo en este móvil.';
const botonAnadir = 'Añadir';
const tituloIdeas = 'Ideas de preguntas';
const tituloIdeasParaTi = 'Ideas para ti';

/// Las 8 ideas de preguntas sobre el proceso (sin afirmaciones jurídicas).
const ideasPreguntas = [
  '¿Me puedes explicar qué va a pasar hoy?',
  '¿Quién va a estar en la sala?',
  '¿Puedo hacer un descanso si lo necesito?',
  '¿Me puedes repetir la pregunta con otras palabras?',
  '¿Puedo decir «no lo sé» o «no me acuerdo»?',
  '¿Puede estar conmigo una persona de confianza?',
  '¿Qué pasa después de hoy?',
  '¿Cuándo me contaréis lo que se decida?',
];

const textoYaPreguntado = 'Ya lo he preguntado';
const textoEditar = 'Editar';
const textoQuitar = 'Quitar';
String textoOrigen(String origen) => 'De: $origen';

const vacioPedir = 'Aún no has apuntado nada para pedir. En Mi situación, toca «Apuntar» junto a lo que quieras pedir.';
const vacioPreguntar = 'Aún no has escrito ninguna duda. Escríbela arriba o elige una idea.';
const vacioTodo =
    'Aún no has apuntado nada. En Mi situación, toca «Apuntar» en lo que quieras pedir, o escribe aquí tu duda.';
const botonIrMiSituacion = 'Ir a Mi situación';

const botonEnsenar = 'Enseñar en grande';
const botonBorrarTodas = 'Borrar todas';
const confirmarBorrarTodas = '¿Borrar todas tus preguntas? No se puede deshacer.';
const botonCancelar = 'Cancelar';
const botonBorrar = 'Borrar';
const textoMaximo = 'Has llegado a 30. Quita alguna para apuntar más.';
const textoRepetida = 'Ya la tienes apuntada.';
const textoApuntada = 'Apuntada en «Quiero preguntar».';
const textoBorradas = 'Hecho. Ya no tienes preguntas apuntadas.';

// Enseñar en grande.
const etiquetaPedir = 'QUIERO PEDIR';
const etiquetaPreguntar = 'QUIERO PREGUNTAR';
const botonAnterior = 'Anterior';
const botonSiguiente = 'Siguiente';
const botonCerrar = 'Cerrar';
const vacioEnsenar = 'No hay nada que enseñar todavía. Apunta antes lo que quieras pedir o preguntar.';
