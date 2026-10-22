import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/entrada.dart';
import '../../../core/mis_preguntas.dart';
import '../../../core/progreso.dart' show relojProvider;
import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../../../widgets/movimiento/hapticos.dart';
import '../../../widgets/movimiento/ticket.dart';
import '../../pasos/personalizacion_linea.dart' show CosaQueLlevar;
import '../mi_ticket.dart';
import '../papel.dart';
import '../personalizacion.dart';
import '../textos.dart';

// «Tu día» (opcional): la fecha de la citación y la lista de lo que vas a llevar, todo solo en este móvil. Cuánto falta
// solo se dice aquí dentro, en «Tu día» (producto: nada de cuentas atrás que agobien): el saludo y la tarjeta dicen la
// fecha. El día de la cita, el «modo día»: arriba de tu guía y en el inicio (solo ese día).

/// «Jueves 24 de octubre».
String fechaLarga(DateTime dia) {
  final texto = fechaEnFrase(dia);
  return texto[0].toUpperCase() + texto.substring(1);
}

/// [texto] con sus cifras en la letra de las cifras ([estiloCifras]): en la de los titulares (MaryKate), el 0 parece
/// una O. Para «Hoy es tu día · 12:30» o «Faltan 3 días». Las cifras van algo más pequeñas (Nunito ExtraBold se ve
/// mayor que MaryKate al mismo tamaño), y el punto que las separa del texto, con ellas (el de MaryKate casi no se ve).
Text textoConCifras(String texto, {TextStyle? estilo}) {
  final cifrasEstilo = estiloCifras(estilo);
  final tamano = cifrasEstilo?.fontSize;
  final deCifras = cifrasEstilo?.copyWith(fontSize: tamano == null ? null : tamano * 0.85);
  final partes = <InlineSpan>[];
  var desde = 0;
  for (final cifras in RegExp(r'(?:\u00A0?·\s*)?\d+(?:[:.,]\d+)*').allMatches(texto)) {
    if (cifras.start > desde) partes.add(TextSpan(text: texto.substring(desde, cifras.start)));
    partes.add(TextSpan(text: cifras.group(0), style: deCifras));
    desde = cifras.end;
  }
  if (desde < texto.length) partes.add(TextSpan(text: texto.substring(desde)));
  return Text.rich(TextSpan(children: partes), style: estilo);
}

/// «10:05».
String textoHora(HoraCita hora) =>
    '${hora.horas.toString().padLeft(2, '0')}:${hora.minutos.toString().padLeft(2, '0')}';

/// «Tu día»: la fecha y cuánto falta, la hora y la lista de lo que llevar (las sugerencias de tu papel y las tuyas).
class TuDia extends ConsumerStatefulWidget {
  const TuDia({super.key, required this.perfil, required this.cosas});

  final PerfilSituacion perfil;

  /// Lo que se sugiere llevar (consejos prácticos).
  final List<CosaQueLlevar> cosas;

  @override
  ConsumerState<TuDia> createState() => _TuDiaState();
}

class _TuDiaState extends ConsumerState<TuDia> {
  final _nueva = TextEditingController();

  @override
  void dispose() {
    _nueva.dispose();
    super.dispose();
  }

  MiTicketNotifier get _ticket => ref.read(miTicketProvider.notifier);

  Future<void> _elegirFecha() async {
    final hoy = ref.read(relojProvider)();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    final actual = widget.perfil.ticket.fecha;
    final elegida = await showDatePicker(
      context: context,
      initialDate: actual != null && !actual.isBefore(inicio) ? actual : inicio,
      firstDate: inicio,
      lastDate: inicio.add(const Duration(days: 366)),
      helpText: 'Día de la citación',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
    );
    if (elegida != null) _ticket.ponerFecha(elegida);
  }

  Future<void> _elegirHora() async {
    final actual = widget.perfil.ticket.hora;
    final elegida = await showTimePicker(
      context: context,
      initialTime: actual == null
          ? const TimeOfDay(hour: 10, minute: 0)
          : TimeOfDay(hour: actual.horas, minute: actual.minutos),
      helpText: 'Hora de la citación',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
    );
    if (elegida != null) _ticket.ponerHora(elegida.hour, elegida.minute);
  }

