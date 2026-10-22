import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/api/models.dart';
import 'core/providers.dart';
import 'features/ajustes/ajustes_screen.dart';
import 'features/aprende/aprende_screen.dart';
import 'features/ayuda/ayuda_screen.dart';
import 'features/ayuda/pantalla_neutra.dart';
import 'features/glosario/glosario_screen.dart';
import 'features/inicio/inicio_screen.dart';
import 'features/juego/juego_screen.dart';
import 'features/mis_preguntas/ensenar_screen.dart';
import 'features/mis_preguntas/mis_preguntas_screen.dart';
import 'features/pregunta/pregunta_screen.dart';
import 'features/situacion/situacion_screen.dart';
import 'pixel/ui/estilo_pixel.dart';
import 'pixel/ui/transicion_pixel.dart';
import 'tema.dart';
import 'widgets/estados.dart';
import 'widgets/iconos/iconos.dart';
import 'widgets/movimiento/transiciones.dart';
import 'widgets/tuturno_scaffold.dart';

class TuTurnoApp extends ConsumerWidget {
  const TuTurnoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final factorTexto = ref.watch(ajustesProvider.select((a) => a.tamanoTexto));
    final lecturaFacil = ref.watch(ajustesProvider.select((a) => a.lecturaFacil));
    final reducirMovimiento = ref.watch(ajustesProvider.select((a) => a.reducirMovimiento));
    // Con menos animaciones (en Ajustes o en el sistema), el tema cambia de golpe: al pasar a lectura fácil o a oscuro.
    final sinAnimaciones = reducirMovimiento || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return MaterialApp.router(
      title: 'TuTurno',
      debugShowCheckedModeBanner: false,
      theme: temaTuTurno(Brightness.light, lecturaFacil: lecturaFacil),
      darkTheme: temaTuTurno(Brightness.dark, lecturaFacil: lecturaFacil),
      themeAnimationDuration: sinAnimaciones ? Duration.zero : kThemeAnimationDuration,
      locale: const Locale('es', 'ES'),
      supportedLocales: const [Locale('es', 'ES')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        // Respeta el tamaño de letra del sistema y le suma el elegido en Ajustes. «Reducir animaciones» de Ajustes se
        // suma a la opción del sistema: con cualquiera de las dos, todo lo que mira MediaQuery.disableAnimationsOf
        // (duracion(), paginaTuTurno, el confeti…) se queda quieto en todas las pantallas.
        final mq = MediaQuery.of(context);
        final sistema = mq.textScaler.scale(16) / 16;
        final scroll = ScrollConfiguration.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(sistema * factorTexto),
            disableAnimations: mq.disableAnimations || reducirMovimiento,
          ),
          // TemaPixel lleva «lectura fácil» a Vive el caso: con ella, el kit pixel pasa a Atkinson Hyperlegible. Pone
          // también el scroll del juego (sin estirado); el resto de la app recupera aquí el suyo, y el juego vuelve a
          // ponerlo con su propio TemaPixel.
          child: TemaPixel(
            lecturaFacil: lecturaFacil,
            child: ScrollConfiguration(
              behavior: scroll,
              // La flecha de «atrás» de todas las barras es la de la iconografía de TuTurno. El botón conserva su
              // descripción («Atrás») para el lector de pantalla.
              child: ActionIconTheme(data: _iconosDeAccion, child: child!),
            ),
          ),
        );
      },
    );
  }
}

final _iconosDeAccion = ActionIconThemeData(
  backButtonIconBuilder: (context) =>
      const IconoTuTurno(TuIcono.volver, estilo: EstiloIcono.mono, size: 26, decorativo: true),
);

