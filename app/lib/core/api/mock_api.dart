import '../seguridad.dart';
import '../texto.dart';
import 'tuturno_api.dart';

/// Respuestas simuladas para trabajar sin backend (`--dart-define=USE_MOCK=true`). También son las respuestas de
/// ejemplo de Pregunta cuando el agente de voz no contesta (`respuestasEjemploProvider`).
///
/// Los JSON de ejemplo de la sección 8 ([ejemploAsk], [ejemploGrade] y [ejemploHealth]) son exactamente los del
/// documento: los compara el test de contrato. [ask] responde por palabras clave (texto normalizado con core/texto.dart)
/// a las preguntas de ejemplo de Pregunta, a las de cada papel, a sus sugerencias y a las frases del guion de la demo.
/// Los textos salen de los «Para explicarlo» de docs/MARCO_LEGAL.md, con su fuente; si no reconoce la pregunta, lo dice
/// ([respuestaSinConexion]) en vez de contestar otra cosa.
///
/// Antes que ninguna palabra clave va la red de seguridad (sección 10.2, «ante la duda, ofrecer ayuda»): las señales de
/// peligro (las suyas y las de core/seguridad.dart) dan la plantilla de `crisis`, y quien cuenta que le hacen daño, la
/// de `hechos` con ANAR, sin hablar de lo que pasó. Las plantillas son las de content/seguridad.json (sección 9.7). La
/// detección real está en el backend.
class MockTuTurnoApi implements TuTurnoApi {
  MockTuTurnoApi({this.latencia = const Duration(milliseconds: 600)});

  final Duration latencia;

  /// Sección 8.1.
  static const ejemploAsk = <String, Object?>{
    'tipo': 'normal',
    'respuesta': 'Antes de los 14 años no se puede exigir responsabilidad penal en España [A-017]...',
    'fuentes': [
      {
        'id': 'A-017',
        'titulo': 'Antes de los 14 años no hay responsabilidad penal',
        'norma': 'LO 5/2000',
        'articulo': '3',
      },
    ],
    'sugerencias': ['¿Qué pasa a partir de los 14?', '¿Qué hace la Fiscalía de Menores?'],
    'terminos': ['responsabilidad penal', 'Fiscalía de Menores'],
    'latencia_ms': 2140,
  };

  /// Sección 8.2.
  static const ejemploGrade = <String, Object?>{
    'puntuacion': 0.67,
    'cubiertas': [
      'Tienes derecho a que te escuchen en lo que te afecta',
      'A partir de los 12 años se da por hecho que tienes madurez',
    ],
    'faltan': ['Tu opinión se tiene en cuenta según tu edad y madurez'],
    'feedback': '¡Muy bien! Te falta una idea: tu opinión se tiene en cuenta según tu edad y madurez.',
  };

  /// Las ideas de los otros «Dilo con tus palabras» del contenido de ejemplo (assets/mock/content/ejercicios), una lista
  /// por concepto. Así, sin backend, cada «Dilo» enseña sus propias ideas y no las de C-ser-oido.
  static const _ideasPorConcepto = <String, List<String>>{
    'C-fiscalia': [
      'Defiende los derechos de los menores',
      'Vigila que el proceso sea justo',
      'Dirige la investigación',
    ],
    'C-comunicar-violencia': [
      'Puede contarlo él mismo o ella misma',
      'Puede contárselo a la policía, a la Fiscalía, a un juzgado o a servicios sociales',
      'Los canales para contarlo tienen que ser seguros y confidenciales',
    ],
    'C-que-pedir': [
      'Que se lo expliquen todo con palabras claras',
      'Ir acompañada de una persona de confianza',
      'Pedir medidas para que la protejan',
    ],
    'C-sala-gesell': [
      'Tu entrevista se graba en vídeo',
      'La grabación vale para el juicio',
      'Normalmente no tienes que ir al juicio',
    ],
    'C-sin-contacto': [
      'Los juzgados se organizan para evitar que se crucen',
      'En la entrevista no tiene que verla cara a cara',
      'Se puede prohibir que se acerque o que se comunique con ella',
    ],
    // Unidades 3 a 7.
    'C-personas': [
      'El fiscal defiende tus derechos y puede pedir medidas para protegerte',
      'El equipo psicosocial puede hacerte la entrevista',
      'Tu persona de confianza puede acompañarte cuando declaras',
    ],
    'C-proceso': [
      'Alguien presenta una denuncia',
      'La Fiscalía decide si sigue adelante y dirige la investigación',
      'Al final, el juez de menores decide',
    ],
    'C-entender': [
      'Te tienen que hablar con palabras claras y sencillas',
      'Lo que te expliquen tiene que estar adaptado a tu edad',
      'Si no entiendes algo, puedes pedir que te lo repitan',
    ],
    'C-proteccion': [
      'Se evita que se cruce con la persona acusada',
      'Se protege su intimidad y no se puede publicar nada que la identifique',
      'Tienen en cuenta su opinión para decidir cómo protegerla',
    ],
    'C-no-reenviar': [
      'Reenviarlas hace más daño a la persona que sale en ellas',
      'Pasar imágenes sexuales de un menor es un delito muy serio',
      'La culpa es de quien las difunde, no de quien sale en ellas',
    ],
    'C-retirar-contenido': [
      'Puede pedirlo en el Canal prioritario de la AEPD',
      'Desde los 14 años puede hacerlo ella sola',
      'Como es menor, puede pedir a la red social que borre sus fotos y datos',
    ],
    'C-denunciar': [
      'Puede denunciarlo ella misma, sin un adulto',
      'Si lo cuenta en su instituto, se pone en marcha el protocolo',
      'La culpa es de quien difunde las imágenes, no suya',
    ],
    'C-medidas': [
      'Se aplica la ley penal de menores',
      'La Fiscalía de Menores dirige la investigación',
      'El juez de menores puede poner medidas, no penas como a los adultos',
    ],
    'C-derechos-detenido': [
      'Explicarle enseguida de qué se le acusa y por qué le detiene',
      'Decirle qué derechos tiene',
      'Hablarle con palabras claras que pueda entender',
    ],
    'C-escuchado-familia': [
      'Desde los 12 años, el juez tiene que escucharte',
      'Con menos de 12, puede escucharte si lo ve necesario',
      'Tu opinión cuenta, pero decide el juez',
    ],
    'C-seguir-familia': [
      'Lo normal es ayudar a la familia para que sigas en casa',
      'Solo si no te pueden proteger se busca otra forma de cuidarte',
      'Nadie puede prometer cómo acabará, pero te tienen que escuchar',
    ],
  };

  /// La respuesta de `grade` para [conceptoId]: la de la sección 8.2 para C-ser-oido (y para un concepto que no conoce)
  /// y, para los demás, la misma forma con sus ideas: las primeras explicadas y la última, la que falta.
  static Map<String, Object?> ejemploGradePara(String conceptoId) {
    final ideas = _ideasPorConcepto[conceptoId];
    if (ideas == null) return ejemploGrade;
    final falta = ideas.last;
    return {
      'puntuacion': 0.67,
      'cubiertas': ideas.sublist(0, ideas.length - 1),
      'faltan': [falta],
      'feedback': '¡Muy bien! Te falta una idea: ${falta[0].toLowerCase()}${falta.substring(1)}.',
    };
  }

