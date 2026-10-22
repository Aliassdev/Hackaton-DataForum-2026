"""GET /api/session/token y /api/session/signed-url (sección 8.5). ElevenLabs simulado con httpx.MockTransport."""

import logging
from collections.abc import Callable

import httpx
import pytest

from app.api import limites, session

CLAVE = "clave-de-prueba"
AGENTE = "agente-de-prueba"


@pytest.fixture
def elevenlabs(monkeypatch: pytest.MonkeyPatch, ajustar):
    """Configura las claves de prueba y devuelve una función para decidir qué contesta ElevenLabs."""
    ajustar(session, elevenlabs_api_key=CLAVE, elevenlabs_agent_id=AGENTE)
    peticiones: list[httpx.Request] = []

    def responder_con(manejador: Callable[[httpx.Request], httpx.Response]) -> list[httpx.Request]:
        def transporte(request: httpx.Request) -> httpx.Response:
            peticiones.append(request)
            return manejador(request)

        monkeypatch.setattr(session, "_cliente", lambda: httpx.AsyncClient(transport=httpx.MockTransport(transporte)))
        return peticiones

    return responder_con


def test_token_correcto(cliente, elevenlabs, caplog):
    caplog.set_level(logging.DEBUG)
    peticiones = elevenlabs(lambda r: httpx.Response(200, json={"token": "tok-123", "conversation_id": "conv_9"}))
    resp = cliente.get("/api/session/token")
    assert resp.status_code == 200 and resp.json() == {"token": "tok-123"}

    (peticion,) = peticiones
    assert peticion.method == "GET"
    assert str(peticion.url.copy_with(query=None)) == "https://api.elevenlabs.io/v1/convai/conversation/token"
    assert dict(peticion.url.params) == {"agent_id": AGENTE}
    assert peticion.headers["xi-api-key"] == CLAVE
    # Ni la clave, ni el id del agente, ni el token en los logs
    assert CLAVE not in caplog.text and AGENTE not in caplog.text and "tok-123" not in caplog.text


def test_token_sin_configurar(cliente, ajustar):
    ajustar(session, elevenlabs_api_key="", elevenlabs_agent_id="")
    resp = cliente.get("/api/session/token")
    assert resp.status_code == 503
    assert resp.json() == {"error": {"codigo": "SIN_CONFIGURACION", "mensaje": session.MENSAJE_SIN_VOZ}}


@pytest.mark.parametrize(
    "manejador",
    [
        lambda r: httpx.Response(401, json={"detail": "invalid api key"}),
        lambda r: httpx.Response(200, json={"conversation_id": "sin token"}),
        lambda r: httpx.Response(200, text="no es json"),
    ],
    ids=["401", "sin-token", "no-json"],
)
def test_token_fallo_de_elevenlabs(cliente, elevenlabs, manejador, caplog):
    caplog.set_level(logging.DEBUG)
    elevenlabs(manejador)
    resp = cliente.get("/api/session/token")
    assert resp.status_code == 502
    assert resp.json()["error"]["codigo"] == "ELEVENLABS_NO_DISPONIBLE"
    assert AGENTE not in caplog.text and CLAVE not in caplog.text


def test_token_elevenlabs_sin_red(cliente, elevenlabs):
    def sin_red(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("sin red", request=request)

    elevenlabs(sin_red)
    resp = cliente.get("/api/session/token")
    assert resp.status_code == 502 and resp.json()["error"]["codigo"] == "ELEVENLABS_NO_DISPONIBLE"


def test_token_limite_de_peticiones(cliente, elevenlabs, ajustar):
    ajustar(limites, limite_sesion_ip=2)
    elevenlabs(lambda r: httpx.Response(200, json={"token": "tok", "conversation_id": "c"}))
    assert [cliente.get("/api/session/token").status_code for _ in range(2)] == [200, 200]
    resp = cliente.get("/api/session/token")
    assert resp.status_code == 429
    assert resp.json() == {"error": {"codigo": "DEMASIADAS_PETICIONES", "mensaje": limites.MENSAJE_LIMITE_IP}}
    assert int(resp.headers["retry-after"]) >= 1
    # La URL firmada abre la misma conversación: comparte el límite
    assert cliente.get("/api/session/signed-url").status_code == 429


def test_signed_url_se_mantiene(cliente, elevenlabs):
    peticiones = elevenlabs(lambda r: httpx.Response(200, json={"signed_url": "wss://api.elevenlabs.io/v1/convai/conversation?x=1"}))
    resp = cliente.get("/api/session/signed-url")
    assert resp.status_code == 200 and resp.json() == {"signed_url": "wss://api.elevenlabs.io/v1/convai/conversation?x=1"}
    assert peticiones[0].url.path == "/v1/convai/conversation/get-signed-url"
