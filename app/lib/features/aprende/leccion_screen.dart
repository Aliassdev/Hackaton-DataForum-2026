import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/tuturno_api.dart';
import '../../core/progreso.dart';
import '../../core/providers.dart';
import '../../core/seguridad.dart';
import '../../core/voz/stt.dart';
import '../../core/voz/tts.dart';
import '../../tema.dart';
import '../../widgets/estados.dart';
import '../../widgets/iconos/iconos.dart';
import '../../widgets/justicia/justicia.dart';
import '../../widgets/movimiento/contador_flip.dart';
import '../../widgets/movimiento/hapticos.dart';
import '../../widgets/tuturno_scaffold.dart';
import 'bkt.dart';
import 'correccion_local.dart';
import 'curso.dart';
import 'modelos.dart';
import 'seleccion.dart';
import 'textos.dart';
import 'widgets/celebracion.dart';
import 'widgets/comunes.dart';
import 'widgets/correccion.dart';
import 'widgets/ejercicio_dilo.dart';
import 'widgets/ejercicio_eleccion.dart';
import 'widgets/ejercicio_emparejar.dart';
import 'widgets/ejercicio_ordenar.dart';

// Reproductor de lecciones (sección 4.3): los 6 ejercicios uno a uno con barra de progreso, «Comprobar», panel de
// corrección con la explicación y la fuente, y al final el sello «SUPERADA» con los XP, la racha y los conceptos que
// han mejorado. +10 XP por acierto y +5 en «Dilo» si cubre al menos la mitad; el dominio (BKT) se actualiza
// después de cada respuesta. Con /aprende/leccion/practica-<unidad>, practica esa unidad (política de 10.6).
// En modo DEMO, /aprende/leccion/dilo-<lección> empieza la lección en su «Dilo con tus palabras».
//
// «Dilo» nunca se queda sin corregir: con servidor, POST /api/learn/grade; si no hay servidor, si falla, si no conoce
// el ejercicio o si tarda más de [esperaCorreccionDilo], se corrige en el móvil (correccion_local.dart) y se avisa
// de que es una corrección aproximada. Con la API simulada (USE_MOCK) no se le pregunta: devolvería siempre lo mismo.
//
// La voz: «Escuchar» lee el ejercicio o la corrección. La lectura se calla al comprobar, al seguir, al salir, al tapar
// la lección con otra pantalla (Ayuda, Glosario, una hoja…) y si la app pasa a segundo plano. Nunca se escucha
// mientras se habla (sección 6.5): leer apaga antes el micrófono de «Dilo».

/// XP por acierto.
const xpAcierto = 10;

/// XP en «Dilo con tus palabras» si cubre al menos la mitad de las ideas.
const xpDilo = 5;

/// Lo que se espera al servidor para corregir «Dilo». Si tarda más, se corrige en el móvil.
const esperaCorreccionDilo = Duration(seconds: 10);

class LeccionScreen extends ConsumerWidget {
  const LeccionScreen({super.key, required this.leccionId});

  final String leccionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curso = ref.watch(cursoProvider);
    return curso.when(
      loading: () => const TuTurnoScaffold(
        titulo: 'Aprende',
        body: Cargando(mensaje: 'Preparando la lección…'),
      ),
      error: (_, _) => TuTurnoScaffold(
        titulo: 'Aprende',
        body: EstadoError(
          mensaje: 'No he podido cargar la lección. Prueba otra vez.',
          onReintentar: () => ref.invalidate(cursoProvider),
        ),
      ),
      data: (curso) => _resolver(context, ref, curso),
    );
  }

  Widget _resolver(BuildContext context, WidgetRef ref, Curso curso) {
    if (leccionId.startsWith(prefijoPractica)) {
      final unidad = curso.unidad(leccionId.substring(prefijoPractica.length));
      if (unidad == null) return const _NoEncontrada();
      return _Reproductor(key: ValueKey(leccionId), curso: curso, unidad: unidad);
    }
    final demo = ref.watch(configProvider).demo;
    // El atajo de la demo solo vale en modo DEMO; fuera de él, abre la lección normal.
    final atajoDilo = leccionId.startsWith(prefijoDilo);
    final id = atajoDilo ? leccionId.substring(prefijoDilo.length) : leccionId;
    final leccion = curso.leccion(id);
    final unidad = curso.unidadDe(id);
    if (leccion == null || unidad == null) return const _NoEncontrada();
    final completadas = ref.watch(progresoProvider.select((p) => p.leccionesCompletadas));
    final abierta = curso.estado(leccion.id, completadas) != EstadoLeccion.bloqueada;
    if (!abierta && !demo) {
      return _Bloqueada(leccion: leccion, siguiente: curso.siguiente(completadas));
    }
    return _Reproductor(
      key: ValueKey(leccionId),
      curso: curso,
      unidad: unidad,
      leccion: leccion,
      empezarEnDilo: atajoDilo && demo,
    );
  }
}

