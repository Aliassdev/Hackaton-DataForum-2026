"""Capa 1: guardrail de entrada. Decide si el mensaje sigue hacia el LLM o se responde con plantilla.

1. Reglas de crisis (regex sobre texto normalizado): alta cobertura, ante la duda saltan.
2. Clasificador entrenado (crisis / hechos / fuera_de_ambito / normal).
Si no hay modelo entrenado, funciona solo con reglas.
"""

import json
import logging
import random
import re
import time
import unicodedata
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path

from app.agent import clasificador
from app.agent.verificacion import sin_etiquetas
from app.config import settings

log = logging.getLogger("tuturno.safety")


def normalizar(texto: str) -> str:
    texto = unicodedata.normalize("NFD", texto.lower())
    texto = "".join(c for c in texto if unicodedata.category(c) != "Mn")  # quita tildes (ñ -> n)
    texto = re.sub(r"[^a-z0-9 ]+", " ", texto)
    texto = re.sub(r"([aeiou])\1+", r"\1", texto)  # quieroo -> quiero
    texto = re.sub(r"(.)\1{2,}", r"\1", texto)  # porfavorrr -> porfavor
    return re.sub(r"\s+", " ", texto).strip()


@dataclass
class Decision:
    categoria: str  # crisis | hechos | fuera_de_ambito | normal
    origen: str  # regla | modelo | sin_modelo
    regla: str | None = None
    probabilidades: dict[str, float] = field(default_factory=dict)
    ms: float = 0.0


class Guardrail:
    def __init__(self, patrones_path: Path, modelo_dir: Path | None, umbral_crisis: float, umbral_otros: float):
        datos = json.loads(patrones_path.read_text(encoding="utf-8"))
        self.reglas = [(p["id"], re.compile(p["patron"])) for p in datos["patrones"]]
        self.umbral_crisis = umbral_crisis
        self.umbral_otros = umbral_otros
        self.modelo = None
        if modelo_dir and (modelo_dir / "metadata.json").exists():
            self.modelo, meta = clasificador.cargar(modelo_dir)
            log.info("Guardrail con modelo %s (%s)", meta["tipo"], modelo_dir)
        else:
            log.warning("Guardrail sin modelo entrenado en %s: solo reglas", modelo_dir)

    def regla_crisis(self, texto: str) -> str | None:
        norm = normalizar(texto)
        return next((rid for rid, patron in self.reglas if patron.search(norm)), None)

    def evaluar(self, texto: str) -> Decision:
        inicio = time.perf_counter()
        if regla := self.regla_crisis(texto):
            decision = Decision("crisis", "regla", regla=regla)
        elif self.modelo is None:
            decision = Decision("normal", "sin_modelo")
        else:
            probs = self.modelo.probabilidades([texto])[0]
            decision = Decision(clasificador.decidir(probs, self.umbral_crisis, self.umbral_otros), "modelo", probabilidades=probs)
        decision.ms = (time.perf_counter() - inicio) * 1000
        return decision


@lru_cache
def get_guardrail() -> Guardrail:
    return Guardrail(
        settings.content_dir / "seguridad_patrones.json",
        settings.guardrail_modelo_dir,
        settings.guardrail_umbral_crisis,
        settings.guardrail_umbral_otros,
    )


@lru_cache
def _plantillas() -> dict[str, list[str]]:
    return json.loads((settings.content_dir / "seguridad.json").read_text(encoding="utf-8"))


def plantilla(categoria: str) -> str:
    return random.choice(_plantillas()[categoria])


def plantilla_voz(categoria: str) -> str:
    """Para el Custom LLM. Sin las etiquetas de tono ([slow]) salvo con TTS_ETIQUETAS=true: la voz
    eleven_flash_v2_5 no las entiende y las leería en alto."""
    texto = plantilla(categoria)
    return texto if settings.tts_etiquetas else sin_etiquetas(texto)


# Las plantillas están escritas para la voz: teléfonos con letras y etiquetas de tono ([slow]) que no se leen.
# El canal de texto (POST /api/agent/ask y /api/learn/grade) las enseña en pantalla: sin etiquetas y en cifras.
TELEFONOS_EN_CIFRAS = {
    "novecientos, veinte, veinte, diez": "900 20 20 10",
    "ciento dieciséis, ciento once": "116 111",
    "uno, uno, dos": "112",
}
RE_ETIQUETA_VOZ = re.compile(r"\[[a-záéíóúñ ]+\]\s*")


def para_pantalla(texto: str) -> str:
    texto = RE_ETIQUETA_VOZ.sub("", texto)
    for letras, cifras in TELEFONOS_EN_CIFRAS.items():
        texto = texto.replace(letras, cifras)
    return texto.strip()


def plantilla_texto(categoria: str) -> str:
    return para_pantalla(plantilla(categoria))
