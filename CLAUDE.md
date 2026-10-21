# CLAUDE.md

## Proyecto

**TuTurno** es una app para un datathon jurídico y de IA sobre el acceso a la justicia de los menores.

Nuestra parte es un **chatbot por voz** conectado a **ElevenLabs Agents**. Acompaña a menores de 12 a 17 años antes, durante y después de un procedimiento judicial (penal, familia, protección...).

La arquitectura detallada está en [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md).

## Funcionamiento

- **Onboarding en la app** (formulario, no voz): se recogen
  - edad
  - tipo de procedimiento
  - rol: víctima, testigo, investigado (solo 14+ en penal), menor escuchado en un proceso de familia...
  - fase: antes / durante / después
- Esos datos se pasan al agente como **dynamic variables** de ElevenLabs: `edad`, `procedimiento` (`penal` | `familia` | `proteccion` | `ninguno`), `rol` (`victima` | `testigo` | `investigado` | `escuchado`) y `fase` (`antes` | `durante` | `despues`). El backend las lee de la línea `Perfil: edad=...; ...` del prompt que envía ElevenLabs.
- El lenguaje se adapta a tres franjas de edad: **12-13**, **14-15** y **16-17**.
- Las respuestas se basan en un **RAG** sobre 10 normas: LECrim, LEC, LORPM, LO 1/1996, LOPIVI, LO 1/1982, Código Penal, LOPDGDD, RGPD y la Convención sobre los Derechos del Niño.

## Límites del agente

Respétalos en prompts, flujos y textos de la UI:

- **No habla de los hechos del caso**, por el riesgo de contaminar el testimonio.
- **No da consejo legal** ni predice resultados.
- **No promete confidencialidad absoluta.**
- **Deriva a ANAR** (900 20 20 10 / 116 111) si detecta riesgo.

## Stack

- **Frontend web** con `@elevenlabs/react`.
- **Voz:** la voz del menor se transcribe en el dispositivo y el texto se envía al agente con `sendUserMessage` (sesión con el micrófono silenciado). ElevenLabs solo genera la voz del agente.
- **Backend** (FastAPI, `backend/`):
  - Genera la signed URL (`GET /api/session/signed-url`).
  - Hace de **Custom LLM** del agente: `POST /v1/chat/completions`, compatible con OpenAI y en streaming (SSE).
- La API key de ElevenLabs **nunca** va en el frontend: se guarda en `.env`, y `.env` debe estar en `.gitignore`.

## Pipeline del backend (por cada mensaje)

1. **Guardrail** (`app/agent/safety.py`): reglas de crisis + BETO con ajuste fino (crisis / hechos / fuera_de_ambito / normal). Crisis = solo riesgo inminente (suicidio, autolesión, peligro ahora). Si no es `normal`, plantilla fija de `content/seguridad.json` sin llamar al LLM.
2. **Datos personales** fuera (`app/agent/pii.py`) antes de enviar nada a la API.
3. **Reformulación jurídica** de la pregunta con un LLM rápido y **RAG híbrido** (`app/rag/retrieve.py`): BM25 + multilingual-e5, RRF, refuerzo por perfil (`content/rag_perfiles.json`), 6 artículos.
4. **Generación** (`app/agent/prompts.py`, `app/llm/client.py`): prompt propio por franja y perfil, formato para voz. LLM por API compatible con OpenAI (Groq por defecto, configurable en `.env`).
5. **Verificación frase a frase** (`app/agent/verificacion.py`) antes de la voz: elimina preguntas por los hechos, promesas de secreto y predicciones; números en letras.

## Comandos

Desde la raíz del repo, con el venv del backend (`backend/.venv`):

- Tests: `cd backend && .venv/Scripts/python -m pytest -q`
- Backend: `cd backend && .venv/Scripts/python -m uvicorn app.main:app --port 8000`
- Reconstruir RAG: `backend/.venv/Scripts/python -X utf8 ml/ingest_leyes.py` y después `ml/build_index.py`
- Entrenar guardrail: `backend/.venv/Scripts/python ml/train_guardrail.py --modo finetune --out artifacts/models/guardrail_finetune_v2`
- Evaluaciones: `ml/eval_guardrail.py --modelo artifacts/models/guardrail_finetune_v2`, `ml/eval_rag.py`, `ml/eval_respuestas.py`
- Agente ElevenLabs: `backend/scripts/setup_agent.py https://<túnel>` (crea o actualiza la URL) y `backend/scripts/probar_agente.py --perfil "edad=13;procedimiento=penal;rol=victima" "pregunta"`

`artifacts/` (modelos e índices) no está en git: se regenera con los comandos anteriores.
