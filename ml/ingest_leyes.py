"""P1 · Ingesta de leyes: PDF → artículos limpios con jerarquía y trozos listos para indexar.

Uso, desde la raíz del repo:
    backend/.venv/Scripts/python -X utf8 ml/ingest_leyes.py

Entrada: fuentes/leyes/*.pdf (registro en content/leyes.json).
Salida:  artifacts/corpus/articulos.jsonl (un artículo por línea) y trozos.jsonl (unidad de búsqueda).

Decisiones:
- La unidad es el ARTÍCULO: es la unidad natural del texto legal y permite citar con precisión.
- Artículos largos se parten por apartados en trozos de <= MAX_PALABRAS; cada trozo lleva
  delante la cabecera (ley, artículo, título del artículo, capítulo) para no perder contexto.
- Se ignoran preámbulo, índice, disposiciones (en la LOPIVI son en su mayoría modificaciones de
  otras leyes, que ya están consolidadas en sus textos) y las notas de modificación del BOE.
"""

import json
import re
from collections import Counter
from pathlib import Path

import pymupdf

RAIZ = Path(__file__).resolve().parent.parent
FUENTES = RAIZ / "fuentes/leyes"
SALIDA = RAIZ / "artifacts/corpus"
MAX_PALABRAS = 260

SUFIJOS = r"(?: (?:bis|ter|quater|quinquies|sexies|septies|octies|nonies|decies))?"
ORDINALES = {
    "primero": "1", "segundo": "2", "tercero": "3", "cuarto": "4", "quinto": "5",
    "sexto": "6", "séptimo": "7", "octavo": "8", "noveno": "9", "décimo": "10",
}  # la LO 1/1982 numera "Artículo primero", "Artículo segundo"...
# Sin re.I a propósito: "artículo 10 del Reglamento..." al inicio de una línea es una cita, no un encabezado
RE_ARTICULO = re.compile(rf"^Artículo (\d+{SUFIJOS}|único|{'|'.join(ORDINALES)})\.?\s*(.*)$")
RE_RANGO = re.compile(r"^Artículos (\d+) a (\d+)\.")  # "Artículos 907 a 909. (Derogados)"
RE_ESTRUCTURA = re.compile(
    r"^(T[ÍI]TULO|CAP[ÍI]TULO|Secci[óo]n|SECCI[ÓO]N|LIBRO|PARTE)\s+"
    r"([IVXLCDM]+|\d+\.?ª?|PRELIMINAR|Preliminar|[ÚU]NIC[OA]|[ÚU]nic[oa]|PRIMER[OA]?|SEGUND[OA]|TERCER[OA]?|CUART[OA]|QUINT[OA])\b"
)
# Mayúscula obligatoria: "disposición final" en minúscula es una cita dentro del texto
RE_FIN = re.compile(r"^(Disposici[óo]n (adicional|transitoria|derogatoria|final)|DISPOSICI[ÓO]N(ES)? (ADICIONAL|TRANSITORIA|DEROGATORIA|FINAL)|ANEXO\b)")
RE_RUIDO = re.compile(
    r"^(BOLET[ÍI]N OFICIAL DEL ESTADO|LEGISLACI[ÓO]N CONSOLIDADA|P[áa]gina \d+|Núm\. \d+|Sec\. I\.|cve: |Verificable en|D\.L\.: |"
    r"(Lunes|Martes|Miércoles|Jueves|Viernes|Sábado|Domingo) \d+ de |L \d+/\d+|\d+\.\d+\.\d{4}$|Diario Oficial de la Unión Europea|ES$)"
)
RE_NOTA = re.compile(
    r"(Ref\. BOE-|^(Se (modifica|añade|suprime|deroga|da nueva redacción|declara)|Redactad[oa]|Téngase en cuenta|Véase|"
    r"Esta (modificación|redacción)|Texto (añadido|suprimido)|Declarado|Anulado|Este artículo|Afectado)\b)",
    re.I,
)
RE_INDICE = re.compile(r"(\. ){4,}|\.{6,}")


def lineas_limpias(pdf: Path) -> list[str]:
    salida = []
    for pagina in pymupdf.open(pdf):
        for linea in pagina.get_text().splitlines():
            linea = linea.replace("\t", " ").strip()
            if not linea or RE_RUIDO.match(linea) or RE_INDICE.search(linea) or RE_NOTA.search(linea):
                continue
            salida.append(linea)
    return salida


def unir_parrafo(lineas: list[str]) -> str:
    """Une líneas cortadas por el PDF respetando los apartados ('1.', 'a)', '1.ª')."""
    texto = ""
    for l in lineas:
        nuevo_apartado = re.match(r"^(\d+\.(ª)? |[a-zñ]\) |\d+\) |\d+\.ª )", l)
        if texto and (nuevo_apartado or texto.endswith((".", ":", ";"))) and not texto.endswith("-"):
            texto += "\n" + l
        elif texto.endswith("-"):
            texto = texto[:-1] + l
        else:
            texto += (" " if texto else "") + l
    return re.sub(r"[  ]+", " ", texto).strip()


