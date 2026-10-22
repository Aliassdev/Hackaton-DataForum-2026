import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/progreso.dart';
import '../../../pixel/motor/motor.dart';
import '../../../pixel/personajes/personajes.dart';
import '../../../pixel/ui/ui.dart';
import '../../../tema.dart';
import '../../../widgets/modulos.dart' show anchoMaximo;
import '../modelos.dart';
import '../motor.dart';
import '../textos.dart';
import 'cabecera_escena.dart';
import 'estilo.dart';
import 'piezas_pixel.dart';

// Una escena de un caso en pixel, de arriba abajo: «Caso de Lucía · 11 años», la escena (el lugar y quién sale, con
// sus fichas), la narración en una ventana de diálogo de juego de rol (letra a letra, al ritmo de la voz), las palabras
// del glosario y, cuando la narración está entera, la decisión: «Tu turno», la pregunta, las opciones con su cursor y,
// al elegir, la explicación de Tut con su fuente.

/// Qué se está leyendo en voz alta.
enum LecturaCaso { narracion, explicacion }

/// Lo que se lee en voz alta al entrar en una escena: la narración y, si la hay, la pregunta.
String textoEscena(Escena escena) =>
    [escena.narracion, ?escena.decision?.pregunta].where((t) => t.trim().isNotEmpty).join(' ');

/// Lo que se lee al elegir una opción: si es correcta o no y la explicación.
String textoExplicacion(Opcion opcion) => '${opcion.correcta ? tituloAcierto : tituloFallo} ${opcion.feedback}';

/// El orden en que se enseñan las opciones de una decisión: el del contenido, girado según la escena ([clave]: el caso
/// y la escena), siempre el mismo para la misma escena. En los casos, la respuesta correcta suele ir la primera; así no
/// se aprende a elegir siempre la de arriba (guía del kit pixel). Devuelve, para cada sitio, el índice de la opción.
List<int> ordenDeLasOpciones(String clave, int cuantas) {
  if (cuantas < 2) return [for (var i = 0; i < cuantas; i++) i];
  final giro = clave.codeUnits.fold(0, (suma, c) => (suma * 31 + c) & 0x7fffffff) % cuantas;
  return [for (var i = 0; i < cuantas; i++) (i + giro) % cuantas];
}

/// Letras por segundo de la narración mientras la lee la voz, según su velocidad en Ajustes (0,5 es la normal): así el
/// texto aparece más o menos a la vez que se oye. Al acabar la voz, el texto se completa del todo.
double letrasPorSegundoConVoz(double velocidad) => (32 * velocidad).clamp(8.0, 40.0);

/// Letras por segundo de la narración sin voz (las del kit).
const letrasPorSegundoSinVoz = 40.0;

/// Una escena del caso. Se monta de nuevo en cada escena (va con su clave), con su propio diálogo.
class VistaEscenaJuego extends StatefulWidget {
  const VistaEscenaJuego({
    super.key,
    required this.partida,
    required this.terminos,
    required this.leyendo,
    required this.hablando,
    required this.letrasPorSegundo,
    required this.onElegir,
    required this.onAlternarLectura,
    required this.onTermino,
    this.onDialogo,
  });

  final Partida partida;

  /// Términos del glosario que se buscan en la narración (con sus variantes), cada uno con el término al que lleva.
  final Map<String, String> terminos;
  final ValueListenable<LecturaCaso?> leyendo;
  final ValueListenable<bool> hablando;

  /// Velocidad de la máquina de escribir de la narración (0: sale entera).
  final double letrasPorSegundo;
  final ValueChanged<int> onElegir;
  final void Function(String texto, LecturaCaso que) onAlternarLectura;

  /// Abre el glosario en ese término.
  final ValueChanged<String> onTermino;

  /// Recibe el diálogo de la narración al montar la escena (activo: true) y al quitarla (false), para completarlo
  /// cuando la voz acaba de leer.
  final void Function(ControladorDialogoPixel dialogo, {required bool activo})? onDialogo;

