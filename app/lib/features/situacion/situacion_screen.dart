import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../core/entrada.dart';
import '../../core/mis_preguntas.dart';
import '../../core/progreso.dart' show relojProvider;
import '../../tema.dart';
import '../../widgets/iconos/iconos.dart';
import '../../widgets/justicia/expediente_caratula.dart';
import '../../widgets/modulos.dart';
import '../../widgets/movimiento/hapticos.dart';
import '../../widgets/movimiento/ticket.dart';
import '../../widgets/tuturno_scaffold.dart';
import '../pasos/pasos.dart';
import '../pregunta/widgets/tickets.dart' show TicketVertical;
import 'contenido.dart';
import 'mi_ticket.dart';
import 'personalizacion.dart';
import 'roles.dart';
import 'textos.dart';
import 'ticket_screen.dart';
import 'widgets/comunes.dart';
import 'widgets/derechos.dart';
import 'widgets/mi_dia.dart';
import 'widgets/notas.dart';
import 'widgets/preocupaciones.dart';
import 'widgets/saludo.dart';

// Mi situación (sección 4.4 y plan v2): tu guía, hecha a tu medida con tu ticket. Una carpeta con su carátula («Tu
// guía», nunca «tu expediente»: LO 5/2000, art. 16) que se abre una vez; dentro, un saludo que cambia con tu ticket,
// lo que cambia para ti por tu edad o tu proceso, tu camino paso a paso (con «Estás aquí», los personajes de «Vive el
// caso», lo que puedes pedir para apuntar, qué llevar, las palabras que oirás y «Pregúntaselo a TuTurno»), tus
// derechos, lo que te preocupa respondido con la ley, tu día y «Mis preguntas». Es parte de Pregunta: tranquila, sin
// puntos ni celebraciones (un solo momento animado, la carpeta). Nunca se pregunta qué pasó.

class SituacionScreen extends StatelessWidget {
  const SituacionScreen({super.key, required this.rol, this.rolId});

  /// Nulo si la dirección no es uno de los tres papeles del contrato (RolProceso).
  final RolProceso? rol;

  /// El papel tal y como viene en la dirección (/situacion/:rol), también si no es un [RolProceso]; por ejemplo,
  /// 'escuchado_familia'.
  final String? rolId;

  /// El papel de la pantalla, o null si hay que elegirlo.
  PapelSituacion? get papel {
    final rol = this.rol;
    return PapelSituacion.deId(rolId) ?? (rol == null ? null : PapelSituacion.deRolProceso(rol));
  }

  @override
  Widget build(BuildContext context) {
    final papel = this.papel;
    return TuTurnoScaffold(
      titulo: tituloMiSituacion,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: anchoMaximo),
          child: papel == null ? const _Portada() : _MiSituacion(key: ValueKey(papel), papel: papel),
        ),
      ),
    );
  }
}

/// Sin papel: la portada de Mi situación. Rellenar tu ticket (para que la guía sea tuya) o elegir el papel.
class _Portada extends ConsumerWidget {
  const _Portada();

  Future<void> _rellenar(BuildContext context) async {
    final papel = await abrirTuTicket(context);
    if (papel != null && context.mounted) context.pushReplacement(papel.ruta);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.m, Espacio.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sin papel en el ticket, la tarjeta llevaría a esta misma portada: aquí solo sale con papel.
          const TarjetaModoDia(separacion: EdgeInsets.only(bottom: Espacio.m), soloConPapel: true),
          // Lo más rápido primero: elegir tu papel. Debajo, hacerla a tu medida con tu ticket.
          const EncabezadoSelectorRol(),
          const SizedBox(height: Espacio.l),
          SelectorRol(onElegido: (papel) => context.pushReplacement(papel.ruta)),
          const SizedBox(height: Espacio.xl),
          TicketTuTurno(
            etiqueta: 'Para ti',
            titulo: tituloPortada,
            descripcion: textoPortada,
            icono: const IconoTuTurno(TuIcono.expediente, size: 44, decorativo: true),
            talon: const MascotaTut(size: 56, animada: false, decorativo: true),
            tamanoTalon: Espacio.xxl + Espacio.l,
          ),
          const SizedBox(height: Espacio.m),
          FilledButton.icon(
            onPressed: () => _rellenar(context),
            icon: const IconoTuTurno(TuIcono.ticket, estilo: EstiloIcono.mono, decorativo: true),
            label: Text(
              ref.watch(entradaProvider.select((e) => !e.vacia)) ||
                      ref.watch(miTicketProvider.select((t) => !t.sinRespuestas))
                  ? botonCambiarTicket
                  : botonRellenarTicket,
            ),
          ),
        ],
      ),
    );
  }
}

