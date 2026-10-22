"""Despliega el backend en un Space Docker de Hugging Face (pasos completos en backend/DESPLIEGUE.md).

Uso, desde backend/ con el venv del backend:
    .venv/bin/python scripts/desplegar_hf.py <usuario>/<space> --solo-carpeta    # solo monta la carpeta
    .venv/bin/python scripts/desplegar_hf.py <usuario>/<space>                   # monta y sube el código
    .venv/bin/python scripts/desplegar_hf.py <usuario>/<space> --subir-secretos --origenes https://<usuario>.github.io

1. Monta artifacts/space/ con lo que espera el Dockerfile: Dockerfile, .dockerignore, README.md del Space
   (cabecera YAML con sdk: docker y app_port: 7860), backend/ (app/ y requirements.txt), content/ y el
   índice del RAG (artifacts/index, más artifacts/models/guardrail si existe). Nunca copia .env.
2. Crea el Space si no existe (SDK docker, visibilidad "protected" por defecto: código privado y API pública)
   y sube la carpeta en un commit. Cada subida reconstruye la imagen (unos 10 minutos).
3. Enseña las variables y los secretos que hay que poner en Settings → Variables and secrets. Solo con
   --subir-secretos los sube, leyéndolos de backend/.env sin imprimir ningún valor secreto.

Usa el token guardado por `hf auth login` (con permiso de escritura); el script no lo lee ni lo imprime.
"""

import argparse
import re
import shutil
import sys
from pathlib import Path
from typing import TYPE_CHECKING

from dotenv import dotenv_values

if TYPE_CHECKING:
    from huggingface_hub import HfApi

BACKEND = Path(__file__).resolve().parent.parent
RAIZ = BACKEND.parent
ENV_PATH = BACKEND / ".env"
CARPETA = RAIZ / "artifacts/space"
INDICE = RAIZ / "artifacts/index"
GUARDRAIL = RAIZ / "artifacts/models/guardrail"
FICHEROS_INDICE = ("trozos.jsonl", "emb.npy", "bm25")

# Secretos: privados en el Space y nunca en la imagen. LLM_API_KEY solo si se usa en vez de GROQ_API_KEY.
SECRETOS = ("ELEVENLABS_API_KEY", "ELEVENLABS_AGENT_ID", "GROQ_API_KEY", "LLM_API_KEY", "CUSTOM_LLM_SECRET")
# Variables públicas con valor fijo en producción
VARIABLES_FIJAS = {"DEBUG_LLM_REQUESTS": "false"}
# Configuración que solo se sube si está en backend/.env (si no, vale el valor por defecto de config.py)
VARIABLES_OPCIONALES = (
    "LLM_BASE_URL", "LLM_MODELO", "LLM_MODELO_REFORMULAR", "LLM_MODELO_EVALUAR",
    "GUARDRAIL_UMBRAL_CRISIS", "GUARDRAIL_UMBRAL_OTROS", "ALLOWED_ORIGIN_REGEX",
)
# Límites de peticiones: se leen de app/config.py (nombre y valor por defecto) para seguir sus cambios
RE_LIMITE = re.compile(r'_int\("((?:LIMITE_[A-Z_]+)|PROXIES_DE_CONFIANZA)",\s*(\d+)\)')
RE_REPO = re.compile(r"^[\w.-]+/[\w.-]{1,96}$")

README = """---
title: TuTurno API
emoji: ⚖️
colorFrom: indigo
colorTo: yellow
sdk: docker
app_port: 7860
pinned: false
short_description: Backend de TuTurno, justicia explicada a menores
---

# TuTurno · backend

API de TuTurno (DATAthon DATAfórum Justicia 2026, reto 2: infancia y juventud). No tiene interfaz propia:
la usan la app TuTurno y el agente de voz de ElevenLabs.

- `GET /api/health`: estado.
- `GET /api/session/token`: token de conversación de corta duración para el agente de voz (privado).
- `POST /v1/chat/completions`: Custom LLM del agente (compatible con OpenAI, en streaming).
- `POST /api/agent/ask`: modo texto (web en iPhone y respaldo si falla la voz).
- `POST /api/learn/grade`: evaluador de «Dilo con tus palabras».

Este Space se genera con `backend/scripts/desplegar_hf.py` desde el repositorio del proyecto.
Las claves van en Settings → Variables and secrets, nunca en los ficheros.
"""


