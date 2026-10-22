import logging

import httpx

from app.agent import orquestador, prompts
from app.agent.pii import limpiar
from app.llm.client import ErrorLLM

PERFIL = {"edad": 13, "procedimiento": "penal", "rol": "testigo", "fase": "antes", "franja": "12-13"}
MENSAJES = [
    {"role": "system", "content": "prompt genérico de ElevenLabs"},
    {"role": "assistant", "content": "Hola, soy TuTurno."},
    {"role": "user", "content": "me llamo Ana, mi móvil es 612 345 678, ¿tengo que ir a declarar?"},
]


def test_pii_limpia_dni_telefono_y_correo():
    texto = limpiar("DNI 12345678Z, tel 612 345 678, correo ana@ejemplo.com")
    assert "12345678Z" not in texto and "612 345 678" not in texto and "ana@ejemplo.com" not in texto


def test_pii_limpia_nombre_centro_y_localidad():
    """Pruebas adversariales (22/10/2026): el nombre y el instituto llegaban al LLM tal cual."""
    assert limpiar("soy Sergio Martin Ruiz del IES Cervantes de Leganes, la fiscalia puede venir?") == "soy [DATO] del IES [DATO], la fiscalia puede venir?"
    assert limpiar("me llamo Lucia Fernandez Gil, vivo en calle Mayor 12 de Getafe y mi movil es 612 345 678") == (
        "me llamo [DATO], vivo en [DATO] y mi movil es [DATO]"
    )
    assert limpiar("me llamo lucía y tengo 11 años") == "me llamo [DATO] y tengo 11 años"
    assert limpiar("vivo en Madrid con mi madre y voy al colegio San José") == "vivo en [DATO] con mi madre y voy al colegio [DATO]"
    assert limpiar("llámame al 612 34 56 78 o al +34 699-123-456") == "llámame al [DATO] o al [DATO]"


def test_pii_no_toca_lo_que_no_es_un_dato():
    for texto in ("soy testigo y tengo 13 años", "soy víctima de acoso", "Hola, soy TuTurno. ¿Qué quieres saber?", "me llamo la fiscal para declarar",
                  "la Ley 8/2021 y el caso 1612345678", "llama al 116 111 o al 112", "voy al insti y me acosan"):
        assert limpiar(texto) == texto


def test_prompt_adapta_franja_y_perfil():
    s = prompts.sistema(PERFIL, [])
    assert "12 o 13 años" in s and "testigo" in s and "antes del juicio" in s
    assert "nunca de los hechos" in s.lower()


def test_responder_no_envia_datos_personales_ni_prompt_de_elevenlabs(monkeypatch):
    enviado = {}

    def falso_stream(mensajes, modelo, **k):
        enviado["mensajes"] = mensajes
        return iter(["Sí, ", "tienes que ir."])

    monkeypatch.setattr(orquestador.client, "completar", lambda *a, **k: "obligación de comparecer del testigo")
    monkeypatch.setattr(orquestador.client, "stream", falso_stream)
    respuesta = "".join(orquestador.responder(MENSAJES, PERFIL)).strip()

    assert respuesta == "Sí, tienes que ir."
    contenido = " ".join(m["content"] for m in enviado["mensajes"])
    assert "612 345 678" not in contenido
    assert "prompt genérico de ElevenLabs" not in contenido
    assert enviado["mensajes"][0]["role"] == "system" and "FRAGMENTOS DE LA LEY" in enviado["mensajes"][0]["content"]


def test_responder_da_respuesta_segura_si_falla_el_llm(monkeypatch):
    def falla(*a, **k):
        raise ErrorLLM("429")

    monkeypatch.setattr(orquestador.client, "completar", falla)
    monkeypatch.setattr(orquestador.client, "stream", falla)
    assert "".join(orquestador.responder(MENSAJES, PERFIL)) == orquestador.RESPUESTA_SEGURA


def test_errores_del_llm_sin_el_cuerpo_del_proveedor_en_el_log(recuperador, ajustar, monkeypatch, caplog):
    """El cuerpo de un error de Groq puede repetir lo que había generado el modelo: al log solo va «LLM 400»."""

    def falla(*a, **k):
        raise ErrorLLM('LLM 400: {"error": {"code": "tool_use_failed", "failed_generation": "lo que contó el menor"}}')

    ajustar(orquestador, llm_api_key="clave-falsa")  # con clave, antes se intenta reformular
    monkeypatch.setattr(orquestador.client, "completar", falla)
    monkeypatch.setattr(orquestador.client, "stream", falla)
    caplog.set_level(logging.INFO)
    assert "".join(orquestador.responder(MENSAJES, PERFIL)) == orquestador.RESPUESTA_SEGURA
    assert "Reformulación fallida (ErrorLLM: LLM 400)" in caplog.text and "Generación fallida: ErrorLLM: LLM 400" in caplog.text
    assert "lo que contó el menor" not in caplog.text


def test_si_la_reformulacion_no_responde_se_busca_con_la_pregunta_original(recuperador, ajustar, monkeypatch):
    """La reformulación es opcional: un fallo de red en ella no puede dejar callado al agente."""

    def sin_red(*a, **k):
        raise httpx.ReadTimeout("sin respuesta")

    ajustar(orquestador, llm_api_key="clave-falsa")
    monkeypatch.setattr(orquestador.client, "completar", sin_red)
    monkeypatch.setattr(orquestador.client, "stream", lambda *a, **k: iter(["Sí, ", "puedes ir con alguien."]))
    assert "".join(orquestador.responder(MENSAJES, PERFIL)).strip() == "Sí, puedes ir con alguien."
    assert recuperador.llamadas[0]["consulta"] is None


