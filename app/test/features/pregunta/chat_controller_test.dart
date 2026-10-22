import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/api/tuturno_api.dart';
import 'package:tuturno/core/providers.dart';
import 'package:tuturno/core/voz/stt.dart';
import 'package:tuturno/features/pregunta/chat_controller.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiGrabadora api;
  late FakeStt stt;
  late FakeTts tts;
  late List<String> registro;

  setUp(() {
    registro = [];
    api = ApiGrabadora();
    stt = FakeStt(registro: registro);
    tts = FakeTts(registro: registro);
  });

  Future<ProviderContainer> contenedor({bool vozActivada = true, RolProceso? situacion}) async {
    final c = ProviderContainer.test(
      overrides: await overridesDePrueba(api: api, stt: stt, tts: tts, vozActivada: vozActivada),
    );
    // El chat se borra si nadie lo escucha: se mantiene vivo durante el test.
    c.listen(chatProvider(situacion), (_, _) {});
    return c;
  }

  ChatNotifier chat(ProviderContainer c, [RolProceso? situacion]) => c.read(chatProvider(situacion).notifier);
  EstadoChat estado(ProviderContainer c, [RolProceso? situacion]) => c.read(chatProvider(situacion));

  group('preguntar', () {
    test('una pregunta recibe respuesta con fuentes, sugerencias y términos', () async {
      final c = await contenedor();
      await chat(c).enviar('  Si tengo 13 años y hago algo malo, ¿me pueden juzgar?  ');

      final s = estado(c);
      expect(s.esperando, isFalse);
      expect(s.mensajes, hasLength(2));
      expect(s.mensajes.first.esUsuario, isTrue);
      expect(s.mensajes.first.texto, 'Si tengo 13 años y hago algo malo, ¿me pueden juzgar?');
      final respuesta = s.mensajes.last.respuesta!;
      expect(respuesta.tipo, TipoRespuesta.normal);
      expect(respuesta.fuentes.single.id, 'A-017');
      expect(respuesta.fuentes.single.norma, 'LO 5/2000');
      expect(respuesta.sugerencias, hasLength(2));
      expect(respuesta.terminos, contains('responsabilidad penal'));

      final peticion = api.peticiones.single;
      expect(peticion.pregunta, 'Si tengo 13 años y hago algo malo, ¿me pueden juzgar?');
      expect(peticion.modo, ModoPregunta.libre);
      expect(peticion.situacion, isNull);
      expect(peticion.historial, isEmpty);
    });

    test('mientras espera la respuesta se marca y no admite otra pregunta', () async {
      final c = await contenedor();
      api.pausa = Completer<void>();
      final envio = chat(c).enviar('¿Qué es la Sala Gesell?');
      await Future<void>.delayed(Duration.zero);

      expect(estado(c).esperando, isTrue);
      expect(estado(c).mensajes.single.esUsuario, isTrue);
      await chat(c).enviar('Otra pregunta');
      expect(api.peticiones, hasLength(1));

      api.pausa!.complete();
      await envio;
      expect(estado(c).esperando, isFalse);
      expect(estado(c).mensajes, hasLength(2));
    });

    test('un texto vacío no se envía', () async {
      final c = await contenedor();
      await chat(c).enviar('   ');
      expect(api.peticiones, isEmpty);
      expect(estado(c).mensajes, isEmpty);
    });

    test('una frase de crisis devuelve tipo crisis con los teléfonos', () async {
      final c = await contenedor();
      await chat(c).enviar('Tengo miedo de volver a casa');

      final respuesta = estado(c).mensajes.last.respuesta!;
      expect(respuesta.tipo, TipoRespuesta.crisis);
      expect(respuesta.respuesta, contains('900 20 20 10'));
      expect(respuesta.respuesta, contains('112'));
    });

    test('el historial lleva como mucho los 4 últimos mensajes', () async {
      final c = await contenedor();
      for (final p in ['Pregunta 1', 'Pregunta 2', 'Pregunta 3', 'Pregunta 4']) {
        await chat(c).enviar(p);
      }

      expect(api.peticiones[1].historial.map((m) => m.autor), [Autor.usuario, Autor.asistente]);
      expect(api.peticiones[2].historial, hasLength(4));
      final ultima = api.peticiones[3];
      expect(ultima.historial, hasLength(4));
      expect(ultima.historial.first.texto, 'Pregunta 2');
      expect(ultima.historial.first.autor, Autor.usuario);
      expect(ultima.historial[2].texto, 'Pregunta 3');
      expect(ultima.historial.last.autor, Autor.asistente);
      expect(ultima.toJson()['historial'], hasLength(4));
      expect((ultima.toJson()['historial'] as List).first, {'rol': 'usuario', 'texto': 'Pregunta 2'});
    });

    test('el historial no incluye errores ni preguntas sin respuesta', () {
      const respuesta = AskResponse(tipo: TipoRespuesta.normal, respuesta: 'R1');
      final mensajes = [
        MensajeChat.usuario(0, 'P1'),
        MensajeChat.asistente(1, respuesta),
        MensajeChat.usuario(2, 'P2'),
        MensajeChat.error(3, 'Error', pregunta: 'P2', historial: const []),
      ];
      final historial = ChatNotifier.historialPara(mensajes);
      expect(historial.map((m) => m.texto), ['P1', 'R1']);
    });

    test('lo que se marcó como crisis o hechos no se vuelve a enviar en el historial', () async {
      final c = await contenedor();
      await chat(c).enviar('Tengo miedo de volver a casa');
      await chat(c).enviar('Me pegaron en el recreo');
      await chat(c).enviar('¿Qué es la Fiscalía de Menores?');

      final historial = api.peticiones.last.historial;
      final deUsuario = historial.where((m) => m.autor == Autor.usuario).map((m) => m.texto);
      expect(deUsuario, isNot(contains('Tengo miedo de volver a casa')));
      expect(deUsuario, isNot(contains('Me pegaron en el recreo')));
      // Las plantillas del asistente sí van, para no perder el hilo.
      expect(historial.where((m) => m.autor == Autor.asistente), isNotEmpty);
      expect(historial.map((m) => m.texto).join(' '), isNot(contains('miedo de volver')));
    });
  });

  group('situación', () {
    test('se envía en modo situacion con el papel elegido', () async {
      final c = await contenedor(situacion: RolProceso.testigo);
      expect(estado(c, RolProceso.testigo).situacion, RolProceso.testigo);

      await chat(c, RolProceso.testigo).enviar('¿Me pueden ver los acusados?');
      final peticion = api.peticiones.single;
      expect(peticion.modo, ModoPregunta.situacion);
      expect(peticion.situacion, RolProceso.testigo);
      expect(peticion.toJson()['modo'], 'situacion');
      expect(peticion.toJson()['situacion'], 'testigo');
    });

    test('al quitarla se vuelve al modo libre', () async {
      final c = await contenedor(situacion: RolProceso.victima);
      chat(c, RolProceso.victima).quitarSituacion();
      await chat(c, RolProceso.victima).enviar('¿Qué es una citación?');

      expect(estado(c, RolProceso.victima).situacion, isNull);
      expect(api.peticiones.single.modo, ModoPregunta.libre);
      expect(api.peticiones.single.situacion, isNull);
    });
  });

  group('voz en alto', () {
    test('lee la respuesta si la voz está activada, sin las referencias', () async {
      final c = await contenedor();
      await chat(c).enviar('¿Me pueden juzgar?');

      expect(tts.leidos, hasLength(1));
      expect(tts.leidos.single, startsWith('Antes de los 14 años'));
      expect(tts.leidos.single, isNot(contains('[A-017]')));
      expect(tts.velocidades.single, 0.5);
      expect(estado(c).hablandoId, isNull);
    });

    test('no lee nada si la voz está desactivada', () async {
      final c = await contenedor(vozActivada: false);
      await chat(c).enviar('¿Me pueden juzgar?');
      expect(tts.leidos, isEmpty);
    });

    test('no lee sola si lo pide la pantalla (TalkBack activo)', () async {
      final c = await contenedor();
      await chat(c).enviar('¿Me pueden juzgar?', vozAutomatica: false);
      expect(tts.leidos, isEmpty);
    });

    test('al desactivar la voz (aquí o en Ajustes) se calla lo que se está leyendo', () async {
      final c = await contenedor();
      tts.terminarAlInstante = false;
      unawaited(chat(c).enviar('¿Me pueden juzgar?'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(estado(c).hablandoId, isNotNull);
      final paradasAntes = tts.paradas;

      await c.read(ajustesProvider.notifier).actualizar((a) => a.copyWith(vozActivada: false));
      await Future<void>.delayed(Duration.zero);
      expect(estado(c).hablandoId, isNull);
      expect(tts.paradas, greaterThan(paradasAntes));
    });

    test('el altavoz vuelve a leer y, si está leyendo, para', () async {
      final c = await contenedor(vozActivada: false);
      await chat(c).enviar('¿Me pueden juzgar?');
      final id = estado(c).mensajes.last.id;
      tts.terminarAlInstante = false;

      unawaited(chat(c).alternarLectura(id));
      await Future<void>.delayed(Duration.zero);
      expect(estado(c).hablandoId, id);
      expect(tts.leidos, hasLength(1));

      await chat(c).alternarLectura(id);
      expect(estado(c).hablandoId, isNull);
      expect(tts.paradas, greaterThan(0));
    });
  });

  group('errores', () {
    test('un error de la API sale como mensaje y se puede reintentar', () async {
      final c = await contenedor();
      api.errores.add(errorApi);
      await chat(c).enviar('¿Qué es la Fiscalía de Menores?', vozAutomatica: false);

      final error = estado(c).mensajes.last;
      expect(error.esError, isTrue);
      expect(error.texto, errorApi.mensaje);
      expect(estado(c).esperando, isFalse);
      expect(tts.leidos, isEmpty);

      await chat(c).reintentar(error.id);
      final s = estado(c);
      // Se escribió (no se preguntó con la voz): al reintentar tampoco se lee sola.
      expect(tts.leidos, isEmpty);
      expect(s.mensajes.where((m) => m.esError), isEmpty);
      expect(s.mensajes, hasLength(2));
      expect(s.mensajes.last.respuesta, isNotNull);
      expect(api.peticiones, hasLength(2));
      expect(api.peticiones.last.pregunta, '¿Qué es la Fiscalía de Menores?');
    });

    test('al reintentar una pregunta hecha con la voz, la respuesta se lee sola', () async {
      final c = await contenedor();
      api.errores.add(errorApi);
      await chat(c).enviar('¿Qué es la Fiscalía de Menores?', vozAutomatica: true);
      expect(tts.leidos, isEmpty);

      await chat(c).reintentar(estado(c).mensajes.last.id);
      expect(tts.leidos, hasLength(1));
    });

    test('un fallo inesperado enseña el mensaje seguro', () async {
      final c = await contenedor();
      api.errores.add(StateError('roto'));
      await chat(c).enviar('Hola');
      expect(estado(c).mensajes.last.texto, ApiException.mensajeSeguro);
    });
  });

  group('micrófono', () {
    test('para la voz antes de escuchar y muestra la transcripción en vivo', () async {
      final c = await contenedor();
      await chat(c).empezarEscucha();

      expect(registro.indexOf('tts.parar'), lessThan(registro.indexOf('stt.escuchar')));
      expect(estado(c).voz, EstadoVoz.escuchando);

      stt.oir('qué es la');
      expect(estado(c).dictado, 'qué es la');
      stt.oir('qué es la sala gesell');
      stt.volumen(0.8);
      expect(estado(c).dictado, 'qué es la sala gesell');
      expect(estado(c).nivelVoz, 0.8);

      await chat(c).alternarMicro();
      expect(estado(c).voz, EstadoVoz.inactivo);
      expect(stt.paradas, 1);
      expect(estado(c).dictado, 'qué es la sala gesell');
      // Lo dictado no se envía solo: se corrige antes en el campo de texto.
      expect(api.peticiones, isEmpty);
    });

    test('si no se puede usar el micrófono, avisa', () async {
      stt.disponible = false;
      final c = await contenedor();
      await chat(c).alternarMicro();

      expect(estado(c).voz, EstadoVoz.inactivo);
      expect(estado(c).problemaVoz, ProblemaVoz.sinPermiso);

      chat(c).cerrarAvisoVoz();
      expect(estado(c).problemaVoz, isNull);
    });

    test('al callarse el sistema, deja de escuchar', () async {
      final c = await contenedor();
      await chat(c).empezarEscucha();
      stt.oir('hola');
      stt.silencio();
      expect(estado(c).voz, EstadoVoz.inactivo);
      expect(estado(c).dictado, 'hola');
    });

    test('«no te oigo» solo avisa si no se ha entendido nada', () async {
      final c = await contenedor();
      await chat(c).empezarEscucha();
      stt.fallar(ProblemaVoz.noTeOigo);
      expect(estado(c).problemaVoz, ProblemaVoz.noTeOigo);

      await chat(c).empezarEscucha();
      expect(estado(c).problemaVoz, isNull);
      stt.oir('mis derechos');
      stt.fallar(ProblemaVoz.noTeOigo);
      expect(estado(c).problemaVoz, isNull);
      expect(estado(c).dictado, 'mis derechos');

      // Con algo entendido, un error tardío tampoco tapa lo dictado; la falta de permiso sí se avisa.
      await chat(c).empezarEscucha();
      stt.oir('la sala gesell');
      stt.fallar(ProblemaVoz.otro);
      expect(estado(c).problemaVoz, isNull);
      await chat(c).empezarEscucha();
      stt.oir('hola');
      stt.fallar(ProblemaVoz.sinPermiso);
      expect(estado(c).problemaVoz, ProblemaVoz.sinPermiso);
    });

    test('no se puede escuchar mientras llega una respuesta', () async {
      final c = await contenedor();
      api.pausa = Completer<void>();
      final envio = chat(c).enviar('¿Qué es la Sala Gesell?');
      await Future<void>.delayed(Duration.zero);

      await chat(c).alternarMicro();
      expect(stt.inicializaciones, 0);
      expect(estado(c).voz, EstadoVoz.inactivo);

      api.pausa!.complete();
      await envio;
    });

    test('si se para mientras se prepara, no llega a pedir el micrófono', () async {
      final c = await contenedor();
      final inicio = chat(c).empezarEscucha();
      expect(estado(c).voz, EstadoVoz.preparando);
      await chat(c).pararEscucha();
      await inicio;

      expect(stt.inicializaciones, 0);
      expect(estado(c).voz, EstadoVoz.inactivo);
    });

    test('si el reconocimiento falla al empezar, avisa y vuelve al estado normal', () async {
      stt = _SttQueFalla(registro: registro);
      final c = await contenedor();
      await chat(c).empezarEscucha();

      expect(estado(c).voz, EstadoVoz.inactivo);
      expect(estado(c).problemaVoz, ProblemaVoz.otro);
    });

    test('al enviar se cancela la escucha y se ignora lo que llegue tarde', () async {
      final c = await contenedor();
      await chat(c).empezarEscucha();
      stt.oir('hola');
      await chat(c).enviar('Otra pregunta');

      expect(stt.cancelaciones, 1);
      stt.oir('esto llega tarde');
      expect(estado(c).dictado, isEmpty);
    });
  });

  test('borrar empieza de cero, mantiene la situación e ignora respuestas que lleguen tarde', () async {
    final c = await contenedor(situacion: RolProceso.investigado);
    final notifier = chat(c, RolProceso.investigado);
    await notifier.enviar('Primera');
    api.pausa = Completer<void>();
    final envio = notifier.enviar('Segunda');
    await Future<void>.delayed(Duration.zero);

    notifier.borrar();
    api.pausa!.complete();
    await envio;

    final s = estado(c, RolProceso.investigado);
    expect(s.mensajes, isEmpty);
    expect(s.esperando, isFalse);
    expect(s.situacion, RolProceso.investigado);
  });

  test('al salir de la pantalla se para la voz y el micrófono', () async {
    final c = ProviderContainer.test(
      overrides: await overridesDePrueba(api: api, stt: stt, tts: tts),
    );
    final sub = c.listen(chatProvider(null), (_, _) {});
    await c.read(chatProvider(null).notifier).enviar('Hola');
    final paradas = tts.paradas;

    sub.close();
    await Future<void>.delayed(Duration.zero);
    expect(tts.paradas, greaterThan(paradas));
    expect(stt.cancelaciones, greaterThan(0));
  });
}

class _SttQueFalla extends FakeStt {
  _SttQueFalla({super.registro});

  @override
  Future<void> escuchar({
    required void Function(String texto) onTexto,
    required void Function() onFin,
    void Function(double nivel)? onNivel,
    void Function(ProblemaVoz problema)? onProblema,
  }) async => throw StateError('sin reconocimiento');
}
