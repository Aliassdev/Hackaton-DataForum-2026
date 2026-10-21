"""P6 · Evaluación del RAG con ablación: qué aporta cada pieza.

Uso, desde la raíz del repo:
    backend/.venv/Scripts/python -X utf8 ml/eval_rag.py [--detalle]

Conjunto: content/eval/golden_rag.jsonl (preguntas con lenguaje de 12-17 años, perfil y artículos
que las responden, verificados contra el texto de la ley).
Métricas, a nivel de artículo:
- Acierto@5: hay al menos un artículo correcto entre los 5 primeros.
- Recall@5: proporción de artículos correctos recuperados entre los 5 primeros.
- MRR@10: 1 / posición del primer artículo correcto (0 si no está entre los 10 primeros).
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--golden", type=Path, default=RAIZ / "content/eval/golden_rag.jsonl")
    ap.add_argument("--detalle", action="store_true", help="muestra las preguntas falladas por el modo completo")
    args = ap.parse_args()

    rec = Recuperador(RAIZ / "artifacts/index", RAIZ / "content/rag_perfiles.json")
    golden = [json.loads(l) for l in args.golden.read_text(encoding="utf-8").splitlines() if l.strip()]
    rec.buscar("calentamiento")

    resultados = {}
    for modo in MODOS:
        aciertos, recalls, rrs, ms, fallos = [], [], [], [], []
        for g in golden:
            t0 = time.perf_counter()
            top = [f.articulo_id for f in rec.buscar(g["pregunta"], g["perfil"], k=10, modo=modo)]
            ms.append((time.perf_counter() - t0) * 1000)
            relevantes = set(g["relevantes"])
            top5 = set(top[:5])
            aciertos.append(bool(top5 & relevantes))
            recalls.append(len(top5 & relevantes) / len(relevantes))
            rrs.append(next((1 / (i + 1) for i, a in enumerate(top) if a in relevantes), 0.0))
            if not top5 & relevantes:
                fallos.append((g["pregunta"], g["relevantes"], top[:5]))
        resultados[modo] = {
            "acierto@5": statistics.mean(aciertos), "recall@5": statistics.mean(recalls),
            "mrr@10": statistics.mean(rrs), "ms_mediana": statistics.median(ms), "fallos": fallos,
        }

    print(f"\nRAG sobre {len(golden)} preguntas de referencia · {len(rec.trozos)} fragmentos de 9 normas\n")
    print(f"{'modo':<16}{'Acierto@5':>11}{'Recall@5':>10}{'MRR@10':>9}{'ms':>7}")
    for modo, r in resultados.items():
        print(f"{modo:<16}{r['acierto@5']:>11.3f}{r['recall@5']:>10.3f}{r['mrr@10']:>9.3f}{r['ms_mediana']:>7.0f}")

    if args.detalle:
        print("\nFallos del modo completo:")
        for p, rel, top in resultados["completo"]["fallos"]:
            print(f"  x {p}\n      esperado {rel} · obtenido {top}")

    salida = RAIZ / "artifacts/index/metrics_rag.json"
    salida.write_text(json.dumps(resultados, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nMétricas guardadas en {salida}")


if __name__ == "__main__":
    main()
