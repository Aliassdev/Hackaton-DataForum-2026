"""P6 · Evaluación del RAG con ablación: qué aporta cada pieza.

Uso, desde la raíz del repo:
    backend/.venv/Scripts/python -X utf8 ml/eval_rag.py [--detalle] [--index DIR] [--perfiles JSON] [--pausa S]

--index y --perfiles permiten medir otro índice (por ejemplo, el anterior a añadir leyes) o comparar
pesos de perfil sobre el mismo índice. Las métricas se guardan en <index>/metrics_rag.json (o en --salida).
--pausa: segundos entre dos reformulaciones (2,1 por defecto, para el plan gratuito de Groq; con el router de
Hugging Face basta con 0,2).

Conjunto: content/eval/golden_rag.jsonl (preguntas con lenguaje de 11-17 años, perfil y artículos
que las responden, verificados contra el texto de la ley). Las que llevan "demo": true son las preguntas típicas
de la demo (con su respuesta verificada en "respuesta") y se resumen también aparte.
Los ids relevantes son artículos ("LORPM-3"), entradas del glosario validado ("G-sala-gesell") o fuentes web
de docs/MARCO_LEGAL.md ("AEPD-CP").
Métricas, a nivel de artículo (o de entrada del glosario):
- Acierto@5: hay al menos un artículo correcto entre los 5 primeros.
- Recall@5: proporción de artículos correctos recuperados entre los 5 primeros.
- MRR@10: 1 / posición del primer artículo correcto (0 si no está entre los 10 primeros).
«solo normas»: el modo reformulado, quitando del ranking lo que no es una norma (glosario y webs del AEPD y el
INCIBE). Sirve para ver si las fuentes nuevas desplazan artículos de ley correctos.
"""

import argparse
import json
import statistics
import sys
import time
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "backend"))
from app.rag.retrieve import MODOS, Recuperador  # noqa: E402

NO_NORMAS = {"GLOSARIO", "AEPD", "INCIBE"}  # fuentes validadas que no son una norma


def metricas(top: list[str], relevantes: set[str]) -> tuple[bool, float, float]:
    top5 = set(top[:5])
    rr = next((1 / (i + 1) for i, a in enumerate(top[:10]) if a in relevantes), 0.0)
    return bool(top5 & relevantes), len(top5 & relevantes) / len(relevantes), rr


