import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/progreso.dart';
import '../../../core/recursos_ayuda.dart';
import '../../../pixel/juzgado/juzgado.dart' show ModoJuzgado;
import '../../../pixel/motor/motor.dart';
import '../../../pixel/personajes/personajes.dart';
import '../../../pixel/ui/ui.dart';
import '../../../tema.dart';
import '../../../widgets/modulos.dart' show anchoMaximo;
import '../juego_providers.dart';
import '../juzgado_screen.dart' show glifoJuzgado, juzgadoVisibleProvider, rutaJuzgado;
import '../modelos.dart';
import '../motor.dart';
import '../textos.dart';
import 'carta.dart';
import 'escena_juego.dart' show LineaCasoPixel;
import 'piezas_pixel.dart';

/// Id del caso de Sergio: al final, el acceso al juzgado de menores por dentro.
const idCasoSergio = 'caso-acoso-escolar';

/// Id del caso de Sara: al final, los recursos de Ayuda para quitar imágenes de internet y el Canal Joven.
const idCasoSara = 'caso-difusion-imagenes';

/// La ruta del juzgado explorable en modo menores (la audiencia del caso de Sergio).
const rutaJuzgadoMenores = '$rutaJuzgado?modo=menores';

/// El final de un caso, en pixel: «Caso completado», el sello «COMPLETADO» que cae sobre el papel, las cartas de
/// derecho conseguidas y adónde seguir: el siguiente caso (Lucía → Sergio → Sara), lo propio de cada caso (el juzgado
/// de menores al acabar el de Sergio, si se puede abrir; la ayuda para quitar imágenes al acabar el de Sara), Aprende,
/// Pregunta, volver a jugar y la lista de casos.
class FinalCaso extends ConsumerWidget {
  const FinalCaso({
    super.key,
    required this.partida,
    required this.onReiniciar,
    required this.onVerCasos,
    required this.onSiguienteCaso,
  });

