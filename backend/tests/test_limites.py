"""CORS, origen permitido y límite de peticiones por IP real (detrás del proxy de Hugging Face)."""

import pytest
from starlette.requests import Request

from app.api import errores, limites
from app.api.limites import Cubo, Limitador, ip_cliente

CRISIS = {"pregunta": "quiero morirme"}  # responde con plantilla: no hace falta LLM ni RAG


def _peticion(cabeceras: dict[str, str], cliente: str = "10.0.0.5") -> Request:
    return Request({
        "type": "http", "method": "GET", "path": "/", "query_string": b"", "client": (cliente, 1234),
        "headers": [(k.lower().encode(), v.encode()) for k, v in cabeceras.items()],
    })


# --- CORS y origen ---

@pytest.mark.parametrize("origen", ["https://aliassdev.github.io", "http://localhost:54321", "http://127.0.0.1:8080"])
def test_cors_origenes_permitidos(cliente, origen):
    resp = cliente.get("/api/health", headers={"Origin": origen})
    assert resp.headers.get("access-control-allow-origin") == origen


def test_cors_origen_no_permitido(cliente):
    resp = cliente.get("/api/health", headers={"Origin": "https://otra-web.example"})
    assert "access-control-allow-origin" not in resp.headers


def test_cors_preflight(cliente):
    resp = cliente.options("/api/agent/ask", headers={
        "Origin": "https://aliassdev.github.io", "Access-Control-Request-Method": "POST",
        "Access-Control-Request-Headers": "content-type",
    })
    assert resp.status_code == 200 and resp.headers["access-control-allow-origin"] == "https://aliassdev.github.io"


def test_origen_no_permitido_403_aunque_el_proxy_abra_cors(cliente, guardrail):
    resp = cliente.post("/api/agent/ask", json=CRISIS, headers={"Origin": "https://otra-web.example"})
    assert resp.status_code == 403
    assert resp.json() == {"error": {"codigo": "ORIGEN_NO_PERMITIDO", "mensaje": limites.MENSAJE_ORIGEN}}
    # Sin Origin (la APK) y con un origen permitido, pasa
    assert cliente.post("/api/agent/ask", json=CRISIS).status_code == 200
    assert cliente.post("/api/agent/ask", json=CRISIS, headers={"Origin": "https://aliassdev.github.io"}).status_code == 200


# --- IP real ---

def test_ip_real_es_la_ultima_entrada_que_anade_el_proxy(ajustar):
    ajustar(limites, proxies_de_confianza=1)
    assert ip_cliente(_peticion({"X-Forwarded-For": "198.51.100.7"})) == "198.51.100.7"
    # Lo que escribe el cliente queda delante: no cuenta
    assert ip_cliente(_peticion({"X-Forwarded-For": "203.0.113.9, 198.51.100.7"})) == "198.51.100.7"
    assert ip_cliente(_peticion({"X-Forwarded-For": "198.51.100.7", "X-Real-IP": "203.0.113.9"})) == "198.51.100.7"
    assert ip_cliente(_peticion({"X-Forwarded-For": "basura, [2001:db8::1]:443"})) == "2001:db8::1"
    # Sin cabecera (en local, sin proxy): la IP de la conexión
    assert ip_cliente(_peticion({})) == "10.0.0.5"


def test_ip_sin_proxy_ignora_la_cabecera(ajustar):
    ajustar(limites, proxies_de_confianza=0)
    assert ip_cliente(_peticion({"X-Forwarded-For": "203.0.113.9"})) == "10.0.0.5"


def test_ip_con_dos_proxies(ajustar):
    ajustar(limites, proxies_de_confianza=2)
    assert ip_cliente(_peticion({"X-Forwarded-For": "203.0.113.9, 198.51.100.7, 10.1.2.3"})) == "198.51.100.7"
    assert ip_cliente(_peticion({"X-Forwarded-For": "10.1.2.3"})) == "10.0.0.5"  # menos entradas que proxies


def test_ipv6_se_agrupa_por_64():
    limitador = Limitador()
    assert limitador.resumen("2001:db8:1:2::1") == limitador.resumen("2001:db8:1:2:ffff::5")
    assert limitador.resumen("2001:db8:1:2::1") != limitador.resumen("2001:db8:1:3::1")
    assert limitador.resumen("::ffff:198.51.100.7") == limitador.resumen("198.51.100.7")
    assert "198.51.100.7" not in limitador.resumen("198.51.100.7")  # no se guardan las IP


# --- límites ---