enum _Fase { respondiendo, comprobando, revisado, terminada }

/// Resumen para la celebración. [record] es la nueva mejor racha, si se ha batido hoy (y es de 2 días o más).
typedef _Resumen = ({int racha, bool rachaSube, int? record, List<Mejora> mejoras});

class _Reproductor extends ConsumerStatefulWidget {
  const _Reproductor({super.key, required this.curso, required this.unidad, this.leccion, this.empezarEnDilo = false});

  final Curso curso;
  final Unidad unidad;

  /// null en una práctica.
  final Leccion? leccion;

  /// Modo DEMO: empieza en el «Dilo con tus palabras» de la lección (para enseñarlo en pocos segundos).
  final bool empezarEnDilo;

  bool get esPractica => leccion == null;

  @override
  ConsumerState<_Reproductor> createState() => _ReproductorState();
}

class _ReproductorState extends ConsumerState<_Reproductor> {
  static const _bkt = Bkt();
  static const _politica = PoliticaSeleccion();

  late final Tts _tts = ref.read(ttsProvider);
  late final AppLifecycleListener _ciclo;

  /// La lección está a la vista (ninguna pantalla ni hoja encima).
  var _rutaActual = true;

  /// Ejercicios de la sesión. En una práctica se van añadiendo según el dominio (10.6).
  final _cola = <Ejercicio>[];
  final _repasos = <String>{};
  late int _total;

  var _indice = 0;
  var _fase = _Fase.respondiendo;
  Object? _respuesta;

  // Corrección del ejercicio actual.
  bool? _acierto;
  GradeResponse? _nota;

  /// La corrección de «Dilo» se ha hecho en el móvil, sin servidor: es aproximada.
  var _notaAproximada = false;

  /// En «Dilo» se ha escrito algo que suena a peligro: no se corrige y se ofrece ayuda.
  var _crisis = false;

  /// Ya se está guardando el final: un segundo toque en «Terminar» no suma dos veces.
  var _terminando = false;

  // Marcador de la sesión.
  var _xp = 0;
  var _xpUltimo = 0;
  var _aciertos = 0;
  var _respondidas = 0;
  var _seguidos = 0;
  var _sacudidas = 0;
  final _antes = <String, double>{};
  final _despues = <String, double>{};
  _Resumen? _resumen;

  @override
  void initState() {
    super.initState();
    final leccion = widget.leccion;
    if (leccion != null) {
      _cola.addAll(widget.curso.ejerciciosDe(leccion));
      _total = _cola.length;
      if (widget.empezarEnDilo) {
        final dilo = _cola.indexWhere((e) => e is EjercicioDilo);
        if (dilo > 0) _indice = dilo;
      }
    } else {
      final disponibles = widget.curso.ejerciciosDeUnidad(widget.unidad).length;
      _total = math.min(PoliticaSeleccion.ejerciciosPorSesion, disponibles);
      if (!_anadirSiguiente()) _total = 0;
    }
    // El Glosario se empieza a cargar ya: cuando salga la primera explicación, sus términos estarán subrayados.
    ref.read(glosarioProvider);
    // Si la app se oculta (otra app, la pantalla apagada o, en web, otra pestaña), se deja de leer.
    _ciclo = AppLifecycleListener(onHide: _callar, onPause: _callar);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Si otra pantalla o una hoja tapa la lección (Ayuda, Glosario, la fuente…), se deja de leer.
    final actual = ModalRoute.isCurrentOf(context) ?? true;
    if (_rutaActual && !actual) _callar();
    _rutaActual = actual;
  }

  @override
  void dispose() {
    _ciclo.dispose();
    unawaited(_tts.parar());
    super.dispose();
  }

  void _callar() => unawaited(_tts.parar());

  /// Práctica: añade el siguiente ejercicio según la política de selección. false si ya no quedan.
  bool _anadirSiguiente() {
    final progreso = ref.read(progresoProvider);
    final elegido = _politica.siguiente(
      conceptos: widget.unidad.conceptos,
      ejercicios: widget.curso.ejerciciosDeUnidad(widget.unidad),
      dominio: progreso.dominio,
      ultimaPractica: progreso.ultimaPractica,
      vistos: {for (final e in _cola) e.id},
      ahora: ref.read(relojProvider)(),
    );
    if (elegido == null) return false;
    _cola.add(elegido.ejercicio);
    if (elegido.repaso) _repasos.add(elegido.ejercicio.id);
    return true;
  }

