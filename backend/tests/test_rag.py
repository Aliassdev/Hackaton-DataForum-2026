import pytest

from app.agent.perfil import extraer_perfil, franja
from app.rag.retrieve import get_recuperador


def test_extraer_perfil_de_prompt_elevenlabs():
    system = "Agent character description: Eres TuTurno...\nPerfil: edad=13; procedimiento=penal; rol=testigo; fase=antes.\nThe documentation..."
    assert extraer_perfil(system) == {"edad": 13, "procedimiento": "penal", "rol": "testigo", "fase": "antes", "franja": "12-13"}


def test_perfil_ignora_variables_sin_sustituir():
    assert extraer_perfil("Perfil: edad={{edad}}; rol=victima.") == {"rol": "victima"}


def test_franjas():
    assert [franja(e) for e in (12, 13, 14, 15, 16, 17)] == ["12-13", "12-13", "14-15", "14-15", "16-17", "16-17"]


@pytest.mark.skipif(get_recuperador() is None, reason="sin índice RAG construido")
def test_rag_encuentra_prueba_preconstituida():
    citas = [f.articulo_id for f in get_recuperador().buscar("qué es la prueba preconstituida", {"procedimiento": "penal", "rol": "testigo"})]
    assert "LECRIM-449bis" in citas or "LECRIM-449ter" in citas


@pytest.mark.skipif(get_recuperador() is None, reason="sin índice RAG construido")
def test_rag_devuelve_articulos_distintos():
    frags = get_recuperador().buscar("tengo derecho a un abogado", k=5)
    assert len({f.articulo_id for f in frags}) == len(frags) == 5


@pytest.mark.skipif(get_recuperador() is None, reason="sin índice RAG construido")
@pytest.mark.parametrize(
    ("pregunta", "consulta"),
    [
        ("¿Tengo que ver al que me pegó cuando declare?", "evitar confrontación visual del testigo menor con el investigado"),
        ("¿Me pueden juzgar con trece años?", "responsabilidad penal de los menores de catorce años"),
        ("¿Puedo pedir que borren unas fotos mías?", None),
    ],
)
def test_buscar_con_los_rankings_ya_calculados_da_lo_mismo(pregunta, consulta):
    """La reformulación va en paralelo con la búsqueda de la pregunta (app/agent/orquestador.py): pasar sus
    rankings ya calculados no puede cambiar el resultado."""
    rec = get_recuperador()
    perfil = {"procedimiento": "penal", "rol": "victima"}
    normal = rec.buscar(pregunta, perfil, k=6, consulta_juridica=consulta)
    en_paralelo = rec.buscar(pregunta, perfil, k=6, consulta_juridica=consulta, rankings_pregunta=rec.rankings(pregunta))
    assert [(f.id, f.puntuacion) for f in en_paralelo] == [(f.id, f.puntuacion) for f in normal]


@pytest.mark.parametrize(
    ("ficheros", "esperado"),
    [
        ({"cpu.max": "200000 100000\n"}, 2),  # cgroup v2 con cuota de 2 CPU
        ({"cpu.max": "150000 100000\n"}, 2),  # 1,5 CPU: se redondea hacia arriba
        ({"cpu.max": "max 100000\n"}, None),  # sin cuota: las de la afinidad
        ({"cpu/cpu.cfs_quota_us": "400000\n", "cpu/cpu.cfs_period_us": "100000\n"}, 4),  # cgroup v1
        ({"cpu/cpu.cfs_quota_us": "-1\n", "cpu/cpu.cfs_period_us": "100000\n"}, None),
        ({"cpu.max": "basura"}, None),
        ({}, None),
    ],
)
def test_cpus_disponibles_respeta_la_cuota_del_contenedor(tmp_path, monkeypatch, ficheros, esperado):
    from app.rag import retrieve

    monkeypatch.setattr(retrieve.os, "sched_getaffinity", lambda _: set(range(16)), raising=False)
    for nombre, contenido in ficheros.items():
        (tmp_path / nombre).parent.mkdir(parents=True, exist_ok=True)
        (tmp_path / nombre).write_text(contenido)
    assert retrieve.cpus_disponibles(tmp_path) == (esperado or 16)


def test_ajustar_hilos_openblas_con_uno_y_torch_sin_pasarse():
    import torch
    from threadpoolctl import threadpool_info

    from app.rag.retrieve import ajustar_hilos, cpus_disponibles

    hilos = ajustar_hilos()
    assert hilos == torch.get_num_threads() <= cpus_disponibles()
    assert all(i["num_threads"] == 1 for i in threadpool_info() if i["user_api"] == "blas")
