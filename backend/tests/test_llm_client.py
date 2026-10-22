"""Cliente LLM: parámetros según el proveedor, respaldo, plazos y streaming. Sin red: httpx.MockTransport."""

import json
import logging
import time
from collections.abc import Callable, Iterator

import httpx
import pytest

from app.llm import client

ROUTER = "https://router.huggingface.co/v1"
GROQ = "https://api.groq.com/openai/v1"
MENSAJES = [{"role": "user", "content": "¿Qué es la prueba preconstituida?"}]


class Proveedor:
    """Responde según el host y apunta cada petición (host, cuerpo y timeouts) para comprobarla después."""

    def __init__(self, respuestas: dict[str, Callable[[httpx.Request], httpx.Response]]) -> None:
        self.respuestas = respuestas
        self.peticiones: list[dict] = []

    def __call__(self, request: httpx.Request) -> httpx.Response:
        self.peticiones.append({
            "host": request.url.host, "cuerpo": json.loads(request.content), "timeout": request.extensions["timeout"],
            "auth": request.headers.get("authorization"),
        })
        return self.respuestas[request.url.host](request)

    @property
    def hosts(self) -> list[str]:
        return [p["host"] for p in self.peticiones]


def respuesta(texto: str) -> Callable[[httpx.Request], httpx.Response]:
    return lambda _: httpx.Response(200, json={"choices": [{"message": {"content": texto}}]})


def estado(codigo: int, cuerpo: str = "error") -> Callable[[httpx.Request], httpx.Response]:
    return lambda _: httpx.Response(codigo, text=cuerpo)


def falla(excepcion: type[httpx.HTTPError]) -> Callable[[httpx.Request], httpx.Response]:
    def lanzar(request: httpx.Request) -> httpx.Response:
        raise excepcion("simulado", request=request)

    return lanzar


def sse(*deltas: dict, pausa_s: float = 0.0) -> Callable[[httpx.Request], httpx.Response]:
    """Respuesta en streaming con un trozo por delta ({"content": ...} o {"reasoning": ...})."""

    def lineas() -> Iterator[bytes]:
        for delta in deltas:
            if pausa_s:
                time.sleep(pausa_s)
            yield f"data: {json.dumps({'choices': [{'index': 0, 'delta': delta}]})}\n\n".encode()
        yield b"data: [DONE]\n\n"

    return lambda _: httpx.Response(200, content=lineas(), headers={"content-type": "text/event-stream"})


class Reloj:
    """time.monotonic() de mentira solo para app/llm/client.py: devuelve las horas dadas y repite la última."""

    def __init__(self, *horas: float) -> None:
        self.horas = list(horas)

    def monotonic(self) -> float:
        return self.horas.pop(0) if len(self.horas) > 1 else self.horas[0]


@pytest.fixture(autouse=True)
def sin_averias():
    """Las averías apuntadas viven en el módulo: cada test empieza y acaba sin ninguna."""
    client.averias.limpiar()
    yield
    client.averias.limpiar()


@pytest.fixture
def proveedor(monkeypatch: pytest.MonkeyPatch, ajustar):
    """Instala un proveedor falso y deja el principal en el router de Hugging Face, sin respaldo."""
    ajustar(client, llm_base_url=ROUTER, llm_api_key="clave-hf", llm_respaldo_base_url="", llm_respaldo_api_key="", llm_respaldo_modelo="")

    def instalar(**respuestas: Callable[[httpx.Request], httpx.Response]) -> Proveedor:
        falso = Proveedor({host.replace("_", "."): r for host, r in respuestas.items()})
        monkeypatch.setattr(client, "_http", lambda: httpx.Client(transport=httpx.MockTransport(falso)))
        return falso

    return instalar


# --- parámetros según el proveedor ---

def test_router_gpt_oss_sin_include_reasoning():
    """El router de Hugging Face (Cerebras) rechaza include_reasoning con un 400: solo reasoning_effort."""
    cuerpo = client.cuerpo_peticion(MENSAJES, client.Destino("principal", ROUTER, "k", "openai/gpt-oss-120b"), 600, 0.3)
    assert cuerpo["reasoning_effort"] == "low" and "include_reasoning" not in cuerpo


