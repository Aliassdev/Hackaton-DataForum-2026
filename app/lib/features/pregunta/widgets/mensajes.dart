import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/models.dart';
import '../../../core/content_models.dart';
import '../../../core/providers.dart';
import '../../../core/recursos_ayuda.dart';
import '../../../core/seguridad.dart';
import '../../../core/texto.dart';
import '../../../tema.dart';
import '../../../widgets/fuente_chip.dart';
import '../../../widgets/iconos/iconos.dart';
import '../../../widgets/movimiento/hapticos.dart';
import '../../../widgets/movimiento/ticket.dart';
import '../../../widgets/texto_con_terminos.dart';
import '../chat_controller.dart';
import '../textos.dart';
import 'tickets.dart';

// Mensajes de «Pregunta». Tranquilos y claros: aquí nada se gamifica. Responde Tut, la mascota (siempre seria o
// pensando, nunca de fiesta); cada respuesta es un ticket con las fuentes en el talón, y la tarjeta de crisis es roja e
// inconfundible.

/// Ancho máximo de una burbuja: cómodo de leer en móvil y sin líneas larguísimas en pantallas grandes.
double anchoBurbuja(BuildContext context, {double fraccion = 0.84}) =>
    math.min(MediaQuery.sizeOf(context).width * fraccion, 560);

/// Lado del avatar de Tut y hueco hasta la burbuja (las sugerencias se alinean con la burbuja).
const ladoAvatar = 44.0;
const _huecoAvatar = Espacio.s;

/// Entrada suave (aparece y sube un poco). Decide si se anima al crearse; sin animación si el sistema lo pide.
class Aparecer extends StatefulWidget {
  const Aparecer({super.key, required this.child, this.animar = true, this.retraso = Duration.zero});

  final Widget child;
  final bool animar;
  final Duration retraso;

  @override
  State<Aparecer> createState() => _AparecerState();
}

class _AparecerState extends State<Aparecer> {
  late final bool _animar = widget.animar;

  @override
  Widget build(BuildContext context) {
    final base = duracion(context, Duracion.media);
    if (!_animar || base == Duration.zero) return widget.child;
    final total = base + widget.retraso;
    final inicio = widget.retraso.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(inicio, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * Espacio.m), child: child),
      ),
      child: widget.child,
    );
  }
}

/// Avatar del asistente: Tut, quieto (en Pregunta no hay gestos ni saltos). [expresion] es neutral en las
/// respuestas (también en las de crisis y de hechos) y «pensando» mientras llega la respuesta. Es decorativo: al lado
/// siempre pone «TuTurno · IA».
class AvatarIA extends StatelessWidget {
  const AvatarIA({super.key, this.tamano = ladoAvatar, this.expresion = ExpresionTut.neutral});

  final double tamano;
  final ExpresionTut expresion;

  @override
  Widget build(BuildContext context) =>
      MascotaTut(expresion: expresion, size: tamano, animada: false, decorativo: true);
}

/// Fila del asistente: Tut, «TuTurno · IA» y el contenido.
class FilaAsistente extends StatelessWidget {
  const FilaAsistente({
    super.key,
    required this.child,
    this.etiqueta = 'TuTurno · IA',
    this.expresion = ExpresionTut.neutral,
  });

  final Widget child;
  final String etiqueta;
  final ExpresionTut expresion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: anchoBurbuja(context, fraccion: 0.94)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarIA(expresion: expresion),
            const SizedBox(width: _huecoAvatar),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: Espacio.xs, top: Espacio.s, bottom: Espacio.xs),
                    child: Text(
                      etiqueta,
                      style: tema.textTheme.labelMedium?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Forma de las burbujas: la esquina de quien habla es más pequeña.
BorderRadius formaBurbuja({required bool usuario}) => BorderRadiusDirectional.only(
  topStart: Radius.circular(usuario ? Radios.m : Radios.s),
  topEnd: Radius.circular(usuario ? Radios.s : Radios.m),
  bottomStart: const Radius.circular(Radios.m),
  bottomEnd: const Radius.circular(Radios.m),
).resolve(TextDirection.ltr);

/// La pregunta del usuario: papel del color principal (azul en claro, amarillo en oscuro) con su tinta.
class BurbujaUsuario extends StatelessWidget {
  const BurbujaUsuario({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: anchoBurbuja(context, fraccion: 0.8)),
        child: Semantics(
          label: 'Tu pregunta',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Espacio.m, vertical: Espacio.s + Espacio.xs),
            decoration: BoxDecoration(
              color: esquema.primary,
              borderRadius: formaBurbuja(usuario: true),
              boxShadow: sombrasPapel(context, elevacion: 0.6),
            ),
            child: Text(texto, style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onPrimary, height: 1.4)),
          ),
        ),
      ),
    );
  }
}

