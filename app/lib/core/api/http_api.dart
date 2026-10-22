import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'tuturno_api.dart';

/// Implementación real de [TuTurnoApi] contra el backend FastAPI.
class HttpTuTurnoApi implements TuTurnoApi {
  HttpTuTurnoApi({required String baseUrl, http.Client? client, this.timeout = const Duration(seconds: 20)})
    : _baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  /// El agente puede hacer una segunda pasada («más sencillo»), así que se deja margen.
  final Duration timeout;

  static const _headers = {'Content-Type': 'application/json; charset=utf-8', 'Accept': 'application/json'};

  @override
  Future<AskResponse> ask(AskRequest request) async =>
      _parsear(await _enviar('/api/agent/ask', request.toJson()), AskResponse.fromJson);

  @override
  Future<GradeResponse> grade(GradeRequest request) async =>
      _parsear(await _enviar('/api/learn/grade', request.toJson()), GradeResponse.fromJson);

  @override
  Future<HealthResponse> health() async => _parsear(await _enviar('/api/health'), HealthResponse.fromJson);

  void close() => _client.close();

  /// POST si hay [cuerpo]; GET si no.
  ///
  /// Códigos propios: SIN_API_URL, URL_INVALIDA, TIEMPO_AGOTADO, SIN_CONEXION y RESPUESTA_INVALIDA.
  /// Si el backend responde con error sin el formato de la sección 8.4: `HTTP_` y el código de estado.
  Future<Map<String, dynamic>> _enviar(String ruta, [Map<String, dynamic>? cuerpo]) async {
    if (_baseUrl.isEmpty) {
      throw const ApiException('SIN_API_URL', ApiException.mensajeSeguro);
    }
    // La URL de Ajustes se escribe a mano y puede llegar sin http(s):// («192.168.1.20:8000»). Sin esta
    // comprobación, Uri.parse o el cliente lanzarían FormatException o ArgumentError en vez de ApiException.
    final uri = Uri.tryParse('$_baseUrl$ruta');
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) {
      throw const ApiException('URL_INVALIDA', ApiException.mensajeSeguro);
    }
    final http.Response res;
    try {
      final peticion = cuerpo == null
          ? _client.get(uri, headers: _headers)
          : _client.post(uri, headers: _headers, body: jsonEncode(cuerpo));
      res = await peticion.timeout(timeout);
    } on TimeoutException {
      throw const ApiException('TIEMPO_AGOTADO', ApiException.mensajeSeguro);
    } catch (_) {
      // ClientException, SocketException, HandshakeException… o cualquier otro fallo del cliente.
      throw const ApiException('SIN_CONEXION', ApiException.mensajeSeguro);
    }

    // El backend responde en UTF-8 aunque no lo indique en la cabecera: res.body usaría latin1.
    Object? json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      json = null;
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException.desdeRespuesta(json, statusCode: res.statusCode);
    }
    if (json is! Map<String, dynamic>) {
      throw const ApiException('RESPUESTA_INVALIDA', ApiException.mensajeSeguro);
    }
    return json;
  }

  T _parsear<T>(Map<String, dynamic> json, T Function(Map<String, dynamic>) desdeJson) {
    try {
      return desdeJson(json);
    } catch (_) {
      throw const ApiException('RESPUESTA_INVALIDA', ApiException.mensajeSeguro);
    }
  }
}
