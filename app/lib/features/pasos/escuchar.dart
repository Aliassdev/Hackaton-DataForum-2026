import '../../core/voz/tts.dart' show textoParaVoz;
import 'modelos.dart';
import 'personalizacion_linea.dart';

// «Escuchar este paso» (plan v2, producto §5.2): lo que se lee en voz alta de un paso. Todo lo que se oye también está
// escrito en la tarjeta.

/// Lo que se lee al tocar «Escuchar este paso»: el nombre, qué pasa, lo que cambia para ti, quién estará y qué puedes
/// pedir. Sin las referencias a fuentes ([A-017]), que no se leen.
String textoParaEscuchar(Paso paso, {ExtrasPaso? extras}) {
  final partes = <String>[
    paso.nombre,
    if (paso.quePasa.isNotEmpty) paso.quePasa,
    for (final nota in extras?.paraTi ?? const <NotaParaTi>[]) 'Para ti: ${nota.texto}',
    if (paso.quienEsta.isNotEmpty) 'Quién estará: ${paso.quienEsta.join('; ')}',
    if (paso.quePuedesPedir.isNotEmpty) 'Qué puedes pedir: ${paso.quePuedesPedir.join('; ')}',
  ];
  return textoParaVoz(partes.map(_conPunto).join(' '));
}

/// Termina en punto (o en otro signo de cierre), para que la voz haga una pausa entre una parte y otra.
String _conPunto(String texto) {
  final limpio = texto.trim();
  if (limpio.isEmpty) return limpio;
  return RegExp(r'[.!?…:»)]$').hasMatch(limpio) ? limpio : '$limpio.';
}
