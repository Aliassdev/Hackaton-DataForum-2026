import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/api/mock_api.dart';
import 'package:tuturno/core/api/tuturno_api.dart';
import 'package:tuturno/core/texto.dart';
import 'package:tuturno/features/pregunta/textos.dart' show ejemplos, ejemplosPorRol, sugerenciasPorTipo;

import 'fixtures.dart';

void main() {
  final api = MockTuTurnoApi(latencia: Duration.zero);

  Future<AskResponse> preguntar(String pregunta, {RolProceso? situacion}) => api.ask(
    AskRequest(
      pregunta: pregunta,
      modo: situacion == null ? ModoPregunta.libre : ModoPregunta.situacion,
      situacion: situacion,
    ),
  );

  group('JSON exactos de la sección 8', () {
    test('los ejemplos del mock son exactamente los del documento', () {
      expect(MockTuTurnoApi.ejemploAsk, mapa(askRespuestaDoc));
      expect(MockTuTurnoApi.ejemploGrade, mapa(gradeRespuestaDoc));
      expect(MockTuTurnoApi.ejemploHealth, mapa(healthDoc));
    });

    test('pregunta de la demo → la respuesta de la sección 8.1, completa (sin los «...» del documento)', () async {
      final r = await preguntar('Si tengo 13 años y hago algo malo, ¿me pueden juzgar?');
      final doc = AskResponse.fromJson(mapa(askRespuestaDoc));

      expect(r.tipo, TipoRespuesta.normal);
      expect(doc.respuesta, endsWith('[A-017]...'));
      expect(r.respuesta, startsWith('${doc.respuesta.substring(0, doc.respuesta.length - 3)}.'));
      expect(r.respuesta, isNot(endsWith('...')));
      expect(r.fuentes.map((f) => [f.id, f.titulo, f.norma, f.articulo]), [
        ['A-017', 'Antes de los 14 años no hay responsabilidad penal', 'LO 5/2000', '3'],
      ]);
      expect(r.sugerencias, doc.sugerencias);
      expect(r.terminos, doc.terminos);
      expect(r.latenciaMs, 2140);
      // Y lo que pasa en su lugar, del mismo artículo: que nadie de 13 años entienda que «no pasa nada».
      expect(r.respuesta, contains('En su lugar actúan las normas y los servicios de protección de menores'));
      // Dicha en voz (o más corta), sigue siendo la de la demo.
      expect((await preguntar('¿Me pueden juzgar?')).respuesta, startsWith('Antes de los 14 años'));
      expect((await preguntar('si tengo 13 años me pueden juzgar')).fuentes.single.id, 'A-017');
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
      final textos = {...MockTuTurnoApi.plantillas.values, MockTuTurnoApi.plantillaHechosAgente};
      for (final texto in textos) {
        for (final prohibida in preguntasProhibidas) {
          expect(normalizar(texto), isNot(contains(prohibida)), reason: '$texto: $prohibida');
        }
      }
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
      expect((await preguntar('El que me insultaba me dijo que no quiero vivir')).tipo, TipoRespuesta.crisis);
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
        final r = await preguntar(pregunta);
        expect(r.tipo, TipoRespuesta.normal, reason: pregunta);
        expect(r.respuesta, isNot(MockTuTurnoApi.respuestaSinConexion), reason: pregunta);
        expect(r.fuentes, isNotEmpty, reason: pregunta);
      }
    });
  });

  group('red de seguridad antes que las palabras clave (sección 10.2: ante la duda, ofrecer ayuda)', () {
    test(
      'las señales de peligro dan la plantilla de crisis, aunque nombren a la familia, las fotos o «borrar»',
      () async {
        for (final pregunta in [
          'Estoy en peligro, mi padre está borracho',
          'Me quiero suicidar, mi madre no me entiende',
          'Mi padre me va a matar',
          'Tengo miedo de mi padre',
          'Quiero morir, han difundido una foto mía',
        ]) {
          final r = await preguntar(pregunta);
          expect(r.tipo, TipoRespuesta.crisis, reason: pregunta);
          expect(r.respuesta, MockTuTurnoApi.plantillas[TipoRespuesta.crisis], reason: pregunta);
          expect(r.fuentes, isEmpty, reason: pregunta);
        }
      },
    );

    test(
      'quien cuenta que le hacen daño recibe la plantilla de «hechos» con ANAR, no la respuesta de un tema',
      () async {
        for (final pregunta in [
          'Mi padre me pega',
          'Mi padre me pegó ayer',
          'Mi padre pega a mi madre',
          'Mi madre me ha echado de casa',
          'Mi tío me hizo algo malo',
          'Un chico de clase me toca y no quiero',
          'Me amenazan por Instagram',
          'Un monitor abusaba de mí',
        ]) {
          final r = await preguntar(pregunta);
          expect(r.tipo, TipoRespuesta.hechos, reason: pregunta);
          expect(r.respuesta, MockTuTurnoApi.plantillaHechosAgente, reason: pregunta);
          expect(r.respuesta, contains('900 20 20 10'), reason: pregunta);
          expect(r.fuentes, isEmpty, reason: pregunta);
          expect(r.sugerencias, MockTuTurnoApi.sugerenciasHechos, reason: pregunta);
        }
      },
    );

    test('«me toca declarar» o «me toca ir» es una pregunta del proceso, no lo que le pasa a alguien', () async {
      for (final pregunta in ['¿Qué derechos tengo si me toca declarar?', '¿Me toca ir al juicio?']) {
        final r = await preguntar(pregunta);
        expect(r.tipo, TipoRespuesta.normal, reason: pregunta);
        expect(r.fuentes, isNotEmpty, reason: pregunta);
      }
    });

    test('nombrar a la madre o al padre no basta para «seguir con tu familia»; «borracho» no es «borrar»', () async {
      final familia = await preguntar('¿Voy a dejar de vivir con mi madre?');
      expect(familia.fuentes.map((f) => f.id), contains('ML-LO1-1996-17.1'));
      for (final pregunta in ['Mi madre trabaja en un juzgado', 'Mi padre está borracho']) {
        final r = await preguntar(pregunta);
        expect(r.fuentes.map((f) => f.id), isNot(contains('ML-LO1-1996-17.1')), reason: pregunta);
        expect(r.fuentes.map((f) => f.id), isNot(contains('ML-LOPDGDD-94.3')), reason: pregunta);
      }
      expect((await preguntar('¿Pueden borrar mis fotos?')).fuentes.map((f) => f.id), contains('ML-LOPDGDD-94.3'));
    });

    test(
      '«¿Me van a castigar por haber mandado la foto?»: la de las fotos (no es tu culpa), no la de las medidas',
      () async {
        final r = await preguntar('¿Me van a castigar por haber mandado la foto?');
        expect(r.fuentes.map((f) => f.id), contains('ML-CP-197.7'));
        expect(r.respuesta, isNot(contains('internamiento')));
        expect(r.respuesta, contains('lo hubieras enviado tú'));
      },
    );

    test(
      '«sin que se entere», «secreto», «confidencial»: dónde hablar con confianza, sin prometer un secreto',
      () async {
        for (final pregunta in [
          '¿Puedo contarlo sin que se entere mi madre?',
          '¿Lo que cuento es secreto?',
          '¿Hay algún sitio confidencial donde pedir ayuda?',
          '¿Mis padres se van a enterar si denuncio el acoso?',
        ]) {
          final r = await preguntar(pregunta);
          expect(r.tipo, TipoRespuesta.normal, reason: pregunta);
          expect(r.fuentes.map((f) => f.id), containsAll(['ML-L4-4', 'ML-INCIBE-017']), reason: pregunta);
          expect(r.respuesta, contains('nadie puede prometerte'), reason: pregunta);
          expect(r.respuesta, contains('900 20 20 10'), reason: pregunta);
          expect(normalizar(r.respuesta), isNot(contains('canales seguros y confidenciales')), reason: pregunta);
        }
      },
    );
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

  group('sin backend, cada pregunta de Pregunta tiene su respuesta (auditoría P0-1)', () {
    Fuente? fuente(AskResponse r, String norma, String articulo) =>
        r.fuentes.where((f) => f.norma == norma && f.articulo == articulo).firstOrNull;

    test(
      'las preguntas de la vista inicial y las de cada papel: respuesta propia, con fuentes y sugerencias',
      () async {
        final preguntas = <(String, RolProceso?)>[
          for (final e in ejemplos) (e.texto, null),
          for (final MapEntry(key: rol, value: lista) in ejemplosPorRol.entries)
            for (final e in lista) (e.texto, rol),
        ];
        expect(preguntas, hasLength(greaterThanOrEqualTo(15)));
        for (final (pregunta, rol) in preguntas) {
          final r = await preguntar(pregunta, situacion: rol);
          expect(r.tipo, TipoRespuesta.normal, reason: pregunta);
          expect(r.respuesta, isNot(MockTuTurnoApi.respuestaSinConexion), reason: pregunta);
          expect(r.respuesta, isNot(endsWith('...')), reason: pregunta);
          expect(r.fuentes, isNotEmpty, reason: pregunta);
          expect(r.sugerencias, isNotEmpty, reason: pregunta);
        }
      },
    );

    test('la Sala Gesell, la Fiscalía de Menores y las fotos responden lo suyo, con su fuente', () async {
      final gesell = await preguntar('¿Qué es la Sala Gesell?');
      expect(
        gesell.respuesta,
        allOf(contains('Sala Gesell'), contains('prueba preconstituida'), contains('cara a cara')),
      );
      expect(fuente(gesell, 'LECrim', '449 ter, párr. 1'), isNotNull);
      expect(fuente(gesell, 'LECrim', '449 ter, párr. 3'), isNotNull);

      final fiscalia = await preguntar('¿Qué hace la Fiscalía de Menores?');
      expect(
        fiscalia.respuesta,
        contains('defiende los derechos de los menores, vigila que el proceso sea justo y dirige la investigación'),
      );
      expect(fuente(fiscalia, 'LO 5/2000', '6'), isNotNull);

      final fotos = await preguntar('¿Qué hago si difunden fotos mías?');
      expect(
        fotos.respuesta,
        allOf(
          contains('Canal prioritario'),
          contains('WhatsApp'),
          contains('017'),
          contains('8:00 a 23:00'),
          contains('900 20 20 10'),
        ),
      );
      expect(fuente(fotos, 'AEPD · Canal prioritario', ''), isNotNull);
      expect(fuente(fotos, 'INCIBE · 017', ''), isNotNull);
      expect(fuente(fotos, 'LO 8/2021', '50.2.e) y 50.2.h)'), isNotNull);
      // La culpa no es de quien sale en ellas, y la edad del Canal prioritario (ARQUITECTURA, sección 2.3).
      expect(fuente(fotos, 'Código Penal', '197.7'), isNotNull);
      expect(fotos.respuesta, allOf(contains('nadie puede pasarlo a otros sin tu permiso'), contains('con menos')));
      final borrar = await preguntar('¿Puedo pedir que borren mis fotos?');
      expect(borrar.respuesta, contains('Desde los 14 años puedes hacerlo tú; con menos, que te ayude un adulto'));
      // Las preguntas del guion de la demo (sección 2.3) también.
      expect((await preguntar('¿Qué puedo hacer si difunden fotos mías sin permiso?')).respuesta, fotos.respuesta);
      final verlos = await preguntar('¿Tendré que verlos cuando declare?');
      expect(verlos.respuesta, contains('videoconferencia'));
      expect(fuente(verlos, 'Ley 4/2015', '20'), isNotNull);
    });

    test(
      'Sergio, «Mis padres han ido a la Fiscalía…»: normal, con la Fiscalía de Menores, la protección y ANAR',
      () async {
        final r = await preguntar(
          'Mis padres han ido a la Fiscalía porque me acosan en el instituto. ¿Qué va a pasar ahora?',
        );

        expect(r.tipo, TipoRespuesta.normal);
        expect(r.respuesta, allOf(contains('Fiscalía de Menores'), contains('protegerte'), contains('900 20 20 10')));
        for (final (norma, articulo) in [('LO 5/2000', '16.2'), ('LO 5/2000', '6'), ('LO 5/2000', '28.1')]) {
          expect(fuente(r, norma, articulo), isNotNull, reason: '$norma, art. $articulo');
        }
        expect(fuente(r, 'LO 8/2021', '34.1'), isNotNull, reason: 'el protocolo contra el acoso');
        expect(r.respuesta, isNot(contains('¿')), reason: 'no pregunta nada (y menos qué pasó)');
      },
    );

    test('Sergio, «El que me insultaba era mi compañero de mesa.»: hechos, con la plantilla del agente', () async {
      final r = await preguntar('El que me insultaba era mi compañero de mesa.');

      expect(r.tipo, TipoRespuesta.hechos);
      expect(r.respuesta, MockTuTurnoApi.plantillaHechosAgente);
      expect(r.fuentes, isEmpty);
      expect(r.terminos, isEmpty);
      expect(r.sugerencias, MockTuTurnoApi.sugerenciasHechos);
      // Es la de content/seguridad.json de Iker (hechos[1]), con el teléfono de ANAR en cifras.
      expect(r.respuesta, contains('900 20 20 10'));
      expect(r.respuesta, isNot(contains('novecientos')));
      expect(r.respuesta.replaceFirst('900 20 20 10', 'novecientos, veinte, veinte, diez'), _hechosDeIker);
    });

    test('si no la reconoce, lo dice: sin fuentes y con las tres primeras preguntas de la vista inicial', () async {
      expect(MockTuTurnoApi.sugerenciasIniciales, [for (final e in ejemplos.take(3)) e.texto]);
      for (final pregunta in ['Hola', '¿Qué es una citación?', 'Otra pregunta']) {
        final r = await preguntar(pregunta);
        expect(r.tipo, TipoRespuesta.normal, reason: pregunta);
        expect(
          r.respuesta,
          'Ahora mismo no tengo conexión para responder bien a eso. Prueba con una de las preguntas de abajo o pulsa '
          'Ayuda.',
          reason: pregunta,
        );
        expect(r.fuentes, isEmpty, reason: pregunta);
        expect(r.terminos, isEmpty, reason: pregunta);
        expect(r.sugerencias, MockTuTurnoApi.sugerenciasIniciales, reason: pregunta);
      }
    });

    test('el abogado: si te investigan, como víctima o, sin papel, las dos cosas', () async {
      const pregunta = '¿Puedo tener abogado o abogada?';
      final investigado = await preguntar(pregunta, situacion: RolProceso.investigado);
      final victima = await preguntar(pregunta, situacion: RolProceso.victima);
      final libre = await preguntar(pregunta);

      expect(fuente(investigado, 'LO 5/2000', '22.1'), isNotNull);
      expect(fuente(investigado, 'LO 8/2021', '14.1 y 14.3'), isNull);
      expect(fuente(victima, 'LO 8/2021', '14.1 y 14.3'), isNotNull);
      expect(fuente(victima, 'LO 5/2000', '22.1'), isNull);
      expect(fuente(libre, 'LO 5/2000', '22.1'), isNotNull);
      expect(fuente(libre, 'LO 8/2021', '14.1 y 14.3'), isNotNull);
      for (final r in [investigado, victima, libre]) {
        expect(normalizar(r.respuesta), isNot(contains('siempre gratis')));
      }
    });

    test('cada sugerencia lleva a otra respuesta con fuentes (nunca a la de «sin conexión»)', () {
      final sugerencias = {
        for (final r in MockTuTurnoApi.respuestasPorClavesConocidas) ...r.sugerencias,
        ...MockTuTurnoApi.sugerenciasHechos,
        ...MockTuTurnoApi.sugerenciasIniciales,
        ...?sugerenciasPorTipo[TipoRespuesta.fueraDeAmbito],
      };
      for (final sugerencia in sugerencias) {
        final r = MockTuTurnoApi.respuestaPorClaves(sugerencia);
        expect(r, isNotNull, reason: sugerencia);
        expect(r!.fuentes, isNotEmpty, reason: sugerencia);
      }
    });

    test('las referencias del texto ([ML-…]) son sus fuentes, y cada fuente sale en el texto', () {
      final referencia = RegExp(r'\[([A-Za-z]{1,4}-[\w.-]+)\]');
      for (final r in MockTuTurnoApi.respuestasPorClavesConocidas) {
        final ids = {for (final m in referencia.allMatches(r.respuesta)) m.group(1)!};
        expect(ids, {for (final f in r.fuentes) f.id}, reason: r.respuesta);
        expect({for (final f in r.fuentes) f.id}, hasLength(r.fuentes.length), reason: 'fuentes repetidas');
      }
    });

    test('textos para alguien de 11 a 17 años: completos, cortos y sin promesas ni preguntas sobre los hechos', () {
      const prohibidas = [
        'carcel',
        'prision',
        '24 horas',
        '¿que paso',
        '¿que te paso',
        '¿que ha pasado',
        'cuentame',
        'siempre gratis',
        'te prometo',
        'seguro que',
        'reenviar tambien es delito',
      ];
      final textos = [
        for (final r in MockTuTurnoApi.respuestasPorClavesConocidas) r.respuesta,
        MockTuTurnoApi.respuestaSinConexion,
        MockTuTurnoApi.plantillaHechosAgente,
      ];
      for (final texto in textos) {
        expect(texto, isNot(endsWith('...')), reason: texto);
        final normal = normalizar(texto);
        for (final prohibida in prohibidas) {
          expect(normal, isNot(contains(prohibida)), reason: '$prohibida: $texto');
        }
        final palabras = texto.replaceAll(RegExp(r'\[[^\]]+\]'), '').split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
        expect(palabras.length, lessThanOrEqualTo(120), reason: 'sección 10.1, paso 7: $texto');
      }
    });

    test('los términos están en el glosario de ejemplo y salen en el texto (así se subrayan)', () {
      final glosario = jsonDecode(File('assets/mock/content/glosario.json').readAsStringSync()) as List<Object?>;
      final terminos = {for (final e in glosario) normalizar((e! as Map)['termino'] as String)};
      // La de la demo lleva los términos de la sección 8.1 tal cual, aunque no salgan todos en el texto.
      final demo = MockTuTurnoApi.respuestaPorClaves('Si tengo 13 años y hago algo malo, ¿me pueden juzgar?');
      for (final r in MockTuTurnoApi.respuestasPorClavesConocidas) {
        final texto = ' ${normalizar(r.respuesta).replaceAll(RegExp('[^a-z0-9]+'), ' ')} ';
        for (final termino in r.terminos) {
          expect(terminos, contains(normalizar(termino)), reason: termino);
          if (identical(r, demo)) continue;
          expect(texto, contains(' ${normalizar(termino)} '), reason: '$termino: ${r.respuesta}');
        }
      }
    });

    final marcoLegal = _marcoLegal();
    test('cada fuente es un apartado de docs/MARCO_LEGAL.md', () {
      final encabezados = marcoLegal!.split('\n').where((l) => l.startsWith('### ')).toList();
      // Cómo se llama cada norma en los encabezados del marco, si no es igual.
      const enElMarco = {
        'LO 8/2021': 'LOPIVI (LO 8/2021)',
        'CE': 'CE (Constitución Española)',
        'LEC': 'LEC (Ley 1/2000)',
        'Ley 1/1996': 'Ley 1/1996 de asistencia jurídica gratuita',
        'AEPD · FAQ 15.03': 'AEPD · Preguntas frecuentes, art. FAQ 15.03',
      };
      final numero = RegExp(r'^\d+(\.\d+)*( (bis|ter))?');
      final fuentes = {
        for (final r in MockTuTurnoApi.respuestasPorClavesConocidas)
          for (final f in r.fuentes) f.id: f,
      };
      for (final f in fuentes.values) {
        final norma = enElMarco[f.norma] ?? f.norma;
        final articulos = [
          for (final parte in f.articulo.split(RegExp(r', | y ')))
            if (numero.firstMatch(parte.trim()) case final m?) m.group(0)!,
        ];
        // Los artículos se buscan en lo que sigue a la norma (para no confundir «LO 5/2000, art. 5» con el «5» de 5/2000).
        final esta = encabezados.any(
          (e) =>
              (e.startsWith('### $norma,') || e.startsWith('### $norma ')) &&
              articulos.every(
                (a) => RegExp('(?<![\\d.])${RegExp.escape(a)}(?!\\d)').hasMatch(e.substring('### $norma'.length)),
              ),
        );
        expect(esta, isTrue, reason: '«${f.norma}, art. ${f.articulo}» (${f.id}) no está en docs/MARCO_LEGAL.md');
      }
    }, skip: marcoLegal == null ? 'No se encuentra docs/MARCO_LEGAL.md' : null);
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

/// content/seguridad.json de Iker (rama feat/api-base), `hechos[1]`, tal cual (para la voz, con el número en letras).
const _hechosDeIker =
    'Te agradezco que me lo cuentes. De lo que pasó es mejor que hables con los profesionales de tu caso; yo no te voy a '
    'preguntar por ello. Lo que sí puedo hacer es explicarte qué va a pasar en el proceso. Y si te sientes mal, en ANAR '
    'te escuchan: novecientos, veinte, veinte, diez. ¿Qué quieres saber del proceso?';

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

/// docs/MARCO_LEGAL.md, o null si no está (por ejemplo, si solo se copia app/). Con `DOCS=<carpeta>`, esa copia.
String? _marcoLegal() {
  final carpeta = Platform.environment['DOCS'];
  final rutas = [if (carpeta != null) '$carpeta/MARCO_LEGAL.md', '../docs/MARCO_LEGAL.md', 'docs/MARCO_LEGAL.md'];
  return rutas.map(File.new).where((f) => f.existsSync()).firstOrNull?.readAsStringSync();
}
