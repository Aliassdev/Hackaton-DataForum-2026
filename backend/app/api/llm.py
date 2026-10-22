"""Custom LLM para ElevenLabs Agents: endpoint compatible con OpenAI Chat Completions (SSE).

En el agente de ElevenLabs se configura la URL del servidor como https://<túnel>/v1
y ElevenLabs llama a /v1/chat/completions con stream=true.

Flujo:
- Si el último turno no es del usuario (ElevenLabs le da la palabra al agente sin que haya un mensaje nuevo), un
  stream vacío y correcto: el agente no dice nada. El guardrail mira solo ese último mensaje del usuario.
- Guardrail (capa 1): si no es "normal", plantilla fija sin LLM (sin etiquetas de tono si TTS_ETIQUETAS=false).
- Si es normal: frase puente (VOZ_FRASE_PUENTE) al instante, para que el agente hable ya, y después perfil (dynamic
  variables) → orquestador: reformulación jurídica en paralelo con el RAG (capa 2) → generación adaptada a la edad
  (capa 3) → verificación frase a frase (capa 4).
Con la frase puente el primer texto sale en milisegundos. Así ElevenLabs tampoco tiene motivo para pasar a su propio LLM
de respaldo (backup_llm_config, sin nuestras capas), que según su API entra a los cascade_timeout_seconds (4 s).
"""

import json
import logging
import time
import uuid
from collections.abc import Iterable, Iterator

from fastapi import APIRouter, Header, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, ConfigDict

from app.agent.orquestador import frase_puente, responder
from app.agent.perfil import extraer_perfil
from app.agent.safety import get_guardrail, plantilla_voz
from app.config import settings

router = APIRouter()
log = logging.getLogger("tuturno.llm")
# Que ningún proxy (el de Hugging Face, nginx...) acumule el SSE: cada trozo tiene que salir en cuanto se escribe
CABECERAS_SSE = {"Cache-Control": "no-cache", "X-Accel-Buffering": "no"}


class ChatMessage(BaseModel):
    model_config = ConfigDict(extra="allow")
    role: str
    content: str | list | None = None


class ChatRequest(BaseModel):
    model_config = ConfigDict(extra="allow")
    messages: list[ChatMessage]
    model: str | None = None
    stream: bool = True


def _comprobar_secreto(authorization: str | None) -> None:
    if settings.custom_llm_secret and authorization != f"Bearer {settings.custom_llm_secret}":
        raise HTTPException(401, "No autorizado")


def _registrar_estructura(req: ChatRequest) -> None:
    """Registra la forma de la petición. El texto del usuario nunca va al log, solo su longitud."""
    resumen = []
    for m in req.messages:
        if m.role == "system":
            resumen.append({"role": "system", "content": m.content})  # el prompt es nuestro: permite ver las dynamic variables
        else:
            texto = m.content if isinstance(m.content, str) else json.dumps(m.content or "")
            resumen.append({"role": m.role, "chars": len(texto)})
    extra = {k: v for k, v in (req.model_extra or {}).items() if k != "elevenlabs_extra_body"}
    log.info(
        "Petición Custom LLM: %s",
        json.dumps(
            {
                "model": req.model,
                "stream": req.stream,
                "messages": resumen,
                "elevenlabs_extra_body": (req.model_extra or {}).get("elevenlabs_extra_body"),
                "otros_campos": sorted(extra),
            },
            ensure_ascii=False,
        ),
    )


def _chunk(chat_id: str, created: int, delta: dict, finish_reason: str | None = None) -> str:
    cuerpo = {
        "id": chat_id,
        "object": "chat.completion.chunk",
        "created": created,
        "model": "tuturno",
        "choices": [{"index": 0, "delta": delta, "finish_reason": finish_reason}],
    }
    return f"data: {json.dumps(cuerpo, ensure_ascii=False)}\n\n"


def _stream_trozos(trozos: Iterable[str]) -> Iterator[str]:
    chat_id = f"chatcmpl-{uuid.uuid4().hex}"
    created = int(time.time())
    yield _chunk(chat_id, created, {"role": "assistant"})
    for trozo in trozos:
        yield _chunk(chat_id, created, {"content": trozo})
    yield _chunk(chat_id, created, {}, finish_reason="stop")
    yield "data: [DONE]\n\n"


def _stream(texto: str) -> Iterator[str]:
    return _stream_trozos(palabra + " " for palabra in texto.split(" "))


def _texto(m: ChatMessage) -> str:
    if isinstance(m.content, list):  # formato por partes: [{"type": "text", "text": ...}]
        return " ".join(p.get("text", "") for p in m.content if isinstance(p, dict))
    return m.content or ""


def pregunta_pendiente(req: ChatRequest) -> str | None:
    """El texto del último turno de la conversación si es del usuario y no está vacío; si no, None. Los mensajes de
    sistema no cuentan como turno."""
    ultimo = next((m for m in reversed(req.messages) if m.role in ("user", "assistant")), None)
    if ultimo is None or ultimo.role != "user":
        return None
    return _texto(ultimo).strip() or None


def _sse(trozos: Iterator[str]) -> StreamingResponse:
    return StreamingResponse(trozos, media_type="text/event-stream", headers=CABECERAS_SSE)


@router.post("/v1/chat/completions")
def chat_completions(req: ChatRequest, authorization: str | None = Header(default=None)):
    _comprobar_secreto(authorization)
    if settings.debug_llm_requests:
        _registrar_estructura(req)

    pregunta = pregunta_pendiente(req)
    if pregunta is None:
        log.info("Turno sin mensaje nuevo del usuario: respuesta vacía")
        return _sse(_stream_trozos([]))
    decision = get_guardrail().evaluar(pregunta)
    log.info("Guardrail: %s (origen=%s, regla=%s, %.0f ms)", decision.categoria, decision.origen, decision.regla, decision.ms)
    if decision.categoria != "normal":
        return _sse(_stream(plantilla_voz(decision.categoria)))

    system = next((m.content for m in req.messages if m.role == "system" and isinstance(m.content, str)), "")
    perfil = extraer_perfil(system)
    log.info("Perfil: %s", perfil)
    mensajes = [{"role": m.role, "content": _texto(m)} for m in req.messages]
    return _sse(_stream_trozos(responder(mensajes, perfil, puente=frase_puente(pregunta))))
