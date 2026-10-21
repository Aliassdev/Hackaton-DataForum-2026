"""Orquestador de una respuesta para mensajes "normales" (el guardrail ya los ha filtrado).

datos personales → reformulación jurídica (LLM rápido) → RAG con las dos consultas → generación (LLM)
→ verificación frase a frase antes de la voz (capa 4)
Cualquier fallo del LLM acaba en una respuesta segura, nunca en silencio ni en un error.
"""

import logging
import time
from collections.abc import Iterator

from app.agent import prompts
from app.agent.pii import limpiar
from app.agent.verificacion import verificar_stream
from app.config import settings
from app.llm import client
from app.rag.retrieve import Fragmento, get_recuperador

log = logging.getLogger("tuturno.orquestador")

RESPUESTA_SEGURA = "Ahora mismo no he podido responderte. Prueba otra vez en un momento, o pulsa el botón de Ayuda si lo necesitas."
TURNOS_HISTORIAL = 6
K_FRAGMENTOS = 6  # artículos que ve el LLM: con 4, artículos clave en 5.º-7.º lugar quedaban fuera


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
    except client.ErrorLLM as e:
        log.warning("Reformulación fallida (%s): se busca solo con la pregunta original", e)
        return None


def recuperar(pregunta: str, historial: list[dict], perfil: dict) -> tuple[list[Fragmento], str | None]:
    recuperador = get_recuperador()
    if recuperador is None:
        return [], None
    consulta = reformular(pregunta, historial, perfil) if settings.llm_api_key else None
    return recuperador.buscar(pregunta, perfil, k=K_FRAGMENTOS, consulta_juridica=consulta), consulta


def responder(mensajes: list[dict], perfil: dict) -> Iterator[str]:
    inicio = time.perf_counter()
    historial = _historial(mensajes)
    if not historial or historial[-1]["role"] != "user":
        yield RESPUESTA_SEGURA
        return
    pregunta = historial[-1]["content"]

    fragmentos, consulta = recuperar(pregunta, historial, perfil)
    t_rag = time.perf_counter()
    log.info("Consulta jurídica: %r · fuentes=%s · %.0f ms", consulta, [f.cita for f in fragmentos], (t_rag - inicio) * 1000)

    llamada = [{"role": "system", "content": prompts.sistema(perfil, fragmentos)}] + historial
    primero = True
    try:
        for trozo in verificar_stream(client.stream(llamada, modelo=settings.llm_modelo)):
            if primero:
                log.info("Primer token del LLM: %.0f ms desde la pregunta", (time.perf_counter() - inicio) * 1000)
                primero = False
            yield trozo
    except (client.ErrorLLM, Exception) as e:  # noqa: BLE001 - ante cualquier fallo, respuesta segura
        log.error("Generación fallida: %s", e)
        if primero:
            yield RESPUESTA_SEGURA