  /// Sección 8.3.
  static const ejemploHealth = <String, Object?>{
    'estado': 'ok',
    'indice_a': 182,
    'indice_b': 940,
    'modelo_llm': 'claude-haiku-5-5',
    'demo': false,
  };

  /// Sección 9.7.
  static const plantillas = <TipoRespuesta, String>{
    TipoRespuesta.crisis: 'Siento que estés pasando por esto. No estás solo ni sola. Llama ahora al 900 20 20 10 (ANAR, gratis y a cualquier hora) o al 112 si estás en peligro. También puedes hablar con un adulto de confianza.',
    TipoRespuesta.hechos: 'Gracias por contármelo. Yo no soy la persona adecuada para escuchar lo que ha pasado, pero hay personas que sí: un adulto de confianza, el coordinador de bienestar de tu centro o ANAR (900 20 20 10). Si quieres, te explico qué pasa cuando se cuenta algo así.',
    TipoRespuesta.fueraDeAmbito:
        'Eso se sale de lo que sé. Puedo ayudarte con tus derechos y con cómo funciona la justicia.',
  };

  /// La plantilla de «hechos» del agente (content/seguridad.json de Iker, rama feat/api-base, `hechos[1]`), con el
  /// teléfono en cifras. Responde a la frase de Sergio del guion de la demo, para que el ejemplo diga lo mismo que el
  /// agente en directo.
  static const plantillaHechosAgente =
      'Te agradezco que me lo cuentes. De lo que pasó es mejor que hables con los profesionales de tu caso; yo no te '
      'voy a preguntar por ello. Lo que sí puedo hacer es explicarte qué va a pasar en el proceso. Y si te sientes mal, '
      'en ANAR te escuchan: 900 20 20 10. ¿Qué quieres saber del proceso?';

  /// Sección 10.1, paso 6: después de la plantilla de `hechos` se propone seguir hablando del proceso.
  static const sugerenciasHechos = ['¿Qué pasa si se denuncia?', '¿A quién puedo pedir ayuda?'];

  /// Si no reconoce la pregunta: lo dice, sin fuente, y propone las preguntas de la vista inicial de Pregunta.
  static const respuestaSinConexion =
      'Ahora mismo no tengo conexión para responder bien a eso. Prueba con una de las preguntas de abajo o pulsa Ayuda.';

  /// Las tres primeras preguntas de la vista inicial de Pregunta (`ejemplos` de features/pregunta/textos.dart): una
  /// por caso oficial (Lucía, Sergio y Sara).
  static const sugerenciasIniciales = [
    '¿Qué es la Sala Gesell?',
    '¿Qué hace la Fiscalía de Menores si hay acoso escolar?',
    '¿Qué hago si difunden fotos mías?',
  ];

  static const _crisis = ['quiero morir', 'hacerme dano', 'no quiero vivir', 'tengo miedo de volver a casa'];
  static const _hechos = ['me pegaron', 'me han pegado', 'me paso', 'me ha pasado'];

  /// Alguien cuenta, en primera persona, que le hacen daño («mi padre me pega», «mi tío me hizo algo malo»): no se habla
  /// de lo que pasó; se agradece y se da ANAR ([plantillaHechosAgente]). Ante la duda, mejor la plantilla que una
  /// respuesta que no toca (sección 10.2).
  static const _revelaciones = [
    ' me pega ',
    ' me pegan ',
    ' me pego ',
    ' me pegaba ',
    ' me pegaban ',
    ' nos pega ',
    ' nos pegan ',
    ' pega a mi ',
    ' me hizo ',
    ' me hicieron ',
    ' me ha hecho ',
    ' me han hecho ',
    ' me hace dano ',
    ' me hacen dano ',
    ' me hace cosas ',
    ' me hacen cosas ',
    ' me amenaza',
    ' me amenazo ',
    ' me ha echado ',
    ' me han echado ',
    ' me echo de casa ',
    ' me echaron de casa ',
    ' abus',
    ' miedo de mi ',
  ];

  /// «Me toca», «me tocó», «me tocaba»… salvo «me toca declarar» o «me tocó ir» (es mi turno de hacer algo).
  static final _meToca = RegExp(r' me (toca|tocan|toco|tocaba|tocaban|tocaron) (?!(a mi )?[a-z]*(ar|er|ir) )');

  /// Si [texto] (ya [_comparable]) cuenta que a quien escribe le hacen daño.
  static bool cuentaQueLeHacenDano(String texto) => _revelaciones.any(texto.contains) || _meToca.hasMatch(texto);

  /// «El que me insultaba era mi compañero de mesa.» (docs: guion de la demo, Sergio): cuenta lo que pasó.
  static const _hechosDelGuion = ['me insultaba', 'me insultaban'];
  static const _fueraDeAmbito = ['futbol', 'videojuego', 'receta'];

  @override
  Future<AskResponse> ask(AskRequest request) async {
    await Future<void>.delayed(latencia);
    final texto = _comparable(request.pregunta);
    bool contiene(List<String> expresiones) => expresiones.any(texto.contains);

    // Primero, la red de seguridad: el peligro (también el de core/seguridad.dart, el mismo que vigila el chat) y
    // quien cuenta lo que le pasa. Ninguna palabra clave de después puede quitarles la ayuda.
    if (contiene(_crisis) || pareceCrisis(request.pregunta)) return _plantilla(TipoRespuesta.crisis);
    if (contiene(_hechos)) return _plantilla(TipoRespuesta.hechos);
    if (contiene(_hechosDelGuion) || cuentaQueLeHacenDano(texto)) {
      return const AskResponse(
        tipo: TipoRespuesta.hechos,
        respuesta: plantillaHechosAgente,
        sugerencias: sugerenciasHechos,
        latenciaMs: 5,
      );
    }
    if (contiene(_fueraDeAmbito)) return _plantilla(TipoRespuesta.fueraDeAmbito);
    return respuestaPorClaves(request.pregunta, situacion: request.situacion) ??
        const AskResponse(
          tipo: TipoRespuesta.normal,
          respuesta: respuestaSinConexion,
          sugerencias: sugerenciasIniciales,
          latenciaMs: 5,
        );
  }

  static AskResponse _plantilla(TipoRespuesta tipo) => AskResponse(
    tipo: tipo,
    respuesta: plantillas[tipo]!,
    sugerencias: tipo == TipoRespuesta.hechos ? sugerenciasHechos : const [],
    latenciaMs: 5,
  );

  /// Minúsculas, sin tildes y sin signos, con un espacio delante y otro detrás (para buscar palabras enteras).
  static String _comparable(String texto) => ' ${normalizar(texto).replaceAll(RegExp('[^a-z0-9]+'), ' ').trim()} ';

