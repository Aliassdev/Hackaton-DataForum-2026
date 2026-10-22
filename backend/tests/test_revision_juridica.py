"""Revisión jurídica de las respuestas reales del Space (22/10/2026, calidad/REVISION.md).

Cada test lleva la frase real que motivó el cambio. Sin red: el LLM y el RAG son de mentira, salvo los tests marcados
con el índice construido.
"""

import pytest

from app.agent import orquestador, prompts
from app.agent.verificacion import (
    FRASE_ACOSO_INSTITUTO,
    FRASE_MEDIDAS,
    para_texto,
    para_voz,
    revisar,
    sin_genero,
    sin_numero_de_articulo,
    verificar_stream,
    verificar_texto,
)
from app.rag.retrieve import Fragmento, get_recuperador, terminos_nombrados

LUCIA = {"edad": 11, "franja": "12-13", "procedimiento": "penal", "rol": "victima", "fase": "antes"}
SERGIO = {"edad": 13, "franja": "12-13", "procedimiento": "penal", "rol": "victima", "fase": "antes"}
INVESTIGADO = {"edad": 15, "franja": "14-15", "procedimiento": "penal", "rol": "investigado", "fase": "antes"}
FAMILIA = {"edad": 12, "franja": "12-13", "procedimiento": "familia", "rol": "escuchado", "fase": "antes"}


# --- prompt ---

@pytest.mark.parametrize("canal", ["voz", "texto"])
def test_norma_1_la_oficina_de_victimas_solo_para_victimas_y_testigos(canal):
    """A un investigado de 15 años: «¿Te gustaría saber cómo puedes contactar a tu abogado o a la Oficina de Asistencia a
    las Víctimas?»; en familia, la Oficina y ANAR en respuestas neutras."""
    oficina = "Oficina de Asistencia a las Víctimas"
    assert oficina in prompts.sistema(LUCIA, [], canal=canal)
    assert oficina in prompts.sistema({"rol": "testigo"}, [], canal=canal)
    investigado = prompts.sistema(INVESTIGADO, [], canal=canal)
    assert oficina not in investigado and "sugiere preguntar a su abogado o abogada." in investigado
    familia = prompts.sistema(FAMILIA, [], canal=canal)
    assert oficina not in familia and "sugiere preguntar a su familia o a una persona adulta de confianza." in familia
    sin_papel = prompts.sistema({}, [], canal=canal)
    assert oficina not in sin_papel and "sugiere preguntar a una persona adulta de confianza o a su abogado o abogada, si tiene." in sin_papel
    # ANAR sigue en las normas 7 y 8 (malestar, violencia, riesgo) para todos
    assert "Fundación ANAR" in familia and "Fundación ANAR" in sin_papel


def test_normas_iguales_en_los_dos_canales_para_cada_papel():
    for rol in (None, "victima", "testigo", "investigado", "escuchado"):
        voz, texto = prompts.normas("voz", rol), prompts.normas("texto", rol)
        assert texto == (
            voz.replace("novecientos, veinte, veinte, diez", "900 20 20 10").replace("ciento dieciséis, ciento once", "116 111")
            .replace("uno, uno, dos", "112").replace("no leas", "no escribas")
        )
        assert "{" not in voz and "{" not in texto


@pytest.mark.parametrize("canal", ["voz", "texto"])
def test_normas_de_la_revision_en_los_dos_canales(canal):
    s = prompts.sistema(SERGIO, [], canal=canal)
    # Norma 3: «¿me van a creer?», «de oficio, es decir, gratuito» y el defensor judicial como derecho de todas las víctimas
    assert "No digas si le van a creer" in s and "«De oficio» no quiere decir gratis." in s
    assert "el defensor judicial se nombra cuando los intereses de sus padres chocan con los suyos" in s
    # Norma 12: la Fiscalía visita los centros de protección, no los institutos; derechos del investigado ≠ de la víctima
    assert "como que el Ministerio Fiscal los visita y supervisa sus protocolos, no vale para los colegios ni los institutos" in s
    assert "Los derechos de la persona investigada no son los de la víctima o los testigos, ni al revés." in s
    # Norma 14 (culpa de la víctima y anuencia) y 15 (derecho a ser oído sin límite de edad)
    assert "A una víctima nunca le digas ni le des a entender que tiene la culpa" in s
    assert "aunque se hubieran hecho o enviado con permiso" in s
    assert "El derecho a que le escuchen no depende de la edad" in s
    # Norma 4 (los avisos a los padres de una víctima menor) y 9 (con menos de 14, ni con la ley de menores)
    assert "los avisos oficiales del proceso se mandan a sus padres o a quien le represente" in s
    assert "ni como adulto ni con la ley de menores" in s
    # Los personajes del glosario son víctimas (el ejemplo de la conciliación se aplicaba a quien causó el daño)
    assert "personajes inventados de la app que son víctimas" in s


