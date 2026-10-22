import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Configuración de arranque (docs/ARQUITECTURA.md, sección 6.7).
class AppConfig {
  const AppConfig({required this.apiUrl, required this.useMock, required this.demo});

  /// URL base del backend. Vacía si no se ha configurado.
  final String apiUrl;

  /// `--dart-define=USE_MOCK=true`: API simulada (y contenido de ejemplo si falta el real).
  final bool useMock;

  /// `--dart-define=DEMO=true`: modo demo.
  final bool demo;

  static const _useMock = bool.fromEnvironment('USE_MOCK');
  static const _demo = bool.fromEnvironment('DEMO');
  static const _apiUrl = String.fromEnvironment('API_URL');

  /// En web, `api_url` se lee de `config.json` (junto a index.html) para poder cambiar la URL
  /// del túnel sin recompilar. Si no existe o está vacío, se usa `--dart-define=API_URL`.
  static Future<AppConfig> load({http.Client? client}) async {
    var apiUrl = _apiUrl;
    if (kIsWeb) {
      apiUrl = await _apiUrlDeConfigJson(client) ?? apiUrl;
    }
    return AppConfig(apiUrl: apiUrl, useMock: _useMock, demo: _demo);
  }

  static Future<String?> _apiUrlDeConfigJson(http.Client? client) async {
    final cliente = client ?? http.Client();
    try {
      // Con la estrategia de URL por defecto (#), Uri.base apunta a la carpeta de index.html.
      final uri = Uri.base
          .resolve('config.json')
          .replace(queryParameters: {'v': '${DateTime.now().millisecondsSinceEpoch}'});
      final res = await cliente.get(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      final url = json is Map<String, dynamic> ? json['api_url'] : null;
      return url is String && url.trim().isNotEmpty ? url.trim() : null;
    } catch (_) {
      return null;
    } finally {
      if (client == null) cliente.close();
    }
  }
}
