import 'package:flutter/material.dart';

import '../../../tema.dart';
import '../../../widgets/iconos/iconos.dart';
import '../../pasos/fuentes_paso.dart';
import '../../pasos/linea_pasos.dart' show BotonApuntar, TextoCorto;
import '../../pasos/personalizacion_linea.dart' show EstiloExplicacion;
import '../personalizacion.dart';
import '../textos.dart';
import 'comunes.dart';

/// Cuántos derechos se ven antes de «Ver los N derechos».
const derechosVisibles = 4;

/// Origen de lo que se apunta desde aquí en «Mis preguntas».
const origenDerechos = 'Tus derechos';

/// «Tus derechos»: los de tu papel y tu edad, como cartas, primero los que tienen que ver con lo que te preocupa. Cada
/// uno con su fuente y «Apuntar» en «Mis preguntas».
class MazoDerechos extends StatefulWidget {
  const MazoDerechos({super.key, required this.derechos, this.estilo});

  final List<DerechoParaTi> derechos;
  final EstiloExplicacion? estilo;

  @override
  State<MazoDerechos> createState() => _MazoDerechosState();
}

class _MazoDerechosState extends State<MazoDerechos> {
  var _todos = false;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final derechos = widget.derechos;
    if (derechos.isEmpty) {
      return Text(
        'Estoy preparando tus derechos. Mientras tanto, puedes preguntarme por ellos.',
        style: tema.textTheme.bodyLarge,
      );
    }
    final visibles = _todos || derechos.length <= derechosVisibles + 1 ? derechos : derechos.take(derechosVisibles);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(textoDerechos, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
        const SizedBox(height: Espacio.s + Espacio.xs),
        for (final derecho in visibles)
          Padding(
            padding: const EdgeInsets.only(bottom: Espacio.s + Espacio.xs),
            child: CartaDerecho(derecho: derecho, estilo: widget.estilo),
          ),
        if (visibles.length < derechos.length)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton(
              onPressed: () => setState(() => _todos = true),
              child: Text('Ver los ${derechos.length} derechos'),
            ),
          ),
      ],
    );
  }
}

/// Un derecho como una carta: el título con la mano alzada, por qué te sale («Por tu edad»), el texto (con «Corto», la
/// primera frase y «Leer todo», como en los pasos), un ejemplo de «Vive el caso» si lo prefieres con ejemplos, sus
/// fuentes y «Apuntar».
class CartaDerecho extends StatelessWidget {
  const CartaDerecho({super.key, required this.derecho, this.estilo});

  final DerechoParaTi derecho;
  final EstiloExplicacion? estilo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final colores = context.colores;
    final d = derecho.derecho;
    final citas = CitaPaso.de(d.fuentes);
    final etiquetas = [
      if (derecho.porLoQueTePreocupa) etiquetaTePreocupa,
      if (derecho.porTuEdad) etiquetaPorTuEdad,
      ?derecho.etiquetaEdad,
      ?d.condicionTexto,
    ];
    final ejemplo = d.ejemplo;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colores.ticket,
        borderRadius: BorderRadius.circular(Radios.m),
        border: Border.all(color: esquema.outlineVariant),
        boxShadow: sombrasPapel(context, elevacion: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Espacio.m, Espacio.s + Espacio.xs, Espacio.xs, Espacio.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: Espacio.xs),
                  child: IconoTuTurno(TuIcono.manoAlzada, size: Espacio.l + Espacio.xs, decorativo: true),
                ),
                const SizedBox(width: Espacio.s + Espacio.xs),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: Espacio.xs),
                    child: Semantics(
                      header: true,
                      child: Text(
                        d.titulo,
                        style: tema.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colores.tintaTicket,
                        ),
                      ),
                    ),
                  ),
                ),
                BotonApuntar(texto: d.titulo, origen: origenDerechos, fuentes: d.fuentes),
              ],
            ),
            if (etiquetas.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Espacio.xs, right: Espacio.s),
                child: Wrap(
                  spacing: Espacio.xs + 2,
                  runSpacing: Espacio.xs,
                  children: [for (final e in etiquetas) Pegatina(texto: e)],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: Espacio.s, right: Espacio.s),
              child: estilo == EstiloExplicacion.corto
                  ? TextoCorto(
                      texto: d.texto,
                      estilo: tema.textTheme.bodyLarge?.copyWith(color: colores.tintaTicket),
                    )
                  : Text(d.texto, style: tema.textTheme.bodyLarge?.copyWith(color: colores.tintaTicket)),
            ),
            if (estilo == EstiloExplicacion.ejemplos && ejemplo != null)
              Padding(
                padding: const EdgeInsets.only(top: Espacio.s, right: Espacio.s),
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Por ejemplo: ',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: ejemplo),
                    ],
                  ),
                  style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                ),
              ),
            if (citas.isNotEmpty)
              Wrap(
                spacing: Espacio.s,
                children: [for (final cita in citas) ChipFuentePaso(cita: cita, paso: d.titulo)],
              ),
          ],
        ),
      ),
    );
  }
}
