import '../../core/api/models.dart';
import '../../core/texto.dart';

// «Dilo con tus palabras» corregido en el móvil, cuando no hay servidor: sin conexión, con el servidor caído o si el
// servidor no conoce el ejercicio. Es una corrección aproximada, y en pantalla se dice («Corrección aproximada sin
// conexión»). Es honesta: el resultado depende solo de lo que se ha escrito, nunca es una respuesta enlatada.
//
// Cómo se hace:
// 1. Se normaliza: minúsculas, sin tildes y sin palabras vacías («el», «que», «tienes»…).
// 2. Cada palabra se recorta a su raíz de 5 letras («grabación» y «graban» → «graba») y pasa por los sinónimos
//    («sirve» → «vale», «oír» → «escuchar», «doce» → «12»).
// 3. Una idea clave cuenta como dicha si comparte al menos la mitad de sus palabras clave, y como mínimo dos (o todas,
//    si tiene menos).
// 4. Las negaciones cuentan: en «Normalmente no tienes que ir al juicio», «ir» va negado, y «Sí tienes que ir al
//    juicio» no vale. Al revés, una idea que afirma («La grabación vale para el juicio») no cuenta si una de sus
//    palabras (que no sea de la pregunta) solo se dice negada justo detrás de un «no» («La grabación no vale…»).
//    «No solo…» no es una negación. Hay palabras que no pueden faltar: «menos» («Con menos de 12…»), «culpa» y
//    «delito».
// 5. Repetir la pregunta no es explicar: cada idea necesita alguna palabra que no sea, tal cual, de la pregunta. Y si
//    dos ideas se parecen («Desde los 12…» y «Con menos de 12…»), cada una necesita alguna palabra solo suya.
// Nota = ideas dichas / ideas totales.

/// Hasta cuántas palabras detrás de un «no» llega la negación dentro de una idea clave («no tienes que ir»: «ir»).
const _alcanceNegacionIdea = 3;

/// Lo que no cuenta como palabra clave: artículos, preposiciones, pronombres, conjunciones y verbos de relleno.
const _vacias = {
  'a', 'al', 'algo', 'algun', 'alguna', 'algunas', 'alguno', 'algunos', 'alguien', 'ante', 'aqui', 'ahi', 'alli', //
  'asi', 'aun', 'bajo', 'bastante', 'bien', 'cada', 'casi', 'como', 'con', 'conmigo', 'contigo', 'consigo', 'contra',
  'cual', 'cuales', 'cualquier', 'cuando', 'cuanto', 'de', 'del', 'dentro', 'desde', 'donde', 'durante', 'el', 'ella',
  'ellas', 'ello', 'ellos', 'en', 'entonces', 'entre', 'era', 'eran', 'eres', 'es', 'esa', 'esas', 'ese', 'eso',
  'esos', 'esta', 'estaba', 'estado', 'estan', 'estar', 'estas', 'este', 'esto', 'estos', 'estoy', 'etc', 'fue',
  'fueron', 'ha', 'haber', 'habia', 'han', 'has', 'hasta', 'hay', 'haya', 'he', 'hecho', 'hacia', 'hace', 'hacen',
  'hacer', 'haces', 'hago', 'haga', 'hagan', 'hacerlo', 'hacerte', 'hacerle', 'la', 'las', 'le', 'les', 'lo', 'los',
  'mas', 'me', 'mi', 'mia', 'mio', 'mis', 'mucho', 'mucha', 'muchos', 'muchas', 'muy', 'nos', 'nosotros', 'nuestra',
  'nuestro', 'os', 'otra', 'otro', 'otras', 'otros', 'para', 'poco', 'por', 'puede', 'pueden', 'puedes', 'puedo',
  'poder', 'pueda', 'puedan', 'podria', 'podrian', 'que', 'quien', 'quienes', 'se', 'sea', 'sean', 'segun', 'ser',
  'si', 'sido', 'siempre', 'sobre', 'su', 'sus', 'tal', 'tambien', 'tan', 'tanto', 'te', 'tener', 'tengo', 'tiene',
  'tienen', 'tienes', 'tenga', 'tengan', 'tengas', 'ti', 'toda', 'todas', 'todo', 'todos', 'tras', 'tu', 'tus',
  'tuya', 'tuyo', 'suya', 'suyo', 'suyas', 'suyos', 'un', 'una', 'unas', 'uno', 'unos', 'usted', 'ustedes', 'vosotros',
  'yo', 'ya', 'debe', 'deben', 'debes', 'deber', 'cosa', 'cosas', 'pues', 'vez', 'veces', 'luego', 'ademas',
  'da', 'dan', 'dar',
};