/// Antes de la primera pregunta: un ticket de turno con quién responde (una IA) y qué hace. Tut espera en el talón,
/// quieto. Con la letra muy grande el talón pasa abajo, para dejarle al texto todo el ancho.
class BurbujaPresentacion extends StatelessWidget {
  const BurbujaPresentacion({super.key});

  /// A partir de este tamaño de letra, el talón va abajo.
  static const _letraGrande = 1.2;

  @override
  Widget build(BuildContext context) {
    final grande = MediaQuery.textScalerOf(context).scale(1) > _letraGrande;
    return TicketTuTurno(
      etiqueta: 'Tu turno de preguntar',
      titulo: '¿Qué quieres saber?',
      descripcion: textoPresentacion,
      fondoTalon: ColoresMarca.azul,
      ladoTalon: grande ? LadoTalon.abajo : LadoTalon.derecha,
      tamanoTalon: grande ? 88 : 104,
      talon: MascotaTut(size: grande ? 72 : 88, animada: false, pegatina: true, decorativo: true),
    );
  }
}

/// Abre el Glosario desde una respuesta. Con `desde=pregunta`, sus botones «Pregúntalo» vuelven a esta
/// conversación en vez de abrir otra vacía encima.
void abrirTerminoDesdePregunta(BuildContext context, String termino) =>
    context.push(Uri(path: '/glosario', queryParameters: {'q': termino, 'desde': 'pregunta'}).toString());

/// Los términos de la respuesta que están en el Glosario: solo se subraya lo que se puede abrir.
List<String> terminosEnGlosario(List<String> terminos, List<EntradaGlosario> glosario) {
  final disponibles = {for (final e in glosario) normalizar(e.termino.trim())};
  return [
    for (final t in terminos)
      if (disponibles.contains(normalizar(t.trim()))) t,
  ];
}

/// Respuesta del asistente: tarjeta de ayuda si es crisis y un ticket con el texto (términos subrayados) arriba y, en
/// el talón, las fuentes y el botón para escucharla. Debajo, las sugerencias.
class BurbujaAsistente extends ConsumerWidget {
  const BurbujaAsistente({
    super.key,
    required this.mensaje,
    required this.hablando,
    required this.onLeer,
    required this.onSugerencia,
    this.mostrarSugerencias = false,
    this.revelar = false,
  });

  final MensajeChat mensaje;
  final bool hablando;
  final VoidCallback onLeer;
  final ValueChanged<String> onSugerencia;

  /// Solo en la última respuesta.
  final bool mostrarSugerencias;

  /// Recién llegada: si es de crisis, la lista se desplaza hasta la tarjeta de Ayuda.
  final bool revelar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final colores = context.colores;
    final respuesta = mensaje.respuesta!;
    final sugerencias = respuesta.sugerencias.isNotEmpty
        ? respuesta.sugerencias.take(3).toList()
        : sugerenciasPorTipo[respuesta.tipo] ?? const <String>[];
    final terminos = terminosEnGlosario(
      respuesta.terminos,
      ref.watch(glosarioProvider).value ?? const <EntradaGlosario>[],
    );

