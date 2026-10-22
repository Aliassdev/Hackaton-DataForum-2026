"""Capa 2: recuperación híbrida sobre las leyes.

1. BM25 (lematizador español): acierta términos exactos ("prueba preconstituida", "dispensa").
2. Denso (multilingual-e5): entiende lo coloquial ("ver la cara del que me hizo daño").
3. Fusión RRF (k=60): combina rankings sin tener que calibrar puntuaciones de escalas distintas.
4. Refuerzo por perfil: multiplica según la ley (content/rag_perfiles.json).
5. Agregación por artículo: se devuelven k artículos distintos con su mejor fragmento.

Además de las leyes, el índice tiene fuentes validadas (ml/fuentes_validadas.py): el glosario de la app y las citas
literales de docs/MARCO_LEGAL.md. Sus trozos traen su propia etiqueta de cita («Glosario TuTurno · Sala Gesell (Ley
4/2015, art. 25.1; ...)», «LORPM art. 28.1», «AEPD · Canal prioritario») y la norma y el artículo que enseña la app.
Una cita del marco legal lleva el id de su artículo (LORPM-28): compite con el texto completo del artículo y se queda
el mejor de los dos.

Hilos: numpy y scipy (OpenBLAS) arrancan un hilo por núcleo que se queda girando un rato después de cada producto
y le quita la CPU al codificador de torch. Con 32 núcleos, la parte densa de una consulta pasaba de unos 26 ms a
130 ms. Nuestros productos son pequeños (unos 4000 × 768), así que OpenBLAS va con un hilo, y torch con tantos como CPU
tenga de verdad el contenedor (en un Space, la cuota del cgroup, no los núcleos de la máquina).

Concurrencia: las consultas del modo denso se codifican por lotes desde un solo hilo (Codificador). Es lo que más CPU
gasta (unos 60 ms por consulta con 2 hilos, y cada pregunta lleva dos: la original y la jurídica), y en las 2 vCPU del
Space 30 preguntas a la vez tardaban casi 5 s solo en esta parte.
"""

import hashlib
import json
import logging
import math
import os
import re
import threading
import time
import unicodedata
from collections import OrderedDict
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from typing import Any, Protocol

import numpy as np

from app.agent.verificacion import numero_a_letras

log = logging.getLogger("tuturno.rag")

ENCODER = "intfloat/multilingual-e5-base"
K_RRF = 60
CANDIDATOS = 100
MAX_LOTE = 64  # consultas por lote del codificador
CACHE_CONSULTAS = 512  # vectores de consulta recordados, por el resumen SHA-256 del texto (unos 1,5 MB)
ESPERA_MAX_S = 20.0  # si el codificador no contesta en este tiempo, la petición falla (y la voz dice la respuesta segura)
MODOS = ("bm25", "denso", "hibrido", "hibrido_perfil", "completo")
# Prior de dominio (fijado a priori): en códigos generales como LECrim o LEC, los artículos que
# mencionan a menores son mucho más probables como respuesta para nuestro público.
RE_MENORES = re.compile(r"\bmenor(es)?\b|\bniñ[oa]s?\b|adolescente|\bhijos?\b|menor de edad|catorce años|dieciocho años", re.IGNORECASE)
PESO_MENORES = 1.3
# Edades como las escribe la ley (SEGURIDAD.md, 7.2): con letras y por tramos («menor de catorce años», «mayores de catorce
# años y menores de dieciocho»), mientras que quien pregunta escribe «tengo 13 años». A la consulta BM25 se le añaden la
# edad con letras y su tramo. Con «Tengo 13 años y he hecho algo malo, ¿me pueden juzgar?», el artículo 3 de la LORPM
# pasa del 6.º al 2.º puesto. Solo BM25: el codificador denso ya relaciona «13» y «trece».
RE_EDAD = re.compile(r"\b(\d{1,2})\s+años\b")
TRAMO_MENOR_14 = "menor de catorce años"
TRAMO_14_A_17 = "mayores de catorce años y menores de dieciocho"
# Términos del glosario validado nombrados en la pregunta (revisión jurídica del 22/10/2026): si alguien pregunta por la
# «Fiscalía de Menores», el «acoso escolar» o el «juicio», la definición validada de ese término entra siempre entre los
# fragmentos. Con la reformulación, «la Fiscalía de Menores» pasaba a «el Ministerio Fiscal» y la definición se quedaba
# fuera, por detrás de la LOPIVI 53 y 55 (centros de protección), que el LLM aplicaba a los institutos. Como mucho dos,
# los más largos primero; un término dentro de otro ya nombrado no cuenta («Fiscalía» en «Fiscalía de Menores»).
MAX_TERMINOS_GLOSARIO = 2
GLOSARIO = "GLOSARIO"
PREFIJO_GLOSARIO = "Glosario TuTurno · "


