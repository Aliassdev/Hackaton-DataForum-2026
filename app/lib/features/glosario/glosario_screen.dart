import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/content_models.dart';
import '../../core/providers.dart';
import '../../core/texto.dart';
import '../../tema.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/estados.dart';
import '../../widgets/iconos/iconos.dart';
import '../../widgets/modulos.dart';
import '../../widgets/movimiento/contador_flip.dart';
import '../../widgets/movimiento/hapticos.dart';
import '../../widgets/movimiento/ticket.dart';
import '../../widgets/tuturno_scaffold.dart';
import 'detalle_termino.dart';
import 'favoritos.dart';
import 'terminos_por_caso.dart';

/// Glosario (sección 4.5): buscador sin tildes y una colección de cartas, una por palabra, numeradas como cartas
/// coleccionables y agrupadas por letras. Al tocar una carta se abre su detalle.
/// Con [busquedaInicial] (p. ej. /glosario?q=citación), si coincide con un término, se abre su detalle.
///
/// Debajo del buscador, los filtros (plan v2, producto §5.7): «Todas», «Mis palabras (n)» y un chip por cada caso de
/// Vive el caso con protagonista («Lucía», «Sergio», «Sara»). El filtro se combina con la búsqueda, y el recuento
/// cuenta lo que se ve.
class GlosarioScreen extends ConsumerStatefulWidget {
  const GlosarioScreen({super.key, this.busquedaInicial, this.vieneDePregunta = false});

  final String? busquedaInicial;

  /// Se ha abierto desde una respuesta de Pregunta (`/glosario?q=…&desde=pregunta`): «Pregúntalo» vuelve atrás.
  final bool vieneDePregunta;

  @override
  ConsumerState<GlosarioScreen> createState() => _GlosarioScreenState();
}

class _GlosarioScreenState extends ConsumerState<GlosarioScreen> {
  late final TextEditingController _busqueda = TextEditingController(text: widget.busquedaInicial?.trim() ?? '');
  bool _detalleInicialResuelto = false;
  FiltroGlosario _filtro = FiltroGlosario.todas;

  /// La lista vuelve arriba al cambiar de filtro o de búsqueda: lo primero que se ve es lo que se acaba de pedir.
  final _desplazamiento = ScrollController();
  late String _ultimaBusqueda = _busqueda.text;

  void _filtrar(FiltroGlosario filtro) {
    if (filtro == _filtro) return;
    _arriba();
    setState(() => _filtro = filtro);
  }

  void _alBuscar() {
    if (_busqueda.text == _ultimaBusqueda) return;
    _ultimaBusqueda = _busqueda.text;
    _arriba();
  }

