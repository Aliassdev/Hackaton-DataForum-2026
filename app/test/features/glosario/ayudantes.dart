import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tuturno/core/content_models.dart';
import 'package:tuturno/core/content_repo.dart';
import 'package:tuturno/core/voz/tts.dart';
import 'package:tuturno/features/juego/modelos.dart';

// Piezas comunes de las pruebas del glosario (plan v2, producto §5.7).

/// Texto a voz falso: guarda lo que se lee. Con [terminarAlInstante] en false, sigue «hablando» hasta [parar].
class TtsFalso implements Tts {
  TtsFalso({this.terminarAlInstante = false});

  bool terminarAlInstante;
  final leidos = <String>[];
  final velocidades = <double?>[];
  int paradas = 0;
  final _hablando = ValueNotifier(false);
  Completer<void>? _lectura;

  @override
  ValueListenable<bool> get hablando => _hablando;

  @override
  Future<void> hablar(String texto, {double? velocidad}) {
    leidos.add(texto);
    velocidades.add(velocidad);
    _lectura?.complete();
    _lectura = null;
    if (terminarAlInstante) return Future.value();
    final lectura = _lectura = Completer<void>();
    _hablando.value = true;
    return lectura.future;
  }

  @override
  Future<void> parar() async {
    paradas++;
    _hablando.value = false;
    _lectura?.complete();
    _lectura = null;
  }
}

/// Un caso mínimo en memoria: una escena con [narracion], una decisión con [pregunta], [opcion] y [explicacion], y una
/// carta con [carta].
Caso casoEnMemoria({
  required String id,
  String protagonista = '',
  String titulo = 'Un caso',
  String narracion = '',
  String pregunta = '',
  String opcion = '',
  String explicacion = '',
  String carta = '',
}) => Caso.fromJson({
  'id': id,
  'titulo': titulo,
  'rol': 'victima',
  'escenas': [
    {
      'id': 'E1',
      'lugar': 'casa',
      'personajes': [if (protagonista.isNotEmpty) protagonista],
      'narracion': narracion,
      if (pregunta.isNotEmpty || opcion.isNotEmpty)
        'decision': {
          'pregunta': pregunta,
          'opciones': [
            {'texto': opcion, 'correcta': true, 'feedback': explicacion, 'fuente': 'A-001'},
          ],
        },
    },
  ],
  'cartas': [
    if (carta.isNotEmpty) {'id': 'R-1', 'titulo': 'Carta', 'texto': carta, 'fuente': 'A-001'},
  ],
  'validado': true,
});

/// Una palabra del glosario para las pruebas.
EntradaGlosario palabra(String id, String termino, {String definicion = 'Definición.', String ejemplo = ''}) =>
    EntradaGlosario(
      id: id,
      termino: termino,
      definicion: definicion,
      ejemplo: ejemplo,
      fuente: 'A-001',
      validado: true,
    );

/// Los tests se ejecutan desde app/.
const casosOficiales = ['caso-sala-gesell', 'caso-acoso-escolar', 'caso-difusion-imagenes'];

/// Los casos de ejemplo de assets/mock/content/juego (los tres oficiales), leídos del disco.
List<Caso> casosDeEjemplo() => [
  for (final id in casosOficiales)
    Caso.fromJson(
      jsonDecode(File('${ContentRepo.raizEjemplos}/juego/$id.json').readAsStringSync()) as Map<String, dynamic>,
    ),
];

/// El glosario de ejemplo (assets/mock/content/glosario.json) tal cual, como texto.
String glosarioDeEjemploJson() => File('${ContentRepo.raizEjemplos}/glosario.json').readAsStringSync();

/// El glosario de ejemplo, ya leído.
List<EntradaGlosario> glosarioDeEjemplo() => [
  for (final e in jsonDecode(glosarioDeEjemploJson()) as List) EntradaGlosario.fromJson(e as Map<String, dynamic>),
];
