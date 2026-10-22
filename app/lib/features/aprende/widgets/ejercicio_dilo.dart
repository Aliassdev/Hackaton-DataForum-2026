import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/seguridad.dart';
import '../../../core/voz/stt.dart';
import '../../../core/voz/tts.dart';
import '../../../tema.dart';
import '../../../widgets/movimiento/hapticos.dart';
import '../modelos.dart';
import '../textos.dart';
import 'comunes.dart';

/// Palabras de [texto] (sin contar espacios ni signos sueltos).
int contarPalabras(String texto) => RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(texto).length;

String mensajeVozDilo(ProblemaVoz problema) => switch (problema) {
  ProblemaVoz.sinPermiso => 'No puedo usar el micrófono. Puedes escribir tu respuesta.',
  ProblemaVoz.noTeOigo => 'No te he oído bien. Prueba otra vez o escríbelo.',
  ProblemaVoz.sinRed => 'Para dictar hace falta internet. Puedes escribir tu respuesta.',
  ProblemaVoz.ocupado => 'El micrófono está ocupado. Prueba otra vez en un momento.',
  ProblemaVoz.idioma => 'Tu móvil no reconoce la voz en español. Puedes escribir tu respuesta.',
  ProblemaVoz.otro => 'No he podido escucharte. Prueba otra vez o escríbelo.',
};

/// «Dilo con tus palabras»: un campo de texto y el micrófono (pulsar para hablar). La transcripción va al campo
/// y se puede corregir antes de comprobar. Si la voz falla, el campo sigue ahí.
class VistaDilo extends ConsumerStatefulWidget {
  const VistaDilo({super.key, required this.ejercicio, required this.bloqueado, required this.onRespuesta});

  final EjercicioDilo ejercicio;

  /// Mientras se corrige y después: el texto ya no se puede cambiar.
  final bool bloqueado;

  /// El texto cuando tiene al menos [palabrasMinimasDilo] palabras y el micrófono está apagado; si no, null.
  final ValueChanged<String?> onRespuesta;

  @override
  ConsumerState<VistaDilo> createState() => _VistaDiloState();
}

enum _Micro { inactivo, preparando, escuchando }

class _VistaDiloState extends ConsumerState<VistaDilo> {
  final _texto = TextEditingController();
  late final Stt _stt = ref.read(sttProvider);
  var _micro = _Micro.inactivo;
  double _nivel = 0;
  String? _aviso;
  var _desdeVoz = false;

  /// Lo que había escrito antes de dictar: lo dictado se añade detrás.
  var _base = '';

  @override
  void initState() {
    super.initState();
    _texto.addListener(_avisar);
  }

  @override
  void didUpdateWidget(VistaDilo anterior) {
    super.didUpdateWidget(anterior);
    if (widget.bloqueado && !anterior.bloqueado && _micro != _Micro.inactivo) unawaited(_stt.parar());
  }

  @override
  void dispose() {
    if (_micro != _Micro.inactivo) unawaited(_stt.cancelar());
    _texto.dispose();
    super.dispose();
  }

  /// Avisa de la respuesta. Mientras se prepara el micrófono o se dicta, lo que hay es una transcripción a medias: no
  /// se puede comprobar hasta que el micrófono se apaga y el texto final está en el campo. Si suena a peligro («quiero
  /// morir»), vale aunque sean pocas palabras: al comprobar se ofrece ayuda (sección 10.2).
  void _avisar() {
    final texto = _texto.text.trim();
    final suficiente = contarPalabras(texto) >= palabrasMinimasDilo || pareceCrisis(texto);
    widget.onRespuesta(_micro == _Micro.inactivo && suficiente ? texto : null);
  }