def test_groq_gpt_oss_con_include_reasoning():
    cuerpo = client.cuerpo_peticion(MENSAJES, client.Destino("respaldo", GROQ, "k", "openai/gpt-oss-120b"), 600, 0.3)
    assert cuerpo["reasoning_effort"] == "low" and cuerpo["include_reasoning"] is False


def test_modelo_sin_razonamiento_sin_parametros_de_razonamiento():
    cuerpo = client.cuerpo_peticion(MENSAJES, client.Destino("principal", GROQ, "k", "llama-3.3-70b-versatile"), 250, 0.0)
    assert "reasoning_effort" not in cuerpo and "include_reasoning" not in cuerpo


def test_es_groq_solo_por_el_host():
    assert client.es_groq(GROQ) and not client.es_groq(ROUTER) and not client.es_groq("https://groq.com.ejemplo.net/v1")


def test_no_se_anade_reasoning_low_al_mensaje_de_sistema():
    cuerpo = client.cuerpo_peticion([{"role": "system", "content": "Eres TuTurno."}], client.Destino("p", ROUTER, "k", "openai/gpt-oss-120b"), 9, 0)
    assert cuerpo["messages"] == [{"role": "system", "content": "Eres TuTurno."}]


# --- respaldo: configuración ---

def test_respaldo_sin_configurar_repite_el_principal(ajustar):
    ajustar(client, llm_base_url=ROUTER, llm_api_key="k", llm_respaldo_base_url="", llm_respaldo_modelo="")
    assert [d.nombre for d in client.destinos("m")] == ["principal", "principal"]


def test_respaldo_con_su_clave(ajustar):
    ajustar(client, llm_base_url=ROUTER, llm_api_key="k", llm_respaldo_base_url=GROQ, llm_respaldo_api_key="kg", llm_respaldo_modelo="openai/gpt-oss-120b")
    principal, respaldo = client.destinos("openai/gpt-oss-20b")
    assert (principal.base_url, principal.modelo) == (ROUTER, "openai/gpt-oss-20b")
    assert (respaldo.base_url, respaldo.api_key, respaldo.modelo) == (GROQ, "kg", "openai/gpt-oss-120b")


def test_respaldo_en_el_mismo_router_reutiliza_la_clave(ajustar):
    ajustar(client, llm_base_url=ROUTER, llm_api_key="k", llm_respaldo_base_url=ROUTER, llm_respaldo_api_key="", llm_respaldo_modelo="openai/gpt-oss-120b:groq")
    assert client.respaldo() == client.Destino("respaldo", ROUTER, "k", "openai/gpt-oss-120b:groq")


def test_la_clave_del_principal_nunca_va_a_otro_servidor(ajustar):
    ajustar(client, llm_base_url=ROUTER, llm_api_key="k", llm_respaldo_base_url=GROQ, llm_respaldo_api_key="", llm_respaldo_modelo="openai/gpt-oss-120b")
    assert client.respaldo() is None


def test_sin_ninguna_clave_error_claro(ajustar):
    ajustar(client, llm_api_key="", llm_respaldo_base_url="", llm_respaldo_modelo="")
    with pytest.raises(client.ErrorLLM, match="LLM sin clave"):
        client.completar(MENSAJES, modelo="m")


# --- completar (sin streaming) ---

def test_completar_usa_una_conexion_persistente():
    assert client._http() is client._http()  # el mismo cliente (y su pool) para todas las llamadas


def test_completar_responde(proveedor):
    falso = proveedor(router_huggingface_co=respuesta("  consulta jurídica  "))
    assert client.completar(MENSAJES, modelo="openai/gpt-oss-20b") == "consulta jurídica"
    assert falso.peticiones[0]["auth"] == "Bearer clave-hf"


