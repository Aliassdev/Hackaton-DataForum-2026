"""POST /api/agent/ask: modo texto de Pregunta (ARQUITECTURA.md, sección 8.1).

Lo usan la versión web (iPhone) y la APK cuando ElevenLabs no está disponible. Mismas capas que la voz:
guardrail (si no es "normal", plantilla fija sin LLM) → datos personales fuera → reformulación y RAG →
generación → verificación. La respuesta se lee en pantalla: cifras, párrafos cortos y las fuentes aparte.
El texto del usuario nunca va al log: solo el tipo, el perfil (categorías), las fuentes y la latencia.
"""

import logging
import re
import time
from typing import Annotated, Literal

import httpx
from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field, StringConstraints

from app.agent import orquestador
from app.agent.perfil import normalizar_perfil
from app.agent.safety import get_guardrail, plantilla_texto
from app.api.errores import ErrorApi, resumen_error
from app.api.limites import proteger
from app.llm.client import ErrorLLM
from app.rag.retrieve import Fragmento

router = APIRouter()
log = logging.getLogger("tuturno.agent")

MAX_HISTORIAL = 4  # la app manda como mucho los 4 últimos mensajes (8.1)
ROLES_HISTORIAL = {"usuario": "user", "asistente": "assistant"}
RE_ARTICULO = re.compile(r"^(\d+)([a-z]+)$")  # 449ter → 449 ter

Corto = Annotated[str, StringConstraints(strip_whitespace=True, max_length=40)]


class MensajeHistorial(BaseModel):
    rol: Literal["usuario", "asistente"]
    texto: Annotated[str, StringConstraints(max_length=4000)]


class PerfilPeticion(BaseModel):
    """Variables del formulario de entrada (8.6), con los mismos valores que la sesión de voz."""

    edad: Corto | int | None = None
    procedimiento: Corto | None = None
    rol: Corto | None = None
    fase: Corto | None = None


class PeticionAsk(BaseModel):
    pregunta: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=2000)]
    modo: Literal["libre", "situacion"] = "libre"
    situacion: Corto | None = None
    historial: list[MensajeHistorial] = Field(default_factory=list, max_length=20)
    perfil: PerfilPeticion | None = None


class Fuente(BaseModel):
    id: str
    titulo: str
    norma: str
    articulo: str
    url: str = ""


class RespuestaAsk(BaseModel):
    tipo: Literal["normal", "crisis", "hechos", "fuera_de_ambito"]
    respuesta: str
    fuentes: list[Fuente] = []
    sugerencias: list[str] = []
    terminos: list[str] = []
    latencia_ms: int


def perfil_de(peticion: PeticionAsk) -> dict:
    """Perfil del formulario; en «Mi situación», el papel elegido manda sobre el del formulario."""
    perfil = normalizar_perfil(peticion.perfil.model_dump() if peticion.perfil else {})
    if rol := normalizar_perfil({"rol": peticion.situacion}).get("rol"):
        perfil["rol"] = rol
    return perfil


def fuente(f: Fragmento) -> Fuente:
    norma, _, articulo = f.cita.rpartition(" art. ")
    articulo = RE_ARTICULO.sub(r"\1 \2", articulo)
    return Fuente(id=f.articulo_id, titulo=f.titulo or f"Artículo {articulo}", norma=norma or f.ley, articulo=articulo, url=f.url)


def _ms(inicio: float) -> int:
    return round((time.perf_counter() - inicio) * 1000)


@router.post("/api/agent/ask", dependencies=[Depends(proteger("ask"))])
def ask(peticion: PeticionAsk) -> RespuestaAsk:
    inicio = time.perf_counter()
    decision = get_guardrail().evaluar(peticion.pregunta)
    if decision.categoria != "normal":
        log.info("Ask: %s (origen=%s, regla=%s) · %d ms", decision.categoria, decision.origen, decision.regla, _ms(inicio))
        return RespuestaAsk(tipo=decision.categoria, respuesta=plantilla_texto(decision.categoria), latencia_ms=_ms(inicio))

    perfil = perfil_de(peticion)
    mensajes = [{"role": ROLES_HISTORIAL[m.rol], "content": m.texto} for m in peticion.historial[-MAX_HISTORIAL:]]
    mensajes.append({"role": "user", "content": peticion.pregunta})
    try:
        resultado = orquestador.responder_texto(mensajes, perfil)
    except (ErrorLLM, httpx.HTTPError) as e:
        log.error("Ask sin respuesta del LLM (%s)", resumen_error(e))
        raise ErrorApi(503, "LLM_NO_DISPONIBLE") from e
    except Exception as e:  # la app siempre recibe el formato 8.4
        log.error("Ask: fallo inesperado (%s)", resumen_error(e))
        raise ErrorApi(500, "ERROR_INTERNO") from e

    fuentes = [fuente(f) for f in resultado.fragmentos]
    log.info("Ask: normal · perfil=%s · fuentes=%s · %d ms", perfil, [f.id for f in fuentes], _ms(inicio))
    return RespuestaAsk(tipo="normal", respuesta=resultado.texto, fuentes=fuentes, latencia_ms=_ms(inicio))
