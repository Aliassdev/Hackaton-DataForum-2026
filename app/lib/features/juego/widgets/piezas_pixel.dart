import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../pixel/motor/motor.dart';
import '../../../pixel/personajes/personajes.dart';
import '../../../pixel/ui/ui.dart';
import '../../../tema.dart';
import '../../../widgets/texto_con_terminos.dart' show trocearTexto;
import '../textos.dart';

// Piezas pixel de la pantalla de un caso (CasoScreen), hechas con el kit de lib/pixel/ui: todo sobre el azul noche
// del juego, con la letra pixel (o la de lectura fácil, si está activada: TemaPixel).

/// «Escuchar» o «Parar»: lee en voz alta (o deja de leer) [que] («la narración», «la explicación»).
class BotonEscucharPixel extends StatelessWidget {
  const BotonEscucharPixel({super.key, required this.leyendo, required this.que, required this.onPressed});

  final bool leyendo;

  /// «la narración»: para el lector de pantalla.
  final String que;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BotonPixel(
      etiqueta: leyendo ? botonParar : botonEscuchar,
      semantica: leyendo ? 'Parar la lectura' : 'Escuchar $que',
      icono: IconoPixel(leyendo ? GlifoPixel.parar : GlifoPixel.altavoz),
      variante: VarianteBotonPixel.secundario,
      onPressed: onPressed,
    );
  }
}

/// Un aviso corto con su dibujo (la carta nueva, la carta repetida, la pista de otra carta).
class AvisoPixel extends StatelessWidget {
  const AvisoPixel({super.key, required this.glifo, required this.texto, this.destacado = false});

  final GlifoPixel glifo;
  final String texto;

  /// En amarillo (la carta nueva); si no, en azul hielo.
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    return CajaPixel(
      estilo: destacado
          ? const EstiloCajaPixel(
              relleno: ColoresUiPixel.amarillo,
              luz: ColoresUiPixel.amarilloLuz,
              sombraInterior: ColoresUiPixel.ocre,
              esquina: 1,
            )
          : const EstiloCajaPixel(
              relleno: ColoresUiPixel.hielo,
              luz: ColoresUiPixel.blanco,
              sombraInterior: ColoresUiPixel.cielo,
              esquina: 1,
            ),
      interior: const EdgeInsets.fromLTRB(3, 2, 3, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: u),
            child: IconoPixel(glifo, color: ColoresUiPixel.noche),
          ),
          SizedBox(width: 3 * u),
          Expanded(
            child: TextoPixel(texto, tipo: TipoTextoPixel.pequeno, color: ColoresUiPixel.noche),
          ),
        ],
      ),
    );
  }
}

/// Sombra tramada de azul noche bajo la barra de arriba, cuando lo de debajo se ha desplazado: así el texto que pasa
/// por debajo no parece montado encima de la barra (auditoría P2-1). Es una trama de pixel, no un degradado suave.
class SombraDesplazamientoPixel extends StatelessWidget {
  const SombraDesplazamientoPixel({super.key, required this.visible});

  final ValueListenable<bool> visible;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return IgnorePointer(
      child: ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (context, visible, _) => visible
            ? AjustePixel(
                child: CustomPaint(
                  size: Size(double.infinity, 4 * u),
                  painter: _PintorSombraTramada(u: u, dpr: dpr),
                ),
              )
            : SizedBox(height: 4 * u),
      ),
    );
  }
}

class _PintorSombraTramada extends CustomPainter {
  const _PintorSombraTramada({required this.u, required this.dpr});

  final double u;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    final ancho = (size.width * dpr).roundToDouble() / dpr;
    final columnas = (ancho / u).ceil();
    final noche = Paint()
      ..color = ColoresUiPixel.noche
      ..isAntiAlias = false;
    // Fila entera, dos de damero (una de cada dos y una de cada cuatro celdas) y nada: de opaco a transparente.
    canvas.drawRect(Rect.fromLTWH(0, 0, ancho, u), noche);
    for (var c = 0; c < columnas; c += 2) {
      canvas.drawRect(Rect.fromLTWH(c * u, u, u, u), noche);
    }
    for (var c = 1; c < columnas; c += 4) {
      canvas.drawRect(Rect.fromLTWH(c * u, 2 * u, u, u), noche);
    }
  }

  @override
  bool shouldRepaint(_PintorSombraTramada oldDelegate) => oldDelegate.u != u || oldDelegate.dpr != dpr;
}

