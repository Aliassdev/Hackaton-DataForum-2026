import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../tema.dart';
import '../iconos/icono_tuturno.dart';
import '../iconos/pieza.dart';
import '../iconos/tu_icono.dart';
import '../movimiento/hapticos.dart';

/// La carpeta de «Mi situación» (capa justicia, tema-justicia.md §7.5): una tapa de cartón amarilla con su carátula
/// de papel y una goma azul. Al entrar, la tapa se abre despacio (620 ms, una vez por sesión) y deja ver la primera
/// hoja: [titulo], [papel] y las fases, con la actual marcada. Después aparece [child]. Tranquila: sin rebotes, sellos
/// que caen ni confeti. Con «reducir animaciones», la carpeta ya está abierta.
///
/// La pestaña dice «TU GUÍA», nunca «tu expediente»: en la ley del menor, el expediente es el procedimiento contra el
/// menor infractor (LO 5/2000, art. 16). Sin nombres, números ni datos de la persona: si alguien mira la pantalla, solo
/// ve «Tu guía».
///
/// El lector de pantalla lee la hoja como una frase («Tu guía. Mi situación. Tu papel: víctima. Fases: Antes,
/// Durante, estás aquí, Después.»); la tapa es decorativa.
class ExpedienteCaratula extends StatefulWidget {
  const ExpedienteCaratula({
    super.key,
    required this.titulo,
    required this.papel,
    this.tituloTapa,
    this.etiqueta = 'TU GUÍA',
    this.fases = const ['Antes', 'Durante', 'Después'],
    this.iconosFases = const [TuIcono.citacion, TuIcono.puertaSala, TuIcono.reloj],
    this.faseActual,
    this.abrirAlEntrar = true,
    this.clave,
    this.sello,
    this.lecturaSello,
    this.child,
  });

  /// 'Mi situación' o 'Tu guía como víctima'.
  final String titulo;

  /// 'Tu papel: víctima'.
  final String papel;

  /// Lo que dice la carátula de la tapa cerrada, debajo de [etiqueta]. Por defecto, [titulo]. Mejor algo general
  /// («Mi situación»): la tapa es lo que vería alguien que mira la pantalla de reojo.
  final String? tituloTapa;

  /// El texto de la pestaña.
  final String etiqueta;
  final List<String> fases;

  /// Un icono por fase (Antes: la citación; Durante: la puerta de la sala; Después: el reloj).
  final List<TuIcono> iconosFases;

  /// Índice en [fases] de la fase marcada con «Estás aquí», o null.
  final int? faseActual;

  /// Con false, la carpeta ya sale abierta.
  final bool abrirAlEntrar;

  /// Lo que recuerda en esta sesión que la carpeta ya se abrió (por defecto, [titulo] y [papel]). Se guarda en
  /// memoria, no en el móvil: al volver a abrir la app se abre otra vez.
  final Object? clave;

  /// Un sello quieto en la esquina de la hoja (por ejemplo, «PARA TI»). No cae ni vibra: es parte del papel.
  final Widget? sello;

  /// Lo que el lector de pantalla dice del [sello], al final de la lectura de la hoja (por ejemplo, «Hecha para ti»).
  final String? lecturaSello;

  /// Lo que se ve debajo de la carpeta cuando se abre.
  final Widget? child;

  /// Lo que tarda la tapa en abrirse.
  static const duracionApertura = Duration(milliseconds: 620);

  /// Lo que espera la tapa antes de abrirse, para que se vea cerrada después de la transición de la página.
  static const esperaApertura = Duration(milliseconds: 300);

  /// Ángulo final de la tapa, en grados (más allá de 90 ya no se ve).
  static const anguloAbierta = -105.0;

  static final _abiertas = <Object>{};

  /// Para las pruebas: olvida qué carpetas se han abierto en esta sesión.
  @visibleForTesting
  static void olvidarAperturas() => _abiertas.clear();

  @override
  State<ExpedienteCaratula> createState() => _ExpedienteCaratulaState();
}

class _ExpedienteCaratulaState extends State<ExpedienteCaratula> with SingleTickerProviderStateMixin {
  late final AnimationController _apertura = AnimationController(vsync: this);
  late Animation<double> _tapa = _apertura;
  bool _preparada = false;

