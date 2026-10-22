"""POST /api/learn/grade: corrige «Dilo con tus palabras» (ARQUITECTURA.md, sección 8.2).

Lo primero, el guardrail: si el texto suena a crisis no se corrige, y se devuelve la plantilla de ayuda con
"tipo": "crisis". Ese campo es nuevo y compatible hacia atrás: las respuestas corregidas llevan "normal".
Después, el LLM como juez (app/agent/evaluador.py). El texto del alumno nunca va al log.
"""

import logging
import re
import time
from typing import Annotated, Literal

import httpx
from fastapi import APIRouter, Depends
from pydantic import BaseModel, StringConstraints

from app.agent.evaluador import conceptos, evaluar
from app.agent.safety import get_guardrail, plantilla_texto
from app.api.errores import ErrorApi, resumen_error
from app.api.limites import proteger
from app.llm.client import ErrorLLM

router = APIRouter()
log = logging.getLogger("tuturno.learn")

MENSAJE_CONCEPTO = "No he podido corregir este ejercicio. Prueba con otro."


class PeticionGrade(BaseModel):
    concepto_id: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=80)]
    texto: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=2000)]


class RespuestaGrade(BaseModel):
    puntuacion: float
    cubiertas: list[str]
    faltan: list[str]
    feedback: str
    tipo: Literal["normal", "crisis"] = "normal"


@router.post("/api/learn/grade", dependencies=[Depends(proteger("grade"))])
def grade(peticion: PeticionGrade) -> RespuestaGrade:
    inicio = time.perf_counter()
    decision = get_guardrail().evaluar(peticion.texto)
    if decision.categoria == "crisis":  # antes que nada: aunque el concepto no exista, se ofrece ayuda
        log.info("Grade: crisis (origen=%s, regla=%s)", decision.origen, decision.regla)
        return RespuestaGrade(puntuacion=0.0, cubiertas=[], faltan=[], feedback=plantilla_texto("crisis"), tipo="crisis")

    concepto = conceptos().get(peticion.concepto_id)
    if concepto is None:
        log.warning("Grade: concepto sin ideas clave (%s)", re.sub(r"[^\w.-]", "?", peticion.concepto_id)[:40])
        raise ErrorApi(404, "CONCEPTO_DESCONOCIDO", MENSAJE_CONCEPTO)
    try:
        nota = evaluar(concepto, peticion.texto)
    except (ErrorLLM, httpx.HTTPError) as e:
        log.error("Grade sin respuesta del LLM (%s)", resumen_error(e))
        raise ErrorApi(503, "LLM_NO_DISPONIBLE") from e
    except Exception as e:  # la app siempre recibe el formato 8.4
        log.error("Grade: fallo inesperado (%s)", resumen_error(e))
        raise ErrorApi(500, "ERROR_INTERNO") from e

    log.info(
        "Grade: %s · %d de %d ideas · %.0f ms",
        concepto.id, len(nota.cubiertas), len(concepto.proposiciones), (time.perf_counter() - inicio) * 1000,
    )
    return RespuestaGrade(puntuacion=nota.puntuacion, cubiertas=nota.cubiertas, faltan=nota.faltan, feedback=nota.feedback)
