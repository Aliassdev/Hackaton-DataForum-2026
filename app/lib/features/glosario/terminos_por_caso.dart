import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/content_models.dart';
import '../../core/providers.dart';
import '../../core/texto.dart';
import '../juego/juego_providers.dart' show casosProvider;
import '../juego/modelos.dart' show Caso;

// Filtro por caso del glosario (plan v2, producto §5.7): qué palabras salen en el caso de Lucía, en el de Sergio y en
// el de Sara. Se calcula buscando cada término en el texto de los casos, sin tocar el esquema del glosario (9.6).

/// Ids de los términos de [glosario] que aparecen en el texto de cada caso (título, narraciones, preguntas, opciones,
/// explicaciones y cartas), por id del caso. Un caso sin ningún término sale con el conjunto vacío.
///
/// Cada término se busca entero, como frase, sin que importen tildes ni mayúsculas, y también en plural y en femenino
/// («Abogado de oficio» encuentra «una abogada de oficio»; «Medida», «medidas»). Los términos muy generales
/// («Víctima», «Denuncia») salen en varios casos: es correcto, salen.
Map<String, Set<String>> terminosPorCaso(List<EntradaGlosario> glosario, List<Caso> casos) {
  final patrones = <(String, RegExp)>[
    for (final entrada in glosario)
      if (patronDeTermino(entrada.termino) case final patron?) (entrada.id, patron),
  ];
  final porCaso = <String, Set<String>>{};
  for (final caso in casos) {
    final texto = textoDeCaso(caso);
    porCaso[caso.id] = {
      for (final (id, patron) in patrones)
        if (patron.hasMatch(texto)) id,
    };
  }
  return porCaso;
}

/// Todo el texto que se lee en un caso, ya normalizado (minúsculas y sin tildes). Cada trozo va separado con « | »
/// para que un término no se encuentre a caballo entre dos trozos.
@visibleForTesting
String textoDeCaso(Caso caso) => normalizar(
  [
    caso.titulo,
    for (final escena in caso.escenas) ...[
      escena.narracion,
      if (escena.decision case final decision?) ...[
        decision.pregunta,
        for (final opcion in decision.opciones) ...[opcion.texto, opcion.feedback],
      ],
    ],
    for (final carta in caso.cartas) ...[carta.titulo, carta.texto],
  ].join(' | '),
);

/// La expresión que encuentra [termino] entero en un texto normalizado: palabra a palabra, con el plural y el
/// femenino de cada una. null si el término no tiene letras.
RegExp? patronDeTermino(String termino) {
  final palabras = normalizar(termino).split(RegExp(r'[^a-z0-9]+')).where((p) => p.isNotEmpty).toList();
  if (palabras.isEmpty) return null;
  return RegExp('(?<![a-z0-9])${palabras.map(_formas).join(r'\s+')}(?![a-z0-9])');
}

/// Las formas de una palabra normalizada que se aceptan. Las cortas («de», «la», «ser») van tal cual.
String _formas(String palabra) {
  if (palabra.length <= 3) return RegExp.escape(palabra);
  final raiz = RegExp.escape(palabra.substring(0, palabra.length - 1));
  return switch (palabra[palabra.length - 1]) {
    // abogado → abogada, abogados, abogadas
    'o' => '$raiz[oa]s?',
    // juez → jueza, jueces
    'z' => '$raiz(?:z(?:as?)?|ces)',
    // menores, datos: ya están en plural
    's' => RegExp.escape(palabra),
    // víctima → víctimas; equipo psicosocial → equipos psicosociales
    'a' || 'e' || 'i' || 'u' => '${RegExp.escape(palabra)}s?',
    // declaración → declaraciones; coordinador → coordinadora, coordinadoras
    _ => '${RegExp.escape(palabra)}(?:es|as?)?',
  };
}

/// Un chip de caso del glosario: «Lucía», con las palabras de su caso.
@immutable
class FiltroCaso {
  const FiltroCaso({required this.casoId, required this.protagonista, required this.terminos});

  final String casoId;

  /// El nombre del chip.
  final String protagonista;

  /// Ids de las palabras del glosario que salen en el caso.
  final Set<String> terminos;
}

/// Los chips de caso, en el orden de los casos (Lucía, Sergio y Sara): uno por cada caso con protagonista y con al
/// menos una palabra del glosario.
List<FiltroCaso> filtrosDeCaso(List<EntradaGlosario> glosario, List<Caso> casos) {
  final porCaso = terminosPorCaso(glosario, casos);
  return [
    for (final caso in casos)
      if (caso.protagonista.trim().isNotEmpty && (porCaso[caso.id] ?? const {}).isNotEmpty)
        FiltroCaso(casoId: caso.id, protagonista: caso.protagonista.trim(), terminos: porCaso[caso.id]!),
  ];
}

/// Los chips de caso del glosario. Si los casos no se pueden cargar, da error y el glosario se ve sin ellos.
final filtrosCasoProvider = FutureProvider<List<FiltroCaso>>((ref) async {
  final glosario = await ref.watch(glosarioProvider.future);
  final casos = await ref.watch(casosProvider.future);
  return filtrosDeCaso(glosario, casos);
}, retry: (_, _) => null);
