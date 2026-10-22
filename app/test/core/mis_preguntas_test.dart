import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/mis_preguntas.dart';
import 'package:tuturno/core/progreso.dart';
import 'package:tuturno/core/providers.dart';

// «Mis preguntas» (plan v2, producto §5.2): lo apuntado se guarda solo en el móvil, con la clave 'mis_preguntas'.

final _ahora = DateTime(2026, 10, 22, 17, 30);

Future<ProviderContainer> _contenedor([Map<String, Object> valores = const {}]) async {
  SharedPreferences.setMockInitialValues(valores);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs), relojProvider.overrideWithValue(() => _ahora)],
  );
  addTearDown(c.dispose);
  return c;
}

/// Otro arranque de la app con lo que haya guardado [c].
ProviderContainer _reabrir(ProviderContainer c) {
  final otra = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(c.read(sharedPreferencesProvider)),
      relojProvider.overrideWithValue(() => _ahora),
    ],
  );
  addTearDown(otra.dispose);
  return otra;
}

const _paso = 'Te citan para escucharte';
const _pedir = 'Que te expliquen con palabras claras qué va a pasar y quién estará';

void main() {
  late ProviderContainer c;
  MisPreguntasNotifier notifier() => c.read(misPreguntasProvider.notifier);
  List<Apunte> lista() => c.read(misPreguntasProvider);

  setUp(() async => c = await _contenedor());

  group('apuntar', () {
    test('desde un paso: guarda el texto tal cual, el tipo, el paso y sus fuentes', () {
      expect(lista(), isEmpty);
      expect(
        notifier().apuntar(_pedir, tipo: TipoApunte.pedir, origen: _paso, fuentes: ['LO 8/2021, art. 11']),
        isTrue,
      );
      final apunte = lista().single;
      expect(apunte.texto, _pedir);
      expect(apunte.tipo, TipoApunte.pedir);
      expect(apunte.origen, _paso);
      expect(apunte.fuentes, ['LO 8/2021, art. 11']);
      expect(apunte.hecho, isFalse);
      expect(apunte.id, '${_ahora.microsecondsSinceEpoch}');
      expect(notifier().contiene(_pedir), isTrue);
    });

    test('escrito a mano: sin paso ni fuentes y sin espacios de sobra', () {
      expect(notifier().apuntar('  ¿Puedo  hacer un descanso?\n', tipo: TipoApunte.preguntar), isTrue);
      expect(lista().single.texto, '¿Puedo hacer un descanso?');
      expect(lista().single.origen, isNull);
      expect(lista().single.fuentes, isEmpty);
    });

    test('vacío: no apunta nada', () {
      expect(notifier().apuntar('', tipo: TipoApunte.preguntar), isFalse);
      expect(notifier().apuntar('   \n ', tipo: TipoApunte.preguntar), isFalse);
      expect(lista(), isEmpty);
    });

    test('repetido, también con otras tildes, mayúsculas o espacios: no lo apunta dos veces', () {
      expect(notifier().apuntar('¿Quién va a estar en la sala?', tipo: TipoApunte.preguntar), isTrue);
      expect(notifier().apuntar('¿QUIEN va a estar  en la SALA?', tipo: TipoApunte.preguntar), isFalse);
      expect(notifier().apuntar('¿Quién va a estar en la sala?', tipo: TipoApunte.pedir, origen: _paso), isFalse);
      expect(lista(), hasLength(1));
      expect(notifier().contiene('¿quien va a estar en la sala?'), isTrue);
      expect(notifier().contiene('¿Quién más va a estar?'), isFalse);
      expect(notifier().contiene(''), isFalse);
    });

    test('como mucho 30: el 31 no entra', () {
      for (var i = 0; i < maxApuntes; i++) {
        expect(notifier().apuntar('Pregunta número $i', tipo: TipoApunte.preguntar), isTrue);
      }
      expect(notifier().apuntar('Una más', tipo: TipoApunte.preguntar), isFalse);
      expect(lista(), hasLength(30));
      expect(lista().map((a) => a.id).toSet(), hasLength(30), reason: 'ids distintos aunque el reloj no se mueva');
      notifier().quitar(lista().first.id);
      expect(notifier().apuntar('Una más', tipo: TipoApunte.preguntar), isTrue);
    });

    test('recorta a 200 caracteres sin partir emojis ni letras con tilde', () {
      expect(notifier().apuntar('á' * 250, tipo: TipoApunte.preguntar), isTrue);
      expect(lista().single.texto, 'á' * 200);
      expect(notifier().apuntar('${'b' * 199}👍🏽 y más', tipo: TipoApunte.preguntar), isTrue);
      expect(lista().last.texto, '${'b' * 199}👍🏽');
      expect(notifier().contiene('á' * 300), isTrue, reason: 'se compara ya recortado');
    });

    test('la lista no se puede cambiar desde fuera', () {
      notifier().apuntar('Hola', tipo: TipoApunte.preguntar);
      expect(() => lista().clear(), throwsUnsupportedError);
    });
  });

  group('cambiar lo apuntado', () {
    test('marcar «Ya lo he preguntado» y desmarcarlo', () {
      notifier().apuntar('¿Qué pasa después de hoy?', tipo: TipoApunte.preguntar);
      final id = lista().single.id;
      notifier().marcar(id, true);
      expect(lista().single.hecho, isTrue);
      notifier().marcar(id, false);
      expect(lista().single.hecho, isFalse);
      notifier().marcar('otro', true);
      expect(lista().single.hecho, isFalse);
    });

    test('editar solo las propias, sin dejarlas vacías ni repetidas', () {
      notifier().apuntar(_pedir, tipo: TipoApunte.pedir, origen: _paso);
      notifier().apuntar('¿Puedo ir con mi madre?', tipo: TipoApunte.preguntar);
      notifier().apuntar('¿Cuánto dura?', tipo: TipoApunte.preguntar);
      final [deUnPaso, propia, otra] = lista();

      notifier().editar(propia.id, '  ¿Puede estar conmigo una persona de confianza? ');
      expect(lista()[1].texto, '¿Puede estar conmigo una persona de confianza?');
      expect(lista()[1].id, propia.id);

      notifier().editar(deUnPaso.id, 'Otra cosa');
      expect(lista()[0].texto, _pedir, reason: 'lo de un paso es contenido validado: no se reescribe');

      notifier().editar(otra.id, '   ');
      expect(lista()[2].texto, '¿Cuánto dura?');

      notifier().editar(otra.id, '¿puede estar conmigo una persona de confianza?');
      expect(lista()[2].texto, '¿Cuánto dura?', reason: 'ya está apuntada');

      notifier().editar('no-existe', 'Algo');
      expect(lista(), hasLength(3));
    });

    test('quitar por id y quitar por texto (el botón «Apuntar» de un paso, otra vez)', () {
      notifier().apuntar(_pedir, tipo: TipoApunte.pedir, origen: _paso);
      notifier().apuntar('¿Me puedes repetir la pregunta con otras palabras?', tipo: TipoApunte.preguntar);
      notifier().quitarTexto(_pedir.toUpperCase());
      expect(notifier().contiene(_pedir), isFalse);
      expect(lista(), hasLength(1));
      notifier().quitar(lista().single.id);
      expect(lista(), isEmpty);
      notifier().quitar('no-existe');
      notifier().quitarTexto('nada');
      expect(lista(), isEmpty);
    });

    test('borrarTodas deja la lista vacía y quita la clave', () async {
      notifier().apuntar('Una', tipo: TipoApunte.preguntar);
      notifier().apuntar('Otra', tipo: TipoApunte.pedir, origen: _paso);
      await notifier().borrarTodas();
      expect(lista(), isEmpty);
      expect(c.read(sharedPreferencesProvider).getString('mis_preguntas'), isNull);
      expect(_reabrir(c).read(misPreguntasProvider), isEmpty);
    });
  });

  group('se guarda en el móvil', () {
    test('sobrevive a cerrar la app, con lo marcado y lo editado', () {
      notifier().apuntar(_pedir, tipo: TipoApunte.pedir, origen: _paso, fuentes: ['LO 8/2021, art. 11']);
      notifier().apuntar('¿Puedo decir «no lo sé»?', tipo: TipoApunte.preguntar);
      notifier().marcar(lista().last.id, true);

      final guardado = jsonDecode(c.read(sharedPreferencesProvider).getString('mis_preguntas')!) as List;
      expect((guardado.first as Map).keys, unorderedEquals(['id', 'texto', 'tipo', 'origen', 'fuentes', 'hecho']));
      expect((guardado.first as Map)['tipo'], 'pedir');

      final otra = _reabrir(c);
      expect(otra.read(misPreguntasProvider), lista());
      expect(otra.read(misPreguntasProvider).last.hecho, isTrue);
    });

    test('un JSON roto o que no es una lista da la lista vacía', () async {
      for (final roto in ['[{"id": ', '{"id": "1"}', '"hola"', '']) {
        final otro = await _contenedor({'mis_preguntas': roto});
        expect(otro.read(misPreguntasProvider), isEmpty, reason: roto);
      }
    });

    test('un apunte roto se salta y el resto se lee', () async {
      final otro = await _contenedor({
        'mis_preguntas': jsonEncode([
          {'id': '1', 'texto': 'Bien', 'tipo': 'preguntar', 'origen': null, 'fuentes': <String>[], 'hecho': false},
          {'texto': 'Sin id'},
          {'id': '2'},
          {'id': '3', 'texto': '   '},
          'no es un apunte',
          {'id': '1', 'texto': 'Id repetido'},
          {
            'id': '4',
            'texto': 'Con un tipo que no existe',
            'tipo': 'otro',
            'fuentes': ['A', 3],
            'hecho': 'sí',
          },
        ]),
      });
      final apuntes = otro.read(misPreguntasProvider);
      expect(apuntes.map((a) => a.id), ['1', '4']);
      expect(apuntes.last.tipo, TipoApunte.preguntar);
      expect(apuntes.last.fuentes, ['A']);
      expect(apuntes.last.hecho, isFalse);
    });

    test('si hubiera más de 30 guardados, se leen los 30 primeros', () async {
      final otro = await _contenedor({
        'mis_preguntas': jsonEncode([
          for (var i = 0; i < 35; i++) {'id': '$i', 'texto': 'Pregunta $i', 'tipo': 'preguntar'},
        ]),
      });
      expect(otro.read(misPreguntasProvider), hasLength(30));
    });
  });

  group('Apunte', () {
    test('toJson y fromJson de ida y vuelta', () {
      const apunte = Apunte(
        id: '42',
        texto: 'Que haya un descanso si lo necesitas',
        tipo: TipoApunte.pedir,
        origen: _paso,
        fuentes: ['LO 8/2021, art. 11'],
        hecho: true,
      );
      expect(Apunte.fromJson(jsonDecode(jsonEncode(apunte.toJson())) as Map<String, dynamic>), apunte);
      expect(apunte.toJson(), {
        'id': '42',
        'texto': 'Que haya un descanso si lo necesitas',
        'tipo': 'pedir',
        'origen': _paso,
        'fuentes': ['LO 8/2021, art. 11'],
        'hecho': true,
      });
    });

    test('fromJson recorta el texto a 200 y rechaza lo que no tiene id o texto', () {
      expect(Apunte.fromJson({'id': '1', 'texto': 'x' * 300}).texto, hasLength(maxCaracteresApunte));
      expect(() => Apunte.fromJson({'texto': 'Hola'}), throwsFormatException);
      expect(() => Apunte.fromJson({'id': '1', 'texto': ' '}), throwsFormatException);
    });

    test('toString no enseña el texto (nunca va a los logs)', () {
      const apunte = Apunte(id: '1', texto: 'Algo privado', tipo: TipoApunte.preguntar);
      expect(apunte.toString(), isNot(contains('privado')));
    });
  });
}
