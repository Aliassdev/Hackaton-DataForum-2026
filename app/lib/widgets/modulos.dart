import 'package:flutter/material.dart';

import '../tema.dart';
import 'iconos/iconos.dart';
import 'movimiento/fondo_papel.dart';
import 'movimiento/ticket.dart';

// TicketPulsable vivía aquí: ahora está con el resto de los tickets, y se sigue pudiendo importar desde este fichero.
export 'movimiento/ticket.dart' show TicketPulsable;

/// Ancho máximo del contenido: en tablet o en el navegador las pantallas no se estiran de más.
const anchoMaximo = 640.0;

const _ilustracionNormal = 96.0;
const _ilustracionPequena = 64.0;
const _circuloFondo = 168.0;

/// A partir de este factor de letra, las ilustraciones pasan encima del texto para dejarle todo el ancho.
const _umbralLetraGrande = 1.2;

/// Los tres módulos de TuTurno (sección 4).
enum Modulo {
  juego(
    titulo: 'Vive el caso',
    descripcion: 'Juega un caso y descubre tus derechos.',
    etiqueta: 'Juego',
    ruta: '/juego',
    icono: Icons.sports_esports_rounded,
    insignias: (Icons.style_rounded, Icons.star_rounded),
    tuIcono: TuIcono.juego,
    tuInsignias: (TuIcono.carta, TuIcono.estrella),
  ),
  aprende(
    titulo: 'Aprende',
    descripcion: 'Lecciones cortas para entender tus derechos.',
    etiqueta: 'Lecciones',
    ruta: '/aprende',
    icono: Icons.school_rounded,
    insignias: (Icons.bolt_rounded, Icons.local_fire_department_rounded),
    tuIcono: TuIcono.aprende,
    tuInsignias: (TuIcono.xp, TuIcono.racha),
  ),
  pregunta(
    titulo: 'Pregunta',
    descripcion: 'Pregunta tus dudas a la IA, con texto o con voz.',
    etiqueta: 'Con voz',
    ruta: '/pregunta',
    icono: Icons.record_voice_over_rounded,
    insignias: (Icons.chat_bubble_rounded, Icons.auto_awesome_rounded),
    tuIcono: TuIcono.pregunta,
    tuInsignias: (TuIcono.microfono, TuIcono.idea),
  );

  const Modulo({
    required this.titulo,
    required this.descripcion,
    required this.etiqueta,
    required this.ruta,
    required this.icono,
    required this.insignias,
    required this.tuIcono,
    required this.tuInsignias,
  });

  final String titulo;
  final String descripcion;

  /// Etiqueta corta de la tarjeta («Juego», «Lecciones», «Con voz»).
  final String etiqueta;
  final String ruta;
  final IconData icono;

  /// Iconos pequeños que acompañan al principal en la ilustración.
  final (IconData, IconData) insignias;

  /// Icono propio de TuTurno (lib/widgets/iconos/) y sus insignias: los que se usan en las pantallas nuevas.
  final TuIcono tuIcono;
  final (TuIcono, TuIcono) tuInsignias;

  List<Color> colores(BuildContext context) => switch (this) {
    Modulo.juego => context.colores.juego,
    Modulo.aprende => context.colores.aprende,
    Modulo.pregunta => context.colores.pregunta,
  };
}

LinearGradient degradado(List<Color> colores) =>
    LinearGradient(colors: colores, begin: Alignment.topLeft, end: Alignment.bottomRight);

/// Sombra de color bajo las tarjetas con degradado. En el tema oscuro no se ve, así que no se pinta.
List<BoxShadow> sombraDe(BuildContext context, List<Color> colores) => Theme.of(context).brightness == Brightness.dark
    ? const []
    : [
        BoxShadow(
          color: colores.last.withValues(alpha: 0.28),
          blurRadius: Espacio.l,
          offset: const Offset(0, Espacio.s),
        ),
      ];

