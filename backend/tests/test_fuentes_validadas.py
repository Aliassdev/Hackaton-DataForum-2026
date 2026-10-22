"""Fuentes validadas del RAG (glosario de la app y citas de docs/MARCO_LEGAL.md): ingesta, etiquetas de cita, cómo las
enseña la app y cómo las acepta la verificación. Sin red ni LLM."""

import importlib.util
import json
from pathlib import Path

import pytest

from app.agent import prompts
from app.api.agent import fuente
from app.rag.retrieve import TRAMO_14_A_17, TRAMO_MENOR_14, Fragmento, edades_de_la_ley, get_recuperador

RAIZ = Path(__file__).resolve().parents[2]


def _cargar(nombre: str, ruta: Path):
    spec = importlib.util.spec_from_file_location(nombre, ruta)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


fv = _cargar("fuentes_validadas", RAIZ / "ml/fuentes_validadas.py")
LEYES = {l["id"]: l for l in json.loads((RAIZ / "content/leyes.json").read_text(encoding="utf-8"))["leyes"]}

MARCO_MD = """# Marco legal comprobado

## Sergio · 13 años · acoso escolar y Fiscalía de Menores

### LO 5/2000, art. 28.1 · Reglas generales (medidas cautelares)
> 1. El Ministerio Fiscal (...) podrá solicitar del Juez de Menores, en cualquier momento, la adopción de medidas cautelares (...)

**Para explicarlo:** En cualquier momento del proceso, el fiscal puede pedir al juez medidas para protegerte.

Fuente: [BOE-A-2000-641](https://www.boe.es/buscar/act.php?id=BOE-A-2000-641)

## Lucía · 11 años · Sala Gesell

### LECrim, art. 449 ter, párr. 3
> Para el supuesto de que la persona investigada estuviere presente en la audiencia del menor se evitará su confrontación visual con el testigo.

Fuente: [BOE-A-1882-6036](https://www.boe.es/buscar/act.php?id=BOE-A-1882-6036)

### LECrim, art. 520.2 bis
> 2 bis. La información (...) se facilitará en un lenguaje comprensible.

Fuente: [BOE-A-1882-6036](https://www.boe.es/buscar/act.php?id=BOE-A-1882-6036)

### LOPIVI (LO 8/2021), art. 14.1 y 14.3 · Derecho a la asistencia jurídica gratuita · ⚠️ corrige el documento
> Las personas menores de edad víctimas de violencia tienen derecho a la defensa y representación gratuitas.

**Corrección:** La gratuidad no es incondicional.

Fuente: [BOE-A-2021-9347](https://www.boe.es/buscar/act.php?id=BOE-A-2021-9347)

### CE (Constitución Española), art. 24.2 (párr. 1) · Derecho a la defensa y presunción de inocencia
> 2. Asimismo, todos tienen derecho (...) a la presunción de inocencia.

Fuente: [BOE-A-1978-31229](https://www.boe.es/buscar/act.php?id=BOE-A-1978-31229)

## Sara · casi 16 años · difusión de imágenes íntimas

### AEPD · Canal prioritario, art. Página principal, bloque #CanalPrioritario · Tú también #PuedesPararlo con el #CanalPrioritario
> Puedes solicitar su retirada inmediata en el Canal prioritario de la Agencia.

Fuente: [https://www.aepd.es/canalprioritario](https://www.aepd.es/canalprioritario)

### AEPD · Canal prioritario, art. Sección «¿Eres menor de edad?» · ¿Eres menor de edad?
> Si tienes entre 14 y 17 años (...) recuerda que #PuedesPararlo.

Fuente: [https://www.aepd.es/canalprioritario](https://www.aepd.es/canalprioritario)

### AEPD · Preguntas frecuentes, art. FAQ 15.03 · ¿En qué casos no puedo acudir a este canal?
> No podremos ayudarte a través de este canal (...) mediante servicios de mensajería instantánea.

Fuente: [https://www.aepd.es/preguntas-frecuentes/FAQ-1503](https://www.aepd.es/preguntas-frecuentes/FAQ-1503)
"""


# --- docs/MARCO_LEGAL.md → content/marco_legal.json ---