  Ejercicio get _actual => _cola[_indice];

  /// Título entero: el de la lección o, en una práctica, el de la unidad. Va encima de la barra de progreso.
  String get _titulo => widget.leccion?.titulo ?? widget.unidad.titulo;

  /// Título corto para la barra, que también lleva el Glosario y la Ayuda: «Lección 2» (como en el mapa) o
  /// «Practicar». Así no se corta en un móvil estrecho ni con letra grande.
  String get _tituloBarra {
    final leccion = widget.leccion;
    if (leccion == null) return 'Practicar';
    final posicion = widget.unidad.lecciones.indexWhere((l) => l.id == leccion.id);
    return posicion < 0 ? 'Aprende' : 'Lección ${posicion + 1}';
  }

  /// Se puede salir sin preguntar si aún no se ha respondido nada o si ya ha terminado.
  bool get _salidaLibre => _fase == _Fase.terminada || (_respondidas == 0 && _fase == _Fase.respondiendo);

  void _alResponder(Object? respuesta) {
    if (_fase != _Fase.respondiendo) return;
    setState(() => _respuesta = respuesta);
  }

  Future<void> _comprobar() async {
    final respuesta = _respuesta;
    if (respuesta == null || _fase != _Fase.respondiendo) return;
    // Lo que se estuviera leyendo ya no toca: ahora sale la corrección. Y el teclado se cierra para dejarle sitio.
    _callar();
    FocusManager.instance.primaryFocus?.unfocus();
    final ejercicio = _actual;
    final bool acierto;
    switch (ejercicio) {
      case EjercicioDilo():
        return _corregirDilo(ejercicio, respuesta as String);
      case EjercicioEleccion():
        acierto = ejercicio.esCorrecta(respuesta as int);
      case EjercicioVf():
        acierto = ejercicio.esCorrecta(respuesta as bool);
      case EjercicioOrdenar():
        acierto = ejercicio.esCorrecta(respuesta as List<int>);
      case EjercicioEmparejar():
        acierto = ejercicio.esCorrecta(respuesta as Map<int, int>);
    }
    _registrar(ejercicio, acierto: acierto, xp: acierto ? xpAcierto : 0);
  }

  Future<void> _corregirDilo(EjercicioDilo ejercicio, String texto) async {
    // Red de seguridad (sección 10.2, «ante la duda, ofrecer ayuda»): si lo escrito suena a peligro, no se corrige ni
    // se envía. Se enseñan los teléfonos de ayuda, sin puntos y sin tocar el dominio.
    if (pareceCrisis(texto)) {
      _crisis = true;
      _registrar(ejercicio, acierto: null, xp: 0);
      return;
    }
    setState(() => _fase = _Fase.comprobando);
    GradeResponse? nota;
    // La API simulada devuelve siempre la misma corrección, se escriba lo que se escriba: con ella no se pregunta.
    if (!ref.read(configProvider).useMock) {
      try {
        nota = await ref
            .read(apiProvider)
            .grade(GradeRequest(conceptoId: ejercicio.concepto, texto: texto))
            .timeout(esperaCorreccionDilo);
      } catch (_) {
        // Sin conexión, el servidor caído, un ejercicio que no conoce o que tarda demasiado: se corrige en el móvil.
        nota = null;
      }
      if (!mounted) return;
    }
    if (nota != null && esCorreccionDeCrisis(nota)) {
      // El servidor ha visto peligro donde la app no: tampoco se corrige, se ofrece ayuda.
      _crisis = true;
      _registrar(ejercicio, acierto: null, xp: 0);
      return;
    }
    final aproximada = nota == null;
    final corregida =
        nota ?? corregirEnElMovil(proposiciones: ejercicio.proposiciones, texto: texto, pregunta: ejercicio.pregunta);
    _nota = corregida;
    _notaAproximada = aproximada;
    final cubreLaMitad = corregida.puntuacion >= 0.5;
    // Una corrección aproximada nunca resta: si no llega a la mitad, el dominio no cambia (puede que lo hayas dicho
    // con otras palabras). Si llega, suma como siempre.
    _registrar(ejercicio, acierto: cubreLaMitad ? true : (aproximada ? null : false), xp: cubreLaMitad ? xpDilo : 0);
  }

  /// «Ahora no» en «Dilo»: se enseñan las ideas clave y se sigue, sin puntos y sin tocar el dominio. Si lo escrito
  /// suena a peligro, se ofrece ayuda igualmente.
  void _saltarDilo() {
    if (_fase != _Fase.respondiendo) return;
    _callar();
    FocusManager.instance.primaryFocus?.unfocus();
    final texto = _respuesta;
    if (texto is String && pareceCrisis(texto)) _crisis = true;
    _registrar(_actual, acierto: null, xp: 0);
  }