/// Con la letra muy grande (Ajustes o sistema), las ilustraciones van encima del texto.
bool letraGrande(BuildContext context) => MediaQuery.textScalerOf(context).scale(1) > _umbralLetraGrande;

/// Ilustración hecha con formas e iconos: un disco con el icono principal y, si hay [insignias],
/// dos chapas blancas con iconos del color [acento]. Es decorativa: no se lee en voz alta.
///
/// Con [tuIcono], el icono principal es una pegatina de la iconografía de TuTurno (y [tuInsignias], si las hay,
/// sustituyen a [insignias]).
class Ilustracion extends StatelessWidget {
  const Ilustracion({
    super.key,
    required this.icono,
    required this.acento,
    this.insignias,
    this.tamano = _ilustracionNormal,
    this.tuIcono,
    this.tuInsignias,
  });

  final IconData icono;
  final Color acento;
  final (IconData, IconData)? insignias;
  final double tamano;
  final TuIcono? tuIcono;
  final (TuIcono, TuIcono)? tuInsignias;

  @override
  Widget build(BuildContext context) {
    final insignias = this.insignias;
    final tuInsignias = this.tuInsignias;
    final tuIcono = this.tuIcono;
    final disco = tamano * 0.68;
    final principal = tuIcono == null
        ? Icon(icono, color: Colors.white, size: tamano * 0.38)
        : Transform.rotate(
            angle: -0.08,
            child: IconoTuTurno(tuIcono, size: tamano * 0.5, pegatina: true, decorativo: true),
          );
    Widget? insignia(int cual, double lado) {
      if (tuInsignias != null) {
        return _InsigniaPropia(icono: cual == 0 ? tuInsignias.$1 : tuInsignias.$2, tamano: lado);
      }
      if (insignias != null) {
        return _Insignia(icono: cual == 0 ? insignias.$1 : insignias.$2, color: acento, tamano: lado);
      }
      return null;
    }

    final primera = insignia(0, tamano * 0.34);
    final segunda = insignia(1, tamano * 0.28);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: tamano,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.14)),
              ),
            ),
            Center(
              child: Container(
                width: disco,
                height: disco,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1.5),
                ),
                child: principal,
              ),
            ),
            if (primera != null) Positioned(top: -tamano * 0.04, right: -tamano * 0.04, child: primera),
            if (segunda != null) Positioned(bottom: 0, left: -tamano * 0.06, child: segunda),
          ],
        ),
      ),
    );
  }
}

class _Insignia extends StatelessWidget {
  const _Insignia({required this.icono, required this.color, required this.tamano});

  final IconData icono;
  final Color color;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: Espacio.s,
            offset: const Offset(0, Espacio.xs),
          ),
        ],
      ),
      child: Icon(icono, size: tamano * 0.56, color: color),
    );
  }
}

/// Chapa de papel con un icono propio a dos tintas.
class _InsigniaPropia extends StatelessWidget {
  const _InsigniaPropia({required this.icono, required this.tamano});

  final TuIcono icono;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: ColoresMarca.papel, shape: BoxShape.circle, boxShadow: sombrasPapel(context)),
      child: IconoTuTurno(icono, size: tamano * 0.7, sombra: false, decorativo: true),
    );
  }
}

/// Píldora con texto corto. Por defecto, blanca con texto del color del módulo (contraste AA sobre blanco),
/// para ir encima de un degradado. Fuera de un degradado, pasa [fondo] y [color] del esquema.
///
/// Con [tuIcono], el icono es de la iconografía de TuTurno, a una tinta del [color].
class EtiquetaModulo extends StatelessWidget {
  const EtiquetaModulo({
    super.key,
    required this.texto,
    required this.color,
    this.icono,
    this.fondo = Colors.white,
    this.tuIcono,
  });