@pytest.mark.parametrize("canal", ["voz", "texto"])
def test_norma_13_segun_el_papel(canal):
    """La primera versión (una sola norma 13 para todos) se le aplicaba también a las víctimas: a Sergio, de 13 años,
    «No tienes que declarar si no quieres», y en un proceso de familia, «No tienes que ir si no quieres declarar»."""
    investigado = prompts.sistema(INVESTIGADO, [], canal=canal)
    assert "se presume su inocencia" in investigado and "puede no declarar" in investigado and "No le hables de penas de prisión." in investigado
    for perfil in (SERGIO, {"rol": "testigo"}):
        victima = prompts.sistema(perfil, [], canal=canal)
        assert "dile que puede no declarar" not in victima and "se presume su inocencia" not in victima
        assert "no le digas que puede no declarar si no quiere (eso es un derecho de la persona investigada)" in victima
        assert "normalmente su declaración se graba antes del juicio" in victima
    familia = prompts.sistema(FAMILIA, [], canal=canal)
    assert "dile que puede no declarar" not in familia and "el juez escucha a los hijos y las hijas para conocer su opinión" in familia
    sin_papel = prompts.sistema({}, [], canal=canal)
    assert "explica la diferencia" in sin_papel and "una víctima o un testigo, en cambio, normalmente tiene que contar lo que sabe" in sin_papel


def test_las_normas_nuevas_no_usan_genero_sobre_la_persona():
    for rol in (None, "victima", "investigado", "escuchado"):
        normas = prompts.normas("texto", rol)
        for forma in ("sí misma", "sí mismo", "ella misma", "obligado", "obligada"):
            assert forma not in normas.split("13.")[1]


def test_el_llm_ve_en_que_parte_de_la_ley_esta_cada_articulo():
    """La visita del Ministerio Fiscal a los centros de protección (LOPIVI 55) se contaba como si fuera a los institutos."""
    lopivi = Fragmento("LOPIVI-55", "LOPIVI-55", "LOPIVI", "LOPIVI art. 55", "Supervisión por parte del Ministerio Fiscal",
                       "El Ministerio Fiscal visitará periódicamente...", "", 0.1,
                       contexto="TÍTULO IV. De las actuaciones en centros de protección")
    lecrim = Fragmento("LECRIM-449ter#1", "LECRIM-449ter", "LECRIM", "LECrim art. 449ter", "", "Cuando una persona menor...", "", 0.1,
                       contexto="TÍTULO V. De la comprobación del delito · CAPÍTULO V. De las declaraciones de los testigos")
    glosario = Fragmento("G-sala-gesell", "G-sala-gesell", "GLOSARIO", "Glosario TuTurno · Sala Gesell (Ley 4/2015, art. 25.1)",
                         "Ley 4/2015, art. 25.1", "Sala Gesell: ...", "", 0.1, norma="Glosario TuTurno · Sala Gesell", articulo="")
    texto = prompts.formatear_fragmentos([lopivi, lecrim, glosario])
    assert "[LOPIVI art. 55] Supervisión por parte del Ministerio Fiscal (TÍTULO IV. De las actuaciones en centros de protección)" in texto
    assert "[LECrim art. 449ter] (CAPÍTULO V. De las declaraciones de los testigos)" in texto
    assert "[Glosario TuTurno · Sala Gesell (Ley 4/2015, art. 25.1)]\nSala Gesell" in texto


# --- recuperación ---

