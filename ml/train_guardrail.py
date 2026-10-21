"""Entrena el clasificador del guardrail (capa 1) y lo evalúa.

Uso, desde la raíz del repo (con el venv del backend):
    backend/.venv/Scripts/python ml/train_guardrail.py --modo lr
    backend/.venv/Scripts/python ml/train_guardrail.py --modo finetune

Evaluación:
- Validación cruzada estratificada de 5 particiones sobre content/guardrail/train.jsonl.
- Conjunto aparte de pruebas trampa (content/eval/red_team.jsonl), con frases redactadas
  de otra forma que el modelo no ve al entrenar.
Métricas: F1 macro, recall de crisis (la que importa: una crisis no detectada es el peor error)
y matriz de confusión. Se guardan en <out>/metrics.json.
"""

import argparse
import json
import random
import sys
from pathlib import Path

import numpy as np
from sklearn.metrics import classification_report, confusion_matrix, f1_score, recall_score
from sklearn.model_selection import StratifiedKFold

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "backend"))
from app.agent.clasificador import CLASES, decidir  # noqa: E402

SEMILLA = 42
ENCODER = "intfloat/multilingual-e5-base"
BASE_FINETUNE = "PlanTL-GOB-ES/roberta-base-bne"


def cargar(ruta: Path) -> tuple[list[str], list[str]]:
    filas = [json.loads(l) for l in ruta.read_text(encoding="utf-8").splitlines() if l.strip()]
    return [f["texto"] for f in filas], [f["etiqueta"] for f in filas]


# ---------- Línea base: embeddings + regresión logística ----------

class ModeloLR:
    def __init__(self):
        from sentence_transformers import SentenceTransformer

        self.encoder = SentenceTransformer(ENCODER)
        self.cache: dict[str, np.ndarray] = {}

    def _emb(self, textos):
        nuevos = [t for t in textos if t not in self.cache]
        if nuevos:
            for t, e in zip(nuevos, self.encoder.encode([f"query: {t}" for t in nuevos], normalize_embeddings=True)):
                self.cache[t] = e
        return np.stack([self.cache[t] for t in textos])

    def entrenar(self, textos, etiquetas):
        from sklearn.linear_model import LogisticRegression

        self.lr = LogisticRegression(C=4.0, class_weight="balanced", max_iter=5000, random_state=SEMILLA)
        self.lr.fit(self._emb(textos), etiquetas)

    def probabilidades(self, textos):
        return [dict(zip(self.lr.classes_, map(float, f))) for f in self.lr.predict_proba(self._emb(textos))]

    def guardar(self, out: Path):
        import joblib

        joblib.dump(self.lr, out / "lr.joblib")
        return {"tipo": "embeddings_lr", "encoder": ENCODER}


# ---------- Ajuste fino de un transformer en español ----------

