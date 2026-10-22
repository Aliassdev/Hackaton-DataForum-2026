"""Orquestador de una respuesta para mensajes "normales" (el guardrail ya los ha filtrado).

datos personales → reformulación jurídica (LLM rápido) → RAG con las dos consultas → generación (LLM)
→ verificación frase a frase antes de la voz (capa 4)
Dos canales con las mismas capas (preparar() es común):
- voz, responder(): Custom LLM de ElevenLabs, en streaming. Cualquier fallo del LLM acaba en una respuesta
  segura, nunca en silencio ni en un error.
- texto, responder_texto(): POST /api/agent/ask, el modo de respaldo. Prompt para leer en pantalla y la
  respuesta entera de una vez, con los artículos usados. Si el LLM falla lanza ErrorLLM, y el endpoint
  devuelve el error de la sección 8.4 con el mensaje seguro para que la app ofrezca reintentar.
"""

import logging
import time
from collections.abc import Iterator
from dataclasses import dataclass

from app.agent import prompts
from app.agent.pii import limpiar
from app.agent.verificacion import verificar_stream, verificar_texto
from app.api.errores import resumen_error
from app.config import settings
from app.llm import client
from app.rag.retrieve import Fragmento, get_recuperador

log = logging.getLogger("tuturno.orquestador")

RESPUESTA_SEGURA = "Ahora mismo no he podido responderte. Prueba otra vez en un momento, o pulsa el botón de Ayuda si lo necesitas."
TURNOS_HISTORIAL = 6
K_FRAGMENTOS = 6  # artículos que ve el LLM: con 4, artículos clave en 5.º-7.º lugar quedaban fuera
MAX_TOKENS_TEXTO = 900  # incluye el razonamiento de gpt-oss


@dataclass
class Contexto:
    """Lo que comparten los dos canales: el historial sin datos personales y los artículos recuperados."""

    historial: list[dict]
    fragmentos: list[Fragmento]


@dataclass
class RespuestaTexto:
    texto: str
    fragmentos: list[Fragmento]  # los artículos que el LLM dice haber usado


def _historial(mensajes: list[dict]) -> list[dict]:
    """Últimos turnos de la conversación (sin el prompt de ElevenLabs) y sin datos personales."""
    turnos = [m for m in mensajes if m["role"] in ("user", "assistant") and m.get("content")]
    return [{"role": m["role"], "content": limpiar(m["content"])} for m in turnos[-TURNOS_HISTORIAL:]]


def reformular(pregunta: str, historial: list[dict], perfil: dict) -> str | None:
    texto_hist = "\n".join(f"{m['role']}: {m['content']}" for m in historial[:-1]) or "(ninguna)"
    try:
        consulta = client.completar(
            [{"role": "user", "content": prompts.REFORMULAR.format(
                perfil=prompts.describir_perfil(perfil), historial=texto_hist, pregunta=pregunta)}],
            modelo=settings.llm_modelo_reformular,
        )
        return consulta.splitlines()[0].strip(' "') if consulta else None
    except Exception as e:  # noqa: BLE001 - es opcional: ante cualquier fallo (también de red), sin reformular
        # Solo el resumen: el cuerpo del error del proveedor puede repetir lo que había generado el modelo
        log.warning("Reformulación fallida (%s): se busca solo con la pregunta original", resumen_error(e))
        return None


def recuperar(pregunta: str, historial: list[dict], perfil: dict) -> tuple[list[Fragmento], str | None]:
    recuperador = get_recuperador()
    if recuperador is None:
        return [], None
    consulta = reformular(pregunta, historial, perfil) if settings.llm_api_key else None
    return recuperador.buscar(pregunta, perfil, k=K_FRAGMENTOS, consulta_juridica=consulta), consulta


def preparar(mensajes: list[dict], perfil: dict) -> Contexto | None:
    """Datos personales fuera, reformulación y RAG. None si el último mensaje no es del usuario."""
    inicio = time.perf_counter()
    historial = _historial(mensajes)
    if not historial or historial[-1]["role"] != "user":
        return None
    fragmentos, consulta = recuperar(historial[-1]["content"], historial, perfil)
    # La consulta jurídica es una paráfrasis de lo que ha escrito el menor: al log solo va si la hay.
    log.info(
        "Consulta jurídica: %s · fuentes=%s · %.0f ms",
        "sí" if consulta else "no", [f.cita for f in fragmentos], (time.perf_counter() - inicio) * 1000,
    )
    return Contexto(historial, fragmentos)


def responder(mensajes: list[dict], perfil: dict) -> Iterator[str]:
    inicio = time.perf_counter()
    contexto = preparar(mensajes, perfil)
    if contexto is None:
        yield RESPUESTA_SEGURA
        return

    llamada = [{"role": "system", "content": prompts.sistema(perfil, contexto.fragmentos)}] + contexto.historial
    primero = True
    try:
        for trozo in verificar_stream(client.stream(llamada, modelo=settings.llm_modelo)):
            if primero:
                log.info("Primer token del LLM: %.0f ms desde la pregunta", (time.perf_counter() - inicio) * 1000)
                primero = False
            yield trozo
    except (client.ErrorLLM, Exception) as e:  # noqa: BLE001 - ante cualquier fallo, respuesta segura
        log.error("Generación fallida: %s", resumen_error(e))
        if primero:
            yield RESPUESTA_SEGURA


def responder_texto(mensajes: list[dict], perfil: dict) -> RespuestaTexto:
    """Canal de texto. Lanza client.ErrorLLM si no hay una respuesta que enseñar."""
    contexto = preparar(mensajes, perfil)
    if contexto is None:
        raise client.ErrorLLM("No hay ninguna pregunta del usuario")
    llamada = [{"role": "system", "content": prompts.sistema(perfil, contexto.fragmentos, canal="texto")}] + contexto.historial
    bruto = client.completar(llamada, modelo=settings.llm_modelo, max_tokens=MAX_TOKENS_TEXTO, temperatura=0.3)
    cuerpo, citas = prompts.separar_fuentes(bruto)
    texto = verificar_texto(cuerpo)
    if not texto:
        raise client.ErrorLLM("Respuesta vacía después de la verificación")
    return RespuestaTexto(texto, prompts.fuentes_usadas(citas, contexto.fragmentos))