@pytest.mark.parametrize("fallo", [estado(429), estado(503), falla(httpx.ReadTimeout), falla(httpx.ConnectError), estado(400)])
def test_completar_pasa_al_respaldo(proveedor, ajustar, fallo):
    ajustar(client, llm_respaldo_base_url=GROQ, llm_respaldo_api_key="kg", llm_respaldo_modelo="openai/gpt-oss-120b")
    falso = proveedor(router_huggingface_co=fallo, api_groq_com=respuesta("desde Groq"))
    assert client.completar(MENSAJES, modelo="openai/gpt-oss-20b") == "desde Groq"
    assert falso.hosts == ["router.huggingface.co", "api.groq.com"]
    assert falso.peticiones[1]["auth"] == "Bearer kg" and falso.peticiones[1]["cuerpo"]["include_reasoning"] is False


@pytest.mark.parametrize("fallo", [estado(429), estado(502), falla(httpx.ConnectError), falla(httpx.RemoteProtocolError)])
def test_completar_sin_respaldo_reintenta_una_vez_lo_pasajero(proveedor, fallo):
    respuestas = iter([fallo, respuesta("a la segunda")])
    falso = proveedor(router_huggingface_co=lambda r: next(respuestas)(r))
    assert client.completar(MENSAJES, modelo="m") == "a la segunda"
    assert len(falso.peticiones) == 2


def test_completar_sin_respaldo_no_repite_un_400(proveedor):
    falso = proveedor(router_huggingface_co=estado(400, '{"error": "include_reasoning: unsupported"}'))
    with pytest.raises(client.ErrorLLM, match="^LLM 400"):
        client.completar(MENSAJES, modelo="m")
    assert len(falso.peticiones) == 1


def test_completar_respuesta_vacia_cuenta_como_fallo(proveedor):
    respuestas = iter([respuesta(""), respuesta("ahora sí")])
    proveedor(router_huggingface_co=lambda r: next(respuestas)(r))
    assert client.completar(MENSAJES, modelo="m") == "ahora sí"


def test_completar_reparte_el_plazo_entre_los_dos_intentos(proveedor, monkeypatch):
    monkeypatch.setattr(client, "time", Reloj(0.0, 0.0, 6.0))  # el primer intento agota sus 6 s
    falso = proveedor(router_huggingface_co=falla(httpx.ReadTimeout))
    with pytest.raises(client.ErrorLLM, match="ReadTimeout"):
        client.completar(MENSAJES, modelo="m", plazo_s=10.0)
    primero, segundo = (p["timeout"] for p in falso.peticiones)
    assert primero["read"] == pytest.approx(6.0) and primero["connect"] == client.CONEXION_S
    assert segundo["read"] == pytest.approx(4.0)  # lo que queda del plazo


def test_si_el_principal_falla_rapido_el_respaldo_tiene_casi_todo_el_plazo(proveedor, ajustar):
    ajustar(client, llm_respaldo_base_url=GROQ, llm_respaldo_api_key="kg", llm_respaldo_modelo="openai/gpt-oss-120b")
    falso = proveedor(router_huggingface_co=estado(429), api_groq_com=respuesta("ok"))
    client.completar(MENSAJES, modelo="m", plazo_s=10.0)
    assert falso.peticiones[1]["timeout"]["read"] == pytest.approx(10.0, abs=0.2)


def test_completar_sin_tiempo_no_empieza_otro_intento(proveedor, monkeypatch):
    monkeypatch.setattr(client, "time", Reloj(0.0, 0.0, 9.8))  # el primer intento se come casi todo el plazo
    falso = proveedor(router_huggingface_co=falla(httpx.ReadTimeout))
    with pytest.raises(client.ErrorLLM):
        client.completar(MENSAJES, modelo="m", plazo_s=10.0)
    assert len(falso.peticiones) == 1


def test_completar_plazo_por_defecto_del_modo_texto(proveedor, ajustar):
    ajustar(client, llm_plazo_texto_s=5.0)
    falso = proveedor(router_huggingface_co=respuesta("ok"))
    client.completar(MENSAJES, modelo="m")
    assert falso.peticiones[0]["timeout"]["read"] == pytest.approx(3.0, abs=0.1)  # 60 % de 5 s (hay segundo intento)


