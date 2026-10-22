import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/api/models.dart';
import '../../../core/texto.dart';
import '../../../tema.dart';
import '../../../widgets/texto_con_terminos.dart';
import '../../pregunta/widgets/mensajes.dart' show TarjetaCrisis;
import '../modelos.dart';
import '../textos.dart';
import 'comunes.dart';

/// Cómo ha ido una respuesta: bien, no, sin corregir («Dilo» sin conexión o saltado) o «ayuda» (en «Dilo» se ha
/// escrito algo que suena a peligro: no se corrige y se ofrecen los teléfonos de ayuda).
enum TipoCorreccion { acierto, fallo, neutra, ayuda }

/// Panel que sube desde abajo después de «Comprobar»: si es correcto o no, la respuesta correcta, la explicación,
/// la fuente y «Continuar». Se anuncia solo al lector de pantalla.
///
/// Los detalles se desplazan dentro del panel (con la barra siempre a la vista, para que se note que hay más) y
/// «Continuar» no se mueve de abajo.
class PanelCorreccion extends StatefulWidget {
  const PanelCorreccion({
    super.key,
    required this.tipo,
    required this.titulo,
    required this.onContinuar,
    this.detalle,
    this.explicacion = '',
    this.terminos = const [],
    this.fuente = '',
    this.xp = 0,
    this.textoRacha,
    this.textoBoton = 'Continuar',
    this.onReintentar,
    this.onEscuchar,
    this.hablando,
    this.altoDisponible,
  });

  final TipoCorreccion tipo;
  final String titulo;

  /// La respuesta correcta, las ideas de «Dilo»…
  final Widget? detalle;
  final String explicacion;

  /// Términos del Glosario: en la explicación salen subrayados y, al tocarlos, se abre su definición.
  final List<String> terminos;
  final String fuente;
  final int xp;

  /// «¡3 seguidas!», si toca.
  final String? textoRacha;
  final String textoBoton;
  final VoidCallback onContinuar;

  /// Si no se ha podido corregir («Dilo» sin conexión): «Volver a intentarlo», encima de «Continuar».
  final VoidCallback? onReintentar;

  /// Leer la corrección en voz alta (o pararla). Con [hablando], el botón cambia a «Parar».
  final VoidCallback? onEscuchar;
  final ValueListenable<bool>? hablando;

  /// Alto que comparten el ejercicio y el panel (debajo de la barra de progreso). El panel ocupa como mucho una parte
  /// y, si no cabe todo, los detalles se desplazan. Si es null, el alto de la pantalla.
  final double? altoDisponible;

  @override
  State<PanelCorreccion> createState() => _PanelCorreccionState();
}

class _PanelCorreccionState extends State<PanelCorreccion> {
  final _desplazamiento = ScrollController();

