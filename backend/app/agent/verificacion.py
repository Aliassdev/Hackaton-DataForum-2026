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
    # «¿Me van a creer?» (Lucía, 11 años): «el juez y el fiscal valoran si tu testimonio es fiable», sacado de la
    # evaluación de las necesidades de protección (Estatuto de la víctima, arts. 23 y 24), y «el juez decidirá si tu
    # testimonio es suficiente según tu capacidad». Se quita la frase: la norma 3 pide no decir cómo se valorará.
    "valoracion_testimonio": (
        re.compile(
            r"\b(?:valor\w*|decid\w*|evalu\w*|revis\w*|comprob\w*|analiz\w*)\b[^.;!?]{0,80}\b(?:tu|su)\s+"
            r"(?:testimonio|declaraci[óo]n|relato)\b[^.;!?]{0,40}\b(?:fiable|creíble|cre[íi]ble|suficiente|verdad|cierto)\b"
            r"|\b(?:fiabilidad|credibilidad)\s+de\s+(?:tu|su)\s+(?:testimonio|declaraci[óo]n|relato)",
            re.IGNORECASE,
        ),
        None,
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
        re.compile(
            r"falso testimonio|juramento|jurar(?:[áa]s)? (?:decir )?la verdad|promet\w* (?:que )?(?:decir|dir[áa]s) (?:siempre )?la verdad"
            r"|mentir (?:es|ser[íi]a|puede ser) (?:un )?delito|denuncias? fals[ao]s?|denuncia\w*\s+(?:resultara|resulta|fuera|es|era)\s+(?:ser\s+)?fals[ao]",
            re.IGNORECASE,
        ),
        "El juez te pedirá que cuentes lo que recuerdes, con tus palabras; si algo no lo sabes o no lo recuerdas, puedes decirlo.",
    ),
}

FRASE_MEDIDAS = PROHIBIDOS["duracion_medida"][1]

# A una víctima (revisión jurídica del 22/10/2026): «un abogado de oficio, es decir, un profesional que te representa sin
# coste» y «si la familia tiene ingresos altos, el derecho sigue aplicándose porque la ley protege a todas las víctimas de
# violencia, sin importar su situación económica». Es al revés salvo en los delitos sexuales y algunos más (Ley 1/1996,
# art. 2.h; docs/MARCO_LEGAL.md lo marca como corrección). La frase se cambia por la precisión del glosario validado
# (G-abogado-oficio), la misma que añade el orquestador.
PRECISION_GRATIS = (
    "El abogado es gratis en los casos que marca la ley: si es un delito sexual, aunque tu familia tenga dinero; "
    "en otros casos, depende de los ingresos de tu familia."
)
_GRATIS = r"grat(?:is|uit[oa]s?|uitamente)|sin\s+coste|sin\s+pagar|no\s+(?:tienes|tendrás|tiene)\s+que\s+pagar"
# «Asistencia jurídica gratuita» es el nombre del derecho («puedes pedir la asistencia jurídica gratuita en...»): no cuenta
_ABOGADO = r"abogad[oa]s?|letrad[oa]s?|representa"
PROHIBIDOS_VICTIMA = {
    "gratis_sin_condicion": (
        re.compile(
            rf"\b(?:{_ABOGADO})\b[^.;!?]*\b(?:{_GRATIS})\b|\b(?:{_GRATIS})\b[^.;!?]*\b(?:{_ABOGADO})\b"
            r"|\b(?:sin\s+importar|independientemente\s+de|con\s+independencia\s+de|aunque)\b[^.;!?]{0,60}"
            r"\b(?:ingresos|dinero|situación\s+económica|recursos)\b",
            re.IGNORECASE,
        ),
        PRECISION_GRATIS,
    ),
}

# «Cuando el responsable es menor, sus padres asumen el compromiso» (conciliación, 3 de 4 en la revisión jurídica): la ley
# de menores (art. 19.6) dice que, si la VÍCTIMA es menor, el compromiso lo asume quien la representa. Venía del ejemplo
# del glosario, que habla de Sergio, la víctima.
FRASE_CONCILIACION = (
    "Si la víctima es menor de edad, el compromiso lo asumen sus padres o quien la represente, y lo tiene que aprobar el juez "
    "de menores."
)

# A quien investigan (la app es para 11 a 17 años: es menor de edad), nada de penas de prisión (norma 13 del prompt). En
# la revisión jurídica del 22/10/2026, a un investigado de 15 años que había pasado una foto: «quien difunde esas imágenes
# puede ser castigado con prisión de tres a cinco años» (además, el artículo 197.7 dice de tres meses a un año). «No vas a
# ir a una cárcel de adultos» o «las penas de prisión son para adultos» se quedan.
PROHIBIDOS_INVESTIGADO = {
    "prision_investigado": (re.compile(r"\bprisi[óo]n\b|\bc[áa]rcel\b|\bpenas?\s+privativas?", re.IGNORECASE), FRASE_MEDIDAS),
}