def test_marco_legal_norma_articulo_y_etiqueta():
    entradas = {e["id"]: e for e in fv.entradas_marco_legal(MARCO_MD, LEYES, {"LORPM-28": {"titulo": "Reglas generales"}})}
    assert list(entradas) == [
        "ML-LORPM-28", "ML-LECRIM-449ter", "ML-LECRIM-520", "ML-LOPIVI-14", "ML-CE-24",
        "ML-AEPD-canal-prioritario", "ML-AEPD-canal-prioritario-2", "ML-AEPD-FAQ-15.03",
    ]
    e = entradas["ML-LORPM-28"]
    assert (e["articulo_id"], e["ley"], e["cita"], e["norma"], e["articulo"], e["caso"]) == (
        "LORPM-28", "LORPM", "LORPM art. 28.1", "LORPM", "28.1", "Sergio")
    assert e["url"] == "https://www.boe.es/buscar/act.php?id=BOE-A-2000-641#a28" and e["validado"] is True
    assert e["titulo"] == "Reglas generales (medidas cautelares)"
    # El sufijo del artículo es del artículo («449 ter») o del apartado («520.2 bis»)
    assert entradas["ML-LECRIM-449ter"]["articulo_id"] == "LECRIM-449ter"
    assert entradas["ML-LECRIM-449ter"]["cita"] == "LECrim art. 449 ter, párr. 3"
    assert entradas["ML-LECRIM-520"]["articulo_id"] == "LECRIM-520"
    # Normas que no están en el corpus de leyes, sin lo que va entre paréntesis
    assert (entradas["ML-CE-24"]["cita"], entradas["ML-CE-24"]["norma"]) == ("CE art. 24.2", "CE")
    # Webs oficiales: la etiqueta es la página, como en los ejemplos de la app
    assert entradas["ML-AEPD-canal-prioritario"]["cita"] == "AEPD · Canal prioritario"
    assert entradas["ML-AEPD-canal-prioritario-2"]["cita"] == "AEPD · Canal prioritario (¿Eres menor de edad?)"
    assert entradas["ML-AEPD-canal-prioritario-2"]["norma"] == "AEPD · Canal prioritario"
    assert (entradas["ML-AEPD-FAQ-15.03"]["cita"], entradas["ML-AEPD-FAQ-15.03"]["articulo"]) == ("AEPD · FAQ 15.03", "")


def test_marco_legal_solo_la_cita_literal():
    """La explicación «Para explicarlo» es orientativa y las «Correcciones» son notas del equipo: no entran."""
    textos = " ".join(e["texto"] for e in fv.entradas_marco_legal(MARCO_MD, LEYES))
    assert "Para explicarlo" not in textos and "fiscal puede pedir al juez" not in textos
    assert "incondicional" not in textos and "corrige el documento" not in json.dumps(fv.entradas_marco_legal(MARCO_MD, LEYES))


def test_marco_legal_norma_desconocida_para_la_generacion():
    with pytest.raises(ValueError, match="Norma desconocida"):
        fv.entradas_marco_legal("## X\n\n### Ley Inventada 9/2099, art. 1\n> texto\n\nFuente: [x](https://x)\n", LEYES)


# --- contenido validado del repositorio ---

def test_glosario_validado_con_etiqueta_verificable():
    trozos = {t["id"]: t for t in fv.trozos_glosario()}
    glosario = json.loads((RAIZ / "content/glosario.json").read_text(encoding="utf-8"))
    assert len(trozos) == sum(1 for e in glosario if e.get("validado") is True and e.get("fuente"))
    t = trozos["G-sala-gesell"]
    assert t["cita"] == "Glosario TuTurno · Sala Gesell (Ley 4/2015, art. 25.1; LECrim, arts. 449 bis y 449 ter)"
    assert t["norma"] == "Glosario TuTurno · Sala Gesell" and t["articulo"] == "" and t["articulo_id"] == "G-sala-gesell"
    assert t["texto"].startswith("Sala Gesell: Sala preparada") and "\nEjemplo de TuTurno: Lucía" in t["texto"]


def test_glosario_sin_validar_o_sin_fuente_no_entra(tmp_path: Path):
    ruta = tmp_path / "glosario.json"
    ruta.write_text(json.dumps([
        {"id": "G-a", "termino": "A", "definicion": "Def.", "ejemplo": "", "fuente": "LO 5/2000, art. 1", "validado": True},
        {"id": "G-b", "termino": "B", "definicion": "Def.", "ejemplo": "", "fuente": "LO 5/2000, art. 1", "validado": False},
        {"id": "G-c", "termino": "C", "definicion": "Def.", "ejemplo": "", "fuente": "", "validado": True},
    ]), encoding="utf-8")
    assert [t["id"] for t in fv.trozos_glosario(ruta)] == ["G-a"]


