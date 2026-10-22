import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/agente/respuesta_agente.dart' show plantillasSeguridad, TipoTextoAgente, telefonosEnCifras;
import 'package:tuturno/core/api/mock_api.dart';
import 'package:tuturno/core/api/tuturno_api.dart';
import 'package:tuturno/features/pregunta/ejemplos.dart';

// Las conversaciones de ejemplo de Pregunta (assets/mock/content/pregunta_ejemplos.json): el JSON se lee, cada
// respuesta lleva fuentes que son apartados de docs/MARCO_LEGAL.md (con su enlace exacto), y se reconocen las frases del
// guion de la demo. La red de seguridad va antes que el guion.

/// El JSON leído del disco (los tests se ejecutan desde app/). Sin fakes.dart: así no depende del resto de la app.
String ejemplosPreguntaJson() => File(rutaEjemplosPregunta).readAsStringSync();

void main() {
  final conversaciones = leerEjemplosPregunta(ejemplosPreguntaJson());

  test('el JSON se lee: las tres conversaciones del guion, todas con origen marco_legal', () {
    expect(conversaciones.map((c) => c.id), ['sergio-hechos', 'sergio-proceso', 'sara-fotos']);
    expect(conversaciones.map((c) => c.caso), ['Sergio', 'Sergio', 'Sara']);
    for (final c in conversaciones) {
      expect(c.origen, 'marco_legal', reason: c.id);
      expect(c.respuesta.respuesta.trim(), isNotEmpty, reason: c.id);
      expect(c.respuesta.fuentes, isNotEmpty, reason: '${c.id}: cada respuesta lleva su fuente');
      expect(c.respuesta.sugerencias, isNotEmpty, reason: c.id);
    }
    expect(conversaciones.map((c) => c.respuesta.tipo), [
      TipoRespuesta.hechos,
      TipoRespuesta.normal,
      TipoRespuesta.normal,
    ]);
  });

  test('el momento «hechos» de Sergio es la plantilla literal del agente, con el teléfono en cifras', () {
    final hechos = conversaciones.firstWhere((c) => c.id == 'sergio-hechos').respuesta.respuesta;
    expect(hechos, MockTuTurnoApi.plantillaHechosAgente);
    expect(hechos, telefonosEnCifras(plantillasSeguridad[TipoTextoAgente.hechos]![1]));
  });

  test('las respuestas no prometen secreto, no preguntan qué pasó y van en párrafos cortos', () {
    for (final c in conversaciones) {
      final texto = c.respuesta.respuesta.toLowerCase();
      expect(texto, isNot(contains('qué pasó?')), reason: c.id);
      expect(texto, isNot(contains('secreto')), reason: c.id);
      expect(texto, isNot(contains('nadie se va a enterar')), reason: c.id);
      for (final parrafo in c.respuesta.respuesta.split('\n\n')) {
        expect(parrafo.trim().split(RegExp(r'\s+')).length, lessThan(80), reason: '${c.id}: párrafo largo');
      }
    }
  });

  test('cada referencia del texto es una de sus fuentes, y cada fuente se cita o es la única', () {
    final referencia = RegExp(r'\[([A-Za-z]{1,4}-[\w.-]+)\]');
    for (final c in conversaciones) {
      final ids = {for (final f in c.respuesta.fuentes) f.id};
      final citadas = {for (final m in referencia.allMatches(c.respuesta.respuesta)) m.group(1)!};
      expect(ids, containsAll(citadas), reason: c.id);
      if (citadas.isNotEmpty) expect(citadas, containsAll(ids), reason: '${c.id}: fuente sin citar');
    }
  });

  final marcoLegal = _marcoLegal();
  test('cada fuente es un apartado de docs/MARCO_LEGAL.md y su enlace es el de ese apartado', () {
    final apartados = _apartados(marcoLegal!);
    // Cómo se llama cada norma en los encabezados del marco, si no es igual.
    const enElMarco = {
      'LO 8/2021': 'LOPIVI (LO 8/2021)',
      'AEPD · FAQ 15.03': 'AEPD · Preguntas frecuentes, art. FAQ 15.03',
    };
    final numero = RegExp(r'^\d+(\.\d+)*( (bis|ter))?');
    for (final c in conversaciones) {
      for (final f in c.respuesta.fuentes) {
        final norma = enElMarco[f.norma] ?? f.norma;
        final articulos = [
          for (final parte in f.articulo.split(RegExp(r', | y ')))
            if (numero.firstMatch(parte.trim()) case final m?) m.group(0)!,
        ];
        final apartado = apartados.entries
            .where(
              (e) =>
                  (e.key.startsWith('### $norma,') || e.key.startsWith('### $norma ')) &&
                  articulos.every(
                    (a) =>
                        RegExp('(?<![\\d.])${RegExp.escape(a)}(?!\\d)').hasMatch(e.key.substring('### $norma'.length)),
                  ),
            )
            .firstOrNull;
        expect(
          apartado,
          isNotNull,
          reason: '«${f.norma}, art. ${f.articulo}» (${f.id}) no está en docs/MARCO_LEGAL.md',
        );
        final enlace = RegExp(r'^Fuente: \[[^\]]*\]\(([^)]+)\)', multiLine: true).firstMatch(apartado!.value)?.group(1);
        expect(f.url, enlace, reason: '${f.id}: el enlace tiene que ser el de su apartado');
      }
    }
  }, skip: marcoLegal == null ? 'No se encuentra docs/MARCO_LEGAL.md' : null);

  group('qué conversación contesta', () {
    final ejemplos = RespuestasDeEjemplo.desdeJson(ejemplosPreguntaJson());

    Future<AskResponse> preguntar(String pregunta) => ejemplos.ask(AskRequest(pregunta: pregunta));

    test('las frases del guion de la demo (plan v2, demo §2.3)', () async {
      expect(
        (await preguntar('Mis padres han ido a la Fiscalía porque me acosan en el instituto. ¿Qué va a pasar ahora?'))
            .fuentes
            .first
            .id,
        'ML-LO5-16.2',
      );
      final hechos = await preguntar('El que me insultaba era mi compañero de mesa.');
      expect(hechos.tipo, TipoRespuesta.hechos);
      expect(hechos.respuesta, MockTuTurnoApi.plantillaHechosAgente);
      final fotos = await preguntar('¿Qué puedo hacer si difunden fotos mías sin permiso?');
      expect(fotos.fuentes.map((f) => f.id), contains('ML-AEPD-CP'));
      expect(fotos.respuesta, contains('todos los días de 8:00 a 23:00'));
    });

    test('la pregunta de cada conversación la reconoce su conversación', () async {
      for (final c in conversaciones) {
        expect((await ejemplos.buscar(c.pregunta))?.id, c.id);
      }
      expect((await ejemplos.buscar('¿Qué hago si difunden fotos mías?'))?.id, 'sara-fotos');
    });

    test(
      'antes que el guion, la red de seguridad: peligro → crisis; quien cuenta que le hacen daño → hechos',
      () async {
        final crisis = await preguntar('Quiero morir, me insultaba un compañero y me acosan en el instituto');
        expect(crisis.tipo, TipoRespuesta.crisis);
        final revelacion = await preguntar('Mi padre me pega y difunde fotos mías');
        expect(revelacion.tipo, TipoRespuesta.hechos);
      },
    );

    test('la de Sara contesta como a una víctima: desde «Pregunta como investigado» no se usa', () async {
      final fotos = await preguntar('¿Qué puedo hacer si difunden fotos mías sin permiso?');
      expect(fotos.fuentes.map((f) => f.id), contains('ML-CP-189.1'));
      expect(fotos.respuesta, isNot(contains('tú misma')));
      for (final request in [
        const AskRequest(
          pregunta: '¿Qué puedo hacer si difunden fotos mías sin permiso?',
          situacion: RolProceso.investigado,
        ),
        const AskRequest(
          pregunta: '¿Qué puedo hacer si difunden fotos mías sin permiso?',
          perfil: {'edad': '15', 'procedimiento': 'penal', 'rol': 'investigado', 'fase': ''},
        ),
      ]) {
        // Contesta MockTuTurnoApi, no la conversación de Sara (que es la única con el art. 189.1).
        final r = await ejemplos.ask(request);
        expect(r.fuentes.map((f) => f.id), isNot(contains('ML-CP-189.1')), reason: '${request.situacion}');
        expect(await ejemplos.buscar(request.pregunta, investigado: true), isNull);
      }
      // La plantilla de «hechos» sí vale para todos.
      final hechos = await ejemplos.ask(
        const AskRequest(pregunta: 'El que me insultaba era mi compañero de mesa.', situacion: RolProceso.investigado),
      );
      expect(hechos.tipo, TipoRespuesta.hechos);
    });

    test('si no es del guion, contesta MockTuTurnoApi (por palabras clave o diciendo que no tiene conexión)', () async {
      expect((await preguntar('¿Qué es la Sala Gesell?')).respuesta, contains('Sala Gesell'));
      expect((await preguntar('xyz')).respuesta, MockTuTurnoApi.respuestaSinConexion);
    });

    test('sin el JSON (no está en el bundle) quedan las respuestas por palabras clave', () async {
      final sinJson = RespuestasDeEjemplo(bundle: _BundleVacio(), latencia: Duration.zero);
      expect(await sinJson.buscar('El que me insultaba era mi compañero de mesa.'), isNull);
      final r = await sinJson.ask(const AskRequest(pregunta: 'El que me insultaba era mi compañero de mesa.'));
      expect(r.tipo, TipoRespuesta.hechos);
    });
  });

  test('un JSON sin conversaciones o sin claves no se acepta', () {
    expect(() => leerEjemplosPregunta('{}'), throwsFormatException);
    expect(
      () => leerEjemplosPregunta(
        '{"conversaciones": [{"id": "x", "caso": "Sara", "origen": "marco_legal", "pregunta": "p", "claves": [], '
        '"respuesta": {"tipo": "normal", "respuesta": "r"}}]}',
      ),
      throwsFormatException,
    );
  });
}

class _BundleVacio extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw StateError('No está: $key');
}

/// Cada apartado («### …») de docs/MARCO_LEGAL.md con su texto.
Map<String, String> _apartados(String marco) {
  final apartados = <String, String>{};
  String? encabezado;
  final texto = StringBuffer();
  for (final linea in marco.split('\n')) {
    if (linea.startsWith('### ') || linea.startsWith('## ')) {
      if (encabezado != null) apartados[encabezado] = texto.toString();
      encabezado = linea.startsWith('### ') ? linea : null;
      texto.clear();
    } else {
      texto.writeln(linea);
    }
  }
  if (encabezado != null) apartados[encabezado] = texto.toString();
  return apartados;
}

/// docs/MARCO_LEGAL.md, o null si no está (por ejemplo, si solo se copia app/). Con `DOCS=<carpeta>`, esa copia.
String? _marcoLegal() {
  final carpeta = Platform.environment['DOCS'];
  final rutas = [if (carpeta != null) '$carpeta/MARCO_LEGAL.md', '../docs/MARCO_LEGAL.md', 'docs/MARCO_LEGAL.md'];
  return rutas.map(File.new).where((f) => f.existsSync()).firstOrNull?.readAsStringSync();
}
