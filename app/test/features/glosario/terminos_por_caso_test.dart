import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/features/glosario/terminos_por_caso.dart';

import 'ayudantes.dart';

// Filtro por caso del glosario (plan v2, producto §5.7): qué palabras salen en el texto de cada caso.

final _glosario = [
  palabra('G-sala-gesell', 'Sala Gesell'),
  palabra('G-fiscalia-menores', 'Fiscalía de Menores'),
  palabra('G-fiscalia', 'Fiscalía'),
  palabra('G-abogado-oficio', 'Abogado de oficio'),
  palabra('G-juez-menores', 'Juez de menores'),
  palabra('G-medida-cautelar', 'Medida cautelar'),
  palabra('G-juicio', 'Juicio'),
  palabra('G-coordinador', 'Coordinador de bienestar y protección'),
  palabra('G-declaracion', 'Declaración'),
];

void main() {
  group('terminosPorCaso', () {
    test('con un caso que dice «Sala Gesell» y «Fiscalía de Menores», asigna sus ids', () {
      final caso = casoEnMemoria(
        id: 'caso-1',
        protagonista: 'Lucía',
        narracion: 'Lucía va a la Sala Gesell. Después, la Fiscalía de Menores revisa el caso.',
      );
      expect(terminosPorCaso(_glosario, [caso]), {
        'caso-1': {'G-sala-gesell', 'G-fiscalia-menores', 'G-fiscalia'},
      });
    });

    test('las tildes y las mayúsculas no importan', () {
      final caso = casoEnMemoria(id: 'c', narracion: 'EN LA SALA GESELL Y EN LA FISCALIA DE MENORES.');
      expect(terminosPorCaso(_glosario, [caso])['c'], containsAll(['G-sala-gesell', 'G-fiscalia-menores']));
      final conTildes = casoEnMemoria(id: 'd', narracion: 'Una declaración.');
      expect(terminosPorCaso([palabra('G-x', 'DECLARACION')], [conTildes])['d'], {'G-x'});
    });

    test('busca en la pregunta, las opciones, las explicaciones, las cartas y el título', () {
      for (final (campo, caso) in [
        ('pregunta', casoEnMemoria(id: 'c', pregunta: '¿Qué hace la Fiscalía?', opcion: 'Nada')),
        ('opción', casoEnMemoria(id: 'c', pregunta: '¿Qué?', opcion: 'Ir a la Fiscalía')),
        ('explicación', casoEnMemoria(id: 'c', pregunta: '¿Qué?', opcion: 'Sí', explicacion: 'La Fiscalía ayuda.')),
        ('carta', casoEnMemoria(id: 'c', carta: 'La Fiscalía te protege.')),
        ('título', casoEnMemoria(id: 'c', titulo: 'Sara y la Fiscalía')),
      ]) {
        expect(terminosPorCaso(_glosario, [caso])['c'], {'G-fiscalia'}, reason: campo);
      }
    });

    test('encuentra el plural y el femenino', () {
      final caso = casoEnMemoria(
        id: 'c',
        narracion:
            'Le asignan una abogada de oficio. La jueza de menores puede poner medidas cautelares. Laura es la '
            'coordinadora de bienestar y protección. Hubo dos juicios y varias declaraciones.',
      );
      expect(terminosPorCaso(_glosario, [caso])['c'], {
        'G-abogado-oficio',
        'G-juez-menores',
        'G-medida-cautelar',
        'G-coordinador',
        'G-juicio',
        'G-declaracion',
      });
    });

    test('solo palabras enteras: «prejuicio» no es «Juicio» ni «medidor» es «Medida cautelar»', () {
      final caso = casoEnMemoria(id: 'c', narracion: 'Es un prejuicio. Un medidor cautelar. Las salas gesellianas.');
      expect(terminosPorCaso(_glosario, [caso])['c'], isEmpty);
    });

    test('una frase no se encuentra a caballo entre dos trozos del caso', () {
      final caso = casoEnMemoria(
        id: 'c',
        narracion: 'Entra en la sala',
        pregunta: 'Gesell es un apellido',
        opcion: 'x',
      );
      expect(terminosPorCaso(_glosario, [caso])['c'], isEmpty);
    });

    test('cada caso tiene lo suyo y un caso sin palabras sale vacío', () {
      final lucia = casoEnMemoria(id: 'lucia', narracion: 'La Sala Gesell.');
      final otro = casoEnMemoria(id: 'otro', narracion: 'Un día normal.');
      expect(terminosPorCaso(_glosario, [lucia, otro]), {
        'lucia': {'G-sala-gesell'},
        'otro': <String>{},
      });
    });

    test('un término sin letras no se busca', () {
      expect(patronDeTermino(' ¿? '), isNull);
      expect(patronDeTermino('Sala Gesell')!.hasMatch('la sala   gesell'), isTrue);
    });
  });

  group('filtrosDeCaso', () {
    test('un chip por caso con protagonista y alguna palabra, en el orden de los casos', () {
      final casos = [
        casoEnMemoria(id: 'lucia', protagonista: 'Lucía', narracion: 'Lucía tiene 11 años. La Sala Gesell.'),
        casoEnMemoria(id: 'sin-nombre', narracion: 'La Fiscalía.'),
        casoEnMemoria(id: 'sin-palabras', protagonista: 'Nora', narracion: 'Nora tiene 12 años.'),
        casoEnMemoria(id: 'sergio', protagonista: 'Sergio', narracion: 'Sergio va a la Fiscalía de Menores.'),
      ];
      final filtros = filtrosDeCaso(_glosario, casos);
      expect([for (final f in filtros) f.protagonista], ['Lucía', 'Sergio']);
      expect(filtros.first.casoId, 'lucia');
      expect(filtros.first.terminos, {'G-sala-gesell'});
    });

    test('con los casos y el glosario de ejemplo: Lucía, Sergio y Sara, cada uno con sus palabras', () {
      final glosario = glosarioDeEjemplo();
      expect(glosario, hasLength(42));
      final filtros = filtrosDeCaso(glosario, casosDeEjemplo());
      expect([for (final f in filtros) f.protagonista], ['Lucía', 'Sergio', 'Sara']);
      final porNombre = {for (final f in filtros) f.protagonista: f.terminos};
      expect(porNombre['Lucía'], containsAll(['G-sala-gesell', 'G-prueba-preconstituida', 'G-equipo-psicosocial']));
      expect(porNombre['Sergio'], containsAll(['G-acoso-escolar', 'G-fiscalia-menores', 'G-protocolo-acoso']));
      // El momento de la demo: filtro «Sara» → «Canal prioritario».
      expect(porNombre['Sara'], containsAll(['G-canal-prioritario', 'G-agencia-proteccion-datos', 'G-denuncia']));
      // Lo de Lucía no es de Sara.
      expect(porNombre['Sara'], isNot(contains('G-sala-gesell')));
    });
  });
}