# La Fiscalía no visita ni supervisa los colegios ni los institutos: la LOPIVI 55 habla de los centros de protección de
# menores. Seguía saliendo con el botón «¿Qué hace la Fiscalía de Menores si hay acoso escolar?» (2 de 2 con el perfil de
# Sergio en la revisión; antes, 3 de 3 en texto y en voz): «Visita el centro regularmente», «supervisa que los centros
# cumplan los protocolos contra el acoso escolar». La frase de sustitución sale de docs/MARCO_LEGAL.md (LOPIVI, arts. 34.1
# y 35; LO 5/2000, art. 6). Sin aplicar en un procedimiento de protección (ahí la Fiscalía sí visita su centro).
# Pruebas de voz del 22/10/2026 (3 de 3): «la Fiscalía de Menores puede acudir al instituto», «puede intervenir en tu
# instituto», «coordina con el centro educativo», «ordena que se active el protocolo de acoso escolar del centro»
_VISITA = (r"(?:(?:visit|supervis|revis|comprueb|comprob|verific|inspeccion|vigil|control|acud|interven|intervien|coordin)\w*"
           r"|pide|piden|pedir|pedirá|ir|irá|irán|va|van|vaya|vayan|viene|vienen|vendrá|vendrán|venir)")
_ESCUELA = r"(?:institutos?|insti|colegios?|cole|escuelas?|centros?\s+(?:educativos?|escolar(?:es)?)|centros?\b(?!\s+de\s+protecci))"
FRASE_ACOSO_INSTITUTO = (
    "En el instituto, el protocolo contra el acoso se pone en marcha con solo contarlo, y la persona coordinadora de "
    "bienestar es a quien puedes acudir; si se denuncia y quien acosa tiene 14 años o más, la Fiscalía de Menores dirige la "
    "investigación."
)
# Si la pregunta no va del colegio ni del acoso (a Lucía, «¿Qué hace la Fiscalía de Menores?»: «Visita los centros donde
# estés»), la frase del protocolo del instituto no pega: entonces, lo que hace la Fiscalía de Menores (glosario validado).
FRASE_FISCALIA_MENORES = (
    "La Fiscalía de Menores defiende los derechos de los menores y, si alguien de 14 a 17 años puede haber cometido un "
    "delito, dirige la investigación."
)
PROHIBIDOS_FUERA_DE_PROTECCION = {
    "fiscalia_en_el_instituto": (
        re.compile(
            rf"\b(?:fiscal\w*|ministerio\s+fiscal)\b[^.;!?]*\b{_VISITA}\b[^.;!?]*\b{_ESCUELA}"
            rf"|^\s*(?:(?:y|además|también),?\s+)?(?:visita|visitará|supervisa|supervisará|revisa|revisará|vigila|vigilará)"
            rf"\s+(?:que\s+)?(?:el|los|tu|su|sus)\s+{_ESCUELA}",
            re.IGNORECASE,
        ),
        FRASE_ACOSO_INSTITUTO,
    ),
}
PROHIBIDOS["conciliacion_al_reves"] = (
    re.compile(
        r"\b(?:responsable|quien\s+(?:caus[óo]|hizo|ha\s+(?:causado|hecho))\s+(?:el\s+)?daño|autor\w*|infractor\w*|menor\s+infractor)\b"
        r"[^.;!?]{0,30}\b(?:es|sea|fuera)\s+menor\b[^.;!?]*\bcompromiso\b"
        r"|\b(?:en\s+el\s+caso\s+de\s+(?:los\s+)?menores|si\s+eres\s+menor|como\s+eres\s+menor)\b[^.;!?]*\bcompromiso\b",
        re.IGNORECASE,
    ),
    FRASE_CONCILIACION,
)

# «¿Puedo denunciar yo sola sin mis padres?» → «al ser menor de edad la ley exige que la hagas acompañada de una persona
# que te represente» (con la LECrim 265, que habla del mandatario): es al revés, la LOPIVI (art. 50.2.e) deja denunciar
# sin una persona adulta. Frase del glosario validado (G-denuncia) y del marco legal.
FRASE_DENUNCIA_SOLA = (
    "Puedes denunciar por tu cuenta, sin que te acompañe una persona adulta; si quieres, puede estar contigo alguien de tu "
    "confianza."
)
PROHIBIDOS["denuncia_con_adulto"] = (
    re.compile(
        r"\bdenunci\w*\b[^.;!?]*\b(?:necesitas|exige|tienes\s+que|debes|hace\s+falta|obligatori\w*|tendrás\s+que)\b[^.;!?]*"
        r"\b(?:acompañad\w*|adult[oa]s?|represent\w*|mandatario|padres|tutor\w*)"
        r"|\b(?:necesitas|exige|tienes\s+que|debes|hace\s+falta|tendrás\s+que)\b[^.;!?]*\b(?:acompañad\w*|adult[oa]s?|mandatario)\b[^.;!?]*\bdenunci\w*",
        re.IGNORECASE,
    ),
    FRASE_DENUNCIA_SOLA,
)

