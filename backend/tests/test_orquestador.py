from app.agent import orquestador, prompts
from app.agent.pii import limpiar
from app.llm.client import ErrorLLM

PERFIL = {"edad": 13, "procedimiento": "penal", "rol": "testigo", "fase": "antes", "franja": "12-13"}
MENSAJES = [
    {"role": "system", "content": "prompt genérico de ElevenLabs"},
    {"role": "assistant", "content": "Hola, soy TuTurno."},
    {"role": "user", "content": "me llamo Ana, mi móvil es 612 345 678, ¿tengo que ir a declarar?"},
]


def test_pii_limpia_dni_telefono_y_correo():
    texto = limpiar("DNI 12345678Z, tel 612 345 678, correo ana@ejemplo.com")
    assert "12345678Z" not in texto and "612 345 678" not in texto and "ana@ejemplo.com" not in texto


def test_prompt_adapta_franja_y_perfil():
    s = prompts.sistema(PERFIL, [])
    assert "12 o 13 años" in s and "testigo" in s and "antes del juicio" in s
    assert "nunca de los hechos" in s.lower()


def test_responder_no_envia_datos_personales_ni_prompt_de_elevenlabs(monkeypatch):
    enviado = {}

    def falso_stream(mensajes, modelo, **k):
        enviado["mensajes"] = mensajes
        return iter(["Sí, ", "tienes que ir."])

    monkeypatch.setattr(orquestador.client, "completar", lambda *a, **k: "obligación de comparecer del testigo")
    monkeypatch.setattr(orquestador.client, "stream", falso_stream)
    respuesta = "".join(orquestador.responder(MENSAJES, PERFIL))

    assert respuesta == "Sí, tienes que ir."
    contenido = " ".join(m["content"] for m in enviado["mensajes"])
    assert "612 345 678" not in contenido
    assert "prompt genérico de ElevenLabs" not in contenido
    assert enviado["mensajes"][0]["role"] == "system" and "FRAGMENTOS DE LA LEY" in enviado["mensajes"][0]["content"]


def test_responder_da_respuesta_segura_si_falla_el_llm(monkeypatch):
    def falla(*a, **k):
        raise ErrorLLM("429")

    monkeypatch.setattr(orquestador.client, "completar", falla)
    monkeypatch.setattr(orquestador.client, "stream", falla)
    assert "".join(orquestador.responder(MENSAJES, PERFIL)) == orquestador.RESPUESTA_SEGURA
