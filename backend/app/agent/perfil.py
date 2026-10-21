"""Perfil del menor que llega del onboarding como dynamic variables de ElevenLabs.

ElevenLabs envuelve nuestro prompt en el suyo y sustituye las variables, así que nos llega una
línea como: "Perfil: edad=13; procedimiento=penal; rol=testigo; fase=antes."
Valores esperados:
- procedimiento: penal | familia | proteccion | ninguno
- rol: victima | testigo | investigado | escuchado
- fase: antes | durante | despues
"""

import re

RE_PERFIL = re.compile(r"Perfil:\s*(.+?)\.?\s*$", re.M)


def franja(edad: int | None) -> str | None:
    if edad is None:
        return None
    return "12-13" if edad <= 13 else "14-15" if edad <= 15 else "16-17"


def extraer_perfil(system_prompt: str) -> dict:
    m = RE_PERFIL.search(system_prompt or "")
    if not m:
        return {}
    perfil = {}
    for par in m.group(1).split(";"):
        clave, _, valor = par.partition("=")
        valor = valor.strip().lower()
        if clave.strip() and valor and "{{" not in valor:  # variable sin sustituir = sin dato
            perfil[clave.strip().lower()] = valor
    if "edad" in perfil:
        perfil["edad"] = int(perfil["edad"]) if perfil["edad"].isdigit() else None
        perfil["franja"] = franja(perfil["edad"])
    return perfil