# Lo que no cuenta aunque coincida con el patrón
EXCEPCIONES = {
    "denuncia_con_adulto": re.compile(r"\bno\s+(?:necesitas|hace\s+falta|tienes\s+que|es\s+obligatori|debes)|\bsin\s+(?:necesidad|que)", re.IGNORECASE),
    # Con su condición: «depende de los ingresos», «en los casos que marca la ley», «si es un delito sexual»
    "gratis_sin_condicion": re.compile(
        r"depende|en\s+(?:los|algunos|ciertos)\s+casos|si\s+es\s+un\s+delito|delitos?\s+sexual|libertad\s+sexual|requisitos"
        r"|si\s+(?:tu\s+familia\s+)?no\s+tiene|no\s+siempre|si\s+procede|en\s+su\s+caso|si\s+cumples|si\s+te\s+corresponde|\?",
        re.IGNORECASE,
    ),
    "prision_investigado": re.compile(
        r"\bno\b[^.;!?]{0,60}\b(?:c[áa]rcel|prisi[óo]n)|c[áa]rcel(?:es)?\s+de\s+adultos|para\s+(?:los\s+)?adultos"
        r"|en\s+(?:vez|lugar)\s+de\s+(?:la\s+)?(?:c[áa]rcel|prisi[óo]n)|distint\w*\s+(?:a|de)\s+(?:la\s+)?(?:c[áa]rcel|prisi[óo]n)",
        re.IGNORECASE,
    ),
    "fiscalia_en_el_instituto": re.compile(r"centros?\s+de\s+protecci", re.IGNORECASE),
}

# Pruebas reales del 22/10/2026 contra el Space (686a191), preguntas de los casos oficiales:
# - S05 (Sergio, 13 años, 2 de 2): «si denuncio a los de mi clase les meten en la carcel?» → «Para menores de 14 años no se
#   usa la cárcel de adultos; se aplican medidas educativas o de protección según la Ley de menores». Es al revés (LO 5/2000,
#   art. 3): con menos de 14 no se aplica la ley de menores. La frase es la de la norma 9 del prompt.
FRASE_MENOR_14 = (
    "Con menos de 14 años no se juzga a nadie por un delito, ni como adulto ni con la ley de menores: de su caso se ocupan los "
    "servicios de protección de menores."
)
_MENOS_14 = r"(?:menor(?:es)?\s+de\s+(?:14|catorce)|menos\s+de\s+(?:14|catorce))\s+años"
_LEY_MENORES = r"(?:ley\s+de\s+menores|medidas?\s+educativ\w*|juez(?:a)?\s+de\s+menores|internamiento|libertad\s+vigilada)"
PROHIBIDOS["menor_14_con_ley_de_menores"] = (
    re.compile(rf"\b{_MENOS_14}\b[^.!?]*\b{_LEY_MENORES}|\b{_LEY_MENORES}\b[^.!?]*\b{_MENOS_14}\b", re.IGNORECASE),
    FRASE_MENOR_14,
)
# - Z03 (Sergio, 2 de 2): «¿Cuánto tiempo van a castigar a los que me acosan?» → «la pena puede ser de seis a doce meses de
#   prisión o una multa de diez a quince meses [...] uno o dos años de prisión» (Código Penal, arts. 184 y 172 ter). Por voz,
#   a un investigado de 15: «internamiento de hasta seis meses, que podría prorrogarse tres meses más». La norma 9 prohíbe
#   las duraciones. En años solo de 1 a 10 («de 14 a 17 años» es una edad); en meses, cualquier cifra.
_NUM_MESES = (r"(?:\d{1,2}|un[oa]?|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce|trece|catorce|quince|dieciséis"
              r"|dieciseis|diecisiete|dieciocho|veinte|veinticuatro|treinta|treinta\s+y\s+seis)")
