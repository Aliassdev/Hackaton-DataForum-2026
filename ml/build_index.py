"""P4 · Índices del RAG: embeddings densos (multilingual-e5) + BM25 con lematizador español.

Uso, desde la raíz del repo (después de ml/ingest_leyes.py):
    backend/.venv/Scripts/python -X utf8 ml/build_index.py

Entrada: artifacts/corpus/trozos.jsonl
Salida:  artifacts/index/{trozos.jsonl, emb.npy, bm25/}

Con ~3.000 trozos, una matriz numpy normalizada (producto escalar = coseno) es más simple y rápida
que una base vectorial: ~9 MB en memoria y búsqueda exacta en milisegundos.
"""

import json
import shutil
import sys
import time
from pathlib import Path

import numpy as np

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "backend"))
from app.rag.retrieve import ENCODER, texto_bm25, texto_denso, tokenizar  # noqa: E402

CORPUS = RAIZ / "artifacts/corpus/trozos.jsonl"
SALIDA = RAIZ / "artifacts/index"


def main():
    import bm25s
    from sentence_transformers import SentenceTransformer

    trozos = [json.loads(l) for l in CORPUS.read_text(encoding="utf-8").splitlines()]
    SALIDA.mkdir(parents=True, exist_ok=True)
    shutil.copy(CORPUS, SALIDA / "trozos.jsonl")

    t0 = time.perf_counter()
    encoder = SentenceTransformer(ENCODER)
    emb = encoder.encode([texto_denso(t) for t in trozos], batch_size=32, normalize_embeddings=True, show_progress_bar=True)
    np.save(SALIDA / "emb.npy", emb.astype(np.float32))
    print(f"Embeddings: {emb.shape} en {time.perf_counter() - t0:.0f} s")

    retriever = bm25s.BM25()
    retriever.index(tokenizar([texto_bm25(t) for t in trozos]))
    retriever.save(SALIDA / "bm25")
    print(f"BM25 indexado ({len(trozos)} trozos). Índices en {SALIDA}")


if __name__ == "__main__":
    main()
