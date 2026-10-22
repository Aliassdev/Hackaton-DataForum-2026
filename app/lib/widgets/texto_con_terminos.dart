import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/api/models.dart';
import '../core/texto.dart';
import '../tema.dart';
import 'fuente_chip.dart';

/// Texto con los términos jurídicos subrayados (sección 4.4). Al tocar uno se abre el Glosario con ese término.
///
/// Los términos se buscan sin que importen las mayúsculas ni las tildes, como palabras completas, y se marca
/// la primera vez que sale cada uno. Las referencias a fuentes del texto ([A-017]) se cambian por su número,
/// que también se puede tocar.
class TextoConTerminos extends StatefulWidget {
  const TextoConTerminos({
    super.key,
    required this.texto,
    this.terminos = const [],
    this.fuentes = const [],
    this.style,
    this.onTermino,
    this.onFuente,
  });

  final String texto;
  final List<String> terminos;

  /// Para numerar las referencias [A-017] del texto. Las que no están aquí se quitan.
  final List<Fuente> fuentes;
  final TextStyle? style;

  /// Por defecto abre `/glosario?q=<término>`.
  final ValueChanged<String>? onTermino;

  /// Por defecto abre la hoja de la fuente.
  final ValueChanged<Fuente>? onFuente;

  @override
  State<TextoConTerminos> createState() => _TextoConTerminosState();
}

class _TextoConTerminosState extends State<TextoConTerminos> {
  List<TrozoTexto> _trozos = const [];
  final _reconocedores = <TapGestureRecognizer>[];

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  @override
  void didUpdateWidget(TextoConTerminos anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.texto != widget.texto ||
        !_mismaLista(anterior.terminos, widget.terminos) ||
        !_mismaLista([for (final f in anterior.fuentes) f.id], [for (final f in widget.fuentes) f.id])) {
      _preparar();
    }
  }

  void _preparar() {
    _soltarReconocedores();
    _trozos = trocearTexto(widget.texto, terminos: widget.terminos, fuentes: widget.fuentes);
    for (final trozo in _trozos) {
      if (trozo.termino != null) {
        _reconocedores.add(TapGestureRecognizer()..onTap = () => _abrirTermino(trozo.termino!));
      }
    }
  }

  void _abrirTermino(String termino) {
    HapticFeedback.selectionClick();
    final accion = widget.onTermino;
    if (accion != null) {
      accion(termino);
    } else {
      context.push(Uri(path: '/glosario', queryParameters: {'q': termino}).toString());
    }
  }

  void _abrirFuente(Fuente fuente) {
    HapticFeedback.selectionClick();
    final accion = widget.onFuente;
    if (accion != null) {
      accion(fuente);
    } else {
      mostrarFuente(context, fuente);
    }
  }

  void _soltarReconocedores() {
    for (final r in _reconocedores) {
      r.dispose();
    }
    _reconocedores.clear();
  }

  @override
  void dispose() {
    _soltarReconocedores();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final base = widget.style ?? tema.textTheme.bodyLarge;
    final estiloTermino = TextStyle(
      color: esquema.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: esquema.primary,
      decorationThickness: 2,
    );
    var r = 0;
    final hijos = <InlineSpan>[];
    for (final trozo in _trozos) {
      if (trozo.termino != null) {
        hijos.add(
          TextSpan(
            text: trozo.texto,
            style: estiloTermino,
            recognizer: _reconocedores[r++],
            semanticsLabel: '${trozo.texto}. Toca para ver qué significa',
          ),
        );
      } else if (trozo.fuentes.isNotEmpty) {
        for (final i in trozo.fuentes) {
          final fuente = widget.fuentes[i];
          hijos.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: Espacio.xs),
                // Es un enlace dentro del texto (como los términos); la etiqueta grande está debajo.
                child: Semantics(
                  link: true,
                  label: 'Fuente ${i + 1}: ${fuente.titulo}',
                  excludeSemantics: true,
                  onTap: () => _abrirFuente(fuente),
                  child: Tooltip(
                    message: fuente.titulo,
                    excludeFromSemantics: true,
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => _abrirFuente(fuente),
                      child: NumeroFuente(numero: i + 1),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      } else {
        hijos.add(TextSpan(text: trozo.texto));
      }
    }
    return Text.rich(TextSpan(style: base, children: hijos));
  }
}

/// Un trozo del texto: texto normal, un término del glosario o una referencia a fuentes.
@immutable
class TrozoTexto {
  const TrozoTexto(this.texto, {this.termino, this.fuentes = const []});

  final String texto;

  /// El término tal como viene en `terminos` (para buscarlo en el Glosario).
  final String? termino;

  /// Índices en la lista de fuentes.
  final List<int> fuentes;
}

final _referencia = RegExp(r'\s*\[([A-Za-z]{1,4}-[\w.-]+(?:\s*[,;]\s*[A-Za-z]{1,4}-[\w.-]+)*)\]');
final _separadorIds = RegExp(r'\s*[,;]\s*');
final _letraODigito = RegExp(r'[a-z0-9]');

/// Divide [texto] en trozos (público para poder probarlo).
List<TrozoTexto> trocearTexto(String texto, {List<String> terminos = const [], List<Fuente> fuentes = const []}) {
  final marcas = <({int inicio, int fin, TrozoTexto trozo})>[];

  for (final m in _referencia.allMatches(texto)) {
    final indices = <int>{
      for (final id in m.group(1)!.split(_separadorIds)) fuentes.indexWhere((f) => f.id == id.trim()),
    }.where((i) => i >= 0).toList()..sort();
    marcas.add((inicio: m.start, fin: m.end, trozo: TrozoTexto('', fuentes: indices)));
  }

  final normal = _normalizarIgualLongitud(texto);
  final buscados = {for (final t in terminos) t.trim()}.where((t) => t.isNotEmpty).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final termino in buscados) {
    final aguja = _normalizarIgualLongitud(termino);
    var desde = 0;
    while (desde <= normal.length - aguja.length) {
      final i = normal.indexOf(aguja, desde);
      if (i < 0) break;
      final fin = i + aguja.length;
      final libre = !marcas.any((m) => i < m.fin && fin > m.inicio);
      if (libre && _esLimite(normal, i - 1) && _esLimite(normal, fin)) {
        marcas.add((inicio: i, fin: fin, trozo: TrozoTexto(texto.substring(i, fin), termino: termino)));
        break;
      }
      desde = i + 1;
    }
  }

  marcas.sort((a, b) => a.inicio.compareTo(b.inicio));
  final trozos = <TrozoTexto>[];
  var posicion = 0;
  for (final m in marcas) {
    if (m.inicio > posicion) trozos.add(TrozoTexto(texto.substring(posicion, m.inicio)));
    trozos.add(m.trozo);
    posicion = m.fin;
  }
  if (posicion < texto.length) trozos.add(TrozoTexto(texto.substring(posicion)));
  return trozos;
}

bool _esLimite(String texto, int indice) =>
    indice < 0 || indice >= texto.length || !_letraODigito.hasMatch(texto[indice]);

/// Como [normalizar], pero sin cambiar la longitud, para que las posiciones sirvan en el texto original.
String _normalizarIgualLongitud(String texto) {
  final resultado = StringBuffer();
  for (var i = 0; i < texto.length; i++) {
    final caracter = texto[i];
    final normal = normalizar(caracter);
    resultado.write(normal.length == 1 ? normal : caracter);
  }
  return resultado.toString();
}

bool _mismaLista(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
