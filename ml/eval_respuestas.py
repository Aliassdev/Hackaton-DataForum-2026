"""P6 · Evaluación de las respuestas completas (capas 2 + 3 + 4) con un LLM como juez.

Uso, desde la raíz del repo:
    backend/.venv/Scripts/python -X utf8 ml/eval_respuestas.py [--n 12]

Por cada pregunta del conjunto de referencia: recupera, genera y verifica como en producción, y mide:
- Fidelidad: afirmaciones de la respuesta respaldadas por los fragmentos recuperados (juez: LLM_MODELO_REFORMULAR).
- Legibilidad Fernández-Huerta (objetivo >= 65) por franja de edad.
- Infracciones de los límites del agente (preguntar por los hechos, prometer secreto, predecir).
- Longitud en palabras.
Usa pocas preguntas por defecto para no agotar la cuota diaria del plan gratuito de Groq.
"""

import argparse
import json
import re
import statistics
import sys
import time
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "backend"))
from app.agent import orquestador, prompts  # noqa: E402
from app.agent.perfil import franja  # noqa: E402
from app.agent.verificacion import PROHIBIDOS, verificar_stream  # noqa: E402
from app.config import settings  # noqa: E402
from app.llm import client  # noqa: E402

JUEZ = """Eres un evaluador estricto. Compara la RESPUESTA con los FRAGMENTOS DE LA LEY.
Divide la respuesta en afirmaciones sobre la ley o el proceso (ignora saludos, preguntas finales y la recomendación de llamar a ANAR).
Una afirmación está respaldada si se deduce de los fragmentos. Devuelve SOLO JSON:
{{"afirmaciones": <número>, "respaldadas": <número>, "no_respaldadas": ["...", "..."]}}

FRAGMENTOS DE LA LEY
{fragmentos}

RESPUESTA
{respuesta}"""


def silabas(palabra: str) -> int:
    p = re.sub(r"[^a-záéíóúüñ]", "", palabra.lower())
    if not p:
        return 0
    p = p.replace("ü", "u")
    fuertes, n, prev = set("aeoáéóíú"), 0, ""
    for c in p:
        if c in "aeiouáéíóú":
            # nueva sílaba si no hay vocal previa, o si son dos fuertes seguidas (hiato)
            if not prev or (prev in fuertes and c in fuertes):
                n += 1
            prev = c
        else:
            prev = ""
    return max(n, 1)


def fernandez_huerta(texto: str) -> float:
    palabras = re.findall(r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+", texto)
    frases = max(len(re.findall(r"[.!?]+", texto)), 1)
    if not palabras:
        return 0.0
    p = 100 * sum(silabas(w) for w in palabras) / len(palabras)  # sílabas por cada 100 palabras
    f = len(palabras) / frases  # palabras por frase (adaptación de Flesch)
    return 206.84 - 0.60 * p - 1.02 * f


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=12)
    args = ap.parse_args()
    if not settings.llm_api_key:
        sys.exit("Falta GROQ_API_KEY en backend/.env")

    golden = [json.loads(l) for l in (RAIZ / "content/eval/golden_rag.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
    # Muestra repartida por todo el conjunto (penal, familia, protección, imágenes)
    paso = max(len(golden) // args.n, 1)
    muestra = golden[::paso][: args.n]

    filas = []
    for i, g in enumerate(muestra, 1):
        perfil = dict(g["perfil"], franja=franja(g["perfil"]["edad"]))
        historial = [{"role": "user", "content": g["pregunta"]}]
        fragmentos, _ = orquestador.recuperar(g["pregunta"], historial, perfil)
        llamada = [{"role": "system", "content": prompts.sistema(perfil, fragmentos)}] + historial
        crudo = "".join(client.stream(llamada, modelo=settings.llm_modelo))
        respuesta = "".join(verificar_stream([crudo])).strip()
        time.sleep(2)

        veredicto = json.loads(client.completar(
            [{"role": "user", "content": JUEZ.format(fragmentos=prompts.formatear_fragmentos(fragmentos), respuesta=respuesta)}],
            modelo=settings.llm_modelo_reformular, max_tokens=800, json_obj=True,
        ))
        time.sleep(2)
        infracciones_crudo = [m for m, (patron, _) in PROHIBIDOS.items() if patron.search(crudo)]
        filas.append({
            "pregunta": g["pregunta"], "franja": perfil["franja"], "respuesta": respuesta,
            "afirmaciones": veredicto.get("afirmaciones", 0), "respaldadas": veredicto.get("respaldadas", 0),
            "no_respaldadas": veredicto.get("no_respaldadas", []),
            "fernandez_huerta": round(fernandez_huerta(respuesta), 1), "palabras": len(respuesta.split()),
            "infracciones_llm": infracciones_crudo,  # lo que el LLM intentó decir y la capa 4 quitó
        })
        f = filas[-1]
        print(f"[{i}/{len(muestra)}] {f['respaldadas']}/{f['afirmaciones']} respaldadas · FH {f['fernandez_huerta']} · {f['palabras']} palabras · {g['pregunta']}")

    total_af = sum(f["afirmaciones"] for f in filas) or 1
    print(f"\n=== Respuestas completas ({len(filas)} preguntas) ===")
    print(f"Fidelidad: {sum(f['respaldadas'] for f in filas) / total_af:.1%} de las afirmaciones respaldadas por la ley recuperada")
    for fr in ("12-13", "14-15", "16-17"):
        v = [f["fernandez_huerta"] for f in filas if f["franja"] == fr]
        if v:
            print(f"Legibilidad Fernández-Huerta {fr}: media {statistics.mean(v):.1f} (n={len(v)})")
    print(f"Palabras por respuesta: mediana {statistics.median(f['palabras'] for f in filas)}")
    print(f"Infracciones que intentó el LLM y bloqueó la capa 4: {sum(len(f['infracciones_llm']) for f in filas)}")
    print("\nAfirmaciones no respaldadas:")
    for f in filas:
        for a in f["no_respaldadas"]:
            print(f"  - [{f['pregunta'][:50]}] {a}")

    salida = RAIZ / "artifacts/index/metrics_respuestas.json"
    salida.write_text(json.dumps(filas, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nDetalle en {salida}")


if __name__ == "__main__":
    main()
