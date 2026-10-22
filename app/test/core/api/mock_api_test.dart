import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/api/mock_api.dart';
import 'package:tuturno/core/api/tuturno_api.dart';
import 'package:tuturno/core/texto.dart';

import 'fixtures.dart';

void main() {
  final api = MockTuTurnoApi(latencia: Duration.zero);

  Future<AskResponse> preguntar(String pregunta) => api.ask(AskRequest(pregunta: pregunta));

  group('JSON exactos de la sección 8', () {
    test('los ejemplos del mock son exactamente los del documento', () {
      expect(MockTuTurnoApi.ejemploAsk, mapa(askRespuestaDoc));
      expect(MockTuTurnoApi.ejemploGrade, mapa(gradeRespuestaDoc));
      expect(MockTuTurnoApi.ejemploHealth, mapa(healthDoc));
    });

    test('pregunta de la demo → la respuesta de ejemplo de la sección 8.1', () async {
      final r = await preguntar('Si tengo 13 años y hago algo malo, ¿me pueden juzgar?');
      final doc = AskResponse.fromJson(mapa(askRespuestaDoc));

      expect(r.tipo, TipoRespuesta.normal);
      expect(r.respuesta, doc.respuesta);
      expect(r.fuentes.map((f) => [f.id, f.titulo, f.norma, f.articulo]), [
        ['A-017', 'Antes de los 14 años no hay responsabilidad penal', 'LO 5/2000', '3'],
      ]);
      expect(r.sugerencias, doc.sugerencias);
      expect(r.terminos, doc.terminos);
      expect(r.latenciaMs, 2140);
    });

    test('grade → la respuesta de la sección 8.2', () async {
      final r = await api.grade(const GradeRequest(conceptoId: 'C-ser-oido', texto: 'Que me escuchen'));

      expect(r.puntuacion, 0.67);
      expect(r.cubiertas, mapa(gradeRespuestaDoc)['cubiertas']);
      expect(r.faltan, ['Tu opinión se tiene en cuenta según tu edad y madurez']);
      expect(r.feedback, '¡Muy bien! Te falta una idea: tu opinión se tiene en cuenta según tu edad y madurez.');
    });

    test('health → la respuesta de la sección 8.3', () async {
      final r = await api.health();

      expect([r.estado, r.indiceA, r.indiceB, r.modeloLlm, r.demo], ['ok', 182, 940, 'claude-haiku-5-5', false]);
    });

    test('las plantillas son las de la sección 9.7', () {
      final doc = mapa(seguridadDoc);

      expect(
        MockTuTurnoApi.plantillas.keys,
        unorderedEquals([TipoRespuesta.crisis, TipoRespuesta.hechos, TipoRespuesta.fueraDeAmbito]),
      );
      MockTuTurnoApi.plantillas.forEach((tipo, texto) => expect(texto, doc[tipo.json], reason: tipo.json));
    });

    test('ninguna plantilla pregunta qué pasó (se habla del proceso, nunca de los hechos)', () {
      const preguntasProhibidas = ['¿que paso', '¿que te paso', '¿que ha pasado', '¿que te ha pasado', 'cuentame'];
      MockTuTurnoApi.plantillas.forEach((tipo, texto) {
        for (final prohibida in preguntasProhibidas) {
          expect(normalizar(texto), isNot(contains(prohibida)), reason: '${tipo.json}: $prohibida');
        }
      });
    });

    test('la plantilla de crisis da el teléfono de ANAR y el 112', () {
      final crisis = MockTuTurnoApi.plantillas[TipoRespuesta.crisis]!;

      expect(crisis, contains('900 20 20 10'));
      expect(crisis, contains('112'));
      expect(MockTuTurnoApi.plantillas[TipoRespuesta.hechos], contains('900 20 20 10'));
    });
  });

  group('tipos simulados (con tildes y mayúsculas)', () {
    Future<void> esperarTipo(List<String> preguntas, TipoRespuesta tipo) async {
      for (final pregunta in preguntas) {
        final r = await preguntar(pregunta);
        expect(r.tipo, tipo, reason: pregunta);
        expect(r.respuesta, MockTuTurnoApi.plantillas[tipo], reason: pregunta);
        expect(r.fuentes, isEmpty, reason: pregunta);
        expect(r.terminos, isEmpty, reason: pregunta);
        // Solo la plantilla de «hechos» propone seguir hablando del proceso (sección 10.1, paso 6).
        expect(
          r.sugerencias,
          tipo == TipoRespuesta.hechos ? MockTuTurnoApi.sugerenciasHechos : isEmpty,
          reason: pregunta,
        );
      }
    }

    test('crisis: las expresiones de la sección 10.2', () async {
      await esperarTipo([
        'Quiero MORIR',
        'a veces pienso en hacerme daño',
        'HACERME DAÑO',
        'No quiero vivir así',
        'Tengo miedo de volver a casa.',
        '¿Y si tengo miedo de volver a casa?',
      ], TipoRespuesta.crisis);
    });

    test('hechos: cuando alguien cuenta lo que le ha pasado', () async {
      await esperarTipo([
        'Me pegaron en el recreo',
        'ME HAN PEGADO',
        'Te cuento lo que me pasó ayer',
        'Esto es lo que me ha pasado',
      ], TipoRespuesta.hechos);
    });

    test('fuera de ámbito', () async {
      await esperarTipo([
        '¿Quién ganó el partido de FÚTBOL?',
        'Recomiéndame un videojuego',
        'Dame una receta de tortilla',
      ], TipoRespuesta.fueraDeAmbito);
    });

    test('crisis gana a hechos: ante la duda, se ofrece la ayuda', () async {
      expect((await preguntar('Me pegaron y no quiero vivir')).tipo, TipoRespuesta.crisis);
      expect((await preguntar('Me han pegado jugando al fútbol')).tipo, TipoRespuesta.hechos);
    });

    test('las preguntas de los casos oficiales son normales (hablan del proceso)', () async {
      const preguntas = [
        // Lucía, 11 años, prueba preconstituida en la Sala Gesell.
        '¿Por qué quieren hablar conmigo personas que no conozco?',
        '¿Qué pasa después de la Sala Gesell?',
        '¿Voy a dejar de vivir con mi madre?',
        // Sergio, 13 años, acoso escolar, Fiscalía de Menores.
        '¿Me voy a encontrar con los que me acosan?',
        '¿Qué hace la Fiscalía de Menores?',
        // Sara, casi 16 años, imágenes íntimas difundidas.
        'Están pasando fotos mías, ¿es delito si soy menor?',
        '¿Hay algún sitio confidencial donde pedir ayuda?',
      ];
      for (final pregunta in preguntas) {
        expect((await preguntar(pregunta)).tipo, TipoRespuesta.normal, reason: pregunta);
      }
    });
  });

  group('sugerencias de la plantilla de «hechos» (sección 10.1, paso 6)', () {
    test('son «¿Qué pasa si se denuncia?» y «¿A quién puedo pedir ayuda?»', () async {
      expect(MockTuTurnoApi.sugerenciasHechos, ['¿Qué pasa si se denuncia?', '¿A quién puedo pedir ayuda?']);

      final r = await preguntar('Me pegaron en el recreo');
      expect(r.tipo, TipoRespuesta.hechos);
      expect(r.sugerencias, MockTuTurnoApi.sugerenciasHechos);
      expect(r.latenciaMs, 5);
    });

    test('crisis y fuera de ámbito siguen sin sugerencias', () async {
      expect((await preguntar('No quiero vivir')).sugerencias, isEmpty);
      expect((await preguntar('Dame una receta de tortilla')).sugerencias, isEmpty);
    });

    test('hablan del proceso: no preguntan qué pasó', () {
      const prohibidas = ['¿que paso', '¿que te paso', '¿que ha pasado', '¿que te ha pasado', 'cuentame'];
      for (final sugerencia in MockTuTurnoApi.sugerenciasHechos) {
        for (final prohibida in prohibidas) {
          expect(normalizar(sugerencia), isNot(contains(prohibida)), reason: sugerencia);
        }
      }
    });

    test('al tocarlas se responde con normalidad (no vuelve a salir la plantilla)', () async {
      for (final sugerencia in MockTuTurnoApi.sugerenciasHechos) {
        final r = await preguntar(sugerencia);
        expect(r.tipo, TipoRespuesta.normal, reason: sugerencia);
        expect(r.fuentes, isNotEmpty, reason: sugerencia);
      }
    });

    // Si el documento ya tiene el paso 6 (versión 1.1), las sugerencias tienen que ser las suyas.
    // `DOCS=<carpeta>` permite comprobarlo con otra copia de docs/.
    final paso6 = _paso6DelDocumento();
    test(
      'son las del documento',
      () => expect(MockTuTurnoApi.sugerenciasHechos, paso6),
      skip: paso6 == null ? 'docs/ARQUITECTURA.md no tiene aún el paso 6 de la sección 10.1' : null,
    );
  });

  test('espera la latencia configurada antes de responder', () async {
    final lento = MockTuTurnoApi(latencia: const Duration(milliseconds: 60));
    final reloj = Stopwatch()..start();

    await lento.ask(const AskRequest(pregunta: 'Hola'));

    expect(reloj.elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 50)));
  });

  test('MockTuTurnoApi cumple la interfaz', () {
    expect(MockTuTurnoApi(), isA<TuTurnoApi>());
  });
}

/// Las preguntas «¿…?» del paso 6 de la sección 10.1 de docs/ARQUITECTURA.md, o null si el documento no está o
/// todavía no las tiene. Los tests se ejecutan desde app/; con `DOCS=<carpeta>` se usa esa copia de docs/.
List<String>? _paso6DelDocumento() {
  final carpeta = Platform.environment['DOCS'];
  final rutas = [if (carpeta != null) '$carpeta/ARQUITECTURA.md', '../docs/ARQUITECTURA.md', 'docs/ARQUITECTURA.md'];
  final fichero = rutas.map(File.new).where((f) => f.existsSync()).firstOrNull;
  if (fichero == null) return null;
  final lineas = fichero.readAsLinesSync();
  final inicio = lineas.indexWhere((l) => l.startsWith('### 10.1 '));
  if (inicio == -1) return null;
  final paso = lineas
      .skip(inicio + 1)
      .takeWhile((l) => !l.startsWith('#'))
      .where((l) => l.startsWith('6. '))
      .firstOrNull;
  final preguntas = [for (final m in RegExp('«(¿[^»]+\\?)»').allMatches(paso ?? '')) m.group(1)!];
  return preguntas.isEmpty ? null : preguntas;
}
