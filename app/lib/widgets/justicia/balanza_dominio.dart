import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../../tema.dart';
import '../iconos/paleta_iconos.dart';
import '../iconos/pieza.dart';
import '../iconos/tu_icono.dart';

/// La balanza del dominio de un concepto (BKT): se inclina mientras falta y se queda recta cuando lo dominas. Solo mide
/// lo que te falta por aprender: nunca juzga ni castiga.
///
/// [avance] va de 0 (sin practicar) a 1 (dominado), como `avanceDominio(p)` de aprende/widgets/comunes.dart: así no
/// depende de features/. La inclinación es 14° × (1 − avance). Al cambiar (o al aparecer, si hay [desde]), el brazo
/// oscila hasta su sitio con un muelle amortiguado (unos 900 ms: dos pequeñas oscilaciones y quieta) y los platos
/// cuelgan verticales. Con «reducir animaciones», el ángulo final, directo.
///
/// Es decorativa por defecto: la barra de dominio ya dice el nivel al lector de pantalla.
class BalanzaDominio extends StatefulWidget {
  const BalanzaDominio({
    super.key,
    required this.avance,
    this.desde,
    this.tamano = 40,
    this.alEquilibrar,
    this.semanticLabel,
    this.decorativo = true,
  });

  /// De 0 a 1.
  final double avance;

  /// Avance anterior, para animar la mejora al aparecer.
  final double? desde;
  final double tamano;

  /// Se llama una vez, cuando la balanza llega a quedarse recta (avance 1) viniendo de inclinada: para un
  /// `PopPegatina` y `Hapticos.acierto`.
  final VoidCallback? alEquilibrar;

  /// Por defecto, «Balanza: …» con su [estado].
  final String? semanticLabel;
  final bool decorativo;

  /// Grados de inclinación con avance 0.
  static const inclinacionMaxima = 14.0;

  /// Lo que tarda, más o menos, en quedarse quieta.
  static const duracionMuelle = Duration(milliseconds: 900);

  /// El muelle: masa 1, rigidez 180 y amortiguación 12 (dos pequeñas oscilaciones en ~900 ms).
  static const muelle = SpringDescription(mass: 1, stiffness: 180, damping: 12);

  /// Inclinación en grados para un [avance] (recta = dominado).
  static double inclinacion(double avance) => inclinacionMaxima * (1 - avance.clamp(0.0, 1.0));

  /// Cómo está la balanza: «Se inclina un poco», «Casi en equilibrio» o «En equilibrio: lo dominas».
  static String estado(double avance) => avance >= 1
      ? 'En equilibrio: lo dominas'
      : avance >= 2 / 3
      ? 'Casi en equilibrio'
      : 'Se inclina un poco';

  @override
  State<BalanzaDominio> createState() => EstadoBalanzaDominio();
}

/// Estado de [BalanzaDominio]. Es público para que las pruebas puedan leer la inclinación.
class EstadoBalanzaDominio extends State<BalanzaDominio> with SingleTickerProviderStateMixin {
  /// El brazo se da por quieto a menos de 0,05° de su sitio.
  static const _tolerancia = Tolerance(distance: 0.05, velocity: 0.5);

  late final AnimationController _brazo = AnimationController.unbounded(vsync: this)..addStatusListener(_alTerminar);
  var _iniciada = false;

  /// La balanza está inclinada (aún no se ha avisado de que se ha equilibrado).
  var _porEquilibrar = false;

