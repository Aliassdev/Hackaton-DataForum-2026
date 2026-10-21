from app.agent.verificacion import numero_a_letras, verificar_stream


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
