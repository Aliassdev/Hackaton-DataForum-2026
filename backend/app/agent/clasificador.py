"""Clasificador de intención del guardrail: crisis, hechos, fuera_de_ambito o normal.

Dos variantes con la misma interfaz (las entrena ml/train_guardrail.py):
- "embeddings_lr": embeddings multilingual-e5 + regresión logística (línea base).
- "finetuned": transformer en español con ajuste fino completo.
"""

import json
from pathlib import Path

import numpy as np

CLASES = ("crisis", "hechos", "fuera_de_ambito", "normal")


def decidir(probs: dict[str, float], umbral_crisis: float, umbral_otros: float) -> str:
    """Crisis tiene umbral propio y bajo (preferimos falsos positivos). El resto, la clase más
    probable si supera umbral_otros; si no, normal (el LLM y la verificación siguen protegiendo)."""
    if probs["crisis"] >= umbral_crisis:
        return "crisis"
    resto = {c: p for c, p in probs.items() if c != "crisis"}
    mejor = max(resto, key=resto.get)
    return mejor if mejor == "normal" or resto[mejor] >= umbral_otros else "normal"


class ClasificadorEmbeddingsLR:
    def __init__(self, directorio: Path, meta: dict):
        import joblib
        from sentence_transformers import SentenceTransformer

        self.encoder = SentenceTransformer(meta["encoder"])
        self.lr = joblib.load(directorio / "lr.joblib")
        self.clases = list(self.lr.classes_)

    def probabilidades(self, textos: list[str]) -> list[dict[str, float]]:
        emb = self.encoder.encode([f"query: {t}" for t in textos], normalize_embeddings=True)
        return [dict(zip(self.clases, map(float, fila))) for fila in self.lr.predict_proba(emb)]


class ClasificadorFinetuned:
    def __init__(self, directorio: Path, meta: dict):
        import torch
        from transformers import AutoModelForSequenceClassification, AutoTokenizer

        self.torch = torch
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.tok = AutoTokenizer.from_pretrained(directorio)
        self.model = AutoModelForSequenceClassification.from_pretrained(directorio).to(self.device).eval()
        self.clases = [self.model.config.id2label[i] for i in range(self.model.config.num_labels)]
        self.max_len = meta.get("max_len", 64)

    def probabilidades(self, textos: list[str]) -> list[dict[str, float]]:
        enc = self.tok(textos, truncation=True, max_length=self.max_len, padding=True, return_tensors="pt").to(self.device)
        with self.torch.no_grad():
            probs = self.torch.softmax(self.model(**enc).logits, dim=-1).cpu().numpy()
        return [dict(zip(self.clases, map(float, fila))) for fila in np.atleast_2d(probs)]


def cargar(directorio: Path):
    meta = json.loads((directorio / "metadata.json").read_text(encoding="utf-8"))
    tipos = {"embeddings_lr": ClasificadorEmbeddingsLR, "finetuned": ClasificadorFinetuned}
    return tipos[meta["tipo"]](directorio, meta), meta