/// Las secciones de la guía, para el índice de carteles.
enum _Seccion { camino, derechos, preocupa, dia, preguntas }

class _MiSituacion extends ConsumerStatefulWidget {
  const _MiSituacion({super.key, required this.papel});

  final PapelSituacion papel;

  @override
  ConsumerState<_MiSituacion> createState() => _MiSituacionState();
}

class _MiSituacionState extends ConsumerState<_MiSituacion> {
  final _claves = {for (final s in _Seccion.values) s: GlobalKey(debugLabel: s.name)};

  PapelSituacion get _papel => widget.papel;

  void _ir(_Seccion seccion) {
    final destino = _claves[seccion]?.currentContext;
    if (destino == null) return;
    Hapticos.seleccion();
    Scrollable.ensureVisible(
      destino,
      duration: duracion(context, Duracion.media),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
  }

  Future<void> _cambiarTicket() async {
    final papel = await abrirTuTicket(context, papelSugerido: _papel);
    if (papel != null && papel != _papel && mounted) context.pushReplacement(papel.ruta);
  }

  /// Abre Pregunta con [duda] ya escrita (no se envía sola). Con «Me van a escuchar», sin situación: no es un papel
  /// de la API (sección 8).
  void _preguntar(String? duda) {
    final rol = _papel.rolProceso;
    context.push(
      Uri(
        path: '/pregunta',
        queryParameters: {
          if (rol != null) 'situacion': rol.name,
          if (duda != null && duda.trim().isNotEmpty) 'q': duda,
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final entrada = ref.watch(entradaProvider);
    final ticket = ref.watch(miTicketProvider);
    final hoy = ref.watch(relojProvider)();
    final contenido = ref.watch(contenidoSituacionProvider).value ?? const ContenidoSituacion();
    final apuntes = ref.watch(misPreguntasProvider.select((l) => l.length));
    final perfil = PerfilSituacion(papel: _papel, entrada: entrada, ticket: ticket, hoy: hoy);
    final notas = notasPara(contenido, perfil);
    final extras = extrasPara(contenido, perfil);
    final cosas = cosasDelDia(contenido, _papel);
    final respuestas = respuestasPara(contenido, perfil);
    final faseActual = perfil.fase;
    final otro = perfil.papelDelTicket;

    final secciones = <Widget>[
      ExpedienteCaratula(
        titulo: _papel.tituloCamino,
        tituloTapa: tituloMiSituacion,
        papel: _papel.papelCaratula,
        faseActual: faseActual == null ? null : Fase.values.indexOf(faseActual),
        clave: 'situacion-${_papel.id}',
        // Un sello quieto, impreso en la hoja: la guía está hecha para ti (no es un premio, no cae ni vibra). Solo si
        // es tu guía: mirando otro camino, no.
        sello: perfil.personalizado && !perfil.miraOtroPapel ? const SelloParaTi() : null,
        lecturaSello: 'Hecha para ti',
        child: Padding(
          padding: const EdgeInsets.only(top: Espacio.m),
          child: SaludoSituacion(
            perfil: perfil,
            alCambiarTicket: _cambiarTicket,
            alVerElMio: otro == null ? null : () => context.pushReplacement(otro.ruta),
            hayQueLlevar: cosas.isNotEmpty,
            hayRespuestas: respuestas.any((r) => r.puntos.isNotEmpty),
          ),
        ),
      ),
      if (perfil.esElDia)
        PanelModoDia(perfil: perfil, pedirHoy: _pedirHoy(extras), alVerLista: () => _ir(_Seccion.dia)),
      _Indice(alIr: _ir),
      _QueSignifica(papel: _papel),
      if (notas.isNotEmpty) NotasParaTi(notas: notas),
      // Tu camino.
      Column(
        key: _claves[_Seccion.camino],
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CartelSeccion(texto: cartelCamino, icono: TuIcono.miSituacion, detalle: _papel.nombre),
          const SizedBox(height: Espacio.s),
          Text(
            'Toca cada paso para ver qué pasa, quién estará, qué puedes pedir y qué llevar.',
            style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: Espacio.m),
          // La línea de pasos ya entra escalonada por su cuenta (features/pasos).
          LineaPasos(
            rol: _papel.id,
            encabezado: false,
            personalizacion: PersonalizacionLinea(
              extras: extras,
              estilo: ticket.estilo,
              conQuien: ticket.conQuienEnFrase,
              acompanantes: {for (final a in ticket.conQuien) a.valor},
              alPreguntar: (paso, duda) => _preguntar(duda),
            ),
          ),
        ],
      ),
      // Tus derechos.
      Column(
        key: _claves[_Seccion.derechos],
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CartelSeccion(texto: cartelDerechos, icono: TuIcono.carta),
          const SizedBox(height: Espacio.s),
          MazoDerechos(derechos: derechosPara(contenido, perfil), estilo: ticket.estilo),
        ],
      ),
      // Lo que te preocupa.
      Column(
        key: _claves[_Seccion.preocupa],
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CartelSeccion(texto: cartelPreocupa, icono: TuIcono.personaConfianza),
          const SizedBox(height: Espacio.s),
          LoQueTePreocupa(
            elegidas: ticket.preocupaciones,
            respuestas: respuestas,
            alAlternar: ref.read(miTicketProvider.notifier).alternarPreocupacion,
          ),
        ],
      ),
      // Tu día.
      Column(
        key: _claves[_Seccion.dia],
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CartelSeccion(texto: cartelDia, icono: TuIcono.citacion),
          const SizedBox(height: Espacio.s),
          TuDia(perfil: perfil, cosas: cosas),
        ],
      ),
      // Mis preguntas.
      Column(
        key: _claves[_Seccion.preguntas],
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CartelSeccion(texto: cartelMisPreguntas, icono: TuIcono.pregunta),
          const SizedBox(height: Espacio.s),
          Text(
            'Lo que apuntas aquí se guarda solo en este móvil. Enséñaselo a las personas que llevan tu caso.',
            style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: Espacio.s),
          OutlinedButton.icon(
            onPressed: () => context.push('/mis-preguntas'),
            icon: const IconoTuTurno(TuIcono.pregunta, estilo: EstiloIcono.mono, decorativo: true),
            label: Text('Mis preguntas ($apuntes)'),
          ),
        ],
      ),
      FilledButton.icon(
        onPressed: () {
          Hapticos.toque();
          _preguntar(null);
        },
        icon: const IconoTuTurno(TuIcono.pregunta, estilo: EstiloIcono.mono, decorativo: true),
        label: Text(_papel.textoPregunta),
      ),
      TextButton.icon(
        onPressed: () => mostrarSelectorRol(context, reemplazar: true),
        icon: const Icon(Icons.swap_horiz_rounded),
        label: const Text(botonCambiarPapel),
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconoTuTurno(TuIcono.candado, size: Espacio.l - Espacio.xs, decorativo: true),
          const SizedBox(width: Espacio.s),
          Expanded(
            child: Text(notaNoPreguntamos, style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
          ),
        ],
      ),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.m, Espacio.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, seccion) in secciones.indexed) ...[
            if (i > 0) SizedBox(height: i <= 2 ? Espacio.m : Espacio.l),
            seccion,
          ],
        ],
      ),
    );
  }

  /// Lo que puedes pedir el día de la cita: lo del primer paso con cita de tu camino (o del primero de «Durante»). Sin
  /// los pasos que no son para tu edad (al investigado de 13, la audiencia de la LO 5/2000 no se le aplica).
  List<String> _pedirHoy(Map<String, ExtrasPaso> extras) {
    final itinerario = ref.watch(itinerarioProvider(_papel.id)).value;
    if (itinerario == null) return const [];
    final pasos = [
      for (final p in itinerario.pasos)
        if (extras[p.id]?.noEsParaTi == null) p,
    ];
    final cita =
        pasos.where((p) => extras[p.id]?.esCita ?? false).firstOrNull ??
        pasos.where((p) => p.fase == Fase.durante).firstOrNull;
    return cita == null ? const [] : cita.quePuedesPedir.take(3).toList();
  }
}