  /// La respuesta de [pregunta] por palabras clave, o null si no la reconoce. Va la primera regla que coincide: las más
  /// concretas, antes. [situacion] solo cambia la del abogado (como víctima o si te investigan).
  static AskResponse? respuestaPorClaves(String pregunta, {RolProceso? situacion}) {
    final texto = _comparable(pregunta);
    bool hay(List<String> claves) => claves.any(texto.contains);

    // Si lo que se pregunta es si se va a enterar alguien, la respuesta honesta, antes que cualquier tema: nunca se
    // promete un secreto (CLAUDE.md).
    if (hay(_confidencialidad)) return _contarloEnConfianza;
    if (hay(const ['despues de declarar', 'despues de la sala', 'despues de la entrevista', 'ir al juicio'])) {
      return _despuesDeDeclarar;
    }
    if (hay(_verALaPersona)) return _sinCruzarte;
    if (hay(const [' abogad', ' letrad'])) {
      if (situacion == RolProceso.investigado || hay(const ['investig', 'deten', ' acus'])) {
        return _abogadoSiTeInvestigan;
      }
      return situacion == null ? _abogado : _abogadoSiEresVictima;
    }
    if (hay(_investigado)) return _siTeInvestigan;
    if (hay(_desde14)) return _desde14Anos;
    if (hay(const ['menos de 14'])) return _menosDe14Detalle;
    if (hay(_menosDe14Claves)) return _menosDe14;
    if (hay(const ['internamiento', 'centro de menores', 'ley de menores'])) return _desde14Anos;
    if (hay(const ['fiscal'])) return hay(_acoso) ? _fiscaliaYAcoso : _fiscalia;
    if (hay(_acoso)) return _acosoEscolar;
    if (hay(_borrar)) return _borrarFotos;
    if (hay(const [' 017 ', 'incibe'])) return _linea017;
    // Las fotos antes que «castigar»: «¿Me van a castigar por haber mandado la foto?» es, casi siempre, de una víctima.
    if (hay(const [' foto', ' imagen', ' video', 'difund', 'difusion', 'sexting'])) return _fotos;
    if (hay(const ['castig'])) return _desde14Anos;
    if (hay(_pedirAyuda)) return _aQuienPedirAyuda;
    if (hay(const ['denunci'])) return _denunciar;
    if (hay(const ['acompan', 'confianza', 'ir sola ', 'ir solo '])) return _acompanarte;
    if (hay(const ['hablar conmigo', 'quieren hablar', 'no conozco', 'entrevistarme'])) return _porQueHablanContigo;
    if (hay(const ['gesell', 'espejo', 'preconstituida', 'graban', 'grabacion'])) return _salaGesell;
    if (hay(const ['se separan', 'se separen', 'separacion', 'divorci', 'custodia'])) return _siTusPadresSeSeparan;
    if (hay(_familia)) return _seguirConTuFamilia;
    if (hay(const ['declarar', 'declaracion', 'declare', 'testigo'])) return _siTeTocaDeclarar;
    if (hay(const ['derecho'])) return _tusDerechos;
    return null;
  }

  static const _verALaPersona = [
    'tendre que ver',
    'tengo que ver',
    ' verlo ',
    ' verlos ',
    ' verla ',
    ' verlas ',
    ' verle ',
    'ver a la persona',
    ' ver al ',
    'ver a los',
    'me pueden ver',
    'cruzar',
    'cruce con',
    'encontrar con',
    'encontrarme con',
    'me voy a encontrar',
    'cara a cara',
  ];
  static const _investigado = [
    'me investigan',
    'me estan investigando',
    'investigado',
    'investigada',
    'me detienen',
    'detenido',
    'detenida',
    'detencion',
    'me acusan',
    'me han denunciado',
  ];
  static const _menosDe14Claves = [
    ' 13 anos',
    'tengo 13',
    'juzgar',
    'juzgan',
    'juzguen',
    'responsabilidad penal',
    'algo malo',
  ];
  static const _desde14 = [
    'a partir de los 14',
    'mas de 14',
    'mayor de 14',
    'de 14 a 17',
    'tengo 14',
    'tengo 15',
    'tengo 16',
    'tengo 17',
  ];
  static const _acoso = [
    ' acoso',
    ' acosa',
    ' acosan',
    ' acosaba',
    ' acosador',
    'ciberacoso',
    'bullying',
    'me insultan',
    'me molestan',
  ];
  // Sin « mi madre » ni « mi padre »: nombrar a la familia no es preguntar por seguir con ella («mi padre me pega» no
  // puede recibir «lo normal es seguir con tu familia»).
  static const _familia = ['vivir con', 'desamparo', 'servicios sociales'];

  /// Borrar fotos o datos, con palabras enteras (« borr» también encontraba «borracho»).
  static const _borrar = [' borrar', ' borre ', ' borren ', ' borran ', ' borro ', ' borrado', 'olvido', 'eliminen'];

  /// Si se va a enterar alguien, si es secreto o confidencial.
  static const _confidencialidad = [
    'sin que se entere',
    'sin que lo sepa',
    'sin que se lo digan',
    ' se va a enterar',
    ' se van a enterar',
    ' se enteren ',
    ' se enterara',
    ' secreto',
    'confidencial',
  ];
  static const _pedirAyuda = [
    'pedir ayuda',
    'a quien puedo',
    'a quien se lo',
    'con quien puedo hablar',
    ' ayuda',
    'intimidad',
    ' anar ',
  ];

