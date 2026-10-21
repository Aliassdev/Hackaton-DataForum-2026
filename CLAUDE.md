# TuTurno · instrucciones para Claude Code

## Qué es
App para chicos y chicas de 12 a 18 años con tres módulos: el juego «Vive el caso», las lecciones «Aprende» y el agente de voz «Pregunta». La arquitectura completa está en docs/ARQUITECTURA.md.

## Reglas
- No cambies los contratos de la API (docs/ARQUITECTURA.md, sección 8) ni los esquemas de contenido (sección 9) sin avisar.
- A trabaja en app/. B trabaja en backend/, ml/ y content/. No toques la carpeta del otro sin avisar.
- Nunca subas .env, data/ ni artifacts/.
- El contenido jurídico solo se muestra si tiene "validado": true y fuente.
- El agente habla del proceso, nunca de los hechos, y nunca pregunta qué pasó.
- Sin cuentas ni datos personales. No guardes el texto de los usuarios en los logs.

## Flutter (app/)
- Riverpod para el estado, go_router para las rutas, http para la API.
- Interfaz TuTurnoApi con HttpTuTurnoApi y MockTuTurnoApi.
- Un directorio por funcionalidad en lib/features/.
- Accesibilidad: Semantics, tamaño de texto del sistema, zonas táctiles de 48 px.
- Comprobar con: flutter analyze

## Python (backend/ y ml/)
- FastAPI y Pydantic v2, con tipos en todas las funciones.
- La configuración solo se lee en app/config.py (.env).
- Los modelos se cargan una vez al arrancar.
- Comprobar con: ruff check . && pytest -q

## Comandos
- Backend: uvicorn app.main:app --reload --port 8000
- App: flutter run -d chrome --dart-define=API_URL=http://localhost:8000
- App sin backend: flutter run -d chrome --dart-define=USE_MOCK=true
- Contenido: python scripts/validate_content.py && ./scripts/sync_content.sh
