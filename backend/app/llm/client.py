"""Cliente LLM para cualquier API compatible con OpenAI Chat Completions (router de Hugging Face, Groq, vLLM...).

El proveedor se elige en .env (LLM_BASE_URL, LLM_API_KEY, LLM_MODELO...): cambiarlo es cambiar la URL, sin tocar código.
- Parámetros según el proveedor: reasoning_effort="low" en los gpt-oss (lo aceptan todos) e include_reasoning=false
  solo en Groq. El router de Hugging Face lo rechaza con un 400 cuando el modelo lo sirve Cerebras (el 120b); sin él,
  el razonamiento llega en un campo aparte y nunca en "content". «Reasoning: low» en el mensaje de sistema no aporta
  nada medible además de reasoning_effort (probado con Cerebras y con Groq), así que no se añade.
- Una sola conexión persistente (keep-alive) para todo el proceso: cada llamada se ahorra abrir TCP y TLS (unos 0,1 s
  contra el router, y hay dos llamadas por pregunta).
- Plazos cortos y respaldo: si un intento falla (429, 5xx, timeout, fallo de conexión o respuesta sin texto), se
  prueba el respaldo (LLM_RESPALDO_*) o, si no lo hay, se repite una vez, siempre dentro del plazo total de la llamada.
  Un error que no se arregla repitiendo (400, 401...) también pasa al respaldo, que es otro proveedor u otro modelo.
- Si el principal acaba de fallar por culpa del proveedor (conexión, timeout, 429 o 5xx), durante ENFRIAMIENTO_S el
  respaldo va primero: una caída no cuesta el timeout de conexión en cada llamada (hay dos por pregunta).
"""

import json
import logging
import threading
import time
from collections.abc import Iterator
from dataclasses import dataclass
from functools import lru_cache
from urllib.parse import urlsplit

import httpx

from app.config import settings

log = logging.getLogger("tuturno.llm.client")

CONEXION_S = 2.0  # abrir la conexión (TCP y TLS): contra el router tarda ~0,1 s
LECTURA_STREAM_S = 5.0  # máximo sin recibir nada en mitad de un streaming
POOL_S = 1.0  # esperar una conexión libre del pool
MIN_INTENTO_S = 0.5  # con menos tiempo que esto no se empieza otro intento
PARTE_PRIMER_INTENTO = 0.6  # si hay segundo intento, el primero no puede gastar todo el plazo
ENFRIAMIENTO_S = 30.0  # tras un fallo del proveedor, el respaldo va primero durante este tiempo


class ErrorLLM(Exception):
    """El mensaje empieza por «LLM <estado o motivo>»: es lo único que va al log (resumen_error, app/api/errores.py).
    reintentable: otro intento puede salir bien. caida: el fallo es del proveedor (conexión, timeout, 429 o 5xx)."""

    def __init__(self, mensaje: str, reintentable: bool = False, caida: bool = False) -> None:
        super().__init__(mensaje)
        self.reintentable = reintentable
        self.caida = caida


@dataclass(frozen=True)
class Destino:
    nombre: str  # «principal» o «respaldo», para el log
    base_url: str
    api_key: str
    modelo: str


def es_groq(base_url: str) -> bool:
    host = urlsplit(base_url).hostname or ""
    return host == "groq.com" or host.endswith(".groq.com")


def es_gpt_oss(modelo: str) -> bool:
    return "gpt-oss" in modelo.lower()


def respaldo() -> Destino | None:
    """El respaldo de LLM_RESPALDO_*, o None si no está configurado. Sin clave propia solo vale la del principal si la
    URL es la misma (el router de Hugging Face con otro proveedor): la clave nunca se manda a otro servidor."""
    if not (settings.llm_respaldo_base_url and settings.llm_respaldo_modelo):
        return None
    misma_url = settings.llm_respaldo_base_url == settings.llm_base_url
    clave = settings.llm_respaldo_api_key or (settings.llm_api_key if misma_url else "")
    return Destino("respaldo", settings.llm_respaldo_base_url, clave, settings.llm_respaldo_modelo) if clave else None