  final Partida partida;
  final VoidCallback onReiniciar;
  final VoidCallback onVerCasos;
  final ValueChanged<Caso> onSiguienteCaso;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = unidadPixel(context);
    final caso = partida.caso;
    final progreso = ref.watch(progresoProvider);
    final tenidas = progreso.cartas;
    final casos = ref.watch(casosProvider).value ?? [caso];
    final conseguidas = caso.cartas.where((c) => tenidas.contains(c.id)).length;
    final faltan = caso.cartas.length - conseguidas;
    final siguiente = siguienteCaso(casos, caso.id, terminados: progreso.casosTerminados);
    return ScrollConSombraPixel(
      padding: EdgeInsets.fromLTRB(Espacio.m, 5 * u, Espacio.m, 8 * u),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: anchoMaximo),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: TextoPixel(
                  tituloFinal,
                  tipo: TipoTextoPixel.grande,
                  color: ColoresUiPixel.amarillo,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 5 * u),
              _PapelDelCaso(caso: caso),
              SizedBox(height: 5 * u),
              _CartasConseguidas(conseguidas: conseguidas),
              SizedBox(height: 6 * u),
              if (siguiente != null)
                BotonPixel(
                  etiqueta: botonSiguienteCaso(siguiente.protagonista),
                  iconoFinal: const IconoPixel(GlifoPixel.siguiente),
                  expandido: true,
                  onPressed: () => onSiguienteCaso(siguiente),
                )
              else
                BotonPixel(etiqueta: botonVerCasos, expandido: true, onPressed: onVerCasos),
              // Solo si «El juzgado por dentro» se puede abrir: sus textos aún no están validados y, sin borradores, la
              // pantalla solo diría que está en revisión (un callejón sin salida al final de un caso).
              if (caso.id == idCasoSergio && ref.watch(juzgadoVisibleProvider(ModoJuzgado.menores))) ...[
                SizedBox(height: 4 * u),
                _Acceso(
                  glifo: glifoJuzgado,
                  titulo: accesoJuzgadoMenores,
                  texto: accesoJuzgadoMenoresTexto,
                  onPressed: () => context.push(rutaJuzgadoMenores),
                ),
              ],
              if (caso.id == idCasoSara) ...[SizedBox(height: 6 * u), const _AyudaSara()],
              if (caso.cartas.isNotEmpty) ...[
                SizedBox(height: 7 * u),
                _Titulo(tituloCartasDelCaso),
                SizedBox(height: 3 * u),
                for (final (i, carta) in caso.cartas.indexed) ...[
                  if (i > 0) SizedBox(height: 3 * u),
                  if (tenidas.contains(carta.id))
                    CartaPixelDerecho(
                      carta: carta,
                      indice: indiceEnColeccion(casos, carta.id),
                      onPressed: () =>
                          mostrarCartaPixel(context, carta: carta, indice: indiceEnColeccion(casos, carta.id)),
                    )
                  else
                    CartaPixelDerecho(
                      carta: carta,
                      indice: indiceEnColeccion(casos, carta.id),
                      bloqueada: true,
                      pista: 'Vuelve a jugar para encontrarla.',
                    ),
                ],
                if (faltan > 0) ...[
                  SizedBox(height: 3 * u),
                  TextoPixel(textoCartasQueFaltan(faltan), color: ColoresUiPixel.cielo),
                ],
              ],
              SizedBox(height: 7 * u),
              _Titulo(tituloYAhora),
              SizedBox(height: 3 * u),
              _Acceso(
                glifo: GlifoPixel.bombilla,
                titulo: accesoAprende,
                texto: accesoAprendeTexto,
                onPressed: () => context.push('/aprende'),
              ),
              SizedBox(height: 3 * u),
              _Acceso(
                glifo: GlifoPixel.bocadillo,
                titulo: accesoPregunta,
                texto: accesoPreguntaTexto,
                onPressed: () => context.push('/pregunta'),
              ),
              SizedBox(height: 6 * u),
              BotonPixel(
                etiqueta: botonVolverAJugar,
                variante: VarianteBotonPixel.secundario,
                expandido: true,
                onPressed: onReiniciar,
              ),
              if (siguiente != null) ...[
                SizedBox(height: 3 * u),
                BotonPixel(
                  etiqueta: botonVerCasos,
                  variante: VarianteBotonPixel.secundario,
                  expandido: true,
                  onPressed: onVerCasos,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// El papel del caso con el sello «COMPLETADO» que cae encima y «Has acompañado a Lucía hasta el final…».
class _PapelDelCaso extends StatelessWidget {
  const _PapelDelCaso({required this.caso});

  final Caso caso;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    return CajaPixel(
      estilo: const EstiloCajaPixel(
        relleno: ColoresUiPixel.papel,
        luz: ColoresUiPixel.blanco,
        sombraInterior: ColoresUiPixel.crema,
        esquina: 3,
      ),
      interior: const EdgeInsets.fromLTRB(5, 4, 5, 5),
      child: FondoPixel(
        color: ColoresUiPixel.papel,
        pintar: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LineaCasoPixel(
              protagonista: caso.protagonista,
              edad: caso.edad,
              color: ColoresUiPixel.noche,
              colorSuave: ColoresUiPixel.noche,
            ),
            SizedBox(height: 5 * u),
            // Cae cuando ya ha terminado la transición a bloques del final.
            const Center(child: SelloPixel(retraso: Duration(milliseconds: 700))),
            SizedBox(height: 5 * u),
            TextoPixel(textoFinal(caso.protagonista), tipo: TipoTextoPixel.cuerpo, color: ColoresUiPixel.noche),
          ],
        ),
      ),
    );
  }
}

/// «Cartas de derecho conseguidas: N», con Tut contento al lado. La cifra va en la letra de rótulo.
class _CartasConseguidas extends StatelessWidget {
  const _CartasConseguidas({required this.conseguidas});

  final int conseguidas;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    return Semantics(
      container: true,
      label: textoCartasConseguidas(conseguidas),
      excludeSemantics: true,
      child: Row(
        children: [
          SpritePixel(sprite: PersonajesPixel.tutFeliz, ancho: 16 * u, alto: 15 * u),
          SizedBox(width: 3 * u),
          const IconoPixel(GlifoPixel.carta, color: ColoresUiPixel.amarillo),
          SizedBox(width: 2 * u),
          Flexible(
            child: TextoPixel(
              'Cartas de derecho conseguidas:',
              tipo: TipoTextoPixel.etiqueta,
              color: ColoresUiPixel.papel,
            ),
          ),
          SizedBox(width: 2 * u),
          RotuloPixel('$conseguidas', color: ColoresUiPixel.amarillo, escala: 2),
        ],
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: TextoPixel(texto, tipo: TipoTextoPixel.titulo, color: ColoresUiPixel.amarillo),
    );
  }
}

