import 'package:flutter/services.dart';

// «Salir rápido» en Android (y en escritorio): lo importa lib/core/salida_rapida.dart cuando no es la web.

/// Cierra la actividad de TuTurno y el móvil vuelve a lo que había debajo (normalmente, la pantalla de inicio). La
/// tarea sigue en «recientes», pero su miniatura es la pantalla neutra, y al volver a abrirla TuTurno arranca desde
/// el principio. En iPhone no hace nada (Apple no deja cerrar las apps): allí se usa la versión web.
Future<void> salirDeTuTurno() => SystemNavigator.pop();