  void _anadir() {
    final texto = _nueva.text;
    if (texto.trim().isEmpty) return;
    if (_ticket.anadirLlevar(texto)) {
      Hapticos.seleccion();
      _nueva.clear();
    } else {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(const SnackBar(content: Text('Ya está en la lista o no caben más (como mucho 10).')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final perfil = widget.perfil;
    final ticket = perfil.ticket;
    final fecha = ticket.fecha;
    final dias = perfil.diasParaLaCita;
    if (fecha == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(textoSinDia, style: tema.textTheme.bodyLarge),
          const SizedBox(height: Espacio.s + Espacio.xs),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              onPressed: _elegirFecha,
              icon: const IconoTuTurno(TuIcono.citacion, estilo: EstiloIcono.mono, decorativo: true),
              label: const Text(botonPonerFecha),
            ),
          ),
          const SizedBox(height: Espacio.s),
          Text(notaDiaPrivado, style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
        ],
      );
    }
    final hora = ticket.hora;
    final hechas =
        [
          for (final c in widget.cosas)
            if (ticket.llevarHecho.contains(c.id)) c,
        ].length +
        ticket.llevarPropias.where((c) => c.hecho).length;
    final total = widget.cosas.length + ticket.llevarPropias.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CuentaAtras(perfil: perfil),
        const SizedBox(height: Espacio.s),
        Semantics(
          label: 'Tu cita: ${fechaLarga(fecha)}${hora == null ? '' : ', a las ${textoHora(hora)}'}',
          excludeSemantics: true,
          child: Text(
            '${fechaLarga(fecha)}${hora == null ? '' : ' · ${textoHora(hora)}'}',
            style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (dias != null && dias < 0) ...[
          const SizedBox(height: Espacio.xs),
          Text(textoDiaPasado, style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
        ],
        Wrap(
          spacing: Espacio.xs,
          children: [
            TextButton(onPressed: _elegirFecha, child: const Text(botonCambiarFecha)),
            if (hora == null)
              TextButton(onPressed: _elegirHora, child: const Text(botonPonerHora))
            else
              TextButton(onPressed: _elegirHora, child: const Text('Cambiar la hora')),
            TextButton(onPressed: _ticket.borrarDia, child: const Text(botonBorrarDia)),
          ],
        ),
        const SizedBox(height: Espacio.s),
        Semantics(
          header: true,
          child: Row(
            children: [
              IconoTuTurno(
                TuIcono.ticket,
                estilo: EstiloIcono.mono,
                size: Espacio.l - 2,
                color: esquema.primary,
                decorativo: true,
              ),
              const SizedBox(width: Espacio.s),
              Expanded(
                child: Text(
                  // Sin sugerencias ni cosas propias, sin el «0 de 0»: solo el título y el campo para añadir.
                  total == 0 ? textoQueLlevar : '$textoQueLlevar ($hechas de $total preparadas)',
                  style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Espacio.xs),
        for (final cosa in widget.cosas)
          _Casilla(
            texto: cosa.texto,
            hecho: ticket.llevarHecho.contains(cosa.id),
            alCambiar: (valor) => _ticket.marcarLlevar(cosa.id, valor),
          ),
        for (final cosa in ticket.llevarPropias)
          _Casilla(
            texto: cosa.texto,
            hecho: cosa.hecho,
            alCambiar: (valor) => _ticket.marcarLlevar(cosa.id, valor),
            alQuitar: () => _ticket.quitarLlevar(cosa.id),
          ),
        const SizedBox(height: Espacio.s),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nueva,
                maxLength: maxCaracteresCosaPropia,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _anadir(),
                decoration: const InputDecoration(
                  labelText: textoAnadirLlevar,
                  hintText: pistaAnadirLlevar,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: Espacio.s),
            IconButton.filledTonal(
              tooltip: 'Añadir a la lista',
              onPressed: _anadir,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: Espacio.s),
        Text(notaDiaPrivado, style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
      ],
    );
  }
}

/// La cuenta atrás grande: «Faltan 3 días», «Es mañana», «Es hoy».
class _CuentaAtras extends StatelessWidget {
  const _CuentaAtras({required this.perfil});

  final PerfilSituacion perfil;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final texto = cuentaAtras(perfil) ?? '';
    final dias = perfil.diasParaLaCita ?? 0;
    return Row(
      children: [
        Container(
          width: Espacio.xxl + Espacio.m,
          height: Espacio.xxl + Espacio.m,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ColoresMarca.amarillo,
            borderRadius: BorderRadius.circular(Radios.m),
            border: Border.all(color: ColoresMarca.azulNoche, width: 2),
          ),
          child: dias > 1
              ? ExcludeSemantics(
                  child: Text(
                    '$dias',
                    style: estiloCifras(tema.textTheme.headlineMedium)?.copyWith(color: ColoresMarca.azulNoche),
                  ),
                )
              : const IconoTuTurno(TuIcono.citacion, size: Espacio.xl + Espacio.xs, decorativo: true),
        ),
        const SizedBox(width: Espacio.m),
        Expanded(
          child: textoConCifras(texto, estilo: tema.textTheme.headlineSmall?.copyWith(color: esquema.onSurface)),
        ),
      ],
    );
  }
}

class _Casilla extends StatelessWidget {
  const _Casilla({required this.texto, required this.hecho, required this.alCambiar, this.alQuitar});

  final String texto;
  final bool hecho;
  final ValueChanged<bool> alCambiar;
  final VoidCallback? alQuitar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: CheckboxListTile(
            value: hecho,
            onChanged: (valor) {
              Hapticos.seleccion();
              alCambiar(valor ?? false);
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: false,
            title: Text(
              texto,
              style: tema.textTheme.bodyLarge?.copyWith(
                decoration: hecho ? TextDecoration.lineThrough : null,
                color: hecho ? tema.colorScheme.onSurfaceVariant : null,
              ),
            ),
          ),
        ),
        if (alQuitar != null)
          IconButton(
            tooltip: 'Quitar de la lista',
            onPressed: alQuitar,
            icon: const IconoTuTurno(TuIcono.cerrar, estilo: EstiloIcono.mono, decorativo: true),
          ),
      ],
    );
  }
}

/// El «modo día»: arriba de tu guía el día de la cita. Respira; lo que puedes pedir hoy; enseñar tus preguntas en
/// grande y lo que te queda por preparar. Tranquilo: sin cuenta atrás que agobie ni celebraciones.
class PanelModoDia extends ConsumerWidget {
  const PanelModoDia({super.key, required this.perfil, required this.pedirHoy, required this.alVerLista});

