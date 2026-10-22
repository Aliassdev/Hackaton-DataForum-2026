#!/usr/bin/env bash
# Copia a la app el contenido que usa (docs/ARQUITECTURA.md, sección 6.8). Ejecútalo antes de cada build.
# Solo se copian los JSON; las carpetas de app/assets/content se mantienen con .gitkeep.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/content"
DST="$ROOT/app/assets/content"

if [ ! -d "$SRC" ]; then
  echo "Aviso: no existe $SRC (lo prepara B). No se cambia nada en app/assets/content." >&2
  echo "Sin contenido, la app con USE_MOCK=false enseña el glosario vacío; con USE_MOCK=true usa los ejemplos." >&2
  exit 0
fi

find "$DST" -name '*.json' -delete 2>/dev/null || true
for dir in lecciones ejercicios juego itinerarios; do
  mkdir -p "$DST/$dir"
  if [ -d "$SRC/$dir" ]; then
    find "$SRC/$dir" -maxdepth 1 -name '*.json' -exec cp {} "$DST/$dir/" \;
  fi
done
if [ -f "$SRC/glosario.json" ]; then
  cp "$SRC/glosario.json" "$DST/"
fi
echo "Contenido sincronizado: $(find "$DST" -name '*.json' | wc -l) ficheros JSON en app/assets/content"
# La app solo enseña lo que tiene "validado": true y "fuente" (CLAUDE.md). Avisa de cuántas entradas no saldrán.
if [ -f "$DST/glosario.json" ] && command -v python3 >/dev/null; then
  python3 -I - "$DST/glosario.json" <<'PY' || true
import json, sys
datos = json.load(open(sys.argv[1], encoding="utf-8"))
ocultas = [e for e in datos if not (isinstance(e, dict) and e.get("validado") is True and str(e.get("fuente", "")).strip())]
print(f"Glosario: {len(datos) - len(ocultas)} términos visibles, {len(ocultas)} sin validar o sin fuente (no se ven).")
PY
fi