def test_terminos_del_glosario_nombrados_en_la_pregunta():
    terminos = {"fiscalia de menores": 1, "fiscalia": 2, "acoso escolar": 3, "orden de alejamiento": 4, "sala gesell": 5}
    assert terminos_nombrados("¿Qué hace la Fiscalía de Menores si hay acoso escolar?", terminos) == [1, 3]
    assert terminos_nombrados("¿Qué es la SALA   gesell?", terminos) == [5]
    assert terminos_nombrados("¿Qué hace la Fiscalía?", terminos) == [2]
    assert terminos_nombrados("prejuicios y acosos escolares", terminos) == []  # palabras enteras
    assert terminos_nombrados("orden de alejamiento, sala Gesell y acoso escolar", terminos) == [4, 3]  # como mucho dos, los más largos
    # Con otra forma de la palabra, por la raíz: «denunciar» → «Denuncia»; los términos generales, nunca
    con_formas = {"denuncia": 1, "declaracion": 2, "intimidad": 3, "victima": 4, "juicio": 5}
    assert terminos_nombrados("¿Puedo denunciar yo sola sin mis padres?", con_formas) == [1]
    assert terminos_nombrados("¿Tengo que ir a declarar a un juicio?", con_formas) == []
    assert terminos_nombrados("¿Es delito reenviar una foto íntima?", con_formas) == []
    assert terminos_nombrados("qué derechos tengo si soy víctima", con_formas) == []


sin_indice = pytest.mark.skipif(get_recuperador() is None, reason="sin índice RAG construido")


@sin_indice
@pytest.mark.parametrize("perfil", [SERGIO, {}])
def test_rag_fiscalia_y_acoso_escolar_sin_los_centros_de_proteccion(perfil):
    """Botón «¿Qué hace la Fiscalía de Menores si hay acoso escolar?»: la LOPIVI 53 y 55 (centros de protección) salían
    delante de las definiciones validadas, y el LLM decía que la Fiscalía visita el instituto."""
    ids = [f.articulo_id for f in get_recuperador().buscar("¿Qué hace la Fiscalía de Menores si hay acoso escolar?", perfil, k=6)]
    assert {"G-fiscalia-menores", "G-acoso-escolar"} <= set(ids)
    assert "LOPIVI-55" not in ids and "LOPIVI-53" not in ids


@sin_indice
def test_rag_centros_de_proteccion_enteros_en_un_procedimiento_de_proteccion():
    rec = get_recuperador()
    pregunta = "Vivo en un centro de menores, ¿la Fiscalía viene a visitarlo?"
    proteccion = rec.pesos_contexto({"procedimiento": "proteccion"})
    penal = rec.pesos_contexto({"procedimiento": "penal"})
    assert proteccion == {} and penal and set(penal.values()) == {0.5}
    assert "LOPIVI-55" in [f.articulo_id for f in rec.buscar(pregunta, {"procedimiento": "proteccion"}, k=6)]


@sin_indice
def test_rag_el_termino_nombrado_entra_aunque_no_este_entre_los_mejores():
    rec = get_recuperador()
    frags = rec.buscar("¿Puedo denunciar yo sola sin mis padres?", {"edad": 15, "procedimiento": "penal", "rol": "victima"}, k=6)
    assert "G-denuncia" in [f.articulo_id for f in frags] and len(frags) == 6
    assert len({f.articulo_id for f in frags}) == 6
    # Las fuentes validadas (glosario, marco legal) no llevan la parte de la ley
    assert all(f.contexto is None for f in frags if f.norma is not None)


# --- verificación: género ---

@pytest.mark.parametrize(
    ("frase", "esperado"),
    [
        ("En la sala estarás solo/a con profesionales preparados.", "En la sala estarás con profesionales preparados."),
        ("No irás solo/a.", "No irás sin compañía."),
        ("¿Te sientes preparado/a para hablar allí?", "¿Te sientes con fuerzas para hablar allí?"),
        ("Se tiene en cuenta lo que necesites para estar seguro y feliz.", "Se tiene en cuenta lo que necesites para estar a salvo y feliz."),
        ("Todo esto se hace para que tú estés seguro/a en el colegio.", "Todo esto se hace para que tú estés a salvo en el colegio."),
        ("Si te pones nerviosa, puedes parar.", "Si te entran nervios, puedes parar."),
        ("Es normal ponerte muy nervioso.", "Es normal tener muchos nervios."),
        ("Puedes hacerlo acompañad@ de la persona que elijas.", "Puedes hacerlo con la persona que elijas."),
        ("Puedes ir acompañad@ de la persona que elijas.", "Puedes ir con la persona que elijas."),
        ("Se procurará que estés acompañada en todo momento por una persona de tu confianza.",
         "Se procurará que estés en todo momento con una persona de tu confianza."),
        ("Puedes ir acompañado de tu abogado o de la persona que te represente.",
         "Puedes ir con tu abogado o con la persona que te represente."),
    ],
)
def test_genero_formas_de_la_revision(frase, esperado):
    assert sin_genero(frase) == esperado