  // Fuentes: el apartado de docs/MARCO_LEGAL.md de cada afirmación. La LOPIVI va como «LO 8/2021», que es como la
  // nombra la etiqueta de fuente.
  static const _fuenteMenosDe14 = Fuente(
    id: 'A-017',
    titulo: 'Antes de los 14 años no hay responsabilidad penal',
    norma: 'LO 5/2000',
    articulo: '3',
  );
  static const _fuenteLeyDeMenores = Fuente(
    id: 'ML-LO5-1.1',
    titulo: 'La ley penal de menores, de 14 a 17 años',
    norma: 'LO 5/2000',
    articulo: '1.1',
  );
  static const _fuenteFiscalia = Fuente(
    id: 'ML-LO5-6',
    titulo: 'Qué hace la Fiscalía de Menores',
    norma: 'LO 5/2000',
    articulo: '6',
  );
  static const _fuenteDenuncia = Fuente(
    id: 'ML-LO5-16.2',
    titulo: 'La Fiscalía decide si sigue adelante',
    norma: 'LO 5/2000',
    articulo: '16.2',
  );
  static const _fuenteMedidasParaProtegerte = Fuente(
    id: 'ML-LO5-28.1',
    titulo: 'Medidas para protegerte durante el proceso',
    norma: 'LO 5/2000',
    articulo: '28.1',
  );
  static const _fuenteMedidas = Fuente(
    id: 'ML-LO5-7.1',
    titulo: 'Las medidas de la ley de menores',
    norma: 'LO 5/2000',
    articulo: '7.1',
  );
  static const _fuenteADistancia = Fuente(
    id: 'ML-LO5-4',
    titulo: 'Declarar a distancia si eres menor',
    norma: 'LO 5/2000',
    articulo: '4, párrs. 4 y 5',
  );
  static const _fuenteDetencion = Fuente(
    id: 'ML-LO5-17.1',
    titulo: 'Si te detienen, te lo explican con palabras claras',
    norma: 'LO 5/2000',
    articulo: '17.1',
  );
  static const _fuenteDetencionFamiliaYAbogado = Fuente(
    id: 'ML-LO5-17.2',
    titulo: 'Si te detienen: aviso a tu familia y tu abogado',
    norma: 'LO 5/2000',
    articulo: '17.1 y 17.2',
  );
  static const _fuenteExpediente = Fuente(
    id: 'ML-LO5-22.1',
    titulo: 'Tus derechos desde que se abre el expediente',
    norma: 'LO 5/2000',
    articulo: '22.1',
  );
  static const _fuenteDefensaEInocencia = Fuente(
    id: 'ML-CE-24.2',
    titulo: 'Derecho a la defensa y presunción de inocencia',
    norma: 'CE',
    articulo: '24.2',
  );
  static const _fuenteSalaPreparada = Fuente(
    id: 'ML-L4-25.1',
    titulo: 'Declarar en una sala preparada',
    norma: 'Ley 4/2015',
    articulo: '25.1 a) y b)',
  );
  static const _fuenteSinCruzarte = Fuente(
    id: 'ML-L4-20',
    titulo: 'Que no te cruces con la persona acusada',
    norma: 'Ley 4/2015',
    articulo: '20',
  );
  static const _fuenteIntimidad = Fuente(
    id: 'ML-L4-22',
    titulo: 'Tu intimidad, protegida',
    norma: 'Ley 4/2015',
    articulo: '22',
  );
  static const _fuenteInformacion = Fuente(
    id: 'ML-L4-5.1',
    titulo: 'Te explican tus derechos desde el principio',
    norma: 'Ley 4/2015',
    articulo: '5.1',
  );
  static const _fuenteAvisos = Fuente(
    id: 'ML-L4-7.1',
    titulo: 'Te avisan del juicio y de las decisiones importantes',
    norma: 'Ley 4/2015',
    articulo: '7.1 a) y b)',
  );
  static const _fuentePruebaPreconstituida = Fuente(
    id: 'ML-LECRIM-449ter.1',
    titulo: 'Tu entrevista, como prueba preconstituida',
    norma: 'LECrim',
    articulo: '449 ter, párr. 1',
  );
  static const _fuenteEquipoPsicosocial = Fuente(
    id: 'ML-LECRIM-449ter.2',
    titulo: 'La entrevista con un equipo psicosocial',
    norma: 'LECrim',
    articulo: '449 ter, párr. 2',
  );
  static const _fuenteSinVerla = Fuente(
    id: 'ML-LECRIM-449ter.3',
    titulo: 'Sin ver cara a cara a la persona investigada',
    norma: 'LECrim',
    articulo: '449 ter, párr. 3',
  );
  static const _fuenteGrabacionEnElJuicio = Fuente(
    id: 'ML-LECRIM-703bis',
    titulo: 'En el juicio se pone la grabación',
    norma: 'LECrim',
    articulo: '703 bis',
  );
  static const _fuentePersonaDeConfianza = Fuente(
    id: 'ML-LECRIM-433',
    titulo: 'Declarar con una persona de confianza',
    norma: 'LECrim',
    articulo: '433, párr. 3',
  );
  static const _fuenteDenunciarSinAdulto = Fuente(
    id: 'ML-LOPIVI-50.2',
    titulo: 'Denunciar sin un adulto y con alguien de confianza',
    norma: 'LO 8/2021',
    articulo: '50.2.e) y 50.2.h)',
  );
  static const _fuenteContarlo = Fuente(
    id: 'ML-LOPIVI-17',
    titulo: 'Puedes contarlo tú',
    norma: 'LO 8/2021',
    articulo: '17.1 y 17.2',
  );
  static const _fuenteProtocolo = Fuente(
    id: 'ML-LOPIVI-34.1',
    titulo: 'El protocolo contra el acoso',
    norma: 'LO 8/2021',
    articulo: '34.1',
  );
  static const _fuenteCoordinador = Fuente(
    id: 'ML-LOPIVI-35',
    titulo: 'El coordinador o la coordinadora de bienestar',
    norma: 'LO 8/2021',
    articulo: '35.1 y 35.2.c)',
  );
  static const _fuenteCentroTeProtege = Fuente(
    id: 'ML-LOPIVI-20.2',
    titulo: 'Tu centro tiene que protegerte',
    norma: 'LO 8/2021',
    articulo: '20.2',
  );
  static const _fuenteAbogadoSiEresVictima = Fuente(
    id: 'ML-LOPIVI-14',
    titulo: 'Abogado si eres víctima de violencia',
    norma: 'LO 8/2021',
    articulo: '14.1 y 14.3',
  );
  static const _fuenteJusticiaGratuita = Fuente(
    id: 'ML-L1-1996-2h',
    titulo: 'Abogado gratis en los delitos sexuales',
    norma: 'Ley 1/1996',
    articulo: '2.h)',
  );
  static const _fuenteSerOido = Fuente(
    id: 'ML-LO1-1996-9',
    titulo: 'Derecho a que te escuchen',
    norma: 'LO 1/1996',
    articulo: '9.1 y 9.2',
  );
  static const _fuenteDefenderTusDerechos = Fuente(
    id: 'ML-LO1-1996-10.2',
    titulo: 'Contarlo a la Fiscalía o al Defensor del Pueblo',
    norma: 'LO 1/1996',
    articulo: '10.2.b) y 10.2.c)',
  );
  static const _fuenteRiesgo = Fuente(
    id: 'ML-LO1-1996-17.1',
    titulo: 'Ayuda para seguir con tu familia',
    norma: 'LO 1/1996',
    articulo: '17.1',
  );
  static const _fuenteDesamparo = Fuente(
    id: 'ML-LO1-1996-18.2',
    titulo: 'Qué es el desamparo',
    norma: 'LO 1/1996',
    articulo: '18.2',
  );
  static const _fuenteMadreVictima = Fuente(
    id: 'ML-LO1-1996-12.3',
    titulo: 'Seguir con tu madre si es víctima',
    norma: 'LO 1/1996',
    articulo: '12.3',
  );
  static const _fuenteSeparacion = Fuente(
    id: 'ML-LEC-770',
    titulo: 'Que te escuchen si tus padres se separan',
    norma: 'LEC',
    articulo: '770, regla 4.ª',
  );
  static const _fuenteEscuchado = Fuente(
    id: 'ML-CDN-12.2',
    titulo: 'Que te escuchen cuando deciden sobre ti',
    norma: 'CDN',
    articulo: '12.2',
  );
  static const _fuenteOlvido = Fuente(
    id: 'ML-LOPDGDD-94.3',
    titulo: 'Pedir a una red social que borre tus fotos y datos',
    norma: 'LOPDGDD',
    articulo: '94.3',
  );
  static const _fuenteCanalPrioritario = Fuente(
    id: 'ML-AEPD-CP',
    titulo: 'Canal prioritario de la Agencia Española de Protección de Datos',
    norma: 'AEPD · Canal prioritario',
    articulo: '',
  );
  static const _fuenteCanalNoSirve = Fuente(
    id: 'ML-AEPD-FAQ15.03',
    titulo: 'Cuándo no sirve el Canal prioritario',
    norma: 'AEPD · FAQ 15.03',
    articulo: '',
  );
  static const _fuente017 = Fuente(
    id: 'ML-INCIBE-017',
    titulo: 'El 017, ayuda con problemas en internet',
    norma: 'INCIBE · 017',
    articulo: '',
  );
  static const _fuenteAvisosAPadres = Fuente(
    id: 'ML-L4-4',
    titulo: 'Los avisos oficiales, a tus padres o a quien te represente',
    norma: 'Ley 4/2015',
    articulo: '4 a)',
  );
  static const _fuenteDifundirSinPermiso = Fuente(
    id: 'ML-CP-197.7',
    titulo: 'Pasar a otros imágenes íntimas sin permiso',
    norma: 'Código Penal',
    articulo: '197.7',
  );

