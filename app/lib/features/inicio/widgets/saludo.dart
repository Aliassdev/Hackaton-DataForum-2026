import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/progreso.dart';
import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../../../widgets/modulos.dart';
import '../../../widgets/movimiento/movimiento.dart';
import '../nivel.dart';
import '../turno_del_dia.dart';
import 'bocadillo.dart';

/// Saludo del inicio: Tut te saluda con un bocadillo. Si le tocas, se sorprende y dice otra cosa; cuando cae el sello
/// del turno del día, lo celebra un momento.
class SaludoTut extends ConsumerStatefulWidget {
  const SaludoTut({super.key});

  /// El saludo para la [hora] del día (de 0 a 23).
  static String saludoPara(int hora) => switch (hora) {
    < 6 => '¡Buenas noches!',
    < 13 => '¡Buenos días!',
    < 21 => '¡Buenas tardes!',
    _ => '¡Buenas noches!',
  };

  /// Lo que dice Tut cuando le tocas (sin contenido jurídico: solo para jugar).
  static const frasesAlTocar = [
    '¡Eh, que hace cosquillas!',
    'Soy Tut, tu ticket favorito.',
    'Toca tu turno del día y vamos allá.',
  ];

  @override
  ConsumerState<SaludoTut> createState() => _SaludoTutState();
}

class _SaludoTutState extends ConsumerState<SaludoTut> {
  static const _sorpresa = Duration(milliseconds: 900);
  static const _fiesta = Duration(milliseconds: 3200);

  ExpresionTut? _momentanea;
  String? _frase;
  int _toques = 0;
  Timer? _vuelta;

  void _poner(ExpresionTut expresion, Duration durante) {
    _vuelta?.cancel();
    setState(() => _momentanea = expresion);
    _vuelta = Timer(durante, () {
      if (mounted) setState(() => _momentanea = null);
    });
  }

  void _alTocar() {
    Hapticos.seleccion();
    setState(() => _frase = SaludoTut.frasesAlTocar[_toques++ % SaludoTut.frasesAlTocar.length]);
    _poner(ExpresionTut.sorprendida, _sorpresa);
  }