  Future<void> _alternarMicro() async {
    if (widget.bloqueado) return;
    if (_micro == _Micro.escuchando) {
      Hapticos.seleccion();
      await _stt.parar();
      return;
    }
    if (_micro == _Micro.preparando) return;
    setState(() {
      _micro = _Micro.preparando;
      _aviso = null;
    });
    _avisar();
    // Nunca se escucha mientras la app habla: el micrófono se oiría a sí mismo.
    await ref.read(ttsProvider).parar();
    final disponible = await _stt.inicializar();
    if (!mounted) return;
    if (!disponible) {
      setState(() {
        _micro = _Micro.inactivo;
        _aviso = mensajeVozDilo(ProblemaVoz.sinPermiso);
      });
      _avisar();
      return;
    }
    _base = _texto.text.trim();
    Hapticos.toque();
    setState(() => _micro = _Micro.escuchando);
    await _stt.escuchar(
      onTexto: (dictado) {
        // Lo que llegue cuando ya se está corrigiendo no cambia el texto: se corrige lo que se ve.
        if (!mounted || widget.bloqueado) return;
        final completo = [_base, dictado.trim()].where((t) => t.isNotEmpty).join(' ');
        _texto.value = TextEditingValue(
          text: completo,
          selection: TextSelection.collapsed(offset: completo.length),
        );
        if (!_desdeVoz && dictado.trim().isNotEmpty) setState(() => _desdeVoz = true);
      },
      onFin: () {
        if (!mounted) return;
        setState(() {
          _micro = _Micro.inactivo;
          _nivel = 0;
        });
        _avisar();
      },
      onNivel: (nivel) {
        // Android lo manda varias veces por segundo: solo se repinta si cambia de verdad.
        if (mounted && _micro == _Micro.escuchando && (nivel - _nivel).abs() >= 0.05) setState(() => _nivel = nivel);
      },
      onProblema: (problema) {
        if (mounted) setState(() => _aviso = mensajeVozDilo(problema));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final aviso = _aviso;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.ejercicio.pregunta, style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: Espacio.s),
        Text(textoDiloAyuda, style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
        const SizedBox(height: Espacio.m),
        TextField(
          key: const ValueKey('campo-dilo'),
          controller: _texto,
          readOnly: widget.bloqueado,
          minLines: 4,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          // Que el teclado no aprenda lo que se escribe aquí (móviles compartidos en familia).
          enableIMEPersonalizedLearning: false,
          inputFormatters: [LengthLimitingTextInputFormatter(500)],
          style: tema.textTheme.bodyLarge,
          onChanged: (_) {
            if (_desdeVoz) setState(() => _desdeVoz = false);
          },
          decoration: InputDecoration(
            hintText: 'Escribe aquí con tus palabras…',
            semanticCounterText: '',
            fillColor: widget.bloqueado ? esquema.surfaceContainerLow : null,
          ),
        ),
        const SizedBox(height: Espacio.s),
        AnimatedSize(
          duration: duracionTamano(context, Duracion.corta),
          alignment: Alignment.topCenter,
          child: _desdeVoz && !widget.bloqueado
              ? Padding(
                  padding: const EdgeInsets.only(bottom: Espacio.s),
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, size: Espacio.m, color: esquema.primary),
                      const SizedBox(width: Espacio.xs),
                      Expanded(
                        child: Text(
                          'Revisa lo que he entendido antes de comprobar.',
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: esquema.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        if (!widget.bloqueado)
          Row(
            children: [
              _BotonMicro(estado: _micro, nivel: _nivel, onPressed: _alternarMicro),
              const SizedBox(width: Espacio.m - 4),
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    switch (_micro) {
                      _Micro.inactivo => 'Pulsa para dictar',
                      _Micro.preparando => 'Preparando el micrófono…',
                      _Micro.escuchando => 'Te escucho… Pulsa para parar',
                    },
                    style: tema.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _micro == _Micro.escuchando ? esquema.primary : esquema.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Espacio.s),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _texto,
                builder: (context, valor, _) {
                  final palabras = contarPalabras(valor.text);
                  final suficiente = palabras >= palabrasMinimasDilo;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (suficiente) ...[
                        Icon(Icons.check_circle_rounded, size: Espacio.m + 2, color: context.colores.exito),
                        const SizedBox(width: Espacio.xs),
                      ],
                      Text(
                        palabras == 1 ? '1 palabra' : '$palabras palabras',
                        style: tema.textTheme.labelLarge?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        if (aviso != null && !widget.bloqueado) ...[
          const SizedBox(height: Espacio.s),
          Semantics(
            liveRegion: true,
            container: true,
            child: Container(
              padding: const EdgeInsets.all(Espacio.s + Espacio.xs),
              decoration: BoxDecoration(
                color: fondoAcento(context, esquema.primary),
                borderRadius: BorderRadius.circular(Radios.m),
                border: Border.all(color: bordeTinte(esquema.primary)),
              ),
              child: Row(
                children: [
                  Icon(Icons.mic_off_rounded, color: esquema.primary),
                  const SizedBox(width: Espacio.s),
                  Expanded(
                    child: Text(
                      aviso,
                      style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurface, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BotonMicro extends StatelessWidget {
  const _BotonMicro({required this.estado, required this.nivel, required this.onPressed});

  final _Micro estado;
  final double nivel;
  final VoidCallback onPressed;

  static const _diametro = 60.0;

  /// Lo más que crece el halo alrededor del botón (con la voz más alta). Ese margen queda reservado siempre.
  static const _haloMaximo = 14.0;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores.aprende;
    final escuchando = estado == _Micro.escuchando;
    final quieto = sinMovimiento(context);
    final halo = escuchando ? (quieto ? 10.0 : 6 + nivel.clamp(0.0, 1.0) * (_haloMaximo - 6)) : 0.0;
    return Semantics(
      key: const ValueKey('micro-dilo'),
      button: true,
      label: escuchando ? 'Te estoy escuchando. Pulsa para parar' : 'Micrófono. Pulsa para dictar tu respuesta',
      excludeSemantics: true,
      onTap: onPressed,
      // El hueco es siempre el mismo: el halo late con la voz sin mover nada de alrededor.
      child: SizedBox.square(
        dimension: _diametro + 2 * _haloMaximo,
        child: Stack(
          alignment: Alignment.center,
          children: [
            IgnorePointer(
              child: AnimatedScale(
                scale: 1 + halo / (_diametro / 2),
                duration: duracion(context, Duracion.corta),
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: duracion(context, Duracion.corta),
                  width: _diametro,
                  height: _diametro,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colores.last.withValues(alpha: escuchando ? 0.2 : 0),
                  ),
                ),
              ),
            ),
            Container(
              width: _diametro,
              height: _diametro,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: colores, begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Material(
                type: MaterialType.transparency,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPressed,
                  child: Center(
                    child: estado == _Micro.preparando
                        ? SizedBox.square(
                            dimension: Espacio.l,
                            child: CircularProgressIndicator(strokeWidth: 3, color: sobreColor(colores.first)),
                          )
                        : Icon(
                            escuchando ? Icons.stop_rounded : Icons.mic_rounded,
                            size: Espacio.xl,
                            color: sobreColor(colores.first),
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