  // Respuestas (sección 8.1). Cada frase sale de un «Para explicarlo» de docs/MARCO_LEGAL.md, con su referencia, y
  // ninguna acaba en «...». Las sugerencias llevan a otras respuestas de esta lista.
  static const _latencia = 1500;

  /// La de la sección 8.1 para la pregunta de la demo, sin los «...» del documento: el mismo texto, terminado en punto,
  /// y las mismas fuente, sugerencias y términos. Añade lo que pasa en su lugar (la protección de menores, del mismo
  /// artículo), para que nadie de 13 años entienda que «no pasa nada». El detalle está en [_menosDe14Detalle].
  static const _menosDe14 = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'Antes de los 14 años no se puede exigir responsabilidad penal en España [A-017]. En su lugar actúan las '
        'normas y los servicios de protección de menores [A-017].',
    fuentes: [_fuenteMenosDe14],
    sugerencias: ['¿Qué pasa a partir de los 14?', '¿Qué hace la Fiscalía de Menores?'],
    terminos: ['responsabilidad penal', 'Fiscalía de Menores'],
    latenciaMs: 2140,
  );

  static const _menosDe14Detalle = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'Con menos de 14 años no hay responsabilidad penal: si alguien de esa edad hace algo que es delito, no se le '
        'juzga con la ley de menores. En su lugar actúan las normas y los servicios de protección de menores [A-017]. '
        'La ley penal de menores solo se aplica a chicos y chicas de 14 a 17 años que cometen un delito [ML-LO5-1.1].',
    fuentes: [_fuenteMenosDe14, _fuenteLeyDeMenores],
    sugerencias: ['¿Qué pasa a partir de los 14?', '¿Qué derechos tengo si me investigan?'],
    terminos: ['responsabilidad penal'],
    latenciaMs: _latencia,
  );

  static const _desde14Anos = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'La ley penal de menores se aplica a chicos y chicas de 14 a 17 años que cometen un delito [ML-LO5-1.1]. La '
        'Fiscalía de Menores dirige la investigación [ML-LO5-6]. Si al final el juez de menores decide que se cometió '
        'un delito, puede poner una medida, no una pena como a los adultos. Las que más limitan son las de '
        'internamiento: vivir durante un tiempo en un centro de menores. Para elegir la medida, el juez tiene en cuenta '
        'sobre todo la edad, la familia, la situación y lo que es mejor para esa persona [ML-LO5-7.1].',
    fuentes: [_fuenteLeyDeMenores, _fuenteFiscalia, _fuenteMedidas],
    sugerencias: [
      '¿Qué derechos tengo si me investigan?',
      '¿Puedo tener abogado o abogada?',
      '¿Qué pasa si tengo menos de 14 años?',
    ],
    terminos: ['Fiscalía de Menores', 'juez de menores', 'medida'],
    latenciaMs: _latencia,
  );

  static const _siTeInvestigan = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'Si te detienen y tienes de 14 a 17 años, la policía tiene que explicarte enseguida y con palabras claras de qué '
        'se te acusa, por qué te detienen y qué derechos tienes [ML-LO5-17.1]. También tiene que avisar a tus padres o '
        'tutores, y cuando declares tiene que estar tu abogado o abogada [ML-LO5-17.2]. Desde que se abre el '
        'expediente, puedes elegir abogado o abogada, o que te asignen un abogado de oficio, y hablar a solas con él '
        'antes de declarar [ML-LO5-22.1]. Y que te investiguen no quiere decir que ya se haya decidido nada: se presume '
        'que eres inocente [ML-CE-24.2].',
    fuentes: [_fuenteDetencion, _fuenteDetencionFamiliaYAbogado, _fuenteExpediente, _fuenteDefensaEInocencia],
    sugerencias: [
      '¿Puedo tener abogado o abogada?',
      '¿Qué pasa a partir de los 14?',
      '¿Qué pasa si tengo menos de 14 años?',
    ],
    terminos: ['expediente', 'abogado de oficio'],
    latenciaMs: _latencia,
  );

  static const _abogadoSiTeInvestigan = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'Sí. Desde que se abre el expediente, puedes elegir abogado o abogada, o que te asignen un abogado de oficio, y '
        'hablar a solas con él antes de declarar [ML-LO5-22.1]. Si te detienen, cuando declares tiene que estar tu '
        'abogado, y puedes hablar a solas con él antes y después de declarar [ML-LO5-17.2]. Si te acusan de algo, '
        'tienes derecho a defenderte con un abogado o una abogada [ML-CE-24.2].',
    fuentes: [_fuenteExpediente, _fuenteDetencionFamiliaYAbogado, _fuenteDefensaEInocencia],
    sugerencias: ['¿Qué derechos tengo si me investigan?', '¿Qué pasa a partir de los 14?'],
    terminos: ['expediente', 'abogado de oficio'],
    latenciaMs: _latencia,
  );

  static const _abogadoSiEresVictima = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'Si eres víctima de violencia, puedes tener abogado gratis en los casos que marca la ley de justicia gratuita, y '
        'el Colegio de Abogados tiene que asignártelo con urgencia [ML-LOPIVI-14]. Si lo que te han hecho es un delito '
        'sexual, tienes derecho a un abogado gratis aunque tu familia tenga dinero [ML-L1-1996-2h]. En muchos otros '
        'casos, depende de los ingresos de la familia.',
    fuentes: [_fuenteAbogadoSiEresVictima, _fuenteJusticiaGratuita],
    sugerencias: ['¿Qué pasa si se denuncia?', '¿Quién puede acompañarme?'],
    terminos: ['víctima'],
    latenciaMs: _latencia,
  );

  static const _abogado = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'Si eres víctima de violencia, puedes tener abogado gratis en los casos que marca la ley de justicia gratuita, y '
        'el Colegio de Abogados tiene que asignártelo con urgencia [ML-LOPIVI-14]. Si es un delito sexual, es gratis '
        'aunque tu familia tenga dinero [ML-L1-1996-2h]; en muchos otros casos, depende de los ingresos de la familia. '
        'Y si te investigan, desde que se abre el expediente puedes elegir abogado o abogada, o que te asignen un '
        'abogado de oficio [ML-LO5-22.1].',
    fuentes: [_fuenteAbogadoSiEresVictima, _fuenteJusticiaGratuita, _fuenteExpediente],
    sugerencias: ['¿Qué pasa si se denuncia?', '¿Qué derechos tengo si me investigan?'],
    terminos: ['víctima', 'expediente', 'abogado de oficio'],
    latenciaMs: _latencia,
  );

  static const _fiscalia = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'La Fiscalía de Menores defiende los derechos de los menores, vigila que el proceso sea justo y dirige la '
        'investigación [ML-LO5-6]. Cuando alguien denuncia, decide si lo que pasó puede ser delito y si sigue adelante, '
        'y tiene que comunicar lo que decida a quien denunció [ML-LO5-16.2]. En cualquier momento del proceso, el '
        'fiscal puede pedir al juez medidas para protegerte, como prohibir a la persona denunciada que se te acerque o '
        'que se comunique contigo [ML-LO5-28.1].',
    fuentes: [_fuenteFiscalia, _fuenteDenuncia, _fuenteMedidasParaProtegerte],
    sugerencias: [
      '¿Tendré que ver a la persona denunciada?',
      '¿Qué pasa a partir de los 14?',
      '¿Quién puede acompañarme?',
    ],
    terminos: ['Fiscalía de Menores'],
    latenciaMs: _latencia,
  );

  /// También la de «Mis padres han ido a la Fiscalía porque me acosan en el instituto. ¿Qué va a pasar ahora?» (guion
  /// de la demo, Sergio): el acoso dentro de una pregunta sobre el proceso es una pregunta normal.
  static const _fiscaliaYAcoso = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'Cuando se denuncia, la Fiscalía de Menores decide si lo que pasó puede ser delito y si sigue adelante, y tiene '
        'que comunicar lo que decida a quien denunció [ML-LO5-16.2]. Defiende tus derechos, vigila que el proceso sea '
        'justo y dirige la investigación [ML-LO5-6]. En cualquier momento, el fiscal puede pedir al juez medidas para '
        'protegerte, como prohibir a la persona denunciada que se te acerque o que se comunique contigo [ML-LO5-28.1]. '
        'Además, en tu colegio o instituto, el protocolo contra el acoso se pone en marcha con solo que lo cuentes '
        '[ML-LOPIVI-34.1]. Si lo necesitas, en ANAR te escuchan a cualquier hora: 900 20 20 10.',
    fuentes: [_fuenteDenuncia, _fuenteFiscalia, _fuenteMedidasParaProtegerte, _fuenteProtocolo],
    sugerencias: [
      '¿Tendré que ver a la persona denunciada?',
      '¿Quién puede acompañarme?',
      '¿A quién puedo pedir ayuda?',
    ],
    terminos: ['Fiscalía de Menores', 'protocolo contra el acoso'],
    latenciaMs: _latencia,
  );

  static const _acosoEscolar = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'Todos los colegios e institutos tienen que seguir un protocolo contra el acoso y el ciberacoso, y ese protocolo '
        'se pone en marcha con solo que tú lo cuentes [ML-LOPIVI-34.1]. En tu centro tiene que haber un coordinador o '
        'coordinadora de bienestar y protección: es la persona a la que puedes contarle que te acosan [ML-LOPIVI-35]. '
        'Si lo cuentas, tu centro está obligado a tomar medidas para protegerte, para que contarlo no empeore las cosas '
        '[ML-LOPIVI-20.2]. Y en ANAR te escuchan a cualquier hora: 900 20 20 10.',
    fuentes: [_fuenteProtocolo, _fuenteCoordinador, _fuenteCentroTeProtege],
    sugerencias: [
      '¿Qué hace la Fiscalía de Menores si hay acoso escolar?',
      '¿A quién puedo pedir ayuda?',
      '¿Qué pasa si se denuncia?',
    ],
    terminos: ['protocolo contra el acoso', 'ciberacoso'],
    latenciaMs: _latencia,
  );

  /// La de Sara: primero, que la culpa no es de quien sale en las imágenes (aunque las hubiera enviado), y después qué
  /// se puede hacer, con la edad que hace falta para el Canal prioritario.
  static const _fotos = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'Aunque tú hubieras aceptado una foto o un vídeo íntimo, o lo hubieras enviado tú, nadie puede pasarlo a otros '
        'sin tu permiso: si eso daña gravemente tu intimidad, es un delito [ML-CP-197.7]. Si es sexual o violento y está '
        'en internet, la Agencia Española de Protección de Datos puede quitarlo enseguida: pídelo en su Canal '
        'prioritario. Desde los 14 años puedes hacerlo tú; con menos, que te ayude un adulto de confianza '
        '[ML-AEPD-CP]. No sirve para WhatsApp, Telegram ni el correo [ML-AEPD-FAQ15.03]. Puedes denunciar en la '
        'policía sin un adulto [ML-LOPIVI-50.2]. El 017 ayuda de 8:00 a 23:00 [ML-INCIBE-017], y ANAR, a cualquier '
        'hora: 900 20 20 10.',
    fuentes: [
      _fuenteDifundirSinPermiso,
      _fuenteCanalPrioritario,
      _fuenteCanalNoSirve,
      _fuenteDenunciarSinAdulto,
      _fuente017,
    ],
    sugerencias: ['¿Puedo pedir que borren mis fotos?', '¿Qué es el 017?', '¿A quién puedo pedir ayuda?'],
    terminos: ['intimidad', 'Agencia Española de Protección de Datos', 'Canal prioritario'],
    latenciaMs: _latencia,
  );

  static const _borrarFotos = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'Con el derecho al olvido, si eres menor de edad y una red social tiene fotos o datos tuyos, basta con que pidas '
        'que los borren, aunque los haya subido otra persona. La red social tiene que borrarlos sin retrasos '
        '[ML-LOPDGDD-94.3]. Si son fotos o vídeos sexuales o violentos publicados en internet sin permiso, también '
        'puedes pedir a la Agencia Española de Protección de Datos que los quite enseguida en su Canal prioritario. '
        'Desde los 14 años puedes hacerlo tú; con menos, que te ayude un adulto de confianza [ML-AEPD-CP].',
    fuentes: [_fuenteOlvido, _fuenteCanalPrioritario],
    sugerencias: ['¿Qué hago si difunden fotos mías?', '¿Qué es el 017?'],
    terminos: ['derecho al olvido', 'Agencia Española de Protección de Datos', 'Canal prioritario'],
    latenciaMs: _latencia,
  );

  static const _linea017 = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'El 017 es un teléfono gratuito y confidencial que ayuda con problemas en internet, también a menores y a sus '
        'familias, todos los días de 8:00 a 23:00. También atienden por WhatsApp (900 116 117) y Telegram (@INCIBE017) '
        '[ML-INCIBE-017]. Fuera de ese horario, en ANAR te escuchan a cualquier hora: 900 20 20 10.',
    fuentes: [_fuente017],
    sugerencias: ['¿Qué hago si difunden fotos mías?', '¿A quién puedo pedir ayuda?'],
    latenciaMs: _latencia,
  );

  /// «¿Puedo contarlo sin que se entere mi madre?», «¿Es secreto?»: dónde se habla con confianza, pero sin prometer un
  /// secreto que nadie puede garantizar (CLAUDE.md: nunca confidencialidad absoluta).
  static const _contarloEnConfianza = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'En ANAR te escuchan gratis y a cualquier hora: 900 20 20 10. El 017 es un teléfono gratuito y confidencial que '
        'ayuda con problemas en internet, todos los días de 8:00 a 23:00 [ML-INCIBE-017]. Lo que nadie puede '
        'prometerte es que nunca se entere nadie: si eres víctima y hay un proceso, los avisos oficiales se envían a '
        'tus padres o a quien te represente [ML-L4-4]. Si eso te preocupa, habla antes con ANAR o con una persona '
        'adulta de confianza.',
    fuentes: [_fuente017, _fuenteAvisosAPadres],
    sugerencias: ['¿A quién puedo pedir ayuda?', '¿Qué es el 017?', '¿Quién puede acompañarme?'],
    terminos: ['víctima'],
    latenciaMs: _latencia,
  );

  static const _aQuienPedirAyuda = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'Si sufres violencia o la ves, puedes contarlo directamente a servicios sociales, a la policía, a la Fiscalía o '
        'a un juzgado. Las administraciones deben tener canales seguros y confidenciales, explicados con palabras que '
        'entiendas [ML-LOPIVI-17]. En tu centro tiene que haber un coordinador o coordinadora de bienestar y '
        'protección: es la persona a la que puedes contarlo [ML-LOPIVI-35]. Si eres una víctima menor de edad, jueces, '
        'fiscales y policías tienen que proteger tu intimidad y evitar que se difunda cualquier dato que permita saber '
        'quién eres [ML-L4-22]. Y en ANAR te escuchan a cualquier hora: 900 20 20 10.',
    fuentes: [_fuenteContarlo, _fuenteCoordinador, _fuenteIntimidad],
    sugerencias: ['¿Qué pasa si se denuncia?', '¿Quién puede acompañarme?', '¿Qué hace la Fiscalía de Menores?'],
    terminos: ['Fiscalía', 'víctima', 'intimidad'],
    latenciaMs: _latencia,
  );

  static const _denunciar = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'Si eres víctima, desde el primer momento, incluso antes de denunciar, la policía o el juzgado tienen que '
        'explicarte tus derechos, por ejemplo cómo pedir protección [ML-L4-5.1]. En la policía puedes denunciar sin que '
        'tenga que acompañarte un adulto, y puede estar contigo una persona de tu confianza que tú elijas '
        '[ML-LOPIVI-50.2]. Si la persona denunciada tiene de 14 a 17 años, la Fiscalía de Menores decide si lo que pasó '
        'puede ser delito y si sigue adelante, y tiene que comunicar lo que decida a quien denunció [ML-LO5-16.2].',
    fuentes: [_fuenteInformacion, _fuenteDenunciarSinAdulto, _fuenteDenuncia],
    sugerencias: [
      '¿Quién puede acompañarme?',
      '¿Tendré que ver a la persona denunciada?',
      '¿A quién puedo pedir ayuda?',
    ],
    terminos: ['víctima', 'Fiscalía de Menores'],
    latenciaMs: _latencia,
  );

  static const _acompanarte = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'Cuando declares como víctima, puedes ir con tu representante legal y con una persona de confianza que elijas, '
        'salvo que el juez explique por qué no [ML-LECRIM-433]. En la policía puedes denunciar sin que tenga que '
        'acompañarte un adulto y, además, puede estar contigo una persona de tu confianza que tú elijas '
        '[ML-LOPIVI-50.2].',
    fuentes: [_fuentePersonaDeConfianza, _fuenteDenunciarSinAdulto],
    sugerencias: ['¿Tendré que ver a la persona denunciada?', '¿Qué es la Sala Gesell?', '¿A quién puedo pedir ayuda?'],
    terminos: ['víctima', 'persona de confianza'],
    latenciaMs: _latencia,
  );

  /// También la de «¿Tendré que verlos cuando declare?» (guion de la demo, Sergio).
  static const _sinCruzarte = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'Si eres víctima, los juzgados y las fiscalías tienen que organizarse para que ni tú ni tu familia os crucéis '
        'con la persona acusada [ML-L4-20]. Y si la persona denunciada tiene de 14 a 17 años, como eres menor, lo normal '
        'es que declares a distancia, por videoconferencia: solo irías en persona si el juez o el fiscal explican por qué '
        'hace falta [ML-LO5-4]. Si tienes menos de 14 años y te hacen la entrevista como prueba preconstituida, tampoco '
        'tendrás que ver cara a cara a la persona investigada [ML-LECRIM-449ter.3].',
    fuentes: [_fuenteSinCruzarte, _fuenteADistancia, _fuenteSinVerla],
    sugerencias: ['¿Quién puede acompañarme?', '¿Qué es la Sala Gesell?', '¿Qué pasa después de declarar?'],
    terminos: ['víctima', 'videoconferencia', 'prueba preconstituida', 'persona investigada'],
    latenciaMs: _latencia,
  );

  static const _salaGesell = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'Te pueden tomar declaración en una sala preparada para ello, como la Sala Gesell, y con profesionales formados '
        'para que lo pases lo mejor posible [ML-L4-25.1]. Si tienes menos de 14 años y eres testigo en un caso de '
        'violencia o maltrato, el juez tiene que hacer tu entrevista como prueba preconstituida, que vale como si '
        'hablaras en el juicio [ML-LECRIM-449ter.1]. Si la persona investigada está presente, no tendrás que verla cara '
        'a cara: se puede usar un cristal, una pantalla u otro medio técnico [ML-LECRIM-449ter.3].',
    fuentes: [_fuenteSalaPreparada, _fuentePruebaPreconstituida, _fuenteSinVerla],
    sugerencias: [
      '¿Qué pasa después de declarar?',
      '¿Puede acompañarme alguien de confianza?',
      '¿Tendré que ver a la persona denunciada?',
    ],
    terminos: ['Sala Gesell', 'testigo', 'prueba preconstituida', 'juicio', 'persona investigada'],
    latenciaMs: _latencia,
  );

  static const _despuesDeDeclarar = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'Si tu entrevista se ha grabado como prueba preconstituida, normalmente en el juicio se pone la grabación y no '
        'hace falta que vayas. Solo de forma excepcional, si el juez lo decide y explica por qué, podrías tener que '
        'declarar otra vez [ML-LECRIM-703bis]. Si eres víctima, a ti o a tus padres os tienen que avisar de cuándo y '
        'dónde es el juicio y de las decisiones importantes, como no seguir con el caso o la sentencia [ML-L4-7.1].',
    fuentes: [_fuenteGrabacionEnElJuicio, _fuenteAvisos],
    sugerencias: ['¿Tendré que ver a la persona denunciada?', '¿Quién puede acompañarme?'],
    terminos: ['prueba preconstituida', 'juicio', 'víctima', 'sentencia'],
    latenciaMs: _latencia,
  );

  static const _porQueHablanContigo = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'Tienes derecho a que te escuchen, tengas la edad que tengas, y a que te lo expliquen todo con palabras que '
        'entiendas [ML-LO1-1996-9]. Si tienes menos de 14 años, el juez puede pedir que la entrevista la haga un equipo '
        'psicosocial (psicólogos y trabajadores sociales) que conoce tu situación. Por eso habla contigo gente que no '
        'conoces: para tratarte mejor [ML-LECRIM-449ter.2].',
    fuentes: [_fuenteSerOido, _fuenteEquipoPsicosocial],
    sugerencias: [
      '¿Qué es la Sala Gesell?',
      '¿Puede acompañarme alguien de confianza?',
      '¿Qué pasa después de declarar?',
    ],
    terminos: ['equipo psicosocial'],
    latenciaMs: _latencia,
  );

  static const _siTeTocaDeclarar = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'Tienes derecho a que te escuchen, tengas la edad que tengas, y a que te lo expliquen todo con palabras que '
        'entiendas [ML-LO1-1996-9]. Si eres víctima, te pueden tomar declaración en una sala preparada para ello, como '
        'la Sala Gesell, y con profesionales formados para que lo pases lo mejor posible [ML-L4-25.1]. Y cuando declares '
        'como víctima, puedes ir con tu representante legal y con una persona de confianza que elijas, salvo que el '
        'juez explique por qué no [ML-LECRIM-433].',
    fuentes: [_fuenteSerOido, _fuenteSalaPreparada, _fuentePersonaDeConfianza],
    sugerencias: [
      '¿Qué es la Sala Gesell?',
      '¿Qué pasa después de declarar?',
      '¿Tendré que ver a la persona denunciada?',
    ],
    terminos: ['víctima', 'Sala Gesell', 'persona de confianza'],
    latenciaMs: _latencia,
  );

  /// «¿Voy a dejar de vivir con mi madre?» (Lucía): la regla es seguir con la familia y no se promete nada.
  static const _seguirConTuFamilia = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'Lo normal es seguir con tu familia: si hay problemas en casa pero no son tan graves, los servicios sociales '
        'ayudan a tu familia para que puedas seguir viviendo con ella [ML-LO1-1996-17.1]. Solo si las personas que te '
        'cuidan no cumplen, no pueden o no saben protegerte y te falta lo necesario, la Administración se hace cargo de '
        'ti; a eso se le llama desamparo [ML-LO1-1996-18.2]. Si tu madre o la persona que te cuida es víctima de '
        'violencia en casa, las autoridades tienen que ayudaros para que puedas seguir viviendo con ella '
        '[ML-LO1-1996-12.3]. Nadie puede prometer cómo acabará, pero te tienen que escuchar [ML-LO1-1996-9].',
    fuentes: [_fuenteRiesgo, _fuenteDesamparo, _fuenteMadreVictima, _fuenteSerOido],
    sugerencias: ['¿Por qué quieren hablar conmigo?', '¿A quién puedo pedir ayuda?'],
    terminos: ['desamparo', 'víctima'],
    latenciaMs: _latencia,
  );

  static const _siTusPadresSeSeparan = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'Si tus padres se separan y no se ponen de acuerdo, el juez puede escucharte aunque tengas menos de 12 años si '
        'lo ve necesario; desde los 12 tiene que escucharte siempre [ML-LEC-770]. Puede escucharte a ti directamente o '
        'a través de alguien que hable por ti [ML-CDN-12.2]. Tu opinión cuenta, pero no tienes que elegir tú: decide el '
        'juez [ML-LO1-1996-9].',
    fuentes: [_fuenteSeparacion, _fuenteEscuchado, _fuenteSerOido],
    sugerencias: ['¿Qué derechos tengo?', '¿A quién puedo pedir ayuda?'],
    latenciaMs: _latencia,
  );

  static const _tusDerechos = AskResponse(
    tipo: TipoRespuesta.normal,
    respuesta:
        'Tienes derecho a que te escuchen, tengas la edad que tengas, y a que te lo expliquen todo con palabras que '
        'entiendas [ML-LO1-1996-9]. Si un juez o una oficina pública va a decidir algo sobre tu vida, tienen que darte '
        'la oportunidad de que te escuchen, a ti directamente o a través de alguien que hable por ti [ML-CDN-12.2]. Y '
        'puedes contar tú a la Fiscalía que no se respetan tus derechos para que actúe, y también quejarte al Defensor '
        'del Pueblo o al defensor de tu comunidad autónoma [ML-LO1-1996-10.2].',
    fuentes: [_fuenteSerOido, _fuenteEscuchado, _fuenteDefenderTusDerechos],
    sugerencias: [
      '¿Qué derechos tengo si me toca declarar?',
      '¿Qué derechos tengo si me investigan?',
      '¿A quién puedo pedir ayuda?',
    ],
    terminos: ['Fiscalía', 'Defensor del Pueblo'],
    latenciaMs: _latencia,
  );

  /// Todas las respuestas por palabras clave (para los tests: fuentes, sugerencias y textos).
  static const respuestasPorClavesConocidas = <AskResponse>[
    _menosDe14,
    _menosDe14Detalle,
    _desde14Anos,
    _siTeInvestigan,
    _abogadoSiTeInvestigan,
    _abogadoSiEresVictima,
    _abogado,
    _fiscalia,
    _fiscaliaYAcoso,
    _acosoEscolar,
    _fotos,
    _borrarFotos,
    _linea017,
    _contarloEnConfianza,
    _aQuienPedirAyuda,
    _denunciar,
    _acompanarte,
    _sinCruzarte,
    _salaGesell,
    _despuesDeDeclarar,
    _porQueHablanContigo,
    _siTeTocaDeclarar,
    _seguirConTuFamilia,
    _siTusPadresSeSeparan,
    _tusDerechos,
  ];

  @override
  Future<GradeResponse> grade(GradeRequest request) async {
    await Future<void>.delayed(latencia);
    return GradeResponse.fromJson(ejemploGradePara(request.conceptoId));
  }

  @override
  Future<HealthResponse> health() async => HealthResponse.fromJson(ejemploHealth);
}
