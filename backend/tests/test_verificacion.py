import pytest

from app.agent.verificacion import (
    NEGATIVA_EN_ESPANOL,
    normalizar_salida,
    numero_a_letras,
    parece_ingles,
    revisar,
    verificar_stream,
    verificar_texto,
)


def _verificar(texto: str, trozo: int = 7) -> str:
    """Simula el streaming del LLM partiendo el texto en trozos pequeños."""
    return "".join(verificar_stream(texto[i : i + trozo] for i in range(0, len(texto), trozo))).strip()


def test_deja_pasar_respuesta_correcta():
    texto = "Puedes ir con alguien de confianza. El juez te hablará con calma."
    assert _verificar(texto) == texto


def test_elimina_pregunta_por_los_hechos():
    salida = _verificar("Entiendo que estés nervioso. ¿Qué te hizo exactamente? Te explico cómo es la declaración.")
    assert "qué te hizo" not in salida.lower()
    assert "Te explico cómo es la declaración." in salida


def test_sustituye_promesa_de_secreto():
    salida = _verificar("Tranquilo, nadie se va a enterar de lo que me cuentes.")
    assert "nadie se va a enterar" not in salida
    assert "los adultos que te protegen tienen que actuar" in salida


def test_sustituye_prediccion():
    salida = _verificar("Te aseguro que vas a ganar el juicio.")
    assert "ganar" not in salida and "depende" in salida


def test_numeros_en_letras_y_sin_markdown():
    assert _verificar("**Tienes** que ir si tienes 14 años.") == "Tienes que ir si tienes catorce años."
    assert numero_a_letras(900) == "novecientos" and numero_a_letras(116) == "ciento dieciséis" and numero_a_letras(21) == "veintiuno"


def test_no_parte_la_frase_detras_de_art():
    """«art. 22» no es un final de frase: si se partiera, la cita entre corchetes se quedaría a medias y se leería."""
    assert "".join(verificar_stream(["Puedes ir con alguien [LORPM ", "art. 22]. ", "Te lo explican antes."])) == "Puedes ir con alguien. Te lo explican antes. "
    assert "".join(verificar_stream(["Lo dice el art. 3 de la ley. Fin."])) == "Lo dice el art. tres de la ley. Fin. "


# --- pruebas adversariales contra el Space (22/10/2026) ---

def test_citas_con_corchetes_lenticulares_no_se_leen_ni_se_ven():
    """gpt-oss cita a veces como «【LECrim art. 682】»: en pantalla se veía y en la voz se leía el número."""
    voz = "".join(verificar_stream(["El juez puede prohibir que se grabe【LECrim art. 682】. ", "Te lo explican antes【4†L1-L5】."]))
    assert voz == "El juez puede prohibir que se grabe. Te lo explican antes. "
    # En el canal de texto, las citas se quitan al separar las fuentes (test_agent_ask); aquí, las de navegación
    assert verificar_texto("Puedes denunciarlo【2†L3-L9】.") == "Puedes denunciarlo."


def test_espacios_finos_de_los_telefonos_pasan_a_espacios_normales():
    assert verificar_texto("Llama a ANAR al 900 20 20 10.") == "Llama a ANAR al 900 20 20 10."
    assert normalizar_salida("116 111") == "116 111"
    assert "".join(verificar_stream(["Llama al 900 20 20 10."])) == "Llama al novecientos veinte veinte diez. "


@pytest.mark.parametrize("frase", ["I’m sorry, but I can’t share that.", "I'm sorry, but I can't comply with that request.", "Sure! Here is a joke for you: what do you call a fake noodle?"])
def test_frase_en_ingles_se_cambia_por_una_negativa_en_espanol(frase):
    assert "".join(verificar_stream([frase])).strip() == NEGATIVA_EN_ESPANOL
    assert verificar_texto(frase) == NEGATIVA_EN_ESPANOL