@pytest.mark.parametrize(
    "frase",
    [
        "Si no estás seguro de algo, pregúntalo.",  # «seguro de» es «sé con certeza»
        "Para estar seguro de que lo entiendes, te lo explico.",
        "El juez se pone serio a veces.",
        "Estarás solo una vez en la sala.",  # «solo» adverbio, sin barra
        "Lucía se pone nerviosa a veces.",  # tercera persona
    ],
)
def test_genero_no_toca_lo_que_no_es_sobre_la_persona(frase):
    assert sin_genero(frase) == frase


@pytest.mark.parametrize(
    ("frase", "esperado"),
    [
        ("¿Te sientes listo para hablar cuando llegue el momento?", "¿Te sientes con fuerzas para hablar cuando llegue el momento?"),
        ("Así puedes contar lo que recuerdas sin sentirte presionado.", "Así puedes contar lo que recuerdas sin sentir presión."),
        ("Si te sientes presionada, dilo.", "Si sientes presión, dilo."),
    ],
)
def test_genero_listo_y_presionado(frase, esperado):
    assert sin_genero(frase) == esperado


# --- verificación: números de artículo ---

@pytest.mark.parametrize(
    ("frase", "esperado"),
    [
        ("También puedes pedir al juez que ordene la retirada (Código Penal artículo quinientos setenta y ocho).",
         "También puedes pedir al juez que ordene la retirada."),
        ("En el artículo cincuenta y dos de la Ley de Protección de la Infancia se indica que hay un canal.",
         "En la Ley de Protección de la Infancia se indica que hay un canal."),
        ("Según el artículo 197 del Código Penal, es delito.", "Según el Código Penal, es delito."),
        ("El artículo 3 de la ley de menores lo dice.", "La ley de menores lo dice."),
        ("Lo dice el artículo veintidós de la ley de menores.", "Lo dice la ley de menores."),
    ],
)
def test_sin_numeros_de_articulo(frase, esperado):
    assert sin_numero_de_articulo(frase) == esperado


def test_sin_numero_detras_del_nombre_de_la_ley_ni_parentesis_vacios():
    assert sin_numero_de_articulo("Puede ser delito según el Código Penal art. 197, que castiga la difusión.") == (
        "Puede ser delito según el Código Penal, que castiga la difusión."
    )
    # Una cita entre corchetes quitada dentro de un paréntesis («([LECrim art. 681.3] a)») dejaba «( a)» y «()»
    assert verificar_texto("Se prohíbe divulgarla ( a). Hay oficinas de ayuda (). Tu abogado(a) te ayuda.") == (
        "Se prohíbe divulgarla. Hay oficinas de ayuda. Tu abogado(a) te ayuda."
    )


def test_sin_numeros_de_articulo_en_la_voz():
    assert para_voz("Lo puede ordenar el juez (Código Penal artículo quinientos setenta y ocho).") == "Lo puede ordenar el juez."
    assert para_voz("Lo dice el artículo 52 de la LOPIVI.") == "Lo dice la LOPIVI."
    # Sin artículo no se toca nada
    assert sin_numero_de_articulo("Tienes 14 años y el 900 20 20 10 es gratis.") == "Tienes 14 años y el 900 20 20 10 es gratis."


# --- verificación: con menos de 14 años, ni como adulto ---