  /// Corrige: actualiza el dominio del concepto (BKT) y el marcador. Con [acierto] null no cuenta (saltado, ayuda o
  /// una corrección aproximada que no llega a la mitad) y el dominio no cambia.
  void _registrar(Ejercicio ejercicio, {required bool? acierto, required int xp}) {
    if (acierto != null) {
      final concepto = ejercicio.concepto;
      final antes = dominioDe(ref.read(progresoProvider).dominio, concepto);
      final despues = _bkt.actualizar(antes, acierto);
      _antes.putIfAbsent(concepto, () => antes);
      _despues[concepto] = despues;
      unawaited(ref.read(progresoProvider.notifier).actualizarDominio(concepto, despues));
      _respondidas++;
      if (acierto) {
        _aciertos++;
        _seguidos++;
        Hapticos.acierto();
      } else {
        // Un toque suave: fallar es parte de aprender.
        _seguidos = 0;
        _sacudidas++;
        Hapticos.toque();
      }
    } else {
      Hapticos.seleccion();
    }
    setState(() {
      _fase = _Fase.revisado;
      _acierto = acierto;
      _xp += xp;
      _xpUltimo = xp;
    });
  }

  Future<void> _continuar() async {
    // Solo una vez por corrección: un segundo toque mientras el panel se va (o mientras se guarda el final) no hace
    // nada. Si no, se saltaría el ejercicio siguiente sin responderlo o se sumarían dos veces los puntos.
    if (_fase != _Fase.revisado || _terminando) return;
    _callar();
    if (widget.esPractica && _indice == _cola.length - 1 && _cola.length < _total && !_anadirSiguiente()) {
      _total = _cola.length;
    }
    if (_indice + 1 < _cola.length) {
      setState(() {
        _indice++;
        _fase = _Fase.respondiendo;
        _respuesta = null;
        _acierto = null;
        _nota = null;
        _notaAproximada = false;
        _crisis = false;
        _xpUltimo = 0;
      });
      return;
    }
    _terminando = true;
    await _terminar();
  }

  Future<void> _terminar() async {
    final notifier = ref.read(progresoProvider.notifier);
    final ahora = ref.read(relojProvider)();
    final antes = estadoRacha(ref.read(progresoProvider), ahora);
    try {
      if (_xp > 0) await notifier.sumarXp(_xp);
      final leccion = widget.leccion;
      if (leccion != null) await notifier.completarLeccion(leccion.id);
    } catch (_) {
      // Si no se puede guardar en el móvil, el progreso de esta sesión sigue en memoria: la celebración sale igual.
    }
    if (!mounted) return;
    final despues = estadoRacha(ref.read(progresoProvider), ahora);
    final racha = despues.dias;
    final mejoras = <Mejora>[
      for (final MapEntry(key: concepto, value: despues) in _despues.entries)
        if (despues - (_antes[concepto] ?? despues) > 0.001)
          (nombre: nombreConcepto(concepto), antes: _antes[concepto]!, despues: despues),
    ]..sort((a, b) => (b.despues - b.antes).compareTo(a.despues - a.antes));
    // La vibración fuerte la da el sello al caer.
    setState(() {
      _fase = _Fase.terminada;
      _resumen = (
        racha: racha,
        rachaSube: racha > antes.dias,
        record: despues.mejor > antes.mejor && racha >= 2 ? racha : null,
        mejoras: mejoras,
      );
    });
  }

