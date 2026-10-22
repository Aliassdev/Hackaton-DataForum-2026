"""Fuentes validadas del RAG además del texto de las leyes: el glosario de la app y las citas de docs/MARCO_LEGAL.md.

Uso, desde la raíz del repo:
    backend/.venv/Scripts/python -X utf8 ml/fuentes_validadas.py --marco ruta/a/docs/MARCO_LEGAL.md
        (re)genera content/marco_legal.json a partir del documento
    backend/.venv/Scripts/python -X utf8 ml/fuentes_validadas.py
        enseña los trozos que se añadirían al corpus (ml/ingest_leyes.py los añade solo)

- content/glosario.json (esquema 9.6): copia del glosario validado de la app. Un trozo por término, con su definición,
  su ejemplo y su fuente. Etiqueta de cita: «Glosario TuTurno · Sala Gesell (Ley 4/2015, art. 25.1; LECrim, arts. 449
  bis y 449 ter)». Es la única fuente del RAG que explica «Sala Gesell», «orden de alejamiento» o «Canal prioritario»:
  esos nombres no salen en ninguna ley.
- content/marco_legal.json: las citas literales de docs/MARCO_LEGAL.md, comprobadas contra el BOE (la CDN, con el texto
  oficial de UNICEF; la AEPD y el INCIBE, con sus webs oficiales). Una entrada por cita, con su norma y su artículo
  exactos: etiqueta «LORPM art. 28.1», «AEPD · Canal prioritario». Si la norma ya está en el corpus, la entrada lleva
  el id de su artículo (LORPM-28): es un fragmento escogido de ese artículo y la búsqueda devuelve uno por artículo.
  Solo la cita: la explicación «Para explicarlo» es orientativa (el documento pide validarla antes de publicarla) y
  las «Correcciones» son notas para el equipo.
Solo entra lo que tiene "validado": true y fuente. En el trozo van los campos de siempre más "cita" (la etiqueta que ve
y copia el LLM) y "norma" (la que enseña la app en la etiqueta de la fuente, contrato 8.1).
"""

import argparse
import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
GLOSARIO = RAIZ / "content/glosario.json"
MARCO = RAIZ / "content/marco_legal.json"
LEYES = RAIZ / "content/leyes.json"

LEY_GLOSARIO = "GLOSARIO"
NOMBRE_GLOSARIO = "Glosario TuTurno"

# Norma tal y como la escribe docs/MARCO_LEGAL.md (sin lo que va entre paréntesis) → id de la ley en el corpus
NORMAS_CORPUS = {
    "LECrim": "LECRIM", "LO 5/2000": "LORPM", "Ley 4/2015": "EVD", "LOPIVI": "LOPIVI", "LO 1/1996": "LOPJM", "LEC": "LEC",
    "LO 1/1982": "LOHIP", "LOPDGDD": "LOPDGDD", "Código Penal": "CP", "RGPD": "RGPD", "CDN": "CDN",
    "Ley 1/1996 de asistencia jurídica gratuita": "LAJG",
}
# Normas y webs que no están en el corpus de leyes: id → etiqueta corta (la de la app, widgets/fuente_chip.dart)
NORMAS_NUEVAS = {"LOPJ": ("LOPJ", "LOPJ"), "CE": ("CE", "CE"), "LO 3/1981": ("LODP", "LO 3/1981")}
ORGANISMOS = {"AEPD", "INCIBE"}  # webs oficiales: la etiqueta es la página («AEPD · Canal prioritario»)

RE_ENTRADA = re.compile(r"^### (?P<cabecera>.+)$")
RE_SECCION = re.compile(r"^## (?P<seccion>.+)$")
RE_FUENTE = re.compile(r"^Fuente: \[[^\]]*\]\((?P<url>[^)]+)\)")
RE_ARTICULO_BASE = re.compile(r"^(\d+)(?:\s+(bis|ter|quater|quinquies|sexies|septies|octies|nonies|decies)\b)?")
RE_PARENTESIS = re.compile(r"\s*\([^()]*\)")


def _leer_json(ruta: Path) -> object:
    return json.loads(ruta.read_text(encoding="utf-8"))


def _validada(e: dict) -> bool:
    return e.get("validado") is True and bool(str(e.get("fuente") or "").strip())


# --- glosario ---