class Averias:
    """Destinos que acaban de fallar por culpa del proveedor, hasta cuándo (reloj monotónico). Compartido entre hilos."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._hasta: dict[tuple[str, str], float] = {}

    def marcar(self, destino: Destino) -> None:
        with self._lock:
            self._hasta[(destino.base_url, destino.modelo)] = time.monotonic() + ENFRIAMIENTO_S

    def reparado(self, destino: Destino) -> None:
        with self._lock:
            self._hasta.pop((destino.base_url, destino.modelo), None)

    def averiado(self, destino: Destino) -> bool:
        with self._lock:
            return self._hasta.get((destino.base_url, destino.modelo), 0.0) > time.monotonic()

    def limpiar(self) -> None:
        with self._lock:
            self._hasta.clear()


averias = Averias()


def destinos(modelo: str) -> list[Destino]:
    """Los intentos de una llamada, en orden: el principal y después el respaldo o, si no hay, otra vez el principal.
    Si el principal está averiado (ha fallado hace menos de ENFRIAMIENTO_S) y el respaldo no, el respaldo va primero."""
    principal = Destino("principal", settings.llm_base_url, settings.llm_api_key, modelo)
    otro = respaldo()
    if otro is None:
        lista = [principal, principal]
    elif averias.averiado(principal) and not averias.averiado(otro):
        lista = [otro, principal]
    else:
        lista = [principal, otro]
    return [d for d in lista if d.api_key]


def cuerpo_peticion(mensajes: list[dict], destino: Destino, max_tokens: int, temperatura: float) -> dict:
    cuerpo = {"model": destino.modelo, "messages": mensajes, "max_tokens": max_tokens, "temperature": temperatura}
    if es_gpt_oss(destino.modelo):
        cuerpo["reasoning_effort"] = "low"  # razonamiento mínimo para que la voz no espere (max_tokens lo incluye)
        if es_groq(destino.base_url):
            cuerpo["include_reasoning"] = False  # Groq: que no lo devuelva. Otros proveedores rechazan el parámetro
    return cuerpo


class Plan:
    """Los intentos de una llamada dentro de su plazo. Se recorre con for; quien llama apunta cada fallo con fallo()."""

    def __init__(self, modelo: str, plazo_s: float) -> None:
        self.lista = destinos(modelo)
        if not self.lista:
            raise ErrorLLM("LLM sin clave: falta LLM_API_KEY (o GROQ_API_KEY) en .env")
        self.fin = time.monotonic() + plazo_s
        self.error: ErrorLLM | None = None

    def __iter__(self) -> Iterator[tuple[Destino, float]]:
        """(destino, segundos que tiene ese intento)."""
        for n, destino in enumerate(self.lista):
            quedan = self.fin - time.monotonic()
            if n > 0:
                repetir_inutil = destino == self.lista[n - 1] and self.error is not None and not self.error.reintentable
                if quedan < MIN_INTENTO_S or repetir_inutil:
                    return
                log.info("LLM: segundo intento con el %s", destino.nombre)
            yield destino, quedan * PARTE_PRIMER_INTENTO if n == 0 and len(self.lista) > 1 else quedan

    def fallo(self, destino: Destino, error: ErrorLLM) -> None:
        self.error = error
        if error.caida:
            averias.marcar(destino)
        # Solo «LLM 429» o el motivo: el cuerpo de la respuesta del proveedor puede repetir lo que generó el modelo
        log.warning("LLM %s (%s) ha fallado: %s", destino.nombre, urlsplit(destino.base_url).hostname, str(error).split(":")[0][:80])

    def exito(self, destino: Destino) -> None:
        averias.reparado(destino)

    def rendirse(self) -> ErrorLLM:
        return self.error or ErrorLLM("LLM sin respuesta: se ha agotado el plazo")


@lru_cache(maxsize=1)
def _http() -> httpx.Client:
    """Cliente compartido por todos los hilos (httpx.Client es seguro entre hilos), con conexiones persistentes.
    Sin tope de conexiones: ya lo ponen los hilos (HILOS_MAX), y esperar un hueco en el pool no es culpa del proveedor."""
    return httpx.Client(limits=httpx.Limits(max_connections=None, max_keepalive_connections=32, keepalive_expiry=60.0))


def _timeout(segundos: float, lectura: float) -> httpx.Timeout:
    corto = min(CONEXION_S, segundos)
    return httpx.Timeout(connect=corto, read=lectura, write=corto, pool=min(POOL_S, segundos))


def _cabeceras(destino: Destino) -> dict[str, str]:
    return {"Authorization": f"Bearer {destino.api_key}"}


def _error_estado(r: httpx.Response) -> ErrorLLM:
    pasajero = r.status_code == 429 or r.status_code >= 500
    return ErrorLLM(f"LLM {r.status_code}: {r.text[:200]}", reintentable=pasajero, caida=pasajero)


def _error_red(e: httpx.HTTPError) -> ErrorLLM:
    return ErrorLLM(f"LLM sin respuesta ({type(e).__name__})", reintentable=True, caida=True)


def completar(
    mensajes: list[dict], modelo: str, max_tokens: int = 250, temperatura: float = 0.0, json_obj: bool = False,
    plazo_s: float | None = None,
) -> str:
    """Respuesta entera, sin streaming. Lanza ErrorLLM si ningún intento responde dentro del plazo
    (por defecto, LLM_PLAZO_TEXTO_S)."""
    plan = Plan(modelo, settings.llm_plazo_texto_s if plazo_s is None else plazo_s)
    for destino, segundos in plan:
        cuerpo = cuerpo_peticion(mensajes, destino, max_tokens, temperatura)
        if json_obj:
            cuerpo["response_format"] = {"type": "json_object"}
        try:
            # Sin streaming el proveedor no manda nada hasta terminar: la lectura es el tiempo de toda la respuesta
            r = _http().post(f"{destino.base_url}/chat/completions", json=cuerpo, headers=_cabeceras(destino), timeout=_timeout(segundos, segundos))
            if r.status_code >= 400:
                raise _error_estado(r)
            texto = (r.json()["choices"][0]["message"]["content"] or "").strip()
            if not texto:  # p. ej., el razonamiento se ha comido todos los tokens
                raise ErrorLLM("LLM vacío: respuesta sin texto", reintentable=True)
            plan.exito(destino)
            return texto
        except ErrorLLM as e:
            plan.fallo(destino, e)
        except httpx.HTTPError as e:
            plan.fallo(destino, _error_red(e))
        except (ValueError, KeyError, IndexError, TypeError):
            plan.fallo(destino, ErrorLLM("LLM respuesta ilegible", reintentable=True))
    raise plan.rendirse()


def _stream_destino(mensajes: list[dict], destino: Destino, segundos: float, max_tokens: int, temperatura: float) -> Iterator[str]:
    """Un intento en streaming. Si en `segundos` no ha llegado texto (por ejemplo, porque solo llega razonamiento o
    nada), lanza ErrorLLM reintentable. Las líneas que no traen texto (razonamiento, uso de tokens) se ignoran."""
    inicio = time.monotonic()
    cuerpo = cuerpo_peticion(mensajes, destino, max_tokens, temperatura) | {"stream": True}
    timeout = _timeout(segundos, min(LECTURA_STREAM_S, segundos))
    with _http().stream("POST", f"{destino.base_url}/chat/completions", json=cuerpo, headers=_cabeceras(destino), timeout=timeout) as r:
        if r.status_code >= 400:
            r.read()
            raise _error_estado(r)
        hubo_texto = False
        for linea in r.iter_lines():
            if not hubo_texto and time.monotonic() - inicio > segundos:
                raise ErrorLLM("LLM lento: sin texto dentro del plazo", reintentable=True, caida=True)
            if not linea.startswith("data:"):
                continue
            dato = linea[5:].strip()
            if dato == "[DONE]":
                break
            try:
                texto = (json.loads(dato)["choices"][0].get("delta") or {}).get("content")
            except (ValueError, KeyError, IndexError, TypeError, AttributeError):
                continue
            if texto:
                hubo_texto = True
                yield texto
        if not hubo_texto:
            raise ErrorLLM("LLM vacío: respuesta sin texto", reintentable=True)


def stream(mensajes: list[dict], modelo: str, max_tokens: int = 600, temperatura: float = 0.3, plazo_s: float | None = None) -> Iterator[str]:
    """Devuelve el texto según llega. Si un intento falla antes del primer texto, se pasa al siguiente (plazo por
    defecto: LLM_PLAZO_VOZ_S, hasta el primer texto). Lanza ErrorLLM si nadie responde a tiempo, y también si la
    respuesta se corta a medias: lo que ya se ha enviado no se puede repetir con otro proveedor."""
    plan = Plan(modelo, settings.llm_plazo_voz_s if plazo_s is None else plazo_s)
    for destino, segundos in plan:
        hubo_texto = False
        try:
            for texto in _stream_destino(mensajes, destino, segundos, max_tokens, temperatura):
                if not hubo_texto:
                    plan.exito(destino)
                    hubo_texto = True
                yield texto
            return
        except ErrorLLM as e:
            if hubo_texto:
                raise
            plan.fallo(destino, e)
        except httpx.HTTPError as e:
            if hubo_texto:
                raise ErrorLLM(f"LLM cortado a medias ({type(e).__name__})") from e
            plan.fallo(destino, _error_red(e))
    raise plan.rendirse()
