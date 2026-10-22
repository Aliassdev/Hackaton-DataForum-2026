import 'dart:async';

import 'package:flutter/material.dart';

import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../../../widgets/justicia/justicia.dart';
import '../../../widgets/movimiento/confeti_papel.dart';
import '../../../widgets/movimiento/contador_flip.dart';
import '../../../widgets/movimiento/hapticos.dart';
import '../../../widgets/movimiento/pop_pegatina.dart';
import '../bkt.dart';
import '../textos.dart';
import 'comunes.dart';

/// Un concepto que ha subido en la sesión.
typedef Mejora = ({String nombre, double antes, double despues});

/// Pantalla final de una lección o una práctica: cae el sello de tinta («SUPERADA» o «REPASADO») y, al golpear el
/// papel, el confeti (los dos solo aquí, al terminar). Debajo, los XP ganados (como un panel de turnos), la racha, los
/// aciertos, la mejor racha si se ha batido y los conceptos que han mejorado, con su balanza equilibrándose.
///
/// Con «reducir animaciones», el sello aparece ya puesto y no hay confeti.
///
/// Sus botones no responden durante un momento al aparecer: así el segundo toque de un doble toque en «Terminar» no
/// pulsa sin querer «Siguiente», que sale justo debajo del dedo.
class Celebracion extends StatefulWidget {
  const Celebracion({
    super.key,
    required this.sello,
    required this.titulo,
    required this.subtitulo,
    this.detalle,
    required this.xp,
    required this.racha,
    required this.rachaSube,
    this.record,
    required this.aciertos,
    required this.respondidas,
    required this.mejoras,
    required this.botones,
  });

  /// [TipoSello.leccion] al terminar una lección y [TipoSello.practica] al terminar un repaso.
  final TipoSello sello;
  final String titulo;
  final String subtitulo;

  /// El nombre de la lección o de la unidad.
  final String? detalle;
  final int xp;
  final int racha;

  /// La racha ha subido hoy con esta lección.
  final bool rachaSube;

  /// La nueva mejor racha, si se acaba de batir.
  final int? record;
  final int aciertos;
  final int respondidas;
  final List<Mejora> mejoras;
  final List<Widget> botones;

  /// Lo que tardan los botones en responder al aparecer.
  static const esperaBotones = Duration(milliseconds: 450);

  /// Desde dónde salta el confeti: el sello.
  static const origenConfeti = Alignment(0, -0.55);

  @override
  State<Celebracion> createState() => _CelebracionState();
}

class _CelebracionState extends State<Celebracion> {
  var _botonesActivos = false;
  Timer? _espera;

  @override
  void initState() {
    super.initState();
    _espera = Timer(Celebracion.esperaBotones, () {
      if (mounted) setState(() => _botonesActivos = true);
    });
  }

  @override
  void dispose() {
    _espera?.cancel();
    super.dispose();
  }

