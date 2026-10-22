"""Orquestador de una respuesta para mensajes "normales" (el guardrail ya los ha filtrado).

datos personales → reformulación jurídica (LLM rápido) → RAG con las dos consultas → generación (LLM)
→ verificación frase a frase antes de la voz (capa 4)
La reformulación va en paralelo con la búsqueda de la pregunta original: mientras el LLM reformula, se calculan los
rankings BM25 y densos de la pregunta, y al llegar la consulta jurídica solo falta buscarla a ella y fusionar. El
resultado es idéntico al de buscar después (misma fusión RRF, en el mismo orden).
Dos canales con las mismas capas (preparar() es común):
- voz, responder(): Custom LLM de ElevenLabs, en streaming. Puede empezar por una frase puente («Vale, te lo
  explico.») para que el agente hable mientras se prepara la respuesta. Cualquier fallo acaba en una respuesta
  segura, nunca en silencio ni en un error.
- texto, responder_texto(): POST /api/agent/ask, el modo de respaldo. Prompt para leer en pantalla y la
  respuesta entera de una vez, con los artículos usados. Si el LLM falla lanza ErrorLLM, y el endpoint
  devuelve el error de la sección 8.4 con el mensaje seguro para que la app ofrezca reintentar.
"""

import logging
import random
import re
import time
from collections.abc import Iterator
from concurrent.futures import ThreadPoolExecutor
from concurrent.futures import TimeoutError as TiempoAgotado
from dataclasses import dataclass

from app.agent import prompts
from app.agent.pii import limpiar
from app.agent.safety import normalizar
from app.agent.verificacion import normalizar_salida, verificar_stream, verificar_texto
from app.api.errores import resumen_error
from app.config import settings
from app.llm import client
from app.rag.retrieve import Fragmento, get_recuperador

log = logging.getLogger("tuturno.orquestador")

RESPUESTA_SEGURA = "Ahora mismo no he podido responderte. Prueba otra vez en un momento, o pulsa el botón de Ayuda si lo necesitas."
RESPUESTA_SEGURA_TRAS_PUENTE = "Perdona, " + RESPUESTA_SEGURA[0].lower() + RESPUESTA_SEGURA[1:]  # detrás de «Vale, te lo explico.»
TURNOS_HISTORIAL = 6
K_FRAGMENTOS = 6  # artículos que ve el LLM: con 4, artículos clave en 5.º-7.º lugar quedaban fuera
MAX_TOKENS_TEXTO = 900  # incluye el razonamiento de gpt-oss
MARGEN_REFORMULAR_S = 0.3  # la llamada ya tiene su plazo; esto cubre el reparto entre hilos

# Frase puente de la voz: corta, neutra y válida para cualquier pregunta. No se usa con saludos, agradecimientos ni
# mensajes muy cortos («hola», «gracias», «vale»): ahí no pega un «te lo explico» y la respuesta ya es breve.
FRASES_PUENTE = ("Vale, te lo explico.", "Vale, te cuento.")
MIN_PALABRAS_PUENTE = 3
MAX_PALABRAS_SOCIAL = 6
RE_SOCIAL = re.compile(r"^[\W_]*(hola|buenas|gracias|muchas gracias|vale|ok|okay|adi[oó]s|hasta luego|chao|genial|perfecto|de acuerdo|entendido)\b", re.IGNORECASE)
# Muletilla de entrada al principio de la respuesta («Vale, te lo explico.», «Claro, ...»): después de la frase puente
# sonaría repetida. El prompt ya pide no usarlas; esto es la red de seguridad. Solo con puntuación detrás, para no
# tocar frases como «Vale la pena preguntar...».
RE_ECO_PUENTE = re.compile(
    r"^\s*(?:(?:vale|claro|de acuerdo|por supuesto|muy bien)\s*[,.:;!]+\s*)?(?:te (?:lo )?(?:explico|cuento)\s*[,.:;!]+\s*)?",
    re.IGNORECASE,
)

