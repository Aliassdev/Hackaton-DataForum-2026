import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/features/juego/modelos.dart';
import 'package:tuturno/features/juego/widgets/estilo.dart';
import 'package:tuturno/pixel/ui/ui.dart';
import 'package:tuturno/widgets/iconos/iconos.dart';

import 'fakes.dart';

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

  test('la hoja «De dónde sale» dice «art.» solo si es un artículo, y «arts.» si son varios', () {
    expect(textoCita(citasDe('LECrim, art. 449 ter').single), 'LECrim · art. 449 ter');
    expect(textoCita(citasDe('LOPIVI, arts. 17.1 y 34.1').single), 'LOPIVI · arts. 17.1 y 34.1');
    expect(textoCita(citasDe('AEPD, FAQ 15.03').single), 'AEPD · FAQ 15.03');
    expect(textoCita(citasDe('AEPD, Canal prioritario').single), 'AEPD · Canal prioritario');
    expect(textoCita(citasDe('Código Penal').single), 'Código Penal');
    expect(esLey(citasDe('Ley 4/2015, art. 4').single), isTrue);
    expect(esLey(citasDe('AEPD, FAQ 15.06').single), isFalse);
    expect(esLey(citasDe('INCIBE, 017').single), isFalse);
  });

  test('justicia de verdad: ni mazos ni balanzas de Material en Vive el caso', () {
    for (final fichero in Directory('lib/features/juego').listSync(recursive: true).whereType<File>()) {
      if (!fichero.path.endsWith('.dart')) continue;
      final codigo = fichero.readAsStringSync();
      expect(codigo, isNot(contains('Icons.gavel')), reason: fichero.path);
      expect(codigo, isNot(contains('Icons.balance')), reason: fichero.path);
    }
    expect(iconoPersonaje('La jueza', protagonista: false), TuIcono.toga);
    expect(iconoPersonaje('El juez de menores', protagonista: false), TuIcono.toga);
    expect(iconoPersonaje('El fiscal', protagonista: false), TuIcono.ley);
    expect(iconoLugar(Lugar.fiscalia), TuIcono.ley);
  });

  test('dentro del juego no se juzga a nadie: ni «culpable», ni «condena», ni «caso cerrado»', () {
    for (final ruta in ['lib/features/juego/textos.dart', 'lib/features/juego/caso_screen.dart']) {
      // Solo el código y sus textos: los comentarios explican justo lo que no se dice.
      final texto = File(ruta)
          .readAsLinesSync()
          .where((linea) => !linea.trimLeft().startsWith('//'))
          .join('\n')
          .toLowerCase();
      for (final palabra in ['culpable', 'condena', 'caso cerrado', 'veredicto', 'tu expediente']) {
        expect(texto, isNot(contains(palabra)), reason: '$ruta: «$palabra»');
      }
    }
  });

  test('cada carta de los tres casos oficiales tiene su dibujo pixel, distinto dentro de su caso', () {
    for (final json in casosOficiales().values) {
      final caso = Caso.fromJson(jsonDecode(json) as Map<String, dynamic>);
      final dibujos = [for (final carta in caso.cartas) glifoCarta(carta)];
      expect(dibujos.toSet(), hasLength(dibujos.length), reason: caso.id);
      expect(dibujos, isNot(contains(GlifoPixel.estrella)), reason: '${caso.id}: ninguna sin su dibujo');
    }
    const carta = Carta(id: 'R-una-sola-vez', titulo: 'Lo cuentas una sola vez', texto: '', fuente: '');
    expect(glifoCarta(carta), GlifoPixel.camara);
  });

  test('los colores de las cartas pixel van por turnos', () {
    expect(coloresCartaPixel(0).color, ColoresUiPixel.azul);
    expect(coloresCartaPixel(4).color, ColoresUiPixel.azul);
    expect(coloresCartaPixel(1).color, isNot(coloresCartaPixel(0).color));
  });
}
