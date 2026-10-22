import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../core/agente/agente_provider.dart';
import '../../core/agente/agente_voz.dart';
import '../../core/api/tuturno_api.dart';
import '../../core/borrar_todo.dart';
import '../../core/demo.dart';
import '../../core/entrada.dart';
import '../../core/progreso.dart';
import '../../core/providers.dart';
import '../../core/recursos_ayuda.dart';
import '../../core/voz/stt.dart';
import '../../widgets/iconos/iconos.dart';
import '../glosario/favoritos.dart' show favoritosProvider;
import '../inicio/turno_del_dia.dart' show TurnoDelDiaNotifier, turnoDelDiaProvider;
import '../juego/juego_providers.dart' show partidaProvider;
import '../juego/juzgado_screen.dart' show rutaJuzgado;
import '../pasos/personalizacion_linea.dart' show EstiloExplicacion;
import '../pregunta/agente/chat_agente.dart' show chatAgenteProvider;
import '../pregunta/agente/hoja_perfil.dart' show perfilPreguntadoProvider;
import '../pregunta/chat_controller.dart' show chatProvider;
import '../situacion/mi_ticket.dart' show Acompanante, MiTicketNotifier, Preocupacion, miTicketProvider;

// Lo que hay detrás de Ajustes → «Para el equipo (demo)» (plan v2, demo §3.1 y §3.5) y de «Borrar todo lo de este
// móvil» (producto §5.3): dejar la app como nueva, preparar cada ensayo igual, los atajos del guion y «Comprobar antes
// de salir». Las pantallas están en para_el_equipo.dart y ajustes_screen.dart.

// ---------------------------------------------------------------------------------------------------------------------
// Dejar la app como nueva y preparar la demo
// ---------------------------------------------------------------------------------------------------------------------

/// «Borrar mis respuestas» de Ajustes, lo mismo que el botón del mismo nombre de «Tu ticket» (Mi situación): el ticket
/// de la app (edad, proceso, papel y momento) y lo que se contestó en Mi situación (con quién irás, qué te preocupa y
/// cómo prefieres que te lo cuente). «Tu día» se queda: tiene su propio «Borrar mi día», y «Borrar todo» lo borra.
Future<void> borrarTicket(WidgetRef ref) async {
  await ref.read(miTicketProvider.notifier).borrarRespuestas();
  await ref.read(entradaProvider.notifier).borrar();
}

/// Deja TuTurno como recién instalado, salvo los ajustes (letra, lectura fácil, animaciones, voz y servidor): borra lo
/// guardado ([borrarTodo]) y olvida lo que las pantallas tienen en memoria: el turno del día, las palabras guardadas
/// del glosario, las partidas a medias de Vive el caso (sin esto, la lista seguiría diciendo «Escena 5 de 11»), el
/// chat de Pregunta y si ya se ofreció la hoja del perfil.
///
/// No navega: después, quien llama hace `go('/')`. Con la bienvenida sin ver, el inicio la enseña.
Future<void> reiniciarUso(WidgetRef ref) async {
  await borrarTodo(ref);
  ref
    ..invalidate(turnoDelDiaProvider)
    ..invalidate(favoritosProvider)
    ..invalidate(partidaProvider)
    ..invalidate(chatProvider)
    ..invalidate(chatAgenteProvider)
    ..invalidate(perfilPreguntadoProvider);
}

/// «Preparar demo»: cada ensayo empieza igual, por muchas veces que se pulse. Deja la app como nueva
/// ([reiniciarUso]), carga el progreso de la demo ([progresoDemo], calculado con la hora de ahora), guarda el ticket
/// de Sergio si [conTicket] (también lo de Mi situación: [sembrarMiTicketDeSergio]), da la bienvenida por vista y
/// enseña los borradores (como «El juzgado por dentro», que aún no está validado; solo tiene efecto con DEMO).
Future<void> prepararDemo(WidgetRef ref, {bool conTicket = true}) async {
  await reiniciarUso(ref);
  final ahora = ref.read(relojProvider)();
  await ref.read(progresoProvider.notifier).reemplazar(progresoDemo(ahora));
  if (conTicket) {
    await ref.read(entradaProvider.notifier).guardar(entradaDemoSergio);
    sembrarMiTicketDeSergio(ref.read(miTicketProvider.notifier), ahora);
  }
  await ref.read(bienvenidaVistaProvider.notifier).marcar();
  ref.read(mostrarBorradoresProvider.notifier).cambiar(true);
  await _turnoDelDiaDesdeAqui(ref);
}