  @override
  State<VistaEscenaJuego> createState() => _VistaEscenaJuegoState();
}

class _VistaEscenaJuegoState extends State<VistaEscenaJuego> {
  final _scroll = ScrollController();
  final _claveDialogo = GlobalKey();
  final _claveDecision = GlobalKey();
  final _claveExplicacion = GlobalKey();
  final _dialogo = ControladorDialogoPixel();

  /// La narración ya está entera: se puede decidir.
  var _narracionEntera = false;

  /// La narración sale entera nada más abrir la escena (con «reducir animaciones» o con lector de pantalla): entonces
  /// no se desplaza al aparecer la decisión, y se empieza a leer desde arriba.
  bool? _enteraAlMontar;

  /// La velocidad de la narración, la de cuando se montó la escena: si cambia la voz a mitad, el texto no vuelve a
  /// escribirse desde el principio.
  late final double _letras = widget.letrasPorSegundo;

  @override
  void initState() {
    super.initState();
    _dialogo.addListener(_alCambiarDialogo);
    widget.onDialogo?.call(_dialogo, activo: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enteraAlMontar ??= _letras <= 0 || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
  }

  @override
  void didUpdateWidget(VistaEscenaJuego anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.partida.eleccion == null && widget.partida.eleccion != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revelar(_claveExplicacion));
    }
  }

  @override
  void dispose() {
    widget.onDialogo?.call(_dialogo, activo: false);
    _dialogo
      ..removeListener(_alCambiarDialogo)
      ..dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _alCambiarDialogo() {
    if (!_dialogo.completo || _narracionEntera || !mounted) return;
    setState(() => _narracionEntera = true);
    // Al aparecer la decisión, se desplaza lo justo para ver la pregunta, pero sin que el principio de la narración se
    // salga por arriba. Si la narración ya salía entera al abrir la escena, no se desplaza: la decisión espera debajo.
    if (widget.partida.decision != null && !(_enteraAlMontar ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _revelar(_claveDecision, soloPrincipio: true, tope: _claveDialogo),
      );
    }
  }

  /// Desplaza lo justo para que se vea [clave] entera (o su principio, si [soloPrincipio] o no cabe), sin que su
  /// principio se salga por arriba. Con [tope], tampoco pasa del principio de [tope] (la primera línea de la narración
  /// se sigue viendo). Nunca sube.
  void _revelar(GlobalKey clave, {bool soloPrincipio = false, GlobalKey? tope}) {
    final caja = clave.currentContext?.findRenderObject();
    if (!mounted || caja == null || !_scroll.hasClients) return;
    final vista = RenderAbstractViewport.maybeOf(caja);
    if (vista == null) return;
    final posicion = _scroll.position;
    final arriba = vista.getOffsetToReveal(caja, 0).offset - Espacio.m;
    final abajo = soloPrincipio
        ? arriba - posicion.viewportDimension * 0.5
        : vista.getOffsetToReveal(caja, 1).offset + Espacio.m;
    var destino = math.min(arriba, math.max(posicion.pixels, abajo));
    final cajaTope = tope?.currentContext?.findRenderObject();
    if (cajaTope != null) {
      destino = math.max(posicion.pixels, math.min(destino, vista.getOffsetToReveal(cajaTope, 0).offset - Espacio.m));
    }
    destino = destino.clamp(0.0, posicion.maxScrollExtent);
    if ((destino - posicion.pixels).abs() < 1) return;
    final tiempo = duracion(context, Duracion.larga);
    if (tiempo == Duration.zero) {
      _scroll.jumpTo(destino);
    } else {
      _scroll.animateTo(destino, duration: tiempo, curve: Curves.easeOutCubic);
    }
  }

  /// Lo que se deja como mínimo para leer debajo de la escena fija; si no cabe, la escena se desplaza con el texto.
  static const _altoMinimoLectura = 320.0;

  @override
  Widget build(BuildContext context) {
    final partida = widget.partida;
    final escena = partida.escena;
    final caso = partida.caso;
    final u = unidadPixel(context);
    final decidir = partida.decision != null && (_narracionEntera || partida.eleccion != null);
    final cabecera = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LineaCasoPixel(protagonista: caso.protagonista, edad: caso.edad),
        SizedBox(height: 3 * u),
        CabeceraEscena(escena: escena, protagonista: caso.protagonista, conFichas: false),
      ],
    );
    final resto = [
      // Al abrir el caso, Tut (contento) saluda y explica cómo se juega.
      if (partida.numeroEscena == 1) ...[SaludoTutPixel(protagonista: caso.protagonista), SizedBox(height: 4 * u)],
      if (escena.personajes.isNotEmpty) ...[
        FichasPersonajes(nombres: escena.personajes, lugar: escena.lugar, protagonista: caso.protagonista),
        SizedBox(height: 5 * u),
      ],
      DialogoPixel(
        key: _claveDialogo,
        hablante: Lugar.desde(escena.lugar).nombre,
        texto: escena.narracion,
        controlador: _dialogo,
        caracteresPorSegundo: _letras,
      ),
      SizedBox(height: 3 * u),
      Align(
        alignment: Alignment.centerLeft,
        child: ListenableBuilder(
          listenable: Listenable.merge([widget.leyendo, widget.hablando]),
          builder: (context, _) => BotonEscucharPixel(
            key: const Key('boton-escuchar'),
            leyendo: widget.hablando.value && widget.leyendo.value == LecturaCaso.narracion,
            que: 'la narración',
            onPressed: () => widget.onAlternarLectura(textoEscena(escena), LecturaCaso.narracion),
          ),
        ),
      ),
      if (TerminosEscena.encontrar(escena.narracion, widget.terminos).isNotEmpty) ...[
        SizedBox(height: 4 * u),
        TerminosEscena(texto: escena.narracion, terminos: widget.terminos, onTermino: widget.onTermino),
      ],
      if (decidir) ...[
        SizedBox(height: 6 * u),
        _DecisionPixel(
          key: _claveDecision,
          partida: partida,
          claveExplicacion: _claveExplicacion,
          leyendo: widget.leyendo,
          hablando: widget.hablando,
          onElegir: widget.onElegir,
          onAlternarLectura: widget.onAlternarLectura,
        ),
      ],
    ];
    Widget centrar(Widget hijo) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: anchoMaximo),
        child: hijo,
      ),
    );
    return LayoutBuilder(
      builder: (context, limites) {
        // La escena (con la línea del caso) se queda fija arriba si debajo queda sitio para leer: así se ve el lugar
        // mientras se lee y se decide (la cámara de la Sala Gesell, por ejemplo). En pantallas bajas o con la letra muy
        // grande, todo se desplaza junto.
        final ancho = math.min(limites.maxWidth - 2 * Espacio.m, anchoMaximo);
        final altoLinea = altoLineaPixel(context, estiloTextoPixel(context, TipoTextoPixel.etiqueta));
        final altoEscena = ancho * 96 / 160 + (2 * MarcoPixel.grosor + 1) * u + altoLinea + 7 * u;
        final fija = limites.hasBoundedHeight && limites.maxHeight - altoEscena >= _altoMinimoLectura;
        final desplazable = ScrollConSombraPixel(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(Espacio.m, (fija ? 3 : 4) * u, Espacio.m, 8 * u),
          child: centrar(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!fija) ...[cabecera, SizedBox(height: 3 * u)],
                ...resto,
              ],
            ),
          ),
        );
        if (!fija) return desplazable;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(padding: EdgeInsets.fromLTRB(Espacio.m, 4 * u, Espacio.m, 0), child: centrar(cabecera)),
            Expanded(child: desplazable),
          ],
        );
      },
    );
  }
}

