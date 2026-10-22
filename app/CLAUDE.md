# TuTurno · instrucciones para Claude Code en la app (app/)

Se suman a las del CLAUDE.md de la raíz. El detalle completo está en docs/ARQUITECTURA.md: secciones 4 (experiencia), 6 (app), 8 (contratos de la API), 9 (esquemas de contenido) y 10.6 (BKT).

## Alcance
- App Flutter para web (Chrome) y Android. Trabaja solo en app/; para tocar backend/, ml/ o content/, avisa antes.
- Ramas: feat/app-base (A1 esqueleto, A2 cliente de la API y mock), feat/pregunta (A3), feat/aprende (A4), feat/juego (A5), feat/situacion (A6) y chore/deploy-web (A7).
- Commits: feat(app): …, fix(app): …

## Estructura de lib/
- app.dart: MaterialApp.router, tema y rutas.
- core/config.dart: API_URL, USE_MOCK y DEMO. En web, API_URL se lee de web/config.json al arrancar; si no existe, de --dart-define.
- core/api/: interfaz TuTurnoApi, HttpTuTurnoApi (real) y MockTuTurnoApi, que devuelve exactamente los JSON de la sección 8.
- core/voz/: stt.dart (speech_to_text, es_ES, pulsar para hablar) y tts.dart (flutter_tts, es-ES, velocidad ajustable).
- core/storage.dart (shared_preferences) y core/content_repo.dart (JSON de assets/content).
- features/: inicio, juego (escenas y cartas de derecho), aprende (mapa, reproductor, ejercicios y bkt.dart), pregunta, situacion, ayuda y glosario.
- widgets/: botón de Ayuda, etiquetas de fuente y texto con términos del glosario.
- Rutas: / · /juego · /juego/juzgado (con ?modo=menores; /juzgado redirige ahí) · /juego/:casoId · /aprende · /aprende/leccion/:leccionId · /pregunta · /situacion/:rol · /mis-preguntas · /mis-preguntas/ensenar · /salida · /ayuda · /glosario · /ajustes
  - /juego/juzgado va antes que /juego/:casoId (rutaHijaJuzgado y rutaRedireccionJuzgado, de features/juego/juego_screen.dart). Las dos entran con la transición a bloques del kit pixel (paginaPixel).
  - /salida es la pantalla neutra de «Salir rápido» (core/salida_rapida.dart), sin transición. En la web, el router va con routerNeglect: toda la app ocupa una sola entrada del historial, y location.replace la quita.
- Providers: contentProvider, progresoProvider, dominioProvider (BKT), chatProvider (solo en memoria) y ajustesProvider.
- Letra y tema (tema.dart): temaTuTurno(brillo, lecturaFacil:).
  - Fuentes.texto es Nunito (cuerpo, etiquetas, botones y barras). MaryKate (Fuentes.titulos) solo en display y headline.
  - Con «Lectura fácil» (Ajustes.lecturaFacil), todo pasa a Atkinson Hyperlegible (Fuentes.lecturaFacil), también el kit pixel (TemaPixel).
  - Las cifras de contadores, tickets y números de carta van con estiloCifras(): Nunito ExtraBold con cifras tabulares (en MaryKate el 0 parece una O).
  - El título de las barras es TituloBarra (widgets/tuturno_scaffold.dart): 20 si cabe y, si no, más pequeño o en dos líneas; nunca «…» en los títulos de la app.
- «Reducir animaciones» (Ajustes.reducirMovimiento) se suma a la opción del sistema: todo lo que mira MediaQuery.disableAnimationsOf se queda quieto.
- Racha amable (core/progreso.dart): para enseñarla, estadoRacha(); hay un día de descanso cada 7 días y nunca se habla de perderla.

## Reglas
- Ayuda y Glosario, arriba a la derecha en todas las pantallas. Los teléfonos de Ayuda (900 20 20 10, 116 111, 112, 017, 016) llaman directamente con url_launcher.
- Solo se muestra contenido con "validado": true. En modo DEMO, un interruptor permite ver borradores.
- No edites app/assets/content/ a mano: lo genera scripts/sync_content.sh a partir de content/.
- Al backend solo van la pregunta, como mucho los 4 últimos mensajes del chat y el texto de «Dilo con tus palabras». Progreso, XP, racha y dominio se guardan en el dispositivo; el chat no se guarda.
- La transcripción de voz se muestra y se puede editar antes de enviar. Si la voz falla, queda el campo de texto. Todo lo que se oye también se puede leer.
- En web, la voz necesita Chrome y HTTPS (o localhost).
- Respuesta con tipo "crisis": tarjeta de Ayuda arriba. Con tipo "hechos": mensaje de derivación. Si la API devuelve un error (sección 8.4), muestra su mensaje.
- Accesibilidad: Semantics en botones e imágenes, tamaño de texto del sistema, contraste alto y zonas táctiles de 48 px como mínimo.
- BKT: p0 = 0,2, T = 0,15, G = 0,2, S = 0,1; un concepto está dominado si p ≥ 0,95. +10 XP por acierto y +5 en «Dilo» si cubre al menos la mitad.
- Android: declara RECORD_AUDIO e INTERNET en android/app/src/main/AndroidManifest.xml. Si INTERNET solo está en el manifiesto de debug, la build release se queda sin red.

## Comandos (desde app/)
- Crear el proyecto (A1, una sola vez): flutter create --project-name tuturno --platforms web,android .
- flutter pub get
- Sin backend: flutter run -d chrome --dart-define=USE_MOCK=true
- Con backend: flutter run -d chrome --dart-define=API_URL=http://localhost:8000
- Build web: flutter build web --release (con --base-href /tuturno/ si se publica en GitHub Pages)
- Antes de un PR: flutter analyze. Una tarea está terminada cuando funciona en la build web y en un Android, con la voz activada y desactivada.
- Capturas para revisar a ojo: CAPTURAS=build/capturas flutter test <prueba de capturas>. Cargan las fuentes de verdad con test/fuentes_reales.dart.