  /// El sello golpea el papel: confeti de papel por toda la pantalla (no sale con «reducir animaciones»).
  void _alEstampar() {
    if (mounted) lanzarConfeti(context, origen: Celebracion.origenConfeti);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final colores = context.colores;
    final Celebracion(:titulo, :subtitulo, :detalle, :xp, :racha, :rachaSube, :record, :aciertos, :respondidas) =
        widget;
    final mejoras = widget.mejoras;
    final dominados = [
      for (final m in mejoras)
        if (Bkt.dominado(m.despues) && !Bkt.dominado(m.antes)) m.nombre,
    ];
    final cifras = estiloCifras(tema.textTheme.headlineSmall)?.copyWith(color: esquema.onSurface);
    var orden = 0;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: anchoMaximoAprende),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.l, Espacio.m, Espacio.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SelloJusticia(
                  key: const ValueKey('sello-celebracion'),
                  tipo: widget.sello,
                  tamano: 148,
                  alEstampar: _alEstampar,
                ),
              ),
              const SizedBox(height: Espacio.l),
              Aparece(
                orden: orden++,
                child: Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(titulo, textAlign: TextAlign.center, style: tema.textTheme.headlineMedium),
                ),
              ),
              const SizedBox(height: Espacio.xs),
              Aparece(
                orden: orden++,
                child: Text(
                  subtitulo,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.titleMedium?.copyWith(color: esquema.onSurfaceVariant),
                ),
              ),
              if (detalle != null && detalle.isNotEmpty)
                Aparece(
                  orden: orden++,
                  child: Text(
                    detalle,
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                  ),
                ),
              const SizedBox(height: Espacio.l),
              Aparece(
                orden: orden++,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Dato(
                        icono: TuIcono.xp,
                        color: esquema.tertiary,
                        // Los puntos giran como el panel de turnos, desde cero.
                        valor: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('+', style: cifras),
                            const SizedBox(width: Espacio.xs / 2),
                            ContadorFlip(valor: xp, desde: 0, digitos: '$xp'.length, estilo: tema.textTheme.titleLarge),
                          ],
                        ),
                        etiqueta: 'puntos XP',
                        semantica: 'Has ganado $xp puntos de experiencia',
                      ),
                    ),
                    const SizedBox(width: Espacio.s),
                    Expanded(
                      child: _Dato(
                        icono: TuIcono.racha,
                        color: colores.juego.first,
                        valor: Text('$racha', style: cifras),
                        etiqueta: racha == 1 ? 'día de racha' : 'días de racha',
                        insignia: rachaSube ? '+1' : null,
                        semantica: 'Racha de ${textoDias(racha)}${rachaSube ? '. Ha subido hoy' : ''}',
                      ),
                    ),
                    const SizedBox(width: Espacio.s),
                    Expanded(
                      child: _Dato(
                        icono: TuIcono.check,
                        color: colores.exito,
                        valor: Text('$aciertos/$respondidas', style: cifras),
                        etiqueta: 'aciertos',
                        semantica: '$aciertos aciertos de $respondidas',
                      ),
                    ),
                  ],
                ),
              ),
              if (record != null) ...[
                const SizedBox(height: Espacio.m),
                Center(
                  child: PopPegatina(
                    retraso: const Duration(milliseconds: 700),
                    vibrar: true,
                    child: _MejorRacha(dias: record),
                  ),
                ),
              ],
              const SizedBox(height: Espacio.m),
              Aparece(
                orden: orden++,
                child: Text(
                  animoFinal(aciertos: aciertos, total: respondidas),
                  textAlign: TextAlign.center,
                  style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: Espacio.l),
              Aparece(
                orden: orden++,
                child: _TarjetaMejoras(mejoras: mejoras, dominados: dominados),
              ),
              const SizedBox(height: Espacio.l),
              for (final boton in widget.botones) ...[
                Aparece(
                  orden: orden++,
                  child: IgnorePointer(ignoring: !_botonesActivos, child: boton),
                ),
                const SizedBox(height: Espacio.s + Espacio.xs),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// «¡Tu mejor racha! 5 días.», como una pegatina amarilla.
class _MejorRacha extends StatelessWidget {
  const _MejorRacha({required this.dias});

  final int dias;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final pegatina = colorPegatina(context);
    return DecoratedBox(
      key: const ValueKey('mejor-racha'),
      decoration: ShapeDecoration(
        color: pegatina.fondo,
        shape: StadiumBorder(side: BorderSide(color: pegatina.tinta, width: 2)),
        shadows: [BoxShadow(color: sombraPapelDe(context), offset: const Offset(1.5, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Espacio.m, vertical: Espacio.s),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconoTuTurno(TuIcono.racha, size: Espacio.l, decorativo: true),
            const SizedBox(width: Espacio.s),
            Flexible(
              child: Text(
                textoMejorRacha(dias),
                style: tema.textTheme.titleSmall?.copyWith(color: pegatina.tinta, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.icono,
    required this.color,
    required this.valor,
    required this.etiqueta,
    required this.semantica,
    this.insignia,
  });

  final TuIcono icono;
  final Color color;
  final Widget valor;
  final String etiqueta;
  final String semantica;
  final String? insignia;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final insignia = this.insignia;
    return Semantics(
      container: true,
      label: semantica,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Espacio.s, vertical: Espacio.m),
        decoration: BoxDecoration(
          color: fondoAcento(context, color),
          border: Border.all(color: bordeTinte(color)),
          borderRadius: BorderRadius.circular(Radios.m),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconoTuTurno(icono, size: Espacio.xl + Espacio.xs, decorativo: true),
                if (insignia != null)
                  Positioned(
                    right: -Espacio.m,
                    top: -Espacio.xs,
                    // Una recompensa: se pega como una pegatina.
                    child: PopPegatina(
                      retraso: const Duration(milliseconds: 500),
                      child: DecoratedBox(
                        decoration: ShapeDecoration(color: color, shape: const StadiumBorder()),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Espacio.xs + 2, vertical: 1),
                          child: Text(
                            insignia,
                            style: estiloCifras(tema.textTheme.labelMedium)?.copyWith(color: sobreColor(color)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Espacio.xs),
            SizedBox(
              height: Espacio.xl + Espacio.s,
              child: FittedBox(fit: BoxFit.scaleDown, child: valor),
            ),
            Text(
              etiqueta,
              textAlign: TextAlign.center,
              style: tema.textTheme.labelLarge?.copyWith(color: esquema.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaMejoras extends StatelessWidget {
  const _TarjetaMejoras({required this.mejoras, required this.dominados});

  final List<Mejora> mejoras;
  final List<String> dominados;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Container(
      padding: const EdgeInsets.all(Espacio.l - Espacio.xs),
      decoration: decoracionPapel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconoTuTurno(TuIcono.balanza, size: Espacio.l + Espacio.xs, decorativo: true),
              const SizedBox(width: Espacio.s),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    mejoras.isEmpty ? 'Lo que has practicado' : 'Lo que has mejorado',
                    style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Espacio.m),
          if (mejoras.isEmpty)
            Text(
              'Esta vez no ha subido ningún concepto. No pasa nada: cada intento te ayuda a aprender.',
              style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurface),
            )
          else ...[
            Text(textoBalanza, style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
            const SizedBox(height: Espacio.m - 4),
            for (final m in mejoras) ...[
              BarraDominio(
                nombre: m.nombre,
                p: m.despues,
                desde: m.antes,
                compacta: true,
                conEstado: true,
                alEquilibrar: Hapticos.acierto,
              ),
              const SizedBox(height: Espacio.m - 4),
            ],
          ],
          for (final nombre in dominados)
            Padding(
              padding: const EdgeInsets.only(top: Espacio.xs),
              child: Row(
                children: [
                  PopPegatina(
                    retraso: const Duration(milliseconds: 900),
                    child: const IconoTuTurno(TuIcono.selloConseguido, size: Espacio.l + Espacio.xs, decorativo: true),
                  ),
                  const SizedBox(width: Espacio.s),
                  Expanded(
                    child: Text(
                      '¡Ya dominas «$nombre»!',
                      style: tema.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: esquema.onSurface),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
