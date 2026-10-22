"""Copia las ideas clave de los ejercicios «dilo» de la app en content/evaluador.json (POST /api/learn/grade, 8.2).

Uso, desde backend/:
    .venv/bin/python scripts/sincronizar_evaluador.py ../../app/assets/mock/content/ejercicios
    .venv/bin/python scripts/sincronizar_evaluador.py <carpeta> --comprobar   # solo dice si hay diferencias

Lee los ejercicios de la app (esquema 9.3, un fichero por unidad) y se queda con los de tipo «dilo» que tienen
"validado": true, fuente y al menos una idea clave. Si la app cambia un «dilo», basta con volver a ejecutarlo.
Mientras los ejercicios no vivan en content/ejercicios/, este fichero es la copia que lee el backend.
"""

import argparse
import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent.parent
SALIDA = RAIZ / "content/evaluador.json"
NOTA = (
    "Ideas clave de cada concepto para el evaluador de «Dilo con tus palabras» (POST /api/learn/grade). Copia de los "
    "ejercicios «dilo» validados de la app (app/assets/mock/content/ejercicios, esquema 9.3), generada con "
    "backend/scripts/sincronizar_evaluador.py: si cambian allí, vuelve a ejecutarlo. Cuando los ejercicios vivan en "
    "content/ejercicios/, el backend los lee de ahí primero y este archivo solo cubre lo que falte."
)


def conceptos_dilo(carpeta: Path) -> list[dict]:
    salida: list[dict] = []
    vistos: set[str] = set()
    for ruta in sorted(carpeta.glob("*.json"), key=lambda r: (len(r.stem), r.stem)):  # unidad-2 antes que unidad-10
        datos = json.loads(ruta.read_text(encoding="utf-8"))
        ejercicios = datos.get("ejercicios", []) if isinstance(datos, dict) else datos
        for e in ejercicios:
            if not (isinstance(e, dict) and e.get("tipo") == "dilo" and e.get("validado") is True):
                continue
            ideas = [p.strip() for p in e.get("proposiciones", []) if isinstance(p, str) and p.strip()]
            if not (e.get("concepto") and str(e.get("fuente") or "").strip() and ideas) or e["concepto"] in vistos:
                continue
            vistos.add(e["concepto"])
            salida.append({
                "concepto": e["concepto"], "ejercicio": e.get("id", ""), "pregunta": e.get("pregunta", ""),
                "proposiciones": ideas, "fuente": e["fuente"].strip(), "validado": True,
            })
    return salida


def contenido(conceptos: list[dict]) -> str:
    filas = ",\n".join("    " + json.dumps(c, ensure_ascii=False) for c in conceptos)
    return f'{{\n  "_nota": {json.dumps(NOTA, ensure_ascii=False)},\n  "conceptos": [\n{filas}\n  ]\n}}\n'


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("carpeta", type=Path, help="carpeta de ejercicios de la app (unidad-*.json)")
    ap.add_argument("--comprobar", action="store_true", help="no escribe: sale con 1 si content/evaluador.json no coincide")
    args = ap.parse_args()
    conceptos = conceptos_dilo(args.carpeta)
    if not conceptos:
        sys.exit(f"No hay ejercicios «dilo» validados en {args.carpeta}")
    nuevo = contenido(conceptos)
    if args.comprobar:
        igual = SALIDA.exists() and SALIDA.read_text(encoding="utf-8") == nuevo
        print("content/evaluador.json está al día" if igual else "content/evaluador.json no coincide con los ejercicios de la app")
        sys.exit(0 if igual else 1)
    SALIDA.write_text(nuevo, encoding="utf-8")
    print(f"content/evaluador.json: {len(conceptos)} conceptos ({', '.join(c['concepto'] for c in conceptos)})")


if __name__ == "__main__":
    main()