def test_limpiar_consulta_juridica():
    assert orquestador.limpiar_consulta('"sala Gesell" en el proceso\nexplicación') == "sala Gesell en el proceso"
    assert orquestador.limpiar_consulta("abcabc") == "abc"  # escrita dos veces seguidas
    assert orquestador.limpiar_consulta("   ") is None and orquestador.limpiar_consulta(None) is None


def test_reformulacion_con_el_vocabulario_de_la_ley():
    """La consulta jurídica usa las palabras de la ley («Ministerio Fiscal»), sin cambiar el resto del prompt validado: las
    variantes que quitaban el contexto o escribían las edades con letras salían peor en content/eval/golden_rag.jsonl (ver
    backend/API.md). Revisión jurídica (22/10/2026): «Fiscalía de Menores» se queda junto a «Ministerio Fiscal» (si no, la
    definición validada no salía) y la pista de las fotos ya no es «retirada de contenidos», que traía los artículos 578
    (terrorismo) y 510 (odio) del Código Penal."""
    for pista in ('"la Fiscalía de Menores" → "el Ministerio Fiscal, Fiscalía de Menores"', "prohibición de aproximarse o comunicarse con la víctima",
                  "asistencia jurídica gratuita", "Canal prioritario de la Agencia Española de Protección de Datos",
                  "prueba preconstituida, reproducción de la grabación en el juicio", "mantenlo en la consulta"):
        assert pista in prompts.REFORMULAR
    assert "retirada de contenidos" not in prompts.REFORMULAR
    # La pista del «¿tengo que declarar?» del investigado se colaba en las consultas de las víctimas
    assert "derecho a no declarar" not in prompts.REFORMULAR
    assert prompts.REFORMULAR.rstrip().endswith("Consulta jurídica:")


def test_normas_11_y_12_en_los_dos_canales():
    for canal in ("voz", "texto"):
        s = prompts.sistema({}, [], canal=canal)
        assert "nunca «tu defensa»" in s and "centros de protección de menores" in s and "institutos" in s
        assert '"no tienes que" y no "no estás obligado"' in s


def test_responder_corrige_tu_defensa_a_una_victima(monkeypatch):
    monkeypatch.setattr(orquestador, "preparar", lambda m, p: orquestador.Contexto([{"role": "user", "content": "¿Quién estará?"}], []))
    monkeypatch.setattr(orquestador.client, "stream", lambda *a, **k: iter(["Tu defensa ", "estará allí."]))
    victima = "".join(orquestador.responder([{"role": "user", "content": "¿Quién estará?"}], {"rol": "victima"}))
    investigado = "".join(orquestador.responder([{"role": "user", "content": "¿Quién estará?"}], {"rol": "investigado"}))
    assert victima.strip() == "La defensa de la persona investigada estará allí."
    assert investigado.strip() == "Tu defensa estará allí."


def test_norma_3_pide_decir_las_condiciones():
    """«¿Tengo abogado gratis?»: decía «sin coste» aunque la LOPIVI y el glosario dicen «en los casos que marca la ley»."""
    for canal in ("voz", "texto"):
        assert "no digas que algo es gratis o seguro para todo el mundo" in prompts.sistema({}, [], canal=canal)


def test_abogado_gratis_con_sus_condiciones(monkeypatch):
    """«¿Tengo abogado gratis?»: «sí, gratuito» sin condiciones (respuesta real). A una víctima se le añade la precisión
    del glosario validado; a quien investigan, no (esa gratuidad sin mirar ingresos es para las víctimas)."""
    monkeypatch.setattr(orquestador, "preparar", lambda m, p: orquestador.Contexto([{"role": "user", "content": "¿Tengo abogado gratis?"}], []))
    sin_condicion = "Sí, tienes derecho a un abogado de oficio, es decir, gratuito.\n\n¿Quieres saber cómo pedirlo?\nFUENTES: ninguna"
    monkeypatch.setattr(orquestador.client, "completar", lambda *a, **k: sin_condicion)
    texto = orquestador.responder_texto([{"role": "user", "content": "¿Tengo abogado gratis?"}], {"rol": "victima"}).texto
    # Revisión jurídica: la frase sin condición se cambia por la precisión (antes se añadía detrás y se contradecían)
    assert texto == orquestador.PRECISION_GRATIS + "\n\n¿Quieres saber cómo pedirlo?"
    assert orquestador.PRECISION_GRATIS not in orquestador.responder_texto([{"role": "user", "content": "x"}], {"rol": "investigado"}).texto
    con_condicion = "Es gratis en los casos que marca la ley; si no, depende de los ingresos de tu familia.\nFUENTES: ninguna"
    monkeypatch.setattr(orquestador.client, "completar", lambda *a, **k: con_condicion)
    assert orquestador.PRECISION_GRATIS not in orquestador.responder_texto([{"role": "user", "content": "x"}], {"rol": "victima"}).texto
    # En la voz, igual: la frase se cambia por la precisión
    monkeypatch.setattr(orquestador.client, "stream", lambda *a, **k: iter(["Sí, el abogado ", "es gratis."]))
    voz = "".join(orquestador.responder([{"role": "user", "content": "¿Tengo abogado gratis?"}], {"rol": "victima"}))
    assert voz.strip() == orquestador.PRECISION_GRATIS
