// Cuándo se mueven las animaciones en reposo de SpritePixel y EscenaPixel (interno del motor: no se exporta).
import 'package:flutter/widgets.dart';

import '../../tema.dart' show duracion;
import 'reloj_pixel.dart';

/// Pone [reloj] en marcha si algo lo deja moverse y, si no, lo para:
///
/// - con [animar] a false o «reducir animaciones», quieto en la pose de descanso;
/// - en una ruta tapada por otra (`TickerMode`) o con la app en segundo plano, parado donde está.
void ponerEnMarcha(BuildContext context, RelojPixel? reloj, {required bool animar}) {
  if (reloj == null) return;
  if (!animar || duracion(context, const Duration(seconds: 1)) == Duration.zero) {
    reloj.reposo();
  } else if (TickerMode.valuesOf(context).enabled && appVisible()) {
    reloj.arrancar();
  } else {
    reloj.parar();
  }
}

/// Si la app se ve: en primer plano o tapada un momento (inactiva), no en segundo plano. En segundo plano no se dibuja
/// nada, así que un reloj en marcha solo despertaría a la app en cada cambio de fotograma.
bool appVisible() => switch (WidgetsBinding.instance.lifecycleState) {
  null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
  AppLifecycleState.hidden || AppLifecycleState.paused || AppLifecycleState.detached => false,
};
