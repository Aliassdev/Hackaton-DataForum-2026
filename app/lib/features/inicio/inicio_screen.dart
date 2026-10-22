import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../tema.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/iconos/iconos.dart';
import '../../widgets/justicia/cartel_sala.dart';
import '../../widgets/justicia/fondo_justicia.dart';
import '../../widgets/marca/marca.dart';
import '../../widgets/modulos.dart';
import '../../widgets/movimiento/movimiento.dart';
import '../../widgets/tuturno_scaffold.dart';
import '../situacion/roles.dart';
import '../situacion/widgets/mi_dia.dart' show TarjetaModoDia;
import 'bienvenida.dart';
import 'tu_camino.dart';
import 'widgets/arranque.dart';
import 'widgets/palabra_del_dia.dart';
import 'widgets/saludo.dart';
import 'widgets/ticket_del_dia.dart';

/// Inicio (sección 4.1): la primera vez, la bienvenida; después, la portada. Al empezar, la bienvenida se arranca
/// como un ticket y deja ver la portada.
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vista = ref.watch(bienvenidaVistaProvider);
    return AnimatedSwitcher(
      duration: duracion(context, TransicionArranque.duracion),
      layoutBuilder: TransicionArranque.disposicion,
      transitionBuilder: TransicionArranque.transicion,
      child: vista ? const _Portada(key: ValueKey('portada')) : const Bienvenida(key: TransicionArranque.claveHoja),
    );
  }
}

/// La portada: el vestíbulo del palacio de justicia de papel (tema-justicia.md). Tut saluda, la racha y el nivel, el
/// ticket «¡Es tu turno!» del día saliendo del panel de turnos, los tres módulos como tickets con el cartel de su sala,
/// Mi situación («tu guía», con el cartel «PARTICIPA») y la palabra del día. Detrás del saludo y del pase, el palacio en
/// silueta y unas pocas formas de papel recortado que flotan despacio; los dos se quedan atrás al desplazar (paralaje).
class _Portada extends StatefulWidget {
  const _Portada({super.key});

  @override
  State<_Portada> createState() => _PortadaState();
}

class _PortadaState extends State<_Portada> {
  /// Alto del fondo (el palacio y el papel recortado, detrás del saludo, del pase y del ticket del día).
  static const _altoFondo = 330.0;