  @override
  void dispose() {
    _desplazamiento.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final exito = context.colores.exito;
    final tipo = widget.tipo;
    final (Color acento, Color sobreAcento, IconData icono) = switch (tipo) {
      TipoCorreccion.acierto => (exito, context.colores.sobreExito, Icons.check_rounded),
      // El rojo de la marca es para Ayuda y los errores: fallar es parte de aprender, con una bombilla y el color
      // terciario, como en Vive el caso.
      TipoCorreccion.fallo => (esquema.tertiary, esquema.onTertiary, Icons.lightbulb_rounded),
      TipoCorreccion.neutra => (esquema.primary, esquema.onPrimary, Icons.info_rounded),
      TipoCorreccion.ayuda => (esquema.primary, esquema.onPrimary, Icons.favorite_rounded),
    };
    final alto = widget.altoDisponible ?? MediaQuery.sizeOf(context).height;
    final letraGrande = MediaQuery.textScalerOf(context).scale(1) > 1.15;
    // Lo más que ocupa el panel: con letra grande, más; con la ayuda, más todavía (sus botones tienen que verse). Lo
    // que no quepa se desplaza dentro y «Continuar» se queda siempre abajo, a la vista.
    final ayuda = tipo == TipoCorreccion.ayuda;
    final tope = alto * (ayuda ? 0.95 : (letraGrande ? 0.75 : 0.65));
    final detalle = widget.detalle;
    final textoRacha = widget.textoRacha;
    final explicacion = widget.explicacion;
    final fuente = widget.fuente;
    final hayDetalles = detalle != null || explicacion.isNotEmpty || fuente.isNotEmpty;
    final onEscuchar = widget.onEscuchar;
    final hablando = widget.hablando;
    final onReintentar = widget.onReintentar;
    final continuar = Text(widget.textoBoton);

    return ConstrainedBox(
      key: const ValueKey('panel-correccion'),
      constraints: BoxConstraints(maxHeight: tope),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: esquema.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Radios.l)),
          boxShadow: [
            BoxShadow(
              color: esquema.shadow.withValues(alpha: 0.12),
              blurRadius: Espacio.l,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fondoAcento(context, acento),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(Radios.l)),
            border: Border(top: BorderSide(color: bordeTinte(acento), width: 2)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.m, Espacio.m, Espacio.s + Espacio.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      // Solo el título y los puntos se anuncian solos; el botón de escuchar va aparte.
                      child: Semantics(
                        liveRegion: true,
                        container: true,
                        child: Row(
                          children: [
                            // Con la ayuda, sin adornos y con el título más pequeño: lo que importa es la tarjeta
                            // de los teléfonos, que tiene que caber.
                            if (!ayuda) ...[
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.4, end: 1),
                                duration: duracion(context, Duracion.larga),
                                curve: Curves.elasticOut,
                                builder: (context, escala, hijo) => Transform.scale(scale: escala, child: hijo),
                                child: Container(
                                  width: Espacio.xl + Espacio.s,
                                  height: Espacio.xl + Espacio.s,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: acento),
                                  child: Icon(icono, color: sobreAcento, size: Espacio.l + 2),
                                ),
                              ),
                              const SizedBox(width: Espacio.m - 4),
                            ],
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(
                                  widget.titulo,
                                  style: (ayuda ? tema.textTheme.titleMedium : tema.textTheme.titleLarge)?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: esquema.onSurface,
                                  ),
                                ),
                              ),
                            ),
                            if (widget.xp > 0) ...[const SizedBox(width: Espacio.s), _ChapaXp(xp: widget.xp)],
                          ],
                        ),
                      ),
                    ),
                    if (onEscuchar != null && hablando != null)
                      ValueListenableBuilder<bool>(
                        valueListenable: hablando,
                        builder: (context, leyendo, _) => IconButton(
                          key: const ValueKey('boton-escuchar-correccion'),
                          tooltip: leyendo ? 'Parar la lectura' : 'Escuchar la explicación',
                          onPressed: onEscuchar,
                          color: esquema.onSurface,
                          icon: Icon(leyendo ? Icons.stop_rounded : Icons.volume_up_rounded),
                        ),
                      ),
                  ],
                ),
                if (textoRacha != null) ...[
                  const SizedBox(height: Espacio.s),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: PastillaDato(
                      icono: Icons.local_fire_department_rounded,
                      texto: Text(textoRacha),
                      semantica: textoRacha,
                      colorTexto: esquema.onSurface,
                      colorIcono: esquema.tertiary,
                      fondo: esquema.surface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
                if (hayDetalles) ...[
                  const SizedBox(height: Espacio.s + Espacio.xs),
                  // Con letra grande o mucho texto, los detalles se desplazan y «Continuar» sigue a la vista. La barra
                  // siempre visible avisa de que hay más debajo.
                  Flexible(
                    child: Scrollbar(
                      controller: _desplazamiento,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _desplazamiento,
                        // Hueco a la derecha para que la barra no tape el texto.
                        padding: const EdgeInsetsDirectional.only(end: Espacio.s + Espacio.xs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (detalle != null) ...[detalle, const SizedBox(height: Espacio.s)],
                            if (explicacion.isNotEmpty) ...[
                              TextoConTerminos(
                                texto: explicacion,
                                terminos: widget.terminos,
                                style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurface),
                              ),
                              const SizedBox(height: Espacio.s + Espacio.xs),
                            ],
                            if (fuente.isNotEmpty)
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: ChipFuente(fuente: fuente),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: Espacio.m - 4),
                if (onReintentar != null) ...[
                  OutlinedButton.icon(
                    key: const ValueKey('boton-reintentar'),
                    onPressed: onReintentar,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text(textoVolverAIntentar),
                  ),
                  const SizedBox(height: Espacio.s),
                ],
                // Con la ayuda, lo principal es llamar: seguir con la lección queda en segundo plano.
                if (ayuda)
                  OutlinedButton(
                    key: const ValueKey('boton-continuar'),
                    onPressed: widget.onContinuar,
                    child: continuar,
                  )
                else
                  FilledButton(
                    key: const ValueKey('boton-continuar'),
                    style: tipo == TipoCorreccion.acierto
                        ? FilledButton.styleFrom(backgroundColor: exito, foregroundColor: context.colores.sobreExito)
                        : null,
                    onPressed: widget.onContinuar,
                    child: continuar,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChapaXp extends StatelessWidget {
  const _ChapaXp({required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duracion(context, Duracion.larga),
      curve: Curves.easeOutBack,
      builder: (context, t, hijo) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * Espacio.m), child: hijo),
      ),
      child: PastillaDato(
        icono: Icons.bolt_rounded,
        texto: Text('+$xp XP'),
        semantica: 'Has ganado $xp puntos',
        colorTexto: esquema.onSurface,
        colorIcono: esquema.tertiary,
        fondo: esquema.surface,
      ),
    );
  }
}

/// La respuesta correcta dicha con palabras, para leerla en voz alta. null en «Dilo» (allí se leen las ideas).
String? textoRespuestaCorrecta(Ejercicio ejercicio) => switch (ejercicio) {
  EjercicioEleccion(:final opciones, :final correcta) => 'La respuesta correcta es: ${opciones[correcta]}.',
  EjercicioVf(:final correcta) => correcta ? 'Es verdadero.' : 'Es falso.',
  EjercicioOrdenar(:final pasos) => 'El orden correcto es: ${pasos.join('. ')}.',
  EjercicioEmparejar(:final pares) =>
    'Las parejas correctas son: ${[for (final (a, b) in pares) '$a, con $b'].join('. ')}.',
  EjercicioDilo() => null,
};

/// La respuesta correcta de un ejercicio, para cuando se ha fallado.
Widget? respuestaCorrecta(BuildContext context, Ejercicio ejercicio) {
  final tema = Theme.of(context);
  final esquema = tema.colorScheme;
  final etiqueta = tema.textTheme.labelLarge?.copyWith(color: esquema.onSurfaceVariant, fontWeight: FontWeight.w700);
  final valor = tema.textTheme.titleMedium?.copyWith(color: esquema.onSurface, fontWeight: FontWeight.w700);
  Widget lista(String titulo, List<String> filas) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(titulo, style: etiqueta),
      const SizedBox(height: Espacio.xs),
      for (final (i, fila) in filas.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: Espacio.xs),
          child: Text('${i + 1}. $fila', style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurface)),
        ),
    ],
  );
  return switch (ejercicio) {
    EjercicioEleccion(:final opciones, :final correcta) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Respuesta correcta', style: etiqueta),
        Text(opciones[correcta], style: valor),
      ],
    ),
    EjercicioVf(:final correcta) => Text(correcta ? 'Es verdadero.' : 'Es falso.', style: valor),
    EjercicioOrdenar(:final pasos) => lista('El orden correcto', pasos),
    EjercicioEmparejar(:final pares) => lista('Las parejas correctas', [for (final (a, b) in pares) '$a → $b']),
    EjercicioDilo() => null,
  };
}

