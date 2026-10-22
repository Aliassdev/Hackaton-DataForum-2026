"""Capa 4: verificación frase a frase de la respuesta del LLM antes de que llegue a la voz.

El texto se acumula hasta completar una frase; cada frase se revisa:
1. Patrones prohibidos (límites del agente): preguntar por los hechos, prometer secreto absoluto,
   predecir el resultado del caso. La frase se elimina y, si procede, se sustituye por una segura.
2. Formato para voz: sin markdown, con los números escritos con letras y, si la voz no las entiende
   (TTS_ETIQUETAS=false), sin nada entre corchetes: ni etiquetas de tono ([slow]) ni citas ([LORPM art. 3]).
3. Longitud máxima.
El canal de texto (POST /api/agent/ask) usa verificar_texto: los mismos patrones prohibidos, pero con los
números en cifras y conservando los párrafos, porque la respuesta se lee en pantalla.
"""

import logging
import re
from collections.abc import Iterable, Iterator

from app.config import settings

log = logging.getLogger("tuturno.verificacion")

MAX_PALABRAS = 110
MAX_PALABRAS_TEXTO = 160  # el prompt de texto pide 110 como máximo
# Fin de frase: un signo de cierre y espacio, o un salto de línea. Nunca detrás de «art.» o «arts.»: partiría en dos una
# cita como «[LORPM art. 22]» y la mitad sin corchetes se leería en alto
FIN_FRASE = re.compile(r"(?<=[.!?…])(?<![Aa]rt\.)(?<![Aa]rts\.)\s+|\n+")

PROHIBIDOS = {
    "pregunta_hechos": (
        re.compile(
            r"(qu[ée]|c[óo]mo) (te )?(pas[óo]|ha pasado|te hizo|te hicieron|ocurri[óo])"
            r"|cu[ée]ntame (lo que|qu[ée]|c[óo]mo) (pas[óo]|te hizo|ocurri[óo])"
            r"|(dime|cu[ée]ntame|expl[íi]came) (m[áa]s )?(detalles|lo que pas[óo]|qui[ée]n fue)",
            re.IGNORECASE,
        ),
        None,  # se elimina sin sustituir: nunca se pregunta por los hechos
    ),
    "secreto_absoluto": (
        re.compile(
            r"nadie (se )?(va a )?(enterar[áa]?|sabr[áa])|(es|ser[áa]) (totalmente |completamente |siempre )?(secreto|confidencial)"
            r"|no se lo (dir[ée]|contar[ée]) a nadie|quedar[áa] entre (t[úu] y yo|nosotros)|te prometo que nadie",
            re.IGNORECASE,
        ),
        "Lo que hablamos es privado, pero si hay un peligro, los adultos que te protegen tienen que actuar.",
    ),
    "prediccion": (
        re.compile(
            r"(seguro que|te aseguro que|te garantizo) .*(ganar|perder|condena|c[áa]rcel|absuelv|culpable)"
            r"|vas a ganar|vas a perder|(le|te) van a condenar|no te va a pasar nada|ir[áa]s? a la c[áa]rcel|saldr[áa]s? absuelt",
            re.IGNORECASE,
        ),
        "Lo que pase en cada caso depende de muchas cosas; tu abogado te lo puede explicar mejor.",
    ),
}

UNIDADES = ["cero", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez", "once", "doce", "trece", "catorce", "quince", "dieciséis", "diecisiete", "dieciocho", "diecinueve", "veinte", "veintiuno", "veintidós", "veintitrés", "veinticuatro", "veinticinco", "veintiséis", "veintisiete", "veintiocho", "veintinueve"]
DECENAS = {3: "treinta", 4: "cuarenta", 5: "cincuenta", 6: "sesenta", 7: "setenta", 8: "ochenta", 9: "noventa"}
CENTENAS = {1: "ciento", 2: "doscientos", 3: "trescientos", 4: "cuatrocientos", 5: "quinientos", 6: "seiscientos", 7: "setecientos", 8: "ochocientos", 9: "novecientos"}


def numero_a_letras(n: int) -> str:
    if n < 30:
        return UNIDADES[n]
    if n < 100:
        d, u = divmod(n, 10)
        return DECENAS[d] + (f" y {UNIDADES[u]}" if u else "")
    if n == 100:
        return "cien"
    if n < 1000:
        c, r = divmod(n, 100)
        return CENTENAS[c] + (f" {numero_a_letras(r)}" if r else "")
    if n < 1_000_000:
        m, r = divmod(n, 1000)
        return ("mil" if m == 1 else f"{numero_a_letras(m)} mil") + (f" {numero_a_letras(r)}" if r else "")
    return str(n)


def para_texto(frase: str) -> str:
    return re.sub(r"[*_#`>]+|^\s*[-•]\s*", "", frase)  # markdown y viñetas


# Lo que va entre corchetes en una línea: etiquetas de tono ([slow]) o una cita que se haya colado ([LORPM art. 3])
RE_CORCHETES = re.compile(r"\s*\[[^\[\]\n]{0,80}\]")


def sin_etiquetas(texto: str) -> str:
    """Quita lo que va entre corchetes. La voz eleven_flash_v2_5 no entiende las etiquetas y las leería en alto."""
    return re.sub(r"[ \t]{2,}", " ", RE_CORCHETES.sub("", texto)).strip()


def para_voz(frase: str) -> str:
    if not settings.tts_etiquetas:
        frase = sin_etiquetas(frase)
    return re.sub(r"\d+", lambda m: numero_a_letras(int(m.group())), para_texto(frase))


def revisar(frase: str, voz: bool = True) -> tuple[str | None, str | None]:
    """Devuelve (frase final o None si se elimina, motivo o None)."""
    for motivo, (patron, sustituta) in PROHIBIDOS.items():
        if patron.search(frase):
            return sustituta, motivo
    return (para_voz(frase) if voz else para_texto(frase)), None


def verificar_stream(trozos: Iterable[str]) -> Iterator[str]:
    buffer, palabras, sustituidas = "", 0, set()

    def emitir(frase: str) -> Iterator[str]:
        nonlocal palabras
        final, motivo = revisar(frase.strip())
        if motivo:
            log.warning("Verificación: frase eliminada (%s)", motivo)
            if final is None or motivo in sustituidas:
                return
            sustituidas.add(motivo)
        if final and palabras < MAX_PALABRAS:
            palabras += len(final.split())
            yield final + " "

    for trozo in trozos:
        buffer += trozo
        partes = FIN_FRASE.split(buffer)
        for frase in partes[:-1]:
            if frase.strip():
                yield from emitir(frase)
        buffer = partes[-1]
    if buffer.strip():
        yield from emitir(buffer)


def verificar_texto(texto: str, max_palabras: int = MAX_PALABRAS_TEXTO) -> str:
    """La misma revisión frase a frase para el canal de texto: cifras en vez de letras y un párrafo por línea."""
    parrafos, palabras, sustituidas = [], 0, set()
    for linea in re.split(r"\s*\n\s*", texto):
        frases = []
        for frase in FIN_FRASE.split(linea):
            if not frase.strip() or palabras >= max_palabras:
                continue
            final, motivo = revisar(frase.strip(), voz=False)
            if motivo:
                log.warning("Verificación: frase eliminada (%s)", motivo)
                if final is None or motivo in sustituidas:
                    continue
                sustituidas.add(motivo)
            if final and final.strip():
                palabras += len(final.split())
                frases.append(final.strip())
        if frases:
            parrafos.append(" ".join(frases))
    return "\n\n".join(parrafos)