  void _arriba() {
    if (_desplazamiento.hasClients) _desplazamiento.jumpTo(0);
  }

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(_alBuscar);
    final inicial = normalizar(widget.busquedaInicial?.trim() ?? '');
    if (inicial.isEmpty) return;
    ref.listenManual<AsyncValue<List<EntradaGlosario>>>(glosarioProvider, (_, estado) {
      final entradas = estado.value;
      if (_detalleInicialResuelto || entradas == null) return;
      _detalleInicialResuelto = true;
      final indice = entradas.indexWhere((e) => normalizar(e.termino) == inicial);
      if (indice < 0) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        mostrarDetalleTermino(
          context,
          entradas[indice],
          vieneDePregunta: widget.vieneDePregunta,
          numero: indice + 1,
          total: entradas.length,
        );
      });
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _busqueda.dispose();
    _desplazamiento.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(glosarioProvider);
    return TuTurnoScaffold(
      titulo: 'Glosario',
      mostrarGlosario: false,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: anchoMaximo),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.m, Espacio.s),
                child: _Buscador(controlador: _busqueda),
              ),
              Expanded(
                child: estado.when(
                  skipLoadingOnRefresh: false,
                  loading: () => const Cargando(mensaje: 'Cargando el glosario…'),
                  error: (_, _) => EstadoError(
                    mensaje: 'No he podido abrir el glosario. Prueba otra vez.',
                    onReintentar: () => ref.invalidate(glosarioProvider),
                  ),
                  data: (entradas) {
                    final lista = ValueListenableBuilder(
                      valueListenable: _busqueda,
                      builder: (context, valor, _) => _Resultados(
                        entradas: entradas,
                        consulta: valor.text,
                        filtro: _filtro,
                        onFiltrar: _filtrar,
                        desplazamiento: _desplazamiento,
                        vieneDePregunta: widget.vieneDePregunta,
                      ),
                    );
                    if (entradas.isEmpty) return lista;
                    return Column(
                      children: [
                        _Filtros(entradas: entradas, filtro: _filtro, onFiltrar: _filtrar),
                        Expanded(child: lista),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Buscador extends StatelessWidget {
  const _Buscador({required this.controlador});

  final TextEditingController controlador;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controlador,
      builder: (context, valor, _) => TextField(
        controller: controlador,
        textInputAction: TextInputAction.search,
        autocorrect: false,
        enableIMEPersonalizedLearning: false,
        decoration: InputDecoration(
          hintText: 'Busca una palabra',
          prefixIcon: const Padding(
            padding: EdgeInsetsDirectional.only(start: Espacio.m, end: Espacio.s),
            child: IconoTuTurno(TuIcono.buscar, estilo: EstiloIcono.mono, decorativo: true),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: Espacio.xxl, minHeight: Espacio.xxl),
          suffixIcon: valor.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Borrar la búsqueda',
                  icon: const IconoTuTurno(TuIcono.cerrar, estilo: EstiloIcono.mono, decorativo: true),
                  onPressed: controlador.clear,
                ),
        ),
      ),
    );
  }
}

/// Qué palabras enseña la lista: todas, las de «Mis palabras» o las de un caso de Vive el caso.
enum TipoFiltro { todas, misPalabras, caso }

@immutable
class FiltroGlosario {
  const FiltroGlosario._(this.tipo, [this.casoId]);

  /// Las palabras que salen en el caso [casoId].
  const FiltroGlosario.caso(String casoId) : this._(TipoFiltro.caso, casoId);

  static const todas = FiltroGlosario._(TipoFiltro.todas);
  static const misPalabras = FiltroGlosario._(TipoFiltro.misPalabras);

  final TipoFiltro tipo;
  final String? casoId;

  @override
  bool operator ==(Object other) => other is FiltroGlosario && other.tipo == tipo && other.casoId == casoId;

  @override
  int get hashCode => Object.hash(tipo, casoId);
}

/// El chip de caso de [filtro], o null si no es de caso o si ese caso ya no tiene chip.
FiltroCaso? casoDelFiltro(FiltroGlosario filtro, List<FiltroCaso> casos) =>
    filtro.tipo == TipoFiltro.caso ? casos.where((c) => c.casoId == filtro.casoId).firstOrNull : null;

/// Las palabras de [entradas] que deja ver [filtro]: todas, las guardadas en [favoritos] o las del caso, según
/// [casos]. Un caso que ya no tiene chip (p. ej., si los casos no han cargado) enseña todas.
List<EntradaGlosario> aplicarFiltro(
  List<EntradaGlosario> entradas,
  FiltroGlosario filtro, {
  Set<String> favoritos = const {},
  List<FiltroCaso> casos = const [],
}) {
  switch (filtro.tipo) {
    case TipoFiltro.todas:
      return entradas;
    case TipoFiltro.misPalabras:
      return [
        for (final e in entradas)
          if (favoritos.contains(e.id)) e,
      ];
    case TipoFiltro.caso:
      final caso = casoDelFiltro(filtro, casos);
      if (caso == null) return entradas;
      return [
        for (final e in entradas)
          if (caso.terminos.contains(e.id)) e,
      ];
  }
}

/// «Mis palabras» sin ninguna palabra guardada.
const tituloMisPalabrasVacia = 'Aún no has guardado ninguna palabra';
const pistaMisPalabrasVacia = 'Abre una carta y toca «Guardar en mis palabras».';

/// Una búsqueda que no encuentra nada en todo el glosario.
String tituloSinResultados(String palabra) => 'Aún no tengo «$palabra» en el glosario';

/// Lo que coincide con [consulta] en el término o en la definición, sin que importen tildes ni mayúsculas.
List<EntradaGlosario> filtrarGlosario(List<EntradaGlosario> entradas, String consulta) {
  final q = normalizar(consulta.trim());
  if (q.isEmpty) return entradas;
  return [
    for (final e in entradas)
      if (normalizar(e.termino).contains(q) || normalizar(e.definicion).contains(q)) e,
  ];
}

String _letraDe(EntradaGlosario entrada) {
  final termino = normalizar(entrada.termino.trim());
  return termino.isEmpty ? '#' : termino[0].toUpperCase();
}

/// El número de carta de cada palabra: su puesto en el glosario completo (en orden alfabético), que no cambia al
/// buscar.
Map<String, int> numerosDeCarta(List<EntradaGlosario> entradas) => {for (final (i, e) in entradas.indexed) e.id: i + 1};

/// Cifras con las que se escriben los números de carta («07» si hay menos de 100).
int cifrasDeCarta(int total) => math.max(2, '$total'.length);

/// Los chips de filtro: «Todas», «Mis palabras (n)» y uno por caso con protagonista. Se ven todos a la vez (si no
/// caben en una línea, pasan a la siguiente): así «Sara» no queda escondida por la derecha. Si los casos no cargan,
/// solo los dos primeros.
class _Filtros extends ConsumerWidget {
  const _Filtros({required this.entradas, required this.filtro, required this.onFiltrar});

  final List<EntradaGlosario> entradas;
  final FiltroGlosario filtro;
  final ValueChanged<FiltroGlosario> onFiltrar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritos = ref.watch(favoritosProvider);
    // Solo cuentan las guardadas que siguen en el glosario.
    final guardadas = entradas.where((e) => favoritos.contains(e.id)).length;
    final casos = ref.watch(filtrosCasoProvider).value ?? const <FiltroCaso>[];
    // Un caso que ya no tiene chip cuenta como «Todas».
    final actual = filtro.tipo == TipoFiltro.caso && casoDelFiltro(filtro, casos) == null
        ? FiltroGlosario.todas
        : filtro;

    Widget chip(FiltroGlosario valor, String texto, {String? semantica}) => ChoiceChip(
      label: Text(texto, semanticsLabel: semantica),
      selected: actual == valor,
      onSelected: (_) {
        Hapticos.seleccion();
        onFiltrar(valor);
      },
    );

    return Padding(
      key: const Key('glosario-filtros'),
      padding: const EdgeInsets.fromLTRB(Espacio.m, 0, Espacio.m, Espacio.xs),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Wrap(
          spacing: Espacio.s,
          children: [
            chip(FiltroGlosario.todas, 'Todas'),
            chip(FiltroGlosario.misPalabras, 'Mis palabras ($guardadas)'),
            for (final caso in casos)
              chip(
                FiltroGlosario.caso(caso.casoId),
                caso.protagonista,
                semantica: 'Palabras del caso de ${caso.protagonista}',
              ),
          ],
        ),
      ),
    );
  }
}