def _normalizar_termino(texto: str) -> str:
    """Minúsculas, sin tildes y con un solo espacio: «¿Qué es la Sala   Gesell?» → «¿que es la sala gesell?»."""
    texto = unicodedata.normalize("NFD", texto.lower())
    return re.sub(r"\s+", " ", "".join(c for c in texto if unicodedata.category(c) != "Mn"))


# También con otra forma de la palabra («denunciar» → «Denuncia»), por las raíces del lematizador de BM25. Los términos
# de una palabra muy generales no se fuerzan: «víctima», «declarar» o «juicio» salen en muchas preguntas sin ser de lo
# que tratan, y su definición quitaba el sitio a un artículo relevante (medido con las 61 preguntas del conjunto de
# evaluación y las consultas reales guardadas: «qué derechos tengo si soy víctima» perdía la LORPM 4 por G-victima).
TERMINOS_GENERICOS = frozenset({"victima", "testigo", "declaracion", "juicio", "medida", "sentencia", "expediente", "intimidad"})


@lru_cache(maxsize=256)
def _raices(texto: str) -> tuple[str, ...]:
    import Stemmer

    return tuple(Stemmer.Stemmer("spanish").stemWords(re.findall(r"\w+", texto)))


def _contiene(secuencia: tuple[str, ...], parte: tuple[str, ...]) -> bool:
    return bool(parte) and any(secuencia[i : i + len(parte)] == parte for i in range(len(secuencia) - len(parte) + 1))


def terminos_nombrados(pregunta: str, terminos: dict[str, int], maximo: int = MAX_TERMINOS_GLOSARIO) -> list[int]:
    """Índices de los trozos del glosario cuyo término aparece en la pregunta: tal cual (palabras enteras, sin tildes ni
    mayúsculas) o con otra forma de las mismas palabras. terminos: término normalizado → índice del trozo."""
    texto = _normalizar_termino(pregunta)
    raices = _raices(texto)
    elegidos: list[str] = []
    for termino in sorted(terminos, key=len, reverse=True):
        if len(elegidos) == maximo:
            break
        if termino in TERMINOS_GENERICOS or any(termino in otro for otro in elegidos):
            continue
        if re.search(rf"(?<!\w){re.escape(termino)}(?!\w)", texto) or _contiene(raices, _raices(termino)):
            elegidos.append(termino)
    return [terminos[t] for t in elegidos]


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


def edades_de_la_ley(consulta: str) -> str:
    """La consulta con cada edad «N años» también con letras y, si va de 10 a 17, con su tramo de la ley."""
    extra = []
    for m in RE_EDAD.finditer(consulta):
        n = int(m.group(1))
        extra.append(f"{numero_a_letras(n)} años")
        if 10 <= n <= 13:
            extra.append(TRAMO_MENOR_14)
        elif 14 <= n <= 17:
            extra.append(TRAMO_14_A_17)
    return f"{consulta} {' '.join(extra)}" if extra else consulta


def tokenizar(textos: list[str]):
    import bm25s
    import Stemmer

    return bm25s.tokenize(textos, stopwords="es", stemmer=Stemmer.Stemmer("spanish"), show_progress=False)


class Encoder(Protocol):
    """Lo que el Codificador usa de SentenceTransformer."""

    def encode(self, textos: list[str], **opciones: Any) -> np.ndarray: ...


@dataclass(eq=False)
class _Encargo:
    clave: bytes
    texto: str
    listo: threading.Event = field(default_factory=threading.Event)
    vector: np.ndarray | None = None
    error: BaseException | None = None


