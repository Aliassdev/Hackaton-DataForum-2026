"""Capa 2: recuperación híbrida sobre las leyes.

1. BM25 (lematizador español): acierta términos exactos ("prueba preconstituida", "dispensa").
2. Denso (multilingual-e5): entiende lo coloquial ("ver la cara del que me hizo daño").
3. Fusión RRF (k=60): combina rankings sin tener que calibrar puntuaciones de escalas distintas.
4. Refuerzo por perfil: multiplica según la ley (content/rag_perfiles.json).
5. Agregación por artículo: se devuelven k artículos distintos con su mejor fragmento.
"""

import json
import logging
import re
import time
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

import numpy as np

log = logging.getLogger("tuturno.rag")

ENCODER = "intfloat/multilingual-e5-base"
K_RRF = 60
CANDIDATOS = 100
MODOS = ("bm25", "denso", "hibrido", "hibrido_perfil", "completo")
# Prior de dominio (fijado a priori): en códigos generales como LECrim o LEC, los artículos que
# mencionan a menores son mucho más probables como respuesta para nuestro público.
RE_MENORES = re.compile(r"\bmenor(es)?\b|\bniñ[oa]s?\b|adolescente|\bhijos?\b|menor de edad|catorce años|dieciocho años", re.I)
PESO_MENORES = 1.3


def texto_denso(t: dict) -> str:
    return f"passage: {t['cabecera']}. {t['contexto']}\n{t['texto']}"


def texto_bm25(t: dict) -> str:
    return f"{t['cabecera']} {t['texto']}"


def tokenizar(textos: list[str]):
    import bm25s
    import Stemmer

    return bm25s.tokenize(textos, stopwords="es", stemmer=Stemmer.Stemmer("spanish"), show_progress=False)


@dataclass
class Fragmento:
    id: str
    articulo_id: str
    ley: str
    cita: str  # "LORPM art. 22"
    titulo: str
    texto: str
    url: str
    puntuacion: float


class Recuperador:
    def __init__(self, index_dir: Path, perfiles_path: Path):
        import bm25s
        from sentence_transformers import SentenceTransformer

        self.trozos = [json.loads(l) for l in (index_dir / "trozos.jsonl").read_text(encoding="utf-8").splitlines()]
        self.emb = np.load(index_dir / "emb.npy")
        self.bm25 = bm25s.BM25.load(index_dir / "bm25")
        self.encoder = SentenceTransformer(ENCODER)
        self.perfiles = json.loads(perfiles_path.read_text(encoding="utf-8"))
        self.habla_de_menores = [bool(RE_MENORES.search(t["texto"])) for t in self.trozos]
        log.info("RAG cargado: %d trozos (%d hablan de menores)", len(self.trozos), sum(self.habla_de_menores))

    # --- rankings individuales (índices de trozo, de mejor a peor) ---
    def _denso(self, pregunta: str) -> list[int]:
        q = self.encoder.encode([f"query: {pregunta}"], normalize_embeddings=True)[0]
        return list(np.argsort(-(self.emb @ q))[:CANDIDATOS])

    def _bm25(self, pregunta: str) -> list[int]:
        docs, _ = self.bm25.retrieve(tokenizar([pregunta]), k=CANDIDATOS, show_progress=False)
        return list(docs[0])

    def peso_perfil(self, ley: str, perfil: dict | None) -> float:
        p = self.perfiles
        peso = p["base"].get(ley, 1.0)
        if perfil:
            peso *= p["procedimiento"].get(perfil.get("procedimiento") or "", {}).get(ley, 1.0)
            peso *= p["rol"].get(perfil.get("rol") or "", {}).get(ley, 1.0)
        return peso

    def buscar(
        self, pregunta: str, perfil: dict | None = None, k: int = 5, modo: str = "hibrido_perfil",
        consulta_juridica: str | None = None,
    ) -> list[Fragmento]:
        """consulta_juridica: reformulación de la pregunta en lenguaje de la ley (la genera el LLM).
        Si llega, se busca con las dos consultas y se fusionan los cuatro rankings."""
        inicio = time.perf_counter()
        funciones = {"bm25": [self._bm25], "denso": [self._denso]}.get(modo, [self._bm25, self._denso])
        consultas = [pregunta] + ([consulta_juridica] if consulta_juridica else [])
        puntos: dict[int, float] = {}
        for ranking in (f(c) for c in consultas for f in funciones):
            for pos, i in enumerate(ranking):
                puntos[int(i)] = puntos.get(int(i), 0.0) + 1.0 / (K_RRF + pos + 1)
        if modo in ("hibrido_perfil", "completo"):
            puntos = {i: s * self.peso_perfil(self.trozos[i]["ley"], perfil) for i, s in puntos.items()}
        if modo == "completo":
            puntos = {i: s * (PESO_MENORES if self.habla_de_menores[i] else 1.0) for i, s in puntos.items()}

        # Agregación por artículo: el mejor fragmento representa al artículo
        vistos, salida = set(), []
        for i in sorted(puntos, key=puntos.get, reverse=True):
            t = self.trozos[i]
            if t["articulo_id"] in vistos:
                continue
            vistos.add(t["articulo_id"])
            salida.append(Fragmento(
                id=t["id"], articulo_id=t["articulo_id"], ley=t["ley"], cita=f"{t['ley_corta']} art. {t['articulo']}",
                titulo=t["titulo"], texto=t["texto"], url=t["url"], puntuacion=puntos[i],
            ))
            if len(salida) == k:
                break
        log.debug("RAG %s: %.0f ms", modo, (time.perf_counter() - inicio) * 1000)
        return salida


@lru_cache
def get_recuperador() -> Recuperador | None:
    from app.config import settings

    if not (settings.rag_index_dir / "emb.npy").exists():
        log.warning("Sin índice RAG en %s: ejecuta ml/ingest_leyes.py y ml/build_index.py", settings.rag_index_dir)
        return None
    return Recuperador(settings.rag_index_dir, settings.content_dir / "rag_perfiles.json")