  /// Grados de inclinación que se están pintando ahora.
  @visibleForTesting
  double get inclinacionActual => _brazo.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciada) return;
    _iniciada = true;
    final desde = widget.desde;
    _porEquilibrar = (desde ?? widget.avance) < 1;
    if (desde == null) {
      _brazo.value = BalanzaDominio.inclinacion(widget.avance);
    } else {
      _brazo.value = BalanzaDominio.inclinacion(desde);
      _ir(BalanzaDominio.inclinacion(widget.avance));
    }
  }

  @override
  void didUpdateWidget(BalanzaDominio oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avance == widget.avance) return;
    if (oldWidget.avance < 1) _porEquilibrar = true;
    _ir(BalanzaDominio.inclinacion(widget.avance));
  }

  void _ir(double destino) {
    if (duracion(context, BalanzaDominio.duracionMuelle) == Duration.zero) {
      _brazo.value = destino;
      // Sin animación también se avisa, después de este fotograma (nunca durante la construcción).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _avisarSiEquilibrada();
      });
      return;
    }
    _brazo.animateWith(SpringSimulation(BalanzaDominio.muelle, _brazo.value, destino, 0, tolerance: _tolerancia));
  }

  void _alTerminar(AnimationStatus estado) {
    if (estado == AnimationStatus.completed) _avisarSiEquilibrada();
  }

  void _avisarSiEquilibrada() {
    if (!_porEquilibrar || widget.avance < 1) return;
    _porEquilibrar = false;
    widget.alEquilibrar?.call();
  }

  @override
  void dispose() {
    _brazo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paleta = PaletaIconos.de(context);
    final dibujo = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _brazo,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.tamano),
          painter: _PintorBalanza(grados: _brazo.value, paleta: paleta),
        ),
      ),
    );
    if (widget.decorativo) return ExcludeSemantics(child: dibujo);
    return Semantics(
      image: true,
      label: widget.semanticLabel ?? 'Balanza: ${BalanzaDominio.estado(widget.avance)}',
      child: ExcludeSemantics(child: dibujo),
    );
  }
}

/// Pinta las piezas de [TuIcono.balanza] por partes: el poste, el pomo y la base, quietos; el brazo, girado alrededor
/// de su centro (50, 33); y cada plato colgado de la nueva punta del brazo, sin girar (cuelga vertical).
class _PintorBalanza extends CustomPainter {
  _PintorBalanza({required this.grados, required this.paleta});

  final double grados;
  final PaletaIconos paleta;

  /// Centro del brazo y puntas de las que cuelgan los platos, en la rejilla de 100 × 100 del icono.
  static const _eje = Offset(50, 33);
  static const _puntaIzquierda = Offset(21, 33);
  static const _puntaDerecha = Offset(79, 33);

  // Las piezas del dibujo de la balanza (lib/widgets/iconos/dibujos.dart), en su orden: los dos triángulos, los dos
  // platos, el poste, el brazo, el pomo, la base y la raya de la base.
  static List<PiezaIcono> get _piezas => TuIcono.balanza.piezas;
  static List<PiezaIcono> get _platoIzquierdo => [_piezas[0], _piezas[2]];
  static List<PiezaIcono> get _platoDerecho => [_piezas[1], _piezas[3]];
  static List<PiezaIcono> get _poste => [_piezas[4]];
  static List<PiezaIcono> get _brazo => [_piezas[5]];
  static List<PiezaIcono> get _fijas => _piezas.sublist(6);

  @override
  void paint(Canvas canvas, Size size) {
    final lado = size.shortestSide;
    if (lado <= 0 || _piezas.length < 7) return;
    final escala = lado / 100;
    // Se inclina hacia la izquierda: ángulo negativo (en pantalla, el eje y va hacia abajo).
    final angulo = -grados * math.pi / 180;
    Offset punta(Offset original) {
      final d = original - _eje;
      return _eje +
          Offset(d.dx * math.cos(angulo) - d.dy * math.sin(angulo), d.dx * math.sin(angulo) + d.dy * math.cos(angulo));
    }

    void pintar(List<PiezaIcono> piezas, {Offset desplazamiento = Offset.zero, double giro = 0}) {
      canvas.save();
      final origen = Offset((size.width - lado) / 2, (size.height - lado) / 2);
      canvas.translate(origen.dx + desplazamiento.dx * escala, origen.dy + desplazamiento.dy * escala);
      if (giro != 0) {
        canvas
          ..translate(_eje.dx * escala, _eje.dy * escala)
          ..rotate(giro)
          ..translate(-_eje.dx * escala, -_eje.dy * escala);
      }
      // La sombra de papel solo en grande: en pequeño no se nota y, en un mapa con muchas balanzas, cuesta pintarla.
      PintorIcono(piezas: piezas, paleta: paleta, sombra: lado >= 40).paint(canvas, Size.square(lado));
      canvas.restore();
    }

    pintar(_platoIzquierdo, desplazamiento: punta(_puntaIzquierda) - _puntaIzquierda);
    pintar(_platoDerecho, desplazamiento: punta(_puntaDerecha) - _puntaDerecha);
    pintar(_poste);
    pintar(_brazo, giro: angulo);
    pintar(_fijas);
  }

  @override
  bool shouldRepaint(_PintorBalanza anterior) => anterior.grados != grados || anterior.paleta != paleta;
}
