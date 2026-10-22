"""Piezas comunes de los tests de los endpoints. Sin red: el LLM, ElevenLabs y el RAG son de mentira."""

from dataclasses import replace

import pytest
from fastapi.testclient import TestClient

from app.agent import orquestador
from app.agent.safety import Decision, Guardrail
from app.api import agent as agent_api
from app.api import learn as learn_api
from app.api import limites
from app.api import llm as llm_api
from app.config import settings
from app.llm import client as cliente_llm
from app.main import app
from app.rag.retrieve import Fragmento

FRAGMENTOS = [
    Fragmento(
        "LORPM-3", "LORPM-3", "LORPM", "LORPM art. 3", "Régimen de los menores de catorce años",
        "Cuando el autor de los hechos sea menor de catorce años, no se le exigirá responsabilidad con arreglo a la presente Ley.",
        "https://www.boe.es/buscar/act.php?id=BOE-A-2000-641#a3", 0.031,
    ),
    Fragmento(
        "LECRIM-449ter#1", "LECRIM-449ter", "LECRIM", "LECrim art. 449ter", "",
        "Cuando una persona menor de catorce años deba intervenir como testigo, la autoridad judicial acordará la práctica de la prueba preconstituida.",
        "https://www.boe.es/buscar/act.php?id=BOE-A-1882-6036#a449ter", 0.029,
    ),
    Fragmento(
        "LOPJM-9", "LOPJM-9", "LOPJM", "LO 1/1996 art. 9", "Derecho a ser oído y escuchado",
        "El menor tiene derecho a ser oído y escuchado sin discriminación alguna por edad.",
        "https://www.boe.es/buscar/act.php?id=BOE-A-1996-1069#a9", 0.020,
    ),
]


class RecuperadorFalso:
    def __init__(self, fragmentos: list[Fragmento]) -> None:
        self.fragmentos = fragmentos
        self.llamadas: list[dict] = []
        self.rankings_pedidos: list[str] = []

    def rankings(self, consulta: str, modo: str = "hibrido_perfil") -> list[list[int]]:
        self.rankings_pedidos.append(consulta)
        return [[0, 1, 2]]

    def buscar(
        self, pregunta: str, perfil: dict | None = None, k: int = 5, consulta_juridica: str | None = None,
        rankings_pregunta: list[list[int]] | None = None, **_: object,
    ) -> list[Fragmento]:
        self.llamadas.append({"pregunta": pregunta, "perfil": perfil, "consulta": consulta_juridica, "rankings": rankings_pregunta})
        return self.fragmentos[:k]


class LLMFalso:
    """Devuelve en orden las respuestas de la cola (una excepción se lanza). La reformulación jurídica, si la
    hay (con LLM_API_KEY en .env), contesta aparte para no gastar la cola."""

    def __init__(self) -> None:
        self.respuestas: list[str | Exception] = []
        self.llamadas: list[dict] = []

    def completar(
        self, mensajes: list[dict], modelo: str, max_tokens: int = 250, temperatura: float = 0.0, json_obj: bool = False, **_: object,
    ) -> str:
        if "Consulta jurídica:" in mensajes[-1]["content"]:
            return "consulta jurídica de prueba"
        self.llamadas.append({"mensajes": mensajes, "modelo": modelo, "json_obj": json_obj})
        respuesta = self.respuestas.pop(0) if self.respuestas else ""
        if isinstance(respuesta, Exception):
            raise respuesta
        return respuesta

    def stream(self, *_: object, **__: object) -> None:
        raise AssertionError("el canal de texto no usa streaming")


class GuardrailFijo:
    def __init__(self, categoria: str) -> None:
        self.categoria = categoria

    def evaluar(self, texto: str) -> Decision:
        return Decision(self.categoria, "modelo")


@pytest.fixture(autouse=True)
def limites_limpios():
    """El limitador vive en memoria toda la sesión de tests: se vacía antes y después de cada test."""
    limites.limitador.reiniciar()
    yield
    limites.limitador.reiniciar()


@pytest.fixture(scope="session")
def reglas() -> Guardrail:
    return Guardrail(settings.content_dir / "seguridad_patrones.json", None, 0.3, 0.5)


@pytest.fixture
def guardrail(monkeypatch: pytest.MonkeyPatch, reglas: Guardrail) -> Guardrail:
    """Solo reglas, sin el modelo BETO: el resultado no depende de lo que haya en artifacts/."""
    for modulo in (agent_api, learn_api, llm_api):
        monkeypatch.setattr(modulo, "get_guardrail", lambda: reglas)
    return reglas


@pytest.fixture
def fijar_guardrail(monkeypatch: pytest.MonkeyPatch):
    def fijar(categoria: str) -> None:
        for modulo in (agent_api, learn_api, llm_api):
            monkeypatch.setattr(modulo, "get_guardrail", lambda: GuardrailFijo(categoria))

    return fijar


@pytest.fixture
def fragmentos() -> list[Fragmento]:
    return list(FRAGMENTOS)


@pytest.fixture
def recuperador(monkeypatch: pytest.MonkeyPatch) -> RecuperadorFalso:
    falso = RecuperadorFalso(FRAGMENTOS)
    monkeypatch.setattr(orquestador, "get_recuperador", lambda: falso)
    return falso


@pytest.fixture
def llm(monkeypatch: pytest.MonkeyPatch) -> LLMFalso:
    falso = LLMFalso()
    monkeypatch.setattr(cliente_llm, "completar", falso.completar)
    monkeypatch.setattr(cliente_llm, "stream", falso.stream)
    return falso


@pytest.fixture
def ajustar(monkeypatch: pytest.MonkeyPatch):
    """Cambia valores de config.py en un módulo (Settings es inmutable: se sustituye por una copia)."""

    def cambiar(modulo: object, **valores: object) -> None:
        monkeypatch.setattr(modulo, "settings", replace(modulo.settings, **valores))

    return cambiar


@pytest.fixture
def cliente() -> TestClient:
    return TestClient(app)
