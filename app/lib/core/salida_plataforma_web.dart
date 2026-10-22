import 'dart:js_interop';

// «Salir rápido» en la web: lo importa lib/core/salida_rapida.dart con `dart.library.js_interop`.

/// Página neutra a la que se va la pestaña.
const paginaNeutraWeb = 'https://www.google.com/';

@JS('location')
external _Ubicacion get _ubicacion;

extension type _Ubicacion._(JSObject _) implements JSObject {
  external void replace(String url);
}

/// Cambia la pestaña a una página neutra con `location.replace`. En la web, toda la app ocupa una sola entrada del
/// historial de la pestaña (el router va con `routerNeglect`, lib/app.dart), así que esa entrada pasa a ser la página
/// neutra y «atrás» no vuelve a TuTurno. Lo que sí queda es la visita en el historial del navegador: por eso Ayuda
/// recomienda, en la web, la ventana privada.
Future<void> salirDeTuTurno() async => _ubicacion.replace(paginaNeutraWeb);