class Codificador:
    """Codifica consultas con el modelo denso por lotes dinámicos, desde un solo hilo.

    Antes, cada hilo de petición llamaba a encode() por su cuenta. Con muchas preguntas a la vez, en las 2 vCPU del
    Space los hilos de torch de todas las peticiones se pisaban, y cada consulta costaba lo de varias. Ahora cada
    petición deja su consulta en una cola y espera; un único hilo coge todo lo pendiente, sin repetidos, y lo codifica
    de una vez. Con una sola petición no cambia nada: es un lote de uno y no se espera a nadie. Con muchas a la vez,
    una consulta en lote cuesta unos 25 ms en vez de 60 (medido con 2 hilos de CPU), y en la práctica 30 preguntas
    simultáneas pasan de 3,9 s a 2,3 s en esta parte.

    Además recuerda los últimos vectores por el resumen SHA-256 del texto (nunca guarda el texto): las preguntas de
    ejemplo de la app llegan idénticas muchas veces, y su consulta jurídica suele repetirse también.
    """

    def __init__(self, encoder: Encoder, max_lote: int = MAX_LOTE, cache: int = CACHE_CONSULTAS, espera_max_s: float = ESPERA_MAX_S) -> None:
        self.encoder = encoder
        self.max_lote = max_lote
        self.tam_cache = cache
        self.espera_max_s = espera_max_s
        self._cond = threading.Condition()
        self._pendientes: list[_Encargo] = []
        self._cache: OrderedDict[bytes, np.ndarray] = OrderedDict()
        self.lotes = 0  # cuántas veces se ha llamado a encode() (para las pruebas)
        threading.Thread(target=self._trabajar, name="codificador", daemon=True).start()

    @staticmethod
    def _clave(texto: str) -> bytes:
        return hashlib.sha256(texto.encode("utf-8")).digest()

    def codificar(self, texto: str) -> np.ndarray:
        """Vector normalizado del texto, como encoder.encode([texto], normalize_embeddings=True)[0]."""
        clave = self._clave(texto)
        with self._cond:
            if (vector := self._cache.get(clave)) is not None:
                self._cache.move_to_end(clave)
                return vector
            encargo = _Encargo(clave, texto)
            self._pendientes.append(encargo)
            self._cond.notify()
        if not encargo.listo.wait(self.espera_max_s):
            with self._cond:
                if encargo in self._pendientes:
                    self._pendientes.remove(encargo)
            raise TimeoutError(f"El codificador no ha respondido en {self.espera_max_s:.0f} s")
        if encargo.error is not None:
            raise encargo.error
        if encargo.vector is None:  # el hilo ha terminado sin vector ni error: no debería pasar
            raise RuntimeError("El codificador no ha devuelto ningún vector")
        return encargo.vector

    def _trabajar(self) -> None:
        while True:
            with self._cond:
                while not self._pendientes:
                    self._cond.wait()
                lote = self._pendientes[: self.max_lote]
                del self._pendientes[: self.max_lote]
            try:
                unicos = list(dict.fromkeys(e.texto for e in lote))
                vectores = self.encoder.encode(unicos, normalize_embeddings=True, show_progress_bar=False, batch_size=len(unicos))
                por_texto = {}
                for texto, fila in zip(unicos, vectores, strict=True):
                    vector = np.array(fila, copy=True)  # copia: una vista mantendría vivo el lote entero en la caché
                    vector.flags.writeable = False  # compartido entre peticiones
                    por_texto[texto] = vector
                self.lotes += 1
                with self._cond:
                    for e in lote:
                        e.vector = por_texto[e.texto]
                        self._cache[e.clave] = e.vector
                        self._cache.move_to_end(e.clave)
                    while len(self._cache) > self.tam_cache:
                        self._cache.popitem(last=False)
                if len(unicos) > 1:
                    log.debug("Codificador: lote de %d consultas", len(unicos))
            except Exception as error:  # noqa: BLE001 - el fallo se entrega a cada petición del lote, y el hilo sigue
                for e in lote:
                    e.error = error
            finally:
                for e in lote:
                    e.texto = ""  # el texto no se queda en memoria más de lo necesario
                    e.listo.set()