def articulos_de(ley: dict) -> list[dict]:
    lineas = lineas_limpias(FUENTES / ley["pdf"])

    def es_encabezado(l):
        return RE_ARTICULO.match(l) or RE_FIN.match(l) or RE_ESTRUCTURA.match(l)

    # Empieza en el primer "Artículo 1" seguido de texto (en un índice va seguido de otro encabezado)
    inicio = next(
        i for i, l in enumerate(lineas[:-1])
        if (m := RE_ARTICULO.match(l)) and m.group(1) in ("1", "primero") and not es_encabezado(lineas[i + 1])
    )
    articulos, actual, estructura = [], None, {}
    titulo_pendiente = False
    ultimo_num = 0

    def cerrar():
        if actual and actual["lineas"]:
            texto = unir_parrafo(actual.pop("lineas"))
            if len(texto.split()) >= 5:
                articulos.append({**actual, "texto": texto})

    for l in lineas[inicio:]:
        if RE_FIN.match(l):
            # Las disposiciones van al final; lo que sigue son citas de artículos de otras leyes
            break
        if (rango := RE_RANGO.match(l)) and ultimo_num <= int(rango.group(1)) <= ultimo_num + 30:
            cerrar()
            actual, ultimo_num = None, int(rango.group(2))
            continue
        m = RE_ARTICULO.match(l)
        if m:
            num = ORDINALES.get(m.group(1).replace(" ", ""), m.group(1).replace(" ", ""))
            n = int(re.match(r"\d+", num).group()) if num[0].isdigit() else ultimo_num + 1
            if not (ultimo_num <= n <= ultimo_num + 30):
                m = None  # número fuera de secuencia: es texto que empieza por "Artículo N"
        if m:
            cerrar()
            ultimo_num = n
            titulo = m.group(2).strip().rstrip(".")
            actual = {"ley": ley["id"], "articulo": num, "titulo": titulo, "estructura": dict(estructura), "lineas": []}
            titulo_pendiente = not titulo  # RGPD y CDN ponen el título en la línea siguiente (o no lo tienen)
            continue
        if RE_ESTRUCTURA.match(l):
            nivel = l.split()[0].upper().replace("Í", "I").replace("Ó", "O")
            estructura[nivel] = l
            # al cambiar de título se reinician los niveles inferiores
            orden = ["PARTE", "LIBRO", "TITULO", "CAPITULO", "SECCION"]
            for inferior in orden[orden.index(nivel) + 1 :] if nivel in orden else []:
                estructura.pop(inferior, None)
            continue
        if actual is None:
            continue
        if titulo_pendiente and ley["id"] == "RGPD":
            # El título puede ocupar varias líneas y la última llevar pegado el "1." del primer apartado
            if m_fin := re.match(r"^(.*?)\s+(\d+\.)$", l):
                actual["titulo"] = (actual["titulo"] + " " + m_fin.group(1)).strip()
                actual["lineas"].append(m_fin.group(2))
                titulo_pendiente = False
                continue
            if len(l) < 120 and not l.endswith("."):
                actual["titulo"] = (actual["titulo"] + " " + l).strip()
                continue
        titulo_pendiente = False
        if actual["lineas"] and re.fullmatch(r"\d+\.", actual["lineas"][-1]):
            actual["lineas"][-1] += " " + l  # "1." suelto + texto del apartado
            continue
        actual["lineas"].append(l)
    cerrar()

    # Si un número aparece repetido (p. ej. citas que parecen encabezados), nos quedamos con el más largo
    mejores: dict[str, dict] = {}
    for a in articulos:
        if a["articulo"] not in mejores or len(a["texto"]) > len(mejores[a["articulo"]]["texto"]):
            mejores[a["articulo"]] = a
    return [a for a in articulos if mejores[a["articulo"]] is a]


def trocear(art: dict, ley: dict) -> list[dict]:
    cabecera = f"{ley['corta']} · Artículo {art['articulo']}" + (f". {art['titulo']}" if art["titulo"] else "")
    contexto = " · ".join(v for k, v in art["estructura"].items() if k in ("TITULO", "CAPITULO"))
    apartados = art["texto"].split("\n")
    trozos, actual = [], []
    for ap in apartados:
        if actual and len(" ".join(actual + [ap]).split()) > MAX_PALABRAS:
            trozos.append(actual)
            actual = []
        actual.append(ap)
    if actual:
        trozos.append(actual)

    base = f"{ley['id']}-{art['articulo']}"
    return [
        {
            "id": base if len(trozos) == 1 else f"{base}#{i}",
            "articulo_id": base,
            "ley": ley["id"],
            "ley_corta": ley["corta"],
            "articulo": art["articulo"],
            "titulo": art["titulo"],
            "contexto": contexto,
            "url": ley["url"].replace("{art}", art["articulo"]),
            "cabecera": cabecera,
            "texto": "\n".join(t),
        }
        for i, t in enumerate(trozos, 1)
    ]


def main():
    leyes = json.loads((RAIZ / "content/leyes.json").read_text(encoding="utf-8"))["leyes"]
    SALIDA.mkdir(parents=True, exist_ok=True)
    todos_art, todos_trozos = [], []
    for ley in leyes:
        arts = articulos_de(ley)
        trozos = [t for a in arts for t in trocear(a, ley)]
        todos_art += arts
        todos_trozos += trozos
        print(f"{ley['id']:>8}: {len(arts):4d} artículos · {len(trozos):4d} trozos")

    with open(SALIDA / "articulos.jsonl", "w", encoding="utf-8") as f:
        for a in todos_art:
            f.write(json.dumps(a, ensure_ascii=False) + "\n")
    with open(SALIDA / "trozos.jsonl", "w", encoding="utf-8") as f:
        for t in todos_trozos:
            f.write(json.dumps(t, ensure_ascii=False) + "\n")

    palabras = [len(t["texto"].split()) for t in todos_trozos]
    print(f"\nTotal: {len(todos_art)} artículos · {len(todos_trozos)} trozos · "
          f"palabras por trozo: mediana {sorted(palabras)[len(palabras)//2]}, máx {max(palabras)}")
    dup = [k for k, v in Counter(t["id"] for t in todos_trozos).items() if v > 1]
    if dup:
        print(f"AVISO: ids duplicados: {dup[:10]}")


if __name__ == "__main__":
    main()
