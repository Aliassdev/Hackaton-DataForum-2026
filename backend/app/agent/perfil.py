"""Perfil del menor que llega del onboarding como dynamic variables de ElevenLabs.

ElevenLabs envuelve nuestro prompt en el suyo y sustituye las variables, así que nos llega una
línea como: "Perfil: edad=13; procedimiento=penal; rol=testigo; fase=antes."
En el modo texto (POST /api/agent/ask) las mismas variables llegan en el campo "perfil" de la petición.
Valores esperados:
- procedimiento: penal | familia | proteccion | ninguno
- rol: victima | testigo | investigado | escuchado
- fase: antes | durante | despues
La app manda "no_lo_se" en lo que no se ha respondido y "escuchado_familia" para el menor escuchado en un
proceso de familia (ARQUITECTURA.md, 8.6).
"""

import re
import unicodedata

RE_PERFIL = re.compile(r"Perfil:\s*(.+?)\.?\s*$", re.MULTILINE)

VALORES = {
    "procedimiento": {"penal", "familia", "proteccion", "ninguno"},
    "rol": {"victima", "testigo", "investigado", "escuchado"},
    "fase": {"antes", "durante", "despues"},
}
ALIAS = {"escuchado_familia": "escuchado"}
EDADES = range(8, 19)


def franja(edad: int | None) -> str | None:
    if edad is None:
        return None
    return "12-13" if edad <= 13 else "14-15" if edad <= 15 else "16-17"


def _sin_tildes(texto: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", texto) if unicodedata.category(c) != "Mn")


def normalizar_perfil(valores: dict) -> dict:
    """Solo se quedan los valores conocidos: los escribe el cliente y van al prompt del sistema.
    "no_lo_se", "", una variable sin sustituir ({{rol}}) o cualquier otro valor = sin dato."""
    perfil: dict = {}
    for clave, valor in valores.items():
        clave = str(clave).strip().lower()
        texto = _sin_tildes(str(valor if valor is not None else "").strip().lower())
        texto = ALIAS.get(texto, texto)
        if texto in VALORES.get(clave, ()):
            perfil[clave] = texto
        elif clave == "edad" and texto.isdigit() and int(texto) in EDADES:
            perfil["edad"] = int(texto)
            perfil["franja"] = franja(perfil["edad"])
    return perfil


def extraer_perfil(system_prompt: str) -> dict:
    m = RE_PERFIL.search(system_prompt or "")
    if not m:
        return {}
    pares = (par.partition("=") for par in m.group(1).split(";"))
    return normalizar_perfil({clave: valor for clave, _, valor in pares})
