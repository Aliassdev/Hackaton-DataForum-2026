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
- Esos datos se pasan al agente como **dynamic variables** de ElevenLabs.
- El lenguaje se adapta a tres franjas de edad: **12-13**, **14-15** y **16-17**.
- Las respuestas se basan en una **knowledge base (RAG)** con guías validadas.

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
  - Hace de **Custom LLM** del agente: `POST /v1/chat/completions`, compatible con OpenAI y en streaming (SSE). Aquí va el orquestador: seguridad → datos personales → RAG → LLM → verificación.
- La API key de ElevenLabs **nunca** va en el frontend: se guarda en `.env`, y `.env` debe estar en `.gitignore`.