  Object get _clave => widget.clave ?? '${widget.titulo}|${widget.papel}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preparada) return;
    _preparada = true;
    final abrir = widget.abrirAlEntrar && !ExpedienteCaratula._abiertas.contains(_clave);
    final movimiento = duracion(context, ExpedienteCaratula.duracionApertura);
    ExpedienteCaratula._abiertas.add(_clave);
    if (!abrir || movimiento == Duration.zero) {
      _apertura.value = 1;
      return;
    }
    final total = ExpedienteCaratula.esperaApertura + ExpedienteCaratula.duracionApertura;
    _apertura.duration = total;
    _tapa = CurvedAnimation(
      parent: _apertura,
      curve: Interval(
        ExpedienteCaratula.esperaApertura.inMicroseconds / total.inMicroseconds,
        1,
        curve: Curves.easeInOutCubic,
      ),
    );
    _apertura.forward();
  }

  @override
  void dispose() {
    _apertura.dispose();
    super.dispose();
  }

  /// Tocar la carpeta cerrada la abre ya.
  void _abrirYa() {
    if (_apertura.isCompleted) return;
    Hapticos.seleccion();
    _apertura
      ..duration = ExpedienteCaratula.duracionApertura
      ..forward();
    setState(() => _tapa = CurvedAnimation(parent: _apertura, curve: Curves.easeInOutCubic));
  }

  String get _lectura {
    final fases = [for (final (i, fase) in widget.fases.indexed) i == widget.faseActual ? '$fase, estás aquí' : fase]
        .join(', ');
    final sello = widget.sello == null ? null : widget.lecturaSello;
    return '${_capitalizar(widget.etiqueta)}. ${widget.titulo}. ${widget.papel}. Fases: $fases.'
        '${sello == null ? '' : ' $sello.'}';
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: _lectura,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: _abrirYa,
            child: _Carpeta(
              etiqueta: widget.etiqueta,
              titulo: widget.titulo,
              papel: widget.papel,
              fases: widget.fases,
              iconosFases: widget.iconosFases,
              faseActual: widget.faseActual,
              sello: widget.sello,
              tituloTapa: widget.tituloTapa ?? widget.titulo,
              tapa: _tapa,
            ),
          ),
        ),
        if (child != null)
          AnimatedBuilder(
            animation: _tapa,
            builder: (context, hijo) {
              final t = const Interval(0.55, 1).transform(_tapa.value);
              return Opacity(
                opacity: t,
                child: Transform.translate(offset: Offset(0, (1 - t) * Espacio.m), child: hijo),
              );
            },
            child: child,
          ),
      ],
    );
  }
}

String _capitalizar(String texto) {
  final minusculas = texto.toLowerCase();
  return minusculas.isEmpty ? minusculas : minusculas[0].toUpperCase() + minusculas.substring(1);
}

/// Alto de la pestaña de la carpeta.
const _altoPestana = 28.0;

/// Borde de la tapa trasera alrededor de la hoja.
const _margenTapa = Espacio.s + 2;

class _Carpeta extends StatelessWidget {
  const _Carpeta({
    required this.etiqueta,
    required this.titulo,
    required this.papel,
    required this.fases,
    required this.iconosFases,
    required this.faseActual,
    required this.sello,
    required this.tituloTapa,
    required this.tapa,
  });

  final String etiqueta;
  final String titulo;
  final String tituloTapa;
  final String papel;
  final List<String> fases;
  final List<TuIcono> iconosFases;
  final int? faseActual;
  final Widget? sello;
  final Animation<double> tapa;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = context.colores;
    final tinta = colores.tintaTicket;
    final sello = this.sello;
    final hoja = DecoratedBox(
      decoration: BoxDecoration(
        color: colores.ticket,
        borderRadius: BorderRadius.circular(Radios.s),
        boxShadow: [BoxShadow(color: sombraPapelDe(context), offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.m, Espacio.m, Espacio.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              // Sitio para el sello de la esquina.
              padding: EdgeInsetsDirectional.only(end: sello == null ? 0 : Espacio.xxl + Espacio.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: tema.textTheme.headlineSmall?.copyWith(color: tinta, height: 1.1)),
                  const SizedBox(height: Espacio.xs),
                  Text(
                    papel,
                    style: tema.textTheme.titleMedium?.copyWith(color: tinta, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Espacio.m),
            Wrap(
              spacing: Espacio.s,
              runSpacing: Espacio.s,
              children: [
                for (final (i, fase) in fases.indexed)
                  _Fase(
                    texto: fase,
                    icono: i < iconosFases.length ? iconosFases[i] : TuIcono.reloj,
                    actual: i == faseActual,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // La tapa trasera, azul, con la pestaña.
        const Positioned.fill(top: _altoPestana - Radios.s, child: _TapaTrasera()),
        PositionedDirectional(
          start: Espacio.m,
          top: 0,
          child: _Pestana(texto: etiqueta),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(_margenTapa, _altoPestana, _margenTapa, _margenTapa),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              hoja,
              if (sello != null)
                PositionedDirectional(
                  end: Espacio.s,
                  top: Espacio.s,
                  child: Transform.rotate(angle: -0.16, child: sello),
                ),
            ],
          ),
        ),
        // La tapa de delante: se abre girando sobre su borde izquierdo.
        Positioned.fill(
          top: _altoPestana,
          left: _margenTapa - 2,
          right: _margenTapa - 2,
          bottom: _margenTapa - 2,
          child: AnimatedBuilder(
            animation: tapa,
            builder: (context, child) {
              final angulo = ExpedienteCaratula.anguloAbierta * tapa.value * math.pi / 180;
              // Más allá de 90 grados se vería la tapa del revés: ya no se pinta.
              if (angulo.abs() >= math.pi / 2) return const SizedBox.shrink();
              return Transform(
                alignment: AlignmentDirectional.centerStart.resolve(Directionality.of(context)),
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(angulo),
                child: child,
              );
            },
            child: ExcludeSemantics(
              child: _TapaDelantera(etiqueta: etiqueta, titulo: tituloTapa),
            ),
          ),
        ),
      ],
    );
  }
}

class _TapaTrasera extends StatelessWidget {
  const _TapaTrasera();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ColoresMarca.azul,
        borderRadius: BorderRadius.circular(Radios.m),
        boxShadow: sombrasPapel(context),
      ),
    );
  }
}