@pytest.mark.parametrize(
    "frase",
    ["El bullying y el sexting pueden ser delito.", "¿Has hablado con tu abogado?", "Puedes pedir ayuda online en ANAR.", "La ley de menores se aplica de 14 a 17 años."],
)
def test_frases_en_espanol_con_anglicismos_no_se_tocan(frase):
    assert not parece_ingles(frase)


def test_no_iras_a_la_carcel_no_es_una_prediccion():
    """De 14 a 17 años no se va a una cárcel de adultos (ley de menores): esa frase no se puede borrar."""
    assert _verificar("Con 15 años no irás a la cárcel. El juez de menores puede poner medidas educativas.") == (
        "Con quince años no irás a la cárcel. El juez de menores puede poner medidas educativas."
    )
    assert "cárcel" not in _verificar("Irás a la cárcel seguro.")


@pytest.mark.parametrize(
    "frase",
    [
        "El juez de menores podrá imponer una medida de internamiento en régimen cerrado de uno a ocho años, y libertad vigilada.",
        "La medida puede durar hasta 3 años.",
        "Te pueden poner de 1 a 5 años de internamiento.",
        "La libertad vigilada puede alcanzar dos años.",
    ],
)
def test_sin_anos_de_internamiento(frase):
    """gpt-oss copiaba de la LORPM las duraciones del supuesto más grave aunque el prompt lo prohíbe."""
    salida = _verificar(frase)
    assert "años" not in salida and "dependen de lo que pasó" in salida


@pytest.mark.parametrize(
    "frase",
    [
        "La ley de menores se aplica de 14 a 17 años.",
        "El juez de menores puede poner medidas educativas, que dependen de lo que pasó.",
        "Si tienes 16 o 17 años, se aplica la ley de menores.",
    ],
)
def test_edades_y_medidas_sin_duracion_se_quedan(frase):
    assert revisar(frase, voz=False) == (frase, None)


@pytest.mark.parametrize(
    "frase", ["El expediente de menores es confidencial.", "Tu identidad será confidencial durante el proceso.", "La audiencia es secreta para el público."]
)
def test_datos_del_proceso_confidenciales_no_son_una_promesa(frase):
    assert revisar(frase, voz=False) == (frase, None)


@pytest.mark.parametrize("frase", ["Todo lo que me cuentes es confidencial.", "Esto es totalmente secreto.", "Lo que hablamos queda siempre secreto."])
def test_promesas_de_secreto_se_sustituyen(frase):
    final, motivo = revisar(frase, voz=False)
    assert motivo == "secreto_absoluto" and "tienen que actuar" in final


@pytest.mark.parametrize("frase", ["¿Qué te pasó exactamente?", "¿que te hicieron?", "Cuéntame lo que pasó.", "¿Cómo ocurrió?"])
def test_preguntas_por_los_hechos_se_eliminan(frase):
    assert revisar(frase, voz=False) == (None, "pregunta_hechos")


def test_lo_que_paso_sin_preguntar_no_se_borra():
    frase = "Las medidas dependen de lo que pasó y de cada persona."
    assert revisar(frase, voz=False) == (frase, None)


def test_con_menos_de_14_sin_juramento_ni_falso_testimonio():
    """LECrim 433: el juramento y el aviso de falso testimonio son para testigos adultos. A Lucía (11) se los contaba."""
    frase = "El juez te explicará que debes ser veraz y que mentir es delito de falso testimonio."
    final, motivo = revisar(frase, voz=False, menor_14=True)
    assert motivo == "falso_testimonio" and "falso testimonio" not in final
    assert revisar(frase, voz=False) == (frase, None)  # sin la edad o con 14 o más, se queda
    assert "juramento" not in "".join(verificar_stream(["Declararás bajo juramento. ", "Puedes ir con alguien."], menor_14=True))


