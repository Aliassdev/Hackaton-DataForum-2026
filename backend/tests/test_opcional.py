"""Parche opcional: frases reales del Space (22/10/2026, 686a191) en las preguntas de los casos oficiales."""

from app.agent.verificacion import (
    FRASE_ACOSO_INSTITUTO,
    FRASE_EDADES,
    FRASE_MEDIDAS,
    FRASE_MENOR_14,
    FRASE_NO_ES_CULPA,
    verificar_stream,
    verificar_texto,
)

SERGIO = {"menor_14": True, "victima": True, "rol": "victima"}
SARA = {"menor_14": False, "victima": True, "rol": "victima"}


def test_s05_menores_de_14_no_van_por_la_ley_de_menores():
    frase = ("Para menores de 14 años no se usa la cárcel de adultos; se aplican medidas educativas o de protección según la Ley "
             "de menores.")
    assert verificar_texto(frase, **SERGIO) == FRASE_MENOR_14
    frase_b = ("En caso de que la persona que cometió el delito sea menor de 14 años, no se le enviará a una cárcel de adultos; "
               "se aplicará la Ley de menores y pueden ponerse medidas educativas.")
    assert verificar_texto(frase_b, **SERGIO) == FRASE_MENOR_14


def test_s05_lo_correcto_se_queda():
    for frase in (
        "Si tienen menos de 14 años, no se les aplica la ley de menores: actúan los servicios de protección de menores.",
        "Con menos de 14 años no se juzga a nadie por un delito, tampoco con la ley de menores.",
        "La ley de menores se aplica de 14 a 17 años.",
    ):
        assert verificar_texto(frase, **SERGIO) == frase


def test_z03_penas_con_duracion_a_una_victima():
    texto = ("El castigo depende de cómo sea el acoso. Si es un caso sencillo, la pena puede ser de seis a doce meses de prisión "
             "o una multa de diez a quince meses. Si el acosador tiene una posición de autoridad, la pena puede subir a uno o dos "
             "años de prisión y una inhabilitación para ejercer su trabajo.")
    salida = verificar_texto(texto, **SERGIO)
    assert FRASE_EDADES in salida and "prisión" not in salida.replace(FRASE_EDADES, "")
    assert salida.count(FRASE_EDADES) == 1


def test_duracion_en_meses_a_un_investigado():
    frase = "Puede imponerse una medida cautelar, como internamiento de hasta seis meses, que podría prorrogarse tres meses más."
    assert verificar_texto(frase, victima=False, rol="investigado") == FRASE_MEDIDAS
    assert "".join(verificar_stream([frase], rol="investigado")).strip() == FRASE_MEDIDAS


def test_duraciones_que_no_son_penas_se_quedan():
    for frase in ("La audiencia debe celebrarse sin que pasen más de diez días desde la citación.",
                  "El juez de menores puede poner medidas educativas a chicos y chicas de 14 a 17 años."):
        assert verificar_texto(frase, **SARA) == frase


def test_a04_no_es_culpa_de_sara():
    for frase in (
        ("Si enviaste la foto a otra persona sin su permiso, la responsabilidad recae en quien la difunde, es decir, en quien la "
         "envía o la comparte."),
        ("Si enviaste la foto a otras personas sin el permiso de quien aparece en ella, la responsabilidad recae en quien la "
         "difunde, no en quien aparece."),
    ):
        assert verificar_texto(frase, **SARA) == FRASE_NO_ES_CULPA
    # Sin fotos ni vídeos no es lo de Sara
    assert verificar_texto("La responsabilidad es de quien manda los mensajes.", **SARA) == "La responsabilidad es de quien manda los mensajes."


def test_l04_la_grabacion_no_es_secreta():
    salida = verificar_texto("Nadie más verá la grabación y se cuidará que no haya contacto visual.", **SERGIO)
    assert salida == "La grabación se guarda y solo se usa en el proceso, por ejemplo, en el juicio."


def test_fiscalia_acudir_al_instituto():
    frase = "Cuando se abre una investigación por acoso escolar, la Fiscalía de Menores puede acudir al instituto."
    voz = "".join(verificar_stream([frase], **SERGIO))
    assert "acudir al instituto" not in voz and "catorce años" in voz
    assert verificar_texto("Sí, la Fiscalía de Menores puede intervenir en tu instituto.", **SERGIO) == FRASE_ACOSO_INSTITUTO


def test_s05b_denuncia_falsa_a_menores_de_14():
    frase = "Si la denuncia resultara ser falsa, la ley penal castiga a quien la haya hecho con multa o, en casos graves, con prisión."
    assert "prisión" not in verificar_texto(frase, **SERGIO)
