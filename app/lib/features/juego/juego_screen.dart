import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/progreso.dart';
import '../../pixel/juzgado/juzgado.dart' show DatosJuzgado, ModoJuzgado;
import '../../pixel/motor/motor.dart' show SpritePixel;
import '../../pixel/personajes/personajes.dart';
import '../../pixel/ui/ui.dart';
import '../../widgets/ayuda_button.dart';
import 'juego_providers.dart';
import 'juzgado_screen.dart';
import 'modelos.dart';
import 'textos.dart';
import 'widgets/carta.dart';
import 'widgets/piezas_pixel.dart' show mostrarVentanaPixel;

export 'caso_screen.dart' show CasoScreen;
export 'juzgado_screen.dart' show JuzgadoScreen, rutaHijaJuzgado, rutaJuzgado, rutaRedireccionJuzgado;

// Textos de la lista que no están en textos.dart.
const textoEntradaJuzgado = '¿Quién es quién? Toca a cada persona de la sala y descubre qué hace.';
const ctaEntrarJuzgado = 'Entrar';
const ctaRepasarJuzgado = 'Repasar';
const estadoJuzgadoCompleto = '¡Ya sabes quién es quién!';
const pistaCartaJuzgado = 'Esta carta se consigue conociendo a todas las personas del juzgado.';
const etiquetaBorrador = 'Borrador';
const notaColeccion = 'Cada buena decisión en un caso te da una carta. Toca una para verla en grande.';
const notaColeccionCompleta = '¡Las tienes todas! Ya conoces todos los derechos de estos casos.';
const tituloCartaPorDescubrir = 'Carta por descubrir';
const botonCerrar = 'Cerrar';
const botonEntrarJuzgado = 'Entrar en el juzgado';

/// «1 de 3 casos», «2 de 13 cartas».
String textoDe(int actual, int total, String singular, String plural) =>
    '$actual de $total ${total == 1 ? singular : plural}';

/// «Jugar el caso de Lucía».
String botonJugarCaso(String protagonista) => protagonista.isEmpty ? 'Jugar el caso' : 'Jugar el caso de $protagonista';

/// Una carta de la colección y dónde se gana: en [caso] o, si es null, en «El juzgado por dentro».
typedef CartaDeColeccion = ({Carta carta, Caso? caso});

/// La colección entera: las cartas de los casos, sin repetir, y al final la del juzgado ([conJuzgado]: solo cuando se
/// puede abrir).
List<CartaDeColeccion> coleccionCompleta(List<Caso> casos, {required bool conJuzgado}) => [
  for (final entrada in coleccionDe(casos)) (carta: entrada.carta, caso: entrada.caso),
  if (conJuzgado) (carta: cartaQuienEsQuien, caso: null),
];

/// El ancho máximo de la lista en pantallas grandes.
const _anchoMaximo = 720.0;

