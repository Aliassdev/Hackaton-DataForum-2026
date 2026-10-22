"""Sesión con el agente de ElevenLabs sin que la app vea la API key (ARQUITECTURA.md, sección 8.5).

- GET /api/session/token → {"token": "..."}: token de conversación (WebRTC) de corta duración para el agente
  privado. La app Flutter (SDK elevenlabs_agents) abre la sesión con startSession(conversationToken: token).
  ElevenLabs: GET /v1/convai/conversation/token?agent_id=... con la cabecera xi-api-key, que responde
  {"token": "...", "conversation_id": "..."}.
- GET /api/session/signed-url → {"signed_url": "..."}: URL firmada para el SDK de React (WebSocket).
Los dos abren una conversación que gasta créditos, así que comparten el límite de peticiones "sesion".
Nunca se registran la URL (lleva el agent_id), la API key ni el token.
"""

import logging

import httpx
from fastapi import APIRouter, Depends

from app.api.errores import ErrorApi
from app.api.limites import proteger
from app.config import settings

router = APIRouter()
log = logging.getLogger("tuturno.session")

API_CONVAI = "https://api.elevenlabs.io/v1/convai/conversation"
TOKEN_ENDPOINT = f"{API_CONVAI}/token"
SIGNED_URL_ENDPOINT = f"{API_CONVAI}/get-signed-url"
MENSAJE_SIN_VOZ = "La voz no está disponible ahora. Puedes escribir tu pregunta."


def _cliente() -> httpx.AsyncClient:
    return httpx.AsyncClient(timeout=10)


async def _pedir_a_elevenlabs(url: str, campo: str) -> str:
    if not settings.elevenlabs_api_key or not settings.elevenlabs_agent_id:
        log.warning("Falta ELEVENLABS_API_KEY o ELEVENLABS_AGENT_ID: no se puede abrir la sesión de voz")
        raise ErrorApi(503, "SIN_CONFIGURACION", MENSAJE_SIN_VOZ)
    try:
        async with _cliente() as cliente:
            resp = await cliente.get(
                url,
                params={"agent_id": settings.elevenlabs_agent_id},
                headers={"xi-api-key": settings.elevenlabs_api_key},
            )
    except httpx.HTTPError as e:
        log.warning("ElevenLabs no responde al pedir %s (%s)", campo, type(e).__name__)
        raise ErrorApi(502, "ELEVENLABS_NO_DISPONIBLE", MENSAJE_SIN_VOZ) from e
    if resp.status_code != 200:
        log.warning("ElevenLabs respondió %s al pedir %s", resp.status_code, campo)
        raise ErrorApi(502, "ELEVENLABS_NO_DISPONIBLE", MENSAJE_SIN_VOZ)
    try:
        valor = resp.json().get(campo)
    except (ValueError, AttributeError):
        valor = None
    if not isinstance(valor, str) or not valor:
        log.warning("La respuesta de ElevenLabs no trae %s", campo)
        raise ErrorApi(502, "ELEVENLABS_NO_DISPONIBLE", MENSAJE_SIN_VOZ)
    return valor


@router.get("/api/session/token", dependencies=[Depends(proteger("sesion"))])
async def conversation_token() -> dict[str, str]:
    return {"token": await _pedir_a_elevenlabs(TOKEN_ENDPOINT, "token")}


@router.get("/api/session/signed-url", dependencies=[Depends(proteger("sesion"))])
async def signed_url() -> dict[str, str]:
    return {"signed_url": await _pedir_a_elevenlabs(SIGNED_URL_ENDPOINT, "signed_url")}
