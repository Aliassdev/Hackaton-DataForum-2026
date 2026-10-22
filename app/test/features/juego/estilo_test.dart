import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/features/juego/modelos.dart';
import 'package:tuturno/features/juego/widgets/estilo.dart';

void main() {
  test('listaNatural junta los nombres como se dice en voz alta', () {
    expect(listaNatural([]), '');
    expect(listaNatural(['Lucía']), 'Lucía');
    expect(listaNatural(['Lucía', 'Ana']), 'Lucía y Ana');
    expect(listaNatural(['Lucía', 'Ana', 'Elena']), 'Lucía, Ana y Elena');
  });

  test('los términos que nombran a personas también se reconocen en femenino', () {
    final terminos = terminosConVariantes([
      'Coordinador de bienestar y protección',
      'Juez de menores',
      'Abogado de oficio',
      'Denuncia',
      'Sala Gesell',
    ]);
    expect(terminos['Coordinadora de bienestar y protección'], 'Coordinador de bienestar y protección');
    expect(terminos['Jueza de menores'], 'Juez de menores');
    expect(terminos['Abogada de oficio'], 'Abogado de oficio');
    expect(terminos['Denuncia'], 'Denuncia');
    expect(terminos['Sala Gesell'], 'Sala Gesell');
    expect(terminos, hasLength(8), reason: 'solo se añaden las tres variantes en femenino');
  });

  test('cada lugar tiene su nombre y su icono', () {
    for (final lugar in Lugar.values) {
      expect(lugar.nombre, isNotEmpty);
      expect(iconoLugar(lugar), isNotNull);
    }
    expect(Lugar.desde('sala_gesell').nombre, 'En la Sala Gesell');
  });

  test('las fuentes se separan en citas con su norma y su artículo', () {
    expect(citasDe('LECrim, art. 449 ter; Ley 4/2015, art. 20'), [
      (norma: 'LECrim', articulo: '449 ter'),
      (norma: 'Ley 4/2015', articulo: '20'),
    ]);
    expect(citasDe('LO 1/1996, arts. 12.3, 17.1 y 18.2').single.articulo, '12.3, 17.1 y 18.2');
    expect(nombreNormaJuego('LECrim'), 'Ley de Enjuiciamiento Criminal');
  });
}