/// «Vive el caso» (sección 4.2), dentro del mundo pixel del juego: un ticket de turno por caso con el retrato de su
/// protagonista, la entrada a «El juzgado por dentro» y la colección de cartas de derechos. Arriba, la barra del juego
/// con los casos terminados («1 de 3 casos»), las cartas, Glosario y Ayuda.
class JuegoScreen extends ConsumerWidget {
  const JuegoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casos = ref.watch(casosProvider);
    final lista = casos.value;
    final progreso = ref.watch(progresoProvider);
    final conJuzgado = ref.watch(juzgadoVisibleProvider(ModoJuzgado.salaVistas));
    final coleccion = lista == null ? const <CartaDeColeccion>[] : coleccionCompleta(lista, conJuzgado: conJuzgado);
    final total = lista?.length ?? 0;
    final terminados = lista?.where((caso) => progreso.casosTerminados.contains(caso.id)).length ?? 0;
    final conseguidas = coleccion.where((entrada) => progreso.cartas.contains(entrada.carta.id)).length;
    return Scaffold(
      backgroundColor: ColoresUiPixel.noche,
      body: FondoPixel(
        color: ColoresUiPixel.noche,
        // El scroll del juego: sin el estirado de Android, que reescalaría (y emborronaría) el pixel art de los tickets.
        child: ScrollPixel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HudPixel(
                titulo: tituloJuego,
                progreso: total == 0 ? 0 : terminados / total,
                segmentos: total == 0 ? 1 : total,
                etiquetaProgreso: 'Casos terminados',
                textoProgreso: textoDe(terminados, total, 'caso', 'casos'),
                cartas: coleccion.isEmpty ? null : conseguidas,
                totalCartas: coleccion.isEmpty ? null : coleccion.length,
                onVolver: () => context.canPop() ? context.pop() : context.go('/'),
                acciones: const [GlosarioButton(), AyudaButton()],
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: casos.when(
                    skipLoadingOnReload: true,
                    data: (casos) => casos.isEmpty
                        ? _Aviso(
                            titulo: sinCasosTitulo,
                            texto: sinCasosMensaje,
                            boton: BotonPixel(etiqueta: 'Ir a Pregunta', onPressed: () => context.push('/pregunta')),
                          )
                        : _Portada(casos: casos, coleccion: coleccion, conJuzgado: conJuzgado),
                    error: (_, _) => _Aviso(
                      texto: errorCasos,
                      boton: BotonPixel(etiqueta: 'Probar otra vez', onPressed: () => ref.invalidate(casosProvider)),
                    ),
                    loading: () => const _Aviso(texto: cargandoCasos),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un aviso a pantalla completa sobre el fondo del juego: sin casos, error o cargando.
class _Aviso extends StatelessWidget {
  const _Aviso({this.titulo, required this.texto, this.boton});

  final String? titulo;
  final String texto;
  final Widget? boton;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final titulo = this.titulo;
    final boton = this.boton;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(6 * u),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (titulo != null) ...[
                Semantics(
                  header: true,
                  child: Text(
                    titulo,
                    textAlign: TextAlign.center,
                    style: estiloTextoPixel(context, TipoTextoPixel.titulo, color: ColoresUiPixel.amarillo),
                  ),
                ),
                SizedBox(height: 3 * u),
              ],
              Text(
                texto,
                textAlign: TextAlign.center,
                style: estiloTextoPixel(context, TipoTextoPixel.cuerpo, color: ColoresUiPixel.papel),
              ),
              if (boton != null) ...[SizedBox(height: 6 * u), boton],
            ],
          ),
        ),
      ),
    );
  }
}

class _Portada extends ConsumerWidget {
  const _Portada({required this.casos, required this.coleccion, required this.conJuzgado});

  final List<Caso> casos;
  final List<CartaDeColeccion> coleccion;
  final bool conJuzgado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = unidadPixel(context);
    final progreso = ref.watch(progresoProvider);
    final terminados = casos.where((caso) => progreso.casosTerminados.contains(caso.id)).length;
    final conseguidas = coleccion.where((entrada) => progreso.cartas.contains(entrada.carta.id)).length;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _anchoMaximo),
        child: ListView(
          // Nitidez del pixel art (lib/pixel/ui/LEEME.md): sin capas propias para cada pieza de la lista.
          addRepaintBoundaries: false,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              textoCabeceraJuego,
              style: estiloTextoPixel(context, TipoTextoPixel.cuerpo, color: ColoresUiPixel.papel),
            ),
            SizedBox(height: 6 * u),
            _Encabezado(
              titulo: tituloElegirCaso,
              contador: _Contador(
                glifo: GlifoPixel.check,
                actual: terminados,
                total: casos.length,
                cosa: ('caso', 'casos'),
              ),
            ),
            SizedBox(height: 4 * u),
            for (final (i, caso) in casos.indexed) ...[_TicketCaso(caso: caso, numero: i + 1), SizedBox(height: 4 * u)],
            if (conJuzgado) ...[const _TicketJuzgado(), SizedBox(height: 4 * u)],
            if (coleccion.isNotEmpty) ...[
              SizedBox(height: 4 * u),
              _Encabezado(
                titulo: tituloColeccion,
                contador: _Contador(
                  glifo: GlifoPixel.carta,
                  actual: conseguidas,
                  total: coleccion.length,
                  cosa: ('carta', 'cartas'),
                ),
              ),
              SizedBox(height: 2 * u),
              Text(
                conseguidas == coleccion.length ? notaColeccionCompleta : notaColeccion,
                style: estiloTextoPixel(context, TipoTextoPixel.pequeno, color: ColoresUiPixel.papel),
              ),
              SizedBox(height: 4 * u),
              _Coleccion(coleccion: coleccion, conseguidas: progreso.cartas),
            ],
            SizedBox(height: 6 * u),
            Text(
              notaCasosInventados,
              style: estiloTextoPixel(context, TipoTextoPixel.pequeno, color: ColoresUiPixel.cielo),
            ),
          ],
        ),
      ),
    );
  }
}

