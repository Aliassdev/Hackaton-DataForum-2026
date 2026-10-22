import 'package:flutter/material.dart';

import '../../../core/texto.dart';
import '../../../tema.dart';
import '../../../widgets/movimiento/hapticos.dart';
import '../modelos.dart';

// Colores, iconos y fuentes del juego. Los colores salen siempre del tema (degradados de los módulos y esquema),
// así que si cambia la paleta, el juego cambia con ella. La tinta encima de un degradado se elige según lo claro u
// oscuro que sea el fondo, con las reglas de la marca: azul noche sobre el amarillo y blanco sobre los azules.

/// Tinta legible encima de [colores] (un degradado o un color liso): la tinta oscura del tema sobre fondos claros
/// (azul noche sobre el amarillo de la marca) y blanco sobre fondos oscuros.
Color tintaSobre(BuildContext context, List<Color> colores) {
  final medio = colores.length == 1 ? colores.first : Color.lerp(colores.first, colores.last, 0.5)!;
  if (ThemeData.estimateBrightnessForColor(medio) == Brightness.dark) return Colors.white;
  final esquema = Theme.of(context).colorScheme;
  // La tinta oscura del tema: el texto en claro y la superficie en oscuro (azul noche en los dos).
  return esquema.brightness == Brightness.light ? esquema.onSurface : esquema.surface;
}

/// El acento cálido del tema: el amarillo de la marca en los dos temas (contenedor secundario en claro, color
/// principal en oscuro).
Color acentoCalido(BuildContext context) {
  final esquema = Theme.of(context).colorScheme;
  return esquema.brightness == Brightness.light ? esquema.secondaryContainer : esquema.primary;
}

/// Degradado cálido a partir del acento: del amarillo a uno más suave.
List<Color> degradadoCalido(BuildContext context) {
  final acento = acentoCalido(context);
  return [acento, Color.lerp(acento, Colors.white, 0.45)!];
}

/// Papel de las tarjetas: blanco sobre el papel cálido en claro; un azul algo más claro que el fondo en oscuro
/// (como las Card del tema).
Color papel(BuildContext context) {
  final esquema = Theme.of(context).colorScheme;
  return esquema.brightness == Brightness.light ? esquema.surfaceContainerLowest : esquema.surfaceContainerLow;
}

LinearGradient degradadoDiagonal(List<Color> colores) =>
    LinearGradient(colors: colores, begin: Alignment.topLeft, end: Alignment.bottomRight);

/// Degradado de fondo de cada lugar: amarillo en casa y al final, azules en los sitios de la justicia y un azul hielo
/// tranquilo en la sala de espera.
List<Color> degradadoLugar(BuildContext context, Lugar lugar) {
  final c = context.colores;
  final esquema = Theme.of(context).colorScheme;
  final calido = degradadoCalido(context);
  return switch (lugar) {
    Lugar.casa => calido,
    Lugar.colegio => [c.aprende.first, c.aprende.last],
    Lugar.instituto => [c.aprende.last, c.aprende.first],
    Lugar.juzgado => [c.pregunta.first, c.pregunta.last],
    Lugar.salaEspera => [esquema.primaryContainer, esquema.surfaceContainerHighest],
    Lugar.salaGesell => [c.juego.first, c.juego.last],
    Lugar.despues => [calido.first, Color.lerp(calido.first, c.exito, 0.3)!],
    Lugar.comisaria => [c.pregunta.last, c.pregunta.first],
    Lugar.fiscalia => [c.aprende.last, c.pregunta.first],
    Lugar.otro => [c.juego.first, c.juego.last],
  };
}

/// Icono de cada lugar, para la cabecera de la escena.
IconData iconoLugar(Lugar lugar) => switch (lugar) {
  Lugar.casa => Icons.home_rounded,
  Lugar.colegio => Icons.backpack_rounded,
  Lugar.instituto => Icons.school_rounded,
  Lugar.juzgado => Icons.account_balance_rounded,
  Lugar.salaEspera => Icons.weekend_rounded,
  Lugar.salaGesell => Icons.meeting_room_rounded,
  Lugar.despues => Icons.wb_sunny_rounded,
  Lugar.comisaria => Icons.local_police_rounded,
  Lugar.fiscalia => Icons.balance_rounded,
  Lugar.otro => Icons.place_rounded,
};

/// «Lucía», «Lucía y Ana», «Lucía, Ana y Elena».
String listaNatural(List<String> elementos) => switch (elementos.length) {
  0 => '',
  1 => elementos.first,
  _ => '${elementos.sublist(0, elementos.length - 1).join(', ')} y ${elementos.last}',
};