def test_marco_legal_del_repositorio_validado_y_con_su_articulo():
    entradas = json.loads((RAIZ / "content/marco_legal.json").read_text(encoding="utf-8"))["entradas"]
    assert len(entradas) >= 90 and len({e["id"] for e in entradas}) == len(entradas)
    assert all(e["validado"] is True and e["fuente"] and e["texto"] and e["cita"] and e["url"].startswith("https://") for e in entradas)
    por_id = {e["articulo_id"] for e in entradas}
    assert {"LORPM-3", "LORPM-6", "LECRIM-449ter", "EVD-25", "AEPD-canal-prioritario", "AEPD-FAQ-15.03", "INCIBE-017"} <= por_id


# --- cómo las enseña la app (contrato 8.1, sin campos nuevos) ---

def _fragmento(cita: str, articulo_id: str, titulo: str = "", norma: str | None = None, articulo: str | None = None, url: str = "") -> Fragmento:
    return Fragmento(articulo_id, articulo_id, "X", cita, titulo, "texto", url, 0.1, norma, articulo)


GESELL = _fragmento("Glosario TuTurno · Sala Gesell (Ley 4/2015, art. 25.1; LECrim, arts. 449 bis y 449 ter)", "G-sala-gesell",
                    "Ley 4/2015, art. 25.1; LECrim, arts. 449 bis y 449 ter", "Glosario TuTurno · Sala Gesell", "")
AEPD = _fragmento("AEPD · Canal prioritario", "AEPD-canal-prioritario", "Tú también #PuedesPararlo con el #CanalPrioritario",
                  "AEPD · Canal prioritario", "", "https://www.aepd.es/canalprioritario")
CAUTELAR = _fragmento("LORPM art. 28.1", "LORPM-28", "Reglas generales (medidas cautelares)", "LORPM", "28.1",
                      "https://www.boe.es/buscar/act.php?id=BOE-A-2000-641#a28")
BOE = _fragmento("LECrim art. 449ter", "LECRIM-449ter", "", url="https://www.boe.es/buscar/act.php?id=BOE-A-1882-6036#a449ter")


def test_fuente_para_la_app():
    assert fuente(GESELL).model_dump() == {
        "id": "G-sala-gesell", "titulo": "Ley 4/2015, art. 25.1; LECrim, arts. 449 bis y 449 ter",
        "norma": "Glosario TuTurno · Sala Gesell", "articulo": "", "url": "",
    }
    assert fuente(AEPD).model_dump()["norma"] == "AEPD · Canal prioritario" and fuente(AEPD).articulo == ""
    assert (fuente(CAUTELAR).norma, fuente(CAUTELAR).articulo, fuente(CAUTELAR).id) == ("LORPM", "28.1", "LORPM-28")
    # Los artículos de ley, como siempre
    assert (fuente(BOE).norma, fuente(BOE).articulo, fuente(BOE).titulo) == ("LECrim", "449 ter", "Artículo 449 ter")


def test_el_llm_ve_la_etiqueta_sola_entre_corchetes():
    texto = prompts.formatear_fragmentos([GESELL, CAUTELAR])
    assert "[Glosario TuTurno · Sala Gesell (Ley 4/2015, art. 25.1; LECrim, arts. 449 bis y 449 ter)]\n" in texto  # sin repetir la base legal
    assert "[LORPM art. 28.1] Reglas generales (medidas cautelares)\n" in texto
    sistema = prompts.sistema({}, [GESELL], canal="texto")
    assert "personajes inventados" in sistema and "copiadas tal cual" in sistema


# --- la verificación acepta sus citas y descarta las inventadas ---

@pytest.mark.parametrize(
    ("cita", "esperado"),
    [
        ("Glosario TuTurno · Sala Gesell (Ley 4/2015, art. 25.1; LECrim, arts. 449 bis y 449 ter)", "G-sala-gesell"),
        ("Glosario TuTurno · Sala Gesell", "G-sala-gesell"),  # sin la base legal
        ("Glosario TuTurno · Sala Gesell (Ley 4/2015, art. 25.1)", "G-sala-gesell"),  # base legal recortada
        ("Sala Gesell", "G-sala-gesell"),  # solo el término
        ("AEPD · Canal prioritario", "AEPD-canal-prioritario"),
        ("AEPD · Canal prioritario · Tú también", "AEPD-canal-prioritario"),  # con el título
        ("LORPM art. 28.1", "LORPM-28"),
        ("LORPM art. 28", "LORPM-28"),  # el artículo entero
        ("LORPM, artículo 28.1 · Reglas generales", "LORPM-28"),
        ("lecrim, artículo 449 ter", "LECRIM-449ter"),
    ],
)
def test_fuentes_usadas_acepta_las_citas_de_las_fuentes_validadas(cita, esperado):
    assert [f.articulo_id for f in prompts.fuentes_usadas([cita], [GESELL, AEPD, CAUTELAR, BOE])] == [esperado]


