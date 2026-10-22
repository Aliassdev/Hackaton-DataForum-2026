import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

/// Comprueba que los JSON de fixtures.dart siguen siendo los de docs/ARQUITECTURA.md.
/// Si el documento no está (p. ej. se copia solo app/), estos tests se saltan.
void main() {
  final doc = _documento();
  final skip = doc == null ? 'No se encuentra docs/ARQUITECTURA.md' : null;

  List<Object?> bloques(String apartado) => _bloquesJson(doc!, apartado);

  test('8.1: petición y respuesta de /api/agent/ask', () {
    expect(bloques('8.1'), [jsonDecode(askPeticionDoc), jsonDecode(askRespuestaDoc)]);
  }, skip: skip);

  test('8.2: petición y respuesta de /api/learn/grade', () {
    expect(bloques('8.2'), [jsonDecode(gradePeticionDoc), jsonDecode(gradeRespuestaDoc)]);
  }, skip: skip);

  test('8.3: respuesta de /api/health', () {
    expect(bloques('8.3'), [jsonDecode(healthDoc)]);
  }, skip: skip);

  test('8.4: formato de los errores', () {
    expect(bloques('8.4'), [jsonDecode(errorDoc)]);
  }, skip: skip);

  test('9.7: plantillas de seguridad', () {
    expect(bloques('9.7'), [jsonDecode(seguridadDoc)]);
  }, skip: skip);
}

/// Los tests se ejecutan desde app/; el documento está en la raíz del repo.
String? _documento() {
  for (final ruta in ['../docs/ARQUITECTURA.md', 'docs/ARQUITECTURA.md']) {
    final fichero = File(ruta);
    if (fichero.existsSync()) return fichero.readAsStringSync();
  }
  return null;
}

/// Bloques ```json del apartado («### 8.1 …») hasta el siguiente título.
List<Object?> _bloquesJson(String doc, String apartado) {
  final lineas = const LineSplitter().convert(doc);
  final inicio = lineas.indexWhere((l) => l.startsWith('### $apartado '));
  expect(inicio, isNot(-1), reason: 'Falta el apartado $apartado en el documento');
  var fin = lineas.indexWhere((l) => l.startsWith('#'), inicio + 1);
  if (fin == -1) fin = lineas.length;
  final seccion = lineas.sublist(inicio + 1, fin).join('\n');
  return [for (final m in RegExp(r'```json\n(.*?)\n```', dotAll: true).allMatches(seccion)) jsonDecode(m.group(1)!)];
}