_PENA = r"(?:prisi[óo]n|multa|penas?|c[áa]rcel|castig\w*|condena\w*|internamiento|medidas?|inhabilitaci[óo]n)"
FRASE_EDADES = (
    "Depende de la edad de quien lo hizo: con menos de 14 años no se le juzga por un delito; de 14 a 17 se le aplica la ley "
    "de menores, con la que no se va a una cárcel de adultos; y si es adulto, decide el juez según el Código Penal. Nadie "
    "puede decirte ahora qué pasará ni cuánto durará."
)
PROHIBIDOS["pena_con_duracion"] = (
    re.compile(
        rf"\b{_PENA}\b[^.!?]{{0,100}}?\b(?:{_NUM_MESES}\s+(?:a|y|o)\s+{_NUM_MESES}|hasta\s+{_NUM_MESES}|m[áa]ximo\s+de\s+{_NUM_MESES})"
        rf"\s+meses\b"
        rf"|\b{_NUM}\s+(?:a|y|o)\s+{_NUM}\s+años\s+de\s+(?:prisi[óo]n|c[áa]rcel|multa|inhabilitaci[óo]n)"
        rf"|\b(?:prisi[óo]n|c[áa]rcel|multa)\b[^.!?]{{0,60}}?\b(?:{_NUM}(?:\s+a\s+|\s+y\s+|\s+o\s+){_NUM}|hasta\s+{_NUM}"
        rf"|m[áa]ximo\s+de\s+{_NUM})\s+años",
        re.IGNORECASE,
    ),
    FRASE_EDADES,
)
# - L04 (Lucía, 11): «Nadie más verá la grabación». La grabación se pone en el juicio (LECrim, art. 703 bis) y en la
#   entrevista está el abogado de la persona investigada (art. 449 bis).
PROHIBIDOS["grabacion_secreta"] = (
    re.compile(r"\bnadie\s+(?:m[áa]s\s+)?(?:ver[áa]|va\s+a\s+ver|podr[áa]\s+ver|tendr[áa]\s+acceso\s+a)\s+(?:la|tu|esa)\s+grabaci[óo]n",
               re.IGNORECASE),
    "La grabación se guarda y solo se usa en el proceso, por ejemplo, en el juicio.",
)

# - A04 (Sara, 15, 2 de 2): «si yo le mandé la foto es culpa mia?» → «Si enviaste la foto a otra persona sin su permiso, la
#   responsabilidad recae en quien la difunde, es decir, en quien la envía». A una víctima, la frase del marco legal (Código
#   Penal, art. 197.7, «Para explicarlo») y la norma 14.
FRASE_NO_ES_CULPA = (
    "No es culpa tuya: aunque tú mandaras la foto, nadie puede pasarla a otros sin tu permiso, y quien la difunde puede cometer "
    "un delito."
)
PROHIBIDOS_VICTIMA["culpa_a_quien_envia"] = (
    re.compile(
        r"\b(?:culpa|responsabilidad|responsable|culpable)\b[^.!?]*\b(?:quien|la\s+persona\s+que|el\s+que|la\s+que)\s+"
        r"(?:la\s+|las\s+|lo\s+|los\s+)?(?:env[íi]\w*|mand\w*)\b"
        r"|\bsi\s+(?:enviaste|mandaste|pasaste|compartiste|reenviaste)\b[^.!?]*\bsin\s+(?:su|el)\s+permiso",
        re.IGNORECASE,
    ),
    FRASE_NO_ES_CULPA,
)
# Solo si la frase habla de fotos o vídeos: «la responsabilidad es de quien manda los mensajes» (acoso) no es lo de Sara
EXCEPCIONES["culpa_a_quien_envia"] = re.compile(r"^(?![\s\S]*\b(?:fotos?|imagen|im[áa]genes|v[íi]deos?)\b)", re.IGNORECASE)
EXCEPCIONES["menor_14_con_ley_de_menores"] = re.compile(
    r"\bno\s+se\s+(?:le\s+|les\s+)?(?:aplica|juzga|exige|puede\s+juzgar)|\bni\s+(?:con\s+)?la\s+ley\s+de\s+menores"
    r"|\bno\s+(?:se\s+)?(?:le\s+|les\s+)?(?:pueden?\s+)?juzgar|servicios\s+de\s+protecci|normas\s+(?:sobre|de)\s+protecci",
    re.IGNORECASE,
)


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
# art. 197)»): se quitan, y en la voz no se leen. En la voz los escribe con letras («(Código Penal artículo quinientos
# setenta y ocho)», revisión jurídica del 22/10/2026): también se quitan. Dentro de la frase, «el artículo 197 del Código
# Penal» pasa a «el Código Penal» y «en el artículo cincuenta y dos de la Ley de...», a «en la Ley de...».
_NUMERO_LETRAS = (
    r"(?:(?:cero|uno|una|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce|trece|catorce|quince|dieci\w+|veinte|"
    r"veinti\w+|treinta|cuarenta|cincuenta|sesenta|setenta|ochenta|noventa|cien|ciento|doscientos|trescientos|"
    r"cuatrocientos|quinientos|seiscientos|setecientos|ochocientos|novecientos|mil)(?:\s+y\s+|\s+(?=[a-z]))?)+"
)
RE_ARTICULO_ENTRE_PARENTESIS = re.compile(
    rf"\s*\([^()\n]*\b(?:art[íi]culos?|arts?\.)\s*(?:\d|{_NUMERO_LETRAS}\b)[^()\n]*\)", re.IGNORECASE
)
RE_ARTICULO_EN_FRASE = re.compile(
    rf"\b(?P<pre>el|del|al)\s+art[íi]culo\s+(?:\d+(?:\.\d+)?(?:\s?(?:bis|ter|quater|quinquies))?|{_NUMERO_LETRAS})"
    rf"(?:\s*,?\s*(?:apartado|párrafo|letra)\s+\w+)?\s+(?P<de>de\s+la|del)\s+",
    re.IGNORECASE,
)
# «el artículo N de la Ley» → «la Ley»; «del artículo N del Código Penal» → «del Código Penal»
_SIN_ARTICULO = {("el", "de la"): "la ", ("el", "del"): "el ", ("del", "de la"): "de la ", ("del", "del"): "del ",
                 ("al", "de la"): "a la ", ("al", "del"): "al "}