@pytest.mark.parametrize(
    ("frase", "esperado"),
    [
        ("No. Si tienes 13 años, la ley dice que no se te juzga como a un adulto.", "No. Si tienes 13 años, la ley dice que no se te juzga por un delito."),
        ("A los menores de 14 años no se les juzga como adultos.", "A los menores de 14 años no se les juzga por un delito."),
    ],
)
def test_menos_de_14_no_se_juzga_ni_como_adulto(frase, esperado):
    assert verificar_texto(frase) == esperado


def test_de_14_a_17_no_se_juzga_como_adulto_se_queda():
    frase = "Con 15 años no te juzgan como a un adulto, sino con la ley de menores."
    assert verificar_texto(frase) == frase


# --- verificación: «¿me van a creer?» ---

@pytest.mark.parametrize(
    "frase",
    [
        "En el proceso, el juez y el fiscal valoran si tu testimonio es fiable.",
        "El juez decidirá si tu testimonio es suficiente según tu capacidad de entender y declarar.",
        "Revisarán la credibilidad de tu declaración durante la investigación.",
    ],
)
def test_sin_valorar_el_testimonio(frase):
    assert revisar(frase, voz=False) == (None, "valoracion_testimonio")


@pytest.mark.parametrize(
    "frase",
    [
        "La grabación de tu declaración es suficiente y normalmente no tendrás que repetirla.",
        "Si algo no lo recuerdas, puedes decirlo.",
    ],
)
def test_lo_que_si_se_puede_decir_del_testimonio(frase):
    assert revisar(frase, voz=False)[1] is None


# --- verificación: la Fiscalía no visita los institutos ---

@pytest.mark.parametrize(
    "frase",
    [
        "La Fiscalía de Menores revisa que el centro tenga un protocolo contra el acoso escolar y que se cumpla.",
        "La Fiscalía de Menores supervisa que los centros cumplan los protocolos contra el acoso escolar.",
        "Cada vez que se detecta acoso, el Ministerio Fiscal lo visita para comprobar que se está siguiendo en el colegio.",
        "Visita el centro regularmente, habla con los niños y niñas que lo pidan.",
        "Además, supervisará que el instituto cumpla ese protocolo.",
    ],
)
def test_la_fiscalia_no_visita_ni_supervisa_los_institutos(frase):
    assert revisar(frase, voz=False) == (FRASE_ACOSO_INSTITUTO, "fiscalia_en_el_instituto")
    assert "catorce años" in revisar(frase)[0]  # en la voz, con letras


@pytest.mark.parametrize(
    "frase",
    [
        "El Ministerio Fiscal visita los centros de protección de menores, no los colegios.",
        "Si el instituto no actúa, puedes contárselo a la Fiscalía de Menores.",
        "La Fiscalía de Menores dirige la investigación y vigila que se respeten tus derechos.",
        "En el instituto, la coordinadora de bienestar revisa que se cumpla el protocolo.",
    ],
)
def test_lo_que_si_se_puede_decir_de_la_fiscalia(frase):
    assert revisar(frase, voz=False)[1] is None


def test_en_un_procedimiento_de_proteccion_la_fiscalia_si_visita_su_centro():
    frase = "La Fiscalía visita tu centro para comprobar que se cumplen los protocolos."
    assert revisar(frase, voz=False)[1] == "fiscalia_en_el_instituto"
    assert revisar(frase, voz=False, proteccion=True) == (frase, None)


def test_la_frase_del_instituto_sale_una_sola_vez():
    texto = ("La Fiscalía de Menores revisa que el centro cumpla el protocolo contra el acoso. Visita el centro para comprobar "
             "que se aplican las medidas. Si lo necesitas, puedes pedir ayuda.")
    assert verificar_texto(texto) == FRASE_ACOSO_INSTITUTO + " Si lo necesitas, puedes pedir ayuda."
    voz = "".join(verificar_stream([texto])).strip()
    assert voz.count("coordinadora de bienestar") == 1 and "Visita" not in voz


# --- verificación: a quien investigan, nada de penas de prisión ---

def test_investigado_sin_penas_de_prision():
    """Investigado de 15 años: «quien difunde esas imágenes puede ser castigado con prisión de tres a cinco años»."""
    frase = "La ley dice que quien difunde esas imágenes puede ser castigado con prisión de tres a cinco años."
    assert revisar(frase, voz=False, rol="investigado") == (FRASE_MEDIDAS, "prision_investigado")
    # A una víctima, la pena de un adulto es información (el artículo 197.7 la da)
    assert revisar("La pena puede ser prisión de tres meses a un año o multa.", voz=False, rol="victima")[1] is None


