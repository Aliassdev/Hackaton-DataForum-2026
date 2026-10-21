# TuTurno · instrucciones para Claude Code

## Qué es
App para chicos y chicas de 11 a 17 años (DATAthon DATAfórum Justicia 2026, reto 2: infancia y juventud) con tres módulos: el juego «Vive el caso», las lecciones «Aprende» y el agente de voz «Pregunta». La arquitectura completa está en docs/ARQUITECTURA.md.

## Decisiones clave
- Casos oficiales del jurado: Lucía (11 años, Sala Gesell y prueba preconstituida), Sergio (13, acoso escolar y Fiscalía de Menores) y Sara (casi 16, difusión de imágenes íntimas). Ver docs/ARQUITECTURA.md, sección 1.1.
- Pregunta, fase 1 (sección 5.0): agente de ElevenLabs Agents.
  - La app Flutter usa el SDK oficial elevenlabs_agents.
  - La voz del menor se transcribe en el dispositivo y se envía como texto (sendUserMessage, con el micrófono de la sesión silenciado).
  - El backend da el token de sesión (GET /api/session/token) y hace de Custom LLM (POST /v1/chat/completions en streaming).
  - Contratos en las secciones 8.5 a 8.7.
- Pregunta, fase 2, si sobra tiempo: client tools para fuentes, sugerencias, términos y ayuda (8.8). POST /api/agent/ask (8.1) queda como modo texto de respaldo.

## Reglas
- No cambies los contratos de la API (sección 8) ni los esquemas de contenido (sección 9) sin avisar.
- A trabaja en app/. B trabaja en backend/, ml/ y content/. No toques la carpeta del otro sin avisar.
- Nunca subas .env, data/ ni artifacts/. Las API keys (ElevenLabs, LLM) solo van en el backend.
- El contenido jurídico solo se muestra si tiene "validado": true y fuente.
- Límites del agente:
  - Habla del proceso, nunca de los hechos (para no contaminar el testimonio), y nunca pregunta qué pasó.
  - No da consejo legal ni predice resultados.
  - No promete confidencialidad absoluta.
  - Deriva a ANAR (900 20 20 10 / 116 111) si detecta riesgo.
- Sin cuentas ni datos personales. No guardes el texto de los usuarios en los logs.

## Flutter (app/)
- Riverpod para el estado, go_router para las rutas, http para la API y elevenlabs_agents para el agente.
- Interfaz TuTurnoApi con HttpTuTurnoApi y MockTuTurnoApi.
- Un directorio por funcionalidad en lib/features/. Más detalle en app/CLAUDE.md.
- Accesibilidad: Semantics, tamaño de texto del sistema, zonas táctiles de 48 px.
- Comprobar con: flutter analyze && flutter test

## Python (backend/ y ml/)
- FastAPI y Pydantic v2, con tipos en todas las funciones.
- La configuración solo se lee en app/config.py (.env).
- Los modelos se cargan una vez al arrancar.
- Comprobar con: ruff check . && pytest -q

## Comandos
- Backend: uvicorn app.main:app --reload --port 8000
- App en el móvil: flutter run --dart-define=API_URL=https://<túnel>
- App sin backend: flutter run --dart-define=USE_MOCK=true
- Contenido: python scripts/validate_content.py && ./scripts/sync_content.sh
