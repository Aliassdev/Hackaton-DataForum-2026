import json

from fastapi.testclient import TestClient

from app.config import settings
from app.main import app

client = TestClient(app, headers={"Authorization": f"Bearer {settings.custom_llm_secret}"})


def test_health():
    assert client.get("/api/health").json() == {"estado": "ok"}


def test_chat_completions_stream_formato_openai(monkeypatch):
    from app.agent import orquestador

    monkeypatch.setattr(orquestador.client, "completar", lambda *a, **k: "citación testigo obligación de comparecer")
    monkeypatch.setattr(orquestador.client, "stream", lambda *a, **k: iter(["Hola, soy ", "TuTurno. ", "Te explico."]))
    resp = client.post(
        "/v1/chat/completions",
        json={
            "model": "tuturno",
            "stream": True,
            "messages": [
                {"role": "system", "content": "Perfil: 14 años, testigo, penal, antes"},
                {"role": "user", "content": "¿Qué pasa si me llaman a declarar?"},
            ],
            "elevenlabs_extra_body": {"session": "x"},
        },
    )
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith("text/event-stream")

    lineas = [l.removeprefix("data: ") for l in resp.text.split("\n\n") if l.startswith("data: ")]
    assert lineas[-1] == "[DONE]"
    chunks = [json.loads(l) for l in lineas[:-1]]
    assert chunks[0]["choices"][0]["delta"] == {"role": "assistant"}
    assert chunks[-1]["choices"][0]["finish_reason"] == "stop"
    texto = "".join(c["choices"][0]["delta"].get("content", "") for c in chunks)
    assert "TuTurno" in texto


def test_crisis_responde_plantilla_sin_llm():
    resp = client.post("/v1/chat/completions", json={"messages": [{"role": "user", "content": "quiero morirme"}]})
    texto = "".join(
        json.loads(l.removeprefix("data: "))["choices"][0]["delta"].get("content", "")
        for l in resp.text.split("\n\n")
        if l.startswith("data: {")
    )
    assert "ANAR" in texto