/// Lo que Sergio contaría en «Tu ticket» de Mi situación, para que el atajo «Mi situación de víctima» enseñe la guía
/// hecha a su medida: irá con su familia, le preocupan el instituto y qué le van a preguntar, lo prefiere paso a paso
/// y su cita es hoy a las 12:30 (el «modo día»).
void sembrarMiTicketDeSergio(MiTicketNotifier miTicket, DateTime hoy) {
  miTicket
    ..guardarRespuestas(
      conQuien: const {Acompanante.familia},
      preocupaciones: const {Preocupacion.colegio, Preocupacion.preguntas},
      estilo: EstiloExplicacion.pasoAPaso,
    )
    ..ponerFecha(hoy)
    ..ponerHora(12, 30);
}

/// Lo que dice el diálogo de «Preparar demo» de lo que [sembrarMiTicketDeSergio] guarda en Mi situación.
const resumenMiTicketDeSergio =
    'En Mi situación: irá con su familia, le preocupan el instituto y las preguntas, paso a paso y su cita es hoy a '
    'las 12:30.';

/// «Empezar de cero»: como [prepararDemo], pero sin progreso ni ticket y con la bienvenida otra vez, como alguien que
/// abre TuTurno por primera vez.
Future<void> empezarDeCero(WidgetRef ref) async {
  await reiniciarUso(ref);
  await ref.read(bienvenidaVistaProvider.notifier).desmarcar();
  ref.read(mostrarBorradoresProvider.notifier).cambiar(true);
  await _turnoDelDiaDesdeAqui(ref);
}

/// El turno del día se apunta lo que hay en el progreso al empezar el día. Mientras se prepara, el inicio (que sigue
/// debajo de Ajustes) puede haberlo calculado con el progreso vacío de un momento antes, y entonces la misión saldría
/// ya cumplida: se vuelve a calcular con el progreso que queda.
Future<void> _turnoDelDiaDesdeAqui(WidgetRef ref) async {
  await ref.read(sharedPreferencesProvider).remove(TurnoDelDiaNotifier.clave);
  ref.invalidate(turnoDelDiaProvider);
}

// ---------------------------------------------------------------------------------------------------------------------
// Atajos del guion
// ---------------------------------------------------------------------------------------------------------------------

/// Los atajos de la demo, en el orden del guion (plan v2, demo §3.5).
enum AtajoDemo {
  luciaCamara(
    titulo: 'Lucía · ¿Para qué sirve la cámara?',
    detalle: 'Escena 5, en la Sala Gesell',
    ruta: '/juego/caso-sala-gesell',
    icono: TuIcono.grabacion,
    casoId: 'caso-sala-gesell',
    escena: 'S5',
  ),
  luciaMadre(
    titulo: 'Lucía · ¿Tendré que dejar de vivir con mi madre?',
    detalle: 'Escena 9',
    ruta: '/juego/caso-sala-gesell',
    icono: TuIcono.personaConfianza,
    casoId: 'caso-sala-gesell',
    escena: 'S9',
  ),
  sergio(
    titulo: 'Sergio y el protocolo contra el acoso',
    detalle: 'Vive el caso, desde el principio',
    ruta: '/juego/caso-acoso-escolar',
    icono: TuIcono.juego,
    casoId: 'caso-acoso-escolar',
  ),
  sara(
    titulo: 'Sara y el derecho a su imagen',
    detalle: 'Vive el caso, desde el principio',
    ruta: '/juego/caso-difusion-imagenes',
    icono: TuIcono.juego,
    casoId: 'caso-difusion-imagenes',
  ),
  preguntaSergio(
    titulo: 'Pregunta con el perfil de Sergio',
    detalle: '13 años · Penal · Víctima · Durante',
    ruta: '/pregunta',
    icono: TuIcono.pregunta,
    ticketDeSergio: true,
  ),
  situacionVictima(
    titulo: 'Mi situación de víctima',
    detalle: 'Los pasos del proceso',
    ruta: '/situacion/victima',
    icono: TuIcono.miSituacion,
  ),

