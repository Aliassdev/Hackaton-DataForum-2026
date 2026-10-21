"""Crea (o actualiza) el agente de ElevenLabs que usa nuestro backend como Custom LLM.

Uso, desde backend/:
    .venv/Scripts/python scripts/setup_agent.py https://<túnel>.trycloudflare.com

- Primera vez: crea el secreto CUSTOM_LLM_SECRET en ElevenLabs, crea el agente y
  escribe ELEVENLABS_AGENT_ID en .env.
- Siguientes veces (el túnel rápido cambia de URL al reiniciarse): solo actualiza la URL.
"""

import re
import sys
from pathlib import Path

import httpx
from dotenv import dotenv_values

API = "https://api.elevenlabs.io/v1/convai"
ENV_PATH = Path(__file__).resolve().parent.parent / ".env"

PROMPT = """Eres TuTurno, una IA que acompaña a chicos y chicas de 12 a 17 años en un procedimiento judicial.
Perfil: edad={{edad}}; procedimiento={{procedimiento}}; rol={{rol}}; fase={{fase}}."""

PLACEHOLDERS = {"edad": "14", "procedimiento": "penal", "rol": "testigo", "fase": "antes"}


def _guardar_env(clave: str, valor: str) -> None:
    texto = ENV_PATH.read_text(encoding="utf-8")
    if re.search(rf"^{clave}=.*$", texto, flags=re.M):
        texto = re.sub(rf"^{clave}=.*$", f"{clave}={valor}", texto, flags=re.M)
    else:
        texto += f"\n{clave}={valor}\n"
    ENV_PATH.write_text(texto, encoding="utf-8")


def _custom_llm(url_tunel: str, secret_id: str | None) -> dict:
    cfg = {"url": f"{url_tunel.rstrip('/')}/v1", "model_id": "tuturno", "api_type": "chat_completions"}
    if secret_id:
        cfg["api_key"] = {"secret_id": secret_id}
    return cfg


def main() -> None:
    if len(sys.argv) != 2 or not sys.argv[1].startswith("https://"):
        sys.exit("Uso: python scripts/setup_agent.py https://<túnel>")
    url_tunel = sys.argv[1]

    env = dotenv_values(ENV_PATH)
    api_key = env.get("ELEVENLABS_API_KEY")
    if not api_key:
        sys.exit("Falta ELEVENLABS_API_KEY en backend/.env")
    http = httpx.Client(headers={"xi-api-key": api_key}, timeout=30)

    agent_id = env.get("ELEVENLABS_AGENT_ID")
    secret_id = env.get("ELEVENLABS_LLM_SECRET_ID")

    if not secret_id and env.get("CUSTOM_LLM_SECRET"):
        r = http.post(f"{API}/secrets", json={"type": "new", "name": "tuturno-custom-llm", "value": env["CUSTOM_LLM_SECRET"]})
        r.raise_for_status()
        secret_id = r.json()["secret_id"]
        _guardar_env("ELEVENLABS_LLM_SECRET_ID", secret_id)
        print(f"Secreto creado: {secret_id}")

    if agent_id:
        r = http.patch(
            f"{API}/agents/{agent_id}",
            json={"conversation_config": {"agent": {"prompt": {"llm": "custom-llm", "custom_llm": _custom_llm(url_tunel, secret_id)}}}},
        )
        if r.status_code >= 400:
            sys.exit(f"Error {r.status_code} al actualizar el agente: {r.text}")
        print(f"Agente {agent_id} apuntando a {url_tunel}/v1")
        return

    cuerpo = {
        "name": "TuTurno",
        "conversation_config": {
            "agent": {
                "language": "es",
                "first_message": "Hola, soy TuTurno. ¿En qué te puedo ayudar?",
                "prompt": {"prompt": PROMPT, "llm": "custom-llm", "custom_llm": _custom_llm(url_tunel, secret_id)},
                "dynamic_variables": {"dynamic_variable_placeholders": PLACEHOLDERS},
            },
        },
    }
    r = http.post(f"{API}/agents/create", json=cuerpo)
    if r.status_code >= 400:
        sys.exit(f"Error {r.status_code} al crear el agente: {r.text}")
    agent_id = r.json()["agent_id"]
    _guardar_env("ELEVENLABS_AGENT_ID", agent_id)
    print(f"Agente creado: {agent_id} (guardado en .env), apuntando a {url_tunel}/v1")


if __name__ == "__main__":
    main()
