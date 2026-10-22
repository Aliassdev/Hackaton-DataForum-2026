import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../../../widgets/justicia/panel_senalamiento.dart';
import '../../../widgets/modulos.dart';
import '../../../widgets/movimiento/movimiento.dart';
import '../turno_del_dia.dart';

/// «¡Es tu turno!»: el ticket del día sale del panel de turnos (como en el vestíbulo de un juzgado o en un mostrador
/// de verdad), con el número en paletas que giran y una misión pequeña que lleva a un módulo. Encima, el tablero del
/// panel ([PanelSenalamiento]) dice el turno y la sala de la misión: «TURNO 001 · SALA 2 · APRENDE». Al cumplir la
/// misión, un sello «HECHO» cae sobre el talón con confeti de papel (una sola vez).
///
/// Todo el ticket es un botón que lleva al módulo de la misión. Con «reducir animaciones», el ticket ya está fuera,
/// los números no giran y el sello aparece puesto.
class TicketDelDia extends ConsumerStatefulWidget {
  const TicketDelDia({super.key, this.retraso = const Duration(milliseconds: 220)});

  /// Espera antes de que el ticket empiece a salir.
  final Duration retraso;

  @override
  ConsumerState<TicketDelDia> createState() => _TicketDelDiaState();
}

class _TicketDelDiaState extends ConsumerState<TicketDelDia> with SingleTickerProviderStateMixin {
  /// Lo que tarda el ticket en salir del panel de turnos.
  static const _salida = Duration(milliseconds: 820);

  /// Alto de la barra del panel de turnos y altura de su ranura (por donde sale el ticket).
  static const _altoDispensador = 26.0;
  static const _ranura = 15.0;

  late final AnimationController _dispensar = AnimationController(vsync: this);
  bool _iniciado = false;
  int? _desde;

  Duration get _total => widget.retraso + _salida;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    if (duracion(context, _salida) == Duration.zero) {
      _dispensar.value = 1;
    } else {
      _dispensar
        ..duration = _total
        ..forward();
    }
  }

  @override
  void dispose() {
    _dispensar.dispose();
    super.dispose();
  }

  /// Progreso de la salida del ticket (de 0 a 1), sin el retraso.
  double get _p {
    final inicio = widget.retraso.inMicroseconds / _total.inMicroseconds;
    return ((_dispensar.value - inicio) / (1 - inicio)).clamp(0.0, 1.0);
  }

  void _alEstampar() {
    if (!mounted || !ref.read(turnoDelDiaProvider).porCelebrar) return;
    lanzarConfeti(context, origen: const Alignment(0.55, -0.45));
    ref.read(turnoDelDiaProvider.notifier).marcarCelebrada();
  }

  @override
  Widget build(BuildContext context) {
    final turno = ref.watch(turnoDelDiaProvider);
    if (_desde == null) {
      // La primera vez, el panel da la vuelta desde «998» hasta el 001; después, gira desde el último que se vio.
      _desde = turno.numeroVisto ?? (turno.numero + 997) % 1000;
      final numero = turno.numero;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(turnoDelDiaProvider.notifier).marcarVisto(numero);
      });
    }
    // Si se cumple mientras otra pantalla tapa el inicio, el sello espera a que se vea: cae al volver.
    final visible = ModalRoute.isCurrentOf(context) ?? true;
    final estampado = turno.cumplida && (turno.celebrada || visible);
    final retrasoSello = _dispensar.isCompleted
        ? const Duration(milliseconds: 380)
        : _total + const Duration(milliseconds: 120);

    // En su propia capa: mientras sale del panel de turnos solo se mueve, no se vuelve a pintar.
    final ticket = RepaintBoundary(
      child: _Ticket(turno: turno, desde: _desde!, onTap: () => context.push(turno.mision.ruta)),
    );
    final sala = turno.mision.modulo.sala;
    final maquina = Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: _ranura),
          child: ClipRect(
            clipper: const _SoloPorArriba(),
            child: AnimatedBuilder(
              animation: _dispensar,
              child: ticket,
              builder: (context, hijo) {
                final p = _p;
                // Sale de la ranura pasándose un poco y se balancea al soltarse.
                final salida = Curves.easeOutBack.transform(p);
                final balanceo = (1 - Curves.easeOutCubic.transform(p)) * 0.05;
                return FractionalTranslation(
                  translation: Offset(0, salida - 1),
                  child: Transform.rotate(angle: balanceo, alignment: Alignment.topCenter, child: hijo),
                );
              },
            ),
          ),
        ),
        const Positioned(
          top: 0,
          left: -Espacio.xs,
          right: -Espacio.xs,
          height: _altoDispensador,
          child: _Dispensador(),
        ),
        // El sello va fuera del recorte del ticket: mientras cae es grande.
        Positioned(
          top: _ranura,
          right: 0,
          bottom: 0,
          width: _Ticket.anchoTalonPara(context),
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _dispensar,
              builder: (context, hijo) => Opacity(opacity: const Interval(0.8, 1).transform(_p), child: hijo),
              child: Center(
                child: SelloAnimado(
                  estampado: estampado,
                  animar: turno.porCelebrar,
                  retraso: retrasoSello,
                  colorTinta: ColoresMarca.azulNoche,
                  inclinacion: -0.2,
                  alEstampar: _alEstampar,
                  child: const Sello(
                    texto: 'Hecho',
                    textoCircular: 'TURNO CUMPLIDO · TUTURNO · ',
                    color: ColoresMarca.azulNoche,
                    tamano: 100,
                    semanticLabel: 'Sello: turno cumplido',
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    if (sala == null) return maquina;
    // Encima, el panel de turnos con el número y la sala de la misión (los señalamientos de un juzgado): gira a la vez
    // que el número del talón. Va encajado en la máquina (la barra se pinta encima de su borde de abajo).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Espacio.m),
            child: PanelSenalamiento(
              turno: _cifras(turno.numero),
              desde: _cifras(_desde!),
              sala: sala,
              destino: turno.mision.modulo.titulo,
            ),
          ),
        ),
        Transform.translate(offset: const Offset(0, -_encaje), child: maquina),
      ],
    );
  }

  /// Lo que el panel de turnos se mete por debajo de la barra de la máquina.
  static const _encaje = 4.0;

  /// El número de turno con tres cifras, como en el talón: 1 → «001».
  static String _cifras(int numero) => numero.toString().padLeft(3, '0');
}

