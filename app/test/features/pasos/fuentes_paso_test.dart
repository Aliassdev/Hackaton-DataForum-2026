import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/features/pasos/fuentes_paso.dart';

void main() {
  group('CitaPaso', () {
    test('separa la norma del artículo por la primera coma', () {
      final cita = CitaPaso.desdeTexto(' LEC (Ley 1/2000), art. 770, regla 4.ª ');

      expect(cita.original, 'LEC (Ley 1/2000), art. 770, regla 4.ª');
      expect(cita.norma, 'LEC (Ley 1/2000)');
      expect(cita.detalle, 'art. 770, regla 4.ª');
      expect(cita.etiqueta, 'LEC (Ley 1/2000) · art. 770, regla 4.ª');
    });

    test('una fuente con «;» son varias citas, y se quitan los trozos vacíos', () {
      final citas = CitaPaso.de([
        'LOPIVI, art. 14; Ley 1/1996 de asistencia jurídica gratuita, art. 2.h)',
        'LECrim, art. 449 ter;',
        '  ',
      ]);

      expect(
        [for (final c in citas) c.etiqueta],
        ['LOPIVI · art. 14', 'Ley 1/1996 de asistencia jurídica gratuita · art. 2.h)', 'LECrim · art. 449 ter'],
      );
    });

    test('nombre fácil de las normas de docs/MARCO_LEGAL.md', () {
      String? nombre(String fuente) => CitaPaso.desdeTexto(fuente).nombreFacil;

      expect(nombre('LECrim, art. 449 ter'), 'Ley de Enjuiciamiento Criminal');
      expect(nombre('LEC (Ley 1/2000), art. 770'), 'Ley de Enjuiciamiento Civil');
      expect(nombre('LO 1/1996, art. 9.1'), 'Ley de protección jurídica del menor');
      expect(nombre('Ley 1/1996, art. 2.h)'), 'Ley de asistencia jurídica gratuita');
      expect(nombre('Ley 4/2015 (Estatuto de la víctima), art. 20'), 'Estatuto de la víctima del delito');
      expect(
        nombre('LOPIVI (LO 8/2021), art. 11'),
        'Ley de protección de la infancia y la adolescencia frente a la violencia',
      );
      expect(nombre('LO 5/2000, art. 3'), 'Ley de responsabilidad penal de los menores');
      expect(nombre('CDN, art. 12.2'), 'Convención sobre los Derechos del Niño');
      expect(nombre('RGPD, art. 17'), 'Reglamento General de Protección de Datos');
      expect(nombre('LOPDGDD (LO 3/2018), art. 84.2'), 'Ley de protección de datos personales');
      expect(nombre('LO 3/1981 (Defensor del Pueblo), art. 10.1'), 'Ley del Defensor del Pueblo');
      expect(nombre('AEPD, Canal prioritario y FAQ 15.03'), 'Agencia Española de Protección de Datos');
      expect(nombre('INCIBE · 017'), 'Instituto Nacional de Ciberseguridad');
      // Si la norma ya lo dice, no se repite; si no se conoce, nada.
      expect(nombre('Código Penal, art. 197.7'), isNull);
      expect(nombre('Ley de otra cosa, art. 1'), isNull);
    });

    test('la AEPD y el INCIBE son organismos, no leyes (sin confundirlos con las leyes de protección de datos)', () {
      expect(CitaPaso.desdeTexto('AEPD, Canal prioritario').esOrganismo, isTrue);
      expect(CitaPaso.desdeTexto('Agencia Española de Protección de Datos, FAQ 15.03').esOrganismo, isTrue);
      expect(CitaPaso.desdeTexto('INCIBE, 017').esOrganismo, isTrue);
      for (final ley in ['LOPDGDD (LO 3/2018), art. 84.2', 'RGPD, art. 17', 'LECrim, art. 433', 'A-050', 'MOCK']) {
        expect(CitaPaso.desdeTexto(ley).esOrganismo, isFalse, reason: ley);
      }
      expect(nombreFacilDeNorma('LOPDGDD (LO 3/2018)'), 'Ley de protección de datos personales');
      expect(nombreFacilDeNorma('RGPD'), 'Reglamento General de Protección de Datos');
    });

    test('para el lector de pantalla, el nombre fácil y las abreviaturas enteras', () {
      String lector(String fuente) => CitaPaso.desdeTexto(fuente).etiquetaLector;

      expect(lector('LO 5/2000, art. 16.2'), 'Ley de responsabilidad penal de los menores, artículo 16.2');
      expect(lector('LECrim, arts. 449 ter y 703 bis'), 'Ley de Enjuiciamiento Criminal, artículos 449 ter y 703 bis');
      expect(
        lector('LO 5/2000, art. 4, párrs. 4 y 5'),
        'Ley de responsabilidad penal de los menores, artículo 4, párrafos 4 y 5',
      );
      expect(
        lector('Ley 1/1996 de asistencia jurídica gratuita, art. 2.h)'),
        'Ley de asistencia jurídica gratuita, artículo 2.h',
      );
      expect(lector('LO 5/2000, art. 7.1 i)'), 'Ley de responsabilidad penal de los menores, artículo 7.1 i');
      expect(lector('Código Penal, art. 197.7'), 'Código Penal, artículo 197.7');
      expect(
        lector('AEPD, Canal prioritario y FAQ 15.03'),
        'Agencia Española de Protección de Datos, Canal prioritario y FAQ 15.03',
      );
      // Lo que no se conoce, tal cual; una tarjeta y MOCK, con lo que son.
      expect(lector('Ley de otra cosa, art. 1'), 'Ley de otra cosa, artículo 1');
      expect(lector('A-050'), 'ficha A-050');
      expect(lector('MOCK'), 'dato de ejemplo');
    });

    test('una tarjeta de conocimiento (A-050) va tal cual, y MOCK es un dato de ejemplo', () {
      final tarjeta = CitaPaso.desdeTexto('A-050');
      final mock = CitaPaso.desdeTexto('MOCK');

      expect(tarjeta.esTarjeta, isTrue);
      expect(tarjeta.etiqueta, 'A-050');
      expect(tarjeta.nombreFacil, isNull);
      expect(mock.esEjemplo, isTrue);
      expect(mock.etiqueta, 'Dato de ejemplo');
      expect(CitaPaso.desdeTexto('LECrim, art. 433').esTarjeta, isFalse);
    });
  });
}