RE_LEY_ARTICULO = re.compile(
    rf"\b(?P<ley>Código Penal|LECrim|LORPM|LOPIVI|LOPDGDD|RGPD|Constitución(?: Española)?|Estatuto de la [Vv]íctima|"
    rf"Ley de Enjuiciamiento (?:Criminal|Civil)|[Ll]ey de [Mm]enores)\s*,?\s*(?:art\.|artículo)\s*"
    rf"(?:\d+(?:\.\d+)?(?:\s?(?:bis|ter|quater|quinquies))?|{_NUMERO_LETRAS})\b",
)
# Con un espacio delante: «tú mismo(a)» o «abogado(a)» no son paréntesis vacíos
RE_PARENTESIS_VACIO = re.compile(r"\s+\(\s*(?:[a-z]{1,2}\)?)?\s*\)")


def sin_numero_de_articulo(frase: str) -> str:
    frase = RE_PARENTESIS_VACIO.sub("", RE_ARTICULO_ENTRE_PARENTESIS.sub("", frase))
    frase = RE_LEY_ARTICULO.sub(lambda m: m.group("ley"), frase)

    def cambiar(m: re.Match[str]) -> str:
        nuevo = _SIN_ARTICULO[(m.group("pre").lower(), re.sub(r"\s+", " ", m.group("de").lower()))]
        return nuevo[:1].upper() + nuevo[1:] if m.group("pre")[:1].isupper() else nuevo

    return RE_ARTICULO_EN_FRASE.sub(cambiar, frase)


# --- Sin género sobre la persona (filtro ligero) ---
# Solo formas que hablan de quien pregunta: detrás de un verbo en segunda persona o en infinitivo («si estás asustado»,
# «puedes ir acompañado»). «La persona investigada», «el menor está obligado» o «solo una vez» no se tocan, y tampoco
# las formas dobles («solo ni sola», «nervioso o nerviosa»).
_ESTAR = r"estar|estás|estarás|estés|estarías|estabas|estando|quedarte|te\s+quedes|te\s+quedas|te\s+quedarás"
_SENTIR = r"sentirte|te\s+sientes|te\s+sientas|te\s+sentirás|te\s+sentirías|sintiéndote|sentir"
_MOVER = (r"ir|vas|irás|vayas|venir|vienes|vendrás|vengas|declarar|declaras|declararás|declares|entrar|entras|entrarás|"
          r"entres|acudir|acudes|acudirás|acudas|presentarte|hablar|hablarás|hables|hacerlo|hacerla|hagas|denunciar|denunciarlo")
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
    r"(?!\s+(?:o|u|y)\s+acompañad)(?P<medio>\s+(?:en\s+todo\s+momento|siempre|también))?"
    r"(?P<prep>\s+(?:de|por)\b(?:(?P<coord>\s+[^,.;:!?]{1,60}?\s+(?:o|y|u))\s+(?:de|por)\b)?)?",
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


# Revisión jurídica del 22/10/2026 (respuestas reales del Space):
# - «acompañad@», «tod@s»: la arroba pasa a «o/a» y la cogen las reglas de arriba.
# - «estarás solo/a con profesionales»: con la barra, «solo» es el adjetivo → «estarás con profesionales».
# - «¿Te sientes preparado/a para hablar allí?» → «¿Te sientes con fuerzas...?».
# - «para estar seguro y feliz», «para que tú estés seguro/a en el colegio» → «a salvo» (no «para estar seguro de que»).
# - «si te pones nerviosa» → «si te entran nervios».
# - «estés acompañada en todo momento por una persona» → «estés en todo momento con una persona» (antes quedaba «estés con
#   alguien en todo momento por una persona»), e «ir acompañado de tu abogado o de la persona...» → «... o con la persona».
RE_ARROBA = re.compile(r"\b([a-záéíóúñ]{2,})@(s?)(?!\w)", re.IGNORECASE)
RE_SOLO_BARRA = re.compile(
    rf"\b(?P<verbo>{_ESTAR}|{_MOVER})\s+sol[oa](?:\s*/\s*[oa]s?\b|\([oa]s?\))(?P<con>\s+con\b)?", re.IGNORECASE
)
RE_CON_FUERZAS = re.compile(rf"\b(?P<verbo>{_SENTIR})(?:\s+(?P<adv>muy|más))?\s+(?P<adj>preparad|list)[oa]s?\b{_BARRA}{_DOBLE}", re.IGNORECASE)
# «sin sentirte presionado» → «sin sentir presión»: el verbo cambia
PRESION = {"sentirte": "sentir", "te sientes": "sientes", "te sientas": "sientas", "te sentirás": "sentirás"}
RE_PRESIONADO = re.compile(r"\b(?P<verbo>sentirte|te\s+sientes|te\s+sientas|te\s+sentirás)\s+presionad[oa]s?\b" + _BARRA, re.IGNORECASE)
RE_ESTAR_SEGURO = re.compile(
    rf"\b(?P<lead>para\s+que\s+(?:tú\s+)?|para\s+)(?P<verbo>estar|estés)\s+(?P<adj>segur)[oa]s?\b{_BARRA}{_DOBLE}(?!\s+de\b)",
    re.IGNORECASE,
)
PONERSE = {"te pones": "te entran", "te pongas": "te entren", "te pondrás": "te entrarán", "te pusiste": "te entraron",
           "ponerte": "tener"}
