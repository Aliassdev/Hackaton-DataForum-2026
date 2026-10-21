import pytest

from app.agent.perfil import extraer_perfil, franja
from app.rag.retrieve import get_recuperador


def test_extraer_perfil_de_prompt_elevenlabs():
    system = "Agent character description: Eres TuTurno...\nPerfil: edad=13; procedimiento=penal; rol=testigo; fase=antes.\nThe documentation..."
    assert extraer_perfil(system) == {"edad": 13, "procedimiento": "penal", "rol": "testigo", "fase": "antes", "franja": "12-13"}


def test_perfil_ignora_variables_sin_sustituir():
    assert extraer_perfil("Perfil: edad={{edad}}; rol=victima.") == {"rol": "victima"}


def test_franjas():
    assert [franja(e) for e in (12, 13, 14, 15, 16, 17)] == ["12-13", "12-13", "14-15", "14-15", "16-17", "16-17"]


@pytest.mark.skipif(get_recuperador() is None, reason="sin índice RAG construido")
def test_rag_encuentra_prueba_preconstituida():
    citas = [f.articulo_id for f in get_recuperador().buscar("qué es la prueba preconstituida", {"procedimiento": "penal", "rol": "testigo"})]
    assert "LECRIM-449bis" in citas or "LECRIM-449ter" in citas


@pytest.mark.skipif(get_recuperador() is None, reason="sin índice RAG construido")
def test_rag_devuelve_articulos_distintos():
    frags = get_recuperador().buscar("tengo derecho a un abogado", k=5)
    assert len({f.articulo_id for f in frags}) == len(frags) == 5
