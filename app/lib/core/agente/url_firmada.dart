import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

// La URL firmada de la sesión (docs/ARQUITECTURA.md, sección 8.5): `GET {API_URL}/api/session/signed-url` →
// `{"signed_url": "wss://…"}`. El backend la pide a ElevenLabs con su API key; así la APK no necesita el agent_id
// (y el agente puede ser privado). ElevenLabs dice que vale 15 minutos para empezar conversaciones y que se puede
// reutilizar: se guarda unos minutos para que reconectar no tenga que pasar por el backend.

/// No se ha podido conseguir la URL firmada. Nunca lleva la URL.
class ErrorUrlFirmada implements Exception {
  const ErrorUrlFirmada(this.motivo, {this.codigoHttp});

  final String motivo;
  final int? codigoHttp;

  @override
  String toString() => 'ErrorUrlFirmada($motivo${codigoHttp == null ? '' : ', HTTP $codigoHttp'})';
}

/// Pide la URL firmada al backend en [apiUrl] y la devuelve ya comprobada (wss://, o ws:// en local).
Future<Uri> pedirUrlFirmada(http.Client cliente, String apiUrl, {required Duration limite}) async {
  final base = apiUrl.trim().replaceFirst(RegExp(r'/+$'), '');
  final uri = Uri.tryParse('$base/api/session/signed-url');
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) {
    throw const ErrorUrlFirmada('API_URL no válida');
  }
  final http.Response respuesta;
  try {
    respuesta = await cliente.get(uri, headers: const {'Accept': 'application/json'}).timeout(limite);
  } on TimeoutException {
    throw const ErrorUrlFirmada('tiempo agotado');
  } catch (_) {
    throw const ErrorUrlFirmada('sin conexión');
  }
  if (respuesta.statusCode != 200) throw ErrorUrlFirmada('respuesta', codigoHttp: respuesta.statusCode);
  Object? json;
  try {
    json = jsonDecode(utf8.decode(respuesta.bodyBytes));
  } on FormatException {
    json = null;
  }
  final texto = json is Map ? json['signed_url'] : null;
  final firmada = texto is String ? Uri.tryParse(texto.trim()) : null;
  if (firmada == null || !(firmada.isScheme('wss') || firmada.isScheme('ws')) || firmada.host.isEmpty) {
    throw const ErrorUrlFirmada('sin signed_url');
  }
  return firmada;
}

/// De dónde saca el agente la URL firmada: la guardada si aún vale y, si no, una nueva del backend en [apiUrl].
class FuenteUrlFirmada {
  FuenteUrlFirmada({required this.apiUrl, required this.pedir, required this.cache});

  final String apiUrl;

  /// Pide una URL nueva al backend, con ese tiempo límite.
  final Future<Uri> Function(Duration limite) pedir;
  final CacheUrlFirmada cache;

  Uri? guardada() => cache.vigente(apiUrl);

  Future<Uri> nueva(Duration limite) async {
    final url = await pedir(limite);
    cache.guardar(apiUrl, url);
    return url;
  }

  void olvidar() => cache.olvidar();
}

/// La última URL firmada, para reutilizarla mientras sea [vigencia] (menos que los 15 minutos de ElevenLabs). Vive lo
/// que la app: así vale también al volver a entrar en Pregunta.
class CacheUrlFirmada {
  CacheUrlFirmada({DateTime Function()? reloj, this.vigencia = const Duration(minutes: 10)})
    : _reloj = reloj ?? DateTime.now;

  final DateTime Function() _reloj;
  final Duration vigencia;
  Uri? _url;
  String? _apiUrl;
  DateTime? _obtenida;

  /// La URL guardada si es de [apiUrl] y aún vale; si no, null.
  Uri? vigente(String apiUrl) {
    final url = _url;
    final obtenida = _obtenida;
    if (url == null || obtenida == null || _apiUrl != apiUrl) return null;
    final edad = _reloj().difference(obtenida);
    return edad.isNegative || edad >= vigencia ? null : url;
  }

  void guardar(String apiUrl, Uri url) {
    _url = url;
    _apiUrl = apiUrl;
    _obtenida = _reloj();
  }

  /// Si la conexión con la URL guardada falla, se pide otra la próxima vez.
  void olvidar() {
    _url = null;
    _apiUrl = null;
    _obtenida = null;
  }
}