  /// E-212, la prueba preconstituida: cierra la historia de Lucía (es `rutaDemoDilo('U2-L2')`, de Aprende).
  diloSalaGesell(
    titulo: '«Dilo» de la Sala Gesell',
    detalle: 'Aprende, lección U2-L2 (empieza en «Dilo» solo con DEMO)',
    ruta: '/aprende/leccion/dilo-U2-L2',
    icono: TuIcono.microfono,
  ),
  juzgado(
    titulo: 'El juzgado por dentro',
    detalle: '¿Quién es quién en la sala? Es un borrador',
    ruta: rutaJuzgado,
    icono: TuIcono.juzgado,
  );

  const AtajoDemo({
    required this.titulo,
    required this.detalle,
    required this.ruta,
    required this.icono,
    this.casoId,
    this.escena,
    this.ticketDeSergio = false,
  });

  final String titulo;
  final String detalle;
  final String ruta;
  final TuIcono icono;

  /// El caso de Vive el caso que abre (empieza desde el principio, o en [escena]).
  final String? casoId;

  /// Escena por la que empieza el caso (escenaInicialProvider).
  final String? escena;

  /// Guarda antes el ticket de Sergio ([entradaDemoSergio]).
  final bool ticketDeSergio;
}

/// Abre [atajo] encima del inicio: «atrás» vuelve al inicio y no a Ajustes, que el jurado no tiene por qué ver con la
/// parte del equipo abierta. Un caso empieza desde el principio, o en su escena.
Future<void> abrirAtajo(WidgetRef ref, GoRouter router, AtajoDemo atajo) async {
  final casoId = atajo.casoId;
  final escena = atajo.escena;
  if (casoId != null && escena != null) {
    ref.read(escenaInicialProvider.notifier).fijar(casoId, escena);
  } else if (casoId != null) {
    ref.invalidate(partidaProvider(casoId));
  }
  if (atajo.ticketDeSergio) await ref.read(entradaProvider.notifier).guardar(entradaDemoSergio);
  router.go('/');
  unawaited(router.push<void>(atajo.ruta));
}

// ---------------------------------------------------------------------------------------------------------------------
// Servidor
// ---------------------------------------------------------------------------------------------------------------------

/// Solo direcciones http:// o https:// con servidor.
bool esUrlServidorValida(String texto) {
  final uri = Uri.tryParse(texto.trim());
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
}

/// La APK release solo habla HTTPS (el tráfico sin cifrar solo está permitido en debug) y una web servida por
/// https no puede llamar a http://: en esos casos una dirección http:// no funcionaría.
bool soloHttps({bool release = kReleaseMode, bool web = kIsWeb, String esquemaPagina = ''}) =>
    release && (!web || esquemaPagina == 'https');

/// Qué decir cuando falla «Probar la conexión», según el código de [ApiException].
String pistaConexion(String codigo) => switch (codigo) {
  'SIN_API_URL' => 'Falta la dirección del servidor. Escríbela arriba.',
  'URL_INVALIDA' => 'Escribe la dirección completa, empezando por https://',
  'TIEMPO_AGOTADO' => 'El servidor tarda demasiado en responder. Prueba otra vez.',
  'SIN_CONEXION' => 'No llego al servidor. Revisa la dirección, el túnel y la conexión del móvil.',
  'RESPUESTA_INVALIDA' => 'El servidor responde, pero no como espera TuTurno. ¿Es la dirección correcta?',
  _ => 'No he podido hablar con el servidor ($codigo).',
};

// ---------------------------------------------------------------------------------------------------------------------
// Comprobar antes de salir
// ---------------------------------------------------------------------------------------------------------------------

/// Cuánto se espera a la red y al servidor.
const limiteRed = Duration(seconds: 4);
const limiteServidor = Duration(seconds: 4);

/// La sesión del agente tiene que abrir y cerrar en menos de esto (si no, Pregunta salta al ejemplo).
const limiteAgente = Duration(seconds: 6);

/// Lo que se mira antes de salir al escenario, en este orden. Nada bloquea la app: solo avisa.
enum Comprobacion {
  red('Hay red'),
  servidor('El servidor responde'),
  agente('La voz de Pregunta conecta'),
  microfono('Permiso de micrófono'),
  voz('Voz en español'),
  demo('Modo DEMO'),
  ayuda017('El 017, abierto ahora');

  const Comprobacion(this.titulo);