def test_sin_numeros_de_articulo_entre_parentesis():
    """Norma 6: el LLM ponía «(artículo 20)» o «(Código Penal art. 197)»; en la voz se leía el número."""
    assert verificar_texto("Deben garantizar tu seguridad (artículo 20). Puedes denunciar tú (artículo 50 e).") == (
        "Deben garantizar tu seguridad. Puedes denunciar tú."
    )
    assert _verificar("Difundirla es delito (Código Penal art. 197). Te pueden ayudar.") == "Difundirla es delito. Te pueden ayudar."
    assert verificar_texto("Tienes derechos (por ejemplo, a un abogado).") == "Tienes derechos (por ejemplo, a un abogado)."


# --- sin género sobre la persona y «tu defensa» (medidas de calidad del 22/10/2026) ---

@pytest.mark.parametrize(
    ("frase", "esperado"),
    [
        ("Puedes ir acompañado de una persona de confianza.", "Puedes ir con una persona de confianza."),
        ("Siempre puedes estar acompañada desde el primer contacto.", "Siempre puedes estar con alguien desde el primer contacto."),
        ("Si estás asustado, puedes pedir una pausa.", "Si estás con miedo, puedes pedir una pausa."),
        ("Entiendo que te sientes muy asustada.", "Entiendo que te sientes con mucho miedo."),
        ("No estás obligado a declarar contra tu padre.", "No tienes que declarar contra tu padre."),
        ("Tienes derecho a estar informada de todo.", "Tienes derecho a recibir información de todo."),
        ("Estarás informado de la fecha.", "Recibirás información de la fecha."),
        ("Tienes derecho a ser oído y escuchado.", "Tienes derecho a que te oigan y te escuchen."),
        ("No estás solo.", "No estás solo ni sola."),
        ("Puedes denunciarlo tú sola, sin un adulto.", "Puedes denunciarlo por tu cuenta, sin un adulto."),
        ("No tienes que ir sola.", "No tienes que ir sin compañía."),
        ("Para que te sientas segura y tranquila.", "Para que te sientas a salvo y con tranquilidad."),
        ("Estarás protegido durante todo el proceso.", "Tendrás protección durante todo el proceso."),
        ("Puedes contarlo tú mismo o pedir ayuda.", "Puedes contarlo tú o pedir ayuda."),
        ("Si eres lo bastante maduro, el juez te escucha.", "Si tienes madurez suficiente, el juez te escucha."),
        ("Cuando estés preparada, el juez te llamará.", "Cuando quieras, el juez te llamará."),
        ("Para que estés más cómodo.", "Para que estés más a gusto."),
        ("Si te sientes incómoda o nerviosa, dilo.", "Si te sientes a disgusto o con nervios, dilo."),
    ],
)
def test_sin_genero_sobre_la_persona(frase, esperado):
    assert verificar_texto(frase) == esperado


@pytest.mark.parametrize(
    "frase",
    [
        "La persona acompañada del menor declara después.",  # de un tercero
        "Los testigos están obligados a declarar.",
        "El menor tiene derecho a ser oído y escuchado.",
        "Declaras solo una vez y se graba.",  # «solo» adverbio
        "Solo tienes que contar lo que recuerdes.",
        "No estás solo ni sola.",  # ya es inclusivo
        "Estás nervioso o nerviosa, es normal.",
        "Si no estás seguro, pregúntalo.",  # «seguro» de «saber»
        "Puedes ser escuchada por el juez.",  # con «por el juez» no se puede dar la vuelta
        "Esa persona no es segura para ti.",
    ],
)
def test_sin_genero_no_toca_lo_que_no_habla_de_quien_pregunta(frase):
    assert verificar_texto(frase) == frase


def test_sin_genero_tambien_en_la_voz():
    assert _verificar("Puedes ir acompañado de tu madre. Si estás nerviosa, dilo.") == "Puedes ir con tu madre. Si estás con nervios, dilo."