/// Lo que se desplaza en la pantalla de un caso, con la [SombraDesplazamientoPixel] arriba en cuanto se ha desplazado
/// algo (auditoría P2-1). Ocupa todo el sitio que le den.
class ScrollConSombraPixel extends StatefulWidget {
  const ScrollConSombraPixel({super.key, this.controller, this.padding, required this.child});

  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final Widget child;

  @override
  State<ScrollConSombraPixel> createState() => _ScrollConSombraPixelState();
}

class _ScrollConSombraPixelState extends State<ScrollConSombraPixel> {
  final _desplazado = ValueNotifier(false);

  @override
  void dispose() {
    _desplazado.dispose();
    super.dispose();
  }

  bool _alDesplazar(ScrollNotification aviso) {
    if (aviso.depth == 0 && aviso.metrics.axis == Axis.vertical) _desplazado.value = aviso.metrics.pixels > 0.5;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _alDesplazar,
      child: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(controller: widget.controller, padding: widget.padding, child: widget.child),
          Positioned(top: 0, left: 0, right: 0, child: SombraDesplazamientoPixel(visible: _desplazado)),
        ],
      ),
    );
  }
}

/// Fondo de las ventanas del juego: azul noche casi opaco (auditoría P2-2: así no se lee lo de detrás).
const fondoVentanaPixel = Color(0xF20E1A4F);

/// Abre [constructor] en una ventana sobre el fondo azul noche del juego, que aparece a bloques (con «reducir
/// animaciones», sin moverse), con la letra del juego que haya en [context] (pixel o de lectura fácil) o, si se da,
/// la de [lecturaFacil].
Future<T?> mostrarVentanaPixel<T>(
  BuildContext context,
  WidgetBuilder constructor, {
  bool cerrarFuera = true,
  bool? lecturaFacil,
}) {
  final tema = TemaPixel.maybeOf(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: cerrarFuera,
    barrierLabel: 'Cerrar',
    barrierColor: fondoVentanaPixel,
    transitionDuration: duracion(context, Duracion.media),
    transitionBuilder: transicionPixel,
    pageBuilder: (context, _, _) => TemaPixel(
      lecturaFacil: lecturaFacil ?? tema?.lecturaFacil ?? false,
      unidad: tema?.unidad,
      child: Builder(builder: constructor),
    ),
  );
}

/// Pregunta antes de hacer algo que no se puede deshacer (empezar de nuevo). Devuelve true si se confirma.
Future<bool> confirmarPixel(
  BuildContext context, {
  required String titulo,
  required String texto,
  required String si,
  String no = cancelar,
  bool? lecturaFacil,
}) async {
  final respuesta = await mostrarVentanaPixel<bool>(
    context,
    lecturaFacil: lecturaFacil,
    (context) => VentanaPixel(
      titulo: titulo,
      botones: [
        BotonPixel(
          etiqueta: no,
          variante: VarianteBotonPixel.secundario,
          expandido: true,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        BotonPixel(etiqueta: si, expandido: true, onPressed: () => Navigator.of(context).pop(true)),
      ],
      children: [TextoPixel(texto, tipo: TipoTextoPixel.cuerpo, color: ColoresUiPixel.noche)],
    ),
  );
  return respuesta ?? false;
}

/// Una ventana de papel del juego, centrada: título, contenido y botones (uno debajo de otro).
class VentanaPixel extends StatelessWidget {
  const VentanaPixel({super.key, required this.titulo, required this.children, this.botones = const []});

  final String titulo;
  final List<Widget> children;
  final List<Widget> botones;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Espacio.l),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: CajaPixel(
                estilo: const EstiloCajaPixel(
                  relleno: ColoresUiPixel.papel,
                  luz: ColoresUiPixel.blanco,
                  sombraInterior: ColoresUiPixel.crema,
                  esquina: 3,
                ),
                interior: const EdgeInsets.all(6),
                child: FondoPixel(
                  color: ColoresUiPixel.papel,
                  pintar: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: TextoPixel(titulo, tipo: TipoTextoPixel.titulo, color: ColoresUiPixel.noche),
                      ),
                      SizedBox(height: 3 * u),
                      ...children,
                      for (final boton in botones) ...[SizedBox(height: 3 * u), boton],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mientras se carga el caso: Tut, contento, y «Preparando la sala…».
class CargandoPixel extends StatelessWidget {
  const CargandoPixel({super.key, this.mensaje = cargandoCaso});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    return Center(
      child: Semantics(
        liveRegion: true,
        label: mensaje,
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SpritePixel(sprite: PersonajesPixel.tutFeliz, ancho: 24 * u, alto: 22 * u),
            SizedBox(height: 4 * u),
            TextoPixel(mensaje, tipo: TipoTextoPixel.cuerpo, color: ColoresUiPixel.papel, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Un aviso a pantalla completa (el caso no está, no se ha podido cargar), con calma: Tut, el título, el mensaje y
/// lo que se puede hacer.
class EstadoPixel extends StatelessWidget {
  const EstadoPixel({super.key, required this.titulo, required this.mensaje, required this.accion});

  final String titulo;
  final String mensaje;
  final Widget accion;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Espacio.l),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SpritePixel(sprite: PersonajesPixel.tutFeliz, ancho: 24 * u, alto: 22 * u),
              ),
              SizedBox(height: 4 * u),
              Semantics(
                header: true,
                child: TextoPixel(
                  titulo,
                  tipo: TipoTextoPixel.titulo,
                  color: ColoresUiPixel.amarillo,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 2 * u),
              TextoPixel(
                mensaje,
                tipo: TipoTextoPixel.cuerpo,
                color: ColoresUiPixel.papel,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 5 * u),
              accion,
            ],
          ),
        ),
      ),
    );
  }
}