/// Palabras que parten una frase en trozos: la negación no pasa de un trozo a otro («te graban y no vas al juicio»).
const _separadores = {'y', 'e', 'pero', 'sino', 'aunque', 'porque', 'pues', 'mientras', 'o', 'u'};

/// Negaciones. No son palabras clave: cambian el sentido de lo que viene detrás.
const _negaciones = {
  'no', 'nunca', 'jamas', 'ni', 'tampoco', 'sin', 'nadie', 'nada', 'ningun', 'ninguna', 'ninguno', 'ningunos', //
  'ningunas',
};

/// Verbos que niegan lo que viene detrás («evitar que se crucen» es «que no se crucen»). Ellos sí son palabras clave.
bool _niegaDetras(String palabra) =>
    palabra.startsWith('evit') ||
    palabra.startsWith('imped') ||
    palabra.startsWith('impid') ||
    palabra.startsWith('prohib');

/// Raíces que no pueden faltar si la idea las tiene (ya pasadas por los sinónimos).
const _imprescindibles = {'menos', 'culpa', 'delit'};

/// Contrarios: cuentan como la otra palabra, pero negada («orden de alejamiento» es «que no se acerque»).
const _contrarios = {'aleja': 'acerc', 'lejos': 'acerc', 'dista': 'acerc'};

/// Números escritos con letra.
const _numeros = {
  'diez': '10', 'once': '11', 'doce': '12', 'trece': '13', 'catorce': '14', 'quince': '15', 'dieciseis': '16', //
  'diecisiete': '17', 'dieciocho': '18',
};