def test_los_fallos_no_escriben_el_cuerpo_del_proveedor_en_el_log(proveedor, caplog):
    caplog.set_level(logging.INFO)
    proveedor(router_huggingface_co=estado(500, "lo que contó el menor"))
    with pytest.raises(client.ErrorLLM):
        client.completar(MENSAJES, modelo="m")
    assert "LLM principal (router.huggingface.co) ha fallado: LLM 500" in caplog.text
    assert "lo que contó el menor" not in caplog.text


# --- stream ---

def test_stream_devuelve_solo_el_texto(proveedor):
    proveedor(router_huggingface_co=sse({"role": "assistant"}, {"reasoning": "pienso..."}, {"content": "Hola, "}, {"content": "soy TuTurno."}))
    assert "".join(client.stream(MENSAJES, modelo="openai/gpt-oss-120b")) == "Hola, soy TuTurno."


def test_stream_pide_streaming_sin_include_reasoning_en_el_router(proveedor):
    falso = proveedor(router_huggingface_co=sse({"content": "ok"}))
    list(client.stream(MENSAJES, modelo="openai/gpt-oss-120b"))
    cuerpo = falso.peticiones[0]["cuerpo"]
    assert cuerpo["stream"] is True and cuerpo["reasoning_effort"] == "low" and "include_reasoning" not in cuerpo


def test_stream_ignora_lineas_raras(proveedor):
    def raro(_: httpx.Request) -> httpx.Response:
        cuerpo = b': keep-alive\n\ndata: {"choices": []}\n\ndata: no-json\n\ndata:{"choices":[{"delta":{"content":"vale"}}]}\n\ndata: [DONE]\n\n'
        return httpx.Response(200, content=cuerpo)

    proveedor(router_huggingface_co=raro)
    assert "".join(client.stream(MENSAJES, modelo="m")) == "vale"


@pytest.mark.parametrize("fallo", [estado(429), estado(500), falla(httpx.ConnectTimeout), falla(httpx.ReadTimeout), sse({"reasoning": "solo pienso"})])
def test_stream_pasa_al_respaldo_antes_del_primer_texto(proveedor, ajustar, fallo):
    ajustar(client, llm_respaldo_base_url=GROQ, llm_respaldo_api_key="kg", llm_respaldo_modelo="openai/gpt-oss-120b")
    falso = proveedor(router_huggingface_co=fallo, api_groq_com=sse({"content": "Desde Groq."}))
    assert "".join(client.stream(MENSAJES, modelo="openai/gpt-oss-120b")) == "Desde Groq."
    assert falso.hosts == ["router.huggingface.co", "api.groq.com"]


def test_stream_sin_texto_a_tiempo_pasa_al_siguiente(proveedor, monkeypatch):
    """Un proveedor que solo manda razonamiento (o nada útil) no puede dejar callado al agente más que su parte del plazo."""
    monkeypatch.setattr(client, "MIN_INTENTO_S", 0.05)
    lento = sse(*[{"reasoning": "pienso"}] * 6, {"content": "tarde"}, pausa_s=0.1)
    respuestas = iter([lento, sse({"content": "a tiempo"})])
    proveedor(router_huggingface_co=lambda r: next(respuestas)(r))
    inicio = time.monotonic()
    assert "".join(client.stream(MENSAJES, modelo="m", plazo_s=0.5)) == "a tiempo"
    assert time.monotonic() - inicio < 0.6  # el primer intento tenía 0,3 s (60 % de 0,5)


def test_stream_cortado_a_medias_no_repite_con_otro_proveedor(proveedor, ajustar):
    ajustar(client, llm_respaldo_base_url=GROQ, llm_respaldo_api_key="kg", llm_respaldo_modelo="openai/gpt-oss-120b")

    def cortado(_: httpx.Request) -> httpx.Response:
        def lineas() -> Iterator[bytes]:
            yield b'data: {"choices":[{"delta":{"content":"Primera frase. "}}]}\n\n'
            raise httpx.ReadError("conexión cortada")

        return httpx.Response(200, content=lineas())

    falso = proveedor(router_huggingface_co=cortado, api_groq_com=sse({"content": "no debería salir"}))
    recibido: list[str] = []
    with pytest.raises(client.ErrorLLM, match="cortado a medias"):
        recibido.extend(client.stream(MENSAJES, modelo="m"))  # extend conserva lo recibido antes del corte
    assert recibido == ["Primera frase. "] and falso.hosts == ["router.huggingface.co"]


