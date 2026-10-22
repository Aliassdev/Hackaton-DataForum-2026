"""Protección de los endpoints públicos: origen web permitido y límite de peticiones.

IP real. Detrás de Hugging Face Spaces es la ÚLTIMA entrada de X-Forwarded-For: el proxy de HF añade al
final la IP desde la que se conecta el cliente y conserva delante lo que el cliente haya escrito en esa
cabecera (comprobado con un Space de prueba). Por eso no se usan las entradas anteriores, ni X-Real-IP ni
Forwarded, que llegan tal cual las manda el cliente. Tampoco request.client.host: en HF es la IP interna
del proxy (la misma para todos) o, si uvicorn arranca con --forwarded-allow-ips='*', la PRIMERA entrada
de X-Forwarded-For, que es justo la que escribe el cliente. PROXIES_DE_CONFIANZA dice cuántas entradas
añaden los proxies (HF: 1).

Límites. Por IP, ventana deslizante en memoria (un solo contenedor); las IPv6 se agrupan por /64, porque
un mismo cliente tiene miles. No se guardan las IP: la clave es un resumen con una sal aleatoria que cambia
en cada arranque, y en los logs solo salen 8 caracteres de ese resumen. Además, un tope diario para todos
por grupo de endpoints, que se reinicia a las 00:00 UTC.

Origen. En HF el proxy contesta él mismo al preflight de CORS y añade Access-Control-Allow-Origin con
cualquier origen (comprobado), así que CORSMiddleware no impide que otra web use la API desde el navegador.
Si la petición trae Origin y no está permitido, 403. Sin Origin (la APK, curl o ElevenLabs) se deja pasar:
el límite de peticiones es lo que protege de los scripts.
"""

import hashlib
import ipaddress
import logging
import math
import re
import secrets
import threading
import time
from collections import deque
from collections.abc import Awaitable, Callable
from dataclasses import dataclass

from fastapi import Request

from app.api.errores import ErrorApi
from app.config import settings

log = logging.getLogger("tuturno.limites")

MENSAJE_LIMITE_IP = "Hay muchas preguntas a la vez. Espera un momento y vuelve a probar."
MENSAJE_LIMITE_DIA = "Hoy ya se han hecho muchas preguntas. Vuelve a probar mañana."
MENSAJE_ORIGEN = "Esta página no tiene permiso para usar TuTurno."
LIMPIAR_CADA = 500  # cada cuántas peticiones se borran de memoria las IP sin actividad reciente
DIA_S = 86400

Ip = ipaddress.IPv4Address | ipaddress.IPv6Address


@dataclass(frozen=True)
class Cubo:
    """Límite de un grupo de endpoints. 0 = sin límite."""

    nombre: str
    por_ip: int
    diario: int
    ventana_s: float


def cubo(nombre: str) -> Cubo:
    """Valores de config.py en el momento de la petición."""
    limites = {
        "sesion": (settings.limite_sesion_ip, settings.limite_sesion_dia),
        "ask": (settings.limite_ask_ip, settings.limite_ask_dia),
        "grade": (settings.limite_grade_ip, settings.limite_grade_dia),
    }
    por_ip, diario = limites[nombre]
    return Cubo(nombre, por_ip, diario, settings.limite_ventana_s)


def _ip(texto: str) -> Ip | None:
    texto = texto.strip().strip('"')
    if texto.startswith("[") and "]" in texto:  # [2001:db8::1]:443
        texto = texto[1 : texto.index("]")]
    elif texto.count(":") == 1:  # 203.0.113.7:443
        texto = texto.split(":")[0]
    try:
        return ipaddress.ip_address(texto)
    except ValueError:
        return None


def ip_cliente(request: Request) -> str:
    """IP real del cliente: la entrada de X-Forwarded-For que añadió el primer proxy de confianza."""
    saltos = settings.proxies_de_confianza
    if saltos > 0:
        entradas = [e for valor in request.headers.getlist("x-forwarded-for") for e in valor.split(",") if e.strip()]
        if len(entradas) >= saltos and (ip := _ip(entradas[-saltos])) is not None:
            return str(ip)
    return request.client.host if request.client else "desconocida"


