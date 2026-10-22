import '../../core/api/models.dart';
import '../../core/voz/stt.dart';
import '../../widgets/iconos/tu_icono.dart';

// Textos de «Pregunta». Frases cortas, de tú y con palabras que entiende alguien de 11 años.
// El agente habla del proceso y nunca pregunta qué ha pasado.

const textoPresentacion =
    'Soy una IA. Pregúntame sobre tus derechos o sobre cómo funciona un juicio. No guardo lo que hablamos.';

const textoAvisoIa = 'Soy una IA y puedo equivocarme. Si es urgente, pulsa Ayuda.';

/// Una pregunta de ejemplo con su icono de TuTurno (decorativo).
typedef Ejemplo = ({String texto, TuIcono icono});

/// Preguntas de ejemplo: cubren los casos de Lucía, Sergio y Sara, más la de la demo.
/// Siempre sobre el proceso, nunca contando lo que pasó (eso el backend lo trataría como «hechos»).
const ejemplos = <Ejemplo>[
  (texto: '¿Qué es la Sala Gesell?', icono: TuIcono.grabacion),
  (texto: '¿Qué hace la Fiscalía de Menores si hay acoso escolar?', icono: TuIcono.escudo),
  (texto: '¿Qué hago si difunden fotos mías?', icono: TuIcono.candado),
  (texto: 'Si tengo 13 años y hago algo malo, ¿me pueden juzgar?', icono: TuIcono.juzgado),
];

/// Con «Mi situación», preguntas acotadas a ese papel (sección 4.4). Son preguntas, no afirmaciones jurídicas.
const ejemplosPorRol = <RolProceso, List<Ejemplo>>{
  RolProceso.testigo: [
    (texto: '¿Por qué quieren hablar conmigo?', icono: TuIcono.pregunta),
    (texto: '¿Qué es la Sala Gesell?', icono: TuIcono.grabacion),
    (texto: '¿Qué pasa después de declarar?', icono: TuIcono.miSituacion),
    (texto: '¿Puede acompañarme alguien de confianza?', icono: TuIcono.personaConfianza),
  ],
  RolProceso.victima: [
    (texto: '¿Tendré que ver a la persona denunciada?', icono: TuIcono.escudo),
    (texto: '¿Qué hace la Fiscalía de Menores?', icono: TuIcono.juzgado),
    (texto: '¿Quién puede acompañarme?', icono: TuIcono.personaConfianza),
    (texto: '¿Puedo pedir ayuda sin que se entere todo el mundo?', icono: TuIcono.candado),
  ],
  RolProceso.investigado: [
    (texto: '¿Qué derechos tengo si me investigan?', icono: TuIcono.fuente),
    (texto: '¿Puedo tener abogado o abogada?', icono: TuIcono.personaConfianza),
    (texto: '¿Qué pasa si tengo menos de 14 años?', icono: TuIcono.juzgado),
  ],
};

/// Los ejemplos que tocan: los del papel elegido o los generales.
List<Ejemplo> ejemplosPara(RolProceso? situacion) => ejemplosPorRol[situacion] ?? ejemplos;

/// Si la respuesta no trae sugerencias, se ofrecen estas para seguir. Las de «hechos» son las de la sección 10.1,
/// paso 6: proponen seguir hablando del proceso.
const sugerenciasPorTipo = <TipoRespuesta, List<String>>{
  TipoRespuesta.hechos: ['¿Qué pasa si se denuncia?', '¿A quién puedo pedir ayuda?'],
  TipoRespuesta.fueraDeAmbito: [
    '¿Qué derechos tengo si me toca declarar?',
    '¿Qué es la Fiscalía de Menores?',
    '¿Qué es la Sala Gesell?',
  ],
};

String etiquetaSituacion(RolProceso rol) => switch (rol) {
  RolProceso.testigo => 'Preguntas como testigo',
  RolProceso.victima => 'Preguntas como víctima',
  RolProceso.investigado => 'Preguntas como investigado o investigada',
};

String mensajeProblemaVoz(ProblemaVoz problema) => switch (problema) {
  ProblemaVoz.sinPermiso => 'No puedo usar el micrófono. Puedes escribir tu pregunta.',
  ProblemaVoz.noTeOigo => 'No te he oído bien. Prueba otra vez o escribe tu pregunta.',
  ProblemaVoz.sinRed => 'Para usar la voz hace falta internet. Puedes escribir tu pregunta.',
  ProblemaVoz.ocupado => 'El micrófono está ocupado. Prueba otra vez en un momento.',
  ProblemaVoz.idioma => 'Tu móvil no reconoce la voz en español. Puedes escribir tu pregunta.',
  ProblemaVoz.otro => 'No he podido escucharte. Prueba otra vez o escribe tu pregunta.',
};

/// Lo que se va enseñando mientras llega la respuesta.
const pasosEsperando = ['Pensando', 'Buscando en las leyes', 'Preparando una respuesta clara'];
