import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/texto.dart';
import '../../../pixel/ui/ui.dart';
import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../../../widgets/movimiento/hapticos.dart';
import '../modelos.dart';

// Colores, iconos y fuentes del juego. Fuera del mundo pixel (la lista de casos y la colección planas), los colores
// salen del tema (degradados de los módulos y esquema), así que si cambia la paleta, el juego cambia con ella. La tinta
// encima de un degradado se elige según lo claro u oscuro que sea el fondo, con las reglas de la marca: azul noche
// sobre el amarillo y blanco sobre los azules. Dentro del caso, todo es del kit pixel (lib/pixel/ui).
//
// Justicia de verdad: nada de mazos (en España no se usan) ni de la balanza como icono de persona. La jueza o el juez
// llevan la toga de TuIcono, y la Fiscalía y las fuentes, la ley.

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
    Lugar.habitacion => [c.juego.last, calido.first],
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

/// Icono de cada lugar, de la iconografía de TuTurno (para pintarlo, `IconoTuTurno`).
TuIcono iconoLugar(Lugar lugar) => switch (lugar) {
  Lugar.casa || Lugar.habitacion => TuIcono.inicio,
  Lugar.colegio || Lugar.instituto => TuIcono.aprende,
  Lugar.juzgado => TuIcono.juzgado,
  Lugar.salaEspera => TuIcono.reloj,
  Lugar.salaGesell => TuIcono.grabacion,
  Lugar.despues => TuIcono.estrella,
  Lugar.comisaria => TuIcono.escudo,
  Lugar.fiscalia => TuIcono.ley,
  Lugar.otro => TuIcono.puertaSala,
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

/// De qué derecho habla una carta (por su id o su título), para elegir su dibujo. Las cartas de los tres casos
/// oficiales tienen cada una el suyo.
enum _TemaCarta {
  escuchar,
  sinVer,
  grabar,
  entender,
  acompanar,
  familia,
  centro,
  disculpas,
  proteccion,
  culpa,
  quitar,
  borrar,
  denunciar,
  ley,
  otro;

  static _TemaCarta de(Carta carta) {
    final clave = normalizar('${carta.id} ${carta.titulo}');
    bool tiene(List<String> palabras) => palabras.any(clave.contains);
    if (tiene(['escuch', 'oida', 'oido', 'opinion'])) return escuchar;
    if (tiene(['cruz', 'investigad', 'confront', 'cara a cara'])) return sinVer;
    if (tiene(['una-sola-vez', 'una sola vez', 'grab', 'preconst', 'distancia', 'videoconf'])) return grabar;
    if (tiene(['entender', 'claro', 'explica'])) return entender;
    if (tiene(['acompa', 'confianza'])) return acompanar;
    if (tiene(['familia', 'casa'])) return familia;
    if (tiene(['centro', 'colegio', 'instituto', 'protocolo'])) return centro;
    if (tiene(['concilia', 'disculpa', 'perdon'])) return disculpas;
    if (tiene(['culpa'])) return culpa;
    if (tiene(['canal', 'quit', 'retir'])) return quitar;
    if (tiene(['borr', 'supres'])) return borrar;
    if (tiene(['denunci'])) return denunciar;
    if (tiene(['fiscal'])) return ley;
    if (tiene(['proteccion', 'protege', 'acerqu', 'alejamiento', 'intimidad', 'imagen', 'datos'])) return proteccion;
    return otro;
  }
}

/// Icono de una carta según de qué derecho habla (por su id o su título), de la iconografía de TuTurno.
TuIcono iconoCarta(Carta carta) => switch (_TemaCarta.de(carta)) {
  _TemaCarta.escuchar => TuIcono.turnoPalabra,
  _TemaCarta.sinVer => TuIcono.escudo,
  _TemaCarta.grabar => TuIcono.grabacion,
  _TemaCarta.entender => TuIcono.idea,
  _TemaCarta.acompanar => TuIcono.personaConfianza,
  _TemaCarta.familia => TuIcono.inicio,
  _TemaCarta.centro => TuIcono.aprende,
  _TemaCarta.disculpas => TuIcono.check,
  _TemaCarta.proteccion => TuIcono.escudo,
  _TemaCarta.culpa => TuIcono.estrella,
  _TemaCarta.quitar || _TemaCarta.borrar => TuIcono.web,
  _TemaCarta.denunciar => TuIcono.manoAlzada,
  _TemaCarta.ley => TuIcono.ley,
  _TemaCarta.otro => TuIcono.carta,
};

/// El dibujo pixel de una carta (para [CartaPixel]) según de qué derecho habla.
GlifoPixel glifoCarta(Carta carta) => switch (_TemaCarta.de(carta)) {
  _TemaCarta.escuchar => GlifoPixel.bocadillo,
  _TemaCarta.sinVer => GlifoPixel.ojoTachado,
  _TemaCarta.grabar => GlifoPixel.camara,
  _TemaCarta.entender => GlifoPixel.bombilla,
  _TemaCarta.acompanar => GlifoPixel.personas,
  _TemaCarta.familia => GlifoPixel.casa,
  _TemaCarta.centro => GlifoPixel.escuela,
  _TemaCarta.disculpas => GlifoPixel.check,
  _TemaCarta.proteccion => GlifoPixel.escudo,
  _TemaCarta.culpa => GlifoPixel.corazon,
  _TemaCarta.quitar => GlifoPixel.nube,
  _TemaCarta.borrar => GlifoPixel.papelera,
  _TemaCarta.denunciar => GlifoPixel.mano,
  _TemaCarta.ley => GlifoPixel.ley,
  _TemaCarta.otro => GlifoPixel.estrella,
};

/// Los colores del marco de cada carta pixel de la colección, por turnos (con su luz y su sombra): así cada carta tiene
/// siempre el mismo, aquí y en la lista. Son los azules de la marca (el amarillo va en la banda del título); el verde y
/// la teja quedan para el acierto y el fallo.
({Color color, Color luz, Color sombra}) coloresCartaPixel(int indice) => const [
  (color: ColoresUiPixel.azul, luz: ColoresUiPixel.azulClaro, sombra: ColoresUiPixel.marino),
  (color: ColoresUiPixel.marino, luz: ColoresUiPixel.azul, sombra: ColoresUiPixel.noche),
  (color: ColoresUiPixel.azulClaro, luz: ColoresUiPixel.cielo, sombra: ColoresUiPixel.azul),
  (color: ColoresUiPixel.cielo, luz: ColoresUiPixel.hielo, sombra: ColoresUiPixel.azulClaro),
][indice % 4];

/// Icono de un personaje según quién es, de la iconografía de TuTurno: la toga para la jueza o el juez y la ley para
/// la fiscal o el fiscal (nunca un mazo ni la balanza).
TuIcono iconoPersonaje(String personaje, {required bool protagonista}) {
  if (protagonista) return TuIcono.estrella;
  final clave = normalizar(personaje);
  bool tiene(List<String> palabras) => palabras.any(clave.contains);
  if (tiene(['psicolog'])) return TuIcono.idea;
  if (tiene(['tutor', 'profe', 'maestr'])) return TuIcono.aprende;
  if (tiene(['coordinador', 'bienestar'])) return TuIcono.escudo;
  if (tiene(['juez', 'jueza'])) return TuIcono.toga;
  if (tiene(['fiscal'])) return TuIcono.ley;
  if (tiene(['abogad'])) return TuIcono.expediente;
  if (tiene(['polic', 'agente', 'guardia'])) return TuIcono.escudo;
  if (tiene(['madre', 'padre', 'tia', 'tio', 'abuel', 'herman', 'familia', 'amig'])) return TuIcono.personaConfianza;
  return TuIcono.miSituacion;
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

/// «LECrim · art. 449 ter» («arts.» si son varios: «LOPIVI · arts. 17.1 y 34.1»); «art.» solo si es un artículo (empieza
/// por una cifra): «AEPD · Canal prioritario» o «AEPD · FAQ 15.03», no «art. FAQ 15.03».
String textoCita(CitaLegal cita) {
  final articulo = cita.articulo;
  if (articulo.isEmpty) return cita.norma;
  if (!RegExp(r'^\d').hasMatch(articulo)) return '${cita.norma} · $articulo';
  final varios = RegExp(r'\d.*( y |, )\d').hasMatch(articulo);
  return '${cita.norma} · ${varios ? 'arts.' : 'art.'} $articulo';
}

/// Si la cita es de una ley y no de la web de un organismo (la AEPD o el INCIBE), que no son leyes.
bool esLey(CitaLegal cita) => !const {'aepd', 'incibe'}.contains(normalizar(cita.norma.trim()));

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

/// Etiqueta con la fuente legal (con el icono de la ley). Al tocarla, una hoja explica de qué ley sale.
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
      label: 'Fuente: $fuente. Toca para ver de dónde sale',
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
                IconoTuTurno(
                  TuIcono.ley,
                  estilo: EstiloIcono.mono,
                  size: Espacio.m + Espacio.xs,
                  color: color,
                  decorativo: true,
                ),
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
                    IconoTuTurno(TuIcono.ley, estilo: EstiloIcono.mono, color: esquema.primary, decorativo: true),
                    const SizedBox(width: Espacio.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            textoCita(cita),
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
                citasDe(fuente).every(esLey)
                    ? 'Es la ley en la que se apoya lo que acabas de leer. Puedes enseñársela a una persona adulta de '
                          'confianza o a tu abogado o abogada.'
                    : 'Es la fuente oficial en la que se apoya lo que acabas de leer. Puedes enseñársela a una persona '
                          'adulta de confianza o a tu abogado o abogada.',
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

/// La fuente legal dentro del juego, en pixel: el libro de la ley y la norma («LECrim, art. 449 ter») en una ficha de
/// papel. Al tocarla, la misma hoja que [FuenteLegal] explica de qué ley sale. Mide 48 de alto como mínimo.
class FuentePixel extends StatelessWidget {
  const FuentePixel({super.key, required this.fuente});

  final String fuente;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    return Semantics(
      button: true,
      label: 'Fuente: $fuente. Toca para ver de dónde sale',
      excludeSemantics: true,
      onTap: () => _abrir(context),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _abrir(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: CajaPixel(
              estilo: const EstiloCajaPixel(
                relleno: ColoresUiPixel.hielo,
                luz: ColoresUiPixel.blanco,
                sombraInterior: ColoresUiPixel.cielo,
                esquina: 1,
              ),
              interior: const EdgeInsets.fromLTRB(2, 1, 3, 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const IconoPixel(GlifoPixel.ley, color: ColoresUiPixel.marino),
                  SizedBox(width: 2 * u),
                  Flexible(
                    // Con las cifras en su letra: en la letra pixel, «Ley 4/2015» se leería «Ley 4/201S».
                    child: Text.rich(
                      textoConCifras(
                        fuente,
                        estiloTextoPixel(
                          context,
                          TipoTextoPixel.etiqueta,
                          color: ColoresUiPixel.noche,
                        ).copyWith(decoration: TextDecoration.underline, decorationColor: ColoresUiPixel.marino),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _abrir(BuildContext context) {
    unawaited(Hapticos.seleccion());
    unawaited(mostrarFuenteLegal(context, fuente));
  }
}
