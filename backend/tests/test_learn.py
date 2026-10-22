"""POST /api/learn/grade (sección 8.2): el LLM como juez, con el guardrail delante. Sin red."""

import json
import logging
from pathlib import Path

import pytest

from app.agent import evaluador
from app.agent.safety import _plantillas, para_pantalla

IDEAS = [
    "Tienes derecho a que te escuchen en lo que te afecta",
    "Tu opinión se tiene en cuenta según tu edad y madurez",
    "A partir de los 12 años se da por hecho que tienes madurez",
]
CLAVES_RESPUESTA = {"puntuacion", "cubiertas", "faltan", "feedback", "tipo"}


def _corregir(cliente, texto: str = "Que el juez tiene que escucharte si tienes 12 años", concepto: str = "C-ser-oido"):
    return cliente.post("/api/learn/grade", json={"concepto_id": concepto, "texto": texto})


def test_grade_formato_de_la_app(cliente, guardrail, llm):
    llm.respuestas = ['{"cubiertas": [1, 3]}']
    resp = _corregir(cliente)
    assert resp.status_code == 200
    datos = resp.json()
    assert set(datos) == CLAVES_RESPUESTA
    assert datos == {
        "puntuacion": 0.67,
        "cubiertas": [IDEAS[0], IDEAS[2]],
        "faltan": [IDEAS[1]],
        "feedback": "¡Muy bien! Te falta una idea: tu opinión se tiene en cuenta según tu edad y madurez.",
        "tipo": "normal",
    }
    (llamada,) = llm.llamadas
    assert llamada["json_obj"] is True
    assert all(idea in llamada["mensajes"][0]["content"] for idea in IDEAS)


@pytest.mark.parametrize(
    ("juicio", "puntuacion", "feedback"),
    [
        ('{"cubiertas": [1, 2, 3]}', 1.0, "¡Genial! Has explicado todas las ideas clave."),
        ('{"cubiertas": []}', 0.0, "Todavía no aparecen las ideas clave. Una pista: tienes derecho a que te escuchen en lo que te afecta."),
        ('{"cubiertas": [2]}', 0.33, "¡Vas bien! Te faltan 2 ideas. Por ejemplo: tienes derecho a que te escuchen en lo que te afecta."),
        ('{"cubiertas": [0, 2, 7, "3"]}', 0.67, "¡Muy bien! Te falta una idea: tienes derecho a que te escuchen en lo que te afecta."),
    ],
)
def test_grade_puntuacion_y_feedback(cliente, guardrail, llm, juicio, puntuacion, feedback):
    llm.respuestas = [juicio]
    datos = _corregir(cliente).json()
    assert datos["puntuacion"] == puntuacion and datos["feedback"] == feedback


def test_grade_no_envia_datos_personales_al_juez(cliente, guardrail, llm):
    llm.respuestas = ['{"cubiertas": [1]}']
    _corregir(cliente, "Que te escuchen. Mi correo es ana@ejemplo.com")
    assert "ana@ejemplo.com" not in json.dumps(llm.llamadas, ensure_ascii=False)


def test_grade_crisis_antes_que_nada(cliente, guardrail, llm):
    llm.respuestas = [AssertionError("en crisis no se llama al LLM")]
    for concepto in ("C-ser-oido", "C-que-no-existe"):
        resp = _corregir(cliente, "no quiero seguir viviendo", concepto)
        assert resp.status_code == 200
        datos = resp.json()
        assert datos["tipo"] == "crisis" and datos["cubiertas"] == [] and datos["faltan"] == [] and datos["puntuacion"] == 0.0
        assert datos["feedback"] in [para_pantalla(t) for t in _plantillas()["crisis"]]
        assert "900 20 20 10" in datos["feedback"]
    assert llm.llamadas == []


def test_grade_concepto_desconocido(cliente, guardrail, llm):
    resp = _corregir(cliente, concepto="C-que-no-existe")
    assert resp.status_code == 404 and resp.json()["error"]["codigo"] == "CONCEPTO_DESCONOCIDO"


def test_grade_reintenta_si_el_json_no_vale(cliente, guardrail, llm):
    llm.respuestas = ["las ideas 1 y 3", '{"cubiertas": [1]}']
    assert _corregir(cliente).json()["puntuacion"] == 0.33
    llm.respuestas = ["no es json", '{"otra_cosa": 1}']
    resp = _corregir(cliente)
    assert resp.status_code == 503 and resp.json()["error"]["codigo"] == "LLM_NO_DISPONIBLE"


def test_grade_no_escribe_el_texto_en_el_log(cliente, guardrail, llm, caplog):
    caplog.set_level(logging.INFO)
    llm.respuestas = ['{"cubiertas": [1]}']
    _corregir(cliente, "texto privadísimo del alumno")
    assert "privadísimo" not in caplog.text and "Grade: C-ser-oido" in caplog.text


def test_conceptos_del_contenido_validado():
    todos = evaluador.conceptos()
    assert {"C-ser-oido", "C-fiscalia", "C-comunicar-violencia", "C-que-pedir", "C-sala-gesell", "C-sin-contacto"} <= set(todos)
    assert list(todos["C-ser-oido"].proposiciones) == IDEAS


def test_conceptos_de_content_ejercicios_van_primero(tmp_path: Path, ajustar):
    (tmp_path / "ejercicios").mkdir()
    ejercicios = [
        {"id": "E-1", "tipo": "dilo", "concepto": "C-ser-oido", "pregunta": "¿?", "proposiciones": ["Idea nueva"], "fuente": "LO 1/1996, art. 9", "validado": True},
        {"id": "E-2", "tipo": "dilo", "concepto": "C-borrador", "pregunta": "¿?", "proposiciones": ["Sin validar"], "fuente": "x", "validado": False},
        {"id": "E-3", "tipo": "vf", "concepto": "C-vf", "afirmacion": "x", "correcta": True, "fuente": "x", "validado": True},
    ]
    (tmp_path / "ejercicios" / "unidad-1.json").write_text(json.dumps(ejercicios), encoding="utf-8")
    (tmp_path / "evaluador.json").write_text(json.dumps({"conceptos": [
        {"concepto": "C-ser-oido", "proposiciones": ["Idea vieja"], "fuente": "x", "validado": True},
        {"concepto": "C-fiscalia", "proposiciones": ["Dirige la investigación"], "fuente": "x", "validado": True},
    ]}), encoding="utf-8")
    ajustar(evaluador, content_dir=tmp_path)
    evaluador.conceptos.cache_clear()
    try:
        todos = evaluador.conceptos()
        assert set(todos) == {"C-ser-oido", "C-fiscalia"}
        assert todos["C-ser-oido"].proposiciones == ("Idea nueva",)
    finally:
        evaluador.conceptos.cache_clear()
