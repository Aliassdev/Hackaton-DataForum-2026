"""Signed URL para que el frontend abra la sesión con el agente sin ver la API key."""

import httpx
from fastapi import APIRouter, HTTPException

from app.config import settings

router = APIRouter()

SIGNED_URL_ENDPOINT = "https://api.elevenlabs.io/v1/convai/conversation/get-signed-url"


@router.get("/api/session/signed-url")
async def signed_url() -> dict:
    if not settings.elevenlabs_api_key or not settings.elevenlabs_agent_id:
        raise HTTPException(503, "Falta ELEVENLABS_API_KEY o ELEVENLABS_AGENT_ID en .env")

    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(
            SIGNED_URL_ENDPOINT,
            params={"agent_id": settings.elevenlabs_agent_id},
            headers={"xi-api-key": settings.elevenlabs_api_key},
        )
    if resp.status_code != 200:
        raise HTTPException(502, f"ElevenLabs respondió {resp.status_code}")
    return {"signed_url": resp.json()["signed_url"]}