  final PerfilSituacion perfil;

  /// Lo que puedes pedir en la cita (del paso de la cita de tu camino).
  final List<String> pedirHoy;

  /// Baja a «Tu día» (la lista de lo que llevar).
  final VoidCallback alVerLista;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final hayPreguntas = ref.watch(misPreguntasProvider.select((l) => l.isNotEmpty));
    final hora = perfil.ticket.hora;
    const tinta = ColoresMarca.azulNoche;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ColoresMarca.amarillo,
        borderRadius: BorderRadius.circular(Radios.l),
        border: Border.all(color: tinta, width: 2),
        boxShadow: sombrasPapel(context),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Espacio.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const MascotaTut(size: 56, animada: false, expresion: ExpresionTut.animo, decorativo: true),
                const SizedBox(width: Espacio.s + Espacio.xs),
                Expanded(
                  child: Semantics(
                    header: true,
                    // Con un espacio duro antes del punto: con la letra grande, «· 12:30» no se queda suelto.
                    child: textoConCifras(
                      hora == null ? tituloModoDia : '$tituloModoDia\u00A0· ${textoHora(hora)}',
                      estilo: tema.textTheme.headlineSmall?.copyWith(color: tinta),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espacio.s),
            Text(textoModoDia, style: tema.textTheme.bodyLarge?.copyWith(color: tinta)),
            if (pedirHoy.isNotEmpty) ...[
              const SizedBox(height: Espacio.s + Espacio.xs),
              Text(
                textoParaHoy,
                style: tema.textTheme.titleSmall?.copyWith(color: tinta, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: Espacio.xs),
              for (final cosa in pedirHoy)
                Padding(
                  padding: const EdgeInsets.only(bottom: Espacio.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: IconoTuTurno(
                          TuIcono.manoAlzada,
                          size: 18,
                          estilo: EstiloIcono.mono,
                          color: tinta,
                          decorativo: true,
                        ),
                      ),
                      const SizedBox(width: Espacio.s),
                      Expanded(
                        child: Text(cosa, style: tema.textTheme.bodyLarge?.copyWith(color: tinta)),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: Espacio.s),
            Wrap(
              spacing: Espacio.s,
              runSpacing: Espacio.s,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: tinta, foregroundColor: ColoresMarca.amarillo),
                  onPressed: () =>
                      GoRouter.maybeOf(context)?.push(hayPreguntas ? '/mis-preguntas/ensenar' : '/mis-preguntas'),
                  icon: const IconoTuTurno(
                    TuIcono.pregunta,
                    estilo: EstiloIcono.mono,
                    color: ColoresMarca.amarillo,
                    decorativo: true,
                  ),
                  label: Text(hayPreguntas ? botonEnsenarPreguntas : 'Apuntar mis preguntas'),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tinta,
                    side: const BorderSide(color: tinta, width: 2),
                  ),
                  onPressed: alVerLista,
                  child: const Text('Ver lo que llevo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// La tarjeta de «Tu día» para la portada de Mi situación y para el inicio: solo sale si hay una cita en los próximos
/// 30 días (con [soloElDia], solo el mismo día: el «modo día»). Dice la fecha, sin cuenta atrás (producto: nada de
/// cuentas atrás que agobien). Toca para ir a tu guía. Sin fecha, no ocupa nada.
///
/// En el inicio: `const TarjetaModoDia(separacion: EdgeInsets.only(bottom: Espacio.l), soloElDia: true)`. Ni el papel
/// ni dónde es la cita: el inicio es lo primero que ve cualquiera que coja el móvil. [separacion] solo se aplica
/// cuando la tarjeta se ve.
class TarjetaModoDia extends ConsumerWidget {
  const TarjetaModoDia({
    super.key,
    this.separacion = EdgeInsets.zero,
    this.soloElDia = false,
    this.soloConPapel = false,
  });

  /// El espacio alrededor de la tarjeta cuando se ve (sin cita, no ocupa nada).
  final EdgeInsetsGeometry separacion;

  /// Solo el día de la cita (en el inicio).
  final bool soloElDia;

  /// Solo si el ticket dice papel. En la portada de Mi situación (/situacion/elegir), sin papel la tarjeta llevaría a
  /// la misma pantalla, una encima de otra.
  final bool soloConPapel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entrada = ref.watch(entradaProvider);
    final ticket = ref.watch(miTicketProvider);
    final fecha = ticket.fecha;
    if (fecha == null) return const SizedBox.shrink();
    final papel = PapelSituacion.deEntrada(entrada.rol);
    if (soloConPapel && papel == null) return const SizedBox.shrink();
    final perfil = PerfilSituacion(
      papel: papel ?? PapelSituacion.victima,
      entrada: entrada,
      ticket: ticket,
      hoy: ref.watch(relojProvider)(),
    );
    final dias = perfil.diasParaLaCita!;
    if (dias < 0 || dias > 30 || (soloElDia && dias != 0)) return const SizedBox.shrink();
    final hora = ticket.hora;
    final aLaHora = hora == null ? '' : ' · ${textoHora(hora)}';
    final ruta = papel?.ruta ?? '/situacion/elegir';
    final tarjeta = TicketTuTurno(
      etiqueta: dias == 0 ? 'Modo día' : cartelDia,
      titulo: switch (dias) {
        0 => tituloModoDia,
        1 => 'Mañana es tu día',
        _ => 'Tu cita',
      },
      descripcion: dias == 0
          ? 'Respira. ${hora == null ? '' : 'A las ${textoHora(hora)}. '}Toca para ver lo que puedes pedir hoy.'
          : '${fechaLarga(fecha)}$aLaHora. Toca para ver tu guía y lo que puedes llevar.',
      icono: const IconoTuTurno(TuIcono.citacion, size: 44, decorativo: true),
      talon: const MascotaTut(size: 52, animada: false, expresion: ExpresionTut.animo, decorativo: true),
      tamanoTalon: Espacio.xxl + Espacio.l,
      onTap: () => GoRouter.maybeOf(context)?.push(ruta),
    );
    return Padding(padding: separacion, child: tarjeta);
  }
}
