import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api/models.dart';
import '../tema.dart';
import 'iconos/iconos.dart';

/// Etiqueta de una fuente legal (sección 4.4). Al tocarla se ve la norma y el artículo.
class FuenteChip extends StatelessWidget {
  const FuenteChip({super.key, required this.fuente, this.numero});

  final Fuente fuente;

  /// Número con el que se cita en el texto (1, 2…), si lo hay.
  final int? numero;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return ActionChip(
      avatar: numero == null
          ? const IconoTuTurno(TuIcono.fuente, size: 18, decorativo: true)
          : NumeroFuente(numero: numero!),
      label: Text(etiquetaFuente(fuente), maxLines: 1, overflow: TextOverflow.ellipsis),
      labelStyle: tema.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: esquema.onSurface),
      tooltip: 'Ver de dónde sale: ${fuente.titulo}',
      backgroundColor: esquema.surface,
      side: BorderSide(color: esquema.outlineVariant),
      onPressed: () {
        HapticFeedback.selectionClick();
        mostrarFuente(context, fuente);
      },
    );
  }
}

/// Círculo con el número de una fuente, igual en el texto y en las etiquetas.
class NumeroFuente extends StatelessWidget {
  const NumeroFuente({super.key, required this.numero});

  final int numero;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    // En la etiqueta el hueco es cuadrado y fijo; dentro del texto, se ajusta al número.
    return DecoratedBox(
      decoration: ShapeDecoration(color: tema.colorScheme.primary, shape: const StadiumBorder()),
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Espacio.xs),
          child: Text(
            '$numero',
            style: tema.textTheme.labelMedium?.copyWith(
              color: tema.colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// «LO 5/2000 · art. 3». Si no hay norma, el título.
String etiquetaFuente(Fuente fuente) {
  final norma = fuente.norma.trim();
  final articulo = fuente.articulo.trim();
  if (norma.isEmpty) return fuente.titulo.isNotEmpty ? fuente.titulo : fuente.id;
  return articulo.isEmpty ? norma : '$norma · art. $articulo';
}

/// Nombre fácil de las normas que más salen, para quien no sabe qué es «LO 5/2000».
const _nombresNormas = {
  'lo 5/2000': 'Ley de responsabilidad penal de los menores',
  'lo 1/1996': 'Ley de protección jurídica del menor',
  'lo 8/2021': 'Ley de protección de la infancia y la adolescencia frente a la violencia',
  'lo 10/1995': 'Código Penal',
  'ley 4/2015': 'Estatuto de la víctima del delito',
  'lecrim': 'Ley de Enjuiciamiento Criminal',
  'ce': 'Constitución Española',
  'cp': 'Código Penal',
  'cc': 'Código Civil',
  'cdn': 'Convención sobre los Derechos del Niño',
};

String? nombreNorma(String norma) => _nombresNormas[norma.trim().toLowerCase()];

/// Hoja con el título, la norma y el artículo de una fuente.
Future<void> mostrarFuente(BuildContext context, Fuente fuente) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _HojaFuente(fuente: fuente),
);

class _HojaFuente extends StatelessWidget {
  const _HojaFuente({required this.fuente});

  final Fuente fuente;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final nombre = nombreNorma(fuente.norma);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Espacio.l, 0, Espacio.l, Espacio.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // El documento de la iconografía de TuTurno, como una pegatina un poco torcida.
              Transform.rotate(
                angle: -0.06,
                child: const IconoTuTurno(TuIcono.fuente, size: Espacio.xxl, decorativo: true),
              ),
              const SizedBox(width: Espacio.m),
              Expanded(
                child: Text(
                  'De dónde sale la respuesta',
                  style: tema.textTheme.labelLarge?.copyWith(color: esquema.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: Espacio.m),
          Semantics(
            header: true,
            child: Text(fuente.titulo.isNotEmpty ? fuente.titulo : fuente.id, style: tema.textTheme.headlineSmall),
          ),
          const SizedBox(height: Espacio.l),
          if (fuente.norma.trim().isNotEmpty)
            _Dato(icono: TuIcono.juzgado, etiqueta: 'Norma', valor: fuente.norma.trim(), detalle: nombre),
          if (fuente.articulo.trim().isNotEmpty)
            _Dato(icono: TuIcono.fuente, etiqueta: 'Artículo', valor: fuente.articulo.trim()),
          const SizedBox(height: Espacio.s),
          Container(
            padding: const EdgeInsets.all(Espacio.m),
            decoration: BoxDecoration(
              color: tinte(context, esquema.primary),
              borderRadius: BorderRadius.circular(Radios.m),
            ),
            child: Text(
              'Es la ley en la que se apoya la respuesta. Puedes enseñársela a una persona adulta de confianza '
              'o a tu abogado o abogada.',
              style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurface),
            ),
          ),
          if (fuente.id.isNotEmpty) ...[
            const SizedBox(height: Espacio.s),
            Text(
              'Referencia: ${fuente.id}',
              style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: Espacio.l),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Entendido')),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.etiqueta, required this.valor, this.detalle});

  final TuIcono icono;
  final String etiqueta;
  final String valor;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Espacio.m),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconoTuTurno(icono, size: 28, decorativo: true),
            const SizedBox(width: Espacio.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(etiqueta, style: tema.textTheme.labelLarge?.copyWith(color: esquema.onSurfaceVariant)),
                  Text(valor, style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  if (detalle != null) Text(detalle!, style: tema.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