@pytest.mark.parametrize(
    "frase",
    [
        "Con la ley de menores no se va a una cárcel de adultos.",
        "Las penas de prisión del Código Penal son para adultos.",
        "No vas a ir a la cárcel: el juez de menores puede poner medidas educativas.",
    ],
)
def test_investigado_lo_que_si_se_puede_decir_de_la_carcel(frase):
    assert revisar(frase, voz=False, rol="investigado")[1] is None


def test_la_frase_de_las_medidas_no_se_repite():
    texto = "Puede haber internamiento de uno a cinco años. También prisión de tres a cinco años. Habla con tu abogado."
    assert verificar_texto(texto, rol="investigado") == FRASE_MEDIDAS + " Habla con tu abogado."


# --- verificación: según el papel ---

@pytest.mark.parametrize("rol", ["investigado", "escuchado"])
@pytest.mark.parametrize(
    ("frase", "esperado"),
    [
        ("¿Te gustaría saber cómo puedes contactar a tu abogado o a la Oficina de Asistencia a las Víctimas para más información?",
         "¿Te gustaría saber cómo puedes contactar a tu abogado para más información?"),
        ("Si tienes dudas, habla con tu abogado o con la Oficina de Asistencia a las Víctimas.", "Si tienes dudas, habla con tu abogado."),
        ("Pregunta a la Oficina de Asistencia a las Víctimas o a tu abogado.", "Pregunta a tu abogado."),
    ],
)
def test_sin_oficina_de_victimas_para_quien_no_es_victima(rol, frase, esperado):
    assert para_texto(frase, rol=rol) == esperado
    assert para_texto(frase, victima=True, rol="victima") == frase


def test_de_oficio_no_quiere_decir_gratis():
    frase = "Tienes derecho a que te asignen un abogado o abogada de oficio, es decir, gratuito, siempre que lo solicites."
    assert para_texto(frase, victima=True) == "Tienes derecho a que te asignen un abogado o abogada de oficio, siempre que lo solicites."
    assert para_texto("La Oficina de Atención a la Víctima te ayuda.", victima=True) == "La Oficina de Asistencia a las Víctimas te ayuda."


# --- orquestador: precisiones ---

def _texto(monkeypatch, respuesta: str, pregunta: str, perfil: dict) -> str:
    monkeypatch.setattr(orquestador, "preparar", lambda m, p: orquestador.Contexto([{"role": "user", "content": pregunta}], []))
    monkeypatch.setattr(orquestador.client, "completar", lambda *a, **k: respuesta)
    return orquestador.responder_texto([{"role": "user", "content": pregunta}], perfil).texto


def test_canal_prioritario_con_su_condicion(monkeypatch):
    """«un chaval ha pasado una foto mía por el grupo de clase»: al Canal prioritario sin decir que no sirve para
    WhatsApp (glosario validado y AEPD, FAQ 15.03)."""
    pregunta = "un chaval ha pasado una foto mia por el grupo de clase, la pueden quitar?"
    respuesta = "Puedes pedir que la quiten en el Canal prioritario de la AEPD.\n\n¿Quieres saber cómo?\nFUENTES: ninguna"
    texto = _texto(monkeypatch, respuesta, pregunta, SERGIO)
    assert texto.split("\n\n")[1] == orquestador.PRECISION_CANAL and texto.endswith("¿Quieres saber cómo?")
    con_condicion = "El Canal prioritario no sirve para WhatsApp, pero puedes denunciarlo.\nFUENTES: ninguna"
    assert orquestador.PRECISION_CANAL not in _texto(monkeypatch, con_condicion, pregunta, SERGIO)
    assert orquestador.PRECISION_CANAL not in _texto(monkeypatch, "Puedes denunciarlo.\nFUENTES: ninguna", pregunta, SERGIO)
    # En la voz, al final (antes del recordatorio de ANAR)
    monkeypatch.setattr(orquestador.client, "stream", lambda *a, **k: iter(["Pide que la quiten ", "en el Canal prioritario."]))
    voz = "".join(orquestador.responder([{"role": "user", "content": pregunta}], SERGIO))
    assert voz.index(orquestador.PRECISION_CANAL) < voz.index("Fundación ANAR")