  final String titulo;
}

enum EstadoComprobacion { comprobando, bien, mal, noAplica }

@immutable
class ResultadoComprobacion {
  const ResultadoComprobacion(this.estado, this.detalle);

  const ResultadoComprobacion.bien(this.detalle) : estado = EstadoComprobacion.bien;

  const ResultadoComprobacion.mal(this.detalle) : estado = EstadoComprobacion.mal;

  /// No hace falta aquí (por ejemplo, la voz del agente en la web, donde Pregunta va en modo texto).
  const ResultadoComprobacion.noAplica(this.detalle) : estado = EstadoComprobacion.noAplica;

  static const comprobando = ResultadoComprobacion(EstadoComprobacion.comprobando, 'Comprobando…');

  final EstadoComprobacion estado;
  final String detalle;
}

/// Si el motor de voz tiene el español: instalado en el móvil (va sin red), solo con red, o nada.
enum VozEspanola { instalada, conRed, no }

/// Lo que «Comprobar antes de salir» pregunta a la red y al móvil fuera de los providers de la app. Las pruebas lo
/// sustituyen ([sondasDemoProvider]).
abstract interface class SondasDemo {
  /// Si hay conexión: una petición pequeña que siempre responde.
  Future<bool> hayRed();

  Future<VozEspanola> vozEspanola();
}

class SondasReales implements SondasDemo {
  const SondasReales();

  static const _canalTts = MethodChannel('flutter_tts');