/// El título de un apartado, en amarillo, y a su lado (o debajo, si no cabe) cuántos llevas.
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.titulo, required this.contador});

  final String titulo;
  final Widget contador;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 3 * u,
      runSpacing: 2 * u,
      children: [
        Semantics(
          header: true,
          child: Text(titulo, style: estiloTextoPixel(context, TipoTextoPixel.titulo, color: ColoresUiPixel.amarillo)),
        ),
        contador,
      ],
    );
  }
}

/// «1 de 3 casos», con las cifras en la letra que las distingue ([TextoPixel]: en Pixelify, el 0, el 5 y el 8 se
/// confunden con letras), del mismo tamaño que el resto. Con letra muy grande, baja de línea en vez de salirse.
class _Contador extends StatelessWidget {
  const _Contador({required this.glifo, required this.actual, required this.total, required this.cosa});

  final GlifoPixel glifo;
  final int actual;
  final int total;

  /// El nombre de lo que se cuenta, en singular y en plural.
  final (String, String) cosa;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final texto = textoDe(actual, total, cosa.$1, cosa.$2);
    return Semantics(
      container: true,
      label: texto,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconoPixel(glifo, color: ColoresUiPixel.amarillo),
          SizedBox(width: 2 * u),
          Flexible(
            child: TextoPixel(texto, tipo: TipoTextoPixel.etiqueta, color: ColoresUiPixel.papel),
          ),
        ],
      ),
    );
  }
}

/// El ticket de un caso: en el talón, el retrato pixel de quien lo protagoniza y su número; en el cuerpo, quién es,
/// el título, de qué va, cómo vas y qué hacer. Es un solo botón para el lector de pantalla.
class _TicketCaso extends ConsumerWidget {
  const _TicketCaso({required this.caso, required this.numero});

  final Caso caso;
  final int numero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = unidadPixel(context);
    final progreso = ref.watch(progresoProvider);
    final partida = ref.watch(partidaProvider(caso.id)).value;
    final terminado = progreso.casosTerminados.contains(caso.id);
    final enCurso = partida != null && partida.empezada && !partida.terminada;
    final ganadas = caso.cartas.where((carta) => progreso.cartas.contains(carta.id)).length;
    final (estado, glifoEstado) = enCurso
        ? ('Escena ${partida.numeroEscena} de ${partida.totalEscenas}', GlifoPixel.flecha)
        : terminado
        ? (estadoTerminado, GlifoPixel.check)
        : (estadoNuevo, GlifoPixel.estrella);
    final cta = enCurso ? ctaSeguirCaso : (terminado || (partida?.terminada ?? false) ? ctaOtraVez : ctaEmpezar);
    final rol = _nombreRol(caso.rol);
    final quien = presentacion(caso.protagonista, caso.edad);
    final cartas = textoDe(ganadas, caso.cartas.length, 'carta', 'cartas');

    void abrir() {
      // Un caso ya terminado se vuelve a jugar desde el principio; uno a medias sigue donde se dejó.
      if (!enCurso && (partida?.terminada ?? false)) ref.read(partidaProvider(caso.id).notifier).reiniciar();
      context.push('/juego/${caso.id}');
    }

