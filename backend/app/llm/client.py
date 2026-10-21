"""Cliente LLM para cualquier API compatible con OpenAI Chat Completions (Groq, vLLM, Ollama...).

El proveedor se elige en .env (LLM_BASE_URL, LLM_API_KEY, LLM_MODELO...): cambiar de Groq a un
modelo local es cambiar la URL, sin tocar código.
"""

import json
import logging
import time
from collections.abc import Iterator

import httpx

from app.config import settings

log = logging.getLogger("tuturno.llm.client")
TIMEOUT = httpx.Timeout(connect=5.0, read=20.0, write=10.0, pool=5.0)


class ErrorLLM(Exception):
    pass


def _cabeceras() -> dict:
    if not settings.llm_api_key:
        raise ErrorLLM("Falta LLM_API_KEY (o GROQ_API_KEY) en .env")
    return {"Authorization": f"Bearer {settings.llm_api_key}"}


def _post(cuerpo: dict, reintentos: int = 2) -> httpx.Response:
    """POST no streaming con reintento ante 429 (límite del plan gratuito) y errores 5xx."""
    for intento in range(reintentos + 1):
        r = httpx.post(f"{settings.llm_base_url}/chat/completions", json=cuerpo, headers=_cabeceras(), timeout=TIMEOUT)
        if r.status_code == 429 or r.status_code >= 500:
            espera = float(r.headers.get("retry-after", 2 ** intento))
            log.warning("LLM %s, reintento en %.1f s", r.status_code, espera)
            time.sleep(min(espera, 10))
            continue
        if r.status_code >= 400:
            raise ErrorLLM(f"LLM {r.status_code}: {r.text[:200]}")
        return r
    raise ErrorLLM(f"LLM sin respuesta tras {reintentos + 1} intentos ({r.status_code})")


def _cuerpo(mensajes: list[dict], modelo: str, max_tokens: int, temperatura: float) -> dict:
    cuerpo = {"model": modelo, "messages": mensajes, "max_tokens": max_tokens, "temperature": temperatura}
    if modelo.startswith("openai/gpt-oss"):
        # Modelos con razonamiento: el mínimo y oculto, para que la voz no espere (max_tokens lo incluye)
        cuerpo |= {"reasoning_effort": "low", "include_reasoning": False}
    return cuerpo


def completar(mensajes: list[dict], modelo: str, max_tokens: int = 250, temperatura: float = 0.0) -> str:
    return (_post(_cuerpo(mensajes, modelo, max_tokens, temperatura)).json()["choices"][0]["message"]["content"] or "").strip()


def stream(mensajes: list[dict], modelo: str, max_tokens: int = 600, temperatura: float = 0.3) -> Iterator[str]:
    """Devuelve el texto según llega. Lanza ErrorLLM si falla antes del primer token."""
    cuerpo = _cuerpo(mensajes, modelo, max_tokens, temperatura) | {"stream": True}
    with httpx.stream("POST", f"{settings.llm_base_url}/chat/completions", json=cuerpo, headers=_cabeceras(), timeout=TIMEOUT) as r:
        if r.status_code >= 400:
            r.read()
            raise ErrorLLM(f"LLM {r.status_code}: {r.text[:200]}")
        for linea in r.iter_lines():
            if not linea.startswith("data: ") or linea == "data: [DONE]":
                continue
            delta = json.loads(linea[6:])["choices"][0].get("delta", {})
            if texto := delta.get("content"):
                yield texto