/// Grupos de sinónimos. Todos los de un grupo cuentan como el primero. Van normalizados (sin tildes).
const _gruposSinonimos = [
  [
    'escuchar', 'escuchen', 'escucha', 'oir', 'oigan', 'oiga', 'oye', 'oyen', 'oyes', 'oido', 'oida', 'atender', //
    'atiendan', 'atienden',
  ],
  ['opinion', 'opinar', 'opina', 'opinas', 'opinan', 'pensar', 'piensa', 'piensas', 'piensan', 'parecer', 'parece'],
  [
    'contar', 'contarlo', 'contarselo', 'cuenta', 'cuentan', 'cuentas', 'cuente', 'cuenten', 'decir', 'decirlo', //
    'decirle', 'decirselo', 'dice', 'dicen', 'diga', 'digan', 'explicar', 'explica', 'explican', 'explique',
    'expliquen', 'explicarle', 'informar', 'informa', 'informan', 'informen', 'avisar', 'avisa', 'avisan', 'hablar',
    'habla', 'hablan', 'hablen', 'hablarle', 'comunicar', 'comunique', 'comunica', 'contactar', 'contacto', 'llamar',
    'llama', 'llamen', 'escribir', 'escriba', 'escribe', 'mensaje', 'mensajes',
  ],
  ['afecta', 'afectan', 'afectar', 'afecte', 'importa', 'importan'],
  [
    'juez', 'jueza', 'jueces', 'juzgado', 'juzgados', 'juzgar', 'juicio', 'juicios', 'tribunal', 'tribunales', //
    'magistrado', 'magistrada',
  ],
  ['grabar', 'graba', 'graban', 'grabado', 'grabacion', 'grabe', 'graben', 'filmar', 'filma', 'filman'],
  ['imagen', 'imagenes', 'foto', 'fotos', 'fotografia', 'video', 'videos', 'camara', 'camaras'],
  [
    'entrevista', 'entrevistan', 'entrevistar', 'declaracion', 'declarar', 'declaras', 'declara', 'declare', //
    'testimonio',
  ],
  ['vale', 'valen', 'valer', 'valida', 'valido', 'sirve', 'sirven', 'usa', 'usan', 'usar', 'utiliza', 'utilizan'],
  ['normalmente', 'normal', 'generalmente', 'general', 'habitualmente'],
  [
    'ir', 'voy', 'vas', 'va', 'vamos', 'van', 'vaya', 'vayas', 'vayan', 'iras', 'ira', 'iran', 'ido', 'yendo', //
    'acudir', 'acudes', 'acuda', 'acudas', 'asistir', 'asistes', 'asista', 'asistas',
  ],
  [
    'defender', 'defiende', 'defienden', 'defensa', 'proteger', 'protege', 'protegen', 'protejan', 'proteja', //
    'proteccion', 'protegida', 'protegido',
  ],
  ['vigila', 'vigilar', 'vigilan', 'controla', 'controlar', 'asegura', 'asegurar', 'supervisa', 'comprueba'],
  ['justo', 'justa', 'justicia', 'imparcial'],
  ['dirige', 'dirigir', 'dirigen', 'dirija', 'lleva', 'llevan', 'llevar', 'coordina', 'encarga', 'encargan'],
  ['mismo', 'misma', 'solo', 'sola', 'propio', 'propia'],
  ['policia', 'guardia', 'mossos', 'ertzaintza', 'agente', 'agentes', 'comisaria'],
  ['canal', 'canales', 'medio', 'medios'],
  ['confidencial', 'secreto', 'secretos', 'privado', 'privada', 'anonimo', 'anonima'],
  ['claro', 'clara', 'sencillo', 'sencilla', 'facil', 'faciles', 'simple', 'simples'],
  [
    'pedir', 'pide', 'piden', 'pida', 'pidan', 'pidas', 'pido', 'pedirlo', 'pedirle', 'solicitar', 'solicita', //
    'reclamar', 'reclama', 'exigir',
  ],
  ['organiza', 'organizan', 'organizar', 'preparan', 'preparar', 'planifican', 'horarios'],
  [
    'cruzar', 'cruzan', 'crucen', 'cruce', 'cruza', 'coincidir', 'coincidan', 'coinciden', 'encontrar', 'encuentre', //
    'encuentren', 'encontrarse', 'juntar', 'junten', 'topar',
  ],
  [
    'ver', 'verla', 'verle', 'verlo', 'verlas', 'verlos', 'veo', 'ves', 've', 'vea', 'veas', 'vean', 'ven', 'viendo', //
    'visto', 'mirar', 'mira', 'miran', 'mire',
  ],
  ['cara', 'frente', 'delante'],
  ['prohibir', 'orden', 'ordenes'],
  ['acercar', 'acerque', 'acerquen', 'acerca', 'acercan', 'aproximar', 'aproxime'],
  ['presentar', 'presenta', 'presentan', 'poner', 'pone', 'ponen', 'pongan', 'ponga', 'puso'],
  ['decidir', 'decide', 'deciden', 'decida', 'decision', 'decisiones', 'elige', 'resuelve'],
  ['seguir', 'sigue', 'siguen', 'siga', 'sigan', 'sigas', 'continua', 'continuar'],
  ['final', 'finalmente', 'acaba', 'acabar', 'acabara', 'termina', 'terminar', 'fin'],
  ['entender', 'entiendes', 'entiende', 'entienden', 'entiendan', 'entienda', 'entendido'],
  ['repetir', 'repitan', 'repita', 'repite', 'repiten'],
  [
    'reenviar', 'reenviarlas', 'reenvia', 'reenvian', 'enviar', 'envia', 'envian', 'mandar', 'manda', 'mandan', //
    'pasar', 'pasa', 'pasan', 'pases', 'compartir', 'comparte', 'comparten', 'difundir', 'difunde', 'difunden',
    'difusion', 'publicar', 'publica', 'publican', 'subir', 'suben', 'sube',
  ],
  ['dano', 'danar', 'dolor', 'duele', 'sufrir', 'sufre', 'herir', 'hiere', 'mal'],
  ['sexual', 'sexuales', 'sexo', 'desnudo', 'desnuda', 'intima', 'intimas', 'intimo', 'intimidad'],
  ['delito', 'delitos', 'crimen', 'ilegal', 'ilegales'],
  ['serio', 'seria', 'grave', 'graves', 'gordo'],
  ['culpa', 'culpable', 'culpables', 'responsable'],
  ['sale', 'salen', 'sales', 'aparece', 'aparecen'],
  ['aepd', 'agencia'],
  ['red', 'redes', 'instagram', 'tiktok', 'youtube', 'twitter', 'facebook', 'snapchat', 'whatsapp', 'internet'],
  [
    'borrar', 'borre', 'borren', 'borra', 'quitar', 'quite', 'quiten', 'quita', 'eliminar', 'elimine', 'eliminen', //
    'retirar', 'retire', 'retiren', 'bajar',
  ],
  [
    'instituto', 'colegio', 'cole', 'escuela', 'insti', 'clase', 'profesor', 'profesora', 'profe', 'tutor', 'tutora', //
    'centro',
  ],
  ['marcha', 'activa', 'activan', 'empieza', 'empiezan', 'inicia'],
  ['pena', 'penas', 'carcel', 'prision', 'castigo', 'castigos'],
  ['adulto', 'adulta', 'mayor', 'mayores', 'padre', 'padres', 'madre', 'madres'],
  ['enseguida', 'rapido', 'pronto', 'inmediatamente'],
  ['detener', 'detiene', 'detienen', 'detenido', 'detenida', 'detencion', 'arresta', 'arrestan', 'arresto'],
  ['necesario', 'necesaria', 'falta'],
  ['ayudar', 'ayuda', 'ayudan', 'apoyar', 'apoyo', 'apoyan'],
  ['casa', 'hogar'],
  ['buscar', 'busca', 'buscan', 'busque', 'busquen'],
  ['forma', 'manera', 'modo', 'opcion', 'alternativa'],
  ['cuidar', 'cuidarte', 'cuida', 'cuiden', 'cuidado'],
  ['prometer', 'promete', 'prometen', 'prometa', 'garantizar'],
  ['menos', 'antes'],
  [
    'menor', 'menores', 'nino', 'nina', 'ninos', 'ninas', 'chico', 'chica', 'chicos', 'chicas', 'joven', 'jovenes', //
    'adolescente', 'adolescentes',
  ],
  ['ley', 'leyes'],
];