@dataclass
class Fragmento:
    id: str
    articulo_id: str
    ley: str
    cita: str  # "LORPM art. 22", "Glosario TuTurno · Sala Gesell (Ley 4/2015, art. 25.1; ...)", "AEPD · Canal prioritario"
    titulo: str
    texto: str
    url: str
    puntuacion: float
    # Lo que enseña la app en la etiqueta de la fuente (contrato 8.1). None en los artículos de ley: se saca de la cita
    norma: str | None = None
    articulo: str | None = None
    # Parte de la ley en la que está el artículo («TÍTULO IV. De las actuaciones en centros de protección»). Solo en los
    # artículos de ley: el prompt la enseña para que no se aplique un artículo fuera de su sitio
    contexto: str | None = None


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
        self.terminos_glosario = {
            _normalizar_termino((t.get("norma") or "").removeprefix(PREFIJO_GLOSARIO)): i
            for i, t in enumerate(self.trozos) if t["ley"] == GLOSARIO and t.get("norma")
        }
        # Pesos por parte de la ley (rag_perfiles.json, «contexto»): por ejemplo, los artículos de la LOPIVI sobre los
        # centros de protección pesan menos salvo en un procedimiento de protección
        self.reglas_contexto = [
            (i, regla) for i, t in enumerate(self.trozos) for regla in self.perfiles.get("contexto", [])
            if t["ley"] == regla["ley"] and t.get("contexto", "").startswith(regla["empieza"])
        ]
        hilos = ajustar_hilos()
        self.codificador = Codificador(self.encoder)  # con los hilos de torch ya ajustados
        self.rankings("calentamiento")  # la primera codificación es más lenta: que no le toque a nadie
        log.info("RAG cargado: %d trozos (%d hablan de menores) · torch con %d hilos", len(self.trozos), sum(self.habla_de_menores), hilos)

    # --- rankings individuales (índices de trozo, de mejor a peor) ---
    def _denso(self, pregunta: str) -> list[int]:
        q = self.codificador.codificar(f"query: {pregunta}")
        return list(np.argsort(-(self.emb @ q))[:CANDIDATOS])

    def _bm25(self, pregunta: str) -> list[int]:
        docs, _ = self.bm25.retrieve(tokenizar([edades_de_la_ley(pregunta)]), k=CANDIDATOS, show_progress=False)
        return list(docs[0])

    def peso_perfil(self, ley: str, perfil: dict | None) -> float:
        p = self.perfiles
        peso = p["base"].get(ley, 1.0)
        if perfil:
            peso *= p["procedimiento"].get(perfil.get("procedimiento") or "", {}).get(ley, 1.0)
            peso *= p["rol"].get(perfil.get("rol") or "", {}).get(ley, 1.0)
        return peso

    def pesos_contexto(self, perfil: dict | None) -> dict[int, float]:
        """Peso de cada trozo según la parte de la ley en la que está (solo los que tienen regla)."""
        procedimiento = (perfil or {}).get("procedimiento") or ""
        return {i: regla["peso"] for i, regla in self.reglas_contexto if procedimiento not in regla.get("salvo_procedimiento", [])}

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
        forzados: list[int] = []
        if modo in ("hibrido_perfil", "completo"):
            contexto = self.pesos_contexto(perfil)
            puntos = {i: s * self.peso_perfil(self.trozos[i]["ley"], perfil) * contexto.get(i, 1.0) for i, s in puntos.items()}
            forzados = terminos_nombrados(pregunta, self.terminos_glosario)
        if modo == "completo":
            puntos = {i: s * (PESO_MENORES if self.habla_de_menores[i] else 1.0) for i, s in puntos.items()}

        # Agregación por artículo: el mejor fragmento representa al artículo. Los términos del glosario nombrados en la
        # pregunta entran siempre: ocupan el sitio de los últimos y luego todo va por puntuación.
        forzados = forzados[:k]
        ids_forzados = {self.trozos[i]["articulo_id"] for i in forzados}
        vistos, elegidos = set(ids_forzados), list(forzados)
        for i in sorted(puntos, key=puntos.get, reverse=True):
            if len(elegidos) == k:
                break
            if self.trozos[i]["articulo_id"] not in vistos:
                vistos.add(self.trozos[i]["articulo_id"])
                elegidos.append(i)
        elegidos.sort(key=lambda i: puntos.get(i, 0.0), reverse=True)
        salida = []
        for i in elegidos:
            t = self.trozos[i]
            norma = t.get("norma")  # solo las fuentes validadas: glosario y marco legal
            salida.append(Fragmento(
                id=t["id"], articulo_id=t["articulo_id"], ley=t["ley"], cita=t.get("cita") or f"{t['ley_corta']} art. {t['articulo']}",
                titulo=t["titulo"], texto=t["texto"], url=t["url"], puntuacion=puntos.get(i, 0.0),
                norma=norma, articulo=t.get("articulo", "") if norma is not None else None,
                contexto=(t.get("contexto") or None) if norma is None else None,
            ))
        log.debug("RAG %s: %.0f ms", modo, (time.perf_counter() - inicio) * 1000)
        return salida


@lru_cache
def get_recuperador() -> Recuperador | None:
    from app.config import settings

    if not (settings.rag_index_dir / "emb.npy").exists():
        log.warning("Sin índice RAG en %s: ejecuta ml/ingest_leyes.py y ml/build_index.py", settings.rag_index_dir)
        return None
    return Recuperador(settings.rag_index_dir, settings.content_dir / "rag_perfiles.json")