    return TicketPixel(
      onPressed: abrir,
      semantica: [
        caso.titulo,
        quien.isEmpty ? 'Caso $numero' : 'Caso $numero: $quien',
        if (rol.isNotEmpty) rol,
        estado,
        if (caso.cartas.isNotEmpty) cartas,
        if (!caso.validado) etiquetaBorrador,
        cta,
      ].join('. '),
      talon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Retrato(protagonista: caso.protagonista),
          SizedBox(height: 2 * u),
          RotuloPixel('N.º $numero'),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextoPixel(
            quien.isEmpty ? 'Caso $numero' : 'Caso $numero · $quien',
            tipo: TipoTextoPixel.etiqueta,
            color: ColoresUiPixel.noche,
          ),
          SizedBox(height: u),
          Text(caso.titulo, style: estiloTextoPixel(context, TipoTextoPixel.titulo, color: ColoresUiPixel.noche)),
          SizedBox(height: u),
          Text(
            caso.resumen,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: estiloTextoPixel(context, TipoTextoPixel.pequeno, color: ColoresUiPixel.noche),
          ),
          SizedBox(height: 2 * u),
          Wrap(
            spacing: 2 * u,
            runSpacing: u,
            children: [
              _Etiqueta(glifo: glifoEstado, texto: estado),
              if (caso.cartas.isNotEmpty)
                _Etiqueta(glifo: GlifoPixel.carta, rotulo: '$ganadas/${caso.cartas.length}', semantica: cartas),
              if (rol.isNotEmpty) _Etiqueta(texto: rol),
              if (!caso.validado) const _Etiqueta(texto: etiquetaBorrador, borrador: true),
            ],
          ),
          SizedBox(height: 3 * u),
          _Llamada(texto: cta),
        ],
      ),
    );
  }
}

/// La entrada a «El juzgado por dentro», con el talón azul cielo: el edificio y a cuántas personas conoces ya.
class _TicketJuzgado extends ConsumerWidget {
  const _TicketJuzgado();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = unidadPixel(context);
    final ids = idsDelJuzgado(ModoJuzgado.salaVistas);
    final conocidos = ref.watch(progresoProvider.select((p) => p.personasConocidas.where(ids.contains).length));
    final total = ids.length;
    final completo = conocidos >= total;
    final validado = DatosJuzgado.de(ModoJuzgado.salaVistas).validado;
    final estado = conocidos == 0
        ? estadoNuevo
        : (completo ? estadoJuzgadoCompleto : 'Has conocido a $conocidos de $total');
    final cta = conocidos == 0 ? ctaEntrarJuzgado : (completo ? ctaRepasarJuzgado : ctaSeguirCaso);
    return TicketPixel(
      colorTalon: ColoresUiPixel.cielo,
      onPressed: () => context.push(rutaJuzgado),
      semantica: [
        tituloJuzgado,
        textoEntradaJuzgado,
        'Has conocido a $conocidos de $total personas',
        if (!validado) etiquetaBorrador,
        cta,
      ].join('. '),
      talon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const IconoPixel(glifoJuzgado, escala: 2, color: ColoresUiPixel.noche),
          SizedBox(height: 2 * u),
          RotuloPixel('$conocidos/$total'),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tituloJuzgado, style: estiloTextoPixel(context, TipoTextoPixel.titulo, color: ColoresUiPixel.noche)),
          SizedBox(height: u),
          Text(
            textoEntradaJuzgado,
            style: estiloTextoPixel(context, TipoTextoPixel.pequeno, color: ColoresUiPixel.noche),
          ),
          SizedBox(height: 2 * u),
          Wrap(
            spacing: 2 * u,
            runSpacing: u,
            children: [
              _Etiqueta(glifo: completo ? GlifoPixel.check : GlifoPixel.estrella, texto: estado),
              if (!validado) const _Etiqueta(texto: etiquetaBorrador, borrador: true),
            ],
          ),
          SizedBox(height: 3 * u),
          _Llamada(texto: cta),
        ],
      ),
    );
  }
}