@pytest.mark.parametrize(
    "frase",
    [
        "Tienes derecho a que te asignen un abogado o abogada de oficio, es decir, un profesional que te representa sin coste.",
        "Si la familia tiene ingresos altos, el derecho sigue aplicándose porque la ley protege a todas las víctimas, sin importar su situación económica.",
        "Sí, el abogado es gratis.",
    ],
)
def test_victima_abogado_gratis_sin_condicion_se_cambia_por_la_precision(frase):
    """Sara, 15 años: «...un profesional que te representa sin coste [...] si la familia tiene ingresos altos, el derecho
    sigue aplicándose [...] sin importar su situación económica» (la precisión no salía porque decía «ingresos»)."""
    assert revisar(frase, voz=False, victima=True, rol="victima") == (orquestador.PRECISION_GRATIS, "gratis_sin_condicion")
    assert revisar(frase, voz=False, rol="investigado")[1] != "gratis_sin_condicion"


@pytest.mark.parametrize(
    "frase",
    [
        "El abogado es gratis si es un delito sexual; en otros casos, depende de los ingresos de tu familia.",
        "¿Quieres que te explique cómo funciona la asistencia jurídica gratuita?",
        "Puedes pedir asistencia jurídica gratuita si cumples los requisitos.",
    ],
)
def test_victima_abogado_gratis_con_condicion_se_queda(frase):
    assert revisar(frase, voz=False, victima=True, rol="victima")[1] is None


def test_la_precision_no_salta_por_una_pregunta_de_la_respuesta(monkeypatch):
    """«¿Te gustaría que te explique cómo funciona la asistencia jurídica gratuita para víctimas?» añadía la precisión."""
    respuesta = "No tienen por qué avisar al instituto.\n\n¿Te explico cómo funciona la asistencia jurídica gratuita para víctimas?\nFUENTES: ninguna"
    assert orquestador.PRECISION_GRATIS not in _texto(monkeypatch, respuesta, "¿Se van a enterar en el insti?", SERGIO)


def test_conciliacion_el_compromiso_lo_asume_quien_representa_a_la_victima():
    """«Cuando el responsable es menor, sus padres asumen el compromiso» (al revés que la ley de menores, art. 19.6)."""
    for frase in ("Cuando el responsable es menor, sus padres o quien le represente deben asumir el compromiso y el juez de menores tiene que aprobarlo.",
                  "En el caso de menores, el compromiso lo asumen sus padres o quien le represente."):
        assert revisar(frase, voz=False)[1] == "conciliacion_al_reves"
    assert revisar("Si la víctima es menor, el compromiso lo asumen sus padres y lo aprueba el juez.", voz=False)[1] is None


def test_menor_de_14_sin_prometer_decir_la_verdad():
    """A Lucía, 11 años: «Es decir, prometes decir siempre la verdad» (el juramento y la promesa son para los adultos)."""
    assert revisar("Es decir, prometes decir siempre la verdad.", voz=False, menor_14=True)[1] == "falso_testimonio"


def test_abogado_gratuitamente_sin_condiciones(monkeypatch):
    """A Sergio: «tienes derecho a que te asistan gratuitamente un abogado o abogada» sin condiciones."""
    respuesta = "Tienes derecho a que te asistan gratuitamente un abogado o abogada.\nFUENTES: ninguna"
    assert orquestador.PRECISION_GRATIS in _texto(monkeypatch, respuesta, "¿Tengo que ir a declarar?", SERGIO)


def test_abogado_gratis_si_la_pregunta_es_por_el_coste(monkeypatch):
    """«¿Tengo abogado gratis?» → «...un abogado de oficio, es decir, gratuito»: quitada la equivalencia, sigue haciendo
    falta decir cuándo es gratis."""
    respuesta = "Tienes derecho a un abogado de oficio, que te asigna el Colegio de Abogados.\nFUENTES: ninguna"
    texto = _texto(monkeypatch, respuesta, "¿Tengo abogado gratis?", SERGIO)
    assert texto == "Tienes derecho a un abogado de oficio, que te asigna el Colegio de Abogados.\n\n" + orquestador.PRECISION_GRATIS
    # Si no pregunta por el coste ni la respuesta dice «gratis», no se añade
    assert orquestador.PRECISION_GRATIS not in _texto(monkeypatch, "Tienes derecho a un abogado.\nFUENTES: ninguna", "¿Quién me ayuda?", SERGIO)