/// Recorta solo lo que queda por encima de la ranura: las sombras de los lados y de abajo se siguen viendo.
class _SoloPorArriba extends CustomClipper<Rect> {
  const _SoloPorArriba();

  @override
  Rect getClip(Size size) => Rect.fromLTRB(-size.width, 0, size.width * 2, size.height * 3);

  @override
  bool shouldReclip(_SoloPorArriba oldClipper) => false;
}

/// El ticket: cuerpo azul con la misión y talón amarillo con el número de turno.
class _Ticket extends StatelessWidget {
  const _Ticket({required this.turno, required this.desde, required this.onTap});

  /// Ancho del talón: algo más estrecho con la letra grande, para dejar sitio a la misión.
  static double anchoTalonPara(BuildContext context) => letraGrande(context) ? 92 : 104;

  final TurnoDelDia turno;
  final int desde;
  final VoidCallback onTap;

  /// Papel recortado del cuerpo: luces suaves sobre el azul (el texto blanco sigue por encima de 4,5:1).
  static const _papel = [Color(0x14FFFFFF), Color(0x0FFFFFFF), Color(0x1A0E1A4F)];

  static const _meses = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final textos = tema.textTheme;
    final anchoTalon = anchoTalonPara(context);
    final forma = TicketBorder(
      radio: Radios.l - Espacio.xs,
      radioMuesca: 12,
      talon: anchoTalon,
      colorTalon: ColoresMarca.amarillo,
      colorPerforado: tema.scaffoldBackgroundColor,
    );
    final mision = turno.mision;
    final cumplida = turno.cumplida;