/// La cabeza y los hombros de [protagonista] en una ventanita azul cielo, como la foto de un carné. Si no hay
/// retrato para ese nombre, su inicial.
class _Retrato extends StatelessWidget {
  const _Retrato({required this.protagonista});

  final String protagonista;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final id = PersonajesPixel.buscar(protagonista);
    final retrato = id == null ? null : PersonajesPixel.retrato(id);
    final inicial = protagonista.trim().isEmpty ? '?' : protagonista.trim().characters.first.toUpperCase();
    return CajaPixel(
      estilo: const EstiloCajaPixel(
        relleno: ColoresUiPixel.cielo,
        luz: ColoresUiPixel.hielo,
        sombra: null,
        esquina: 1,
        profundidad: 0,
      ),
      conFilo: false,
      interior: const EdgeInsets.all(1),
      child: SizedBox(
        width: PersonajesPixel.anchoRetrato * u,
        height: PersonajesPixel.altoRetrato * u,
        child: retrato == null
            ? Center(child: RotuloPixel(inicial, escala: 2, color: ColoresUiPixel.noche))
            : SpritePixel(sprite: retrato, alineacion: Alignment.bottomCenter),
      ),
    );
  }
}

/// Una etiqueta pequeña de papel crema con borde azul noche: un glifo y un texto (o unas cifras de rótulo).
class _Etiqueta extends StatelessWidget {
  const _Etiqueta({this.glifo, this.texto, this.rotulo, this.semantica, this.borrador = false});

  final GlifoPixel? glifo;
  final String? texto;
  final String? rotulo;
  final String? semantica;

  /// La de «Borrador»: en gris, para que no parezca un logro.
  final bool borrador;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final glifo = this.glifo;
    final texto = this.texto;
    final rotulo = this.rotulo;
    Widget etiqueta = CajaPixel(
      estilo: EstiloCajaPixel(
        relleno: borrador ? ColoresUiPixel.grisClaro : ColoresUiPixel.crema,
        sombra: null,
        esquina: 1,
        profundidad: 0,
      ),
      conFilo: false,
      interior: const EdgeInsets.fromLTRB(2, 1, 2, 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glifo != null) ...[IconoPixel(glifo, color: ColoresUiPixel.noche), SizedBox(width: u)],
          if (rotulo != null) RotuloPixel(rotulo, color: ColoresUiPixel.noche),
          if (texto != null)
            Flexible(
              child: TextoPixel(texto, tipo: TipoTextoPixel.etiqueta, color: ColoresUiPixel.noche),
            ),
        ],
      ),
    );
    final semantica = this.semantica;
    if (semantica != null) {
      etiqueta = Semantics(container: true, label: semantica, excludeSemantics: true, child: etiqueta);
    }
    return etiqueta;
  }
}

/// Lo que se hace al tocar el ticket («Empezar ►»), con aspecto de acción pero sin ser otro botón: el ticket entero
/// es el botón.
class _Llamada extends StatelessWidget {
  const _Llamada({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(texto, style: estiloTextoPixel(context, TipoTextoPixel.boton, color: ColoresUiPixel.azul)),
        ),
        SizedBox(width: 2 * u),
        const IconoPixel(GlifoPixel.flecha, color: ColoresUiPixel.azul),
      ],
    );
  }
}

/// Las cartas de la colección: en un móvil, una columna de cartas tumbadas; en pantallas anchas, una rejilla de cartas
/// de pie (lib/pixel/ui/LEEME.md, «Mis cartas»).
class _Coleccion extends StatelessWidget {
  const _Coleccion({required this.coleccion, required this.conseguidas});

