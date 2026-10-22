import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../escenarios/escenarios.dart';
import '../motor/motor.dart';
import '../personajes/personajes.dart';
import '../ui/ui.dart' show ColoresUiPixel, MarcoPixel, unidadPixel;

/// Una escena montada a partir del contenido: el lugar con su fondo y las personas en sus sitios, lista para una
/// [EscenaPixel]. La hace [montarEscenaCaso].
@immutable
class MontajeEscenaCaso {
  const MontajeEscenaCaso._({
    required this.escenario,
    required this.elementos,
    required this.ids,
    required this.descripcion,
  });

  /// El lugar (con su fondo, sus muebles de delante y sus puestos).
  final EscenarioPixel escenario;

  /// Las personas y los muebles que tapan, en el orden en que se pintan.
  final List<ElementoEscena> elementos;

  /// Los ids de [PersonajesPixel] de quienes salen, de izquierda a derecha por el orden del contenido.
  final List<String> ids;

  /// Lo que dicen los lectores de pantalla: el lugar y quién sale.
  final String descripcion;
}

/// Monta la escena de [lugar] (el texto del contenido, `escena.lugar`) con las personas de [personajes] (los nombres
/// del contenido, `escena.personajes`):
///
/// - el fondo es el de [EscenariosPixel.de] (con el de reserva si el lugar no tiene);
/// - cada nombre se convierte en sprites con [PersonajesPixel.buscarTodos] («Sus padres» son dos; en la Fiscalía el
///   fiscal va sin toga). Un nombre sin dibujo no sale, pero la escena se monta igual;
/// - quien tiene un puesto con nombre en ese lugar se pone ahí (la jueza en el estrado, el fiscal tras su mesa, en la
///   Sala Gesell la niña en el sofá y la psicóloga en el sillón) y los demás se reparten de izquierda a derecha, en el
///   orden del contenido, lejos de quien está tras un mueble;
/// - los muebles de delante tapan a quien se sienta detrás ([EscenarioPixel.componer]).
///
/// Con [alPulsar], cada persona se puede tocar (su id es el de [PersonajesPixel]); [resaltado] es el id de quien lleva
/// el halo.
MontajeEscenaCaso montarEscenaCaso(String lugar, List<String> personajes, {String? resaltado, bool tocables = false}) {
  final escenario = EscenariosPixel.de(lugar);
  final ids = <String>{for (final nombre in personajes) ...PersonajesPixel.buscarTodos(nombre, lugar: lugar)}.toList();

  // Primero, quien tiene su sitio con nombre en este lugar.
  final puestos = <String, PuntoPixel>{};
  for (final id in ids) {
    final clave = _puestoCon(escenario, id);
    if (clave != null && !puestos.values.contains(escenario.puesto(clave))) puestos[id] = escenario.puesto(clave)!;
  }
  // Los demás, repartidos por los sitios libres.
  final libres = [
    for (final id in ids)
      if (!puestos.containsKey(id)) id,
  ];
  final sitios = _repartir(escenario, libres.length, ocupados: puestos.values.toList());
  for (final (i, id) in libres.indexed) {
    puestos[id] = sitios[i];
  }

  final elementos = escenario.componer([
    for (final id in ids)
      ElementoEscena(
        sprite: PersonajesPixel.porId(id)!,
        x: puestos[id]!.x,
        y: puestos[id]!.y,
        id: tocables ? id : null,
        etiqueta: tocables ? PersonajesPixel.ficha(id)!.descripcion : null,
        resaltado: id == resaltado,
      ),
  ]);
  final quien = _listaNatural(personajes);
  return MontajeEscenaCaso._(
    escenario: escenario,
    elementos: elementos,
    ids: ids,
    descripcion: quien.isEmpty ? escenario.descripcion : '${escenario.descripcion} En esta escena: $quien.',
  );
}

/// El puesto con nombre de [id] en [escenario], si lo tiene.
String? _puestoCon(EscenarioPixel escenario, String id) {
  final clave = switch (id) {
    'jueza' => 'jueza',
    'fiscal' || 'fiscal-despacho' => 'fiscal',
    'abogada-victima' => 'abogada_victima',
    'abogado-defensa' => 'abogado_defensa',
    'letrada' => 'letrada',
    'policia' => 'policia',
    'investigada' => 'persona_investigada',
    'testigo' => 'testigo',
    // En la Sala Gesell, quien declara se sienta en el sofá y la psicóloga, en el sillón.
    'lucia' || 'sergio' || 'sara' => 'sofa',
    'ana' => 'sillon',
    _ => null,
  };
  return clave != null && escenario.puesto(clave) != null ? clave : null;
}