def test_a_una_victima_no_se_le_dice_tu_defensa():
    """N2 contra el Space: a Lucía, víctima de 11 años, «Tu defensa y el juez estarán presentes»."""
    texto = "Tu defensa y el juez estarán presentes. Habla con tu defensor si tienes dudas."
    assert verificar_texto(texto, victima=True) == (
        "La defensa de la persona investigada y el juez estarán presentes. Habla con tu abogado o tu abogada si tienes dudas."
    )
    assert verificar_texto(texto) == texto  # a quien investigan sí se le habla de su defensa
    voz = "".join(verificar_stream(["Tu defensa estará en la sala."], victima=True)).strip()
    assert voz == "La defensa de la persona investigada estará en la sala."


def test_etiqueta_larga_del_glosario_no_se_lee():
    """Las etiquetas del glosario, con su base legal, pasan de 80 caracteres: también se quitan en la voz."""
    frase = "Es una sala preparada [Glosario TuTurno · Sala Gesell (Ley 4/2015, art. 25.1; LECrim, arts. 449 bis y 449 ter)]."
    assert _verificar(frase) == "Es una sala preparada."


@pytest.mark.parametrize(
    ("frase", "esperado"),
    [
        # Respuestas reales en local (22/10/2026): la forma con barra dejaba «a disgusto/a» y «tú/a»
        ("Si te sientes incómodo/a o tienes miedo, dilo.", "Si te sientes a disgusto o tienes miedo, dilo."),
        ("Como tienes 15 años, puedes hacerlo tú mismo/a.", "Como tienes 15 años, puedes hacerlo tú."),
        ("Puedes ir acompañado/a de tu madre.", "Puedes ir con tu madre."),
        ("No estás obligado/a a ir.", "No tienes que ir."),
        ("¿Ya tienes a alguien que te haga sentir seguro?", "¿Ya tienes a alguien que te haga sentir a salvo?"),
        ("Alguien que te haga sentir tranquilo.", "Alguien que te haga sentir con tranquilidad."),
        ("Si te sientes inseguro, llama.", "Si te sientes con inseguridad, llama."),
    ],
)
def test_sin_genero_formas_con_barra_y_sentir(frase, esperado):
    assert verificar_texto(frase) == esperado


def test_sin_genero_no_toca_terceras_personas_con_barra():
    assert verificar_texto("Te informarán de cuándo llega tu abogado/a.") == "Te informarán de cuándo llega tu abogado/a."
    assert verificar_texto("Lucía se siente tranquila con su tía.") == "Lucía se siente tranquila con su tía."


def test_el_limite_de_la_ley_de_menores_son_14_anos():
    """«No, a los menores de 13 años no se les juzga» (respuesta real): el límite es 14 (LORPM, arts. 1 y 3)."""
    assert verificar_texto("No, a los menores de 13 años no se les juzga con la ley penal.") == (
        "No, a los menores de 14 años no se les juzga con la ley penal."
    )
    assert _verificar("Un menor de trece años no tiene responsabilidad penal.") == "Un menor de catorce años no tiene responsabilidad penal."
    # En un proceso de familia, «menores de 12 años» es otra regla (LEC, art. 770): no se toca
    assert verificar_texto("Los menores de 12 años pueden ser oídos si el juez lo ve necesario.") == (
        "Los menores de 12 años pueden ser oídos si el juez lo ve necesario."
    )


@pytest.mark.parametrize(
    ("frase", "esperado"),
    [
        ("Como víctima, puedes ser llamada a declarar.", "Como víctima, te pueden llamar a declarar."),  # respuesta real a Sergio
        ("Puedes ser citado como testigo.", "Te pueden citar como testigo."),
        ("Vas a ser entrevistada en una sala preparada.", "Te van a entrevistar en una sala preparada."),
        ("Tienes derecho a ser acompañada y protegida.", "Tienes derecho a que te acompañen y te protejan."),
        ("Tienes derecho a ser oído y escuchado.", "Tienes derecho a que te oigan y te escuchen."),
    ],
)
def test_sin_genero_en_pasiva(frase, esperado):
    assert verificar_texto(frase) == esperado