/// El índice de la guía: los carteles de sus secciones, para bajar directamente a cada una.
class _Indice extends StatelessWidget {
  const _Indice({required this.alIr});

  final ValueChanged<_Seccion> alIr;

  static const _textos = {
    _Seccion.camino: (cartelCamino, TuIcono.miSituacion),
    _Seccion.derechos: (cartelDerechos, TuIcono.carta),
    _Seccion.preocupa: (cartelPreocupa, TuIcono.personaConfianza),
    _Seccion.dia: (cartelDia, TuIcono.citacion),
    _Seccion.preguntas: (cartelMisPreguntas, TuIcono.pregunta),
  };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Semantics(
      container: true,
      label: 'Índice de tu guía',
      child: Wrap(
        spacing: Espacio.s,
        runSpacing: Espacio.xs,
        children: [
          for (final MapEntry(key: seccion, value: (texto, icono)) in _textos.entries)
            ActionChip(
              avatar: IconoTuTurno(icono, estilo: EstiloIcono.mono, color: esquema.primary, decorativo: true),
              label: Text(texto),
              labelStyle: tema.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: esquema.onSurface),
              materialTapTargetSize: MaterialTapTargetSize.padded,
              backgroundColor: esquema.surfaceContainerLowest,
              side: BorderSide(color: esquema.outlineVariant),
              tooltip: 'Ir a «$texto»',
              onPressed: () => alIr(seccion),
            ),
        ],
      ),
    );
  }
}

