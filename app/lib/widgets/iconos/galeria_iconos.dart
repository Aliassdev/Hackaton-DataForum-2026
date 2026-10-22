import 'package:flutter/material.dart';

import '../../tema.dart';
import 'icono_tuturno.dart';
import 'mascota_tut.dart';
import 'paleta_iconos.dart';
import 'pieza.dart';
import 'tu_icono.dart';

/// Tamaños de la fila de legibilidad.
const _tamanos = [24.0, 32.0, 48.0, 72.0, 120.0];

/// Iconos de muestra en la fila de tamaños.
const _muestra = [TuIcono.racha, TuIcono.ayuda, TuIcono.carta, TuIcono.pregunta];

/// Todos los iconos y todas las expresiones de Tut, para revisar el diseño (y para las capturas).
class GaleriaIconos extends StatelessWidget {
  const GaleriaIconos({super.key, this.tamano = 56, this.animada = false});

  /// Tamaño de los iconos en la cuadrícula principal.
  final double tamano;

  /// Iconos con aparición y Tut con gestos.
  final bool animada;

  @override
  Widget build(BuildContext context) {
    final paleta = PaletaIconos.de(context);
    final esquema = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Espacio.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Titulo('Iconos', 'A dos tintas, con contorno y sombra de papel'),
          _Rejilla(
            children: [
              for (final icono in TuIcono.values)
                _Celda(
                  texto: icono.etiqueta,
                  child: IconoTuTurno(icono, size: tamano, animado: animada),
                ),
            ],
          ),
          const _Titulo('Pegatinas', 'Con borde blanco, para fondos de color'),
          _Panel(
            color: paleta.azul,
            child: _Rejilla(
              children: [
                for (final icono in TuIcono.values) IconoTuTurno(icono, size: tamano, pegatina: true, decorativo: true),
              ],
            ),
          ),
          const _Titulo('Una tinta', 'Para botones, barras y chips'),
          _Panel(
            color: esquema.primary,
            child: _Rejilla(
              children: [
                for (final icono in TuIcono.values)
                  IconoTuTurno(icono, size: 32, estilo: EstiloIcono.mono, color: esquema.onPrimary, decorativo: true),
              ],
            ),
          ),
          const SizedBox(height: Espacio.s),
          _Rejilla(
            children: [
              for (final icono in TuIcono.values)
                IconoTuTurno(icono, size: 24, estilo: EstiloIcono.mono, decorativo: true),
            ],
          ),
          const _Titulo('Tamaños', '24 · 32 · 48 · 72 · 120'),
          for (final icono in _muestra)
            Padding(
              padding: const EdgeInsets.only(bottom: Espacio.s),
              child: Wrap(
                spacing: Espacio.m,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [for (final lado in _tamanos) IconoTuTurno(icono, size: lado, decorativo: true)],
              ),
            ),
          const _Titulo('Tut', 'La mascota: el ticket con la cara del monograma'),
          _Rejilla(
            children: [
              for (final expresion in ExpresionTut.values)
                _Celda(
                  texto: expresion.name,
                  ancho: 136,
                  child: MascotaTut(expresion: expresion, size: 128, animada: animada, decorativo: true),
                ),
            ],
          ),
          const SizedBox(height: Espacio.m),
          _Panel(
            color: paleta.azul,
            child: _Rejilla(
              children: [
                for (final expresion in ExpresionTut.values)
                  MascotaTut(expresion: expresion, size: 88, pegatina: true, animada: animada, decorativo: true),
              ],
            ),
          ),
          const SizedBox(height: Espacio.m),
          _Rejilla(
            children: [
              for (final expresion in ExpresionTut.values)
                MascotaTut(expresion: expresion, size: 40, animada: animada, decorativo: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.titulo, this.subtitulo);

  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: Espacio.l, bottom: Espacio.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(titulo, style: texto.headlineSmall)),
          Text(subtitulo, style: texto.bodyMedium),
        ],
      ),
    );
  }
}

class _Rejilla extends StatelessWidget {
  const _Rejilla({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Espacio.m,
    runSpacing: Espacio.m,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: children,
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Radios.m)),
    child: Padding(padding: const EdgeInsets.all(Espacio.m), child: child),
  );
}

class _Celda extends StatelessWidget {
  const _Celda({required this.texto, required this.child, this.ancho = 88});

  final String texto;
  final Widget child;
  final double ancho;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: ancho,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(height: Espacio.xs),
        Text(
          texto,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    ),
  );
}