/// Femenino de las palabras con las que empiezan los términos del glosario que nombran a personas.
const _femeninos = {'coordinador': 'coordinadora', 'juez': 'jueza', 'abogado': 'abogada', 'defensor': 'defensora'};

/// Los términos del glosario que se subrayan en las narraciones, cada uno con el término del glosario al que lleva.
/// Los que nombran a personas también se reconocen en femenino («la coordinadora de bienestar y protección» lleva a
/// «Coordinador de bienestar y protección»).
Map<String, String> terminosConVariantes(List<String> terminos) {
  final resultado = <String, String>{};
  for (final termino in terminos) {
    resultado[termino] = termino;
    final espacio = termino.indexOf(' ');
    final primera = espacio < 0 ? termino : termino.substring(0, espacio);
    final femenina = _femeninos[normalizar(primera)];
    if (femenina == null) continue;
    final mayuscula = primera.isNotEmpty && primera[0] != primera[0].toLowerCase();
    final inicio = mayuscula ? femenina[0].toUpperCase() + femenina.substring(1) : femenina;
    resultado.putIfAbsent('$inicio${espacio < 0 ? '' : termino.substring(espacio)}', () => termino);
  }
  return resultado;
}

/// Cada carta de la colección lleva uno de estos degradados, por turnos: los de los módulos y el amarillo.
List<Color> degradadoCarta(BuildContext context, int indice) {
  final c = context.colores;
  final opciones = [c.juego, degradadoCalido(context), c.aprende, c.pregunta];
  return opciones[indice % opciones.length];
}

/// Icono de una carta según de qué derecho habla (por su id o su título).
IconData iconoCarta(Carta carta) {
  final clave = normalizar('${carta.id} ${carta.titulo}');
  bool tiene(List<String> palabras) => palabras.any(clave.contains);
  if (tiene(['escuch', 'oida', 'oido', 'opinion'])) return Icons.hearing_rounded;
  if (tiene(['cruz', 'investigad', 'confront', 'cara a cara'])) return Icons.visibility_off_rounded;
  if (tiene(['una-sola-vez', 'una sola vez', 'grab', 'preconst'])) return Icons.videocam_rounded;
  if (tiene(['entender', 'claro', 'explica'])) return Icons.lightbulb_rounded;
  if (tiene(['acompa', 'confianza'])) return Icons.people_alt_rounded;
  if (tiene(['familia', 'casa'])) return Icons.family_restroom_rounded;
  if (tiene(['centro', 'colegio', 'instituto', 'protocolo'])) return Icons.school_rounded;
  if (tiene(['distancia', 'videoconf'])) return Icons.video_call_rounded;
  if (tiene(['concilia', 'disculpa', 'perdon'])) return Icons.handshake_rounded;
  if (tiene(['proteccion', 'acerqu', 'alejamiento'])) return Icons.shield_rounded;
  if (tiene(['fiscal'])) return Icons.balance_rounded;
  if (tiene(['intimidad', 'imagen', 'datos'])) return Icons.privacy_tip_rounded;
  return Icons.verified_rounded;
}

/// Icono de un personaje según quién es.
IconData iconoPersonaje(String personaje, {required bool protagonista}) {
  if (protagonista) return Icons.face_rounded;
  final clave = normalizar(personaje);
  bool tiene(List<String> palabras) => palabras.any(clave.contains);
  if (tiene(['psicolog'])) return Icons.psychology_rounded;
  if (tiene(['tutor', 'profe', 'maestr'])) return Icons.school_rounded;
  if (tiene(['coordinador', 'bienestar'])) return Icons.volunteer_activism_rounded;
  if (tiene(['juez', 'jueza'])) return Icons.gavel_rounded;
  if (tiene(['fiscal'])) return Icons.balance_rounded;
  if (tiene(['abogad'])) return Icons.work_rounded;
  if (tiene(['polic', 'agente', 'guardia'])) return Icons.local_police_rounded;
  if (tiene(['trabajador', 'social', 'educador'])) return Icons.diversity_3_rounded;
  if (tiene(['madre', 'padre', 'tia', 'tio', 'abuel', 'herman', 'familia'])) return Icons.favorite_rounded;
  return Icons.person_rounded;
}

/// «victima» → «Víctima».
String nombreRol(String rol) => switch (normalizar(rol.trim())) {
  'victima' => 'Víctima',
  'testigo' => 'Testigo',
  'investigado' => 'Investigado o investigada',
  final otro when otro.isNotEmpty => otro[0].toUpperCase() + otro.substring(1),
  _ => '',
};

