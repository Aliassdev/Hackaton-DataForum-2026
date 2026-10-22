import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/texto.dart';
import '../../tema.dart';

// Fuentes de un paso: etiquetas pequeñas que, al tocarlas, abren una hoja con la referencia.
// Una fuente puede ser una cita de una ley («LECrim, art. 449 ter»), la información oficial de un organismo
// («AEPD, Canal prioritario»), una tarjeta de conocimiento («A-050», sección 9.1) o «MOCK» en los datos de ejemplo.

/// Una fuente de un paso, ya separada: «LECrim, art. 449 ter» → norma «LECrim» y detalle «art. 449 ter».
@immutable
class CitaPaso {
  const CitaPaso({required this.original, required this.norma, this.detalle = ''});

  factory CitaPaso.desdeTexto(String texto) {
    final original = texto.trim();
    final coma = original.indexOf(',');
    if (coma < 0) return CitaPaso(original: original, norma: original);
    return CitaPaso(
      original: original,
      norma: original.substring(0, coma).trim(),
      detalle: original.substring(coma + 1).trim(),
    );
  }

  /// Las citas de las fuentes de un paso. Una fuente con «;» son varias citas: «LOPIVI, art. 14; Ley 1/1996, art. 2.h)».
  static List<CitaPaso> de(List<String> fuentes) => [
    for (final fuente in fuentes)
      for (final parte in fuente.split(';'))
        if (parte.trim().isNotEmpty) CitaPaso.desdeTexto(parte),
  ];

  /// Tal como viene en el contenido.
  final String original;
  final String norma;

  /// Lo que va después de la primera coma: «art. 449 ter», «arts. 4 y 7»…
  final String detalle;

  /// Dato de ejemplo de assets/mock (fuente «MOCK»): no tiene una ley comprobada detrás.
  bool get esEjemplo => original == 'MOCK';

  /// Tarjeta de conocimiento del índice A (sección 9.1), p. ej. «A-050».
  bool get esTarjeta => _tarjeta.hasMatch(original);

  /// Información oficial de un organismo (la AEPD o el INCIBE), que no es una ley: «AEPD, Canal prioritario».
  bool get esOrganismo => _organismoDe(norma) != null;

  /// «LECrim · art. 449 ter». Una tarjeta, tal cual («A-050»); MOCK, «Dato de ejemplo».
  String get etiqueta => esEjemplo ? 'Dato de ejemplo' : (detalle.isEmpty ? norma : '$norma · $detalle');

  /// Para el lector de pantalla, que lee las siglas y las abreviaturas letra a letra: el nombre fácil y las
  /// abreviaturas enteras. «LO 5/2000, art. 16.2» → «Ley de responsabilidad penal de los menores, artículo 16.2».
  String get etiquetaLector {
    if (esEjemplo) return 'dato de ejemplo';
    if (esTarjeta) return 'ficha $original';
    final nombre = nombreFacilDeNorma(norma) ?? norma;
    if (detalle.isEmpty) return nombre;
    var leido = detalle;
    for (final (abreviatura, entera) in _abreviaturas) {
      leido = leido.replaceAll(abreviatura, entera);
    }
    return '$nombre, $leido';
  }

  /// Nombre que se entiende de la norma («LECrim» → «Ley de Enjuiciamiento Criminal»).
  /// null si no se conoce o si la norma ya lo dice.
  String? get nombreFacil {
    final nombre = nombreFacilDeNorma(norma);
    return nombre == null || normalizar(norma).contains(normalizar(nombre)) ? null : nombre;
  }

  static final _tarjeta = RegExp(r'^[A-Z]{1,3}-\d+$');

  /// Abreviaturas de las citas, con lo que se lee. El paréntesis de las letras («2.h)», «7.1 i)») no se lee.
  static final _abreviaturas = <(RegExp, String)>[
    (RegExp(r'\barts\.'), 'artículos'),
    (RegExp(r'\bart\.'), 'artículo'),
    (RegExp(r'\bpárrs\.'), 'párrafos'),
    (RegExp(r'\bpárr\.'), 'párrafo'),
    (RegExp(r'(?<=\b[a-zñ])\)'), ''),
  ];
}

/// Un organismo cuya información oficial se cita como fuente en docs/MARCO_LEGAL.md.
typedef _Organismo = ({String sigla, String nombre, String conDe});

const _organismos = <_Organismo>[
  (
    sigla: 'aepd',
    nombre: 'Agencia Española de Protección de Datos',
    conDe: 'de la Agencia Española de Protección de Datos',
  ),
  (sigla: 'incibe', nombre: 'Instituto Nacional de Ciberseguridad', conDe: 'del Instituto Nacional de Ciberseguridad'),
];

/// La sigla sola o al principio («LEC (Ley 1/2000)», «AEPD · Canal prioritario»). [n] ya va normalizado.
bool _empiezaPor(String n, String sigla) => n == sigla || n.startsWith('$sigla ') || n.startsWith('$sigla(');

_Organismo? _organismoDe(String norma) {
  final n = normalizar(norma.trim());
  for (final organismo in _organismos) {
    if (_empiezaPor(n, organismo.sigla) || n.contains(normalizar(organismo.nombre))) return organismo;
  }
  return null;
}