/// Raíz de cada sinónimo → raíz del primero de su grupo.
final Map<String, String> _sinonimos = () {
  final mapa = <String, String>{};
  for (final grupo in _gruposSinonimos) {
    final canonica = raizDilo(grupo.first);
    for (final palabra in grupo) {
      mapa[raizDilo(palabra)] = canonica;
    }
  }
  return mapa;
}();

/// Los grupos de sinónimos, para comprobar en las pruebas que ninguna raíz está en dos grupos.
List<List<String>> get gruposSinonimosDilo => _gruposSinonimos;

/// La raíz de una palabra ya normalizada: los números escritos pasan a cifras, se quita el plural y se recorta a
/// 5 letras («grabaciones» → «graba», «jueces» → «juez», «leyes» → «ley»).
String raizDilo(String palabra) {
  final numero = _numeros[palabra];
  if (numero != null) return numero;
  if (RegExp(r'^\d+$').hasMatch(palabra)) return palabra;
  // «confidencial» no es «confianza», y «compañero» no es «compartir».
  if (palabra.startsWith('confid')) return 'confid';
  if (palabra.startsWith('compan')) return 'compan';
  var p = palabra;
  if (p.length > 4 && p.endsWith('ces')) {
    p = '${p.substring(0, p.length - 3)}z';
  } else if (p.length > 4 && p.endsWith('yes')) {
    p = p.substring(0, p.length - 2);
  } else if (p.length > 3 && p.endsWith('s')) {
    p = p.substring(0, p.length - 1);
  }
  return p.length > 5 ? p.substring(0, 5) : p;
}

/// Una palabra clave: su raíz tal cual ([literal]), la que cuenta después de los sinónimos ([raiz]) y si va negada.
class _Clave {
  const _Clave(this.literal, this.raiz, {required this.negada});

