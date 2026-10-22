import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../../../widgets/movimiento/hapticos.dart';
import '../widgets/compositor.dart' show ProveedorChat;
import '../widgets/estilo.dart';
import 'chat_agente.dart';
import 'textos_agente.dart';

/// Banda de arriba de Pregunta: cómo va la conversación con TuTurno (conectando, hablando, te escucho, la voz no
/// responde…) y lo que se puede hacer (conectar, probar con voz, volver a TuTurno). TalkBack anuncia los cambios.
///
/// Con los ejemplos sale siempre, también en el modo texto: «Sin conexión con el asistente: estas respuestas son de
/// ejemplo». Por escrito porque se ha elegido («Sin voz» o lector de pantalla) no sale nada.
class BandaPregunta extends ConsumerWidget {
  const BandaPregunta({super.key, required this.proveedor, this.compacto = false});

  final ProveedorChat proveedor;

  /// Con poca altura (teclado abierto o letra muy grande en un móvil pequeño): sin la pista de «Te escucho».
  final bool compacto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(proveedor.notifier);
    final (:esperando, :hablando, :hayMensajes, :ejemplos) = ref.watch(
      proveedor.select(
        (s) => (
          esperando: s.esperando,
          hablando: s.agenteHablando,
          hayMensajes: s.mensajes.isNotEmpty,
          ejemplos: s.ejemplos,
        ),
      ),
    );
    if (ejemplos) {
      return _Banda(
        key: const Key('banda-ejemplos'),
        icono: _Icono.ejemplo,
        titulo: tituloEjemplo,
        detalle: detalleEjemplo,
        acciones: [(accionVolverATuTurno, () => _accion(chat.volverATuTurno))],
      );
    }
    if (chat is! ChatAgenteNotifier) return const SizedBox.shrink();
    // Con «Sin voz» o con lector de pantalla no se abre la sesión: no se anuncia que se prepara.
    final vozPosible =
        ref.watch(ajustesProvider.select((a) => a.vozActivada)) && !MediaQuery.accessibleNavigationOf(context);
    return ValueListenableBuilder<SesionAgente>(
      valueListenable: chat.sesion,
      builder: (context, sesion, _) {
        if (!vozPosible && sesion.fase == FaseAgente.preparando) return const SizedBox.shrink();
        final contenido = _contenido(
          sesion,
          esperando: esperando,
          hablando: hablando,
          hayMensajes: hayMensajes,
          compacto: compacto,
        );
        if (contenido == null) return const SizedBox.shrink();
        return _Banda(
          key: const Key('banda-agente'),
          icono: contenido.icono,
          titulo: contenido.titulo,
          detalle: contenido.detalle,
          acciones: [for (final (texto, accion) in contenido.acciones) (texto, () => _accion(() => accion(chat)))],
        );
      },
    );
  }

  static void _accion(void Function() accion) {
    Hapticos.seleccion();
    accion();
  }

  static _Contenido? _contenido(
    SesionAgente sesion, {
    required bool esperando,
    required bool hablando,
    required bool hayMensajes,
    required bool compacto,
  }) {
    final conectar = ('Conectar', (ChatAgenteNotifier c) => c.abrirSesion());
    switch (sesion.fase) {
      case FaseAgente.preparando:
        return const _Contenido(_Icono.espera, tituloPreparando);
      case FaseAgente.conectando:
        return const _Contenido(_Icono.cargando, tituloConectando);
      case FaseAgente.sinConexion:
        return _Contenido(_Icono.sinConexion, tituloSinConexion, detalle: sesion.aviso, acciones: [conectar]);
      case FaseAgente.pausado:
        return _Contenido(_Icono.pausa, tituloPausa, detalle: detallePausa, acciones: [conectar]);
      case FaseAgente.texto:
        return null;
      case FaseAgente.sinVoz:
        return _Contenido(
          _Icono.sinVoz,
          tituloSinVoz,
          detalle: detalleSinVoz,
          acciones: [if (!esperando) (accionProbarVoz, (ChatAgenteNotifier c) => c.probarConVoz())],
        );
      case FaseAgente.conectado:
        if (hablando) return const _Contenido(_Icono.hablando, tituloHablando);
        if (esperando) return const _Contenido(_Icono.espera, tituloPensando);
        final saludo = sesion.saludo;
        final detalle = sesion.conversacionNueva && hayMensajes
            ? [detalleConversacionNueva, if (saludo != null) 'TuTurno ha dicho: «$saludo»'].join(' ')
            : (compacto ? null : detalleEscucho);
        return _Contenido(_Icono.escucho, tituloEscucho, detalle: detalle);
    }
  }
}

