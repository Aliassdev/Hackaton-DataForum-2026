import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/api/models.dart';
import 'package:tuturno/core/entrada.dart';
import 'package:tuturno/features/pasos/personalizacion_linea.dart';
import 'package:tuturno/features/situacion/contenido.dart';
import 'package:tuturno/features/situacion/mi_ticket.dart';
import 'package:tuturno/features/situacion/papel.dart';
import 'package:tuturno/features/situacion/personalizacion.dart';

// La personalización de Mi situación, con el contenido de verdad (assets/mock/content/situacion/): de tu ticket a tu
// saludo, tus notas «Para ti», los pasos de tu caso, tus derechos y las respuestas a lo que te preocupa.

Object? _json(String fichero) => jsonDecode(File('assets/mock/content/situacion/$fichero.json').readAsStringSync());

final _contenido = ContenidoSituacion.desdeJson(
  derechos: _json('derechos'),
  preocupaciones: _json('preocupaciones'),
  pasos: _json('pasos'),
  notas: _json('notas'),
);

final _hoy = DateTime(2026, 10, 22, 10);

PerfilSituacion _perfil(
  PapelSituacion papel, {
  int? edad,
  Procedimiento? procedimiento,
  RolEntrada? rol,
  Fase? fase,
  MiTicket ticket = const MiTicket(),
}) => PerfilSituacion(
  papel: papel,
  hoy: _hoy,
  entrada: Entrada(edad: edad, procedimiento: procedimiento, rol: rol ?? papel.rolEntrada, fase: fase),
  ticket: ticket,
);

final _lucia = _perfil(
  PapelSituacion.victima,
  edad: 11,
  procedimiento: Procedimiento.penal,
  fase: Fase.durante,
  ticket: MiTicket(
    conQuien: const {Acompanante.confianza},
    preocupaciones: const {Preocupacion.verPersona, Preocupacion.noEntender},
    estilo: EstiloExplicacion.ejemplos,
    fecha: DateTime(2026, 10, 24),
  ),
);

final _sergio = _perfil(
  PapelSituacion.victima,
  edad: 13,
  procedimiento: Procedimiento.penal,
  fase: Fase.antes,
  ticket: MiTicket(
    conQuien: const {Acompanante.familia},
    preocupaciones: const {Preocupacion.colegio, Preocupacion.preguntas},
    estilo: EstiloExplicacion.pasoAPaso,
    fecha: DateTime(2026, 10, 22),
  ),
);

final _sara = _perfil(
  PapelSituacion.victima,
  edad: 15,
  procedimiento: Procedimiento.penal,
  fase: Fase.despues,
  ticket: const MiTicket(
    conQuien: {Acompanante.familia, Acompanante.abogado},
    preocupaciones: {Preocupacion.redes, Preocupacion.colegio},
    estilo: EstiloExplicacion.corto,
  ),
);