def test_limite_por_ip_con_cabecera_falsificada(cliente, guardrail, ajustar):
    ajustar(limites, limite_ask_ip=2, proxies_de_confianza=1)
    real = {"X-Forwarded-For": "198.51.100.7"}  # lo que añade el proxy de Hugging Face
    assert [cliente.post("/api/agent/ask", json=CRISIS, headers=real).status_code for _ in range(2)] == [200, 200]

    resp = cliente.post("/api/agent/ask", json=CRISIS, headers=real)
    assert resp.status_code == 429
    assert resp.json() == {"error": {"codigo": "DEMASIADAS_PETICIONES", "mensaje": limites.MENSAJE_LIMITE_IP}}
    assert int(resp.headers["retry-after"]) >= 1

    # Escribir otra IP en X-Forwarded-For o en X-Real-IP no sirve: el proxy añade la real al final
    for falsa in ({"X-Forwarded-For": "203.0.113.1, 198.51.100.7"}, {"X-Forwarded-For": "198.51.100.7", "X-Real-IP": "203.0.113.1"}):
        assert cliente.post("/api/agent/ask", json=CRISIS, headers=falsa).status_code == 429
    # Otra persona (otra IP real) sí puede
    assert cliente.post("/api/agent/ask", json=CRISIS, headers={"X-Forwarded-For": "203.0.113.1, 198.51.100.8"}).status_code == 200


def test_limite_429_lleva_cors_para_que_la_web_lo_lea(cliente, guardrail, ajustar):
    ajustar(limites, limite_ask_ip=1)
    origen = {"Origin": "https://aliassdev.github.io"}
    cliente.post("/api/agent/ask", json=CRISIS, headers=origen)
    resp = cliente.post("/api/agent/ask", json=CRISIS, headers=origen)
    assert resp.status_code == 429 and resp.headers["access-control-allow-origin"] == "https://aliassdev.github.io"


def test_limites_separados_por_endpoint(cliente, guardrail, ajustar):
    ajustar(limites, limite_ask_ip=1, limite_grade_ip=1)
    assert cliente.post("/api/agent/ask", json=CRISIS).status_code == 200
    assert cliente.post("/api/learn/grade", json={"concepto_id": "C-ser-oido", "texto": "quiero morirme"}).status_code == 200
    assert cliente.post("/api/agent/ask", json=CRISIS).status_code == 429


def test_tope_diario_global(cliente, guardrail, ajustar):
    ajustar(limites, limite_ask_ip=100, limite_ask_dia=3)
    for i in range(3):
        assert cliente.post("/api/agent/ask", json=CRISIS, headers={"X-Forwarded-For": f"198.51.100.{i}"}).status_code == 200
    resp = cliente.post("/api/agent/ask", json=CRISIS, headers={"X-Forwarded-For": "198.51.100.99"})
    assert resp.status_code == 429
    assert resp.json()["error"] == {"codigo": "LIMITE_DIARIO", "mensaje": limites.MENSAJE_LIMITE_DIA}
    assert 1 <= int(resp.headers["retry-after"]) <= 86400


def test_ventana_deslizante():
    limitador, cubo = Limitador(), Cubo("ask", por_ip=2, diario=0, ventana_s=60)
    limitador.comprobar(cubo, "198.51.100.7", ahora=0)
    limitador.comprobar(cubo, "198.51.100.7", ahora=30)
    with pytest.raises(errores.ErrorApi) as error:
        limitador.comprobar(cubo, "198.51.100.7", ahora=50)
    assert error.value.estado == 429 and error.value.cabeceras == {"Retry-After": "10"}
    limitador.comprobar(cubo, "198.51.100.7", ahora=60)  # la de t=0 ya ha salido de la ventana
    with pytest.raises(errores.ErrorApi):
        limitador.comprobar(cubo, "198.51.100.7", ahora=61)


def test_tope_diario_se_reinicia_a_medianoche_utc():
    limitador, cubo = Limitador(), Cubo("ask", por_ip=0, diario=1, ventana_s=60)
    medianoche = 86400 * 20000  # una medianoche UTC cualquiera
    limitador.comprobar(cubo, "198.51.100.7", reloj=medianoche - 100)
    with pytest.raises(errores.ErrorApi) as error:
        limitador.comprobar(cubo, "198.51.100.8", reloj=medianoche - 40)
    assert error.value.codigo == "LIMITE_DIARIO" and error.value.cabeceras == {"Retry-After": "40"}
    limitador.comprobar(cubo, "198.51.100.8", reloj=medianoche + 1)


def test_cero_es_sin_limite():
    limitador, cubo = Limitador(), Cubo("ask", por_ip=0, diario=0, ventana_s=60)
    for i in range(1000):
        limitador.comprobar(cubo, "198.51.100.7", ahora=i / 1000)


def test_custom_llm_sin_limite_ni_cambios(cliente, ajustar):
    ajustar(limites, limite_ask_ip=1, limite_sesion_ip=1, limite_grade_ip=1)
    respuestas = [cliente.post("/v1/chat/completions", json={"messages": [{"role": "user", "content": "quiero morirme"}]}) for _ in range(3)]
    assert all(r.status_code in (200, 401) for r in respuestas)  # 401 si hay CUSTOM_LLM_SECRET en .env
    assert all(r.status_code != 429 for r in respuestas)
