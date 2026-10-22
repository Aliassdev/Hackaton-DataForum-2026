import 'dart:async';
import 'dart:convert';

import 'package:web_socket/web_socket.dart';

import 'conexion_ws.dart';

/// [abrirConexionWs] en la web: el WebSocket del navegador. El navegador no deja mandar pings del protocolo; una
/// conexión muerta se nota cuando el propio navegador la cierra. (En la web, Pregunta va en modo texto: esto solo hace
/// falta para que compile.)
Future<ConexionWs> abrir(Uri uri, {required Duration limite, Duration? intervaloPing}) async {
  final conectando = WebSocket.connect(uri);
  try {
    return _ConexionWeb(await conectando.timeout(limite));
  } on TimeoutException {
    unawaited(conectando.then((s) => s.close(1000), onError: (Object _) => null));
    throw const ErrorConexionWs(tiempoAgotado: true);
  } catch (_) {
    throw const ErrorConexionWs();
  }
}

class _ConexionWeb implements ConexionWs {
  _ConexionWeb(this._socket) {
    _socket.events.listen(
      (evento) {
        switch (evento) {
          case TextDataReceived(:final text):
            _textos.add(text);
          case BinaryDataReceived(:final data):
            _textos.add(utf8.decode(data, allowMalformed: true));
          case CloseReceived(:final code):
            _codigo = code;
            unawaited(_textos.close());
        }
      },
      onError: (Object _) {
        if (!_textos.isClosed) _textos.addError(const ErrorConexionWs());
      },
      onDone: () => unawaited(_textos.close()),
    );
  }

  final WebSocket _socket;
  final _textos = StreamController<String>();
  int? _codigo;

  @override
  Stream<String> get textos => _textos.stream;

  @override
  int? get codigoCierre => _codigo;

  @override
  void enviar(String texto) => _socket.sendText(texto);

  @override
  Future<void> cerrar() async {
    try {
      unawaited(_socket.close(1000).then((_) {}, onError: (Object _) {}));
    } catch (_) {
      // Ya cerrada.
    }
  }
}