void main() {
  group('papeles y rutas', () {
    test('cada papel del ticket lleva a su camino; «No lo sé» o sin papel, al selector', () {
      expect(rutaSituacionDe(const Entrada(rol: RolEntrada.victima)), '/situacion/victima');
      expect(rutaSituacionDe(const Entrada(rol: RolEntrada.testigo)), '/situacion/testigo');
      expect(rutaSituacionDe(const Entrada(rol: RolEntrada.investigado)), '/situacion/investigado');
      expect(rutaSituacionDe(const Entrada(rol: RolEntrada.escuchadoFamilia)), '/situacion/escuchado_familia');
      expect(rutaSituacionDe(const Entrada(rol: RolEntrada.noLoSe)), isNull);
      expect(rutaSituacionDe(const Entrada()), isNull);
      expect(tituloCaminoDe(const Entrada(rol: RolEntrada.victima)), 'Tu camino como víctima');
    });

    test('«Me van a escuchar» no es un papel de la API: desde él, Pregunta va sin situación', () {
      expect(PapelSituacion.escuchadoFamilia.rolProceso, isNull);
      expect(PapelSituacion.escuchadoFamilia.textoPregunta, 'Pregúntale a TuTurno');
      expect(PapelSituacion.victima.textoPregunta, 'Pregunta como víctima');
      expect(RolProceso.values, hasLength(3), reason: 'el contrato de la sección 8 sigue con tres papeles');
      for (final rol in RolProceso.values) {
        expect(PapelSituacion.deRolProceso(rol).rolProceso, rol);
      }
    });

    test('el papel de la ruta se lee sin que importen mayúsculas ni tildes; lo demás no es un papel', () {
      expect(PapelSituacion.deId('victima'), PapelSituacion.victima);
      expect(PapelSituacion.deId('Víctima'), PapelSituacion.victima);
      expect(PapelSituacion.deId('escuchado_familia'), PapelSituacion.escuchadoFamilia);
      expect(PapelSituacion.deId('elegir'), isNull);
      expect(PapelSituacion.deId(null), isNull);
    });

    test('la carátula nunca dice «expediente» (LO 5/2000, art. 16): dice tu papel o que te van a escuchar', () {
      for (final papel in PapelSituacion.values) {
        expect(papel.papelCaratula.toLowerCase(), isNot(contains('expediente')));
        expect(papel.tituloCamino.toLowerCase(), isNot(contains('expediente')));
      }
    });
  });

  group('contenido', () {
    test('se lee entero: nada se queda fuera por no estar validado o no tener fuente', () {
      final derechos = (_json('derechos')! as Map)['derechos'] as List;
      final notas = (_json('notas')! as Map)['notas'] as List;
      expect(_contenido.derechos, hasLength(derechos.length));
      expect(_contenido.notas, hasLength(notas.length));
      expect(_contenido.preocupaciones.keys, unorderedEquals(Preocupacion.values));
      for (final papel in PapelSituacion.values) {
        expect(_contenido.pasos[papel.id], isNotNull, reason: papel.id);
      }
      expect(_contenido.llevar, isNotEmpty);
    });

    test('sin validar o sin fuente no se enseña (salvo los consejos, que no son afirmaciones jurídicas)', () {
      final contenido = ContenidoSituacion.desdeJson(
        derechos: {
          'validado': true,
          'derechos': [
            {
              'id': 'a',
              'titulo': 'Con fuente',
              'texto': 'x',
              'fuentes': ['LO 1/1996, art. 9.1'],
              'validado': true,
            },
            {'id': 'b', 'titulo': 'Sin fuente', 'texto': 'x', 'fuentes': <String>[], 'validado': true},
            {
              'id': 'c',
              'titulo': 'Sin validar',
              'texto': 'x',
              'fuentes': ['LO 1/1996, art. 9.1'],
            },
          ],
        },
        preocupaciones: {
          'validado': true,
          'preocupaciones': [
            {
              'id': 'redes',
              'puntos': [
                {'texto': 'Consejo', 'consejo': true, 'validado': true},
                {'texto': 'Sin fuente', 'validado': true},
              ],
            },
          ],
        },
      );
      expect([for (final d in contenido.derechos) d.id], ['a']);
      expect([for (final p in contenido.preocupaciones[Preocupacion.redes]!.puntos) p.texto], ['Consejo']);
      // En modo DEMO con borradores, sí.
      final demo = ContenidoSituacion.desdeJson(
        derechos: {
          'validado': false,
          'derechos': [
            {'id': 'c', 'titulo': 'Sin validar', 'texto': 'x'},
          ],
        },
        mostrarBorradores: true,
      );
      expect(demo.derechos, hasLength(1));
    });

    test('un fichero roto o que falta deja esa parte vacía (nunca falla)', () {
      final contenido = ContenidoSituacion.desdeJson(derechos: 'roto', preocupaciones: 3, pasos: null, notas: []);
      expect(contenido.vacio, isTrue);
    });
  });

  group('notas «Para ti»', () {
    test('Lucía (11, víctima): por su edad, la prueba preconstituida, con su edad puesta y su fuente', () {
      final notas = notasPara(_contenido, _lucia);
      expect(notas.first.titulo, 'Por tu edad');
      expect(notas.first.nota.texto, startsWith('Con 11 años'));
      expect(notas.first.nota.texto, contains('prueba preconstituida'));
      expect(notas.first.nota.fuentes, contains('LECrim, art. 449 ter'));
    });

    test('Sara (15, víctima, le preocupan las redes): puede pedir ella misma a la AEPD que quite imágenes sexuales o '
        'violentas de internet', () {
      final nota = notasPara(_contenido, _sara).first;
      expect(nota.nota.texto, startsWith('Con 15 años'));
      // El Canal prioritario es para contenido sexual o violento publicado en internet (AEPD), no para cualquier foto.
      expect(nota.nota.texto, contains('sexuales o violentos'));
      expect(nota.nota.texto, contains('en internet'));
      expect(nota.nota.fuentes, ['AEPD, Canal prioritario']);
      // Sin que le preocupen las redes, esa nota no sale.
      final sinRedes = _perfil(PapelSituacion.victima, edad: 15);
      expect(notasPara(_contenido, sinRedes).map((n) => n.nota.texto), isNot(contains(contains('Agencia'))));
    });

    test('Lucía (11): la prueba preconstituida no promete que solo te escuchen una vez (LECrim, art. 703 bis)', () {
      final nota = notasPara(_contenido, _lucia).first;
      expect(nota.nota.texto, isNot(contains('una vez')));
      expect(nota.nota.texto, contains('normalmente no tienes que ir al juicio'));
      expect(nota.nota.fuentes, containsAll(['LECrim, art. 449 ter', 'LECrim, art. 703 bis']));
    });

    test('investigado de 13: la ley penal de menores no se le aplica (LO 5/2000, art. 3); de 15, sí', () {
      final de13 = notasPara(_contenido, _perfil(PapelSituacion.investigado, edad: 13)).single;
      expect(de13.nota.texto, contains('no se te aplica'));
      expect(de13.nota.fuentes, contains('LO 5/2000, art. 3'));
      final de15 = notasPara(_contenido, _perfil(PapelSituacion.investigado, edad: 15)).single;
      expect(de15.nota.texto, contains('se aplica la ley penal de menores'));
    });

    test('escuchado en familia: desde los 12, el juez tiene que escucharle; con 11, puede (y lo puede pedir)', () {
      final de12 = notasPara(_contenido, _perfil(PapelSituacion.escuchadoFamilia, edad: 12)).single;
      expect(de12.nota.texto, contains('tiene que escucharte siempre'));
      expect(de12.nota.fuentes, ['LEC, art. 770']);
      final de11 = notasPara(_contenido, _perfil(PapelSituacion.escuchadoFamilia, edad: 11)).single;
      expect(de11.nota.texto, contains('lo puedes pedir tú'));
    });

    test('sin edad, no hay notas de edad; con un proceso de familia, la nota lleva al camino «Me van a escuchar»', () {
      expect(notasPara(_contenido, _perfil(PapelSituacion.victima)), isEmpty);
      final familia = notasPara(
        _contenido,
        _perfil(PapelSituacion.victima, procedimiento: Procedimiento.familia),
      ).single;
      expect(familia.enlace, '/situacion/escuchado_familia');
      expect(familia.nota.consejo, isTrue);
      // Desde el propio camino de familia, no se ofrece ir a él.
      expect(
        notasPara(_contenido, _perfil(PapelSituacion.escuchadoFamilia, procedimiento: Procedimiento.familia)),
        isEmpty,
      );
    });

    test('un proceso de protección tiene su nota (LO 1/1996, arts. 17.1 y 18.2)', () {
      final nota = notasPara(_contenido, _perfil(PapelSituacion.testigo, procedimiento: Procedimiento.proteccion));
      expect(nota.single.nota.fuentes, ['LO 1/1996, art. 17.1', 'LO 1/1996, art. 18.2']);
    });
  });

  group('los pasos de tu caso', () {
    test('víctima de 11: en «Tu declaración», la prueba preconstituida; de 15, la sala preparada', () {
      final de11 = extrasPara(_contenido, _lucia)['P4']!;
      expect(de11.paraTi.single.texto, startsWith('Como tienes 11 años'));
      expect(de11.paraTi.single.fuentes, ['LECrim, art. 449 ter', 'LECrim, art. 703 bis']);
      expect(de11.esCita, isTrue);
      expect(de11.enSala, isFalse, reason: 'la Sala Gesell no es estrados: nadie lleva toga');
      final de15 = extrasPara(_contenido, _sara)['P4']!;
      expect(de15.paraTi.single.texto, startsWith('Con 15 años'));
      expect(de15.paraTi.single.fuentes, ['Ley 4/2015, art. 25.1']);
    });

    test('el juicio es en la sala (estrados, con toga) y lo que llevar sale del catálogo', () {
      final juicio = extrasPara(_contenido, _lucia)['P6']!;
      expect(juicio.enSala, isTrue);
      expect([for (final c in juicio.llevar) c.id], ['citacion', 'dni', 'confianza', 'agua', 'calma']);
      expect(juicio.llevar.first.texto, 'La citación (el aviso) o una foto de ella');
    });

    test('con quién irás cambia el paso de la citación (LECrim, art. 433)', () {
      expect(extrasPara(_contenido, _lucia)['P3']!.paraTi.single.fuentes, ['LECrim, art. 433']);
      expect(extrasPara(_contenido, _sergio)['P3']!.paraTi, isEmpty, reason: 'Sergio irá con su familia');
    });

    test('investigado de 13: los pasos de la ley penal de menores dicen que son de 14 a 17', () {
      final extras = extrasPara(_contenido, _perfil(PapelSituacion.investigado, edad: 13));
      expect(extras['P1']!.noEsParaTi, isNull);
      expect(extras['P1']!.paraTi.single.fuentes, ['LO 5/2000, art. 3']);
      for (final paso in ['P2', 'P3', 'P4', 'P5', 'P6', 'P7']) {
        expect(extras[paso]!.noEsParaTi, 'Este paso es para chicos y chicas de 14 a 17 años', reason: paso);
      }
      final de15 = extrasPara(_contenido, _perfil(PapelSituacion.investigado, edad: 15));
      expect(de15['P2']!.noEsParaTi, isNull);
      // Sin edad, no se dice nada: no sabemos.
      expect(extrasPara(_contenido, _perfil(PapelSituacion.investigado))['P2']!.noEsParaTi, isNull);
    });

    test('las notas de edad de los pasos no salen si no sabemos la edad', () {
      final extras = extrasPara(_contenido, _perfil(PapelSituacion.victima));
      expect(extras['P4']!.paraTi, isEmpty);
      expect(extras['P4']!.duda, '¿Cómo será el día que me escuchen?');
    });

    test('lo que llevar el día de la cita: lo de los pasos con cita, sin repetir', () {
      final cosas = cosasDelDia(_contenido, PapelSituacion.victima);
      expect([for (final c in cosas) c.id], ['citacion', 'dni', 'preguntas', 'confianza', 'agua', 'calma']);
      final investigado = cosasDelDia(_contenido, PapelSituacion.investigado);
      expect([for (final c in investigado) c.id], contains('papeles'));
    });
  });

  group('tus derechos', () {
    test('Lucía: primero los de su edad que tienen que ver con lo que le preocupa (la grabación, no verla)', () {
      final derechos = derechosPara(_contenido, _lucia);
      expect([for (final d in derechos.take(2)) d.derecho.id], ['DS-v-grabacion', 'DS-no-verla']);
      expect(derechos.first.porTuEdad, isTrue);
      expect(derechos.first.porLoQueTePreocupa, isTrue);
      // Lo que solo es de quien investigan no le sale.
      expect(derechos.map((d) => d.derecho.id), isNot(contains('DS-i-abogado')));
    });

    test('Sara (redes): «Pedir que quiten fotos o vídeos tuyos de internet» está entre los primeros', () {
      final ids = [for (final d in derechosPara(_contenido, _sara).take(4)) d.derecho.id];
      expect(ids, contains('DS-canal'));
      // Sin la preocupación de las redes, ese derecho no sale.
      final sinRedes = _perfil(PapelSituacion.victima, edad: 15);
      expect(derechosPara(_contenido, sinRedes).map((d) => d.derecho.id), isNot(contains('DS-canal')));
    });

    test('la edad filtra: con 15 no sale la prueba preconstituida obligatoria; sin edad, sale con su condición', () {
      expect(derechosPara(_contenido, _sara).map((d) => d.derecho.id), isNot(contains('DS-v-grabacion')));
      final sinEdad = derechosPara(_contenido, _perfil(PapelSituacion.victima));
      final grabacion = sinEdad.firstWhere((d) => d.derecho.id == 'DS-v-grabacion');
      expect(grabacion.etiquetaEdad, 'Si tienes menos de 14 años');
      expect(grabacion.porTuEdad, isFalse);
    });

    test('investigado: de 13, que no se le juzga con la ley de menores; de 15, sus derechos de la LO 5/2000', () {
      final de13 = derechosPara(_contenido, _perfil(PapelSituacion.investigado, edad: 13)).map((d) => d.derecho.id);
      expect(de13, contains('DS-i-menor14'));
      expect(de13, isNot(contains('DS-i-abogado')));
      final de15 = derechosPara(_contenido, _perfil(PapelSituacion.investigado, edad: 15)).map((d) => d.derecho.id);
      expect(de15, containsAll(['DS-i-abogado', 'DS-i-defensa', 'DS-i-avisar']));
      expect(de15, isNot(contains('DS-i-menor14')));
      expect(de15, isNot(contains('DS-v-sin-cruzarte')));
    });

    test('el momento filtra: «Denunciar tú» solo antes (o si no se sabe el momento)', () {
      bool tiene(PerfilSituacion p) => derechosPara(_contenido, p).any((d) => d.derecho.id == 'DS-v-denunciar');
      expect(tiene(_perfil(PapelSituacion.victima, fase: Fase.antes)), isTrue);
      expect(tiene(_perfil(PapelSituacion.victima)), isTrue);
      expect(tiene(_perfil(PapelSituacion.victima, fase: Fase.durante)), isFalse);
    });

    test('escuchado en familia: el derecho de su edad (LEC, art. 770)', () {
      final de12 = derechosPara(
        _contenido,
        _perfil(PapelSituacion.escuchadoFamilia, edad: 12),
      ).map((d) => d.derecho.id);
      expect(de12, containsAll(['DS-f-escuchar', 'DS-f-12']));
      expect(de12, isNot(contains('DS-f-menos12')));
    });
  });

  group('lo que te preocupa', () {
    test('una respuesta por preocupación, en orden, con los puntos de su papel y su edad', () {
      final respuestas = respuestasPara(_contenido, _lucia);
      expect([for (final r in respuestas) r.preocupacion], [Preocupacion.verPersona, Preocupacion.noEntender]);
      final ver = respuestas.first;
      expect(ver.puntos.first.fuentes, ['LECrim, art. 449 ter, párr. 3']);
      expect(ver.puntos.any((p) => p.consejo), isTrue);
      expect(ver.ideas, isNotEmpty);
    });

    test('con 15, la de las redes dice que puede contactar ella con la AEPD; con 11, no', () {
      String textos(PerfilSituacion p) => respuestasPara(
        _contenido,
        p,
      ).firstWhere((r) => r.preocupacion == Preocupacion.redes).puntos.map((x) => x.texto).join();
      expect(textos(_sara), contains('Con 14 a 17 años'));
      final de11 = _perfil(
        PapelSituacion.victima,
        edad: 11,
        ticket: const MiTicket(preocupaciones: {Preocupacion.redes}),
      );
      expect(textos(de11), isNot(contains('Con 14 a 17 años')));
    });

    test('a quien investigan se le responde distinto que a una víctima', () {
      final investigado = _perfil(
        PapelSituacion.investigado,
        edad: 15,
        ticket: const MiTicket(preocupaciones: {Preocupacion.preguntas}),
      );
      final puntos = respuestasPara(_contenido, investigado).single.puntos;
      expect(puntos.any((p) => p.fuentes.contains('CE, art. 24.2')), isTrue);
      expect(puntos.any((p) => p.fuentes.contains('LOPIVI, art. 11.2')), isFalse);
    });

    test('ninguna respuesta pregunta qué pasó ni promete nada', () {
      for (final r in _contenido.preocupaciones.values) {
        for (final punto in r.puntos) {
          final texto = punto.texto.toLowerCase();
          expect(texto, isNot(contains('¿qué pasó')));
          expect(texto, isNot(contains('cuéntame')));
          expect(texto, isNot(contains('te creerán')));
          expect(texto, isNot(contains('todo saldrá bien')));
          expect(texto, isNot(contains('es secreto')));
        }
      }
    });

    test('ideas para preguntar, por lo que te preocupa y sin repetir', () {
      final ideas = ideasParaTi(_contenido, _lucia.ticket);
      expect(ideas, hasLength(4));
      expect(ideas.toSet(), hasLength(4));
    });
  });

  group('saludo y cuenta atrás', () {
    test('cambia con el ticket: edad, cómo lo prefiere, con quién irá y su día', () {
      final lucia = saludoPara(_lucia);
      // La fecha, no cuánto falta (producto: nada de cuentas atrás que agobien).
      expect(lucia.titulo, 'Tu cita: sábado 24 de octubre');
      expect(lucia.texto, contains('para alguien de 11 años'));
      expect(lucia.texto, contains('con ejemplos de «Vive el caso»'));
      expect(lucia.texto, contains('Irás con una persona de confianza.'));
      expect(lucia.texto, contains('Abajo te respondo a lo que te preocupa.'));

      final sara = saludoPara(_sara);
      expect(sara.titulo, 'Vamos a ver lo que viene ahora');
      expect(sara.texto, contains('corto y claro'));
      expect(sara.texto, contains('Irás con tu familia y tu abogado o abogada.'));
      expect(saludoPara(_sergio).texto, contains('paso a paso'));
    });

    test('sin ticket, es una guía general que invita a rellenarlo (sin pedir nombre ni hechos)', () {
      final general = saludoPara(PerfilSituacion(papel: PapelSituacion.testigo, hoy: _hoy));
      expect(general.titulo, 'Esta es una guía general');
      expect(general.texto, contains('No te pido tu nombre ni lo que pasó.'));
    });

    test('mirando otro papel, lo dice', () {
      final otro = PerfilSituacion(
        papel: PapelSituacion.testigo,
        hoy: _hoy,
        entrada: const Entrada(edad: 12, rol: RolEntrada.victima),
      );
      expect(otro.miraOtroPapel, isTrue);
      expect(otro.fase, isNull);
      expect(saludoPara(otro).texto, startsWith('Estás mirando otro camino: «Testigo».'));
    });

    test('la cuenta atrás: hoy, mañana, faltan días o ya pasó', () {
      PerfilSituacion con(DateTime fecha) => PerfilSituacion(
        papel: PapelSituacion.victima,
        hoy: _hoy,
        ticket: MiTicket(fecha: fecha),
      );
      expect(cuentaAtras(con(DateTime(2026, 10, 22))), 'Es hoy');
      expect(con(DateTime(2026, 10, 22)).esElDia, isTrue);
      expect(cuentaAtras(con(DateTime(2026, 10, 23))), 'Es mañana');
      expect(cuentaAtras(con(DateTime(2026, 10, 25))), 'Faltan 3 días');
      expect(cuentaAtras(con(DateTime(2026, 10, 21))), 'Fue ayer');
      expect(cuentaAtras(con(DateTime(2026, 10, 20))), 'Fue hace 2 días');
      expect(cuentaAtras(PerfilSituacion(papel: PapelSituacion.victima, hoy: _hoy)), isNull);
      // Cruzando el cambio de hora de octubre (25/10), los días siguen siendo días.
      expect(cuentaAtras(con(DateTime(2026, 10, 27))), 'Faltan 5 días');
    });

    test('el resumen del ticket solo dice lo respondido', () {
      expect(
        resumenTicket(
          const Entrada(edad: 13, procedimiento: Procedimiento.penal, rol: RolEntrada.victima, fase: Fase.durante),
        ),
        '13 años · Penal · Víctima · Durante',
      );
      expect(resumenTicket(const Entrada(rol: RolEntrada.noLoSe, procedimiento: Procedimiento.noLoSe)), '');
      expect(resumenTicket(const Entrada(edad: 12)), '12 años');
    });
  });
}
