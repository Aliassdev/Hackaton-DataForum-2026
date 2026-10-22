import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tuturno/core/api/http_api.dart';
import 'package:tuturno/core/api/tuturno_api.dart';
import 'package:tuturno/core/entrada.dart';
import 'package:tuturno/features/pregunta/widgets/fuentes.dart';

// El modo texto real de Pregunta (POST /api/agent/ask, backend/API.md): el perfil viaja con la pregunta, las fuentes
// traen el enlace al BOE y `grade` puede decir que lo escrito sonaba a crisis.

http.Response _json(Object cuerpo) => http.Response.bytes(utf8.encode(jsonEncode(cuerpo)), 200);

void main() {
  group('AskRequest con el perfil', () {
    test('sin perfil, la petición es la de la sección 8.1 tal cual (sin la clave)', () {
      expect(const AskRequest(pregunta: 'p').toJson().containsKey('perfil'), isFalse);
    });

    test('con perfil, van las cuatro variables de Entrada.variablesAgente (lo que no se sabe, vacío)', () {
      const entrada = Entrada(edad: 13, procedimiento: Procedimiento.penal, rol: RolEntrada.victima);
      final json = AskRequest(pregunta: 'p', perfil: entrada.variablesAgente()).toJson();
      expect(json['perfil'], {'edad': '13', 'procedimiento': 'penal', 'rol': 'victima', 'fase': ''});
      // Con «Mi situación» y sin papel elegido, el papel sale de la situación (el backend también lo usa).
      final conSituacion = AskRequest(
        pregunta: 'p',
        modo: ModoPregunta.situacion,
        situacion: RolProceso.testigo,
        perfil: const Entrada(edad: 15).variablesAgente(situacion: RolProceso.testigo),
      ).toJson();
      expect(conSituacion['perfil'], {'edad': '15', 'procedimiento': '', 'rol': 'testigo', 'fase': ''});
      expect(conSituacion['situacion'], 'testigo');
    });

    test('HttpTuTurnoApi lo envía en el cuerpo y lee las fuentes con su enlace', () async {
      final peticiones = <http.Request>[];
      final api = HttpTuTurnoApi(
        baseUrl: 'https://tuturno.example.com',
        client: MockClient((request) async {
          peticiones.add(request);
          return _json({
            'tipo': 'normal',
            'respuesta': 'Antes de los 14 años no te pueden juzgar.\n\nSi tienes 14 o más...',
            'fuentes': [
              {
                'id': 'LORPM-3',
                'titulo': 'Régimen de los menores de catorce años',
                'norma': 'LORPM',
                'articulo': '3',
                'url': 'https://www.boe.es/buscar/act.php?id=BOE-A-2000-641#a3',
              },
            ],
            'sugerencias': <String>[],
            'terminos': <String>[],
            'latencia_ms': 2140,
          });
        }),
      );
      const perfil = {'edad': '13', 'procedimiento': 'penal', 'rol': 'investigado', 'fase': ''};
      final r = await api.ask(const AskRequest(pregunta: '¿Me pueden juzgar?', perfil: perfil));

      expect(jsonDecode(utf8.decode(peticiones.single.bodyBytes))['perfil'], perfil);
      expect(r.respuesta, contains('\n\n'));
      expect(r.fuentes.single.url, 'https://www.boe.es/buscar/act.php?id=BOE-A-2000-641#a3');
    });
  });

  group('Fuente.url', () {
    test('sin url, vacía; solo se aceptan enlaces http(s) con dominio', () {
      Fuente leer(Object? url) =>
          Fuente.fromJson({'id': 'x', 'titulo': 't', 'norma': 'n', 'articulo': '1', 'url': ?url});
      expect(leer(null).url, '');
      expect(leer('').url, '');
      expect(leer('https://www.boe.es/a').url, 'https://www.boe.es/a');
      expect(leer('javascript:alert(1)').url, '');
      expect(leer('/ruta/relativa').url, '');
      expect(leer(42).url, '');
    });
  });

  group('GradeResponse.tipo', () {
    test('es opcional: sin él, null y no es crisis', () {
      final r = GradeResponse.fromJson({'puntuacion': 0.5, 'cubiertas': [], 'faltan': [], 'feedback': 'f'});
      expect(r.tipo, isNull);
      expect(r.esCrisis, isFalse);
    });

    test('«crisis» (sin que importen mayúsculas ni espacios) y «normal»', () {
      final crisis = GradeResponse.fromJson({
        'puntuacion': 0.0,
        'cubiertas': [],
        'faltan': [],
        'feedback': 'Llama a ANAR: 900 20 20 10.',
        'tipo': ' Crisis ',
      });
      expect(crisis.tipo, 'crisis');
      expect(crisis.esCrisis, isTrue);
      final normal = GradeResponse.fromJson({
        'puntuacion': 1,
        'cubiertas': ['a'],
        'faltan': [],
        'feedback': '¡Genial!',
        'tipo': 'normal',
      });
      expect(normal.tipo, 'normal');
      expect(normal.esCrisis, isFalse);
    });
  });

  test('las siglas del backend tienen nombre fácil; el BOE se reconoce por su dominio', () {
    expect(nombreFacilNorma('LORPM'), 'Ley de responsabilidad penal de los menores');
    expect(nombreFacilNorma('LO 5/2000'), 'Ley de responsabilidad penal de los menores');
    expect(nombreFacilNorma('LOPIVI'), contains('infancia y la adolescencia'));
    expect(nombreFacilNorma('Otra'), isNull);
    expect(esEnlaceBoe('https://www.boe.es/buscar/act.php?id=BOE-A-2000-641#a3'), isTrue);
    expect(esEnlaceBoe('https://www.aepd.es/canalprioritario'), isFalse);
    expect(esEnlaceBoe('https://boe.es.ejemplo.com/'), isFalse);
  });

  test('AskResponse.copyWith cambia solo lo que se pide', () {
    const r = AskResponse(tipo: TipoRespuesta.normal, respuesta: 'r', sugerencias: ['s'], latenciaMs: 7);
    final crisis = r.copyWith(tipo: TipoRespuesta.crisis);
    expect(crisis.tipo, TipoRespuesta.crisis);
    expect(crisis.respuesta, 'r');
    expect(crisis.sugerencias, ['s']);
    expect(crisis.latenciaMs, 7);
  });
}
