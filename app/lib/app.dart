import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/api/models.dart';
import 'core/providers.dart';
import 'features/ajustes/ajustes_screen.dart';
import 'features/aprende/aprende_screen.dart';
import 'features/ayuda/ayuda_screen.dart';
import 'features/glosario/glosario_screen.dart';
import 'features/inicio/inicio_screen.dart';
import 'features/juego/juego_screen.dart';
import 'features/pregunta/pregunta_screen.dart';
import 'features/situacion/situacion_screen.dart';
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
    return MaterialApp.router(
      title: 'TuTurno',
      debugShowCheckedModeBanner: false,
      theme: temaTuTurno(Brightness.light),
      darkTheme: temaTuTurno(Brightness.dark),
      locale: const Locale('es', 'ES'),
      supportedLocales: const [Locale('es', 'ES')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        // Respeta el tamaño de letra del sistema y le suma el elegido en Ajustes.
        final mq = MediaQuery.of(context);
        final sistema = mq.textScaler.scale(16) / 16;
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(sistema * factorTexto)),
          // La flecha de «atrás» de todas las barras es la de la iconografía de TuTurno. El botón conserva su
          // descripción («Atrás») para el lector de pantalla.
          child: ActionIconTheme(data: _iconosDeAccion, child: child!),
        );
      },
    );
  }
}

final _iconosDeAccion = ActionIconThemeData(
  backButtonIconBuilder: (context) =>
      const IconoTuTurno(TuIcono.volver, estilo: EstiloIcono.mono, size: 26, decorativo: true),
);

/// Rutas de la sección 6.3, más /ajustes.
///
/// Transiciones (lib/widgets/movimiento/transiciones.dart): al entrar en Vive el caso y en Aprende, la pantalla se
/// rasga como un ticket; las lecciones, Pregunta y Mi situación suben como un ticket del dispensador; Ayuda, Glosario
/// y Ajustes se abren rápidas y tranquilas. Con «reducir animaciones», ninguna se mueve.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', pageBuilder: (context, state) => paginaTuTurno(context, state, const InicioScreen())),
      GoRoute(
        path: '/juego',
        pageBuilder: (context, state) =>
            paginaTuTurno(context, state, const JuegoScreen(), transicion: TransicionTuTurno.rasgar),
        routes: [
          GoRoute(
            path: ':casoId',
            pageBuilder: (context, state) => paginaTuTurno(
              context,
              state,
              CasoScreen(casoId: state.pathParameters['casoId']!),
              transicion: TransicionTuTurno.rasgar,
            ),
          ),
        ],
      ),
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
          SituacionScreen(rol: _rol(state.pathParameters['rol'])),
          transicion: TransicionTuTurno.deslizar,
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
