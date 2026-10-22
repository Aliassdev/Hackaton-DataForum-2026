import 'dart:async';

import 'package:flutter/foundation.dart';

/// El estado «pulsado» de una pieza pixel (un botón, una opción, un ticket o una carta): baja en cuanto llega el dedo
/// y se queda abajo al menos [minimo], aunque el toque sea muy corto.
///
/// Dentro de una lista con scroll, el «abajo» del dedo no llega hasta que se sabe que no es un arrastre (100 ms) y, en
/// un toque rápido, llega a la vez que el «arriba»: sin el mínimo, la pieza no se vería bajar nunca.
///
/// Uso: `bajar` en onTapDown, `soltar` en onTapUp, `cancelar` en onTapCancel y `pulsarYSoltar` con el teclado.
class PulsacionPixel {
  PulsacionPixel(this._alCambiar);

  /// Lo mínimo que se ve una pieza pulsada (lo mismo que con el teclado).
  static const minimo = Duration(milliseconds: 120);

  /// Se llama cuando cambia [pulsada] (normalmente, `() => setState(() {})`).
  final VoidCallback _alCambiar;

  bool _pulsada = false;
  bool _soltada = true;
  Timer? _espera;

  bool get pulsada => _pulsada;

  /// Llega el dedo (o la tecla): la pieza baja.
  void bajar() {
    _espera?.cancel();
    _soltada = false;
    _espera = Timer(minimo, () {
      _espera = null;
      if (_soltada) _poner(false);
    });
    _poner(true);
  }

  /// Se levanta el dedo: la pieza sube en cuanto haya pasado el mínimo.
  void soltar() {
    _soltada = true;
    if (_espera == null) _poner(false);
  }

  /// El toque no sigue (gana el scroll, o la pieza se desactiva): sube ya.
  void cancelar() {
    _espera?.cancel();
    _espera = null;
    _soltada = true;
    _poner(false);
  }

  /// Con el teclado no hay dedo que levantar: baja el mínimo y vuelve sola.
  void pulsarYSoltar() {
    bajar();
    soltar();
  }

  /// Como [cancelar], pero sin avisar (para usarlo dentro de didUpdateWidget, que ya vuelve a construir).
  void reiniciar() {
    _espera?.cancel();
    _espera = null;
    _soltada = true;
    _pulsada = false;
  }

  void dispose() {
    _espera?.cancel();
    _espera = null;
  }

  void _poner(bool valor) {
    if (_pulsada == valor) return;
    _pulsada = valor;
    _alCambiar();
  }
}