/// Una norma citada en una fuente: «LECrim, art. 449 ter» → (LECrim, 449 ter).
typedef CitaLegal = ({String norma, String articulo});

final _prefijoArticulo = RegExp(r'^arts?\.\s*', caseSensitive: false);

/// Separa «LECrim, art. 449 ter; Ley 4/2015, art. 20» en sus citas.
List<CitaLegal> citasDe(String fuente) => [
  for (final parte in fuente.split(';'))
    if (parte.trim().isNotEmpty) _cita(parte.trim()),
];

CitaLegal _cita(String parte) {
  final coma = parte.indexOf(',');
  if (coma < 0) return (norma: parte, articulo: '');
  return (
    norma: parte.substring(0, coma).trim(),
    articulo: parte.substring(coma + 1).trim().replaceFirst(_prefijoArticulo, ''),
  );
}

/// Los mismos nombres fáciles que usan Aprende, Pregunta y Mi situación.
const _nombresNormas = {
  'lecrim': 'Ley de Enjuiciamiento Criminal',
  'lec': 'Ley de Enjuiciamiento Civil',
  'lo 1/1996': 'Ley de protección jurídica del menor',
  'ley 1/1996': 'Ley de asistencia jurídica gratuita',
  'ley 4/2015': 'Estatuto de la víctima del delito',
  'lopivi': 'Ley de protección de la infancia y la adolescencia frente a la violencia',
  'lo 8/2021': 'Ley de protección de la infancia y la adolescencia frente a la violencia',
  'lo 5/2000': 'Ley de responsabilidad penal de los menores',
  'lo 1/1982': 'Ley del derecho al honor, a la intimidad y a la propia imagen',
  'lo 3/1981': 'Ley del Defensor del Pueblo',
  'codigo penal': 'Código Penal',
  'cp': 'Código Penal',
  'cdn': 'Convención sobre los Derechos del Niño',
  'rgpd': 'Reglamento General de Protección de Datos',
  'lopdgdd': 'Ley de protección de datos personales',
  'aepd': 'Agencia Española de Protección de Datos',
  'incibe': 'Instituto Nacional de Ciberseguridad',
};

/// Nombre que se entiende de una norma («LECrim» → «Ley de Enjuiciamiento Criminal»). null si no se conoce.
String? nombreNormaJuego(String norma) => _nombresNormas[normalizar(norma.trim())];

/// Etiqueta con la fuente legal. Al tocarla, una hoja explica de qué ley sale.
class FuenteLegal extends StatelessWidget {
  const FuenteLegal({super.key, required this.fuente, this.color});

  final String fuente;

  /// Color del texto y el icono; por defecto, el del texto secundario.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = this.color ?? tema.colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      label: 'Fuente: $fuente. Toca para ver de qué ley sale',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radios.s),
        onTap: () {
          Hapticos.seleccion();
          mostrarFuenteLegal(context, fuente);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Espacio.xxl),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Espacio.xs, vertical: Espacio.s),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.gavel_rounded, size: Espacio.m + Espacio.xs, color: color),
                const SizedBox(width: Espacio.s),
                Flexible(
                  child: Text(
                    fuente,
                    style: tema.textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: color.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hoja con las normas de una fuente, con su nombre fácil.
Future<void> mostrarFuenteLegal(BuildContext context, String fuente) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _HojaFuente(fuente: fuente),
);

class _HojaFuente extends StatelessWidget {
  const _HojaFuente({required this.fuente});

  final String fuente;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Espacio.l, 0, Espacio.l, Espacio.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('De dónde sale', style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: Espacio.m),
          for (final cita in citasDe(fuente))
            Padding(
              padding: const EdgeInsets.only(bottom: Espacio.m),
              child: MergeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(child: Icon(Icons.menu_book_rounded, color: esquema.primary)),
                    const SizedBox(width: Espacio.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cita.articulo.isEmpty ? cita.norma : '${cita.norma} · art. ${cita.articulo}',
                            style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (nombreNormaJuego(cita.norma) case final nombre?)
                            Text(nombre, style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: tinte(context, esquema.primary),
              borderRadius: BorderRadius.circular(Radios.m),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Espacio.m),
              child: Text(
                'Es la ley en la que se apoya lo que acabas de leer. Puedes enseñársela a una persona adulta de '
                'confianza o a tu abogado o abogada.',
                style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurface),
              ),
            ),
          ),
          const SizedBox(height: Espacio.l),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Entendido')),
        ],
      ),
    );
  }
}