def resumir(filas: list[dict]) -> dict:
    if not filas:
        return {}
    return {
        "n": len(filas),
        "acierto@5": statistics.mean(f["acierto"] for f in filas),
        "recall@5": statistics.mean(f["recall"] for f in filas),
        "mrr@10": statistics.mean(f["rr"] for f in filas),
        "ms_mediana": statistics.median(f["ms"] for f in filas),
        "fallos": [(f["pregunta"], f["relevantes"], f["top"][:5]) for f in filas if not f["acierto"]],
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--golden", type=Path, default=RAIZ / "content/eval/golden_rag.jsonl")
    ap.add_argument("--detalle", action="store_true", help="muestra las preguntas falladas por el modo completo")
    ap.add_argument("--index", type=Path, default=RAIZ / "artifacts/index", help="carpeta del índice que se evalúa")
    ap.add_argument("--perfiles", type=Path, default=RAIZ / "content/rag_perfiles.json", help="pesos de refuerzo por perfil")
    ap.add_argument("--pausa", type=float, default=2.1, help="segundos entre reformulaciones (plan gratuito de Groq: 2,1)")
    ap.add_argument("--salida", type=Path, default=None, help="dónde guardar las métricas (por defecto, <index>/metrics_rag.json)")
    args = ap.parse_args()

    rec = Recuperador(args.index, args.perfiles)
    golden = [json.loads(l) for l in args.golden.read_text(encoding="utf-8").splitlines() if l.strip()]
    rec.buscar("calentamiento")
    ley_de = {t["articulo_id"]: t["ley"] for t in rec.trozos}

    # Modo con reformulación jurídica por LLM (solo si hay key): la consulta se genera una vez por pregunta
    from app.agent.orquestador import reformular
    from app.config import settings

    modos = list(MODOS)
    consultas = {}
    if settings.llm_api_key:
        modos += ["reformulado", "solo_normas"]
        for g in golden:
            consultas[g["pregunta"]] = reformular(g["pregunta"], [{"role": "user", "content": g["pregunta"]}], g["perfil"])
            time.sleep(args.pausa)
        print("Ejemplos de reformulación:")
        for p in list(consultas)[:4]:
            print(f"  «{p}» → «{consultas[p]}»")
    else:
        print("(Sin LLM_API_KEY/GROQ_API_KEY: se omite el modo 'reformulado')")

    resultados, detalle = {}, []
    for modo in modos:
        filas = []
        for g in golden:
            t0 = time.perf_counter()
            if modo in ("reformulado", "solo_normas"):
                frags = rec.buscar(g["pregunta"], g["perfil"], k=20, consulta_juridica=consultas[g["pregunta"]])
            else:
                frags = rec.buscar(g["pregunta"], g["perfil"], k=20, modo=modo)
            ms = (time.perf_counter() - t0) * 1000
            top = [f.articulo_id for f in frags if modo != "solo_normas" or f.ley not in NO_NORMAS][:10]
            relevantes = set(g["relevantes"])
            if modo == "solo_normas":
                relevantes = {r for r in relevantes if ley_de.get(r) not in NO_NORMAS and not r.startswith(("G-", "AEPD-", "INCIBE-"))}
                if not relevantes:
                    continue
            acierto, recall, rr = metricas(top, relevantes)
            filas.append({"pregunta": g["pregunta"], "relevantes": sorted(relevantes), "top": top, "demo": bool(g.get("demo")),
                          "acierto": acierto, "recall": recall, "rr": rr, "ms": ms})
            if modo == "reformulado":
                detalle.append({"pregunta": g["pregunta"], "demo": bool(g.get("demo")), "consulta": consultas[g["pregunta"]],
                                "relevantes": g["relevantes"], "top6": top[:6], "acierto@5": acierto, "recall@5": recall, "rr": rr})
        resultados[modo] = resumir(filas)
        if any(f["demo"] for f in filas):
            resultados[modo]["demo"] = resumir([f for f in filas if f["demo"]])
            resultados[modo]["referencia"] = resumir([f for f in filas if not f["demo"]])

    print(f"\nRAG sobre {len(golden)} preguntas de referencia · {len(rec.trozos)} fragmentos de {len({t['ley'] for t in rec.trozos})} fuentes\n")
    grupos = [("todas", None), ("las 48 de referencia", "referencia"), ("demo", "demo")]
    for nombre, clave in grupos:
        if clave and not any(clave in r for r in resultados.values()):
            continue
        print(f"== {nombre}")
        print(f"{'modo':<16}{'n':>4}{'Acierto@5':>11}{'Recall@5':>10}{'MRR@10':>9}{'ms':>7}")
        for modo, r in resultados.items():
            r = r.get(clave, {}) if clave else r
            if r:
                print(f"{modo:<16}{r['n']:>4}{r['acierto@5']:>11.3f}{r['recall@5']:>10.3f}{r['mrr@10']:>9.3f}{r['ms_mediana']:>7.0f}")
        print()

    if args.detalle:
        mejor = "reformulado" if "reformulado" in resultados else "hibrido_perfil"
        print(f"Fallos del modo {mejor}:")
        for p, rel, top in resultados[mejor]["fallos"]:
            print(f"  x {p}\n      esperado {rel} · obtenido {top}")
        if detalle:
            print("\nPreguntas de la demo (modo reformulado):")
            for d in detalle:
                if d["demo"]:
                    print(f"  {'ok' if d['acierto@5'] else 'x '} {d['pregunta']}\n      consulta: {d['consulta']}\n"
                          f"      esperado {d['relevantes']} · obtenido {d['top6']}")

    salida = args.salida or args.index / "metrics_rag.json"
    salida.write_text(json.dumps({"metricas": resultados, "detalle_reformulado": detalle}, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nMétricas guardadas en {salida}")


if __name__ == "__main__":
    main()
