import 'dart:async';

import 'package:flutter/material.dart';

import '../../../pixel/ui/ui.dart';
import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../../../widgets/movimiento/hapticos.dart';
import '../modelos.dart';
import '../textos.dart';
import 'estilo.dart';
import 'piezas_pixel.dart';

// Cartas de derecho.
//
// - Dentro del caso, en pixel: [CartaPixelDerecho] (la carta del kit pixel con el dibujo de su derecho), su detalle
//   ([mostrarCartaPixel]) y la carta recién ganada ([mostrarCartaNueva] y [RevelarCarta]): primero sale bloqueada y, al
//   momento, se desbloquea con el brillo del kit, sobre un fondo azul noche casi opaco.
// - Fuera del caso (la colección plana de la lista): [CartaDerecho], [CartaBloqueada], [DorsoCarta], [RejillaCartas] y
//   [mostrarDetalleCarta].

/// Cara de una carta. [indice] elige su degradado; [grande] enseña también el texto.
class CartaDerecho extends StatelessWidget {
  const CartaDerecho({super.key, required this.carta, required this.indice, this.grande = false});

  final Carta carta;
  final int indice;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = degradadoCarta(context, indice);
    final tinta = tintaSobre(context, colores);
    final icono = iconoCarta(carta);
    final forma = BorderRadius.circular(Radios.l);
    return Semantics(
      container: true,
      label: 'Carta de derecho: ${carta.titulo}.${grande ? ' ${carta.texto}' : ''} Fuente: ${carta.fuente}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: degradadoDiagonal(colores),
          borderRadius: forma,
          boxShadow: sombrasPapel(context),
        ),
        child: ClipRRect(
          borderRadius: forma,
          child: Stack(
            children: [
              Positioned(
                right: -Espacio.l,
                bottom: -Espacio.l,
                child: Opacity(
                  opacity: 0.12,
                  child: IconoTuTurno(
                    icono,
                    estilo: EstiloIcono.mono,
                    size: grande ? 168 : 96,
                    color: tinta,
                    decorativo: true,
                  ),
                ),
              ),
              // Brillo en diagonal, como el de una carta de colección.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.16),
                        Colors.white.withValues(alpha: 0),
                      ],
                      stops: const [0.25, 0.45, 0.65],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(grande ? Espacio.l : Espacio.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _IconoRedondo(
                          icono: icono,
                          tinta: tinta,
                          tamano: grande ? Espacio.xxl + Espacio.s : Espacio.xxl,
                        ),
                        if (grande) ...[
                          const SizedBox(width: Espacio.s + Espacio.xs),
                          Expanded(
                            child: Text(
                              'Carta de derecho',
                              style: tema.textTheme.labelLarge?.copyWith(
                                color: tinta.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: grande ? Espacio.m : Espacio.s + Espacio.xs),
                    Text(
                      carta.titulo,
                      style: (grande ? tema.textTheme.headlineSmall : tema.textTheme.titleMedium)?.copyWith(
                        color: tinta,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    if (grande) ...[
                      const SizedBox(height: Espacio.s + Espacio.xs),
                      Text(carta.texto, style: tema.textTheme.bodyLarge?.copyWith(color: tinta, height: 1.4)),
                    ],
                    SizedBox(height: grande ? Espacio.l : Espacio.m),
                    Row(
                      children: [
                        IconoTuTurno(
                          TuIcono.ley,
                          estilo: EstiloIcono.mono,
                          size: Espacio.m,
                          color: tinta.withValues(alpha: 0.9),
                          decorativo: true,
                        ),
                        const SizedBox(width: Espacio.xs + 2),
                        Flexible(
                          child: Text(
                            carta.fuente,
                            style: tema.textTheme.labelMedium?.copyWith(
                              color: tinta.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carta que aún no se tiene: gris, con un candado y una pista de dónde se gana.
class CartaBloqueada extends StatelessWidget {
  const CartaBloqueada({super.key, this.pista});

  /// P. ej. «Caso de Lucía».
  final String? pista;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final pista = this.pista;
    return Semantics(
      container: true,
      label: 'Carta por descubrir.${pista == null ? '' : ' $pista.'}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: esquema.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Radios.l),
          border: Border.all(color: esquema.outlineVariant, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Espacio.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: Espacio.xxl,
                height: Espacio.xxl,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: esquema.surfaceContainerLow),
                child: IconoTuTurno(
                  TuIcono.candado,
                  estilo: EstiloIcono.mono,
                  color: esquema.onSurfaceVariant,
                  decorativo: true,
                ),
              ),
              const SizedBox(height: Espacio.s + Espacio.xs),
              Text(
                'Por descubrir',
                style: tema.textTheme.titleMedium?.copyWith(
                  color: esquema.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (pista != null) ...[
                const SizedBox(height: Espacio.xs),
                Text(pista, style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dorso de una carta: el degradado del juego con un dibujo de estrellas y una interrogación.
class DorsoCarta extends StatelessWidget {
  const DorsoCarta({super.key});

  @override
  Widget build(BuildContext context) {
    final colores = context.colores.juego;
    final tinta = tintaSobre(context, colores);
    final forma = BorderRadius.circular(Radios.l);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: degradadoDiagonal(colores),
        borderRadius: forma,
        border: Border.all(color: tinta.withValues(alpha: 0.35), width: 3),
      ),
      child: ClipRRect(
        borderRadius: forma,
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (var fila = 0; fila < 6; fila++)
              for (var columna = 0; columna < 4; columna++)
                Align(
                  alignment: Alignment(-0.9 + columna * 0.6 + (fila.isOdd ? 0.3 : 0), -0.92 + fila * 0.37),
                  child: Icon(Icons.star_rounded, size: Espacio.m, color: tinta.withValues(alpha: 0.12)),
                ),
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tinta.withValues(alpha: 0.16),
                  border: Border.all(color: tinta.withValues(alpha: 0.5), width: 2),
                ),
                child: Icon(Icons.question_mark_rounded, size: 52, color: tinta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconoRedondo extends StatelessWidget {
  const _IconoRedondo({required this.icono, required this.tinta, required this.tamano});

  final TuIcono icono;
  final Color tinta;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tinta.withValues(alpha: 0.18),
        border: Border.all(color: tinta.withValues(alpha: 0.4), width: 1.5),
      ),
      child: IconoTuTurno(icono, estilo: EstiloIcono.mono, size: tamano * 0.52, color: tinta, decorativo: true),
    );
  }
}

/// Coloca [hijos] en filas de [columnas], todas las de una fila con la misma altura (crece con la letra).
class RejillaCartas extends StatelessWidget {
  const RejillaCartas({super.key, required this.hijos, this.columnas = 2});

  final List<Widget> hijos;
  final int columnas;

  @override
  Widget build(BuildContext context) {
    final filas = <Widget>[];
    for (var i = 0; i < hijos.length; i += columnas) {
      if (filas.isNotEmpty) filas.add(const SizedBox(height: Espacio.m));
      filas.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < columnas; j++) ...[
                if (j > 0) const SizedBox(width: Espacio.m),
                Expanded(child: i + j < hijos.length ? hijos[i + j] : const SizedBox.shrink()),
              ],
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: filas);
  }
}

/// Hoja con una carta de la colección en grande y de dónde sale.
Future<void> mostrarDetalleCarta(BuildContext context, {required Carta carta, required int indice}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Espacio.l, 0, Espacio.l, Espacio.l),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CartaDerecho(carta: carta, indice: indice, grande: true),
              const SizedBox(height: Espacio.m),
              Align(
                alignment: Alignment.centerLeft,
                child: FuenteLegal(fuente: carta.fuente),
              ),
              const SizedBox(height: Espacio.m),
              FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Una carta de derecho en pixel, con el dibujo de su derecho, su número en la colección ([indice] + 1) y los colores
/// de su sitio. Para el lector de pantalla es «Carta: {título}» (o «Carta por descubrir», si está [bloqueada]); con
/// [onPressed], un botón que la abre en grande.
class CartaPixelDerecho extends StatelessWidget {
  const CartaPixelDerecho({
    super.key,
    required this.carta,
    required this.indice,
    this.bloqueada = false,
    this.pista = 'Sigue el caso para conseguirla.',
    this.formato = FormatoCartaPixel.horizontal,
    this.brillo = true,
    this.icono,
    this.indicacion,
    this.onPressed,
  });

  final Carta carta;
  final int indice;
  final bool bloqueada;
  final String pista;
  final FormatoCartaPixel formato;
  final bool brillo;

  /// El dibujo, si no es el de su derecho ([glifoCarta]): por ejemplo, el edificio del juzgado.
  final GlifoPixel? icono;

  /// Qué pasa al tocarla, para el lector de pantalla. Null: «Toca para verla en grande».
  final String? indicacion;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colores = coloresCartaPixel(indice);
    final onPressed = this.onPressed;
    return Semantics(
      container: true,
      button: onPressed != null ? true : null,
      label: bloqueada ? 'Carta por descubrir' : 'Carta: ${carta.titulo}',
      value: bloqueada ? pista : carta.texto,
      hint: onPressed == null ? null : indicacion ?? 'Toca para verla en grande',
      onTap: onPressed,
      excludeSemantics: true,
      child: CartaPixel(
        numero: indice + 1,
        titulo: carta.titulo,
        texto: carta.texto,
        icono: icono ?? glifoCarta(carta),
        bloqueada: bloqueada,
        pista: pista,
        formato: formato,
        brillo: brillo,
        color: colores.color,
        luz: colores.luz,
        sombraColor: colores.sombra,
        onPressed: onPressed,
      ),
    );
  }
}

/// Una carta de la colección en grande, en pixel: la carta de pie, de dónde sale y «Cerrar». [icono]: el dibujo, si no
/// es el de su derecho.
Future<void> mostrarCartaPixel(BuildContext context, {required Carta carta, required int indice, GlifoPixel? icono}) =>
    mostrarVentanaPixel<void>(
      context,
      (context) => VentanaCartaPixel(
        carta: CartaPixelDerecho(
          carta: carta,
          indice: indice,
          formato: FormatoCartaPixel.vertical,
          brillo: false,
          icono: icono,
        ),
        fuente: carta.fuente,
        botones: [
          BotonPixel(
            etiqueta: 'Cerrar',
            variante: VarianteBotonPixel.secundario,
            expandido: true,
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );

/// Enseña una carta recién ganada, en pixel: sale bloqueada, se desbloquea con el brillo del kit y vibra. Con «reducir
/// animaciones» aparece ya desbloqueada. [xp] son los puntos que ha sumado (0 para no enseñarlos). La usan los casos y
/// «El juzgado por dentro» ([icono]: el dibujo, si no es el de su derecho).
Future<void> mostrarCartaNueva(
  BuildContext context, {
  required Carta carta,
  required int indice,
  int xp = 0,
  GlifoPixel? icono,
  bool? lecturaFacil,
}) => mostrarVentanaPixel<void>(
  context,
  (context) => RevelarCarta(carta: carta, indice: indice, xp: xp, icono: icono),
  lecturaFacil: lecturaFacil,
);

/// La ventana de una carta recién ganada: «¡Carta nueva!», la carta, los puntos y «¡A mi colección!».
class RevelarCarta extends StatefulWidget {
  const RevelarCarta({super.key, required this.carta, required this.indice, this.xp = 0, this.icono});

  final Carta carta;
  final int indice;
  final int xp;
  final GlifoPixel? icono;

  /// Lo que tarda en desbloquearse.
  static const espera = Duration(milliseconds: 450);

  @override
  State<RevelarCarta> createState() => _RevelarCartaState();
}

class _RevelarCartaState extends State<RevelarCarta> with SingleTickerProviderStateMixin {
  /// La espera hasta desbloquearla (un controlador y no un Timer: se para con la pantalla tapada y las pruebas lo
  /// esperan con pumpAndSettle).
  late final AnimationController _espera = AnimationController(vsync: this, duration: RevelarCarta.espera)
    ..addStatusListener((estado) {
      if (estado == AnimationStatus.completed) _desbloquear();
    });
  var _bloqueada = true;
  var _preparada = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preparada) return;
    _preparada = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      // Ya desbloqueada desde el principio; vibra igual, una vez.
      _bloqueada = false;
      unawaited(Hapticos.acierto());
    } else {
      _espera.forward();
    }
  }

  void _desbloquear() {
    if (!mounted || !_bloqueada) return;
    unawaited(Hapticos.acierto());
    setState(() => _bloqueada = false);
  }

  @override
  void dispose() {
    _espera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    return VentanaCartaPixel(
      titulo: tituloCartaNueva,
      carta: CartaPixelDerecho(
        carta: widget.carta,
        indice: widget.indice,
        bloqueada: _bloqueada,
        pista: 'Ya casi es tuya…',
        formato: FormatoCartaPixel.vertical,
        icono: widget.icono,
      ),
      fuente: widget.carta.fuente,
      extra: widget.xp <= 0
          ? null
          : MergeSemantics(
              child: Semantics(
                label: '+${widget.xp} puntos',
                excludeSemantics: true,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const IconoPixel(GlifoPixel.estrella, color: ColoresUiPixel.amarillo),
                    SizedBox(width: 2 * u),
                    RotuloPixel('+${widget.xp}', color: ColoresUiPixel.amarillo),
                    SizedBox(width: 2 * u),
                    TextoPixel('puntos', tipo: TipoTextoPixel.etiqueta, color: ColoresUiPixel.papel),
                  ],
                ),
              ),
            ),
      botones: [
        BotonPixel(
          etiqueta: botonAMiColeccion,
          icono: const IconoPixel(GlifoPixel.carta),
          expandido: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// La disposición de las ventanas de cartas (para abrirla, [mostrarVentanaPixel]): título, carta, fuente (si la hay),
/// lo de [extra] y los botones, uno debajo de otro, centrados y con scroll si no caben (letra grande).
class VentanaCartaPixel extends StatelessWidget {
  const VentanaCartaPixel({
    super.key,
    this.titulo,
    required this.carta,
    this.fuente = '',
    this.extra,
    required this.botones,
  });

  final String? titulo;
  final Widget carta;

  /// De qué ley sale ([FuentePixel]). Vacía: no se enseña (una carta por descubrir, la del juzgado).
  final String fuente;
  final Widget? extra;
  final List<Widget> botones;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final titulo = this.titulo;
    return Material(
      type: MaterialType.transparency,
      child: FondoPixel(
        color: ColoresUiPixel.noche,
        pintar: false,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Espacio.l),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (titulo != null) ...[
                      Semantics(
                        header: true,
                        liveRegion: true,
                        child: TextoPixel(
                          titulo,
                          tipo: TipoTextoPixel.grande,
                          color: ColoresUiPixel.amarillo,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 5 * u),
                    ],
                    carta,
                    if (fuente.isNotEmpty) ...[SizedBox(height: 3 * u), Center(child: FuentePixel(fuente: fuente))],
                    if (extra case final extra?) ...[SizedBox(height: 3 * u), extra],
                    for (final (i, boton) in botones.indexed) ...[SizedBox(height: (i == 0 ? 5 : 2) * u), boton],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