/// [n] sitios en el suelo de [escenario], de izquierda a derecha: uno en el centro; dos, juntos a los lados del centro
/// (como dos personas que hablan); tres, en la izquierda, el centro y la derecha; más, repartidos entre los dos lados.
/// Si hay [ocupados] (alguien tras un mueble), los sitios se eligen lejos de ellos.
List<PuntoPixel> _repartir(EscenarioPixel escenario, int n, {List<PuntoPixel> ocupados = const []}) {
  if (n == 0) return const [];
  final izquierda = escenario.puesto('izquierda')!;
  final centro = escenario.puesto('centro')!;
  final derecha = escenario.puesto('derecha')!;
  PuntoPixel entre(PuntoPixel a, PuntoPixel b, double t) =>
      (x: (a.x + (b.x - a.x) * t).round(), y: (a.y + (b.y - a.y) * t).round());
  if (ocupados.isNotEmpty && n < 3) {
    double distancia(PuntoPixel p) => ocupados.map((o) => (o.x - p.x).abs().toDouble()).reduce(math.min);
    // Una sola persona, en el centro si no está encima de nadie (delante de la mesa del fiscal, por ejemplo).
    if (n == 1 && distancia(centro) >= 24) return [centro];
    final candidatos = [izquierda, centro, derecha]..sort((a, b) => distancia(b).compareTo(distancia(a)));
    return candidatos.take(n).toList()..sort((a, b) => a.x.compareTo(b.x));
  }
  return switch (n) {
    1 => [centro],
    2 => [entre(izquierda, centro, 0.5), entre(centro, derecha, 0.5)],
    3 => [izquierda, centro, derecha],
    _ => [for (var i = 0; i < n; i++) entre(izquierda, derecha, i / (n - 1))],
  };
}

/// «Lucía», «Lucía y Su tutora», «Sergio, Su madre y El fiscal».
String _listaNatural(List<String> nombres) => switch (nombres.length) {
  0 => '',
  1 => nombres.first,
  _ => '${nombres.sublist(0, nombres.length - 1).join(', ')} y ${nombres.last}',
};

/// Una escena del contenido de «Vive el caso» en pixel art, enmarcada como la pantalla de un juego: el sitio para
/// `CabeceraEscena` en el reproductor del caso.
///
/// ```dart
/// EscenaCasoPixel(lugar: escena.lugar, personajes: escena.personajes)
/// ```
///
/// Ocupa el ancho que le den; el marco (`MarcoPixel`) se ajusta a la mayor escala entera de la escena y se centra, sin
/// bandas a los lados, y el alto es el justo. Con [compacta] (la portada de un caso en la lista), sin marco, quieta y
/// sin nada para los lectores de pantalla: llena todo el sitio que le den, como una foto de portada, y lo que no cabe
/// se recorta (sobre todo el techo, para que se vea a las personas). Las animaciones respetan «reducir animaciones».
class EscenaCasoPixel extends StatelessWidget {
  const EscenaCasoPixel({
    super.key,
    required this.lugar,
    required this.personajes,
    this.resaltado,
    this.alPulsar,
    this.compacta = false,
    this.animar = true,
  });

  /// El lugar de la escena, tal como viene en el contenido (`escena.lugar`).
  final String lugar;

  /// Quién sale, tal como viene en el contenido (`escena.personajes`).
  final List<String> personajes;

  /// El id de [PersonajesPixel] de quien lleva el halo (por ejemplo, para señalar a quién tocar).
  final String? resaltado;

  /// Si no es null, cada persona se puede tocar y se llama con su id de [PersonajesPixel].
  final ValueChanged<String>? alPulsar;

  /// La portada de un caso: sin marco, quieta y sin semántica propia.
  final bool compacta;

  final bool animar;

  @override
  Widget build(BuildContext context) {
    final montaje = montarEscenaCaso(lugar, personajes, resaltado: resaltado, tocables: alPulsar != null);
    final fondo = montaje.escenario.fondo;
    if (compacta) {
      final escena = EscenaPixel(
        fondo: fondo,
        elementos: montaje.elementos,
        colorMarco: ColoresUiPixel.noche,
        contorno: false,
        animar: false,
      );
      return ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, limites) {
            if (!limites.hasBoundedWidth || !limites.hasBoundedHeight) return escena;
            // La escala entera más pequeña que llena todo el ancho (sin bandas a los lados: lo que sobra, unas pocas
            // columnas, se recorta a partes iguales) y el alto justo para ella; lo que sobre de alto se recorta, sobre
            // todo por arriba.
            final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
            final fisicos = math.max(1, (limites.maxWidth * dpr / fondo.ancho - 1e-6).ceil());
            final ancho = fondo.ancho * fisicos / dpr;
            return ClipRect(
              child: OverflowBox(
                minWidth: ancho,
                maxWidth: ancho,
                minHeight: 0,
                maxHeight: double.infinity,
                alignment: const Alignment(0, 0.7),
                child: escena,
              ),
            );
          },
        ),
      );
    }
    final escena = EscenaPixel(
      fondo: fondo,
      elementos: montaje.elementos,
      descripcion: montaje.descripcion,
      alPulsar: alPulsar,
      colorMarco: ColoresUiPixel.noche,
      animar: animar,
    );
    return LayoutBuilder(
      builder: (context, limites) {
        if (!limites.hasBoundedWidth) return MarcoPixel(child: escena);
        // El marco, del ancho justo para la escala entera de la escena: sin bandas azules a los lados.
        final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
        final borde = MarcoPixel.grosor * unidadPixel(context);
        final fisicos = math.max(1, ((limites.maxWidth - 2 * borde) * dpr / fondo.ancho + 1e-6).floor());
        final ancho = math.min(limites.maxWidth, fondo.ancho * fisicos / dpr + 2 * borde);
        return Center(
          child: SizedBox(
            width: ancho,
            child: MarcoPixel(child: escena),
          ),
        );
      },
    );
  }
}
