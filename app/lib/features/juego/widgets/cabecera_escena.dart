import 'package:flutter/material.dart';

import '../../../pixel/escenarios/escenarios.dart';
import '../../../pixel/escenas/escenas.dart';
import '../../../pixel/motor/motor.dart';
import '../../../pixel/personajes/personajes.dart';
import '../../../pixel/ui/ui.dart';
import '../modelos.dart';
import 'estilo.dart';

// La ilustración de cada escena, en pixel art: el lugar (lib/pixel/escenarios) con las personas que salen
// (lib/pixel/personajes), enmarcado como la pantalla de un juego (EscenaCasoPixel, de lib/pixel/escenas). Debajo, las
// fichas de quién sale, con su retrato: sirven a quien no distingue los dibujos y al lector de pantalla.
//
// [CabeceraEscena] es la misma pieza en el reproductor del caso (arriba de cada escena) y en la portada de cada caso
// en la lista (versión compacta, sin fichas).

/// Posesivos con los que el contenido nombra a la familia y a quien acompaña («Su madre», «Sus padres», «Su
/// abogada»). Dicho así, el nombre no dice de quién es; el caso, sí: en el de Sara, «Su madre» es la madre de Sara.
final _posesivo = RegExp(r'^(su|sus)\s', caseSensitive: false);

/// [nombre] (uno de `escena.personajes`) tal como lo busca el pixel art: con el posesivo aclarado por [protagonista]
/// («Su madre» en el caso de Sara → «Su madre de Sara»). Así [PersonajesPixel.buscar] encuentra a la madre de Sara y no
/// a la de Sergio. Solo cambia lo que se busca; en pantalla y para el lector de pantalla se ve el nombre del contenido.
String nombreParaPixel(String nombre, String protagonista) {
  final limpio = nombre.trim();
  if (protagonista.isEmpty || !_posesivo.hasMatch(limpio)) return limpio;
  return '$limpio de $protagonista';
}

/// La tabla de los nombres del contenido a los personajes pixel: los ids de [PersonajesPixel] de [nombre] en [lugar]
/// (dos para «Sus padres»; en la Fiscalía, el fiscal y la abogada sin toga), con el posesivo aclarado por
/// [protagonista]. Vacía si no hay dibujo: esa persona no sale en la escena, pero sí en las fichas.
List<String> idsPersonaje(String nombre, {required String lugar, String protagonista = ''}) =>
    PersonajesPixel.buscarTodos(nombreParaPixel(nombre, protagonista), lugar: lugar);

/// Ilustración de una escena: el lugar y quién sale, en pixel art.
///
/// Con [compacta], la portada del caso en la lista: la escena llena el sitio que le den (por defecto, [altoCompacta]
/// de alto), quieta, sin fichas y sin semántica propia (la tarjeta del caso ya lo dice todo).
class CabeceraEscena extends StatelessWidget {
  const CabeceraEscena({
    super.key,
    required this.escena,
    this.protagonista = '',
    this.compacta = false,
    this.animar = true,
    this.conFichas = true,
  });

  final Escena escena;

  /// Su ficha va destacada, y aclara de quién es la familia («Su madre»).
  final String protagonista;
  final bool compacta;

  /// Las animaciones en reposo de los personajes (respirar, parpadear). Respetan siempre «reducir animaciones».
  final bool animar;

  /// Con las fichas de quién sale debajo. Sin ellas, la escena sola (el reproductor la deja fija arriba y pone las
  /// fichas, con [FichasPersonajes], en lo que se desplaza).
  final bool conFichas;

  /// Alto de la portada del caso.
  static const altoCompacta = 148.0;

  /// Alto aproximado de la escena en el reproductor en un móvil (lo justo para su escala entera: unos 180 puntos con
  /// 390 de ancho).
  static const altoMinimo = 176.0;

  @override
  Widget build(BuildContext context) {
    final nombres = [for (final p in escena.personajes) nombreParaPixel(p, protagonista)];
    if (compacta) {
      return SizedBox(
        height: altoCompacta,
        child: EscenaCasoPixel(lugar: escena.lugar, personajes: nombres, compacta: true),
      );
    }
    final lugar = Lugar.desde(escena.lugar);
    final escenario = EscenariosPixel.de(escena.lugar);
    final u = unidadPixel(context);
    final imagen = Semantics(
      container: true,
      image: true,
      label: '${lugar.nombre}. ${escenario.descripcion}',
      excludeSemantics: true,
      child: EscenaCasoPixel(lugar: escena.lugar, personajes: nombres, animar: animar),
    );
    if (!conFichas || escena.personajes.isEmpty) return imagen;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        imagen,
        SizedBox(height: 3 * u),
        FichasPersonajes(nombres: escena.personajes, lugar: escena.lugar, protagonista: protagonista),
      ],
    );
  }
}

/// Las fichas de quién sale en una escena: el retrato pixel de cada persona (si tiene dibujo) y su nombre, tal como lo
/// dice el contenido. La protagonista va en amarillo. El lector de pantalla las lee juntas: «En esta escena: Lucía y
/// Ana, la psicóloga».
class FichasPersonajes extends StatelessWidget {
  const FichasPersonajes({super.key, required this.nombres, required this.lugar, this.protagonista = ''});

  final List<String> nombres;
  final String lugar;
  final String protagonista;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    return Semantics(
      container: true,
      label: 'En esta escena: ${listaNatural(nombres)}',
      excludeSemantics: true,
      child: Wrap(
        spacing: 2 * u,
        runSpacing: 2 * u,
        children: [
          for (final nombre in nombres)
            _Ficha(
              nombre: nombre,
              ids: idsPersonaje(nombre, lugar: lugar, protagonista: protagonista),
              protagonista: nombre == protagonista,
            ),
        ],
      ),
    );
  }
}

class _Ficha extends StatelessWidget {
  const _Ficha({required this.nombre, required this.ids, required this.protagonista});

  final String nombre;
  final List<String> ids;
  final bool protagonista;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final retratos = [for (final id in ids) ?PersonajesPixel.retrato(id)];
    return CajaPixel(
      estilo: protagonista
          ? const EstiloCajaPixel(
              relleno: ColoresUiPixel.amarillo,
              luz: ColoresUiPixel.amarilloLuz,
              sombraInterior: ColoresUiPixel.ocre,
              esquina: 1,
            )
          : const EstiloCajaPixel(
              relleno: ColoresUiPixel.papel,
              luz: ColoresUiPixel.blanco,
              sombraInterior: ColoresUiPixel.crema,
              esquina: 1,
            ),
      interior: EdgeInsets.fromLTRB(retratos.isEmpty ? 3 : 1, 1, 3, 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final retrato in retratos) SpritePixel(sprite: retrato, alto: 10 * u, ancho: 12 * u, animar: false),
          if (retratos.isNotEmpty) SizedBox(width: u),
          Flexible(
            child: TextoPixel(nombre, tipo: TipoTextoPixel.etiqueta, color: ColoresUiPixel.noche),
          ),
        ],
      ),
    );
  }
}