  final List<CartaDeColeccion> coleccion;
  final Set<String> conseguidas;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final hueco = 4 * u;
    return LayoutBuilder(
      builder: (context, limites) {
        final columnas = limites.maxWidth >= 560 ? 2 : 1;
        if (columnas == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, entrada) in coleccion.indexed) ...[
                if (i > 0) SizedBox(height: hueco),
                _CartaColeccion(
                  entrada: entrada,
                  numero: i + 1,
                  conseguida: conseguidas.contains(entrada.carta.id),
                  formato: FormatoCartaPixel.horizontal,
                ),
              ],
            ],
          );
        }
        final ancho = ((limites.maxWidth - hueco * (columnas - 1)) / columnas).floorToDouble();
        return Wrap(
          spacing: hueco,
          runSpacing: hueco,
          children: [
            for (final (i, entrada) in coleccion.indexed)
              SizedBox(
                width: ancho,
                child: _CartaColeccion(
                  entrada: entrada,
                  numero: i + 1,
                  conseguida: conseguidas.contains(entrada.carta.id),
                  formato: FormatoCartaPixel.vertical,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Una carta de la colección, la misma que en los casos ([CartaPixelDerecho]: el dibujo de su derecho y los colores de
/// su sitio). El lector de pantalla dice «Carta: {título}» o «Carta por descubrir» (auditoría, P2-3). Al tocarla, la
/// conseguida se ve en grande con su fuente; la bloqueada dice dónde se consigue y deja ir allí.
class _CartaColeccion extends StatelessWidget {
  const _CartaColeccion({required this.entrada, required this.numero, required this.conseguida, required this.formato});

  final CartaDeColeccion entrada;
  final int numero;
  final bool conseguida;
  final FormatoCartaPixel formato;

  @override
  Widget build(BuildContext context) {
    final carta = entrada.carta;
    final caso = entrada.caso;
    final pista = caso == null ? pistaCartaJuzgado : textoCartaBloqueada(caso.protagonista);
    // La del juzgado lleva el edificio; las de los casos, el dibujo de su derecho.
    final icono = caso == null ? glifoJuzgado : null;
    void abrir() => conseguida
        ? mostrarCartaPixel(context, carta: carta, indice: numero - 1, icono: icono)
        : _mostrarPista(context, entrada: entrada, numero: numero, pista: pista, icono: icono);
    return CartaPixelDerecho(
      carta: carta,
      indice: numero - 1,
      bloqueada: !conseguida,
      pista: pista,
      formato: formato,
      icono: icono,
      indicacion: conseguida ? null : 'Toca para ver dónde se consigue',
      onPressed: abrir,
    );
  }
}

/// Una carta por descubrir: dónde se consigue y un botón para ir allí.
Future<void> _mostrarPista(
  BuildContext context, {
  required CartaDeColeccion entrada,
  required int numero,
  required String pista,
  GlifoPixel? icono,
}) {
  final router = GoRouter.of(context);
  final caso = entrada.caso;
  return mostrarVentanaPixel<void>(
    context,
    (ventana) => VentanaCartaPixel(
      titulo: tituloCartaPorDescubrir,
      carta: CartaPixelDerecho(
        carta: entrada.carta,
        indice: numero - 1,
        bloqueada: true,
        pista: pista,
        formato: FormatoCartaPixel.vertical,
        icono: icono,
      ),
      botones: [
        BotonPixel(
          etiqueta: caso == null ? botonEntrarJuzgado : botonJugarCaso(caso.protagonista),
          expandido: true,
          autofocus: true,
          icono: const IconoPixel(GlifoPixel.flecha),
          onPressed: () {
            Navigator.of(ventana).pop();
            router.push(caso == null ? rutaJuzgado : '/juego/${caso.id}');
          },
        ),
        BotonPixel(
          etiqueta: botonCerrar,
          variante: VarianteBotonPixel.secundario,
          expandido: true,
          onPressed: () => Navigator.of(ventana).pop(),
        ),
      ],
    ),
  );
}

/// El papel de quien protagoniza el caso, para la etiqueta del ticket.
String _nombreRol(String rol) => switch (rol.trim().toLowerCase()) {
  'victima' || 'víctima' => 'Víctima',
  'testigo' => 'Testigo',
  'investigado' || 'investigada' => 'Investigado o investigada',
  final otro when otro.isNotEmpty => otro[0].toUpperCase() + otro.substring(1),
  _ => '',
};