  Future<void> _salir() async {
    if (_salidaLibre) {
      _cerrar();
      return;
    }
    final salir = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: const Icon(Icons.pause_circle_rounded),
        title: const Text(textoSalirTitulo),
        content: const Text(textoSalirMensaje),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogo).pop(true), child: const Text('Salir')),
          FilledButton(onPressed: () => Navigator.of(dialogo).pop(false), child: const Text('Seguir aprendiendo')),
        ],
      ),
    );
    if (salir == true && mounted) _cerrar();
  }

  void _cerrar() {
    unawaited(_tts.parar());
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/aprende');
    }
  }

  Future<void> _escuchar() => _leer(textoParaLeer(_actual));

  /// Lee [texto] en voz alta o, si ya está leyendo algo, lo para.
  Future<void> _leer(String texto) async {
    if (_tts.hablando.value) {
      await _tts.parar();
      return;
    }
    // Nunca se escucha mientras se habla (sección 6.5): el micrófono de «Dilo» transcribiría la voz de la app. Se
    // apaga antes de leer y lo dictado se queda en el campo.
    if (_actual is EjercicioDilo) await ref.read(sttProvider).parar();
    if (!mounted) return;
    await _tts.hablar(texto);
  }

  /// Lo que se lee del panel de corrección: el título, la respuesta correcta si se ha fallado y la explicación;
  /// en «Dilo», si la corrección es aproximada, las ideas que ha explicado, las que faltan y el comentario si dice algo
  /// más (o las ideas clave si se ha saltado).
  String _textoCorreccion(Ejercicio ejercicio, String titulo) {
    final partes = [titulo];
    if (ejercicio is EjercicioDilo) {
      final nota = _nota;
      if (nota != null) {
        if (_notaAproximada) partes.add('$textoDiloAproximada.');
        if (nota.cubiertas.isNotEmpty) partes.add('Has explicado: ${nota.cubiertas.join('. ')}.');
        if (nota.faltan.isNotEmpty) {
          partes.add('${textoIdeasQueFaltan(nota.faltan.length)}: ${nota.faltan.join('. ')}.');
        }
        if (comentarioDilo(nota) case final comentario?) partes.add(comentario);
      } else {
        partes.add('$textoDiloIdeasClave ${ejercicio.proposiciones.join('. ')}.');
      }
    } else {
      if (_acierto != true) partes.add(textoRespuestaCorrecta(ejercicio) ?? '');
      partes.add(ejercicio.explicacion);
    }
    return partes.where((p) => p.trim().isNotEmpty).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    if (_total == 0 || _cola.isEmpty) {
      return TuTurnoScaffold(
        titulo: _tituloBarra,
        body: EstadoVacio(
          icono: Icons.hourglass_empty_rounded,
          tuIcono: TuIcono.reloj,
          titulo: 'Esta lección se está preparando',
          mensaje: 'Aún no tiene ejercicios listos. Vuelve a Aprende y prueba con otra.',
          accion: FilledButton(onPressed: _cerrar, child: const Text('Volver a Aprende')),
        ),
      );
    }
    final rapida = duracion(context, Duracion.media);
    return PopScope(
      canPop: _salidaLibre,
      onPopInvokedWithResult: (hecho, _) {
        if (!hecho) unawaited(_salir());
      },
      child: TuTurnoScaffold(
        titulo: _tituloBarra,
        body: AnimatedSwitcher(
          duration: rapida,
          switchInCurve: Curves.easeOutCubic,
          child: _fase == _Fase.terminada ? _celebracion() : _juego(context),
        ),
      ),
    );
  }

  /// El título y la barra de progreso arriba; debajo, el ejercicio y, abajo del todo, «Comprobar» o el panel de
  /// corrección. El panel sabe cuánto alto hay debajo de la barra de progreso, para no pasarse nunca de la pantalla.
  Widget _juego(BuildContext context) {
    final ejercicio = _actual;
    final rapida = duracion(context, Duracion.media);
    final completados = _indice + (_fase == _Fase.revisado ? 1 : 0);
    final claveEjercicio = ValueKey('ejercicio-$_indice');
    final claveAbajo = _fase == _Fase.revisado ? ValueKey('panel-$_indice') : const ValueKey('botonera');
    final tema = Theme.of(context);
    return Column(
      key: const ValueKey('juego'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.m, Espacio.xs),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: anchoMaximoAprende),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // El título entero de la lección (en la barra va el corto).
                Semantics(
                  header: true,
                  child: Text(
                    _titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tema.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tema.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: Espacio.s),
                Row(
                  children: [
                    Expanded(
                      child: BarraProgreso(
                        valor: completados / _total,
                        etiqueta: 'Progreso de la lección',
                        valorTexto: 'Ejercicio ${_indice + 1} de $_total',
                      ),
                    ),
                    const SizedBox(width: Espacio.s + Espacio.xs),
                    PastillaDato(
                      key: const ValueKey('pastilla-xp-leccion'),
                      tuIcono: TuIcono.xp,
                      // Como el panel de turnos: con cada acierto, las cifras giran.
                      texto: ContadorFlip(valor: _xp, estilo: tema.textTheme.labelLarge),
                      semantica: '$_xp puntos en esta lección',
                      colorTexto: tema.colorScheme.onSurface,
                      fondo: tema.colorScheme.surfaceContainerHighest,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, limites) => Column(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: rapida,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (hijo, animacion) {
                      final entrando = hijo.key == claveEjercicio;
                      final desplazamiento = Tween<Offset>(
                        begin: entrando ? const Offset(0.18, 0) : const Offset(-0.18, 0),
                        end: Offset.zero,
                      ).animate(animacion);
                      // Lo que se va ya no se puede tocar mientras sale.
                      return IgnorePointer(
                        ignoring: !entrando,
                        child: FadeTransition(
                          opacity: animacion,
                          child: SlideTransition(position: desplazamiento, child: hijo),
                        ),
                      );
                    },
                    child: Align(
                      key: claveEjercicio,
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: anchoMaximoAprende),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.m, Espacio.m, Espacio.l),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _CabeceraEjercicio(
                                ejercicio: ejercicio,
                                repaso: _repasos.contains(ejercicio.id),
                                turnoActivo: _fase == _Fase.respondiendo,
                                tts: _tts,
                                onEscuchar: _escuchar,
                              ),
                              const SizedBox(height: Espacio.m),
                              Sacudida(disparo: _sacudidas, child: _vista(ejercicio)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: anchoMaximoAprende + Espacio.xl),
                  child: AnimatedSwitcher(
                    duration: rapida,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    // El panel que se va ya no se puede tocar mientras sale: un segundo toque en «Continuar» no hace nada.
                    transitionBuilder: (hijo, animacion) => IgnorePointer(
                      ignoring: hijo.key != claveAbajo,
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(animacion),
                        child: FadeTransition(opacity: animacion, child: hijo),
                      ),
                    ),
                    child: _fase == _Fase.revisado ? _panel(ejercicio, limites.maxHeight) : _botonera(ejercicio),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _vista(Ejercicio ejercicio) {
    final revisado = _fase == _Fase.revisado;
    final clave = ValueKey('vista-$_indice-${ejercicio.id}');
    return switch (ejercicio) {
      EjercicioEleccion() => VistaEleccion(
        key: clave,
        ejercicio: ejercicio,
        revisado: revisado,
        onRespuesta: _alResponder,
      ),
      EjercicioVf() => VistaVf(key: clave, ejercicio: ejercicio, revisado: revisado, onRespuesta: _alResponder),
      EjercicioOrdenar() => VistaOrdenar(
        key: clave,
        ejercicio: ejercicio,
        revisado: revisado,
        onRespuesta: _alResponder,
      ),
      EjercicioEmparejar() => VistaEmparejar(
        key: clave,
        ejercicio: ejercicio,
        revisado: revisado,
        onRespuesta: _alResponder,
      ),
      EjercicioDilo() => VistaDilo(
        key: clave,
        ejercicio: ejercicio,
        bloqueado: _fase != _Fase.respondiendo,
        onRespuesta: _alResponder,
      ),
    };
  }

  Widget _botonera(Ejercicio ejercicio) {
    final esquema = Theme.of(context).colorScheme;
    final comprobando = _fase == _Fase.comprobando;
    final listo = _respuesta != null && _fase == _Fase.respondiendo;
    return DecoratedBox(
      key: const ValueKey('botonera'),
      decoration: BoxDecoration(
        color: esquema.surface,
        border: Border(top: BorderSide(color: esquema.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s + Espacio.xs, Espacio.m, Espacio.s + Espacio.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              key: const ValueKey('boton-comprobar'),
              onPressed: listo ? _comprobar : null,
              // Mientras se comprueba, el botón no se apaga: conserva su color y lleva una rueda, para que se vea que
              // está trabajando. El lector de pantalla lo anuncia.
              style: comprobando
                  ? FilledButton.styleFrom(
                      disabledBackgroundColor: esquema.primary,
                      disabledForegroundColor: esquema.onPrimary,
                    )
                  : null,
              child: comprobando
                  ? Semantics(
                      liveRegion: true,
                      label: textoDiloComprobando.replaceAll('…', ''),
                      excludeSemantics: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox.square(
                            dimension: Espacio.l - Espacio.xs,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: esquema.onPrimary),
                          ),
                          const SizedBox(width: Espacio.m - 4),
                          const Flexible(child: Text(textoDiloComprobando)),
                        ],
                      ),
                    )
                  : const Text('Comprobar'),
            ),
            if (ejercicio is EjercicioDilo && !comprobando) ...[
              const SizedBox(height: Espacio.xs),
              TextButton(
                key: const ValueKey('boton-saltar'),
                onPressed: _saltarDilo,
                child: const Text('Ahora no puedo: ver las ideas clave'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _panel(Ejercicio ejercicio, double alto) {
    final ultimo = _indice + 1 >= _total;
    final textoBoton = ultimo ? 'Terminar' : 'Continuar';
    final acierto = _acierto;
    if (ejercicio is EjercicioDilo) {
      if (_crisis) {
        // Sin corregir y sin puntos: lo primero son los teléfonos de ayuda.
        return PanelCorreccion(
          key: ValueKey('panel-$_indice'),
          tipo: TipoCorreccion.ayuda,
          titulo: textoAyudaDiloTitulo,
          detalle: const AyudaDilo(),
          textoBoton: textoBoton,
          onContinuar: _continuar,
          onEscuchar: () => _leer(textoAyudaDiloVoz),
          hablando: _tts.hablando,
          altoDisponible: alto,
        );
      }
      final nota = _nota;
      if (nota == null) {
        // «Ahora no puedo»: solo las ideas clave, sin corrección.
        const titulo = 'Mira las ideas clave';
        return PanelCorreccion(
          key: ValueKey('panel-$_indice'),
          tipo: TipoCorreccion.neutra,
          titulo: titulo,
          detalle: IdeasDilo(proposiciones: ejercicio.proposiciones),
          fuente: ejercicio.fuente,
          textoBoton: textoBoton,
          onContinuar: _continuar,
          onEscuchar: () => _leer(_textoCorreccion(ejercicio, titulo)),
          hablando: _tts.hablando,
          altoDisponible: alto,
        );
      }
      final titulo = tituloDilo(nota.puntuacion);
      return PanelCorreccion(
        key: ValueKey('panel-$_indice'),
        tipo: nota.puntuacion >= 0.5 ? TipoCorreccion.acierto : TipoCorreccion.fallo,
        titulo: titulo,
        xp: _xpUltimo,
        aproximada: _notaAproximada,
        detalle: IdeasDilo(nota: nota, proposiciones: ejercicio.proposiciones),
        fuente: ejercicio.fuente,
        textoBoton: textoBoton,
        onContinuar: _continuar,
        onEscuchar: () => _leer(_textoCorreccion(ejercicio, titulo)),
        hablando: _tts.hablando,
        altoDisponible: alto,
      );
    }
    final bien = acierto == true;
    final titulo = tituloCorreccion(acierto: bien, vez: _indice);
    return PanelCorreccion(
      key: ValueKey('panel-$_indice'),
      tipo: bien ? TipoCorreccion.acierto : TipoCorreccion.fallo,
      titulo: titulo,
      xp: _xpUltimo,
      textoRacha: bien ? textoRachaAciertos(_seguidos) : null,
      detalle: bien ? null : respuestaCorrecta(context, ejercicio),
      explicacion: ejercicio.explicacion,
      terminos: _terminosGlosario,
      fuente: ejercicio.fuente,
      textoBoton: textoBoton,
      onContinuar: _continuar,
      onEscuchar: () => _leer(_textoCorreccion(ejercicio, titulo)),
      hablando: _tts.hablando,
      altoDisponible: alto,
    );
  }

  /// Términos del Glosario, para subrayarlos en la explicación (como en Vive el caso). Solo después de responder:
  /// en la pregunta, la definición podría dar la respuesta.
  List<String> get _terminosGlosario => [for (final e in ref.watch(glosarioProvider).value ?? const []) e.termino];

  Widget _celebracion() {
    final resumen = _resumen!;
    final leccion = widget.leccion;
    final siguiente = leccion == null ? null : widget.curso.posterior(leccion.id);
    final botones = <Widget>[
      if (siguiente != null)
        FilledButton.icon(
          key: const ValueKey('boton-siguiente'),
          onPressed: () => context.pushReplacement(rutaLeccion(siguiente.id)),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: Text('Siguiente: ${siguiente.titulo}', textAlign: TextAlign.center),
        ),
      if (siguiente == null)
        FilledButton.icon(
          key: const ValueKey('boton-mapa'),
          onPressed: _cerrar,
          icon: const Icon(Icons.map_rounded),
          label: const Text('Volver al mapa'),
        )
      else
        OutlinedButton.icon(
          key: const ValueKey('boton-mapa'),
          onPressed: _cerrar,
          icon: const Icon(Icons.map_rounded),
          label: const Text('Volver al mapa'),
        ),
      if (widget.esPractica)
        TextButton.icon(
          onPressed: () => context.pushReplacement(rutaPractica(widget.unidad.id)),
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Practicar otra vez'),
        ),
    ];
    return Celebracion(
      key: const ValueKey('celebracion'),
      sello: widget.esPractica ? TipoSello.practica : TipoSello.leccion,
      titulo: widget.esPractica ? textoRepasoHecho : textoLeccionSuperada,
      subtitulo: textoSelloConseguido,
      detalle: _titulo,
      xp: _xp,
      racha: resumen.racha,
      rachaSube: resumen.rachaSube,
      record: resumen.record,
      aciertos: _aciertos,
      respondidas: _respondidas,
      mejoras: resumen.mejoras,
      botones: botones,
    );
  }
}

/// Tipo de ejercicio, «Repaso» si toca y el botón para escucharlo. En «Dilo con tus palabras», el aviso «Tu turno de
/// palabra», con la luz del micrófono encendida mientras se responde (tema de justicia, apartado 7.7).
class _CabeceraEjercicio extends StatelessWidget {
  const _CabeceraEjercicio({
    required this.ejercicio,
    required this.repaso,
    required this.turnoActivo,
    required this.tts,
    required this.onEscuchar,
  });

  final Ejercicio ejercicio;
  final bool repaso;
  final bool turnoActivo;
  final Tts tts;
  final VoidCallback onEscuchar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Row(
      children: [
        // El botón de escuchar, siempre en el borde derecho, donde el pulgar lo encuentra.
        Expanded(
          child: Wrap(
            spacing: Espacio.s,
            runSpacing: Espacio.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (ejercicio is EjercicioDilo)
                AvisoTurnoPalabra(key: const ValueKey('aviso-turno-palabra'), activo: turnoActivo)
              else
                PastillaDato(
                  icono: iconoTipo(ejercicio.tipo),
                  texto: Text(etiquetaTipo(ejercicio.tipo)),
                  semantica: etiquetaTipo(ejercicio.tipo),
                  colorTexto: esquema.onSurface,
                  colorIcono: esquema.primary,
                  fondo: fondoAcento(context, esquema.primary),
                ),
              if (repaso)
                PastillaDato(
                  tuIcono: TuIcono.reloj,
                  texto: const Text('Repaso'),
                  semantica: 'Ejercicio de repaso',
                  colorTexto: esquema.onSurface,
                  fondo: fondoAcento(context, esquema.tertiary),
                ),
            ],
          ),
        ),
        const SizedBox(width: Espacio.s),
        ValueListenableBuilder<bool>(
          valueListenable: tts.hablando,
          builder: (context, hablando, _) => IconButton.filledTonal(
            key: const ValueKey('boton-escuchar'),
            tooltip: hablando ? 'Parar la lectura' : 'Escuchar el ejercicio',
            onPressed: onEscuchar,
            icon: IconoTuTurno(
              hablando ? TuIcono.silencio : TuIcono.altavoz,
              estilo: EstiloIcono.mono,
              color: esquema.onSecondaryContainer,
              decorativo: true,
            ),
          ),
        ),
      ],
    );
  }
}

/// Lo que se lee en voz alta de cada ejercicio (en el mismo orden en que se ven las opciones).
String textoParaLeer(Ejercicio ejercicio) => switch (ejercicio) {
  EjercicioEleccion(:final id, :final pregunta, :final opciones) =>
    '$pregunta Las opciones son: ${[for (final i in barajar(opciones.length, semillaDe(id))) opciones[i]].join('. ')}.',
  EjercicioVf(:final afirmacion) => '$afirmacion ¿Verdadero o falso?',
  EjercicioOrdenar(:final id, :final enunciado, :final pasos) =>
    '$enunciado. Los pasos son: '
        '${[for (final i in barajar(pasos.length, semillaDe(id), evitarIdentidad: true)) pasos[i]].join('. ')}.',
  EjercicioEmparejar(:final id, :final pares) =>
    'Une cada tarjeta con su pareja. A la izquierda: ${[for (final p in pares) p.$1].join('. ')}. '
        'A la derecha: ${[for (final i in barajar(pares.length, semillaDe(id), evitarIdentidad: true)) pares[i].$2].join('. ')}.',
  EjercicioDilo(:final pregunta) => pregunta,
};

class _Bloqueada extends StatelessWidget {
  const _Bloqueada({required this.leccion, required this.siguiente});

  final Leccion leccion;
  final Leccion? siguiente;

  @override
  Widget build(BuildContext context) {
    final siguiente = this.siguiente;
    return TuTurnoScaffold(
      titulo: leccion.titulo,
      body: EstadoVacio(
        icono: Icons.lock_rounded,
        tuIcono: TuIcono.candado,
        titulo: 'Esta lección aún está cerrada',
        mensaje: 'Se abre cuando completes la anterior. ¡Ya queda menos!',
        accion: siguiente == null
            ? FilledButton(onPressed: () => context.go('/aprende'), child: const Text('Ir a Aprende'))
            : FilledButton.icon(
                onPressed: () => context.pushReplacement(rutaLeccion(siguiente.id)),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text('Ir a «${siguiente.titulo}»'),
              ),
      ),
    );
  }
}

class _NoEncontrada extends StatelessWidget {
  const _NoEncontrada();

  @override
  Widget build(BuildContext context) {
    return TuTurnoScaffold(
      titulo: 'Aprende',
      body: EstadoVacio(
        icono: Icons.search_off_rounded,
        tuIcono: TuIcono.buscar,
        titulo: 'No encuentro esta lección',
        mensaje: 'Puede que haya cambiado de sitio. Vuelve al mapa de Aprende.',
        accion: FilledButton(onPressed: () => context.go('/aprende'), child: const Text('Ir a Aprende')),
      ),
    );
  }
}
