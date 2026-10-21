"""Custom LLM para ElevenLabs Agents: endpoint compatible con OpenAI Chat Completions (SSE).

En el agente de ElevenLabs se configura la URL del servidor como https://<túnel>/v1
y ElevenLabs llama a /v1/chat/completions con stream=true.

De momento devuelve una respuesta fija: sirve para probar la conexión de punta a punta
y ver qué nos llega (dynamic variables, extra body). Aquí irá el orquestador
(seguridad → datos personales → RAG → LLM → verificación).
"""

import json
import logging
import time
import uuid
from collections.abc import Iterator

from fastapi import APIRouter, Header, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, ConfigDict

from app.config import settings

router = APIRouter()
log = logging.getLogger("tuturno.llm")

RESPUESTA_FIJA = "Hola, soy TuTurno. Te contesto desde el servidor del equipo. La conexión funciona."


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


def _stream(texto: str) -> Iterator[str]:
    chat_id = f"chatcmpl-{uuid.uuid4().hex}"
    created = int(time.time())
    yield _chunk(chat_id, created, {"role": "assistant"})
    for palabra in texto.split(" "):
        yield _chunk(chat_id, created, {"content": palabra + " "})
    yield _chunk(chat_id, created, {}, finish_reason="stop")
    yield "data: [DONE]\n\n"


@router.post("/v1/chat/completions")
def chat_completions(req: ChatRequest, authorization: str | None = Header(default=None)):
    _comprobar_secreto(authorization)
    if settings.debug_llm_requests:
        _registrar_estructura(req)
    return StreamingResponse(_stream(RESPUESTA_FIJA), media_type="text/event-stream")
