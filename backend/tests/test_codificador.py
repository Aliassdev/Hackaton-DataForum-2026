"""Codificador por lotes del RAG (app/rag/retrieve.py). Sin red; casi todo con un codificador de mentira."""

import hashlib
import threading
import time
from concurrent.futures import ThreadPoolExecutor

import numpy as np
import pytest

from app.rag.retrieve import Codificador, get_recuperador


def vector(texto: str) -> np.ndarray:
    semilla = int.from_bytes(hashlib.sha256(texto.encode()).digest()[:8], "little")
    v = np.random.default_rng(semilla).standard_normal(8).astype(np.float32)
    return v / np.linalg.norm(v)


class EncoderFalso:
    """Vector fijo por texto. Con `puerta`, la primera llamada espera dentro de encode() a que se abra: así las
    peticiones que llegan mientras tanto se juntan en el lote siguiente."""

    def __init__(self, puerta: threading.Event | None = None) -> None:
        self.llamadas: list[list[str]] = []
        self.puerta = puerta
        self.fallar = False

    def encode(self, textos: list[str], normalize_embeddings: bool, show_progress_bar: bool, batch_size: int) -> np.ndarray:
        assert normalize_embeddings and not show_progress_bar and batch_size == len(textos)
        self.llamadas.append(list(textos))
        if self.puerta is not None and len(self.llamadas) == 1:
            self.puerta.wait(5)
        if self.fallar:
            raise RuntimeError("codificador roto")
        return np.array([vector(t) for t in textos])


def esperar(condicion, segundos: float = 5.0) -> None:
    fin = time.monotonic() + segundos
    while not condicion():
        assert time.monotonic() < fin, "no se ha cumplido a tiempo"
        time.sleep(0.005)


def bloqueado(puerta: threading.Event) -> tuple[Codificador, EncoderFalso, ThreadPoolExecutor, object]:
    """Un codificador con su hilo atascado en la primera llamada, para ir juntando peticiones."""
    encoder = EncoderFalso(puerta)
    cod = Codificador(encoder)
    pool = ThreadPoolExecutor(16)
    primera = pool.submit(cod.codificar, "primera")
    esperar(lambda: len(encoder.llamadas) == 1)
    return cod, encoder, pool, primera


def test_una_consulta_sola_es_un_lote_de_uno():
    encoder = EncoderFalso()
    cod = Codificador(encoder)
    assert np.array_equal(cod.codificar("¿Qué es la Sala Gesell?"), vector("¿Qué es la Sala Gesell?"))
    assert encoder.llamadas == [["¿Qué es la Sala Gesell?"]]


def test_las_consultas_que_llegan_a_la_vez_van_en_un_solo_lote():
    puerta = threading.Event()
    cod, encoder, pool, primera = bloqueado(puerta)
    textos = [f"pregunta {i}" for i in range(10)]
    futuros = [pool.submit(cod.codificar, t) for t in textos]
    esperar(lambda: len(cod._pendientes) == 10)
    puerta.set()
    resultados = [f.result(5) for f in futuros]
    assert np.array_equal(primera.result(5), vector("primera"))
    assert len(encoder.llamadas) == 2 and sorted(encoder.llamadas[1]) == sorted(textos)
    for texto, v in zip(textos, resultados, strict=True):
        assert np.array_equal(v, vector(texto))


def test_los_textos_repetidos_de_un_lote_se_codifican_una_vez():
    puerta = threading.Event()
    cod, encoder, pool, _ = bloqueado(puerta)
    futuros = [pool.submit(cod.codificar, t) for t in ["igual"] * 5 + ["otra"]]
    esperar(lambda: len(cod._pendientes) == 6)
    puerta.set()
    resultados = [f.result(5) for f in futuros]
    assert sorted(encoder.llamadas[1]) == ["igual", "otra"]
    assert all(np.array_equal(v, vector("igual")) for v in resultados[:5])


def test_recuerda_por_el_resumen_y_no_guarda_el_texto():
    encoder = EncoderFalso()
    cod = Codificador(encoder, cache=2)
    v = cod.codificar("¿Qué hace la Fiscalía de Menores?")
    assert cod.codificar("¿Qué hace la Fiscalía de Menores?") is v and len(encoder.llamadas) == 1
    assert not v.flags.writeable  # compartido entre peticiones: nadie lo puede cambiar
    assert all(isinstance(k, bytes) and len(k) == 32 for k in cod._cache)
    assert "Fiscalía".encode() not in b"".join(cod._cache)
    cod.codificar("b")
    cod.codificar("c")  # se olvida la más antigua
    cod.codificar("¿Qué hace la Fiscalía de Menores?")
    assert len(encoder.llamadas) == 4 and len(cod._cache) == 2


def test_un_fallo_llega_a_quien_espera_y_el_hilo_sigue_trabajando():
    encoder = EncoderFalso()
    encoder.fallar = True
    cod = Codificador(encoder)
    with pytest.raises(RuntimeError, match="codificador roto"):
        cod.codificar("a")
    encoder.fallar = False
    assert np.array_equal(cod.codificar("b"), vector("b"))
    assert cod._cache and len(cod._cache) == 1  # lo que falló no se recuerda


def test_si_el_codificador_no_contesta_la_peticion_no_se_queda_colgada():
    puerta = threading.Event()
    encoder = EncoderFalso(puerta)
    cod = Codificador(encoder, espera_max_s=0.2)
    with pytest.raises(TimeoutError):
        cod.codificar("primera")  # el hilo se queda atascado con ella
    with pytest.raises(TimeoutError):
        cod.codificar("segunda")  # ni siquiera ha salido de la cola
    assert cod._pendientes == []  # quien se va no deja trabajo pendiente
    puerta.set()
    esperar(lambda: len(cod._cache) == 1)
    assert np.array_equal(cod.codificar("tercera"), vector("tercera"))


@pytest.mark.skipif(get_recuperador() is None, reason="sin índice RAG construido")
def test_con_el_modelo_real_el_lote_da_los_mismos_vectores():
    rec = get_recuperador()
    textos = [f"query: ¿Puedo ir con alguien cuando declare? ({i})" for i in range(8)]
    solos = rec.encoder.encode(textos, normalize_embeddings=True, show_progress_bar=False, batch_size=1)
    with ThreadPoolExecutor(8) as pool:
        juntos = list(pool.map(rec.codificador.codificar, textos))
    for a, b in zip(solos, juntos, strict=True):
        assert np.allclose(a, b, atol=1e-5)