    final cuerpo = Padding(
      padding: const EdgeInsets.fromLTRB(Espacio.l - 2, Espacio.m + 2, Espacio.m - 2, Espacio.m + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'TU TURNO DEL DÍA',
            semanticsLabel: 'Tu turno del día.',
            style: textos.labelLarge?.copyWith(
              color: ColoresMarca.amarillo,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: Espacio.xs / 2),
          Text(
            cumplida ? '¡Cumplido!' : '¡Es tu turno!',
            style: textos.displaySmall?.copyWith(color: Colors.white, height: 1.05),
          ),
          const SizedBox(height: Espacio.s + Espacio.xs),
          Row(
            children: [
              Transform.rotate(
                angle: -0.08,
                child: IconoTuTurno(
                  cumplida ? TuIcono.check : mision.icono,
                  size: 30,
                  pegatina: true,
                  decorativo: true,
                ),
              ),
              const SizedBox(width: Espacio.s + 2),
              Expanded(
                // La flecha va al final del texto, con él: se entiende que el ticket lleva a algún sitio.
                child: Text.rich(
                  TextSpan(
                    text: cumplida ? mision.hecha : mision.texto,
                    children: [
                      if (!cumplida)
                        const WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: EdgeInsets.only(left: Espacio.s - 2),
                            child: _Flecha(),
                          ),
                        ),
                    ],
                  ),
                  semanticsLabel: cumplida ? '${mision.hecha}.' : 'Misión: ${mision.texto}.',
                  style: textos.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700, height: 1.25),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final dia = turno.dia;
    final tinta = textos.labelLarge?.copyWith(color: ColoresMarca.azulNoche, fontWeight: FontWeight.w700);
    // Con el sello puesto, lo de debajo se queda en un segundo plano para que «HECHO» se lea bien.
    final talon = AnimatedOpacity(
      opacity: cumplida && turno.celebrada ? 0.22 : 1,
      duration: duracion(context, Duracion.media),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Espacio.s, vertical: Espacio.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('TURNO', style: tinta?.copyWith(letterSpacing: 1.8)),
              ),
            ),
            const SizedBox(height: Espacio.xs + 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: ContadorFlip(
                valor: turno.numero,
                digitos: 3,
                desde: desde,
                estilo: textos.headlineSmall,
                semanticsLabel: 'Turno número ${turno.numero}.',
              ),
            ),
            const SizedBox(height: Espacio.xs + 2),
            ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${dia.day} ${_meses[dia.month - 1]}',
                  style: tinta?.copyWith(fontWeight: FontWeight.w400, letterSpacing: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return MergeSemantics(
      child: Semantics(
        button: true,
        hint: 'Ir a ${mision.modulo.titulo}',
        child: TicketPulsable(
          forma: forma,
          decoracion: ShapeDecoration(color: ColoresMarca.azul, shape: forma),
          elevacion: 1.6,
          onTap: onTap,
          child: Row(
            children: [
              Expanded(
                child: FondoPapel(colores: _papel, formas: 3, semilla: 8, animado: false, child: cuerpo),
              ),
              SizedBox(
                width: anchoTalon,
                child: Center(child: talon),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botoncito amarillo con una flecha: se entiende que el ticket lleva a algún sitio.
class _Flecha extends StatelessWidget {
  const _Flecha();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(color: ColoresMarca.amarillo, shape: BoxShape.circle),
        child: const Icon(Icons.arrow_forward_rounded, size: 18, color: ColoresMarca.azulNoche),
      ),
    );
  }
}

/// La barra del panel de turnos: la ranura por la que sale el ticket y una lucecita amarilla.
class _Dispensador extends StatelessWidget {
  const _Dispensador();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final oscuro = tema.brightness == Brightness.dark;
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _PintorDispensador(
          cuerpo: oscuro ? tema.colorScheme.surfaceBright : ColoresMarca.azulNoche,
          sombra: sombraPapelDe(context),
        ),
      ),
    );
  }
}

class _PintorDispensador extends CustomPainter {
  const _PintorDispensador({required this.cuerpo, required this.sombra});

  final Color cuerpo;
  final Color sombra;

  @override
  void paint(Canvas canvas, Size size) {
    final barra = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height / 2));
    canvas
      ..drawRRect(barra.shift(const Offset(0, 2.5)), Paint()..color = sombra)
      ..drawRRect(barra, Paint()..color = cuerpo)
      // Brillo de plástico arriba.
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.height / 2, 3, size.width - size.height, 2.5),
          const Radius.circular(2),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.12),
      );
    // La ranura, a la altura por la que sale el ticket.
    final ranura = RRect.fromRectAndRadius(
      Rect.fromLTRB(26, size.height * 0.5, size.width - 14, size.height * 0.5 + 6),
      const Radius.circular(3),
    );
    canvas
      ..drawRRect(ranura, Paint()..color = Colors.black.withValues(alpha: 0.5))
      ..drawCircle(Offset(13, size.height * 0.5), 4, Paint()..color = ColoresMarca.amarillo);
  }

  @override
  bool shouldRepaint(_PintorDispensador anterior) => anterior.cuerpo != cuerpo || anterior.sombra != sombra;
}