  final String literal;
  final String raiz;
  final bool negada;
}

/// Las palabras clave de [texto], trozo a trozo. Una palabra va negada si detrás de una negación, en su mismo trozo,
/// hay como mucho [alcance] palabras (sin límite: hasta el final del trozo).
List<_Clave> _claves(String texto, {int? alcance}) {
  final claves = <_Clave>[];
  // «No solo es delito, también…» no niega nada: «no solo» pasa a una palabra vacía.
  final sinNoSolo = normalizar(texto).replaceAll(RegExp(r'\bno (solo|solamente|unicamente)\b'), 'ademas');
  final trozos = sinNoSolo.split(RegExp(r'''[.,;:!?¡¿()\[\]{}"«»“”…\n\r\t/]+'''));
  for (final trozo in trozos) {
    var posicion = 0;
    int? negacion;
    for (final coincidencia in RegExp('[a-z0-9]+').allMatches(trozo)) {
      final palabra = coincidencia.group(0)!;
      if (_separadores.contains(palabra)) {
        negacion = null;
        continue;
      }
      final aqui = posicion++;
      final negada = negacion != null && (alcance == null || aqui - negacion <= alcance);
      if (_negaciones.contains(palabra)) {
        negacion = aqui;
        continue;
      }
      if (_vacias.contains(palabra)) continue;
      final literal = raizDilo(palabra);
      final contraria = _contrarios[literal];
      claves.add(
        contraria == null
            ? _Clave(literal, _sinonimos[literal] ?? literal, negada: negada)
            : _Clave(literal, contraria, negada: !negada),
      );
      if (_niegaDetras(palabra)) negacion = aqui;
    }
  }
  return claves;
}

/// Una idea clave preparada para comparar: sus raíces (sin repetir) y cuáles van negadas.
class _Idea {
  _Idea(this.texto) {
    for (final clave in _claves(texto, alcance: _alcanceNegacionIdea)) {
      if (clave.negada) negadas.add(clave.raiz);
      raices.add(clave.raiz);
    }
  }

  final String texto;
  final raices = <String>{};
  final negadas = <String>{};

  /// Las que hay que decir: la mitad como poco, y como mínimo dos (o todas, si tiene menos).
  int get necesarias {
    final n = raices.length;
    if (n <= 2) return n;
    final mitad = (n + 1) ~/ 2;
    return mitad < 2 ? 2 : mitad;
  }
}