/// Tut, contento, al abrir un caso: «Soy Tut. Vas a acompañar a Lucía. Cuando sea tu turno, decides tú.».
class SaludoTutPixel extends StatelessWidget {
  const SaludoTutPixel({super.key, required this.protagonista});

  final String protagonista;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    return MergeSemantics(
      child: Row(
        children: [
          SpritePixel(sprite: PersonajesPixel.tutFeliz, ancho: 20 * u, etiqueta: 'Tut'),
          SizedBox(width: 2 * u),
          Expanded(
            child: CajaPixel(
              estilo: const EstiloCajaPixel(
                relleno: ColoresUiPixel.hielo,
                luz: ColoresUiPixel.blanco,
                sombraInterior: ColoresUiPixel.cielo,
                esquina: 2,
              ),
              interior: const EdgeInsets.fromLTRB(3, 2, 3, 2),
              child: TextoPixel(saludoTut(protagonista), tipo: TipoTextoPixel.pequeno, color: ColoresUiPixel.noche),
            ),
          ),
        ],
      ),
    );
  }
}

/// «Caso de Lucía · 11 años», la primera línea de cada escena (el título de la barra es solo el nombre, para que no se
/// corte: auditoría P1-1). La edad, con las cifras que se leen bien (en la letra pixel, el 5 parece una S).
class LineaCasoPixel extends StatelessWidget {
  const LineaCasoPixel({
    super.key,
    required this.protagonista,
    this.edad,
    this.color = ColoresUiPixel.amarillo,
    this.colorSuave = ColoresUiPixel.cielo,
  });