/// Solo «cargando» se mueve (mientras conecta): el resto de estados son quietos, como todo Pregunta.
enum _Icono { cargando, espera, hablando, escucho, sinConexion, pausa, sinVoz, ejemplo }

class _Contenido {
  const _Contenido(this.icono, this.titulo, {this.detalle, this.acciones = const []});

  final _Icono icono;
  final String titulo;
  final String? detalle;
  final List<(String, void Function(ChatAgenteNotifier))> acciones;
}

class _Banda extends StatelessWidget {
  const _Banda({super.key, required this.icono, required this.titulo, this.detalle, this.acciones = const []});

  final _Icono icono;
  final String titulo;
  final String? detalle;

  /// Texto y acción de cada botón.
  final List<(String, VoidCallback)> acciones;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final aviso = icono == _Icono.sinConexion;
    final colorIcono = aviso ? esquema.error : esquema.primary;
    // El estilo del botón se suma al del tema (zona táctil de 48 px).
    final estiloBoton = TextButton.styleFrom(foregroundColor: aviso ? esquema.onErrorContainer : esquema.primary);
    final Widget dibujo = switch (icono) {
      _Icono.cargando => SizedBox.square(
        dimension: Espacio.l - Espacio.xs,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: colorIcono),
      ),
      _Icono.espera => Icon(Icons.hourglass_top_rounded, color: colorIcono),
      _Icono.hablando => IconoTuTurno(TuIcono.altavoz, estilo: EstiloIcono.mono, color: colorIcono, decorativo: true),
      _Icono.escucho => IconoTuTurno(TuIcono.microfono, estilo: EstiloIcono.mono, color: colorIcono, decorativo: true),
      _Icono.sinConexion => Icon(Icons.cloud_off_rounded, color: colorIcono),
      _Icono.pausa => Icon(Icons.pause_circle_rounded, color: colorIcono),
      _Icono.sinVoz => IconoTuTurno(TuIcono.silencio, estilo: EstiloIcono.mono, color: colorIcono, decorativo: true),
      _Icono.ejemplo => IconoTuTurno(TuIcono.info, estilo: EstiloIcono.mono, color: colorIcono, decorativo: true),
    };
    return Material(
      color: aviso ? esquema.errorContainer : tinteMarca(esquema),
      child: AnimatedSize(
        duration: duracionTamano(context, Duracion.media),
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.s, Espacio.s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                container: true,
                liveRegion: true,
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: SizedBox(
                        width: Espacio.l,
                        child: Center(child: dibujo),
                      ),
                    ),
                    const SizedBox(width: Espacio.s + Espacio.xs),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: Espacio.xs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titulo,
                              style: tema.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: aviso ? esquema.onErrorContainer : esquema.onSurface,
                              ),
                            ),
                            if (detalle != null)
                              Text(
                                detalle!,
                                style: tema.textTheme.bodyMedium?.copyWith(
                                  color: aviso ? esquema.onErrorContainer : esquema.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (acciones.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: Espacio.l),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: Espacio.xs,
                    children: [
                      for (final (texto, accion) in acciones)
                        TextButton(style: estiloBoton, onPressed: accion, child: Text(texto)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
