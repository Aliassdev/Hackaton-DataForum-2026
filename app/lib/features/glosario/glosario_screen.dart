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
import '../../widgets/movimiento/ticket.dart';
import '../../widgets/tuturno_scaffold.dart';
import 'detalle_termino.dart';

/// Glosario (sección 4.5): buscador sin tildes y una colección de cartas, una por palabra, numeradas como cartas
/// coleccionables y agrupadas por letras. Al tocar una carta se abre su detalle.
/// Con [busquedaInicial] (p. ej. /glosario?q=citación), si coincide con un término, se abre su detalle.
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

  @override
  void initState() {
    super.initState();
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
                  data: (entradas) => ValueListenableBuilder(
                    valueListenable: _busqueda,
                    builder: (context, valor, _) =>
                        _Resultados(entradas: entradas, consulta: valor.text, vieneDePregunta: widget.vieneDePregunta),
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

class _Resultados extends StatelessWidget {
  const _Resultados({required this.entradas, required this.consulta, this.vieneDePregunta = false});

  final List<EntradaGlosario> entradas;
  final String consulta;
  final bool vieneDePregunta;

  @override
  Widget build(BuildContext context) {
    if (entradas.isEmpty) {
      return const _AvisoTut(
        expresion: ExpresionTut.neutral,
        titulo: 'El glosario se está preparando',
        mensaje: 'Muy pronto tendrás aquí las palabras difíciles, explicadas fácil.',
      );
    }
    final encontradas = filtrarGlosario(entradas, consulta);
    if (encontradas.isEmpty) {
      final palabra = consulta.trim();
      return _AvisoTut(
        expresion: ExpresionTut.pensando,
        titulo: 'Aún no tengo “$palabra” en el glosario',
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

/// Una palabra del glosario como carta de la colección: el icono de su tema, el nombre y el principio de la
/// definición; en el talón amarillo, su número. Se lee como un botón con el nombre y la definición (el número es
/// decorativo).
class _CartaTermino extends StatelessWidget {
  const _CartaTermino({required this.entrada, required this.numero, required this.cifras, required this.onTap});

  final EntradaGlosario entrada;
  final int numero;
  final int cifras;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final colores = context.colores;
    final estiloNumero = tema.textTheme.headlineSmall?.copyWith(color: ColoresMarca.azulNoche, height: 1);
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
                      Text(
                        entrada.termino,
                        style: tema.textTheme.headlineSmall?.copyWith(color: colores.tintaTicket, height: 1.1),
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
