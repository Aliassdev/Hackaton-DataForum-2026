import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../tema.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/iconos/iconos.dart';
import '../../widgets/marca/marca.dart';
import '../../widgets/modulos.dart';
import '../../widgets/movimiento/movimiento.dart';
import '../../widgets/tuturno_scaffold.dart';
import '../situacion/roles.dart';
import 'bienvenida.dart';
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

/// La portada: el mostrador de turnos de TuTurno. Tut saluda, la racha y el nivel, el ticket «¡Es tu turno!» del día
/// saliendo del dispensador, los tres módulos como tickets, Mi situación y la palabra del día. Detrás, papel recortado
/// que flota despacio y se queda atrás al desplazar (paralaje).
class _Portada extends StatefulWidget {
  const _Portada({super.key});

  @override
  State<_Portada> createState() => _PortadaState();
}

class _PortadaState extends State<_Portada> {
  /// Alto del papel recortado del fondo (detrás del saludo, del pase y del ticket del día).
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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _altoFondo,
            child: FondoPapel(
              formas: 5,
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

/// «Mi situación: estoy en un proceso» → selector de papel → `/situacion/<rol>`. Un ticket de papel tranquilo: sin
/// giros ni saltos (va con Pregunta, que no se gamifica).
class _EntradaMiSituacion extends StatelessWidget {
  const _EntradaMiSituacion();

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return TicketTuTurno(
      titulo: 'Mi situación',
      descripcion: 'Me toca ir a la policía o al juzgado y quiero saber qué me espera',
      icono: const IconoTuTurno(TuIcono.miSituacion, size: 44, decorativo: true),
      talon: const Icon(Icons.chevron_right_rounded, size: 32),
      tamanoTalon: 52,
      fondoTalon: oscuro ? Theme.of(context).colorScheme.surfaceContainerHighest : ColoresMarca.azulHielo,
      onTap: () => mostrarSelectorRol(context),
    );
  }
}

class _NotaPrivacidad extends StatelessWidget {
  const _NotaPrivacidad();

  /// El mismo mensaje de la bienvenida, sin la parte de Ayuda (Ayuda ya está arriba).
  static const texto = 'Soy una IA. No te pido tu nombre y lo que hablamos se borra.';

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
