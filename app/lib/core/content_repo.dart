import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'content_models.dart';
import 'texto.dart';

/// Carga el contenido empaquetado en assets/content (lo copia scripts/sync_content.sh desde content/)
/// y lo guarda en memoria.
///
/// Solo devuelve elementos con "validado": true y fuente, salvo con [mostrarBorradores] (modo DEMO).
/// Con [usarEjemplos], si falta un fichero se usan los datos de ejemplo de assets/mock/content.
class ContentRepo {
  ContentRepo({AssetBundle? bundle, this.mostrarBorradores = false, this.usarEjemplos = false, this.listarAssets})
    : _bundle = bundle ?? rootBundle;

  static const raiz = 'assets/content';
  static const raizEjemplos = 'assets/mock/content';

  final AssetBundle _bundle;
  final bool mostrarBorradores;
  final bool usarEjemplos;

  /// Lista de todos los assets empaquetados. Los tests la sustituyen.
  final Future<List<String>> Function()? listarAssets;

  /// Se guarda el Future: si dos pantallas piden lo mismo a la vez, el fichero se lee una sola vez.
  final _cache = <String, Future<Object?>>{};

  /// Un fichero de contenido (p. ej. 'lecciones/unidad-1.json'), ya decodificado. null si falta o no es JSON.
  Future<Object?> json(String fichero) => _cargar(fichero);

  /// Los JSON de una carpeta de contenido (p. ej. 'juego'), como rutas relativas ordenadas
  /// ('juego/caso-sala-gesell.json'). Si la carpeta real está vacía, los de ejemplo.
  Future<List<String>> listar(String carpeta) async {
    final assets = await (listarAssets ?? _assetsDelManifiesto)();
    List<String> de(String base) {
      final prefijo = '$base/$carpeta/';
      return [
        for (final a in assets)
          if (a.startsWith(prefijo) && a.endsWith('.json') && !a.substring(prefijo.length).contains('/'))
            a.substring(base.length + 1),
      ]..sort();
    }

    final reales = de(raiz);
    return reales.isNotEmpty || !usarEjemplos ? reales : de(raizEjemplos);
  }

  Future<List<String>> _assetsDelManifiesto() async {
    try {
      return (await AssetManifest.loadFromAssetBundle(_bundle)).listAssets();
    } catch (e) {
      debugPrint('ContentRepo: no se pudo leer el manifiesto de assets ($e)');
      return const [];
    }
  }

  /// El contenido jurídico solo se enseña si está validado y tiene fuente (CLAUDE.md), salvo borradores en DEMO.
  bool visible({required bool validado, required String fuente}) => mostrarBorradores || publicable(validado, fuente);

  /// Glosario ordenado alfabéticamente (sin que importen las tildes).
  Future<List<EntradaGlosario>> glosario() async {
    final json = await _cargar('glosario.json');
    if (json is! List) return const [];
    final entradas = <EntradaGlosario>[];
    for (final e in json) {
      final entrada = _entradaGlosario(e);
      if (entrada != null && visible(validado: entrada.validado, fuente: entrada.fuente)) {
        entradas.add(entrada);
      }
    }
    return entradas..sort((a, b) {
      final orden = normalizar(a.termino).compareTo(normalizar(b.termino));
      return orden != 0 ? orden : a.termino.compareTo(b.termino);
    });
  }

  /// El contenido jurídico solo se enseña si está validado y tiene fuente (CLAUDE.md).
  static bool publicable(bool validado, String fuente) => validado && fuente.trim().isNotEmpty;

  /// Una entrada mal formada se salta: no deja sin glosario al resto.
  static EntradaGlosario? _entradaGlosario(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      return EntradaGlosario.fromJson(json);
    } catch (_) {
      debugPrint('ContentRepo: entrada del glosario no válida (${json['id']})');
      return null;
    }
  }

  Future<Object?> _cargar(String fichero) => _cache[fichero] ??= _cargarSinCache(fichero);

  Future<Object?> _cargarSinCache(String fichero) async {
    final json = await _leer('$raiz/$fichero');
    if (json != null || !usarEjemplos) return json;
    return _leer('$raizEjemplos/$fichero');
  }

  /// Nunca lanza: si el fichero falta o no es JSON válido, devuelve null.
  Future<Object?> _leer(String ruta) async {
    try {
      return jsonDecode(await _bundle.loadString(ruta));
    } catch (e) {
      debugPrint('ContentRepo: no se pudo cargar $ruta ($e)');
      return null;
    }
  }
}