  /// Los tickets de los módulos, un poco torcidos, como pegados a mano.
  static const _giros = [-0.014, 0.011, -0.009];

  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    var orden = 0;
    return TuTurnoScaffold(
      titulo: 'TuTurno',
      tituloWidget: Semantics(header: true, child: const LogoTuTurno(alto: 28)),
      acciones: [
        IconButton(
          tooltip: 'Ajustes',
          icon: const IconoTuTurno(TuIcono.ajustes, size: 26, decorativo: true),
          onPressed: () => context.push('/ajustes'),
        ),
      ],
      body: Stack(
        children: [
          // El palacio en silueta, debajo del papel recortado: es lo más lejano (decorativo, no se lee ni se toca).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _altoFondo,
            child: FondoJusticia(scroll: _scroll, alineacion: Alignment.topCenter),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _altoFondo,
            child: FondoPapel(
              formas: 3,
              semilla: 5,
              ciclos: 1,
              periodo: const Duration(seconds: 10),
              acento: ColoresMarca.amarillo,
              scroll: _scroll,
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: anchoMaximo),
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.m, Espacio.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Entrada(orden: orden++, child: const SaludoTut()),
                    const SizedBox(height: Espacio.s + Espacio.xs),
                    Entrada(orden: orden++, child: const PaseProgreso()),
                    const SizedBox(height: Espacio.m + 2),
                    const TicketDelDia(),
                    const SizedBox(height: Espacio.l + 2),
                    Entrada(
                      orden: orden++,
                      child: Semantics(
                        header: true,
                        child: Text('¿Por dónde empiezas?', style: tema.textTheme.headlineSmall),
                      ),
                    ),
                    const SizedBox(height: Espacio.s + Espacio.xs),
                    for (final (i, modulo) in Modulo.values.indexed) ...[
                      PopPegatina(
                        orden: i,
                        retraso: const Duration(milliseconds: 320),
                        inclinacion: _giros[i],
                        giroInicial: 0.14,
                        // En su propia capa: al hacer «pop» solo se mueve la capa, no se vuelve a pintar el ticket.
                        child: RepaintBoundary(
                          child: TarjetaModulo(modulo: modulo, onTap: () => context.push(modulo.ruta)),
                        ),
                      ),
                      const SizedBox(height: Espacio.m - 2),
                    ],
                    const SizedBox(height: Espacio.s + 2),
                    // El «modo día» en la portada, solo el día de la cita (sin cuenta atrás los días de antes): «Hoy es
                    // tu día» y la hora, sin el papel ni dónde es. Sin cita hoy, no ocupa nada.
                    Entrada(
                      orden: orden++,
                      child: const TarjetaModoDia(separacion: EdgeInsets.only(bottom: Espacio.m), soloElDia: true),
                    ),
                    Entrada(orden: orden++, child: const _EntradaMiSituacion()),
                    const SizedBox(height: Espacio.l),
                    Entrada(orden: orden++, child: const PalabraDelDia()),
                    const SizedBox(height: Espacio.l + 2),
                    Entrada(orden: orden++, child: const _NotaPrivacidad()),
                    const SizedBox(height: Espacio.m),
                    Entrada(orden: orden++, child: const _Firma()),
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

/// «Mi situación» («tu guía»): con el papel del ticket de Pregunta ([tuCaminoProvider]), «Tu camino» (sin decir el
/// papel ni la fase: el móvil puede ser compartido) y directo a su línea de pasos; sin papel, el selector de papel y
/// luego `/situacion/<rol>`. Un ticket de papel tranquilo: sin giros ni saltos (va con Pregunta, que no se gamifica).
class _EntradaMiSituacion extends ConsumerWidget {
  const _EntradaMiSituacion();

  /// Lo que dice el ticket sin papel.
  static const descripcion = 'Me toca ir a la policía o al juzgado y quiero saber qué me espera';

  /// El cartel de su puerta, como el de las salas: aquí es donde participa (su camino, lo que puede pedir y Mis
  /// preguntas). Pregunta, que resuelve dudas, lleva «INFORMACIÓN».
  static const cartel = 'PARTICIPA';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camino = ref.watch(tuCaminoProvider);
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return TicketTuTurno(
      cartel: const CartelSala(texto: cartel),
      etiqueta: camino == null ? null : 'Mi situación',
      titulo: camino?.titulo ?? 'Mi situación',
      descripcion: camino?.descripcion ?? descripcion,
      icono: const IconoTuTurno(TuIcono.expediente, size: 44, decorativo: true),
      talon: const _TalonGuia(),
      tamanoTalon: 64,
      fondoTalon: oscuro ? Theme.of(context).colorScheme.surfaceContainerHighest : ColoresMarca.azulHielo,
      onTap: () => camino == null ? mostrarSelectorRol(context) : context.push(camino.ruta),
    );
  }
}

/// El talón de Mi situación: «TU GUÍA» y la flecha (nunca «tu expediente»: en la ley del menor, el expediente es el
/// procedimiento contra el menor infractor, LO 5/2000, art. 16). Con la tinta del talón.
class _TalonGuia extends StatelessWidget {
  const _TalonGuia();

  @override
  Widget build(BuildContext context) {
    final estilo = DefaultTextStyle.of(context).style;
    final letras = Theme.of(context).textTheme.labelLarge
        ?.copyWith(color: estilo.color, fontWeight: FontWeight.w800, letterSpacing: 1.2, height: 1.15);
    return Semantics(
      label: 'Tu guía',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('TU', style: letras),
            Text('GUÍA', style: letras),
            Icon(Icons.chevron_right_rounded, size: 28, color: estilo.color),
          ],
        ),
      ),
    );
  }
}

class _NotaPrivacidad extends StatelessWidget {
  const _NotaPrivacidad();

  /// Lo mismo que dice Tut en la bienvenida (auditoría P1-4: solo lo que es cierto hoy, sin prometer que se borre).
  static const texto = mensajeIA;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = tema.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconoTuTurno(TuIcono.candado, size: 18, estilo: EstiloIcono.mono, color: color, decorativo: true),
        const SizedBox(width: Espacio.s),
        Flexible(
          child: Text(texto, style: tema.textTheme.bodyMedium?.copyWith(color: color)),
        ),
      ],
    );
  }
}

/// Firma al final de la portada: el monograma y la frase de TuTurno.
class _Firma extends StatelessWidget {
  const _Firma();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      children: [
        const MonogramaTut(alto: 22, etiqueta: null),
        const SizedBox(height: Espacio.xs + 2),
        Text(
          'El derecho a ser oído empieza por entender.',
          textAlign: TextAlign.center,
          style: tema.textTheme.labelLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