class ModeloFinetune:
    def __init__(self, base=BASE_FINETUNE, epocas=10, lr=3e-5, batch=16, max_len=64):
        import torch

        self.torch = torch
        self.base, self.epocas, self.lr_, self.batch, self.max_len = base, epocas, lr, batch, max_len
        self.device = "cuda" if torch.cuda.is_available() else "cpu"

    def entrenar(self, textos, etiquetas):
        import torch
        from transformers import AutoModelForSequenceClassification, AutoTokenizer, get_linear_schedule_with_warmup

        torch.manual_seed(SEMILLA)
        self.tok = AutoTokenizer.from_pretrained(self.base)
        self.model = AutoModelForSequenceClassification.from_pretrained(
            self.base,
            num_labels=len(CLASES),
            id2label=dict(enumerate(CLASES)),
            label2id={c: i for i, c in enumerate(CLASES)},
        ).to(self.device)

        y = torch.tensor([CLASES.index(e) for e in etiquetas])
        # Pesos por clase (inversa de la frecuencia), como class_weight="balanced"
        conteo = torch.bincount(y, minlength=len(CLASES)).float()
        pesos = (len(y) / (len(CLASES) * conteo)).to(self.device)
        perdida = torch.nn.CrossEntropyLoss(weight=pesos)

        opt = torch.optim.AdamW(self.model.parameters(), lr=self.lr_, weight_decay=0.01)
        pasos = self.epocas * ((len(textos) + self.batch - 1) // self.batch)
        sched = get_linear_schedule_with_warmup(opt, int(0.1 * pasos), pasos)

        self.model.train()
        g = torch.Generator().manual_seed(SEMILLA)
        for _ in range(self.epocas):
            for idx in torch.randperm(len(textos), generator=g).split(self.batch):
                enc = self.tok([textos[i] for i in idx], truncation=True, max_length=self.max_len, padding=True, return_tensors="pt").to(self.device)
                with torch.autocast(self.device, dtype=torch.bfloat16, enabled=self.device == "cuda"):
                    logits = self.model(**enc).logits
                loss = perdida(logits.float(), y[idx].to(self.device))
                loss.backward()
                torch.nn.utils.clip_grad_norm_(self.model.parameters(), 1.0)
                opt.step()
                sched.step()
                opt.zero_grad()
        self.model.eval()

    def probabilidades(self, textos):
        salida = []
        for i in range(0, len(textos), 64):
            enc = self.tok(textos[i : i + 64], truncation=True, max_length=self.max_len, padding=True, return_tensors="pt").to(self.device)
            with self.torch.no_grad():
                probs = self.torch.softmax(self.model(**enc).logits.float(), dim=-1).cpu().numpy()
            salida += [dict(zip(CLASES, map(float, f))) for f in probs]
        return salida

    def guardar(self, out: Path):
        self.model.save_pretrained(out)
        self.tok.save_pretrained(out)
        return {"tipo": "finetuned", "base": self.base, "max_len": self.max_len, "epocas": self.epocas}


# ---------- Evaluación ----------

def metricas(textos, reales, probs, umbral_crisis, umbral_otros) -> dict:
    pred = [decidir(p, umbral_crisis, umbral_otros) for p in probs]
    return {
        "f1_macro": round(f1_score(reales, pred, labels=list(CLASES), average="macro"), 4),
        "recall_crisis": round(recall_score(reales, pred, labels=["crisis"], average="macro"), 4),
        "matriz_confusion": {"clases": list(CLASES), "valores": confusion_matrix(reales, pred, labels=list(CLASES)).tolist()},
        "informe": classification_report(reales, pred, labels=list(CLASES), zero_division=0, output_dict=True),
        "errores": [{"texto": t, "real": r, "pred": p} for t, r, p in zip(textos, reales, pred) if r != p],
    }


def imprimir(nombre, m):
    print(f"\n=== {nombre} ===  F1 macro: {m['f1_macro']:.3f}  ·  recall crisis: {m['recall_crisis']:.3f}")
    print("Matriz de confusión (filas = real, columnas = predicho):", ", ".join(CLASES))
    for c, fila in zip(CLASES, m["matriz_confusion"]["valores"]):
        print(f"  {c:>16}: {fila}")
    for e in m["errores"]:
        print(f"  x [{e['real']} -> {e['pred']}] {e['texto']}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--modo", choices=["lr", "finetune"], required=True)
    ap.add_argument("--train", type=Path, default=RAIZ / "content/guardrail/train.jsonl")
    ap.add_argument("--test", type=Path, default=RAIZ / "content/eval/red_team.jsonl")
    ap.add_argument("--out", type=Path)
    ap.add_argument("--folds", type=int, default=5)
    ap.add_argument("--umbral-crisis", type=float, default=0.30)
    ap.add_argument("--umbral-otros", type=float, default=0.50)
    args = ap.parse_args()
    out = args.out or RAIZ / f"artifacts/models/guardrail_{args.modo}"

    random.seed(SEMILLA)
    np.random.seed(SEMILLA)
    X, y = cargar(args.train)
    X_test, y_test = cargar(args.test)
    print(f"Entrenamiento: {len(X)} ejemplos · pruebas trampa: {len(X_test)}")

    nuevo = (lambda: ModeloLR()) if args.modo == "lr" else (lambda: ModeloFinetune())
    lr_compartido = nuevo() if args.modo == "lr" else None  # reutiliza encoder y caché entre particiones

    # Validación cruzada: predicciones fuera de partición para todo el conjunto
    probs_cv: list[dict] = [None] * len(X)
    skf = StratifiedKFold(n_splits=args.folds, shuffle=True, random_state=SEMILLA)
    for k, (tr, va) in enumerate(skf.split(X, y), 1):
        modelo = lr_compartido or nuevo()
        modelo.entrenar([X[i] for i in tr], [y[i] for i in tr])
        for i, p in zip(va, modelo.probabilidades([X[i] for i in va])):
            probs_cv[i] = p
        print(f"  partición {k}/{args.folds} lista")
    m_cv = metricas(X, y, probs_cv, args.umbral_crisis, args.umbral_otros)
    imprimir(f"Validación cruzada ({args.folds} particiones)", m_cv)

    # Modelo final con todos los datos y evaluación en las pruebas trampa
    modelo = lr_compartido or nuevo()
    modelo.entrenar(X, y)
    probs_test = modelo.probabilidades(X_test)
    m_test = metricas(X_test, y_test, probs_test, args.umbral_crisis, args.umbral_otros)
    imprimir("Pruebas trampa (conjunto aparte)", m_test)

    out.mkdir(parents=True, exist_ok=True)
    meta = modelo.guardar(out)
    meta.update({"clases": list(CLASES), "umbral_crisis": args.umbral_crisis, "umbral_otros": args.umbral_otros, "n_train": len(X)})
    (out / "metadata.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    (out / "metrics.json").write_text(
        json.dumps({"validacion_cruzada": m_cv, "pruebas_trampa": m_test}, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"\nModelo y métricas guardados en {out}")


if __name__ == "__main__":
    main()