class _Pestana extends StatelessWidget {
  const _Pestana({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.labelLarge
        ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.6, height: 1.1);
    return Container(
      height: _altoPestana,
      padding: const EdgeInsets.symmetric(horizontal: Espacio.m),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: ColoresMarca.azul,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radios.s)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const IconoTuTurno(
            TuIcono.expediente,
            size: 18,
            estilo: EstiloIcono.mono,
            color: Colors.white,
            decorativo: true,
          ),
          const SizedBox(width: Espacio.xs + 2),
          Text(texto.toUpperCase(), style: estilo, maxLines: 1),
        ],
      ),
    );
  }
}

/// La tapa de cartón amarilla con su carátula de papel y la goma azul.
class _TapaDelantera extends StatelessWidget {
  const _TapaDelantera({required this.etiqueta, required this.titulo});

  final String etiqueta;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ColoresMarca.amarillo,
        borderRadius: BorderRadius.circular(Radios.s),
        border: Border.all(color: ColoresMarca.ocre.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [BoxShadow(color: sombraPapelDe(context), offset: const Offset(2, 3), blurRadius: 4)],
      ),
      child: Stack(
        children: [
          // La goma azul, vertical, cerca del borde de la derecha.
          const PositionedDirectional(
            end: Espacio.l,
            top: 0,
            bottom: 0,
            width: Espacio.s + 2,
            child: ColoredBox(color: ColoresMarca.azul),
          ),
          // La carátula: una etiqueta de papel, un poco torcida.
          Align(
            alignment: const AlignmentDirectional(-0.35, -0.1),
            child: Transform.rotate(
              angle: -0.03,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: Espacio.m, vertical: Espacio.s + 2),
                decoration: BoxDecoration(
                  color: ColoresMarca.papel,
                  borderRadius: BorderRadius.circular(Radios.s / 2),
                  border: Border.all(color: ColoresMarca.azulNoche, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      etiqueta.toUpperCase(),
                      style: tema.textTheme.titleMedium?.copyWith(
                        color: ColoresMarca.azulNoche,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      style: tema.textTheme.bodyMedium?.copyWith(color: ColoresMarca.azulNoche),
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

/// Una fase en la hoja: su icono y su nombre; la actual, en amarillo con «Estás aquí».
class _Fase extends StatelessWidget {
  const _Fase({required this.texto, required this.icono, required this.actual});

  final String texto;
  final TuIcono icono;
  final bool actual;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final tinta = actual ? ColoresMarca.azulNoche : esquema.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Espacio.s + 2, vertical: Espacio.xs + 2),
      decoration: BoxDecoration(
        color: actual ? ColoresMarca.amarillo : Colors.transparent,
        borderRadius: BorderRadius.circular(Radios.s),
        border: Border.all(color: actual ? ColoresMarca.azulNoche : esquema.outlineVariant, width: actual ? 2 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconoTuTurno(icono, size: 20, estilo: EstiloIcono.mono, color: tinta, decorativo: true),
          const SizedBox(width: Espacio.xs + 2),
          // Si no cabe (letra grande, móvil estrecho), pasa a otra línea dentro de su pastilla.
          Flexible(
            child: Text(
              actual ? '$texto · Estás aquí' : texto,
              style: tema.textTheme.labelLarge?.copyWith(
                color: tinta,
                fontWeight: actual ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