def trozos_glosario(ruta: Path = GLOSARIO) -> list[dict]:
    """Un trozo por término validado del glosario de la app (esquema 9.6)."""
    if not ruta.exists():
        return []
    trozos = []
    for e in _leer_json(ruta):
        if not (isinstance(e, dict) and _validada(e) and e.get("id") and e.get("termino") and e.get("definicion")):
            continue
        termino, fuente = e["termino"].strip(), e["fuente"].strip()
        texto = f"{termino}: {e['definicion'].strip()}"
        if (ejemplo := (e.get("ejemplo") or "").strip()):
            texto += f"\nEjemplo de TuTurno: {ejemplo}"
        trozos.append({
            "id": e["id"], "articulo_id": e["id"], "ley": LEY_GLOSARIO, "ley_corta": NOMBRE_GLOSARIO, "articulo": "",
            # En la app (contrato 8.1): la etiqueta dice de dónde sale y la hoja de la fuente enseña su base legal
            "titulo": fuente, "norma": f"{NOMBRE_GLOSARIO} · {termino}",
            "cita": f"{NOMBRE_GLOSARIO} · {termino} ({fuente})",
            "contexto": "Glosario validado de TuTurno, escrito para chicos y chicas de 11 a 17 años",
            "url": "", "cabecera": f"{NOMBRE_GLOSARIO} · {termino}", "texto": texto,
        })
    return trozos


# --- docs/MARCO_LEGAL.md → content/marco_legal.json ---

def _articulo_base(articulo: str) -> str | None:
    """«449 ter, párr. 3» → «449ter»; «520.2 bis» → «520» (el «bis» es del apartado); «Página principal» → None."""
    m = RE_ARTICULO_BASE.match(articulo)
    return (m.group(1) + (m.group(2) or "")) if m else None


def _slug(texto: str) -> str:
    return re.sub(r"[^A-Za-z0-9.]+", "-", texto.replace("ñ", "n")).strip("-")


def _pagina_web(norma: str, localizador: str) -> tuple[str, str]:
    """Etiqueta e id de una cita de una web oficial («AEPD · Canal prioritario», sección «¿Eres menor de edad?»)."""
    organismo = norma.split(" · ")[0]
    if (faq := re.match(r"FAQ\s+([\d.]+)", localizador)):
        return f"{organismo} · FAQ {faq.group(1)}", f"{organismo}-FAQ-{faq.group(1)}"
    pagina = norma.split(" · ", 1)[1] if " · " in norma else ""
    ident = f"{organismo}-{_slug(pagina).lower()}" if pagina else organismo
    if (seccion := re.search(r"«([^»]+)»", localizador)) and localizador.startswith("Sección"):
        return f"{norma} ({seccion.group(1)})", ident
    return norma, ident


def entradas_marco_legal(texto_md: str, leyes: dict[str, dict], articulos: dict[str, dict] | None = None) -> list[dict]:
    """Las citas de docs/MARCO_LEGAL.md con su norma, su artículo y su id. leyes: content/leyes.json por id; articulos:
    los del corpus por id (para el título y para comprobar que el artículo existe)."""
    articulos = articulos or {}
    entradas: list[dict] = []
    seccion, actual = "", None

    def cerrar() -> None:
        if actual and actual["texto"] and actual["url"]:
            entradas.append(actual)

    for linea in texto_md.splitlines():
        if (m := RE_SECCION.match(linea)):
            cerrar()
            actual, seccion = None, m.group("seccion").split(" · ")[0].strip()
        elif (m := RE_ENTRADA.match(linea)):
            cerrar()
            actual = {"cabecera": m.group("cabecera").strip(), "caso": seccion, "texto": "", "url": ""}
        elif actual is not None and linea.startswith("> "):
            actual["texto"] = (actual["texto"] + " " + linea[2:].strip()).strip()
        elif actual is not None and (m := RE_FUENTE.match(linea)):
            actual["url"] = m.group("url")
    cerrar()

    salida, vistos = [], {}
    for e in entradas:
        norma, _, resto = e["cabecera"].partition(", art. ")
        partes = [p.strip() for p in resto.split(" · ") if p.strip() and not p.strip().startswith("⚠")]
        localizador, titulo = partes[0], (partes[1] if len(partes) > 1 else "")
        base_norma = RE_PARENTESIS.sub("", norma).strip()
        organismo = base_norma.split(" · ")[0]
        if base_norma in NORMAS_CORPUS:
            ley = NORMAS_CORPUS[base_norma]
            corta = leyes[ley]["corta"]
            base = _articulo_base(localizador)
            if base is None:
                raise ValueError(f"Artículo sin número en «{e['cabecera']}»")
            articulo_id = f"{ley}-{base}"
            articulo = RE_PARENTESIS.sub("", localizador).strip()
            cita, norma_app = f"{corta} art. {articulo}", corta
            url = leyes[ley]["url"].replace("{art}", base)
            titulo = titulo or articulos.get(articulo_id, {}).get("titulo", "")
        elif base_norma in NORMAS_NUEVAS:
            ley, corta = NORMAS_NUEVAS[base_norma]
            base = _articulo_base(localizador)
            if base is None:
                raise ValueError(f"Artículo sin número en «{e['cabecera']}»")
            articulo_id, articulo = f"{ley}-{base}", RE_PARENTESIS.sub("", localizador).strip()
            cita, norma_app, url = f"{corta} art. {articulo}", corta, e["url"]
        elif organismo in ORGANISMOS:
            ley, articulo, url = organismo, "", e["url"]
            cita, articulo_id = _pagina_web(base_norma, localizador)
            norma_app = cita.split(" (")[0]
        else:
            raise ValueError(f"Norma desconocida en docs/MARCO_LEGAL.md: «{norma}» (añádela a NORMAS_CORPUS o NORMAS_NUEVAS)")
        n = vistos[articulo_id] = vistos.get(articulo_id, 0) + 1
        salida.append({
            "id": f"ML-{articulo_id}" + (f"-{n}" if n > 1 else ""), "articulo_id": articulo_id, "ley": ley,
            "norma": norma_app, "articulo": articulo, "cita": cita, "titulo": titulo, "caso": e["caso"],
            "texto": e["texto"], "url": url, "validado": True,
            "fuente": " · ".join(p for p in e["cabecera"].split(" · ") if not p.strip().startswith("⚠")),
        })
    return salida


