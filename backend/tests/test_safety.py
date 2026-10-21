import pytest

from app.agent.clasificador import decidir
from app.agent.safety import Guardrail, normalizar, plantilla
from app.config import settings


@pytest.fixture(scope="module")
def solo_reglas():
    return Guardrail(settings.content_dir / "seguridad_patrones.json", None, 0.3, 0.5)


def test_normalizar():
    assert normalizar("¡¡Quieroo MORIIIR!!") == "quiero morir"
    assert normalizar("Me hago daño") == "me hago dano"


@pytest.mark.parametrize(
    "texto",
    [
        "quiero morirme",
        "k m kiero morir",
        "Quieroo moriiir",
        "no quiero seguir viviendo",
        "he pensado en suicidarme",
        "me hago daño cuando estoy mal",
        "tengo miedo de volver a casa",
        "me están pegando",
        "si vuelvo a casa me pegan",
        "me van a matar si declaro",
        "me están chantajeando con fotos",
    ],
)
def test_reglas_detectan_crisis(solo_reglas, texto):
    assert solo_reglas.evaluar(texto).categoria == "crisis"


@pytest.mark.parametrize(
    "texto",
    [
        "me muero de vergüenza si tengo que hablar",
        "me mata la espera del juicio",
        "me da miedo declarar",
        "me corto el pelo antes del juicio",
        "si a alguien le pegan en casa qué puede hacer",
        "el chico que me pegó llevaba sudadera",
        "qué pasa si me llaman a declarar",
    ],
)
def test_reglas_no_saltan_con_frases_normales(solo_reglas, texto):
    assert solo_reglas.regla_crisis(texto) is None


def test_decidir_prioriza_crisis_con_umbral_bajo():
    probs = {"crisis": 0.35, "hechos": 0.40, "fuera_de_ambito": 0.05, "normal": 0.20}
    assert decidir(probs, umbral_crisis=0.30, umbral_otros=0.5) == "crisis"


def test_decidir_duda_va_a_normal():
    probs = {"crisis": 0.05, "hechos": 0.45, "fuera_de_ambito": 0.10, "normal": 0.40}
    assert decidir(probs, umbral_crisis=0.30, umbral_otros=0.5) == "normal"


def test_plantilla_crisis_lleva_anar_en_letras():
    texto = plantilla("crisis")
    assert "ANAR" in texto and "novecientos, veinte, veinte, diez" in texto
    assert not any(c.isdigit() for c in texto)  # la voz debe leer los números bien