/// Un acceso a otra parte de la app (Aprende, Pregunta, el juzgado): una tarjeta de papel que se pulsa, con su dibujo,
/// su título y una línea de texto.
class _Acceso extends StatelessWidget {
  const _Acceso({required this.glifo, required this.titulo, required this.texto, required this.onPressed});

  final GlifoPixel glifo;
  final String titulo;
  final String texto;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    return TicketPixel(
      semantica: '$titulo. $texto',
      onPressed: onPressed,
      anchoTalon: 16,
      talon: IconoPixel(glifo, color: ColoresUiPixel.noche),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextoPixel(titulo, tipo: TipoTextoPixel.etiqueta, color: ColoresUiPixel.noche),
          SizedBox(height: u),
          TextoPixel(texto, tipo: TipoTextoPixel.pequeno, color: ColoresUiPixel.grisOscuro),
        ],
      ),
    );
  }
}

/// Al final del caso de Sara: dónde pedir ayuda si te pasa algo parecido, con los recursos de Ayuda que le sirven a
/// ella (lib/core/recursos_ayuda.dart): quitar fotos o vídeos de internet (el Canal prioritario de la AEPD) y el Canal
/// Joven. Sin juego: papel liso, sin puntos ni estrellas.
class _AyudaSara extends StatelessWidget {
  const _AyudaSara();

  static RecursoAyuda? _recurso(bool Function(RecursoAyuda) cual) {
    for (final recurso in recursosAyuda) {
      if (cual(recurso)) return recurso;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final quitar = _recurso((r) => r.web?.contains('canalprioritario') ?? false);
    final canalJoven = _recurso((r) => r.telefono == '900 293 183');
    return CajaPixel(
      estilo: const EstiloCajaPixel(
        relleno: ColoresUiPixel.papel,
        luz: ColoresUiPixel.blanco,
        sombraInterior: ColoresUiPixel.crema,
        esquina: 2,
      ),
      interior: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: FondoPixel(
        color: ColoresUiPixel.papel,
        pintar: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: TextoPixel(tituloSiTePasa, tipo: TipoTextoPixel.titulo, color: ColoresUiPixel.noche),
            ),
            SizedBox(height: 2 * u),
            TextoPixel(textoSiTePasa, tipo: TipoTextoPixel.cuerpo, color: ColoresUiPixel.noche),
            if (quitar != null) ...[SizedBox(height: 4 * u), _RecursoSara(recurso: quitar)],
            if (canalJoven != null) ...[SizedBox(height: 4 * u), _RecursoSara(recurso: canalJoven)],
            SizedBox(height: 4 * u),
            BotonPixel(
              etiqueta: botonVerAyuda,
              variante: VarianteBotonPixel.secundario,
              expandido: true,
              onPressed: () => context.push('/ayuda'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un recurso de Ayuda: su nombre, para qué sirve, sus notas (para qué no sirve, desde qué edad) y el botón que abre la
/// web o el teclado del teléfono con el número (no llama solo: quien juega decide).
class _RecursoSara extends StatelessWidget {
  const _RecursoSara({required this.recurso});

  final RecursoAyuda recurso;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final telefono = recurso.telefono;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextoPixel(recurso.nombre, tipo: TipoTextoPixel.etiqueta, color: ColoresUiPixel.noche),
        SizedBox(height: u),
        TextoPixel(recurso.descripcion, tipo: TipoTextoPixel.pequeno, color: ColoresUiPixel.noche),
        for (final nota in recurso.notas) ...[
          SizedBox(height: u),
          TextoPixel('· ${nota.texto}', tipo: TipoTextoPixel.pequeno, color: ColoresUiPixel.noche),
        ],
        SizedBox(height: 2 * u),
        BotonPixel(
          // El número con espacios duros (no se parte) y sus cifras en la letra que las distingue.
          etiqueta: telefono == null ? 'Abrir su web' : 'Llamar al ${recurso.telefonoVisible}',
          icono: IconoPixel(telefono == null ? GlifoPixel.nube : GlifoPixel.bocadillo),
          semantica: telefono == null
              ? 'Abrir la web de ${recurso.nombre}'
              : 'Llamar al ${recurso.nombre}, $telefono. Se abre el teclado del teléfono',
          variante: VarianteBotonPixel.secundario,
          expandido: true,
          onPressed: () => unawaited(abrirRecurso(recurso)),
        ),
      ],
    );
  }
}