class _Resultados extends ConsumerWidget {
  const _Resultados({
    required this.entradas,
    required this.consulta,
    required this.filtro,
    required this.onFiltrar,
    this.desplazamiento,
    this.vieneDePregunta = false,
  });

  final List<EntradaGlosario> entradas;
  final String consulta;
  final FiltroGlosario filtro;
  final ValueChanged<FiltroGlosario> onFiltrar;
  final ScrollController? desplazamiento;
  final bool vieneDePregunta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entradas.isEmpty) {
      return const _AvisoTut(
        expresion: ExpresionTut.neutral,
        titulo: 'El glosario se está preparando',
        mensaje: 'Muy pronto tendrás aquí las palabras difíciles, explicadas fácil.',
      );
    }
    final favoritos = ref.watch(favoritosProvider);
    final casos = ref.watch(filtrosCasoProvider).value ?? const <FiltroCaso>[];
    final caso = casoDelFiltro(filtro, casos);
    final visibles = aplicarFiltro(entradas, filtro, favoritos: favoritos, casos: casos);
    final encontradas = filtrarGlosario(visibles, consulta);
    if (encontradas.isEmpty) {
      final palabra = consulta.trim();
      // «Mis palabras» vacía: cómo se guarda una.
      if (filtro.tipo == TipoFiltro.misPalabras && visibles.isEmpty) {
        return _AvisoTut(
          expresion: ExpresionTut.neutral,
          titulo: tituloMisPalabrasVacia,
          mensaje: pistaMisPalabrasVacia,
          accion: OutlinedButton(
            onPressed: () => onFiltrar(FiltroGlosario.todas),
            child: const Text('Ver todas las palabras'),
          ),
        );
      }
      // No está en esta lista, pero sí en el glosario: se busca en todas.
      if (visibles.length < entradas.length && filtrarGlosario(entradas, consulta).isNotEmpty) {
        return _AvisoTut(
          expresion: ExpresionTut.pensando,
          titulo: caso != null ? 'No sale en el caso de ${caso.protagonista}' : 'No está en Mis palabras',
          mensaje: 'Pero en el glosario sí hay palabras con «$palabra».',
          accion: FilledButton.icon(
            onPressed: () => onFiltrar(FiltroGlosario.todas),
            icon: const IconoTuTurno(TuIcono.buscar, estilo: EstiloIcono.mono, decorativo: true),
            label: const Text('Buscar en todas'),
          ),
        );
      }
      return _AvisoTut(
        expresion: ExpresionTut.pensando,
        titulo: tituloSinResultados(palabra),
        mensaje: 'Pregúntalo y te lo explico con palabras sencillas.',
        accion: FilledButton.icon(
          onPressed: () => irAPregunta(
            GoRouter.of(context),
            vieneDePregunta: vieneDePregunta,
            pregunta: '¿Qué significa «$palabra»?',
          ),
          icon: const IconoTuTurno(TuIcono.pregunta, estilo: EstiloIcono.mono, decorativo: true),
          label: const Text('Pregúntalo'),
        ),
      );
    }

    final numeros = numerosDeCarta(entradas);
    final cifras = cifrasDeCarta(entradas.length);
    // Lista plana con una cabecera por letra.
    final filas = <Object>[];
    String? letraActual;
    for (final e in encontradas) {
      final letra = _letraDe(e);
      if (letra != letraActual) {
        filas.add(letra);
        letraActual = letra;
      }
      filas.add(e);
    }
    // La lista entra una sola vez; al escribir en el buscador no vuelve a animarse (solo gira el contador).
    return Entrada(
      child: ListView.builder(
        controller: desplazamiento,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(Espacio.m, 0, Espacio.m, Espacio.xl),
        itemCount: filas.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) return _Recuento(total: encontradas.length, cifras: cifras);
          final fila = filas[i - 1];
          return switch (fila) {
            final String letra => _CabeceraLetra(letra: letra),
            final EntradaGlosario entrada => Padding(
              padding: const EdgeInsets.only(bottom: Espacio.s + Espacio.xs),
              child: _CartaTermino(
                entrada: entrada,
                numero: numeros[entrada.id] ?? 0,
                cifras: cifras,
                guardada: favoritos.contains(entrada.id),
                onTap: () => mostrarDetalleTermino(
                  context,
                  entrada,
                  vieneDePregunta: vieneDePregunta,
                  numero: numeros[entrada.id],
                  total: entradas.length,
                ),
              ),
            ),
            _ => const SizedBox.shrink(),
          };
        },
      ),
    );
  }
}