def generar_marco_legal(md: Path, salida: Path = MARCO) -> list[dict]:
    leyes = {l["id"]: l for l in _leer_json(LEYES)["leyes"]}
    corpus = RAIZ / "artifacts/corpus/articulos.jsonl"
    articulos = {}
    if corpus.exists():
        for linea in corpus.read_text(encoding="utf-8").splitlines():
            a = json.loads(linea)
            articulos[f"{a['ley']}-{a['articulo']}"] = a
    entradas = entradas_marco_legal(md.read_text(encoding="utf-8"), leyes, articulos)
    if articulos:
        sin_articulo = sorted({e["articulo_id"] for e in entradas if e["ley"] in NORMAS_CORPUS.values() and e["articulo_id"] not in articulos})
        if sin_articulo:
            print(f"AVISO: artículos que no están en el corpus: {sin_articulo}")
    datos = {
        "_nota": (
            "Generado con ml/fuentes_validadas.py a partir de docs/MARCO_LEGAL.md: las citas literales, comprobadas el "
            "21-22/10/2026 contra el BOE (la CDN, con el texto oficial de UNICEF; la AEPD y el INCIBE, con sus webs "
            "oficiales). validado: true se refiere a la cita literal; la explicación «Para explicarlo» es orientativa y "
            "no se incluye. articulo_id es el id del artículo en el corpus del RAG (o de la página web); cita es la "
            "etiqueta que ve el LLM; norma y articulo, lo que enseña la app. Si cambia el documento, vuelve a generarlo."
        ),
        "origen": "docs/MARCO_LEGAL.md",
        "entradas": entradas,
    }
    salida.write_text(json.dumps(datos, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    return entradas


def trozos_marco_legal(ruta: Path = MARCO, leyes_path: Path = LEYES) -> list[dict]:
    """Un trozo por cita validada de content/marco_legal.json."""
    if not ruta.exists():
        return []
    leyes = {l["id"]: l for l in _leer_json(leyes_path)["leyes"]}
    trozos = []
    for e in _leer_json(ruta)["entradas"]:
        if not (e.get("validado") is True and e.get("fuente") and e.get("texto") and e.get("cita")):
            continue
        corta = leyes[e["ley"]]["corta"] if e["ley"] in leyes else e["norma"]
        trozos.append({
            "id": e["id"], "articulo_id": e["articulo_id"], "ley": e["ley"], "ley_corta": corta, "articulo": e["articulo"],
            "titulo": e["titulo"], "norma": e["norma"], "cita": e["cita"],
            "contexto": f"Marco legal comprobado de TuTurno · {e['caso']}",
            "url": e["url"], "cabecera": e["cita"] + (f". {e['titulo']}" if e["titulo"] else ""), "texto": e["texto"],
        })
    return trozos


def trozos_validados() -> list[dict]:
    return trozos_glosario() + trozos_marco_legal()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--marco", type=Path, help="docs/MARCO_LEGAL.md: regenera content/marco_legal.json")
    args = ap.parse_args()
    if args.marco:
        entradas = generar_marco_legal(args.marco)
        print(f"content/marco_legal.json: {len(entradas)} citas de {len({e['articulo_id'] for e in entradas})} artículos o páginas")
    trozos = trozos_validados()
    for t in trozos:
        print(f"{t['id']:<28} {t['articulo_id']:<22} [{t['cita']}]")
    print(f"\n{len(trozos)} trozos validados ({sum(t['ley'] == LEY_GLOSARIO for t in trozos)} del glosario)", file=sys.stderr)


if __name__ == "__main__":
    main()
