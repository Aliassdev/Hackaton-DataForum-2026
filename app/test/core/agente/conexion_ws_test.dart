import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/agente/conexion_ws.dart';

// abrirConexionWs de verdad (dart:io) contra un servidor WebSocket local. Sin TestWidgetsFlutterBinding: con él, las
// peticiones HTTP de los tests devuelven siempre 400.

void main() {
  late HttpServer servidor;
  late StreamController<WebSocket> sockets;

  setUp(() async {
    sockets = StreamController<WebSocket>();
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    servidor.listen((peticion) async {
      if (peticion.uri.path == '/rechazo') {
        peticion.response.statusCode = HttpStatus.forbidden;
        await peticion.response.close();
        return;
      }
      if (peticion.uri.path == '/mudo') return; // Acepta la conexión y no contesta nunca.
      sockets.add(await WebSocketTransformer.upgrade(peticion));
    });
  });

  tearDown(() async {
    await servidor.close(force: true);
    // Sin oyente, close() no acabaría nunca: no se espera.
    unawaited(sockets.close());
  });

  Uri ws(String ruta) => Uri.parse('ws://127.0.0.1:${servidor.port}$ruta?agent_id=agente-de-prueba');

  test('manda y recibe texto; el cierre del servidor llega con su código', () async {
    final conexion = await abrirConexionWs(ws('/conversacion'));
    final delServidor = await sockets.stream.first;
    final enElServidor = Completer<Object?>();
    delServidor.listen((mensaje) {
      if (!enElServidor.isCompleted) enElServidor.complete(mensaje);
    });
    final recibidos = <String>[];
    final cerrada = Completer<void>();
    conexion.textos.listen(recibidos.add, onDone: cerrada.complete);

    conexion.enviar('{"type":"user_activity"}');
    expect(await enElServidor.future, '{"type":"user_activity"}');
    delServidor.add('{"type":"ping","ping_event":{"event_id":1}}');
    await delServidor.close(1000, 'fin');
    await cerrada.future;

    expect(recibidos, ['{"type":"ping","ping_event":{"event_id":1}}']);
    expect(conexion.codigoCierre, 1000);
    expect(() => conexion.enviar('x'), throwsStateError);
  });

  test('cerrar() cierra con 1000 sin esperar al servidor', () async {
    final conexion = await abrirConexionWs(ws('/conversacion'));
    final delServidor = await sockets.stream.first;

    await conexion.cerrar();
    await delServidor.drain<void>();

    expect(delServidor.closeCode, 1000);
  });

  test('si el servidor no acepta la conexión: ErrorConexionWs con el código HTTP y sin la URL', () async {
    final error = await abrirConexionWs(ws('/rechazo')).then<Object?>((_) => null, onError: (Object e) => e);

    expect(error, isA<ErrorConexionWs>().having((e) => e.codigoHttp, 'codigoHttp', 403));
    expect('$error', isNot(contains('agente-de-prueba')));
  });

  test('si no contesta a tiempo: ErrorConexionWs por tiempo agotado', () async {
    final error = await abrirConexionWs(
      ws('/mudo'),
      limite: const Duration(milliseconds: 300),
    ).then<Object?>((_) => null, onError: (Object e) => e);

    expect(error, isA<ErrorConexionWs>().having((e) => e.tiempoAgotado, 'tiempoAgotado', isTrue));
  });

  test('sin servidor: ErrorConexionWs', () async {
    final puerto = servidor.port;
    await servidor.close(force: true);

    final error = await abrirConexionWs(Uri.parse('ws://127.0.0.1:$puerto/conversacion'))
        .then<Object?>((_) => null, onError: (Object e) => e);

    expect(error, isA<ErrorConexionWs>());
  });
}
