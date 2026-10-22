import 'package:flutter/material.dart';

import '../../../tema.dart';
import '../modelos.dart';
import 'comunes.dart';
import 'opcion.dart';

/// Empareja: se toca una tarjeta de cada columna para unirlas (en cualquier orden). Cada pareja lleva su color
/// y su número a los dos lados. Tocar una tarjeta ya unida deshace la pareja.
class VistaEmparejar extends StatefulWidget {
  const VistaEmparejar({super.key, required this.ejercicio, required this.revisado, required this.onRespuesta});

  final EjercicioEmparejar ejercicio;
  final bool revisado;

  /// Con todas las parejas hechas, las uniones (izquierda → derecha, en posiciones originales); si no, null.
  final ValueChanged<Map<int, int>?> onRespuesta;

  @override
  State<VistaEmparejar> createState() => _VistaEmparejarState();
}

class _VistaEmparejarState extends State<VistaEmparejar> {
  late final List<int> _derecha = barajar(
    widget.ejercicio.pares.length,
    semillaDe(widget.ejercicio.id),
    evitarIdentidad: true,
  );
  final _uniones = <int, int>{};
  int? _izquierdaElegida;
  int? _derechaElegida;

  int get _total => widget.ejercicio.pares.length;

  int? _izquierdaDe(int derecha) {
    for (final u in _uniones.entries) {
      if (u.value == derecha) return u.key;
    }
    return null;
  }

  void _tocarIzquierda(int i) {
    setState(() {
      if (_uniones.remove(i) != null) {
        _izquierdaElegida = i;
        _derechaElegida = null;
      } else if (_derechaElegida != null) {
        _uniones[i] = _derechaElegida!;
        _izquierdaElegida = _derechaElegida = null;
      } else {
        _izquierdaElegida = _izquierdaElegida == i ? null : i;
      }
    });
    _avisar();
  }

  void _tocarDerecha(int j) {
    setState(() {
      final unida = _izquierdaDe(j);
      if (unida != null) {
        _uniones.remove(unida);
        _derechaElegida = j;
        _izquierdaElegida = null;
      } else if (_izquierdaElegida != null) {
        _uniones[_izquierdaElegida!] = j;
        _izquierdaElegida = _derechaElegida = null;
      } else {
        _derechaElegida = _derechaElegida == j ? null : j;
      }
    });
    _avisar();
  }

  void _avisar() => widget.onRespuesta(_uniones.length == _total ? Map.unmodifiable(_uniones) : null);

  /// Un color distinto para cada pareja, sacado del tema y sin repetidos (en el tema claro el de Vive el caso es el
  /// mismo azul que el primario). Nunca el primario, que marca la tarjeta elegida que espera su pareja, ni el verde de
  /// acierto ni el terciario de fallo (ni el rojo de error), para no confundir una pareja con una corrección.
  List<Color> _paleta(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final c = context.colores;
    final reservados = {esquema.primary, c.exito, esquema.tertiary, esquema.error};
    final colores = {
      c.juego.last,
      c.aprende.last,
      c.pregunta.first,
      esquema.secondary,
      c.juego.first,
    }.where((color) => !reservados.contains(color)).toList();
    return colores.isEmpty ? [esquema.primary] : colores;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final pares = widget.ejercicio.pares;
    final paleta = _paleta(context);
    final estiloItem = tema.textTheme.bodyLarge;

    Color colorDe(int izquierda) => paleta[izquierda % paleta.length];

    Widget izquierda(int i) {
      final unida = _uniones[i];
      final EstadoOpcion estado;
      if (widget.revisado) {
        estado = unida == i ? EstadoOpcion.correcta : EstadoOpcion.incorrecta;
      } else {
        estado = unida != null || _izquierdaElegida == i ? EstadoOpcion.elegida : EstadoOpcion.normal;
      }
      final texto = pares[i].$1;
      final detalle = unida != null
          ? '. Unida con «${pares[unida].$2}»${widget.revisado ? (unida == i ? ', bien' : ', no es su pareja') : '. Toca para deshacer'}'
          : (_izquierdaElegida == i ? '. Elegida: ahora toca su pareja en la otra columna' : '');
      return TarjetaOpcion(
        key: ValueKey('izquierda-$i'),
        texto: texto,
        estado: estado,
        chapa: unida != null ? '${i + 1}' : null,
        colorElegida: unida != null ? colorDe(i) : esquema.primary,
        estiloTexto: estiloItem,
        semantica: '$texto$detalle',
        onTap: widget.revisado ? null : () => _tocarIzquierda(i),
      );
    }

    Widget derecha(int j) {
      final unida = _izquierdaDe(j);
      final EstadoOpcion estado;
      if (widget.revisado) {
        estado = unida == j ? EstadoOpcion.correcta : EstadoOpcion.incorrecta;
      } else {
        estado = unida != null || _derechaElegida == j ? EstadoOpcion.elegida : EstadoOpcion.normal;
      }
      final texto = pares[j].$2;
      final detalle = unida != null
          ? '. Unida con «${pares[unida].$1}»${widget.revisado ? (unida == j ? ', bien' : ', no es su pareja') : '. Toca para deshacer'}'
          : (_derechaElegida == j ? '. Elegida: ahora toca su pareja en la otra columna' : '');
      return TarjetaOpcion(
        key: ValueKey('derecha-$j'),
        texto: texto,
        estado: estado,
        chapa: unida != null ? '${unida + 1}' : null,
        colorElegida: unida != null ? colorDe(unida) : esquema.primary,
        estiloTexto: estiloItem,
        semantica: '$texto$detalle',
        onTap: widget.revisado ? null : () => _tocarDerecha(j),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Une cada tarjeta con su pareja', style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: Espacio.s),
        Row(
          children: [
            ExcludeSemantics(
              child: Icon(Icons.touch_app_rounded, size: Espacio.m + 2, color: esquema.primary),
            ),
            const SizedBox(width: Espacio.s),
            Expanded(
              child: Text(
                'Toca una tarjeta de cada columna para unirlas.',
                style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: Espacio.s),
            Semantics(
              liveRegion: true,
              child: Text(
                '${_uniones.length} de $_total',
                style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: Espacio.m),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < pares.length; i++) ...[
                    Aparece(orden: i + 1, desplazamiento: Espacio.m, child: izquierda(i)),
                    const SizedBox(height: Espacio.s + Espacio.xs),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Espacio.s + Espacio.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (posicion, j) in _derecha.indexed) ...[
                    Aparece(orden: posicion + 2, desplazamiento: Espacio.m, child: derecha(j)),
                    const SizedBox(height: Espacio.s + Espacio.xs),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
