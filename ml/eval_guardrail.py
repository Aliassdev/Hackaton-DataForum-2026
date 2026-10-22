"""Evalúa el guardrail completo (reglas + modelo), tal y como corre en el backend.

Uso, desde la raíz del repo:
    backend/.venv/Scripts/python ml/eval_guardrail.py --modelo artifacts/models/guardrail_lr
"""

import argparse
import json
import statistics
import sys
from pathlib import Path

from sklearn.metrics import confusion_matrix, f1_score, recall_score

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "backend"))
from app.agent.clasificador import CLASES  # noqa: E402
from app.agent.safety import Guardrail  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--modelo", type=Path, required=True)
    ap.add_argument("--test", type=Path, default=RAIZ / "content/eval/red_team.jsonl")
    ap.add_argument("--umbral-crisis", type=float, default=0.30)
    ap.add_argument("--umbral-otros", type=float, default=0.50)
    args = ap.parse_args()

    g = Guardrail(RAIZ / "content/seguridad_patrones.json", (RAIZ / args.modelo).resolve(), args.umbral_crisis, args.umbral_otros)
    filas = [json.loads(l) for l in args.test.read_text(encoding="utf-8").splitlines() if l.strip()]
    g.evaluar("calentamiento")  # la primera inferencia incluye la carga perezosa de CUDA

    reales, pred, ms, por_regla = [], [], [], 0
    for f in filas:
        d = g.evaluar(f["texto"])
        reales.append(f["etiqueta"])
        pred.append(d.categoria)
        ms.append(d.ms)
        por_regla += d.origen == "regla"
        if d.categoria != f["etiqueta"]:
            print(f"  x [{f['etiqueta']} -> {d.categoria}] ({d.origen}) {f['texto']}")

    print(f"\nGuardrail completo sobre {len(filas)} pruebas trampa ({args.modelo.name})")
    print(f"  F1 macro:       {f1_score(reales, pred, labels=list(CLASES), average='macro'):.3f}")
    print(f"  Recall crisis:  {recall_score(reales, pred, labels=['crisis'], average='macro'):.3f}")
    print(f"  Decididos por regla: {por_regla}")
    print(f"  Latencia: mediana {statistics.median(ms):.0f} ms · máx {max(ms):.0f} ms")
    print("  Matriz (filas = real):", ", ".join(CLASES))
    for c, fila in zip(CLASES, confusion_matrix(reales, pred, labels=list(CLASES)).tolist()):
        print(f"    {c:>16}: {fila}")


if __name__ == "__main__":
    main()