  final String protagonista;
  final int? edad;

  /// El color de «Caso de Lucía» y el de « · 11 años» (por defecto, para el azul noche del juego).
  final Color color;
  final Color colorSuave;

  @override
  Widget build(BuildContext context) {
    final estilo = estiloTextoPixel(context, TipoTextoPixel.etiqueta, color: color);
    return MergeSemantics(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text.rich(textoConCifras(tituloCaso(protagonista), estilo)),
          if (edad != null) Text.rich(textoConCifras(edadCaso(edad), estilo.copyWith(color: colorSuave))),
        ],
      ),
    );
  }
}

class _DecisionPixel extends StatelessWidget {
  const _DecisionPixel({
    super.key,
    required this.partida,
    required this.claveExplicacion,
    required this.leyendo,
    required this.hablando,
    required this.onElegir,
    required this.onAlternarLectura,
  });

  final Partida partida;
  final GlobalKey claveExplicacion;
  final ValueListenable<LecturaCaso?> leyendo;
  final ValueListenable<bool> hablando;
  final ValueChanged<int> onElegir;
  final void Function(String texto, LecturaCaso que) onAlternarLectura;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final decision = partida.decision!;
    final opcion = partida.opcionElegida;
    final eleccion = partida.eleccion;
    final orden = ordenDeLasOpciones('${partida.caso.id}/${partida.escena.id}', decision.opciones.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RotuloTurnoPixel(),
        SizedBox(height: 3 * u),
        Semantics(
          header: true,
          child: TextoPixel(decision.pregunta, tipo: TipoTextoPixel.titulo, color: ColoresUiPixel.papel),
        ),
        SizedBox(height: 4 * u),
        MenuOpcionesPixel(
          opciones: [for (final i in orden) decision.opciones[i].texto],
          correctas: {
            for (final (sitio, i) in orden.indexed)
              if (decision.opciones[i].correcta) sitio,
          },
          elegida: eleccion == null ? null : orden.indexOf(eleccion),
          // Al fallar no se destapa la buena: se puede probar otra vez (y la explicación ya cuenta por qué).
          revelarCorrecta: false,
          etiqueta: decision.pregunta,
          onElegir: eleccion == null ? (sitio) => onElegir(orden[sitio]) : null,
        ),
        if (opcion != null) ...[
          SizedBox(height: 5 * u),
          ListenableBuilder(
            listenable: Listenable.merge([leyendo, hablando]),
            builder: (context, _) => ExplicacionPixel(
              key: claveExplicacion,
              partida: partida,
              opcion: opcion,
              leyendo: hablando.value && leyendo.value == LecturaCaso.explicacion,
              onAlternar: () => onAlternarLectura(textoExplicacion(opcion), LecturaCaso.explicacion),
            ),
          ),
        ],
      ],
    );
  }
}

