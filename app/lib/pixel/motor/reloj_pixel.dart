import 'dart:async';

import 'package:flutter/foundation.dart';

import 'sprite.dart';

/// Reloj de las animaciones en reposo de uno o varios sprites. Lleva el paso de cada animación y avisa a quien escucha
/// solo cuando cambia algo que se ve (el fotograma o el desplazamiento).
///
/// Funciona con un [Timer] hasta el siguiente cambio, no con un fotograma de pantalla en cada vsync: un parpadeo cada
/// pocos segundos cuesta dos repintados, no sesenta por segundo, y `pumpAndSettle` no se queda esperando en las
/// pruebas de las pantallas que lo usan. Se para con [parar] o [dispose].
class RelojPixel extends ChangeNotifier {
  /// [desfasesMs] adelanta cada animación esos milisegundos, para que los personajes de una escena no parpadeen a la
  /// vez.
  RelojPixel(List<AnimacionPixel?> animaciones, {List<int>? desfasesMs})
    : assert(desfasesMs == null || desfasesMs.length == animaciones.length),
      // Una animación sin pasos cuenta como ninguna.
      _animaciones = List.unmodifiable([
        for (final animacion in animaciones) animacion?.descanso == null ? null : animacion,
      ]),
      _paso = List.filled(animaciones.length, 0),
      _restante = [for (final animacion in animaciones) animacion?.descanso?.ms ?? 0],
      _desfases = desfasesMs == null ? null : List.unmodifiable(desfasesMs);

  /// Cuántos relojes están en marcha (para comprobar en las pruebas que todos se paran).
  @visibleForTesting
  static int debugEnMarcha = 0;

  final List<AnimacionPixel?> _animaciones;
  final List<int> _paso;
  final List<int> _restante;
  final List<int>? _desfases;
  Timer? _temporizador;
  var _espera = 0;

  /// Los desfases se aplican al arrancar: con «reducir animaciones» todos se quedan en la pose de descanso.
  var _desfasar = true;

  /// Cuántas animaciones lleva.
  int get length => _animaciones.length;

  /// Si alguna animación cambia con el tiempo.
  bool get seMueve => _animaciones.any((animacion) => animacion != null && animacion.seMueve);

  bool get enMarcha => _temporizador != null;

  /// El paso que se ve ahora de la animación [i], o null si no tiene animación.
  PasoPixel? paso(int i) => _animaciones[i]?.pasos[_paso[i]];

  /// El fotograma que se ve ahora de la animación [i] (0 si no tiene animación).
  int fotograma(int i) => paso(i)?.fotograma ?? 0;

  /// El desplazamiento vertical de ahora de la animación [i], en píxeles del dibujo.
  int dy(int i) => paso(i)?.dy ?? 0;

  /// Pone el reloj en marcha (si algo se mueve y no estaba ya en marcha).
  void arrancar() {
    if (_temporizador != null || !seMueve) return;
    debugEnMarcha++;
    final cambia = _desfasar && _aplicarDesfases();
    _desfasar = false;
    _programar();
    if (cambia) notifyListeners();
  }

  /// Lo para donde está.
  void parar() {
    final temporizador = _temporizador;
    if (temporizador == null) return;
    temporizador.cancel();
    _temporizador = null;
    debugEnMarcha--;
  }

  /// Lo para y vuelve a la pose de descanso (el primer paso de cada animación), como con «reducir animaciones».
  void reposo() {
    parar();
    var cambia = false;
    for (var i = 0; i < length; i++) {
      final animacion = _animaciones[i];
      if (animacion == null) continue;
      if (animacion.pasos[_paso[i]] != animacion.pasos.first) cambia = true;
      _paso[i] = 0;
      _restante[i] = animacion.pasos.first.ms;
    }
    _desfasar = true;
    if (cambia) notifyListeners();
  }

  @override
  void dispose() {
    parar();
    super.dispose();
  }

  /// Adelanta cada animación su desfase. Devuelve si cambia lo que se ve.
  bool _aplicarDesfases() {
    final desfases = _desfases;
    if (desfases == null) return false;
    var cambia = false;
    for (var i = 0; i < length; i++) {
      final animacion = _animaciones[i];
      final desfase = animacion == null || !animacion.seMueve ? 0 : desfases[i] % animacion.duracionMs;
      if (desfase > 0 && _avanzar(i, desfase)) cambia = true;
    }
    return cambia;
  }

  void _programar() {
    var espera = -1;
    for (var i = 0; i < length; i++) {
      final animacion = _animaciones[i];
      if (animacion == null || !animacion.seMueve) continue;
      if (espera < 0 || _restante[i] < espera) espera = _restante[i];
    }
    _espera = espera < 1 ? 1 : espera;
    _temporizador = Timer(Duration(milliseconds: _espera), _tic);
  }

  void _tic() {
    var cambia = false;
    for (var i = 0; i < length; i++) {
      final animacion = _animaciones[i];
      if (animacion == null || !animacion.seMueve) continue;
      if (_avanzar(i, _espera)) cambia = true;
    }
    _programar();
    if (cambia) notifyListeners();
  }

  /// Avanza [ms] la animación [i]. Devuelve si cambia lo que se ve.
  bool _avanzar(int i, int ms) {
    final pasos = _animaciones[i]!.pasos;
    final antes = pasos[_paso[i]];
    var paso = _paso[i];
    var restante = _restante[i] - ms;
    while (restante <= 0) {
      paso = (paso + 1) % pasos.length;
      restante += pasos[paso].ms;
    }
    _paso[i] = paso;
    _restante[i] = restante;
    final ahora = pasos[paso];
    return ahora.fotograma != antes.fotograma || ahora.dy != antes.dy;
  }
}