# Malestar que no llega a crisis (las reglas de crisis ya han pasado): «tengo mucho miedo», «lo estoy pasando fatal»,
# «me acosan», «me pegaron en el baño». Sobre el texto normalizado del guardrail (sin tildes ni signos). Con malestar no
# hay frase puente (un «Vale, te lo explico.» delante de «tengo mucho miedo» suena a no haber escuchado) y, si la
# respuesta no ha nombrado a ANAR, se añade el recordatorio: la norma 7 del prompt lo pide, pero el LLM no siempre lo
# hace. Si solo se habla del tema (acoso, fotos íntimas), también el recordatorio, pero con frase puente: «¿Qué hace la
# Fiscalía de Menores si hay acoso escolar?» es uno de los ejemplos de la app.
RE_MALESTAR = re.compile(
    r"\b(miedo|panico|asustad[oa]s?|aterrad[oa]s?|agobiad[oa]s?|angustiad[oa]s?|desesperad[oa]s?|ansiedad|triste|tristeza"
    r"|llor(o|ando|ar|e)|me odio|odio mi vida|nadie me (quiere|entiende|ayuda|cree|escucha)"
    r"|me siento (muy )?(mal|sol[oa]|fatal|vaci[oa]|horrible)|estoy (muy )?(mal|fatal|hundid[oa]|destrozad[oa]|sol[oa])"
    r"|lo (estoy pasando|paso) (muy )?(mal|fatal)|me (acosan|acosa|insultan|humillan|amenazan|hacen bullying|hacen dano)"
    r"|me hacen la vida imposible"
    r"|me (pegaron|han pegado|pegaba|pegaban|grabaron|han grabado|insultaron|insultaban|acosaron|acosaban|amenazaron"
    r"|tocaba|tocaron|toco|ha tocado|han tocado|violaron|ha violado|agredio|agredieron|ha agredido))\b"
)
RE_TEMA_VIOLENCIA = re.compile(r"\b(acoso|ciberacoso|bullying|desnud[oa]s?|(fotos?|videos?) (intim[oa]s?|mias?|mios?))\b")  # no «fotos de mi ex»
RECORDATORIO_ANAR = {
    "voz": "Si lo necesitas, en la Fundación ANAR te escuchan a cualquier hora: novecientos, veinte, veinte, diez.",
    "texto": "Si lo necesitas, en la Fundación ANAR te escuchan a cualquier hora: 900 20 20 10.",
}
RE_AYUDA_DICHA = re.compile(r"ANAR|novecientos,? veinte|900 ?20 ?20 ?10|116 ?111|ciento diecis[eé]is", re.IGNORECASE)

# La reformulación corre en estos hilos mientras el hilo de la petición busca la pregunta original. Uno por cada hilo
# de petición (HILOS_MAX): cada petición tiene como mucho una reformulación en marcha y nunca espera a que haya hueco.
_hilos_reformular = ThreadPoolExecutor(max_workers=settings.hilos_max, thread_name_prefix="reformular")


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


def menor_de_14(perfil: dict) -> bool:
    """Solo si la app ha mandado la edad (normalizar_perfil la deja como entero)."""
    edad = perfil.get("edad")
    return isinstance(edad, int) and edad < 14


def malestar(pregunta: str) -> bool:
    return bool(RE_MALESTAR.search(normalizar(pregunta)))


def recordar_ayuda(pregunta: str) -> bool:
    """Malestar o violencia en la pregunta: la respuesta tiene que nombrar a ANAR."""
    norm = normalizar(pregunta)
    return bool(RE_MALESTAR.search(norm) or RE_TEMA_VIOLENCIA.search(norm))


def _ultima_pregunta(mensajes: list[dict]) -> str:
    return next((m.get("content") or "" for m in reversed(mensajes) if m.get("role") == "user"), "")


def frase_puente(pregunta: str) -> str | None:
    """Primer trozo de la voz mientras se prepara la respuesta, o None (desactivada, un saludo o un «gracias», o un
    mensaje con malestar). Solo se llama cuando el guardrail ha dicho «normal»: nunca en crisis, hechos ni fuera de
    ámbito."""
    if not settings.voz_frase_puente:
        return None
    palabras = len(pregunta.split())
    if palabras < MIN_PALABRAS_PUENTE:
        return None
    if RE_SOCIAL.match(pregunta) and palabras <= MAX_PALABRAS_SOCIAL and "?" not in pregunta:
        return None
    if malestar(pregunta):
        return None
    return random.choice(FRASES_PUENTE)


def sin_eco_del_puente(frase: str) -> str:
    """Quita la muletilla de entrada de una frase de la respuesta; si no queda nada, devuelve ""."""
    resto = RE_ECO_PUENTE.sub("", frase, count=1)
    if resto == frase:
        return frase
    resto = resto.strip()
    return resto[:1].upper() + resto[1:] + " " if resto else ""