    final cuerpo = Padding(
      padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.m, Espacio.m, Espacio.m - Espacio.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextoConTerminos(
            texto: respuesta.respuesta,
            terminos: terminos,
            fuentes: respuesta.fuentes,
            style: tema.textTheme.bodyLarge?.copyWith(color: colores.tintaTicket, height: 1.45),
            onTermino: (termino) => abrirTerminoDesdePregunta(context, termino),
          ),
          if (respuesta.tipo == TipoRespuesta.hechos) ...[
            const SizedBox(height: Espacio.m),
            OutlinedButton.icon(
              onPressed: () => context.push('/ayuda'),
              icon: const IconoTuTurno(TuIcono.ayuda, estilo: EstiloIcono.mono, decorativo: true),
              label: const Text('Ver teléfonos de ayuda'),
            ),
          ],
        ],
      ),
    );

    // El talón es la parte «oficial» del ticket: de dónde sale la respuesta y el botón para oírla.
    final talon = Padding(
      padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.s, Espacio.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (respuesta.fuentes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Espacio.xs),
              child: Row(
                children: [
                  IconoTuTurno(TuIcono.fuente, size: Espacio.m + Espacio.xs, decorativo: true),
                  const SizedBox(width: Espacio.s),
                  Text(
                    respuesta.fuentes.length == 1 ? 'Fuente' : 'Fuentes',
                    style: tema.textTheme.labelLarge?.copyWith(
                      color: esquema.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          Wrap(
            spacing: Espacio.s,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < respuesta.fuentes.length; i++)
                FuenteChip(fuente: respuesta.fuentes[i], numero: i + 1),
              BotonLeer(hablando: hablando, onPressed: onLeer),
            ],
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En crisis, la tarjeta de Ayuda va primero y a todo el ancho: es lo más importante de la pantalla.
        if (respuesta.tipo == TipoRespuesta.crisis) ...[
          TarjetaCrisis(key: const Key('tarjeta-crisis'), revelar: revelar),
          const SizedBox(height: Espacio.m),
        ],
        FilaAsistente(
          child: TicketVertical(
            key: const Key('ticket-respuesta'),
            color: colores.ticket,
            colorTalon: esquema.surfaceContainer,
            colorPerforado: esquema.outlineVariant,
            borde: BorderSide(color: esquema.outlineVariant),
            sombras: sombrasTicket(context, elevacion: 0.6),
            cuerpo: cuerpo,
            talon: talon,
          ),
        ),
        if (mostrarSugerencias && sugerencias.isNotEmpty) ...[
          const SizedBox(height: Espacio.m),
          Sugerencias(sugerencias: sugerencias, onSugerencia: onSugerencia),
        ],
      ],
    );
  }
}

/// Altavoz de una respuesta: la vuelve a leer o la para.
class BotonLeer extends StatelessWidget {
  const BotonLeer({super.key, required this.hablando, required this.onPressed});

  final bool hablando;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Tooltip(
      message: hablando ? 'Parar la voz' : 'Escuchar la respuesta',
      excludeFromSemantics: true,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: esquema.primary,
          padding: const EdgeInsets.symmetric(horizontal: Espacio.s),
        ),
        onPressed: () {
          Hapticos.seleccion();
          onPressed();
        },
        icon: AnimatedSwitcher(
          duration: duracion(context, Duracion.corta),
          child: hablando
              ? const Icon(Icons.stop_circle_rounded, key: ValueKey(true))
              : const IconoTuTurno(
                  TuIcono.altavoz,
                  key: ValueKey(false),
                  estilo: EstiloIcono.mono,
                  size: 20,
                  decorativo: true,
                ),
        ),
        label: Text(hablando ? 'Parar' : 'Escuchar'),
      ),
    );
  }
}

/// Preguntas sugeridas: tickets pequeños que, al tocarlos, se preguntan directamente.
class Sugerencias extends StatelessWidget {
  const Sugerencias({super.key, required this.sugerencias, required this.onSugerencia});

