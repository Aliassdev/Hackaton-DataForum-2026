"""Capa 4: verificación frase a frase de la respuesta del LLM antes de que llegue a la voz.

El texto se acumula hasta completar una frase; cada frase se revisa:
1. Patrones prohibidos (límites del agente): preguntar por los hechos, prometer secreto absoluto,
   predecir el resultado del caso. La frase se elimina y, si procede, se sustituye por una segura.
   Una frase en inglés (gpt-oss contesta así a algunos jailbreaks: «I'm sorry, but I can't share that.») se sustituye
   por una negativa en español.
2. Formato para voz: sin markdown, con los números escritos con letras y, si la voz no las entiende
   (TTS_ETIQUETAS=false), sin nada entre corchetes: ni etiquetas de tono ([slow]) ni citas ([LORPM art. 3]).
3. Longitud máxima.
4. Sin género sobre la persona (sin_genero): el prompt lo pide, pero el LLM seguía escribiendo «puedes ir acompañado» o
   «si estás asustado». Se cambian solo las formas más comunes y solo detrás de un verbo en segunda persona o en
   infinitivo, que es cuando hablan de quien pregunta. Y a una víctima o a un testigo, «tu defensa» (que es el abogado
   de la persona investigada) se corrige.
Antes de todo, normalizar_salida(): gpt-oss a veces cita con corchetes lenticulares («【LECrim art. 682】»), que se
enseñaban en pantalla y se leían en voz alta, y separa las cifras de los teléfonos con espacios finos (U+202F),
que la app podría no reconocer como un teléfono.
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

_NUM = r"(10|[1-9]|un[oa]?|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez)\b"  # duraciones, no edades

PROHIBIDOS = {
    "pregunta_hechos": (
        re.compile(
            # «¿Qué pasó?» lleva tilde; «depende de lo que pasó» no es una pregunta y no se borra (la norma 9 del prompt
            # pide justo esa frase). Sin tilde, solo detrás de «¿».
            r"(qu[é]|c[ó]mo) (te )?(pas[óo]|ha pasado|te hizo|te hicieron|ocurri[óo])"
            r"|¿\s*(que|como) (te )?(pas[óo]|ha pasado|te hizo|te hicieron|ocurri[óo])"
            r"|cu[ée]ntame (lo que|qu[ée]|c[óo]mo) (pas[óo]|te hizo|ocurri[óo])"
            r"|(dime|cu[ée]ntame|expl[íi]came) (m[áa]s )?(detalles|lo que pas[óo]|qui[ée]n fue)",
            re.IGNORECASE,
        ),
        None,  # se elimina sin sustituir: nunca se pregunta por los hechos
    ),
    "secreto_absoluto": (
        re.compile(
            # Sobre lo que se habla aquí o con un «totalmente». No «el expediente de menores es confidencial»: es un dato
            # del proceso, y cambiarlo por la frase de abajo dejaba una frase sin sentido (pruebas del 22/10/2026).
            r"nadie (se )?(va a )?(enterar[áa]?|sabr[áa])"
            r"|(lo que (me )?(dices|digas|cuentas|cuentes|escribes|escribas|hablamos|hablemos)|esta conversaci[óo]n|todo lo que)[^.]{0,40}"
            r"\b(es|ser[áa]|queda(r[áa])?|se queda(r[áa])?) (totalmente |completamente |siempre |absolutamente )?(secreto|confidencial)"
            r"|(es|ser[áa]) (totalmente|completamente|siempre|absolutamente) (secreto|confidencial)"
            r"|no se lo (dir[ée]|contar[ée]) a nadie|quedar[áa] entre (t[úu] y yo|nosotros)|te prometo que nadie",
            re.IGNORECASE,
        ),
        "Lo que hablamos es privado, pero si hay un peligro, los adultos que te protegen tienen que actuar.",
    ),
    # Años de internamiento («de uno a ocho años»): gpt-oss los copiaba de la LORPM aunque el prompt lo prohíbe, y casi
    # siempre del supuesto más grave (asesinato, violación). Solo duraciones de 1 a 10: «de 14 a 17 años» es una edad.
    "duracion_medida": (
        re.compile(
            rf"\b(medidas?|internamiento|libertad vigilada)\b[^.;]{{0,120}}?\b({_NUM}( a | y | o ){_NUM}|hasta {_NUM}"
            rf"|(un )?m[áa]ximo de {_NUM}|alcanzar {_NUM}|durar {_NUM}) años"
            rf"|\b{_NUM}( a | y ){_NUM} años de (internamiento|libertad vigilada|medida)",
            re.IGNORECASE,
        ),
        # Sustituye la frase entera, que solía llevar también el «no va a una cárcel de adultos»: aquí se repite
        (
            "Con la ley de menores no se va a una cárcel de adultos: el juez de menores puede poner medidas educativas, "
            "que dependen de lo que pasó y de cada persona. Tu abogado te lo puede explicar mejor."
        ),
    ),
    "prediccion": (
        re.compile(
            r"(seguro que|te aseguro que|te garantizo) .*(ganar|perder|condena|c[áa]rcel|absuelv|culpable)"
            # «No irás a la cárcel» (de 14 a 17 años se aplican medidas de la ley de menores) no es una predicción
            r"|vas a ganar|vas a perder|(le|te) van a condenar|no te va a pasar nada|(?<!no )(?<!nunca )ir[áa]s? a la c[áa]rcel|saldr[áa]s? absuelt",
            re.IGNORECASE,
        ),
        "Lo que pase en cada caso depende de muchas cosas; tu abogado te lo puede explicar mejor.",
    ),
}

# Solo con menos de 14 años (si se sabe la edad): el juramento y el aviso de falso testimonio son para los testigos
# mayores de edad penal (LECrim, art. 433), pero gpt-oss se los contaba a Lucía, de 11 años, aunque el prompt lo prohíbe.
PROHIBIDOS_MENOR_14 = {
    "falso_testimonio": (
        re.compile(r"falso testimonio|juramento|jurar(?:[áa]s)? (?:decir )?la verdad|mentir (?:es|ser[íi]a|puede ser) (?:un )?delito", re.IGNORECASE),
        "El juez te pedirá que cuentes lo que recuerdes, con tus palabras; si algo no lo sabes o no lo recuerdas, puedes decirlo.",
    ),
}

# Frase en inglés: palabras que no existen en español. Hacen falta 3 y que sean al menos el 40 % de la frase, para no
# saltar con un anglicismo suelto («bullying», «sexting»).
PALABRAS_INGLES = frozenset({
    "the", "and", "you", "your", "is", "are", "was", "were", "this", "that", "with", "what", "can", "can't", "cannot",
    "i'm", "i", "it", "it's", "of", "to", "for", "not", "sorry", "here", "please", "have", "do", "don't", "will", "would",
    "my", "help", "request", "comply", "share", "joke", "assist", "unable",
})
NEGATIVA_EN_ESPANOL = "Con eso no te puedo ayudar. Estoy aquí para explicarte cómo funciona la justicia y tus derechos."

# Espacios raros que mete el LLM (sobre todo U+202F entre las cifras de los teléfonos) → espacio normal; corchetes
# lenticulares → corchetes, para que las citas se quiten como las demás. Las citas de navegación de gpt-oss
# («【4†L1-L5】») no dicen nada: fuera.
TRADUCIR_SALIDA = str.maketrans(dict.fromkeys("\u00a0\u202f\u2007\u2009\u200a\u2002\u2003\u2004\u2005\u2006\u2008", " ") | {"\u3010": "[", "\u3011": "]"})
RE_CITA_NAVEGACION = re.compile("\u3010[^\u3010\u3011\n]*\u2020[^\u3010\u3011\n]*\u3011")  # 【…†…】


def normalizar_salida(texto: str) -> str:
    return RE_CITA_NAVEGACION.sub("", texto).translate(TRADUCIR_SALIDA)


# Muletillas inglesas que forman una frase por sí solas («Sure!», «Sorry.»)
MULETILLAS_INGLES = frozenset({"sure", "sorry", "hello", "hi", "yes", "okay", "oops", "well"})


def parece_ingles(frase: str) -> bool:
    palabras = [p.replace("’", "'") for p in re.findall(r"[a-zñáéíóúü'’]+", frase.lower())]
    if 0 < len(palabras) <= 2 and all(p in MULETILLAS_INGLES or p in PALABRAS_INGLES for p in palabras):
        return any(p in MULETILLAS_INGLES for p in palabras)
    ingles = sum(1 for p in palabras if p in PALABRAS_INGLES)
    return ingles >= 3 and ingles >= 0.4 * len(palabras)

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


# Norma 6 del prompt: sin números de artículo. El LLM a veces los pone entre paréntesis («(artículo 20)», «(Código Penal
# art. 197)»): se quitan, y en la voz no se leen. Los que van en la frase («según el artículo 197») se quedan.
RE_ARTICULO_ENTRE_PARENTESIS = re.compile(r"\s*\([^()\n]*\b(?:art[íi]culos?|arts?\.)\s*\d[^()\n]*\)", re.IGNORECASE)


# --- Sin género sobre la persona (filtro ligero) ---
# Solo formas que hablan de quien pregunta: detrás de un verbo en segunda persona o en infinitivo («si estás asustado»,
# «puedes ir acompañado»). «La persona investigada», «el menor está obligado» o «solo una vez» no se tocan, y tampoco
# las formas dobles («solo ni sola», «nervioso o nerviosa»).
_ESTAR = r"estar|estás|estarás|estés|estarías|estabas|estando|quedarte|te\s+quedes|te\s+quedas|te\s+quedarás"
_SENTIR = r"sentirte|te\s+sientes|te\s+sientas|te\s+sentirás|te\s+sentirías|sintiéndote|sentir"
_MOVER = (r"ir|vas|irás|vayas|venir|vienes|vendrás|vengas|declarar|declaras|declararás|declares|entrar|entras|entrarás|"
          r"entres|acudir|acudes|acudirás|acudas|presentarte|hablar|hablarás|hables")
# «nervioso o nerviosa», «solo ni sola»: la forma doble ya es inclusiva (mismo adjetivo detrás de ni, o, u, y)
_DOBLE = r"(?!\s+(?:ni|o|u|y)\s+(?P=adj)[oa]s?\b)"
# «incómodo/a», «tú mismo(a)»: la terminación doble se quita junto con el adjetivo (en la voz se leería «barra a»)
_BARRA = r"(?:\s*/\s*[oa]s?\b|\([oa]s?\))?"
# adjetivo → sin género, con «muy» y con «más»
ESTADOS = {
    "asustad": ("con miedo", "con mucho miedo", "con más miedo"),
    "nervios": ("con nervios", "con muchos nervios", "con más nervios"),
    "agobiad": ("con agobio", "con mucho agobio", "con más agobio"),
    "preocupad": ("con preocupación", "con mucha preocupación", "con más preocupación"),
    "tranquil": ("con tranquilidad", "con mucha tranquilidad", "con más tranquilidad"),
    "incómod": ("a disgusto", "muy a disgusto", "más a disgusto"),
    "insegur": ("con inseguridad", "con mucha inseguridad", "con más inseguridad"),
    "cómod": ("a gusto", "muy a gusto", "más a gusto"),
}
RE_ESTADO = re.compile(
    rf"\b(?P<verbo>{_ESTAR}|{_SENTIR})(?:\s+(?P<adv>muy|más))?\s+(?P<adj>{'|'.join(ESTADOS)})[oa]s?\b{_BARRA}{_DOBLE}", re.IGNORECASE
)
# «seguro» y «protegido» solo con «sentirte»: «si no estás seguro» suele ser «si no lo sabes»
RE_A_SALVO = re.compile(rf"\b(?P<verbo>{_SENTIR})(?:\s+(?P<adv>muy|más))?\s+(?P<adj>segur|protegid)[oa]s?\b{_BARRA}{_DOBLE}", re.IGNORECASE)
TENER = {"estás": "tienes", "estarás": "tendrás", "estar": "tener", "estés": "tengas", "estarías": "tendrías", "estabas": "tenías"}
RE_PROTEGIDO = re.compile(rf"\b(?P<verbo>{'|'.join(TENER)})\s+(?P<adj>protegid)[oa]s?\b{_BARRA}{_DOBLE}", re.IGNORECASE)
RE_OBLIGADO = re.compile(rf"\b(?P<verbo>{'|'.join(TENER)})(?P<adv>\s+siempre)?\s+obligad[oa]s?\b{_BARRA}\s+a\b", re.IGNORECASE)
RE_ACOMPANADO = re.compile(
    rf"\b(?P<verbo>{_ESTAR}|{_SENTIR}|{_MOVER})(?P<adv>\s+(?:siempre|también|bien))?\s+acompañad[oa]s?\b{_BARRA}"
    r"(?!\s+(?:o|u|y)\s+acompañad)(?P<prep>\s+(?:de|por)\b)?",
    re.IGNORECASE,
)
RE_INFORMADO = re.compile(r"\b(?P<verbo>estar|ser|estarás)\s+(?P<adj>informad)[oa]s?\b" + _BARRA + _DOBLE, re.IGNORECASE)
# «puedes ser llamada a declarar» → «te pueden llamar a declarar»: participio → (infinitivo, subjuntivo)
PASIVAS = {
    "oíd": ("oír", "oigan"), "escuchad": ("escuchar", "escuchen"), "llamad": ("llamar", "llamen"), "citad": ("citar", "citen"),
    "entrevistad": ("entrevistar", "entrevisten"), "acompañad": ("acompañar", "acompañen"), "atendid": ("atender", "atiendan"),
    "ayudad": ("ayudar", "ayuden"), "grabad": ("grabar", "graben"), "juzgad": ("juzgar", "juzguen"), "detenid": ("detener", "detengan"),
    "investigad": ("investigar", "investiguen"), "interrogad": ("interrogar", "interroguen"), "protegid": ("proteger", "protejan"),
    "representad": ("representar", "representen"), "asistid": ("asistir", "asistan"),
}
_PARTICIPIO = "|".join(PASIVAS)
RE_SER_ESCUCHADO = re.compile(
    # Sin «por el juez» detrás: «te pueden escuchar por el juez» no se entiende
    rf"\b(?P<lead>tienes\s+derecho\s+a|tienes\s+que|debes|puedes|podrás|vas\s+a|quieres)\s+ser\s+(?P<p1>{_PARTICIPIO})[oa]s?{_BARRA}"
    rf"(?:\s+y\s+(?P<p2>{_PARTICIPIO})[oa]s?{_BARRA})?\b(?!\s+por\b)",
    re.IGNORECASE,
)
ESCUCHAR = {  # lo que va delante → (con infinitivo o con subjuntivo, cómo empieza)
    "tienes derecho a": ("subj", "tienes derecho a que te"), "quieres": ("subj", "quieres que te"),
    "tienes que": ("inf", "te tienen que"), "debes": ("inf", "te tienen que"), "puedes": ("inf", "te pueden"),
    "podrás": ("inf", "te podrán"), "vas a": ("inf", "te van a"),
}
RE_NO_ESTAS_SOLO = re.compile(rf"\bno\s+estás\s+sol[oa]\b{_BARRA}(?!\s+(?:ni|o|u)\s+sol[oa])", re.IGNORECASE)
RE_TU_SOLO = re.compile(rf"\btú\s+sol[oa]\b{_BARRA}(?!\s+(?:ni|o|u)\s+sol[oa])", re.IGNORECASE)
# «solo» detrás de estar o de ir, y solo con un signo o una preposición detrás: «declaras solo una vez» no es «sin compañía»
RE_SOLO = re.compile(
    rf"\b(?P<verbo>{_ESTAR}|{_MOVER})\s+sol[oa]{_BARRA}(?=\s*[,.;:!?]|\s*$|\s+(?:en|ante|durante)\b)", re.IGNORECASE
)
RE_MISMO = re.compile(rf"\b(?P<por>por\s+)?(?P<pron>tú|ti)\s+mism[oa]\b{_BARRA}(?!\s+(?:o|u)\s+(?:tú|ti)\s+mism[oa])", re.IGNORECASE)
RE_MADURO = re.compile(rf"\beres\s+(?:lo\s+)?(?:bastante|suficientemente)\s+madur[oa]\b{_BARRA}", re.IGNORECASE)
RE_LISTO = re.compile(rf"\bcuando\s+(?:estés|te\s+sientas|te\s+veas)\s+(?:list[oa]|preparad[oa])\b{_BARRA}", re.IGNORECASE)
# Segundo adjetivo coordinado con el que ya se ha cambiado: «te sientas a salvo y tranquila» → «... y con tranquilidad»
NEUTRO = {adj: formas[0] for adj, formas in ESTADOS.items()} | {"segur": "a salvo", "protegid": "a salvo"}
RE_COORDINADO = re.compile(
    rf"(?P<prev>\b(?:muy |más )?a (?:salvo|gusto|disgusto)|\bcon (?:(?:mucho|mucha|muchos|más) )?"
    rf"(?:alguien|miedo|nervios|agobio|preocupación|tranquilidad|inseguridad))"
    rf"\s+(?P<y>y|o|ni)\s+"
    rf"(?P<adj>{'|'.join(NEUTRO)})[oa]s?\b{_BARRA}",
    re.IGNORECASE,
)


def _como(original: str, nuevo: str) -> str:
    """Con mayúscula inicial si el original la llevaba."""
    return nuevo[:1].upper() + nuevo[1:] if original[:1].isupper() else nuevo


def _escuchado(m: re.Match[str]) -> str:
    forma, inicio = ESCUCHAR[re.sub(r"\s+", " ", m.group("lead").lower())]
    i = 1 if forma == "subj" else 0
    verbos = [PASIVAS[p.lower()][i] for p in (m.group("p1"), m.group("p2")) if p]
    fin = (" y te " if forma == "subj" else " y ").join(verbos)
    return _como(m.group(0), f"{inicio} {fin}")


def sin_genero(frase: str) -> str:
    """Quita las palabras con género más comunes sobre quien pregunta (ver arriba)."""
    def estado(m: re.Match[str]) -> str:
        base, muy, mas = ESTADOS[m.group("adj").lower()]
        adv = (m.group("adv") or "").lower()
        return f"{m.group('verbo')} {muy if adv == 'muy' else mas if adv == 'más' else base}"

    frase = RE_ESTADO.sub(estado, frase)
    frase = RE_A_SALVO.sub(lambda m: f"{m.group('verbo')} {(m.group('adv') + ' ') if m.group('adv') else ''}a salvo", frase)
    frase = RE_PROTEGIDO.sub(lambda m: _como(m.group(0), f"{TENER[m.group('verbo').lower()]} protección"), frase)
    frase = RE_OBLIGADO.sub(lambda m: _como(m.group(0), f"{TENER[m.group('verbo').lower()]}{m.group('adv') or ''} que"), frase)
    frase = RE_ACOMPANADO.sub(lambda m: f"{m.group('verbo')}{m.group('adv') or ''} con" + ("" if m.group("prep") else " alguien"), frase)
    frase = RE_INFORMADO.sub(
        lambda m: _como(m.group(0), "recibirás información" if m.group("verbo").lower() == "estarás" else "recibir información"), frase
    )
    frase = RE_SER_ESCUCHADO.sub(_escuchado, frase)
    frase = RE_NO_ESTAS_SOLO.sub(lambda m: _como(m.group(0), "no estás solo ni sola"), frase)
    frase = RE_TU_SOLO.sub(lambda m: _como(m.group(0), "por tu cuenta"), frase)
    frase = RE_SOLO.sub(lambda m: f"{m.group('verbo')} sin compañía", frase)
    frase = RE_MISMO.sub(lambda m: _como(m.group(0), "por tu cuenta") if m.group("por") else m.group("pron"), frase)
    frase = RE_MADURO.sub(lambda m: _como(m.group(0), "tienes madurez suficiente"), frase)
    frase = RE_LISTO.sub(lambda m: _como(m.group(0), "cuando quieras"), frase)
    return RE_COORDINADO.sub(lambda m: f"{m.group('prev')} {m.group('y')} {NEUTRO[m.group('adj').lower()]}", frase)


# Umbral de la ley de menores: 14 años (LORPM, arts. 1 y 3). gpt-oss repetía la edad de la pregunta como si fuera el
# límite: «a los menores de 13 años no se les juzga» (y en las pruebas adversariales, «los menores de 13 años no pueden
# ser juzgados»). Solo si la frase habla de juzgar, de responsabilidad penal o de delitos.
RE_TEMA_PENAL = re.compile(r"juzg|responsab|penal|delito|ley de menores|cárcel|imputab", re.IGNORECASE)
RE_MENORES_DE_1X = re.compile(r"\b(?P<menor>menor(?:es)?)\s+de\s+(?:1[0-3]|diez|once|doce|trece)\s+años\b", re.IGNORECASE)


def umbral_14(frase: str) -> str:
    return RE_MENORES_DE_1X.sub(lambda m: f"{m.group('menor')} de 14 años", frase) if RE_TEMA_PENAL.search(frase) else frase


# A una víctima o a un testigo: «la defensa» es el abogado de la persona investigada (norma 11 del prompt)
RE_TU_DEFENSA = re.compile(r"\b(?P<art>tu)\s+(?P<que>defensa|defensor(?:a)?|abogad[oa]\s+defensor[a]?)\b", re.IGNORECASE)


def sin_tu_defensa(frase: str) -> str:
    def cambiar(m: re.Match[str]) -> str:
        nuevo = "la defensa de la persona investigada" if m.group("que").lower() == "defensa" else "tu abogado o tu abogada"
        return _como(m.group(0), nuevo)
    return RE_TU_DEFENSA.sub(cambiar, frase)


def para_texto(frase: str, victima: bool = False) -> str:
    """victima: quien pregunta es víctima o testigo (por el perfil de la app)."""
    frase = umbral_14(sin_genero(RE_ARTICULO_ENTRE_PARENTESIS.sub("", frase)))
    if victima:
        frase = sin_tu_defensa(frase)
    return re.sub(r"[*_#`>]+|^\s*[-•]\s*", "", frase)  # markdown y viñetas


# Lo que va entre corchetes en una línea: etiquetas de tono ([slow]) o una cita que se haya colado ([LORPM art. 3])
# Hasta 200 caracteres: la etiqueta de una entrada del glosario, con su base legal, pasa de 80
RE_CORCHETES = re.compile(r"\s*\[[^\[\]\n]{0,200}\]")


def sin_etiquetas(texto: str) -> str:
    """Quita lo que va entre corchetes. La voz eleven_flash_v2_5 no entiende las etiquetas y las leería en alto."""
    return re.sub(r"[ \t]{2,}", " ", RE_CORCHETES.sub("", texto)).strip()


def para_voz(frase: str, victima: bool = False) -> str:
    if not settings.tts_etiquetas:
        frase = sin_etiquetas(frase)
    return re.sub(r"\d+", lambda m: numero_a_letras(int(m.group())), para_texto(frase, victima))


def revisar(frase: str, voz: bool = True, menor_14: bool = False, victima: bool = False) -> tuple[str | None, str | None]:
    """Devuelve (frase final o None si se elimina, motivo o None). menor_14: quien pregunta tiene menos de 14 años.
    victima: es víctima o testigo (entonces «tu defensa» se corrige)."""
    prohibidos = PROHIBIDOS | PROHIBIDOS_MENOR_14 if menor_14 else PROHIBIDOS
    for motivo, (patron, sustituta) in prohibidos.items():
        if patron.search(frase):
            return sustituta, motivo
    if parece_ingles(frase):
        return NEGATIVA_EN_ESPANOL, "otro_idioma"
    return (para_voz(frase, victima) if voz else para_texto(frase, victima)), None


def verificar_stream(trozos: Iterable[str], menor_14: bool = False, victima: bool = False) -> Iterator[str]:
    trozos = (normalizar_salida(t) for t in trozos)  # los caracteres que cambia son sueltos: no se parten entre trozos
    buffer, palabras, sustituidas = "", 0, set()

    def emitir(frase: str) -> Iterator[str]:
        nonlocal palabras
        final, motivo = revisar(frase.strip(), menor_14=menor_14, victima=victima)
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


def verificar_texto(texto: str, max_palabras: int = MAX_PALABRAS_TEXTO, menor_14: bool = False, victima: bool = False) -> str:
    """La misma revisión frase a frase para el canal de texto: cifras en vez de letras y un párrafo por línea."""
    parrafos, palabras, sustituidas = [], 0, set()
    for linea in re.split(r"\s*\n\s*", normalizar_salida(texto)):
        frases = []
        for frase in FIN_FRASE.split(linea):
            if not frase.strip() or palabras >= max_palabras:
                continue
            final, motivo = revisar(frase.strip(), voz=False, menor_14=menor_14, victima=victima)
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
