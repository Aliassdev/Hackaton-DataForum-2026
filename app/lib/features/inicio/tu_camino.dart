import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entrada.dart';
import '../situacion/papel.dart';

/// «Tu camino»: Mi situación con el papel del ticket que se rellena en Pregunta ([Entrada], lib/core/entrada.dart).
///
/// El papel y su ruta son los de Mi situación ([PapelSituacion], de lib/features/situacion/papel.dart): con papel
/// (víctima, testigo, investigado o escuchado en familia), el inicio lleva directo a su línea de pasos
/// (`/situacion/<papel>`; escuchado en familia, `/situacion/escuchado_familia`) y lo recuerda en el saludo; allí, si la
/// Entrada tiene fase, Mi situación marca «Estás aquí». Sin papel o con «No lo sé», el papel se elige en la hoja de
/// siempre. Habla del proceso, nunca de lo que pasó.
///
/// El inicio es lo primero que ve cualquiera que coja el móvil, y el móvil puede ser compartido (en el caso de Lucía,
/// quien hace daño puede estar en casa): por eso aquí ni el título ni la descripción dicen el papel ni la fase
/// («Tu camino como víctima», «si te investigan»…). Eso solo se ve dentro de Mi situación.
@immutable
class TuCamino {
  const TuCamino(this.papel, {this.fase});

  /// El camino de [entrada], o null si no tiene papel (o es «No lo sé»).
  static TuCamino? de(Entrada entrada) {
    final papel = PapelSituacion.deEntrada(entrada.rol);
    return papel == null ? null : TuCamino(papel, fase: entrada.fase);
  }

  final PapelSituacion papel;
  final Fase? fase;

  /// La línea de pasos de Mi situación de este papel.
  String get ruta => papel.ruta;

  /// El título en el inicio: el mismo para todos los papeles (sin decir cuál).
  static const tituloNeutro = 'Tu camino';

  /// La descripción en el inicio: sin el papel ni la fase.
  static const descripcionNeutra = 'Tu guía, a tu medida: qué pasa en cada paso y qué puedes pedir.';

  String get titulo => tituloNeutro;

  String get descripcion => descripcionNeutra;

  @override
  bool operator ==(Object other) => other is TuCamino && other.papel == papel && other.fase == fase;

  @override
  int get hashCode => Object.hash(papel, fase);
}

/// El camino del ticket guardado (null si no tiene papel). Cambia en cuanto se rellena o se borra el ticket.
final tuCaminoProvider = Provider<TuCamino?>((ref) => TuCamino.de(ref.watch(entradaProvider)));