/// Qué ideas clave de [proposiciones] ha explicado [texto]. [pregunta] sirve para no contar como explicada una idea
/// solo por repetir la pregunta. Devuelve, en orden, true para cada idea dicha.
List<bool> ideasDichas({required List<String> proposiciones, required String texto, String pregunta = ''}) {
  final ideas = [for (final p in proposiciones) _Idea(p)];
  final escrito = _claves(texto);
  // Lo que dice la pregunta, tal cual, sin el «Explica con tus palabras» que llevan todas.
  final clavesPregunta = _claves(normalizar(pregunta).replaceFirst('explica con tus palabras', ''));
  final dePregunta = {for (final clave in clavesPregunta) clave.literal};
  final raicesPregunta = {for (final clave in clavesPregunta) clave.raiz};

  // Cada palabra escrita: si aparece negada en algún sitio y si aparece sin negar, y si alguna vez no es de la pregunta.
  final negadas = <String>{};
  final sinNegar = <String>{};
  final nuevas = <String>{};
  for (final clave in escrito) {
    (clave.negada ? negadas : sinNegar).add(clave.raiz);
    if (!dePregunta.contains(clave.literal)) nuevas.add(clave.raiz);
  }
  // Lo mismo con la negación de cerca, como en las ideas («la grabación no vale»: «vale», sí; «juicio», no).
  final negadasCerca = <String>{};
  final sinNegarCerca = <String>{};
  for (final clave in _claves(texto, alcance: _alcanceNegacionIdea)) {
    (clave.negada ? negadasCerca : sinNegarCerca).add(clave.raiz);
  }

  // Primero, las ideas que cumplen todo salvo la última regla (las candidatas), con lo que tienen en común.
  final dichas = <Set<String>?>[];
  for (final idea in ideas) {
    final coinciden = <String>{};
    var contradice = false;
    for (final raiz in idea.raices) {
      if (idea.negadas.contains(raiz)) {
        // Negada en la idea («no tienes que ir»): solo vale negada; dicha sin negar, la contradice.
        if (negadas.contains(raiz)) {
          coinciden.add(raiz);
        } else if (sinNegar.contains(raiz)) {
          contradice = true;
        }
      } else if (idea.negadas.isEmpty &&
          negadasCerca.contains(raiz) &&
          !sinNegarCerca.contains(raiz) &&
          !raicesPregunta.contains(raiz)) {
        // La idea afirma («la grabación vale») y solo se ha dicho negada justo detrás de un «no» («no vale»): la
        // contradice. Las palabras de la pregunta no cuentan («No hay que reenviarlas porque…», en E-506).
        contradice = true;
      } else if (negadas.contains(raiz) || sinNegar.contains(raiz)) {
        coinciden.add(raiz);
      }
    }
    final candidata =
        !contradice &&
        idea.raices.isNotEmpty &&
        coinciden.length >= idea.necesarias &&
        idea.raices.where(_imprescindibles.contains).every(coinciden.contains) &&
        coinciden.any(nuevas.contains);
    dichas.add(candidata ? coinciden : null);
  }

  // Si dos ideas se parecen, cada una necesita alguna palabra que no comparta con otra candidata.
  final veces = <String, int>{};
  for (final coinciden in dichas) {
    for (final raiz in coinciden ?? const <String>{}) {
      veces[raiz] = (veces[raiz] ?? 0) + 1;
    }
  }
  return [for (final coinciden in dichas) coinciden != null && coinciden.any((raiz) => veces[raiz] == 1)];
}

/// La corrección aproximada de «Dilo con tus palabras», con la misma forma que la del servidor (sección 8.2): las ideas
/// dichas, las que faltan, la nota (dichas / totales) y el mensaje («Te falta una idea: …»).
GradeResponse corregirEnElMovil({required List<String> proposiciones, required String texto, String pregunta = ''}) {
  final dichas = ideasDichas(proposiciones: proposiciones, texto: texto, pregunta: pregunta);
  final cubiertas = [
    for (final (i, idea) in proposiciones.indexed)
      if (dichas[i]) idea,
  ];
  final faltan = [
    for (final (i, idea) in proposiciones.indexed)
      if (!dichas[i]) idea,
  ];
  return GradeResponse(
    puntuacion: proposiciones.isEmpty ? 0 : cubiertas.length / proposiciones.length,
    cubiertas: cubiertas,
    faltan: faltan,
    feedback: mensajeIdeas(faltan),
  );
}

/// «Te falta una idea: …», «Te faltan 2 ideas: …» o, si no falta ninguna, «¡Has dicho todas las ideas clave!».
String mensajeIdeas(List<String> faltan) {
  String enFrase(String idea) {
    final limpia = idea.trim().replaceAll(RegExp(r'[.\s]+$'), '');
    return limpia.isEmpty ? limpia : '${limpia[0].toLowerCase()}${limpia.substring(1)}';
  }

  return switch (faltan.length) {
    0 => '¡Has dicho todas las ideas clave!',
    1 => 'Te falta una idea: ${enFrase(faltan.single)}.',
    _ => 'Te faltan ${faltan.length} ideas: ${faltan.map(enFrase).join('; ')}.',
  };
}

/// El servidor no corrige lo que suena a peligro (sección 8.2, `"tipo": "crisis"`): responde con la plantilla de ayuda.
/// Se reconoce por `tipo` ([GradeResponse.esCrisis]). Si un servidor antiguo no lo manda, por la forma: sin ideas (una
/// corrección normal siempre trae las ideas del ejercicio, dichas o no). Entonces se enseña la tarjeta de Ayuda, sin
/// puntos y sin tocar el dominio.
bool esCorreccionDeCrisis(GradeResponse nota) =>
    nota.esCrisis || (nota.tipo == null && nota.cubiertas.isEmpty && nota.faltan.isEmpty);