def comprobar_entrada() -> None:
    faltan = [str(p.relative_to(RAIZ)) for p in (RAIZ / "Dockerfile", BACKEND / "requirements.txt", RAIZ / "content")
              if not p.exists()]
    faltan += [f"artifacts/index/{f}" for f in FICHEROS_INDICE if not (INDICE / f).exists()]
    if faltan:
        sys.exit("Faltan ficheros para el despliegue: " + ", ".join(faltan)
                 + "\nEl índice se construye con ml/ingest_leyes.py y ml/build_index.py.")


def _sin_secretos(_: str, nombres: list[str]) -> set[str]:
    """Filtro de copytree: fuera .env*, entornos virtuales y cachés."""
    fuera = {".venv", "venv", "__pycache__", ".pytest_cache", ".ruff_cache"}
    return {n for n in nombres if n.startswith(".env") or n in fuera or n.endswith((".pyc", ".pyo"))}


def montar_carpeta(carpeta: Path) -> None:
    if carpeta.exists():
        shutil.rmtree(carpeta)
    carpeta.mkdir(parents=True)
    shutil.copy2(RAIZ / "Dockerfile", carpeta / "Dockerfile")
    if (RAIZ / ".dockerignore").exists():
        shutil.copy2(RAIZ / ".dockerignore", carpeta / ".dockerignore")
    (carpeta / "README.md").write_text(README, encoding="utf-8")

    (carpeta / "backend").mkdir()
    shutil.copytree(BACKEND / "app", carpeta / "backend/app", ignore=_sin_secretos)
    shutil.copy2(BACKEND / "requirements.txt", carpeta / "backend/requirements.txt")
    shutil.copytree(RAIZ / "content", carpeta / "content", ignore=_sin_secretos)

    (carpeta / "artifacts/index").mkdir(parents=True)
    for nombre in FICHEROS_INDICE:
        origen = INDICE / nombre
        destino = carpeta / "artifacts/index" / nombre
        if origen.is_dir():
            shutil.copytree(origen, destino)
        else:
            shutil.copy2(origen, destino)
    if (GUARDRAIL / "metadata.json").exists():
        shutil.copytree(GUARDRAIL, carpeta / "artifacts/models/guardrail", ignore=_sin_secretos)

    # Última barrera: ningún .env puede acabar en el Space
    if colados := list(carpeta.rglob(".env*")):
        shutil.rmtree(carpeta)
        sys.exit(f"Se ha colado un fichero de entorno ({colados[0].name}); carpeta borrada, no se sube nada.")


def _tamano(ruta: Path) -> int:
    return sum(f.stat().st_size for f in ruta.rglob("*") if f.is_file()) if ruta.is_dir() else ruta.stat().st_size


def resumen_carpeta(carpeta: Path) -> None:
    print(f"Carpeta del Space: {carpeta}")
    for parte in sorted(carpeta.iterdir()):
        print(f"  {parte.name:<16}{_tamano(parte) / 1e6:8.1f} MB")
    con_guardrail = (carpeta / "artifacts/models/guardrail").exists()
    print(f"  Guardrail: {'modelo entrenado incluido' if con_guardrail else 'sin modelo entrenado (solo reglas)'}")


def limites_de_config() -> dict[str, str]:
    """Nombre y valor por defecto de los límites de peticiones que define app/config.py."""
    texto = (BACKEND / "app/config.py").read_text(encoding="utf-8")
    return dict(RE_LIMITE.findall(texto))


def variables(env: dict[str, str | None], origenes: str | None) -> dict[str, str]:
    """Variables públicas del Space. Los límites, con el valor de .env o el de config.py."""
    salida = dict(VARIABLES_FIJAS)
    if origenes:
        salida["ALLOWED_ORIGINS"] = origenes
    for clave, defecto in limites_de_config().items():
        salida[clave] = env.get(clave) or defecto
    for clave in VARIABLES_OPCIONALES:
        if env.get(clave):
            salida[clave] = str(env[clave])
    return salida


def explicar_configuracion(env: dict[str, str | None], origenes: str | None) -> None:
    print("\nSettings → Variables and secrets del Space")
    print("  Secretos (privados; el valor se lee del .env y no se imprime):")
    for clave in SECRETOS:
        estado = "en .env" if env.get(clave) else "falta en .env"
        nota = " (solo si no usas GROQ_API_KEY)" if clave == "LLM_API_KEY" else ""
        print(f"    - {clave}: {estado}{nota}")
    print("  Variables (públicas):")
    for clave, valor in variables(env, origenes).items():
        print(f"    - {clave}={valor}")
    if not origenes:
        print("    - ALLOWED_ORIGINS: pásala con --origenes (la web de GitHub Pages); si no, vale la de config.py")
    if not env.get("CUSTOM_LLM_SECRET"):
        print("  AVISO: sin CUSTOM_LLM_SECRET, /v1/chat/completions queda abierto a cualquiera (gasta el LLM).")


