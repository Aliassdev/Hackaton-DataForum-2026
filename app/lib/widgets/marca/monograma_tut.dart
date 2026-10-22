import 'package:flutter/material.dart';

import '../../tema.dart';
import 'pintor_marca.dart';
import 'trazos_marca.dart';

/// El monograma TuT (dos T altas y una u pequeña): el icono de la app y la cara de la mascota Tut. Es de la misma
/// familia que el logotipo, en grueso, así que se lee bien en pequeño.
///
/// Las piezas están en [TrazosMonograma] (T izquierda, u y T derecha) por si se quieren animar por separado.
class MonogramaTut extends StatelessWidget {
  const MonogramaTut({
    super.key,
    this.alto = 48,
    this.tono,
    this.color,
    this.pegatina = false,
    this.etiqueta = 'TuTurno',
  });

  /// Ancho / alto del monograma.
  static const proporcion = TrazosMonograma.ancho / TrazosMonograma.alto;

  final double alto;

  /// Tono de la marca. Si no se indica (ni [color]), el del tema.
  final TonoMarca? tono;

  /// Color libre. Gana a [tono].
  final Color? color;
  final bool pegatina;

  /// Lo que lee el lector de pantalla; `null` si es decorativo.
  final String? etiqueta;

  @override
  Widget build(BuildContext context) {
    final dibujo = CustomPaint(
      size: Size(alto * proporcion, alto),
      painter: PintorMarca(
        trazos: TrazosMonograma.piezas,
        lienzo: const Size(TrazosMonograma.ancho, TrazosMonograma.alto),
        color: color ?? (tono ?? TonoMarca.delTema(context)).color,
        pegatina: pegatina,
        colorSombra: sombraPapelDe(context),
      ),
    );
    final etiqueta = this.etiqueta;
    return etiqueta == null
        ? ExcludeSemantics(child: dibujo)
        : Semantics(label: etiqueta, image: true, excludeSemantics: true, child: dibujo);
  }
}

/// El icono de la app: el monograma sobre una placa redondeada (por defecto, amarillo sobre azul, como en el móvil).
/// Para la bienvenida, «Acerca de» o un avatar. Mide [lado] x [lado].
class PlacaTut extends StatelessWidget {
  const PlacaTut({super.key, this.lado = 64, this.tono = TonoMarca.amarillo, this.fondo, this.etiqueta = 'TuTurno'});

  final double lado;
  final TonoMarca tono;

  /// Color de la placa; por defecto, el que acompaña a [tono] ([TonoMarca.fondo]).
  final Color? fondo;
  final String? etiqueta;

  /// Mismas proporciones que el icono del móvil: radio del 22 % y monograma al 60 % del ancho.
  static const _radio = 0.22;
  static const _ocupa = 0.6;

  @override
  Widget build(BuildContext context) {
    final placa = Container(
      width: lado,
      height: lado,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fondo ?? tono.fondo,
        borderRadius: BorderRadius.circular(lado * _radio),
        boxShadow: sombrasPapel(context),
      ),
      child: MonogramaTut(alto: lado * _ocupa / MonogramaTut.proporcion, tono: tono, etiqueta: null),
    );
    final etiqueta = this.etiqueta;
    return etiqueta == null
        ? ExcludeSemantics(child: placa)
        : Semantics(label: etiqueta, image: true, excludeSemantics: true, child: placa);
  }
}
