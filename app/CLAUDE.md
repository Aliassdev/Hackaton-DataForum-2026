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
- features/: inicio, juego (escenas y cartas de derecho), aprende (mapa, reproductor, ejercicios y bkt.dart), pregunta, situacion, pasos, mis_preguntas, ajustes, ayuda y glosario.
- widgets/: botón de Ayuda, etiquetas de fuente y texto con términos del glosario.
  - fuente_chip.dart: FuenteChip y mostrarFuente. Si la fuente trae url, la hoja ofrece «Leer la ley en el BOE» (o «Abrir la web oficial»). nombreNorma entiende también LORPM y LOPIVI.
  - widgets/justicia/: la capa de justicia. FondoJusticia (palacio en silueta o en color, paralaje 0,4, assets/justicia/palacio*.svg, precargar()), PanelSenalamiento, ExpedienteCaratula (la carpeta «TU GUÍA» de Mi situación, nunca «tu expediente»), BalanzaDominio (junto a BarraDominio), SelloJusticia y CartelSala.
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

## Módulos (lo que conviene saber antes de tocarlos)
- Pregunta (features/pregunta/):
  - Con agente (APK con API_URL o AGENT_ID), contesta la voz si está «Voz» y no hay lector de pantalla.
  - Si no, o si la voz no conecta en 10 s, no contesta en 20 s o se pulsa «Contestar por escrito» (sale a los 8 s), contesta el modo texto real: POST /api/agent/ask con el perfil.
  - Los ejemplos (assets/mock/content/pregunta_ejemplos.json, ejemplos.dart) solo salen si tampoco responde el backend, y siempre marcados como ejemplo. Desde «Pregunta como investigado», solo la plantilla de «hechos».
  - En la web, siempre modo texto, con «Escuchar».
  - «Te explico para: …» (ResumenPerfil, con «Cambiar» o «Elegir») sale en los dos modos.
  - /pregunta?q=… deja la duda escrita sin enviarla, también con el agente. «Pregúntaselo a TuTurno» de cada paso lo usa.
- «Dilo con tus palabras» (Aprende) se corrige con POST /api/learn/grade (10 s como mucho). Si falla, o con USE_MOCK, se corrige en el móvil (features/aprende/correccion_local.dart) y se marca «Corrección aproximada sin conexión». Con "tipo": "crisis" (GradeResponse.esCrisis) sale la tarjeta de Ayuda, sin puntos y sin tocar el dominio.
- Mi situación (features/situacion/), tu guía hecha a tu medida:
  - papel.dart: PapelSituacion con 4 papeles. «Me van a escuchar» (escuchado_familia) no es un RolProceso: desde él, Pregunta se abre sin situación.
  - mi_ticket.dart: lo que «Tu ticket» suma a la Entrada (con quién irás, qué te preocupa, cómo prefieres que te lo cuente y «Tu día»). Clave 'mi_situacion', solo en el móvil.
  - ticket_screen.dart: abrirTuTicket(context), que también usa Ajustes. «Investigado» solo desde los 14 años: rolesPara(edad), en core/entrada.dart, la misma regla que la hoja del perfil de Pregunta.
  - contenido.dart lee assets/mock/content/situacion/ (derechos, preocupaciones, pasos y notas). La carpeta tiene que estar en pubspec.yaml: lo vigila test/core/assets_empaquetados_test.dart. Las fuentes salen de docs/MARCO_LEGAL.md: lo comprueba test/features/situacion/contenido_situacion_test.dart.
  - personalizacion.dart: funciones puras (saludo, notas, derechos, respuestas…).
  - widgets/mi_dia.dart: «Tu día» y TarjetaModoDia. En el inicio va con soloElDia («Hoy es tu día»). Cuánto falta solo se dice dentro de «Tu día»: el saludo y la tarjeta dicen la fecha.
  - LineaPasos(personalizacion:, apuntar:, escuchar:), en features/pasos/. «Apuntar» lleva a Mis preguntas, y Mis preguntas y «Enseñar en grande» están completas.
  - Tranquila: sin XP, rachas, confeti ni sellos que caen. El único sello es el quieto «PARA TI» de la carátula.
- Inicio: con papel en el ticket, «Mi situación» lleva directo a su camino (inicio/tu_camino.dart, tuCaminoProvider). El inicio nunca dice el papel ni la fase, porque el móvil puede ser compartido.
- Ajustes (features/ajustes/): «Leer mejor», «Tu ticket» («Cambiar mi ticket» abre «Tu ticket»), «Tus datos en este móvil» y «Acerca de».
  - «Para el equipo (demo)», con el servidor, sale tras una pulsación larga en el pie. Está en demo.dart y para_el_equipo.dart: «Preparar demo» (con el ticket de Sergio y su «Tu día» de hoy), atajos y «Comprobar antes de salir».
  - Compilar la release: env/release.example.json y app/README.md.
  - TituloBarra encoge el título entero: no parte palabras ni pone «…».
- Ayuda: PanelSalidaRapida va debajo del 112.
- Glosario:
  - favoritos.dart: favoritosProvider, «Mis palabras», con la clave 'glosario.favoritos'.
  - terminos_por_caso.dart: terminosPorCaso y filtrosCasoProvider, los chips Lucía, Sergio y Sara.
- «Borrar todo» (core/borrar_todo.dart) borra clavesDeUsuario. Quien guarde algo nuevo de uso añade ahí su clave. Los providers de pantalla que viven toda la sesión vigilan borradoProvider para volver a leer, como hace miTicketProvider.

## Reglas
- Ayuda y Glosario, arriba a la derecha en todas las pantallas. Los teléfonos de Ayuda (900 20 20 10, 116 111, 112, 017, 016) llaman directamente con url_launcher.
- Solo se muestra contenido con "validado": true. En modo DEMO, un interruptor permite ver borradores.
- No edites app/assets/content/ a mano: lo genera scripts/sync_content.sh a partir de content/.
- Al backend van la pregunta, como mucho los 4 últimos mensajes del chat, el texto de «Dilo con tus palabras» y el perfil del ticket. El perfil son edad, procedimiento, papel y momento, sin nombre: va en POST /api/agent/ask y en las variables de la sesión de voz. Lo demás de «Tu ticket» (con quién irás, preocupaciones y «Tu día») no sale del móvil. Progreso, XP, racha y dominio se guardan en el dispositivo; el chat no se guarda.
- Textos de privacidad: solo lo que es cierto hoy. La voz pasa por ElevenLabs, que guarda según cómo esté configurado el agente. Por eso nunca se dice que la conversación «se borra», sino que «desaparece de la pantalla». Tampoco se dice «solo en este móvil» de lo que viaja con las preguntas.
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