  final List<String> sugerencias;
  final ValueChanged<String> onSugerencia;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: ladoAvatar + _huecoAvatar),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Puedes seguir con…', style: tema.textTheme.labelLarge?.copyWith(color: esquema.onSurfaceVariant)),
          const SizedBox(height: Espacio.s),
          Wrap(
            spacing: Espacio.s,
            runSpacing: Espacio.s,
            children: [
              for (var i = 0; i < sugerencias.length; i++)
                Aparecer(
                  retraso: Duracion.corta * i,
                  child: TicketPregunta(
                    texto: sugerencias[i],
                    compacto: true,
                    onTap: () => onSugerencia(sugerencias[i]),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de Ayuda que sale encima de una respuesta de tipo crisis. Roja, a todo el ancho y sin adornos: tiene que
/// ser lo primero que se ve.
///
/// Con [revelar], al aparecer la lista se desplaza hasta ella: la lista va al revés y, sin esto, lo que se veía
/// era el final de la respuesta y la tarjeta quedaba por arriba, fuera de la pantalla.
class TarjetaCrisis extends StatefulWidget {
  const TarjetaCrisis({super.key, this.revelar = false});

  final bool revelar;

  static final anar = recursosAyuda.firstWhere((r) => r.telefono == '900 20 20 10');
  static final emergencias = recursosAyuda.firstWhere((r) => r.telefono == '112');

  @override
  State<TarjetaCrisis> createState() => _TarjetaCrisisState();
}

class _TarjetaCrisisState extends State<TarjetaCrisis> {
  final _botonAnar = GlobalKey();
  Timer? _espera;

  @override
  void initState() {
    super.initState();
    if (widget.revelar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Se espera a que termine casi del todo la entrada (sube un poco al aparecer): si no, la posición
        // calculada quedaría desplazada.
        final entrada = duracion(context, Duracion.media) * 0.9;
        _espera = Timer(entrada, _revelar);
      });
    }
  }

  @override
  void dispose() {
    _espera?.cancel();
    super.dispose();
  }

  Future<void> _revelar() async {
    if (!mounted || Scrollable.maybeOf(context) == null) return;
    final tiempo = duracion(context, Duracion.media);
    // En la lista invertida, 1.0 deja el borde de arriba de la tarjeta arriba de la zona visible.
    await Scrollable.ensureVisible(context, alignment: 1.0, duration: tiempo, curve: Curves.easeOutCubic);
    // Si la tarjeta no cabe entera (letra muy grande), lo importante es que se vea el botón de llamar a ANAR.
    final boton = _botonAnar.currentContext;
    if (!mounted || boton == null || !boton.mounted) return;
    final cajaBoton = boton.findRenderObject();
    final cajaLista = Scrollable.of(context).context.findRenderObject();
    if (cajaBoton is! RenderBox || cajaLista is! RenderBox) return;
    final abajoBoton = cajaBoton.localToGlobal(Offset(0, cajaBoton.size.height)).dy;
    final abajoLista = cajaLista.localToGlobal(Offset(0, cajaLista.size.height)).dy;
    if (abajoBoton > abajoLista && boton.mounted) {
      // 0.0 en la lista invertida: el borde de abajo del botón, abajo de la zona visible.
      await Scrollable.ensureVisible(boton, alignment: 0.0, duration: tiempo, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final anar = TarjetaCrisis.anar;
    final emergencias = TarjetaCrisis.emergencias;
    final tema = Theme.of(context);
    final rojo = context.colores.ayuda;
    // El margen de arriba deja aire bajo la barra cuando la lista se desplaza hasta la tarjeta.
    return Padding(
      padding: const EdgeInsets.only(top: Espacio.s),
      // Compacta a propósito: con letra grande en un móvil pequeño, el botón de ANAR tiene que verse sin desplazar
      // (también la usa la corrección de «Dilo» en Aprende).
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Espacio.m),
        decoration: BoxDecoration(
          color: rojo,
          borderRadius: BorderRadius.circular(Radios.l),
          boxShadow: sombrasPapel(context, elevacion: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconoTuTurno(
                  TuIcono.ayuda,
                  estilo: EstiloIcono.mono,
                  color: Colors.white,
                  size: Espacio.l,
                  decorativo: true,
                ),
                const SizedBox(width: Espacio.s),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Pide ayuda ahora',
                      style: tema.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espacio.s),
            Text(
              'No estás solo ni sola. Llamar es gratis y te atienden a cualquier hora.',
              style: tema.textTheme.bodyLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: Espacio.m),
            _BotonLlamar(
              key: _botonAnar,
              recurso: anar,
              texto: 'Llamar a ANAR · ${anar.telefonoVisible}',
              principal: true,
            ),
            const SizedBox(height: Espacio.s),
            _BotonLlamar(recurso: emergencias, texto: 'Emergencias · ${emergencias.telefonoVisible}'),
            const SizedBox(height: Espacio.xs),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () => context.push('/ayuda'),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Más teléfonos de ayuda'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonLlamar extends StatelessWidget {
  const _BotonLlamar({super.key, required this.recurso, required this.texto, this.principal = false});

  final RecursoAyuda recurso;
  final String texto;
  final bool principal;

  Future<void> _llamar(BuildContext context) async {
    Hapticos.toque();
    final mensajero = ScaffoldMessenger.maybeOf(context);
    final abierto = await abrirRecurso(recurso);
    if (!abierto) {
      mensajero?.showSnackBar(SnackBar(content: Text('No he podido abrir el teléfono. Marca el ${recurso.telefono}.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rojo = context.colores.ayuda;
    final estilo = principal
        ? FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: rojo)
        : OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white, width: 2),
          );
    // El icono toma el color del botón (rojo sobre blanco, blanco sobre rojo).
    const icono = IconoTuTurno(TuIcono.telefono, estilo: EstiloIcono.mono, decorativo: true);
    final etiqueta = Text(texto);
    return SizedBox(
      width: double.infinity,
      child: principal
          ? FilledButton.icon(style: estilo, onPressed: () => _llamar(context), icon: icono, label: etiqueta)
          : OutlinedButton.icon(style: estilo, onPressed: () => _llamar(context), icon: icono, label: etiqueta),
    );
  }
}

/// Error de la API con su mensaje (sección 8.4), «Reintentar» y acceso a los teléfonos de ayuda.
///
/// Sin conexión la crisis no se puede detectar en el backend: si la pregunta suena a peligro, se enseña igualmente
/// la tarjeta de Ayuda (sección 10.2, «ante la duda, ofrecer ayuda»). Llamar funciona sin datos.
class BurbujaError extends StatelessWidget {
  const BurbujaError({
    super.key,
    required this.mensaje,
    required this.onReintentar,
    this.activo = true,
    this.revelar = false,
  });

  final MensajeChat mensaje;
  final VoidCallback onReintentar;
  final bool activo;
  final bool revelar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final peligro = pareceCrisis(mensaje.preguntaOriginal ?? '');
    final burbuja = Container(
      padding: const EdgeInsets.all(Espacio.m),
      decoration: BoxDecoration(
        color: esquema.errorContainer,
        borderRadius: formaBurbuja(usuario: false),
        boxShadow: sombrasPapel(context, elevacion: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_off_rounded, color: esquema.onErrorContainer),
              const SizedBox(width: Espacio.s),
              Expanded(
                child: Text(
                  mensaje.texto,
                  style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onErrorContainer, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: Espacio.m),
          Wrap(
            spacing: Espacio.s,
            runSpacing: Espacio.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: esquema.error, foregroundColor: esquema.onError),
                onPressed: activo
                    ? () {
                        Hapticos.toque();
                        onReintentar();
                      }
                    : null,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: esquema.onErrorContainer),
                onPressed: () => context.push('/ayuda'),
                icon: const IconoTuTurno(TuIcono.ayuda, estilo: EstiloIcono.mono, decorativo: true),
                label: const Text('Teléfonos de ayuda'),
              ),
            ],
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (peligro) ...[
          TarjetaCrisis(key: const Key('tarjeta-crisis-sin-conexion'), revelar: revelar),
          const SizedBox(height: Espacio.m),
        ],
        FilaAsistente(child: burbuja),
      ],
    );
  }
}

/// Mientras llega la respuesta: Tut pensando, tres puntos que botan y lo que está haciendo.
class IndicadorEscribiendo extends StatefulWidget {
  const IndicadorEscribiendo({super.key});

  @override
  State<IndicadorEscribiendo> createState() => _IndicadorEscribiendoState();
}

class _IndicadorEscribiendoState extends State<IndicadorEscribiendo> with SingleTickerProviderStateMixin {
  late final _puntos = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  Timer? _temporizador;
  var _paso = 0;

  @override
  void initState() {
    super.initState();
    _temporizador = Timer.periodic(const Duration(milliseconds: 1800), (t) {
      if (_paso >= pasosEsperando.length - 1) {
        t.cancel();
        return;
      }
      setState(() => _paso++);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (duracion(context, Duracion.media) == Duration.zero) {
      _puntos.stop();
    } else if (!_puntos.isAnimating) {
      _puntos.repeat();
    }
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    _puntos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Semantics(
      liveRegion: true,
      label: 'TuTurno está preparando la respuesta',
      child: ExcludeSemantics(
        child: FilaAsistente(
          expresion: ExpresionTut.pensando,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Espacio.m, vertical: Espacio.s + Espacio.xs),
            decoration: BoxDecoration(
              color: context.colores.ticket,
              border: Border.all(color: esquema.outlineVariant),
              borderRadius: formaBurbuja(usuario: false),
              boxShadow: sombrasPapel(context, elevacion: 0.6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _puntos,
                  builder: (context, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Transform.translate(
                          offset: Offset(0, -Espacio.xs * _bote(_puntos.value, i)),
                          child: Container(
                            width: Espacio.s,
                            height: Espacio.s,
                            margin: const EdgeInsets.symmetric(horizontal: Espacio.xs / 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color.lerp(
                                esquema.onSurfaceVariant.withValues(alpha: 0.45),
                                esquema.primary,
                                _bote(_puntos.value, i),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: Espacio.m),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: duracion(context, Duracion.media),
                    child: Text(
                      '${pasosEsperando[_paso]}…',
                      key: ValueKey(_paso),
                      style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 0-1: lo alto que está cada punto en este momento.
  static double _bote(double t, int i) {
    final fase = (t - i * 0.18) % 1.0;
    return fase < 0.5 ? math.sin(fase * 2 * math.pi).clamp(0.0, 1.0) : 0.0;
  }
}