def origen_permitido(origen: str | None) -> bool:
    if not origen:
        return True
    if "*" in settings.allowed_origins or origen in settings.allowed_origins:
        return True
    return bool(settings.allowed_origin_regex) and re.fullmatch(settings.allowed_origin_regex, origen) is not None


class Limitador:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self.reiniciar()

    def reiniciar(self) -> None:
        with self._lock:
            self._sal = secrets.token_bytes(16)
            self._ventanas: dict[tuple[str, str], deque[float]] = {}
            self._dia = -1  # días desde 1970 en UTC
            self._hoy: dict[str, int] = {}
            self._peticiones = 0
            self._ventana_max = 0.0

    def resumen(self, ip: str) -> str:
        obj = _ip(ip)
        if isinstance(obj, ipaddress.IPv6Address):
            texto = str(obj.ipv4_mapped or ipaddress.ip_network(f"{obj}/64", strict=False))
        else:
            texto = str(obj) if obj is not None else ip
        return hashlib.sha256(self._sal + texto.encode()).hexdigest()[:16]

    def comprobar(self, cubo: Cubo, ip: str, ahora: float | None = None, reloj: float | None = None) -> None:
        """Cuenta la petición o lanza ErrorApi 429 (con Retry-After) si supera algún límite.
        ahora: segundos monótonos (ventana por IP); reloj: segundos desde 1970 (tope diario, en UTC)."""
        ahora = time.monotonic() if ahora is None else ahora
        reloj = time.time() if reloj is None else reloj
        clave = (cubo.nombre, self.resumen(ip))
        with self._lock:
            if (hoy := int(reloj // DIA_S)) != self._dia:
                self._dia, self._hoy = hoy, {}
            marcas = self._ventanas.get(clave, deque())
            while marcas and marcas[0] <= ahora - cubo.ventana_s:
                marcas.popleft()
            if cubo.por_ip and len(marcas) >= cubo.por_ip:
                espera = max(1, math.ceil(marcas[0] + cubo.ventana_s - ahora))
                log.warning("Límite por IP en %s (cliente %s)", cubo.nombre, clave[1][:8])
                raise ErrorApi(429, "DEMASIADAS_PETICIONES", MENSAJE_LIMITE_IP, {"Retry-After": str(espera)})
            if cubo.diario and self._hoy.get(cubo.nombre, 0) >= cubo.diario:
                espera = max(1, math.ceil((hoy + 1) * DIA_S - reloj))  # hasta las 00:00 UTC
                log.warning("Tope diario de %s alcanzado (%d)", cubo.nombre, cubo.diario)
                raise ErrorApi(429, "LIMITE_DIARIO", MENSAJE_LIMITE_DIA, {"Retry-After": str(espera)})
            self._hoy[cubo.nombre] = self._hoy.get(cubo.nombre, 0) + 1
            if cubo.por_ip:
                marcas.append(ahora)
                self._ventanas[clave] = marcas
                self._ventana_max = max(self._ventana_max, cubo.ventana_s)
            self._peticiones += 1
            if self._peticiones % LIMPIAR_CADA == 0:
                self._ventanas = {k: v for k, v in self._ventanas.items() if v and v[-1] > ahora - self._ventana_max}


limitador = Limitador()


def proteger(nombre: str) -> Callable[[Request], Awaitable[None]]:
    """Dependencia de FastAPI: origen permitido y límite de peticiones del grupo `nombre`."""

    async def dependencia(request: Request) -> None:
        if not origen_permitido(request.headers.get("origin")):
            raise ErrorApi(403, "ORIGEN_NO_PERMITIDO", MENSAJE_ORIGEN)
        limitador.comprobar(cubo(nombre), ip_cliente(request))

    return dependencia