/// Nombre fácil de las normas (y de los organismos, como la AEPD) que salen en docs/MARCO_LEGAL.md. null si no se
/// conoce.
String? nombreFacilDeNorma(String norma) {
  final organismo = _organismoDe(norma);
  if (organismo != null) return organismo.nombre;
  final n = normalizar(norma.trim());
  bool tiene(String texto) => n.contains(texto);
  // «LEC» o «CP» solos o al principio («LEC (Ley 1/2000)»), sin confundirlos con «LECrim».
  bool empieza(String sigla) => _empiezaPor(n, sigla);

  if (tiene('lecrim') || tiene('enjuiciamiento criminal')) return 'Ley de Enjuiciamiento Criminal';
  if (empieza('lec') || tiene('ley 1/2000') || tiene('enjuiciamiento civil')) return 'Ley de Enjuiciamiento Civil';
  if (tiene('lopivi') || tiene('lo 8/2021')) {
    return 'Ley de protección de la infancia y la adolescencia frente a la violencia';
  }
  if (tiene('lo 1/1996')) return 'Ley de protección jurídica del menor';
  if (tiene('ley 1/1996') || tiene('asistencia juridica gratuita')) return 'Ley de asistencia jurídica gratuita';
  if (tiene('ley 4/2015') || tiene('estatuto de la victima')) return 'Estatuto de la víctima del delito';
  if (tiene('lo 5/2000')) return 'Ley de responsabilidad penal de los menores';
  if (tiene('lo 1/1982')) return 'Ley del derecho al honor, a la intimidad y a la propia imagen';
  if (tiene('lo 3/1981') || tiene('defensor del pueblo')) return 'Ley del Defensor del Pueblo';
  if (tiene('lopdgdd') || tiene('lo 3/2018')) return 'Ley de protección de datos personales';
  if (empieza('rgpd')) return 'Reglamento General de Protección de Datos';
  if (empieza('cp') || tiene('codigo penal') || tiene('lo 10/1995')) return 'Código Penal';
  if (empieza('cdn') || tiene('derechos del nino')) return 'Convención sobre los Derechos del Niño';
  return null;
}

/// Etiqueta pequeña de una fuente («LECrim · art. 449 ter»), sin icono para que quepan varias por línea (el título
/// «De dónde sale» ya lleva el mazo). Se ve pequeña, pero la zona táctil sigue siendo de 48 px. Al tocarla,
/// [mostrarFuentePaso].
class ChipFuentePaso extends StatelessWidget {
  const ChipFuentePaso({super.key, required this.cita, this.paso});

  final CitaPaso cita;

  /// Nombre del paso, para recordarlo en la hoja.
  final String? paso;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    void abrir() => mostrarFuentePaso(context, cita, paso: paso);
    // El lector de pantalla ya dice que es un botón y cómo se activa: la etiqueta solo dice qué fuente es, con su
    // nombre fácil, y la pista dice para qué sirve tocarla.
    return Semantics(
      button: true,
      label: 'Fuente: ${cita.etiquetaLector}',
      onTapHint: cita.esEjemplo ? 'saber más' : 'ver de dónde sale',
      excludeSemantics: true,
      onTap: abrir,
      child: ActionChip(
        label: Text(cita.etiqueta, maxLines: 1, overflow: TextOverflow.ellipsis),
        labelStyle: tema.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: esquema.onSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: Espacio.xs, vertical: Espacio.xs),
        labelPadding: const EdgeInsets.symmetric(horizontal: Espacio.xs),
        // Sin VisualDensity.compact: también encoge la zona táctil, a 40 px.
        materialTapTargetSize: MaterialTapTargetSize.padded,
        backgroundColor: esquema.surfaceContainerLowest,
        side: BorderSide(color: esquema.outlineVariant),
        onPressed: abrir,
      ),
    );
  }
}

/// Hoja con la referencia de una fuente: la norma, su nombre fácil y para qué sirve.
Future<void> mostrarFuentePaso(BuildContext context, CitaPaso cita, {String? paso}) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _HojaFuentePaso(cita: cita, paso: paso),
  );
}

class _HojaFuentePaso extends StatelessWidget {
  const _HojaFuentePaso({required this.cita, this.paso});

  final CitaPaso cita;
  final String? paso;

  String get _nota {
    if (cita.esEjemplo) return 'Es un dato de ejemplo para probar la app: todavía no tiene una ley comprobada detrás.';
    if (cita.esTarjeta) {
      return 'Es la referencia de la ficha legal en la que se apoya este paso. Si tienes dudas, pregúntaselas a una '
          'persona adulta de confianza.';
    }
    // Un organismo no es una ley: el Canal prioritario es un servicio de la AEPD.
    final organismo = _organismoDe(cita.norma);
    if (organismo != null) {
      return 'Es la información oficial ${organismo.conDe} en la que se apoya lo que te contamos en este paso. Si '
          'quieres, enséñasela a una persona adulta de confianza.';
    }
    return 'Es la ley en la que se apoya lo que te contamos en este paso. Si quieres, enséñasela a una persona '
        'adulta de confianza.';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final nombre = cita.esEjemplo ? null : cita.nombreFacil;
    final paso = this.paso;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Espacio.l, 0, Espacio.l, Espacio.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: Espacio.xxl,
                  height: Espacio.xxl,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: esquema.primaryContainer),
                  child: Icon(Icons.gavel_rounded, color: esquema.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: Espacio.m),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'De dónde sale',
                    style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          if (paso != null) ...[
            const SizedBox(height: Espacio.m),
            Text(
              'Lo que te contamos en «$paso» se apoya en esto:',
              style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: Espacio.l),
          Semantics(
            label: nombre == null ? cita.etiqueta : '${cita.original}. $nombre',
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.menu_book_rounded, color: esquema.primary),
                const SizedBox(width: Espacio.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cita.etiqueta, style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      if (nombre != null) ...[
                        const SizedBox(height: Espacio.xs),
                        Text(nombre, style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Espacio.l),
          DecoratedBox(
            decoration: BoxDecoration(
              color: esquema.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(Radios.m),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Espacio.m),
              child: Text(_nota, style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurface)),
            ),
          ),
          const SizedBox(height: Espacio.l),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Entendido')),
        ],
      ),
    );
  }
}
