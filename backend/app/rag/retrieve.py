"""Capa 2: recuperación híbrida sobre las leyes.

1. BM25 (lematizador español): acierta términos exactos ("prueba preconstituida", "dispensa").
2. Denso (multilingual-e5): entiende lo coloquial ("ver la cara del que me hizo daño").
3. Fusión RRF (k=60): combina rankings sin tener que calibrar puntuaciones de escalas distintas.
4. Refuerzo por perfil: multiplica según la ley (content/rag_perfiles.json).
5. Agregación por artículo: se devuelven k artículos distintos con su mejor fragmento.

Hilos: numpy y scipy (OpenBLAS) arrancan un hilo por núcleo que se queda girando un rato después de cada producto
y le quita la CPU al codificador de torch. Con 32 núcleos, la parte densa de una consulta pasaba de unos 26 ms a
130 ms. Nuestros productos son pequeños (3841 × 768), así que OpenBLAS va con un hilo, y torch con tantos como CPU
tenga de verdad el contenedor (en un Space, la cuota del cgroup, no los núcleos de la máquina).
"""

import json
import logging
import math
import os
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
RE_MENORES = re.compile(r"\bmenor(es)?\b|\bniñ[oa]s?\b|adolescente|\bhijos?\b|menor de edad|catorce años|dieciocho años", re.IGNORECASE)
PESO_MENORES = 1.3
# Peso de la consulta jurídica frente a la pregunta original. Probados 1, 1,5, 2, 3 y "solo consulta"
# con el conjunto de referencia: ninguno mejora a 1,0 (diferencias de una pregunta), así que se deja en 1.
PESO_CONSULTA = 1.0


def texto_denso(t: dict) -> str:
    return f"passage: {t['cabecera']}. {t['contexto']}\n{t['texto']}"


def texto_bm25(t: dict) -> str:
    return f"{t['cabecera']} {t['texto']}"


def _cuota_cgroup(raiz: Path) -> float | None:
    """CPU de la cuota del contenedor, o None si no la hay. cgroup v2: cpu.max («200000 100000» = 2 CPU; «max» = sin
    cuota). cgroup v1: cpu/cpu.cfs_quota_us (-1 = sin cuota) y cpu/cpu.cfs_period_us."""
    try:
        cuota, periodo = (raiz / "cpu.max").read_text().split()[:2]
    except (OSError, ValueError):
        try:
            cuota = (raiz / "cpu/cpu.cfs_quota_us").read_text().strip()
            periodo = (raiz / "cpu/cpu.cfs_period_us").read_text().strip()
        except OSError:
            return None
    try:
        return int(cuota) / int(periodo) if cuota not in ("max", "-1") and int(periodo) > 0 else None
    except ValueError:
        return None


def cpus_disponibles(raiz_cgroup: Path = Path("/sys/fs/cgroup")) -> int:
    """CPU que puede usar el proceso: las de su afinidad, limitadas por la cuota del contenedor si la hay."""
    try:
        cpus = len(os.sched_getaffinity(0))
    except AttributeError:  # Windows y macOS no tienen afinidad
        cpus = os.cpu_count() or 1
    cuota = _cuota_cgroup(raiz_cgroup)
    return max(1, min(cpus, math.ceil(cuota))) if cuota else cpus


def ajustar_hilos() -> int:
    """OpenBLAS con un hilo y torch con las CPU reales (ver el docstring del módulo). Devuelve los hilos de torch."""
    import torch
    from threadpoolctl import threadpool_limits

    threadpool_limits(limits=1, user_api="blas")
    hilos = min(torch.get_num_threads(), cpus_disponibles())
    torch.set_num_threads(hilos)
    return hilos


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
        hilos = ajustar_hilos()
        self.rankings("calentamiento")  # la primera codificación es más lenta: que no le toque a nadie
        log.info("RAG cargado: %d trozos (%d hablan de menores) · torch con %d hilos", len(self.trozos), sum(self.habla_de_menores), hilos)

    # --- rankings individuales (índices de trozo, de mejor a peor) ---
    def _denso(self, pregunta: str) -> list[int]:
        q = self.encoder.encode([f"query: {pregunta}"], normalize_embeddings=True, show_progress_bar=False)[0]
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

    def rankings(self, consulta: str, modo: str = "hibrido_perfil") -> list[list[int]]:
        """Rankings de una consulta (BM25 y denso, o solo uno según el modo), en el orden en que se fusionan."""
        funciones = {"bm25": [self._bm25], "denso": [self._denso]}.get(modo, [self._bm25, self._denso])
        return [f(consulta) for f in funciones]

    def buscar(
        self, pregunta: str, perfil: dict | None = None, k: int = 5, modo: str = "hibrido_perfil",
        consulta_juridica: str | None = None, peso_consulta: float = PESO_CONSULTA,
        rankings_pregunta: list[list[int]] | None = None,
    ) -> list[Fragmento]:
        """consulta_juridica: reformulación de la pregunta en lenguaje de la ley (la genera el LLM).
        Si llega, se busca con las dos consultas y se fusionan los cuatro rankings con RRF ponderado:
        la consulta jurídica pesa más (habla el idioma de la ley) y la pregunta original queda como
        red de seguridad por si la reformulación sale mal.
        rankings_pregunta: los de la pregunta original ya calculados con rankings(pregunta, modo), mientras el LLM
        reformulaba (app/agent/orquestador.py). El resultado es el mismo que sin ellos."""
        inicio = time.perf_counter()
        listas = [(r, 1.0) for r in (rankings_pregunta if rankings_pregunta is not None else self.rankings(pregunta, modo))]
        if consulta_juridica:
            listas += [(r, peso_consulta) for r in self.rankings(consulta_juridica, modo)]
        puntos: dict[int, float] = {}
        for ranking, peso in listas:
            for pos, i in enumerate(ranking):
                puntos[int(i)] = puntos.get(int(i), 0.0) + peso / (K_RRF + pos + 1)
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
