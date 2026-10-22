import 'package:shared_preferences/shared_preferences.dart';

import 'ajustes.dart';

/// Lo que se guarda en el dispositivo (shared_preferences). Nada de esto sale del móvil.
class Storage {
  Storage(this._prefs);

  final SharedPreferences _prefs;

  static const _bienvenida = 'bienvenida_vista';
  static const _tamanoTexto = 'ajustes.tamano_texto';
  static const _voz = 'ajustes.voz_activada';
  static const _velocidadVoz = 'ajustes.velocidad_voz';
  static const _apiUrl = 'ajustes.api_url';
  static const _lecturaFacil = 'ajustes.lectura_facil';
  static const _reducirMovimiento = 'ajustes.reducir_movimiento';

  bool get bienvenidaVista => _prefs.getBool(_bienvenida) ?? false;

  Future<void> marcarBienvenidaVista() => _prefs.setBool(_bienvenida, true);

  /// Para el modo DEMO: vuelve a enseñar la bienvenida (p. ej., antes del pitch).
  Future<void> desmarcarBienvenidaVista() => _prefs.remove(_bienvenida);

  Ajustes leerAjustes() => Ajustes(
    tamanoTexto: _prefs.getDouble(_tamanoTexto) ?? 1.0,
    vozActivada: _prefs.getBool(_voz) ?? true,
    velocidadVoz: _prefs.getDouble(_velocidadVoz) ?? 0.5,
    apiUrlManual: _prefs.getString(_apiUrl),
    lecturaFacil: _prefs.getBool(_lecturaFacil) ?? false,
    reducirMovimiento: _prefs.getBool(_reducirMovimiento) ?? false,
  );

  Future<void> guardarAjustes(Ajustes ajustes) async {
    await _prefs.setDouble(_tamanoTexto, ajustes.tamanoTexto);
    await _prefs.setBool(_voz, ajustes.vozActivada);
    await _prefs.setDouble(_velocidadVoz, ajustes.velocidadVoz);
    await _prefs.setBool(_lecturaFacil, ajustes.lecturaFacil);
    await _prefs.setBool(_reducirMovimiento, ajustes.reducirMovimiento);
    final url = ajustes.apiUrlManual?.trim();
    if (url == null || url.isEmpty) {
      await _prefs.remove(_apiUrl);
    } else {
      await _prefs.setString(_apiUrl, url);
    }
  }
}
