import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api/models.dart';
import '../tema.dart';
import 'iconos/iconos.dart';
import 'movimiento/hapticos.dart';

/// Etiqueta de una fuente legal (sección 4.4), con el libro de la ley ([TuIcono.ley]: «De dónde sale»). Al tocarla se
/// ve la norma y el artículo y, si la fuente trae enlace ([Fuente.url]), un botón para leer el texto oficial.
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
          ? const IconoTuTurno(TuIcono.ley, size: 18, decorativo: true)
          : NumeroFuente(numero: numero!),
      label: Text(etiquetaFuente(fuente), maxLines: 1, overflow: TextOverflow.ellipsis),
      labelStyle: tema.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: esquema.onSurface),
      tooltip: 'Ver de dónde sale: ${fuente.titulo}',
      backgroundColor: esquema.surface,
      side: BorderSide(color: esquema.outlineVariant),
      onPressed: () {
        Hapticos.seleccion();
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

/// Nombre fácil de las normas que más salen, para quien no sabe qué es «LO 5/2000». Los mismos que `nombresNormas`
/// de lib/features/aprende/textos.dart.
const _nombresNormas = {
  'lo 5/2000': 'Ley de responsabilidad penal de los menores',
  'lo 1/1996': 'Ley de protección jurídica del menor',
  'lo 8/2021': 'Ley de protección de la infancia y la adolescencia frente a la violencia',
  'lo 10/1995': 'Código Penal',
  'ley 4/2015': 'Estatuto de la víctima del delito',
  'lecrim': 'Ley de Enjuiciamiento Criminal',
  'lec': 'Ley de Enjuiciamiento Civil',
  'ley 1/1996': 'Ley de asistencia jurídica gratuita',
  'lo 1/1982': 'Ley del derecho al honor, a la intimidad y a la propia imagen',
  'lopdgdd': 'Ley de protección de datos personales',
  'rgpd': 'Reglamento General de Protección de Datos',
  'ce': 'Constitución Española',
  'cp': 'Código Penal',
  'cc': 'Código Civil',
  'cdn': 'Convención sobre los Derechos del Niño',
  // Las siglas que usa el backend en sus fuentes (content/leyes.json, campo «corta»).
  'lorpm': 'Ley de responsabilidad penal de los menores',
  'lopivi': 'Ley de protección de la infancia y la adolescencia frente a la violencia',
};

/// El nombre fácil de [norma] («LO 5/2000» o «LORPM» → «Ley de responsabilidad penal de los menores»), si lo hay.
String? nombreNorma(String norma) => _nombresNormas[norma.trim().toLowerCase()];

/// true si [url] es del BOE (el texto oficial de una ley).
bool esEnlaceBoe(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  return host == 'boe.es' || host.endsWith('.boe.es');
}

/// Abre [url] fuera de la app (el navegador). Solo https o http. Devuelve false si no se pudo.
Future<bool> abrirEnlaceFuente(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Hoja con el título, la norma y el artículo de una fuente. Si trae enlace, con «Leer la ley en el BOE» (o «Abrir la
/// web oficial», como la del Canal prioritario de la AEPD).
Future<void> mostrarFuente(BuildContext context, Fuente fuente) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => HojaFuente(fuente: fuente),
);

class HojaFuente extends StatelessWidget {
  const HojaFuente({super.key, required this.fuente});

  final Fuente fuente;

  Future<void> _abrir(BuildContext context) async {
    Hapticos.toque();
    final mensajero = ScaffoldMessenger.maybeOf(context);
    if (!await abrirEnlaceFuente(fuente.url)) {
      mensajero?.showSnackBar(const SnackBar(content: Text('No he podido abrir el enlace. Prueba otra vez.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final nombre = nombreNorma(fuente.norma);
    final conEnlace = fuente.url.trim().isNotEmpty;
    final boe = conEnlace && esEnlaceBoe(fuente.url);
    final explicacion = !conEnlace
        ? 'Es la ley en la que se apoya la respuesta. Puedes enseñársela a una persona adulta de confianza o a tu '
              'abogado o abogada.'
        : boe
        ? 'Es la ley en la que se apoya la respuesta. Puedes leerla en el BOE, que es donde se publican las leyes, o '
              'enseñársela a una persona adulta de confianza o a tu abogado o abogada.'
        : 'Es la web oficial de donde sale la respuesta. Puedes leerla o enseñársela a una persona adulta de confianza.';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Espacio.l, 0, Espacio.l, Espacio.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // El libro de la ley de la iconografía de TuTurno, como una pegatina un poco torcida.
              Transform.rotate(
                angle: -0.06,
                child: const IconoTuTurno(TuIcono.ley, size: Espacio.xxl, decorativo: true),
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
            _Dato(
              icono: TuIcono.juzgado,
              etiqueta: conEnlace && !boe ? 'De dónde' : 'Norma',
              valor: fuente.norma.trim(),
              detalle: nombre,
            ),
          if (fuente.articulo.trim().isNotEmpty)
            _Dato(icono: TuIcono.fuente, etiqueta: 'Artículo', valor: fuente.articulo.trim()),
          const SizedBox(height: Espacio.s),
          Container(
            padding: const EdgeInsets.all(Espacio.m),
            decoration: BoxDecoration(
              color: tinte(context, esquema.primary),
              borderRadius: BorderRadius.circular(Radios.m),
            ),
            child: Text(explicacion, style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurface)),
          ),
          if (fuente.id.isNotEmpty && !conEnlace) ...[
            const SizedBox(height: Espacio.s),
            Text(
              'Referencia: ${fuente.id}',
              style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: Espacio.l),
          if (conEnlace) ...[
            FilledButton.icon(
              key: const Key('abrir-fuente'),
              onPressed: () => _abrir(context),
              icon: const IconoTuTurno(TuIcono.web, estilo: EstiloIcono.mono, decorativo: true),
              label: Text(boe ? 'Leer la ley en el BOE' : 'Abrir la web oficial'),
            ),
            const SizedBox(height: Espacio.s),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Entendido')),
          ] else
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