/// Rutas de la sección 6.3, más /ajustes, /mis-preguntas (con /mis-preguntas/ensenar) y /salida.
///
/// Transiciones (lib/widgets/movimiento/transiciones.dart): al entrar en Vive el caso y en Aprende, la pantalla se
/// rasga como un ticket; las lecciones, Pregunta, Mi situación y Mis preguntas suben como un ticket del dispensador;
/// Ayuda, Glosario, Ajustes y «Enseñar» se abren rápidas y tranquilas. Con «reducir animaciones», ninguna se mueve.
/// La pantalla neutra de la salida rápida (/salida) aparece de golpe, siempre.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    // En la web, toda la app ocupa una sola entrada del historial del navegador (cada pantalla reemplaza la anterior;
    // para volver están los botones de la app). Así, «Salir rápido» (lib/core/salida_rapida.dart) cambia esa entrada
    // por una página neutra con location.replace y «atrás» ya no vuelve a TuTurno.
    routerNeglect: kIsWeb,
    routes: [
      GoRoute(path: '/', pageBuilder: (context, state) => paginaTuTurno(context, state, const InicioScreen())),
      GoRoute(
        path: '/juego',
        pageBuilder: (context, state) =>
            paginaTuTurno(context, state, const JuegoScreen(), transicion: TransicionTuTurno.rasgar),
        routes: [
          // «El juzgado por dentro» va antes que ':casoId', que si no se quedaría con «juzgado». Dentro del juego, las
          // dos entran con la transición a bloques del kit pixel (con «reducir animaciones», un fundido corto).
          rutaHijaJuzgado(pagina: paginaPixel),
          GoRoute(
            path: ':casoId',
            pageBuilder: (context, state) =>
                paginaPixel(context, state, CasoScreen(casoId: state.pathParameters['casoId']!)),
          ),
        ],
      ),
      // /juzgado?modo=menores (final del caso de Sergio y atajo de la demo) lleva a /juego/juzgado?modo=menores.
      rutaRedireccionJuzgado(),
      GoRoute(
        path: '/aprende',
        pageBuilder: (context, state) =>
            paginaTuTurno(context, state, const AprendeScreen(), transicion: TransicionTuTurno.rasgar),
        routes: [
          GoRoute(
            path: 'leccion/:leccionId',
            pageBuilder: (context, state) => paginaTuTurno(
              context,
              state,
              LeccionScreen(leccionId: state.pathParameters['leccionId']!),
              transicion: TransicionTuTurno.deslizar,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/pregunta',
        // ?q= deja una pregunta escrita en el campo (desde el Glosario); no se envía sola.
        pageBuilder: (context, state) => paginaTuTurno(
          context,
          state,
          PreguntaScreen(
            situacion: _rol(state.uri.queryParameters['situacion']),
            preguntaInicial: state.uri.queryParameters['q'],
          ),
          transicion: TransicionTuTurno.deslizar,
        ),
      ),
      GoRoute(
        path: '/situacion/:rol',
        pageBuilder: (context, state) => paginaTuTurno(
          context,
          state,
          SituacionScreen(rol: _rol(state.pathParameters['rol']), rolId: state.pathParameters['rol']),
          transicion: TransicionTuTurno.deslizar,
        ),
      ),
      GoRoute(
        path: '/mis-preguntas',
        pageBuilder: (context, state) =>
            paginaTuTurno(context, state, const MisPreguntasScreen(), transicion: TransicionTuTurno.deslizar),
        routes: [
          GoRoute(
            path: 'ensenar',
            pageBuilder: (context, state) => paginaTuTurno(context, state, const EnsenarScreen()),
          ),
        ],
      ),
      // Salida rápida: sin transición, para que la pantalla de antes no se vea ni un momento.
      GoRoute(
        path: '/salida',
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          name: state.name ?? state.path,
          restorationId: state.pageKey.value,
          child: const PantallaNeutra(),
        ),
      ),
      GoRoute(path: '/ayuda', pageBuilder: (context, state) => paginaTuTurno(context, state, const AyudaScreen())),
      GoRoute(
        path: '/glosario',
        pageBuilder: (context, state) => paginaTuTurno(
          context,
          state,
          GlosarioScreen(
            busquedaInicial: state.uri.queryParameters['q'],
            vieneDePregunta: state.uri.queryParameters['desde'] == 'pregunta',
          ),
        ),
      ),
      GoRoute(path: '/ajustes', pageBuilder: (context, state) => paginaTuTurno(context, state, const AjustesScreen())),
    ],
    errorBuilder: (context, state) => const _NoEncontrada(),
  );
  ref.onDispose(router.dispose);
  return router;
});

RolProceso? _rol(String? valor) => valor == null ? null : RolProceso.values.asNameMap()[valor];

class _NoEncontrada extends StatelessWidget {
  const _NoEncontrada();

  @override
  Widget build(BuildContext context) {
    return TuTurnoScaffold(
      titulo: 'TuTurno',
      body: EstadoVacio(
        icono: Icons.explore_off_rounded,
        titulo: 'Esta pantalla no existe',
        mensaje: 'Vuelve al inicio para seguir.',
        accion: FilledButton(onPressed: () => context.go('/'), child: const Text('Ir al inicio')),
      ),
    );
  }
}