RE_NERVIOSO = re.compile(
    rf"\b(?P<verbo>te\s+pones|te\s+pongas|te\s+pondrás|te\s+pusiste|ponerte)\s+(?P<muy>muy\s+)?(?P<adj>nervios)[oa]s?\b{_BARRA}{_DOBLE}",
    re.IGNORECASE,
)


def _presion(m: re.Match[str]) -> str:
    verbo = re.sub(r"\s+", " ", m.group("verbo").lower())
    return _como(m.group(0), f"{PRESION[verbo]} presión")


def _nervios(m: re.Match[str]) -> str:
    verbo = PONERSE[re.sub(r"\s+", " ", m.group("verbo").lower())]
    return _como(m.group(0), f"{verbo} {'muchos ' if m.group('muy') else ''}nervios")


def sin_genero(frase: str) -> str:
    """Quita las palabras con género más comunes sobre quien pregunta (ver arriba)."""
    def estado(m: re.Match[str]) -> str:
        base, muy, mas = ESTADOS[m.group("adj").lower()]
        adv = (m.group("adv") or "").lower()
        return f"{m.group('verbo')} {muy if adv == 'muy' else mas if adv == 'más' else base}"

    frase = RE_ARROBA.sub(r"\1o/a\2", frase)
    frase = RE_SOLO_BARRA.sub(lambda m: f"{m.group('verbo')} " + ("con" if m.group("con") else "sin compañía"), frase)
    frase = RE_CON_FUERZAS.sub(lambda m: f"{m.group('verbo')} {(m.group('adv') + ' ') if m.group('adv') else ''}con fuerzas", frase)
    frase = RE_ESTAR_SEGURO.sub(lambda m: f"{m.group('lead')}{m.group('verbo')} a salvo", frase)
    frase = RE_NERVIOSO.sub(_nervios, frase)
    frase = RE_PRESIONADO.sub(_presion, frase)
    frase = RE_ESTADO.sub(estado, frase)
    frase = RE_A_SALVO.sub(lambda m: f"{m.group('verbo')} {(m.group('adv') + ' ') if m.group('adv') else ''}a salvo", frase)
    frase = RE_PROTEGIDO.sub(lambda m: _como(m.group(0), f"{TENER[m.group('verbo').lower()]} protección"), frase)
    frase = RE_OBLIGADO.sub(lambda m: _como(m.group(0), f"{TENER[m.group('verbo').lower()]}{m.group('adv') or ''} que"), frase)
    frase = RE_ACOMPANADO.sub(
        lambda m: f"{m.group('verbo')}{m.group('adv') or ''}{m.group('medio') or ''} con"
        + (f"{m.group('coord')} con" if m.group("coord") else "") + ("" if m.group("prep") else " alguien"),
        frase,
    )
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


# «Si tienes 13 años, la ley dice que no se te juzga como a un adulto» (botón «Si tengo 13 años y hago algo malo, ¿me
# pueden juzgar?», 2 de 3 en la revisión jurídica): con menos de 14 no se juzga a nadie por un delito, tampoco con la ley
# de menores. Solo si la misma frase dice una edad de menos de 14.
RE_EDAD_MENOR_14 = re.compile(r"\b(?:1[0-3]|diez|once|doce|trece)\s+años\b|\bmenor(?:es)?\s+de\s+(?:14|catorce)\s+años\b", re.IGNORECASE)
RE_COMO_ADULTO = re.compile(r"\b(?P<juzga>juzg\w+)\s+como\s+(?:a\s+)?(?:un\s+|una\s+)?(?:persona\s+)?adult[oa]s?\b", re.IGNORECASE)


def umbral_14(frase: str) -> str:
    if not RE_TEMA_PENAL.search(frase):
        return frase
    frase = RE_MENORES_DE_1X.sub(lambda m: f"{m.group('menor')} de 14 años", frase)
    if RE_EDAD_MENOR_14.search(frase):
        frase = RE_COMO_ADULTO.sub(lambda m: f"{m.group('juzga')} por un delito", frase)
    return frase