/// La etiqueta «Tu turno» de las decisiones: un talón amarillo con la flecha del cursor.
class RotuloTurnoPixel extends StatelessWidget {
  const RotuloTurnoPixel({super.key});

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: CajaPixel(
        estilo: const EstiloCajaPixel(
          relleno: ColoresUiPixel.amarillo,
          luz: ColoresUiPixel.amarilloLuz,
          sombraInterior: ColoresUiPixel.ocre,
          esquina: 1,
        ),
        interior: const EdgeInsets.fromLTRB(3, 1, 4, 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconoPixel(GlifoPixel.flecha, color: ColoresUiPixel.noche),
            SizedBox(width: 2 * u),
            TextoPixel(tuDecides, tipo: TipoTextoPixel.etiqueta, color: ColoresUiPixel.noche),
          ],
        ),
      ),
    );
  }
}

/// Las palabras del glosario que salen en [texto]: una ficha por cada una, que abre su entrada. [terminos] son los
/// términos que se buscan (con sus variantes, como «coordinadora…»), cada uno con el término del glosario al que lleva.
class TerminosEscena extends StatelessWidget {
  const TerminosEscena({super.key, required this.texto, required this.terminos, required this.onTermino});

  final String texto;
  final Map<String, String> terminos;

  /// Recibe el término del glosario.
  final ValueChanged<String> onTermino;

  /// Las palabras de [terminos] que salen en [texto], tal como salen, cada una con su término del glosario.
  static List<({String palabra, String termino})> encontrar(String texto, Map<String, String> terminos) {
    if (terminos.isEmpty) return const [];
    final vistos = <String>{};
    return [
      for (final trozo in trocearTexto(texto, terminos: terminos.keys.toList()))
        if (trozo.termino case final termino?)
          if (vistos.add(terminos[termino] ?? termino)) (palabra: trozo.texto, termino: terminos[termino] ?? termino),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final encontradas = encontrar(texto, terminos);
    if (encontradas.isEmpty) return const SizedBox.shrink();
    final u = unidadPixel(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: TextoPixel('Palabras del glosario', tipo: TipoTextoPixel.pequeno, color: ColoresUiPixel.cielo),
        ),
        SizedBox(height: 2 * u),
        Wrap(
          spacing: 2 * u,
          runSpacing: 2 * u,
          children: [
            for (final (:palabra, :termino) in encontradas)
              BotonPixel(
                etiqueta: palabra,
                semantica: '¿Qué es «$palabra»? Abre el glosario',
                icono: const IconoPixel(GlifoPixel.pregunta),
                variante: VarianteBotonPixel.secundario,
                onPressed: () => onTermino(termino),
              ),
          ],
        ),
      ],
    );
  }
}