  final String texto;
  final Color color;
  final IconData? icono;
  final Color fondo;
  final TuIcono? tuIcono;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700);
    final icono = this.icono;
    final tuIcono = this.tuIcono;
    return DecoratedBox(
      decoration: ShapeDecoration(color: fondo, shape: const StadiumBorder()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Espacio.s + Espacio.xs, vertical: Espacio.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tuIcono != null) ...[
              IconoTuTurno(tuIcono, size: Espacio.m + 2, estilo: EstiloIcono.mono, color: color, decorativo: true),
              const SizedBox(width: Espacio.xs),
            ] else if (icono != null) ...[
              Icon(icono, size: Espacio.m, color: color),
              const SizedBox(width: Espacio.xs),
            ],
            Flexible(child: Text(texto, style: estilo)),
          ],
        ),
      ),
    );
  }
}

/// Círculo translúcido de fondo, para dar profundidad a los degradados.
class _CirculoFondo extends StatelessWidget {
  const _CirculoFondo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _circuloFondo,
      height: _circuloFondo,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.07)),
    );
  }
}

/// Tarjeta grande de un módulo en el inicio: un ticket de turno a dos tintas. El cuerpo lleva el degradado del módulo
/// con su título y una línea de descripción; el talón amarillo, el icono del módulo como una pegatina. Por la línea de
/// puntos se «arranca» al entrar (la transición rasgar de los módulos).
class TarjetaModulo extends StatelessWidget {
  const TarjetaModulo({super.key, required this.modulo, required this.onTap});

