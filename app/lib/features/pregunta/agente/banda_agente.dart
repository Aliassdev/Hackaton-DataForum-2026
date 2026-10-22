import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart';
import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../../../widgets/movimiento/hapticos.dart';
import '../widgets/estilo.dart';
import 'chat_agente.dart';
import 'textos_agente.dart';

/// Banda de arriba en el modo agente: cómo va la conversación con TuTurno (conectando, hablando, te escucho, sin
/// conexión…) y lo que se puede hacer (conectar, ver ejemplos, volver a TuTurno). TalkBack anuncia los cambios.
class BandaAgente extends ConsumerWidget {
  const BandaAgente({super.key, required this.situacion});

  /// La misma con la que se abrió Pregunta: elige el chat ([chatAgenteProvider]).
  final RolProceso? situacion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proveedor = chatAgenteProvider(situacion);
    final chat = ref.watch(proveedor.notifier) as ChatAgenteNotifier;
    final (:esperando, :hablando, :hayMensajes) = ref.watch(
      proveedor.select((s) => (esperando: s.esperando, hablando: s.agenteHablando, hayMensajes: s.mensajes.isNotEmpty)),
    );
    return ValueListenableBuilder<SesionAgente>(
      valueListenable: chat.sesion,
      builder: (context, sesion, _) {
        final contenido = _contenido(sesion, esperando: esperando, hablando: hablando, hayMensajes: hayMensajes);
        return _Banda(
          key: const Key('banda-agente'),
          icono: contenido.icono,
          titulo: contenido.titulo,
          detalle: contenido.detalle,
          acciones: [
            for (final (texto, accion) in contenido.acciones)
              (
                texto,
                () {
                  Hapticos.seleccion();
                  accion(chat);
                },
              ),
          ],
        );
      },
    );
  }

  static _Contenido _contenido(
    SesionAgente sesion, {
    required bool esperando,
    required bool hablando,
    required bool hayMensajes,
  }) {
    final ejemplos = ('Ver respuestas de ejemplo', (ChatAgenteNotifier c) => c.usarEjemplos());
    final conectar = ('Conectar', (ChatAgenteNotifier c) => c.abrirSesion());
    switch (sesion.fase) {
      case FaseAgente.preparando:
        return const _Contenido(_Icono.espera, tituloPreparando);
      case FaseAgente.conectando:
        return const _Contenido(_Icono.cargando, tituloConectando);
      case FaseAgente.sinConexion:
        return _Contenido(
          _Icono.sinConexion,
          tituloSinConexion,
          detalle: sesion.aviso,
          acciones: [conectar, if (!esperando) ejemplos],
        );
      case FaseAgente.pausado:
        return _Contenido(_Icono.pausa, tituloPausa, detalle: detallePausa, acciones: [conectar]);
      case FaseAgente.ejemplo:
        return _Contenido(
          _Icono.ejemplo,
          tituloEjemplo,
          detalle: detalleEjemplo,
          acciones: [('Volver a TuTurno', (ChatAgenteNotifier c) => c.volverAlAgente())],
        );
      case FaseAgente.conectado:
        if (hablando) return const _Contenido(_Icono.hablando, tituloHablando);
        if (esperando) return const _Contenido(_Icono.espera, tituloPensando);
        if (sesion.sinRespuesta) {
          return _Contenido(_Icono.sinConexion, tituloNoResponde, detalle: detalleNoResponde, acciones: [ejemplos]);
        }
        final saludo = sesion.saludo;
        final detalle = sesion.conversacionNueva && hayMensajes
            ? [detalleConversacionNueva, if (saludo != null) 'TuTurno ha dicho: «$saludo»'].join(' ')
            : detalleEscucho;
        return _Contenido(_Icono.escucho, tituloEscucho, detalle: detalle);
    }
  }
}

/// Solo «cargando» se mueve (mientras conecta): el resto de estados son quietos, como todo Pregunta.
enum _Icono { cargando, espera, hablando, escucho, sinConexion, pausa, ejemplo }

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
