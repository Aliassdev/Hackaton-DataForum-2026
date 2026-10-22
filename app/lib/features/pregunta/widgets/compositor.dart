import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart';
import '../../../core/providers.dart';
import '../../../core/voz/stt.dart';
import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../../../widgets/movimiento/hapticos.dart';
import '../chat_controller.dart';
import '../textos.dart';
import 'estilo.dart';

typedef ProveedorChat = NotifierProvider<ChatNotifier, EstadoChat>;

/// Parte de abajo de «Pregunta»: situación, avisos de voz, campo de texto y micrófono.
class Compositor extends ConsumerWidget {
  const Compositor({
    super.key,
    required this.proveedor,
    required this.texto,
    required this.foco,
    required this.desdeVoz,
    required this.onEnviar,
    required this.onMicro,
    required this.onBorrar,
    this.compacto = false,
  });

  final ProveedorChat proveedor;
  final TextEditingController texto;
  final FocusNode foco;

  /// El campo tiene lo que se ha dictado y nadie lo ha tocado todavía.
  final ValueListenable<bool> desdeVoz;

  /// Con el teclado abierto o poca altura: micrófono pequeño junto al campo y sin la fila del micrófono grande
  /// («Voz» y «Nueva» pasan al menú de la barra de arriba). Lo decide la pantalla, que sí ve el teclado.
  final bool compacto;
  final VoidCallback onEnviar;
  final VoidCallback onMicro;
  final VoidCallback onBorrar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:voz, :esperando, :situacion, :problema, :hayMensajes) = ref.watch(
      proveedor.select(
        (s) => (
          voz: s.voz,
          esperando: s.esperando,
          situacion: s.situacion,
          problema: s.problemaVoz,
          hayMensajes: s.mensajes.isNotEmpty,
        ),
      ),
    );
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final escuchando = voz != EstadoVoz.inactivo;
    final estadoMicro = esperando
        ? EstadoMicro.desactivado
        : switch (voz) {
            EstadoVoz.preparando => EstadoMicro.preparando,
            EstadoVoz.escuchando => EstadoMicro.escuchando,
            EstadoVoz.inactivo => problema == ProblemaVoz.sinPermiso ? EstadoMicro.noDisponible : EstadoMicro.inactivo,
          };
    final rapida = duracion(context, Duracion.media);
    final microPequeno = BotonMicroPequeno(
      key: const Key('boton-micro-pequeno'),
      estado: estadoMicro,
      onPressed: onMicro,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radios.l)),
        border: Border(top: BorderSide(color: esquema.outlineVariant)),
        boxShadow: [
          BoxShadow(color: sombraPapelDe(context), blurRadius: Espacio.l, offset: const Offset(0, -Espacio.xs)),
        ],
      ),
      child: AnimatedSize(
        duration: duracionTamano(context, Duracion.media),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s + Espacio.xs, Espacio.m, Espacio.s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (situacion != null) ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _ChipSituacion(rol: situacion, onQuitar: () => ref.read(proveedor.notifier).quitarSituacion()),
                ),
                const SizedBox(height: Espacio.s),
              ],
              if (problema != null) ...[
                AvisoVoz(
                  key: const Key('aviso-voz'),
                  problema: problema,
                  onCerrar: () => ref.read(proveedor.notifier).cerrarAvisoVoz(),
                ),
                const SizedBox(height: Espacio.s),
              ],
              AnimatedSwitcher(
                duration: rapida,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animacion) => FadeTransition(
                  opacity: animacion,
                  child: SizeTransition(sizeFactor: animacion, alignment: Alignment.topCenter, child: child),
                ),
                child: escuchando
                    ? (compacto
                          // En compacto, el micrófono pequeño (que ahora es «parar») sigue junto a la transcripción.
                          ? Row(
                              key: const ValueKey('panel-compacto'),
                              children: [
                                microPequeno,
                                const SizedBox(width: Espacio.s),
                                Expanded(child: PanelEscucha(proveedor: proveedor)),
                              ],
                            )
                          : PanelEscucha(key: const ValueKey('panel'), proveedor: proveedor))
                    : Column(
                        key: const ValueKey('campo'),
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (compacto) ...[microPequeno, const SizedBox(width: Espacio.s)],
                              // Con clave: al entrar o salir del modo compacto el campo no se vuelve a crear, así
                              // no pierde el foco (si lo perdiera, el teclado se cerraría y volvería a cambiar).
                              Expanded(
                                key: const ValueKey('fila-campo'),
                                child: _CampoPregunta(texto: texto, foco: foco, onEnviar: onEnviar),
                              ),
                              const SizedBox(width: Espacio.s),
                              _BotonEnviar(texto: texto, activo: !esperando, onEnviar: onEnviar),
                            ],
                          ),
                          _AvisoRevisar(desdeVoz: desdeVoz),
                        ],
                      ),
              ),
              if (!compacto) ...[
                const SizedBox(height: Espacio.xs),
                Row(
                  children: [
                    const Expanded(child: Center(child: _BotonVozAutomatica())),
                    BotonMicro(estado: estadoMicro, proveedor: proveedor, onPressed: onMicro),
                    Expanded(
                      child: Center(
                        child: _BotonLateral(
                          icono: const Icon(Icons.restart_alt_rounded),
                          texto: 'Nueva',
                          tooltip: 'Empezar una conversación nueva',
                          onPressed: hayMensajes || escuchando ? onBorrar : null,
                        ),
                      ),
                    ),
                  ],
                ),
                EtiquetaMicro(estado: estadoMicro),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipSituacion extends StatelessWidget {
  const _ChipSituacion({required this.rol, required this.onQuitar});

  final RolProceso rol;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    // Hecho a mano (no InputChip) para que, con letra grande, el texto pase a dos líneas en vez de cortarse.
    return Material(
      key: const Key('chip-situacion'),
      color: tinteMarca(esquema),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radios.s),
        side: BorderSide(color: esquema.primary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: Espacio.s + Espacio.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconoTuTurno(
              TuIcono.miSituacion,
              estilo: EstiloIcono.mono,
              size: Espacio.l - Espacio.xs,
              color: esquema.primary,
              decorativo: true,
            ),
            const SizedBox(width: Espacio.s),
            Flexible(
              child: Text(
                etiquetaSituacion(rol),
                style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Quitar y preguntar en general',
              color: esquema.primary,
              iconSize: Espacio.l - Espacio.xs,
              onPressed: () {
                Hapticos.seleccion();
                onQuitar();
              },
              icon: const IconoTuTurno(TuIcono.cerrar, estilo: EstiloIcono.mono, decorativo: true),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso amable cuando la voz no funciona. El campo de texto sigue disponible.
class AvisoVoz extends StatelessWidget {
  const AvisoVoz({super.key, required this.problema, required this.onCerrar});

  final ProblemaVoz problema;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: tinteMarca(esquema),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radios.m),
          side: BorderSide(color: esquema.primary.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: Espacio.m),
          child: Row(
            children: [
              if (problema == ProblemaVoz.sinPermiso)
                Icon(Icons.mic_off_rounded, color: esquema.primary)
              else
                IconoTuTurno(TuIcono.info, estilo: EstiloIcono.mono, color: esquema.primary, decorativo: true),
              const SizedBox(width: Espacio.s + Espacio.xs),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Espacio.s + Espacio.xs),
                  child: Text(
                    mensajeProblemaVoz(problema),
                    style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurface, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar el aviso',
                color: esquema.onSurfaceVariant,
                onPressed: onCerrar,
                icon: const IconoTuTurno(TuIcono.cerrar, estilo: EstiloIcono.mono, decorativo: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampoPregunta extends StatelessWidget {
  const _CampoPregunta({required this.texto, required this.foco, required this.onEnviar});

  final TextEditingController texto;
  final FocusNode foco;
  final VoidCallback onEnviar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return TextField(
      key: const Key('campo-pregunta'),
      controller: texto,
      focusNode: foco,
      minLines: 1,
      maxLines: 4,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.send,
      // Que el teclado no aprenda ni sugiera después lo que se escribe aquí (móviles compartidos en familia).
      enableIMEPersonalizedLearning: false,
      textCapitalization: TextCapitalization.sentences,
      inputFormatters: [LengthLimitingTextInputFormatter(500)],
      style: tema.textTheme.bodyLarge,
      onSubmitted: (_) => onEnviar(),
      decoration: const InputDecoration(hintText: 'Escribe tu pregunta…'),
    );
  }
}

/// Después de dictar: recuerda que se puede corregir antes de enviar.
class _AvisoRevisar extends StatelessWidget {
  const _AvisoRevisar({required this.desdeVoz});

  final ValueListenable<bool> desdeVoz;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: desdeVoz,
      builder: (context, revisar, _) => AnimatedSize(
        duration: duracionTamano(context, Duracion.corta),
        alignment: Alignment.topCenter,
        child: revisar
            ? Padding(
                padding: const EdgeInsets.only(top: Espacio.xs, left: Espacio.s),
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 16, color: tema.colorScheme.primary),
                    const SizedBox(width: Espacio.xs),
                    Expanded(
                      child: Text(
                        'Revisa lo que he entendido y pulsa enviar.',
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
    );
  }
}

class _BotonEnviar extends StatelessWidget {
  const _BotonEnviar({required this.texto, required this.activo, required this.onEnviar});

  final TextEditingController texto;
  final bool activo;
  final VoidCallback onEnviar;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: texto,
      builder: (context, valor, _) {
        final puede = activo && valor.text.trim().isNotEmpty;
        final esquema = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: Espacio.xs),
          child: AnimatedScale(
            scale: puede ? 1 : 0.9,
            duration: duracion(context, Duracion.corta),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: duracion(context, Duracion.corta),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: puede ? esquema.primary : esquema.surfaceContainerHighest,
                boxShadow: puede ? sombrasPapel(context, elevacion: 0.6) : null,
              ),
              child: IconButton(
                key: const Key('boton-enviar'),
                tooltip: 'Enviar',
                iconSize: 24,
                color: esquema.onPrimary,
                disabledColor: esquema.onSurfaceVariant,
                style: IconButton.styleFrom(minimumSize: const Size.square(Espacio.xxl + Espacio.xs)),
                onPressed: puede ? onEnviar : null,
                // El avión de papel de la marca, de un color (toma el del botón).
                icon: const IconoTuTurno(TuIcono.enviar, estilo: EstiloIcono.mono, decorativo: true),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BotonVozAutomatica extends ConsumerWidget {
  const _BotonVozAutomatica();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activada = ref.watch(ajustesProvider.select((a) => a.vozActivada));
    return _BotonLateral(
      icono: IconoTuTurno(activada ? TuIcono.altavoz : TuIcono.silencio, estilo: EstiloIcono.mono, decorativo: true),
      texto: activada ? 'Voz' : 'Sin voz',
      tooltip: activada ? 'Las respuestas se leen en voz alta' : 'Las respuestas no se leen en voz alta',
      seleccionado: activada,
      onPressed: () {
        Hapticos.seleccion();
        ref.read(ajustesProvider.notifier).actualizar((a) => a.copyWith(vozActivada: !a.vozActivada));
      },
    );
  }
}

class _BotonLateral extends StatelessWidget {
  const _BotonLateral({
    required this.icono,
    required this.texto,
    required this.tooltip,
    required this.onPressed,
    this.seleccionado,
  });

  final Widget icono;
  final String texto;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool? seleccionado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final apagado = seleccionado == false;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: tooltip,
          isSelected: seleccionado,
          onPressed: onPressed,
          icon: icono,
          style: IconButton.styleFrom(
            backgroundColor: apagado ? esquema.surfaceContainerHighest : tinteMarca(esquema, intensidad: 0.14),
            foregroundColor: apagado ? esquema.onSurfaceVariant : esquema.primary,
            disabledBackgroundColor: esquema.onSurface.withValues(alpha: 0.06),
            disabledForegroundColor: esquema.onSurface.withValues(alpha: 0.38),
          ),
        ),
        ExcludeSemantics(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              texto,
              style: tema.textTheme.labelMedium?.copyWith(
                color: onPressed == null ? tema.disabledColor : tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum EstadoMicro { inactivo, preparando, escuchando, desactivado, noDisponible }

String _etiquetaMicro(EstadoMicro estado) => switch (estado) {
  EstadoMicro.inactivo => 'Pulsa para hablar',
  EstadoMicro.preparando => 'Preparando el micrófono…',
  EstadoMicro.escuchando => 'Te escucho… Pulsa para parar',
  EstadoMicro.desactivado => 'Espera a que te conteste…',
  EstadoMicro.noDisponible => 'Micrófono no disponible',
};

String _semanticaMicro(EstadoMicro estado) => switch (estado) {
  EstadoMicro.inactivo => 'Micrófono. Pulsa para hablar',
  EstadoMicro.preparando => 'Preparando el micrófono',
  EstadoMicro.escuchando => 'Te estoy escuchando. Pulsa para parar',
  EstadoMicro.desactivado => 'Micrófono desactivado mientras llega la respuesta',
  EstadoMicro.noDisponible => 'Micrófono no disponible. Puedes escribir tu pregunta o pulsar para intentarlo otra vez',
};

/// Texto bajo el micrófono.
class EtiquetaMicro extends StatelessWidget {
  const EtiquetaMicro({super.key, required this.estado});

  final EstadoMicro estado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final escuchando = estado == EstadoMicro.escuchando;
    return ExcludeSemantics(
      child: AnimatedSwitcher(
        duration: duracion(context, Duracion.corta),
        child: Text(
          _etiquetaMicro(estado),
          key: ValueKey(estado),
          textAlign: TextAlign.center,
          style: tema.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: escuchando ? tema.colorScheme.primary : tema.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Botón grande del micrófono: una pegatina redonda del color principal (azul en claro, amarillo en oscuro), con
/// borde blanco y sombra de papel. Pulsar para hablar y pulsar para parar; mientras escucha, salen ondas de papel que
/// crecen con la voz.
class BotonMicro extends ConsumerStatefulWidget {
  const BotonMicro({super.key, required this.estado, required this.proveedor, required this.onPressed});

  final EstadoMicro estado;
  final ProveedorChat proveedor;
  final VoidCallback onPressed;

  static const diametro = 76.0;
  static const zona = 108.0;

  /// Borde blanco de pegatina.
  static const _bordePegatina = 3.5;

  @override
  ConsumerState<BotonMicro> createState() => _BotonMicroState();
}

class _BotonMicroState extends ConsumerState<BotonMicro> with SingleTickerProviderStateMixin {
  late final _ondas = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  var _pulsado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _actualizarOndas();
  }

  @override
  void didUpdateWidget(BotonMicro anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.estado != widget.estado) _actualizarOndas();
  }

  void _actualizarOndas() {
    final animar = widget.estado == EstadoMicro.escuchando && duracion(context, Duracion.media) != Duration.zero;
    if (animar && !_ondas.isAnimating) {
      _ondas.repeat();
    } else if (!animar && _ondas.isAnimating) {
      _ondas.stop();
      _ondas.value = 0;
    }
  }

  @override
  void dispose() {
    _ondas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.estado;
    final esquema = Theme.of(context).colorScheme;
    final escuchando = estado == EstadoMicro.escuchando;
    final activo = estado != EstadoMicro.desactivado;
    final nivel = escuchando ? ref.watch(widget.proveedor.select((s) => s.nivelVoz)) : 0.0;
    final sinMovimiento = duracion(context, Duracion.media) == Duration.zero;
    final tinta = activo ? esquema.onPrimary : esquema.onSurfaceVariant;

    final icono = switch (estado) {
      EstadoMicro.escuchando => const Icon(Icons.stop_rounded, key: ValueKey('parar'), size: 38),
      EstadoMicro.preparando => SizedBox.square(
        key: const ValueKey('preparando'),
        dimension: 28,
        child: CircularProgressIndicator(strokeWidth: 3, color: tinta),
      ),
      EstadoMicro.noDisponible => const Icon(Icons.mic_off_rounded, key: ValueKey('sin-micro'), size: 36),
      _ => const IconoTuTurno(
        TuIcono.microfono,
        key: ValueKey('micro'),
        estilo: EstiloIcono.mono,
        size: 36,
        decorativo: true,
      ),
    };

    final escala = _pulsado ? 0.92 : (escuchando && !sinMovimiento ? 1 + nivel * 0.1 : 1.0);

    return Semantics(
      key: const Key('boton-micro'),
      container: true,
      button: true,
      enabled: activo,
      label: _semanticaMicro(estado),
      onTap: activo ? widget.onPressed : null,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: BotonMicro.zona,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (escuchando)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _ondas,
                  builder: (context, _) => CustomPaint(
                    painter: _PintorOndas(
                      progreso: sinMovimiento ? 0.5 : _ondas.value,
                      nivel: nivel,
                      color: esquema.primary,
                      radioBase: BotonMicro.diametro / 2,
                      animado: !sinMovimiento,
                    ),
                  ),
                ),
              ),
            AnimatedScale(
              scale: escala,
              duration: duracion(context, Duracion.corta),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: duracion(context, Duracion.media),
                width: BotonMicro.diametro,
                height: BotonMicro.diametro,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activo ? esquema.primary : esquema.surfaceContainerHighest,
                  // Borde blanco de pegatina y sombra de papel; desactivado, plano.
                  border: activo ? Border.all(color: Colors.white, width: BotonMicro._bordePegatina) : null,
                  boxShadow: activo ? sombrasPapel(context, elevacion: escuchando ? 2 : 1.2) : null,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: activo ? widget.onPressed : null,
                    onHighlightChanged: (valor) => setState(() => _pulsado = valor),
                    splashColor: esquema.onPrimary.withValues(alpha: 0.2),
                    child: Center(
                      child: IconTheme(
                        data: IconThemeData(color: tinta),
                        child: AnimatedSwitcher(
                          duration: duracion(context, Duracion.corta),
                          transitionBuilder: (child, animacion) => ScaleTransition(
                            scale: animacion,
                            child: FadeTransition(opacity: animacion, child: child),
                          ),
                          child: icono,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ondas de papel que salen del micrófono mientras escucha; crecen con el volumen.
class _PintorOndas extends CustomPainter {
  _PintorOndas({
    required this.progreso,
    required this.nivel,
    required this.color,
    required this.radioBase,
    required this.animado,
  });

  final double progreso;
  final double nivel;
  final Color color;
  final double radioBase;
  final bool animado;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final radioMaximo = size.shortestSide / 2;
    final pintura = Paint()..style = PaintingStyle.fill;
    if (!animado) {
      pintura.color = color.withValues(alpha: 0.18);
      canvas.drawCircle(centro, radioBase + (radioMaximo - radioBase) * 0.6, pintura);
      return;
    }
    for (var i = 0; i < 3; i++) {
      final fase = (progreso + i / 3) % 1.0;
      final alcance = 0.55 + 0.45 * nivel;
      final radio = radioBase + (radioMaximo - radioBase) * fase * alcance;
      pintura.color = color.withValues(alpha: (1 - fase) * 0.28);
      canvas.drawCircle(centro, radio, pintura);
    }
  }

  @override
  bool shouldRepaint(_PintorOndas anterior) =>
      anterior.progreso != progreso || anterior.nivel != nivel || anterior.color != color;
}

/// Micrófono pequeño, junto al campo, en modo compacto. Mientras escucha es el botón de parar.
class BotonMicroPequeno extends StatelessWidget {
  const BotonMicroPequeno({super.key, required this.estado, required this.onPressed});

  final EstadoMicro estado;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final activo = estado != EstadoMicro.desactivado;
    final esquema = Theme.of(context).colorScheme;
    final escuchando = estado == EstadoMicro.escuchando;
    final icono = switch (estado) {
      EstadoMicro.escuchando => const Icon(Icons.stop_rounded, key: ValueKey('parar')),
      EstadoMicro.preparando => SizedBox.square(
        key: const ValueKey('preparando'),
        dimension: Espacio.l - Espacio.xs,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: esquema.onPrimary),
      ),
      EstadoMicro.noDisponible => const Icon(Icons.mic_off_rounded, key: ValueKey('sin-micro')),
      _ => const IconoTuTurno(TuIcono.microfono, key: ValueKey('micro'), estilo: EstiloIcono.mono, decorativo: true),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: Espacio.xs),
      child: Semantics(
        button: true,
        enabled: activo,
        label: _semanticaMicro(estado),
        excludeSemantics: true,
        onTap: activo ? onPressed : null,
        child: Tooltip(
          message: escuchando ? 'Parar' : 'Hablar',
          excludeFromSemantics: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activo ? esquema.primary : esquema.surfaceContainerHighest,
              boxShadow: activo ? sombrasPapel(context, elevacion: 0.6) : null,
            ),
            child: IconButton(
              color: activo ? esquema.onPrimary : esquema.onSurfaceVariant,
              onPressed: activo ? onPressed : null,
              icon: AnimatedSwitcher(duration: duracion(context, Duracion.corta), child: icono),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mientras se escucha: la transcripción en vivo, grande, y unas barras que se mueven con la voz.
class PanelEscucha extends ConsumerWidget {
  const PanelEscucha({super.key, required this.proveedor});

  final ProveedorChat proveedor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:dictado, :nivel, :preparando) = ref.watch(
      proveedor.select((s) => (dictado: s.dictado, nivel: s.nivelVoz, preparando: s.voz == EstadoVoz.preparando)),
    );
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final vacio = dictado.trim().isEmpty;
    // Solo se ven las últimas palabras: lo importante es comprobar que te está entendiendo.
    final visible = dictado.length > 160 ? '…${dictado.substring(dictado.length - 160)}' : dictado;

    return Container(
      key: const Key('panel-escucha'),
      constraints: const BoxConstraints(minHeight: Espacio.xxl + Espacio.s),
      padding: const EdgeInsets.symmetric(horizontal: Espacio.m, vertical: Espacio.s + Espacio.xs),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radios.m),
        border: Border.all(color: esquema.primary, width: 2),
      ),
      child: Row(
        children: [
          _Barras(nivel: nivel),
          const SizedBox(width: Espacio.m),
          Expanded(
            child: Text(
              preparando ? 'Un momento…' : (vacio ? 'Habla ahora. Te escucho.' : visible),
              style: tema.textTheme.titleMedium?.copyWith(
                color: vacio ? esquema.onSurfaceVariant : esquema.onSurface,
                fontWeight: vacio ? FontWeight.w400 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Barras extends StatefulWidget {
  const _Barras({required this.nivel});

  final double nivel;

  @override
  State<_Barras> createState() => _BarrasState();
}

class _BarrasState extends State<_Barras> with SingleTickerProviderStateMixin {
  late final _onda = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (duracion(context, Duracion.media) == Duration.zero) {
      _onda.stop();
    } else if (!_onda.isAnimating) {
      _onda.repeat();
    }
  }

  @override
  void dispose() {
    _onda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return ExcludeSemantics(
      child: SizedBox(
        width: Espacio.xl,
        height: Espacio.l,
        child: AnimatedBuilder(
          animation: _onda,
          builder: (context, _) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 4; i++)
                Container(
                  width: Espacio.xs,
                  height: Espacio.l * _alto(i),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Espacio.xs)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _alto(int i) {
    final onda = (math.sin((_onda.value * 2 * math.pi) + i * 1.3) + 1) / 2;
    final base = 0.25 + 0.35 * widget.nivel;
    return (base + onda * (0.3 + 0.4 * widget.nivel)).clamp(0.2, 1.0);
  }
}
