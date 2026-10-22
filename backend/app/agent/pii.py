"""Limpieza de datos personales antes de enviar texto a un LLM externo.

Expresiones regulares, sin NER: DNI, NIE, teléfonos (con las cifras juntas o en grupos), correos y direcciones, y
también el nombre que alguien da al presentarse («me llamo…», «mi nombre es…», «soy» + nombre con mayúscula), el
nombre de su centro educativo («IES Cervantes», «colegio San José») y la localidad tras «vivo en». Las pruebas
adversariales del 22/10/2026 mandaban al LLM «soy Sergio Martín Ruiz del IES Cervantes de Leganés» tal cual.
"""

import re

# Palabras de unión que cierran un nombre: «me llamo Lucía y tengo 11 años» → solo «Lucía»
_CORTE_NOMBRE = r"(?!(?i:y|e|a|al|tengo|vivo|soy|de|del|estoy|voy|me|mi|mis|el|la|los|las|un|una|en|con|que|q|porque|pero|desde|hace|pues|vale|para|por|cuando|si|no|ya|hoy|ayer|es|era)\b)"
_PALABRA = r"[^\s,.;:!?¿¡()\"«»]+"
_PROPIO = r"[A-ZÁÉÍÓÚÑ][\wáéíóúñü]*"

PATRONES = [
    re.compile(r"\b\d{8}[\s-]?[A-HJ-NP-TV-Z]\b", re.IGNORECASE),  # DNI
    re.compile(r"\b[XYZ][\s-]?\d{7}[\s-]?[A-HJ-NP-TV-Z]\b", re.IGNORECASE),  # NIE
    re.compile(r"(?<![\w+])(?:\+34[\s.-]?)?[6-9](?:[\s.-]?\d){8}\b"),  # teléfono: 612345678, 612 345 678, 612 34 56 78
    re.compile(r"[\w.+-]+@[\w-]+\.[\w.]+"),  # correo
    # dirección, con la localidad si va detrás («calle Mayor 12 de Getafe»)
    re.compile(r"\b(calle|c/|avenida|avda\.?|plaza|paseo)\s+[^,.\n]{2,40}\s+\d+(?:\s*,?\s*(?:de|en)\s+[\wáéíóúñü]+)?", re.IGNORECASE),
]
# (patrón, grupo que se sustituye): se conserva lo que dice qué es («me llamo», «IES», «vivo en»)
PATRONES_CON_PREFIJO = [
    (re.compile(rf"(?i:\b(?:me llamo|mi nombre es)\b)\s+({_CORTE_NOMBRE}{_PALABRA}(?:\s+{_CORTE_NOMBRE}{_PALABRA}){{0,3}})"), 1),
    (re.compile(rf"(?i:\bsoy)\s+(?!TuTurno\b)({_PROPIO}(?:\s+{_PROPIO}){{0,3}})"), 1),  # no el saludo del agente
    (re.compile(rf"(?i:\b(?:IES|I\.E\.S\.|CEIP|CEIP\.|colegio|cole|instituto|insti|escuela)\b)\s+({_PROPIO}(?:\s+(?:(?i:de|del|la)\s+)?{_PROPIO}){{0,3}})"), 1),
    (re.compile(rf"(?i:\bvivo en)\s+(?!(?i:la calle|calle|c/|avenida|avda|plaza|paseo)\b)({_PROPIO}(?:\s+(?:(?i:de|del)\s+)?{_PROPIO}){{0,2}})"), 1),
]


def _sustituir_grupo(m: re.Match[str], grupo: int) -> str:
    inicio, fin = m.span(grupo)
    return m.string[m.start() : inicio] + "[DATO]" + m.string[fin : m.end()]


def limpiar(texto: str) -> str:
    for patron in PATRONES:
        texto = patron.sub("[DATO]", texto)
    for patron, grupo in PATRONES_CON_PREFIJO:
        texto = patron.sub(lambda m, g=grupo: _sustituir_grupo(m, g), texto)
    return texto