@pytest.mark.parametrize(
    "cita",
    [
        "Glosario TuTurno · Juicio",  # entrada del glosario que no se ha recuperado
        "Glosario TuTurno",
        "AEPD",
        "AEPD · Canal Joven",
        "LORPM art. 2",  # «2» no es un recorte de «28»
        "LORPM art. 281",
        "LECrim art. 449",  # otro artículo: no es «449 ter»
        "Código Penal art. 197",
        "INCIBE · 017",
    ],
)
def test_fuentes_usadas_descarta_las_inventadas(cita):
    assert prompts.fuentes_usadas([cita], [GESELL, AEPD, CAUTELAR, BOE]) == []


def test_separar_fuentes_con_etiquetas_del_glosario_y_de_webs():
    texto = (
        "Es una sala preparada [Glosario TuTurno · Sala Gesell (Ley 4/2015, art. 25.1; LECrim, arts. 449 bis y 449 ter)]. "
        "Puedes pedirlo en el Canal prioritario [AEPD · Canal prioritario].\n"
        "FUENTES: [Glosario TuTurno · Sala Gesell (Ley 4/2015, art. 25.1; LECrim, arts. 449 bis y 449 ter)] [AEPD · Canal prioritario]"
    )
    cuerpo, citas = prompts.separar_fuentes(texto)
    assert cuerpo == "Es una sala preparada. Puedes pedirlo en el Canal prioritario."
    assert [f.articulo_id for f in prompts.fuentes_usadas(citas, [GESELL, AEPD, CAUTELAR])] == ["G-sala-gesell", "AEPD-canal-prioritario"]


# --- edades como las escribe la ley (consulta BM25) ---

def test_edades_de_la_ley():
    assert edades_de_la_ley("Tengo 13 años y he hecho algo malo") == f"Tengo 13 años y he hecho algo malo trece años {TRAMO_MENOR_14}"
    assert edades_de_la_ley("si me investigan con 15 años") == f"si me investigan con 15 años quince años {TRAMO_14_A_17}"
    assert edades_de_la_ley("tengo 9 años") == "tengo 9 años nueve años"
    assert edades_de_la_ley("¿Qué es la Sala Gesell?") == "¿Qué es la Sala Gesell?"


# --- con el índice construido ---

sin_indice = pytest.mark.skipif(get_recuperador() is None, reason="sin índice RAG construido")


@sin_indice
@pytest.mark.parametrize(
    ("pregunta", "perfil", "alguno_de"),
    [
        ("¿Qué es la Sala Gesell?", {"edad": 11, "procedimiento": "penal", "rol": "victima"}, {"G-sala-gesell"}),
        ("Me han pasado fotos mías, ¿cómo pido que las borren?", {"edad": 15, "procedimiento": "penal", "rol": "victima"},
         {"G-canal-prioritario", "AEPD-canal-prioritario"}),
        ("Tengo 13 años y he hecho algo malo, ¿me pueden juzgar?", {"edad": 13}, {"LORPM-3"}),
        ("¿Qué es una orden de alejamiento?", {"edad": 13, "procedimiento": "penal", "rol": "victima"}, {"G-orden-alejamiento"}),
    ],
)
def test_rag_preguntas_de_la_demo(pregunta, perfil, alguno_de):
    """Sin reformular (no hay LLM en los tests): la pregunta sola ya trae la fuente que la responde entre las 6 que ve el LLM."""
    assert alguno_de & {f.articulo_id for f in get_recuperador().buscar(pregunta, perfil, k=6)}


@sin_indice
def test_rag_las_citas_del_marco_legal_compiten_con_su_articulo():
    """Una cita del marco legal lleva el id de su artículo: nunca salen dos fragmentos del mismo artículo."""
    frags = get_recuperador().buscar("¿Tengo que ver a la persona que me hizo daño?", {"edad": 11, "procedimiento": "penal", "rol": "victima"}, k=10)
    ids = [f.articulo_id for f in frags]
    assert len(ids) == len(set(ids))