/// El comentario del evaluador sin lo que ya se ve en el panel: sin el «¡Muy bien!» del principio (el panel ya tiene
/// título) y nada si solo repite las ideas que faltan, que ya salen en su recuadro. null si no queda nada que decir.
String? comentarioDilo(GradeResponse nota) {
  final texto = nota.feedback.trim().replaceFirst(RegExp(r'^¡[^!]*!\s*'), '').trim();
  if (texto.isEmpty) return null;
  final normal = normalizar(texto);
  String sinPunto(String idea) => normalizar(idea).replaceAll(RegExp(r'[\s.]+$'), '');
  final repite = nota.faltan.isNotEmpty && nota.faltan.every((idea) => normal.contains(sinPunto(idea)));
  return repite ? null : texto;
}

/// Ideas cubiertas y que faltan en «Dilo con tus palabras», con el comentario del evaluador. Lo que falta va aparte y
/// destacado (con una bombilla): es lo que la IA ha encontrado que falta, el momento importante del ejercicio.
class IdeasDilo extends StatelessWidget {
  const IdeasDilo({super.key, this.nota, this.proposiciones = const [], this.error});

  /// La corrección del backend. Si es null, se enseñan [proposiciones] como ideas clave.
  final GradeResponse? nota;
  final List<String> proposiciones;