# --- ajustes tras pasar la verificación nueva por las 227 respuestas reales guardadas ---

@pytest.mark.parametrize(
    "frase",
    [
        "Puedes pedir la asistencia jurídica gratuita en la Oficina de Asistencia a las Víctimas o al funcionario que te atienda.",
        "Ellos tramitarán la solicitud al Colegio de Abogados y, si procede, te asignarán el abogado de forma gratuita.",
    ],
)
def test_victima_lo_que_no_es_decir_que_el_abogado_es_gratis_para_todos(frase):
    assert revisar(frase, voz=False, victima=True, rol="victima")[1] is None


def test_acompanado_de_x_o_de_y_solo_dentro_de_la_regla():
    assert sin_genero("Puedes ir acompañado de tu abogado o de la persona que te represente.") == (
        "Puedes ir con tu abogado o con la persona que te represente."
    )
    for frase in ("Puedes hacerlo con la ayuda de tu abogado o de la Oficina de Asistencia a las Víctimas.",
                  "Podrás hacerlo con la compañía de tus padres o de otra persona que el juez autorice."):
        assert sin_genero(frase) == frase


def test_oficina_de_victimas_en_una_lista():
    frase = "Puedes preguntar a tu abogado, a la Oficina de Asistencia a las Víctimas o a la Fundación ANAR, al 900 20 20 10."
    assert para_texto(frase, rol="investigado") == "Puedes preguntar a tu abogado o a la Fundación ANAR, al 900 20 20 10."


@pytest.mark.parametrize(
    "frase",
    [
        "Estas medidas son distintas a la prisión y dependen de la gravedad del hecho.",
        "No es una pena de prisión para adultos, sino una medida educativa.",
        "En lugar de la cárcel, el juez de menores puede poner medidas educativas.",
    ],
)
def test_investigado_frases_correctas_sobre_la_prision(frase):
    assert revisar(frase, voz=False, rol="investigado")[1] is None


def test_la_frase_de_la_fiscalia_segun_la_pregunta():
    """A Lucía, «¿Qué hace la Fiscalía de Menores?»: «Visita los centros donde estés». Sin acoso en la pregunta, la frase
    del protocolo del instituto no pega."""
    from app.agent.verificacion import FRASE_FISCALIA_MENORES

    frase = "Visita los centros donde estés y escucha lo que necesites contar."
    assert revisar(frase, voz=False, escolar=False) == (FRASE_FISCALIA_MENORES, "fiscalia_en_el_instituto")
    assert revisar(frase, voz=False, escolar=True) == (FRASE_ACOSO_INSTITUTO, "fiscalia_en_el_instituto")
    assert orquestador.opciones_verificacion(LUCIA, "¿Qué hace la Fiscalía de Menores?")["escolar"] is False
    assert orquestador.opciones_verificacion(SERGIO, "¿Qué hace la Fiscalía de Menores si hay acoso escolar?")["escolar"] is True


@pytest.mark.parametrize(
    "frase",
    [
        "Puedes presentar la denuncia, pero al ser menor de edad la ley exige que la hagas acompañada de una persona que te represente.",
        "Para denunciar necesitas que te acompañen tus padres.",
    ],
)
def test_se_puede_denunciar_sin_una_persona_adulta(frase):
    from app.agent.verificacion import FRASE_DENUNCIA_SOLA

    assert revisar(frase, voz=False) == (FRASE_DENUNCIA_SOLA, "denuncia_con_adulto")


def test_denunciar_lo_que_si_se_puede_decir():
    for frase in ("Puedes denunciar sin que te acompañe un adulto.", "Para denunciar no necesitas que te acompañen tus padres.",
                  "Si quieres, tus padres pueden acompañarte a denunciar."):
        assert revisar(frase, voz=False)[1] is None
