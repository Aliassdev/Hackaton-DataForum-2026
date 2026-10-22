import 'package:flutter/material.dart';

import '../../core/texto.dart';
import '../../pixel/motor/motor.dart' show SpritePixel;
import '../../pixel/personajes/personajes.dart';
import '../../tema.dart';

// «Quién estará», con los personajes de «Vive el caso»: la persona que conociste en el juego (Ana, la psicóloga; Laura,
// la coordinadora; la jueza…) al lado de quien estará en tu paso. Fidelidad de la capa justicia (tema-justicia.md, §2):
// la toga solo se lleva en estrados (Reglamento 2/2005 del CGPJ, art. 33), así que fuera de la sala el fiscal y la
// abogada salen sin toga, y la jueza y el abogado defensor (que solo tienen dibujo con toga) no salen. Nunca se dibuja
// a la persona investigada ni a la víctima.

/// Un personaje de «Vive el caso» para quien está en un paso: el [id] de su retrato y [como], la frase que lo une al
/// juego («Como Ana, la psicóloga del caso de Lucía»).
typedef PersonajePaso = ({String id, String como});

/// Palabras (sin tildes) que dicen quién es cada persona. Manda la que sale antes, como en el icono de la persona.
const _claves = <(String, List<String>)>[
  ('psicologa', ['psicolog', 'psicosocial', 'equipo tecnico']),
  ('coordinadora', ['coordinador', 'bienestar']),
  ('juez', ['juez', 'jueza', 'tribunal']),
  ('fiscal', ['fiscal']),
  ('abogado', ['abogad']),
  ('letrada', ['administracion de justicia']),
  ('policia', ['polic', 'guardia civil', 'agente']),
  ('padres', ['padres', 'madre', 'padre']),
  ('confianza', ['confianza', 'familia']),
  // Sin personaje: se quedan con su icono.
  ('ninguno', ['victima', 'investigad', 'acusad', 'mediador', 'servicios sociales', 'trabajador', 'represent']),
];

/// El personaje de «Vive el caso» para [persona] (un elemento de «Quién estará»), o null si no hay uno que le pegue.
/// [enSala]: el paso es en estrados (con toga). [acompanantes]: con quién irá, según «Tu ticket» ('familia',
/// 'confianza'…): a quien irá con su familia (y no con otra persona de confianza), la familia o el adulto de confianza
/// se le dibuja con los padres de Sergio, no con Elena, la tía de Lucía.
PersonajePaso? personajeDePersona(String persona, {bool enSala = false, Set<String> acompanantes = const {}}) {
  final texto = normalizar(persona);
  String? clave;
  int? primera;
  for (final (candidata, palabras) in _claves) {
    for (final palabra in palabras) {
      final posicion = texto.indexOf(palabra);
      if (posicion >= 0 && (primera == null || posicion < primera)) {
        primera = posicion;
        clave = candidata;
      }
    }
  }
  switch (clave) {
    case 'psicologa':
      return (id: 'ana', como: 'Como Ana, la psicóloga del caso de Lucía');
    case 'coordinadora':
      return (id: 'laura', como: 'Como Laura, la coordinadora del caso de Sergio');
    case 'juez':
      return enSala ? (id: 'jueza', como: 'Como la jueza de «Vive el caso»') : null;
    case 'fiscal':
      return (id: enSala ? 'fiscal' : 'fiscal-despacho', como: 'Como el fiscal de «Vive el caso»');
    case 'abogado':
      // El de la persona investigada (o el tuyo si te investigan) es el defensor: solo tiene dibujo con toga.
      final defensa = ['investigad', 'acusad', 'defiend', 'defens'].any(texto.contains);
      if (defensa) return enSala ? (id: 'abogado-defensa', como: 'Como el abogado defensor de «Vive el caso»') : null;
      return (id: enSala ? 'abogada-victima' : 'abogada-despacho', como: 'Como la abogada de Sara en «Vive el caso»');
    case 'letrada':
      return enSala ? (id: 'letrada', como: 'Como la letrada de «Vive el caso»') : null;
    case 'policia':
      return (id: 'policia', como: 'Como el agente que recibe a Sara en «Vive el caso»');
    case 'padres':
      return (id: 'madre-sergio', como: 'Como los padres de Sergio en «Vive el caso»');
    case 'confianza':
      if (acompanantes.contains('familia') && !acompanantes.contains('confianza')) {
        return (id: 'madre-sergio', como: 'Como los padres de Sergio en «Vive el caso»');
      }
      return (id: 'elena', como: 'Como Elena, la tía de Lucía');
    default:
      return null;
  }
}

/// El retrato pixel (cabeza y hombros) de un personaje de «Vive el caso», quieto y en un marco de papel. Es decorativo:
/// el texto de al lado ya dice quién es.
class RetratoPersonaje extends StatelessWidget {
  const RetratoPersonaje({super.key, required this.id, this.tamano = Espacio.xxl});

  final String id;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final retrato = PersonajesPixel.retrato(id);
    if (retrato == null) return SizedBox.square(dimension: tamano);
    final esquema = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          // El cielo del pixel art: el mismo azul claro en los dos temas, para que los colores del dibujo no cambien.
          color: ColoresMarca.azulHielo,
          borderRadius: BorderRadius.circular(Radios.s),
          border: Border.all(color: esquema.outline, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.bottomCenter,
        child: SpritePixel(sprite: retrato, alto: tamano, animar: false, alineacion: Alignment.bottomCenter),
      ),
    );
  }
}