/// «Qué significa» como ticket: la explicación arriba y, en el talón, una frase para dar tranquilidad.
class _QueSignifica extends StatelessWidget {
  const _QueSignifica({required this.papel});

  final PapelSituacion papel;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final colores = context.colores;
    // El talón es una nota amarilla: suave en claro y el amarillo de la marca en oscuro (con tinta azul noche).
    final claro = tema.brightness == Brightness.light;
    final tintaTalon = claro ? esquema.onTertiaryContainer : ColoresMarca.azulNoche;
    return TicketVertical(
      color: colores.ticket,
      colorTalon: claro ? esquema.tertiaryContainer : ColoresMarca.amarillo,
      colorPerforado: esquema.outlineVariant,
      borde: BorderSide(color: esquema.outlineVariant),
      sombras: sombrasTicket(context, elevacion: 0.8),
      radio: Radios.l,
      cuerpo: Padding(
        padding: const EdgeInsets.fromLTRB(
          Espacio.l - Espacio.xs,
          Espacio.l - Espacio.xs,
          Espacio.l - Espacio.xs,
          Espacio.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: Espacio.s,
              runSpacing: Espacio.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Qué significa',
                    style: tema.textTheme.headlineSmall?.copyWith(color: colores.tintaTicket),
                  ),
                ),
                Pegatina(texto: papel.nombre, icono: papel.tuIcono),
              ],
            ),
            const SizedBox(height: Espacio.s),
            Text(
              papel.explicacion,
              style: tema.textTheme.bodyLarge?.copyWith(color: colores.tintaTicket, height: 1.45),
            ),
          ],
        ),
      ),
      talon: Padding(
        padding: const EdgeInsets.fromLTRB(
          Espacio.l - Espacio.xs,
          Espacio.m,
          Espacio.l - Espacio.xs,
          Espacio.m + Espacio.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IconoTuTurno(TuIcono.personaConfianza, size: Espacio.xl, decorativo: true),
            const SizedBox(width: Espacio.s + Espacio.xs),
            Expanded(
              child: Text(
                papel.tranquilidad,
                style: tema.textTheme.bodyLarge?.copyWith(color: tintaTalon, fontWeight: FontWeight.w700, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El sello quieto de la carátula de tu guía: «PARA TI» en un sello de goma rectangular, en la letra del texto y a
/// 22 px, para que se lea (el texto circular de un sello redondo de este tamaño saldría a 6 px). No cae, no vibra y no
/// es un logro: es parte del papel. El lector de pantalla lo dice con la hoja («Hecha para ti»).
class SelloParaTi extends StatelessWidget {
  const SelloParaTi({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final tinta = context.colores.sello;
    final letras = tema.textTheme.titleLarge?.copyWith(
      color: tinta,
      fontWeight: FontWeight.w800,
      fontSize: 22,
      height: 1,
      letterSpacing: 0.5,
    );
    return ExcludeSemantics(
      // Cabe en la esquina de la hoja también con la letra grande.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: tinta, width: 3),
            borderRadius: BorderRadius.circular(Radios.s),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Espacio.xs + 2, vertical: Espacio.xs + 1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('PARA', style: letras),
                Text('TI', style: letras),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
