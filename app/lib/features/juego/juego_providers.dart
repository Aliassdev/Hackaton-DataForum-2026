import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/progreso.dart';
import '../../core/providers.dart';
import '../../core/texto.dart';
import 'modelos.dart';
import 'motor.dart';

/// Puntos por cada carta que entra por primera vez en la colección.
const xpPorCarta = 10;

/// Casos oficiales del reto, en este orden (el de Lucía, primero). Los demás van detrás, por título.
const ordenCasos = ['caso-sala-gesell', 'caso-acoso-escolar'];

/// Los casos de `juego/` (o los de ejemplo, mientras content/ esté vacío). Solo los validados, salvo los borradores
/// en modo DEMO.
final casosProvider = FutureProvider<List<Caso>>((ref) async {
  final repo = ref.watch(contentProvider);
  final casos = <Caso>[];
  final vistos = <String>{};
  for (final fichero in await repo.listar('juego')) {
    final caso = Caso.tryParse(await repo.json(fichero));
    if (caso == null || !(caso.validado || repo.mostrarBorradores) || !vistos.add(caso.id)) continue;
    casos.add(caso);
  }
  return casos..sort(compararCasos);
});

/// Primero los oficiales en [ordenCasos]; después, por título.
int compararCasos(Caso a, Caso b) {
  int posicion(Caso c) {
    final i = ordenCasos.indexOf(c.id);
    return i < 0 ? ordenCasos.length : i;
  }

  final orden = posicion(a).compareTo(posicion(b));
  return orden != 0 ? orden : normalizar(a.titulo).compareTo(normalizar(b.titulo));
}

/// Todas las cartas de los casos visibles, sin repetir, con el caso donde se ganan.
List<({Carta carta, Caso caso})> coleccionDe(List<Caso> casos) {
  final vistas = <String>{};
  return [
    for (final caso in casos)
      for (final carta in caso.cartas)
        if (vistas.add(carta.id)) (carta: carta, caso: caso),
  ];
}

/// Posición de una carta en la colección: así cada carta tiene siempre el mismo color, aquí y en el juego.
int indiceEnColeccion(List<Caso> casos, String cartaId) {
  final i = coleccionDe(casos).indexWhere((e) => e.carta.id == cartaId);
  return i < 0 ? 0 : i;
}

class CasoNoEncontrado implements Exception {
  const CasoNoEncontrado(this.casoId);

  final String casoId;

  @override
  String toString() => 'CasoNoEncontrado($casoId)';
}

/// La partida de cada caso. Vive mientras la app está abierta: si sales a mitad, al volver sigues donde lo dejaste.
/// Las cartas y los casos terminados se guardan en el móvil (progresoProvider).
final partidaProvider = AsyncNotifierProvider.family<PartidaNotifier, Partida, String>(
  PartidaNotifier.new,
  // Un caso que no existe no va a aparecer por reintentar.
  retry: (_, _) => null,
);

class PartidaNotifier extends AsyncNotifier<Partida> {
  PartidaNotifier(this.casoId);

  final String casoId;

  @override
  Future<Partida> build() async {
    final casos = await ref.watch(casosProvider.future);
    for (final caso in casos) {
      if (caso.id == casoId) return Partida.nueva(caso);
    }
    throw CasoNoEncontrado(casoId);
  }

  Partida? get _actual => state.value;

  /// Elige una opción. Si da una carta que no se tenía, se guarda en la colección y suma [xpPorCarta].
  Future<void> elegir(int indice) async {
    final actual = _actual;
    if (actual == null) return;
    final nueva = actual.elegir(indice, coleccion: ref.read(progresoProvider).cartas);
    if (identical(nueva, actual)) return;
    state = AsyncData(nueva);
    final carta = nueva.cartaNueva;
    if (carta == null) return;
    final progreso = ref.read(progresoProvider.notifier);
    await progreso.desbloquearCarta(carta.id);
    await progreso.sumarXp(xpPorCarta);
  }

  /// Vuelve a elegir tras una respuesta que no era la correcta.
  void reintentar() {
    final actual = _actual;
    if (actual != null) state = AsyncData(actual.reintentar());
  }

  /// Pasa a la escena siguiente. Al llegar al final, el caso queda guardado como terminado.
  Future<void> avanzar() async {
    final actual = _actual;
    if (actual == null) return;
    final nueva = actual.avanzar();
    if (identical(nueva, actual)) return;
    state = AsyncData(nueva);
    if (nueva.terminada) await ref.read(progresoProvider.notifier).terminarCaso(casoId);
  }

  /// Vuelve a la primera escena. Las cartas ya ganadas siguen en la colección.
  void reiniciar() {
    final actual = _actual;
    if (actual != null) state = AsyncData(Partida.nueva(actual.caso));
  }
}