def reformular(pregunta: str, historial: list[dict], perfil: dict) -> str | None:
    texto_hist = "\n".join(f"{m['role']}: {m['content']}" for m in historial[:-1]) or "(ninguna)"
    try:
        consulta = client.completar(
            [{"role": "user", "content": prompts.REFORMULAR.format(
                perfil=prompts.describir_perfil(perfil), historial=texto_hist, pregunta=pregunta)}],
            modelo=settings.llm_modelo_reformular,
            plazo_s=settings.reformular_plazo_s,
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
    if not settings.llm_api_key:
        return recuperador.buscar(pregunta, perfil, k=K_FRAGMENTOS), None
    futuro = _hilos_reformular.submit(reformular, pregunta, historial, perfil)
    rankings = recuperador.rankings(pregunta)  # la pregunta original, mientras el LLM reformula
    try:
        consulta = futuro.result(timeout=settings.reformular_plazo_s + MARGEN_REFORMULAR_S)
    except TiempoAgotado:
        futuro.cancel()  # si aún no había empezado, que no gaste una llamada al LLM
        log.warning("Reformulación sin respuesta en %.1f s: se busca solo con la pregunta original", settings.reformular_plazo_s)
        consulta = None
    return recuperador.buscar(pregunta, perfil, k=K_FRAGMENTOS, consulta_juridica=consulta, rankings_pregunta=rankings), consulta


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


def responder(mensajes: list[dict], perfil: dict, puente: str | None = None) -> Iterator[str]:
    """Canal de voz. Con `puente`, esa frase sale la primera, antes de reformular y buscar; el prompt avisa al LLM de
    que la voz ya ha empezado y, si aun así abre con una muletilla («Vale, te lo explico.»), se quita. Si el último
    mensaje no es del usuario, no dice nada. Si algo falla, o la verificación lo quita todo, la respuesta segura: el
    agente nunca se queda callado ni recibe un error. Si la pregunta muestra malestar o habla de violencia y la respuesta
    no ha nombrado a ANAR, termina con el recordatorio."""
    inicio = time.perf_counter()
    if puente:
        yield puente + " "
    dicho = False
    texto_dicho: list[str] = []
    try:
        contexto = preparar(mensajes, perfil)
        if contexto is None:
            return
        llamada = [{"role": "system", "content": prompts.sistema(perfil, contexto.fragmentos, puente=bool(puente))}] + contexto.historial
        generado = client.stream(llamada, modelo=settings.llm_modelo, plazo_s=settings.llm_plazo_voz_s)
        for trozo in verificar_stream(generado, menor_14=menor_de_14(perfil)):
            if puente and not dicho:
                trozo = sin_eco_del_puente(trozo)
                if not trozo:
                    continue
            if not dicho:
                log.info("Primera frase verificada: %.0f ms desde la pregunta", (time.perf_counter() - inicio) * 1000)
                dicho = True
            texto_dicho.append(trozo)
            yield trozo
    except Exception as e:  # noqa: BLE001 - ante cualquier fallo (LLM, RAG, red), respuesta segura
        log.error("Generación fallida: %s", resumen_error(e))
    if not dicho:
        yield RESPUESTA_SEGURA_TRAS_PUENTE if puente else RESPUESTA_SEGURA
    if recordar_ayuda(_ultima_pregunta(mensajes)) and not RE_AYUDA_DICHA.search("".join(texto_dicho)):
        log.info("Recordatorio de ANAR añadido (malestar)")
        # Lo verificado ya acaba en espacio; la respuesta segura, no
        yield (RECORDATORIO_ANAR["voz"] if dicho else " " + RECORDATORIO_ANAR["voz"]) + " "


def responder_texto(mensajes: list[dict], perfil: dict) -> RespuestaTexto:
    """Canal de texto. Lanza client.ErrorLLM si no hay una respuesta que enseñar."""
    contexto = preparar(mensajes, perfil)
    if contexto is None:
        raise client.ErrorLLM("No hay ninguna pregunta del usuario")
    llamada = [{"role": "system", "content": prompts.sistema(perfil, contexto.fragmentos, canal="texto")}] + contexto.historial
    bruto = client.completar(llamada, modelo=settings.llm_modelo, max_tokens=MAX_TOKENS_TEXTO, temperatura=0.3)
    # Antes de separar las fuentes: así una cita con corchetes lenticulares («【LECrim art. 682】») se quita como las demás
    cuerpo, citas = prompts.separar_fuentes(normalizar_salida(bruto))
    texto = verificar_texto(cuerpo, menor_14=menor_de_14(perfil))
    if not texto:
        raise client.ErrorLLM("Respuesta vacía después de la verificación")
    if recordar_ayuda(_ultima_pregunta(mensajes)) and not RE_AYUDA_DICHA.search(texto):
        log.info("Recordatorio de ANAR añadido (malestar)")
        texto = con_recordatorio(texto, RECORDATORIO_ANAR["texto"])
    return RespuestaTexto(texto, prompts.fuentes_usadas(citas, contexto.fragmentos))


def con_recordatorio(texto: str, recordatorio: str) -> str:
    """El recordatorio como penúltimo párrafo si el último es la pregunta para seguir («¿Quieres saber...?»)."""
    parrafos = texto.split("\n\n")
    if len(parrafos) > 1 and parrafos[-1].rstrip().endswith("?"):
        return "\n\n".join([*parrafos[:-1], recordatorio, parrafos[-1]])
    return f"{texto}\n\n{recordatorio}"