def test_stream_plazo_por_defecto_de_la_voz(proveedor, ajustar):
    ajustar(client, llm_plazo_voz_s=5.0)
    falso = proveedor(router_huggingface_co=sse({"content": "ok"}))
    list(client.stream(MENSAJES, modelo="m"))
    timeout = falso.peticiones[0]["timeout"]
    assert timeout["read"] == pytest.approx(3.0, abs=0.1) and timeout["connect"] == client.CONEXION_S


def test_stream_todo_falla_error_llm(proveedor):
    proveedor(router_huggingface_co=estado(503))
    with pytest.raises(client.ErrorLLM, match="^LLM 503"):
        list(client.stream(MENSAJES, modelo="m"))


# --- averías: tras un fallo del proveedor, el respaldo va primero un rato ---

@pytest.fixture
def con_respaldo(ajustar):
    ajustar(client, llm_respaldo_base_url=GROQ, llm_respaldo_api_key="kg", llm_respaldo_modelo="openai/gpt-oss-120b")


@pytest.mark.parametrize("fallo", [falla(httpx.ConnectTimeout), estado(429), estado(503)])
def test_tras_una_caida_el_respaldo_va_primero(proveedor, con_respaldo, fallo):
    falso = proveedor(router_huggingface_co=fallo, api_groq_com=respuesta("desde Groq"))
    client.completar(MENSAJES, modelo="m")
    client.completar(MENSAJES, modelo="m")
    assert falso.hosts == ["router.huggingface.co", "api.groq.com", "api.groq.com"]  # la segunda vez, sin esperar al caído


def test_la_averia_vale_tambien_para_la_voz(proveedor, con_respaldo):
    falso = proveedor(router_huggingface_co=falla(httpx.ConnectError), api_groq_com=sse({"content": "Hola."}))
    list(client.stream(MENSAJES, modelo="m"))
    list(client.stream(MENSAJES, modelo="m"))
    assert falso.hosts == ["router.huggingface.co", "api.groq.com", "api.groq.com"]


def test_pasado_el_enfriamiento_vuelve_el_principal(proveedor, con_respaldo, monkeypatch):
    monkeypatch.setattr(client, "ENFRIAMIENTO_S", -1.0)  # la avería caduca al instante
    respuestas = iter([estado(503), respuesta("vuelve el principal")])
    falso = proveedor(router_huggingface_co=lambda r: next(respuestas)(r), api_groq_com=respuesta("desde Groq"))
    client.completar(MENSAJES, modelo="m")
    assert client.completar(MENSAJES, modelo="m") == "vuelve el principal"
    assert falso.hosts == ["router.huggingface.co", "api.groq.com", "router.huggingface.co"]


def test_si_el_principal_responde_deja_de_estar_averiado(proveedor, con_respaldo):
    principal = client.destinos("m")[0]
    client.averias.marcar(principal)
    assert client.destinos("m")[0].nombre == "respaldo"
    proveedor(router_huggingface_co=respuesta("ok"), api_groq_com=estado(503))
    client.completar(MENSAJES, modelo="m")  # el respaldo falla, el principal responde
    assert client.destinos("m")[0].nombre == "principal"


def test_un_error_de_la_peticion_no_es_una_averia(proveedor, con_respaldo):
    """Un 400 o una respuesta vacía no dicen que el proveedor esté caído: el principal sigue primero."""
    falso = proveedor(router_huggingface_co=estado(400), api_groq_com=respuesta("desde Groq"))
    client.completar(MENSAJES, modelo="m")
    assert client.destinos("m")[0].nombre == "principal" and falso.hosts == ["router.huggingface.co", "api.groq.com"]


def test_sin_respaldo_una_averia_no_cambia_nada(proveedor):
    client.averias.marcar(client.destinos("m")[0])
    assert [d.nombre for d in client.destinos("m")] == ["principal", "principal"]
