"""«Dilo con tus palabras» (POST /api/learn/grade, sección 8.2): un LLM como juez decide qué ideas clave
cubre el texto del alumno.

El LLM solo devuelve los números de las ideas cubiertas, en JSON estricto. La puntuación y el feedback se
calculan aquí con frases fijas: ningún texto del LLM llega a la app, así que no puede comentar lo que haya
escrito el alumno. Las ideas clave salen de content/ejercicios/*.json (esquema 9.3, cuando exista) y de
content/evaluador.json; solo las validadas y con fuente.
"""

import json
import logging
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from pydantic import BaseModel, ValidationError

from app.agent import prompts
from app.agent.pii import limpiar
from app.config import settings
from app.llm import client

log = logging.getLogger("tuturno.evaluador")

INTENTOS = 2  # si el juez devuelve un JSON que no vale, se le pregunta una vez más
MAX_TOKENS = 400  # incluye el razonamiento de gpt-oss


@dataclass(frozen=True)
class Concepto:
    id: str
    pregunta: str
    proposiciones: tuple[str, ...]


@dataclass
class Nota:
    puntuacion: float
    cubiertas: list[str]
    faltan: list[str]
    feedback: str


class Juicio(BaseModel):
    cubiertas: list[int]


def _leer(ruta: Path) -> list[dict]:
    try:
        datos = json.loads(ruta.read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        log.error("Evaluador: no se puede leer %s (%s)", ruta.name, type(e).__name__)
        return []
    datos = datos.get("conceptos", []) if isinstance(datos, dict) else datos
    return [e for e in datos if isinstance(e, dict)]


@lru_cache
def conceptos() -> dict[str, Concepto]:
    """Si un concepto sale varias veces, vale el primero (content/ejercicios va antes que evaluador.json)."""
    carpeta = settings.content_dir / "ejercicios"
    rutas = sorted(carpeta.glob("*.json")) if carpeta.is_dir() else []
    entradas = [e for ruta in rutas for e in _leer(ruta) if e.get("tipo") == "dilo"]
    if (archivo := settings.content_dir / "evaluador.json").exists():
        entradas += _leer(archivo)
    salida: dict[str, Concepto] = {}
    for e in entradas:
        ideas = tuple(p.strip() for p in e.get("proposiciones", []) if isinstance(p, str) and p.strip())
        if e.get("validado") is True and e.get("fuente") and e.get("concepto") and ideas:
            salida.setdefault(e["concepto"], Concepto(e["concepto"], str(e.get("pregunta", "")), ideas))
    log.info("Evaluador: %d conceptos con ideas clave", len(salida))
    return salida


def _en_minuscula(idea: str) -> str:
    idea = idea.strip().rstrip(".")
    return idea[0].lower() + idea[1:] if len(idea) > 1 and not idea[1].isupper() else idea


def feedback(cubiertas: list[str], faltan: list[str]) -> str:
    if not faltan:
        return "¡Genial! Has explicado todas las ideas clave."
    pista = _en_minuscula(faltan[0])
    if not cubiertas:
        return f"Todavía no aparecen las ideas clave. Una pista: {pista}."
    if len(faltan) == 1:
        return f"¡Muy bien! Te falta una idea: {pista}."
    return f"¡Vas bien! Te faltan {len(faltan)} ideas. Por ejemplo: {pista}."


def evaluar(concepto: Concepto, texto: str) -> Nota:
    """Lanza client.ErrorLLM si el juez no contesta con un JSON válido."""
    mensajes = [
        {"role": "system", "content": prompts.evaluar(concepto.pregunta, concepto.proposiciones)},
        {"role": "user", "content": f"TEXTO DEL ALUMNO:\n{limpiar(texto)}"},
    ]
    juicio = None
    for intento in range(1, INTENTOS + 1):
        bruto = client.completar(mensajes, modelo=settings.llm_modelo_evaluar, max_tokens=MAX_TOKENS, json_obj=True)
        try:
            juicio = Juicio.model_validate_json(bruto)
            break
        except ValidationError:
            log.warning("El juez no ha devuelto un JSON válido (intento %d)", intento)
    if juicio is None:
        raise client.ErrorLLM("El juez no ha devuelto un JSON válido")
    elegidas = {i for i in juicio.cubiertas if 1 <= i <= len(concepto.proposiciones)}
    cubiertas = [p for i, p in enumerate(concepto.proposiciones, 1) if i in elegidas]
    faltan = [p for i, p in enumerate(concepto.proposiciones, 1) if i not in elegidas]
    return Nota(round(len(cubiertas) / len(concepto.proposiciones), 2), cubiertas, faltan, feedback(cubiertas, faltan))
