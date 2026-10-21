"""Limpieza de datos personales antes de enviar texto a un LLM externo."""

import re

PATRONES = [
    re.compile(r"\b\d{8}[A-HJ-NP-TV-Z]\b", re.I),  # DNI
    re.compile(r"\b[XYZ]\d{7}[A-HJ-NP-TV-Z]\b", re.I),  # NIE
    re.compile(r"\b(?:\+34\s?)?[6-9]\d{2}\s?\d{3}\s?\d{3}\b"),  # teléfono
    re.compile(r"[\w.+-]+@[\w-]+\.[\w.]+"),  # correo
    re.compile(r"\b(calle|c/|avenida|avda\.?|plaza|paseo)\s+[^,.\n]{2,40}\s+\d+", re.I),  # dirección
]


def limpiar(texto: str) -> str:
    for patron in PATRONES:
        texto = patron.sub("[DATO]", texto)
    return texto