  /// Por qué no se ha podido corregir (sin conexión, por ejemplo).
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final exito = context.colores.exito;
    final nota = this.nota;
    final error = this.error;
    final cuerpo = tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurface);
    final etiqueta = tema.textTheme.labelLarge?.copyWith(color: esquema.onSurface, fontWeight: FontWeight.w700);

    if (nota == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[Text(error, style: cuerpo), const SizedBox(height: Espacio.s + Espacio.xs)],
          Text(textoDiloIdeasClave, style: etiqueta),
          const SizedBox(height: Espacio.xs + 2),
          for (final p in proposiciones)
            Padding(
              padding: const EdgeInsets.only(bottom: Espacio.s),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_rounded, size: Espacio.l - 2, color: esquema.tertiary),
                  const SizedBox(width: Espacio.s),
                  Expanded(child: Text(p, style: cuerpo)),
                ],
              ),
            ),
        ],
      );
    }

    final total = nota.cubiertas.length + nota.faltan.length;
    final comentario = comentarioDilo(nota);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (total > 0) ...[
          Text(
            'Has explicado ${nota.cubiertas.length} de $total ideas',
            style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: esquema.onSurface),
          ),
          const SizedBox(height: Espacio.s),
          BarraProgreso(
            valor: nota.cubiertas.length / total,
            desde: 0,
            alto: Espacio.s + 2,
            etiqueta: 'Ideas explicadas',
            valorTexto: '${nota.cubiertas.length} de $total',
            colores: [exito, exito],
          ),
          const SizedBox(height: Espacio.m - 4),
        ],
        for (final c in nota.cubiertas)
          Padding(
            padding: const EdgeInsets.only(bottom: Espacio.s),
            child: MergeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: Espacio.l - 2,
                    color: exito,
                    semanticLabel: 'La has explicado',
                  ),
                  const SizedBox(width: Espacio.s),
                  Expanded(child: Text(c, style: cuerpo)),
                ],
              ),
            ),
          ),
        if (nota.faltan.isNotEmpty) ...[
          const SizedBox(height: Espacio.xs),
          Semantics(header: true, child: Text(textoDiloTeFalta, style: etiqueta)),
          const SizedBox(height: Espacio.xs + 2),
          for (final (i, f) in nota.faltan.indexed)
            Aparece(
              orden: i + 1,
              desplazamiento: Espacio.s,
              child: Padding(
                padding: const EdgeInsets.only(bottom: Espacio.s),
                child: _IdeaQueFalta(texto: f),
              ),
            ),
        ],
        if (comentario != null) ...[const SizedBox(height: Espacio.xs), Text(comentario, style: cuerpo)],
      ],
    );
  }
}

/// Una idea que falta, en su recuadro: papel claro con borde y bombilla del color terciario, y el texto en negrita.
class _IdeaQueFalta extends StatelessWidget {
  const _IdeaQueFalta({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final claro = esquema.brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(Espacio.s + Espacio.xs),
      decoration: BoxDecoration(
        color: claro ? esquema.surface : esquema.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radios.s),
        border: Border.all(color: esquema.tertiary.withValues(alpha: 0.7), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(Icons.lightbulb_rounded, size: Espacio.l - 2, color: esquema.tertiary),
          ),
          const SizedBox(width: Espacio.s),
          Expanded(
            child: Text(
              texto,
              style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurface, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lo que sale en «Dilo» cuando lo escrito suena a peligro: la tarjeta roja de Ayuda (la misma de Pregunta, con ANAR y
/// el 112) y, debajo, que también puede hablar con un adulto de confianza. Sin corrección y sin puntos.
class AyudaDilo extends StatelessWidget {
  const AyudaDilo({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TarjetaCrisis(key: ValueKey('tarjeta-crisis-dilo')),
        const SizedBox(height: Espacio.m - 4),
        Text(textoAyudaDiloResto, style: tema.textTheme.bodyLarge?.copyWith(color: tema.colorScheme.onSurface)),
      ],
    );
  }
}