/// La explicación tras elegir, con Tut (siempre contento: fallar no es malo): «¡Bien visto!» o «Mira por qué:»,
/// por qué, de qué ley sale y si hay carta.
class ExplicacionPixel extends ConsumerWidget {
  const ExplicacionPixel({
    super.key,
    required this.partida,
    required this.opcion,
    required this.leyendo,
    required this.onAlternar,
  });

  final Partida partida;
  final Opcion opcion;
  final bool leyendo;
  final VoidCallback onAlternar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = unidadPixel(context);
    final acierto = opcion.correcta;
    final coleccion = ref.watch(progresoProvider.select((p) => p.cartas));
    final elegida = opcion.carta;
    // Otra respuesta correcta de esta escena da una carta que aún no se tiene: se puede volver a buscarla.
    final hayOtraCarta =
        acierto &&
        partida.decision!.opciones.any(
          (o) => o.correcta && o.carta != null && o.carta != elegida && !coleccion.contains(o.carta),
        );
    return Semantics(
      container: true,
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2 * u),
            child: SpritePixel(sprite: PersonajesPixel.tutFeliz, ancho: 16 * u, alto: 15 * u),
          ),
          SizedBox(width: 2 * u),
          Expanded(
            child: CajaPixel(
              estilo: const EstiloCajaPixel(
                relleno: ColoresUiPixel.papel,
                luz: ColoresUiPixel.blanco,
                sombraInterior: ColoresUiPixel.crema,
                esquina: 2,
              ),
              interior: const EdgeInsets.fromLTRB(4, 3, 4, 4),
              child: FondoPixel(
                color: ColoresUiPixel.papel,
                pintar: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconoPixel(
                          acierto ? GlifoPixel.check : GlifoPixel.bombilla,
                          color: acierto ? ColoresUiPixel.verdeOscuro : ColoresUiPixel.ocre,
                        ),
                        SizedBox(width: 3 * u),
                        Expanded(
                          child: TextoPixel(
                            acierto ? tituloAcierto : tituloFallo,
                            tipo: TipoTextoPixel.titulo,
                            color: ColoresUiPixel.noche,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2 * u),
                    TextoPixel(opcion.feedback, color: ColoresUiPixel.noche),
                    if (opcion.fuente.isNotEmpty) ...[SizedBox(height: 2 * u), FuentePixel(fuente: opcion.fuente)],
                    if (partida.cartaNueva != null) ...[
                      SizedBox(height: 2 * u),
                      const AvisoPixel(glifo: GlifoPixel.carta, texto: avisoCartaNueva, destacado: true),
                    ] else if (partida.cartaDeLaEleccion != null) ...[
                      SizedBox(height: 2 * u),
                      const AvisoPixel(glifo: GlifoPixel.carta, texto: avisoCartaRepetida),
                    ],
                    if (hayOtraCarta) ...[
                      SizedBox(height: 2 * u),
                      const AvisoPixel(glifo: GlifoPixel.estrella, texto: pistaOtraCarta),
                    ],
                    SizedBox(height: 3 * u),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: BotonEscucharPixel(
                        key: const Key('boton-escuchar-explicacion'),
                        leyendo: leyendo,
                        que: 'la explicación',
                        onPressed: onAlternar,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