# A una víctima o a un testigo: «la defensa» es el abogado de la persona investigada (norma 11 del prompt)
RE_TU_DEFENSA = re.compile(r"\b(?P<art>tu)\s+(?P<que>defensa|defensor(?:a)?|abogad[oa]\s+defensor[a]?)\b", re.IGNORECASE)


def sin_tu_defensa(frase: str) -> str:
    def cambiar(m: re.Match[str]) -> str:
        nuevo = "la defensa de la persona investigada" if m.group("que").lower() == "defensa" else "tu abogado o tu abogada"
        return _como(m.group(0), nuevo)
    return RE_TU_DEFENSA.sub(cambiar, frase)


# Revisión jurídica del 22/10/2026 (respuestas reales del Space). Según el papel de quien pregunta:
# - A una víctima: «un abogado de oficio, es decir, gratuito» → «un abogado de oficio»: de oficio no quiere decir gratis
#   (la precisión de cuándo es gratis la añade el orquestador, como antes).
# - A quien investigan o a quien escuchan en un proceso de familia, sin la Oficina de Asistencia a las Víctimas, que es
#   para las víctimas y los testigos de un delito («pregunta a tu abogado o a la Oficina de Asistencia a las Víctimas»).
RE_DE_OFICIO_GRATIS = re.compile(r"\bde oficio,?\s*(?:es decir|o sea|esto es|que es),?\s*(?:gratis|gratuit[oa]s?)\b", re.IGNORECASE)
_OAV = r"la\s+Oficina\s+de\s+(?:Asistencia|Atención)\s+a\s+(?:las?\s+)?Víctimas?(?:\s+del\s+Delito)?"
RE_OAV_LISTA = re.compile(rf",\s*(?:a\s+|con\s+|en\s+)?{_OAV}\s+(?P<y>o|y|u)\s+", re.IGNORECASE)
RE_OAV_DETRAS = re.compile(rf"\s*,?\s+(?:o|y|u)\s+(?:a\s+|con\s+|en\s+)?{_OAV}", re.IGNORECASE)
RE_OAV_DELANTE = re.compile(rf"(?P<prep>\b(?:a|con|en)\s+){_OAV}\s*,?\s+(?:o|y|u)\s+(?:a\s+|con\s+|en\s+)?", re.IGNORECASE)
RE_OAV_SINGULAR = re.compile(r"\bOficina de Atención a la Víctima\b")
SIN_OAV = ("investigado", "escuchado")


def para_texto(frase: str, victima: bool = False, rol: str | None = None) -> str:
    """victima: quien pregunta es víctima o testigo (por el perfil de la app). rol: su papel, si se sabe."""
    frase = umbral_14(sin_genero(sin_numero_de_articulo(frase)))
    frase = RE_OAV_SINGULAR.sub("Oficina de Asistencia a las Víctimas", frase)
    if victima:
        frase = RE_DE_OFICIO_GRATIS.sub("de oficio", sin_tu_defensa(frase))
    if rol in SIN_OAV:
        frase = RE_OAV_LISTA.sub(lambda m: f" {m.group('y')} ", frase)
        frase = RE_OAV_DELANTE.sub(lambda m: m.group("prep"), RE_OAV_DETRAS.sub("", frase))
    return re.sub(r"[*_#`>]+|^\s*[-•]\s*", "", frase)  # markdown y viñetas


# Lo que va entre corchetes en una línea: etiquetas de tono ([slow]) o una cita que se haya colado ([LORPM art. 3])
# Hasta 200 caracteres: la etiqueta de una entrada del glosario, con su base legal, pasa de 80
RE_CORCHETES = re.compile(r"\s*\[[^\[\]\n]{0,200}\]")


def sin_etiquetas(texto: str) -> str:
    """Quita lo que va entre corchetes. La voz eleven_flash_v2_5 no entiende las etiquetas y las leería en alto."""
    return re.sub(r"[ \t]{2,}", " ", RE_CORCHETES.sub("", texto)).strip()


# Teléfonos cortos como los dicen las plantillas. Antes, «\d+» pasaba «017» a «diecisiete» (pruebas de voz del 22/10/2026,
# tras una crisis: «puedes llamar al diecisiete») y «112» a «ciento doce». Con un cero delante, «cero» y el resto. Los
# largos (900 20 20 10, 116 111) ya se leían bien y no cambian.
TELEFONOS_VOZ = (
    (re.compile(r"\b112\b"), "uno, uno, dos"),
    (re.compile(r"\b0(\d{2})\b"), lambda m: "cero, " + numero_a_letras(int(m.group(1)))),
    (re.compile(r"\b(llamar|llama|llames|marcar|marca|marques) al diecisiete\b", re.IGNORECASE), r"\1 al cero, diecisiete"),
    (re.compile(r"\b(llamar|llama|llames|marcar|marca|marques) al ciento doce\b", re.IGNORECASE), r"\1 al uno, uno, dos"),
)


