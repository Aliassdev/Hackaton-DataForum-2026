import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'conexion_ws.dart';

/// [abrirConexionWs] en Android (y en los tests): dart:io directamente, para poder poner el tiempo límite, el ping del
/// protocolo y escuchar los errores del socket (si nadie los escucha, salen como excepciones no capturadas).
Future<ConexionWs> abrir(Uri uri, {required Duration limite, Duration? intervaloPing}) async {
  final cliente = HttpClient()..connectionTimeout = limite;
  final conectando = WebSocket.connect(uri.toString(), customClient: cliente);
  try {
    final socket = await conectando.timeout(limite);
    socket.pingInterval = intervaloPing;
    return _ConexionIo(socket);
  } on TimeoutException {
    // Si conecta tarde, se cierra en cuanto llegue: ya nadie la espera.
    unawaited(conectando.then((s) => s.close(WebSocketStatus.normalClosure), onError: (Object _) => null));
    throw const ErrorConexionWs(tiempoAgotado: true);
  } on WebSocketException catch (e) {
    // El mensaje lleva la URL: solo se guarda el código HTTP.
    throw ErrorConexionWs(codigoHttp: e.httpStatusCode);
  } catch (_) {
    // SocketException, HandshakeException, HttpException…
    throw const ErrorConexionWs();
  } finally {
    cliente.close();
  }
}

class _ConexionIo implements ConexionWs {
  _ConexionIo(this._socket) {
    _socket.listen(
      (dato) {
        if (dato is String) {
          _textos.add(dato);
        } else if (dato is List<int>) {
          _textos.add(utf8.decode(dato, allowMalformed: true));
        }
      },
      onError: (Object _) {
        if (!_textos.isClosed) _textos.addError(const ErrorConexionWs());
      },
      onDone: () => unawaited(_textos.close()),
      cancelOnError: false,
    );
  }

  final WebSocket _socket;
  final _textos = StreamController<String>();

  @override
  Stream<String> get textos => _textos.stream;

  @override
  int? get codigoCierre => _socket.closeCode;

  @override
  void enviar(String texto) {
    if (_socket.readyState != WebSocket.open) throw StateError('La conexión está cerrada');
    _socket.add(texto);
  }

  @override
  Future<void> cerrar() async {
    try {
      // close() espera la respuesta del servidor: no se espera aquí.
      unawaited(_socket.close(WebSocketStatus.normalClosure).then((_) {}, onError: (Object _) {}));
    } catch (_) {
      // Ya cerrada.
    }
  }
}