  @override
  Future<bool> hayRed() async {
    // En la web, la propia página (mismo origen, sin caché); en el móvil, la comprobación de conexión de Android.
    final uri = kIsWeb
        ? Uri.base.removeFragment().replace(queryParameters: {'red': '${DateTime.now().millisecondsSinceEpoch}'})
        : Uri.https('www.gstatic.com', '/generate_204');
    try {
      final respuesta = await http.get(uri).timeout(limiteRed);
      return respuesta.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<VozEspanola> vozEspanola() async {
    // Por el canal de flutter_tts, sin crear otro FlutterTts: su constructor se queda con el canal y la voz de la app
    // (TtsReal, en lib/core/voz/tts.dart) dejaría de enterarse de sus errores.
    try {
      final disponible = await _canalTts.invokeMethod<Object?>('isLanguageAvailable', 'es-ES');
      if (disponible != true && disponible != 1) return VozEspanola.no;
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return VozEspanola.instalada;
      final instalada = await _canalTts.invokeMethod<Object?>('isLanguageInstalled', 'es-ES');
      return instalada == true ? VozEspanola.instalada : VozEspanola.conRed;
    } catch (_) {
      return VozEspanola.no;
    }
  }
}

final sondasDemoProvider = Provider<SondasDemo>((ref) => const SondasReales());

ResultadoComprobacion resultadoRed({required bool hay}) => hay
    ? const ResultadoComprobacion.bien('Hay conexión a internet.')
    : const ResultadoComprobacion.mal('Sin conexión. Mira el wifi o los datos del móvil.');

ResultadoComprobacion resultadoMicrofono({required bool permiso}) => permiso
    ? const ResultadoComprobacion.bien('Se puede dictar con la voz.')
    : const ResultadoComprobacion.mal(
        'Sin permiso o sin reconocimiento de voz. Dalo en los ajustes del móvil: Aplicaciones, TuTurno, Permisos.',
      );

ResultadoComprobacion resultadoVoz(VozEspanola voz) => switch (voz) {
  VozEspanola.instalada => const ResultadoComprobacion.bien('Hay voz en español en el móvil.'),
  VozEspanola.conRed => const ResultadoComprobacion.mal(
    'Solo funciona con red. Instala los datos de voz en español en los ajustes del móvil (Texto a voz).',
  ),
  VozEspanola.no => const ResultadoComprobacion.mal(
    'No hay voz en español. Instálala en los ajustes del móvil (Texto a voz).',
  ),
};

ResultadoComprobacion resultadoDemo({required bool activo}) => activo
    ? const ResultadoComprobacion.bien('Activo: se ven los borradores y funciona el atajo de «Dilo».')
    : const ResultadoComprobacion.mal(
        'Esta versión no es DEMO: sin borradores ni atajo de «Dilo». Compílala con --dart-define=DEMO=true.',
      );

/// El 017 (INCIBE) no atiende a cualquier hora: si está cerrado, en la demo no se llama.
ResultadoComprobacion resultado017(DateTime ahora) {
  final horario = recursosAyuda.firstWhere((r) => r.telefono == '017').horario!;
  return horario.abierto(ahora)
      ? ResultadoComprobacion.bien('Abierto. ${horario.texto}.')
      : ResultadoComprobacion.mal('Cerrado ahora: abre a las ${horario.textoApertura}. ${horario.texto}.');
}

/// Hace la comprobación [comprobacion]. Nunca lanza: lo que falla sale como [EstadoComprobacion.mal].
Future<ResultadoComprobacion> comprobar(WidgetRef ref, Comprobacion comprobacion) async {
  try {
    return switch (comprobacion) {
      Comprobacion.red => resultadoRed(hay: await ref.read(sondasDemoProvider).hayRed()),
      Comprobacion.servidor => await _comprobarServidor(ref),
      Comprobacion.agente => await _comprobarAgente(ref),
      Comprobacion.microfono => resultadoMicrofono(
        permiso: await ref.read(sttProvider).inicializar().timeout(const Duration(seconds: 30)),
      ),
      Comprobacion.voz => resultadoVoz(await ref.read(sondasDemoProvider).vozEspanola()),
      Comprobacion.demo => resultadoDemo(activo: ref.read(configProvider).demo),
      Comprobacion.ayuda017 => resultado017(ref.read(relojProvider)()),
    };
  } catch (_) {
    return const ResultadoComprobacion.mal('No se ha podido comprobar.');
  }
}

Future<ResultadoComprobacion> _comprobarServidor(WidgetRef ref) async {
  if (ref.read(configProvider).useMock) {
    return const ResultadoComprobacion.mal('Respuestas simuladas (USE_MOCK): la app no usa el servidor.');
  }
  final url = ref.read(apiUrlProvider).trim();
  if (url.isEmpty) return const ResultadoComprobacion.mal('Falta la dirección del servidor (API_URL).');
  try {
    final salud = await ref.read(apiProvider).health().timeout(limiteServidor);
    return salud.estado == 'ok'
        ? ResultadoComprobacion.bien('Responde: $url')
        : ResultadoComprobacion.mal('Responde, pero dice «${salud.estado}».');
  } on TimeoutException {
    return const ResultadoComprobacion.mal(
      'No responde en 4 s. Si estaba dormido, ábrelo en el navegador y vuelve a comprobar en un minuto.',
    );
  } on ApiException catch (e) {
    return ResultadoComprobacion.mal(pistaConexion(e.codigo));
  }
}

/// Abre la sesión del agente de voz y la cierra (sin micrófono y sin datos del ticket): tiene que tardar menos de
/// [limiteAgente].
Future<ResultadoComprobacion> _comprobarAgente(WidgetRef ref) async {
  if (!ref.read(modoAgenteProvider)) {
    return kIsWeb
        ? const ResultadoComprobacion.noAplica('En la web, Pregunta va en modo texto con el servidor.')
        : const ResultadoComprobacion.mal('Sin agente de voz: falta API_URL o AGENT_ID. Pregunta irá en modo texto.');
  }
  // Mientras dure la prueba, el agente no se suelta (es autoDispose); al cerrar la suscripción se libera.
  final suscripcion = ref.listenManual(agenteVozProvider, (_, _) {});
  final reloj = Stopwatch()..start();
  try {
    final agente = suscripcion.read();
    if (agente == null) return const ResultadoComprobacion.mal('No hay agente de voz configurado.');
    await agente.iniciar(variables: const Entrada().variablesAgente()).timeout(limiteAgente);
    final queda = limiteAgente - reloj.elapsed;
    await agente.terminar().timeout(queda > Duration.zero ? queda : Duration.zero);
    final decimas = (reloj.elapsedMilliseconds / 100).round();
    return ResultadoComprobacion.bien('Abre y cierra en ${decimas ~/ 10},${decimas % 10} s.');
  } on TimeoutException {
    return const ResultadoComprobacion.mal('No abre en 6 s. Pregunta ofrecerá la conversación de ejemplo.');
  } on ErrorAgente catch (e) {
    return ResultadoComprobacion.mal(e.mensaje);
  } finally {
    suscripcion.close();
  }
}
