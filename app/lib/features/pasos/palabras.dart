import '../../core/texto.dart';
import 'modelos.dart';

// «Las palabras que oirás» en cada paso: los términos del Glosario que salen en el paso, para que la primera vez que
// los oigas ya sepas qué son. Cada uno abre el Glosario.

/// Cuántas palabras se enseñan como mucho en un paso.
const maximoPalabrasPaso = 6;

/// Los términos de [terminos] que salen en [texto], en el orden en que salen por primera vez. Sin que importen las
/// mayúsculas ni las tildes, y como palabras completas («Juicio» no sale en «perjuicio»).
List<String> terminosEnTexto(String texto, Iterable<String> terminos) {
  final normal = normalizar(texto);
  final encontrados = <(int, String)>[];
  for (final termino in terminos) {
    final clave = normalizar(termino.trim());
    if (clave.isEmpty) continue;
    final patron = RegExp('(?<![a-z0-9])${RegExp.escape(clave)}(?![a-z0-9])');
    final coincidencia = patron.firstMatch(normal);
    if (coincidencia != null) encontrados.add((coincidencia.start, termino));
  }
  encontrados.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (_, termino) in encontrados) termino];
}

/// Las palabras de [paso] que están en el [glosario]: primero las que pide el contenido ([pedidas]), con el nombre que
/// tienen en el glosario, y después las que salen en el texto del paso. Sin repetir y como mucho [maximo].
List<String> palabrasDelPaso(
  Paso paso, {
  required List<String> glosario,
  List<String> pedidas = const [],
  int maximo = maximoPalabrasPaso,
}) {
  final porClave = {for (final termino in glosario) normalizar(termino.trim()): termino};
  final salida = <String>[];
  final vistas = <String>{};
  void anadir(String termino) {
    final clave = normalizar(termino.trim());
    final delGlosario = porClave[clave];
    if (delGlosario == null || !vistas.add(clave)) return;
    salida.add(delGlosario);
  }

  for (final termino in pedidas) {
    anadir(termino);
  }
  final texto = [paso.nombre, paso.quePasa, ...paso.quienEsta, ...paso.quePuedesPedir].join('\n');
  for (final termino in terminosEnTexto(texto, glosario)) {
    anadir(termino);
  }
  return salida.length <= maximo ? salida : salida.sublist(0, maximo);
}