def telefonos_para_voz(frase: str) -> str:
    for patron, letras in TELEFONOS_VOZ:
        frase = patron.sub(letras, frase)
    return frase


def para_voz(frase: str, victima: bool = False, rol: str | None = None) -> str:
    if not settings.tts_etiquetas:
        frase = sin_etiquetas(frase)
    frase = telefonos_para_voz(para_texto(frase, victima, rol))
    return re.sub(r"\d+", lambda m: numero_a_letras(int(m.group())), frase)


def prohibidos_para(menor_14: bool = False, rol: str | None = None, proteccion: bool = False, escolar: bool = True) -> dict:
    """Los patrones prohibidos que tocan según el perfil. escolar: la pregunta habla del colegio o del acoso."""
    prohibidos = dict(PROHIBIDOS)
    if menor_14:
        prohibidos |= PROHIBIDOS_MENOR_14
    if rol == "investigado":
        prohibidos |= PROHIBIDOS_INVESTIGADO
        patron_pena, _ = prohibidos.pop("pena_con_duracion")  # detrás de prision_investigado, con la frase de siempre
        prohibidos["pena_con_duracion"] = (patron_pena, FRASE_MEDIDAS)
    if rol == "victima":
        prohibidos |= PROHIBIDOS_VICTIMA
    if not proteccion:
        patron, _ = PROHIBIDOS_FUERA_DE_PROTECCION["fiscalia_en_el_instituto"]
        prohibidos["fiscalia_en_el_instituto"] = (patron, FRASE_ACOSO_INSTITUTO if escolar else FRASE_FISCALIA_MENORES)
    return prohibidos


def revisar(
    frase: str, voz: bool = True, menor_14: bool = False, victima: bool = False, rol: str | None = None, proteccion: bool = False,
    escolar: bool = True,
) -> tuple[str | None, str | None]:
    """Devuelve (frase final o None si se elimina, motivo o None). menor_14: quien pregunta tiene menos de 14 años.
    victima: es víctima o testigo (entonces «tu defensa» se corrige). rol: su papel (a quien investigan, nada de penas de
    prisión). proteccion: está en un procedimiento de protección (ahí sí puede hablarse de las visitas de la Fiscalía a
    su centro)."""
    for motivo, (patron, sustituta) in prohibidos_para(menor_14, rol, proteccion, escolar).items():
        if patron.search(frase) and not (motivo in EXCEPCIONES and EXCEPCIONES[motivo].search(frase)):
            if voz and sustituta:  # «14 años» → «catorce años» (FRASE_ACOSO_INSTITUTO)
                sustituta = re.sub(r"\d+", lambda m: numero_a_letras(int(m.group())), sustituta)
            return sustituta, motivo
    if parece_ingles(frase):
        return NEGATIVA_EN_ESPANOL, "otro_idioma"
    return (para_voz(frase, victima, rol) if voz else para_texto(frase, victima, rol)), None


def verificar_stream(
    trozos: Iterable[str], menor_14: bool = False, victima: bool = False, rol: str | None = None, proteccion: bool = False,
    escolar: bool = True,
) -> Iterator[str]:
    trozos = (normalizar_salida(t) for t in trozos)  # los caracteres que cambia son sueltos: no se parten entre trozos
    buffer, palabras, sustituidas = "", 0, set()

    def emitir(frase: str) -> Iterator[str]:
        nonlocal palabras
        final, motivo = revisar(frase.strip(), menor_14=menor_14, victima=victima, rol=rol, proteccion=proteccion, escolar=escolar)
        if motivo:
            log.warning("Verificación: frase eliminada (%s)", motivo)
            # Cada frase de sustitución sale una sola vez (dos motivos pueden compartirla)
            if final is None or final in sustituidas:
                return
            sustituidas.add(final)
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


def verificar_texto(
    texto: str, max_palabras: int = MAX_PALABRAS_TEXTO, menor_14: bool = False, victima: bool = False, rol: str | None = None,
    proteccion: bool = False, escolar: bool = True,
) -> str:
    """La misma revisión frase a frase para el canal de texto: cifras en vez de letras y un párrafo por línea."""
    parrafos, palabras, sustituidas = [], 0, set()
    for linea in re.split(r"\s*\n\s*", normalizar_salida(texto)):
        frases = []
        for frase in FIN_FRASE.split(linea):
            if not frase.strip() or palabras >= max_palabras:
                continue
            final, motivo = revisar(
                frase.strip(), voz=False, menor_14=menor_14, victima=victima, rol=rol, proteccion=proteccion, escolar=escolar
            )
            if motivo:
                log.warning("Verificación: frase eliminada (%s)", motivo)
                if final is None or final in sustituidas:
                    continue
                sustituidas.add(final)
            if final and final.strip():
                palabras += len(final.split())
                frases.append(final.strip())
        if frases:
            parrafos.append(" ".join(frases))
    return "\n\n".join(parrafos)
