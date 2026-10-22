import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/content_repo.dart';

// Lo que la app empaqueta de verdad (pubspec.yaml → flutter → assets). Flutter no mete las subcarpetas de una carpeta
// de assets: cada una tiene que estar en la lista. Si falta una, la app (APK y web) se queda sin esos ficheros aunque
// los tests que leen del disco pasen. Pasó con assets/mock/content/situacion/ (los derechos, las preocupaciones, los
// pasos y las notas de Mi situación).

/// Las carpetas de assets que declara pubspec.yaml («    - assets/…/»), sin la barra final.
Set<String> _carpetasDeclaradas() {
  final declaradas = <String>{};
  for (final linea in File('pubspec.yaml').readAsLinesSync()) {
    final m = RegExp(r'^\s+-\s+(assets/\S+)/\s*$').firstMatch(linea);
    if (m != null) declaradas.add(m.group(1)!);
  }
  return declaradas;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cada carpeta con ficheros de assets/mock/content y assets/content está en pubspec.yaml', () {
    final declaradas = _carpetasDeclaradas();
    for (final raiz in [ContentRepo.raizEjemplos, ContentRepo.raiz]) {
      final carpeta = Directory(raiz);
      if (!carpeta.existsSync()) continue;
      final conFicheros = {
        for (final f in carpeta.listSync(recursive: true).whereType<File>())
          if (!f.path.split('/').last.startsWith('.')) f.parent.path,
      };
      for (final ruta in conFicheros) {
        expect(declaradas, contains(ruta), reason: 'Falta «    - $ruta/» en pubspec.yaml (flutter → assets)');
      }
    }
  });

  test('el contenido de Mi situación viaja con la app (se lee del bundle, no del disco)', () async {
    for (final fichero in ['derechos', 'preocupaciones', 'pasos', 'notas']) {
      final ruta = '${ContentRepo.raizEjemplos}/situacion/$fichero.json';
      final json = jsonDecode(await rootBundle.loadString(ruta)) as Map<String, dynamic>;
      expect(json['validado'], isTrue, reason: ruta);
    }
  });
}
