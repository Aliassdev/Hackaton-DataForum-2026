import 'conexion_ws_io.dart' if (dart.library.js_interop) 'conexion_ws_web.dart' as plataforma;

// La conexión WebSocket del agente de voz, sin SDK. En Android, con dart:io: tiempo límite al conectar y ping del
// protocolo cada pocos segundos, para notar enseguida una conexión muerta (por ejemplo, al pasar de wifi a datos). En
// la web, con el WebSocket del navegador (package:web_socket). En los tests se sustituye por una falsa.

/// Una conexión WebSocket abierta.
abstract interface class ConexionWs {
  /// Los mensajes de texto que llegan. Se cierra cuando se cierra la conexión; si se corta por la red, antes llega un
  /// error ([ErrorConexionWs]).
  Stream<String> get textos;

  /// El código de cierre del servidor (1000, 1006…), cuando la conexión ya se ha cerrado. null si no lo hay.
  int? get codigoCierre;

  /// Lanza una excepción si la conexión ya está cerrada.
  void enviar(String texto);

  /// Cierra la conexión con el código 1000. No espera a que el servidor conteste.
  Future<void> cerrar();
}

/// Abre la conexión con [uri] (wss://…). Si no se puede, lanza [ErrorConexionWs].
typedef AbrirConexionWs = Future<ConexionWs> Function(Uri uri);

/// No se ha podido conectar o se ha cortado. Nunca lleva la URL: tiene el agent_id o la firma de la sesión.
class ErrorConexionWs implements Exception {
  const ErrorConexionWs({this.codigoHttp, this.codigoCierre, this.tiempoAgotado = false});

  /// El código HTTP si el servidor no aceptó la conexión (401, 403, 404…).
  final int? codigoHttp;

  /// El código de cierre si el servidor cerró antes de empezar la conversación.
  final int? codigoCierre;
  final bool tiempoAgotado;

  @override
  String toString() =>
      'ErrorConexionWs(http: $codigoHttp, cierre: $codigoCierre${tiempoAgotado ? ', tiempo agotado' : ''})';
}

/// La conexión de verdad: dart:io en Android y el WebSocket del navegador en la web.
///
/// [limite] es lo que se espera a que se abra. [intervaloPing] (solo en Android) es cada cuánto se manda un ping del
/// protocolo WebSocket si no llega nada: sin pong antes del siguiente, la conexión se da por muerta y se cierra (1001).
Future<ConexionWs> abrirConexionWs(
  Uri uri, {
  Duration limite = const Duration(seconds: 6),
  Duration? intervaloPing = const Duration(seconds: 5),
}) => plataforma.abrir(uri, limite: limite, intervaloPing: intervaloPing);