def _hf() -> "HfApi":
    try:
        from huggingface_hub import HfApi
    except ImportError:
        sys.exit("Falta huggingface_hub: .venv/bin/python -m pip install huggingface_hub")
    api = HfApi()
    try:
        usuario = api.whoami()["name"]
    except Exception:  # noqa: BLE001 - sin sesión o token caducado
        sys.exit("No hay sesión de Hugging Face: ejecuta `hf auth login` con un token de escritura.")
    print(f"Sesión de Hugging Face: {usuario}")
    return api


def subir_configuracion(api: "HfApi", repo_id: str, env: dict[str, str | None], origenes: str | None) -> None:
    print("\nSubiendo variables y secretos al Space...")
    for clave in SECRETOS:
        if valor := env.get(clave):
            api.add_space_secret(repo_id, clave, valor)
            print(f"  secreto  {clave}: subido")
    for clave, valor in variables(env, origenes).items():
        api.add_space_variable(repo_id, clave, valor)
        print(f"  variable {clave}={valor}")


def main() -> None:
    ap = argparse.ArgumentParser(description="Despliega el backend de TuTurno en un Space Docker de Hugging Face.")
    ap.add_argument("repo_id", help="Space de destino: <usuario u organización>/<nombre>, p. ej. aliassdev/tuturno-api")
    ap.add_argument("--solo-carpeta", action="store_true", help="monta la carpeta y no sube nada")
    ap.add_argument("--carpeta", type=Path, default=CARPETA, help="dónde montar la carpeta (por defecto artifacts/space)")
    ap.add_argument("--subir-secretos", action="store_true", help="sube secretos y variables leyendo backend/.env")
    ap.add_argument("--env", type=Path, default=ENV_PATH, help="fichero de entorno del que leer (por defecto backend/.env)")
    ap.add_argument("--origenes", help="ALLOWED_ORIGINS de producción, separados por comas")
    ap.add_argument("--visibilidad", choices=("protected", "public", "private"), default="protected",
                    help="solo al crear el Space. protected: código privado y API pública (PRO). "
                         "private dejaría la API sin acceso para ElevenLabs y la app")
    ap.add_argument("--hardware", choices=("cpu-basic", "cpu-upgrade"),
                    help="cambia el hardware del Space. cpu-upgrade cuesta 0,03 $/h y no se duerme")
    ap.add_argument("--mensaje", default="Despliegue del backend de TuTurno", help="mensaje del commit en el Space")
    args = ap.parse_args()
    if not RE_REPO.match(args.repo_id):
        sys.exit("repo_id debe tener la forma <usuario>/<nombre-del-space>")

    comprobar_entrada()
    montar_carpeta(args.carpeta)
    resumen_carpeta(args.carpeta)
    env = dotenv_values(args.env) if args.env.exists() else {}
    explicar_configuracion(env, args.origenes)
    if args.solo_carpeta:
        print("\n--solo-carpeta: no se ha subido nada.")
        return

    api = _hf()
    # Un token fine-grained con escritura solo en el Space no puede crear repos: si ya existe, no se crea
    if api.repo_exists(args.repo_id, repo_type="space"):
        print(f"El Space {args.repo_id} ya existe: se actualiza")
    else:
        api.create_repo(args.repo_id, repo_type="space", space_sdk="docker", exist_ok=True, visibility=args.visibilidad)
        print(f"Space creado: {args.repo_id} ({args.visibilidad})")
    if args.subir_secretos:
        subir_configuracion(api, args.repo_id, env, args.origenes)  # antes del código: la build arranca con ellos
    if args.hardware:
        api.request_space_hardware(args.repo_id, args.hardware)
        print(f"Hardware solicitado: {args.hardware}")
    print("\nSubiendo la carpeta (la primera vez tarda: el índice y, si hay, el guardrail van por LFS)...")
    info = api.upload_folder(
        repo_id=args.repo_id, repo_type="space", folder_path=args.carpeta,
        commit_message=args.mensaje, delete_patterns="*",  # el Space queda igual que la carpeta
    )
    host = api.space_info(args.repo_id).host or f"https://{re.sub(r'[^a-z0-9-]', '-', args.repo_id.lower())}.hf.space"
    print(f"Subido: {info.commit_url}")
    print(f"Logs de la build: https://huggingface.co/spaces/{args.repo_id}?logs=build")
    print(f"Cuando esté en marcha: curl {host}/api/health")
    print(f"URL del Custom LLM para el agente: {host}/v1 (scripts/proteger_agente.py --custom-llm-url {host})")


if __name__ == "__main__":
    main()