/// «20 palabras explicadas fácil», con el número en un panel que gira al buscar.
class _Recuento extends StatelessWidget {
  const _Recuento({required this.total, required this.cifras});

  final int total;
  final int cifras;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final texto = total == 1 ? '1 palabra explicada fácil' : '$total palabras explicadas fácil';
    return Padding(
      padding: const EdgeInsets.only(top: Espacio.xs, bottom: Espacio.xs),
      child: Semantics(
        label: texto,
        excludeSemantics: true,
        child: Row(
          children: [
            ContadorFlip(valor: total, digitos: cifras, estilo: tema.textTheme.headlineSmall),
            const SizedBox(width: Espacio.s + Espacio.xs),
            Expanded(
              child: Text(
                total == 1 ? 'palabra explicada fácil' : 'palabras explicadas fácil',
                style: tema.textTheme.titleMedium?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La letra como una pegatina amarilla, un poco torcida, y una línea troquelada hasta el borde.
class _CabeceraLetra extends StatelessWidget {
  const _CabeceraLetra({required this.letra});

  final String letra;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Espacio.m + Espacio.xs, bottom: Espacio.s + Espacio.xs),
      child: Semantics(
        header: true,
        label: 'Letra $letra',
        child: ExcludeSemantics(
          child: Row(
            children: [
              Transform.rotate(
                angle: -0.06,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: Espacio.xxl - Espacio.s,
                    minHeight: Espacio.xxl - Espacio.s,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: Espacio.s + Espacio.xs),
                  decoration: BoxDecoration(
                    color: ColoresMarca.amarillo,
                    borderRadius: BorderRadius.circular(Radios.s - 2),
                    border: Border.all(color: ColoresMarca.azulNoche, width: 2),
                    boxShadow: sombrasPapel(context, elevacion: 0.6),
                  ),
                  child: Text(
                    letra,
                    style: tema.textTheme.headlineSmall?.copyWith(color: ColoresMarca.azulNoche, height: 1.15),
                  ),
                ),
              ),
              const SizedBox(width: Espacio.m),
              Expanded(child: LineaTroquelada(color: tema.colorScheme.outlineVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Línea de puntos, como la de un ticket que se arranca.
class LineaTroquelada extends StatelessWidget {
  const LineaTroquelada({super.key, required this.color, this.grosor = 2.5});

  final Color color;
  final double grosor;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(double.infinity, grosor),
    painter: _PintorTroquel(color: color, grosor: grosor),
  );
}

class _PintorTroquel extends CustomPainter {
  _PintorTroquel({required this.color, required this.grosor});

  final Color color;
  final double grosor;

  @override
  void paint(Canvas canvas, Size size) {
    const trazo = 6.0;
    const hueco = 5.0;
    final pincel = Paint()
      ..color = color
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    for (var x = grosor / 2; x + trazo <= size.width; x += trazo + hueco) {
      canvas.drawLine(Offset(x, y), Offset(x + trazo, y), pincel);
    }
  }

  @override
  bool shouldRepaint(_PintorTroquel anterior) => anterior.color != color || anterior.grosor != grosor;
}

/// Una palabra del glosario como carta de la colección: el icono de su tema, el nombre (con una estrella si está en
/// «Mis palabras») y el principio de la definición; en el talón amarillo, su número. Se lee como un botón con el
/// nombre y la definición (el número es decorativo).
class _CartaTermino extends StatelessWidget {
  const _CartaTermino({
    required this.entrada,
    required this.numero,
    required this.cifras,
    required this.onTap,
    this.guardada = false,
  });

  final EntradaGlosario entrada;
  final int numero;
  final int cifras;
  final VoidCallback onTap;
  final bool guardada;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final colores = context.colores;
    final estiloNumero = estiloCifras(tema.textTheme.headlineSmall)?.copyWith(color: ColoresMarca.azulNoche, height: 1);
    final numero = '${this.numero}'.padLeft(cifras, '0');
    final anchoTalon = _anchoTalon(MediaQuery.textScalerOf(context), estiloNumero, numero);
    final forma = TicketBorder(
      radio: Radios.m - Espacio.xs,
      radioMuesca: 9,
      talon: anchoTalon,
      colorTalon: ColoresMarca.amarillo,
      colorPerforado: tema.scaffoldBackgroundColor,
      side: BorderSide(color: esquema.outlineVariant),
    );

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: TicketPulsable(
          forma: forma,
          decoracion: ShapeDecoration(color: colores.ticket, shape: forma),
          elevacion: 0.8,
          vibrar: false,
          recortar: false,
          onTap: onTap,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: Espacio.m),
                child: IconoTuTurno(iconoDeTermino(entrada.termino), size: Espacio.xl + Espacio.s, decorativo: true),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(Espacio.m - Espacio.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Text(
                              entrada.termino,
                              style: tema.textTheme.headlineSmall?.copyWith(color: colores.tintaTicket, height: 1.1),
                            ),
                          ),
                          if (guardada) ...[
                            const SizedBox(width: Espacio.xs),
                            const IconoTuTurno(TuIcono.estrella, size: Espacio.l - 2, semanticLabel: 'En Mis palabras'),
                          ],
                        ],
                      ),
                      const SizedBox(height: Espacio.xs),
                      Text(
                        entrada.definicion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: anchoTalon,
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.all(Espacio.xs),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Nº',
                            style: tema.textTheme.labelMedium?.copyWith(
                              color: ColoresMarca.azulNoche,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(numero, style: estiloNumero),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Lo justo para el número con el tamaño de letra actual (con un mínimo, para que todas las cartas casen).
  static double _anchoTalon(TextScaler escala, TextStyle? estilo, String numero) {
    final pintor = TextPainter(
      text: TextSpan(text: numero, style: estilo),
      textDirection: TextDirection.ltr,
      textScaler: escala,
      maxLines: 1,
    )..layout();
    final ancho = pintor.width;
    pintor.dispose();
    return math.max(Espacio.xxl + Espacio.m, ancho + Espacio.l);
  }
}

/// Aviso con Tut en el centro: el glosario vacío (Tut tranquilo) o una búsqueda sin resultados (Tut pensando).
class _AvisoTut extends StatelessWidget {
  const _AvisoTut({required this.expresion, required this.titulo, required this.mensaje, this.accion});

  final ExpresionTut expresion;
  final String titulo;
  final String mensaje;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Espacio.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MascotaTut(expresion: expresion, size: 120, decorativo: true),
            const SizedBox(height: Espacio.m),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Espacio.s),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
            if (accion != null) ...[const SizedBox(height: Espacio.l), accion!],
          ],
        ),
      ),
    );
  }
}