  final Modulo modulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = modulo.colores(context);
    final grande = letraGrande(context);
    final talon = grande ? 84.0 : 96.0;
    final forma = TicketBorder(
      radio: Radios.m,
      radioMuesca: 11,
      talon: talon,
      colorTalon: ColoresMarca.amarillo,
      colorPerforado: tema.scaffoldBackgroundColor,
    );
    final textos = Padding(
      padding: const EdgeInsets.fromLTRB(Espacio.l - 4, Espacio.m, Espacio.m, Espacio.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(modulo.titulo, style: tema.textTheme.headlineSmall?.copyWith(color: Colors.white)),
          const SizedBox(height: Espacio.xs / 2),
          Text(modulo.descripcion, style: tema.textTheme.bodyMedium?.copyWith(color: Colors.white, height: 1.35)),
        ],
      ),
    );
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: TicketPulsable(
          forma: forma,
          decoracion: ShapeDecoration(gradient: degradado(colores), shape: forma),
          onTap: onTap,
          child: Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    const Positioned(right: -Espacio.xxl, bottom: -Espacio.xxl * 1.6, child: _CirculoFondo()),
                    textos,
                  ],
                ),
              ),
              SizedBox(
                width: talon,
                child: Center(
                  child: Transform.rotate(
                    angle: -0.09,
                    child: IconoTuTurno(modulo.tuIcono, size: grande ? 46 : 54, pegatina: true, decorativo: true),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabecera con degradado para las pantallas de cada módulo (y de Mi situación): papel recortado de fondo (quieto) y
/// la ilustración del módulo. Con [tuIcono], la ilustración usa la iconografía de TuTurno.
class CabeceraModulo extends StatelessWidget {
  const CabeceraModulo({
    super.key,
    required this.colores,
    required this.icono,
    required this.titulo,
    required this.texto,
    this.insignias,
    this.etiqueta,
    this.iconoEtiqueta,
    this.sobretitulo,
    this.tuIcono,
    this.tuInsignias,
  });

  final List<Color> colores;
  final IconData icono;
  final (IconData, IconData)? insignias;
  final String titulo;
  final String texto;
  final String? etiqueta;
  final IconData? iconoEtiqueta;
  final String? sobretitulo;
  final TuIcono? tuIcono;
  final (TuIcono, TuIcono)? tuInsignias;

  /// Papel recortado de la cabecera: solo sombras del degradado (el texto blanco de encima gana contraste).
  static const _papel = [Color(0x1F000000), Color(0x14000000), Color(0x0F000000)];

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final grande = letraGrande(context);
    final ilustracion = Ilustracion(
      icono: icono,
      insignias: insignias,
      acento: colores.first,
      tamano: grande ? _ilustracionPequena : _ilustracionNormal,
      tuIcono: tuIcono,
      tuInsignias: tuInsignias,
    );
    final etiqueta = this.etiqueta;
    final sobretitulo = this.sobretitulo;
    final encabezado = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (etiqueta != null) ...[
          EtiquetaModulo(texto: etiqueta, color: colores.first, icono: iconoEtiqueta),
          const SizedBox(height: Espacio.s + Espacio.xs),
        ],
        if (sobretitulo != null) Text(sobretitulo, style: tema.textTheme.titleMedium?.copyWith(color: Colors.white)),
        Semantics(
          header: true,
          child: Text(titulo, style: tema.textTheme.headlineMedium?.copyWith(color: Colors.white)),
        ),
      ],
    );
    final forma = BorderRadius.circular(Radios.l);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: degradado(colores),
        borderRadius: forma,
        boxShadow: sombraDe(context, colores),
      ),
      child: FondoPapel(
        colores: _papel,
        formas: 4,
        semilla: titulo.length,
        animado: false,
        radio: Radios.l,
        child: Padding(
          padding: const EdgeInsets.all(Espacio.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (grande) ...[ilustracion, const SizedBox(height: Espacio.m), encabezado],
              if (!grande)
                Row(
                  children: [
                    Expanded(child: encabezado),
                    const SizedBox(width: Espacio.m),
                    ilustracion,
                  ],
                ),
              const SizedBox(height: Espacio.m),
              Text(texto, style: tema.textTheme.bodyLarge?.copyWith(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Círculo con el degradado de un módulo y un icono blanco: para filas y listas. Con [tuIcono], el icono es de la
/// iconografía de TuTurno (a una tinta, blanco).
class IconoDegradado extends StatelessWidget {
  const IconoDegradado({
    super.key,
    required this.icono,
    required this.colores,
    this.tamano = Espacio.xxl,
    this.tuIcono,
  });

  final IconData icono;
  final List<Color> colores;
  final double tamano;
  final TuIcono? tuIcono;

  @override
  Widget build(BuildContext context) {
    final tuIcono = this.tuIcono;
    return ExcludeSemantics(
      child: Container(
        width: tamano,
        height: tamano,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: degradado(colores)),
        child: tuIcono == null
            ? Icon(icono, color: Colors.white, size: tamano * 0.5)
            : IconoTuTurno(
                tuIcono,
                size: tamano * 0.56,
                estilo: EstiloIcono.mono,
                color: Colors.white,
                decorativo: true,
              ),
      ),
    );
  }
}

/// Icono dentro de un círculo teñido con el color principal del tema (o [fondo] y [color]). Con [tuIcono], el icono
/// es de la iconografía de TuTurno a dos tintas (o a una, del [color], si se indica).
class IconoSuave extends StatelessWidget {
  const IconoSuave({super.key, required this.icono, this.fondo, this.color, this.tamano = Espacio.xxl, this.tuIcono});

  final IconData icono;
  final Color? fondo;
  final Color? color;
  final double tamano;
  final TuIcono? tuIcono;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final tuIcono = this.tuIcono;
    final color = this.color;
    return ExcludeSemantics(
      child: Container(
        width: tamano,
        height: tamano,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: fondo ?? tinte(context, esquema.primary)),
        child: tuIcono == null
            ? Icon(icono, color: color ?? esquema.primary, size: tamano * 0.5)
            : IconoTuTurno(
                tuIcono,
                size: tamano * 0.62,
                estilo: color == null ? EstiloIcono.color : EstiloIcono.mono,
                color: color,
                decorativo: true,
              ),
      ),
    );
  }
}