  @override
  void dispose() {
    _vuelta?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cuando cae el sello del turno del día, Tut lo celebra un momento.
    ref.listen(turnoDelDiaProvider, (antes, ahora) {
      if (antes != null && !antes.celebrada && ahora.celebrada) _poner(ExpresionTut.celebrando, _fiesta);
    });
    final tema = Theme.of(context);
    final turno = ref.watch(turnoDelDiaProvider);
    final progreso = ref.watch(progresoProvider);
    final hora = ref.watch(relojProvider)().hour;
    final primeraVez = progreso.xp == 0 && progreso.leccionesCompletadas.isEmpty && progreso.cartas.isEmpty;
    final frase =
        _frase ??
        (turno.cumplida
            ? '¡Turno cumplido! Sigue a tu ritmo.'
            : primeraVez
            ? 'Soy Tut. ¿Empezamos por tu turno del día?'
            : '¿Qué te toca hoy?');
    final colores = context.colores;
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Tut, la mascota de TuTurno',
          hint: 'Tócala para que te salude',
          onTap: _alTocar,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: _alTocar,
            behavior: HitTestBehavior.opaque,
            child: TutAjustado(tamano: 92, expresion: _momentanea ?? ExpresionTut.feliz),
          ),
        ),
        const SizedBox(width: Espacio.xs),
        Expanded(
          child: Bocadillo(
            posicionCola: 0.45,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    SaludoTut.saludoPara(hora),
                    style: tema.textTheme.headlineSmall?.copyWith(color: colores.tintaTicket, height: 1.1),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: duracion(context, Duracion.corta),
                  layoutBuilder: (actual, anteriores) =>
                      Stack(alignment: Alignment.topLeft, children: [...anteriores, ?actual]),
                  child: Text(
                    frase,
                    key: ValueKey(frase),
                    style: tema.textTheme.bodyLarge?.copyWith(color: colores.tintaTicket, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Tu pase: la racha y el nivel en un ticket de papel de dos partes, con la línea de puntos en medio. Al tocarlo, se
/// explica cómo funcionan (sin letra pequeña).
class PaseProgreso extends ConsumerWidget {
  const PaseProgreso({super.key});

  /// Ancho de la parte de la racha: cabe «12 días» incluso con la letra grande (crece solo un poco, para dejar sitio
  /// al nivel).
  static const _anchoRacha = 98.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progreso = ref.watch(progresoProvider);
    final hoy = soloDia(ref.watch(relojProvider)());
    final racha = rachaViva(progreso, hoy);
    final nivel = Nivel.de(progreso.xp);
    final tema = Theme.of(context);
    final textos = tema.textTheme;
    final colores = context.colores;
    final tinta = colores.tintaTicket;
    final escala = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);
    final dias = racha == 1 ? 'día' : 'días';
    final semantica =
        '${racha == 0 ? 'Racha: empieza hoy con una lección' : 'Racha: $racha $dias seguidos con una lección'}. '
        'Nivel ${nivel.numero}, ${nivel.titulo}. ${progreso.xp} puntos de experiencia.';

    Widget parteRacha({required bool centrada}) => Row(
      mainAxisAlignment: centrada ? MainAxisAlignment.center : MainAxisAlignment.start,
      mainAxisSize: centrada ? MainAxisSize.max : MainAxisSize.min,
      children: [
        const IconoTuTurno(TuIcono.racha, size: 30, decorativo: true),
        const SizedBox(width: Espacio.xs + 2),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              PopPegatina(
                clave: racha,
                animar: false,
                inclinacion: 0,
                child: Text('$racha', style: estiloCifras(textos.headlineSmall)?.copyWith(color: tinta, height: 1)),
              ),
              Text(dias, style: textos.labelMedium?.copyWith(color: tinta)),
            ],
          ),
        ),
      ],
    );
    final parteNivel = Row(
      children: [
        const IconoTuTurno(TuIcono.nivel, size: 30, decorativo: true),
        const SizedBox(width: Espacio.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Nivel ${nivel.numero}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: ' · ${nivel.titulo}'),
                  ],
                ),
                style: textos.titleSmall?.copyWith(color: tinta, height: 1.2),
              ),
              const SizedBox(height: Espacio.xs + 1),
              // La barra siempre se ve: los puntos nunca ocupan más de la mitad (si no caben, se encogen un poco).
              LayoutBuilder(
                builder: (context, restricciones) => Row(
                  children: [
                    Expanded(child: _Barra(valor: nivel.progreso(progreso.xp))),
                    const SizedBox(width: Espacio.s),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: restricciones.maxWidth * 0.5),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: PopPegatina(
                          clave: progreso.xp,
                          animar: false,
                          inclinacion: 0,
                          child: Text(
                            '${progreso.xp} XP',
                            style: textos.labelMedium?.copyWith(color: tinta, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final Widget contenido;
    if (letraGrande(context)) {
      // Con la letra grande no caben una al lado de la otra: la racha arriba y el nivel abajo, con los puntos en medio.
      final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.m - 2));
      contenido = TicketPulsable(
        forma: forma,
        decoracion: ShapeDecoration(color: colores.ticket, shape: forma),
        vibrar: false,
        onTap: () => _abrir(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Espacio.m, vertical: Espacio.s + 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.centerLeft, child: parteRacha(centrada: false)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Espacio.s + 2),
                child: _LineaDePuntos(color: tema.colorScheme.outlineVariant),
              ),
              parteNivel,
            ],
          ),
        ),
      );
    } else {
      contenido = LayoutBuilder(
        builder: (context, restricciones) {
          final izquierda = (_anchoRacha + 16 * (escala - 1)).roundToDouble();
          final forma = TicketBorder(
            radio: Radios.m - 2,
            radioMuesca: 8,
            talon: restricciones.maxWidth - izquierda,
            colorPerforado: tema.colorScheme.outlineVariant,
          );
          return TicketPulsable(
            forma: forma,
            decoracion: ShapeDecoration(color: colores.ticket, shape: forma),
            vibrar: false,
            onTap: () => _abrir(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  SizedBox(
                    width: izquierda,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Espacio.s, vertical: Espacio.s + 2),
                      child: parteRacha(centrada: true),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s + 2, Espacio.m, Espacio.s + 2),
                      child: parteNivel,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Semantics(
      button: true,
      label: semantica,
      hint: 'Ver tu progreso',
      onTap: () => _abrir(context),
      excludeSemantics: true,
      child: contenido,
    );
  }

  static void _abrir(BuildContext context) {
    Hapticos.seleccion();
    mostrarProgreso(context);
  }
}

/// Barrita de progreso del nivel: el relleno amarillo, con borde, sobre una pista clara con su borde (en el tema
/// oscuro, la pista es azul). Sin puntos se ve vacía: ni llena ni desactivada.
class _Barra extends StatelessWidget {
  const _Barra({required this.valor});

  final double valor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final oscuro = tema.brightness == Brightness.dark;
    return Container(
      height: 10,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: oscuro ? tema.colorScheme.surfaceContainerHighest : ColoresMarca.azulHielo,
        borderRadius: BorderRadius.circular(5),
        // El borde de la pista llega a 3:1 sobre el papel del pase en los dos temas.
        border: Border.all(color: (oscuro ? ColoresMarca.azulCielo : ColoresMarca.azulNoche).withValues(alpha: 0.5)),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: valor),
        duration: duracion(context, Duracion.larga),
        curve: Curves.easeOutCubic,
        // Sin puntos no se pinta nada (ni el borde de la parte llena); con alguno, al menos se ve un trocito.
        builder: (context, v, _) => v <= 0.001
            ? const SizedBox.shrink()
            : FractionallySizedBox(
                widthFactor: v.clamp(0.08, 1.0),
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ColoresMarca.amarillo,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: oscuro ? ColoresMarca.azul : ColoresMarca.azulNoche, width: 1.5),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Hoja «Tu progreso»: el nivel, todos los títulos y cómo se ganan los puntos. Transparente y sin presión.
Future<void> mostrarProgreso(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => const _HojaProgreso(),
);

class _HojaProgreso extends ConsumerWidget {
  const _HojaProgreso();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final textos = tema.textTheme;
    final esquema = tema.colorScheme;
    final progreso = ref.watch(progresoProvider);
    final nivel = Nivel.de(progreso.xp);
    final siguiente = nivel.siguiente;
    // Pasado el último título, los niveles se cuentan por número.
    final meta = siguiente.titulo == nivel.titulo ? 'el nivel ${siguiente.numero}' : '«${siguiente.titulo}»';
    final racha = rachaViva(progreso, soloDia(ref.watch(relojProvider)()));
    final niveles = [for (var n = 1; n <= Nivel.titulosNivel.length; n++) Nivel.numero(n)];
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Espacio.l, 0, Espacio.l, Espacio.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(header: true, child: Text('Tu progreso', style: textos.headlineSmall)),
            const SizedBox(height: Espacio.m),
            Row(
              children: [
                const IconoTuTurno(TuIcono.nivel, size: 48, decorativo: true),
                const SizedBox(width: Espacio.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nivel ${nivel.numero} · ${nivel.titulo}',
                        style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: Espacio.xs),
                      Text(
                        'Tienes ${progreso.xp} XP. Te faltan ${nivel.faltan(progreso.xp)} para $meta.',
                        style: textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espacio.l),
            Text('Los niveles', style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: Espacio.s),
            for (final n in niveles)
              _FilaNivel(nivel: n, alcanzado: n.numero <= nivel.numero, actual: n.numero == nivel.numero),
            const SizedBox(height: Espacio.l),
            Text('Cómo se ganan', style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: Espacio.s),
            const _Explicacion(icono: TuIcono.xp, texto: '+10 XP por cada respuesta correcta en Aprende.'),
            const _Explicacion(
              icono: TuIcono.idea,
              texto: '+5 XP en «Dilo con tus palabras» si explicas al menos la mitad de la idea.',
            ),
            _Explicacion(
              icono: TuIcono.racha,
              texto:
                  '${racha == 0 ? 'La racha' : 'Tu racha de $racha ${racha == 1 ? 'día' : 'días'}'} suma un día cada '
                  'día que completas una lección. Si un día no puedes, no pasa nada: empiezas otra cuando quieras.',
            ),
            const _Explicacion(
              icono: TuIcono.candado,
              texto: 'Tus puntos se guardan solo en este móvil. No hay cuentas ni rankings.',
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaNivel extends StatelessWidget {
  const _FilaNivel({required this.nivel, required this.alcanzado, required this.actual});

  final Nivel nivel;
  final bool alcanzado;
  final bool actual;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final estilo = tema.textTheme.bodyLarge?.copyWith(
      fontWeight: actual ? FontWeight.w700 : FontWeight.w400,
      color: alcanzado ? esquema.onSurface : esquema.onSurfaceVariant,
    );
    return Semantics(
      label:
          'Nivel ${nivel.numero}, ${nivel.titulo}, desde ${nivel.desde} XP. '
          '${actual ? 'Es tu nivel.' : (alcanzado ? 'Conseguido.' : 'Aún no.')}',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: Espacio.xs),
        padding: const EdgeInsets.symmetric(horizontal: Espacio.s + 2, vertical: Espacio.s),
        // Tu nivel, marcado con rotulador amarillo; en el tema oscuro, con el tinte de la marca (amarillo translúcido
        // sobre azul noche saldría gris).
        decoration: actual
            ? BoxDecoration(
                color: tema.brightness == Brightness.dark
                    ? tinte(context, ColoresMarca.amarillo)
                    : ColoresMarca.amarillo.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(Radios.s),
              )
            : null,
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text('${nivel.numero}', style: estilo?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Expanded(child: Text(nivel.titulo, style: estilo)),
            const SizedBox(width: Espacio.s),
            Text('${nivel.desde} XP', style: tema.textTheme.labelLarge?.copyWith(color: esquema.onSurfaceVariant)),
            const SizedBox(width: Espacio.s),
            IconoTuTurno(alcanzado ? TuIcono.check : TuIcono.candado, size: 22, decorativo: true),
          ],
        ),
      ),
    );
  }
}

class _Explicacion extends StatelessWidget {
  const _Explicacion({required this.icono, required this.texto});

  final TuIcono icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Espacio.s + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconoTuTurno(icono, size: 26, decorativo: true),
          const SizedBox(width: Espacio.s + 2),
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

/// Línea de puntos horizontal (la que se arranca), para el pase apilado.
class _LineaDePuntos extends StatelessWidget {
  const _LineaDePuntos({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2.5,
      width: double.infinity,
      child: CustomPaint(painter: _PintorPuntos(color)),
    );
  }
}

class _PintorPuntos extends CustomPainter {
  const _PintorPuntos(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;
    const trazo = 4.0;
    const hueco = 5.0;
    for (var x = 0.0; x + trazo <= size.width; x += trazo + hueco) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + trazo, size.height / 2), pincel);
    }
  }

  @override
  bool shouldRepaint(_PintorPuntos anterior) => anterior.color != color;
}
