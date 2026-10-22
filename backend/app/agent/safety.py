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


# Cifras pegadas a letras («m4t4rm3», «su1c1d4rm3»): se leen como letras solo para las reglas de crisis. «13 años» no
# cambia, porque la cifra no toca ninguna letra.
LEET = str.maketrans("4310572", "aeiostz")
RE_CIFRA_EN_PALABRA = re.compile(r"\b(?=\w*[a-z])(?=\w*\d)\w+\b")


def sin_leet(norm: str) -> str:
    return RE_CIFRA_EN_PALABRA.sub(lambda m: m.group().translate(LEET), norm)


# «Hechos» sin clasificador (22/10/2026). El Space va sin modelo, así que nada salía como «hechos»: «El que me insultaba era
# mi compañero de mesa.» (el momento de seguridad de la demo, plan v2, 2.3) iba al LLM, que contestaba con lo que le iba
# a pasar al compañero y con una orden de protección (3 de 3 contra el Space). Estas reglas cogen solo frases que
# CUENTAN lo que pasó y no preguntan nada: con «?», «¿» o una palabra de pregunta («qué», «cómo», «puedo», «tengo
# que»...) siguen al LLM, salvo si, después de contar un momento concreto, pide que se califique («ayer en el recreo me
# quitaron la mochila, ¿eso es acoso?»). Van detrás de las de crisis: «mi entrenador me toca» sigue siendo crisis.
_PASADO_CONTRA_MI = (
    r"(insulto|insultaron|insultaba|insultaban|pego|pegaron|pegaba|pegaban|empujo|empujaron|empujaba|empujaban|quito|quitaron"
    r"|quitaba|quitaban|tiro|tiraron|tiraba|tiraban|robo|robaron|grabo|grabaron|amenazo|amenazaron|amenazaba|amenazaban"
    r"|acoso|acosaron|acosaba|acosaban|toco|tocaron|tocaba|tocaban|rompio|rompieron|escupio|escupieron|encerro|encerraron"
    r"|mando|mandaron|mandaba|mandaban|paso|pasaron|hizo|hicieron|dijo|dijeron|llamo|llamaron|siguio|siguieron)"
)
_PERSONA = (
    r"(companero|companera|amigo|amiga|vecino|vecina|primo|prima|hermano|hermana|tio|tia|padre|madre|padrastro|madrastra"
    r"|novio|novia|profe|profesor|profesora|entrenador|entrenadora|monitor|monitora|chico|chica|hombre|senor|senora)"
)
_MOMENTO = (
    r"(ayer|anteayer|antes de ayer|el otro dia|esta manana|esta tarde|anoche|la semana pasada|el lunes pasado"
    r"|el martes pasado|el miercoles pasado|el jueves pasado|el viernes pasado|el sabado pasado|el domingo pasado"
    r"|en el recreo)"
)
REGLAS_HECHOS = [  # (id, patrón, ¿también si pide calificar lo que cuenta («¿eso es acoso?»)?)
    ("hechos_momento", re.compile(rf"\b{_MOMENTO}\b.{{0,60}}\b(me|nos) {_PASADO_CONTRA_MI}\b"), True),
    ("hechos_quien", re.compile(rf"\b(el|la|los|las) que (me|nos) {_PASADO_CONTRA_MI}\b"), False),
    ("hechos_persona", re.compile(rf"\b(mi|mis|el|la|un|una) {_PERSONA}s? (me|nos|le|les) {_PASADO_CONTRA_MI}\b"), False),
    ("hechos_testigo", re.compile(r"\b(vi como|vi que|vi la|vi el|vi a|estaba delante|estaba alli|recuerdo que|aquel dia)\b"), False),
    ("hechos_propios", re.compile(r"\b(le|les) (quite|pegue|empuje|robe|insulte|pase|mande|grabe|amenace|rompi)\b"
                                  r"|\b(rompimos|robamos|nos colamos|nos peleamos|me pelee)\b"), False),
    ("hechos_te_cuento", re.compile(r"^(te|os) cuento\b"), False),
]
RE_RELATIVO = re.compile(r"\b(el|la|los|las|lo) que\b")
# Sin «cuando» ni «donde»: al contar algo casi siempre son conjunciones («cuando ella no estaba en casa»)
RE_PALABRA_PREGUNTA = re.compile(
    r"\b(que|como|quien|quienes|cual|cuales|cuanto|cuanta|cuantos|cuantas|por que|puedo|puede|pueden|podria"
    r"|podrian|tengo que|tiene que|debo|deberia|hay que|es delito|es legal|seria|se puede|sabes)\b"
)
# Pide que se califique lo que ha contado («Ayer en el recreo me quitaron la mochila, ¿eso es acoso?»): no se contesta
# «sí, eso es acoso» (norma 2). Una pregunta del proceso detrás del relato («¿puedo ir con alguien a declarar?») sí va al LLM.
RE_CALIFICAR = re.compile(
    r"\b(eso|esto|lo que me (hicieron|hizo|paso)) (es|seria|cuenta como|se considera) (acoso|bullying|delito|violencia|abuso"
    r"|agresion|maltrato|normal|grave)\b|^(es|seria) (acoso|bullying|delito)\b"
)


def es_pregunta(texto: str, norm: str) -> bool:
    return "?" in texto or "¿" in texto or bool(RE_PALABRA_PREGUNTA.search(RE_RELATIVO.sub(" ", norm)))


def regla_hechos(texto: str) -> str | None:
    norm = normalizar(texto)
    libre = not es_pregunta(texto, norm)
    calificar = bool(RE_CALIFICAR.search(norm))
    return next((rid for rid, patron, si_califica in REGLAS_HECHOS
                 if (libre or (si_califica and calificar)) and patron.search(norm)), None)


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
        variantes = {norm, sin_leet(norm)}
        return next((rid for rid, patron in self.reglas if any(patron.search(v) for v in variantes)), None)

    def evaluar(self, texto: str) -> Decision:
        inicio = time.perf_counter()
        if regla := self.regla_crisis(texto):
            decision = Decision("crisis", "regla", regla=regla)
        elif regla := regla_hechos(texto):
            decision = Decision("hechos", "regla", regla=regla)
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
